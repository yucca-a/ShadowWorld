local speedup = GetModConfigData("extra_change") and GetModConfigData("notboss_speed") or 1
local attackspeedup = GetModConfigData("extra_change") and GetModConfigData("notboss_attackspeed") or 1
if speedup < 1.45 then TUNING.TERRORBEAK_SPEED = TUNING.TERRORBEAK_SPEED * 1.45 / speedup end
if attackspeedup < 1.33 then TUNING.TERRORBEAK_ATTACK_PERIOD = TUNING.TERRORBEAK_ATTACK_PERIOD * 3 / 4 * attackspeedup end

-- 掉落武器
local hardmode = GetModConfigData("shadowbeak") ~= -1

-- 陷阱
local function TrapSpellFn(inst)
    if inst.disabledeath2hm or inst.wortox_minion then return end
    local x, y, z = inst.Transform:GetWorldPosition()
    local trap = SpawnPrefab("mod_hardmode_shadow_trap")
    trap.Transform:SetPosition(x, y, z)
    if TheWorld.Map:GetPlatformAtPoint(x, z) ~= nil then trap:RemoveTag("ignorewalkableplatforms") end
end

-- 伪装形态,伪装化形成休憩影怪靠近附近的玩家,直到具备仇恨且从化形状态退出时出现袭击,支持强制伪装
local maxrangesq = TUNING.SHADOWCREATURE_TARGET_DIST * TUNING.SHADOWCREATURE_TARGET_DIST * 4
local function findnearplayer(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local rangesq = maxrangesq
    local closestPlayer
    for i, player in ipairs(AllPlayers) do
        if player and player:IsValid() and not IsEntityDeadOrGhost(player) and player.entity:IsVisible() and
            (player.components.sanity and player.components.sanity:IsInsanityMode() and player.components.sanity:GetPercent() < 0.8 or
                inst:HasTag("nightmarecreature")) then
            local distsq = player:GetDistanceSqToPoint(x, y, z)
            if distsq < rangesq then
                rangesq = distsq
                closestPlayer = player
            end
        end
    end
    return closestPlayer, closestPlayer ~= nil and rangesq or nil
end
-- 停止伪装技能
local function trystophidetask(inst)
    if inst.components.timer then
        local cd = inst.components.combat.target and (10 + (inst.hidetask2hmidx or 0) * 5) or 10
        if not inst.components.timer:TimerExists("hidecd2hm") then
            inst.components.timer:StartTimer("hidecd2hm", cd)
        elseif inst.components.timer:GetTimeLeft("hidecd2hm") < cd then
            inst.components.timer:SetTimeLeft("hidecd2hm", cd)
        end
    end
    if inst.hidetask2hm then
        if inst.hidetask2hm ~= true then inst.hidetask2hm:Cancel() end
        inst.hidetask2hm = nil
        inst:ReturnToScene()
        inst.hidetask2hmidx = nil
        if inst.components.health:IsDead() then
            inst.sg:GoToState("death")
        else
            inst.sg:GoToState(inst.wantstodespawn and "disappear" or "appear")
        end
    end
end
-- 随机位移一段距离,也可能是在目标附近随机位移，也可能是优先位移到该目标的面朝方向
local function randommoveinst(inst, moverange, shadowskittish, proxy, tryattack)
    local x, y, z = (proxy or inst).Transform:GetWorldPosition()
    local theta
    if tryattack and proxy then
        theta = proxy.Transform:GetRotation() * DEGREES + (math.random() * 0.5 - 0.25) * PI
    else
        theta = math.random() * 2 * PI
    end
    local range = proxy and moverange or math.random() * moverange
    x = x + range * math.cos(theta)
    z = z - range * math.sin(theta)
    inst.Transform:SetPosition(x, 0, z)
    if shadowskittish then shadowskittish.Transform:SetPosition(x, 0, z) end
end
-- 有仇恨目标,与其缩短或远离一定距离
local function goneartarget(inst, target, rangesq, shortrange, shadowskittish)
    local faraway = inst.components.health:GetPercent() < (1 - 0.25 / (1 - (inst.exchangetimes2hm or 0) * 0.0675))
    if faraway and (inst.hidetask2hmidx or 0) == 5 then
        if shadowskittish then shadowskittish.Transform:SetPosition(inst.Transform:GetWorldPosition()) end
        inst:DoTaskInTime(0, inst.Remove)
        return
    end
    local x, y, z = inst.Transform:GetWorldPosition()
    local theta = inst:GetAngleToPoint(target.Transform:GetWorldPosition()) * DEGREES
    if faraway then
        shortrange = -shortrange
    else
        local range = math.sqrt(rangesq)
        local leftrange = range - shortrange
        -- 如果缩短距离后在敌人身后,那么
        if leftrange < 0 then
            leftrange = math.clamp(leftrange, -TUNING.SHADOWCREATURE_TARGET_DIST / 2, -TUNING.SHADOWCREATURE_TARGET_DIST / 4)
            shortrange = range - leftrange
        elseif leftrange < TUNING.SHADOWCREATURE_TARGET_DIST / 2 then
            -- 如果缩短距离后和敌人挨着,那么
            leftrange = math.clamp(leftrange, TUNING.SHADOWCREATURE_TARGET_DIST / 4, TUNING.SHADOWCREATURE_TARGET_DIST / 2)
            shortrange = range - leftrange
        elseif leftrange > TUNING.SHADOWCREATURE_TARGET_DIST then
            -- 如果缩短距离后还是和敌人太远,那么
            leftrange = TUNING.SHADOWCREATURE_TARGET_DIST
            shortrange = range - leftrange
        end
    end
    x = x + shortrange * math.cos(theta)
    z = z - shortrange * math.sin(theta)
    inst.Transform:SetPosition(x, 0, z)
    inst:ForceFacePoint(target.Transform:GetWorldPosition())
    if shadowskittish then
        shadowskittish.Transform:SetPosition(x, 0, z)
        shadowskittish:ForceFacePoint(target.Transform:GetWorldPosition())
    end
end
-- 开始伪装技能, 周期隐藏和周期化形轮番释放
local function trystarthidetask(inst, switchskittish, switchhide)
    -- 要消失或被骨头头盔驱使或死亡时,不再进入周期隐藏或周期化形,且一段时间内无法再次进入
    if inst.wantstodespawn or inst.locktarget2hm or inst.components.health:IsDead() then
        trystophidetask(inst)
        return
    end
    -- 正在进入周期隐藏时,若之前有玩家靠近过,或此时仇恨的非玩家在攻击范围内,则不再进入周期隐藏,且一段时间内无法再次进入
    if inst:IsValid() and inst.components.combat.target and inst.components.combat.target:IsValid() and inst.hidetask2hm and switchhide and (inst.skittishnear2hm or (inst.components.combat.target and not inst.components.combat.target:HasTag("player") and
        inst.components.combat.target:IsNear(inst, TUNING.SHADOWCREATURE_TARGET_DIST))) then
        inst.skittishnear2hm = nil
        trystophidetask(inst)
        return
    end
    if not inst.hidetask2hm then
        if inst.components.combat.target or not (TheWorld:HasTag("cave") or TheWorld.state.isnight or inst:HasTag("nightmarecreature")) or
            (inst.components.timer and inst.components.timer:TimerExists("hidecd2hm")) then
            if switchskittish then inst.sg:GoToState("appear") end
            return
        end
        -- 首先进入周期隐藏,必定随机位移一段距离
        inst:RemoveFromScene()
        if inst.Physics then inst.Physics:SetActive(true) end
        -- local time = 0.25 + math.random() * 0.5
        inst.hidetask2hm = inst:DoTaskInTime(0.25, trystarthidetask, true)
        -- if not inst.spawnedforplayer then randommoveinst(inst, TUNING.TERRORBEAK_SPEED * time / 2) end
        if not inst.onskittish2hmremovefn then
            inst.onskittish2hmremovefn = function() if inst:IsValid() then inst:DoTaskInTime(0, trystarthidetask, nil, true) end end
        end
    elseif switchskittish or switchhide then
        local player
        local rangesq
        if inst.components.combat.target then
            player = inst.components.combat.target
            rangesq = inst:GetDistanceSqToInst(player)
        elseif inst.spawnedforplayer and inst.spawnedforplayer:IsValid() then
            player = inst.spawnedforplayer
            rangesq = inst:GetDistanceSqToInst(player)
        else
            player, rangesq = findnearplayer(inst)
        end
        if switchskittish then
            -- 正在进入周期化形,周期化形5次后不再进入周期化形
            if inst.hidetask2hm ~= true then inst.hidetask2hm:Cancel() end
            if inst.hidetask2hmidx == nil or (inst.hidetask2hmidx < 5 and player and player:IsValid() and rangesq) then
                inst.hidetask2hmidx = (inst.hidetask2hmidx or 0) + 1
                inst.hidetask2hm = true
                local shadowskittish = SpawnPrefab("shadowskittish2hm") -- 化形出幻象
                shadowskittish.master2hm = inst
                inst:ListenForEvent("onremove", inst.onskittish2hmremovefn, shadowskittish)
                if inst:HasTag("nightmarecreature") then shadowskittish:AddTag("nightmarecreaturefx2hm") end
                if not inst.components.combat.target then
                    if inst.spawnedforplayer and inst.spawnedforplayer:IsValid() then
                        -- 没有仇恨目标，但有追踪玩家或本次伪装期间尚未化形过,则进入周期化形且在追踪玩家周围闪烁
                        randommoveinst(inst, 15 - inst.hidetask2hmidx * 1.5, shadowskittish, inst.spawnedforplayer, math.random() < 0.5)
                    else
                        if shadowskittish.deathtask and shadowskittish.deathtask.fn then
                            local fn = shadowskittish.deathtask.fn
                            shadowskittish.deathtask:Cancel()
                            shadowskittish.deathtask = inst:DoTaskInTime(5 + 10 * math.random(), fn)
                        end
                        -- 没有仇恨目标,但附加有玩家或本次伪装期间尚未化形过,则进入周期化形且随机位移一段距离
                        randommoveinst(inst, TUNING.SHADOWCREATURE_TARGET_DIST / 4, shadowskittish)
                    end
                else
                    -- 有仇恨目标,则进入周期化形且与其缩短或远离一定距离
                    goneartarget(inst, inst.components.combat.target, rangesq, TUNING.SHADOWCREATURE_TARGET_DIST / 3, shadowskittish)
                end
                local fx = SpawnPrefab("shadow_teleport_in2hm")
                fx.Transform:SetPosition(shadowskittish.Transform:GetWorldPosition())
                fx.Transform:SetScale(0.5, 0.5, 0.5)
            else
                -- 没有仇恨且附近没有玩家,且本次伪装期间已经化形过,则不再进入周期化形
                trystophidetask(inst)
            end
        elseif switchhide then
            -- 正在进入周期隐藏
            if inst.hidetask2hm ~= true then inst.hidetask2hm:Cancel() end
            if player and player:IsValid() and rangesq then
                -- local time = 0.25 + math.random() * 0.5
                inst.hidetask2hm = inst:DoTaskInTime(0.25, trystarthidetask, true)
                -- if not inst.components.combat.target then
                --     if inst.spawnedforplayer and inst.spawnedforplayer:IsValid() then
                --         -- 没有仇恨目标，但有追踪玩家,则进入周期隐藏且在追踪玩家周围闪烁
                --         randommoveinst(inst, 15, nil, inst.spawnedforplayer)
                --     else
                --         -- 没有仇恨目标,但附加有玩家,则进入周期隐藏且随机位移一段距离
                --         randommoveinst(inst, TUNING.TERRORBEAK_SPEED * time / 2)
                --     end
                -- else
                --     -- 有仇恨目标,则进入周期隐藏且与其缩短或远离一定距离
                --     goneartarget(inst, inst.components.combat.target, rangesq, TUNING.SHADOWCREATURE_TARGET_DIST / 4)
                -- end
            else
                -- 没有仇恨且附近没有玩家,则不再进入周期隐藏
                trystophidetask(inst)
            end
        end
    elseif inst.components.health:GetPercent() < (1 - 0.25 / (1 - (inst.exchangetimes2hm or 0) * 0.0675)) then
        -- 丢失敌人仇恨,此时尝试消失
        inst:DoTaskInTime(0, inst.Remove)
    end
end

local function waketrystarthidetask(inst) if GetTime() - inst.spawntime > 1 then trystarthidetask(inst) end end

-- 尖嘴移速攻速更快且死亡时生成陷阱,海上不会转换了
local beaks = {"terrorbeak", "nightmarebeak"}
for _, beak in ipairs(beaks) do
    AddPrefabPostInit(beak, function(inst)
        if not TheWorld.ismastersim then return end
        inst.canlunge2hm = true
        if not inst.components.timer then inst:AddComponent("timer") end
        inst:ListenForEvent("death", TrapSpellFn)
        inst.followtosea = nil
        -- inst:DoTaskInTime(0, trystarthidetask)
        inst:ListenForEvent("entitywake", waketrystarthidetask)
        inst:ListenForEvent("droppedtarget", trystarthidetask)
    end)
end

-- 播放音乐
local function FinishExtendedSound(inst, soundid)
    inst.SoundEmitter:KillSound("sound_" .. tostring(soundid))
    inst.sg.mem.soundcache[soundid] = nil
    if inst.sg.statemem.readytoremove and next(inst.sg.mem.soundcache) == nil then inst:Remove() end
end
local function PlayExtendedSound(inst, soundname)
    if inst.sg.mem.soundcache == nil then
        inst.sg.mem.soundcache = {}
        inst.sg.mem.soundid = 0
    else
        inst.sg.mem.soundid = inst.sg.mem.soundid + 1
    end
    inst.sg.mem.soundcache[inst.sg.mem.soundid] = true
    inst.SoundEmitter:PlaySound(inst.sounds[soundname], "sound_" .. tostring(inst.sg.mem.soundid))
    inst:DoTaskInTime(5, FinishExtendedSound, inst.sg.mem.soundid)
end
-- 冲刺前置动作
AddStategraphState("shadowcreature", State {
    name = "lunge_pre2hm",
    tags = {"attack", "busy"},
    onenter = function(inst, target)
        inst.components.locomotor:Stop()
        if target == nil then target = inst.components.combat.target end
        if target ~= nil and target:IsValid() then
            inst.sg.statemem.target = target
            inst.sg.statemem.targetpos = target:GetPosition()
            inst:ForceFacePoint(inst.sg.statemem.targetpos:Get())
        else
            target = nil
            if inst.components.timer and not inst.components.timer:TimerExists("shadowstrikecd2hm") then
                inst.components.timer:StartTimer("shadowstrikecd2hm", 1.5)
            end
            inst.sg.statemem.lunge = true
            inst.sg.mem.dosecondlunge2hm = nil
            inst.sg:GoToState("idle")
            return
        end
        local fx = SpawnPrefab(math.random() < .5 and "shadowstrike_slash_fx" or "shadowstrike_slash2_fx")
        local x, y, z = inst.Transform:GetWorldPosition()
        fx.Transform:SetPosition(x, y + 1.5, z)
        inst:StopBrain()
        inst.AnimState:PlayAnimation("disappear")
        PlayExtendedSound(inst, "taunt")
        if inst.sg.mem.dolonglunge2hm then
            inst.sg.mem.dosecondlunge2hm = true
            inst.components.combat:StartAttack()
        elseif not inst.sg.mem.dosecondlunge2hm and math.random() < (0.25 + (inst.exchangetimes2hm or 0) * 0.125) then
            inst.sg.mem.longlungepre2hm = true
        else
            inst.sg.mem.longlungepre2hm = nil
            inst.components.combat:StartAttack()
        end
    end,
    onupdate = function(inst)
        if inst.sg.statemem.target ~= nil then
            if inst.sg.statemem.target:IsValid() then
                inst.sg.statemem.targetpos = inst.sg.statemem.target:GetPosition()
            else
                inst.sg.statemem.target = nil
            end
        end
    end,
    events = {
        EventHandler("animover", function(inst)
            if inst.AnimState:AnimDone() then
                inst.sg.statemem.lunge = true
                if inst.sg.mem.longlungepre2hm then
                    inst.sg.mem.dolonglunge2hm = true
                    inst.sg.mem.longlungepre2hm = nil
                    inst.sg:GoToState("lunge_pre2hm", inst.sg.statemem.target)
                else
                    inst.sg:GoToState("lunge_loop2hm", {target = inst.sg.statemem.target, targetpos = inst.sg.statemem.targetpos})
                end
            end
        end)
    },
    onexit = function(inst)
        if not inst.sg.statemem.lunge then
            inst.sg.mem.longlungepre2hm = nil
            inst.sg.mem.dosecondlunge2hm = nil
            inst.components.combat:CancelAttack()
            if inst.components.timer and not inst.components.timer:TimerExists("shadowstrikecd2hm") then
                inst.components.timer:StartTimer("shadowstrikecd2hm", 1)
            end
            inst:RestartBrain()
        end
    end
})
-- -- 冲刺特效
-- local function showmovelinefx(inst)
--     local rot = inst.Transform:GetRotation()
--     local iscave = TheWorld:HasTag("cave")
--     local startpos = inst.sg.statemem.startpos
--     local animtime = inst.AnimState:GetCurrentAnimationLength()
--     local lungetime = animtime - (iscave and 0 or 4) * FRAMES
--     local lungedist = (inst.sg.mem.dolonglunge2hm and 70 or 35) * lungetime
--     local width = iscave and 2 or 1
--     local fx = SpawnPrefab("reticulelineshadow2hm")
--     local theta = rot * DEGREES
--     fx.Transform:SetPosition(startpos.x - lungedist * math.cos(theta), 0, startpos.z + lungedist * math.sin(theta))
--     fx.Transform:SetRotation(rot)
--     fx.AnimState:SetScale(lungedist / 2, iscave and 2 or 1)
--     fx:DoTaskInTime(animtime + 1, fx.KillFX or fx.Remove)
-- end
-- local function showmovefx(inst)
--     if not TheWorld:HasTag("cave") then return end
--     inst.Physics:Stop()
--     local fxprefab = "cane_ancient_fx"
--     local fxspacing = 1.5
--     local p1 = {x = inst.sg.statemem.startpos.x, y = inst.sg.statemem.startpos.z}
--     local targetpos = inst:GetPosition()
--     local p2 = {x = targetpos.x, y = targetpos.z}
--     local dx, dy = p2.x - p1.x, p2.y - p1.y
--     local dist = dx * dx + dy * dy
--     if dist <= 0 then
--         local fx = SpawnPrefab(fxprefab)
--         fx.Transform:SetPosition(p2.x, 0, p2.y)
--     else
--         dist = math.sqrt(dist)
--         dx, dy = dx / dist, dy / dist
--         dist = math.floor(dist / fxspacing)
--         dx = dx * fxspacing
--         dy = dy * fxspacing
--         local flip = math.random() < 0.5
--         for i = 0, dist do
--             if i == 0 then
--                 p2.x = p2.x - dx * 0.25
--                 p2.y = p2.y - dy * 0.25
--             elseif i == 1 then
--                 p2.x = p2.x - dx * 0.75
--                 p2.y = p2.y - dy * 0.75
--             else
--                 p2.x = p2.x - dx
--                 p2.y = p2.y - dy
--             end
--             local fx = SpawnPrefab(fxprefab)
--             fx.Transform:SetPosition(p2.x, 0, p2.y)
--             local k = (dist > 0 and math.max(0, 1 - i / dist)) or 0
--             k = 1 - k * k
--             if fx.FastForward then fx:FastForward(0.4 * k) end
--             if fx.SetMotion then
--                 k = 1 + k * 2
--                 fx:SetMotion(k * dx, 0, k * dy)
--             end
--             if flip and fx.AnimState then fx.AnimState:SetScale(-1, 1) end
--             flip = not flip
--         end
--     end
-- end
-- 实际冲刺动作
AddStategraphState("shadowcreature", State {
    name = "lunge_loop2hm",
    tags = {"attack", "busy", "noattack", "temp_invincible"},
    onenter = function(inst, data)
        inst.AnimState:PlayAnimation("disappear") -- NOTE: this anim NOT a loop yo
        inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_nightsword")
        inst.SoundEmitter:PlaySound("dontstarve/impacts/impact_shadow_med_sharp")
        PlayExtendedSound(inst, "attack_grunt")
        if inst.components.timer ~= nil then
            inst.components.timer:StopTimer("shadowstrikecd2hm")
            inst.components.timer:StartTimer("shadowstrikecd2hm", 12.5 + math.random() * 5)
        end
        inst.sg.mem.dosecondlunge2hm = not inst.sg.mem.dosecondlunge2hm
        if data ~= nil then
            if data.target ~= nil and data.target:IsValid() then
                inst.sg.statemem.target = data.target
                inst:ForceFacePoint(data.target.Transform:GetWorldPosition())
            elseif data.targetpos ~= nil then
                inst:ForceFacePoint(data.targetpos)
            end
        end
        inst.sg.statemem.startpos = inst:GetPosition()
        -- showmovelinefx(inst)
        inst.sg:SetTimeout(4 * FRAMES)
    end,
    ontimeout = function(inst)
        inst.Physics:SetMotorVelOverride(inst.sg.mem.dolonglunge2hm and 70 or 35, 0, 0)
        inst.sg.mem.dolonglunge2hm = nil
    end,
    onupdate = function(inst)
        if inst.sg.statemem.attackdone or not inst.sg.statemem.target then return end
        local target = inst.sg.statemem.target
        if not target:IsValid() then
            inst.sg.statemem.target = nil
        elseif inst:IsNear(target, TheWorld:HasTag("cave") and 2 or 1) then
            local fx = SpawnPrefab(math.random() < .5 and "shadowstrike_slash_fx" or "shadowstrike_slash2_fx")
            local x, y, z = target.Transform:GetWorldPosition()
            fx.Transform:SetPosition(x, y + 1.5, z)
            fx.Transform:SetRotation(inst.Transform:GetRotation())
            if hardmode then
                DropPlayerWeapon2hm(inst, target)
                inst.components.combat.externaldamagemultipliers:SetModifier(inst, TheWorld:HasTag("cave") and 0.5 or 0.25, "shadowstrike")
            end
            inst.components.combat:DoAttack(target)
            inst.sg.statemem.attackdone = true
        end
    end,
    events = {
        EventHandler("animover", function(inst)
            if inst.AnimState:AnimDone() then
                -- if TheWorld:HasTag("cave") then showmovefx(inst) end
                inst.sg:GoToState("appear")
            end
        end)
    },
    onexit = function(inst)
        inst.components.combat.externaldamagemultipliers:RemoveModifier(inst, "shadowstrike")
        if not inst.sg.mem.dosecondlunge2hm then inst.components.combat:SetRange(3) end
        inst:RestartBrain()
    end
})

-- 触发冲刺和伪装
AddStategraphPostInit("shadowcreature", function(sg)
    local doattack = sg.events.doattack.fn
    sg.events.doattack.fn = function(inst, data, ...)
        if inst.canlunge2hm and ((inst.components.timer ~= nil and not inst.components.timer:TimerExists("shadowstrikecd2hm")) or inst.sg.mem.dosecondlunge2hm) then
            inst.sg:GoToState("lunge_pre2hm", data.target)
            return
        end
        return doattack(inst, data, ...)
    end
    sg.states.hit.tags.noattack = true
    local idle = sg.states.idle.onenter
    sg.states.idle.onenter = function(inst, ...)
        idle(inst, ...)
        if inst.canlunge2hm and inst.components.timer and not inst.components.timer:TimerExists("shadowstrikecd2hm") then
            inst.components.combat:SetRange(TheWorld:HasTag("cave") and 10 or 5)
        end
        if not inst.wortox_minion and (inst.canlunge2hm and not inst.components.combat.target and not inst.helptask2hm and not inst.locktarget2hm and not inst.wantstodespawn and
            not (inst.components.timer and inst.components.timer:TimerExists("hidecd2hm")) and
            (TheWorld:HasTag("cave") or TheWorld.state.isnight or inst:HasTag("nightmarecreature")) and GetTime() - inst.spawntime > 1) then
            inst.sg:GoToState("taunt")
            inst.sg:AddStateTag("attack")
            inst.AnimState:PlayAnimation("disappear")
            inst:DoTaskInTime(inst.AnimState:GetCurrentAnimationLength(), trystarthidetask, true)
        end
    end
    local appear = sg.states.appear.onenter
    sg.states.appear.onenter = function(inst, ...)
        appear(inst, ...)
        if inst.canlunge2hm and not inst.components.combat.target and not inst.helptask2hm and not inst.locktarget2hm and not inst.wantstodespawn and
            not (inst.components.timer and inst.components.timer:TimerExists("hidecd2hm")) and
            (TheWorld:HasTag("cave") or TheWorld.state.isnight or inst:HasTag("nightmarecreature")) and GetTime() - inst.spawntime > 1 then
            inst:DoTaskInTime(0, trystarthidetask, true)
        end
    end
end)

-- 清除00坐标影怪
local shadowmonster_todetect = {"crawlinghorror", "terrorbeak", "oceanhorror", "crawlingnightmare", "nightmarebeak"}
local function removemonster00(inst)
    local ix, iy, iz = inst.Transform:GetWorldPosition()
    if ix == 0 and iz == 0 then inst.wantstodespawn = true end
end
for _, monster in ipairs(shadowmonster_todetect) do
    AddPrefabPostInit(monster, function(inst)
        if not TheWorld.ismastersim then return end
        inst:DoTaskInTime(7, removemonster00)
    end)
end
