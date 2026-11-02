TUNING.enableoceanhorror2hm = true
-- 加攻速移速
local speedup = GetModConfigData("extra_change") and GetModConfigData("notboss_speed") or 1
local attackspeedup = GetModConfigData("extra_change") and GetModConfigData("notboss_attackspeed") or 1
if speedup < 1.75 then TUNING.OCEANHORROR.SPEED = TUNING.OCEANHORROR.SPEED * 1.75 / speedup end
if attackspeedup < 1.33 then TUNING.OCEANHORROR.ATTACK_PERIOD = TUNING.OCEANHORROR.ATTACK_PERIOD * 3 / 4 * attackspeedup end

local brain = require("brains/shadowcreaturebrain")
AddPrefabPostInit("oceanhorror", function(inst)
    if not TheWorld.ismastersim then return end
    if not inst.components.timer then inst:AddComponent("timer") end
    if inst._update_task then inst._update_task:Cancel() end
    inst:SetBrain(brain)
    inst:SetStateGraph("SGshadowcreature")
    inst.cantaunt2hm = true
end)

-- 持续6秒,持续制造荡漾波纹,击飞玩家同时推远玩家的船只;受到攻击会被打断施法
local function stoptaunttask(inst, nearplayer)
    inst.taunttask2hm:Cancel()
    inst.taunttask2hm = nil
    inst.components.timer:StartTimer("tauntcd2hm", 6) -- 2025.7.25 melon:12秒削弱到6秒
    if inst._ripples ~= nil and inst._ripples:IsValid() then inst._ripples.AnimState:SetScale(1, 1) end
end
local function checknearplayer(inst)
    local player = FindClosestPlayerToInst(inst, 1, true)
    if player and player:IsValid() and not (player.sg and player.sg:HasStateTag("knockout")) then
        local knocker = inst.src2hm and inst.src2hm:IsValid() and inst.src2hm or inst
        local _strengthmult = 3
        if player:HasTag("wereplayer") then _strengthmult = 7 end
        player:PushEvent("knockback", {
            knocker = knocker,
            radius = _strengthmult,
            strengthmult = (player.components.inventory ~= nil and player.components.inventory:ArmorHasTag("heavyarmor") or player:HasTag("heavybody")) and 0.7 or
                1,
            forcelanded = true
        })
        if TheWorld.has_ocean then
            inst.targets2hm = inst.targets2hm or {}
            local boat = player:GetCurrentPlatform()
            if boat and boat:IsValid() and boat:HasTag("boat") and boat.components.boatphysics and not inst.targets2hm[boat] then
                inst.targets2hm[boat] = true
                local _x, _y, _z = knocker.Transform:GetWorldPosition()
                local x, y, z = boat.Transform:GetWorldPosition()
                local nx, nz = VecUtil_Normalize(_x - x, _z - z)
                boat.components.boatphysics:ApplyRowForce(_x - x, _z - z, 1, 6)
            end
        end
    end
end
local function cantaunt(inst) return inst.components.health:GetPercent() < (1 - 0.25 / (1 - (inst.exchangetimes2hm or 0) * 0.0675)) end
local WAKEANIMS = {"idle_loop_1", "idle_loop_2", "idle_loop_3"}
local function dotaunttask(inst)
    inst.taunttask2hmindex = inst.taunttask2hmindex + 1
    if inst.taunttask2hmindex > 48 or inst.components.health:IsDead() or not cantaunt(inst) then
        stoptaunttask(inst)
        return
    end
    local player = FindClosestPlayerToInst(inst, 100, true)
    if player and player:IsValid() then
        local _x, _y, _z = inst.Transform:GetWorldPosition()
        local x, y, z = player.Transform:GetWorldPosition()
        local rotation = inst:GetAngleToPoint(x, y, z)
        local wake = SpawnPrefab("boatwaterfx2hm")
        wake.src2hm = inst
        local theta = rotation * DEGREES
        wake.Transform:SetPosition(_x + 2 * math.cos(theta), 0, _z - math.sin(theta))
        wake.Transform:SetRotation(rotation)
        wake.AnimState:SetMultColour(0, 0, 0, 0.5)
        inst.wakeanimidx2hm = (inst.wakeanimidx2hm + (math.random() > 0.5 and 1 or -1)) % #WAKEANIMS
        wake.AnimState:PlayAnimation(WAKEANIMS[inst.wakeanimidx2hm + 1])
        if wake.components.boattrailmover then
            local nx, nz = VecUtil_Normalize(_x - x, _z - z)
            wake.components.boattrailmover:Setup(nx, nz, 4, 0)
        end
        wake:DoPeriodicTask(FRAMES, checknearplayer)
    else
        stoptaunttask(inst)
    end
end

AddStategraphPostInit("shadowcreature", function(sg)
    local idle = sg.states.idle.onenter
    sg.states.idle.onenter = function(inst, ...)
        -- 击飞技能发动条件,损失100血量之后才能使用,普通恐怖利爪释放此技能会无法行动一直咆哮
        if not inst.wortox_minion and (inst.cantaunt2hm and (inst.taunttask2hm and inst.prefab == "oceanhorror" or
            (not inst.locktarget2hm and not inst.taunttask2hm and inst.components.timer and not inst.components.timer:TimerExists("tauntcd2hm") and
                cantaunt(inst)))) then
            inst.sg:GoToState("taunt")
            return
            -- 恐怖利爪转换状态作战,从而达到100血量以上时能远程攻击敌人且持续锁敌
        elseif inst.cantaunt2hm and not inst.taunttask2hm and not inst.wantstodespawn and inst.components.combat.target and
            inst.components.combat.target:HasTag("player") then
            if inst.prefab == "oceanhorror" and not inst.disableexchange2hm and inst.components.health:GetPercent() >
                (0.25 / (1 - (inst.exchangetimes2hm or 0) * 0.0675)) then
                local timeleft = inst.components.timer and inst.components.timer:GetTimeLeft("tauntcd2hm")
                local replace = SpawnPrefab("oceanhorror2hm")
                replace.simple2hm = true
                replace.Transform:SetPosition(inst.Transform:GetWorldPosition())
                replace.Transform:SetRotation(inst.Transform:GetRotation())
                replace.canexchange2hm = inst.canexchange2hm
                replace.exchangetimes2hm = inst.exchangetimes2hm
                replace.exchangeprefab2hm = "crawlinghorror"
                replace.components.health:SetPercent(inst.components.health:GetPercent())
                replace.components.combat:SetTarget(inst.components.combat.target)
                if replace.components.timer and timeleft then replace.components.timer:StartTimer("tauntcd2hm", timeleft) end
                replace.sg:GoToState("idle")
                TheWorld:PushEvent("ms_exchangeshadowcreature", {ent = inst, exchangedent = replace})
                inst:DoTaskInTime(0, inst.Remove)
            elseif TheWorld.has_ocean and not TheWorld:HasTag("cave") and inst.prefab == "oceanhorror2hm" and inst.simple2hm and
                (not inst.components.combat.target or inst.components.health:GetPercent() <= (0.25 / (1 - (inst.exchangetimes2hm or 0) * 0.0675))) and
                inst:IsOnOcean() then
                local timeleft = inst.components.timer and inst.components.timer:GetTimeLeft("tauntcd2hm")
                local replace = SpawnPrefab("oceanhorror")
                replace.Transform:SetPosition(inst.Transform:GetWorldPosition())
                replace.Transform:SetRotation(inst.Transform:GetRotation())
                replace.canexchange2hm = inst.canexchange2hm
                replace.exchangetimes2hm = inst.exchangetimes2hm
                replace.exchangeprefab2hm = "crawlinghorror"
                replace.components.health:SetPercent(inst.components.health:GetPercent())
                replace.components.combat:SetTarget(inst.components.combat.target)
                if replace.components.timer and timeleft then replace.components.timer:StartTimer("tauntcd2hm", timeleft) end
                replace.sg:GoToState("idle")
                TheWorld:PushEvent("ms_exchangeshadowcreature", {ent = inst, exchangedent = replace})
                inst:DoTaskInTime(0, inst.Remove)
            end
        end
        idle(inst, ...)
    end
    local attack = sg.states.attack.onenter
    sg.states.attack.onenter = function(inst, ...)
        if not inst.wortox_minion and inst.cantaunt2hm and not inst.locktarget2hm and not inst.taunttask2hm and inst.components.timer and
            not inst.components.timer:TimerExists("tauntcd2hm") and cantaunt(inst) then
            inst.sg:GoToState("taunt")
            return
        end
        attack(inst, ...)
    end
    local taunt = sg.states.taunt.onenter
    sg.states.taunt.onenter = function(inst, ...)
        if inst.cantaunt2hm and not inst.locktarget2hm and not inst.taunttask2hm and inst.components.timer and
            not inst.components.timer:TimerExists("tauntcd2hm") and cantaunt(inst) then
            inst.taunttask2hmindex = 0
            inst.wakeanimidx2hm = 0
            inst.taunttask2hm = inst:DoPeriodicTask(8 * FRAMES, dotaunttask, 0.25)
            if inst._ripples ~= nil and inst._ripples:IsValid() then inst._ripples.AnimState:SetScale(2, 2) end
        end
        taunt(inst, ...)
    end
    local hit = sg.states.hit.onenter
    sg.states.hit.onenter = function(inst, ...)
        if inst.taunttask2hm then stoptaunttask(inst) end
        hit(inst, ...)
    end
end)
