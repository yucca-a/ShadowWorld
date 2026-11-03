-- Only for the isolated copy of the reported rollback failure. Never ship.
local key = "sw_rollback_copy_fixture_v1"
local Engine = require("worldexchangeengine2hm")
local attach = Engine.Attach
Engine.Attach = function(service)
    attach(service)
    local e = service.engine
    if not e or e.latency_instrumented then return end
    e.latency_instrumented = true
    local began, measured, hold = service:Now(), false, e.Hold
    e.Hold = function(self, value)
        hold(self, value)
        if not value and not measured and self.core:IsReady() then
            measured = true
            print("[ROLLBACK_COPY] CONTROLS_READY_MS", TheShard:GetShardId(), (service:Now()-began)*1000)
        end
    end
end
local remote, acknowledged, command = {}, nil, nil
AddShardModRPCHandler("SW_ROLLBACK_COPY", "status", function(peer, state)
    local ok, data = RunInSandboxSafe(state)
    if ok then remote[tostring(peer)] = data end
end)
AddShardModRPCHandler("SW_ROLLBACK_COPY", "prepare", function(peer, raw)
    TheSim:SetPersistentString(key, raw, false, function(ok)
        assert(ok ~= false)
        SendModRPCToShard(GetShardModRPC("SW_ROLLBACK_COPY", "ack"), tostring(peer), raw)
    end)
end)
AddShardModRPCHandler("SW_ROLLBACK_COPY", "ack", function(peer, raw) acknowledged = raw end)
AddShardModRPCHandler("SW_ROLLBACK_COPY", "stop", function() c_shutdown(false) end)
for _, name in ipairs({"status", "prepare", "ack", "stop"}) do
    require("worldexchangerpc2hm").Install(GLOBAL, GetShardModRPC("SW_ROLLBACK_COPY", name),
        GetShardModRPCHandler("SW_ROLLBACK_COPY", name))
end
local saves = 0
local nativeSerialize = GLOBAL.SerializeWorldSession
GLOBAL.SerializeWorldSession = function(...)
    saves = saves + 1
    return nativeSerialize(...)
end
AddPrefabPostInit("world", function(inst)
    if not inst.ismastersim then return end
    assert(TheNet:GetServerName() == "ShadowWorld isolated rollback copy", "disposable rollback copy required")
    inst:PushEvent("ms_setautosaveenabled", false) -- Explicit fixture saves only.
    local state, phase, verified, baseline, round, filled = nil, "loading", 0, nil, 1, false
    local last, started, beforeSaves, count, saving, pending, written, timer = nil, false, 0, 0, false, nil, false, 0
    TheSim:GetPersistentString(key, function(ok, raw)
        if ok then local parsed, data = RunInSandboxSafe(raw); assert(parsed); state = data end
        phase = "wait"
    end)
    local function signature(box)
        local item = box.slots[1]
        return item and (item.prefab .. ":" .. (item.components.stackable and item.components.stackable:StackSize() or 1)) or "empty"
    end
    inst:DoStaticPeriodicTask(.25, function()
        timer = timer + .25
        assert(timer < 600, "rollback fixture timeout: " .. phase)
        local service = inst.components.worldexchange2hm
        local e = service and service.engine
        if not e then return end
        local status = tostring(service.legacy) .. "/" .. e.core.phase .. "/" .. tostring(e.timeline_wait) .. "/" ..
            tostring(service.protocol.active and service.protocol.active.phase) .. "/" .. tostring(e.core.generation)
        if status ~= last then print("[ROLLBACK_COPY] STATE", TheShard:GetShardId(), status); last = status end
        local peer = next(service.peers)
        local boxinst = inst:GetPocketDimensionContainer("shadow")
        if not peer or not boxinst then return end
        local box, master = boxinst.components.container, TheShard:IsMaster()
        local own = {ready = e.core:IsReady(), generation = e.core.generation, active = service.protocol.active ~= nil,
            signature = signature(box), verified = verified, filled = filled}
        SendModRPCToShard(GetShardModRPC("SW_ROLLBACK_COPY", "status"), peer, DataDumper(own, nil, true))
        if not e.core:IsReady() or phase == "loading" then return end
        local other = remote[peer]
        if phase == "wait" then
            if state then
                assert(e.core.generation == state.baseline, "rollback loaded wrong shared checkpoint")
                assert(signature(box) == (master and "goldnugget:17" or "rocks:31"), "rollback item count differs")
                baseline, verified, round = state.baseline, state.round, state.round + 1
                print("[ROLLBACK_COPY] VERIFIED_ROLLBACK", state.round, state.steps, TheShard:GetShardId(), e.core.generation)
                phase = "verified"
            else
                assert(inst.state.cycles < 10, "legacy rollback advanced to the later day-65 checkpoint")
                print("[ROLLBACK_COPY] RECOVERED_LEGACY_WORLD", TheShard:GetShardId(), inst.state.cycles)
                box:DestroyContents()
                local item = SpawnPrefab(master and "goldnugget" or "rocks")
                item.components.stackable:SetStackSize(master and 17 or 31)
                assert(box:GiveItem(item, 1))
                filled, phase = true, "baseline"
            end
        end
        if not master then return end
        if phase == "verified" and other and other.verified == verified then
            if verified == 4 then
                phase, started = "finaltrade", false
            else phase, started, count = "trade", false, 0 end
        elseif phase == "baseline" and other and other.filled and not saving then
            saving = true
            SaveGame(false, function() baseline = e.core.generation; phase, saving = "trade", false end)
        end
        if (phase == "trade" or phase == "finaltrade") and other and other.ready and other.generation == e.core.generation then
            if not started then
                beforeSaves = saves
                assert(service.protocol:Start("shadow", peer)); service:Wake(); started = true
            elseif not service.protocol.active and not other.active and signature(box) == "rocks:31" and other.signature == "goldnugget:17" then
                assert(saves == beforeSaves, "fast trade unexpectedly saved")
                print("[ROLLBACK_COPY] FAST_EXCHANGE_PASS", round)
                if phase == "finaltrade" then
                    print("[ROLLBACK_COPY] ALL_ROLLBACKS_PASS")
                    SendModRPCToShard(GetShardModRPC("SW_ROLLBACK_COPY", "stop"), peer)
                    inst:DoStaticTaskInTime(1, function() c_shutdown(false) end)
                    phase = "finished"
                else phase = "save" end
            end
        end
        if phase == "save" and other and other.ready and other.generation == e.core.generation and not saving then
            local steps = ({1, 1, 2, 4})[round]
            if count < steps then
                saving = true
                SaveGame(false, function() count = count + 1; saving = false end)
            else
                pending = DataDumper({round = round, steps = steps, baseline = baseline}, nil, true)
                TheSim:SetPersistentString(key, pending, false, function(ok) assert(ok ~= false); written = true end)
                phase = "prepare"
            end
        end
        if phase == "prepare" then
            SendModRPCToShard(GetShardModRPC("SW_ROLLBACK_COPY", "prepare"), peer, pending)
            if written and acknowledged == pending then
                phase = "rollback"
                local steps = ({1, 1, 2, 4})[round]
                print("[ROLLBACK_COPY] CALL_C_ROLLBACK", round, steps, TheNet:GetCurrentSnapshot())
                inst:DoStaticTaskInTime(.5, function() c_rollback(steps) end)
            end
        end
    end)
end)
