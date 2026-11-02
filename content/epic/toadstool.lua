require "behaviours/doaction"
require "brains/toadstoolbrain"
-- 灵感，毒菌蟾蜍种树技能结束时，如果没有仇恨敌人，会持续回血，当有敌人仇恨时会停止回血了，满血时会变回蘑菇树了
if TUNING.easymode2hm then
    TUNING.TOADSTOOL_HEALTH = TUNING.TOADSTOOL_HEALTH / 2
    TUNING.TOADSTOOL_DARK_HEALTH = TUNING.TOADSTOOL_DARK_HEALTH / 2
end
TUNING.TOADSTOOL_AGGRO_DIST = TUNING.TOADSTOOL_AGGRO_DIST * 2
TUNING.TOADSTOOL_DEAGGRO_DIST = TUNING.TOADSTOOL_DEAGGRO_DIST * 2
TUNING.TOADSTOOL_MUSHROOMSPROUT_DURATION = TUNING.TOADSTOOL_MUSHROOMSPROUT_DURATION / 2
TUNING.TOADSTOOL_MUSHROOMSPROUT_TICK = TUNING.TOADSTOOL_MUSHROOMSPROUT_TICK / 2
local lasttoadstool
-- 毒蘑菇落地时直接爆炸一次
local function testdoublebomb(inst)
    if inst.isdouble2hm then return end
    local toadstool = inst.components.entitytracker and inst.components.entitytracker:GetEntity("toadstool")
    if toadstool ~= nil and toadstool:IsValid() and toadstool:HasTag("toadstool") and not toadstool:HasTag("swc2hm") then
        local bomb = SpawnPrefab(inst.prefab)
        bomb.isdouble2hm = true
        bomb.Transform:SetPosition(inst.Transform:GetWorldPosition())
        bomb.components.entitytracker:TrackEntity("toadstool", toadstool)
        if bomb._growtask and bomb._growtask.fn then
            local fn = bomb._growtask.fn
            bomb._growtask:Cancel()
            fn(bomb, 3)
            if bomb._growtask and bomb._growtask.fn and bomb._growtask.fn ~= fn then
                local fn2 = bomb._growtask.fn
                bomb._growtask:Cancel()
                bomb.persists = false
                bomb.AnimState:SetDeltaTimeMultiplier(2)
                local len = bomb.AnimState:GetCurrentAnimationLength()
                bomb._growtask = bomb:DoTaskInTime(GetRandomMinMax(len * .25, len * .5), fn2)
                if (TheWorld.state.isautumn or toadstool.prefab == "toadstool_dark") and toadstool.mushroomsprout_prefab and math.random() < 0.025 then
                    local ent = SpawnPrefab(inst.prefab == "mushroombomb" and "mushroomsprout" or "mushroomsprout_dark")
                    ent.Transform:SetPosition(inst.Transform:GetWorldPosition())
                    ent:PushEvent("linktoadstool", toadstool)
                end
            else
                bomb:Remove()
            end
        else
            bomb:Remove()
        end
    end
end
local function doublebomb(inst)
    if not TheWorld.ismastersim then return end
    inst:DoTaskInTime(0, testdoublebomb)
end
AddPrefabPostInit("mushroombomb", doublebomb)
AddPrefabPostInit("mushroombomb_dark", doublebomb)
-- 毒孢子会爆炸两次
local function doublespore(inst)
    local parent = inst.entity:GetParent()
    if parent ~= nil and lasttoadstool and lasttoadstool:IsValid() and lasttoadstool.components.combat.target == parent then
        local x, y, z = parent.Transform:GetWorldPosition()
        local cloud = SpawnPrefab("sporecloud")
        cloud.Transform:SetPosition(x, 0, z)
        cloud:FadeInImmediately()
    end
end
AddPrefabPostInit("sporebomb", function(inst)
    if not TheWorld.ismastersim then return end
    if lasttoadstool and lasttoadstool:IsValid() then
        local color
        if TheWorld.state.season == "winter" then
            if not inst.components.heater then
                inst:AddComponent("heater")
                inst.components.heater.heat = -20
                inst.components.heater:SetThermics(false, true)
            end
            color = "blue"
        elseif TheWorld.state.season == "summer" then
            if not inst.components.heater then
                inst:AddComponent("heater")
                inst.components.heater.heat = 90
                inst.components.heater:SetThermics(true, false)
            end
            color = "orange"
        elseif TheWorld.state.season == "spring" then
            SpawnPrefab("electricchargedfx"):SetTarget(inst)
            color = "green"
        else
            color = "yellow"
        end
        SetAnimstateColor2hm(inst, color)
    end
    inst:DoTaskInTime(TUNING.TOADSTOOL_SPOREBOMB_TIMER / 3, doublespore)
end)
-- 黑暗毒菌可以弹射毒蘑菇炸弹
local function bouncethrow2hmfn(self, inst)
    local toadstool = inst.components.entitytracker and inst.components.entitytracker:GetEntity("toadstool")
    if inst.components.complexprojectile and toadstool ~= nil and toadstool:IsValid() then
        local newproj = SpawnPrefab("mushroombomb_projectile")
        newproj.components.entitytracker:TrackEntity("toadstool", toadstool)
        newproj.components.complexprojectile:SetHorizontalSpeed(inst.components.complexprojectile.horizontalSpeed)
        return newproj
    end
end
-- 毒雾同时有冰或火属性,且会主动靠近毒毒蟾蜍
local userealspawnpoint
local function onremove(inst) if lasttoadstool == inst then lasttoadstool = nil end end
-- 脱战后立即种树
-- 灵感，毒菌蟾蜍种树技能结束时，如果没有仇恨敌人，会持续回血，当有敌人仇恨时会停止回血了，满血时会变回蘑菇树了
local function onlosttarget(inst)
    if inst.components.health and not inst.components.health:IsDead() and inst.components.timer then
        if inst.components.health:GetPercent() >= 1 then
            inst:PushEvent("flee")
        else
            if inst.components.timer:TimerExists("mushroomsprout_cd") then inst.components.timer:StopTimer("mushroomsprout_cd") end
            if inst.sg and not inst.sg:HasStateTag("busy") then
                inst.sg:GoToState("channel_pre")
            else
                inst.sg.mem.wantstochannel = true
            end
            inst.components.health:StartRegen(TUNING.DAYWALKER_COMBAT_STALKING_HEALTH_REGEN, TUNING.DAYWALKER_COMBAT_HEALTH_REGEN_PERIOD, false)
        end
    end
end
local function onnewcombattarget(inst, data)
    if inst.components.health and not inst.components.health:IsDead() and data and data.oldtarget == nil then inst.components.health:StopRegen() end
end
local function ontimerdone(inst, data)
    if data and data.name == "channeltick" and inst.components.health and not inst.components.health:IsDead() and inst.components.combat and
        (inst.components.combat.target ~= nil or (GetTime() - inst.components.combat.lastwasattackedtime < 3)) and inst.components.timer and
        not inst.components.timer:TimerExists("mushroombomb_cd") and inst.DoMushroomBomb and inst.sg.mem and inst.SoundEmitter then
        inst.SoundEmitter:PlaySound("dontstarve/creatures/together/toad_stool/spore_shoot")
        inst:DoMushroomBomb()
        inst.sg.mem.mushroombomb_chains = (inst.sg.mem.mushroombomb_chains or 0) + 1
        if inst.sg.mem.mushroombomb_chains >= inst.mushroombomb_maxchain then
            inst.sg.mem.mushroombomb_chains = 0
            inst.components.timer:StartTimer("mushroombomb_cd", inst.mushroombomb_cd)
        end
    end
end
local function swp2hmfn(inst)
    lasttoadstool = inst
    inst:ListenForEvent("onremove", onremove)
    if inst.prefab == "toadstool_dark" then
        inst.bouncethrow2hm = 2
        inst.bouncethrow2hmfn = bouncethrow2hmfn
    end
    if inst.components.lootdropper then
        for _, loot in ipairs({
            "red_mushroomhat_blueprint",
            "green_mushroomhat_blueprint",
            "blue_mushroomhat_blueprint",
            "mushroom_light_blueprint",
            "mushroom_light2_blueprint"
        }) do inst.components.lootdropper:AddChanceLoot(loot, 1) end
    end
    if inst.components.knownlocations then
        local GetLocation = inst.components.knownlocations.GetLocation
        inst.components.knownlocations.GetLocation = function(self, name, ...)
            if name == "spawnpoint" and not userealspawnpoint then return inst:GetPosition() end
            return GetLocation(self, name, ...)
        end
    end
    inst:ListenForEvent("losttarget", onlosttarget)
    inst:ListenForEvent("newcombattarget", onnewcombattarget)
    inst:ListenForEvent("timerdone", ontimerdone)
end
local function processtoadstool(inst)
    if not TheWorld.ismastersim then return end
    if TUNING.shadowworld2hm then
        inst.swp2hmfn = swp2hmfn
    else
        swp2hmfn(inst)
    end
end
AddPrefabPostInit("toadstool", processtoadstool)
AddPrefabPostInit("toadstool_dark", processtoadstool)
-- 毒雾带属性
local function sporecloudseasontarget(inst, target, force)
    if not IsEntityDeadOrGhost(target) then
        if inst.season2hm == "winter" then
            if target.components.freezable and not target.components.freezable:IsFrozen() then
                local hasfx
                if target.components.freezable.coldness <= 0 then
                    hasfx = true
                    target.components.freezable:SpawnShatterFX()
                end
                target.components.freezable:AddColdness(0.5)
                if not hasfx and target.components.freezable:IsFrozen() then target.components.freezable:SpawnShatterFX() end
            end
            if target.components.temperature and target.components.temperature.current > 0 then target.components.temperature:DoDelta(-10) end
        elseif inst.season2hm == "summer" then
            if target.components.temperature and target.components.temperature.current < 70 then target.components.temperature:DoDelta(10) end
            if target.components.burnable and not target.components.burnable:IsBurning() then
                if not target.components.burnable:IsSmoldering() then
                    target.components.burnable:StartWildfire()
                else
                    target.components.burnable:Ignite(true, inst)
                end
            end
        elseif inst.season2hm == "spring" then
            if target.components.moisture then target.components.moisture:DoDelta(TUNING.moisturerate2hm and 0.5 or 2) end
            if force and target.components.combat then
                local IsInsulated = target:HasTag("electricdamageimmune") or (target.components.inventory ~= nil and target.components.inventory:IsInsulated())
                if not IsInsulated then SpawnPrefab("electrichitsparks"):AlignToTarget(target, inst, true) end
                target.components.combat:GetAttacked_Internal(inst, TUNING.TOADSTOOL_SPORECLOUD_DAMAGE * (IsInsulated and 1 or
                                                         (TUNING.ELECTRIC_DAMAGE_MULT +
                                                             (target.components.moisture ~= nil and target.components.moisture:GetMoisturePercent() or
                                                                 (target:GetIsWet() and 1 or 0)))), nil, not IsInsulated and "electric" or nil)
            end
        elseif not (target.sg ~= nil and target.sg:HasStateTag("waking")) then
            local mount = target.components.rider ~= nil and target.components.rider:GetMount() or nil
            if mount ~= nil then mount:PushEvent("ridersleep", {sleepiness = 4, sleeptime = 6}) end
            if target.components.grogginess ~= nil then
                if not (target.sg ~= nil and target.sg:HasStateTag("knockout")) then target.components.grogginess:AddGrogginess(1, 6) end
            elseif target.components.sleeper ~= nil then
                if not (target.sg ~= nil and target.sg:HasStateTag("sleeping")) then target.components.sleeper:AddSleepiness(1, 6) end
            end
        end
    end
end
local function onsporecloudhitother(inst, data)
    if lasttoadstool and lasttoadstool:IsValid() and inst:IsNear(lasttoadstool, 40) and data.target and not data.target:HasTag("player") and inst.persists then
        sporecloudseasontarget(inst, data.target)
    end
end
local function checklasttoadstool(inst)
    if lasttoadstool and lasttoadstool:IsValid() and inst.persists then
        local target = lasttoadstool
        if lasttoadstool.components.combat and lasttoadstool.components.combat.target then target = lasttoadstool.components.combat.target end
        local x, y, z = target.Transform:GetWorldPosition()
        local distsq = inst:GetDistanceSqToPoint(x, y, z)
        if distsq < 1600 and distsq > (target == lasttoadstool and 36 or 4) then
            local angle = inst:GetAngleToPoint(x, y, z) * DEGREES
            local _x, _y, _z = inst.Transform:GetWorldPosition()
            inst.Transform:SetPosition(_x + FRAMES * math.cos(angle), _y, _z - FRAMES * math.sin(angle))
        end
        inst.idx2hm = inst.idx2hm + 1
        local idx10 = inst.idx2hm >= (inst.nodark2hm and 10 or 30)
        local isspring = inst.season2hm == "spring"
        if idx10 or isspring then
            if idx10 then
                inst.idx2hm = 0
                if isspring then SpawnPrefab("electricchargedfx"):SetTarget(inst) end
            end
            for _, player in ipairs(AllPlayers) do
                if player and player:IsValid() and player:IsNear(inst, TUNING.TOADSTOOL_SPORECLOUD_RADIUS) then
                    sporecloudseasontarget(inst, player, idx10)
                end
            end
        end
    else
        inst.lasttoadstooltask2hm:Cancel()
        inst.lasttoadstooltask2hm = nil
    end
end
local springauraexcludetags
local function processsporecloud(inst)
    if lasttoadstool and lasttoadstool:IsValid() and inst.persists then
        inst:ListenForEvent("onhitother", onsporecloudhitother)
        inst.season2hm = TheWorld.state.season
        local color
        if inst.season2hm == "winter" then
            if not inst.components.heater then
                inst:AddComponent("heater")
                inst.components.heater.heat = -20
                inst.components.heater:SetThermics(false, true)
            end
            color = "blue"
        elseif inst.season2hm == "summer" then
            if not inst.components.heater then
                inst:AddComponent("heater")
                inst.components.heater.heat = 90
                inst.components.heater:SetThermics(true, false)
            end
            color = "orange"
        elseif inst.season2hm == "spring" then
            inst:AddDebuff("buff_electricattack", "buff_electricattack")
            if inst.components.aura and inst.components.aura.auraexcludetags then
                if not springauraexcludetags then
                    springauraexcludetags = deepcopy(inst.components.aura.auraexcludetags)
                    table.insert(springauraexcludetags, "player")
                end
                inst.components.aura.auraexcludetags = springauraexcludetags
            end
            color = "green"
        else
            color = "yellow"
        end
        SetAnimstateColor2hm(inst, color)
        if inst._overlayfx then for _, fx in ipairs(inst._overlayfx) do if fx and fx:IsValid() then SetAnimstateColor2hm(fx, color) end end end
        if inst._overlaytasks then
            for k, v in pairs(inst._overlaytasks) do
                if v and v.fn then
                    local fn = v.fn
                    v.fn = function(...)
                        fn(...)
                        local fx = inst._overlayfx and inst._overlayfx[#inst._overlayfx]
                        if fx and fx:IsValid() then SetAnimstateColor2hm(fx, color) end
                    end
                end
            end
        end
        inst.nodark2hm = lasttoadstool.prefab == "toadstool"
        if inst.nodark2hm then
            inst.idx2hm = 5
        else
            inst.idx2hm = 15
        end
        inst.lasttoadstooltask2hm = inst:DoPeriodicTask(inst.nodark2hm and 3 * FRAMES or FRAMES, checklasttoadstool)
    end
end
AddPrefabPostInit("sporecloud", function(inst)
    if not TheWorld.ismastersim then return end
    inst:DoTaskInTime(0, processsporecloud)
end)
AddComponentPostInit("fan", function(self)
    local Fan = self.Fan
    self.Fan = function(self, target, ...)
        local result = Fan(self, target, ...)
        if result and target and target:IsValid() then
            local x, y, z = target.Transform:GetWorldPosition()
            local ents = TheSim:FindEntities(x, y, z, self.inst.prefab == "featherfan" and TUNING.FEATHERFAN_RADIUS * 2 or TUNING.FEATHERFAN_RADIUS,
                                             {"sporecloud"})
            for i, v in pairs(ents) do
                if v.prefab == "sporecloud" and v:IsValid() and v.components.timer and v.components.timer:TimerExists("disperse") then
                    v.components.timer:SetTimeLeft("disperse", v.components.timer:GetTimeLeft("disperse") - 60)
                end
            end
        end
        return true
    end
end)
AddStategraphState("SGtoadstool", State {
    name = "burrow2hm",
    tags = {"busy", "nosleep", "nofreeze", "noattack", "temp_invincible", "noelectrocute"},
    onenter = function(inst)
        if inst.components.health and inst.components.health:GetPercent() >= 1 then
            inst.sg:GoToState("burrow")
            return
        end
        inst.components.locomotor:StopMoving()
        inst:ClearBufferedAction()
        inst.AnimState:PlayAnimation("reset")
    end,
    timeline = {
        TimeEvent(11 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/toad_stool/roar") end),
        TimeEvent(19 * FRAMES, function(inst) inst.DynamicShadow:Enable(false) end),
        TimeEvent(20 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/toad_stool/spawn_appear") end),
        TimeEvent(21 * FRAMES, function(inst) ShakeAllCameras(CAMERASHAKE.VERTICAL, 20 * FRAMES, .03, 2, inst, 40) end),
        TimeEvent(40 * FRAMES, function(inst) ShakeAllCameras(CAMERASHAKE.VERTICAL, 30 * FRAMES, .03, .7, inst, 40) end),
        TimeEvent(48 * FRAMES, function(inst)
            userealspawnpoint = true
            local pt = inst.components.knownlocations:GetLocation("spawnpoint")
            userealspawnpoint = nil
            if pt then
                inst.Transform:SetPosition(pt.x, 0, pt.z)
                inst.components.health:DoDelta(inst.components.health.maxhealth * 0.01, nil, nil, true)
                inst.sg:GoToState("surface")
            else
                inst:OnEscaped()
            end
        end)
    },
    events = {
        EventHandler("animover", function(inst)
            if inst.AnimState:AnimDone() then
                userealspawnpoint = true
                local pt = inst.components.knownlocations:GetLocation("spawnpoint")
                userealspawnpoint = nil
                if pt then
                    inst.Transform:SetPosition(pt.x, 0, pt.z)
                    inst.components.health:DoDelta(inst.components.health.maxhealth * 0.1, nil, nil, true)
                    inst.sg:GoToState("surface")
                else
                    inst:OnEscaped()
                end
            end
        end)
    },
    onexit = function(inst) inst.DynamicShadow:Enable(true) end
})
AddStategraphActionHandler("SGtoadstool", ActionHandler(ACTIONS.ACTION2HM, "burrow2hm"))
-- 蟾蜍远离巢穴就直接遁地回去但不消失;现在只脱离加载消失了
-- 灵感，毒菌蟾蜍种树技能结束时，如果没有仇恨敌人，会持续回血，当有敌人仇恨时会停止回血了，满血时会变回蘑菇树了
local function GoHomeAction(inst)
    if inst.sg:HasStateTag("busy") or inst:HasTag("swc2hm") then return end
    userealspawnpoint = true
    local pt = inst.components.knownlocations:GetLocation("spawnpoint")
    userealspawnpoint = nil
    if pt and inst:GetDistanceSqToPoint(pt:Get()) >= 625 then return BufferedAction(inst, nil, ACTIONS.ACTION2HM) end
end
AddBrainPostInit("toadstoolbrain", function(self)
    if self.bt.root.children then
        if self.bt.root.children[4] and self.bt.root.children[4].name == "Parallel" then table.remove(self.bt.root.children, 4) end
        table.insert(self.bt.root.children, 1, DoAction(self.inst, function() return GoHomeAction(self.inst) end))
    end
end)
-- 毒菌蟾蜍转换阵地
local _spawners
local function exchangetoadstoolcap(inst)
    if #_spawners <= 0 then return end
    local length = #_spawners
    for i = 1, length, 1 do
        local spawner = _spawners[math.random(length)]
        if spawner ~= nil and spawner ~= inst and spawner:IsValid() then
            local x, y, z = inst.Transform:GetWorldPosition()
            inst.Transform:SetPosition(spawner.Transform:GetWorldPosition())
            spawner.Transform:SetPosition(x, y, z)
        end
    end
end
local function capontimerdone(inst, data) if data.name == "respawn" or data.name == "respawndark" then inst:DoTaskInTime(0, exchangetoadstoolcap) end end
AddPrefabPostInit("toadstool_cap", function(inst)
    if not TheWorld.ismastersim then return end
    if _spawners == nil and TheWorld.components.toadstoolspawner ~= nil then
        local GetSpawnedToadstool = getupvalue2hm(TheWorld.components.toadstoolspawner.OnPostInit, "GetSpawnedToadstool")
        if GetSpawnedToadstool ~= nil then _spawners = getupvalue2hm(GetSpawnedToadstool, "_spawners") end
    end
    if _spawners ~= nil then inst:ListenForEvent("timerdone", capontimerdone) end
end)
-- -- 毒军蟾蜍阵地时生成地震,算了，因为玩家必带瓜皮头
-- local function SpawnSinkhole(pt)
--     local sinkhole = SpawnPrefab("antlion_sinkhole")
--     sinkhole.Transform:SetPosition(pt.x, 0, pt.z)
--     sinkhole:PushEvent("startcollapse")
--     sinkhole.remainingrepairs = 1
-- end

-- require("stategraphs/commonstates")
-- 技能一,毒雾孢子弥漫 
-- 技能二,炸弹孢子弹射
-- 技能三,转移阵地
-- -- 钻出地面
-- local surfacestate = State {
--     name = "surface2hm",
--     tags = {"busy", "nosleep", "nofreeze", "noattack"},
--     onenter = function(inst)
--         inst.components.locomotor:StopMoving()
--         inst.components.health:SetInvincible(true)
--         inst.AnimState:PlayAnimation("spawn_appear_toad")
--         inst.AnimState:SetLightOverride(0)
--         inst.DynamicShadow:Enable(false)
--         inst.Light:Enable(false)
--         inst.sg.mem.wantstoroar = true
--     end,
--     timeline = {
--         TimeEvent(0 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/toad_stool/spawn_appear_pre") end),
--         TimeEvent(10 * FRAMES, function(inst) ShakeAllCameras(CAMERASHAKE.VERTICAL, 40 * FRAMES, .03, 2, inst, 40) end),
--         TimeEvent(12 * FRAMES, function(inst)
--             inst.SoundEmitter:PlaySound("dontstarve/creatures/together/toad_stool/spawn_appear")
--             inst.AnimState:SetLightOverride(.3)
--             inst.DynamicShadow:Enable(true)
--             inst.Light:Enable(true)
--         end),
--         TimeEvent(31 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/bearger/groundpound") end),
--         TimeEvent(32 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/bearger/dustpoof") end)
--     },
--     events = {CommonHandlers.OnNoSleepAnimOver("roar")},
--     onexit = function(inst)
--         inst.components.health:SetInvincible(false)
--         inst.AnimState:SetLightOverride(.3)
--         inst.DynamicShadow:Enable(true)
--         inst.Light:Enable(true)
--     end
-- }
-- -- 逃走
-- local burrowstate = State {
--     name = "burrow2hm",
--     tags = {"busy", "nosleep", "nofreeze", "noattack"},
--     onenter = function(inst)
--         inst.components.locomotor:StopMoving()
--         inst.components.health:SetInvincible(true)
--         inst.AnimState:PlayAnimation("reset")
--     end,
--     timeline = {
--         TimeEvent(11 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/toad_stool/roar") end),
--         TimeEvent(19 * FRAMES, function(inst) inst.DynamicShadow:Enable(false) end),
--         TimeEvent(20 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve/creatures/together/toad_stool/spawn_appear") end),
--         TimeEvent(21 * FRAMES, function(inst) ShakeAllCameras(CAMERASHAKE.VERTICAL, 20 * FRAMES, .03, 2, inst, 40) end),
--         TimeEvent(40 * FRAMES, function(inst) ShakeAllCameras(CAMERASHAKE.VERTICAL, 30 * FRAMES, .03, .7, inst, 40) end),
--         TimeEvent(48 * FRAMES, function(inst) inst:FadeOut() end)
--     },
--     events = {
--         EventHandler("animover", function(inst)
--             if inst.AnimState:AnimDone() then
--                 local remove = inst.Remove
--                 inst.Remove = nilfn
--                 inst:OnEscaped()
--                 inst.Remove = remove
--                 -- TODO,转移阵地,并留下足迹
--                 inst.sg:GoToState("surface2hm")
--             end
--         end)
--     },
--     onexit = function(inst)
--         inst.components.health:SetInvincible(false)
--         inst.DynamicShadow:Enable(true)
--         inst:CancelFade()
--     end
-- }
