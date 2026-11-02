local autumn_change = GetModConfigData("autumn_change")

local function hasanotherworldid()
    if ShardList then
        for world_id, v in pairs(ShardList) do if world_id ~= TheShard:GetShardId() and Shard_IsWorldAvailable(world_id) then return true end end
    end
end

AddShardModRPCHandler("MOD_HARDMODE", "ms_setseason_autumn", function(...)
    TheWorld:PushEvent("ms_setseason", "autumn")
    for _, v in ipairs(AllPlayers) do
        if not v:HasTag("playerghost") and v.entity:IsVisible() and v.components.talker then
            v.components.talker:Say((TUNING.isCh2hm and "秋天来了!" or (STRINGS.UI.SANDBOXMENU.AUTUMN .. " is coming!")))
        end
    end
    if TheWorld.ismastershard then
        if autumn_change == -3 then TheWorld:PushEvent("ms_setmoonphase", {moonphase = "full"}) end
        TheWorld:PushEvent("delayrefreshseason2hm")
    end
end)

local function SetWorldAutumn()
    TheWorld:PushEvent("ms_setseason", "autumn")
    SendModRPCToShard(GetShardModRPC("MOD_HARDMODE", "ms_setseason_autumn"), nil)
    for _, v in ipairs(AllPlayers) do
        if not v:HasTag("playerghost") and v.entity:IsVisible() and v.components.talker then
            v.components.talker:Say((TUNING.isCh2hm and "秋天来了!" or (STRINGS.UI.SANDBOXMENU.AUTUMN .. " is coming!")))
        end
    end
    if TheWorld.ismastershard then
        if autumn_change == -3 then TheWorld:PushEvent("ms_setmoonphase", {moonphase = "full"}) end
        TheWorld:PushEvent("delayrefreshseason2hm")
    end
end

local GEM_SOCKET_MUST_TAGS = {"gemsocket", "archive_switch"}
local function removearchiveswitchgems(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 6, GEM_SOCKET_MUST_TAGS)

    for i = #ents, 1, -1 do
        local ent = ents[i]
        if ent.gem and ent.components.pickable and inst.components.pickable.onpickedfn then ent.components.pickable.onpickedfn(ent) end
    end
end

local function checkforgems(inst)
    if not hasanotherworldid() or TUNING.DSA_ONE_PLAYER_MODE then return end
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 6, GEM_SOCKET_MUST_TAGS)

    for i = #ents, 1, -1 do
        local ent = ents[i]
        if not ent.gem then table.remove(ents, i) end
    end

    local archive = TheWorld.components.archivemanager
    if archive and #ents >= 3 then
        if autumn_change == -1 then
            SetWorldAutumn()
        elseif autumn_change == -2 then
            if inst.components.pickable and inst.components.pickable.onpickedfn then
                inst.components.pickable.onpickedfn(inst)
                SetWorldAutumn()
            end
        elseif autumn_change == -3 then
            removearchiveswitchgems(inst)
            SetWorldAutumn()
        end
    end
end

AddPrefabPostInit("archive_switch", function(inst)
    if not TheWorld.ismastersim then return end
    inst:DoTaskInTime(1, function()
        local oldOnGemGiven = inst.components.trader.onaccept
        inst.components.trader.onaccept = function(...)
            oldOnGemGiven(...)
            if TheWorld.state.season ~= SEASONS.AUTUMN then checkforgems(inst) end
        end
    end)
end)

-- 2025.3.18 melon:给不了月台，先注释掉
-- 月泪有新鲜度了,且只能带身上
-- local function checkstatus(inst)
--     if inst.components.inventoryitem and not (inst.components.inventoryitem.owner and not inst.components.inventoryitem.owner:HasTag("player")) then
--         inst.components.inventoryitem.canonlygoinpocket = true
--         if inst.checkstatus2hm then
--             inst:RemoveEventCallback("onputininventory", checkstatus)
--             inst.checkstatus2hm = nil
--         end
--     else
--         inst:ListenForEvent("onputininventory", checkstatus)
--         inst.checkstatus2hm = true
--     end
-- end
AddPrefabPostInit("moon_tear", function(inst)
    inst:AddTag("show_spoilage")
    if not TheWorld.ismastersim then return end
    if not inst.components.perishable then
        inst:AddComponent("perishable")
        inst.components.perishable:SetPerishTime(TUNING.PERISH_ONE_DAY)
        inst.components.perishable:StartPerishing()
        inst.components.perishable.onperishreplacement = "moonrocknugget"
    end
    -- inst:DoTaskInTime(0, checkstatus)
end) -- 2025.4.10 melon end
