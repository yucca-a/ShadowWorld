-- OnPlayerLeave
if GLOBAL.OnPlayerLeave then
    local oldOnPlayerLeave = GLOBAL.OnPlayerLeave
    GLOBAL.OnPlayerLeave = function(player_guid, expected)
        TheWorld.leavetask2hm = TheWorld.leavetask2hm or {}
        if TheWorld.ismastersim and player_guid ~= nil and not TheWorld.leavetask2hm[player_guid] then
            local player = Ents[player_guid]
            if player ~= nil and player:IsValid() and player.components.hunger then player.components.hunger:Pause() end
            TheWorld.leavetask2hm[player_guid] = TheWorld:DoStaticTaskInTime(15, function()
                TheWorld.leavetask2hm[player_guid] = nil
                oldOnPlayerLeave(player_guid, expected)
            end)
        end
    end
end
