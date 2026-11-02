local assets = {Asset("ANIM", "anim/boat_water_fx2.zip")}

local function fn()
    local inst = CreateEntity()

    inst:AddTag("FX")
    inst:AddTag("NOBLOCK")
    inst:AddTag("ignorewalkableplatforms")

    inst.entity:AddTransform()
    local anim = inst.entity:AddAnimState()
    anim:SetBank("boat_water_fx")
    anim:SetBuild("boat_water_fx2")
    anim:PlayAnimation("idle_loop_1")
    anim:SetSortOrder(ANIM_SORT_ORDER_BELOW_GROUND.BOAT_TRAIL)
    anim:SetOrientation(ANIM_ORIENTATION.OnGround)
    anim:SetLayer(LAYER_WORLD)
    anim:SetOceanBlendParams(TUNING.OCEAN_SHADER.EFFECT_TINT_AMOUNT)
    inst.entity:AddNetwork()

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then return inst end

    inst:AddComponent("boattrailmover")

    inst:ListenForEvent("animover", inst.Remove)
    inst:DoTaskInTime(80 * FRAMES, inst.Remove)

    inst.persists = false

    return inst
end

return Prefab("boatwaterfx2hm", fn, assets)
