-- 天体洋葱:天体英雄三阶段掉落,蓝白色洋葱
-- 属性: -50生命 / +150饱食 / +150精神, 保质期65536天
local assets =
{
    Asset("ANIM", "anim/onion.zip"),
    Asset("INV_IMAGE", "quagmire_onion"),
}

STRINGS.NAMES.ONION_CELESTIAL2HM = TUNING.isCh2hm and "天体洋葱" or "Celestial Onion"

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("onion")
    inst.AnimState:SetBuild("onion")
    inst.AnimState:PlayAnimation("idle")
    inst.AnimState:SetMultColour(0.5, 0.8, 1, 1) -- 蓝白色，这个是加个颜色

    MakeInventoryFloatable(inst, "med", 0.05, 0.75)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "quagmire_onion"

    inst:AddComponent("stackable")
    inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM

    inst:AddComponent("edible")
    inst.components.edible.healthvalue = -50
    inst.components.edible.hungervalue = 150
    inst.components.edible.sanityvalue = 150
    inst.components.edible.foodtype = FOODTYPE.VEGGIE

    inst:AddComponent("perishable")
    inst.components.perishable:SetPerishTime(65536 * TUNING.TOTAL_DAY_TIME)
    inst.components.perishable:StartPerishing()

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("onion_celestial2hm", fn, assets)
