local cooking = require "cooking"
local ingredients = cooking.ingredients
local function isfood(item)
    if item.components.edible and (item.components.edible.foodtype == FOODTYPE.VEGGIE or item.components.edible.foodtype == FOODTYPE.BERRY) then return true end
    local recipe = ingredients[item.prefab]
    if recipe and recipe.tags and (recipe.tags.fruit or recipe.tags.veggie) then return true end
end

TUNING.MONKEY_RANGED_DAMAGE = TUNING.MONKEY_MELEE_DAMAGE / 2

local function OnCooldown(inst) inst._cdtask2hm = nil end
local MONKEY_TAGS = {"monkey"}
local function NotBlocked(pt) return not TheWorld.Map:IsGroundTargetBlocked(pt) end
local function OnBlocked(inst, data)
    if inst._cdtask2hm == nil and inst:HasTag("nightmare") and not inst.sg:HasStateTag("attack") and data and data.attacker and data.attacker:IsValid() then
        inst._cdtask2hm = inst:DoTaskInTime(.3, OnCooldown)
        local pos = inst:GetPosition()
        pos.y = 0
        local x, y, z = inst.Transform:GetWorldPosition()
        local attackerpos = data.attacker:GetPosition()
        local monkeys = TheSim:FindEntities(x, y, z, 3, MONKEY_TAGS)
        local teleport = false
        for i, v in ipairs(monkeys) do
            if not v:HasTag("player") and v.components.health and not v.components.health:IsDead() and not v.sg:HasStateTag("attack") then
                if v.components.combat and not data.attacker:HasTag("monkey") then v.components.combat:SetTarget(data.attacker) end
                local theta = attackerpos ~= nil and v:GetAngleToPoint(attackerpos) or v.Transform:GetRotation()
                theta = (theta + 150 + math.random() * 60) * DEGREES
                local offs = FindWalkableOffset(pos, theta, math.random(8, 16), 8, false, true, NotBlocked, false, true) or
                                 FindWalkableOffset(pos, theta, math.random(4, 8), 6, false, true, NotBlocked, false, true)
                if offs ~= nil then
                    pos.x = pos.x + offs.x
                    pos.z = pos.z + offs.z
                end
                v.Physics:Teleport(pos:Get())
                if v._cdtask2hm == nil then v._cdtask2hm = v:DoTaskInTime(.3, OnCooldown) end
                if attackerpos ~= nil then v:ForceFacePoint(attackerpos) end
                teleport = true
            end
        end
        if teleport then SpawnPrefab("shadow_puff").Transform:SetPosition(x, y, z) end
    end
end

local function onmonkeysleep(inst) if inst.nobanana2hm then inst.nobanana2hm = nil end end

local RETARGET_MUST_TAGS = {"_combat"}
local RETARGET_CANT_TAGS = {"playerghost"}
local RETARGET_ONEOF_TAGS = {"character", "monster"}
AddPrefabPostInit("monkey", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.FindTargetOfInterestTask then inst.FindTargetOfInterestTask:Cancel() end
    -- 猴子的便便也有伤害了
    inst:ListenForEvent("entitysleep", onmonkeysleep)
    inst.components.combat:SetDefaultDamage(10)
    -- 猴子仇恨携带素食的玩家
    local oldretargetfn = inst.components.combat.targetfn
    inst.components.combat:SetRetargetFunction(inst.components.combat.retargetperiod or 1, function(inst, ...)
        local target, f = oldretargetfn(inst, ...)
        if target then return target, f end
        if not inst:HasTag("nightmare") then
            local target = FindEntity(inst, TUNING.BUNNYMAN_SEE_MEAT_DIST, function(guy)
                return guy.components.inventory ~= nil and inst.components.combat:CanTarget(guy) and guy.components.inventory:FindItem(isfood) ~= nil
            end, RETARGET_MUST_TAGS, RETARGET_CANT_TAGS, RETARGET_ONEOF_TAGS)
            if target then return target, false end
        end
    end)
    -- 正常猴子没有便便时会消耗身上的掉落物香蕉来生成一个便便
    local HasAmmo = inst.HasAmmo
    inst.HasAmmo = function(inst, ...)
        local result = HasAmmo(inst, ...)
        if not result and not inst:HasTag("nightmare") and not inst.nobanana2hm then
            inst.nobanana2hm = true
            if inst.components.inventory then inst.components.inventory:GiveItem(SpawnPrefab("poop")) end
            return true
        end
        return result
    end
    inst:ListenForEvent("attacked", OnBlocked)
    -- 猴子暗影化时不会掉落小肉,正常时不会掉落燃料
    if inst.components.lootdropper then
        local SpawnLootPrefab = inst.components.lootdropper.SpawnLootPrefab
        inst.components.lootdropper.SpawnLootPrefab = function(self, lootprefab, ...)
            if lootprefab and
                (lootprefab == (inst:HasTag("nightmare") and "smallmeat" or "nightmarefuel") or (inst.nobanana2hm and lootprefab == "cave_banana")) then
                return
            end
            return SpawnLootPrefab(self, lootprefab, ...)
        end
    end
end)

-- 暗影猴也会投掷便便
local function EquipWeapon(inst, weapon) if not weapon.components.equippable:IsEquipped() then inst.components.inventory:Equip(weapon) end end
AddBrainPostInit("nightmaremonkeybrain", function(self)
    if self.bt.root.children then
        table.insert(self.bt.root.children, 2, WhileNode(function() return self.inst.components.combat.target and self.inst:HasAmmo() end, "Attack Player",
                                                         SequenceNode(
            {ActionNode(function() EquipWeapon(self.inst, self.inst.weaponitems.thrower) end, "Equip thrower"), ChaseAndAttack(self.inst, 60, 40)})))
    end
end)
-- 普通猴子会对任何目标丢便便
AddBrainPostInit("monkeybrain", function(self)
    if self.bt.root.children and self.bt.root.children[4] and self.bt.root.children[4].name == "Parallel" and self.bt.root.children[4].children and
        self.bt.root.children[4].children[1] and self.bt.root.children[4].children[1].name == "Attack Player" and self.bt.root.children[4].children[1].fn then
        self.bt.root.children[4].children[1].fn = function(...) return self.inst.components.combat.target and self.inst:HasAmmo() end
    end
end)

-- 妥协缝合发条、蠕虫和洞穴海棠互相友好
if not ModManager:GetMod("workshop-2039181790") then return end
-- 巨炮投掷物排除猴子
AddPrefabPostInit("roship_projectile", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.complexprojectile then
        inst.components.complexprojectile.onhitfn = function(inst, ...)
            local x, y, z = inst.Transform:GetWorldPosition()

            SpawnPrefab("electric_explosion").Transform:SetPosition(x, 0, z)
            SpawnPrefab("bishop_charge_hit").Transform:SetPosition(inst.Transform:GetWorldPosition())

            local ents = TheSim:FindEntities(x, 0, z, 5, { "_health" }, { "shadow", "INLIMBO", "chess" , "monkey2hm"})

            if #ents > 0 then
                for i, v in ipairs(ents) do
                    if v.components.health ~= nil and not v.components.health:IsDead() and v.components.combat ~= nil then
                        v.components.combat:GetAttacked_Internal(inst, 50, nil)
                    end
                end
            end
            inst:Remove()
        end
    end
end)

local function Shockness(inst, x, y, z)
    x = x + math.random(-3, 3)
    z = z + math.random(-3, 3)

    SpawnPrefab("electricchargedfx").Transform:SetPosition(x, 0, z)

    local targets = TheSim:FindEntities(x, y, z, 1, { "_health" }, { "playerghost", "chess", "monkey2hm" }) --Todo, make it shock other things?

    for k, v in pairs(targets) do
        if v.components.health ~= nil and not v.components.health:IsDead() then
            if not (v.components.inventory ~= nil and v.components.inventory:IsInsulated()) then
                if not v:HasTag("electricdamageimmune") then
                    local insulated = (v:HasTag("electricdamageimmune") or
                        (v.components.inventory ~= nil and v.components.inventory:IsInsulated()))

                    local mult = not insulated
                        and TUNING.ELECTRIC_DAMAGE_MULT + TUNING.ELECTRIC_WET_DAMAGE_MULT * (v.components.moisture ~= nil and v.components.moisture:GetMoisturePercent() or (v:GetIsWet() and 1 or 0))
                        or 1

                    local damage = -10 * mult

                    if v.sg ~= nil and not v.sg:HasStateTag("nointerrupt") and not insulated then
                        v.sg:GoToState("electrocute")
                    end

                    v.components.health:DoDelta(damage, nil, inst.prefab, nil, inst) --From the onhit stuff...
                end
            end
        end
    end
end
local function Spark(inst)
    if inst:HasTag("preelectrified") and not inst.sg:HasStateTag("dying") then
        local x, y, z = inst.Transform:GetWorldPosition()

        local x1 = x + math.random(-0.5, 0.5)
        local z1 = z + math.random(-0.5, 0.5)
        SpawnPrefab("electricchargedfx").Transform:SetPosition(x1, 0, z1)

        SpawnPrefab("sparks").Transform:SetPosition(x1, 0 + 0.25 * math.random(), z1)
        if inst.count == 0 then
            if not inst:HasTag("electrified") then
                inst:AddTag("electrified")
            end
            for k = 1, 3 do
                Shockness(inst, x, y, z)
            end
        else
            inst.count = inst.count - 1
        end
    end
end

-- 超载奇械电击排除猴子
AddPrefabPostInit("bight", function(inst)
    if not TheWorld.ismastersim then return end
    local src = "../mods/workshop-2039181790/scripts/prefabs/bight.lua"
    local periodtask = nil
    local count_task = 0
    if inst.pendingtasks then
        -- TheNet:SystemMessage(tostring(GetTableSize(inst.pendingtasks)))
        for a,b in pairs(inst.pendingtasks) do
            -- TheNet:SystemMessage(debug.getinfo(a.fn, "S").source or "nil")
            -- 路径对、间隔对
            if debug.getinfo(a.fn, "S").source == src and a.period == 0.25 then
                periodtask = a
                count_task = count_task + 1
            end
        end
    end
    if periodtask ~= nil and count_task == 1 then
        periodtask:Cancel() -- 取消原有task
        inst.tasktime = 0.25
        inst.taskPG = inst:DoPeriodicTask(inst.tasktime, Spark)
    end
end)

-- 缝合发条禁止仇恨
local UM_chess = {"knook", "roship", "bight"}
for i,v in pairs(UM_chess) do
    AddPrefabPostInit(v, function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.combat then
            inst.components.combat:AddNoAggroTag("monkey2hm")
        end
    end)
end

-- 蠕虫禁止仇恨
local UM_worm = {"worm", "shockworm", "viperworm", "viperling"}
for i,v in pairs(UM_worm) do
    AddPrefabPostInit(v, function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.combat then
            inst.components.combat:AddNoAggroTag("monkey2hm")
        end
    end)
end

-- 海棠禁止仇恨
AddPrefabPostInit("monkey", function(inst)
    inst:AddTag("monkey2hm")
    if not TheWorld.ismastersim then return end
    if inst.components.combat then
        for i, v in pairs(UM_chess) do
            inst.components.combat:AddNoAggroTag(v)
        end
        inst.components.combat:AddNoAggroTag("worm")
    end
end)
