local enableexchange = GetModConfigData("shadowbeak") and GetModConfigData("crawlingshadow") ~= -1
local upgradebeak = GetModConfigData("shadowbeak")
local upgradeocean = GetModConfigData("oceanshadow")

-- 爬行恐惧死亡施放囚笼,且能为队友提供治疗
TUNING.CRAWLINGHORROR_HEALTH = TUNING.TERRORBEAK_HEALTH

-- 死亡时制造暗影囚笼
local function PillarsSpellFn(inst)
    if inst.disabledeath2hm or inst.wortox_minion then return end
    local x, y, z = inst.Transform:GetWorldPosition()
    local spell = SpawnPrefab("mod_hardmode_shadow_pillar_spell")
    spell.caster = inst
    local platform = TheWorld.Map:GetPlatformAtPoint(x, z)
    if platform ~= nil then
        spell.entity:SetParent(platform.entity)
        spell.Transform:SetPosition(platform.entity:WorldToLocalSpace(x, y, z))
    else
        spell.Transform:SetPosition(x, y, z)
    end
end
local function OnHelpAttacked(inst, data) if inst.helptask2hm then inst.readystophelptask2hm = 2 end end
-- 回血时无视非玩家一定程度的攻击,无视玩家的远程攻击
local function GetAttacked_Internal(inst, data)
    if inst.helptask2hm and inst.allmiss2hm and data and
        ((data.damage >= 34 and inst.helptask2hmindex > 0) or (data.attacker and data.attacker:HasTag("player") and
            (data.weapon == nil or
                (data.weapon.components.projectile == nil and (data.weapon.components.weapon == nil or data.weapon.components.weapon.projectile == nil))))) then
        inst.allmiss2hm = nil
    end
end
-- 爬行恐惧可以回血
local crawlings = {"crawlinghorror", "crawlingnightmare"}
for _, crawling in ipairs(crawlings) do
    AddPrefabPostInit(crawling, function(inst)
        if not TheWorld.ismastersim then return end
        inst:DoTaskInTime(0, function()
            if not inst.wortox_minion then
                inst.canhelp2hm = true
            end
        end)
        if not inst.components.timer then inst:AddComponent("timer") end
        inst:ListenForEvent("death", PillarsSpellFn)
        inst:ListenForEvent("GetAttacked_Internal2hm", GetAttacked_Internal)
        inst:ListenForEvent("attacked", OnHelpAttacked)
    end)
end
-- 回血时自我保护特效
local function showshieldfx(inst)
    local r, g, b, alpha = inst.AnimState:GetMultColour()
    local fx = SpawnPrefab("stalker_shield2hm")
    fx.AnimState:SetScale(-1.36, 1.36, 1.36)
    fx.AnimState:SetMultColour(r, g, b, alpha)
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
end
-- 回血特效
local function showtransitionfx(inst, size)
    size = size or .5
    local fx = SpawnPrefab("statue_transition_2")
    fx.Transform:SetScale(size, size, size)
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
end
-- 回血API
local function helpone(inst, source, value)
    if inst.components.health and not inst.components.health:IsDead() then
        if not inst.undergroundmovetask2hm then showtransitionfx(inst, .8) end
        if inst.canhelp2hm and inst.components.timer then
            local isself = inst == source
            if not isself and inst.helptask2hm and not inst.readystophelptask2hm then inst.readystophelptask2hm = 1 end
            -- 给自己回血时,自己的回血技能冷却保底8.5秒CD,每回1次加0.5秒CD,上限18秒CD
            -- 给别人回血时,令其的回血技能冷却保底8.5秒CD,每回1次加0.5秒CD,上限13秒CD
            local cd = (isself and inst.helptask2hmindex or ((source.helptask2hmindex or 0) - 10)) / 2 + 8
            if not inst.components.timer:TimerExists("healcd2hm") then
                inst.components.timer:StartTimer("healcd2hm", cd)
            elseif inst.components.timer:GetTimeLeft("healcd2hm") < cd then
                inst.components.timer:SetTimeLeft("healcd2hm", cd)
            end
        end
        inst.components.health:DoDelta(value)
    end
end
-- 破土而出
local function stopundergroundtask(inst, doattack)
    if inst.components.health:IsDead() then
        inst:Remove()
        return
    end
    inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "shadowhelphealth2hm")
    if inst.undergroundmovetask2hm then
        inst.undergroundmovetask2hm:Cancel()
        inst.undergroundmovetask2hm = nil
    end
    if inst.undergroundstoptask2hm then
        inst.undergroundstoptask2hm:Cancel()
        inst.undergroundstoptask2hm = nil
    end
    if inst.attacktostopundergroundtask then
        inst:RemoveEventCallback("newstate", inst.attacktostopundergroundtask)
        inst.attacktostopundergroundtask = nil
    end
    inst.components.combat.externaldamagetakenmultipliers:RemoveModifier(inst, "shadowhelphealth2hm")
    if inst.allmiss2hm then inst.allmiss2hm = nil end
    if doattack and inst.components.combat.target then inst.Transform:SetPosition(inst.components.combat.target.Transform:GetWorldPosition()) end
    if inst.components.combat.target and inst:IsNear(inst.components.combat.target, 6) then PillarsSpellFn(inst) end
    inst.sg:GoToState("appear")
    inst:Show()
end
-- 遁地攻击敌人
local function attacktostopundergroundtask(inst, data) if data and data.statename == "attack" then inst:DoTaskInTime(0, stopundergroundtask, true) end end
local function skillunderground(inst)
    if inst.components.health:IsDead() then
        inst:Remove()
        return
    end
    inst.components.locomotor:SetExternalSpeedMultiplier(inst, "shadowhelphealth2hm", 2)
    inst:Hide()
    inst.undergroundmovetask2hm = inst:DoPeriodicTask(15 * FRAMES, showtransitionfx)
    inst.undergroundstoptask2hm = inst:DoTaskInTime(3 + (4 - inst.helptask2hmindex) * 0.5, stopundergroundtask)
    inst.attacktostopundergroundtask = attacktostopundergroundtask
    inst:ListenForEvent("newstate", attacktostopundergroundtask)
end
-- 回血终止函数;洞穴影怪可以遁地攻击了,地表影怪15秒内再次触发此效果则也可以遁地攻击
local function stophelpshadow(inst, attacked)
    if inst.components.combat.target and not attacked and inst.helptask2hmindex < 20 and not inst.components.health:IsDead() and not inst.undergroundmovetask2hm and
        inst.components.timer then
        if TheWorld:HasTag("cave") or inst.components.timer:TimerExists("undergroundattack2hm") then
            inst.helptask2hm:Cancel()
            inst.helptask2hm = nil
            inst.sg:GoToState("taunt")
            inst.sg:AddStateTag("attack")
            inst.AnimState:PlayAnimation("disappear")
            inst:DoTaskInTime(inst.AnimState:GetCurrentAnimationLength(), skillunderground)
            return
        end
        inst.components.timer:StartTimer("undergroundattack2hm", 15)
    end
    inst.helptask2hm:Cancel()
    inst.helptask2hm = nil
    inst.components.combat.externaldamagetakenmultipliers:RemoveModifier(inst, "shadowhelphealth2hm")
    if inst.allmiss2hm then inst.allmiss2hm = nil end
end
-- 回血技能条件检测
local helptargettags = {"shadowcreature", "nightmarecreature", "shadowchesspiece"}
local function canhelpshadow(inst, onlyinst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 20, nil, nil, helptargettags)
    -- 有其他影怪正在放回血且快要或正在范围回血,则自己不再释放回血技能
    for index, ent in ipairs(ents) do
        if ent ~= inst and ent.helptask2hm and ent.helptask2hmindex and ent.helptask2hmindex > 8 and ent.helptask2hmindex < 12 then return false, ents end
    end
    -- 自己受伤必定释放回血或继续回血;其他影怪受伤则可以继续为其回血,其他影怪受伤且回血技能正在冷却则可以为其释放回血
    for index, ent in ipairs(ents) do
        if ent.components.health and not ent.components.health:IsDead() and ent.components.health:GetPercent() <
            (onlyinst and (1 - 0.2 / (1 - (ent.exchangetimes2hm or 0) * 0.0675)) or 1) and
            (ent == inst or not onlyinst or not ent.canhelp2hm or
                (ent.components.timer and ent.components.timer:TimerExists("healcd2hm") and not ent.helptask2hm)) then return true, ents end
    end
    return false, ents
end
-- 2025.8.2 melon:恢复附近绝望头/甲耐久
local dreadstonetags = {"dreadstone", "hardarmor"}
local function helpdreadstone(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 20, dreadstonetags, nil)
    for index, ent in ipairs(ents) do
        if ent:IsValid() and ent.components.armor and ent.components.equippable and ent.components.equippable.isequipped then -- 装备时才恢复
            ent.components.armor:Repair(10) -- 每次修复10耐久
        end
    end
end
-- 回血阶段函数
local function helpshadow(inst)
    if inst.readystophelptask2hm then
        stophelpshadow(inst, inst.readystophelptask2hm == 2)
        inst.readystophelptask2hm = nil
        return
    end
    -- 持续施放至多12秒,前6秒每0.5秒给自己回血25,后6秒每0.75秒给群体队友回血50
    inst.helptask2hmindex = inst.helptask2hmindex + 1
    if inst.helptask2hmindex > 20 or inst.components.health:IsDead() then
        stophelpshadow(inst)
        return
    end
    showshieldfx(inst)
    local needhelp, ents = canhelpshadow(inst)
    if not needhelp then
        stophelpshadow(inst)
        return
    end
    helpdreadstone(inst) -- 2025.8.2 melon:恢复附近绝望头/甲耐久
    if inst.helptask2hmindex == 12 then inst.helptask2hm.period = 0.75 end
    if inst.helptask2hmindex > 12 then
        local helpvalue = inst.components.health.maxhealth / 8
        -- 也会让队友技能CD,前三次回复更快,提前打断则CD变短
        for index, ent in ipairs(ents) do helpone(ent, inst, helpvalue) end
    else
        -- 前两次回复更多,打断则CD变短
        helpone(inst, inst, inst.components.health.maxhealth * 3 / (inst.helptask2hmindex < 3 and 16 or 48))
    end
end
-- 回血技能动画和检测释放
AddStategraphPostInit("shadowcreature", function(sg)
    local idle = sg.states.idle.onenter
    sg.states.idle.onenter = function(inst, ...)
        if not inst.wortox_minion and (inst.canhelp2hm and not inst.undergroundmovetask2hm and (inst.helptask2hm and not inst.readystophelptask2hm or
            (not inst.helptask2hm and inst.components.timer and not inst.components.timer:TimerExists("healcd2hm") and canhelpshadow(inst, true)))) then
            inst.sg:GoToState("taunt")
            return
        end
        idle(inst, ...)
    end
    -- 回血技能释放需要有影怪损失了80血量,如果不是自己受伤,那么要求该影怪不能回血或回血技能正在冷却,才能为其回血
    local taunt = sg.states.taunt.onenter
    sg.states.taunt.onenter = function(inst, ...)
        if inst.undergroundmovetask2hm then
            inst.sg:GoToState("idle")
            return
        elseif inst.canhelp2hm and not inst.helptask2hm and inst.components.timer and not inst.components.timer:TimerExists("healcd2hm") and
            canhelpshadow(inst, true) then
            showshieldfx(inst)
            inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, 0.01, "shadowhelphealth2hm")
            inst.helptask2hm = inst:DoPeriodicTask(0.5, helpshadow, 1)
            inst.allmiss2hm = true
            inst.helptask2hmindex = 0
        elseif inst.helptask2hm and inst.components.combat and inst.components.combat.target and not inst:IsNear(inst.components.combat.target, 20) then
            local x0, y0, z0 = inst.components.combat.target.Transform:GetWorldPosition()
            for k = 1, 4 --[[# of attempts]] do
                local x = x0 + math.random() * 20 - 10
                local z = z0 + math.random() * 20 - 10
                if TheWorld.Map:IsPassableAtPoint(x, 0, z) then
                    inst.Physics:Teleport(x, 0, z)
                    break
                end
            end
        end
        taunt(inst, ...)
    end
end)

-- 影怪转换
if enableexchange then
    -- 影怪转换条件,位于洞穴,转换次数少于6次,有仇恨,损失血量100点以上,关键技能正在冷却
    local function cancrawlingexchange(inst)
        return inst.canexchange2hm and not inst.disableexchange2hm and (inst.exchangetimes2hm or 0) < 4 and inst.components.combat.target and
                   not inst.helptask2hm and
                   ((inst.exchangetimes2hm or 0) > 0 or inst.components.health:GetPercent() < (1 - 0.25 / (1 - (inst.exchangetimes2hm or 0) * 0.0675))) and
                   inst.components.timer and inst.components.timer:TimerExists("healcd2hm")
    end
    local function canbeakexchange(inst)
        return inst.canexchange2hm and not inst.disableexchange2hm and (inst.exchangetimes2hm or 0) < 4 and inst.components.combat.target and
                   not inst.hidetask2hm and inst.components.health:GetPercent() < (1 - 0.25 / (1 - (inst.exchangetimes2hm or 0) * 0.0675)) and
                   (not upgradebeak or (inst.components.timer and inst.components.timer:TimerExists("shadowstrikecd2hm")))
    end
    local function canexchangeocean(inst)
        return inst.canexchange2hm and not inst.disableexchange2hm and (inst.exchangetimes2hm or 0) < 4 and inst.components.combat.target and
                   not inst.taunttask2hm and inst.components.health:GetPercent() < (1 - 0.25 / (1 - (inst.exchangetimes2hm or 0) * 0.0675)) and
                   (not upgradeocean or (inst.components.timer and inst.components.timer:TimerExists("tauntcd2hm")))
    end
    local conditions = {
        terrorbeak = canbeakexchange,
        nightmarebeak = canbeakexchange,
        crawlinghorror = cancrawlingexchange,
        crawlingnightmare = cancrawlingexchange,
        oceanhorror2hm = canexchangeocean,
        oceanhorror = canexchangeocean
    }
    local function onattacked(inst, data)
        if not inst.wortox_minion and not inst.canexchange2hm and not inst.disableexchange2hm and data then
            if data.attacker and data.attacker:HasTag("player") and data.attacker.components.locomotor and data.attacker.components.locomotor:GetRunSpeed() >=
                ((TheWorld:HasTag("cave") or inst:HasTag("nightmarecreature")) and 9 or 10.8) then
                inst.canexchange2hm = true
            elseif data.damage and data.damage >= ((TheWorld:HasTag("cave") or inst:HasTag("nightmarecreature")) and 100 or 150) then
                inst.canexchange2hm = true
            end
        end
    end
    for prefab, _ in pairs(conditions) do
        AddPrefabPostInit(prefab, function(inst)
            if not TheWorld.ismastersim then return end
            inst:ListenForEvent("attacked", onattacked)
        end)
    end
    AddStategraphPostInit("shadowcreature", function(sg)
        local idle = sg.states.idle.onenter
        sg.states.idle.onenter = function(inst, ...)
            if not inst.wantstodespawn and conditions[inst.prefab] and conditions[inst.prefab](inst) and 
            ((inst.connect_ent2hm and not inst.connect_ent2hm.nootherexchange2hm) or inst.connect_ent2hm == nil) then
                inst.sg:GoToState("exchange2hm")
                return
            end
            idle(inst, ...)
        end
    end)
    -- 影怪转换目标和距离
    local exchangetargets = {
        terrorbeak = "crawlinghorror",
        crawlinghorror = "terrorbeak",
        nightmarebeak = "crawlingnightmare",
        crawlingnightmare = "nightmarebeak",
        oceanhorror = "crawlinghorror",
        oceanhorror2hm = "crawlingnightmare"
    }
    local exchangeradius = {terrorbeak = 10, crawlinghorror = -5, nightmarebeak = 5, crawlingnightmare = -5, oceanhorror2hm = -10, oceanhorror = -10}
    -- 影怪转换动画
    AddStategraphState("shadowcreature", State {
        name = "exchange2hm",
        tags = {"busy", "attack", "teleporting"},
        onenter = function(inst, playanim)
            inst.nootherexchange2hm = true
            inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, 0.5, "shadowexchange2hm")
            inst.sg.statemem.max2hm = inst.components.health.maxdamagetakenperhit
            inst.components.health:SetMaxDamageTakenPerHit(50)
            local target = inst.components.combat.target
            if target and inst:IsNear(target, 6) then
                local x, y, z = target.Transform:GetWorldPosition()
                local sx, sy, sz = inst.Transform:GetWorldPosition()
                local radius = -4
                local theta = inst:GetAngleToPoint(Vector3(x, y, z)) * DEGREES
                local offset = Vector3(radius * math.cos(theta), 0, -radius * math.sin(theta))
                sx = sx + offset.x
                sy = sy + offset.y
                sz = sz + offset.z
                inst.Transform:SetPosition(sx, sy, sz)
            end
            SpawnPrefab("shadow_teleport_out2hm").Transform:SetPosition(inst.Transform:GetWorldPosition())
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("taunt", false)
            inst.AnimState:PushAnimation("disappear", false)
        end,
        timeline = {TimeEvent(40 * FRAMES, function(inst) SpawnPrefab("shadow_teleport_out2hm").Transform:SetPosition(inst.Transform:GetWorldPosition()) end)},
        events = {
            EventHandler("animqueueover", function(inst)
                if not inst.components.combat.target then
                    inst.sg:GoToState("idle")
                    return
                end
                local newprefab = inst.exchangeprefab2hm or exchangetargets[inst.prefab] or inst.prefab
                local target = inst.components.combat.target
                local x, y, z = target.Transform:GetWorldPosition()
                local sx, sy, sz = inst.Transform:GetWorldPosition()
                local radius = exchangeradius[newprefab] or 0
                local theta = inst:GetAngleToPoint(Vector3(x, y, z)) * DEGREES
                sx = sx + radius * math.cos(theta)
                sz = sz - radius * math.sin(theta)
                SpawnPrefab("shadow_teleport_in2hm").Transform:SetPosition(sx, sy, sz)
                local shadow = SpawnPrefab(newprefab)
                shadow.canexchange2hm = true
                shadow.exchangetimes2hm = (inst.exchangetimes2hm or 0) + 1
                shadow.exchangeprefab2hm = inst.prefab
                shadow.Transform:SetPosition(sx, sy, sz)
                local size = 1 - (shadow.exchangetimes2hm or 0) * 0.0675
                shadow.AnimState:SetScale(size, size, size)
                shadow.components.combat:SetTarget(target)
                shadow.components.combat.attackrange = shadow.components.combat.attackrange * size * size
                shadow.components.combat.externaldamagemultipliers:SetModifier(shadow, size, "exchange2hm")
                shadow.components.locomotor:SetExternalSpeedMultiplier(shadow, "exchange2hm", size)
                shadow.components.health.maxhealth = shadow.components.health.maxhealth * size
                shadow.components.health:SetVal(inst.components.health:GetPercent() * shadow.components.health.maxhealth or 400)
                shadow.components.health:ForceUpdateHUD(true)
                shadow.sg:GoToState("appear")
                TheWorld:PushEvent("ms_exchangeshadowcreature", {ent = inst, exchangedent = shadow})
                if inst.spawnbyepic2hm then shadow.spawnbyepic2hm = inst.spawnbyepic2hm end
                inst:Remove()
            end)
        },
        onexit = function(inst)
            if inst:IsValid() then
                inst.components.combat.externaldamagetakenmultipliers:RemoveModifier(inst, "shadowexchange2hm")
                inst.components.health:SetMaxDamageTakenPerHit(inst.sg.statemem.max2hm)
            end
        end
    })
end
