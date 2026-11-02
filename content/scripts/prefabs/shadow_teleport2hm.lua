local assets = {Asset("ANIM", "anim/shadow_teleport.zip")}

local function fn()
    local inst = CreateEntity()

    inst:AddTag("FX")
    inst:AddTag("DECOR")
    inst:AddTag("NOCLICK")
    inst.entity:SetCanSleep(false)

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("shadow_teleport")
    inst.AnimState:SetBuild("shadow_teleport")
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetMultColour(1, 1, 1, .5)

    inst.persists = false

    return inst
end

local function infn()
    local inst = fn()
    inst.AnimState:PlayAnimation("portal_in")
    inst:ListenForEvent("animover", inst.Remove)
    return inst
end

local function outfn()
    local inst = fn()
    inst.AnimState:PlayAnimation("portal_out")
    inst:ListenForEvent("animover", inst.Remove)
    return inst
end

return Prefab("shadow_teleport_in2hm", infn, assets), Prefab("shadow_teleport_out2hm", outfn, assets)
