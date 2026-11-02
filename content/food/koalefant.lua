require "behaviours/follow"
require "behaviours/runaway"
-- 大象,脚印更远,群居出现和战斗
local animal_change = GetModConfigData("animal_change")
local changeIndex = (animal_change == -1 or animal_change == true or animal_change == false) and 3 or animal_change
local else_changeIndex = math.max(1, changeIndex / 2)
TUNING.HUNT_ALTERNATE_BEAST_CHANCE_MIN = math.min(TUNING.HUNT_ALTERNATE_BEAST_CHANCE_MIN * 2, 0.7)
TUNING.HUNT_ALTERNATE_BEAST_CHANCE_MAX = math.min(TUNING.HUNT_ALTERNATE_BEAST_CHANCE_MAX * 2, 0.9)
-- TUNING.TRACK_ANGLE_DEVIATION = TUNING.TRACK_ANGLE_DEVIATION * 1.5
TUNING.HUNT_SPAWN_DIST = TUNING.HUNT_SPAWN_DIST * 1.6
TUNING.HUNT_RESET_TIME = TUNING.HUNT_RESET_TIME * else_changeIndex
TUNING.HUNT_COOLDOWN = TUNING.HUNT_COOLDOWN * else_changeIndex
TUNING.HUNT_COOLDOWNDEVIATION = TUNING.HUNT_COOLDOWNDEVIATION * else_changeIndex
TUNING.SPAT_HEALTH = TUNING.SPAT_HEALTH * 2

-- 测试代码 c_spawn("koalefant_summer"):PushEvent("spawnedforhunt")

-- 大象会多刷队友，也包括刚羊
local function replacekoalefant(inst, data, ...)
    local spat = ReplacePrefab(inst, "spat")
    if data then data.beast = "spat" end
    spat:PushEvent("spawnedforhunt", data, ...)
end
local function onspawnedforhunt(inst, ...)
    -- 沼泽只刷刚羊
    local x, y, z = inst.Transform:GetWorldPosition()
    if TheWorld.Map:GetTileAtPoint(x, y, z) == WORLD_TILES.MARSH then
        inst:DoTaskInTime(0, replacekoalefant, ...)
        return
    end
    local more = math.random() < 0.75 and 1 or 0
    if TheWorld.state.cycles > 100 and math.random() > 0.5 then more = more + 1 end
    if TheWorld.state.cycles > 400 and math.random() > 0.5 then more = more + 1 end
    for i = 1, more, 1 do
        local chance = math.random()
        local prefab
        if chance < 0.4 then
            prefab = "koalefant_summer"
        elseif chance < 0.7 then
            prefab = "koalefant_winter"
        else
            prefab = "spat"
        end
        local newkoalefant = SpawnPrefab(prefab)
        newkoalefant.Transform:SetPosition(x, y, z)
        if newkoalefant.components.follower then
            newkoalefant.components.follower:SetLeader(inst)
            inst.koalefantindex2hm = (inst.koalefantindex2hm or 0) + 1
        end
        if inst.components.follower and not inst.components.follower.leader then
            inst.components.follower:SetLeader(newkoalefant)
            newkoalefant.koalefantindex2hm = (newkoalefant.koalefantindex2hm or 0) + 1
        end
    end
end
local function setleader(inst, koalefants)
    local minkoalefant
    local min = 1000000
    for index, koalefant in ipairs(koalefants) do
        if koalefant ~= inst and (koalefant.koalefantindex2hm or 0) < min then
            minkoalefant = koalefant
            min = koalefant.koalefantindex2hm or 0
        end
    end
    if minkoalefant then
        inst.components.follower:SetLeader(minkoalefant)
        minkoalefant.koalefantindex2hm = (minkoalefant.koalefantindex2hm or 0) + 1
    end
end
local function findfollower(inst)
    if inst.components.follower and inst.components.follower.leader or (inst.components.health and inst.components.health:IsDead()) then return end
    if inst:HasTag("swc2hm") and inst.swp2hm and inst.swp2hm:IsValid() and not (inst.swp2hm.components.health and inst.swp2hm.components.health:IsDead()) then
        inst.components.follower:SetLeader(inst.swp2hm)
        return
    end
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 50, nil, {"swc2hm"}, {"koalefant", "spat"})
    local koalefants = {}
    if #ents <= 0 then return end
    for index, koalefant in ipairs(ents) do
        if koalefant:IsValid() and koalefant.components.health and not koalefant.components.health:IsDead() then table.insert(koalefants, koalefant) end
    end
    if #koalefants >= 2 then
        for index, koalefant in ipairs(koalefants) do
            if koalefant.components.follower and not koalefant.components.follower.leader then setleader(koalefant, koalefants) end
        end
    end
end
local function OnChangedLeader(inst) inst:DoTaskInTime(0, findfollower) end
-- 刚羊会被大象帮助战斗了
local function onspatattacked(inst, data)
    if inst.components.follower and inst.components.follower.leader and inst.components.follower.leader.components.combat then
        inst.components.follower.leader.components.combat:SuggestTarget(data.attacker)
    end
    inst.components.combat:ShareTarget(data.attacker, 20, nil, 20, {"kolefant", "spat"})
end

-- 大象会水球灭火了和水球攻击了
local BOMB_MUSTHAVE_TAGS = {"_combat"}
local NO_TAGS = {"INLIMBO", "ghost", "playerghost", "FX", "NOCLICK", "DECOR", "notarget", "companion", "shadowminion", "koalefant"}
local function do_bomb(inst, thrower, damage)
    local bx, by, bz = inst.Transform:GetWorldPosition()
    -- Find anything nearby that we might want to interact with
    local entities = TheSim:FindEntities(bx, by, bz, TUNING.WATERSTREAK_AOE_DIST, BOMB_MUSTHAVE_TAGS, NO_TAGS)
    -- If we have a thrower with a combat component, we need to do some manipulation to become a proper combat target.
    if thrower ~= nil and thrower.components.combat ~= nil and thrower:IsValid() then
        thrower.components.combat.ignorehitrange = true
    else
        thrower = nil
    end
    for i, v in ipairs(entities) do
        if v:IsValid() and v.entity:IsVisible() and inst.components.combat:CanTarget(v) then
            if thrower ~= nil and v.components.combat.target == nil then
                v.components.combat:GetAttacked_Internal(thrower, damage, inst)
            else
                inst.components.combat:DoAttack(v)
            end
        end
    end
    if thrower ~= nil then thrower.components.combat.ignorehitrange = false end
end
local function onwaterhit(inst, attacker, target)
    local hpx, hpy, hpz = inst.Transform:GetWorldPosition()
    SpawnPrefab(inst.prefab == "snowball" and "splash_snow_fx" or "waterstreak_burst").Transform:SetPosition(hpx, hpy, hpz)
    if not TheWorld.Map:IsPassableAtPoint(hpx, hpy, hpz) then SpawnPrefab("ocean_splash_small2").Transform:SetPosition(hpx, hpy, hpz) end
    inst.components.wateryprotection:SpreadProtection(inst, TUNING.WATERSTREAK_AOE_DIST)
    do_bomb(inst, attacker, TUNING.KOALEFANT_DAMAGE / 10)
    inst:Remove()
end
local function generatewaterattack(inst, pos, enableattack)
    local x, y, z = inst.Transform:GetWorldPosition()
    local projectile = SpawnPrefab(TheWorld.state.temperature <= 0 and math.random() < (inst.prefab == "koalefant_winter" and 0.75 or 0.5) and "snowball" or
                                       "waterstreak_projectile")
    projectile.Transform:SetPosition(x, 0, z)
    projectile.components.complexprojectile:SetHorizontalSpeed(15)
    projectile.components.complexprojectile:SetGravity(-35)
    projectile.components.complexprojectile:SetLaunchOffset(Vector3(.25, 3, 0))
    local wateryprotection = projectile.components.wateryprotection
    for i = #wateryprotection.ignoretags, 1, -1 do
        if wateryprotection.ignoretags[i] == "player" then
            table.remove(wateryprotection.ignoretags, i)
            break
        end
    end
    wateryprotection:AddIgnoreTag("playerghost")
    if enableattack then
        projectile:AddComponent("combat")
        projectile.components.combat:SetDefaultDamage(TUNING.KOALEFANT_DAMAGE / 10)
        projectile.components.combat:SetRange(TUNING.WATERSTREAK_AOE_DIST)
        projectile.components.combat:SetKeepTargetFunction(falsefn)
        projectile.components.complexprojectile:SetOnHit(onwaterhit)
    end
    projectile.components.complexprojectile:Launch(pos, inst)
    return projectile
end
local function onanimqueueover(inst)
    if inst.fire_pos2hm and not (inst.components.health and inst.components.health:IsDead()) then
        if inst.sg and inst.sg.currentstate and inst.sg.currentstate.name == "graze" then
            generatewaterattack(inst, inst.fire_pos2hm)
            inst.sg:AddStateTag("idle")
            inst.sg:RemoveStateTag("busy")
        end
        inst.fire_pos2hm = nil
    end
end
local function spread_protection_at_point(inst, fire_pos) inst.components.wateryprotection:SpreadProtectionAtPoint(fire_pos:Get()) end
local function on_find_fire(inst, fire_pos)
    if inst:IsAsleep() then
        inst:DoTaskInTime(math.random(), spread_protection_at_point, fire_pos)
    elseif inst.components.timer and not inst.components.timer:TimerExists("waterattack2hm") and inst.sg and not inst.fire_pos2hm and
        (inst.sg:HasStateTag("idle") or (inst.sg:HasStateTag("running") and inst.components.combat and not inst.components.combat.target) or
            (inst.components.burnable and inst.components.burnable:IsBurning() and (inst.sg:HasStateTag("running") or not inst.sg:HasStateTag("busy")))) and
        inst:GetDistanceSqToPoint(fire_pos.x, 0, fire_pos.z) < 49 then
        inst.components.timer:StartTimer("waterattack2hm", 5)
        inst.fire_pos2hm = fire_pos
        inst:FacePoint(fire_pos.x, 0, fire_pos.z)
        inst.sg:GoToState("graze")
        inst.sg:AddStateTag("busy")
        inst.sg:RemoveStateTag("idle")
        inst.sg:RemoveStateTag("canrotate")
        inst:DoTaskInTime(inst.AnimState:GetCurrentAnimationLength(), onanimqueueover)
    end
end
local function onignite(inst) on_find_fire(inst, inst:GetPosition()) end
local function onextinguish(inst)
    if not inst:HasTag("fireimmune") then
        inst:AddTag("fireimmune")
        inst:DoTaskInTime(10, function() inst:RemoveTag("fireimmune") end)
    end
end
local function delayonentitysleeptask(inst)
    inst.delayDeactivatetask2hm = nil
    inst.components.firedetector:Deactivate()
end
local function onentitysleep(inst)
    if inst.delayDeactivatetask2hm then inst.delayDeactivatetask2hm:Cancel() end
    inst.delayDeactivatetask2hm = inst:DoTaskInTime(10, delayonentitysleeptask)
end
local function onentitywake(inst)
    if inst.delayDeactivatetask2hm then
        inst.delayDeactivatetask2hm:Cancel()
        inst.delayDeactivatetask2hm = nil
    end
    inst.components.firedetector:Activate(true)
end
local function dowaterattack(inst)
    if not (inst.components.health and inst.components.health:IsDead()) and inst.components.combat and inst.components.combat.target and
        inst.components.combat.target:IsValid() and inst:IsNear(inst.components.combat.target, 4) then
        inst.components.timer:StartTimer("waterattack2hm", 90 + math.random() * 5)
        local x, y, z = inst.Transform:GetWorldPosition()
        local pos = inst.components.combat.target:GetPosition()
        inst:ForceFacePoint(pos)
        generatewaterattack(inst, pos, true)
        local dir = inst.Transform:GetRotation() * DEGREES
        dir = dir + PI
        local pos1 = Vector3(0, 0, 0)
        for i = 1, 4 do
            local theta = dir + TWOPI / 5 * i
            pos1.x = pos.x + 2 * math.cos(theta)
            pos1.z = pos.z - 2 * math.sin(theta)
            generatewaterattack(inst, pos1, true)
        end
    end
end
AddStategraphPostInit("koalefant", function(sg)
    local attack = sg.states.attack.onenter
    sg.states.attack.onenter = function(inst, ...)
        attack(inst, ...)
        if inst.components.timer and not inst.components.timer:TimerExists("waterattack2hm") and inst.components.combat and inst.components.combat.target and
            inst.components.combat.target:IsValid() and inst.components.health and inst.components.health:GetPercent() < 0.25 then
            inst:ForceFacePoint(inst.components.combat.target:GetPosition())
            -- inst:DoTaskInTime(3 * FRAMES, dowaterattack)
            inst.dowaterattack2hm = true
        end
    end
    AddStateTimeEvent2hm(sg.states.attack, 3 * FRAMES, function(inst)
        if inst.dowaterattack2hm then
            dowaterattack(inst)
            inst.dowaterattack2hm = nil
        end
    end)
    local graze = sg.states.graze.onexit
    sg.states.graze.onexit = function(inst, ...)
        if graze then graze(inst, ...) end
        if inst.fire_pos2hm then onanimqueueover(inst) end
    end
end)

local animals = {"koalefant_summer", "koalefant_winter", "spat"}
for index, value in ipairs(animals) do
    AddPrefabPostInit(value, function(inst)
        if not TheWorld.ismastersim then return end
        inst.koalefantindex2hm = 0
        if not inst.components.follower then
            inst:AddComponent("follower")
            inst:DoTaskInTime(FRAMES, findfollower)
            inst.components.follower.OnChangedLeader = OnChangedLeader
        end
        if inst:HasTag("koalefant") then
            if inst.components.combat and inst.components.combat.min_attack_period > 3 then
                inst.components.combat.min_attack_period = math.max(3, inst.components.combat.min_attack_period * 3 / 4)
            end
            -- 大象灭火
            inst:ListenForEvent("spawnedforhunt", onspawnedforhunt)
            inst:AddComponent("firedetector")
            inst.components.firedetector:SetOnFindFireFn(on_find_fire)
            inst.components.firedetector.range = TUNING.OCEANFISH.SPRINKLER_DETECT_RANGE
            inst.components.firedetector.detectPeriod = TUNING.OCEANFISH.SPRINKLER_DETECT_PERIOD
            inst.components.firedetector.fireOnly = inst:AddComponent("wateryprotection")
            inst.components.wateryprotection.extinguishheatpercent = TUNING.FIRESUPPRESSOR_EXTINGUISH_HEAT_PERCENT
            inst.components.wateryprotection.temperaturereduction = TUNING.FIRESUPPRESSOR_TEMP_REDUCTION
            inst.components.wateryprotection.witherprotectiontime = TUNING.FIRESUPPRESSOR_PROTECTION_TIME
            inst.components.wateryprotection.addcoldness = TUNING.FIRESUPPRESSOR_ADD_COLDNESS
            inst.components.wateryprotection:AddIgnoreTag("player")
            inst:ListenForEvent("entitysleep", onentitysleep)
            inst:ListenForEvent("entitywake", onentitywake)
            inst.components.firedetector:Activate(true)
            if not inst.components.timer then inst:AddComponent("timer") end
            inst.components.timer:StartTimer("waterattack2hm", 15)
            inst:ListenForEvent("onignite", onignite)
            inst:ListenForEvent("onextinguish", onextinguish)
            local ShareTarget = inst.components.combat.ShareTarget
            inst.components.combat.ShareTarget = function(self, target, range, fn, ...)
                ShareTarget(self, target, range, function(dude, ...) return fn and fn(dude, ...) or dude:HasTag("spat") end, ...)
            end
        elseif inst:HasTag("spat") then
            inst:ListenForEvent("attacked", onspatattacked)
        end
    end)
end

-- 大象AI,走着避开玩家,跑着找群落
-- local MIN_FOLLOW_LEADER = 4
-- local MAX_FOLLOW_LEADER = 16
-- local TARGET_FOLLOW_LEADER = (MAX_FOLLOW_LEADER + MIN_FOLLOW_LEADER) / 2
-- 被追赶时更容易往家里赶
local function koalefantGetLeader(inst)
    return inst.sg and inst.sg:HasStateTag("running") and inst.components.follower ~= nil and inst.components.follower.leader or nil
end
AddBrainPostInit("koalefantbrain",
                 function(self) if self.bt.root.children then table.insert(self.bt.root.children, 4, Follow(self.inst, koalefantGetLeader, 4, 24, 8)) end end)
local function spatGetLeader(inst) return inst.components.follower ~= nil and inst.components.follower.leader or nil end
AddBrainPostInit("spatbrain",
                 function(self) if self.bt.root.children then table.insert(self.bt.root.children, 6, Follow(self.inst, spatGetLeader, 8, 24, 12)) end end)
