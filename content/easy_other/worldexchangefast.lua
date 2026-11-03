-- Install recovery before ShardIndex loads the world. All fast-world saves use
-- one paired checkpoint; the container protocol itself never asks for a save.
local Engine = require("worldexchangeengine2hm")
Engine.enabled = (GetModConfigData("Container Sort") or GetModConfigData("Items collect")) and true or false
local function engine()
    local service = TheWorld and TheWorld.ismastersim and TheWorld.components.worldexchange2hm
    if service then service:Initialize() end
    return service and not service.legacy and service.engine or nil
end

local getSaveData = GLOBAL.ShardIndex.GetSaveData
GLOBAL.ShardIndex.GetSaveData = function(index, callback)
    return getSaveData(index, function(data) Engine.Bootstrap(index, data, callback) end)
end
AddSimPostInit(Engine.RestorePlayers)

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
                if (service and service.legacy) or (Engine.boot and Engine.boot.legacy) or
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
    e:RegisterPlayer(player.userid, false, function()
        if player:IsValid() then newPlayer(guid, unpack(args)); e:Joined(player, false) end
    end)
end

-- Defer departures until their before-image is recorded on both worlds and no
-- checkpoint is being captured. Already-started migrations drain before saving.
AddPrefabPostInit("world", function(inst)
    if not inst.ismastersim then return end
    local push = inst.PushEvent
    inst.PushEvent = function(world, event, data, ...)
        local e = event == "ms_playerdespawnandmigrate" and engine() or nil
        if e and data and data.player and not data.player._despawning then
            local player = data.player
            if player.worldexchange_migration2hm then return end
            if not e.core:CanMigrate(player.userid) then
                player.worldexchange_migration2hm = true
                e:RegisterPlayer(player.userid)
                table.insert(e.actions, function()
                    player.worldexchange_migration2hm = nil
                    if player:IsValid() and not player._despawning then world:PushEvent(event, data) end
                end)
                return
            end
            player.worldexchange_departure2hm = e.core:Depart(player.userid)
        end
        return push(world, event, data, ...)
    end
end)
AddComponentPostInit("worldmigrator", function(component)
    local activate = component.Activate
    component.Activate = function(self, doer)
        local e = engine()
        if e and not e.core:IsReady() then return false, "NODESTINATION" end
        return activate(self, doer)
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
AddComponentPostInit("playercontroller", function(pc)
    local enable = pc.Enable
    pc.Enable = function(self, value)
        local e = engine()
        if value and e and e.holding then self.worldexchange_resume2hm = true; return end
        if value == false then self.worldexchange_resume2hm = nil end
        return enable(self, value)
    end
end)

-- Save before exit callbacks despawn players or stop the cave process. A host
-- currently visiting the caves asks its authoritative server via ModRPC.
local clientExit, exitSequence = {}, 0
AddModRPCHandler("MOD_HARDMODE", "worldexchange_exit", function(player, token)
    local client = player and player.userid and TheNet:GetClientTableForUser(player.userid)
    if not client or not client.admin or type(token) ~= "number" then return end
    local e = engine()
    if e then e:Exit(function() SendModRPCToClient(GetClientModRPC("MOD_HARDMODE", "worldexchange_exit"), player.userid, token) end) end
end)
AddClientModRPCHandler("MOD_HARDMODE", "worldexchange_exit", function(token)
    local callback = clientExit[token]
    if callback then clientExit[token] = nil; callback() end
end)
local function exitAfterCheckpoint(callback)
    local e = engine()
    if e then e:Exit(callback); return end
    if TheWorld and not TheWorld.ismastersim and TheNet:GetIsHosting() then
        exitSequence = exitSequence + 1
        clientExit[exitSequence] = callback
        SendModRPCToServer(GetModRPC("MOD_HARDMODE", "worldexchange_exit"), exitSequence)
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
