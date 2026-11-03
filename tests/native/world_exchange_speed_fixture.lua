-- Disposable isolated shards only. Replaces shadow-container contents, runs
-- three measured exchanges, and shuts down the servers. Never import in a player world.
local ready = {}
local saves = 0
local serializeWorld = GLOBAL.SerializeWorldSession
GLOBAL.SerializeWorldSession = function(...)
    saves = saves + 1
    return serializeWorld(...)
end
AddShardModRPCHandler("SW_EXCHANGE_TEST", "ready", function(id, round) ready[tostring(id)] = round end)
AddPrefabPostInit("goldnugget", function(inst)
    if TheWorld.ismastersim and not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
end)
AddPrefabPostInit("world", function(inst)
    if not inst.ismastersim then return end
    local round, filled, started, finished, installed = 1, false, false, false, false
    local ticks = 0
    local function check(ok, label) assert(ok, "EXCHANGE_SPEED failure: " .. label) end
    inst:DoStaticPeriodicTask(.1, function()
        ticks = ticks + 1
        if ticks > 2400 then print("[EXCHANGE_SPEED] TIMEOUT"); c_shutdown(false); return end
        local service = inst.components.worldexchange2hm
        local box = inst:GetPocketDimensionContainer("shadow")
        if not service or not service.protocol or not box then return end
        if service.engine and not service.engine.core:IsReady() then return end
        local master = TheShard:IsMaster()
        if not installed then
            installed = true
            local start, finish, apply, saved = service.protocol.Start, service.protocol.Finish, service.Apply, service.OnSaved
            service.protocol.Start = function(self, ...)
                local before = (GetStaticTime() * 1000)
                local ok, why = start(self, ...)
                if ok then self.benchstart, self.benchsaves = before, saves; print("[EXCHANGE_SPEED] START", round, before) end
                return ok, why
            end
            service.protocol.Finish = function(self, outcome)
                if self.benchstart then print("[EXCHANGE_SPEED] ELAPSED_MS", round, (GetStaticTime() * 1000) - self.benchstart, outcome) end
                if service.engine and self.benchstart then
                    check(saves == self.benchsaves, "no world save during fast exchange")
                    print("[EXCHANGE_SPEED] NO_WORLD_SAVE", round)
                end
                return finish(self, outcome)
            end
            service.Apply = function(self, ...)
                local before = (GetStaticTime() * 1000)
                local ok, why = apply(self, ...)
                print("[EXCHANGE_SPEED] APPLY_MS", round, (GetStaticTime() * 1000) - before)
                return ok, why
            end
            service.OnSaved = function(self, capture)
                print("[EXCHANGE_SPEED] CHECKPOINT", round, capture.marker and capture.marker.phase or "idle", (GetStaticTime() * 1000))
                return saved(self, capture)
            end
        end
        if not filled then
            check(not service.protocol.active, "previous transaction finished")
            filled = true
            local c = box.components.container
            c:DestroyContents()
            if master then
                local gold = SpawnPrefab("goldnugget")
                gold.components.stackable:SetStackSize(17)
                gold.components.persistent2hm.data.exchange_test_payload = string.rep("native-chunk-check-", 1800)
                check(c:GiveItem(gold, 1), "gold inserted")
                local spear = SpawnPrefab("spear"); spear.components.finiteuses:SetPercent(.42)
                check(c:GiveItem(spear, 3), "spear inserted")
            else
                local rocks = SpawnPrefab("rocks"); rocks.components.stackable:SetStackSize(31)
                check(c:GiveItem(rocks, 4), "rocks inserted")
                check(c:GiveItem(SpawnPrefab("berries"), 5), "berries inserted")
            end
        end
        local peer
        for id in pairs(service.peers) do peer = id; break end
        if peer and not finished then SendModRPCToShard(GetShardModRPC("SW_EXCHANGE_TEST", "ready"), peer, round) end
        if master and not started and peer and ready[peer] == round then
            check(service.protocol:Start("shadow", peer), "transaction started")
            if service.Wake then service:Wake() end -- Same fast path as the actual request button.
            started = true
        elseif not master and service.protocol.active then started = true end
        if started and not finished and not service.protocol.active then
            finished = true
            local slots = box.components.container.slots
            if master then
                check(slots[4] and slots[4].components.stackable:StackSize() == 31 and slots[5].prefab == "berries", "B items received")
                check(not slots[1] and not slots[3], "A originals removed")
            else
                check(slots[1] and slots[1].components.stackable:StackSize() == 17, "gold received")
                check(slots[1].components.persistent2hm.data.exchange_test_payload == string.rep("native-chunk-check-", 1800), "large record preserved")
                check(slots[3] and math.abs(slots[3].components.finiteuses:GetPercent() - .42) < .01, "durability preserved")
                check(not slots[4] and not slots[5], "B originals removed")
            end
            check(not box.components.container.readonlycontainer, "unlocked")
            print("[EXCHANGE_SPEED] ROUND_PASS", round, TheShard:GetShardId())
            if round == 3 then
                inst:DoStaticTaskInTime(3, function() c_shutdown(false) end)
            else
                inst:DoStaticTaskInTime(3, function()
                    round, filled, started, finished = round + 1, false, false, false
                end)
            end
        end
    end)
end)
