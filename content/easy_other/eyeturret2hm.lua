-- The existing eyeturret option owns all changes in this file.
local DAMAGE, HEALTH, REGEN = 200, 2000, 50
local CHAIN_RANGE, CHAIN_JUMPS, CHAIN_MULT = 6, 4, 0.8
local ARMOR_TIME, ARMOR_CD = 10, 60
local RECOVERY_TIMER = "eyeturret_recovery2hm"
local RECOVERY_TIME = 5 * TUNING.TOTAL_DAY_TIME
local EYE_FADE_OUT, EYE_FADE_IN = 0.6, 0.8
local deployingUpgrades
-- NewConstant's ruins turrets use shadoweyeturret / shadoweyeturret2 and
-- share eye_charge with the friendly vanilla turret. Never infer allegiance
-- from the projectile, current combat target, or an enhancement flag alone.
local ENEMY_TURRET_TAGS = {"hostile", "shadoweyeturret"}
local function IsFriendlyTurret(inst)
    return inst ~= nil and inst:IsValid() and inst.prefab == "eyeturret" and
        inst:HasTag("companion") and not inst:HasOneOfTags(ENEMY_TURRET_TAGS)
end
local function IsEnhancedTurret(inst)
    return IsFriendlyTurret(inst) and inst.eyeturretenhanced2hm
end
local function IsUpgradeTarget(inst)
    return inst ~= nil and inst:IsValid() and
        ((inst.prefab == "eyeturret_item" and not inst:HasOneOfTags(ENEMY_TURRET_TAGS)) or IsFriendlyTurret(inst))
end
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
    if not IsEnhancedTurret(inst) or not inst.eyeturretfire2hm or not Alive(target) or target.components.burnable == nil or
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
        local attacker = IsEnhancedTurret(doer) and doer or
            (IsEnhancedTurret(source) and source or nil)
        if attacker == nil and source ~= nil and source.components.inventoryitem ~= nil then
            local owner = source.components.inventoryitem.owner
            if IsEnhancedTurret(owner) then attacker = owner end
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
    if not Alive(inst) or not IsEnhancedTurret(inst) or target == nil or not target:IsValid() then return end
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
        if IsEnhancedTurret(attacker) then
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
    if not IsEnhancedTurret(inst) then return end
    local weapon = inst.components.combat:GetWeapon()
    if weapon ~= nil and weapon.components.weapon ~= nil then
        weapon.components.weapon:SetDamage(DAMAGE)
        weapon.components.weapon:SetElectric()
    end
end

local function UpgradeTest(inst, item)
    return IsUpgradeTarget(inst) and (inst.prefab == "eyeturret_item" or Alive(inst)) and
                          ((item.prefab == "dragon_scales" and not inst.eyeturretfire2hm) or
                           (item.prefab == "shroom_skin" and not inst.eyeturretspore2hm))
end

local function ApplyUpgrades(inst, upgrades)
    if not IsUpgradeTarget(inst) then return end
    inst.eyeturretfire2hm = upgrades.fire or nil
    inst.eyeturretspore2hm = upgrades.spore or nil
    if inst.eyeturretspore2hm then inst:AddTag("eyeturretsporeproof2hm") end
end

local function OnUpgrade(inst, giver, item)
    if not IsUpgradeTarget(inst) then return end
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

local function RefundUpgrades(inst)
    if not IsUpgradeTarget(inst) then return end
    local fire, spore = inst.eyeturretfire2hm, inst.eyeturretspore2hm
    -- Clear first: even a repeated deconstruction event must not refund twice.
    inst.eyeturretfire2hm, inst.eyeturretspore2hm = nil, nil
    inst:RemoveTag("eyeturretsporeproof2hm")
    for prefab, upgraded in pairs({dragon_scales = fire, shroom_skin = spore}) do
        if upgraded then
            if inst.components.lootdropper ~= nil then
                inst.components.lootdropper:SpawnLootPrefab(prefab)
            else
                local item = SpawnPrefab(prefab)
                if item ~= nil then item.Transform:SetPosition(inst.Transform:GetWorldPosition()) end
            end
        end
    end
end

-- Inventory tiles request right-click USEITEM actions. Native alltrader GIVE is
-- normally left-click only, so expose the same native action for these materials.
AddComponentAction("USEITEM", "inventoryitem", function(inst, doer, target, actions, right)
    if right and IsUpgradeTarget(target) and target.prefab == "eyeturret_item" and target:HasTag("alltrader") and
        (inst.prefab == "dragon_scales" or inst.prefab == "shroom_skin") then
        for _, action in ipairs(actions) do if action == ACTIONS.GIVE then return end end
        table.insert(actions, ACTIONS.GIVE)
    end
end)

local function InstallUpgradeReceiver(inst)
    if not IsUpgradeTarget(inst) then return end
    inst:AddTag("trader")
    inst:AddTag("alltrader") -- dragon_scales/shroom_skin have no native tradable component
    if not TheWorld.ismastersim then return end
    if inst.components.trader == nil then inst:AddComponent("trader") end
    local trader = inst.components.trader
    trader.acceptnontradable = true
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
    inst:ListenForEvent("ondeconstructstructure", RefundUpgrades)
    SetOnSave(inst, function(i, data)
        if not IsUpgradeTarget(i) then return end
        data.eyeturretupgrades2hm = {fire = i.eyeturretfire2hm or nil, spore = i.eyeturretspore2hm or nil}
        if i.prefab == "eyeturret" then data.hasplaced2hm = true end
    end)
    SetOnLoad(inst, function(i, data)
        local upgrades = data ~= nil and data.eyeturretupgrades2hm or nil
        if upgrades ~= nil then ApplyUpgrades(i, upgrades) end
    end)
end

AddPrefabPostInit("eyeturret_item", function(inst)
    InstallUpgradeReceiver(inst)
    if not TheWorld.ismastersim then return end
    local ondeploy = inst.components.deployable.ondeploy
    inst.components.deployable.ondeploy = function(item, ...)
        -- The native deploy callback spawns the turret synchronously and then
        -- removes the item. Transfer during its prefab init, before removal;
        -- keep the native placement, skins, physics and other mod callbacks.
        local previous = deployingUpgrades
        deployingUpgrades = {fire = item.eyeturretfire2hm, spore = item.eyeturretspore2hm}
        local function finish(ok, ...)
            deployingUpgrades = previous
            if not ok then error((...), 0) end
            return ...
        end
        return finish(pcall(ondeploy, item, ...))
    end
end)

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
    if data == nil or not IsEnhancedTurret(inst) or not Alive(inst) or data.newpercent >= data.oldpercent then return end
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

local function CancelEyeFade(inst)
    if inst.eyeturretfadetask2hm ~= nil then
        inst.eyeturretfadetask2hm:Cancel()
        inst.eyeturretfadetask2hm = nil
    end
end

local function FadeEye(inst, targetalpha, duration, clearcolour)
    CancelEyeFade(inst)
    local colour = inst.eyeturretcolour2hm
    local _, _, _, startalpha = inst.AnimState:GetMultColour()
    local started = GetTime()
    local function Step(i)
        local t = duration > 0 and math.min(1, (GetTime() - started) / duration) or 1
        -- Smoothstep eases both ends without moving/scaling the separate base.
        local eased = t * t * (3 - 2 * t)
        i.AnimState:SetMultColour(colour[1], colour[2], colour[3], startalpha + (targetalpha - startalpha) * eased)
        if t >= 1 then
            i.eyeturretfadetask2hm = nil
            if clearcolour then i.eyeturretcolour2hm = nil end
        else
            i.eyeturretfadetask2hm = i:DoTaskInTime(FRAMES, Step)
        end
    end
    if startalpha == targetalpha then duration = 0 end
    Step(inst)
end

local function BeginRecovery(inst, immediate)
    if not IsEnhancedTurret(inst) then return end
    local wasrecovering = inst.eyeturretrecovering2hm
    inst.eyeturretrecovering2hm = true
    inst.components.health:StopRegen()
    inst.components.combat:DropTarget()
    inst:StopBrain(RECOVERY_TIMER)
    for _, key in ipairs({"eyeturretarmortask2hm", "poor_33cdtask2hm", "poor_66cdtask2hm"}) do
        if inst[key] ~= nil then inst[key]:Cancel(); inst[key] = nil end
    end
    inst.allmiss2hm = nil
    if inst.poor_armor2hm_fx ~= nil then
        if inst.poor_armor2hm_fx:IsValid() then inst.poor_armor2hm_fx:Remove() end
        inst.poor_armor2hm_fx = nil
    end
    if inst._lighttask ~= nil then inst._lighttask:Cancel(); inst._lighttask = nil end
    inst._lightframe:set(24) -- native eyeturret's completed light-charge frame
    inst.Light:Enable(false)
    inst.Light:SetRadius(0)
    -- Only the parent's eye animation becomes transparent. The separate native
    -- base stays visible/clickable; skins, obstacle physics and minimap survive.
    if inst.eyeturretcolour2hm == nil then inst.eyeturretcolour2hm = {inst.AnimState:GetMultColour()} end
    if immediate == true then
        FadeEye(inst, 0, 0) -- loading a resting save must not replay the eye's disappearance
    elseif not wasrecovering then
        FadeEye(inst, 0, EYE_FADE_OUT)
    end
    inst.sg:GoToState("eyeturret_recover2hm")
    if not inst.components.timer:TimerExists(RECOVERY_TIMER) then
        inst.components.timer:StartTimer(RECOVERY_TIMER, RECOVERY_TIME)
    end
end

local function FinishRecovery(inst, data)
    if data.name ~= RECOVERY_TIMER or not IsEnhancedTurret(inst) or not inst.eyeturretrecovering2hm then return end
    inst.eyeturretrecovering2hm = nil
    inst.components.health.causeofdeath = nil
    inst.components.health:SetPercent(1)
    inst.components.health:StartRegen(REGEN, 1)
    FadeEye(inst, inst.eyeturretcolour2hm[4], EYE_FADE_IN, true)
    inst.components.combat:DropTarget()
    inst.sg:GoToState("idle")
    inst:RestartBrain(RECOVERY_TIMER)
    EquipElectricWeapon(inst)
end

AddStategraphState("eyeturret", State{
    name = "eyeturret_recover2hm",
    tags = {"busy"},
    onenter = function(inst) inst:syncanim("idle_loop", true) end,
    events = {
        EventHandler("death", function() end),
        EventHandler("freeze", function() end),
    },
})
AddStategraphPostInit("eyeturret", function(sg)
    local onenter = sg.states.death.onenter
    sg.states.death.onenter = function(inst, ...)
        if IsEnhancedTurret(inst) then
            BeginRecovery(inst)
        else
            return onenter(inst, ...)
        end
    end
end)

local function InstallRecovery(inst)
    local health = inst.components.health
    health.nofadeout = true
    inst.base.client_forward_target = inst -- clicking the visible base selects its tower
    inst.components.inventory:DisableDropOnDeath() -- retain the native projectile weapon
    if inst.components.timer == nil then inst:AddComponent("timer") end
    local setval = health.SetVal
    health.SetVal = function(self, val, ...)
        -- External healing and save/load HUD updates cannot wake a resting tower.
        return setval(self, inst.eyeturretrecovering2hm and 0 or val, ...)
    end
    inst:ListenForEvent("death", BeginRecovery)
    inst:ListenForEvent("timerdone", FinishRecovery)
    inst:ListenForEvent("onremove", CancelEyeFade)
    SetOnSave(inst, function(i, data)
        data.eyeturretrecovering2hm = i.eyeturretrecovering2hm or nil
    end)
    SetOnPreLoad(inst, function(i, data)
        if data ~= nil and data.eyeturretrecovering2hm then
            -- Component loading order is arbitrary. Mark dead before Health's
            -- OnLoad to avoid replaying world death/kill-credit events on reload.
            i.eyeturretrecovering2hm = true
            i.components.health.currenthealth = 0
        end
    end)
    SetOnLoad(inst, function(i)
        if i.eyeturretrecovering2hm or i.components.health:IsDead() then BeginRecovery(i, true) end
    end)
    local description = inst.components.inspectable.descriptionfn
    inst.components.inspectable.descriptionfn = function(i, viewer)
        if i.eyeturretrecovering2hm then
            local days = math.max(0, i.components.timer:GetTimeLeft(RECOVERY_TIMER) or 0) / TUNING.TOTAL_DAY_TIME
            return string.format(TUNING.isCh2hm and "眼球正在休养，约 %.1f 天后恢复。仍可用拆解法杖拆除。" or
                "The eye is resting: about %.1f days remaining. It can still be deconstructed.", days)
        end
        return description ~= nil and description(i, viewer) or i.components.inspectable.description
    end
end

AddPrefabPostInit("eyeturret_base", function(inst)
    if TheWorld.ismastersim then return end
    local replicated = inst.OnEntityReplicated
    inst.OnEntityReplicated = function(i, ...)
        if replicated ~= nil then replicated(i, ...) end
        local parent = i.entity:GetParent()
        if IsFriendlyTurret(parent) then i.client_forward_target = parent end
    end
end)

AddPrefabPostInit("greenstaff", function(inst)
    if not TheWorld.ismastersim then return end
    local caster = inst.components.spellcaster
    local cancast = caster.CanCast
    caster.CanCast = function(self, doer, target, ...)
        if IsEnhancedTurret(target) and target.eyeturretrecovering2hm then
            -- Native CanCast rejects zero-health targets. Relax only that check
            -- for this tower, retaining recipe/visibility/spell restrictions.
            local previous = self.canuseondead
            self.canuseondead = true
            local function finish(ok, ...)
                self.canuseondead = previous
                if not ok then error((...), 0) end
                return ...
            end
            return finish(pcall(cancast, self, doer, target, ...))
        end
        return cancast(self, doer, target, ...)
    end
end)

AddPrefabPostInit("eyeturret", function(inst)
    if not IsFriendlyTurret(inst) then return end
    InstallUpgradeReceiver(inst)
    if not TheWorld.ismastersim then return end
    if deployingUpgrades ~= nil and not deployingUpgrades.used then
        ApplyUpgrades(inst, deployingUpgrades)
        deployingUpgrades.used = true
    end
    inst.eyeturretenhanced2hm = true
    inst.components.health:SetMaxHealth(HEALTH)
    inst.components.health:StartRegen(REGEN, 1)
    inst.components.combat:SetDefaultDamage(DAMAGE)
    InstallRecovery(inst)
    inst:ListenForEvent("equip", EquipElectricWeapon)
    inst:DoTaskInTime(0, EquipElectricWeapon)
    inst:ListenForEvent("healthdelta", OnHealthDelta)
    -- Retain the original two shields. New placements now begin at full health.
    inst.hasplaced2hm = true
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
