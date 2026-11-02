-- AddClassPostConstruct("screens/chatinputscreen", function(self)
--     local oldRun = self.Run
--     function self:Run()
--         -- local chat_string = self.chat_edit:GetString()
--         local player = ThePlayer
--         if player and player._held_cursed_item:value() > 0 then
--             -- print("say", player.held_cursed_item)
--             self.chat_edit:SetString(CraftGiberish())
--         end
--         oldRun(self)
--     end
-- end)

AddComponentPostInit("talker", function(self)
    local oldSay = self.Say
    function self:Say(script, time, noanim, force, nobroadcast, colour, text_filter_context, original_author_netid, onfinishedlinesfn, sgparam)
        if not original_author_netid and self.inst:HasTag("player") and self.inst._held_cursed_item:value() > 0 then
            local lines = type(script) == "string" and { Line(script, noanim, time) } or script
            for _, line in pairs(lines) do
                line.message = CraftGiberish()
            end
            oldSay(self, lines, time, noanim, force, nobroadcast, colour, text_filter_context, original_author_netid, onfinishedlinesfn, sgparam)
        else
            oldSay(self, script, time, noanim, force, nobroadcast, colour, text_filter_context, original_author_netid, onfinishedlinesfn, sgparam)
        end
    end
end)

local oldNetworking_Say = GLOBAL.Networking_Say
GLOBAL.Networking_Say = function(guid, userid, name, prefab, message, colour, whisper, isemote, user_vanity)
    -- print(guid, userid, name, prefab, message)
    local entity = Ents[guid]
    if entity and entity:HasTag("player") and entity._held_cursed_item:value() > 0 then
        message = CraftGiberish()
    end
    oldNetworking_Say(guid, userid, name, prefab, message, colour, whisper, isemote, user_vanity)
end

local function re_check(inst)
    local held_cursed_item = 0
    if inst.components.inventory then
        for _, v in pairs(inst.components.inventory.itemslots) do
            if v:HasTag("curse2hm") or v:HasTag("cursed") then
                held_cursed_item = held_cursed_item + 1
                -- print("找到", count, held_cursed_item)
            end
        end
        for _, v in pairs(inst.components.inventory.equipslots) do
            if v:HasTag("curse2hm") or v:HasTag("cursed") then
                held_cursed_item = held_cursed_item + 1
                -- print("找到", count, held_cursed_item)
            end
        end
    end
    inst._held_cursed_item:set(held_cursed_item)
end

local function OnItemGet(inst, data)
    -- print("OnItemGet")
    if data then
        if data.item and (data.item:HasTag("curse2hm") or data.item:HasTag("cursed")) then
            inst._held_cursed_item:set(inst._held_cursed_item:value() + 1)
            -- print("增加物品 " .. (inst._held_cursed_item:value()))
        end
    end
end

local function OnItemlose(inst, data)
    -- print("OnItemlose")
    if data then
        local item = data.prev_item or data.item
        if item and (item:HasTag("curse2hm") or item:HasTag("cursed")) then
            inst._held_cursed_item:set(inst._held_cursed_item:value() - 1)
            -- print("减少物品 " .. (inst._held_cursed_item:value()))
        end
        if inst._held_cursed_item:value() <= 0 then
            inst:DoTaskInTime(0, function()
                re_check(inst)
            end)
        end
    end
end

AddPlayerPostInit(function(inst)
    inst._held_cursed_item = net_byte(inst.GUID, "player._held_cursed_item")
    if not TheWorld.ismastersim then return end
    inst:WatchWorldState("cycles", re_check)
    inst:DoTaskInTime(1, function()
        re_check(inst)
    end)
    inst:ListenForEvent("itemget", OnItemGet)
    inst:ListenForEvent("equip", OnItemGet)
    inst:ListenForEvent("itemlose", OnItemlose)
    inst:ListenForEvent("unequip", OnItemlose)
end)