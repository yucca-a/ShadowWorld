-- Install recovery before ShardIndex loads the world. All fast-world saves use
-- one shared checkpoint; the container protocol itself never asks for a save.
local Engine = require("worldexchangeengine2hm")
local mode = GetModConfigData("World Exchange")
-- The old coordinator is loaded only to finish recovery of existing saves.
Engine.enabled = false
-- Hosted vaults recover their own journal only. Do not install the retired
-- coordinator's world/player restore, migration, autosaver or exit hooks.
if mode == "hosted" then
    Engine.boot = {native_only=true, ready=true}
    return
end
local function engine()
    local service = TheWorld and TheWorld.ismastersim and TheWorld.components.worldexchange2hm
    if service and service.vault_retiring then return end
    if service then service:Initialize() end
    return service and not service.legacy and service.engine or nil
end

local getSaveData = GLOBAL.ShardIndex.GetSaveData
GLOBAL.ShardIndex.GetSaveData = function(index, callback)
    return getSaveData(index, function(data) Engine.Bootstrap(index, data, callback) end)
end
AddSimPostInit(Engine.RestorePlayers)
AddPlayerPostInit(function(inst)
    if TheWorld.ismastersim and (Engine.enabled or (Engine.boot and Engine.boot.loaded)) then
        require("worldexchangemaps2hm").Install(inst)
    end
end)

-- Preserve vanilla's exact rollback-count/truncation rules. Intercept only the
-- restart it requests, after native selection, to tell peers its target.
local rollback, nextInstance = GLOBAL.WorldRollbackFromSim, GLOBAL.StartNextInstance
local rolling
GLOBAL.WorldRollbackFromSim = function(count)
    local e = engine()
    if not e then return rollback(count) end
    return e:Rollback(function()
        rolling = e
        rollback(count)
        rolling = nil
    end)
end
GLOBAL.StartNextInstance = function(params)
    if rolling then
        local e = rolling; rolling = nil
        return e:BeforeRollbackRestart(function() nextInstance(params) end)
    end
    return nextInstance(params)
end

Engine.nativeSave = GLOBAL.SaveGame
GLOBAL.SaveGame = function(shutdown, callback)
    local e = engine()
    if e then return e:SaveRequested(shutdown, callback) end
    return Engine.nativeSave(shutdown, callback)
end
local serializeWorld = GLOBAL.SerializeWorldSession
GLOBAL.SerializeWorldSession = function(data, session, callback, metadata)
    local e = engine()
    if e then e:WorldSerialized(data) end
    return serializeWorld(data, session, callback, metadata)
end

-- Native secondary snapshot numbers are local physical file counters. Fast
-- recovery compares immutable common IDs instead, including after a rollback.
AddComponentPostInit("autosaver", function(component)
    if not TheWorld.ismastersim or TheShard:IsMaster() then return end
    local inst = component.inst
    local listeners = TheWorld.event_listeners.secondary_autosaverupdate
    local callbacks = listeners and listeners[inst]
    if callbacks then
        local originals = {}; for _, callback in ipairs(callbacks) do table.insert(originals, callback) end
        for _, original in ipairs(originals) do
            inst:RemoveEventCallback("secondary_autosaverupdate", original, TheWorld)
            inst:ListenForEvent("secondary_autosaverupdate", function(source, data)
                local service = TheWorld.components.worldexchange2hm
                if (service and service.legacy) or (Engine.boot and (Engine.boot.legacy or Engine.boot.native_only)) or
                    (not Engine.enabled and not (Engine.boot and Engine.boot.loaded)) then original(source, data)
                else TheShard:SetSecondaryLoading(false) end
            end, TheWorld)
        end
    end
end)

local serializePlayer, deletePlayer = GLOBAL.SerializeUserSession, GLOBAL.DeleteUserSession
GLOBAL.SerializeUserSession = function(player, isnew)
    local e = engine()
    if not e or not player or not player.userid or #player.userid == 0 then return serializePlayer(player, isnew) end
    -- Same native serialization/metadata contract. Never wrap native user bytes
    -- in the persistent-string codec used for world backups.
    local record = player:GetSaveRecord()
    if record.data and record.data.migration and player.worldexchange_departure2hm then
        record.data.migration.worldexchange_token2hm = player.worldexchange_departure2hm
    end
    local raw = DataDumper(record, nil, BRANCH ~= "dev")
    local metadata = DataDumper({character = player.prefab}, nil, BRANCH ~= "dev")
    e:PlayerWrite(player.userid, raw, isnew == true, player, metadata)
end
GLOBAL.DeleteUserSession = function(player)
    local e = engine()
    if not e or not player or not player.userid or #player.userid == 0 then return deletePlayer(player) end
    e:PlayerWrite(player.userid, false, false, nil, nil, true)
end

local resume = GLOBAL.ResumeExistingUserSession
GLOBAL.ResumeExistingUserSession = function(data, guid)
    local e, player = engine(), Ents[guid]
    -- Preserve the before-image before Resume can materialize inventory in the
    -- world. Joining can be synchronous; native profile writes remain gated.
    if e and player and player.userid then e:RegisterPlayer(player.userid, DataDumper(data, nil, true)) end
    local result = resume(data, guid)
    if e and player then e:Joined(player, DataDumper(data, nil, true), data.data and data.data.migration) end
    return result
end
local newPlayer = GLOBAL.SpawnNewPlayerOnServerFromSim
GLOBAL.SpawnNewPlayerOnServerFromSim = function(guid, ...)
    local e, player = engine(), Ents[guid]
    if not e or not player or not player.userid then return newPlayer(guid, ...) end
    local args = {...}
    -- Native spawn only waits for the local before-image to be durable.
    e:RegisterPlayer(player.userid, false, function()
        if player:IsValid() then newPlayer(guid, unpack(args)); e:Joined(player, false) end
    end)
end

local MIGRATION_TIMEOUT = 20
local function reportMigrationWait(e, uid, destination)
    local core = e.core
    print("[WorldExchange2hm] Native migration wait ended", e.service.id, destination, core.phase, core.error,
        "suspended", core.suspended, "registering", core.registrations[uid] ~= nil,
        "departing", core.outbound[uid] ~= nil, "arriving", core.inbound[uid] ~= nil)
    e.service:Notify(uid, "checkpoint_pending")
end
-- Accept the native portal action. If the final departure has to wait, retain
-- its destination while the player is still nearby, with a bounded retry.
AddPrefabPostInit("world", function(inst)
    if not inst.ismastersim then return end
    local push = inst.PushEvent
    inst.PushEvent = function(world, event, data, ...)
        local e = event == "ms_playerdespawnandmigrate" and engine() or nil
        if e and data and data.player and data.player.userid and not data.player._despawning then
            local player = data.player
            local destination = data.worldid and tostring(data.worldid)
            if player.worldexchange_migration2hm then return end
            if not e.core:CanMigrate(player.userid, destination) then
                local x, y, z = player.Transform:GetWorldPosition()
                local deadline = e.service:Now() + MIGRATION_TIMEOUT
                e:RegisterPlayer(player.userid)
                e.service:Notify(player.userid, "saving")
                local task
                task = player:DoStaticPeriodicTask(.1, function()
                    local moved = player:GetDistanceSqToPoint(x, y, z) > 16
                    local cancel = moved or player._despawning
                    local unavailable = e.service:Now() >= deadline or not Shard_IsWorldAvailable(data.worldid) or
                        e.core.phase == "error" or e.core.exiting or e.exit_saved
                    if not (cancel or unavailable or e.core:CanMigrate(player.userid, destination)) then return end
                    task:Cancel()
                    player.worldexchange_migration2hm = nil
                    if cancel then return end
                    if unavailable then reportMigrationWait(e, player.userid, destination)
                    else world:PushEvent(event, data) end
                end)
                player.worldexchange_migration2hm = task
                return
            end
            local uid = player.userid
            local token = e.core:Depart(uid)
            player.worldexchange_departure2hm = token
            local result = push(world, event, data, ...)
            -- Mods can refuse the event before the native spawner begins its
            -- despawn. That request will never generate an arrival.
            if not player._despawning and e.core.outbound[uid] == token then
                e.core.outbound[uid] = nil
                player.worldexchange_departure2hm = nil
            end
            return result
        end
        return push(world, event, data, ...)
    end
end)
AddComponentPostInit("worldmigrator", function(component)
    local activate = component.Activate
    component.Activate = function(self, doer)
        local e = engine()
        if e and (not doer or not doer:HasTag("player")) and not e.core:IsReady() then
            return false, "NODESTINATION"
        end
        return activate(self, doer)
    end
end)
AddComponentPostInit("worthyportal", function(component)
    -- Island Adventures only attempts migration once per voyage. Keep the
    -- portal enabled until that attempt can run or the voyage is cancelled.
    local finish, cancel = component.FinishVoyage, component.CancelVoyage
    local retry
    local function stopRetry()
        if retry then retry:Cancel(); retry = nil end
    end
    component.CancelVoyage = function(self, voyager)
        if retry and self.voyager == voyager then
            stopRetry()
            self.inst.components.worldmigrator:SetEnabled(false)
        end
        return cancel(self, voyager)
    end
    component.FinishVoyage = function(self, voyager)
        if retry then return end
        local e = engine()
        if not e or not voyager or not voyager.userid or self.voyager ~= voyager then return finish(self, voyager) end
        local migrator = self.inst.components.worldmigrator
        local destination = migrator.linkedWorld
        local destinationId = destination and tostring(destination)
        if e.core:CanMigrate(voyager.userid, destinationId) then return finish(self, voyager) end
        local deadline = e.service:Now() + MIGRATION_TIMEOUT
        local extendedState
        e:RegisterPlayer(voyager.userid)
        e.service:Notify(voyager.userid, "saving")
        retry = self.inst:DoStaticPeriodicTask(.1, function()
            local remaining = deadline - e.service:Now()
            local sg = voyager.sg
            local inVoyage = sg and sg.statemem.portal == self.inst
            if self.voyager ~= voyager or not voyager:IsValid() or voyager._despawning then
                stopRetry()
                if self.voyager == voyager then migrator:SetEnabled(false) end
            elseif extendedState and not inVoyage then
                self:CancelVoyage(voyager)
            elseif remaining <= 0 or migrator.linkedWorld ~= destination or
                not destination or not Shard_IsWorldAvailable(destination) or e.core.phase == "error" or
                e.core.exiting or e.exit_saved then
                self:CancelVoyage(voyager)
                if inVoyage and sg.statemem.portal == self.inst and sg.timeout then sg:SetTimeout(.1) end
                reportMigrationWait(e, voyager.userid, destinationId)
            elseif e.core:CanMigrate(voyager.userid, destinationId) then
                stopRetry()
                finish(self, voyager)
            elseif inVoyage and sg.timeout and extendedState ~= sg.currentstate then
                -- The stock animation aborts after ten seconds, even though
                -- a healthy four-shard checkpoint can take longer.
                extendedState = sg.currentstate
                sg:SetTimeout(math.max(sg.timeout, remaining + .5))
            end
        end)
    end
end)
local transferItem = GLOBAL.Shard_CreateTransaction_TransferInventoryItem
GLOBAL.Shard_CreateTransaction_TransferInventoryItem = function(shard, item, data)
    local e = engine()
    if e and not e.core:IsReady() then
        if item.worldexchange_migration2hm then return end
        item.worldexchange_migration2hm = true
        table.insert(e.actions, function()
            item.worldexchange_migration2hm = nil
            if item:IsValid() then transferItem(shard, item, data) end
        end)
        return
    end
    return transferItem(shard, item, data)
end
-- Save before exit callbacks despawn players or stop hosted shards. In the
-- character lobby the network user exists before their player entity does.
local clientExit, exitSequence = nil, 0
AddModRPCHandler("MOD_HARDMODE", "worldexchange_exit", function(userid, token)
    if type(userid) ~= "string" or type(token) ~= "number" then return end
    local client = TheNet:GetClientTableForUser(userid)
    if not client then return end
    local function acknowledge() SendModRPCToClient(GetClientModRPC("MOD_HARDMODE", "worldexchange_exit"), userid, token) end
    local vault = TheWorld and TheWorld.components.shadowvault2hm
    local e = client.admin and (engine() or (vault and vault.snapshot))
    if e then e:Exit(acknowledge) else acknowledge() end
end)
GLOBAL.MarkUserIDRPC("MOD_HARDMODE", "worldexchange_exit")
local function finishClientExit(token)
    local pending = clientExit
    if not pending or pending.token ~= token then return end
    clientExit = nil
    if pending.timeout then pending.timeout:Cancel() end
    pending.callback()
end
AddClientModRPCHandler("MOD_HARDMODE", "worldexchange_exit", finishClientExit)
local function exitAfterCheckpoint(callback)
    local e = engine()
    if e then e:Exit(callback); return end
    if TheWorld and not TheWorld.ismastersim and TheNet:GetIsHosting() then
        if clientExit then return end
        exitSequence = exitSequence + 1
        local token = exitSequence
        clientExit = {token = token, callback = callback,
            timeout = TheGlobalInstance:DoStaticTaskInTime(Engine.EXIT_TIMEOUT + 2, function() finishClientExit(token) end)}
        SendModRPCToServer(GetModRPC("MOD_HARDMODE", "worldexchange_exit"), token)
        return
    end
    callback()
end
local restart, shutdown = GLOBAL.DoRestart, GLOBAL.RequestShutdown
GLOBAL.DoRestart = function(save)
    if save then return exitAfterCheckpoint(function() restart(save) end) end
    return restart(save)
end
GLOBAL.RequestShutdown = function() return exitAfterCheckpoint(shutdown) end
AddSimPostInit(function()
    local consoleShutdown = GLOBAL.c_shutdown
    GLOBAL.c_shutdown = function(save)
        if save ~= false and TheWorld and TheWorld.ismastersim then
            return exitAfterCheckpoint(function() consoleShutdown(save) end)
        end
        return consoleShutdown(save)
    end
end)
