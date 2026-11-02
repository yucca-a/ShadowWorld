local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddNetwork()

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then return inst end

    inst:AddTag("DECOR")
    inst:AddTag("NOCLICK")

    inst.persists = false

    return inst
end

return Prefab("playertagentity2hm", fn)
