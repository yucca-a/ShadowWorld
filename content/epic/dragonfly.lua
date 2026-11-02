local attackspeedup = GetModConfigData("extra_change") and GetModConfigData("boss_attackspeed") or 1
if attackspeedup < 1.33 then TUNING.DRAGONFLY_ATTACK_PERIOD = TUNING.DRAGONFLY_ATTACK_PERIOD * 3 / 4 * attackspeedup end
-- 索敌范围增加
TUNING.DRAGONFLY_AGGRO_DIST = TUNING.DRAGONFLY_AGGRO_DIST + 5.5
-- 龙蝇加强，被攻击时若血量低于50%则必定狂暴
local function OnAttacked(inst, data)
    if inst:HasTag("swc2hm") then return end
    if not inst.enraged and inst.components.health and inst.components.health:GetPercent() <= 0.5 and not inst.components.health:IsDead() and
        not inst.modtransformtask then
        inst.sg:GoToState("idle")
        inst:PushEvent("transform", {transformstate = "fire"})
        inst.modtransformtask = inst:DoTaskInTime(1.5, function() inst.modtransformtask = nil end)
    end
end

local function generatehotstar(inst)
    if inst:HasTag("swc2hm") or inst.components.health:IsDead() then return end
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 25, {"staffhotlight2hm"})
    if #ents < 3 then
        for i = 1, 3 - #ents, 1 do
            local star = SpawnPrefab("staffhotlight2hm")
            star.Transform:SetPosition(x, y, z)
            star.index2hm = i
            star.boss2hm = inst
        end
    end
end

-- 龙蝇血量低于50%时,增加各种属性
local function fire(inst)
    if inst.components.health:IsDead() then return end
    generatehotstar(inst)
    if inst.components.sleeper then
        inst.components.sleeper:SetResistance(100000)
        inst.components.sleeper.AddSleepiness = nilfn
        inst.components.sleeper.GoToSleep = nilfn
    end
    if inst.components.freezable then
        inst.components.freezable:SetResistance(100000)
        inst.components.freezable.AddColdness = nilfn
        inst.components.freezable.Freeze = nilfn
    end
    if inst.components.stunnable then
        inst.components.stunnable.stun_resist = 100000
        inst.components.stunnable.Stun = nilfn
    end
    if inst.components.damagetracker then inst.components.damagetracker.damage_threshold = inst.components.damagetracker.damage_threshold * 1000 end
    -- if not inst.components.heater then
    --     inst:AddComponent("heater")
    --     inst.components.heater.heat = 150
    -- end
    inst:ListenForEvent("blocked", OnAttacked)
    inst:ListenForEvent("attacked", OnAttacked)
    inst.TransformNormal = inst.TransformFire
    if inst.reverttask ~= nil then inst.reverttask:Cancel() end
    if not inst.enraged then OnAttacked(inst) end
end
local function OnHealthTrigger(inst)
    if not inst.components.health:IsDead() then
        inst:DoTaskInTime(0.25, fire)
        inst.multithrow2hm = 3
        inst.aoethrow2hmangle = 15
    end
end

local function EquipWeapons(inst)
    if inst.components.inventory ~= nil and not inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) then
        -- 火球
        local thrower = CreateEntity()
        thrower.name = "Thrower"
        thrower.entity:AddTransform()
        thrower:AddComponent("weapon")
        thrower.components.weapon:SetDamage(inst.components.combat.defaultdamage * 2 / 3)
        thrower.components.weapon:SetRange(TUNING.WALRUS_ATTACK_DIST, TUNING.WALRUS_ATTACK_DIST + 4)
        thrower.components.weapon:SetProjectile("torchfireprojectile2hm")
        thrower:AddComponent("inventoryitem")
        thrower.persists = false
        thrower.components.inventoryitem:SetOnDroppedFn(thrower.Remove)
        thrower:AddComponent("equippable")
        thrower:AddTag("nosteal")
        inst.components.inventory:GiveItem(thrower)
        inst.weaponitems.thrower = thrower

        -- 普通攻击
        local hitter = CreateEntity()
        hitter.name = "Hitter"
        hitter.entity:AddTransform()
        hitter:AddComponent("weapon")
        hitter.components.weapon:SetDamage(inst.components.combat.defaultdamage)
        hitter.components.weapon:SetRange(0)
        hitter:AddComponent("inventoryitem")
        hitter.persists = false
        hitter.components.inventoryitem:SetOnDroppedFn(hitter.Remove)
        hitter:AddComponent("equippable")
        hitter:AddTag("nosteal")
        inst.components.inventory:GiveItem(hitter)
        inst.weaponitems.hitter = hitter
    end
end

local function EquipWeapon(inst, weapon)
    if not weapon.components.equippable:IsEquipped() then
        inst.components.inventory:Equip(weapon)
        if weapon.name == "Thrower" then
            inst.equipthrower = true
            weapon.components.weapon:SetDamage(inst.components.combat.defaultdamage * 2 / 3)
        elseif weapon.name == "Hitter" then
            inst.equipthrower = nil
            weapon.components.weapon:SetDamage(inst.components.combat.defaultdamage)
        end
    end
end

require("brains/dragonflybrain")
local CHASE_DIST_NEAR = TUNING.DRAGONFLY_ATTACK_RANGE * 1.75
local CHASE_DIST = TUNING.DRAGONFLY_ATTACK_RANGE * 2.5
AddBrainPostInit("dragonflybrain", function(self)
    if self.bt.root.children then
        local newaction = WhileNode(function()
            return self.inst.components.combat and self.inst.components.combat.target and
                       (self.inst.poundpstattack2hm or (self.inst.components.locomotor and self.inst.components.locomotor:GetWalkSpeed() < 4 and
                           not self.inst:IsNear(self.inst.components.combat.target, TUNING.DRAGONFLY_ATTACK_RANGE)) or
                           (not self.inst.can_ground_pound and
                               not self.inst:IsNear(self.inst.components.combat.target, self.inst.equipthrower and CHASE_DIST_NEAR or CHASE_DIST)))
        end, "Attack not Near", SequenceNode(
            {ActionNode(function() EquipWeapon(self.inst, self.inst.weaponitems.thrower) end, "Equip thrower"), ChaseAndAttack(self.inst)}))
        local newaction2 = SequenceNode({
            ActionNode(function() EquipWeapon(self.inst, self.inst.weaponitems.hitter) end, "Equip hitter"),
            ChaseAndAttack(self.inst)
        })
        table.insert(self.bt.root.children, 3, newaction)
        table.insert(self.bt.root.children, 4, newaction2)
    end
end)

local function endpoundpstattack(inst)
    if inst.poundpstattack2hm then
        inst.poundpstattack2hm = nil
        inst.aoethrow2hm = inst.enraged and 3 or nil
    end
end
AddStategraphPostInit("dragonfly", function(sg)
    local pound_post = sg.states.pound_post.onenter
    sg.states.pound_post.onenter = function(inst, ...)
        if inst.prefab == "dragonfly" then inst.poundpstattack2hm = true end
        pound_post(inst, ...)
    end
    local idle = sg.states.idle.onenter
    sg.states.idle.onenter = function(inst, ...)
        -- if inst.sg.mem.wantstospawn then
        --     inst.speedup2hm = true
        --     inst.components.locomotor:SetExternalSpeedMultiplier(inst, "spawning2hm", 1.4)
        -- elseif inst.speedup2hm then
        --     inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "spawning2hm")
        --     inst.speedup2hm = nil
        -- end
        if inst.poundpstattack2hm then
            if inst.components.combat and inst.components.combat.target and not inst.sg.mem.sleeping and not inst.sg.mem.wantstospawn then
                inst.sg:GoToState("attack")
                return
            else
                inst.poundpstattack2hm = nil
            end
        end
        idle(inst, ...)
    end
    -- local walk_start = sg.states.walk_start.onenter
    -- sg.states.walk_start.onenter = function(inst, ...)
    --     if inst.equipthrower and inst.components.combat and inst.components.combat.target and not inst.can_ground_pound and
    --         inst:IsNear(inst.components.combat.target, TUNING.WALRUS_ATTACK_DIST) then
    --         inst.sg:GoToState("idle")
    --         return
    --     end
    --     walk_start(inst, ...)
    -- end
    -- local walk = sg.states.walk.onenter
    -- sg.states.walk.onenter = function(inst, ...)
    --     if inst.equipthrower and inst.components.combat and inst.components.combat.target and not inst.can_ground_pound and
    --         inst:IsNear(inst.components.combat.target, TUNING.WALRUS_ATTACK_DIST) then
    --         inst.sg:GoToState("idle")
    --         return
    --     end
    --     walk(inst, ...)
    -- end
    local attack = sg.states.attack.onenter
    sg.states.attack.onenter = function(inst, ...)
        if inst.poundpstattack2hm then
            inst.aoethrow2hm = (inst.aoethrow2hm or 1) + 2
            -- inst:DoTaskInTime(1, endpoundpstattack)
        end
        if inst.components.locomotor and not inst.can_ground_pound and (inst.poundpstattack2hm or inst.equipthrower) then
            inst.components.locomotor:StopMoving()
        end
        attack(inst, ...)
    end
    local attackonexit = sg.states.attack.onexit
    sg.states.attack.onexit = function(inst, ...)
        if inst.poundpstattack2hm then endpoundpstattack(inst) end
        if attackonexit then attackonexit(inst, ...) end
    end
    -- AddStateTimeEvent2hm(sg.states.attack, 16 * FRAMES, function(inst)
    --     if inst.poundpstattack2hm then
    --         -- inst.aoethrow2hm = (inst.aoethrow2hm or 1) + 2
    --         endpoundpstattack(inst)
    --     end
    -- end)
end)

local function customdamagemultfn(inst, target, weapon, multiplier, mount)
    return target ~= nil and target:HasTag("player") and weapon ~= nil and inst.components.combat.playerdamagepercent or 1
end

local function OnKilledOther(inst, data)
    if data ~= nil and data.victim ~= nil then
        if data.victim:HasTag("player") or data.victim:HasTag("epic") or math.random() < 0.05 then
            local star = SpawnPrefab("staffhotlight2hm")
            local x, y, z = inst.Transform:GetWorldPosition()
            star.Transform:SetPosition(x, y, z)
            star.index2hm = math.random(3)
            star.boss2hm = inst
        end
    end
end

local function checkhealth(inst) if inst.components.health:GetPercent() < 0.50031 then OnHealthTrigger(inst) end end
AddPrefabPostInit("dragonfly", function(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("killed", OnKilledOther)
    if not inst.components.healthtrigger then inst:AddComponent("healthtrigger") end
    inst.components.healthtrigger:AddTrigger(0.50031, OnHealthTrigger)
    inst:DoTaskInTime(0, checkhealth)
    if not inst.components.inventory then inst:AddComponent("inventory") end
    inst.weaponitems = {}
    EquipWeapons(inst)
    if not inst.components.combat.customdamagemultfn then inst.components.combat.customdamagemultfn = customdamagemultfn end
    local oldTransformFire = inst.TransformFire
    inst.TransformFire = function(inst, ...)
        oldTransformFire(inst, ...)
        inst.aoethrow2hm = 3
        if inst.components.health:GetPercent() < 0.51 and inst.reverttask ~= nil then inst.reverttask:Cancel() end
    end
    local TransformNormal = inst.TransformNormal
    inst.TransformNormal = function(inst, ...)
        TransformNormal(inst, ...)
        if inst.poundpstattack2hm then inst.poundpstattack2hm = nil end
        inst.aoethrow2hm = nil
    end
end)

local function OnLavaeDeath2hm(inst, data)
    --If that was my last lavae & I'm out of lavaes to spawn then enrage.
    -- if inst.components.rampingspawner:GetCurrentWave() <= 0 then
    if data.remaining_spawns <= 0 then
        --Blargh!
        inst.components.rampingspawner:Stop()
        inst.components.rampingspawner:Reset()
        inst:PushEvent("transform", { transformstate = "fire" })
    end
end
-- 2025.8.1 melon:虫子死光必暴怒
AddPrefabPostInit("dragonfly", function(inst)
    if not TheWorld.ismastersim then return end
    inst.OnLavaeDeath2hm = OnLavaeDeath2hm
    inst:ListenForEvent("rampingspawner_death", inst.OnLavaeDeath2hm)
end)