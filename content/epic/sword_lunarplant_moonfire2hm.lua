local SWORD_TAG2HM = "sword_shadow2hm"
local SWORD_LEAP_TAG2HM = "swordleap2hm"
local SWORD_STATE2HM = "swordleapstate2hm"
local SWORD_MATERIAL2HM = "lunar_seed"
local SWORD_SPELL2HM = "SWORDLUNARPLANT2HM"
local SWORD_NAME2HM_CH = "附魔亮茄剑"
local SWORD_NAME2HM_EN = "Infused Sword Lunarplant"

local SWORD_DMG2HM = 200
local SWORD_PLANAR2HM = 300
local SWORD_AOE_DMG2HM = 300
local SWORD_AOE_PLANAR2HM = 400
local SWORD_AOE_RADIUS2HM = 4
local SWORD_LEAP_WEAR2HM = 1
local SWORD_RANGE2HM = 6
local MOONFIRE_TIME2HM = 3 * 30
local MOONFIRE_PERIOD2HM = 10
local MOONFIRE_DMG2HM = 20
local MOONFIRE_RANGE2HM = 1.5
local MOONFIRE_HITS2HM = math.floor(MOONFIRE_TIME2HM / MOONFIRE_PERIOD2HM) + 1

local ENEMY_CANT_TAGS2HM = {"INLIMBO", "playerghost", "player", "companion", "wall", "flight", "invisible", "notarget", "noattack"}

local function IsLeapSword2hm(inst)
    if inst == nil or not inst:IsValid() or inst.prefab ~= "sword_lunarplant" then return false end
    if inst:HasTag(SWORD_LEAP_TAG2HM) then return true end
    return inst._leap2hm ~= nil and inst._leap2hm:value()
end

local function GetUsedSword2hm(inst, action)
    if action ~= nil and action.invobject ~= nil and IsLeapSword2hm(action.invobject) then
        return action.invobject
    end
    local inv = inst.replica ~= nil and inst.replica.inventory or (inst.components ~= nil and inst.components.inventory) or nil
    local equip = inv ~= nil and inv:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
    if IsLeapSword2hm(equip) then return equip end
    return nil
end

local function IsSwordReady2hm(sword)
    if sword.components.rechargeable then return sword.components.rechargeable:IsCharged() end
    return sword._moonfire_ready2hm ~= nil and sword._moonfire_ready2hm:value()
end

local function CancelSwordCast2hm(doer)
    if doer.sg and doer.sg.currentstate.name == "combat_leap_start" then
        doer:ClearBufferedAction()
        doer.sg:GoToState("idle")
    end
    return false
end

local function FindEnemies2hm(x, z, range, owner)
    local list = {}
    local ents = TheSim:FindEntities(x, 0, z, range, {"_combat"}, ENEMY_CANT_TAGS2HM)
    for i = 1, #ents do
        local v = ents[i]
        if v ~= owner and v.components.health ~= nil and not v.components.health:IsDead() and v.components.combat:CanBeAttacked() then
            table.insert(list, v)
        end
    end
    return list
end

local function MakeDamageCarrier2hm(x, z, dmg, planar, name)
    local carrier = CreateEntity()
    carrier.entity:AddTransform()
    carrier.Transform:SetPosition(x, 0, z)
    carrier:AddComponent("combat")
    carrier.components.combat:SetDefaultDamage(dmg)
    carrier:AddComponent("planardamage")
    carrier.components.planardamage:SetBaseDamage(planar)
    carrier.persists = false
    carrier.displaynamefn = function() return name end
    carrier.nameoverride = "sword_lunarplant"
    return carrier
end

local function SpawnMoonfire2hm(target, owner)
    if not TheWorld.ismastersim then return end
    if target == nil or not target:IsValid() then return end
    local x, y, z = target.Transform:GetWorldPosition()
    local flame = SpawnPrefab("warg_mutated_breath_fx")
    if flame ~= nil then
        flame.Transform:SetPosition(x, 0, z)
        flame:RestartFX(1.2 + 0.3 * math.random(), "nofade", {})
        if flame.spawn_embers_task then flame.spawn_embers_task:Cancel() end
        if flame.kill_fx_task then flame.kill_fx_task:Cancel() end
        flame.kill_fx_task = flame:DoTaskInTime(MOONFIRE_TIME2HM * FRAMES, function(f)
            if f:IsValid() then
                if f.AnimState then f.AnimState:PlayAnimation("flame" .. tostring(math.random(3)) .. "_pst") end
                f:DoTaskInTime(1, function(f2) if f2:IsValid() then f2:Remove() end end)
            end
        end)
    end
    local dmg = MakeDamageCarrier2hm(x, z, 0, MOONFIRE_DMG2HM, TUNING.isCh2hm and "月火" or "Moonfire")
    local hits = 0
    local function tick()
        hits = hits + 1
        if hits > MOONFIRE_HITS2HM then return false end
        local enemies = FindEnemies2hm(x, z, MOONFIRE_RANGE2HM, owner)
        for i = 1, #enemies do
            dmg.components.combat:DoAttack(enemies[i], nil, nil, nil, nil, MOONFIRE_RANGE2HM)
        end
        return true
    end
    if tick() then
        dmg.dmgtask = dmg:DoPeriodicTask(MOONFIRE_PERIOD2HM * FRAMES, function()
            if not tick() then
                dmg.dmgtask:Cancel()
                if dmg:IsValid() then dmg:Remove() end
            end
        end)
    else
        if dmg:IsValid() then dmg:Remove() end
    end
end

local function ReticuleTargetFn2hm()
    local player = ThePlayer
    local ground = TheWorld.Map
    local pos = Vector3()
    for r = 7, 0, -.25 do
        pos.x, pos.y, pos.z = player.entity:LocalToWorldSpace(r, 0, 0)
        if ground:IsPassableAtPoint(pos:Get()) and not ground:IsGroundTargetBlocked(pos) then return pos end
    end
    return pos
end

local function EnableReticule2hm(inst, enable)
    if enable then
        if inst.components.reticule == nil then
            inst:AddComponent("reticule")
            inst.components.reticule.reticuleprefab = "reticuleaoe"
            inst.components.reticule.pingprefab = "reticuleaoeping"
            inst.components.reticule.targetfn = ReticuleTargetFn2hm
            inst.components.reticule.validcolour = {1, .75, 0, 1}
            inst.components.reticule.invalidcolour = {.5, 0, 0, 1}
            inst.components.reticule.ease = true
            inst.components.reticule.mouseenabled = true
            inst.components.reticule.ispassableatallpoints = true
            if ThePlayer and ThePlayer.components.playercontroller ~= nil and ThePlayer.replica and ThePlayer.replica.inventory and
                ThePlayer.replica.inventory:IsHolding(inst) then ThePlayer.components.playercontroller:RefreshReticule() end
        end
    elseif inst.components.reticule ~= nil then
        inst:RemoveComponent("reticule")
        if ThePlayer and ThePlayer.components.playercontroller ~= nil and ThePlayer.replica and ThePlayer.replica.inventory and
            ThePlayer.replica.inventory:IsHolding(inst) then ThePlayer.components.playercontroller:RefreshReticule() end
    end
end

local function SwordOnPreLeap2hm(sword, doer, startingpos, targetpos)
end

local function SwordOnLeapt2hm(sword, doer, startingpos, targetpos)
    if sword.components.finiteuses ~= nil then
        sword.components.finiteuses:Use(SWORD_LEAP_WEAR2HM)
    end
    if sword.pulse_fx2hm ~= nil and sword.pulse_fx2hm:IsValid() then
        sword.pulse_fx2hm.AnimState:PlayAnimation("meteorground_pst")
        sword.pulse_fx2hm.AnimState:SetDeltaTimeMultiplier(1)
        sword.pulse_fx2hm:ListenForEvent("animover", sword.pulse_fx2hm.Remove)
        sword.pulse_fx2hm = nil
    end

    if doer ~= nil and doer.components.locomotor ~= nil and startingpos ~= nil and targetpos ~= nil then
        local range = math.sqrt(distsq(startingpos.x, startingpos.z, targetpos.x, targetpos.z))
        doer.leapvelocity2hm = nil
        doer.components.locomotor.isrunning = true
        doer.Physics:SetMotorVel(range / 2 + 12.5, 0, 0)
        doer.components.locomotor:StartUpdatingInternal()
    end
    if doer ~= nil and doer.sg ~= nil then
        doer.sg:RemoveStateTag("busy")
        doer.sg:RemoveStateTag("doing")
        doer.sg:RemoveStateTag("nopredict")
    end
    if doer ~= nil and doer.components.playercontroller ~= nil then
        doer.components.playercontroller:Enable(true)
    end
end

local SWORD_RIGHT_CD2HM = 10

local function SwordLeapSpell2hm(sword, target, pos, doer)
    if not TheWorld.ismastersim or doer == nil or not doer:IsValid() then return end
    if not IsSwordReady2hm(sword) then return CancelSwordCast2hm(doer) end
    if pos == nil and target ~= nil and target:IsValid() then pos = target:GetPosition() end
    if pos == nil then return CancelSwordCast2hm(doer) end
    if not (TheWorld.Map:IsAboveGroundAtPoint(pos.x, pos.y, pos.z) or TheWorld.Map:GetPlatformAtPoint(pos.x, pos.z) ~= nil) then
        if doer.components.talker ~= nil then
            doer.components.talker:Say(TUNING.isCh2hm and "唔,差点跳到海里" or "Swimming is not a good idea.")
        end
        return CancelSwordCast2hm(doer)
    end
    sword.components.rechargeable:Discharge(SWORD_RIGHT_CD2HM)
    sword._rightleap2hm = true
    sword:DoTaskInTime(1.5, function(s) s._rightleap2hm = nil end)
    if doer.components.combat ~= nil then doer.components.combat:RestartCooldown() end
    doer:PushEvent("combat_leap", {targetpos = pos, weapon = sword})
    local fx = SpawnPrefab("alterguardian_phase3trapgroundfx")
    if fx ~= nil then
        fx.Transform:SetPosition(pos.x, 0, pos.z)
        fx.AnimState:SetDeltaTimeMultiplier(4)
        fx.AnimState:SetMultColour(1, 1, 1, 0.5)
        fx:DoTaskInTime(3, fx.Remove)
        sword.pulse_fx2hm = fx
    end
end

local function UpdateSwordSpell2hm(sword)
    if not sword._sword_shadow2hm then return end
    local ready = IsSwordReady2hm(sword)
    local spellcaster = sword.components.spellcaster
    if spellcaster then
        spellcaster.canuseontargets = ready
        spellcaster.canuseondead = ready
        spellcaster.canuseonpoint = ready
        spellcaster.canuseonpoint_water = ready
        spellcaster:SetSpellFn(ready and SwordLeapSpell2hm or nil)
    end
    sword._moonfire_ready2hm:set(ready)
    sword._reticule2hm:set(ready)
end

local SwordLeapState2hm = State{
    name = SWORD_STATE2HM,
    tags = {"attack", "backstab", "busy", "notalking", "abouttoattack", "pausepredict", "nointerrupt"},
    onenter = function(inst)
        local buffaction = inst:GetBufferedAction()
        local target = buffaction ~= nil and buffaction.target or nil
        inst.components.combat:SetTarget(target)
        inst.components.combat:StartAttack()
        inst.AnimState:PlayAnimation("atk_leap", false)
        inst.Transform:SetEightFaced()
        inst.components.locomotor:Stop()
        inst.components.locomotor:EnableGroundSpeedMultiplier(false)
        if inst.components.playercontroller ~= nil then inst.components.playercontroller:RemotePausePrediction() end
    end,
    onexit = function(inst)
        if inst.sg:HasStateTag("abouttoattack") then inst.components.combat:CancelAttack() end
        inst.Transform:SetFourFaced()
        inst.components.locomotor:Stop()
        inst.Physics:ClearMotorVelOverride()
        inst.components.locomotor:EnableGroundSpeedMultiplier(true)
        inst:DoTaskInTime(0, function(i) if i.components.playercontroller ~= nil then i.components.playercontroller:Enable(true) end end)
    end,
    timeline =
    {
        TimeEvent(0 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/common/deathpoof")
            inst.Physics:ClearCollisionMask()
            inst.Physics:CollidesWith(COLLISION.WORLD)
            local buffaction = inst:GetBufferedAction()
            local target = buffaction ~= nil and buffaction.target or nil
            if target ~= nil and target:IsValid() then
                local x, y, z = inst.Transform:GetWorldPosition()
                local tx, ty, tz = target.Transform:GetWorldPosition()
                inst:ForceFacePoint(tx, 0, tz)
                inst.sg.statemem.leaprange2hm = math.sqrt(distsq(x, z, tx, tz))
                inst.leapvelocity2hm = inst.sg.statemem.leaprange2hm / (12 * FRAMES)
            end
        end),
        TimeEvent(12 * FRAMES, function(inst)
            inst.sg:RemoveStateTag("abouttoattack")
            inst.components.locomotor:Stop()
            inst.Physics:ClearMotorVelOverride()
            inst:PerformBufferedAction()
            inst.components.locomotor:EnableGroundSpeedMultiplier(true)
            inst.sg:RemoveStateTag("busy")
            if inst.components.playercontroller ~= nil then inst.components.playercontroller:Enable(false) end
            inst.Physics:CollidesWith(COLLISION.OBSTACLES)
            inst.Physics:CollidesWith(COLLISION.SMALLOBSTACLES)
        end),
        TimeEvent(14 * FRAMES, function(inst)
            inst.leapvelocity2hm = 12.5
            SpawnPrefab("dirt_puff").Transform:SetPosition(inst.Transform:GetWorldPosition())
        end),
        TimeEvent(19 * FRAMES, function(inst) SpawnPrefab("dirt_puff").Transform:SetPosition(inst.Transform:GetWorldPosition()) end),
        TimeEvent(24 * FRAMES, function(inst)
            inst.sg:RemoveStateTag("busy")
            inst.sg:RemoveStateTag("attack")
            inst.sg:RemoveStateTag("nointerrupt")
            inst.sg:RemoveStateTag("pausepredict")
            inst.sg:AddStateTag("idle")
            inst.leapvelocity2hm = 0
            inst.Physics:Stop()
            inst.Physics:CollidesWith(COLLISION.CHARACTERS)
            inst.Physics:CollidesWith(COLLISION.GIANTS)
            if inst.components.playercontroller ~= nil then inst.components.playercontroller:Enable(true) end
        end),
    },
    onupdate = function(inst)
        if inst.leapvelocity2hm then inst.Physics:SetMotorVel(inst.leapvelocity2hm, 0, 0) end
    end,
    events = {EventHandler("animover", function(inst) inst.sg:GoToState("idle") end)},
}
AddStategraphState("wilson", SwordLeapState2hm)
AddStategraphPostInit("wilson", function(sg)
    local _OldCast = sg.actionhandlers[ACTIONS.CASTSPELL].deststate
    sg.actionhandlers[ACTIONS.CASTSPELL].deststate = function(inst, action, ...)
        local sword = GetUsedSword2hm(inst, action)
        if sword ~= nil and not IsSwordReady2hm(sword) then return end
        if sword ~= nil and not (inst.components.rider ~= nil and inst.components.rider:IsRiding()) then
            return "combat_leap_start"
        end
        return _OldCast(inst, action, ...)
    end
    local _OldAttack = sg.actionhandlers[ACTIONS.ATTACK].deststate
    sg.actionhandlers[ACTIONS.ATTACK].deststate = function(inst, action, ...)
        if GetUsedSword2hm(inst, action) ~= nil and action.target ~= nil and action.target:IsValid() and
            not (inst.components.rider ~= nil and inst.components.rider:IsRiding()) then
            return SWORD_STATE2HM
        end
        return _OldAttack(inst, action, ...)
    end
end)
AddStategraphPostInit("wilson_client", function(sg)
    local _OldCast = sg.actionhandlers[ACTIONS.CASTSPELL].deststate
    sg.actionhandlers[ACTIONS.CASTSPELL].deststate = function(inst, action, ...)
        local sword = GetUsedSword2hm(inst, action)
        if sword ~= nil and not IsSwordReady2hm(sword) then return end
        local rider = inst.replica ~= nil and inst.replica.rider or nil
        if sword ~= nil and not (rider ~= nil and rider:IsRiding()) then
            return "combat_leap_start"
        end
        return _OldCast(inst, action, ...)
    end
    local _OldAttack = sg.actionhandlers[ACTIONS.ATTACK].deststate
    sg.actionhandlers[ACTIONS.ATTACK].deststate = function(inst, action, ...)
        if GetUsedSword2hm(inst, action) ~= nil then
            return "combat_leap_start"
        end
        return _OldAttack(inst, action, ...)
    end
    sg.states.combat_leap_start.server_states[hash(SWORD_STATE2HM)] = true
end)

-- Also reject a stale queued/predicted CASTSPELL before playing its wind-up.
-- Ordinary ATTACK uses the same client anticipation state and stays available.
for _, graph in ipairs({"wilson", "wilson_client"}) do
    AddStategraphPostInit(graph, function(sg)
        local state = sg.states.combat_leap_start
        local onenter = state.onenter
        state.onenter = function(inst, ...)
            local action = inst:GetBufferedAction()
            local sword = action and action.action == ACTIONS.CASTSPELL and GetUsedSword2hm(inst, action) or nil
            if sword and not IsSwordReady2hm(sword) then return CancelSwordCast2hm(inst) end
            return onenter(inst, ...)
        end
    end)
end

local function SwordActFn2hm(act, inst)
    if act.action == ACTIONS.CASTSPELL and act.pos == nil and act.target ~= nil then
        act.pos = DynamicPosition(not TheNet:IsDedicated() and TheInput:GetWorldPosition() or act.target:GetPosition())
    end
end

local function ApplySwordUpgrade2hm(sword)
    if sword == nil or not sword:IsValid() then return end
    sword._sword_shadow2hm = true
    sword:AddTag(SWORD_TAG2HM)
    sword:AddTag(SWORD_LEAP_TAG2HM)
    if sword.components.finiteuses ~= nil and sword._repaircap2hm == nil then
        sword._repaircap2hm = true
        local fu = sword.components.finiteuses
        local oldRepair = fu.Repair
        fu.Repair = function(self, amount, ...)
            local total = self.total or 0
            if total > 0 and amount ~= nil and amount > total * 0.1 then
                amount = total * 0.1
            end
            return oldRepair(self, amount, ...)
        end
    end
    local fu2 = sword.components.finiteuses
    if fu2 ~= nil and fu2.SetPercent ~= nil and sword._repaircap3hm == nil then
        sword._repaircap3hm = true
        local oldSetPercent = fu2.SetPercent
        fu2.SetPercent = function(self, amount, ...)
            local cur = self:GetPercent()
            if amount ~= nil and amount > cur and amount - cur > 0.1 then
                amount = cur + 0.1
            end
            return oldSetPercent(self, amount, ...)
        end
    end
    if sword.components.repairable ~= nil and sword._repaircap2rep2hm == nil then
        sword._repaircap2rep2hm = true
        local rep = sword.components.repairable
        local oldRepairableRepair = rep.Repair
        rep.Repair = function(self, doer, repair_item, ...)
            local fu = self.inst.components.finiteuses
            local r = repair_item ~= nil and repair_item.components.repairer or nil
            local saved
            if fu ~= nil and r ~= nil and (r.finiteusesrepairvalue or 0) > 0 then
                local maxadd = (fu.total or 0) * 0.1
                if maxadd > 0 and r.finiteusesrepairvalue > maxadd then
                    saved = r.finiteusesrepairvalue
                    r.finiteusesrepairvalue = maxadd
                end
            end
            local ret = oldRepairableRepair(self, doer, repair_item, ...)
            if saved ~= nil then r.finiteusesrepairvalue = saved end
            return ret
        end
    end
    if sword._leap2hm ~= nil then sword._leap2hm:set(true) end
    if sword._reticule2hm ~= nil then sword._reticule2hm:set(true) end
    if sword.components.weapon ~= nil then
        sword.base_damage = SWORD_DMG2HM
        sword.components.weapon:SetDamage(SWORD_DMG2HM)
        sword.components.weapon.attackrange = SWORD_RANGE2HM
        sword.components.weapon.hitrange = sword.components.weapon.hitrange or SWORD_RANGE2HM
    end
    if sword.components.planardamage == nil then
        sword:AddComponent("planardamage")
    end
    sword.components.planardamage:SetBaseDamage(SWORD_PLANAR2HM)

    local oldonattack = sword.components.weapon.onattack
    if oldonattack ~= sword._sword_onattack_wrap2hm then
        sword._sword_onattack_wrap2hm = function(inst, attacker, target, skipsanity)
            if oldonattack ~= nil then oldonattack(inst, attacker, target, skipsanity) end
            if inst._rightleap2hm and target ~= nil and target:IsValid() and target:HasTag("epic") and
                target.components.health ~= nil and not target.components.health:IsDead() then
                target.components.health:DoDelta(-target.components.health.maxhealth * 0.01, attacker, "swordright2hm", true)
            end
            if target ~= nil and target:IsValid() then SpawnMoonfire2hm(target, attacker) end
        end
        sword.components.weapon.onattack = sword._sword_onattack_wrap2hm
    end

    if sword.components.aoeweapon_leap == nil then
        sword:AddComponent("aoeweapon_leap")
    end
    sword:AddTag("aoeweapon_leap")
    sword.components.aoeweapon_leap:SetDamage(SWORD_DMG2HM)
    sword.components.aoeweapon_leap:SetAOERadius(SWORD_AOE_RADIUS2HM)
    sword.components.aoeweapon_leap:SetTags("_combat")
    sword.components.aoeweapon_leap:SetWorkActions()
    sword.components.aoeweapon_leap:SetOnPreLeapFn(SwordOnPreLeap2hm)
    sword.components.aoeweapon_leap:SetOnLeaptFn(SwordOnLeapt2hm)

    if sword.components.spellcaster == nil then
        sword:AddComponent("spellcaster")
    end
    sword.components.spellcaster:SetSpellFn(SwordLeapSpell2hm)
    sword.components.spellcaster.canuseontargets = true
    sword.components.spellcaster.canuseondead = true
    sword.components.spellcaster.canuseonpoint = true
    sword.components.spellcaster.canuseonpoint_water = true
    sword.components.spellcaster.canusefrominventory = false
    sword.components.spellcaster.can_cast_fn = function(doer)
        local rider = doer.replica ~= nil and doer.replica.rider or doer.components.rider
        return IsSwordReady2hm(sword) and not (rider ~= nil and rider:IsRiding())
    end
    UpdateSwordSpell2hm(sword)
end

STRINGS.ACTIONS.CASTSPELL[SWORD_SPELL2HM] = TUNING.isCh2hm and "月火斩" or "Moonfire Slash"
STRINGS.ACTIONS.REPAIR2HM.UPGRADE = TUNING.isCh2hm and "升级" or "Upgrade"

AddPrefabPostInit("sword_lunarplant", function(inst)
    inst.spelltype = SWORD_SPELL2HM
    inst.actfn2hm = SwordActFn2hm
    inst._leap2hm = net_bool(inst.GUID, "sword_lunarplant.leap2hm", "swordleap2hmdirty")
    inst._reticule2hm = net_bool(inst.GUID, "sword_lunarplant.reticule2hm", "swordreticule2hmdirty")
    inst._moonfire_ready2hm = net_bool(inst.GUID, "sword_lunarplant.moonfireready2hm", "swordmoonfireready2hmdirty")
    inst:ListenForEvent("swordreticule2hmdirty", function(i) EnableReticule2hm(i, i._reticule2hm:value()) end)
    inst.repairmaterials2hm = {[SWORD_MATERIAL2HM] = 1}
    inst.repairtext2hm = "UPGRADE"
    local oldname = inst.displaynamefn
    inst.displaynamefn = function(self)
        if IsLeapSword2hm(self) or self:HasTag(SWORD_TAG2HM) then
            return (TUNING.isCh2hm and SWORD_NAME2HM_CH) or SWORD_NAME2HM_EN
        end
        return oldname ~= nil and oldname(self) or nil
    end
    if not TheWorld.ismastersim then return end
    -- Present before component loading so saved cooldowns restore in any load order.
    if not inst.components.rechargeable then inst:AddComponent("rechargeable") end
    inst.components.rechargeable:SetMaxCharge(SWORD_RIGHT_CD2HM)
    local charged, discharged = inst.components.rechargeable.onchargedfn, inst.components.rechargeable.ondischargedfn
    inst.components.rechargeable:SetOnChargedFn(function(sword)
        if charged then charged(sword) end
        UpdateSwordSpell2hm(sword)
    end)
    inst.components.rechargeable:SetOnDischargedFn(function(sword)
        if discharged then discharged(sword) end
        UpdateSwordSpell2hm(sword)
    end)
    inst:AddComponent("persistent2hm")
    inst:AddComponent("repairable2hm")
    inst.components.repairable2hm.ignoremax = true
    inst.components.repairable2hm.customrepair = function(sword, repairuse, doer, repair_item)
        if sword:HasTag(SWORD_TAG2HM) then
            return false
        end
        if repair_item and repair_item:IsValid() then
            if repair_item.components.stackable then
                repair_item.components.stackable:Get(1):Remove()
            else
                repair_item:Remove()
            end
        end
        ApplySwordUpgrade2hm(sword)
        return true
    end
    if inst.components.forgerepairable ~= nil then
        local _forgerep = inst.components.forgerepairable.onrepaired
        inst.components.forgerepairable.onrepaired = function(inst, ...)
            if _forgerep then _forgerep(inst, ...) end
            if inst:HasTag(SWORD_TAG2HM) then ApplySwordUpgrade2hm(inst) end
        end
    end
    SetOnSave2hm(inst, function(i, data) data.sword_shadow2hm = i._sword_shadow2hm or nil end)
    SetOnLoad2hm(inst, function(i, data)
        if data and data.sword_shadow2hm then ApplySwordUpgrade2hm(i) end
    end)
end)
