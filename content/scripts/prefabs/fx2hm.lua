local assets = {Asset("ANIM", "anim/lavaarena_battlestandard.zip")}

local function Defend()
    local inst = CreateEntity()

    inst:AddTag("DECOR") -- "FX" will catch mouseover
    inst:AddTag("NOCLICK")
    --[[Non-networked entity]]
    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("lavaarena_battlestandard")
    inst.AnimState:SetBuild("lavaarena_battlestandard")
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(3)
    inst:ListenForEvent("animover", inst.Remove)
    inst.AnimState:PlayAnimation("defend_fx")

    return inst
end

local function GroundDefend()
    local inst = Defend()

    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetTime(20 * FRAMES)

    return inst
end

return Prefab("grounddefendfx2hm", GroundDefend, assets), Prefab("defendfx2hm", Defend, assets)
