local assets = {Asset("MINIMAP_IMAGE", "backpack.png")}

local function TrackEntity(inst, target, restriction, icon)
    inst._target = target
    inst.entity:SetParent(target.entity)
    inst:ListenForEvent("enterlimbo", function() inst:RemoveFromScene() end, target)
    inst:ListenForEvent("exitlimbo", function() inst:ReturnToScene() end, target)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()
    inst:AddTag("NOBLOCK")

    inst.MiniMapEntity:SetIcon("backpack.png")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end
    inst.persists = false
    inst.TrackEntity = TrackEntity
    return inst
end

return Prefab("backpackicon2hm", fn, assets)
