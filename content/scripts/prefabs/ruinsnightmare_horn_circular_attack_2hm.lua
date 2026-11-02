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
local AOE_DAMAGE_TARGET_CANT_TAGS = { "INLIMBO", "notarget", "noattack", "flight", "invisible", "playerghost", "shadowdominance"}

local AOE_DAMAGE_RADIUS = 1.25
local AOE_DAMAGE_RADIUS_PADDING = 3

local DAMAGE_OFFSET_DIST = .4
local COLLIDE_POINT_DIST_SQ = 3

local INITIAL_SPEED = 5.5
local FINAL_SPEED = 10
local reduce = 2
FINAL_SPEED = FINAL_SPEED - reduce
local INITIAL_SPEED_RIFTS = INITIAL_SPEED + 1.5
local FINAL_SPEED_RIFTS = FINAL_SPEED + 1.5

local FINAL_SPEED_TIME = .7

local INITIAL_DIST_FROM_TARGET = 6

local OWNER_REAPPEAR_TIME = 1

---------------------------------------------------------------------------------------------------------------------
-- 特效移除后，清除增益buff
local function clear_buff(inst)
    local target = inst.target2hm
    if target and target:HasTag("player") then return end
    if target and target.components.locomotor then target.components.locomotor:RemoveExternalSpeedMultiplier(target, "horn_speedup2hm") end
    target.horn_atktask2hm = nil
    target.hardmode2hm = nil
end

local function RemoveFx(inst, followhorn)
    inst.AnimState:SetDeltaTimeMultiplier(1)
    inst.AnimState:PlayAnimation("horn_atk_pst")
    inst.AnimState:SetFinalOffset(1)

    inst.SoundEmitter:PlaySound("dontstarve/sanity/creature3/horn_collide")

    inst.components.updatelooper:RemoveOnUpdateFn(inst._OnUpdateFn)

    inst.Physics:SetMotorVelOverride(0, 0, 0)

    inst:AddTag("FX")

    clear_buff(inst)

    inst:ListenForEvent("animover", inst.Remove)
    inst:ListenForEvent("entitysleep", inst.Remove)
end

-- 宿主隐身时自身也隐藏
local function statechange2hm(inst)
    local owner = inst.target2hm
    if owner and (owner:HasTag("shadowcreature") or owner:HasTag("nightmarecreature")) and owner.sg and (owner.sg:HasStateTag("hit") or owner.sg:HasStateTag("noattack") or owner.undergroundmovetask2hm or owner.hidetask2hm) then
        inst.ownerhide2hm = true
        inst:Hide()
    else
        inst.ownerhide2hm = nil
        inst:Show()
    end
end

local function OnUpdate(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local target = inst.target2hm
    local x1, y1, z1 = target.Transform:GetWorldPosition()
    local owner = inst.owner
    local hardmode = inst.followhorn and inst.followhorn.hardmode2hm or inst.hardmode2hm
    -- 宿主隐身时自身也隐藏
    if owner and (owner:HasTag("shadowcreature") or owner:HasTag("nightmarecreature")) and owner.sg and (owner.sg:HasStateTag("hit") or owner.sg:HasStateTag("noattack") or owner.undergroundmovetask2hm or owner.hidetask2hm) then
        inst.ownerhide2hm = true
        inst:Hide()
    else
        inst.ownerhide2hm = nil
        inst:Show()
    end
    -- 更新与目标的相对位置，始终保持目标半径范围围绕运动
    if inst.deathrattle2hm then
        x1 = inst.dx
        y1 = inst.dy
        z1 = inst.dz
    end
    if target ~= nil and target:IsValid() and inst.theta2hm and (inst.radius or inst.num) and inst.number then
        if inst.firsthorn2hm then
            -- 圆周运动计算角度
            local current_time = GetTime()
            local elapsed = current_time - inst.start_time
            local current_angle = (inst.start_angle + elapsed * (FINAL_SPEED + (inst.deathrattle2hm and reduce or 0)) * 6 * inst.theta2hm /90) % 360
            local rad = current_angle * DEGREES
            local rel_x = x1 + math.cos(rad) * (inst.radius or inst.num)
            local rel_z = z1 + math.sin(rad) * (inst.radius or inst.num)
            inst.Transform:SetPosition(rel_x, 0, rel_z)
        elseif inst.followhorn then
            -- 在第一个角与目标相对位置基础上计算位置，保持各个方向角度平均
            local x2, y2, z2 = inst.followhorn.Transform:GetWorldPosition()
            if x2 == nil or z2 == nil then return end
            local dx1, dz1 = x1-x2, z1-z2
            local arc = TWOPI/ inst.num * (inst.number - 1)
            local arc_1 = math.atan2(dz1, dx1)
            local arc_2 = arc_1 - PI + arc

            local rel_x = x1 + math.cos(arc_2) * (inst.radius or inst.num)
            local rel_z = z1 + math.sin(arc_2) * (inst.radius or inst.num)
            inst.Transform:SetPosition(rel_x, 0, rel_z)
        end
            --面向方位始终垂直于自身与目标的直线上
        local angletoepos2 = inst:GetAngleToPoint(x1, y1, z1)
        local angle = angletoepos2 + inst.theta2hm
        inst.Transform:SetRotation(angle)
    end

    if inst.ownerhide2hm then return end
    local combat = inst.owner ~= nil and inst.owner.components.combat or nil

    if combat == nil then
        for i, v in ipairs(TheSim:FindEntities(x, y, z, AOE_DAMAGE_RADIUS + AOE_DAMAGE_RADIUS_PADDING, AOE_DAMAGE_TARGET_MUST_TAGS, AOE_DAMAGE_TARGET_CANT_TAGS)) do
            if v ~= inst and v:IsValid() and not v:IsInLimbo() and
                not (v.components.health ~= nil and v.components.health:IsDead())
            then
                if v:HasTag("playerghost") or v:HasTag("shadowdominance") then return end
                local range = AOE_DAMAGE_RADIUS + v:GetPhysicsRadius(0)
                local x1, y1, z1 = v.Transform:GetWorldPosition()
                local dx = x1 - x
                local dz = z1 - z

                local COOLDOWN_TIME = 1.5
                local current_time = GetTime()
                local last_damage_time = inst.targets[v]
            
                if (last_damage_time == nil or (current_time - last_damage_time) >= COOLDOWN_TIME) and (dx * dx + dz * dz) < (range * range) then
                    if v:HasTag("player") then
                        v:PushEvent("knockback", {
                        knocker = inst,
                        radius = inst.num / 4,
                        strengthmult = (v.components.inventory ~= nil and v.components.inventory:ArmorHasTag("heavyarmor") or v:HasTag("heavybody")) and 2.5 or 1.5,
                        forcelanded = false
                    })
                    end
                    v.components.combat:GetAttacked_Internal(inst, TUNING.RUINSNIGHTMARE_DAMAGE)
                    inst.targets[v] = current_time
                end
            end
        end
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
            v:IsValid() and not v:IsInLimbo() and
            not (v.components.health ~= nil and v.components.health:IsDead())
        then
            if v:HasTag("shadowdominance") then return end
            local range = AOE_DAMAGE_RADIUS + v:GetPhysicsRadius(0)
            local x1, y1, z1 = v.Transform:GetWorldPosition()
            local dx = x1 - x
            local dz = z1 - z

            local COOLDOWN_TIME = 1
            local current_time = GetTime()
            local last_damage_time = inst.targets[v]
            if (last_damage_time == nil or (current_time - last_damage_time) >= COOLDOWN_TIME) and (dx * dx + dz * dz) < (range * range) and combat:CanTarget(v) then
                if hardmode then
                    v:PushEvent("knockback", { knocker = inst, radius = AOE_DAMAGE_RADIUS, strengthmult = .6, forcelanded = true })
                end
                combat:DoAttack(v)
                inst.targets[v] = current_time
            end
        end
    end

    combat.ignorehitrange = false
end

---------------------------------------------------------------------------------------------------------------------

local function SetUp(inst, owner, target, num, duration)
    local x, y, z = target.Transform:GetWorldPosition()
    if owner and (owner:HasTag("shadowcreature") or owner:HasTag("nightmarecreature")) and owner.sg and (owner.sg:HasStateTag("hit") or owner.sg:HasStateTag("noattack") or owner.undergroundmovetask2hm or owner.hidetask2hm) then
        inst.ownerhide2hm = true
        inst:Hide()
    end
    inst.target2hm = target
    inst.dx = x
    inst.dy = y
    inst.dz = z
    inst.radius = not target:HasTag("player") and target.components.combat and (target.components.combat.attackrange + 1)
    if type(inst.radius) == "number" then inst.radius = math.max(inst.radius, TUNING.RUINSNIGHTMARE_ATTACK_RANGE) end
    if num == nil then num = 3 end
    if inst.firsthorn2hm then
        -- 生成首个暗影角
        local fx = SpawnPrefab("beef_bell_shadow_cursefx")
        inst:AddChild(fx)
        local randomnum = math.random(0, 1) * 2 - 1
        local arc = TWOPI/num
        local radius = inst.owner and inst.owner.components.planarentity and (num - 1) or num
        local random = math.random()
        inst.Transform:SetPosition(x + radius * math.cos(arc + (arc*0.7) * (math.random() - 1/2)), 0, z - radius * math.sin(arc + (arc*0.7) * (math.random() - 1/2)))
        inst.start_angle = target:GetAngleToPoint(inst.Transform:GetWorldPosition())
        local angletoepos2 = inst:GetAngleToPoint(x, y, z)
        local theta1 = randomnum * 90
        local angle = angletoepos2 + theta1
        inst.Transform:SetRotation(angle)
        inst.theta2hm = theta1
        inst.number = 1
        inst.start_time = GetTime()
        if owner then
            inst:ListenForEvent("newstate", function(owner) statechange2hm(inst) end, owner)
        end
        inst:DoTaskInTime(duration or 8, function() inst:RemoveFx(inst) end)
        -- 在首个基础上处理角度并生成剩余
        for i=2, num do
            local fx = SpawnPrefab("beef_bell_shadow_cursefx")
            local theta = (arc * i) + (random*(arc*0.7) - (arc*0.7)/2)
            local newhorn = SpawnPrefab("ruinsnightmare_horn_circular_attack_2hm")
            newhorn:AddChild(fx)
            if inst.deathrattle2hm then newhorn.deathrattle2hm = true end
            local angletoepos2 = inst:GetAngleToPoint(x, y, z)
            local theta1 = randomnum * 90
            local angle = angletoepos2 + theta1
            newhorn.Transform:SetRotation(angle)
            newhorn.theta2hm = theta1
            newhorn.Transform:SetPosition(x + radius * math.cos(theta), 0, z - radius * math.sin(theta))
            newhorn:SetUp(owner, target, num)
            newhorn.targets = inst.targets
            newhorn.followhorn = inst
            newhorn.number = i
            inst:ListenForEvent("onremove", inst.followhornremove, inst.followhorn)
            if owner then
                newhorn:ListenForEvent("newstate", function(owner) statechange2hm(newhorn) end, owner)
            end
            newhorn:DoTaskInTime(duration or 8, function() newhorn:RemoveFx(newhorn) end) 
        end
    end

    -- if not target:HasTag("player") then inst:ListenForEvent("onremove", clear_buff) end
    inst:ListenForEvent("entitysleep", inst.Remove)
    inst:ListenForEvent("onremove", inst.followhornremove, owner)
    inst:ListenForEvent("death", inst.followhornremove, owner)

    inst.num = num

    inst.owner = owner

    inst.components.updatelooper:AddOnUpdateFn(inst._OnUpdateFn)

    inst.SoundEmitter:PlaySound("dontstarve/sanity/creature3/horn_slice")
    -- inst._final_speed = target:HasTag("player") and FINAL_SPEED_RIFTS or INITIAL_SPEED_RIFTS 

    if inst.owner and inst.owner.components.planarentity ~= nil and not inst.deathrattle2hm then
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

    inst.Physics:SetMotorVelOverride(0, 0, 0)
    inst.AnimState:SetDeltaTimeMultiplier(0.5)
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

    inst.followhornremove = function(followhorn) RemoveFx(inst, followhorn) end
    inst.RemoveFx = RemoveFx

    inst.targets = {}

    inst.SetUp = SetUp
    inst._OnUpdateFn = OnUpdate

    inst:AddComponent("updatelooper")

    inst.persists = false

    return inst
end

return Prefab("ruinsnightmare_horn_circular_attack_2hm", fn, assets, prefabs)