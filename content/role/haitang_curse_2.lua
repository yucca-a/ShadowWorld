-- local function midstr()
--     return STRINGS.GIBERISH_PRE[math.random(1,#STRINGS.GIBERISH_PRE)]
-- end

local strList = {STRINGS.MONKEY_SPEECH_PRE[2], STRINGS.MONKEY_SPEECH_PRE[3], STRINGS.MONKEY_SPEECH_PST[1], STRINGS.MONKEY_SPEECH_PST[2]}
local function midstr()
    return strList[TUNING.util2hm.getRandomIntBetween(1, #strList)]
end

local function string_insert(str, ins, pos)
    local a1 = TUNING.util2hm.utf8sub(str, 1, pos - 1) or ""
    local a2 = TUNING.util2hm.utf8sub(str, pos) or ""
    return a1 .. (ins or "") .. a2 -- 2025.10.22 melon:加个判空，不知道为什么ins会报nil
end

local function CraftGiberish(str)
    local len = TUNING.util2hm.utf8len(str)
    TUNING.util2hm.setSeed(len)
    local count = math.ceil(len / 5)
    local addIndex = {}
    for i = 1, count do
        local isSame = true
        while isSame do
            isSame = false
            addIndex[i] = TUNING.util2hm.getRandomInt(len)
            if addIndex[i] < len or len == 1 then
                for j = 1, i - 1 do
                    if addIndex[j] == addIndex[i] then
                        isSame = true
                        break
                    end
                end
            else
                isSame = true
            end
        end
    end
    table.sort(addIndex, function(a, b)
        return a < b
    end)
    for i = count, 1, -1 do
        str = string_insert(str, midstr(), addIndex[i] + 1)
    end
    return str
end

AddComponentPostInit("talker", function(self)
    if self.inst and self.inst:HasTag("player") then
        local oldSay = self.Say
        function self:Say(script, ...)
            local classified2hm = TUNING.util2hm.GetClassified2hm(self.inst.userid)
            if classified2hm and classified2hm.take_cursed_item_num:value() then
                local lines = type(script) == "string" and { Line(script, noanim, time) } or script
                for _, line in pairs(lines) do
                    line.message = CraftGiberish(line.message)
                end
                oldSay(self, lines, ...)
            else
                oldSay(self, script, ...)
            end
        end
    end
end)

local oldChatHistoryOnSay = GLOBAL.ChatHistory.OnSay
GLOBAL.ChatHistory.OnSay = function(self, guid, userid, netid, name, prefab, message, ...)
    local classified2hm = TUNING.util2hm.GetClassified2hm(userid)
    if classified2hm and classified2hm.take_cursed_item_num:value() then
        message = CraftGiberish(message)
    end
    if oldChatHistoryOnSay then
        return oldChatHistoryOnSay(self, guid, userid, netid, name, prefab, message, ...)
    end
end

-- local oldNetworking_Say = GLOBAL.Networking_Say
-- if oldNetworking_Say then
--     GLOBAL.Networking_Say = function(guid, userid, name, prefab, message, colour, whisper, isemote, user_vanity)
--         -- print(guid, userid, name, prefab, message)
--         local classified2hm = TUNING.util2hm.GetClassified2hm(userid)
--         if classified2hm and classified2hm.take_cursed_item_num:value() then
--             message = CraftGiberish(message)
--         end
--         oldNetworking_Say(guid, userid, name, prefab, message, colour, whisper, isemote, user_vanity)
--     end
-- end

AddPlayerPostInit(function(inst)
    if not TheWorld.ismastersim then return end
    -- print("AddPlayerPostInit")
    if not inst.components.haitangcurse2hm then
        inst:AddComponent("haitangcurse2hm")
    end
end)