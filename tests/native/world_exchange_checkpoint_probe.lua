-- DESTRUCTIVE to this isolated fixture world only: exercises snapshot restoration.
-- Independent storage probe, NOT an automatic cluster recovery controller.
-- Requires two starts: after both READY_FOR_COLD_RESTART messages, terminate
-- both isolated server processes without a save, then start them again.
local Store = require("worldexchange_snapshot_probe")
local peers_ready = {}
local bootstrap
AddSimPostInit(function()
    if bootstrap then bootstrap() end
end)
AddShardModRPCHandler("SW_CHECKPOINT_PROBE", "ready", function(peer, phase, count)
    peers_ready[tostring(peer)] = {phase = phase, count = count}
end)
AddPrefabPostInit("world", function(inst)
    if not inst.ismastersim then return end
    assert(TheNet:GetServerName() == "ShadowWorld isolated exchange test",
        "checkpoint probe requires the disposable isolated test cluster")
    if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
    local uid = "KU_FullCheckpoint" .. TheShard:GetShardId()
    local store = Store.new({
        -- Only world files use this reader/writer. Players use the native
        -- session codec and are written at bootstrap below.
        read = function(path, callback) TheSim:GetPersistentString(path, callback) end,
        write = function(path, data, callback) TheSim:SetPersistentString(path, data, false, callback) end,
        encode = function(data) return DataDumper(data, nil, true) end,
    }, "sw_checkpoint_probe")
    local stage, count, manifest, snapshot, player, observed, userfile = "boot", 0
    local stagekey = "sw_checkpoint_probe_restore_stage"
    local userkey = "sw_checkpoint_probe_pinned_user"
    TheSim:GetPersistentString(stagekey, function(ok, data)
        stage = ok and data == "verify" and "verify" or "prepare"
    end)
    bootstrap = function()
        if stage ~= "verify" then return end
        local completed = false
        TheSim:GetPersistentString(userkey, function(ok, raw)
            assert(ok, "missing pinned user")
            local parsed, record = RunInSandboxSafe(raw)
            assert(parsed and type(record) == "table", "invalid pinned user")
            -- This hook runs before native RestoreSnapshotUserSession and
            -- IncrementSnapshot, while the loaded world cut is current.
            local worldfile = TheNet:GetWorldSessionFile(inst.meta.session_identifier)
            local target = tonumber(worldfile:match("/(%d+)$"))
            print("[CHECKPOINT_RESTORE] BOOTSTRAP_SNAPSHOT", target, TheNet:GetCurrentSnapshot())
            TheNet:SerializeUserSession(uid, raw, false, nil, DataDumper({character = record.prefab}, nil, true))
            local actual = TheNet:GetUserSessionFile(inst.meta.session_identifier, uid)
            assert(tonumber(actual:match("/(%d+)$")) == target, "bootstrap user restored to wrong cut")
            print("[CHECKPOINT_RESTORE] BOOTSTRAP_USER_WRITTEN", uid, actual)
            completed = true
        end)
        -- Research fixture only. A production implementation must gate the
        -- world loader, not assume that this API completes synchronously.
        assert(completed, "asynchronous loading requires a pre-world gate")
    end
    local function verify()
        assert(inst.components.persistent2hm.data.checkpoint_probe == "PINNED", "world state did not roll back")
        local path = TheNet:GetUserSessionFile(inst.meta.session_identifier, uid)
        assert(path, "missing restored player session")
        TheNet:DeserializeUserSession(path, function(ok, raw)
            assert(ok and raw, "native user loading failed after restart")
            local decoded, data = RunInSandboxSafe(raw)
            assert(decoded and data and data.data.inventory, "missing inventory")
            local items = data.data.inventory.items
            assert(items[1] and items[1].prefab == "goldnugget" and items[1].data.stackable.stack == 9, "restored inventory differs")
            for _, item in pairs(items) do assert(item.prefab ~= "axe", "crafted output survived material rollback") end
            print("[CHECKPOINT_RESTORE] VERIFIED_WORLD_AND_PLAYER", TheShard:GetShardId(), path)
            inst:DoStaticTaskInTime(3, function() c_shutdown(false) end)
        end)
    end
    inst:DoStaticPeriodicTask(.2, function()
        if stage == "verify" then stage = "verifying"; verify(); return end
        local service = inst.components.worldexchange2hm
        if not service or not service.protocol or not next(service.peers) then return end
        local peer = next(service.peers)
        if stage == "prepare" then
            stage = "initial_save"
            player = SpawnPrefab("wilson")
            player.userid = uid
            player.Transform:SetPosition(0, 0, 0)
            local gold = SpawnPrefab("goldnugget"); gold.components.stackable:SetStackSize(9)
            assert(player.components.inventory:GiveItem(gold))
            inst.components.persistent2hm.data.checkpoint_probe = "PINNED"
            local saved = service.OnSaved
            service.OnSaved = function(self, capture)
                saved(self, capture)
                if stage == "initial_save" then
                    stage = "pinning"
                    local sid = inst.meta.session_identifier
                    local worldfile = TheNet:GetWorldSessionFile(sid)
                    userfile = TheNet:GetUserSessionFile(sid, uid)
                    snapshot = tonumber(worldfile:match("/(%d+)$"))
                    store:Capture("cut", {worldfile, worldfile .. ".meta"}, function(result, reason)
                        assert(result, reason)
                        manifest = result
                        TheNet:DeserializeUserSession(userfile, function(ok, raw)
                            assert(ok, "cannot decode native user")
                            store:WriteVerified(userkey, raw, function(pinned)
                                assert(pinned, "cannot pin decoded user")
                                print("[CHECKPOINT_RESTORE] PINNED", TheShard:GetShardId(), snapshot)
                                player.components.inventory:DestroyContents()
                                assert(player.components.inventory:GiveItem(SpawnPrefab("axe")))
                                SerializeUserSession(player)
                                inst.components.persistent2hm.data.checkpoint_probe = "ADVANCED"
                                stage = "advance"
                                -- Standalone storage test: deliberately overwrite the
                                -- current files, without claiming to test coordination.
                                inst:DoStaticTaskInTime(2, function() SaveGame(false) end)
                            end)
                        end)
                    end)
                elseif stage == "advance" then
                    count = count + 1
                    print("[CHECKPOINT_RESTORE] ADVANCED_SAVE", TheShard:GetShardId(), count)
                    stage = "advanced"
                end
            end
        end
        SendModRPCToShard(GetShardModRPC("SW_CHECKPOINT_PROBE", "ready"), peer, stage, count)
        local remote = peers_ready[peer]
        if stage == "initial_save" then
            if TheShard:IsMaster() and remote and remote.phase == "initial_save" and not observed then
                observed = true
                inst:DoTaskInTime(1, function() inst:PushEvent("ms_save") end)
            end
        elseif stage == "advanced" and remote and remote.count >= 1 then
            stage = "removing_originals"
            local function erase(index)
                local record = manifest.files[index] or (index == 3 and {path = userfile}) or
                    (index == 4 and {path = userfile .. ".meta"})
                if record then
                    TheSim:ErasePersistentString(record.path, function()
                        TheSim:GetPersistentString(record.path, function(ok)
                            assert(not ok, "original snapshot file still exists")
                            erase(index + 1)
                        end)
                    end)
                else
                    print("[CHECKPOINT_RESTORE] ORIGINAL_FILES_REMOVED", 4)
                    TheSim:SetPersistentString(stagekey, "verify", false, function()
                        store:Restore(manifest, function(ok, reason)
                            assert(ok, reason)
                            TheNet:TruncateSnapshots(inst.meta.session_identifier, snapshot)
                            print("[CHECKPOINT_RESTORE] READY_FOR_COLD_RESTART", TheShard:GetShardId(), snapshot, "player pending bootstrap")
                            stage = "restored"
                        end)
                    end)
                end
            end
            erase(1)
        end
    end)
end)
