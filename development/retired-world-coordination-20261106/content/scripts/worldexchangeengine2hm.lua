local Store = require("worldexchangestore2hm")
local Checkpoint = require("worldexchangecheckpoint2hm")
local Instant = require("worldexchangeinstant2hm")
local Engine = {}
Engine.__index = Engine
Engine.discovered = {}
Engine.EXIT_TIMEOUT = 20

local function hasMultiplePeers(members)
    local count = 0
    for _ in pairs(members or {}) do
        count = count + 1
        if count > 2 then return true end
    end
    return false
end

function Engine.IO(index)
    local clustered = not TheNet:IsDedicated() and index:GetSlot() ~= nil and
        not index:GetServerData().use_legacy_session_path
    local slot, shard = index:GetSlot(), index:GetShard() or "Master"
    return {
        read = function(key, cb)
            if clustered then TheSim:GetPersistentStringInClusterSlot(slot, shard, key, cb)
            else TheSim:GetPersistentString(key, cb) end
        end,
        write = function(key, data, cb)
            if clustered then TheSim:SetPersistentStringInClusterSlot(slot, shard, key, data, false, cb)
            else TheSim:SetPersistentString(key, data, false, cb) end
        end,
        erase = function(key)
            if clustered then TheSim:SetPersistentStringInClusterSlot(slot, shard, key, "", false)
            else TheSim:ErasePersistentString(key) end
        end,
        encode = function(data) return DataDumper(data, nil, true) end,
        decode = RunInSandboxSafe,
    }
end

local function checkpointrecord(world)
    return world and world.map and world.map.persistdata and world.map.persistdata.worldexchange2hm
end

function Engine.ResolveCut(state, record)
    if not state.forced and not (record and record.checkpoint) then return nil, "older_save_has_no_checkpoint" end
    local selected = state.forced or record.checkpoint
    for _ = 1, 64 do
        local redirect = state.redirects and state.redirects[selected]
        if not redirect then break end
        selected = redirect
    end
    if not state.cuts[selected] and not state.forced then
        local serial = record.checkpoint_serial or tonumber(selected:match("/(%d+)$"))
        -- Native world serialization precedes immutable backup commit. A crash
        -- between them leaves a newer marker but no committed candidate: load
        -- the previous committed cut, then negotiate with the other shard.
        local current = state.current and state.cuts[state.current]
        if serial and (serial > (state.nextserial or 0) or (current and serial > current.serial)) then
            -- Older fast builds discarded future cuts without redirects but
            -- retained their physical files. Those newer abandoned markers also
            -- recover through the current committed ancestor, never forward.
            selected = state.current
        end
    end
    if not selected or not state.cuts[selected] then return nil, "selected_checkpoint_missing" end
    local current = state.current and state.cuts[state.current]
    return selected, nil, not state.forced and current and state.cuts[selected].serial < current.serial or false
end

function Engine.NativeFile(index, session)
    if not TheNet:IsDedicated() and index:GetSlot() ~= nil and not index:GetServerData().use_legacy_session_path then
        return TheNet:GetWorldSessionFileInClusterSlot(index:GetSlot(), index:GetShard() or "Master", session)
    end
    return TheNet:GetWorldSessionFile(session)
end

function Engine.NewRebase(snapshot, session)
    return {snapshot = snapshot, origin = session,
        token = session .. "/native/" .. snapshot .. "/" .. os.time() .. "/" .. math.random(1, 1073741823)}
end

function Engine.Bootstrap(index, native, callback)
    if require("shadowvaultconfig2hm").ActiveSave(native) then
        Engine.boot = {native_only = true, ready = true}
        callback(native)
        return
    end
    if not TheNet:GetIsServer() then callback(native); return end
    local session = native and native.meta and native.meta.session_identifier or index:GetSession()
    if not session or session == "" then callback(native); return end
    local store = Store.new(Engine.IO(index), session)
    store:Load(function(state, reason)
        assert(state, "WorldExchange checkpoint journal: " .. tostring(reason))
        assert(native or not next(state.cuts), "WorldExchange: native world/index is missing; keep the swx2 backups for recovery, do not generate a replacement world")
        local record = checkpointrecord(native)
        Engine.boot = {store = store, session = session, ready = true,
            legacy = record and record.version == 1 and record.active ~= nil}
        local file = Engine.NativeFile(index, session)
        Engine.boot.native_snapshot = file and tonumber(file:match("/(%d+)$"))
        -- A power loss can occur after the new timeline is committed but before
        -- its native truncation/reload. Resume that same decision; an empty new
        -- journal is not permission to load the abandoned newer world.
        local rebase = state.rebase
        local pendingRebase = rebase and state.rebase_applied ~= rebase.token and not next(state.cuts)
        local function finishRebase(data)
            store:MarkRebaseApplied(rebase.token, function(ok, failure)
                assert(ok, "WorldExchange native rollback: " .. tostring(failure))
                callback(data)
            end)
        end
        if pendingRebase and ((record and record.checkpoint) or
            (Engine.boot.native_snapshot and Engine.boot.native_snapshot > rebase.snapshot)) then
            local target = file and file:gsub("/%d+$", "/" .. string.format("%010d", rebase.snapshot))
            assert(target, "WorldExchange: pending native rollback snapshot unavailable")
            store.io.read(target, function(found, raw)
                local parsed, data = false, nil
                if found and raw then parsed, data = RunInSandboxSafe(raw) end
                local saved = parsed and type(data) == "table" and checkpointrecord(data)
                if not found and native and not (record and (record.checkpoint or record.active)) and
                    Engine.boot.native_snapshot and Engine.boot.native_snapshot > rebase.snapshot then
                    -- Old builds left rebase markers behind even after native
                    -- saves advanced. With no old target, keep the native
                    -- save and suspend coordination rather than mixing eras.
                    Engine.boot.native_only = true
                    print("[WorldExchange2hm] Old rollback target missing; opening the native save with coordinated exchange suspended.",
                        rebase.snapshot, Engine.boot.native_snapshot)
                    callback(native)
                    return
                end
                assert(parsed and type(data) == "table" and data.meta and data.meta.session_identifier == session and
                    not (saved and saved.checkpoint), "WorldExchange: pending native rollback target unavailable")
                TheNet:TruncateSnapshots(session, rebase.snapshot)
                Engine.boot.native_snapshot = rebase.snapshot
                Engine.boot.legacy = saved and saved.version == 1 and saved.active ~= nil
                print("[WorldExchange2hm] Resume native rollback", rebase.snapshot)
                finishRebase(data)
            end)
            return
        end
        if pendingRebase and native and Engine.boot.native_snapshot == rebase.snapshot then
            finishRebase(native)
            return
        end
        local firstcut
        local current = state.current and state.cuts[state.current]
        if (hasMultiplePeers(state.members) or hasMultiplePeers(current and current.members)) and
            next(state.cuts) and not state.forced and not (record and record.checkpoint) then
            -- Snapshot numbers belong to each shard. A pre-coordination
            -- native rollback can only recover to a verified shared cut.
            for id, cut in pairs(state.cuts) do
                if not firstcut or cut.serial < state.cuts[firstcut].serial then firstcut = id end
            end
            record = {checkpoint = firstcut}
        end
        if next(state.cuts) and not state.forced and not (record and record.checkpoint) then
            assert(Engine.boot.native_snapshot, "WorldExchange: native rollback snapshot unavailable")
            if TheShard:IsMaster() then
                rebase = Engine.NewRebase(Engine.boot.native_snapshot, session)
                store:RebaseNative(rebase, function(ok, failure)
                    assert(ok, "WorldExchange native rollback: " .. tostring(failure))
                    Engine.boot.rebasing = true
                    print("[WorldExchange2hm] Native rollback before fast mode", rebase.snapshot)
                    finishRebase(native)
                end)
            else
                Engine.boot.rollback_request = Engine.boot.native_snapshot
                callback(native)
            end
            return
        end
        if not next(state.cuts) then
            assert(not record or record.version ~= 2 or not record.checkpoint, "WorldExchange checkpoint backup is missing")
            callback(native); return
        end
        local selected, selection_error, manual = Engine.ResolveCut(state, record)
        assert(selected, "WorldExchange: " .. tostring(selection_error))
        store:ReadCut(selected, function(raw, failure, cut)
            assert(raw, "WorldExchange checkpoint: " .. tostring(failure))
            local ok, data = RunInSandboxSafe(raw)
            assert(ok and type(data) == "table" and data.meta and data.meta.session_identifier == session,
                "WorldExchange: checkpoint world does not match its session")
            local saved = checkpointrecord(data)
            assert(saved and saved.checkpoint == selected and not saved.active, "WorldExchange: checkpoint contains an unfinished exchange")
            for uid, player in pairs(cut.players) do
                assert(type(uid) == "string" and #uid > 0 and #uid <= 100, "WorldExchange: invalid player identifier")
                if player ~= false then
                    local valid, info = RunInSandboxSafe(player)
                    assert(valid and type(info) == "table" and type(info.prefab) == "string", "WorldExchange: invalid player backup")
                end
            end
            Engine.boot.loaded, Engine.boot.players, Engine.boot.ready = selected, cut.players, false
            Engine.boot.requested = (manual or firstcut) and selected or nil
            Engine.boot.legacy = false
            -- All asynchronous reads are complete before the world loader runs.
            -- Native snapshot counters remain local; the common cut uses its own ID.
            callback(data)
        end)
    end)
end

function Engine.RestorePlayers()
    local boot = Engine.boot
    if not boot or not boot.players or not TheWorld or not TheWorld.ismastersim then return end
    -- Vanilla does this just after SimPostInit. Do it before writes as well:
    -- GetUserSessionFile otherwise finds newer, uncommitted player profiles.
    TheNet:TruncateSnapshots(boot.session)
    local pending, failed = 1, false
    local function done(ok)
        if not ok then failed = true end
        pending = pending - 1
        if pending == 0 then
            boot.ready = not failed
            if not failed then boot.players = nil end -- Verified profiles need not stay pinned for the whole server session.
            if failed then boot.error = "player_restore_verification_failed"; print("[WorldExchange2hm]", boot.error) end
        end
    end
    for uid, raw in pairs(boot.players) do
        if raw == false then
            TheNet:DeleteUserSession(uid)
            local file = TheNet:GetUserSessionFile(boot.session, uid)
            if file then
                pending = pending + 1
                TheNet:DeserializeUserSession(file, function(ok, restored)
                    local valid, data = false, nil
                    if ok and type(restored) == "string" and #restored > 0 then valid, data = RunInSandboxSafe(restored) end
                    -- Native deletion may retain a tombstone file. Its existence
                    -- alone does not mean that a playable profile survived.
                    done(not ok or restored == nil or restored == "" or (valid and (type(data) ~= "table" or data.prefab == nil)))
                end)
            end
        else
            local _, data = RunInSandboxSafe(raw)
            local file = TheNet:GetUserSessionFile(boot.session, uid)
            pending = pending + 1
            local function restore()
                -- This runs before native RestoreSnapshotUserSession. The Lua
                -- record now carries MapExplorer data as well (see player hook).
                TheNet:SerializeUserSession(uid, raw, false, nil, DataDumper({character = data.prefab}, nil, true))
                local restoredfile = TheNet:GetUserSessionFile(boot.session, uid)
                if not restoredfile then done(false); return end
                TheNet:DeserializeUserSession(restoredfile, function(ok, restored) done(ok and restored == raw) end)
            end
            if file then
                TheNet:DeserializeUserSession(file, function(ok, current)
                    -- Do not replace a matching native session with a write
                    -- lacking its classified entity: native map data lives
                    -- outside the Lua inventory record and must be retained.
                    if ok and current == raw then done(true) else restore() end
                end)
            else restore() end
        end
    end
    done(true)
end

function Engine.AssembleWorld(sections)
    local out = {"local savedata = {}\n"}
    for key, raw in pairs(sections) do
        if key == "ents" then
            table.insert(out, "savedata.ents = {}\n")
            for prefab, value in pairs(raw) do
                table.insert(out, "savedata.ents[" .. string.format("%q", prefab) .. "] = (function() ")
                table.insert(out, value)
                table.insert(out, " end)()\n")
            end
        else
            assert(type(raw) == "string", "unsupported native save section")
            table.insert(out, "savedata[" .. string.format("%q", key) .. "] = (function() ")
            table.insert(out, raw)
            table.insert(out, " end)()\n")
        end
    end
    table.insert(out, "return savedata")
    return table.concat(out)
end

function Engine.Attach(service)
    if service.engine or service.engine_loading then return end
    service.engine_loading = true
    local boot = Engine.boot
    if boot and boot.session ~= service.session then boot = nil end
    local store = boot and boot.session == service.session and boot.store or Store.new(Engine.IO(ShardGameIndex), service.session)
    local function attach()
        store.io.defer = function(callback) service.inst:DoStaticTaskInTime(0, callback) end
        local self = setmetatable({service = service, store = store, revisions = {}, actions = {}}, Engine)
        service.engine, service.engine_loading = self, nil
        self.core = Checkpoint.new({
            id = service.id, boot = service.boot, master = TheShard:IsMaster(),
            masterid = tostring(SHARDID.MASTER),
            now = function() return service:Now() end,
            bootready = function() return self:CanAdvance() and (not boot or boot.ready) end,
            connected = function(peer, epoch)
                local p = service.peers[peer]
                return p and p.boot == epoch and p.fast == 2 and self:CanAdvance() and
                    p.timeline == store.state.timeline and Shard_IsWorldAvailable(peer) and
                    p.lastseen and service:Now() - p.lastseen < 15
            end,
            migrationready = function(peer, generation)
                local info = service.peers[peer]
                return info and info.migration_generation == generation
            end,
            encode = function(message) return DataDumper(message, nil, true) end,
            send = function(peer, message, encoded) service:Send(peer, message, encoded) end,
            wake = function() service:Wake() end,
            idle = function() return self:Idle() end,
            log = function(message) print("[WorldExchange2hm]", message) end,
            save = function(cut, owners) self:Capture(cut, owners) end,
            restart = function() self:RestartToCut(store.state.forced) end,
        }, store, boot and boot.loaded, boot and boot.requested)
        for peer in pairs(ShardList or {}) do Engine.discovered[tostring(peer)] = true end
        for peer in pairs(Engine.discovered) do self.core:Discover(peer) end
        if boot and boot.error then self.core:Fail(boot.error) end
        service.legacy = service.protocol.active ~= nil and (service.saved_version or 1) == 1
        self.rollback_request = boot and boot.rollback_request
        self.timeline_wait = (store.state.rebase ~= nil and not (boot and boot.loaded)) or self.rollback_request ~= nil
        if not service.legacy then self:UseFastProtocol() end
        for peer, info in pairs(service.peers) do self:PeerHello(peer, info) end
        service.nexthello = 0
        service:Wake()
    end
    if store.state then attach()
    else store:Load(function(state, reason)
        assert(state and not next(state.cuts), "WorldExchange requires its pre-world recovery loader: " .. tostring(reason))
        attach()
    end) end
end

function Engine:CanAdvance() return not self.restarting and not self.timeline_wait and not self.rollback_request end

function Engine:Rollback(callback)
    if self.rollback_callback or self.restarting then return end
    self.restarting = true
    self.rollback_callback = callback
    self.service:Wake()
end

function Engine:BeforeRollbackRestart(callback)
    local file = Engine.NativeFile(ShardGameIndex, self.service.session)
    if not file then callback(); return end
    self.store.io.read(file, function(found, raw)
        local parsed, world = false, nil
        if found and raw then parsed, world = RunInSandboxSafe(raw) end
        local record = parsed and checkpointrecord(world)
        local id = record and record.checkpoint and Engine.ResolveCut(self.store.state, record)
        local cut, sent = id and self.store.state.cuts[id], false
        if cut then
            for peer, info in pairs(self.service.peers) do
                if info.fast == 2 and info.timeline == self.store.state.timeline and Shard_IsWorldAvailable(peer) then
                    self.service:Send(peer, {v=3, kind="CHECKPOINT", op="ROLLBACK_HINT", id=id, serial=cut.serial})
                    sent = true
                end
            end
        end
        if sent then
            print("[WorldExchange2hm] Preload rollback checkpoint", id)
            self.service:Flush()
            self.exits = self.exits or {}
            table.insert(self.exits, {at=self.service:Now() + .1, callback=callback})
        else callback() end
    end)
end

function Engine:Restart()
    self.restarting = true
    StartNextInstance({reset_action = RESET_ACTION.LOAD_SLOT, save_slot = ShardGameIndex:GetSlot(), save_shard = ShardGameIndex:GetShard()})
end

function Engine:RestartToCut(id)
    self.restarting = true
    if self:Writing() then self.pending_cut = id; return end
    self.store:ReadCut(id, function(raw, failure, cut)
        if not raw then self.core:Fail(failure); return end
        local parsed, world = RunInSandboxSafe(raw)
        if not parsed or type(world) ~= "table" then self.core:Fail("native_checkpoint_invalid"); return end
        local persist = world.world_network and world.world_network.persistdata or {}
        local metadata = DataDumper({clock = persist.clock, seasons = persist.seasons}, nil, true)
        local file = Engine.NativeFile(ShardGameIndex, self.service.session)
        local current = file and tonumber(file:match("/(%d+)$"))
        if not current then self.core:Fail("native_snapshot_missing"); return end
        local function write(snapshot)
            local target = file:gsub("/%d+$", "/" .. string.format("%010d", snapshot))
            self.store:Write(target, raw, function(ok)
                if not ok then self.core:Fail("native_checkpoint_restore_failed"); return end
                self.store:Write(target .. ".meta", metadata, function(saved)
                    if not saved then self.core:Fail("native_checkpoint_metadata_failed"); return end
                    TheNet:TruncateSnapshots(self.service.session, snapshot)
                    self:Restart()
                end)
            end)
        end
        if cut.native_snapshot then write(cut.native_snapshot); return end
        -- Compatibility with checkpoints made before native index tracking.
        local function find(snapshot)
            if snapshot < math.max(1, current - 32) then write(current); return end
            self.store.io.read(file:gsub("/%d+$", "/" .. string.format("%010d", snapshot)), function(ok, text)
                local parsed, data = false, nil
                if ok and text then parsed, data = RunInSandboxSafe(text) end
                local record = parsed and checkpointrecord(data)
                if record and record.checkpoint == id then write(snapshot) else find(snapshot - 1) end
            end)
        end
        find(current)
    end)
end

function Engine:RebaseNative(rebase)
    if self.restarting then return end
    if type(rebase) ~= "table" or type(rebase.snapshot) ~= "number" or rebase.snapshot < 1 or
        rebase.snapshot % 1 ~= 0 or type(rebase.token) ~= "string" or #rebase.token > 200 then return end
    self.restarting = true
    self.pending_rebase = rebase
    self:ContinueRebase()
end

function Engine:Writing()
    return self.capture ~= nil or self.store.busy or (self.store.pending or 0) > 0 or #self.store.queue > 0
end

function Engine:ContinueRebase()
    if self:Writing() then return end
    local rebase = self.pending_rebase
    self.pending_rebase = nil
    local file = Engine.NativeFile(ShardGameIndex, self.service.session)
    if not file then self.core:Fail("native_rollback_missing"); return end
    local target = file:gsub("/%d+$", "/" .. string.format("%010d", rebase.snapshot))
    self.store.io.read(target, function(ok, raw)
        local parsed, data = false, nil
        if ok and raw then parsed, data = RunInSandboxSafe(raw) end
        local record = parsed and checkpointrecord(data)
        if not parsed or not data.meta or data.meta.session_identifier ~= self.service.session or
            (record and record.checkpoint) then self.core:Fail("native_rollback_target_unavailable"); return end
        self.store:RebaseNative(rebase, function(saved, reason)
            if not saved then self.core:Fail(reason); return end
            print("[WorldExchange2hm] Align native rollback", rebase.snapshot)
            TheNet:TruncateSnapshots(self.service.session, rebase.snapshot)
            self:Restart()
        end)
    end)
end

function Engine:PeerHello(peer, info)
    if self.restarting or info.fast ~= 2 then return end
    if not hasMultiplePeers(self.core.members) then
        if TheShard:IsMaster() and type(info.rollback_request) == "number" and not self.rollback_request then
            self:RebaseNative(Engine.NewRebase(info.rollback_request, self.service.session)); return
        end
        if not TheShard:IsMaster() and peer == tostring(SHARDID and SHARDID.MASTER or "1") and
            info.timeline ~= self.store.state.timeline and info.rebase then
            self:RebaseNative(info.rebase); return
        end
    end
    if info.timeline ~= self.store.state.timeline or self.rollback_request then return end
    self.timeline_wait = nil
    self.core:Connected(peer, info.boot)
end

function Engine:UseFastProtocol()
    local service = self.service
    assert(not service.protocol.active, "cannot convert a running legacy exchange")
    service.protocol = Instant.new(service.protocol.io, service.protocol:Save(), self.core)
    service.legacy = false
    if Engine.boot and Engine.boot.session == service.session then Engine.boot.legacy = false end
end

function Engine:Idle()
    if self.service.protocol.active or self:Writing() then return false end
    -- A world switched to traditional exchange can still need paired recovery
    -- for its older fast checkpoints. Never capture the traditional protocol's
    -- temporary empty containers before it completes or restores them.
    for _, container in pairs(self.service.inst.PocketDimensionContainers or {}) do
        if container.containersendtask2hm or container.containerreceivetask2hm or container.exchangeconfirmtask2hm then return false end
    end
    for _, player in ipairs(AllPlayers) do if player._despawning then return false end end
    local native = self.service.inst.components.shardtransactionsteps
    if native then
        for _, transactions in pairs(native.transactions) do
            for _, transaction in pairs(transactions) do
                if type(transaction) == "table" and transaction.status and transaction.status < SHARDTRANSACTIONSTEPS.FINALIZED then return false end
            end
        end
    end
    return true
end

function Engine:ReadPlayer(uid, callback)
    local path = TheNet:GetUserSessionFile(self.service.session, uid)
    if not path then callback(false); return end
    TheNet:DeserializeUserSession(path, function(ok, raw)
        if ok and (raw == nil or raw == "") then callback(false); return end
        if not ok then self.core:Fail("player_read_failed"); return end
        local parsed, data = RunInSandboxSafe(raw)
        if parsed and type(data) == "table" and next(data) == nil then callback(false); return end
        if not parsed or type(data) ~= "table" or type(data.prefab) ~= "string" then self.core:Fail("invalid_player_session"); return end
        callback(raw)
    end)
end

function Engine:RegisterPlayer(uid, baseline, callback)
    if self.store.state.registry[uid] then if callback then callback(true) end; return end
    if baseline ~= nil then self.core:Register(uid, self.service.id, baseline, callback)
    else self:ReadPlayer(uid, function(raw) self.core:Register(uid, self.service.id, raw, callback) end) end
end

function Engine:PlayerWrite(uid, raw, isnew, player, metadata, deleting)
    self.revisions[uid] = (self.revisions[uid] or 0) + 1
    if self.capture and not self.capture.serialized then
        self.capture.players[uid] = not deleting and raw or false
        self.capture.owners[uid] = self.service.id
    end
    self:RegisterPlayer(uid, nil, function()
        if self.restarting then return end
        if deleting then TheNet:DeleteUserSession(uid)
        else
            local entity = player and player:IsValid() and player.player_classified and player.player_classified.entity or nil
            TheNet:SerializeUserSession(uid, raw, isnew, entity, metadata)
        end
    end)
end

function Engine:Joined(player, baseline, migration)
    local uid = player.userid
    if not uid or #uid == 0 then return end
    self:RegisterPlayer(uid, baseline, function()
        if not player:IsValid() then return end
        self.core.owners[uid] = self.service.id
        self.core:Arrived(uid, migration and migration.worldexchange_token2hm, migration and tostring(migration.worldid))
    end)
end

function Engine:Capture(cut, owners)
    local snapshot = {id = cut.id, serial = cut.serial, players = {}, owners = Store.Copy(owners),
        native_snapshot = TheNet:GetCurrentSnapshot()}
    self.capture = snapshot
    local uids, position = {}, 0
    for uid in pairs(owners) do table.insert(uids, uid) end
    local function nextplayer()
        position = position + 1
        local uid = uids[position]
        if uid then
            if owners[uid] ~= self.service.id then snapshot.players[uid] = false; nextplayer()
            else
                local revision = self.revisions[uid]
                self:ReadPlayer(uid, function(raw)
                    -- PlayerWrite already updates this in-flight snapshot. Do
                    -- not keep another full profile/map for every user who has
                    -- ever logged in just to handle this short read/write race.
                    if revision == self.revisions[uid] then snapshot.players[uid] = raw end
                    nextplayer()
                end)
            end
            return
        end
        -- Lua serialization is synchronous. Capture the exact player records
        -- written by that SaveGame call and the complete serialized world.
        Engine.nativeSave(false, function()
            self.capture = nil
            if not snapshot.raw then self.core:Fail("world_capture_missing"); return end
            local raw = snapshot.raw; snapshot.raw = nil
            self.core:Saved(snapshot, raw)
        end)
    end
    nextplayer()
end

function Engine:WorldSerialized(data)
    if self.capture then
        -- No later player/logout write is allowed to mutate this completed cut.
        self.capture.raw = Engine.AssembleWorld(data)
        self.capture.players = Store.Copy(self.capture.players)
        self.capture.serialized = true
    end
end

function Engine:CanSaveLocally()
    local core = self.core
    return core.phase == "joining" and not core.generation and not next(self.store.state.cuts)
        and not core:AllPeers(core.io.connected)
end

function Engine:SaveRequested(shutdown, callback)
    if shutdown and self.exit_saved and not self.core.generation and not next(self.store.state.cuts) and not self:Writing() then
        Engine.nativeSave(shutdown, callback)
    elseif self.core.exitready or (shutdown and (self.exit_saved or self.core.generation)) then
        -- Normal exits checkpoint BEFORE OnDespawn. A native shutdown callback
        -- is too late to capture a new coherent pair and must not save it again.
        -- Unplanned termination recovers the existing immutable common cut.
        if callback then callback() end
    elseif self.restarting then return
    elseif self:CanSaveLocally() then
        Engine.nativeSave(shutdown, callback)
    else self.core:Request(callback, shutdown) end
end

function Engine:Exit(callback)
    if self:CanSaveLocally() then callback(); return end
    local completed = false
    local function finish()
        if completed then return end
        completed = true
        self.exit_saved = true
        -- Let ACTIVE leave each secondary before it exits. Keep the master
        -- alive longer so it cannot pause those shards before they shut down.
        local grace = self.core.io and self.core.io.master and 1.5 or .5
        self.exits = self.exits or {}
        table.insert(self.exits, {at = self.service:Now() + grace, callback = callback, shutdown = true})
    end
    if self.exit_saved or self.core.exitready then finish(); return end
    self.exit_waiting = self.exit_waiting or {}
    table.insert(self.exit_waiting, finish)
    self.exit_deadline = self.exit_deadline or (self.service:Now() + Engine.EXIT_TIMEOUT)
    self.core:Request(finish, true)
end

function Engine:PeerDisconnected()
    if not self.core.suspended or (self.core.io and self.core.io.master) then return end
    -- A secondary can stop getting updates as soon as the master disconnects.
    -- Finish the requested shutdown from the disconnect event itself.
    if self.exit_waiting then
        local waiting = self.exit_waiting
        self.exit_waiting, self.exit_deadline = nil, nil
        if not self.exit_saved then
            print("[WorldExchange2hm] Peer disconnected during exit; retaining the last committed save.")
        end
        for _, finish in ipairs(waiting) do finish() end
    end
    for i = self.exits and #self.exits or 0, 1, -1 do
        if self.exits[i].shutdown then
            local callback = table.remove(self.exits, i).callback
            callback()
        end
    end
end

function Engine:Update()
    if self.exit_waiting and #self.exit_waiting > 0 then
        local core = self.core
        local unavailable = (core.suspended and not (core.phase == "activating" and core:AwaitingExitActivation())) or
            (core.phase == "joining" and core.generation and not core:AllPeers(core.io.connected))
        if self.exit_saved then
            self.exit_waiting, self.exit_deadline = nil, nil
        elseif self.service:Now() >= self.exit_deadline or
            ((unavailable or core.phase == "error" or self.restarting) and not self:Writing()) then
            print("[WorldExchange2hm] Exiting without another common checkpoint; retaining the last committed save.")
            local waiting = self.exit_waiting
            self.exit_waiting, self.exit_deadline = nil, nil
            for _, finish in ipairs(waiting) do finish() end
        end
    end
    if self.rollback_callback and not self:Writing() then
        local callback = self.rollback_callback; self.rollback_callback = nil
        callback()
        return
    end
    if self.pending_rebase then self:ContinueRebase() end
    if self.pending_cut and not self:Writing() then
        local id = self.pending_cut; self.pending_cut = nil
        self:RestartToCut(id)
    end
    if self.exits then
        for n = #self.exits, 1, -1 do
            if self.service:Now() >= self.exits[n].at then
                local callback = table.remove(self.exits, n).callback
                callback()
            end
        end
    end
    if self.exit_saved then return end
    if Engine.boot and Engine.boot.session == self.service.session and Engine.boot.error then self.core:Fail(Engine.boot.error); return end
    if not self:CanAdvance() then return end
    if self.service.legacy then
        if not self.service.protocol.active then self:UseFastProtocol() else return end
    end
    for _, player in ipairs(AllPlayers) do
        local uid = player.userid
        if uid and #uid > 0 and not self.store.state.registry[uid] and not self.core.registrations[uid] then
            self:RegisterPlayer(uid)
        end
    end
    self.core:Tick()
    if self.core:IsReady() then
        local waiting = self.actions; self.actions = {}
        for _, action in ipairs(waiting) do action() end
    end
end

return Engine
