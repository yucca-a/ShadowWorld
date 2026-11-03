-- Native user-session serialization includes MapExplorer data through the
-- classified entity. Checkpoint Lua backups also need an explicit map record.
local M = {}
function M.Install(inst)
    local save, load = inst.OnSave, inst.OnLoad
    inst.OnSave = function(player, data, ...)
        local refs = save and save(player, data, ...)
        local classified = player.player_classified
        if player.worldexchange_pendingmaps2hm then
            data.worldexchange_maps2hm = player.worldexchange_pendingmaps2hm
        elseif classified and classified.MapExplorer then
            data.worldexchange_maps2hm = classified.MapExplorer:RecordAllMaps()
        end
        return refs
    end
    inst.OnLoad = function(player, data, ...)
        local result = load and load(player, data, ...)
        if data and data.worldexchange_maps2hm then
            local maps = data.worldexchange_maps2hm
            player.worldexchange_pendingmaps2hm = maps
            -- Native session deserialization finishes after OnLoad returns.
            -- Merge only recorded exploration, never reveal new terrain.
            player:DoStaticTaskInTime(0, function()
                local classified = player:IsValid() and player.player_classified
                if classified and classified.MapExplorer then
                    classified.MapExplorer:LearnAllMaps(maps)
                    player.worldexchange_pendingmaps2hm = nil
                end
            end)
        end
        return result
    end
end
return M
