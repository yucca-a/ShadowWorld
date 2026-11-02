require("brains/malbatrossbrain")
TUNING.MALBATROSS_MAX_CHASEAWAY_DIST = TUNING.MALBATROSS_MAX_CHASEAWAY_DIST * 2
local function EquipWeapon2hm(inst)
    if inst.components.inventory ~= nil and not inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) then
        local thrower = CreateEntity()
        thrower.name = "Thrower"
        thrower.entity:AddTransform()
        thrower:AddComponent("weapon")
        thrower.components.weapon:SetDamage(inst.components.combat.defaultdamage / 4)
        thrower.components.weapon:SetRange(TUNING.WALRUS_ATTACK_DIST, TUNING.WALRUS_ATTACK_DIST + 4)
        thrower.components.weapon:SetProjectile("malbatross_feather2hm")
        thrower:AddComponent("inventoryitem")
        thrower.persists = false
        thrower.components.inventoryitem:SetOnDroppedFn(thrower.Remove)
        thrower:AddComponent("equippable")
        thrower:AddTag("nosteal")
        inst.components.inventory:GiveItem(thrower)
        inst.weapon2hm = thrower
    end
end
local function EquipWeapon(inst, weapon) if not weapon.components.equippable:IsEquipped() then inst.components.inventory:Equip(weapon) end end
local CHASE_DIST = TUNING.MALBATROSS_ATTACK_RANGE * 1.75
AddBrainPostInit("malbatrossbrain", function(self)
    if self.bt.root.children and self.bt.root.children[1] and self.bt.root.children[1].children and self.bt.root.children[1].children[2] and
        self.bt.root.children[1].children[2].children then
        local newaction = WhileNode(function()
            return self.inst.components.combat and self.inst.components.combat.target and
                       (not self.inst:IsNear(self.inst.components.combat.target, CHASE_DIST) or
                           (self.inst.components.locomotor and self.inst.components.locomotor:GetWalkSpeed() < 4 and
                               not self.inst:IsNear(self.inst.components.combat.target, TUNING.MALBATROSS_ATTACK_RANGE)))
        end, "Attack not Near", SequenceNode(
            {ActionNode(function() EquipWeapon(self.inst, self.inst.weapon2hm) end, "Equip thrower"), ChaseAndAttack(self.inst)}))
        local newaction2 = SequenceNode({ActionNode(function() EquipWeapon(self.inst, self.inst.weapon) end, "Equip hitter"), ChaseAndAttack(self.inst)})
        table.insert(self.bt.root.children[1].children[2].children, 3, newaction)
        table.insert(self.bt.root.children[1].children[2].children, 5, newaction2)
    end
end)

local function ondeath(inst) inst.spawnfeather = inst.oldspawnfeather2hm end
local function OnHealthTrigger(inst) inst.multithrow2hm = 5 end
-- 改动，受击概率俯冲，被妥协磁力回旋镖控制后大概率潜水攻击
local function OnAttacked(inst, data)
    if inst.components.health ~= nil and not inst.components.health:IsDead() and (not inst.sg:HasStateTag("busy") or inst.sg:HasStateTag("hit")) and data and
        data.attacker and data.attacker:IsValid() then
        if not inst.divetask2hm and math.random() < (inst.willdive and (inst.readytodive and 0.3 or 0.2) or 0.1) then
            inst.divetask2hm = inst:DoTaskInTime(10, function() inst.divetask2hm = nil end)
            inst:PushEvent("dosplash")
            -- if inst.sg.currentstate and inst.sg.currentstate.name ~= "combatdive" then
            -- inst.readytoswoop = false
            -- inst:PushEvent("doswoop", data.attacker)
            -- end
        elseif not inst.swooptask and inst:IsNear(data.attacker, 5) and math.random() <
            ((inst.willswoop and (inst.readytoswoop and 0.25 or 0.15) or 0.05) + (inst.magnerang and 0.15 or 0)) then
            inst.readytoswoop = false
            inst:PushEvent("doswoop", data.attacker)
            -- elseif math.random() < math.clamp((GetTime() - (inst.components.combat.laststartattacktime or 0)) / 60, 0.01, 0.1) then
            --     inst.sg:GoToState("attack", data.attacker)
        end
    end
end
local function ondoswoop(inst)
    if inst.swooptask then
        inst.swooptask:Cancel()
        inst.swooptask = nil
    end
end
-- 潜水失败就使用如来神掌
local function delayondodive(inst)
    if not inst.departcdtask2hm and inst.sg.currentstate and inst.sg.currentstate.name ~= "combatdive" and inst.components.combat.target and
        inst.components.health ~= nil and not inst.components.health:IsDead() and (not inst.sg:HasStateTag("busy") or inst.sg:HasStateTag("hit")) then
        inst.departcdtask2hm = inst:DoTaskInTime(60, function() inst.departcdtask2hm = nil end)
        local player = FindClosestPlayerToInst(inst, 10, true)
        if player and player:IsValid() then
            local boat = player:GetCurrentPlatform()
            if boat and boat:IsValid() and boat:HasTag("boat") then
                inst.sg:GoToState("depart2hm", boat)
            elseif player:IsOnOcean(true) then
                inst.sg:GoToState("depart2hm", player)
            end
        end
        -- TheNet:Announce("测试depart2hm", inst.sg.currentstate and inst.sg.currentstate.name)
    end
end
local function ondodive(inst) if not inst.departcdtask2hm then inst:DoTaskInTime(0, delayondodive) end end
TUNING.MALBATROSS_HEALTH = TUNING.MALBATROSS_HEALTH * 2
-- 原版谢天翁血量低于66% willdive 且10秒内未被攻击过，潜水可以靠近碰撞敌人攻击
-- 低于血量33%且敌人很近会俯冲攻击 willswoop CD 13~19秒，很可能被打断永久不再俯冲
AddPrefabPostInit("malbatross", function(inst)
    if not TheWorld.ismastersim then return end
    EquipWeapon2hm(inst)
    inst.multithrow2hm = 3
    if not inst.components.healthtrigger then inst:AddComponent("healthtrigger") end
    inst.components.healthtrigger:AddTrigger(0.50031, OnHealthTrigger)
    inst:DoTaskInTime(0, function() if inst.components.health:GetPercent() < 0.50031 then OnHealthTrigger(inst) end end)
    inst.oldspawnfeather2hm = inst.spawnfeather
    inst.spawnfeather = nilfn
    inst:ListenForEvent("attacked", OnAttacked)
    inst:ListenForEvent("death", ondeath)
    inst:ListenForEvent("doswoop", ondoswoop)
    inst:ListenForEvent("dosplash", ondodive)
end)
-- 改动，俯冲后概率尝试潜水，潜水出现位置概率是家的位置
AddStategraphPostInit("malbatross", function(sg)
    local diveonenter = sg.states.combatdive_pst.onenter
    sg.states.combatdive_pst.onenter = function(inst, ...)
        diveonenter(inst, ...)
        if inst.components.knownlocations and (inst.magnerang or (inst.components.health and inst.components.health:GetPercent() < 0.33)) and math.random() <
            0.66 then
            local pos = inst.components.knownlocations:GetLocation("home") or inst.components.knownlocations:GetLocation("spawnpoint")
            if pos then inst.Transform:SetPosition(pos.x, pos.y, pos.z) end
        end
    end
    local tauntonenter = sg.states.taunt.onenter
    sg.states.taunt.onenter = function(inst, ...)
        tauntonenter(inst, ...)
        if inst.sg.laststate and inst.sg.laststate.name == "swoop_pst" and math.random() < (inst.willdive and (inst.readytodive and 0.5 or 0.3) or 0.1) then
            inst:PushEvent("dosplash")
        end
    end
    AddStateTimeEvent2hm(sg.states.arrive, 13 * FRAMES, function(inst)
        if inst.arriveattack2hm then
            inst.arriveattack2hm = nil
            local x, y, z = inst.Transform:GetWorldPosition()
            SpawnPrefab("moonpulse_fx").Transform:SetPosition(x, y, z)
            inst.components.combat:DoAttack()
            local mindmg = inst.components.combat.defaultdamage / 10
            local boats = TheSim:FindEntities(x, y, z, 4.5, {"boat"})
            if #boats > 0 then
                for _, boat in ipairs(boats) do
                    if boat:IsValid() and boat.components.health and not boat.components.health:IsDead() and boat.components.boatphysics then
                        local velocity_length = VecUtil_Length(boat.components.boatphysics.velocity_x, boat.components.boatphysics.velocity_z)
                        local boatdmg = inst.components.combat.defaultdamage
                        if velocity_length and velocity_length > 0 then
                            boatdmg = boatdmg / 2
                            if velocity_length > 1 then boatdmg = math.max(boatdmg / velocity_length, mindmg) end
                        end
                        boat.components.health:DoDelta(-boatdmg)
                    end
                end
            end
        end
    end)
end)
-- 潜水时概率使用如来神掌
AddStategraphState("malbatross", State {
    name = "depart2hm",
    tags = {"busy", "nosleep", "nofreeze", "swoop", "flight" ,"noelectrocute"},
    onenter = function(inst, target)
        inst.components.locomotor:Stop()
        inst.AnimState:PlayAnimation("despawn")
        inst.sg.statemem.target = target
    end,
    timeline = {
        TimeEvent(6 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("saltydog/creatures/boss/malbatross/flap") end),
        TimeEvent(30 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("saltydog/creatures/boss/malbatross/flap") end),
        TimeEvent(32 * FRAMES, function(inst)
            inst.sg:AddStateTag("noattack")
            inst.components.health:SetInvincible(true)
        end),
        TimeEvent(4, function(inst)
            if inst.sg.statemem.target and inst.sg.statemem.target:IsValid() and inst.sg.statemem.target:IsOnOcean(true) then
                inst.Transform:SetPosition(inst.sg.statemem.target.Transform:GetWorldPosition())
            else
                local pos = inst.components.knownlocations:GetLocation("home") or inst.components.knownlocations:GetLocation("spawnpoint")
                if pos then inst.Transform:SetPosition(pos.x, pos.y, pos.z) end
            end
            inst.arriveattack2hm = true
            inst.sg:GoToState("arrive")
        end)
    },
    events = {
        EventHandler("animover", function(inst)
            if inst.sg.statemem.target and inst.sg.statemem.target:IsValid() and inst.sg.statemem.target:IsOnOcean(true) then
                inst.Transform:SetPosition(inst.sg.statemem.target.Transform:GetWorldPosition())
            else
                local pos = inst.components.knownlocations:GetLocation("home") or inst.components.knownlocations:GetLocation("spawnpoint")
                if pos then inst.Transform:SetPosition(pos.x, pos.y, pos.z) end
                inst.sg:GoToState("arrive")
                return
            end
            inst:Hide()
            if inst.Physics then inst.Physics:SetActive(false) end
            if inst.DynamicShadow then inst.DynamicShadow:Enable(true) end
        end)
    },
    onexit = function(inst)
        inst.components.health:SetInvincible(false)
        inst:Show()
        if inst.Physics then inst.Physics:SetActive(true) end
    end
})

-- 2025.9.12 melon:掉落增加1邪天翁喙、2飞翼风帆
AddSimPostInit(function()
    table.insert(LootTables['malbatross'],{'malbatross_beak',1})
    table.insert(LootTables['malbatross'],{'mast_malbatross_item',1})
    table.insert(LootTables['malbatross'],{'mast_malbatross_item',1})
end)