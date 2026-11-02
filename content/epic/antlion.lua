local noshadowworld = not GetModConfigData("Shadow World")
-- 蚁狮血量增强
TUNING.ANTLION_HEALTH = TUNING.ANTLION_HEALTH * (noshadowworld and 1.8 or 2)
TUNING.ANTLION_EAT_HEALING = 150 -- 2025.9.19 melon:削弱回血

-- 燃烧的沙刺沙城堡,且玻璃刺具有碰撞
local _antlion
local canburnspikes = {sandspike_short = 6, sandspike_med = 7, sandspike_tall = 8, sandblock = 16}
local function DoBreak(inst) inst.components.health:Kill() end
local function checkantlionforburn(inst)
    -- if inst.components.burnable and _antlion and _antlion:IsValid() and inst:IsNear(_antlion, 10) then
    inst.components.burnable:SetBurnTime(canburnspikes[inst.prefab] or 6)
    local oldOnIgnite = inst.components.burnable.onignite
    inst.components.burnable:SetOnIgniteFn(nil)
    inst.components.burnable:SetOnBurntFn(oldOnIgnite)
    inst.components.burnable:SetOnExtinguishFn(DoBreak)
    if inst.components.propagator == nil then
        if canburnspikes[inst.prefab] >= 8 then
            MakeSmallPropagator(inst)
        else
            MakeMediumPropagator(inst)
        end
    end
    inst.components.burnable:Ignite(true)
    if inst.task then inst.task:Cancel() end
    -- end
end
local function ReadyToBurn(inst)
    inst:RemoveEventCallback("animover", ReadyToBurn)
    if TheWorld.state.israining then return end
    inst:DoTaskInTime(1, checkantlionforburn)
end
-- for spike, _ in pairs(canburnspikes) do
--     AddPrefabPostInit(spike, function(inst)
--         if not TheWorld.ismastersim then return end
--         inst:ListenForEvent("animover", ReadyToBurn)
--     end)
-- end
if TUNING.DSTU and TUNING.DSTU.IMPASSBLES then
    local glass_spikes = {glassspike_short = true, glassspike_med = true, glassspike_tall = true, glassblock = true}
    for glassspike, _ in pairs(glass_spikes) do
        AddPrefabPostInit(glassspike, function(inst)
            inst:DoTaskInTime(0, function()
                if inst.Physics ~= nil then
                    inst.Physics:SetCollisionGroup(COLLISION.OBSTACLES)
                    inst.Physics:ClearCollisionMask()
                    inst.Physics:CollidesWith(COLLISION.GROUND)
                    inst.Physics:CollidesWith(COLLISION.ITEMS)
                    inst.Physics:CollidesWith(COLLISION.CHARACTERS)
                    inst.Physics:SetCapsule(inst.spikeradius, 2)
                end
                if not TheWorld.ismastersim then return end
                if inst.components.heavyobstaclephysics then inst.components.heavyobstaclephysics:SetRadius(inst.spikeradius) end
            end)
        end)
    end
end

-- 普通攻击击飞敌人
local function onhit_knockback(inst, target, disablecollision, shortrange, canknockback)
    if target and target:IsValid() then
        target:PushEvent("knockback", {
            knocker = inst,
            radius = shortrange and 1.5 or 3,
            strengthmult = (target.components.inventory and target.components.inventory:ArmorHasTag("heavyarmor") or target:HasTag("heavybody")) and 3 or 6,
            forcelanded = (disablecollision or canknockback) and false or true,
            disablecollision = disablecollision
        })
    end
end
require("stategraphs/commonstates")
AddStategraphState("antlion_angry", State {
    name = "attack2hm",
    tags = {"attack", "busy", "noelectrocute"},
    onenter = function(inst)
        inst.AnimState:PlayAnimation("attack_pre")
        inst.components.combat:StartAttack()
        inst.sg.statemem.target = inst.components.combat.target
        if inst.components.burnable and not inst.components.burnable:IsBurning() and not inst.components.burnable:IsSmoldering() then
            inst.components.burnable:StartWildfire()
        end
    end,
    timeline = {
        TimeEvent(24 * FRAMES, function(inst)
            inst.sg:AddStateTag("nosleep")
            inst.sg:AddStateTag("nofreeze")
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/attack_pre")
        end),
        TimeEvent(38 * FRAMES, function(inst)
            -- 引燃附近的沙刺
            if not TheWorld.state.israining then
                if inst.components.burnable and not inst.components.burnable:IsBurning() and inst.components.burnable:IsSmoldering() then
                    inst.components.burnable:Ignite(true)
                end
                inst.sg.statemem.attackfire2hm = true
                local attackfx = SpawnPrefab("attackfire_fx")
                attackfx.Transform:SetPosition(inst.Transform:GetWorldPosition())
                attackfx.Transform:SetRotation(inst.Transform:GetRotation())
                local groundpounder = inst.components.groundpounder
                groundpounder:UseRingMode()
                groundpounder.initialRadius = 1.5
                groundpounder.radiusStepDistance = 2
                groundpounder.ringWidth = 2
                groundpounder.damageRings = 2
                groundpounder.destructionRings = 3
                groundpounder.platformPushingRings = 3
                groundpounder.fxRings = 2
                groundpounder.fxRadiusOffset = 1.5
                groundpounder.destroyer = false
                groundpounder.burner = true
                groundpounder.groundpoundfx = "firesplash_fx"
                groundpounder.groundpounddamagemult = 0.5
                groundpounder.groundpoundringfx = "firering_fx"
                table.insert(groundpounder.noTags, "player")
                groundpounder:GroundPound()
                inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/buttstomp")
                inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/dragonfly/buttstomp_voice")
            end
        end),
        TimeEvent(45 * FRAMES, function(inst)
            if inst.sg.statemem.attackfire2hm then
                local x, y, z = inst.Transform:GetWorldPosition()
                local heavyitems = TheSim:FindEntities(x, 0, z, 10, {"groundspike"}, {"INLIMBO", "fire", "NOCLICK"})
                for index, item in ipairs(heavyitems) do
                    if item and item:IsValid() and item.spikeradius and canburnspikes[item.prefab] and item.components.burnable and
                        not item.components.burnable:IsBurning() then
                        if item.task then
                            checkantlionforburn(item)
                        elseif item:HasTag("notarget") then
                            inst:ListenForEvent("animover", ReadyToBurn)
                        end
                    end
                end
            end
        end)
    },
    events = {
        EventHandler("animover", function(inst)
            if inst.AnimState:AnimDone() then
                if inst.sg.statemem.attackfire2hm then
                    local x, y, z = inst.Transform:GetWorldPosition()
                    local players = FindPlayersInRange(x, 0, z, 6, true)
                    for index, player in ipairs(players) do
                        if player.components.burnable and not player.components.burnable:IsBurning() and not player.components.burnable:IsSmoldering() then
                            player.components.burnable:StartWildfire()
                        end
                    end
                end
                inst.sg:GoToState("attack2hm_pst", inst.sg.statemem.target)
            end
        end)
    }
})
AddStategraphState("antlion_angry", State {
    name = "attack2hm_pst",
    tags = {"attack", "busy", "nosleep", "nofreeze", "noelectrocute"},
    onenter = function(inst, target)
        inst.AnimState:PlayAnimation("attack")
        inst.sg.statemem.target = target
    end,
    timeline = {
        TimeEvent(3 * FRAMES, function(inst)
			local AOE_TARGET_MUST_TAGS  = { "_combat", "_health"}
			local AOE_TARGET_CANT_TAGS  = { "INLIMBO", "NOCLICK", "invisible", "playerghost" , "player", "groundspike"}
			local x, y, z = inst.Transform:GetWorldPosition()
            local areahitrange = inst.components.combat.areahitrange
            local areahitdisabled = inst.components.combat.areahitdisabled
            inst.components.combat.areahitrange = 4
            inst.components.combat.areahitdisabled = false
            inst.components.combat:DoAttack(inst.sg.statemem.target)
            for _, player in ipairs(AllPlayers) do
                if player and player:IsValid() and not player:HasTag("playerghost") and player:IsNear(inst, inst.components.combat.areahitrange) then
                    onhit_knockback(inst, player, player ~= inst.sg.statemem.target, nil, true)
                end
            end
			for i, v in ipairs(TheSim:FindEntities(x, y, z, 10, AOE_TARGET_MUST_TAGS, AOE_TARGET_CANT_TAGS)) do
				if v ~= inst then
					if v:IsValid() and v.components.health and not v.components.health:IsDead() and v.components.combat then
						v.components.combat:GetAttacked_Internal(inst, 300)
					end
				end
			end
            inst.components.combat.areahitrange = areahitrange
            inst.components.combat.areahitdisabled = areahitdisabled
            inst.sg.statemem.target = nil
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/sfx/ground_break")
            if inst.components.burnable and inst.components.burnable:IsBurning() then inst.components.burnable:Extinguish() end
        end),
        CommonHandlers.OnNoSleepTimeEvent(15 * FRAMES, function(inst)
            inst.sg:RemoveStateTag("busy")
            inst.sg:RemoveStateTag("nosleep")
            inst.sg:RemoveStateTag("nofreeze")
        end)
    },
    events = {CommonHandlers.OnNoSleepAnimOver("idle")}
})

-- 钻入地下持续攻击,然后逃到其他位置钻出地面;期间发射沙之石攻击标记敌人,从而引发更多沙刺攻击
local SPIKE_SIZES = {"short", "med", "tall"}
local SPIKE_RADIUS = {["short"] = .2, ["med"] = .4, ["tall"] = .6, ["block"] = 1.1}
local function CanSpawnSpikeAt(pos, size)
    local radius = SPIKE_RADIUS[size]
    for i, v in ipairs(TheSim:FindEntities(pos.x, 0, pos.z, radius + 1.5, nil, {"antlion_sinkhole"}, {"groundspike", "antlion_sinkhole_blocker"})) do
        if v.Physics == nil then return false end
        local spacing = radius + v:GetPhysicsRadius(0)
        if v:GetDistanceSqToPoint(pos) < spacing * spacing then return false end
    end
    return true
end
-- 沙刺攻击
local function SpawnSpikes(inst, pos, count)
    for i = #SPIKE_SIZES, 1, -1 do
        local size = SPIKE_SIZES[i]
        if CanSpawnSpikeAt(pos, size) then
            SpawnPrefab("sandspike_" .. size).Transform:SetPosition(pos:Get())
            count = count - 1
            break
        end
    end
    if count > 0 then
        local dtheta = PI * 2 / count
        for theta = math.random() * dtheta, PI * 2, dtheta do
            local size = SPIKE_SIZES[math.random(#SPIKE_SIZES)]
            local offset = FindWalkableOffset(pos, theta, 2 + math.random() * 2, 3, false, true, function(pt) return CanSpawnSpikeAt(pt, size) end, false, true)
            if offset ~= nil then SpawnPrefab("sandspike_" .. size).Transform:SetPosition(pos.x + offset.x, 0, pos.z + offset.z) end
        end
    end
end
local extraattacktarget
local function attackbyspikes(player, inst)
    if player and player:IsValid() and (player.townportaltalisman2hm and player.townportaltalisman2hm:IsValid() or player == extraattacktarget) then
        SpawnSpikes(inst, player:GetPosition(), math.random(6, 7))
    end
end
local function OnProjWork(inst, worker, workleft)
    if not worker:HasTag("player") then
        inst.components.workable:SetWorkLeft(inst.oldworkleft2hm or 6)
        return
    end
    inst.oldworkleft2hm = inst.oldworkleft2hm and inst.oldworkleft2hm - 1 or 5
    if inst.oldworkleft2hm <= 0 then
        SpawnPrefab("dirt_puff").Transform:SetPosition(inst.Transform:GetWorldPosition())
        inst.enablespawn = true
        inst:Remove()
    else
        inst.components.workable:SetWorkLeft(inst.oldworkleft2hm)
        SpawnPrefab("collapse_small").Transform:SetPosition(inst.Transform:GetWorldPosition())
    end
end
local function projlocktarget(inst, target)
    if target and target:IsValid() then
        inst.Transform:SetPosition(target.Transform:GetWorldPosition())
    else
        inst:Remove()
    end
end
local function onprojhitplayer(proj, inst, player)
    if proj and proj:IsValid() and player and player:IsValid() and inst and inst:IsValid() and inst.components.health and not inst.components.health:IsDead() then
        RemovePhysicsColliders(proj)
        if player.townportaltalisman2hm and player.townportaltalisman2hm:IsValid() then player.townportaltalisman2hm:Remove() end
        proj.parent2hm = player
        proj.target2hm = player
        proj.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
        proj.AnimState:SetLayer(LAYER_BACKGROUND)
        proj.AnimState:SetSortOrder(3)
        proj.AnimState:PlayAnimation("inactive", true)
        if proj.DynamicShadow then proj.DynamicShadow:Enable(false) end
        local workable = proj:AddComponent("workable")
        workable:SetWorkAction(ACTIONS.DIG)
        workable:SetWorkLeft(6)
        workable:SetOnWorkCallback(OnProjWork)
        proj:DoPeriodicTask(FRAMES, projlocktarget, 0, player)
        player.townportaltalisman2hm = proj
        proj:DoTaskInTime(math.random(90, 120), proj.Remove)
    else
        proj:Remove()
    end
end
local function delayremoveproj(inst)
    if inst.parent2hm then return end
    inst.enablespawn = true
    inst:Remove()
end
local function onprojremove(inst)
    if inst.parent2hm and inst.parent2hm:IsValid() and inst.parent2hm:HasTag("player") and inst.parent2hm.townportaltalisman2hm then
        inst.parent2hm.townportaltalisman2hm = nil
    end
end
-- 吸附沙石攻击
local function userocksattack(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local sendproj = false
    for _, player in ipairs(AllPlayers) do
        if player and player:IsValid() and not player:HasTag("playerghost") and player:IsNear(inst, 36) then
            sendproj = true
            local proj = SpawnPrefab("townportaltalisman2hm")
            proj:ListenForEvent("onremove", onprojremove)
            proj.target2hm = player
            proj:AddComponent("weapon")
            proj.components.weapon:SetDamage(1)
            proj.components.weapon:SetRange(8, 10)
            proj.components.projectile:SetHoming(true)
            proj.components.projectile:SetSpeed(10)
            proj.components.projectile:SetRange(120)
            proj.components.projectile:SetOnHitFn(onprojhitplayer)
            proj:DoTaskInTime(9, delayremoveproj)
            proj.Transform:SetPosition(inst.Transform:GetWorldPosition())
            proj.components.projectile:Throw(inst, player, inst)
        end
    end
    if sendproj then SpawnPrefab("fence_rotator_fx").Transform:SetPosition(x, y, z) end
end
-- 单独地震攻击
local function SpawnSinkhole(pt)
    local sinkhole = SpawnPrefab("antlion_sinkhole")
    sinkhole.Transform:SetPosition(pt.x, 0, pt.z)
    sinkhole:PushEvent("startcollapse")
    sinkhole.remainingrepairs = 1
    if sinkhole.components.timer then
        sinkhole.components.timer:StopTimer("nextrepair")
        sinkhole.components.timer:StartTimer("nextrepair", math.random(45, 60))
    end
end
local function clearsinkhole(x, y, z)
    local sinkholes = TheSim:FindEntities(x, 0, z, TUNING.ANTLION_SINKHOLE.RADIUS * 1.5, {"antlion_sinkhole"})
    for i, v in ipairs(sinkholes) do if v and v.prefab == "antlion_sinkhole" and v.components.timer then v:Remove() end end
end
local oldANTLION_CAST_RANGE
AddStategraphState("antlion_angry", State {
    name = "enterworld2hm",
    tags = {"busy", "nosleep", "nofreeze", "noelectrocute"},
    onenter = function(inst)
        TUNING.ANTLION_MIN_ATTACK_PERIOD = TUNING.ANTLION_MIN_ATTACK_PERIOD * 2
        TUNING.ANTLION_CAST_MAX_RANGE = TUNING.ANTLION_CAST_MAX_RANGE / 3
        TUNING.ANTLION_CAST_RANGE = TUNING.ANTLION_CAST_RANGE / 3
        oldANTLION_CAST_RANGE = nil
        inst.components.combat:SetRange(TUNING.ANTLION_CAST_RANGE)
        inst.components.combat:SetAttackPeriod(math.max(TUNING.ANTLION_MIN_ATTACK_PERIOD,
                                                        (inst.components.combat.min_attack_period + TUNING.ANTLION_SPEED_UP) * 2))
        if inst.resethidetimer2hm and inst.sandstormcdtask2hm then
            if not inst.resetsandcd2hm then
                inst.resetsandcd2hm = true
                inst.sandstormcdtask2hm:Cancel()
                inst.sandstormcdtask2hm = nil
            end
            if inst.summonwall2hm then inst.summonwall2hm = nil end
        end
        local antlionpt = inst:GetPosition()
        if #FindPlayersInRange(antlionpt.x, 0, antlionpt.z, 12, true) > 0 then userocksattack(inst) end
        -- 破坏附近的玻璃刺
        local heavyitems = TheSim:FindEntities(antlionpt.x, 0, antlionpt.z, 10, {"heavy"}, {"INLIMBO", "NOCLICK"})
        for index, item in ipairs(heavyitems) do
            if item and item:IsValid() and item.spikeradius and item.components.workable and item.components.workable:CanBeWorked() then
                item.components.workable:Destroy(inst)
            end
        end
        if inst.components.health:GetPercent() < 0.5 or inst.resethidetimer2hm or math.random() < 0.35 then
            for index = 1, 18 do
                local radius = inst.resethidetimer2hm and math.random(50, 80) or math.random(15, 35)
                local theta = math.random() * 2 * PI
                local offset = Vector3(radius * math.cos(theta), 0, -radius * math.sin(theta))
                local pt = antlionpt + offset
                local node, node_index = TheWorld.Map:FindVisualNodeAtPoint(pt.x, pt.y, pt.z)
                if node and node.tags and table.contains(node.tags, "sandstorm") and TheWorld.Map:IsVisualGroundAtPoint(pt.x, pt.y, pt.z) then
                    inst.Transform:SetPosition(pt.x, pt.y, pt.z)
                    for i = 0, radius - 6, 6 do
                        local suboffset = Vector3(i * math.cos(theta), 0, -i * math.sin(theta))
                        local subpt = antlionpt + suboffset
                        SpawnPrefab("fence_rotator_fx").Transform:SetPosition(subpt.x, subpt.y, subpt.z)
                        clearsinkhole(subpt.x, subpt.y, subpt.z)
                        SpawnSinkhole(subpt)
                    end
                    antlionpt = pt
                    break
                end
            end
        end
        clearsinkhole(antlionpt.x, antlionpt.y, antlionpt.z)
        SpawnSinkhole(antlionpt)
        inst.Physics:SetActive(true)
        inst:Show()
        inst.AnimState:PlayAnimation("enter")
        ShakeAllCameras(CAMERASHAKE.VERTICAL, .7, .025, 1.25, inst, 40)
        local groundpounder = inst.components.groundpounder
        groundpounder.usePointMode = true
        groundpounder.initialRadius = 1
        groundpounder.radiusStepDistance = 4
        groundpounder.ringWidth = 3
        groundpounder.fxRings = nil
        groundpounder.fxRadiusOffset = nil
        groundpounder.groundpoundfx = "groundpound_fx"
        groundpounder.groundpoundringfx = "groundpoundring_fx"
        groundpounder.groundpounddamagemult = 1
        groundpounder.destroyer = true
        groundpounder.burner = false
        groundpounder.destructionRings = 2
        groundpounder.platformPushingRings = 2
        for i = #groundpounder.noTags, 1, -1 do
            if groundpounder.noTags[i] == "player" then
                table.remove(groundpounder.noTags, i)
                break
            end
        end
        groundpounder:GroundPound()
        inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/sfx/break_spike")
    end,
    events = {
        EventHandler("animover", function(inst)
            if inst.AnimState:AnimDone() then
                inst.hide2hm = nil
                inst.sg:GoToState("idle")
            end
        end)
    }
})
AddStategraphState("antlion_angry", State {
    name = "leaveworld2hm",
    tags = {"busy", "nosleep", "nofreeze", "noelectrocute"},
    onenter = function(inst)
        oldANTLION_CAST_RANGE = TUNING.ANTLION_CAST_RANGE
        TUNING.ANTLION_MIN_ATTACK_PERIOD = TUNING.ANTLION_MIN_ATTACK_PERIOD / 2
        TUNING.ANTLION_CAST_MAX_RANGE = TUNING.ANTLION_CAST_MAX_RANGE * 3
        TUNING.ANTLION_CAST_RANGE = TUNING.ANTLION_CAST_RANGE * 3
        inst.components.combat:SetRange(TUNING.ANTLION_CAST_RANGE)
        inst.components.combat:SetAttackPeriod(math.max(TUNING.ANTLION_MIN_ATTACK_PERIOD,
                                                        (inst.components.combat.min_attack_period + TUNING.ANTLION_SPEED_UP) / 2))
        inst.firsthide2hm = true
        inst.AnimState:PlayAnimation("out")
        inst.SoundEmitter:PlaySound("meta2/woodie/werebeaver_groundpound")
    end,
    timeline = {
        TimeEvent(28 * FRAMES, function(inst)
            inst.sg:AddStateTag("noattack")
            local pt = inst:GetPosition()
            clearsinkhole(pt.x, pt.y, pt.z)
            SpawnSinkhole(pt)
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/sfx/break_spike")
        end),
        TimeEvent(35 * FRAMES, function(inst) inst.Physics:SetActive(false) end)
    },
    events = {
        EventHandler("animover", function(inst)
            if inst.AnimState:AnimDone() then
                inst:DoTaskInTime(1.5, userocksattack)
                inst.Physics:SetActive(false)
                inst:Hide()
                inst.hide2hm = true
                inst.sg:GoToState("idle")
            end
        end)
    }
})

-- 蚁狮同时发动地震和沙尘暴攻击敌人,沙尘暴还能传走敌人
local fx = require("fx")
for k, v in pairs(fx) do
    if v.name == "fence_rotator_fx" and v.fn then
        local fn = v.fn
        v.fn = function(inst, ...)
            fn(inst, ...)
            local parent = inst.entity:GetParent()
            if parent ~= nil and parent:HasTag("bigfencefx2hm") then
                inst.AnimState:SetScale(1.5, 1.8, 1.5)
            elseif parent ~= nil and parent:HasTag("antlion") and not parent:HasTag("littlefencefx2hm") then
                inst.AnimState:SetScale(3, 3.6, 3)
            end
        end
        break
    end
end
local function sandstormtaskfn(inst)
    SpawnPrefab("fence_rotator_fx").entity:SetParent(inst.entity)
    if inst.components.moisture then inst.components.moisture:DoDelta(-1, true) end
end
local function checkplayerstatus(inst)
    if inst.sg and inst.sg.currentstate and not (inst.sg.currentstate.name == "entertownportal" or inst.sg.currentstate.name == "exittownportal_pre") and
        inst.sg:HasStateTag("idle") and inst.components.playercontroller then
        inst:Show()
        inst.components.playercontroller:Enable(true)
    end
end
local function EndfenceSpeedMult(player)
    player.sandfencespeedtask2hm = nil
    if player.components.locomotor ~= nil then player.components.locomotor:RemoveExternalSpeedMultiplier(player, "sandfencespeedtask2hm") end
    if player.sandstormtask2hm then
        player.sandstormtask2hm:Cancel()
        player.sandstormtask2hm = nil
    end
    if player.sandstormattacktask2hm then
        player.sandstormattacktask2hm:Cancel()
        player.sandstormattacktask2hm = nil
    end
    player.sandfencespeedlevel2hm = nil
end
local function sandstormattacktaskfn(inst)
    if inst:IsValid() and inst.components.health and not inst.components.health:IsDead() then
        inst.components.health:DoDelta(-(inst.sandfencespeedlevel2hm or 1), false, "antlion")
    end
end
local function onhit_fencecontrol(inst, player)
    if player and player:IsValid() and player.sg and player:HasTag("player") and player.components.health and not player.components.health:IsDead() and
        player.components.locomotor then
        player.sandfencespeedlevel2hm = math.max((player.sandfencespeedlevel2hm or 0) + 1, 5)
        if player.sandfencespeedtask2hm then player.sandfencespeedtask2hm:Cancel() end
        player.sandfencespeedtask2hm = player:DoTaskInTime(8, EndfenceSpeedMult)
        player.components.locomotor:SetExternalSpeedMultiplier(player, "sandfencespeedtask2hm", 1 - (player.sandfencespeedlevel2hm * 0.25))
        if not player.sandstormattacktask2hm then player.sandstormattacktask2hm = player:DoPeriodicTask(1, sandstormattacktaskfn, 0) end
        if not player.sandstormtask2hm then player.sandstormtask2hm = player:DoPeriodicTask(0.35, sandstormtaskfn, 0) end
    end
end
local function delayendteleport(inst, player)
    if player and player.antlionteleport2hm then player.antlionteleport2hm = nil end
    if player and player:IsValid() and player.sg and player:HasTag("player") and not player:HasTag("playerghost") and player.components.health and
        not player.components.health:IsDead() and inst.teleporter2hm and inst.teleporter2hm:IsValid() and inst.teleporter2hm.components.teleporter then
        if not noshadowworld then DropPlayerWeapon2hm(inst, player) end
        onhit_fencecontrol(inst, player)
        local oldpt = Vector3(inst.Transform:GetWorldPosition())
        local targetpos
        for index = 1, 18 do
            local radius = math.random(50, 80)
            local theta = math.random() * 2 * PI
            local offset = Vector3(radius * math.cos(theta), 0, -radius * math.sin(theta))
            local pt = oldpt + offset
            local node, node_index = TheWorld.Map:FindVisualNodeAtPoint(pt.x, pt.y, pt.z)
            if node and node.tags and table.contains(node.tags, "sandstorm") and TheWorld.Map:IsVisualGroundAtPoint(pt.x, pt.y, pt.z) then
                targetpos = pt
                break
            end
        end
        if targetpos then
            inst.teleporter2hm.components.teleporter.migration_data = {x = targetpos.x, y = targetpos.y, z = targetpos.z}
            player.sg:GoToState("entertownportal", {teleporter = inst.teleporter2hm})
            if player.components.playercontroller ~= nil then player.components.playercontroller:Enable(false) end
            player.sg.statemem.isteleporting = true
            player.sg:AddStateTag("drowning")
            player.sg:AddStateTag("attack")
            player:DoTaskInTime(15 * FRAMES, checkplayerstatus)
            player:DoTaskInTime(30 * FRAMES, checkplayerstatus)
            player:DoTaskInTime(60 * FRAMES, checkplayerstatus)
            player:DoTaskInTime(120 * FRAMES, checkplayerstatus)
            player:DoTaskInTime(240 * FRAMES, checkplayerstatus)
        end
    end
end
local function onhit_teleport(inst, player)
    if player and player:IsValid() and player.sg and player:HasTag("player") and not player:HasTag("playerghost") and player.components.health and
        not player.components.health:IsDead() and inst.teleporter2hm and inst.teleporter2hm:IsValid() and inst.teleporter2hm.components.teleporter then
        onhit_fencecontrol(inst, player)
        if not player.antlionteleport2hm then
            local proj = SpawnPrefab("townportaltalisman2hm")
            proj:ListenForEvent("onremove", onprojremove)
            proj.target2hm = player
            onprojhitplayer(proj, inst, player)
            inst:DoTaskInTime(0.5, delayendteleport, player)
            player.antlionteleport2hm = true
        end
    end
end
local function onhit_dynamic(inst, player)
    if inst and inst:IsValid() and player and player:IsValid() then
        if inst:IsNear(player, 18) then
            onhit_knockback(inst, player)
            onhit_fencecontrol(inst, player)
        else
            onhit_knockback(inst, player, nil, true)
            onhit_fencecontrol(inst, player)
        end
    end
end
local function dorangeattack(inst, onhit)
    local x, y, z = inst.Transform:GetWorldPosition()
    local speed = 20 + (inst.components.health and ((1 - inst.components.health:GetPercent()) * 15) or 5)
    for index, player in ipairs(AllPlayers) do
        if player and player:IsValid() and not player:HasTag("playerghost") and player:IsNear(inst, 36) then
            local proj = SpawnPrefab("blowdart_fire")
            if proj and proj.components.projectile then
                proj.persists = false
                proj.components.projectile:SetSpeed(speed)
                proj.components.projectile:SetRange(45)
                RemovePhysicsColliders(proj)
                proj.components.projectile:SetOnMissFn(proj.Remove)
                proj.components.projectile:SetOnHitFn(function(proj, inst, player)
                    onhit(inst, player)
                    proj:Remove()
                end)
                proj.components.projectile:SetHoming(false)
                local playerpos = player:GetPosition()
                if onhit == onhit_teleport then
                    -- if player.townportaltalisman2hm ~= nil then
                    --     proj.components.projectile:SetSpeed(10)
                    --     proj.components.projectile:SetHoming(true)
                    SpawnPrefab("townportaltalisman2hm"):DoPeriodicTask(FRAMES, projlocktarget, 0, proj)
                    -- end
                    proj:AddTag("bigfencefx2hm")
                    proj.components.projectile:SetHitDist(proj.components.projectile.hitdist * 2)
                    proj.components.projectile:SetRange(60)
                end
                if not proj.sandstormtask2hm then proj.sandstormtask2hm = proj:DoPeriodicTask(0.35, sandstormtaskfn, 0) end
                if proj.components.weapon then proj.components.weapon:SetOnAttack(nil) end
                if proj.components.weapon and proj.components.weapon.projectile_offset ~= nil then
                    local dir = (playerpos - Vector3(x, y, z)):Normalize()
                    dir = dir * proj.components.weapon.projectile_offset
                    proj.Transform:SetPosition(x + dir.x, y, z + dir.z)
                else
                    proj.Transform:SetPosition(inst.Transform:GetWorldPosition())
                end
                proj.components.projectile:Throw(inst, player, inst)
                if player.sg and player.sg:HasStateTag("moving") and (onhit == onhit_teleport or math.random() < 0.35) then
                    local time = math.sqrt(inst:GetDistanceSqToPoint(playerpos)) / speed
                    local radius = (player.components.locomotor and player.components.locomotor:GetRunSpeed() or 6) * time
                    local rot = player.Transform:GetRotation()
                    proj.components.projectile:RotateToTarget(playerpos + Vector3(math.cos(rot) * radius, 0, -math.sin(rot) * radius))
                end
            end
        end
    end
end
local function attacksinkholes(inst)
    inst.components.sinkholespawner:StopSinkholes()
    local num_attacks = math.clamp((1 - inst.components.health:GetPercent()) / 0.08, 3, 6)
    for index, player in ipairs(AllPlayers) do
        if player and player.userid and player:IsValid() and not player:HasTag("playerghost") and player:IsNear(inst, 100) then
            local targetinfo = {client = player, userhash = smallhash(player.userid), attacks = num_attacks, warnings = 3}
            inst.components.sinkholespawner:UpdateTarget(targetinfo)
            if targetinfo.client ~= nil then
                table.insert(inst.components.sinkholespawner.targets, targetinfo)
                inst.components.sinkholespawner:DoTargetWarning(targetinfo)
            end
        end
    end
    inst.components.sinkholespawner:PushRemoteTargets()
    if #inst.components.sinkholespawner.targets > 0 then
        inst:StartUpdatingComponent(inst.components.sinkholespawner)
        inst:PushEvent("onsinkholesstarted")
    end
end
local function ShakeCasting(inst) ShakeAllCameras(CAMERASHAKE.VERTICAL, .3, .02, 1, inst, 30) end
AddStategraphState("antlion_angry", State {
    name = "sinkhole_pre2hm",
    tags = {"busy", "attack", "nosleep", "nofreeze", "noelectrocute"},
    onenter = function(inst)
        inst.sg.mem.causingsinkholes2hm = true
        inst.AnimState:PlayAnimation("cast_pre")
        attacksinkholes(inst)
        if not inst.sandstormupgradetask2hm then
            inst:AddTag("littlefencefx2hm")
            inst.sandstormupgradetask2hm = inst:DoPeriodicTask(0.35, sandstormtaskfn)
            inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, 0.8, "sinkholeattack2hm")
        end
        if TheWorld.state.precipitation ~= "none" then TheWorld:PushEvent("ms_forceprecipitation", false) end
    end,
    timeline = {
        TimeEvent(8 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/cast_pre") end),
        TimeEvent(25.5 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/cast_post") end),
        TimeEvent(29 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/sfx/ground_break") end),
        TimeEvent(32 * FRAMES, function(inst) ShakeCasting(inst) end)
    },
    EventHandler("onsinkholesfinished", function(inst, data) inst.sg.mem.causingsinkholes2hm = false end),
    events = {
        EventHandler("animover", function(inst)
            if inst.AnimState:AnimDone() then inst.sg:GoToState(inst.sg.mem.causingsinkholes2hm and "sinkhole_loop2hm" or "sinkhole_pst2hm") end
        end)
    }
})
AddStategraphState("antlion_angry", State {
    name = "sinkhole_loop2hm",
    tags = {"busy", "attack", "nosleep", "nofreeze", "noelectrocute"},
    onenter = function(inst, lastloop)
        if not inst.sandstormtask2hm and inst.sg.mem.causingsinkholes2hm and not inst.sandstormtask2hmready then
            if not inst.sinkholetask2hm then inst.sinkholetask2hm = inst:DoTaskInTime(60, function() inst.sinkholetask2hm = nil end) end
            inst.sandstormtask2hmready = true
            if inst.sandstormupgradetask2hm then
                inst:RemoveTag("littlefencefx2hm")
                inst:AddTag("bigfencefx2hm")
                inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, 0.65, "sinkholeattack2hm")
            end
        elseif not inst.sinkholetask2hm then
            if inst.sg.mem.causingsinkholes2hm then
                inst.components.sinkholespawner:StopSinkholes()
                inst.sg.mem.causingsinkholes2hm = false
            end
            inst.sg.statemem.lastloop = nil
            inst.sg:GoToState("sinkhole_pst2hm")
            return
        end
        if inst.sg.mem.causingsinkholes2hm and not lastloop and #inst.components.sinkholespawner.targets <= 0 then attacksinkholes(inst) end
        if inst.sandstormtask2hm and TheWorld.state.precipitation ~= "none" then TheWorld:PushEvent("ms_forceprecipitation", false) end
        inst.sg.statemem.target = lastloop and inst or FindClosestPlayerToInst(inst, 30, true)
        inst.AnimState:PlayAnimation(inst.sg.statemem.target and "cast_loop_active" or "eat")
        if inst.sg.statemem.target then
            inst:StartUpdatingComponent(inst.components.sinkholespawner)
        elseif not lastloop then
            inst:StopUpdatingComponent(inst.components.sinkholespawner)
        end
        inst.sg.statemem.lastloop = lastloop
    end,
    timeline = {
        TimeEvent(12 * FRAMES,
                  function(inst) if not inst.sg.statemem.target then inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/eat") end end),
        TimeEvent(36 * FRAMES,
                  function(inst) if not inst.sg.statemem.target then inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/eat") end end),
        TimeEvent(28 * FRAMES, function(inst)
            if inst.sg.statemem.target then
                if inst.sandstormtask2hm then dorangeattack(inst, onhit_dynamic) end
                ShakeCasting(inst)
                inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/cast_pre")
                inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/sfx/ground_break")
            end
        end),
        TimeEvent(38 * FRAMES, function(inst)
            if not inst.components.health:IsDead() and not inst.sg.statemem.target then inst.components.health:DoDelta(TUNING.ANTLION_EAT_HEALING) end
        end),
        TimeEvent(59 * FRAMES, function(inst)
            if not inst.components.health:IsDead() and not inst.sg.statemem.target then inst.components.health:DoDelta(TUNING.ANTLION_EAT_HEALING) end
        end),
        TimeEvent(69 * FRAMES, function(inst)
            if inst.sandstormtask2hmready and not inst.sandstormtask2hm and inst.sg.mem.causingsinkholes2hm then
                if TheWorld.state.precipitation ~= "none" then TheWorld:PushEvent("ms_forceprecipitation", false) end
                if inst.sandstormupgradetask2hm then
                    inst.sandstormtask2hm = inst.sandstormupgradetask2hm
                    inst:RemoveTag("bigfencefx2hm")
                    inst.sandstormupgradetask2hm = nil
                end
                inst.allmiss2hm = true
                inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, 0.5, "sinkholeattack2hm")
                inst.sandstormtask2hmready = nil
            end
            if inst.sg.statemem.target then
                if inst.sandstormtask2hm then dorangeattack(inst, onhit_dynamic) end
                ShakeCasting(inst)
                inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/cast_pre")
                inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/sfx/ground_break")
            end
        end),
        TimeEvent(71 * FRAMES,
                  function(inst) if not inst.sg.statemem.target then inst.SoundEmitter:PlaySound("dontstarve/creatures/together/antlion/swallow") end end)
    },
    events = {
        EventHandler("animover", function(inst)
            if inst.AnimState:AnimDone() then
                if inst.sg.statemem.lastloop then
                    inst.sg:GoToState("sinkhole_pst2hm")
                else
                    inst.sg:GoToState("sinkhole_loop2hm", not inst.sg.mem.causingsinkholes2hm)
                end
            end
        end),
        EventHandler("onsinkholesfinished", function(inst, data) inst.sg.mem.causingsinkholes2hm = false end)
    }
})
AddStategraphState("antlion_angry", State {
    name = "sinkhole_pst2hm",
    tags = {"busy", "attack", "nosleep", "nofreeze", "noelectrocute"},
    onenter = function(inst)
        if inst.sinkholetask2hm then
            inst.sinkholetask2hm:Cancel()
            inst.sinkholetask2hm = nil
        end
        if inst.sandstormupgradetask2hm then
            inst.sandstormupgradetask2hm:Cancel()
            inst.sandstormupgradetask2hm = nil
            inst:RemoveTag("littlefencefx2hm")
            inst:RemoveTag("bigfencefx2hm")
        end
        if inst.sandstormtask2hm then
            inst.sandstormtask2hm:Cancel()
            inst.sandstormtask2hm = nil
        end
        inst.sandstormtask2hmready = nil
        inst.sg.mem.causingsinkholes2hm = nil
        inst.allmiss2hm = nil
        inst.components.combat.externaldamagetakenmultipliers:RemoveModifier(inst, "sinkholeattack2hm")
        inst.AnimState:PlayAnimation("cast_pst")
        dorangeattack(inst, onhit_teleport)
    end,
    timeline = {
        TimeEvent(10 * FRAMES, function(inst)
            inst.sg:RemoveStateTag("busy")
            inst.sg:RemoveStateTag("nosleep")
            inst.sg:RemoveStateTag("nofreeze")
        end)
    },
    events = {EventHandler("animover", function(inst) if inst.AnimState:AnimDone() then inst.sg:GoToState("idle") end end)}
})

-- 蚁狮状态图管理
local function endattacktask(inst) inst.attack2hmtask = nil end
local function endsandstormcdtask(inst) inst.sandstormcdtask2hm = nil end
local function enddisappearcdtask(inst) inst.disappearcdtask2hm = nil end
local function endappearcdtask(inst) inst.appearcdtask2hm = nil end
AddStategraphPostInit("antlion_angry", function(sg)
    local oldOnEnteridle = sg.states.idle.onenter
    sg.states.idle.onenter = function(inst, ...)
        if inst.sandstormupgradetask2hm or inst.sandstormtask2hm then
            inst.sg:GoToState("sinkhole_loop2hm", not inst.sg.mem.causingsinkholes2hm)
            return
        elseif inst.components.health and inst.components.health:GetPercent() < 0.8 and not inst.hide2hm and not inst.disappearcdtask2hm and
            not inst.appearcdtask2hm then
            inst.disappearcdtask2hm = inst:DoTaskInTime(noshadowworld and 90 or 60, enddisappearcdtask)
            inst.appearcdtask2hm = inst:DoTaskInTime(20, endappearcdtask)
            inst.sg:GoToState("leaveworld2hm")
            return
        elseif inst.components.health and inst.components.health:GetPercent() < 0.4 and not inst.resethidetimer2hm and not inst.hide2hm and
            inst.disappearcdtask2hm then
            inst.resethidetimer2hm = true
            inst.disappearcdtask2hm:Cancel()
            inst.disappearcdtask2hm = inst:DoTaskInTime(noshadowworld and 90 or 60, enddisappearcdtask)
            if inst.appearcdtask2hm then inst.appearcdtask2hm:Cancel() end
            inst.appearcdtask2hm = inst:DoTaskInTime(20, endappearcdtask)
            inst.sg:GoToState("leaveworld2hm")
            return
        elseif inst.hide2hm and not inst.appearcdtask2hm then
            inst.sg:GoToState("enterworld2hm")
            return
        elseif not inst.hide2hm and not inst.sandstormcdtask2hm and (inst.summonwall2hm or math.random() < 0.15) and
            (inst.firsthide2hm or (inst.components.health and inst.components.health:GetPercent() < 0.8)) then
            local target = inst.components.combat and inst.components.combat.target or FindClosestPlayerToInst(inst, TUNING.ANTLION_CAST_RANGE, true)
            if target and target:IsValid() and target:IsNear(inst, TUNING.ANTLION_CAST_RANGE) then
                inst.sandstormcdtask2hm = inst:DoTaskInTime(90, endsandstormcdtask)
                inst.summonwall2hm = nil
                inst.sg:GoToState("sinkhole_pre2hm")
                return
            end
        end
        oldOnEnteridle(inst, ...)
    end
    local oldOnEatidle = sg.states.eat.onenter
    sg.states.eat.onenter = function(inst, ...)
        if inst.hide2hm then
            local target = FindClosestPlayerToInst(inst, TUNING.ANTLION_CAST_RANGE, true)
            if target then
                inst.sg:GoToState("summonspikes", target)
            else
                if inst.appearcdtask2hm then
                    inst.appearcdtask2hm:Cancel()
                    inst.appearcdtask2hm = nil
                end
                inst.sg:GoToState("enterworld2hm")
            end
            return
        end
        oldOnEatidle(inst, ...)
    end
    local oldOnsummonwallidle = sg.states.summonwall.onenter
    sg.states.summonwall.onenter = function(inst, ...)
        if inst.hide2hm then
            local target = inst.components.combat.target or FindClosestPlayerToInst(inst, TUNING.ANTLION_CAST_RANGE, true)
            if target then
                inst.sg:GoToState("summonspikes", target)
                return
            else
                if inst.appearcdtask2hm then
                    inst.appearcdtask2hm:Cancel()
                    inst.appearcdtask2hm = nil
                end
                inst.sg:GoToState("enterworld2hm")
                return
            end
        end
        inst.summonwall2hm = true
        oldOnsummonwallidle(inst, ...)
        local x, y, z = inst.Transform:GetWorldPosition()
        for i, player in ipairs(AllPlayers) do
            if player:IsValid() and not IsEntityDeadOrGhost(player) and player:GetDistanceSqToPoint(x, y, z) < 144 then
                player:DoTaskInTime(14 * FRAMES, attackbyspikes, inst)
            end
        end
    end
    local Attack_Old = sg.events.doattack.fn
    sg.events.doattack.fn = function(inst, data, ...)
        if not (inst.sg:HasStateTag("busy") or inst.components.health:IsDead()) and not inst.attack2hmtask and not inst.hide2hm and inst.components.combat and
            inst.components.combat.target and inst:IsNear(inst.components.combat.target, 4) then
            inst.attack2hmtask = inst:DoTaskInTime(inst.components.combat.target:HasTag("player") and 12 or 6, endattacktask)
            inst:ForceFacePoint(inst.components.combat.target.Transform:GetWorldPosition())
            inst.sg:GoToState("attack2hm")
            return
        elseif inst.hide2hm and not inst.appearcdtask2hm then
            inst.sg:GoToState("enterworld2hm")
            return
        end
        return Attack_Old(inst, data, ...)
    end
    local summonspikes = sg.states.summonspikes.onenter
    sg.states.summonspikes.onenter = function(inst, ...)
        summonspikes(inst, ...)
        -- 攻击时尝试双发攻击
        if extraattacktarget == inst.sg.statemem.target then
            extraattacktarget = nil
            for index, player in ipairs(AllPlayers) do
                if player and player:IsValid() and player ~= inst.sg.statemem.target and player:IsNear(inst, TUNING.ANTLION_CAST_RANGE) and
                    player.components.health and not player:HasTag("playerghost") and not player.components.health:IsDead() then
                    extraattacktarget = player
                    player:DoTaskInTime(3 * FRAMES, attackbyspikes, inst)
                    break
                end
            end
        elseif extraattacktarget and extraattacktarget:IsValid() and not extraattacktarget:HasTag("playerghost") and extraattacktarget.components.health and
            not extraattacktarget.components.health:IsDead() then
            extraattacktarget:DoTaskInTime(3 * FRAMES, attackbyspikes, inst)
        else
            extraattacktarget = nil
        end
        -- 攻击时尝试两段攻击
        for index, player in ipairs(AllPlayers) do
            if player and player:IsValid() and player.townportaltalisman2hm and player.townportaltalisman2hm:IsValid() and player.components.health and
                not player:HasTag("playerghost") and not player.components.health:IsDead() then
                player:DoTaskInTime((player ~= inst.sg.statemem.target and player ~= extraattacktarget and 3 or 23) * FRAMES, attackbyspikes, inst)
            end
        end
    end
end)
-- 被攻击时记录一个额外目标
local function onattacked(inst, data)
    if data and data.attacker and data.attacker:IsValid() and extraattacktarget ~= inst.components.combat.target and
        not (inst.sg and inst.sg.statemem and data.attacker == inst.sg.statemem.target) then extraattacktarget = data.attacker end
end

-- 蚁狮本身配套改动
local function OnStartTeleporting(self, doer)
    if doer:HasTag("player") then
        if doer.components.talker ~= nil then doer.components.talker:ShutUp() end
        if doer.components.sanity ~= nil then doer.components.sanity:DoDelta(-TUNING.SANITY_HUGE) end
        if self.migration_data ~= nil then
            local data = self.migration_data
            if doer.Physics ~= nil then
                doer.Physics:Teleport(data.x, data.y, data.z)
            elseif doer.Transform ~= nil then
                doer.Transform:SetPosition(data.x, data.y, data.z)
            end
            self:ReceivePlayer(doer, self.inst)
            self.migration_data = nil
        end
    end
    return true
end
local function ondeath(inst)
    for _, player in ipairs(AllPlayers) do
        if player and player:IsValid() and player.townportaltalisman2hm and player.townportaltalisman2hm:IsValid() then
            player.townportaltalisman2hm.enablespawn = true
            player.townportaltalisman2hm:Remove()
            player.townportaltalisman2hm = nil
        end
    end
    if oldANTLION_CAST_RANGE and TUNING.ANTLION_CAST_RANGE ~= oldANTLION_CAST_RANGE then
        TUNING.ANTLION_MIN_ATTACK_PERIOD = TUNING.ANTLION_MIN_ATTACK_PERIOD * 2
        TUNING.ANTLION_CAST_MAX_RANGE = TUNING.ANTLION_CAST_MAX_RANGE / 3
        TUNING.ANTLION_CAST_RANGE = TUNING.ANTLION_CAST_RANGE / 3
        oldANTLION_CAST_RANGE = nil
    end
    if inst.hide2hm then
        inst.Physics:SetActive(true)
        inst:Show()
        inst.hide2hm = nil
    end
    if _antlion == inst then _antlion = nil end
end
local function onstopcombat(inst)
    if inst.hide2hm then
        inst.Physics:SetActive(true)
        inst:Show()
        inst.hide2hm = nil
    end
    if inst.appearcdtask2hm then
        inst.appearcdtask2hm:Cancel()
        inst.appearcdtask2hm = nil
    end
    if inst.disappearcdtask2hm then
        inst.disappearcdtask2hm:Cancel()
        inst.disappearcdtask2hm = nil
    end
    inst.firsthide2hm = nil
    inst.resethidetimer2hm = nil
    inst.resetsandcd2hm = nil
    inst.summonwall2hm = nil
    if inst.sandstormcdtask2hm then
        inst.sandstormcdtask2hm:Cancel()
        inst.sandstormcdtask2hm = nil
    end
    for _, player in ipairs(AllPlayers) do
        if player and player:IsValid() and player.townportaltalisman2hm and player.townportaltalisman2hm:IsValid() then
            player.townportaltalisman2hm:Remove()
            player.townportaltalisman2hm = nil
        end
    end
    if oldANTLION_CAST_RANGE and TUNING.ANTLION_CAST_RANGE ~= oldANTLION_CAST_RANGE then
        TUNING.ANTLION_MIN_ATTACK_PERIOD = TUNING.ANTLION_MIN_ATTACK_PERIOD * 2
        TUNING.ANTLION_CAST_MAX_RANGE = TUNING.ANTLION_CAST_MAX_RANGE / 3
        TUNING.ANTLION_CAST_RANGE = TUNING.ANTLION_CAST_RANGE / 3
        oldANTLION_CAST_RANGE = nil
    end
    if inst.sinkholetask2hm then
        inst.sinkholetask2hm:Cancel()
        inst.sinkholetask2hm = nil
    end
    if inst.sandstormupgradetask2hm then
        inst.sandstormupgradetask2hm:Cancel()
        inst.sandstormupgradetask2hm = nil
    end
    inst:RemoveTag("littlefencefx2hm")
    inst:RemoveTag("bigfencefx2hm")
    if inst.sandstormtask2hm then
        inst.sandstormtask2hm:Cancel()
        inst.sandstormtask2hm = nil
    end
    inst.sandstormtask2hmready = nil
    inst.allmiss2hm = nil
end
local function onload(inst)
    if inst.components.health and not inst.components.health:IsDead() then inst.components.health:DoDelta(inst.components.health.maxhealth * 0.15) end
end
local redskilltreeupdater = {IsActivated = falsefn}
AddPrefabPostInit("antlion", function(inst)
    inst:AddTag("flying")
    inst:AddTag("controlled_burner")
    if not TheWorld.ismastersim then return end
    inst.components.skilltreeupdater = redskilltreeupdater
    if not inst.teleporter2hm then
        inst.teleporter2hm = CreateEntity()
        inst.teleporter2hm.entity:AddTransform()
        inst.teleporter2hm.persists = false
        inst.teleporter2hm:AddComponent("teleporter")
        inst.teleporter2hm.components.teleporter.Activate = OnStartTeleporting
        inst.teleporter2hm.components.teleporter.offset = 4
        inst.teleporter2hm.components.teleporter.saveenabled = false
        inst.teleporter2hm.components.teleporter.travelcameratime = 0.9
        inst.teleporter2hm.components.teleporter.travelarrivetime = 0.8
        inst.teleporter2hm.entity:SetParent(inst.entity)
    end
    if not inst.components.groundpounder then
        inst:AddComponent("groundpounder")
        inst.components.groundpounder.destroyer = true
        inst.components.groundpounder.damageRings = 2
        inst.components.groundpounder.destructionRings = 2
        inst.components.groundpounder.platformPushingRings = 2
        inst.components.groundpounder.numRings = 3
    end
    table.insert(inst.components.groundpounder.noTags, "groundspike")
    SetOnLoad(inst, onload)
    local StartCombat = inst.StartCombat
    inst.StartCombat = function(inst, ...)
        StartCombat(inst, ...)
        _antlion = inst
        if inst.components.health then
            inst.components.health.fire_damage_scale = 0
            if not inst.components.health.avoidKill2hm then
                inst.components.health.avoidKill2hm = true
                local Kill = inst.components.health.Kill
                inst.components.health.Kill = nilfn
            end
        end
    end
    local StopCombat = inst.StopCombat
    inst.StopCombat = function(inst, ...)
        StopCombat(inst, ...)
        onstopcombat(inst)
        if _antlion == inst then _antlion = nil end
    end
    if inst.components.lootdropper then
        inst.components.lootdropper:AddChanceLoot("antliontrinket", 1)
        for _, value in ipairs(inst.components.lootdropper.randomloot or {}) do
            if value and value.prefab == "antliontrinket" then value.prefab = "trinket_26" end
        end
    end
    inst:ListenForEvent("death", ondeath)
    inst:ListenForEvent("onremove", ondeath)
    inst:ListenForEvent("attacked", onattacked)
end)

-- 瓜皮头需要沙滩玩具
if GetModConfigData("Turf-Raiser Helm Plant Tree Cone") then
    AddRecipePostInit("antlionhat", function(inst)
        for _, ingredient in ipairs(inst.ingredients) do
            if ingredient and ingredient.type == "townportaltalisman" and ingredient.amount then
                ingredient.amount = 10
                break
            end
        end
        table.insert(inst.ingredients, Ingredient("antliontrinket", 1))
        table.insert(inst.ingredients, Ingredient("orangegem", 2))
    end)
end

-- 沙滩玩具更难获得
local newloottable = {trinket_1 = 1, trinket_3 = 1, trinket_8 = 1, trinket_9 = 1, trinket_26 = .1}
AddPrefabPostInit("wetpouch", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.setupdata and inst.setupdata.lootfn and not inst.setupdata.oldsetupdata2hm then
        inst.setupdata.oldsetupdata2hm = inst.setupdata.lootfn
        inst.setupdata.lootfn = function(inst, doer, ...)
            local items = inst.setupdata.oldsetupdata2hm(inst, doer, ...)
            if items and items[1] == "antliontrinket" then
                local chance = 1.5
                if doer and doer.components.builder and doer.components.builder:KnowsRecipe("antlionhat") then
                    chance = 0.5
                elseif doer and doer.components.builder and doer.components.builder:KnowsRecipe("deserthat") then
                    chance = 0.875
                end
                if math.random() < chance then
				items[1] = weighted_random_choice(newloottable) end
            end
            return items
        end
    end
end)

-- 瓜皮头修复变慢
TUNING.ANTLIONHAT_REPAIR2hm = 10

-- 蚁狮20天CD复活
local function OnStopSummer(inst)
    if inst.components.timer and inst.components.timer:TimerExists("killed2hm") then
        inst.killed = true
        if inst.components.timer:TimerExists("spawndelay") then inst.components.timer:StopTimer("spawndelay") end
    end
end
local function OnspawnerTimerDone(inst, data) if data.name == "killed2hm" and inst.killed then inst.killed = nil end end
local function delayOnStopSummer(inst) inst:DoTaskInTime(0, OnStopSummer) end
local function OnspawnerInit(inst)
    inst:WatchWorldState("stopsummer", delayOnStopSummer)
    if not TheWorld.state.issummer then delayOnStopSummer(inst) end
    if inst._onantliondeath then
        local fn = inst._onantliondeath
        inst._onantliondeath = function(...)
            fn(...)
            if inst.components.timer and inst.killed then
                inst.components.timer:StopTimer("killed2hm")
                inst.components.timer:StartTimer("killed2hm", TUNING.ATRIUM_GATE_COOLDOWN)
            end
        end
    end
end
AddPrefabPostInit("antlion_spawner", function(inst)
    inst:ListenForEvent("timerdone", OnspawnerTimerDone)
    inst:DoTaskInTime(FRAMES, OnspawnerInit)
end)
AddPrefabPostInit("moonspider_spike", function(inst) inst:RemoveTag("groundspike") end)

-- 陷坑能减速骑牛玩家的移速
AddComponentPostInit("carefulwalker", function(self)
    local oldOnUpdate = self.OnUpdate
    self.OnUpdate = function(self, dt, ...)
        local mount = self.inst.components.rider and self.inst.components.rider:GetMount()
        if mount and not mount.components.locomotor.fasteronroad then
            self.change2hm = true
            self.fasteronroad2hm = mount.components.locomotor.fasteronroad
            mount.components.locomotor.fasteronroad = true 
        end
        oldOnUpdate(self, dt, ...)
        if mount and self.change2hm then
            self.change2hm = nil
            mount.components.locomotor.fasteronroad = self.fasteronroad2hm
        end
    end
end)