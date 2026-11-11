-- Runs only on the disposable cluster created by the native stress runner.
GLOBAL.setmetatable(env, {__index = function(_, key) return GLOBAL.rawget(GLOBAL, key) end})
local count = GetModConfigData("shards")
local mode = GetModConfigData("mode")
local total = GetModConfigData("rounds")
local dropOpen = GetModConfigData("drop_open")
local recover = GetModConfigData("recover")
local shutdown = GetModConfigData("shutdown")
local id = tostring(TheShard:GetShardId())
local master = tostring(SHARDID.MASTER)
local reports, box, player, started = {}, nil, nil, false
local recoveryKey = "exchange_stress_recovery_v1"
local armRequest
local savecount = 0
local nativeSerialize = GLOBAL.SerializeWorldSession
GLOBAL.SerializeWorldSession = function(...)
    savecount = savecount + 1
    return nativeSerialize(...)
end

local function signature(container)
    local parts = {}
    for slot = 1, container.numslots do
        local item = container.slots[slot]
        if item then
            local c = item.components
            local wrapped = c.unwrappable and c.unwrappable.itemdata and c.unwrappable.itemdata[1]
            local nestedStack = wrapped and wrapped.data and wrapped.data.stackable
            parts[#parts + 1] = slot .. ":" .. item.prefab .. ":" .. (c.stackable and c.stackable:StackSize() or 1)
                .. ":" .. (c.finiteuses and c.finiteuses:GetUses() or "")
                .. ":" .. (wrapped and wrapped.prefab .. ":" .. (nestedStack and nestedStack.stack or 1) or "")
        end
    end
    return table.concat(parts, "|")
end

local function fill(container)
    container:DestroyContents()
    local n = assert(tonumber(id))
    for slot = 1, container.numslots do
        local item = SpawnPrefab(slot == 2 and "bundle" or slot == 3 and "axe" or slot % 2 == 0 and "rocks" or "goldnugget")
        local c = item.components
        if c.stackable then c.stackable:SetStackSize(n + slot) end
        if c.finiteuses then c.finiteuses:SetUses(10 + n) end
        if c.unwrappable then
            local nested = SpawnPrefab("twigs")
            nested.components.stackable:SetStackSize(n + 5)
            c.unwrappable:WrapItems({nested})
            nested:Remove()
        end
        assert(container:GiveItem(item, slot), "fixture cannot place " .. item.prefab .. " in slot " .. slot)
    end
end

local function click()
    box.components.container.openlist[player] = true
    local rpc = GetModRPC("MOD_HARDMODE", "exchangebtn2hm")
    MOD_RPC_HANDLERS[rpc.namespace][rpc.id](player, box)
end

AddShardModRPCHandler("SW_EXCHANGE_STRESS", "report", function(peer, raw)
    local ok, data = RunInSandboxSafe(raw)
    if ok then reports[tostring(peer)] = data end
end)
AddShardModRPCHandler("SW_EXCHANGE_STRESS", "click", function(peer)
    if tostring(peer) == master and started then click() end
end)
AddShardModRPCHandler("SW_EXCHANGE_STRESS", "arm", function(peer, before, after)
    if tostring(peer) == master then armRequest = {before = before, after = after} end
end)

AddPrefabPostInit("world", function(world)
    if not world.ismastersim then return end
    assert(TheNet:GetServerName() == "ShadowWorld isolated exchange stress")
    local recovery, firstItems, recoveryObserved, removedPeer
    world:DoStaticTaskInTime(3, function()
        box = assert(world:GetPocketDimensionContainer("shadow"))
        player = SpawnPrefab("wilson")
        player.userid = "KU_ExchangeStress" .. id
        player:AddComponent("playercontroller")
        player.Transform:SetPosition(world.components.playerspawner:GetAnySpawnPoint())
        player.components.health:SetInvincible(true)
        box.components.container.openlist[player] = true
        world:PushEvent("ms_setautosaveenabled", false)
        TheSim:GetPersistentString(recoveryKey, function(found, raw)
            if found then
                local ok, data = RunInSandboxSafe(raw)
                assert(ok and type(data) == "table")
                recovery = data
            else
                fill(box.components.container)
                firstItems = signature(box.components.container)
            end
            started = true
        end)
    end)
    local expected, startedAt, earliest, source, round, initial = {}, nil, 0, nil, 0, false
    local faultInstalled, dropped, firstCut, baselineRequested, previousCut
    local preStressCut, recoverySaved
    local pairsCovered = {}
    world:DoStaticPeriodicTask(.15, function()
        if not started then return end
        local service = world.components.worldexchange2hm
        local core = service and service.engine and service.engine.core
        local current = {items = signature(box.components.container), saves = savecount,
            idle = not box:HasTag("exchangeloading2hm") and not (service and service.protocol.active),
            ready = mode == "traditional" or core and core:IsReady(), cut = core and core.generation}
        if recovery then
            if current.ready and not recoveryObserved then
                recoveryObserved = true
                assert(player.components.playercontroller:IsEnabled(), "player input remains enabled")
                if current.cut == recovery.after then
                    assert(current.items == recovery.afterItems, "reloaded box must match the saved exchange")
                    print("[EXCHANGE_STRESS] REJOINED", id, current.cut)
                else
                    assert(current.cut == recovery.before, "rollback restored the wrong checkpoint")
                    assert(current.items == recovery.beforeItems,
                        "rollback items: expected " .. recovery.beforeItems .. ", got " .. current.items)
                    print("[EXCHANGE_STRESS] ROLLED_BACK", id, current.cut)
                end
            elseif current.cut == recovery.after and recoveryObserved and id ~= tostring(count) and
                not removedPeer and not Shard_IsWorldAvailable(tostring(count)) then
                removedPeer = true
                recoveryObserved = false
                if id == master then
                    assert(not core:IsReady() and not service.protocol.active, "offline shard must block exchanges")
                    assert(player.components.playercontroller:IsEnabled(), "offline shard must not lock player input")
                    click()
                    assert(not service.protocol.active and current.items == recovery.afterItems and
                        signature(box.components.container) == current.items, "offline click cannot move cargo")
                    print("[EXCHANGE_STRESS] OFFLINE_HELD", id)
                end
            end
            return
        end
        if armRequest and current.ready and current.cut == armRequest.after then
            recovery, armRequest = armRequest, nil
            recovery.beforeItems, recovery.afterItems = firstItems, current.items
            recoveryObserved = true
            TheSim:SetPersistentString(recoveryKey, DataDumper(recovery, nil, true), false, function(ok)
                assert(ok ~= false)
                print("[EXCHANGE_STRESS] ARMED", id, current.cut)
            end)
            return
        end
        if id ~= master then
            SendModRPCToShard(GetShardModRPC("SW_EXCHANGE_STRESS", "report"), master, DataDumper(current, nil, true))
            return
        end
        reports[id] = current
        if (dropOpen or shutdown) and core and not faultInstalled then
            faultInstalled = true
            local send, open = core.io.send, core.Open
            core.io.send = function(peer, packet, encoded)
                if shutdown and core.exiting and packet.op == "OPEN" and peer == tostring(math.max(2, count - 1)) then
                    print("[EXCHANGE_STRESS] DROPPED_SHUTDOWN_OPEN", packet.id, peer)
                    return
                end
                if dropOpen and baselineRequested and packet.op == "OPEN" and packet.id ~= previousCut and
                    peer == tostring(count) and not dropped then
                    dropped = true
                    print("[EXCHANGE_STRESS] DROPPED_OPEN", packet.id, peer)
                    return
                end
                send(peer, packet, encoded)
            end
            core.Open = function(self)
                open(self)
                if dropped and not firstCut then
                    firstCut = self.generation
                    self:Request()
                end
            end
        end
        for n = 1, count do
            local peer = tostring(n)
            if not (reports[peer] and reports[peer].ready and Shard_IsWorldAvailable(peer)) then return end
        end
        if not initial then
            if mode == "coordinated" then
                if not baselineRequested then
                    -- All fixtures have populated their boxes. A checkpoint
                    -- taken during startup may predate a slower shard's fill.
                    baselineRequested, previousCut = true, current.cut
                    SaveGame(false)
                    return
                end
                if not current.cut or current.cut == previousCut then return end
            end
            if dropOpen and (not firstCut or current.cut == firstCut) then return end
            for peer, report in pairs(reports) do
                if report.cut ~= current.cut then return end
                expected[peer] = {items = report.items, saves = report.saves}
            end
            if dropOpen then print("[EXCHANGE_STRESS] OVERLAP_PASS", firstCut, current.cut) end
            assert(#current.items > 100)
            preStressCut = current.cut
            initial, startedAt = true, nil
            print("[EXCHANGE_STRESS] READY", mode, count, current.cut)
        end
        local now = GetStaticTime()
        if startedAt then
            assert(now - startedAt < 15, "exchange timed out: " .. round .. " source " .. source)
            local changed = {}
            for peer, report in pairs(reports) do
                if not report.idle then return end
                assert(report.saves == expected[peer].saves, "unexpected world save")
                if report.items ~= expected[peer].items then changed[#changed + 1] = peer end
            end
            if #changed == 0 then return end
            if #changed == 1 then return end -- Reports can arrive a tick apart.
            assert(#changed == 2, "only two worlds may change")
            local a, b = changed[1], changed[2]
            assert(a == source or b == source, "the requesting world must participate")
            assert(reports[a].items == expected[b].items and reports[b].items == expected[a].items, "whole-box contents must be conserved")
            expected[a].items, expected[b].items = reports[a].items, reports[b].items
            pairsCovered[a < b and a .. "-" .. b or b .. "-" .. a] = true
            print("[EXCHANGE_STRESS] ROUND", round, a, b, now - startedAt)
            startedAt, earliest = nil, now + .3
            if round == total then
                local coverage = 0
                for _ in pairs(pairsCovered) do coverage = coverage + 1 end
                assert(coverage == count * (count - 1) / 2, "every pair must exchange")
                print("[EXCHANGE_STRESS] PASS", mode, count, round, coverage)
                if recover then SaveGame(false, function() recoverySaved = true end) end
            end
        elseif recover and recoverySaved and current.cut ~= preStressCut then
            for peer, report in pairs(reports) do
                if report.cut ~= current.cut or report.items ~= expected[peer].items then return end
            end
            recoverySaved = false
            armRequest = {before = preStressCut, after = current.cut}
            SendModRPCToShard(GetShardModRPC("SW_EXCHANGE_STRESS", "arm"), nil, preStressCut, current.cut)
        elseif round < total and now >= earliest then
            source = tostring(round % count + 1)
            round, startedAt = round + 1, now
            if source == master then click()
            else SendModRPCToShard(GetShardModRPC("SW_EXCHANGE_STRESS", "click"), source) end
        end
    end)
end)
