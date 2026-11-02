-- 新三王改动
local shadownumber = TUNING.shadowworld2hm
local hardgestalt = GetModConfigData("gestalt")
TUNING.MUTATED_DEERCLOPS_STAGGER_TIME = TUNING.MUTATED_DEERCLOPS_STAGGER_TIME / 2
TUNING.MUTATED_BEARGER_STAGGER_TIME = TUNING.MUTATED_BEARGER_STAGGER_TIME / 2
TUNING.MUTATED_WARG_STAGGER_TIME = TUNING.MUTATED_WARG_STAGGER_TIME / 2
-- 增加一个分身或回满血量
local function consumereadychildren2hm(inst)
    if not inst.components.childspawner2hm then return end
    inst.readychildren2hm = math.max((inst.readychildren2hm or 0) - 1, 0)
    local num = inst.components.childspawner2hm.maxchildren
    if num < 6 then
        inst.components.childspawner2hm:SetMaxChildren(math.min(num + 1, 6))
    elseif not inst.components.health:IsDead() then
        local percent = inst.components.health:GetPercent()
        inst.components.health:SetPercent(1)
        for k, child in pairs(inst.components.childspawner2hm.childrenoutside) do
            if child:IsValid() and not child.isdead2hm and child.components.health and not child.components.health:IsDead() then
                child.components.health:SetPercent(math.min(child.components.health:GetPercent() + percent / 2, 1))
            end
        end
    end
end
local function mutatedongestaltremove(inst, force)
    if inst.mutatedtarget2hm and inst.mutatedtarget2hm:IsValid() then
        consumereadychildren2hm(inst.mutatedtarget2hm)
        inst.mutatedtarget2hm = nil
    end
end
local function mutatedongestaltentitysleep(inst)
    inst:DoTaskInTime(0, inst.Remove)
    if inst.mutatedtarget2hm and inst.mutatedtarget2hm:IsValid() and not inst.mutatedtarget2hm:IsAsleep() and inst.mutatedspawngestalt2hm then
        inst.mutatedspawngestalt2hm(inst.mutatedtarget2hm)
        inst.mutatedtarget2hm = nil
    end
end
local function mutatedspawngestalt(inst)
    if not inst.components.childspawner2hm then return end
    inst.readychildren2hm = (inst.readychildren2hm or 0) + 1
    if inst.StartLunarRiftMutation and inst.StartLunarRiftMutation ~= nilfn then
        consumereadychildren2hm(inst)
        return
    end
    if not inst.StartLunarRiftMutation then inst.StartLunarRiftMutation = nilfn end
    local gestalt = SpawnPrefab("corpse_gestalt")
    gestalt.AnimState:SetMultColour(0, 0, 0, 0.6)
    gestalt.Transform:SetScale(2, 2, 2)
    gestalt.persists = false
    gestalt:SetTarget(inst)
    gestalt:Spawn()
    gestalt.mutatedtarget2hm = inst
    gestalt.mutatedspawngestalt2hm = mutatedspawngestalt
    gestalt:ListenForEvent("entitysleep", mutatedongestaltentitysleep)
    gestalt:ListenForEvent("onremove", mutatedongestaltremove)
end
-- 和分身交换位置和血量
local function mutatedexchangewithswc2hm(inst)
    if inst:HasTag("swp2hm") and inst.components.health and not inst.components.health:IsDead() and inst.components.childspawner2hm and
        inst.components.childspawner2hm.numchildrenoutside > 0 then
        local finalchild
        local currenthealth = inst.components.health.currenthealth
        for k, child in pairs(inst.components.childspawner2hm.childrenoutside) do
            if child:IsValid() and not child.isdead2hm and child.components.health and not child.components.health:IsDead() then
                if child.components.health.currenthealth > currenthealth then
                    currenthealth = child.components.health.currenthealth
                    finalchild = child
                end
            end
        end
        if finalchild then
            local cx, cy, cz = finalchild.Transform:GetWorldPosition()
            local x, y, z = inst.Transform:GetWorldPosition()
            local fx = SpawnPrefab("shadow_teleport_out2hm")
            fx.Transform:SetPosition(x, y, z)
            finalchild.Transform:SetPosition(x, y, z)
            inst.Transform:SetPosition(cx, cy, cz)
            finalchild.components.health.currenthealth = inst.components.health.currenthealth
            inst.components.health.currenthealth = currenthealth
            finalchild.components.health:ForceUpdateHUD(true)
            inst.components.health:ForceUpdateHUD(true)
            mutatedspawngestalt(inst)
        end
    end
end
-- 传送分身到自己附近
local function mutatedteleportchild(child, inst, radius)
    local theta
    if shadownumber == 1 then
        theta = math.random() * 2 * PI
    elseif not inst.teleportchildindexhm then
        inst.teleportchildtheta2hm = math.random()
        inst.teleportchildindexhm = 0
        theta = inst.teleportchildtheta2hm * 2 * PI
    else
        inst.teleportchildindexhm = inst.teleportchildindexhm + 1
        theta = (inst.teleportchildtheta2hm + 1 / shadownumber * inst.teleportchildindexhm) * 2 * PI
    end
    radius = radius or 10
    local offset = Vector3(radius * math.cos(theta), 0, -radius * math.sin(theta))
    local pt = inst:GetPosition() + offset
    child.Transform:SetPosition(pt.x, pt.y, pt.z)
end
local function mutatedteleportchildren(inst, radius)
    if inst.components.childspawner2hm and inst.components.childspawner2hm.numchildrenoutside > 0 then
        local children = {}
        for k, child in pairs(inst.components.childspawner2hm.childrenoutside) do
            if child:IsValid() and not child.isdead2hm then
                mutatedteleportchild(child, inst, radius)
                table.insert(children, child)
            end
        end
        if inst.teleportchildindexhm then inst.teleportchildindexhm = nil end
        if inst.teleportchildtheta2hm then inst.teleportchildtheta2hm = nil end
        return children
    end
end
-- 血量阈值变化时触发特效
local function mutatedOnHealthChange(inst)
    if not (inst.components.health and not inst.components.health:IsDead()) then return end
    if inst:HasTag("swc2hm") and inst.swp2hm and inst.swp2hm:IsValid() and inst.swp2hm.components.health and not inst.swp2hm.components.health:IsDead() then
        -- 分身血量阈值时,和本体交换位置
        if inst.teleportswptask2hm then return end
        -- if inst.SoundEmitter then inst.SoundEmitter:PlaySound("dontstarve/common/staffteleport") end
        local x, y, z = inst.Transform:GetWorldPosition()
        local fx = SpawnPrefab("shadow_teleport_in2hm")
        fx.Transform:SetPosition(x, y, z)
        local r, g, b, alpha = inst.AnimState:GetMultColour()
        local i = 1
        inst.teleportswptask2hm = inst:DoPeriodicTask(0.1, function(inst)
            if not inst.teleportswptask2hm or i >= 36 then return end
            if i >= 35 then
                inst.AnimState:SetMultColour(r, g, b, alpha)
                if inst.teleportswptask2hm then
                    inst.teleportswptask2hm:Cancel()
                    inst.teleportswptask2hm = nil
                end
            elseif i <= 8 then
                inst.AnimState:SetMultColour(r, g, b, math.max(0.1, alpha - 0.05 * i))
            elseif i == 17 and inst.swp2hm and inst.swp2hm:IsValid() and inst.swp2hm.components.health and not inst.swp2hm.components.health:IsDead() then
                local cx, cy, cz = inst.swp2hm.Transform:GetWorldPosition()
                local x, y, z = inst.Transform:GetWorldPosition()
                local fx = SpawnPrefab("shadow_teleport_out2hm")
                fx.Transform:SetPosition(x, y, z)
                inst.swp2hm.Transform:SetPosition(x, y, z)
                inst.Transform:SetPosition(cx, cy, cz)
            elseif i >= 27 then
                inst.AnimState:SetMultColour(r, g, b, math.min(alpha, (i - 25) * 0.05))
            end
            i = i + 1
        end)
    elseif inst:HasTag("swp2hm") and inst.components.childspawner2hm and inst.components.childspawner2hm.numchildrenoutside > 0 then
        -- if inst.SoundEmitter then inst.SoundEmitter:PlaySound("dontstarve/common/staffteleport") end
        local x, y, z = inst.Transform:GetWorldPosition()
        -- 如果有血量高于自己的分身,则与该分身交换位置和血量,同时增加一个新的分身
        if not inst.exchangewithswctask2hm then
            for k, child in pairs(inst.components.childspawner2hm.childrenoutside) do
                if child:IsValid() and not child.isdead2hm and child.components.health and child.components.health.currenthealth >
                    inst.components.health.currenthealth then
                    local fx = SpawnPrefab("shadow_teleport_in2hm")
                    fx.Transform:SetPosition(x, y, z)
                    local r, g, b, alpha = inst.AnimState:GetMultColour()
                    local i = 1
                    inst.exchangewithswctask2hm = inst:DoPeriodicTask(0.1, function(inst)
                        if not inst.exchangewithswctask2hm or i >= 36 then return end
                        if i >= 35 then
                            inst.AnimState:SetMultColour(r, g, b, alpha)
                            if inst.exchangewithswctask2hm then
                                inst.exchangewithswctask2hm:Cancel()
                                inst.exchangewithswctask2hm = nil
                            end
                        elseif i <= 8 then
                            inst.AnimState:SetMultColour(r, g, b, math.max(0.2, alpha - 0.1 * i))
                        elseif i == 18 then
                            mutatedexchangewithswc2hm(inst)
                        elseif i >= 27 then
                            inst.AnimState:SetMultColour(r, g, b, math.min(alpha, alpha - 0.1 * (35 - i)))
                        end
                        i = i + 1
                    end)
                    return
                end
            end
        end
        if inst.teleportswctask2hm then return end
        -- 如果没有血量高于自己的分身,则传送所有分身到自己附近
        local fx = SpawnPrefab("shadow_teleport_out2hm")
        fx.Transform:SetPosition(x, y, z)
        local r, g, b, alpha = inst.AnimState:GetMultColour()
        local i = 1
        inst.teleportswctask2hm = inst:DoPeriodicTask(0.1, function(inst)
            if not inst.teleportswctask2hm or i >= 36 then return end
            if i >= 35 then
                inst.AnimState:SetMultColour(r, g, b, alpha)
                if inst.teleportswctask2hm then
                    inst.teleportswctask2hm:Cancel()
                    inst.teleportswctask2hm = nil
                end
            elseif i <= 8 then
                local key = 1 - 0.1 * i
                inst.AnimState:SetMultColour(r * key, g * key, b * key, alpha)
            elseif i == 18 then
                mutatedteleportchildren(inst, 10)
                local x, y, z = inst.Transform:GetWorldPosition()
                local fx = SpawnPrefab("shadow_teleport_in2hm")
                fx.Transform:SetPosition(x, y, z)
            elseif i >= 27 then
                local key = (i - 25) * 0.1
                inst.AnimState:SetMultColour(r * key, g * key, b * key, alpha)
            end
            i = i + 1
        end)
    end
end
-- 脱离加载时持续缓慢回血
local function mutatedOnEntitySleep(inst)
    if inst.components.health:IsDead() then return end
    if inst.components.health:IsHurt() then inst.startsleeptime2hm = GetTime() end
end
local function mutatedgain_sleep_health(inst)
    local time_diff = GetTime() - inst.startsleeptime2hm
    if time_diff > 0.0001 then
        local newpercent = (inst.components.health.maxhealth / (TUNING.TOTAL_DAY_TIME * 5) * time_diff + inst.components.health.currenthealth) /
                               inst.components.health.maxhealth
        inst.components.health:SetPercent(newpercent)
    end
end
local function mutatedOnEntityWake(inst)
    if inst.startsleeptime2hm ~= nil then
        mutatedgain_sleep_health(inst)
        inst.startsleeptime2hm = nil
    end
end
local function mutatedonsave(inst, data)
    data.readychildren2hm = inst.readychildren2hm or 0
    if inst.components.childspawner2hm then data.extrachildren2hm = math.max(inst.components.childspawner2hm.maxchildren - shadownumber, 0) end
end
local function mutateddelayonload(inst, num) if inst.components.childspawner2hm then inst.components.childspawner2hm:SetMaxChildren(math.min(num, 6)) end end
local function mutatedonload(inst, data)
    if inst.components.health and not inst.components.health:IsDead() then
        if data and data.readychildren2hm and data.readychildren2hm > 0 then
            inst.components.health:SetPercent(1)
        elseif inst.components.health:GetPercent() < 0.35 then
            inst.components.health:SetPercent(0.35)
        end
    end
    if data and data.extrachildren2hm then inst:DoTaskInTime(FRAMES * 3, mutateddelayonload, shadownumber + data.extrachildren2hm) end
end
local function swp2hmfn(inst)
    if inst.components.childspawner2hm then inst.components.childspawner2hm:SetRegenPeriod(inst.components.childspawner2hm.regenperiod * 4) end
end
function EnableExchangeWitheSwc2hm(inst, healthlist)
    if not shadownumber then return end
    if not inst.components.healthtrigger then inst:AddComponent("healthtrigger") end
    for index, healthvalue in ipairs(healthlist) do inst.components.healthtrigger:AddTrigger(healthvalue, mutatedOnHealthChange) end
    SetOnSave(inst, mutatedonsave)
    SetOnLoad(inst, mutatedonload)
    inst:ListenForEvent("entitysleep", mutatedOnEntitySleep)
    inst:ListenForEvent("entitywake", mutatedOnEntityWake)
    if not inst.swp2hmfn and TUNING.easymode2hm then inst.swp2hmfn = swp2hmfn end
    -- inst:DoTaskInTime(5 + math.random(), mutatedOnHealthChange)
end
-- 新三王本体倒地时转移伤害给血量最少的影分身
local function mutatedredirectdamagefn(inst, attacker, ...)
    if inst.components.childspawner2hm and inst.components.childspawner2hm.numchildrenoutside > 0 then
        local finalchild
        local currenthealth
        for k, child in pairs(inst.components.childspawner2hm.childrenoutside) do
            if child:IsValid() and not child.isdead2hm and child.components.combat and child.components.health and not child.components.health:IsDead() then
                if currenthealth == nil or child.components.health.currenthealth < currenthealth then
                    currenthealth = child.components.health.currenthealth
                    finalchild = child
                end
            end
        end
        if finalchild ~= nil then
            if not inst.teleportdamagefx2hm then
                inst.teleportdamagefx2hm = SpawnPrefab("forcefieldfx")
                inst.teleportdamagefx2hm.entity:SetParent(inst.entity)
                inst.teleportdamagefx2hm.Transform:SetPosition(0, -0.2, 0)
                local bbx1, bby1, bbx2, bby2 = inst.AnimState:GetVisualBB()
                local bby = bby2 - bby1
                inst.teleportdamagefx2hm.Transform:SetScale(2.5, 2.5, 2.5)
                inst.teleportdamagefx2hm.AnimState:SetMultColour(72 / 255, 190 / 255, 148 / 255, 0.5)
                inst.teleportdamagefx2hm.entity:AddFollower()
                inst.teleportdamagefx2hm.Follower:FollowSymbol(inst.GUID, "swap_fire", 0, 250, 0)
            end
            return finalchild
        elseif inst.teleportdamagefx2hm then
            if inst.teleportdamagefx2hm.kill_fx then
                inst.teleportdamagefx2hm:kill_fx()
            else
                inst.teleportdamagefx2hm:Remove()
            end
            inst.teleportdamagefx2hm = nil
        end
    end
end
local function updatemutatedsg(sg)
    if shadownumber then
        if sg.states.stagger_pre then
            local oldpre = sg.states.stagger_pre.onenter
            sg.states.stagger_pre.onenter = function(inst, ...)
                oldpre(inst, ...)
                if inst:HasTag("lunar_aligned") and inst:HasTag("swp2hm") and inst.components.childspawner2hm and inst.components.combat and
                    not inst.components.combat.redirectdamagefn then inst.components.combat.redirectdamagefn = mutatedredirectdamagefn end
            end
        end
        if sg.states.stagger_pst then
            local oldpst = sg.states.stagger_pst.onexit
            sg.states.stagger_pst.onexit = function(inst, ...)
                if oldpst then oldpst(inst, ...) end
                if inst:HasTag("lunar_aligned") and inst:HasTag("swp2hm") and inst.components.childspawner2hm and inst.components.combat and
                    inst.components.combat.redirectdamagefn == mutatedredirectdamagefn then
                    inst.components.combat.redirectdamagefn = nil
                    if inst.teleportdamagefx2hm then
                        if inst.teleportdamagefx2hm.kill_fx then
                            inst.teleportdamagefx2hm:kill_fx()
                        else
                            inst.teleportdamagefx2hm:Remove()
                        end
                        inst.teleportdamagefx2hm = nil
                    end
                end
            end
        end
    end
    if hardgestalt then
        for _, state in pairs(sg.states) do
            if state and state.tags and state.tags.attack and not state.tags.hit and not state.upanim2hm then
                state.upanim2hm = true
                local onenter = state.onenter
                state.onenter = function(inst, ...)
                    onenter(inst, ...)
                    if inst.sg.currentstate == state then
                        if inst:HasTag("lunar_aligned") then
                            SpeedUpState2hm(inst, state, math.max(1.35 + (1 - inst.components.health:GetPercent()) / 4, TUNING.epicupatkanim2hm or 1,
                                                                  TUNING.upatkanim2hm or 1))
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
end
local mutatedfrom = {"bearger", "deerclops", "warg"}
for index, from in ipairs(mutatedfrom) do AddStategraphPostInit(from, updatemutatedsg) end
