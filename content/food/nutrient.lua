local nutrientopt = GetModConfigData("nutrient")
local nutrientlevel = 3
if nutrientopt ~= true then nutrientlevel = -nutrientopt end
local PLANT_DEFS = require("prefabs/farm_plant_defs").PLANT_DEFS
local plantstochoose
local function initseasonnutrients(data)
    data.season = TheWorld.state.season
    data.addon = nil
    if plantstochoose == nil then
        plantstochoose = {}
        for _, def in pairs(PLANT_DEFS) do
            if def and def.nutrient_consumption and def.nutrient_restoration then
                for _, count in ipairs(def.nutrient_consumption) do
                    if count and count ~= 0 and def.prefab then
                        table.insert(plantstochoose, def)
                        break
                    end
                end
            end
        end
    end
    local currdef = plantstochoose[math.random(#plantstochoose)]
    if currdef and currdef.nutrient_consumption and currdef.nutrient_restoration then
        -- 季节本季节的参考作物
        data.prefab = currdef.prefab
        local updatenutrients = {0, 0, 0}
        local total_restore_count = 0
        for n_type, consumptioncount in ipairs(currdef.nutrient_consumption) do
            updatenutrients[n_type] = updatenutrients[n_type] - consumptioncount
            total_restore_count = total_restore_count + consumptioncount
        end
        local nutrients_to_restore_count = GetTableSize(currdef.nutrient_restoration)
        local nutrient_restore_count = math.floor(total_restore_count / nutrients_to_restore_count)
        for n_type = 1, 3 do if currdef.nutrient_restoration[n_type] then updatenutrients[n_type] = updatenutrients[n_type] + nutrient_restore_count end end
        -- 记录本季节的作物加成，有正整数有负整数
        data.updatenutrients = updatenutrients
        -- 默认要取这些数值的1/3，数值大概是浮点数，整数以外的浮点数需要按概率给予才行
    else
        data.updatenutrients = data.updatenutrients or {-1, -1, -1}
    end
    if data.nutrients then data.nutrients = nil end
    if data.chance then data.chance = nil end
end
-- 根据季节额外消耗肥料
AddComponentPostInit("farming_manager", function(self)
    local CycleNutrientsAtPoint = self.CycleNutrientsAtPoint
    self.CycleNutrientsAtPoint = function(self, ...)
        self.dodepleted2hm = true
        local depleted = CycleNutrientsAtPoint(self, ...)
        self.dodepleted2hm = nil
        return depleted
    end
    local AddTileNutrients = self.AddTileNutrients
    self.AddTileNutrients = function(self, x, y, nutrient1, nutrient2, nutrient3, ...)
        if self.dodepleted2hm and TheWorld.components.persistent2hm then
            local data = TheWorld.components.persistent2hm.data.seasonnutrients
            if data == nil or data.season ~= TheWorld.state.season or data.updatenutrients == nil then
                data = data or {}
                TheWorld.components.persistent2hm.data.seasonnutrients = data
                initseasonnutrients(data)
            end
            if data and data.updatenutrients then
                if data.addon == nil or data.nutrientlevel ~= nutrientlevel then
                    data.nutrientlevel = nutrientlevel
                    data.addon = {}
                    for i = 1, 3 do
                        data.addon[i] = {}
                        local value = data.updatenutrients[i] * data.nutrientlevel / 9
                        local floorv = math.floor(value)
                        data.addon[i].floorv = floorv
                        data.addon[i].chance = value - floorv
                    end
                end
                nutrient1 = nutrient1 + data.addon[1].floorv + (data.addon[1].chance > 0 and math.random() < data.addon[1].chance and 1 or 0)
                nutrient2 = nutrient2 + data.addon[2].floorv + (data.addon[2].chance > 0 and math.random() < data.addon[2].chance and 1 or 0)
                nutrient3 = nutrient3 + data.addon[3].floorv + (data.addon[3].chance > 0 and math.random() < data.addon[3].chance and 1 or 0)
            end
        end
        return AddTileNutrients(self, x, y, nutrient1, nutrient2, nutrient3, ...)
    end
end)
-- 检查高级耕地帽
local function onequipped(inst, data)
    if inst.components.inspectable and data and data.owner and data.owner:IsValid() and data.owner:HasTag("player") and data.owner.components.talker then
        local desc, text_filter_context, original_author = inst.components.inspectable:GetDescription(data.owner)
        if desc ~= nil then data.owner.components.talker:Say(desc, 20, true, nil, nil, nil, text_filter_context, original_author) end
    end
end
AddPrefabPostInit("nutrientsgoggleshat", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.inspectable then
        local GetDescription = inst.components.inspectable.GetDescription
        inst.components.inspectable.GetDescription = function(self, ...)
            local txt
            if TheWorld.components.persistent2hm then
                local data = TheWorld.components.persistent2hm.data.seasonnutrients
                if data == nil or data.season ~= TheWorld.state.season or data.updatenutrients == nil then
                    data = data or {}
                    TheWorld.components.persistent2hm.data.seasonnutrients = data
                    initseasonnutrients(data)
                end
                if data and data.prefab and data.updatenutrients then
                    txt = "\n" ..
                              (TUNING.isCh2hm and "本季节各耕地单位养分加成为下数值的" or
                                  "Current Season's Per Farm Nutrients Addon as following's ") .. nutrientlevel .. "/9\n"
                    for i, v in ipairs(data.updatenutrients) do
                        local prefix = v >= 0 and STRINGS.UI.PLANTREGISTRY.NUTRIENTS.RESTORE or STRINGS.UI.PLANTREGISTRY.NUTRIENTS.CONSUME
                        txt =
                            txt .. prefix .. (STRINGS.UI.PLANTREGISTRY.NUTRIENTS[string.upper("nutrient_" .. i)] or ("nutrient_" .. i)) .. " " .. math.abs(v) ..
                                "\n"
                    end
                    txt = txt .. (TUNING.isCh2hm and "可参考" or "Just Like ") .. (STRINGS.NAMES[string.upper(data.prefab)] or data.prefab)
                end
            end
            local desc, filter_context, author = GetDescription(self, ...)
            desc = (desc or "") .. (txt or "")
            return desc, filter_context, author
        end
    end
    inst:ListenForEvent("equipped", onequipped)
end)
