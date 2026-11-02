local assets = {Asset("ANIM", "anim/moonstorm_groundlight.zip")}
local prefabs = {}
local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst:AddTag("fx")

    inst.AnimState:SetBuild("moonstorm_groundlight")
    inst.AnimState:SetBank("moonstorm_groundlight")
    local anim = math.random() < 0.5 and "strike" or "strike2"

    inst.AnimState:PlayAnimation(anim)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(3)

    inst.AnimState:SetMultColour(0.5, 0.5, 1, 1)

    inst.Transform:SetScale(1, 1, 1)
    -- inst.Transform:SetRotation(90)

    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")

    if not TheWorld.ismastersim then return inst end

    -- From watersource component
    inst:AddTag("NOCLICK")
    inst:ListenForEvent("animover", function() inst:Remove() end)

    inst.SoundEmitter:PlaySound("moonstorm/common/moonstorm/electricity")

    inst.persists = false

    return inst
end

return Prefab("moonstorm_ground_lightning_fx2hm", fn, assets, prefabs)
