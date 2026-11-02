local brain = require "brains/crabking2hmclawbrain"

local assets =
{
    Asset("ANIM", "anim/crab_king_claw.zip"),
    Asset("ANIM", "anim/crab_king_claw_build.zip"),
}

local prefabs =
{
    "dwx_claw_shadow",
}

local shadow_assets =
{
    Asset("ANIM", "anim/crab_king_claw.zip"),
    Asset("ANIM", "anim/crab_king_claw_shadow_build.zip"),
}

local shadow_prefabs =
{

}

local function releaseclamp(inst, immediate)
	if inst.boat then
		if inst.boat.components.boatphysics ~= nil then
			inst.boat.components.boatphysics:RemoveBoatDrag(inst)
		end

        if inst._releaseclamp then
            inst:RemoveEventCallback("onremove", inst._releaseclamp, inst.boat)
            inst._releaseclamp = nil
        end
    end
    inst.boat = nil
    inst:PushEvent("releaseclamp", {immediate = immediate} )

    if inst.clamptask then
        inst.clamptask:Cancel()
        inst.clamptask = nil
    end
end

local function crunchboat(inst,boat)
    inst:PushEvent("clamp_attack",boat)
    if inst.clamptask then
        inst.clamptask:Cancel()
        inst.clamptask = nil
    end
    inst.clamptask = inst:DoTaskInTime(math.random()+3,function() inst.crunchboat(inst,inst.boat) end)
end

local CRABKING_CLAW_BOATDAMAGES = 50

local CLAMPDAMAGE_CANT_TAGS = {"flying", "shadow", "ghost", "playerghost", "FX", "NOCLICK", "DECOR", "INLIMBO"}
local function clamp(inst)
    if inst.boat and not inst.boat.components.health:IsDead() then
        local bumper = FindEntity(inst, 2, nil, { "boatbumper" })

        local x, y, z = inst.boat.Transform:GetWorldPosition()
        local _ents = TheSim:FindEntities(x, y, z, 4)
        local mult = 1
        -- look for the pirate hat
        if _ents and #_ents > 0 then
            for i, ent in ipairs(_ents) do
                if ent:GetCurrentPlatform() and ent:GetCurrentPlatform() == inst then
                    if ent:HasTag("boat_health_buffer") then
                        mult = 0.33
                    end
                end
            end
        end

        if bumper then
            bumper.components.health:DoDelta((-TUNING.CRABKING_CLAW_BOATDAMAGE) * mult)
        else
            inst.boat.components.health:DoDelta((-TUNING.CRABKING_CLAW_BOATDAMAGE) * mult)
        end
        --boat might dissapear here after the health delta??
        --might break something idfk
        if inst.boat then
            ShakeAllCameras(CAMERASHAKE.VERTICAL, 0.3, 0.03, 0.5, inst.boat, inst.boat:GetPhysicsRadius(4))
            local pos = Vector3(inst.Transform:GetWorldPosition())
            local ents = TheSim:FindEntities(pos.x, pos.y, pos.z, 3, nil, CLAMPDAMAGE_CANT_TAGS)

            for i, v in pairs(ents) do
                if v ~= inst and v:IsValid() and not v:IsInLimbo() then
                    if v.components.health ~= nil and
                        not v.components.health:IsDead() and
                        inst.components.combat:CanTarget(v) then
                        inst.components.combat:DoAttack(v)
                    end
                end
            end
            ShakeAllCameras(CAMERASHAKE.VERTICAL, 0.3, 0.03, 0.5, inst.boat, inst.boat:GetPhysicsRadius(4))

            if inst.boat.components.boatphysics ~= nil then
                inst.boat.components.boatphysics:AddBoatDrag(inst)
            end

            inst._releaseclamp = function() inst:releaseclamp() end
            inst:ListenForEvent("onremove", inst._releaseclamp, inst.boat)
            inst.clamptask = inst:DoTaskInTime(math.random() + 3, function() inst.crunchboat(inst, inst.boat) end)
        end
    end
end

local function teleport_override_fn(inst)
    local pt = inst.components.knownlocations ~= nil and inst.components.knownlocations:GetLocation("spawnpoint") or inst:GetPosition()
    local offset = FindSwimmableOffset(pt, math.random() * 2 * PI, 3, 8, true, false) or
					FindSwimmableOffset(pt, math.random() * 2 * PI, 8, 8, true, false)
    if offset ~= nil then
		pt = pt + offset
    end

	return pt
end

local function OnTeleported(inst)
	inst:releaseclamp(true)
end

local function OnRemove(inst)
    if inst.shadow then
        inst.shadow:Remove()
    end
    inst.releaseclamp(inst)
end

local function OnDead(inst)
    if inst.shadow then
        inst.shadow:Remove()
    end
    inst.releaseclamp(inst)
end

SetSharedLootTable( 'dwx_claw',
{
    {'meat',                                1.00},
})

-- 帝王蟹的举石头钳子和蟹钳会接住炮弹了
local function unprotectshadowself(inst) if not inst.components.health:IsDead() then inst.components.health:SetInvincible(false) end end
local function proxycomplexprojectile(inst, prefab, rot, far)
    if inst.components.health:IsDead() then
        SpawnPrefab("cannonball_used").Transform:SetPosition(inst.Transform:GetWorldPosition())
        return
    end
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, 0, z, 1.5, nil, nil, {"crabking_claw", "crabking"})
    for i, v in ipairs(ents) do
        if v and v:IsValid() and v.components.health and not v.components.health:IsDead() then
            v.components.health:SetInvincible(true)
            if v.protesttask2hm then
                v.protesttask2hm:Cancel()
                v.protesttask2hm = nil
            end
            v.protesttask2hm = v:DoTaskInTime(0.25, unprotectshadowself)
        end
    end
    local projectile = SpawnPrefab(prefab)
    if projectile == nil then return end
    if not projectile.components.complexprojectile then
        projectile:Remove()
        return
    end
    if far then projectile.components.complexprojectile.horizontalSpeed = projectile.components.complexprojectile.horizontalSpeed * 1.35 end
    projectile.disablecrab2hm = true
    local x, y, z = inst.Transform:GetWorldPosition()
    local theta = rot * DEGREES
    local radius = 0.5
    local offset = Vector3(radius * math.cos(theta), 0, -radius * math.sin(theta))
    projectile.Transform:SetPosition(x + offset.x, y + TUNING.BOAT.BOATCANNON.PROJECTILE_INITIAL_HEIGHT, z + offset.z)
    projectile.shooter = inst
    local angle = -rot * DEGREES
    local range = TUNING.BOAT.BOATCANNON.RANGE
    local targetpos = Vector3(x + math.cos(angle) * range, y, z + math.sin(angle) * range)
    projectile.components.complexprojectile:Launch(targetpos, inst, inst)
end
local function clawdelayproxycomplexprojectile(inst, prefab, rot)
    inst.sg:Start()
    if inst.components.health:IsDead() then
        SpawnPrefab("cannonball_used").Transform:SetPosition(inst.Transform:GetWorldPosition())
        inst.sg:GoToState("death")
    else
        inst.sg:GoToState("emerge")
        local time = math.min(inst.AnimState:GetCurrentAnimationLength(), 0.5)
        inst:DoTaskInTime(time, proxycomplexprojectile, prefab, rot)
    end
end
local function processcomplexprojectile(inst, v)
    -- 无伤接炮弹太奇怪了，但也不会受到太高伤害直接导致死亡
    if v.components.health:IsInvincible() or v.components.health.currenthealth > TUNING.CANNONBALL_DAMAGE then
        if v.components.combat and GetTime() - v.components.combat.lastwasattackedtime > TUNING.CANNONBALL_PASS_THROUGH_TIME_BUFFER then
            v.components.combat:GetAttacked_Internal(v, TUNING.CANNONBALL_DAMAGE, nil)
        end
        SpawnPrefab("crab_king_shine").Transform:SetPosition(inst.Transform:GetWorldPosition())
        local target = inst.shooter or inst.components.complexprojectile.attacker
        local rot
        if target and target:IsValid() then
            rot = v:GetAngleToPoint(target:GetPosition():Get())
        else
            rot = v:GetAngleToPoint(inst:GetPosition():Get())
        end
        -- 反弹炮弹
        if v.prefab == "crabking2hm" then
            v:DoTaskInTime(math.clamp(inst.AnimState:GetCurrentAnimationLength(), 0.25, 1), proxycomplexprojectile, inst.prefab, rot, true)
        else
            v.sg:Stop()
            v.AnimState:PlayAnimation("clamp_pre")
            if v.boat and v.boat.prefab == "crabking2hm" and v.releaseclamp then v:releaseclamp() end
            v.Transform:SetRotation(rot - 180)
            local time = v:DoTaskInTime(math.clamp(inst.AnimState:GetCurrentAnimationLength(), 0.5, 1), clawdelayproxycomplexprojectile, inst.prefab, rot)
        end
    else
        -- 牺牲来格挡炮弹
        SpawnPrefab("cannonball_used").Transform:SetPosition(inst.Transform:GetWorldPosition())
        if v.components.combat and GetTime() - v.components.combat.lastwasattackedtime > TUNING.CANNONBALL_PASS_THROUGH_TIME_BUFFER then
            v.components.combat:GetAttacked_Internal(v, TUNING.CANNONBALL_DAMAGE, nil)
        end
    end
    inst.components.complexprojectile:Cancel()
    inst:DoTaskInTime(0, inst.Remove)
end
local function onclawGetAttacked_Internal2hm(inst, data)
    if data and data.attacker then
        if data.attacker.disablecrab2hm then
            inst.oncemiss2hm = true
        elseif data.attacker.components.complexprojectile and not data.attacker.disablecrab2hm and inst.components.health and
            not inst.components.health:IsDead() and inst.sg and
            (inst.sg:HasStateTag("idle") or inst.sg:HasStateTag("moving") or (inst.boat and inst.boat.prefab == "crabking2hm")) and
            (data.attacker:HasTag("activeprojectile") or data.attacker:IsNear(inst, 0.75)) and GetTime() - inst.spawntime > 0.5 then
            processcomplexprojectile(data.attacker, inst)
            data.attacker.disablecrab2hm = true
            inst.oncemiss2hm = true
        end
    end
end

local function BonusDamage(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 40, { "crabking" })
    if #ents > 0 then
        for i, v in ipairs(ents) do
            if v:IsValid() and not v:IsInLimbo() then
                if v.components.health ~= nil and not v.components.health:IsDead() then
                    v.components.health:DoDelta(-inst.components.health.maxhealth)
                end
            end
        end
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeCharacterPhysics(inst, 1000, 0.1)
    inst.Transform:SetSixFaced()

    inst:AddTag("ignorewalkableplatforms")
    inst:AddTag("animal")
    inst:AddTag("scarytoprey")
    inst:AddTag("hostile")
    inst:AddTag("crabking_claw")
	inst:AddTag("soulless")
    inst:AddTag("lunar_aligned")
    inst:AddTag("crab")

    local s  = 0.7
    inst.Transform:SetScale(s, s, s)

    inst.AnimState:SetBank("crab_claw")
    inst.AnimState:SetBuild("crab_king_claw_build")

    inst.AnimState:PlayAnimation("idle", true)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
	end

	inst:AddComponent("boatdrag")
	inst.components.boatdrag.drag = TUNING.CRABKING_ANCHOR_DRAG
	inst.components.boatdrag.forcedampening = 1
	inst.components.boatdrag.max_velocity_mod = TUNING.CRABKING_MAX_VELOCITY_MOD
    inst.components.boatdrag.sailforcemodifier = 0

    inst:AddComponent("locomotor")
    inst.components.locomotor.walkspeed = TUNING.CRABKING_CLAW_WALK_SPEED
    inst.components.locomotor.runspeed = TUNING.CRABKING_CLAW_RUN_SPEED

    ------------------------------------------

    inst:SetStateGraph("SGcrabking2hmclaw")

    ------------------

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(TUNING.CRABKING_CLAW_HEALTH)

    ------------------

    inst:AddComponent("combat")
    inst.components.combat:SetDefaultDamage(TUNING.CRABKING_CLAW_PLAYER_DAMAGE)
    inst.components.combat:SetRange(0)
    inst.components.combat.hiteffectsymbol = "claw_parts_shoulder"
    inst.components.combat:SetAttackPeriod(0)
    inst.components.combat.conditionexternaldamagetakenmultipliers = {
        function(_inst, _attacker, _weapon)
            if _attacker and _attacker.prefab == "cannonball_rock" and _attacker:IsValid() then return 4 end
        end,
    }

    ------------------------------------------

    inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetChanceLootTable('dwx_claw')

    ------------------------------------------

    inst:AddComponent("inspectable")

    ------------------------------------------

    inst:AddComponent("timer")

    ------------------------------------------

    inst:AddComponent("knownlocations")

    ------------------------------------------

    inst:AddComponent("entitytracker")

    ------------------------------------------

    inst:SetBrain(brain)

    inst:ListenForEvent("death", OnDead)
    inst:ListenForEvent("death", BonusDamage)
    inst:ListenForEvent("onremove", OnRemove)
    inst:ListenForEvent("entitysleep", OnEntitySleep)
    inst:ListenForEvent("entitywake", OnEntityWake)

    inst.releaseclamp = releaseclamp
    inst.clamp = clamp
    inst.crunchboat = crunchboat

    MakeLargeBurnableCharacter(inst, "claw_parts_forearm")
    MakeHugeFreezableCharacter(inst, "claw_parts_forearm")

	inst:AddComponent("teleportedoverride")
	inst.components.teleportedoverride:SetDestPositionFn(teleport_override_fn)
	inst:ListenForEvent("teleported", OnTeleported)
    inst:ListenForEvent("GetAttacked_Internal2hm", onclawGetAttacked_Internal2hm)

    inst.shadow = inst:SpawnChild("dwx_claw_shadow")

    return inst
end

local function shadowfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst.Transform:SetSixFaced()

    inst:AddTag("ignorewalkableplatforms")
    inst:AddTag("notarget")
    inst:AddTag("NOCLICK")
    inst:AddTag("NOBLOCK")
     inst.persists = false

    inst.AnimState:SetSortOrder(ANIM_SORT_ORDER_BELOW_GROUND.UNDERWATER)
    inst.AnimState:SetLayer(LAYER_BELOW_GROUND)

    --local s  = 0.7
    --sinst.Transform:SetScale(s, s, s)

    inst.AnimState:SetBank("crab_claw")
    inst.AnimState:SetBuild("crab_king_claw_shadow_build")

    inst.AnimState:PlayAnimation("idle", true)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    return inst
end

return Prefab("crabking2hm_claw",        fn, assets, prefabs),
       Prefab("dwx_claw_shadow", shadowfn, shadow_assets, shadow_prefabs)

