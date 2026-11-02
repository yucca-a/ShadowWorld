local assets = {Asset("ANIM", "anim/malbatross_feather.zip")}
local assets2 = {Asset("ANIM", "anim/goose_feather.zip")}

local function onhit(inst, owner, other)
    if other ~= nil and other:IsValid() then
        if inst.prefab == "malbatross_feather2hm" and other.components.freezable ~= nil then
            other.components.freezable:AddColdness(1)
            other.components.freezable:SpawnShatterFX()
        end
        if other.components.moisture ~= nil then
            local waterproofness = (other.components.inventory and math.min(other.components.inventory:GetWaterproofness(), 1)) or 0
            other.components.moisture:DoDelta(math.clamp((inst.prefab == "malbatross_feather2hm" and 5 or 10) * (1 - waterproofness), 4, 10))
        end
    end
    inst:Remove()
end

local function onthrown(inst, owner, target, attacker)
    inst.attacker2hm = attacker
    -- inst:DoTaskInTime(0.1, HasCollide)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()
    inst.Transform:SetTwoFaced()

    MakeProjectilePhysics(inst)
    RemovePhysicsColliders(inst)

    inst.AnimState:SetBank("malbatross_feather")
    inst.AnimState:SetBuild("malbatross_feather")
    inst.AnimState:PlayAnimation("idle")

    -- projectile (from projectile component) added to pristine state for optimization
    inst:AddTag("projectile")

    inst:SetPrefabNameOverride("malbatross_feather")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then return inst end

    inst:AddComponent("inspectable")

    inst:AddComponent("projectile")
    inst.components.projectile:SetRange(TUNING.WALRUS_ATTACK_DIST * 2)
    inst.components.projectile:SetSpeed(15)
    inst.components.projectile:SetHoming(false)
    inst.components.projectile:SetOnHitFn(onhit)
    inst.components.projectile:SetOnMissFn(inst.Remove)
    inst.components.projectile:SetOnThrownFn(onthrown)
    -- inst:ListenForEvent("onthrown", onthrown)

    inst.persists = false

    inst:DoTaskInTime(10, inst.Remove)

    return inst
end
local function fn2()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()
    inst.Transform:SetTwoFaced()

    MakeProjectilePhysics(inst)
    RemovePhysicsColliders(inst)

    inst.AnimState:SetBank("goose_feather")
    inst.AnimState:SetBuild("goose_feather")
    inst.AnimState:PlayAnimation("idle")

    -- projectile (from projectile component) added to pristine state for optimization
    inst:AddTag("projectile")

    inst:SetPrefabNameOverride("goose_feather")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then return inst end

    inst:AddComponent("inspectable")

    inst:AddComponent("projectile")
    inst.components.projectile:SetRange(TUNING.WALRUS_ATTACK_DIST * 2)
    inst.components.projectile:SetSpeed(15)
    inst.components.projectile:SetHoming(false)
    inst.components.projectile:SetOnHitFn(onhit)
    inst.components.projectile:SetOnMissFn(inst.Remove)
    inst.components.projectile:SetOnThrownFn(onthrown)
    -- inst:ListenForEvent("onthrown", onthrown)

    inst.persists = false

    inst:DoTaskInTime(10, inst.Remove)

    return inst
end

return Prefab("malbatross_feather2hm", fn, assets), Prefab("goose_feather2hm", fn2, assets2)
