
-- 2025.7.25 melon: 自定义潜伏暗影的夹击  控制方向、伤害

local assets =
{
    Asset("ANIM", "anim/shadow_insanity3_basic.zip"),
}

local prefabs =
{

}

---------------------------------------------------------------------------------------------------------------------

local easing = require("easing")

local AOE_DAMAGE_TARGET_MUST_TAGS = { "_combat", "player" }
local AOE_DAMAGE_TARGET_CANT_TAGS = { "INLIMBO", "notarget", "noattack", "flight", "invisible", "playerghost" }

local AOE_DAMAGE_RADIUS = 1.25
local AOE_DAMAGE_RADIUS_PADDING = 3

local DAMAGE_OFFSET_DIST = .4
local COLLIDE_POINT_DIST_SQ = 3

local INITIAL_SPEED = 5.5
local FINAL_SPEED = 13.5
local INITIAL_SPEED_RIFTS = INITIAL_SPEED + 1.5
local FINAL_SPEED_RIFTS = FINAL_SPEED + 1.5

local FINAL_SPEED_TIME = .7

local INITIAL_DIST_FROM_TARGET = 10

local OWNER_REAPPEAR_TIME = 1

local pdmg2hm = 10 -- 裂隙后 红色 位面伤害
---------------------------------------------------------------------------------------------------------------------

local function TurnIntoCollisionFx(inst)
    inst.Physics:Teleport(inst.collision_x, 0, inst.collision_z)

    inst.AnimState:PlayAnimation("horn_atk_pst")
    inst.AnimState:SetFinalOffset(1)

    inst.SoundEmitter:PlaySound("dontstarve/sanity/creature3/horn_collide")

    inst.components.updatelooper:RemoveOnUpdateFn(inst._OnUpdateFn)

    inst.Physics:SetMotorVelOverride(0, 0, 0)

    inst:AddTag("FX")

    inst:ListenForEvent("animover", inst.Remove)
    inst:ListenForEvent("entitysleep", inst.Remove)
end

local function OnUpdate(inst)
    local x, y, z = inst.Transform:GetWorldPosition()

    if inst.collision_x ~= nil then
        if distsq(x, z, inst.collision_x, inst.collision_z) < COLLIDE_POINT_DIST_SQ then
            if inst.owner ~= nil then
                inst.owner:DoTaskInTime(OWNER_REAPPEAR_TIME, inst.owner.PushEvent, "reappear")
            end

            TurnIntoCollisionFx(inst)

            if inst._pair ~= nil then
                inst._pair:Remove()
            end

            return
        end
    end

    local speed = math.min(easing.inCubic(inst:GetTimeAlive(), inst._initial_speed, inst._final_speed-inst._initial_speed, FINAL_SPEED_TIME), inst._final_speed)

    inst.Physics:SetMotorVelOverride(speed, 0, 0)

    local combat = inst.owner ~= nil and inst.owner.components.combat or nil

    if combat == nil then
        return
    end

    combat.ignorehitrange = true

    if DAMAGE_OFFSET_DIST ~= 0 then
        local theta = inst.Transform:GetRotation() * DEGREES
        local cos_theta = math.cos(theta)
        local sin_theta = math.sin(theta)

        x = x + DAMAGE_OFFSET_DIST * cos_theta
        z = z - DAMAGE_OFFSET_DIST * sin_theta
    end

    for i, v in ipairs(TheSim:FindEntities(x, y, z, AOE_DAMAGE_RADIUS + AOE_DAMAGE_RADIUS_PADDING, AOE_DAMAGE_TARGET_MUST_TAGS, AOE_DAMAGE_TARGET_CANT_TAGS)) do
        if v ~= inst and
            not inst.targets[v] and
            v:IsValid() and not v:IsInLimbo() and
            not (v.components.health ~= nil and v.components.health:IsDead())
        then
            local range = AOE_DAMAGE_RADIUS + v:GetPhysicsRadius(0)
            local x1, y1, z1 = v.Transform:GetWorldPosition()
            local dx = x1 - x
            local dz = z1 - z

            if (dx * dx + dz * dz) < (range * range) and combat:CanTarget(v) then
                -- combat:DoAttack(v)
                -- 修改伤害
                if inst.pdmg2hm == pdmg2hm then
                    v.components.combat:GetAttacked_Internal(inst.owner, inst.dmg2hm, nil, nil, {planar = inst.pdmg2hm})
                else
                    v.components.combat:GetAttacked_Internal(inst.owner, inst.dmg2hm)
                end
                if inst.owner.components.planarentity ~= nil then
                    v:PushEvent("knockback", { knocker = inst, radius = AOE_DAMAGE_RADIUS, strengthmult = .6, forcelanded = true })
                end

                inst.targets[v] = true
            end
        end
    end

    combat.ignorehitrange = false
end

---------------------------------------------------------------------------------------------------------------------

local function SetUp(inst, owner, target, other, _theta) -- 可指定角度_theta  范围0~7
    local x, y, z = target.Transform:GetWorldPosition()

    local theta = other == nil and (45 * math.random(8) * DEGREES) or other.Transform:GetRotation() * DEGREES

    -- 根据_theta设置角度
    if _theta ~= nil then
        _theta = math.clamp(_theta,0,7)
        if other == nil then
            theta = 45 * _theta * DEGREES
        else
            theta = (other.Transform:GetRotation() + 45 * _theta) * DEGREES -- 在other的基础上旋转
        end
    end

    inst.Transform:SetPosition(x + INITIAL_DIST_FROM_TARGET * math.cos(theta), 0, z - INITIAL_DIST_FROM_TARGET * math.sin(theta))

    inst:FacePoint(x, 0, z)

    inst.collision_x = x
    inst.collision_z = z

    inst.owner = owner

    if other ~= nil then
        inst._pair = other
        other._pair = inst
    end

    inst.components.updatelooper:AddOnUpdateFn(inst._OnUpdateFn)

    inst.SoundEmitter:PlaySound("dontstarve/sanity/creature3/horn_slice")

    if inst.owner.components.planarentity ~= nil then
        inst.AnimState:ShowSymbol("red")
        inst.AnimState:SetLightOverride(1)
        inst.AnimState:SetMultColour(1, 1, 1, 0.65)

        inst._initial_speed = INITIAL_SPEED_RIFTS
        inst._final_speed = FINAL_SPEED_RIFTS

        inst.pdmg2hm = pdmg2hm -- 加5位面伤害
    else
        inst.pdmg2hm = 0 -- 无位面伤害
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddPhysics()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst.Transform:SetEightFaced()

    MakeCharacterPhysics(inst, 10, 1.5)
    RemovePhysicsColliders(inst)

    inst.Physics:SetMotorVelOverride(INITIAL_SPEED, 0, 0)

    inst.AnimState:SetBank("shadowcreature3")
    inst.AnimState:SetBuild("shadow_insanity3_basic")
    inst.AnimState:PlayAnimation("horn_atk_pre")
    inst.AnimState:PushAnimation("horn_atk")

    inst.AnimState:SetMultColour(1, 1, 1, 0.5)
    inst.AnimState:UsePointFiltering(true)
    inst.AnimState:HideSymbol("red")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst._initial_speed = INITIAL_SPEED
    inst._final_speed = FINAL_SPEED

    inst.targets = {}
    ------------------------------------------------------
    inst.SetUp = SetUp -- 修改了该函数参数
    inst._OnUpdateFn = OnUpdate -- 此函数中造成伤害
    --
    inst.dmg2hm = 20 -- 物理夹击伤害  3个全中60
    inst.pdmg2hm = 0 -- 位面夹击伤害
    -----------------------------------------------------

    inst:AddComponent("updatelooper")

    inst.persists = false

    return inst
end

return Prefab("ruinsnightmare_horn_attack2hm", fn, assets, prefabs)