local fooddatachange = GetModConfigData("fooddata_change")

local change = math.abs(fooddatachange)
-- 食物削弱，三维回复全部削弱至少33%
TUNING.food_change_2hm = change

local datas = {"hungervalue", "sanityvalue", "healthvalue"}
local downdata = {1.1, 1.2, 1.333}
local updata = {0.9, 0.8, 0.6667}
local updata2 = {0.85, 0.725, 0.6}
local updata3 = {0.8, 0.65, 0.5}
local updata4 = {0.75, 0.575, 0.4}
local updata5 = {0.7, 0.5, 0.3334}

local blacklist = {"red_cap", "green_cap", "blue_cap", "red_cap_cooked", "green_cap_cooked", "blue_cap_cooked"}

local function ProcessFoodEdible(self)
    for _, data in ipairs(datas) do
        self[data] = self[data] or 0
        if self[data] <= 0 then
            self[data] = self[data] * downdata[change]
        elseif self[data] < 10 then
            self[data] = self[data] * updata5[change]
        elseif self[data] < 20 then
            self[data] = self[data] * updata4[change]
        elseif self[data] < 30 then
            self[data] = self[data] * updata3[change]
        elseif self[data] < 40 then
            self[data] = self[data] * updata2[change]
        else
            self[data] = self[data] * updata[change]
        end
    end
end

AddPrefabPostInitAny(function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.edible and not table.contains(blacklist, inst.prefab) then ProcessFoodEdible(inst.components.edible) end
end)

if TUNING.easymode2hm then
    TUNING.WICKERBOTTOM_SPOILED_FOOD_HUNGER = TUNING.WICKERBOTTOM_SPOILED_FOOD_HUNGER / 2 + 0.5
    TUNING.WICKERBOTTOM_STALE_FOOD_HUNGER = TUNING.WICKERBOTTOM_STALE_FOOD_HUNGER / 2 + 0.5
    TUNING.SPOILED_FOOD_HUNGER = TUNING.SPOILED_FOOD_HUNGER / 2 + 0.5
    TUNING.STALE_FOOD_HUNGER = TUNING.STALE_FOOD_HUNGER / 2 + 0.5
end
