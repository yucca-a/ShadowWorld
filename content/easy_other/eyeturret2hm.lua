-- The existing eyeturret option owns all changes in this file.
local DAMAGE, HEALTH, REGEN = 200, 2000, 50
local CHAIN_RANGE, CHAIN_JUMPS, CHAIN_MULT = 6, 4, 0.8
local ARMOR_TIME, ARMOR_CD = 10, 60
local CHAIN_CANT_TAGS = {"INLIMBO", "notarget", "invisible", "flight", "FX", "DECOR", "player", "playerghost",
                         "eyeturret", "structure", "wall", "engineering", "companion", "player_aligned", "domesticated"}

local function Alive(inst)
    return inst ~= nil and inst:IsValid() and inst.components.health ~= nil and not inst.components.health:IsDead()
end

local function KillGlacialHound(attacker, target)
    if target ~= nil and target.prefab == "glacialhound" and Alive(target) then
        -- UM's ice shield redirects even Health:ForceKill(). SetVal still runs
        -- native death events/loot, but skips combat, redirects and absorption.
        local health = target.components.health
        local oldpercent = health:GetPercent()
        target.components.combat.lastattacker = attacker
        health:SetVal(0, "eyeturret", attacker)
        target:PushEvent("healthdelta", {oldpercent = oldpercent, newpercent = health:GetPercent(),
            overtime = false, cause = "eyeturret", afflicter = attacker, amount = -oldpercent * health.maxhealth})
        return true
    end
    return false
end

local function IgniteCreature(inst, target)
    if not inst.eyeturretfire2hm or not Alive(target) or target.components.burnable == nil or
        target:HasOneOfTags({"fireimmune", "player", "structure", "wall", "eyeturret", "engineering"}) then return end
    local fx = target.eyeturretsafefire2hm
    if fx ~= nil and fx:IsValid() then
        fx:Refresh(inst)
    else
        fx = SpawnPrefab("eyeturret_safefire2hm")
        if fx ~= nil then fx:Attach(target, inst) end
    end
end

-- Plant creatures can ignite themselves when receiving native electric hits,
-- including on leaving the electrocute state. Route those tower-caused fires
-- through the same contained flame; ordinary fire sources keep their behaviour.
AddComponentPostInit("burnable", function(self)
    local ignite = self.Ignite
    self.Ignite = function(self, immediate, source, doer, ...)
        local attacker = doer ~= nil and doer.eyeturretenhanced2hm and doer or
            (source ~= nil and source.eyeturretenhanced2hm and source or nil)
        if attacker == nil and source ~= nil and source.components.inventoryitem ~= nil then
            local owner = source.components.inventoryitem.owner
            if owner ~= nil and owner.eyeturretenhanced2hm then attacker = owner end
        end
        if attacker ~= nil then
            IgniteCreature(attacker, self.inst)
            return
        end
        return ignite(self, immediate, source, doer, ...)
    end
end)

local function HasFriendlyLeader(target)
    local seen = {}
    for i = 1, 8 do
        if seen[target] then return true end
        seen[target] = true
        local follower = target.components.follower
        target = follower ~= nil and follower.leader or nil
        if target == nil or not target:IsValid() then return false end
        if target:HasOneOfTags({"player", "companion", "eyeturret", "player_aligned"}) then return true end
    end
    return true
end

local function ChainTarget(inst, target, visited)
    if visited[target] or target == inst or not Alive(target) or target.components.combat == nil or
        target:HasOneOfTags(CHAIN_CANT_TAGS) or HasFriendlyLeader(target) or
        inst.components.combat:IsAlly(target) or not inst.components.combat:CanTarget(target) then return false end
    local enemy = target.components.combat.target
    return target:HasTag("hostile") or enemy == inst or
        (enemy ~= nil and enemy:IsValid() and enemy:HasOneOfTags({"player", "eyeturret", "companion"}))
end

local function OnProjectileHit(projectile, inst, target)
    if not Alive(inst) or not inst.eyeturretenhanced2hm or target == nil or not target:IsValid() then return end
    IgniteCreature(inst, target)
    local visited = {[target] = true, [inst] = true}
    local previous = target
    local combat = inst.components.combat
    for hop = 1, CHAIN_JUMPS do
        local x, y, z = previous.Transform:GetWorldPosition()
        local nearest, distance
        for _, candidate in ipairs(TheSim:FindEntities(x, y, z, CHAIN_RANGE, {"_combat"}, CHAIN_CANT_TAGS)) do
            if ChainTarget(inst, candidate, visited) then
                local dsq = previous:GetDistanceSqToInst(candidate)
                if distance == nil or dsq < distance or (dsq == distance and candidate.GUID < nearest.GUID) then
                    nearest, distance = candidate, dsq
                end
            end
        end
        if nearest == nil then break end
        visited[nearest] = true
        local hit = SpawnPrefab("electrichitsparks")
        if hit ~= nil then hit:AlignToTarget(nearest, previous, true) end
        if not KillGlacialHound(inst, nearest) then
            -- A projectile argument settles damage immediately instead of
            -- launching another eye_charge. Native electric/defence maths stay intact.
            local ignore = combat.ignorehitrange
            combat.ignorehitrange = true
            combat:DoAttack(nearest, combat:GetWeapon(), projectile, "electric", CHAIN_MULT ^ hop)
            combat.ignorehitrange = ignore
            IgniteCreature(inst, nearest)
        end
        previous = nearest
        if not Alive(inst) or not previous:IsValid() then break end
    end
end

AddPrefabPostInit("eye_charge", function(inst)
    if not TheWorld.ismastersim then return end
    local projectile = inst.components.projectile
    local onprehit, onhit = projectile.onprehit, projectile.onhit
    projectile:SetOnPreHitFn(function(projectileinst, attacker, target)
        if onprehit ~= nil then onprehit(projectileinst, attacker, target) end
        if attacker ~= nil and attacker.eyeturretenhanced2hm then
            projectile.stimuli = "electric"
            KillGlacialHound(attacker, target)
        end
    end)
    projectile:SetOnHitFn(function(projectileinst, attacker, target)
        OnProjectileHit(projectileinst, attacker, target)
        if onhit ~= nil then onhit(projectileinst, attacker, target) end
    end)
end)

local function AddHorns(recipe)
    for _, ingredient in ipairs(recipe.ingredients) do
        if ingredient.type == "lightninggoathorn" then
            ingredient.amount = ingredient.amount + 2
            return
        end
    end
    table.insert(recipe.ingredients, Ingredient("lightninggoathorn", 2))
end
AddRecipePostInit("eyeturret_item", AddHorns)
AddRecipePostInit("eyeturret", AddHorns) -- keep native deconstruction materials consistent
-- UM's Wathom alternate recipe produces the same deployable turret.
AddRecipePostInit("wathom_eyeturret_item", AddHorns)

local function EquipElectricWeapon(inst)
    local weapon = inst.components.combat:GetWeapon()
    if weapon ~= nil and weapon.components.weapon ~= nil then
        weapon.components.weapon:SetDamage(DAMAGE)
        weapon.components.weapon:SetElectric()
    end
end

local function UpgradeTest(inst, item)
    return Alive(inst) and ((item.prefab == "dragon_scales" and not inst.eyeturretfire2hm) or
                           (item.prefab == "shroom_skin" and not inst.eyeturretspore2hm))
end

local function OnUpgrade(inst, giver, item)
    if item.prefab == "dragon_scales" then
        inst.eyeturretfire2hm = true
    elseif item.prefab == "shroom_skin" then
        inst.eyeturretspore2hm = true
        inst:AddTag("eyeturretsporeproof2hm")
    end
    if giver ~= nil and giver.components.talker ~= nil then
        giver.components.talker:Say(TUNING.isCh2hm and (item.prefab == "dragon_scales" and "炮塔已获得隔离火焰。" or
            "炮塔已免疫孢子云。") or (item.prefab == "dragon_scales" and "Turret upgraded: contained flames." or
            "Turret upgraded: spore immunity."))
    end
end

local function ArmorFX(inst)
    if inst.poor_armor2hm_fx == nil or not inst.poor_armor2hm_fx:IsValid() then
        local fx = SpawnPrefab("forcefieldfx")
        if fx == nil then return end
        inst.poor_armor2hm_fx = fx
        fx.entity:SetParent(inst.entity)
        fx:AddTag("NOCLICK")
        fx:AddTag("FX")
        local radius = inst:GetPhysicsRadius(0.2) + 0.5
        fx.Transform:SetPosition(0, radius + 0.2, 0)
        fx.Transform:SetScale(radius, radius, radius)
        fx:DoTaskInTime(ARMOR_TIME, fx.Remove)
    end
end

local function OnHealthDelta(inst, data)
    if data == nil or not Alive(inst) or data.newpercent >= data.oldpercent then return end
    local key = data.newpercent < 0.33 and "poor_33cdtask2hm" or
        (data.newpercent < 0.66 and data.newpercent > 0.33 and "poor_66cdtask2hm" or nil)
    if key ~= nil and inst[key] == nil then
        ArmorFX(inst)
        inst.allmiss2hm = true
        if inst.eyeturretarmortask2hm ~= nil then inst.eyeturretarmortask2hm:Cancel() end
        inst.eyeturretarmortask2hm = inst:DoTaskInTime(ARMOR_TIME, function(i)
            i.allmiss2hm = nil
            i.eyeturretarmortask2hm = nil
        end)
        inst[key] = inst:DoTaskInTime(ARMOR_CD, function(i) i[key] = nil end)
    end
end

AddPrefabPostInit("eyeturret", function(inst)
    inst:AddTag("trader")
    if not TheWorld.ismastersim then return end
    inst.eyeturretenhanced2hm = true
    inst.components.health:SetMaxHealth(HEALTH)
    inst.components.health:StartRegen(REGEN, 1)
    inst.components.combat:SetDefaultDamage(DAMAGE)
    inst:ListenForEvent("equip", EquipElectricWeapon)
    inst:DoTaskInTime(0, EquipElectricWeapon)
    inst:ListenForEvent("healthdelta", OnHealthDelta)
    -- Retain the original two shields. New placements now begin at full health.
    inst.hasplaced2hm = true
    if inst.components.trader == nil then inst:AddComponent("trader") end
    local trader = inst.components.trader
    local test, onaccept = trader.test, trader.onaccept
    trader:SetAcceptTest(function(i, item, giver, count)
        if item.prefab == "dragon_scales" or item.prefab == "shroom_skin" then
            return (count == nil or count == 1) and UpgradeTest(i, item)
        end
        return test ~= nil and test(i, item, giver, count) or false
    end)
    trader:SetOnAccept(function(i, giver, item, ...)
        if item.prefab == "dragon_scales" or item.prefab == "shroom_skin" then
            OnUpgrade(i, giver, item)
        elseif onaccept ~= nil then
            onaccept(i, giver, item, ...)
        end
    end)
    SetOnSave(inst, function(i, data)
        data.eyeturretupgrades2hm = {fire = i.eyeturretfire2hm or nil, spore = i.eyeturretspore2hm or nil}
        data.hasplaced2hm = true
    end)
    SetOnLoad(inst, function(i, data)
        local upgrades = data ~= nil and data.eyeturretupgrades2hm or nil
        if upgrades ~= nil then
            i.eyeturretfire2hm = upgrades.fire or nil
            i.eyeturretspore2hm = upgrades.spore or nil
            if i.eyeturretspore2hm then i:AddTag("eyeturretsporeproof2hm") end
        end
    end)
end)

-- Restrict immunity to these clouds; the tower still takes other aura damage.
for _, prefab in ipairs({"sporecloud", "sporecloud_toad"}) do
    AddPrefabPostInit(prefab, function(inst)
        if not TheWorld.ismastersim or inst.components.aura == nil then return end
        local tags = {}
        for _, tag in ipairs(inst.components.aura.auraexcludetags) do table.insert(tags, tag) end
        table.insert(tags, "eyeturretsporeproof2hm")
        inst.components.aura.auraexcludetags = tags
    end)
end
