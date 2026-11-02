local easing = require("easing")
-- 为爽装甲熊灌改动
-- 装甲熊灌掉血800后且敌人在侧后方则屁股蹲攻击(首次疲惫后还会主动冲刺屁股蹲攻击),主动暴露破绽,屁股蹲期间月亮武器连续攻击进入疲惫;疲惫结束后重置计算
-- local function checkmutatedbeargerbuttstate(inst)
--     if inst.sg and inst.sg.currentstate and inst.sg.currentstate.name ~= "butt_pre" then recovermutated(inst) end
-- end
-- local attackstates = {"attack_combo1", "attack_combo2", "attack_combo1a"}
AddPrefabPostInit("mutatedbearger", function(inst)
    if not TheWorld.ismastersim then return end
    if not inst.components.timer then inst:AddComponent("timer") end
    inst.components.timer:StartTimer("sleepcloud2hm", 30 + math.random(15))
    inst.components.timer:StartTimer("sporecloud2hm", 45 + math.random(30))
    inst.components.timer:StartTimer("runningbutt2hm", 45 + math.random(30))
    -- if not inst.StartMutation then inst.StartMutation = StartMutation_mutated end
    -- local IsButtRecovering = inst.IsButtRecovering
    -- inst.IsButtRecovering = function(inst, ...)
    --     local result = IsButtRecovering(inst, ...)
    --     if not result and inst:HasTag("lunar_aligned") and inst.canbutt and inst.sg and inst.sg.currentstate and
    --         table.contains(attackstates, inst.sg.currentstate.name) then inst:DoTaskInTime(0, checkmutatedbeargerbuttstate) end
    --     return result
    -- end
end)
local function generatesleepcloud(inst)
    if inst.components.timer and not inst.components.timer:TimerExists("sleepcloud2hm") and inst.sg and inst.sg.currentstate and inst.sg.currentstate.name ==
        "pound" and inst.components.combat and inst.components.combat.target and inst.components.combat.target:IsValid() then
        inst.components.timer:StartTimer("sleepcloud2hm", 50 + math.random(10))
        local x, y, z = inst.Transform:GetWorldPosition()
        local rot = inst.Transform:GetRotation() * DEGREES
        for dist = 6, 18, 6 do
            local cloud = SpawnPrefab("sleepcloud_lunar")
            if cloud then
                if inst:HasTag("swc2hm") and cloud.AnimState then cloud.AnimState:SetMultColour(0, 0, 0, 0.5) end
                cloud.Transform:SetPosition(x + dist * math.cos(rot), 0, z - dist * math.sin(rot))
                cloud:SetOwner(inst)
                if cloud._drowsytask and cloud._drowsytask.fn then
                    local fn = cloud._drowsytask.fn
                    cloud._drowsytask.fn = function(...)
                        local oldGetPVPEnabled = getmetatable(TheNet).__index["GetPVPEnabled"]
                        getmetatable(TheNet).__index["GetPVPEnabled"] = truefn
                        fn(...)
                        getmetatable(TheNet).__index["GetPVPEnabled"] = oldGetPVPEnabled
                    end
                end
            end
        end
    end
end
local function generatesporecloud(inst)
    if inst.components.timer and not inst.components.timer:TimerExists("sporecloud2hm") and inst.sg and inst.sg.currentstate and inst.sg.currentstate.name ==
        "butt" and inst.components.combat and inst.components.combat.target and inst.components.combat.target:IsValid() then
        inst.components.timer:StartTimer("sporecloud2hm", 75 + math.random(15))
        local x, y, z = inst.Transform:GetWorldPosition()
        local rot = inst.Transform:GetRotation() * DEGREES
        for dist = -7, -13, -6 do
            local cloud = SpawnPrefab("sporecloud")
            if inst:HasTag("swc2hm") and cloud.AnimState then cloud.AnimState:SetMultColour(0, 0, 0, 0.5) end
            cloud.Transform:SetPosition(x + dist * math.cos(rot), 0, z - dist * math.sin(rot))
        end
        for i = 1, 2 do
            local theta = rot + PI / 2 * i - PI * 3 / 4
            local radius = -6
            local offset = Vector3(radius * math.cos(theta), 0, -radius * math.sin(theta))
            local newpos = Vector3(inst.Transform:GetWorldPosition()) + offset
            local cloud = SpawnPrefab("sporecloud")
            if inst:HasTag("swc2hm") and cloud.AnimState then cloud.AnimState:SetMultColour(0, 0, 0, 0.5) end
            cloud.Transform:SetPosition(newpos.x, newpos.y, newpos.z)
            -- local miasma = SpawnPrefab("miasma_cloud")
            -- miasma:ListenForEvent("onremove", function() miasma:Remove() end, cloud)
            -- miasma.Transform:SetPosition(cloud.Transform:GetWorldPosition())
        end
        if inst.sg.laststate and inst.sg.laststate.name == "running_butt_pre" then
            inst.components.timer:StopTimer("sleepcloud2hm")
            generatesleepcloud(inst)
        end
    end
end
AddStategraphPostInit("bearger", function(sg)
    -- local idle = sg.states.idle.onenter
    -- sg.states.idle.onenter = function(inst, ...)
    --     idle(inst, ...)
    --     if inst:HasTag("lunar_aligned") and inst.sg.laststate and (inst.sg.laststate.name == "butt_pst" or inst.sg.laststate.name == "butt_face_hit") then
    --         recovermutated(inst)
    --     end
    -- end
    -- 冲刺时主动屁股蹲
    local pound = sg.states.pound.onenter
    sg.states.pound.onenter = function(inst, ...)
        if inst:HasTag("lunar_aligned") and -- (inst.components.childspawner2hm and inst.components.childspawner2hm.numchildrenoutside > 0 or inst:HasTag("swc2hm")) and 
        not inst.canrunningbutt and inst.sg.laststate and inst.sg.laststate.name == "run" and inst.components.combat and inst.components.combat.target and
            inst.components.combat.target:IsValid() and inst.components.timer and not inst.components.timer:TimerExists("runningbutt2hm") then
            inst.components.timer:StartTimer("runningbutt2hm", 90 + math.random(45))
            inst.Transform:SetRotation(inst.Transform:GetRotation() + 180)
            inst.sg:GoToState("running_butt_pre", inst.components.combat.target)
            return
        end
        pound(inst, ...)
        -- if inst:HasTag("lunar_aligned") -- and (inst.components.childspawner2hm and inst.components.childspawner2hm.numchildrenoutside > 0 or inst:HasTag("swc2hm")) 
        -- then inst:DoTaskInTime(21 * FRAMES, generatesleepcloud) end
    end
    AddStateTimeEvent2hm(sg.states.pound, 21 * FRAMES, function(inst) if inst:HasTag("lunar_aligned") then generatesleepcloud(inst) end end)
    -- local butt = sg.states.butt.onenter
    -- sg.states.butt.onenter = function(inst, ...)
    --     butt(inst, ...)
    --     if inst:HasTag("lunar_aligned") -- and  (inst.components.childspawner2hm and inst.components.childspawner2hm.numchildrenoutside > 0 or inst:HasTag("swc2hm")) 
    --     then inst:DoTaskInTime(8 * FRAMES, generatesporecloud) end
    -- end
    AddStateTimeEvent2hm(sg.states.butt, 8 * FRAMES, function(inst) if inst:HasTag("lunar_aligned") then generatesporecloud(inst) end end)
    local run = sg.states.run.onenter
    sg.states.run.onenter = function(inst, ...)
        run(inst, ...)
        if inst:HasTag("lunar_aligned") and -- (inst.components.childspawner2hm and inst.components.childspawner2hm.numchildrenoutside > 0 or inst:HasTag("swc2hm")) and
        inst.canrunningbutt and not inst.runningbuttspeed2hm and inst.components.locomotor then
            inst.runningbuttspeed2hm = true
            inst.components.locomotor:SetExternalSpeedMultiplier(inst, "canrunningbutt2hm", 2)
        end
    end
    local onexit = sg.states.run.onexit
    sg.states.run.onexit = function(inst, ...)
        if onexit then onexit(inst, ...) end
        if inst:HasTag("lunar_aligned") and inst.runningbuttspeed2hm and inst.components.locomotor then
            inst.runningbuttspeed2hm = nil
            inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "canrunningbutt2hm")
        end
    end
    local attack = sg.states.attack.onenter
    sg.states.attack.onenter = function(inst, ...)
        if inst.components.combat and inst.components.combat.laststartattacktime and GetTime() - inst.components.combat.laststartattacktime < 8 then
            inst.canrangeattack2hm = true
        elseif inst.canrangeattack2hm then
            inst.canrangeattack2hm = nil
        end
        attack(inst, ...)
    end
end)
-- 熊熊远程攻击,需要8秒内已进行过一次攻击
local function delayprocessattackfx(inst)
    local parent = inst.entity:GetParent()
    if parent and parent:IsValid() and parent:HasTag("bearger") and parent.canrangeattack2hm and parent.components.health and parent.components.combat  and parent.sg and parent.sg.statemem and parent.sg.statemem.fx ==
        inst and parent.components.timer and not parent.components.timer:TimerExists("rangeattack2hm") then
        parent.canrangeattack2hm = nil
        local target = parent.sg.statemem.target or (parent.components.combat and parent.components.combat.target)
        if target then
            parent.components.timer:StartTimer("rangeattack2hm", 12 + parent.components.health:GetPercent() * 12)
            local reverse = inst.AnimState:IsCurrentAnimation("atk2")
            local rot = parent.Transform:GetRotation()
            parent.sg.statemem.fx = nil
            local proj = ReplacePrefab(inst, inst.prefab == "bearger_swipe_fx" and "beargerswipefx2hm" or "mutatedbeargerswipefx2hm")
            if proj then
                proj.Transform:SetRotation(rot)
                if reverse then proj:Reverse() end
                proj.components.projectile:Throw(parent, target, parent)
            end
        end
    end
end
local function processattackfx(inst)
    if not TheWorld.ismastersim then return end
    inst:DoTaskInTime(0, delayprocessattackfx)
end
AddPrefabPostInit("bearger_swipe_fx", processattackfx)
AddPrefabPostInit("mutatedbearger_swipe_fx", processattackfx)

-- 妥协模组存在时为爽改动装甲熊灌同样具有妥协普通熊灌的机制
if not ModManager:GetMod("workshop-2039181790") then return end
local function LaunchProjectile(inst, target)
    local x, y, z = inst.Transform:GetWorldPosition()
    for i = 1, 5 do
        if target ~= nil then
            inst.rockthrow2hm = false
            local a, b, c = target.Transform:GetWorldPosition()
            local targetpos = target:GetPosition()
            local theta = (inst:GetAngleToPoint(a, 0, c) + (-30 + ((i - 1) * 15))) * DEGREES

            local variableanglex = (i - 1) * 7.5
            local variableanglez = (5 - i) * 7.5

            targetpos.x = targetpos.x + 15 * math.cos(theta)
            targetpos.z = targetpos.z - 15 * math.sin(theta)

            local rangesq = ((a - x) ^ 2) + ((c - z) ^ 2)
            local maxrange = 15
            local bigNum = 10
            local speed = easing.linear(rangesq, bigNum, 3, maxrange * maxrange)

            local projectile = SpawnPrefab("bearger_boulder")
            if projectile then
                projectile.Transform:SetPosition(x, y, z)
                projectile.components.complexprojectile:SetHorizontalSpeed(speed + math.random(4, 6))
                projectile.components.complexprojectile:Launch(targetpos, inst, inst)
                projectile.Transform:SetScale(0.9 + math.random(0, 0.2), 0.9 + math.random(0, 0.2), 0.9 + math.random(0, 0.2))
            else
                inst.disablerockthrow = true
                break
            end
        end
    end
end
local function Sinkholes(inst)
    local target = inst.components.combat.target ~= nil and inst.components.combat.target or nil
    if target ~= nil and inst.sg and inst.sg.currentstate and inst.sg.currentstate.name == "pound" then
        local target_index = {}
        local found_targets = {}
        local ix, iy, iz = inst.Transform:GetWorldPosition()
        local targetfocus = target
        for i = 1, 6 do
            local delay = i / 10
            local px, py, pz = targetfocus.Transform:GetWorldPosition()
            inst:DoTaskInTime(FRAMES * i * 1.5 + delay, function()
                if targetfocus ~= nil then
                    -- local px, py, pz = targetfocus.Transform:GetWorldPosition()
                    local rad = math.rad(inst:GetAngleToPoint(px, py, pz))
                    local velx = math.cos(rad) * 4.5
                    local velz = -math.sin(rad) * 4.5

                    local dx, dy, dz = ix + (i * velx), 0, iz + (i * velz)

                    local ground = TheWorld.Map:IsPassableAtPoint(dx, dy, dz)
                    local boat = TheWorld.Map:GetPlatformAtPoint(dx, dz)
                    local pt = dx, 0, dz

                    if boat then
                        local fx1 = SpawnPrefab("antlion_sinkhole_boat")
						fx1.Transform:SetPosition(dx, dy, dz)
                    elseif ground and not boat then
                        local fx1 = SpawnPrefab("um_bearger_sinkhole")
						fx1.Transform:SetPosition(dx, dy, dz)
						fx1:PushEvent("startcollapse")
						fx1.bearger = inst
                    else
                        local fx1 = SpawnPrefab("splash_green")
                        fx1.Transform:SetPosition(dx, dy, dz)
                    end
                end
            end)
        end
    end
end
local function RockThrowTimer(inst, data) if data.name == "RockThrow" and not inst.disablerockthrow then inst.rockthrow2hm = true end end
AddPrefabPostInit("mutatedbearger", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.LaunchProjectile then return end
    inst.canrockthrow2hm = true
    inst.rockthrow2hm = true
    inst.LaunchProjectile = LaunchProjectile
    if inst.components.groundpounder then
        -- local groundpoundFn = inst.components.groundpounder.groundpoundFn
        inst.components.groundpounder.groundpoundFn = Sinkholes
    end
    inst:ListenForEvent("timerdone", RockThrowTimer)
    if TUNING.shadowworld2hm and EnableExchangeWitheSwc2hm then EnableExchangeWitheSwc2hm(inst, {0.65031, 0.30031}) end
end)
local attackactions = {"attack", "attack_combo1", "attack_combo2", "attack_combo1a"}
AddStategraphPostInit("bearger", function(sg)
    local idle = sg.states.idle.onenter
    sg.states.idle.onenter = function(inst, ...)
        if inst.canrockthrow2hm and inst.rockthrow2hm and inst:HasTag("lunar_aligned") and inst.sg.laststate and
            table.contains(attackactions, inst.sg.laststate.name) and inst.components.combat.target and inst.components.combat.target:IsValid() and
            inst:IsNear(inst.components.combat.target, 20) then
            inst.sg:GoToState("pre_shoot", inst.components.combat.target)
            return
        end
        idle(inst, ...)
    end
    if not sg.states.shoot then return end
    local shoot = sg.states.shoot.onenter
    sg.states.shoot.onenter = function(inst, ...)
        shoot(inst, ...)
        if inst:HasTag("lunar_aligned") and inst.canrockthrow2hm then
            inst.AnimState:SetBuild("bearger_mutated")
            inst.AnimState:PlayAnimation("ground_pound")
        end
    end
    local onexit = sg.states.shoot.onexit
    sg.states.shoot.onexit = function(inst, ...)
        if onexit then onexit(inst, ...) end
        if inst:HasTag("lunar_aligned") and inst.canrockthrow2hm then inst.AnimState:SetBuild("bearger_mutated") end
    end
end)
