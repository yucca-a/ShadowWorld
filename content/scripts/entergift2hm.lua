return function(inst)
    local gifts = {}
    table.insert(gifts, "smallcandy2hm")
    table.insert(gifts, "smallcandy2hm")
    if TUNING.util2hm.world_level == -6 then
        table.insert(gifts, "boat_grass_item")
        table.insert(gifts, "oar_monkey")
    end
    if #gifts > 0 and inst.components.inventory then
        local gift = SpawnPrefab("gift")
        local oldFunc = gift.components.unwrappable.onwrappedfn
        if oldFunc then
            gift.components.unwrappable.onwrappedfn = function(inst, num, doer)
                num = 5
                return oldFunc(inst, num, doer)
            end
        end
        gift.components.unwrappable:WrapItems(gifts)
        inst:DoTaskInTime(0, function()
            inst.components.inventory:GiveItem(gift)
        end)
    end
    -- 2025.7.30 melon:季节礼物
    local function season_gift(inst)
        local cyc = TheWorld.state.cycles
        if cyc == nil or cyc > 210 then return end -- 前3年给
        cyc = cyc % 70
        local season_gifts = {}
        if cyc < 10 then
            -- 什么也不给
        elseif cyc < 30 then -- 10天~29天  牛帽+暖石
            table.insert(season_gifts, "beefalohat")
            table.insert(season_gifts, "heatrock")
            table.insert(season_gifts, "torch")
        elseif cyc < 40 then -- 30天~39天  牛帽+暖石+雨衣+火把
            table.insert(season_gifts, "beefalohat")
            table.insert(season_gifts, "heatrock")
            table.insert(season_gifts, "raincoat")
            table.insert(season_gifts, "torch")
        elseif cyc < 50 then
            table.insert(season_gifts, "raincoat")
            table.insert(season_gifts, "torch")
        elseif cyc < 67 then
            table.insert(season_gifts, "hawaiianshirt")
            table.insert(season_gifts, "heatrock")
        end
        if #season_gifts > 0 and inst.components.inventory then
            local gift = SpawnPrefab("gift")
            gift.components.unwrappable:WrapItems(season_gifts)
            inst.components.inventory:GiveItem(gift)
        end
    end
    inst:DoTaskInTime(0, season_gift)
end