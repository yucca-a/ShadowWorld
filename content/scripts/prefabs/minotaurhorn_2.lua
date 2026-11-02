-- 微瑕/破损犀牛角(独立prefab, 贴图与原版犀牛角完全一致)
-- 设计: 普通犀牛角 minotaurhorn 升级装备成功后, 转为本 prefab(微瑕状态); 微瑕/破损状态用 tag 区分
-- 独立 prefab 从代码层面隔断所有需要普通犀牛角的合成(配方按 prefab 名匹配, 不会匹配到 minotaurhorn_2)
local assets =
{
    Asset("ANIM", "anim/horn_rhino.zip"),
}

-- 客户端可见注册放本文件(两端必加载, 不受 easy_equipments 门控影响):
--   名字兜底 + 物品栏图标复用原版 + 微瑕/破损显示名
-- 注: easy_equipments 的 setup_horn_postinit 在服务端也会设同名 displaynamefn(逻辑一致, 无冲突)
STRINGS.NAMES.MINOTAURHORN_2 = TUNING.isCh2hm and "犀牛角" or "Guardian Horn"

local function horn2_displaynamefn(inst)
    if inst:HasTag("broken_horn2hm") then
        return TUNING.isCh2hm and "破损的犀牛角" or "Broken Guardian Horn"
    elseif inst:HasTag("flawed_horn2hm") then
        return TUNING.isCh2hm and "微瑕的犀牛角" or "Flawed Guardian Horn"
    end
    return STRINGS.NAMES.MINOTAURHORN_2
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("horn_rhino")
    inst.AnimState:SetBuild("horn_rhino")
    inst.AnimState:PlayAnimation("idle")

    MakeInventoryFloatable(inst, "med", 0.05, 0.75)

    inst.entity:SetPristine()
    inst.displaynamefn = horn2_displaynamefn -- 两端: 物品栏悬浮/检查窗口显示微瑕破损名
    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "minotaurhorn" -- 复用原版犀牛角物品栏图标(新prefab默认名无图集纹理)

    inst:AddComponent("stackable")
    inst.components.stackable.maxsize = TUNING.STACK_SIZE_LARGEITEM

    inst:AddComponent("edible")
    inst.components.edible.foodtype = FOODTYPE.MEAT
    inst.components.edible.healthvalue = TUNING.HEALING_HUGE
    inst.components.edible.hungervalue = TUNING.CALORIES_HUGE
    inst.components.edible.sanityvalue = -TUNING.SANITY_MED

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("minotaurhorn_2", fn, assets)
