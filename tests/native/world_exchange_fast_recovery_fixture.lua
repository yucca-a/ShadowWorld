-- Destructive isolated-cluster test. Never import in a player world.
local remote = {}
AddShardModRPCHandler("SW_FAST_RECOVERY", "stage", function(peer, stage) remote[tostring(peer)] = stage end)
AddPrefabPostInit("world", function(inst)
    if not inst.ismastersim then return end
    assert(TheNet:GetServerName() == "ShadowWorld isolated exchange test", "isolated test cluster required")
    if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
    local uid, lateuid = "KU_FastRecovery" .. TheShard:GetShardId(), "KU_FastLate" .. TheShard:GetShardId()
    local stage, mode, player, late, pinned, started, observed = "boot", "crash"
    TheSim:GetPersistentString("sw_fast_recovery_stage", function(ok, raw) stage = ok and raw == "verify" and "verify" or "prepare" end)
    TheSim:GetPersistentString("sw_fast_recovery_mode", function(ok, raw) if ok then mode = raw end end)
    local function check(ok, label) assert(ok, "FAST_RECOVERY: " .. label) end
    local function makeplayer(id, prefab, amount)
        local p = SpawnPrefab("wilson"); p.userid = id; p.Transform:SetPosition(0, 0, 0)
        local item = SpawnPrefab(prefab)
        if item.components.stackable then item.components.stackable:SetStackSize(amount or 1) end
        check(p.components.inventory:GiveItem(item), "give player item")
        return p
    end
    local ticks = 0
    inst:DoStaticPeriodicTask(.2, function()
        ticks = ticks + 1
        if ticks > 1500 then print("[FAST_RECOVERY] TIMEOUT", stage); c_shutdown(false); return end
        local service = inst.components.worldexchange2hm
        local e = service and service.engine
        if e and mode == "savecrash" and not e.test_savecrash then
            e.test_savecrash = true
            local put = e.store.PutCut
            e.store.PutCut = function(store, cut, raw, callback)
                if not TheShard:IsMaster() and inst.components.persistent2hm.data.fast_recovery_marker == "ADVANCED" then
                    print("[FAST_RECOVERY] NATIVE_SAVED_WITHOUT_COMMITTED_BACKUP", TheShard:GetShardId(), cut.id)
                    return
                end
                return put(store, cut, raw, callback)
            end
        end
        if e and mode == "exit" and stage == "armed" and remote[e.core.peer] == "armed" and not observed then
            observed = true
            print("[FAST_RECOVERY] NORMAL_EXIT", TheShard:GetShardId())
            c_shutdown()
            return
        end
        if not e or not e.core:IsReady() then return end
        local peer, master = e.core.peer, TheShard:IsMaster()
        local box = inst:GetPocketDimensionContainer("shadow").components.container
        if stage == "verify" then
            stage = "verifying"
            check(inst.components.persistent2hm.data.fast_recovery_marker == (mode == "exit" and "ADVANCED" or "PINNED"), "world marker")
            if mode ~= "exit" then
                local item = box.slots[1]
                check(item and item.prefab == (master and "goldnugget" or "rocks"), "container restored before exchange")
                check(item.components.stackable:StackSize() == (master and 17 or 31), "container count")
            end
            local path = TheNet:GetUserSessionFile(inst.meta.session_identifier, uid)
            check(path, "restored player file")
            TheNet:DeserializeUserSession(path, function(ok, raw)
                check(ok, "native player decode")
                local parsed, data = RunInSandboxSafe(raw)
                check(parsed and data.data.inventory, "native player inventory")
                local items = data.data.inventory.items
                if mode == "exit" then
                    local axes = 0
                    for _, item in pairs(items) do if item.prefab == "axe" then axes = axes + 1 end end
                    check(axes == 1, "normal exit preserves changed inventory")
                else
                    check(items[1] and items[1].prefab == "goldnugget" and items[1].data.stackable.stack == 9, "player before-image restored")
                    for _, item in pairs(items) do check(item.prefab ~= "axe", "crafted item rolled back with ingredients") end
                    local latepath = TheNet:GetUserSessionFile(inst.meta.session_identifier, lateuid)
                    if latepath then TheNet:DeserializeUserSession(latepath, function(found, lateraw)
                        local good, record = RunInSandboxSafe(lateraw or "")
                        check(not found or not lateraw or lateraw == "" or (good and (type(record) ~= "table" or not record.prefab)), "new player tombstone restored")
                    end) end
                end
                print("[FAST_RECOVERY] VERIFIED", TheShard:GetShardId(), mode, e.core.generation)
                inst:DoStaticTaskInTime(8, function() c_shutdown(false) end)
            end)
            return
        elseif stage == "prepare" then
            stage = "registering"
            box:DestroyContents()
            local item = SpawnPrefab(master and "goldnugget" or "rocks")
            item.components.stackable:SetStackSize(master and 17 or 31); check(box:GiveItem(item, 1), "fill container")
            player = makeplayer(uid, "goldnugget", 9)
            e:Joined(player, false)
            SerializeUserSession(player)
            inst.components.persistent2hm.data.fast_recovery_marker = "PINNED"
        elseif stage == "registering" and not e.core.regbusy and not e.store.busy and not next(e.core.inbound) then
            stage = "prepared"; pinned = e.core.generation
        elseif stage == "prepared" and master and remote[peer] == "prepared" then
            stage = "cut_wait"; e.core:Request()
        elseif (stage == "prepared" or stage == "cut_wait") and e.core.generation ~= pinned then stage = "cut_ready"
        elseif stage == "cut_ready" and master and remote[peer] == "cut_ready" then
            check(service.protocol:Start("shadow", peer), "fast exchange started"); service:Wake(); stage = "exchange"; started = true
        elseif stage == "cut_ready" and service.protocol.active then stage = "exchange"; started = true
        elseif stage == "exchange" and started and not service.protocol.active then
            -- Simulate taking transferred items, consuming ingredients/crafting,
            -- and overwriting the native player profile after the common cut.
            box:DestroyContents()
            local inventory = player.components.inventory
            for slot = 1, inventory.maxslots do
                local item = inventory.itemslots[slot]
                if item then inventory:RemoveItem(item, true):Remove() end
            end
            check(player.components.inventory:GiveItem(SpawnPrefab("axe")), "craft output")
            SerializeUserSession(player)
            late = makeplayer(lateuid, "goldnugget", 17)
            e:Joined(late, false); SerializeUserSession(late)
            inst.components.persistent2hm.data.fast_recovery_marker = "ADVANCED"
            stage = "mutated"
        elseif stage == "mutated" and not e.core.regbusy and not e.store.busy and not next(e.core.inbound) then
            stage = "armed"
            TheSim:SetPersistentString("sw_fast_recovery_stage", "verify", false, function(ok) check(ok ~= false, "stage write") end)
        elseif stage == "armed" and remote[peer] == "armed" and not observed then
            observed = true
            if mode == "savecrash" then
                if master then e.core:Request() end
            elseif mode == "exit" then
                print("[FAST_RECOVERY] NORMAL_EXIT", TheShard:GetShardId())
                c_shutdown()
            else print("[FAST_RECOVERY] READY_KILL_CAVES_ONLY", TheShard:GetShardId(), e.core.generation) end
        end
        if peer then SendModRPCToShard(GetShardModRPC("SW_FAST_RECOVERY", "stage"), peer, stage) end
    end)
end)
