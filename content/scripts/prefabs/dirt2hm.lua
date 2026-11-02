local assets = {
    Asset("ANIM", "anim/hpm_player_tomb.zip"),
    -- tomb:dirt, full, full_shake, empty, empty_shake, preview
}

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst.AnimState:SetBuild("hpm_player_tomb")
    inst.AnimState:SetBank("tomb")
    inst.AnimState:PlayAnimation("dirt")

    inst:AddTag("NOCLICK")
    inst:AddTag("NOBLOCK")
    inst:AddTag("DECOR")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false
    -- inst.AnimState:SetLayer(LAYER_BACKGROUND)

    return inst
end

return Prefab("dirt2hm", fn, assets)