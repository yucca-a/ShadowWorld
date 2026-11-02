require "tuning"

local function GetDisplayName(inst) return STRINGS.CHARACTERS.WX78.DESCRIBE.COMPOSTINGBIN.DRY .. STRINGS.NAMES[string.upper(inst.dryveggies2hm)] end

local function OnPickup(inst) inst.components.disappears:StopDisappear() end
local function OnDropped(inst) inst.components.disappears:PrepareDisappear() end
local function disappearFn(inst) inst:DoTaskInTime(.1, inst.Remove) end
local function OnHaunt(inst)
    inst.components.disappears:Disappear()
    return true
end

local hungervalue = {berries = TUNING.CALORIES_TINY / 2, berries_juicy = TUNING.CALORIES_SMALL / 2}

local function MakeDryVeggie(name)

    local assets = {Asset("ANIM", "anim/" .. name .. ".zip"), Asset("INV_IMAGE", name)}

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank(name)
        inst.AnimState:SetBuild(name)
        inst.AnimState:PlayAnimation("idle")

        inst.pickupsound = "vegetation_firm"

        inst.dryveggies2hm = name
        inst:SetPrefabNameOverride(inst.dryveggies2hm)
        inst.displaynamefn = GetDisplayName

        MakeInventoryFloatable(inst)

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then return inst end

        inst:AddComponent("edible")
        inst.components.edible.foodtype = FOODTYPE.GOODIES
        inst.components.edible.healthvalue = TUNING.HEALING_TINY
        inst.components.edible.hungervalue = hungervalue[name] or TUNING.CALORIES_TINY / 2
        inst.components.edible.sanityvalue = TUNING.SANITY_TINY

        inst:AddComponent("stackable")
        inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM

        inst:AddComponent("disappears")
        inst.components.disappears.anim = "idle"
        inst.components.disappears.disappearFn = disappearFn

        inst:AddComponent("inspectable")
        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem:SetSinks(true)
        inst.components.inventoryitem:SetOnPutInInventoryFn(OnPickup)
        inst.components.inventoryitem:ChangeImageName(name)

        inst:AddComponent("bait")

        inst:AddComponent("fuel")
        inst.components.fuel.fuelvalue = TUNING.SMALL_FUEL

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

    return Prefab(name .. "_dried2hm", fn, assets)
end

local berriesVEGGIES = {"berries", "berries_juicy"}
local prefs = {}
for _, veggiename in ipairs(berriesVEGGIES) do table.insert(prefs, MakeDryVeggie(veggiename)) end
return unpack(prefs)
