-- 重复吃同一料理收益减少且额外扣san
-- 吃喜欢的料理不触发惩罚且所有属性收益增加30%
local mult = 1.3
AddPlayerPostInit(function(inst)
    if not TheWorld.ismastersim or inst.components.foodmemory then return end
    inst:AddComponent("foodmemory")
    inst.components.foodmemory:SetDuration(TUNING.WARLY_SAME_OLD_COOLDOWN)
    inst.components.foodmemory:SetMultipliers(TUNING.WARLY_SAME_OLD_MULTIPLIERS)

    inst.components.foodmemory.GetFoodMultiplier2hm = inst.components.foodmemory.GetFoodMultiplier
    inst.components.foodmemory.GetFoodMultiplier = function() return 1 end
    if inst.components.eater then
        local oldEat = inst.components.eater.Eat
        inst.components.eater.Eat = function(self, food, ...)
            local finity = inst.components.foodaffinity and inst.components.foodaffinity:HasPrefabAffinity(food)
            if finity or not food:HasTag("preparedfood") then
                self.changetag2hm = true
                food:AddTag("potion") 
            end
            local result = oldEat(self, food, ...)
            if self.changetag2hm == true then 
                self.changetag2hm = nil
                food:RemoveTag("potion")
            end
            return result
        end

        local _custom_stats_mod_fn = inst.components.eater.custom_stats_mod_fn
        inst.components.eater.custom_stats_mod_fn = function(inst, health_delta, hunger_delta, sanity_delta, food, ...)
            if _custom_stats_mod_fn then
                health_delta, hunger_delta, sanity_delta = _custom_stats_mod_fn(inst, health_delta, hunger_delta, sanity_delta, food, ...)
            end
            local finity = food and food:HasTag("preparedfood") and inst.components.foodaffinity and inst.components.foodaffinity:HasPrefabAffinity(food)
            if finity then
                if health_delta < 0 then
                    health_delta = health_delta / 2
                else
                    health_delta = health_delta * mult
                end

                if hunger_delta < 0 then
                    hunger_delta = hunger_delta / 2
                else
                    hunger_delta = hunger_delta * mult
                end

                if sanity_delta < 0 then
                    sanity_delta = sanity_delta / 2
                else
                    sanity_delta = sanity_delta * mult
                end
                return health_delta, hunger_delta, sanity_delta
            end
            local base_mult = inst.components.foodmemory and inst.components.foodmemory.GetFoodMultiplier2hm and
                                    inst.components.foodmemory:GetFoodMultiplier2hm(food.prefab) or 1
            if sanity_delta < 0 then
                sanity_delta = sanity_delta / 2
            else
                sanity_delta = sanity_delta * base_mult
            end
            if base_mult < 1 then sanity_delta = sanity_delta - 50 * (1 - base_mult) end
            return health_delta, hunger_delta, sanity_delta
        end
    end
end)

local UpvalueHacker = require("upvaluehacker2hm")
AddSimPostInit(function() 
    if GetDescription_AddSpecialCases then
        local oldfn = UpvalueHacker.GetUpvalue(GetDescription_AddSpecialCases, "getcharacterstring")
        if oldfn then
            local newfn = function(tab, item, ...)
                if item == "ANNOUNCE_FOODMEMORY" then
                    return (TUNING.isCh2hm and "\n我不想吃同样的旧东西" or "\nI'd rather not eat the same old thing again.")
                end
                return oldfn(tab, item, ...)
            end
            UpvalueHacker.SetUpvalue(GetDescription_AddSpecialCases, newfn, "getcharacterstring")
        end
    end
end)

--使用字符串引用修改对模组人物不生效，很奇怪？
-- if DST_CHARACTERLIST then
--     AddSimPostInit(function() 
--         for i, v in pairs(DST_CHARACTERLIST) do
--             if v ~= "warly" then
--                 STRINGS.CHARACTERS[string.upper(v)] = STRINGS.CHARACTERS[string.upper(v)] or {}
--                 STRINGS.CHARACTERS[string.upper(v)].ANNOUNCE_FOODMEMORY = {
--                     GENERIC = (TUNING.isCh2hm and "\n我不想吃同样的旧东西" or "\nI'd rather not eat the same old thing again."),
--                 }
--             end
--         end
--     end)
-- end

-- if next(MODCHARACTERLIST) ~= nil then
--     AddSimPostInit(function() 
--         for i, v in pairs(MODCHARACTERLIST) do
--             -- print2hm(STRINGS.CHARACTERS[string.upper(v)])
--             STRINGS.CHARACTERS[string.upper(v)] = STRINGS.CHARACTERS[string.upper(v)] or {}
--             -- local wx = rawget(STRINGS.CHARACTERS[string.upper(v)], "ANNOUNCE_FOODMEMORY")
--             -- print2hm(wx)
--             rawset(STRINGS.CHARACTERS[string.upper(v)], "ANNOUNCE_FOODMEMORY", {
--                 GENERIC = (TUNING.isCh2hm and "\n我不想吃同样的旧东西" or "\nI'd rather not eat the same old thing again."),
--             })
--             print("触发")
--             -- wx = rawget(STRINGS.CHARACTERS[string.upper(v)], "ANNOUNCE_FOODMEMORY")
--             -- print2hm(wx)
--         end
--     end)
-- end

-- if TUNING.DSTU then
--     local spc = require("speech_wathom")
--     if spc then
--         for i, v in pairs(spc) do
--             if k == "ANNOUNCE_FOODMEMORY" then v = (TUNING.isCh2hm and "\n我不想吃同样的旧东西" or "\nI'd rather not eat the same old thing again.") end
--         end
--     end
-- end