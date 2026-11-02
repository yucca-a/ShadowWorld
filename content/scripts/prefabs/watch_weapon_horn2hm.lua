----------------------------------------------------------------
--[[2025.5.20 melon:此文件为旺达的夹击 修改自原本的夹击(ruinsnightmare_horn_attack)]]
----------------------------------------------------------------
local assets =
{
    Asset("ANIM", "anim/shadow_insanity3_basic.zip"),
}
local prefabs ={}
----------------------------------------------------------------

-- local easing = require("easing")

local AOE_DAMAGE_TARGET_MUST_TAGS = { "_combat", "_health", } -- 去掉"player"abigail
local AOE_DAMAGE_TARGET_CANT_TAGS = { 
    "INLIMBO", "notarget", "noattack", "flight", "invisible", "playerghost",
    "companion", "abigail", "bernie_big", "player", "deer", -- 不打鹿(deergemresistance打不到克劳斯)
    "trap", -- 妥协陷阱(夹子)崩
}

-- 伤害范围  也合并一下
local AOE_DAMAGE_RADIUS = 1.5  -- 原本1.25
local AOE_DAMAGE_RADIUS_PADDING = 1  -- 原本2

local DAMAGE_OFFSET_DIST = 0.4 -- 原版0.4
local COLLIDE_POINT_DIST_SQ = 3
-- 移动速度 固定吧 减少计算
local INITIAL_SPEED = 12
local FINAL_SPEED = 12
local INITIAL_SPEED_RIFTS = INITIAL_SPEED + 1.5
local FINAL_SPEED_RIFTS = FINAL_SPEED + 1.5

local FINAL_SPEED_TIME = .7

local INITIAL_DIST_FROM_TARGET = 6 -- 开始距离

local OWNER_REAPPEAR_TIME = 1

-- 2025.8.8 melon:白名单，让夹击能打到帝王蟹和触手
local white_list = {"crabking", "tentacle"}
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
    if not inst:IsValid() then return end -- 新增有效性检查

    local x, y, z = inst.Transform:GetWorldPosition()

    if inst.collision_x ~= nil then
        if distsq(x, z, inst.collision_x, inst.collision_z) < COLLIDE_POINT_DIST_SQ then
            TurnIntoCollisionFx(inst)
            if inst._pair ~= nil then inst._pair:Remove() end -- 移除成对的
            return
        end
    end
    inst.Physics:SetMotorVelOverride(12, 0, 0) -- speed

    local combat = inst.owner ~= nil and inst.owner.components.combat or nil

    if combat == nil then return end

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
            not (v.components.health ~= nil and v.components.health:IsDead()) and
            (v.components.follower == nil or v.components.follower:GetLeader() == nil) --没被雇佣才能攻击
        then
            -- 多加点判断: 有仇恨(target)才能打   或者在白名单里
            if combat:CanTarget(v) and v.components.combat and (v.components.combat.target or table.contains(white_list, v.prefab)) then
                -- 单纯打17位面伤害   参数(攻击者，物理伤害， ， ， 其它伤害)  位面伤害不吃加成
                v.components.combat:GetAttacked_Internal(inst, inst.dmg2hm * inst.bouns2hm, nil, nil, {planar = inst.pdmg2hm}) -- 写inst.owner会扣雨衣，写nil打大触手会崩，所以写inst
                v.components.combat:SuggestTarget(inst.owner) -- 仇恨受攻击目标
            end
            inst.targets[v] = true
        end
    end

    combat.ignorehitrange = false
end

---------------------------------------------------------------------------------------------------------------------

local function SetUp(inst, owner, target, other, ifsettheta)
    local x, y, z = target.Transform:GetWorldPosition()
    -- 2025.8.17 melon:根据ifsettheta设置角度  第3个夹击不与其它重合
    local rotate = ifsettheta and math.random(3) or math.random(8)

    local theta = other == nil and (45 * math.random(8) * DEGREES) -- 第1个，随机
        or ifsettheta and (other.Transform:GetRotation() + 45 * math.random(3)) * DEGREES -- 第3个,转45或90或135度
        or other.Transform:GetRotation() * DEGREES -- 第2个 与1相对


    inst.Transform:SetPosition(x + INITIAL_DIST_FROM_TARGET * math.cos(theta), 0, z - INITIAL_DIST_FROM_TARGET * math.sin(theta)) -- INITIAL_DIST_FROM_TARGET 改为6

    inst:FacePoint(x, 0, z)

    inst.collision_x = x
    inst.collision_z = z

    inst.owner = owner

    -- 伤害加成  2025.10.13 去除
    inst.bouns2hm = 1
    -- if inst.owner and inst.owner.components.debuffable then
    --     if inst.owner.components.debuffable:HasDebuff("buff_electricattack") then -- 带电
    --         if target and target.components.moisture and target.components.moisture:IsWet() or TheWorld and TheWorld.state.iswet then
    --             inst.bouns2hm = 2.5
    --         else
    --             inst.bouns2hm = 1.5
    --         end
    --     end
    --     if inst.owner.components.debuffable:HasDebuff("buff_attack") then -- 辣
    --         inst.bouns2hm = inst.bouns2hm * 1.2
    --     end
    -- end

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

    inst.Physics:SetMotorVelOverride(12, 0, 0) -- INITIAL_SPEED

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

    inst.targets = {}

    ------------------------------------------------------
    inst.SetUp = SetUp -- 修改了该函数参数
    inst._OnUpdateFn = OnUpdate -- 此函数中造成伤害
    --
    inst.dmg2hm = 7 -- 物理夹击伤害
    inst.pdmg2hm = 10 -- 位面夹击伤害
    inst.bouns2hm = 1 -- 带电伤害
    -----------------------------------------------------
    inst:AddComponent("updatelooper")

    inst.persists = false

    return inst
end

return Prefab("watch_weapon_horn2hm", fn, assets, prefabs)