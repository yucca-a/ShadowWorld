local assets = {Asset("ANIM", "anim/bearger_mutated_actions_fx.zip")}

local function Reverse(inst) inst.AnimState:SetPercent("atk2", 0.5) end

local function onmiss(inst)
    if not inst.miss2hm then
        inst.miss2hm = true
        inst.Physics:SetMotorVel(inst.components.projectile.speed, 0, 0)
        inst.components.spawnfader2hm:Cancel()
        local despawnfader2hm = inst:AddComponent("despawnfader2hm")
        despawnfader2hm.hasscale = true
        despawnfader2hm.scaley = 0.65
        despawnfader2hm.speed = 2 / 3
        despawnfader2hm.rgb = 1
        despawnfader2hm.alpha = 1
        despawnfader2hm.fn = inst.Remove
        despawnfader2hm:FadeOut()
    end
end

local function upgradespeed(inst)
    inst.components.projectile.speed = 10
    inst.Physics:SetMotorVel(inst.components.projectile.speed, 0, 0)
end

local function onhit(inst)
    inst:DoTaskInTime(1, onmiss)
    inst.Physics:SetMotorVel(inst.components.projectile.speed, 0, 0)
end
local function delayRemove(inst) inst:DoTaskInTime(0, inst.Remove) end

local function MakeFX(name, saturation, lightoverride)
    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeProjectilePhysics(inst)
        RemovePhysicsColliders(inst)

        inst:AddTag("FX")
        inst:AddTag("NOCLICK")

        inst.Transform:SetEightFaced()

        inst.AnimState:SetBank("bearger_mutated_actions_fx")
        inst.AnimState:SetBuild("bearger_mutated_actions_fx")
        inst.AnimState:PlayAnimation("atk1", true)
        inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
        inst.AnimState:SetLayer(LAYER_BACKGROUND)
        inst.AnimState:SetSortOrder(3)
        inst.AnimState:SetSaturation(saturation)
        inst.AnimState:SetLightOverride(lightoverride)
        inst.AnimState:SetPercent("atk1", 0.5)

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then return inst end

        inst.Reverse = Reverse

        local spawnfader2hm = inst:AddComponent("spawnfader2hm")
        spawnfader2hm.hasscale = true
        spawnfader2hm.scaley = 0.65
        spawnfader2hm.speed = 1
        spawnfader2hm.rgb = 1
        spawnfader2hm.alpha = 1
        spawnfader2hm.fn = upgradespeed
        spawnfader2hm:FadeIn()

        inst:AddComponent("weapon")
        inst.components.weapon:SetDamage(TUNING.BEARGER_DAMAGE)

        inst:AddComponent("projectile")
        inst.components.projectile:SetRange(20)
        inst.components.projectile:SetHitDist(3)
        inst.components.projectile:SetSpeed(1)
        inst.components.projectile:SetHoming(false)
        inst.components.projectile:SetOnHitFn(onhit)
        inst.components.projectile:SetOnMissFn(inst.Remove)

        inst.persists = false
        inst.OnEntitySleep = delayRemove

        return inst
    end

    return Prefab(name, fn, assets)
end

return MakeFX("beargerswipefx2hm", 0, 0), MakeFX("mutatedbeargerswipefx2hm", 1, 0.1)
