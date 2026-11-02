-- 脱战无敌
local thralls = {"shadowthrall_hands", "shadowthrall_wings", "shadowthrall_horns"}
local function onentitysleep(inst) if inst.components.health and not inst.components.health:IsDead() then inst.sleeptime2hm = GetTime() end end
local function onentitywake(inst)
    if inst.components.health and not inst.components.health:IsDead() then
        if not inst.sleeptime2hm or GetTime() - inst.sleeptime2hm >= 10 then inst.components.health:SetPercent(1) end
        if inst.undevouredi2hm then inst.undevouredi2hm = nil end
    end
end
local function invinciblesleep(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("entitysleep", onentitysleep)
    inst:ListenForEvent("entitywake", onentitywake)
end
for _, thrall in ipairs(thralls) do AddPrefabPostInit(thrall, invinciblesleep) end
-- 影战士的冲撞现在不会被打断且可以连续攻击敌人了
AddStategraphPostInit("shadowthrall_hands", function(sg)
    local runanim = sg.states.run.events.animover.fn
    sg.states.run.events.animover.fn = function(inst, ...)
        if not inst:HasTag("swc2hm") then
            inst.sg.statemem.stop = false
            inst.sg.statemem.walk = false
            inst.sg.statemem.targethit = nil
            inst.sg.statemem.targets = {}
        end
        runanim(inst, ...)
    end
end)
-- 影法师投弹可以弹射
local function clearshadowthralldata(inst)
    inst.targets2hm = nil
    inst.sfx2hm = nil
    inst.resetshadowthrallprojectiletask2hm = nil
end
local function bouncethrow2hmfn(self, inst)
    local newproj = SpawnPrefab(inst.prefab)
    self.attacker.targets2hm = self.attacker.targets2hm or {}
    newproj.targets = self.attacker.targets2hm
    self.attacker.sfx2hm = self.attacker.sfx2hm or {}
    newproj.sfx = self.attacker.sfx2hm
    if self.attacker and not self.attacker.resetshadowthrallprojectiletask2hm then
        self.attacker.resetshadowthrallprojectiletask2hm = self.attacker:DoTaskInTime(1.5, clearshadowthralldata)
    end
    return newproj
end
local function setbouncethrow(inst)
    if not inst:HasTag("swc2hm") then
        inst.bouncethrow2hm = 2
        inst.bouncethrow2hmfn = bouncethrow2hmfn
    end
end
AddPrefabPostInit("shadowthrall_wings", function(inst)
    if not TheWorld.ismastersim then return end
    inst:DoTaskInTime(0, setbouncethrow)
end)
-- 影战士和影法师会被影子坦克吞噬增强
local state = State {
    name = "devoured2hm",
    tags = {"devoured2hm", "invisible", "noattack", "busy", "temp_invincible"},
    onenter = function(inst, attacker)
        inst.components.locomotor:Stop()
        inst.AnimState:PlayAnimation("empty")
        inst:Hide()
        inst.DynamicShadow:Enable(false)
        inst.Physics:SetActive(false)
        if attacker ~= nil and attacker:IsValid() then
            inst.sg.statemem.attacker = attacker
            inst.Transform:SetRotation(attacker.Transform:GetRotation() + 180)
        end
        inst.sg:SetTimeout(2.25)
    end,
    onupdate = function(inst)
        local attacker = inst.sg.statemem.attacker
        if attacker and attacker:IsValid() and attacker.components.health and not attacker.components.health:IsDead() then
            inst.Transform:SetPosition(attacker.Transform:GetWorldPosition())
            inst.Transform:SetRotation(attacker.Transform:GetRotation() + 180)
        elseif attacker then
            inst.sg.statemem.attacker = nil
            inst.sg.currentstate:HandleEvent(inst.sg, "spitout")
        end
    end,
    ontimeout = function(inst) inst.sg.currentstate:HandleEvent(inst.sg, "spitout") end,
    events = {
        EventHandler("spitout", function(inst, data)
            CreateMiasma2hm(inst, true)
            local attacker = data and data.spitter or inst.sg.statemem.attacker
            if attacker and attacker:IsValid() and attacker.components.health and not attacker.components.health:IsDead() and inst.components.health and
                not inst.components.health:IsDead() then
                local percent = (attacker.components.health:GetPercent() + inst.components.health:GetPercent()) / 2
                inst.components.health:SetPercent(percent)
                attacker.components.health:SetPercent(percent + 0.1)
                local rot = attacker.Transform:GetRotation()
                inst.Transform:SetRotation(rot + 180)
                local physradius = attacker:GetPhysicsRadius(0)
                if physradius > 0 then
                    local x, y, z = inst.Transform:GetWorldPosition()
                    rot = rot * DEGREES
                    x = x + math.cos(rot) * physradius
                    z = z - math.sin(rot) * physradius
                    inst.Physics:Teleport(x, 0, z)
                end
            end
            inst.sg:GoToState("hit")
        end)
    },
    onexit = function(inst)
        inst:Show()
        inst.DynamicShadow:Enable(true)
        inst.Physics:SetActive(true)
    end
}
AddStategraphState("shadowthrall_hands", state)
AddStategraphState("shadowthrall_wings", state)
-- 影子坦克可以吞噬队友进行增强和回血
AddStategraphPostInit("shadowthrall_horns", function(sg)
    local jumponenter = sg.states.jump.onenter
    sg.states.jump.onenter = function(inst, target, ...)
        if not inst:HasTag("swc2hm") and (inst.undevouredi2hm or 0) >= 1 then
            local hurtinst = inst.components.health:GetPercent() < 1
            local first = math.random() < 0.5 and "hands" or "wings"
            local hands = inst.components.entitytracker:GetEntity(first)
            if hands and hands:IsValid() and hands:IsNear(inst, 9) and hands.components.health and not hands.components.health:IsDead() and
                (hurtinst or hands.components.health:GetPercent() < 1) then
                target = hands
                if hands.components.locomotor then hands.components.locomotor:Stop() end
                inst.undevouredi2hm = math.max((inst.undevouredi2hm or 0) - 1, 0)
            else
                local wings = inst.components.entitytracker:GetEntity(first == "hands" and "wings" or "hands")
                if wings and wings:IsValid() and wings:IsNear(inst, 9) and wings.components.health and not wings.components.health:IsDead() and
                    (hurtinst or wings.components.health:GetPercent() < 1) then
                    target = wings
                    if wings.components.locomotor then wings.components.locomotor:Stop() end
                    inst.undevouredi2hm = math.max((inst.undevouredi2hm or 0) - 1, 0)
                end
            end
        end
        jumponenter(inst, target, ...)
    end
    local time1 = 29.5 * FRAMES
    local time2 = 30.5 * FRAMES
    for key, timeevent in pairs(sg.states.jump.timeline) do
        if timeevent and timeevent.time and timeevent.fn and timeevent.time > time1 and timeevent.time < time2 then
            local fn = timeevent.fn
            timeevent.fn = function(inst, ...)
                if not inst.devouredteam2hm then inst.devouredteam2hm = true end
                fn(inst, ...)
                if not inst.sg.statemem.devoured then
                    local hurtinst = inst.components.health:GetPercent() < 1
                    local x, y, z = inst.Transform:GetWorldPosition()
                    local shadowthralls = TheSim:FindEntities(x, y, z, 4, {"shadowthrall"})
                    for _, thrall in ipairs(shadowthralls) do
                        if thrall and thrall:IsValid() and (thrall.prefab == "shadowthrall_hands" or thrall.prefab == "shadowthrall_wings") and
                            thrall.components.health and not thrall.components.health:IsDead() and (hurtinst or thrall.components.health:GetPercent() < 1) and
                            not (thrall.sg and thrall.sg:HasStateTag("attack")) then
                            thrall.sg:GoToState("devoured2hm", inst)
                            inst.sg.statemem.devoured = thrall
                            thrall.components.health:SetPercent(1)
                            inst.SoundEmitter:PlaySound("dontstarve/common/teleportworm/swallow")
                            inst.SoundEmitter:PlaySound("rifts2/thrall_horns/wormhole_amb", "devour_loop")
                            break
                        end
                    end
                    if not inst.sg.statemem.devoured then inst.undevouredi2hm = (inst.undevouredi2hm or 0) + 1 end
                end
            end
        end
    end
end)
-- 影子坦克吞噬敌人或死亡后制造毒雾
local function hornsdeath(inst) CreateMiasma2hm(inst, true) end
AddPrefabPostInit("shadowthrall_horns", function(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("death", hornsdeath)
end)
AddStategraphPostInit("wilson", function(sg)
    local spitoutfn = sg.states.devoured.events.spitout.fn
    sg.states.devoured.events.spitout.fn = function(inst, data, ...)
        spitoutfn(inst, data, ...)
        if data and data.spitter and data.spitter:IsValid() and data.spitter.prefab == "shadowthrall_horns" and data.spitter.components.health and
            not data.spitter.components.health:IsDead() then
            data.spitter.components.health:SetPercent(1)
            CreateMiasma2hm(inst, true)
        end
    end
end)
-- 修复掉落BUG
AddComponentPostInit("shadowthrallmanager", function(self)
    local KillThrall = self.KillThrall
    self.KillThrall = function(self, thrall, ...)
        if thrall and thrall:IsValid() then thrall.persists = false end
        if thrall and thrall:IsAsleep() then thrall:DoTaskInTime(FRAMES, thrall.Remove) end
        return KillThrall(self, thrall, ...)
    end
end)

-- 影虫子跳跃更快,移速更快,攻击会将敌人传送到裂隙并制造黑雾,孢子更快爆炸且能散射
TUNING.FUSED_SHADELING_BOMB_WALKSPEED = TUNING.FUSED_SHADELING_BOMB_WALKSPEED * 2
local EXTRA_QUICKFUSE_BOMBS = 6
local function onqucikbomb(inst)
    CreateMiasma2hm(inst)
    local pos = inst:GetPosition()
    local targets = {} -- shared table for the whole patch of particles
    local sfx = {} -- shared table so we only play sfx once for the whole batch
    local initial_angle, angle_per_bomb = TWOPI * math.random(), TWOPI / EXTRA_QUICKFUSE_BOMBS
    local pos1 = Vector3(0, 0, 0)
    for i = 1, EXTRA_QUICKFUSE_BOMBS do
        local theta = GetRandomWithVariance(initial_angle + i * angle_per_bomb, PI / 6)
        pos1.x = pos.x + 4 * math.cos(theta)
        pos1.z = pos.z - 4 * math.sin(theta)
        local proj = SpawnPrefab("shadowthrall_projectile_fx")
        proj.Physics:Teleport(pos:Get())
        proj.targets = targets
        proj.sfx = sfx
        proj.components.complexprojectile:Launch(pos1, inst)
    end
end
TUNING.FUSED_SHADELING_BOMB_EXPLOSION_TIME = 75 * FRAMES
local function on_timer_done(inst, data)
    if data and data.name == "chase_tick" then
        local target = inst.components.entitytracker:GetEntity("target")
        if target then inst.components.locomotor:GoToEntity(target) end
    elseif data and data.name == "start_explosion" then
        CreateMiasma2hm(inst, true)
    end
end
AddPrefabPostInit("fused_shadeling_bomb", function(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("timerdone", on_timer_done)
    if inst.components.timer and inst.components.timer:TimerExists("spawn_delay") then
        inst.components.timer:SetTimeLeft("spawn_delay", (0.25 + 0.75 * math.random()))
    end
end)
AddPrefabPostInit("fused_shadeling_quickfuse_bomb", function(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("onremove", onqucikbomb)
end)
local function endfusedtask(inst) inst.fusedtask2hm = nil end
local function onshadelinghitother(inst, data)
    if data and data.target and data.target:HasTag("player") and not (data.target and data.target.sg:HasStateTag("parrying")) then
        if not data.target.fusedtask2hm then
            data.target.fusedtask2hm = data.target:DoTaskInTime(3, endfusedtask)
            local homept = inst.components.homeseeker and inst.components.homeseeker.home and inst.components.homeseeker.home:IsValid() and
                               inst.components.homeseeker.home:GetPosition()
            local pt = homept or inst:GetPosition()
            data.target.Transform:SetPosition(pt.x, 0, pt.z)
            data.target.sg:HandleEvent("knockback", {
                knocker = inst,
                radius = inst:GetPhysicsRadius(0) + 2,
                strengthmult = ((data.target.components.inventory and data.target.components.inventory:ArmorHasTag("heavyarmor") or
                    data.target:HasTag("heavybody")) and 1.3 or 1) * (homept and -3 or 1)
            })
        end
        CreateMiasma2hm(inst, true)
    end
end
AddPrefabPostInit("fused_shadeling", function(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("onhitother", onshadelinghitother)
end)
AddStategraphPostInit("fused_shadeling", function(sg)
    local idleonenter = sg.states.idle.onenter
    sg.states.idle.onenter = function(inst, ...)
        if not inst.sg.mem.despawning and inst.components.combat and inst.sg.laststate then
            if inst.sg.laststate.name == "appear_pst" or inst.sg.laststate.name == "attack" then
                local target = inst.components.combat.target or FindClosestPlayerToInst(inst, TUNING.FUSED_SHADELING_MAXJUMPDISTANCE, true)
                if target and target:IsValid() then return inst.sg:GoToState("jump_pre", target:GetPosition()) end
            elseif inst.sg.laststate.name == "jump_pst" and inst.components.combat.target then
                local target = inst.components.combat.target or FindClosestPlayerToInst(inst, TUNING.FUSED_SHADELING_ATTACK_RANGE, true)
                if target and target:IsValid() and target:IsNear(inst, TUNING.FUSED_SHADELING_ATTACK_RANGE) then
                    return inst.sg:GoToState("attack", target)
                end
            end
        end
        idleonenter(inst, ...)
    end
end)
-- 暗影裂隙改动
if GetModConfigData("shadow_rift") then -- 2025.8.5 melon:加个开关
    local function Vac2hm(inst)
        local x, y, z = inst.Transform:GetWorldPosition()
        for index, v in ipairs(AllPlayers) do
            if not IsEntityDeadOrGhost(v) then
                local distsq = inst:GetDistanceSqToInst(v)
                if distsq <= 25 then if v.components.health ~= nil then v.components.health:DoDelta(-0.25, false, inst.prefab) end end
                if distsq <= 1000 and v.sg ~= nil and not v.sg:HasStateTag("gotgrabbed") and not v.sg:HasStateTag("waking") then
                    if v.components.sleepingbaguser ~= nil and v.components.sleepingbaguser.sleeptask ~= nil then
                        v.components.sleepingbaguser:DoWakeUp()
                    end
                    local px, py, pz = v.Transform:GetWorldPosition()
                    local rad = math.rad(v:GetAngleToPoint(x, y, z))
                    local multiplierplayer = distsq / 50
                    if multiplierplayer > 15 then
                        multiplierplayer = 15
                    elseif multiplierplayer < 1.5 then
                        multiplierplayer = 1.5
                    end
                    local dx, dy, dz = px + FRAMES * 5 * math.cos(rad) / multiplierplayer, 0, pz - FRAMES * 5 * math.sin(rad) / multiplierplayer
                    local ground = TheWorld.Map:IsPassableAtPoint(dx, dy, dz)
                    local boat = TheWorld.Map:GetPlatformAtPoint(dx, dz)
                    if dx ~= nil and (ground or boat) then v.Transform:SetPosition(dx, dy, dz) end
                end
            end
        end
    end
    local function shadowriftonentitysleep(inst)
        if inst.vactask2hm then
            inst.vactask2hm:Cancel()
            inst.vactask2hm = nil
        end
    end
    local function shadowriftonentitywake(inst) if not inst.vactask2hm then inst.vactask2hm = inst:DoPeriodicTask(FRAMES * 3, Vac2hm) end end -- 2025.10.13 melon:1/3速度
    AddPrefabPostInit("shadowrift_portal", function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("entitysleep", shadowriftonentitysleep)
        inst:ListenForEvent("entitywake", shadowriftonentitywake)
    end)
end
