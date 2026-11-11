local assets = {
    Asset("ANIM", "anim/tacklecontainer.zip"),
    Asset("ANIM", "anim/ui_chester_shadow_3x4.zip"),
}

local function OnOpen(inst)
    inst.AnimState:PlayAnimation("open")
    inst.SoundEmitter:PlaySound("hookline_2/characters/hermit/tacklebox/small_open")
end

local function OnClose(inst)
    inst.AnimState:PlayAnimation("close")
    inst.AnimState:PushAnimation("closed", false)
    inst.SoundEmitter:PlaySound("hookline_2/characters/hermit/tacklebox/small_close")
end

local function OnPutInInventory(inst)
    inst.components.container:Close()
    inst.AnimState:PlayAnimation("closed", false)
end

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("tacklecontainer")
    inst.AnimState:SetBuild("tacklecontainer")
    inst.AnimState:PlayAnimation("closed")
    inst:AddTag("portablestorage")

    MakeInventoryPhysics(inst)
    MakeInventoryFloatable(inst, "small", 0.2, nil, nil, nil, {bank = "tacklecontainer", anim = "closed"})

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end

    inst:AddComponent("inspectable")
    inst:AddComponent("container")
    local container = inst.components.container
    container:WidgetSetup("winona_toolbox")
    container.onopenfn = OnOpen
    container.onclosefn = OnClose
    container.skipopensnd = true
    container.skipclosesnd = true
    container.droponopen = true

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem:ChangeImageName("tacklecontainer")
    inst.components.inventoryitem:SetOnPutInInventoryFn(OnPutInInventory)

    MakeHauntableLaunch(inst)
    return inst
end

return Prefab("winona_toolbox", fn, assets)
