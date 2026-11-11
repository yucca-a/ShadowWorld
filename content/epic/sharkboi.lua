local UpvalueHacker = require("upvaluehacker2hm")
-- 血量、攻击力提升
TUNING.SHARKBOI_ARENA_SHRINK_TICK_TIME = TUNING.SHARKBOI_ARENA_SHRINK_TICK_TIME * 3
TUNING.SHARKBOI_HEALTH = TUNING.SHARKBOI_HEALTH * 1.5
TUNING.SHARKBOI_DAMAGE = TUNING.SHARKBOI_DAMAGE * 4 / 3
local shadownumber = GetModConfigData("Shadow World")

-- 大霜鲨冰面管理
AddPrefabPostInit("world", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.sharkboimanager then
        local oldMIN_ARENA_SIZE = inst.components.sharkboimanager.MIN_ARENA_SIZE
        inst.components.sharkboimanager.MIN_ARENA_SIZE = oldMIN_ARENA_SIZE * 1.8
        local oldSetArenaState = inst.components.sharkboimanager.SetArenaState
        inst.components.sharkboimanager.SetArenaState = function(self, state, ...)
            local oldstate = self.arena.state
            assert(oldstate < state) -- Only allow state values to go up and must change.
            if state == self.STATES.BOSSFIGHTING then
                if self.MIN_ARENA_SIZE >= 1.8 * 2.5 * TILE_SCALE then self.MIN_ARENA_SIZE = 1.7 * 2.5 * TILE_SCALE end
            end
            -- if self.inst.sharkboicre2hm and self.arena and self.arena.origin then -- Delete the fishing hole.
            --     self:StopShrinking()
            --     local x, _, z = self.arena.origin.x, self.arena.origin.y, self.arena.origin.z
            --     local fight_radius = math.min(
            --         self.arena.radius * 1.2,
            --         1.8 * 2.5 * TILE_SCALE
            --     )

            --     local fx = SpawnPrefab("crabking_ring_fx")
            --     fx.Transform:SetPosition(x,0,z)

            --     self:ForEachTileInBetween(self.arena.radius, fight_radius, self.CreateIceTileAtPoint)
            --     self:SetDesiredArenaRadius(fight_radius)
            --     self:StartShrinking()
            -- end
            oldSetArenaState(self, state, ...)
        end
    end
end)

-- 扩大冰面战场
local function hasselfarena(inst)
    local self = TheWorld.components.sharkboimanager
    return self and self.arena and self.arena and self.arena.sharkbois and self.arena.sharkbois[inst]
end

local function createnewicetile(world, inst)
    if world.components and world.components.sharkboimanager then
        local self = world.components.sharkboimanager
        if self.arena and self.arena.origin and self.arena.sharkbois and self.arena.sharkbois[inst] then -- Delete the fishing hole.
            local x, _, z = self.arena.origin.x, self.arena.origin.y, self.arena.origin.z
            local fight_radius = math.min(
                self.arena.radius + 1.8,
                6 * TILE_SCALE
            )

            local fx = SpawnPrefab("crabking_ring_fx")
            fx.Transform:SetPosition(x,0,z)
            if shadownumber then
                local fxs = TheSim:FindEntities(x, 0, z, 30, {"FX"})
                local _fxs = {}
                if fxs then
                    for i, v in pairs(fxs) do
                        if v and v.prefab == "deer_ice_circle" then
                            table.insert(_fxs, v)
                        end
                    end
                    if _fxs then
                        for i, v in pairs(_fxs) do
                            v:KillFX()
                        end
                    end
                end
            end
            self:StopShrinking()
            self:ForEachTileInBetween(self.arena.radius, fight_radius, self.CreateIceTileAtPoint)
            self:SetDesiredArenaRadius(fight_radius)
            self:StartShrinking()
        end
    end
end

-- 溯冬吐息
-- 向附近的玩家吐出寒息，被命中的目标会被击退、减速、降温并持续增加冰冻层数
local function SpawnCircleSpikes(inst, radius)
    if not radius or not inst then return end
    local center_x , center_y, center_z = inst.Transform:GetWorldPosition()
    local count = TWOPI * radius / 1.65
    count = count + 1
    if count < 1 then return end
    for i = 1, count do
        inst:DoTaskInTime((i-1) * FRAMES, function()

            local angle = (i / (count - 1)) * 2 * PI
            

            local x = center_x + radius * math.cos(angle)
            local z = center_z + radius * math.sin(angle)
            

            if TheWorld.Map:IsPassableAtPoint(x, 0, z) then

                local spike = SpawnPrefab("sharkboi_icespike")
                if not spike then return end
                spike.Transform:SetPosition(x, 0, z)
                

                local towards_center_angle = math.atan2(center_z - z, center_x - z) / DEGREES
                spike.Transform:SetRotation(towards_center_angle)

                if spike.SoundEmitter then
                    spike.SoundEmitter:PlaySound("meta3/sharkboi/ice_spike")
                end
            end
        end)
    end
end

local function EndSpeedMult(player)
    player.icestroefencespeedtask2hm = nil
    if player.components.locomotor ~= nil then player.components.locomotor:RemoveExternalSpeedMultiplier(player, "icestorespeedtask2hm") end
    if player.icestormtask2hm then
        player.icestormtask2hm:Cancel()
        player.icestormtask2hm = nil
    end
    if player.icestormattacktask2hm then
        player.icestormattacktask2hm:Cancel()
        player.icestormattacktask2hm = nil
    end
    player.icefencespeedlevel2hm = nil
end

local function stormtaskfn(inst)
    local fx = SpawnPrefab("sharkboi_icefx2hm")
    fx.entity:SetParent(inst.entity)
    local parent = fx.entity:GetParent()
    if parent ~= nil and parent:HasTag("littlefencefx2hm") then
        fx.AnimState:SetScale(5,4)
    elseif parent ~= nil and parent:HasTag("FX") then
        fx.AnimState:SetScale(5,2)
    elseif parent ~= nil and parent:HasTag("sharkboi") and not parent:HasTag("littlefencefx2hm") then
        fx.AnimState:SetScale(8, 6)
    end
end

local function icestormattacktaskfn(inst)
    if inst:IsValid() and inst.components.health and not inst.components.health:IsDead() then
        if inst.components.freezable then
            inst.components.freezable:AddColdness(((inst.icefencespeedlevel2hm or 1) / 3), 5 + ((inst.icefencespeedlevel2hm or 1) / 3) )
            inst.components.freezable:SpawnShatterFX()
        end
        if inst.components.temperature then
            local tmp = inst.components.temperature:GetCurrent()
            local num = inst.icefencespeedlevel2hm or 5
            if tmp - num <= -5 then num = tmp + 5 end
            inst.components.temperature:DoDelta(-num)
        end
    end
end

-- 最后一发大寒气强制击飞并无视冰面边缘碰撞击出战场
local function onhit_icefn(inst, player, disablecollision)
    if player and player:IsValid() and player.sg and player:HasTag("player") and player.components.health and not player.components.health:IsDead() and
        player.components.locomotor then
        -- local landed = false
        -- if not disablecollision and player.icestroefencespeedtask2hm then landed = true end
        if disablecollision then
            if inst:HasTag("no_rooted") then disablecollision = nil end
            player.sg:GoToState("knockback", {
            knocker = inst,
            radius = 3,
            strengthmult = 9,
            forcelanded = false,
            disableworldcollision2hm = disablecollision
        })
        else
            player:PushEvent("knockback", {
            knocker = inst,
            radius = 3,
            strengthmult = (player.components.inventory and player.components.inventory:ArmorHasTag("heavyarmor") or player:HasTag("heavybody")) and 1.5 or 3,
            forcelanded = true,
        })
        end
        if disablecollision then player.icefencespeedlevel2hm = 5 end
        player.icefencespeedlevel2hm = math.min((player.icefencespeedlevel2hm or 0) + 1, 5)
        if player.icestroefencespeedtask2hm then player.icestroefencespeedtask2hm:Cancel() end
        player.icestroefencespeedtask2hm = player:DoTaskInTime(8, EndSpeedMult)
        player.components.locomotor:SetExternalSpeedMultiplier(player, "icestorespeedtask2hm", 1 - math.min(player.icefencespeedlevel2hm * 0.1, 0.35))
        if not player.icestormattacktask2hm then player.icestormattacktask2hm = player:DoPeriodicTask(1, icestormattacktaskfn, 0) end
        if not player.icestormtask2hm then player.icestormtask2hm = player:DoPeriodicTask(2, stormtaskfn, 0) end
    end
end

local function dorangeattack(inst, onhit, disablecollision)
    local x, y, z = inst.Transform:GetWorldPosition()
    local speed = 20 + (inst.components.health and ((1 - inst.components.health:GetPercent()) * 15) or 5)
    for index, player in ipairs(AllPlayers) do
        if player and player:IsValid() and not player:HasTag("playerghost") and player:IsNear(inst, 36) then
            local proj = SpawnPrefab("ice_projectile")
            if disablecollision then proj:AddTag("littlefencefx2hm") end
            if not proj.components.weapon then proj:AddComponent("weapon") end
            if proj and proj.components.projectile then
                proj.persists = false
                proj.components.projectile:SetSpeed(speed)
                proj.components.projectile:SetRange(45)
                RemovePhysicsColliders(proj)
                proj.components.projectile:SetOnMissFn(proj.Remove)
                proj.components.projectile:SetOnHitFn(function(proj, inst, player)
                    onhit(inst, player, disablecollision)
                    proj:Remove()
                end)
                proj.components.projectile:SetHoming(false)
                local playerpos = player:GetPosition()
                if not proj.icestormtask2hm then proj.icestormtask2hm = proj:DoPeriodicTask(0.35, stormtaskfn, 0) end
                if proj.components.weapon then proj.components.weapon:SetOnAttack(nil) end
                if proj.components.weapon and proj.components.weapon.projectile_offset ~= nil then
                    local dir = (playerpos - Vector3(x, y, z)):Normalize()
                    dir = dir * proj.components.weapon.projectile_offset
                    proj.Transform:SetPosition(x + dir.x, y, z + dir.z)
                else
                    proj.Transform:SetPosition(inst.Transform:GetWorldPosition())
                end
                proj.components.projectile:Throw(inst, player, inst)
                if player.sg and player.sg:HasStateTag("moving") and (disablecollision or math.random() < 0.35) then
                    local time = math.sqrt(inst:GetDistanceSqToPoint(playerpos)) / speed
                    local radius = (player.components.locomotor and player.components.locomotor:GetRunSpeed() or 6) * time
                    local rot = player.Transform:GetRotation()
                    proj.components.projectile:RotateToTarget(playerpos + Vector3(math.cos(rot) * radius, 0, -math.sin(rot) * radius))
                end
            end
        end
    end
end

local function ShouldBeDefeated(inst)
	return inst.components.health.currenthealth <= inst.components.health.minhealth
end

local function ShakeCasting(inst) ShakeAllCameras(CAMERASHAKE.VERTICAL, .3, .02, 1, inst, 30) end

-- 溯冬吐息状态图
AddStategraphState("sharkboi", State {
    name = "icestrom_pre2hm",
    tags = {"busy", "attack", "nosleep", "nofreeze", "noelectrocute", "icestroming2hm"},
    onenter = function(inst, target)
        inst.components.locomotor:Stop()
        inst.AnimState:PlayAnimation("ice_summon")
        if target and target:IsValid() then
            inst.sg.statemem.target = target
            inst.sg.statemem.targetpos = target:GetPosition()
            inst:ForceFacePoint(inst.sg.statemem.targetpos)
        end
        if not inst.icestromupgradetask2hm then
            inst:AddTag("littlefencefx2hm")
            inst.icestromupgradetask2hm = inst:DoPeriodicTask(2, stormtaskfn, 0)
            inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, 0.8, "icestromattack2hm")
        end
        if inst.components.childspawner2hm and inst.components.childspawner2hm.numchildrenoutside > 0 then
            for k, v in pairs(inst.components.childspawner2hm.childrenoutside) do
                if v and v:IsValid() and not v.changeswp2hm then
                    v:PushEvent("icestrom")
                end
            end
        end
    end,
    timeline = {
        FrameEvent(10, function(inst) inst.SoundEmitter:PlaySound(inst.voicepath.."attack_small") end),
        FrameEvent(35, function(inst)
            ShakeCasting(inst)
            inst.SoundEmitter:PlaySound(inst.voicepath.."attack_big")
            inst.sg.statemem.target = nil
            inst.sg.statemem.targetpos = nil
            SpawnCircleSpikes(inst, 4)
            createnewicetile(TheWorld, inst)
        end),
    },

    events = {
        EventHandler("animover", function(inst)
            if inst.AnimState:AnimDone() and ShouldBeDefeated(inst) then
                inst.sg:GoToState("icestrom_pst2hm")
                return
            end
            if inst.AnimState:AnimDone() then inst.sg:GoToState("icestrom_loop2hm") end
        end)
    }
})

AddStategraphState("sharkboi", State {
    name = "icestrom_loop2hm",
    tags = {"busy", "attack", "nosleep", "nofreeze", "noelectrocute", "icestroming2hm"},
    onenter = function(inst, times)
        inst.components.locomotor:Stop()
        if not inst.icestromtask2hm then inst.icestromtask2hm = inst:DoTaskInTime(60, function() inst.icestromtask2hm = nil end) end
        if inst.icestromupgradetask2hm then
            inst:RemoveTag("littlefencefx2hm")
            inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, 0.4, "icestromattack2hm")
            if not inst.icestromfx2hm then
                inst.icestromfx2hm = true
                stormtaskfn(inst)
            end
        end
        if not inst.icestromtask2hm then
            inst.sg.statemem.times2hm = nil
            inst.sg:GoToState("icestrom_pst2hm")
            return
        end
        if inst.components.childspawner2hm and inst.components.childspawner2hm.numchildrenoutside > 0 then
            for k, v in pairs(inst.components.childspawner2hm.childrenoutside) do
                if v and v:IsValid() and not v.changeswp2hm then
                    v:PushEvent("icestrom")
                end
            end
        end
        inst.sg.statemem.times2hm = times or 0
        inst.sg.statemem.target = FindClosestPlayerToInst(inst, 30, true)
        if not inst.sg.statemem.target then 
            inst.sg:GoToState("restroe_pre2hm", inst.sg.statemem.times2hm)
            return
        end
        inst.AnimState:PlayAnimation("taunt")
    end,
    timeline = {
        TimeEvent(18 * FRAMES, function(inst)
            if inst.sg.statemem.target then
                if inst.icestromupgradetask2hm then
                    local times = math.floor(math.max(1 - (inst.components.health:GetPercent() or 1) ,0) * 5) + 6
                    if not ShouldBeDefeated(inst) and inst.sg.statemem.times2hm >= times then 
                        dorangeattack(inst, onhit_icefn, true)
                    else
                        dorangeattack(inst, onhit_icefn) 
                    end
                    inst.sg.statemem.times2hm = inst.sg.statemem.times2hm + 1
                end
                ShakeCasting(inst)
                inst.SoundEmitter:PlaySound("rifts4/mimic/item_become_poof", "sharkboi_icefx2hm")
                inst.SoundEmitter:SetVolume("sharkboi_icefx2hm", 2)
                inst.SoundEmitter:PlaySound("meta3/sharkboi/attack_small")
                inst.SoundEmitter:PlaySound("meta3/sharkboi/swipe_tail")
            end
        end),
        TimeEvent(30 * FRAMES, function(inst)
            inst.AnimState:SetDeltaTimeMultiplier(1.5)
        end),
    },
    events = {
        EventHandler("animover", function(inst)
            if inst.AnimState:AnimDone() then
                inst.AnimState:SetDeltaTimeMultiplier(1)
                local times = math.floor(math.max(1 - (inst.components.health:GetPercent() or 1) ,0) * 5) + 6
                if inst.sg.statemem.times2hm > times or ShouldBeDefeated(inst) then
                    inst.sg:GoToState("icestrom_pst2hm", inst.sg.statemem.target)
                else
                    inst.sg:GoToState("icestrom_loop2hm", inst.sg.statemem.times2hm)
                end
            end
        end),
        EventHandler("attacked", function(inst, data)
            if data and data.attacker and 
            not (data.weapon and (data.weapon.components.projectile or 
            (data.weapon.components.weapon and data.weapon.components.weapon.projectile)))
            then
                local attacker = data.attacker
                if attacker.components.freezable then
                    attacker.components.freezable:AddColdness(1.75, 5)
                    attacker.components.freezable:SpawnShatterFX()
                end
                if attacker.components.temperature then
                    local tmp = attacker.components.temperature:GetCurrent()
                    local num = 5
                    if tmp - num <= -5 then num = tmp + 5 end
                    attacker.components.temperature:DoDelta(-num)
                end
            end
        end),
    },

    onexit = function(inst)
        inst.AnimState:SetDeltaTimeMultiplier(1)
    end
})

AddStategraphState("sharkboi", State {
    name = "icestrom_pst2hm",
    tags = {"busy", "attack", "nosleep", "nofreeze", "noelectrocute", "icestroming2hm"},
    onenter = function(inst, target)
        if inst.icestromfx2hm == true then inst.icestromfx2hm = nil end
        if inst.icestromtask2hm then
            inst.icestromtask2hm:Cancel()
            inst.icestromtask2hm = nil
        end
        if inst.icestromupgradetask2hm then
            inst.icestromupgradetask2hm:Cancel()
            inst.icestromupgradetask2hm = nil
            inst:RemoveTag("littlefencefx2hm")
        end
        inst.components.combat.externaldamagetakenmultipliers:RemoveModifier(inst, "icestromattack2hm")
        if not target then target = FindClosestPlayerToInst(inst, 30, true) end
        if target and target:IsValid() then
            local targetpos = target:GetPosition()
            inst:ForceFacePoint(targetpos)
        end
        inst.AnimState:PlayAnimation("flex")
    end,
    timeline = {
        TimeEvent(10 * FRAMES, function(inst)
            inst.sg:RemoveStateTag("busy")
            inst.sg:RemoveStateTag("nosleep")
            inst.sg:RemoveStateTag("nofreeze")
            inst.sg:RemoveStateTag("noelectrocute")
        end)
    },
    events = {EventHandler("animover", function(inst) if inst.AnimState:AnimDone() then inst.sg:GoToState("idle") end end)}
})

-- 目标太远时或无敌意时趴下休息回血
AddStategraphState("sharkboi", State {
    name = "restroe_pre2hm",
    tags = {"busy", "nosleep", "nofreeze", "noelectrocute"},
    onenter = function(inst, times)
        inst.sg.statemem.times2hm = times
        inst.components.locomotor:Stop()
        inst.AnimState:PlayAnimation("defeated_pre")
    end,
    timeline = {
        TimeEvent(10 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("meta3/sharkboi/hit")
        end)
    },
    events = {EventHandler("animover", function(inst)
        inst.SoundEmitter:PlaySound("meta3/sharkboi/hit")
        if inst.AnimState:AnimDone() then
            inst.sg:GoToState("restroe_loop2hm", inst.sg.statemem.times2hm) 
        end 
    end)}
})

AddStategraphState("sharkboi", State {
    name = "restroe_loop2hm",
    tags = {"busy", "attack", "nosleep", "nofreeze", "noelectrocute"},
    onenter = function(inst, times)
        inst.sg.statemem.times2hm = times
        inst.components.locomotor:Stop()
        if (inst.sg.statemem.times2hm ~= true and not inst.icestromtask2hm) or inst.components.health:GetPercent() >= 1 then
            inst.sg.statemem.times2hm = nil
            inst.sg:GoToState("restroe_pst2hm")
            return
        end
        inst.components.health:SetAbsorptionAmount(0.91)
        inst.AnimState:PlayAnimation("defeated_loop")
    end,
    timeline = {
        TimeEvent(10 * FRAMES, function(inst)
            if not inst.components.health:IsDead() then inst.components.health:DoDelta(25) end
            inst.SoundEmitter:PlaySound("meta3/sharkboi/hit")
        end),
        TimeEvent(20 * FRAMES, function(inst)
            if not inst.components.health:IsDead() then inst.components.health:DoDelta(25) end
            inst.SoundEmitter:PlaySound("meta3/sharkboi/hit")
        end)
    },
    events = {EventHandler("animover", function(inst)
        if not inst.components.health:IsDead() then inst.components.health:DoDelta(25) end
        inst.SoundEmitter:PlaySound("meta3/sharkboi/hit")
        local target = inst.components.combat and inst.components.combat.target or FindClosestPlayerToInst(inst, 15, true)
        if inst.AnimState:AnimDone() then
            if inst:HasTag("hostile") and target then
                local x1, y1, z1 = target.Transform:GetWorldPosition()
                local self = TheWorld.components.sharkboimanager
                if ((inst.icestromtask2hm or not hasselfarena(inst)) and inst:IsNear(target, 15)) or (not inst.icestromtask2hm and hasselfarena(inst) and self:IsPointInArena(x1, y1, z1)) then
                    inst.sg:GoToState("restroe_pst2hm", inst.sg.statemem.times2hm)
                else
                    inst.sg:GoToState("restroe_loop2hm", inst.sg.statemem.times2hm) 
                end
            else
                inst.sg:GoToState("restroe_loop2hm", inst.sg.statemem.times2hm) 
            end
        end 
    end)},

    onexit = function(inst)
        inst.components.health:SetAbsorptionAmount(0)
    end
})

AddStategraphState("sharkboi", State {
    name = "restroe_pst2hm",
    tags = {"busy", "attack", "nosleep", "nofreeze", "noelectrocute"},
    onenter = function(inst, times)
        inst.components.locomotor:Stop()
        inst.sg.statemem.times2hm = times
        inst.AnimState:PlayAnimation("defeated_pst")
    end,
    timeline = {
        TimeEvent(10 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("meta3/sharkboi/hit")
        end),
        TimeEvent(20 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("meta3/sharkboi/hit")
        end)
    },
    events = {EventHandler("animover", function(inst)
        if inst.AnimState:AnimDone() then
            if type(inst.sg.statemem.times2hm) == "number" then
                inst.sg:GoToState("icestrom_loop2hm", inst.sg.statemem.times2hm)
            elseif inst.sg.statemem.times2hm == true then
                inst.sg:GoToState("idle") 
            else
                inst.sg:GoToState("icestrom_pst2hm") 
            end
        end 
    end)}
})

-- 状态图管理
local function endicestormcdtask(inst) inst.icestormcdtask2hm = nil end
AddStategraphPostInit("sharkboi", function(sg)
    if sg.states and sg.states.idle then
        local oldidle = sg.states.idle.onenter
        sg.states.idle.onenter = function(inst, ...)
            -- 溯冬吐息期间影子制造冰裂隙干扰目标
            if inst:HasTag("swc2hm") and inst.swp2hm and inst.swp2hm.sg:HasStateTag("icestroming2hm") then
                inst.sg:GoToState("icestrom_fissure2hm")
                return
            end
            local x, y, z = inst.Transform:GetWorldPosition()
            local self = TheWorld.components.sharkboimanager
            -- 不处于自己的冰面战场会强制钻地并传送会自己的战场中心了
            if not ShouldBeDefeated(inst) and not inst:HasTag("swc2hm") and hasselfarena(inst) and not self:IsPointInArena(x, y, z) then
                inst.forcedig2hm = true
                inst.sg:GoToState("standing_dive_jump_pre")
                return
            end
            -- 低于80%生命值后释放溯冬吐息
            if not inst:HasTag("swc2hm") and inst:HasTag("hostile") and not inst.icestormcdtask2hm and inst.components.health and inst.components.health:GetPercent() < 0.8 then
                local target = inst.components.combat and inst.components.combat.target or FindClosestPlayerToInst(inst, 24, true)
                if target and target:IsValid() and target:HasTag("player") and target:IsNear(inst, 30) then
                    inst.icestormcdtask2hm = inst:DoTaskInTime(90, endicestormcdtask)
                    inst.sg:GoToState("icestrom_pre2hm", target)
                    return
                end
            -- 目标处于无效冰面战场或无敌意且未满血时趴下回血
            elseif not inst:HasTag("swc2hm") and not (inst.sg:HasStateTag("busy") or inst.sg:HasStateTag("sleeping")) 
            and not (ShouldBeDefeated(inst) or inst.components.trader) and inst.components.health and inst.components.health:GetPercent() < 1 then
                local target = inst.components.combat and inst.components.combat.target
                if not target then
                    inst.sg:GoToState("restroe_pre2hm", true)
                    return
                end
            end
            oldidle(inst, ...)
        end
        local oldfin_stop = sg.states.fin_stop.onenter
        sg.states.fin_stop.onenter = function(inst, ...)
            if not inst:HasTag("swc2hm") and not (inst.sg:HasStateTag("busy") or inst.sg:HasStateTag("sleeping")) 
            and not inst.components.trader and inst.components.health and inst.components.health:GetPercent() < 1 then
                local target = inst.components.combat and inst.components.combat.target
                local x, y, z = inst.Transform:GetWorldPosition()
                local self = TheWorld.components.sharkboimanager
                -- 无目标时别再呆在地下了
                if not target then
                    inst.sg:GoToState("dive_jump_delay")
                    return
                -- 强制传送
                -- elseif self and self.arena and self.arena.origin and self.arena.sharkbois 
                -- and self.arena.sharkbois[inst] and not self:IsPointInArena(x, y, z) then
                --     local _x, _y, _z = self.arena.origin.x, self.arena.origin.y, self.arena.origin.z
                --     inst.Transform:SetPosition(_x, 0, _z)
                --     inst.sg:GoToState("dive_jump_delay")
                end
            end
            oldfin_stop(inst, ...)
        end
    end
    if sg.events and sg.events.doattack then
        local oldfn = UpvalueHacker.GetUpvalue(sg.events.doattack.fn, "ChooseAttack")
        if oldfn then
            local newfn = function(inst, target, ...)
                target = target or inst.components.combat.target
                if target and not target:IsValid() then
                    target = nil
                end
                -- 影子状态管理
                if inst:HasTag("swc2hm") then
                    if not (inst.swp2hm and inst.swp2hm.icestromtask2hm) and not inst.sg:HasStateTag("busy") and inst.components.timer and not inst.components.timer:TimerExists("standing_dive_2hmcd") 
                    and hasselfarena(inst.swp2hm) then
                        inst.sg:GoToState("standing_dive_jump_pre")
                        return true
                    elseif target and inst:IsNear(target, 15 + target:GetPhysicsRadius(0)) then
                        inst.sg:GoToState("attack1", target)
                        return true
                    end
                    return false
                -- 非玩家目标只释放普通攻击
                else
                    if not inst.sg:HasStateTag("fin") and target and not target:HasTag("player") and inst:IsNear(target, TUNING.SHARKBOI_MELEE_RANGE + target:GetPhysicsRadius(0)) then
                        inst.sg:GoToState("attack1", target)
                        return true
                    end
                    return oldfn(inst, target, ...)
                end
            end
            UpvalueHacker.SetUpvalue(sg.events.doattack.fn, newfn, "ChooseAttack")
        end
    end
end)

-- 脱加载后清理数据、恢复自身血量
local function onsleep(inst)
    if inst.icestromfx2hm == true then inst.icestromfx2hm = nil end
    if inst.icestormcdtask2hm then
        inst.icestormcdtask2hm:Cancel()
        inst.icestormcdtask2hm = nil
    end
    if inst.icestromtask2hm then
        inst.icestromtask2hm:Cancel()
        inst.icestromtask2hm = nil
    end
    if inst.icestromupgradetask2hm then
        inst.icestromupgradetask2hm:Cancel()
        inst.icestromupgradetask2hm = nil
        inst:RemoveTag("littlefencefx2hm")
    end
    inst.components.combat.externaldamagetakenmultipliers:RemoveModifier(inst, "icestromattack2hm")
    if not inst.components.trader then
        inst.components.health:StartRegen(75, 1)
    end
end

local function onwake(inst)
    inst.components.health:StopRegen()
end

-- 攻击附带寒气波
local function IsTargetInFront(inst, target, arc)
	if not (target and target:IsValid()) then
		return false
	end
	local rot = inst.Transform:GetRotation()
	local rot1 = inst:GetAngleToPoint(target.Transform:GetWorldPosition())
	return DiffAngle(rot, rot1) < (arc or 180) / 2
end

local function iceattackfx(inst, _math, hasrot, final)
    if inst and inst:IsValid() and inst.components.combat then
        local target = inst.sg.statemem.target or (inst.components.combat and inst.components.combat.target) or FindClosestPlayerToInst(inst, 30, true)
        if target then
            local x, y, z = inst.Transform:GetWorldPosition()
            local rot = inst.Transform:GetRotation()
            local proj = SpawnPrefab("sharkboi_attackfx2hm")
            if final then proj.final = true end
            if _math then
                rot = math.random() * 360
                proj.components.projectile.launchangle = rot
            elseif hasrot or not IsTargetInFront(inst, target, 150) then
                proj.components.projectile.launchangle = rot
            end
            proj:DoPeriodicTask(2, stormtaskfn, 0)
            if proj then
                proj.Transform:SetPosition(x,y,z)
                proj.Transform:SetRotation(rot)
                proj.components.projectile:Throw(inst, target, proj)
            end
        end
    end
end

-- 钻出和钻入冰面都会在冰面上留下冰冻裂隙，已存在裂隙则会使其喷发寒气魔法
AddPrefabPostInit("deer_ice_circle", function(inst)
    inst:AddTag("ice_circle2hm")
end)

local removetime = 20
local function frozenfissure(inst)
    if inst and inst:IsValid() and not shadownumber then
        local x, y, z = inst.Transform:GetWorldPosition()
        local fxs = TheSim:FindEntities(x, 0, z, 3, {"FX"})
        local hascrack
        if fxs then
            for i, v in pairs(fxs) do
                if v and v.prefab == "deer_ice_circle" then
                    if v.task2hm then
                        v.task2hm:Cancel()
                        v.task2hm = nil
                    end
                    if not v.fx then
                        v:TriggerFX()
                    end
                    v.task2hm = v:DoTaskInTime(removetime, v.KillFX)
                    hascrack = true
                end
            end
        end
        if hascrack then return end
        local icecrack = SpawnPrefab("deer_ice_circle")
        icecrack.Transform:SetPosition(x, 0, z)
        icecrack.task2hm = icecrack:DoTaskInTime(removetime, icecrack.KillFX)
    end
end

local attackstate = {
    attack1 = 2, 
    attack2 = 1, 
    attack3 = 4,
    ice_summon = 2,
}

AddStategraphPostInit("sharkboi", function(sg)
    if sg.states and sg.states.dive_dig_pre then
        local olddive_dig_pre = sg.states.dive_dig_pre.onenter
        sg.states.dive_dig_pre.onenter = function(inst, ...)
            olddive_dig_pre(inst, ...)
            frozenfissure(inst)
        end
        -- 快速钻入冰面、钻入一定次数或溯冬吐息冷却好了强制出冰
        if sg.states.dive_dig_pre.events and sg.states.dive_dig_pre.events.animover then
            local oldfn = sg.states.dive_dig_pre.events.animover.fn
            sg.states.dive_dig_pre.events.animover.fn = function(inst, ...)
                -- 影子状态管理
                if inst:HasTag("swc2hm") and inst.AnimState:AnimDone() then
                    inst.sg:GoToState("dive_dig_pst2hm")
                    return
                end
                inst.dive_dig2hm = inst.dive_dig2hm or 0
                if not inst.forcedig2hm and ((not inst.icestormcdtask2hm and inst.components.health and inst.components.health:GetPercent() < 0.8) or inst.dive_dig2hm >= 5 
                or (inst.components.combat and not inst.components.combat.target)) then
                    if inst.AnimState:AnimDone() then
                        inst.sg:GoToState("dive_dig_stun")
                    end
                elseif inst.dive_dig2hm <= (1 + math.floor(math.max(1 - (inst.components.health:GetPercent() or 1) ,0) * 5)) then
                    if inst.AnimState:AnimDone() then
                        inst.dive_dig2hm = inst.dive_dig2hm + 1
                        inst.sg:GoToState("dive_dig_pst")
                    end
                else
                    inst.dive_dig2hm = inst.dive_dig2hm + 1
                    oldfn(inst, ...)
                end
            end
        end
    end
    -- 强制传送
    if sg.states and sg.states.dive_dig_pst then
        if sg.states.dive_dig_pst.events and sg.states.dive_dig_pst.events.animover then
            local oldfn = sg.states.dive_dig_pst.events.animover.fn
            sg.states.dive_dig_pst.events.animover.fn = function(inst, ...)
                if inst.AnimState:AnimDone() and inst.forcedig2hm then
                    inst.forcedig2hm = nil
                    local self = TheWorld.components.sharkboimanager
                    local x, _, z = self.arena.origin.x, self.arena.origin.y, self.arena.origin.z
                    inst.Transform:SetPosition(x,0,z)
                end
                oldfn(inst, ...)
            end
        end
    end
    -- 生成冰裂隙
    if sg.states and sg.states.dive_jump_pre then
        local olddive_jump_pre = sg.states.dive_jump_pre.onenter
        sg.states.dive_jump_pre.onenter = function(inst, ...)
            olddive_jump_pre(inst, ...)
            frozenfissure(inst)
        end
    end
    if sg.states and sg.states.dive_dig_stun then
        local olddive_dig_stun = sg.states.dive_dig_stun.onenter
        sg.states.dive_dig_stun.onenter = function(inst, ...)
            inst.dive_dig2hm = nil
            olddive_dig_stun(inst, ...)
        end
    end
    -- 普通攻击附带寒气波
    if sg.states then
        for i, v in pairs(attackstate) do
            if sg.states[i] and sg.states[i].timeline and sg.states[i].timeline[v] then
                local oldfn = sg.states[i].timeline[v].fn
                sg.states[i].timeline[v].fn = function(inst, ...)
                    oldfn(inst, ...)
                    if i == "ice_summon" then
                        iceattackfx(inst, nil, true)
                    else
                        if shadownumber then
                            if not inst:HasTag("swc2hm") and i == "attack3" then
                                iceattackfx(inst, nil, nil, true)
                            elseif inst:HasTag("swc2hm") then
                                iceattackfx(inst, nil, nil, i == "attack3")
                            end
                        else
                            iceattackfx(inst, nil, nil, i == "attack3")
                        end
                    end
                end
            end
        end
    end
    -- 冲刺发射寒气波
    if sg.states and sg.states.torpedo then
        local oldupdate = sg.states.torpedo.onupdate
        sg.states.torpedo.onupdate = function(inst, ...)
            if not inst.sg.statemem.icefxtime2hm then
                iceattackfx(inst, true)
            end
            inst.sg.statemem.icefxtime2hm = (inst.sg.statemem.icefxtime2hm or 0) + 1
            if inst.sg.statemem.icefxtime2hm >= 5 then
                inst.sg.statemem.icefxtime2hm = nil
            end
            oldupdate(inst, ...)
        end
    end
end)

--- 对冰冻目标造成1.5倍伤害，穿戴鳞甲减免
local function freeze_target(target)
    local multiplier = 1
    if target and target:IsValid() and target.components.freezable and target.components.freezable:IsFrozen() then
        multiplier = 1.5
        local body = target.components.inventory and target.components.inventory:GetEquippedItem(EQUIPSLOTS.BODY)
        if body and body.prefab == "armordragonfly" then multiplier = 1 end
    end
    return multiplier
end

local function savaandload(inst)
    local oldonsave = inst.OnSave
    inst.OnSave = function(inst, data, ...)
        data.dropcore2hm = inst.dropcore2hm
        if (inst.stock and inst.stock < 5) then
            data.stock_ = inst.stock
        elseif inst.stock_ then
            data.stock_ = inst.stock_
        end
        if oldonsave then oldonsave(inst, data, ...) end
    end
    local oldOnLoad = inst.OnLoad
    inst.OnLoad = function(inst, data, ...)
        if data and data.dropcore2hm then
            inst.dropcore2hm = data.dropcore2hm
        end
        if data and data.stock_ then
            inst.stock_ = data.stock_
        end
        if oldOnLoad then oldOnLoad(inst, data, ...) end
    end
end
local function onload(inst, data)
    if data and data.dropcore2hm then
        inst.dropcore2hm = true
    end
end

-- 影分身相关
-- 影子额外构造函数
local brainPG = require("brains/sharkboibrain2hm")
local function swc2hmfn(child)
	-- 设置新脑部文件
	child:SetBrain(brainPG)
    -- 设置速度
    if child.components.locomotor then
        child.components.locomotor.runspeed = TUNING.DAYWALKER_RUNSPEED * 1.2
    end
	-- 伤害减免
	if child.components.health then
		child.components.health:SetAbsorptionAmount(0.5)
	end
    -- 攻击间隔、范围增加
    child.components.combat:RestartCooldown()
    child.components.combat:SetAttackPeriod(GetRandomMinMax(9,12))
    child:DoTaskInTime(2, function() child.components.combat:ResetCooldown() end)
    child.components.combat:SetRange(15)
    child.components.timer:StartTimer("standing_dive_2hmcd", removetime)
    -- 无法被催眠和冰冻
    child:RemoveComponent("sleeper")
    child:RemoveComponent("freezable")
	-- 移除物理碰撞，无法落水，无法拉脱加载
	if child.components.playerprox2hm then
		child.components.playerprox2hm:SetDist(30, 50)
	end
	RemovePhysicsColliders(child)
	child:RemoveComponent("drownable")
end

-- 本体受到非玩家目标伤害超75则转移仇恨给分身
local function canshadowhelpself(inst, data)
    if data and data.damage and data.damage >= 75 and data.attacker and not data.attacker:HasTag("player") and not inst.canshadowhelpselftask then
        inst.canshadowhelpselftask = inst:DoTaskInTime(3,function() inst.canshadowhelpselftask = nil end)
        if inst.components.childspawner2hm and inst.components.childspawner2hm.numchildrenoutside > 0 and inst.components.combat then
            for k, v in pairs(inst.components.childspawner2hm.childrenoutside) do
                if v and v:IsValid() and not v.changeswp2hm and inst.components.health and inst.components.health:GetPercent() < 0.7 then
                    inst:PushEvent("transfercombattarget", v)
                    break
                end
            end
        end
    end
end

AddPrefabPostInit("sharkboi", function(inst)
	if not TheWorld.ismastersim then return end
	inst.swc2hmfn = swc2hmfn
    inst.shadowcantout2hm = true
    if not inst.components.knownlocations then inst:AddComponent("knownlocations") end
    inst:ListenForEvent("attacked", canshadowhelpself)
end)

-- 影子在战场上随机位置制造裂隙
local function spawnice_circle(x, z, shorttime, target)
    if target and target:IsValid() and target.swp2hm and (target.swp2hm.icestromtask2hm or target.swp2hm.sg:HasStateTag("icestroming2hm")) and not shorttime then return end
    local icecrack = SpawnPrefab("deer_ice_circle")
    icecrack.Transform:SetPosition(x, 0, z)
    icecrack.task2hm = icecrack:DoTaskInTime(shorttime and 5 or (removetime + 40), icecrack.KillFX)
end

local scale = 0.4
local function frozenfissuretask(x, z, num, inst)
    local fx = SpawnPrefab("deerclops_icelance_ping_fx")
    if not TheNet:IsDedicated() then
        fx.disc.Remove(fx.disc)
	end
    fx.AnimState:SetScale(scale,scale)
    fx:Hide()
    fx.Transform:SetPosition(x, 0, z)
    local time = math.random() * 0.5 + num
    fx:DoTaskInTime(time, function()
        if inst and inst:IsValid() and inst.swp2hm and (inst.swp2hm.icestromtask2hm or inst.swp2hm.sg:HasStateTag("icestroming2hm")) and not shorttime then return end
        fx:Show() 
    end)
    fx.task2 = fx:DoTaskInTime(1 + time, function()
        spawnice_circle(x,z, nil, inst)
        fx:KillFX()
    end)
end

local step = 10
local R = 8.5
local function randomfrozenfissure(inst)
    if TheWorld.components and TheWorld.components.sharkboimanager then
        local self = TheWorld.components.sharkboimanager
        if inst and inst:IsValid() and self.arena and self.arena.origin and self.arena.sharkbois and self.arena.sharkbois[inst.swp2hm] then -- Delete the fishing hole.
            local start_x , start_z = self.arena.origin.x , self.arena.origin.z
            for i = 0, self.arena.radius, R do
                if i == 0 then
                    local random_radius = math.random(0,4)
                    local random_angle = math.random() * TWOPI
                    local _x = start_x + math.cos(random_angle) * random_radius
                    local _z = start_z + math.sin(random_angle) * random_radius
                    if not TheWorld.Map:IsOceanAtPoint(_x,0,_z, false, true) and #TheSim:FindEntities(_x, 0, _z, step / 2, {"ice_circle2hm", "FX"}) <= 0 then
                        frozenfissuretask(_x, _z, i, inst)
                    end
                else 
                    local _i = math.max(i, step/2)
                    local angle = 2 * math.asin(step / (2 * _i))
                    local num = 1
                    if angle then num = math.min(math.floor(TWOPI / angle), 20) end
                    for a = 0, num - 1 do
                        local random_radius = math.random(0,4)
                        local random_angle = math.random() * TWOPI
                        local _x = start_x + math.cos(a * angle) * _i + math.cos(random_angle) * random_radius
                        local _z = start_z + math.sin(a * angle) * _i + math.sin(random_angle) * random_radius
                        if not TheWorld.Map:IsOceanAtPoint(_x,0,_z, false, true) and #TheSim:FindEntities(_x, 0, _z, step / 2, {"ice_circle2hm", "FX"}) <= 0 then
                            frozenfissuretask(_x, _z, i/R, inst)
                        end
                    end
                end
            end
        end
    end
end

-- 激活战场上所有的裂隙
local function resetfissuretask(inst, target, num, final)
    local fx = SpawnPrefab("deerclops_icelance_ping_fx")
    fx.AnimState:SetScale(0.75,0.75)
    if not TheNet:IsDedicated() then
        fx.disc.Remove(fx.disc)
	end
    local x,y,z = target.Transform:GetWorldPosition()
    fx:Hide()
    fx.Transform:SetPosition(x, 0, z)
    local time = num * 0.5
    fx:DoTaskInTime(time, function()
        if inst and inst:IsValid() and inst.swp2hm and (inst.swp2hm.icestromtask2hm or inst.swp2hm.sg:HasStateTag("icestroming2hm")) then return end
        fx:Show() 
    end)
    fx.task2 = fx:DoTaskInTime(1 + time, function()
        if final and inst and inst:IsValid() and inst.sg:HasStateTag("digging") then
            inst.Transform:SetPosition(x, 0, z)
            inst.sg:GoToState("spawn2hm") 
        end
        if target and target:IsValid() then
            if target.task2hm then
                target.task2hm:Cancel()
                target.task2hm = nil
            end
            if not target.fx then
                target:TriggerFX()
            end
            target.task2hm = target:DoTaskInTime(removetime, target.KillFX)
        end
        fx:KillFX()
    end)
end
local function allfrozenfissure(inst)
    if TheWorld.components and TheWorld.components.sharkboimanager then
        local self = TheWorld.components.sharkboimanager
        if inst and inst:IsValid() and self.arena and self.arena.origin and self.arena.sharkbois and self.arena.sharkbois[inst.swp2hm] then -- Delete the fishing hole.
            local x, z = self.arena.origin.x, self.arena.origin.z
            local fxs = TheSim:FindEntities(x, 0, z, 30, {"FX"})
            local _fxs = {}
            if fxs then
                for i, v in pairs(fxs) do
                    if v and v:IsValid() and v.prefab == "deer_ice_circle" then
                        table.insert(_fxs, v)
                    end
                end
                if _fxs then
                    for _i = 1, #(_fxs), 1 do
                        local v = _fxs[_i]
                        resetfissuretask(inst, v, _i, _i == #(_fxs))
                    end
                end
            end
        end
    end
end

-- 钻地后状态处理
-- 钻地后停用脑部和碰撞体积，退出状态再重启脑部
AddStategraphState("sharkboi", State{
    name = "dive_dig_pst2hm",
    tags = {"digging", "busy", "nosleep", "noattack", "invisible"},

    onenter = function(inst)
        inst.components.locomotor:Stop()
        inst.AnimState:PlayAnimation("icedive_dig_pst")
    end,

    timeline =
    {
        FrameEvent(2, function(inst) inst.SoundEmitter:PlaySound("meta3/sharkboi/popup") end),
    },

    events =
    {
        EventHandler("animover", function(inst)
            if inst.AnimState:AnimDone() then
                inst:StopBrain()
                inst.Physics:SetCollisionMask(
                COLLISION.GROUND,
                COLLISION.WORLD
                )
                inst.randomfrozenfissuretask = inst:DoTaskInTime(3, randomfrozenfissure)
                inst.allfrozenfissuretask = inst:DoTaskInTime(10, allfrozenfissure)
            end
        end),
        EventHandler("icestrom", function(inst)
            if inst.randomfrozenfissuretask then
                inst.randomfrozenfissuretask:Cancel()
                inst.randomfrozenfissuretask = nil
            end
            if inst.allfrozenfissuretask then
                inst.allfrozenfissuretask:Cancel()
                inst.allfrozenfissuretask = nil
            end
            inst.sg:GoToState("spawn2hm")       
        end),
    },

    onexit = function(inst)
        inst:RestartBrain()
        if inst and inst:IsValid() then
            RemovePhysicsColliders(inst)
        end
        if not inst.sg.statemem.fin then
            local x, y, z = inst.Transform:GetWorldPosition()
            inst.DynamicShadow:Enable(true)
        end
    end,
})

AddStategraphState("sharkboi", State{
    name = "spawn2hm",
    tags = { "busy", "jumping", "nosleep", "noattack"},

    onenter = function(inst)
        inst.components.locomotor:Stop()
        inst.AnimState:PlayAnimation("spawn")
        inst.SoundEmitter:PlaySound("turnoftides/common/together/water/emerge/large")
        inst.SoundEmitter:PlaySound("meta3/sharkboi/spawn")
    end,

    events =
    {
        EventHandler("animover", function(inst)
            if inst.AnimState:AnimDone() then
                if inst:HasTag("swc2hm") then
                    inst:RestartBrain()
                    inst.components.combat:RestartCooldown()
                    inst.components.timer:StartTimer("standing_dive_2hmcd", removetime + 10)
                    if inst and inst:IsValid() then
                        RemovePhysicsColliders(inst)
                    end
                end
                if inst.swp2hm and inst.swp2hm.sg:HasStateTag("icestroming2hm") then
                    inst.sg:GoToState("icestrom_fissure2hm")
                else
                    inst.sg:GoToState("idle")
                end
            end
        end),
    },
})

-- 在目标附近生成干扰冰裂隙
local scale = 0.4
local function frozenfissuretask2hm(x, z, num)
    if x == nil or z == nil then return end
    local radius = math.random(0,4)
    local angle = math.random() * TWOPI
    x = x + math.cos(angle) * radius
    z = z + math.sin(angle) * radius
    local fx = SpawnPrefab("deerclops_icelance_ping_fx")
    if not TheNet:IsDedicated() then
        fx.disc.Remove(fx.disc)
	end
    fx.AnimState:SetScale(scale,scale)
    fx:Hide()
    fx.Transform:SetPosition(x, 0, z)
    local time = math.random() * 0.5 + (num or 0)
    fx:DoTaskInTime(time, function() fx:Show() end)
    fx.task2 = fx:DoTaskInTime(1 + time, function()
        spawnice_circle(x,z, true)
        fx:KillFX()
    end)
end
AddStategraphState("sharkboi", State {
    name = "icestrom_fissure2hm",
    tags = {"busy", "nosleep", "nofreeze", "noelectrocute", "noattack"},
    onenter = function(inst, target)
        inst.components.locomotor:Stop()
        local target = inst.components.combat and inst.components.combat.target
        if target then
            inst:ForceFacePoint(target.Transform:GetWorldPosition())
        end
        inst.AnimState:PlayAnimation("ice_summon")
    end,
    timeline = {
        FrameEvent(10, function(inst) inst.SoundEmitter:PlaySound(inst.voicepath.."attack_small") end),
        FrameEvent(35, function(inst)
            for i, v in pairs(AllPlayers) do
                if v and v:IsNear(inst.swp2hm, 40) then
                    local x, y, z = v.Transform:GetWorldPosition()
                    frozenfissuretask2hm(x,z)
                end
            end
            inst.SoundEmitter:PlaySound(inst.voicepath.."attack_big")
        end),
    },

    events = {
        EventHandler("animover", function(inst)
            if inst and inst:IsValid() and inst.AnimState:AnimDone() then
                if inst.swp2hm and inst.swp2hm.sg:HasStateTag("icestroming2hm") then
                    inst.sg:GoToState("icestrom_fissure2hm")
                else
                    inst.components.combat:RestartCooldown()
                    inst.sg:GoToState("idle")
                end
            end
        end)
    }
})

-- 独特掉落物
local function reward(inst)
    if inst.MakeTrader then
        local oldMakeTrader = inst.MakeTrader
        inst.MakeTrader = function(inst, ...)
            oldMakeTrader(inst, ...)
            if inst.stock_ then inst.stock = inst.stock_ end
            if not inst.dropcore2hm then
                inst.dropcore2hm = true
                for i = 1, 2 do
                    LaunchAt(SpawnPrefab("frostcore2hm"), inst, nil, 1.5, 2, 1.25)
                end
                LaunchAt(SpawnPrefab("frostshrine2hm_blueprint"), inst, nil, 1.5, 2, 1.25)
            end
        end
    end
end

AddPrefabPostInit("sharkboi", function(inst)
    inst:AddTag("deergemresistance")
    if not inst:HasTag("sharkboi") then inst:AddTag("sharkboi") end
    if not TheWorld.ismastersim then return end
    inst:RemoveComponent("freezable")
    inst:AddComponent("amphibiouscreature")
    inst.aoethrow2hm = 1
    if inst.OnEntitySleep then
        local oldOnEntitySleep = inst.OnEntitySleep
        inst.OnEntitySleep = function(inst, ...)
            oldOnEntitySleep(inst, ...)
            onsleep(inst)
        end
    end
    if inst.OnEntityWake then
        local oldOnEntityWake = inst.OnEntityWake
        inst.OnEntityWake = function(inst, ...)
            oldOnEntityWake(inst, ...)
            onwake(inst)
        end
    end
    if inst.components.combat then
        local oldCalcDamage = inst.components.combat.CalcDamage
        inst.components.combat.CalcDamage = function(self, target, ...)
            local damage, spdamage = oldCalcDamage(self, target, ...)
            local multiplier = freeze_target(target)
            if damage then damage = damage * multiplier end
            return damage, spdamage
        end
    end
    -- 奖励优化
    if inst.GiveReward then
        local oldfn = inst.GiveReward
        inst.GiveReward = function(...)
            local _SpawnPrefab = GLOBAL.SpawnPrefab
            GLOBAL.SpawnPrefab = function(name, ...)
                if name == "bootleg" then name = "bootleg2hm" end
                return _SpawnPrefab(name, ...)
            end
            local reason = oldfn(...)
            GLOBAL.SpawnPrefab = _SpawnPrefab
        end
    end
    reward(inst)
    savaandload(inst)
end)

-- 独特掉落相关
-- 永恒靴子融合
STRINGS.ACTIONS.ACTION2HM.BOOTLEG2HM = TUNING.isCh2hm and "融合" or "INTEGRATE"
-- 霜冻核心升级
STRINGS.ACTIONS.ACTION2HM.FROSTCORE2HM = TUNING.isCh2hm and "升级" or "UPGRADE"
STRINGS.NAMES.FROSTCORE2HM = (TUNING.isCh2hm and "霜冻核心") or "Frost Core"

local function getcontainerspace2hm(inst, container, data, addprefab)
    local slots = container.slots or container.itemslots
    local numslots = container.numslots or container.maxslots
    -- 没有剩余空间时返回true
    local prefabs = data.prefabs or {}
    local infiniteprefabs = data.infiniteprefabs or {}
    local lacksize = data.lacksize or {}
    local leftnumslots = numslots
    for i = 1, numslots do
        local item = slots[i]
        if item ~= nil and item:IsValid() then
            leftnumslots = leftnumslots - 1
            local hasprefab = prefabs and table.contains(prefabs, item.prefab)
            if not hasprefab and addprefab ~= false and prefabs and not table.contains(itemsblacklist, item.prefab) then
                table.insert(prefabs, item.prefab)
                hasprefab = true
            end
            if hasprefab and item.components.stackable then
                if container.infinitestacksize or item.components.stackable.maxsize == math.huge then
                    infiniteprefabs[item.prefab] = true
                    if lacksize[item.prefab] then lacksize[item.prefab] = nil end
                elseif not infiniteprefabs[item.prefab] and item.components.stackable.stacksize < item.components.stackable.maxsize then
                    lacksize[item.prefab] = (lacksize[item.prefab] or 0) + item.components.stackable.maxsize -
                        item.components.stackable.stacksize
                end
            end
        end
    end
    return leftnumslots, lacksize, infiniteprefabs
end

local time = 120
local function createice(inst)
    local container = inst.components.container or inst.components.inventory
    if not container then return end
    local x,y,z = inst:GetPosition()
    local container = inst.components.container or inst.components.inventory
    local data = {}
    data.prefabs = {"ice"}
    local leftnumslots, lacksize, infiniteprefabs = getcontainerspace2hm(inst, container, data, false)
    if not container:IsFull() then
        local ice = SpawnPrefab("ice")
        if not container:GiveItem(ice, nil, x,y,z) then
            ice:Remove()
        end
    elseif container:IsFull() and lacksize and lacksize["ice"] and lacksize["ice"] > 0 or lacksize == nil then
        local ice = SpawnPrefab("ice")
        if not container:GiveItem(ice, nil, x,y,z) then
            ice:Remove()
        end
    end
    if inst.createicetask2hm then
        inst.createicetask2hm:Cancel()
        inst.createicetask2hm = inst:DoPeriodicTask(math.random(-1,1) * 20 + time,createice)
    end
end

local function onupgrade(target, TheWorld, prefab)
    if not target or not target:IsValid() then return end
    target:AddTag("frostcore2hm")
    local preserver = target.components.preserver
    if not preserver then
        target:AddComponent("preserver")
        preserver = target.components.preserver
        local num = TUNING.PERISH_FRIDGE_MULT / 2
        if target:HasTag("fridge") then
            num = function(inst, item)
                return (item and item:HasTag("frozen") and not inst:HasTag("nocool") and not inst:HasTag("lowcool") and TUNING.PERISH_COLD_FROZEN_MULT / 2)
                    or TUNING.PERISH_FRIDGE_MULT / 2
            end
        elseif target:HasTag("foodpreserver") then
            num = TUNING.PERISH_FOOD_PRESERVER_MULT / 2
        end
        preserver:SetPerishRateMultiplier(num)
        preserver.frostcore2hm = true
    elseif not preserver.frostcore2hm then
        local oldperish = preserver.perish_rate_multiplier
        if oldperish then
            preserver.perish_rate_multiplier = function(inst, item, ...)
                local num = FunctionOrValue(oldperish, inst, item, ...)
                if num > 0 then
                    num = num / 2
                elseif num < 0 then
                    num = num * 2
                end
                return num
            end
        else
            preserver:SetPerishRateMultiplier(TUNING.PERISH_FRIDGE_MULT / 2)
        end
        preserver.frostcore2hm = true
    end
    if target.prefab == "icebox" and not target.createicetask2hm then
        target.createicetask2hm = target:DoPeriodicTask(math.random(-1,1) * 20 + time, createice)
    end
end

local function onsave(inst, data) data.upgrade2hm = inst:HasTag("frostcore2hm") end
local function onload(inst, data)
    if data and data.upgrade2hm then
        onupgrade(inst)
    end
end

AddPrefabPostInitAny(function(inst)
    if not inst:HasTag("player") then
        inst:DoTaskInTime(0, function()
            local _container = inst.components.container or inst.replica.container
            if _container and inst:IsValid() then
                inst:AddTag("canfrostcoreUP2hm")
                local olddisplaynamefn = inst.displaynamefn
                inst.displaynamefn = function(inst)
                    local name = STRINGS.NAMES[string.upper(inst.prefab)] or (TUNING.isCh2hm and "容器" or "Container")
                    local extra
                    if inst:HasTag("frostcore2hm") then
                        extra = (TUNING.isCh2hm and "霜冻- " or "Frost- ")
                        if olddisplaynamefn then
                            local _name = olddisplaynamefn(inst)
                            if _name ~= nil then
                                name = _name 
                                extra = (TUNING.isCh2hm and "霜冻/" or "Frost/")
                            end
                        end
                    end
                    return (extra or "") .. name
                end
            end
        end)
        local container = inst.components.container or inst.replica.container
        if not TheWorld.ismastersim or not container then return end
        if inst.components.workable then
            local oldonfinish = inst.components.workable.onfinish
            inst.components.workable.onfinish = function(...)
                if inst:HasTag("frostcore2hm") then
                    SpawnPrefab("frostcore2hm").Transform:SetPosition(inst.Transform:GetWorldPosition())
                end
                if oldonfinish then oldonfinish(...) end
            end
        end
        SetOnSave(inst, onsave)
        SetOnLoad(inst, onload)
    end
end)

AddPrefabPostInit("tacklestation2hm", function(inst)
    if not TheWorld.ismastersim then return end
    inst.onupgrade = function(TheWorld, prefab)
        if TheWorld and prefab then
            if inst.prefab ~= prefab then return end
        end
        onupgrade(inst, TheWorld, prefab) 
    end
    inst:ListenForEvent("preserverupadat2hm", inst.onupgrade, TheWorld)
    SetOnSave(inst, onsave)
    SetOnLoad(inst, onload)
end)
AddPrefabPostInit("shadowvaulttacklepage2hm", function(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("preserverupadat2hm", function() onupgrade(inst) end, TheWorld)
    inst:DoStaticTaskInTime(0, function()
        local tackle = TheWorld:GetPocketDimensionContainer("tacklestation2hm")
        if tackle and tackle:HasTag("frostcore2hm") then onupgrade(inst) end
    end)
end)
AddPrefabPostInit("shadowbank_tackle2hm", function(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("preserverupadat2hm", function() onupgrade(inst) end, TheWorld)
    inst:DoStaticTaskInTime(0, function()
        local tackle = TheWorld:GetPocketDimensionContainer("tacklestation2hm")
        if tackle and tackle:HasTag("frostcore2hm") then onupgrade(inst) end
    end)
end)
AddShardModRPCHandler("MOD_HARDMODE", "ms_preserver_update", function(shard_id, islink, data)
    TheWorld:PushEvent("preserverupadat2hm")
end)

-- 角色状态图更改
-- 骑牛也会滑倒了
local states = {
    "run",
    "run_start",
    "run_stop",
    "run_monkey_start",
    "run_monkey",
    "sprint_woby_start",
    "sprint_woby",
    "acting_run_stop",
    "dash_woby_pre",
    "dash_woby",
    "dash_woby_shadow",
    "dash_woby_pst",
}
AddStategraphPostInit("wilson", function(sg)
    local oldConfigureRunState
    for i, v in pairs(states) do
        if v and sg.states[v] and sg.states[v].onenter then
            oldConfigureRunState = UpvalueHacker.GetUpvalue(sg.states[v].onenter, "ConfigureRunState")
            if oldConfigureRunState then
                local newConfigureRunState = function(inst, ...)
                    local mount = inst.components.rider:GetMount()
                    oldConfigureRunState(inst, ...)
                    if mount then
                        inst.sg:RemoveStateTag("noslip")
                    end
                end
                UpvalueHacker.SetUpvalue(sg.states[v].onenter, newConfigureRunState, "ConfigureRunState")
                break
            end
        end
    end
    local knockback = sg.states.knockback.onenter
    sg.states.knockback.onenter = function(inst, data, ...)
        knockback(inst, data, ...)
        if inst.sg.currentstate and inst.sg.currentstate.name == "knockback" and data and data.disableworldcollision2hm and TheWorld.has_ocean then
            inst.sg.statemem.disableworldcollision2hm = true
            inst.Physics:ClearCollidesWith(COLLISION.WORLD)
            inst.Physics:CollidesWith(COLLISION.GROUND)
            inst.sg.statemem.safepos = nil
            if inst:HasTag("wereplayer") then inst.AnimState:PlayAnimation("idle_loop", true) end
        end
    end
    local knockbackonexit = sg.states.knockback.onexit
    sg.states.knockback.onexit = function(inst, ...)
        knockbackonexit(inst, ...)
        if inst.sg.statemem.disableworldcollision2hm then
            inst.Physics:ClearCollidesWith(COLLISION.GROUND)
            inst.Physics:CollidesWith(COLLISION.WORLD)
            local x, y, z = inst.Transform:GetWorldPosition()
            inst.Physics:Teleport(x, 0.1, z)
            inst.Physics:Stop()
        end
    end
    local slip = sg.states.slip.onenter
    sg.states.slip.onenter = function(inst, data, ...)
        local mount = inst.components.rider:GetMount()
        if mount then
			inst.components.locomotor:Stop()
			inst:ClearBufferedAction()

			if inst.components.slipperyfeet then
				inst.components.slipperyfeet:SetCurrent(0)
			end

			inst.AnimState:PlayAnimation("boat_jump_pre")
			inst.AnimState:PushAnimation("boat_jump_loop", false)
			inst.SoundEmitter:PlaySound("dontstarve/movement/iceslab_slipping")

			inst.sg.statemem.speed = inst.components.locomotor:GetRunSpeed()
			inst.Physics:SetMotorVel(inst.sg.statemem.speed * 0.6, 0, 0)

			inst.player_classified.busyremoteoverridelocomote:set(true)
			inst.sg.statemem.trackcontrol = true
        else
            slip(inst, data, ...)
        end
    end
    local slip_pst = sg.states.slip_pst.onenter
    sg.states.slip_pst.onenter = function(inst, data, ...)
        local mount = inst.components.rider:GetMount()
        if mount then
			inst.AnimState:PlayAnimation("boat_jump_pst")
			inst.sg.statemem.speed = speed or inst.components.locomotor:GetRunSpeed()
			inst.Physics:SetMotorVel(inst.sg.statemem.speed * 0.15, 0, 0)
        else
            slip_pst(inst, data, ...)
        end
    end
    local slip_fall = sg.states.slip_fall.onenter
    sg.states.slip_fall.onenter = function(inst, data, ...)
        local mount = inst.components.rider:GetMount()
        if mount then
			inst:PushEvent("bucked")
        else
            slip_fall(inst, data, ...)
        end
    end
end)

-- 冰钓洞概率钓出核心和蓝图
local loots = {
    frostshrine2hm_blueprint = 0.5,
    frostcore2hm = 0.05,
    bootleg = 0.3,
}

AddPrefabPostInit("world", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.sharkboimanager then
        local self = inst.components.sharkboimanager
        local oldOnPlayerFishCaught = inst.components.sharkboimanager.OnPlayerFishCaught
        inst.components.sharkboimanager.OnPlayerFishCaught = function(inst, ...)
            oldOnPlayerFishCaught(inst, ...)
            local hole = self.arena and self.arena.fishinghole
            if not (hole and hole:IsValid()) then return end
            local random = math.random()
            local bootleg_chance = loots["bootleg"]
            local frostcore_chance = loots["frostcore2hm"]
            local blueprint_chance = loots["frostshrine2hm_blueprint"]
            local known = inst and inst.components and inst.components.builder and inst.components.builder:KnowsRecipe("frostshrine2hm")
            if not known then
                if random < (frostcore_chance * blueprint_chance) then
                    LaunchAt(SpawnPrefab("frostshrine2hm_blueprint"), hole, inst, 2, 3)
                elseif random < frostcore_chance then
                    LaunchAt(SpawnPrefab("frostcore2hm"), hole, inst, 2, 3)
                elseif random < bootleg_chance then
                    LaunchAt(SpawnPrefab("bootleg"), hole, inst, 2, 3)
                end
            elseif known then
                if random < (frostcore_chance + 0.1) then
                    LaunchAt(SpawnPrefab("frostcore2hm"), hole, inst, 2, 3)
                elseif random < (bootleg_chance + 0.2) then
                    LaunchAt(SpawnPrefab("bootleg"), hole, inst, 2, 3)
                end
            end
        end
    end
end)

AddPrefabPostInit("icefishing_hole", function(inst)
    inst.Physics:ClearCollisionMask()		
    inst.Physics:SetCollisionMask(
		COLLISION.CHARACTERS,
		COLLISION.GIANTS
	)
end)
