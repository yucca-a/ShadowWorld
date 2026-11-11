-- Native art fallback; UM supplies its own prefab and artwork when installed.
local assets = {Asset("ANIM", "anim/transistor.zip")}
local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    MakeInventoryPhysics(inst)
    inst.AnimState:SetBank("transistor")
    inst.AnimState:SetBuild("transistor")
    inst.AnimState:PlayAnimation("idle")
    inst:AddTag("toolbox_item")
    MakeInventoryFloatable(inst, "small", nil, 0.8)
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end
    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem:ChangeImageName("transistor")
    inst.components.inventoryitem:SetSinks(false)
    inst:AddComponent("tradable")
    inst:AddComponent("upgrader")
    inst.components.upgrader.upgradetype = UPGRADETYPES.ELECTRICAL
    inst.components.upgrader.upgradevalue = 2
    MakeHauntableLaunch(inst)
    return inst
end
return Prefab("winona_upgradekit_electrical", fn, assets)
