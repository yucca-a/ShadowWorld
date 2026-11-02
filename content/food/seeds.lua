-- 杂草概率提高
TUNING.FARM_PLANT_RANDOMSEED_WEED_CHANCE = GetModConfigData("Seeds Weed Chance")
-- 只能在耕地上种植
-- require("components/map")
-- if Map then
--     local CanTillSoilAtPoint = Map.CanTillSoilAtPoint
--     function Map:CanTillSoilAtPoint(x, y, z, ignore_tile_type, ...) return CanTillSoilAtPoint(self, x, y, z, false, ...) end
-- end
AddPrefabPostInit("world", function(inst)
    local Map = getmetatable(inst.Map).__index
    local CanTillSoilAtPoint = Map.CanTillSoilAtPoint
    Map.CanTillSoilAtPoint = function(self, x, y, z, ignore_tile_type, ...) return CanTillSoilAtPoint(self, x, y, z, false, ...) end
end)
-- 种子作为食物三维削弱
local VEGGIES = {
    "carrot",
    "corn",
    "pumpkin",
    "eggplant",
    "durian",
    "pomegranate",
    "dragonfruit",
    "watermelon",
    "tomato",
    "potato",
    "asparagus",
    "onion",
    "garlic",
    "pepper"
}
local function onperished(inst)
    if inst.components.perishable and inst.components.inventoryitem and inst.components.inventoryitem.owner and inst.components.inventoryitem.owner:IsValid() then
        if not (inst.components.inventoryitem.owner.components.container and inst.components.inventoryitem.owner.components.container.itemtestfn) then
            inst.components.perishable.onperishreplacement = inst.prefab == "seeds" and "dryseeds2hm" or
                                                                 (inst.plant_def and inst.plant_def.product and inst.plant_def.product .. "_dryseeds2hm") or
                                                                 "spoiled_food"
        end
    elseif inst.components.perishable and inst:IsAsleep() then
        inst.components.perishable.onperishreplacement = nil
        inst:DoTaskInTime(0, inst.Remove)
    end
end
local hungervalue = TUNING.DSTU and TUNING.DSTU.SEEDS and TUNING.DSTU.FOOD_SEEDS_HUNGER or TUNING.CALORIES_TINY / 2
local function seedspostinit(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.edible then inst.components.edible.hungervalue = hungervalue end
    if inst.components.perishable then inst:ListenForEvent("perished", onperished) end
end
AddPrefabPostInit("seeds", seedspostinit)
for _, veggiename in ipairs(VEGGIES) do AddPrefabPostInit(veggiename .. "_seeds", seedspostinit) end
