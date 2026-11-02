require "tuning"
local PLANT_DEFS = require("prefabs/farm_plant_defs").PLANT_DEFS

local assets = {Asset("ANIM", "anim/seeds.zip")}
local assets_seeds = {Asset("ANIM", "anim/seeds.zip"), Asset("ANIM", "anim/farm_plant_seeds.zip")}

local function Seed_GetDisplayName(inst)
    if inst.dryseeds2hm == "seeds" then return STRINGS.CHARACTERS.WX78.DESCRIBE.COMPOSTINGBIN.DRY .. STRINGS.NAMES.SEEDS end
    local registry_key = inst.plant_def.product
    local plantregistryinfo = inst.plant_def.plantregistryinfo
    return STRINGS.CHARACTERS.WX78.DESCRIBE.COMPOSTINGBIN.DRY ..
               ((ThePlantRegistry:KnowsSeed(registry_key, plantregistryinfo) and ThePlantRegistry:KnowsPlantName(registry_key, plantregistryinfo)) and
                   STRINGS.NAMES["KNOWN_" .. string.upper(inst.dryseeds2hm)] or STRINGS.NAMES[string.upper(inst.dryseeds2hm)])
end

local hungervalue = TUNING.DSTU and TUNING.DSTU.SEEDS and TUNING.DSTU.FOOD_SEEDS_HUNGER or (TUNING.CALORIES_TINY / 2 - 0.5)

local function OnPickup(inst) inst.components.disappears:StopDisappear() end
local function OnDropped(inst) inst.components.disappears:PrepareDisappear() end
local function disappearFn(inst) inst:DoTaskInTime(.1, inst.Remove) end
local function OnHaunt(inst)
    inst.components.disappears:Disappear()
    return true
end

local function MakeDryVeggieSeed(name)

    local seeds_prefabs = name and {"farm_plant_" .. name} or {}

    local function fn_seeds()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank(name and "farm_plant_seeds" or "seeds")
        inst.AnimState:SetBuild(name and "farm_plant_seeds" or "seeds")
        inst.AnimState:PlayAnimation(name or "idle")
        inst.AnimState:SetRayTestOnBB(true)
        inst.scrapbook_anim = name

        inst.pickupsound = "vegetation_firm"

        inst.dryseeds2hm = name and name .. "_seeds" or "seeds"
        inst:SetPrefabNameOverride(inst.dryseeds2hm)
        inst.plant_def = name and PLANT_DEFS[name] or nil
        inst.displaynamefn = Seed_GetDisplayName

        MakeInventoryFloatable(inst)

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then return inst end

        inst:AddComponent("edible")
        inst.components.edible.foodtype = FOODTYPE.GOODIES
        inst.components.edible.healthvalue = TUNING.HEALING_TINY
        inst.components.edible.hungervalue = hungervalue
        inst.components.edible.sanityvalue = TUNING.SANITY_SUPERTINY

        inst:AddComponent("stackable")
        inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM

        inst:AddComponent("disappears")
        inst.components.disappears.anim = name or "idle"
        inst.components.disappears.disappearFn = disappearFn

        inst:AddComponent("inspectable")
        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem:SetSinks(true)
        inst.components.inventoryitem:SetOnPutInInventoryFn(OnPickup)
        inst.components.inventoryitem:ChangeImageName(name and name .. "_seeds" or "seeds")

        inst:AddComponent("bait")

        inst:AddComponent("fuel")
        inst.components.fuel.fuelvalue = TUNING.TINY_FUEL

        inst:ListenForEvent("ondropped", OnDropped)
        inst.components.disappears:PrepareDisappear()

        inst:AddComponent("hauntable")
        inst.components.hauntable.cooldown_on_successful_haunt = false
        inst.components.hauntable.usefx = false
        inst.components.hauntable:SetHauntValue(TUNING.HAUNT_TINY)
        inst.components.hauntable:SetOnHauntFn(OnHaunt)

        MakeSmallBurnable(inst)
        MakeSmallPropagator(inst)
        return inst
    end

    return Prefab(name and name .. "_dryseeds2hm" or "dryseeds2hm", fn_seeds, name and assets_seeds or assets, seeds_prefabs)
end

local seedVEGGIES = {
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
local prefs = {}
table.insert(prefs, MakeDryVeggieSeed())
for _, veggiename in ipairs(seedVEGGIES) do table.insert(prefs, MakeDryVeggieSeed(veggiename)) end
return unpack(prefs)
