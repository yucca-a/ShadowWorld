-- 只因拟态梅(原恶魔之心):远古织影者(stalker_atrium)掉落,也可在暗影术基座(shadow_forge)旁制作
-- 贴图借用夜莓(ancientfruit_nightvision)的模型
local assets =
{
    Asset("ANIM", "anim/ancienttree_nightvision_fruit.zip"),
    Asset("INV_IMAGE", "ancientfruit_nightvision"),
}

STRINGS.NAMES.DEVIL_HEART2HM = TUNING.isCh2hm and "只因拟态梅" or "Mimic Nightberry"

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("ancienttree_nightvision_fruit")
    inst.AnimState:SetBuild("ancienttree_nightvision_fruit")
    inst.AnimState:PlayAnimation("idle", true)

    MakeInventoryFloatable(inst, "small", 0.08, 0.75)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "ancientfruit_nightvision"

    inst:AddComponent("stackable")
    inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM

    inst:AddComponent("edible")
    inst.components.edible.healthvalue = 0
    inst.components.edible.hungervalue = 25
    inst.components.edible.sanityvalue = 0
    inst.components.edible.foodtype = FOODTYPE.GENERIC -- 通用类型(所有角色饮食都包含,含韦特/薇格弗德)

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("devil_heart2hm", fn, assets)
