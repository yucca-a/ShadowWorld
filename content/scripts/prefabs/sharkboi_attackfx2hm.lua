local assets = {Asset("ANIM", "anim/sharkboi_swipe_fx.zip")}

local function Reverse(inst) inst.AnimState:SetPercent("atk2", 0.5) end

local ONEOFTAGS = {"_combat", "freezable"}
local CANTTAGS = {"INLIMBO", "FX", "notarget", "noattack", "invisible", "playerghost", "shadowdominance", "sharkboi"}
local function spawnfx(inst, radius)
    local MAXRADIUS = radius
    local x,y,z = inst.Transform:GetWorldPosition()
    local theta = math.random()*TWOPI
    local radius = 4+ math.pow(math.random(),0.8)* MAXRADIUS
    local offset = Vector3(radius * math.cos( theta ), 0, -radius * math.sin( theta ))

    local prefab = "crab_king_icefx"
    local fx = SpawnPrefab(prefab)
    fx.Transform:SetPosition(x+offset.x,y+offset.y,z+offset.z)
end

local function onmiss(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local fx = SpawnPrefab("crabking_ring_fx2hm")
    if fx then fx.Transform:SetPosition(x,0,z) end
    local radius = 6
    for i=1,10 do
        spawnfx(inst, radius)
    end
    local ents = TheSim:FindEntities(x, y, z, radius, nil, CANTTAGS, ONEOFTAGS)
    if ents then
        for i, v in pairs(ents) do
            if v and v:IsValid() and v.components.health and not v.components.health:IsDead() then
                if v.components.combat then
                    v.components.combat:GetAttacked_Internal(inst, 37.5)
                end
                if v.components.freezable then
                    v.components.freezable:AddColdness((v.sg and v.sg:HasStateTag("parrying") or inst.final) and 2 or 1,5)
                end
                if v.components.temperature then
                    local tmp = v.components.temperature:GetCurrent()
                    local num = 5
                    if tmp - num <= -5 then num = tmp + 5 end
                    v.components.temperature:DoDelta(-num)
                end
            end
        end
    end
    inst:Remove()
end

local function upgradespeed(inst)
    inst.components.projectile.speed = 10
    inst.Physics:SetMotorVel(inst.components.projectile.speed, 0, 0)
end

local function onhit(inst, attacker, target)
    local x, y, z = inst.Transform:GetWorldPosition()
    local fx = SpawnPrefab("crabking_ring_fx2hm")
    if fx then fx.Transform:SetPosition(x,0,z) end
    local radius = 6
    for i=1,10 do
        spawnfx(inst, radius)
    end
    local ents = TheSim:FindEntities(x, y, z, radius, nil, CANTTAGS, ONEOFTAGS)
    if ents then
        for i, v in pairs(ents) do
            if v and v:IsValid() and v.components.health and not v.components.health:IsDead() then
                if v ~= target and v.components.combat then
                    v.components.combat:GetAttacked_Internal(inst, 37.5)
                end
                if v.components.freezable then
                    v.components.freezable:AddColdness((v.sg and v.sg:HasStateTag("parrying") or inst.final) and 2 or 1,5)
                end
                if v.components.temperature then
                    local tmp = v.components.temperature:GetCurrent()
                    local num = 5
                    if tmp - num <= -5 then num = tmp + 5 end
                    v.components.temperature:DoDelta(-num)
                end
            end
        end
    end
    inst:Remove()
end
local function delayRemove(inst) inst:DoTaskInTime(0, inst.Remove) end

local function MakeFX(name, saturation, lightoverride)
    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()
        inst.entity:AddSoundEmitter()

        MakeProjectilePhysics(inst)
        RemovePhysicsColliders(inst)

        inst:AddTag("FX")
        inst:AddTag("NOCLICK")

        inst.Transform:SetFourFaced()

        inst.AnimState:SetBank("sharkboi_swipe_fx")
        inst.AnimState:SetBuild("sharkboi_swipe_fx")
        inst.AnimState:PlayAnimation("atk1")
        inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
        inst.AnimState:SetLayer(LAYER_BACKGROUND)
        inst.AnimState:SetSortOrder(3)
        inst.AnimState:SetPercent("atk1", 0.5)

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then return inst end

        inst.Reverse = Reverse

        local spawnfader2hm = inst:AddComponent("spawnfader2hm")
        spawnfader2hm.hasscale = true
        spawnfader2hm.scaley = 0.65
        spawnfader2hm.speed = 3
        spawnfader2hm.rgb = 1
        spawnfader2hm.alpha = 1
        spawnfader2hm.fn = upgradespeed
        spawnfader2hm:FadeIn()

        inst:AddComponent("weapon")
        inst.components.weapon:SetDamage(37.5)

        inst:AddComponent("projectile")
        inst.components.projectile:SetRange(20)
        inst.components.projectile:SetHitDist(3)
        inst.components.projectile:SetSpeed(5)
        inst.components.projectile:SetHoming(false)
        inst.components.projectile:SetOnHitFn(onhit)
        inst.components.projectile:SetOnMissFn(onmiss)

        inst.persists = false
        inst.OnEntitySleep = delayRemove

        return inst
    end

    return Prefab(name, fn, assets)
end

return MakeFX("sharkboi_attackfx2hm", 0, 0)