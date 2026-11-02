
-- 2025.8.8 melon:作物放晾肉架可晾干，仅有0.25菜/果度，(回3%血量上限(写在easy_other))

-- from TUNING
local CALORIES_TINY = 9.5
local CALORIES_SMALL = 12.5
local CALORIES_MED = 25
local CALORIES_LARGE = 37.5

local PLANTS_HUNGER = { -- 省略CALORIES_SMALL
    ["corn"]=CALORIES_MED, ["pumpkin"]=CALORIES_LARGE, ["eggplant"]=CALORIES_MED, 
    ["durian"]=CALORIES_MED, ["pomegranate"]=CALORIES_TINY, ["dragonfruit"]=CALORIES_TINY, 
    ["onion"]=CALORIES_TINY, ["garlic"]=CALORIES_TINY, ["pepper"]=CALORIES_TINY,
}

local PLANTS_SAN = {["watermelon"]=8, ["cactus_meat"]=8,} -- 彩蛋:watermelon的san高一点  8*0.7=5.6

local QUAGMIRE_PORTS = {"tomato", "onion"}
-------------------------------------------------------------------------------------

local function MakeDryPlant(name)

    local assets =
    {
        Asset("ANIM", "anim/"..name..".zip"),
        Asset("INV_IMAGE", name),
    }

    local usequagmireicon = table.contains(QUAGMIRE_PORTS, name)
    if usequagmireicon then
        table.insert(assets, Asset("INV_IMAGE", "quagmire_"..name))
    end

    local function fn_dry()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank(name)
        inst.AnimState:SetBuild(name)
        inst.AnimState:PlayAnimation("idle")

        inst.pickupsound = "vegetation_firm"

        --cookable (from cookable component) added to pristine state for optimization
        inst:AddTag("cookable")

        MakeInventoryFloatable(inst)

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then return inst end

        inst:AddComponent("edible")
        inst.components.edible.healthvalue = 5 -- 5*0.7=3.5
        inst.components.edible.hungervalue = (PLANTS_HUNGER[name] or CALORIES_SMALL) / 2 -- 一半
        inst.components.edible.sanityvalue = PLANTS_SAN[name] or 5 -- 5*0.7=3.5
        inst.components.edible.foodtype = FOODTYPE.VEGGIE

        inst:AddComponent("stackable")
        if name ~= "pumpkin" and
            name ~= "eggplant" and
            name ~= "durian" and
            name ~= "watermelon" then
            inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM
        end

        inst:AddComponent("inspectable")
        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem:SetSinks(true)
        inst.components.inventoryitem:ChangeImageName(name)
        if usequagmireicon then
            inst.components.inventoryitem:ChangeImageName("quagmire_"..name)
        end

        inst.dryplants2hm = name .. "_dryplants2hm" -- 标记

        return inst
    end

    return Prefab(name .. "_dryplants2hm", fn_dry, assets, prefabs)
end

local PLANTS = {
    "carrot", "corn", "pumpkin", "eggplant", "durian", "pomegranate", 
    "dragonfruit", "watermelon", "tomato", "potato", "asparagus", 
    "onion", "garlic", "pepper",
    "fig", "cave_banana", "cactus_meat", -- 无花果/香蕉/仙人掌
}

local prefs = {}
for _, plantname in ipairs(PLANTS) do table.insert(prefs, MakeDryPlant(plantname)) end

-- 描述、入锅 ---------------------------------------------------------------
for _, plantname in ipairs(PLANTS) do
    STRINGS.NAMES[string.upper(plantname) .. "_DRYPLANTS2HM"] = TUNING.isCh2hm and STRINGS.NAMES[string.upper(plantname)] .. "干" or "dried " .. plantname
    STRINGS.CHARACTERS.GENERIC.DESCRIBE[string.upper(plantname) .. "_DRYPLANTS2HM"] = TUNING.isCh2hm and "可恢复3%血量上限" or "can recover 3% maximum health"
end
-- 可入锅但只有0.25蔬菜/水果度
local fruits = {"durian", "pomegranate", "dragonfruit", "watermelon", "cave_banana"}
for _, plantname in ipairs(fruits) do
    AddIngredientValues({plantname .. "_dryplants2hm"}, {fruit = .25})
end
local veggies = {"carrot", "corn", "pumpkin", "eggplant", "asparagus", "onion", "garlic", "tomato", "potato", "pepper", "fig", "cactus_meat"}
for _, plantname in ipairs(veggies) do
    AddIngredientValues({plantname .. "_dryplants2hm"}, {veggie = .25})
end
-- 彩蛋  Easter egg
STRINGS.CHARACTERS.GENERIC.DESCRIBE[string.upper("watermelon") .. "_DRYPLANTS2HM"] = TUNING.isCh2hm and "你也喜欢吃西瓜吗?" or "Do you like melon too?"

-- 返回 prefab--------------------------------------------------------------
return unpack(prefs)
