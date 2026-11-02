local speedup = GetModConfigData("extra_change") and GetModConfigData("boss_speed") or 1

-- 浣猫优化
if TUNING.DSTU and TUNING.DSTU.MONSTER_CATCOON_HEALTH_CHANGE then AddPrefabPostInit("catcoon", function(inst) inst.Transform:SetScale(1.3, 1.3, 1.3) end) end

TUNING.PIG_HEALTH = TUNING.PIG_HEALTH * 2
TUNING.BUNNYMAN_HEALTH = TUNING.BUNNYMAN_HEALTH * 2

-- 兔人增强
AddPrefabPostInit("bunnyman", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.trader then
        inst.components.trader.acceptnontradable = true
        local test = inst.components.trader.test
        inst.components.trader:SetAcceptTest(function(inst, item, giver, ...)
            if not inst.rangeweapondata2hm and item.components.equippable ~= nil and item.components.equippable.equipslot == EQUIPSLOTS.HANDS and
                not inst.components.combat:TargetIs(giver) then return true end
            return test and test(inst, item, giver, ...)
        end)
        local onaccept = inst.components.trader.onaccept
        inst.components.trader.onaccept = function(inst, giver, item, ...)
            if item.components.equippable ~= nil and item.components.equippable.equipslot == EQUIPSLOTS.HANDS then
                local current = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                if current ~= nil then inst.components.inventory:DropItem(current, true) end
                inst.components.inventory:Equip(item)
                return
            end
            if onaccept then onaccept(inst, giver, item, ...) end
        end
    end
end)
AddStategraphPostInit("bunnyman", function(sg)
    local oldOnEnterattack = sg.states.attack.onenter
    sg.states.attack.onenter = function(inst, ...)
        oldOnEnterattack(inst, ...)
        if inst.prefab == "bunnyman" then
            local current = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if current ~= nil then
                inst.AnimState:PlayAnimation("idle_loop_overhead")
                inst.AnimState:PushAnimation("atk_object", false)
                inst.sg.statemem.weapon2hm = current
            end
        end
    end
    local oldfn = sg.states.attack.events.animover.fn
    sg.states.attack.events.animover.fn = function(inst, ...) if not inst.sg.statemem.weapon2hm then oldfn(inst, ...) end end
    if not sg.states.attack.events.animqueueover then
        sg.states.attack.events.animqueueover = EventHandler("animqueueover", function(inst) inst.sg:GoToState("idle") end)
    end
end)

-- 猪人增强
AddPrefabPostInit("pigman", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.trader then
        inst.components.trader.acceptnontradable = true
        local test = inst.components.trader.test
        inst.components.trader:SetAcceptTest(function(inst, item, giver, ...)
            if not inst.rangeweapondata2hm and item.components.equippable ~= nil and item.components.equippable.equipslot == EQUIPSLOTS.HANDS and
                not inst.components.combat:TargetIs(giver) then return true end
            return test and test(inst, item, giver, ...)
        end)
        local onaccept = inst.components.trader.onaccept
        inst.components.trader.onaccept = function(inst, giver, item, ...)
            if item.components.equippable ~= nil and item.components.equippable.equipslot == EQUIPSLOTS.HANDS then
                local current = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                if current ~= nil then inst.components.inventory:DropItem(current, true) end
                inst.components.inventory:Equip(item)
                return
            end
            if onaccept then onaccept(inst, giver, item, ...) end
            if item and item:IsValid() and (inst.goldtradecycle2hm or -1) < TheWorld.state.cycles and item.components.tradable and
                item.components.tradable.goldvalue > 0 then
                inst.goldtradecycle2hm = TheWorld.state.cycles
                for k = 1, item.components.tradable.goldvalue do
                    giver.components.inventory:GiveItem(SpawnPrefab("goldnugget"), nil, inst:GetPosition())
                end
            end
        end
    end
end)
AddStategraphPostInit("pig", function(sg)
    local oldOnEnterattack = sg.states.attack.onenter
    sg.states.attack.onenter = function(inst, ...)
        oldOnEnterattack(inst, ...)
        if inst.prefab == "pigman" then
            local current = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if current ~= nil then inst.AnimState:PlayAnimation("atk_object") end
        end
    end
end)
local pigs = {"pigman", "pigguard", "moonpig"}
local function IsNonWerePig(dude) return dude:HasTag("pig") and not dude:HasTag("werepig") end
local function OnAttacked(inst, data)
    local attacker = data.attacker
    if attacker ~= nil then
        if attacker.prefab ~= "deciduous_root" and not attacker:HasTag("pigelite") then
            if inst:HasTag("werepig") then
                inst.components.combat:ShareTarget(attacker, 30, IsNonWerePig, 10)
            elseif not inst:HasTag("werepig") and attacker:HasTag("werepig") and inst.components.werebeast then
                inst.components.werebeast:SetWere(120)
            end
        end
    end
end
local function OnTrade(inst, data)
    local item = data.item
    if item and data.giver and item.components.edible ~= nil and
        (item.components.edible.secondaryfoodtype == FOODTYPE.MONSTER or item.components.edible.healthvalue < 0) then
        inst.components.combat:SetTarget(data.giver)
    end
end
for index, pig in ipairs(pigs) do
    AddPrefabPostInit(pig, function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("attacked", OnAttacked)
        inst:ListenForEvent("trade", OnTrade)
        if inst.components.lootdropper then inst.components.lootdropper:AddChanceLoot("batnose", 0.1) end
    end)
end

-- 猪王无条件小游戏
if TUNING.DSTU then
    local function AbleToAcceptTest(inst, item, giver)
        if item.prefab == "pig_token" then return true end
        return true
    end
    AddPrefabPostInit("pigking", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.trader then inst.components.trader:SetAbleToAcceptTest(AbleToAcceptTest) end
    end)
end

TUNING.DAYWALKER2_DEAGGRO_DIST_FROM_JUNK = TUNING.DAYWALKER2_DEAGGRO_DIST_FROM_JUNK * 2
-- 噩梦猪人柱子限制
AddPrefabPostInit("daywalker_pillar", function(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("worked", function() CreateMiasma2hm(inst, true) end)
end)
-- 噩梦猪人,更快脱离疲惫
local function delayrecover(inst)
    if inst.hostile and inst.components.combat and inst.components.combat.target then
        inst.delayrecovertask2hm = inst:DoTaskInTime(240, delayrecover)
        return
    end
    inst.delayrecovertask2hm = nil
    inst.components.locomotor.walkspeed = TUNING.DAYWALKER_WALKSPEED
    inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "speedup2hm")
    if speedup > 1 then inst.components.locomotor:SetExternalSpeedMultiplier(inst, "HappyPatchExtra", speedup) end
end
-- 升级移速
local function updatespeed(inst, speed)
    inst.upatklevel2hm = math.clamp((inst.upatklevel2hm or 0) + (speed or 1), 1, 6)
    if speedup > 1 then inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "HappyPatchExtra") end
    local runup = math.max((1 + inst.upatklevel2hm * 0.15), speedup)
    local walkup = math.max((1 + inst.upatklevel2hm * 0.75), speedup)
    inst.components.locomotor.walkspeed = TUNING.DAYWALKER_WALKSPEED * walkup / runup
    inst.components.locomotor:SetExternalSpeedMultiplier(inst, "speedup2hm", runup)
    if inst.delayrecovertask2hm then inst.delayrecovertask2hm:Cancel() end
    inst.delayrecovertask2hm = inst:DoTaskInTime(240, delayrecover)
end
local function onsave(inst, data) data.upatklevel2hm = inst.upatklevel2hm end
local function onload(inst, data) if data and data.upatklevel2hm then updatespeed(inst, data.upatklevel2hm) end end
AddPrefabPostInit("daywalker", function(inst)
    if not TheWorld.ismastersim then return end
    inst:DoTaskInTime(0, function() if inst.chained then CreateMiasma2hm(inst, true) end end)
    SetOnSave2hm(inst, onsave)
    SetOnLoad2hm(inst, onload)
end)
AddPrefabPostInit("daywalker2", function(inst)
    if not TheWorld.ismastersim then return end
    SetOnSave2hm(inst, onsave)
    SetOnLoad2hm(inst, onload)
end)
-- 攻击动画也会加速
local function updateattackspeed(sg)
    for _, state in pairs(sg.states) do
        if state and state.tags and (state.tags.attack or state.tags.tired or state.tags.rummaging) and not state.tags.hit and not state.upanim2hm then
            state.upanim2hm = true
            local onenter = state.onenter
            state.onenter = function(inst, ...)
                onenter(inst, ...)
                if inst.sg.currentstate == state then
                    if not inst.defeated and inst.hostile then
                        SpeedUpState2hm(inst, state, math.max(1 + (inst.upatklevel2hm or 0) * 0.15, TUNING.epicupatkanim2hm or 1, TUNING.upatkanim2hm or 1))
                    else
                        SpeedUpState2hm(inst, state, 1)
                    end
                end
            end
            local onexit = state.onexit
            state.onexit = function(inst, ...)
                if onexit then onexit(inst, ...) end
                RemoveSpeedUpState2hm(inst, state, true)
            end
        end
    end
end
AddStategraphPostInit("daywalker", function(sg)
    local tired_stand = sg.states.tired_stand.onenter
    sg.states.tired_stand.onenter = function(inst, ...)
        if not inst.defeated and inst.hostile and inst.components.locomotor then
            CreateMiasma2hm(inst, true)
            updatespeed(inst)
        end
        tired_stand(inst, ...)
    end
    local tired = sg.states.tired.onenter
    sg.states.tired.onenter = function(inst, loops, ...)
        if not inst.defeated and inst.hostile then CreateMiasma2hm(inst, true) end
        local percent = inst.components.health and inst.components.health:GetPercent()
        if inst.hostile and percent then loops = (loops or 0) + math.floor((1 - percent) / 0.25) end
        tired(inst, loops, ...)
    end
    updateattackspeed(sg)
end)
--AddStategraphPostInit("daywalker2", function(sg)
--    local rummage_pst = sg.states.rummage_pst.onenter
--    sg.states.rummage_pst.onenter = function(inst, ...)
--        if not inst.defeated and inst.hostile and inst.components.locomotor then updatespeed(inst, 0.75) end
--        rummage_pst(inst, ...)
--    end
--    updateattackspeed(sg)
--end)
-- 垃圾堆
local randomactions = {ACTIONS.CHOP, ACTIONS.DIG, ACTIONS.MINE, ACTIONS.HAMMER}
local function newjunkonwork(inst, worker, ...)
    if worker and worker:HasTag("player") then
        inst.components.pickable.canbepicked = true
        inst.components.pickable:Pick(worker)
        inst.components.pickable.canbepicked = false
    end
    inst.OnWork2hm(inst, worker, ...)
end
local function resetworkaction(inst)
    inst.resetworkactiontask2hm = nil
    if inst.components.workable and inst.components.workable.workleft > 0 and inst.components.pickable then
        local chance = math.random(7)
        if inst.OnWork2hm then
            inst.components.workable.onwork = inst.OnWork2hm
            inst.OnWork2hm = nil
        end
        local action = chance < 5 and randomactions[chance]
        if action ~= nil and table.contains(randomactions, action) then
            inst.components.workable:SetWorkAction(action)
            inst.components.pickable.canbepicked = false
            if inst:HasTag("junk_pile_big") then
                inst.OnWork2hm = inst.components.workable.onwork
                inst.components.workable.onwork = newjunkonwork
            end
        else
            inst.components.pickable.canbepicked = true
            inst.components.workable:SetWorkAction(nil)
        end
    end
end
local function delayresetworkaction(inst)
    if inst.resetworkactiontask2hm then return end
    inst.resetworkactiontask2hm = inst:DoTaskInTime(0, resetworkaction)
end
local function setjunkworkaction(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.workable and inst.components.pickable then
        inst:ListenForEvent("worked", delayresetworkaction)
        delayresetworkaction(inst)
    end
end
AddPrefabPostInit("junk_pile", setjunkworkaction)
AddPrefabPostInit("junk_pile_big", setjunkworkaction)

-- 不主动仇恨拥有猪人祝福buff的目标
local function setbufftarget(inst)
    if inst.components.combat then
        local oldtargetfn = inst.components.combat.targetfn
        inst.components.combat.targetfn = function(inst)
            local target = oldtargetfn(inst)
            if target and target:HasDebuff("gulumi_bless2hm") then
                return nil
            else
                return target
            end
        end
    end
end
AddPrefabPostInit("pigman", function(inst)
    if not TheWorld.ismastersim then return end
    setbufftarget(inst)
    if inst.components.werebeast then
        local oldnormalfn = inst.components.werebeast.onsetnormalfn 
        inst.components.werebeast.onsetnormalfn = function(inst)
            oldnormalfn(inst)
            setbufftarget(inst)
        end
    end
end)

AddPrefabPostInit("pigguard", function(inst)
    if not TheWorld.ismastersim then return end
    setbufftarget(inst)
    if inst.components.werebeast then
        local oldnormalfn = inst.components.werebeast.onsetnormalfn 
        inst.components.werebeast.onsetnormalfn = function(inst)
            oldnormalfn(inst)
            setbufftarget(inst)
        end
    end
end)

-- 猪王可无条件与拥有buff的玩家交易
AddPrefabPostInit("pigking", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.trader then
        local oldtest = inst.components.trader.test
        inst.components.trader.test = function(inst, item, giver, ...)
            if giver and giver:HasDebuff("gulumi_bless2hm") then
                return item.components.tradable and (item.components.tradable.goldvalue > 0 or item.components.tradable.halloweencandyvalue) or item.prefab == "pig_token"
            else
                return oldtest(inst, item, giver, ...)
            end
        end
    end
end)

if ModManager:GetMod("workshop-2039181790") then
    AddPrefabPostInit("pigking_pigguard", function(inst)
        if not TheWorld.ismastersim then return end
        setbufftarget(inst)
        if inst.components.werebeast then
            local oldnormalfn = inst.components.werebeast.onsetnormalfn 
            inst.components.werebeast.onsetnormalfn = function(inst)
                oldnormalfn(inst)
                setbufftarget(inst)
            end
        end
    end)
end