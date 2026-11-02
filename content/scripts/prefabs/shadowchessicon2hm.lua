local assets = {
    Asset("MINIMAP_IMAGE", "sculpture_rookbody_fixed.png"),
    Asset("MINIMAP_IMAGE", "sculpture_knightbody_fixed.png"),
    Asset("MINIMAP_IMAGE", "sculpture_bishopbody_fixed.png"),
    Asset("MINIMAP_IMAGE", "moonrockseed")
}

local function TrackEntity(inst, target)
    inst._target = target
    inst.entity:SetParent(target.entity)
end

local function icon_init(inst)
    inst.icon = SpawnPrefab("globalmapicon")
    inst.icon.MiniMapEntity:SetPriority(11)
    inst.icon:TrackEntity(inst)
end

local function SetSculpturePrefab(inst, prefab) inst.MiniMapEntity:SetIcon("sculpture_" .. prefab .. "body_fixed.png") end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst.MiniMapEntity:SetIcon("moonrockseed.png")
    inst.MiniMapEntity:SetPriority(11)
    inst.MiniMapEntity:SetCanUseCache(false)
    inst.MiniMapEntity:SetDrawOverFogOfWar(true)

    inst:AddTag("CLASSIFIED")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end

    inst.SetSculpturePrefab = SetSculpturePrefab
    inst.TrackEntity = TrackEntity

    inst:DoTaskInTime(0, icon_init)
    inst.persists = false
    return inst
end

return Prefab("shadowchessicon2hm", fn, assets)
