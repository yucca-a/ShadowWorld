-- Install on both shards. The existing container buttons call this service.
AddPrefabPostInit("world", function(inst)
    if inst.ismastersim and not inst.components.worldexchange2hm then inst:AddComponent("worldexchange2hm") end
end)

AddShardModRPCHandler("MOD_HARDMODE", "worldexchange_v1", function(shard_id, ...)
    local service = TheWorld and TheWorld.components.worldexchange2hm
    if service then service:Packet(tostring(shard_id), ...) end
end)

-- Preserve the native synchronized snapshot mechanism and observe its completion.
-- OnSave captures the exact phase included in that particular snapshot.
local oldSaveGame = GLOBAL.SaveGame
GLOBAL.SaveGame = function(isshutdown, callback)
    local world = TheWorld
    local service = world and world.components.worldexchange2hm
    local capture = {}
    if service then service.savecapture = capture end
    local result = oldSaveGame(isshutdown, function(...)
        if service and world:IsValid() and world == TheWorld then service:OnSaved(capture) end
        if callback then callback(...) end
    end)
    if service then service.savecapture = nil end
    return result
end

local oldShardUpdate = GLOBAL.Shard_UpdateWorldState
GLOBAL.Shard_UpdateWorldState = function(world_id, state, ...)
    local result = oldShardUpdate(world_id, state, ...)
    local service = TheWorld and TheWorld.components.worldexchange2hm
    if service then service:Disconnected(tostring(world_id)) end
    return result
end

-- Vanilla read-only handling covers client inventory actions. These guards also
-- cover server-side sorting/collection code that calls container methods directly.
AddComponentPostInit("container", function(self)
    for _, method in ipairs({"GiveItem", "RemoveItem_Internal", "DestroyContents", "DestroyContentsConditionally", "DropEverything"}) do
        local original = self[method]
        if original then
            self[method] = function(container, ...)
                if container.worldexchange_locked2hm and not container.worldexchange_internal2hm then return end
                return original(container, ...)
            end
        end
    end
end)
