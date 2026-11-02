------------------------------------------------------------------------------
-------------------------------[[潜伏梦魇]]-----------------------------------
------------------------------------------------------------------------------
-- TUNING.RUINSNIGHTMARE_HEALTH = 400 -- 削弱到400血
local enableexchange = GetModConfigData("shadowbeak") and GetModConfigData("crawlingshadow") ~= -1
local speedup = GetModConfigData("extra_change") and GetModConfigData("notboss_speed") or 1
local hardmode = GetModConfigData("ruinsnightmare") ~= -1
if speedup < 1.2 then TUNING.RUINSNIGHTMARE_SPEED = TUNING.RUINSNIGHTMARE_SPEED * 1.2 / speedup end -- 2025.10.7 melon临时:1.45 -> 1.2
-- local attackspeedup = GetModConfigData("extra_change") and GetModConfigData("notboss_attackspeed") or 1
-- if attackspeedup < 1.33 then TUNING.RUINSNIGHTMARE_ATTACK_PERIOD = TUNING.RUINSNIGHTMARE_ATTACK_PERIOD * 3 / 4 * attackspeedup end
-- 2025.7.17 melon:潜伏梦魇3面夹击----------------------------------------------------
local function TryReappearingTeleport(inst)
    local x0, y0, z0 = inst.Transform:GetWorldPosition()
    for k = 1, 12 do
        local mult = math.random() > .5 and -1 or 1
        local x = x0 + (10 - k + math.random() * 5) * mult
        local z = z0 + (10 - k + math.random() * 5) * mult
        if TheWorld.Map:IsPassableAtPoint(x, 0, z) then
            inst.Physics:Teleport(x, 0, z)
            return
        end
    end
end
local function SpawnDoubleHornAttack_3(inst, target)
    local left = SpawnPrefab("ruinsnightmare_horn_attack2hm")
    local right = SpawnPrefab("ruinsnightmare_horn_attack2hm")
    local other = SpawnPrefab("ruinsnightmare_horn_attack2hm") -- 加一个 旋转90度
    left:SetUp(inst, target)
    right:SetUp(inst, target, left)
    other:SetUp(inst, target, left, 2) -- 在left的基础上旋转2个45度
end
AddStategraphState("shadowcreature", State{
    name = "horn_attack2hm",
    tags = { "busy", "hit" },

    onenter = function(inst, target)
        inst.Physics:Stop()
        inst.AnimState:PlayAnimation("disappear")

        inst.sg.statemem.target = target
    end,
    events =
    {
        EventHandler("animover", function(inst)
            TryReappearingTeleport(inst)
            if inst.sg.statemem.target ~= nil and inst.sg.statemem.target:IsValid() and not inst.components.health:IsDead() then
                SpawnDoubleHornAttack_3(inst, inst.sg.statemem.target)
            end
            inst:Hide()
            inst.sg:AddStateTag("invisible")
        end),
    },
})
AddStategraphPostInit("shadowcreature", function(sg)
    if sg.events and sg.events.attacked and sg.events.attacked.fn then
        local _fn = sg.events.attacked.fn
        sg.events.attacked.fn = function(inst, data)
            if inst.prefab == "ruinsnightmare" then
                if not (inst.sg:HasAnyStateTag("attack", "hit", "noattack") or inst.components.health:IsDead()) then
                    inst.sg:GoToState(math.random() <= TUNING.RUINSNIGHTMARE_HORNATTACK_CHANCE and "horn_attack2hm" or "hit", data.attacker)
                end
            else
                _fn(inst, data)
            end
        end
    end
end)

-- 死亡生成暗影八角笼
local function deathrattle2hm(inst)
    if inst.disabledeath2hm or inst.wortox_minion then return end
    local x, y, z = inst.Transform:GetWorldPosition()
    local player = FindClosestPlayerInRange(x,y,z, 10, true)
    if player and player:IsValid() then
        local prefx = SpawnPrefab("shadow_despawn")
        player:AddChild(prefx)
        player:DoTaskInTime(1, function()
            local horn = SpawnPrefab("ruinsnightmare_horn_circular_attack_2hm")
            if hardmode then horn.hardmode2hm = true end
            horn.deathrattle2hm = true
            horn.firsthorn2hm = true
            horn:SetUp(nil, player, math.random(5,9), 10)
        end)
    end
end

-- 仇恨时生成战斗暗影角
-- 满足条件释放
local function canspawnhorn(inst)
    if not inst.horn_atktask2hm and inst.components.combat and inst.components.timer and not inst.components.timer:TimerExists("circular_horncd2hm")
    and inst.components.combat.target ~= nil and (inst.components.combat.target:HasTag("player") or inst.canexchange2hm) and not inst.components.combat.target:HasTag("shadowdominance") then
        return true
    end
    return false
end

-- 战斗暗影角
local function spawnhorn2hm(target)
    local prefx = SpawnPrefab("shadow_despawn")
    target:AddChild(prefx)
    target:DoTaskInTime(1, function()
        if target.components.health and target.components.health:IsDead() then return end
        local horn = SpawnPrefab("ruinsnightmare_horn_circular_attack_2hm")
        -- horn.deathrattle2hm = true
        horn.firsthorn2hm = true
        if hardmode then horn.hardmode2hm = true end
        horn:SetUp(target, target, 3)
        if target.components.locomotor and hardmode then
            if target.prefab ~= "ruinsnightmare" or (target.prefab == "ruinsnightmare" and target.spawnbyepic2hm) then
                target.components.locomotor:SetExternalSpeedMultiplier(target, "horn_speedup2hm", target.prefab == "ruinsnightmare" and 1.5 or 1.2)
            elseif target.prefab == "ruinsnightmare" and not target.spawnbyepic2hm then
                local mount
                local combattarget = target.components.combat and target.components.combat.target
                local isriding = combattarget and (combattarget.components.rider and combattarget.components.rider:IsRiding())
                if not isriding then 
                    target.components.locomotor:SetExternalSpeedMultiplier(target, "horn_speedup2hm", 1.5)
                    return
                end
                if isriding then mount = combattarget.Transform:GetScale() end
                local multiplier = 1.5
                if combattarget and combattarget.components.locomotor then
                    local target_speed = combattarget.components.locomotor:GetRunSpeed()
                    local inst_speed = target.components.locomotor:GetRunSpeed()
                    if target_speed ~= nil and inst_speed ~= nil and inst_speed < target_speed then multiplier = target_speed / inst_speed + (isriding and 0.75 or 0.5) end
                end
                if mount then 
                    multiplier = multiplier + (math.max(1,mount) - 1)
                end
                target.components.locomotor:SetExternalSpeedMultiplier(target, "horn_speedup2hm", multiplier)
            end
        end
    end)
end

-- 释放暗影角并且提供加速效果
local helptargettags = {"shadowcreature", "nightmarecreature", "shadowchesspiece"}
local blacklist = {"terrorbeak", "nightmarebeak", "dreadeye"} -- 2025.10.7 melon临时:不给恐怖尖喙/梦魇尖喙加成
local function circular_horn2hm(inst)
    if inst.horn_atktask2hm then return end
    inst.horn_atktask2hm = true
    -- if inst.components.locomotor and inst.spawnbyepic2hm then
    --     inst.components.locomotor:SetExternalSpeedMultiplier(inst, "horn_speedup2hm", 1.5)
    -- elseif inst.components.locomotor and not inst.spawnbyepic2hm then
    --     local target = inst.components.combat and inst.components.combat.target
    --     local multiplier = 1.5
    --     if target and target.components.locomotor then
    --         local target_speed = target.components.locomotor:GetRunSpeed()
    --         local inst_speed = inst.components.locomotor:GetRunSpeed()
    --         if target_speed ~= nil and inst_speed ~= nil then multiplier = target_speed / inst_speed + 0.5 end
    --     end
    --     inst.components.locomotor:SetExternalSpeedMultiplier(inst, "horn_speedup2hm", multiplier)
    -- end
    if inst.components.timer then inst.components.timer:StartTimer("circular_horncd2hm", 20) end
    spawnhorn2hm(inst)

    if inst.spawnbyepic2hm then return end

    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 20, nil, nil, helptargettags)
    inst.spellents2hm = {}
    for i, v in ipairs(ents) do
        if v.canhorn_attack2hm and v.components.timer then
            if v.components.timer:TimerExists("circular_horncd2hm") then
                v.components.timer:SetTimeLeft("circular_horncd2hm", 20)
            else
                v.components.timer:StartTimer("circular_horncd2hm", 20)
            end
        end
        if inst.spellents2hm and #inst.spellents2hm < 6 and v and not table.contains(blacklist, v.prefab) and v ~= inst and not v.horn_atktask2hm then
            -- if v.components.locomotor then v.components.locomotor:SetExternalSpeedMultiplier(v, "horn_speedup2hm", 1.2) end -- 2025.10.7 melon临时:1.5 -> 1.2
            spawnhorn2hm(v)
            v.horn_atktask2hm = true
            table.insert(inst.spellents2hm,v)
        end
    end
end

local function saveandload(inst)
    local _Save = inst.OnSave
    inst.OnSave = function(inst, data, ...)
        if _Save then _Save(inst, data, ...) end
        if inst.spawnbyepic2hm == true then data.spawnbyepic2hm = true end
    end
    local _Load = inst.OnLoad
    inst.OnLoad = function(inst, data, ...)
        if _Load then _Load(inst, data, ...) end
        if data and data.spawnbyepic2hm then inst.spawnbyepic2hm =true end
    end
end

AddPrefabPostInit("ruinsnightmare", function(inst)
    if not TheWorld.ismastersim then return end
    saveandload(inst)
    if not inst.components.timer then inst:AddComponent("timer") end
    if inst.components.combat then
        local oldStartAttack = inst.components.combat.StartAttack
        inst.components.combat.StartAttack = function(self, ...)
            oldStartAttack(self, ...)
            if self.inst and self.inst.horn_atktask2hm then
                self.laststartattacktime = 2 * self.min_attack_period + GetTime()
            end
        end
    end
    inst:ListenForEvent("death", deathrattle2hm)
    inst.canhorn_attack2hm = true
end)

-- 战斗暗影角检测与生成
AddStategraphPostInit("shadowcreature", function(sg)
    local idle = sg.states.idle.onenter
    sg.states.idle.onenter = function(inst, ...)
        if not inst.wortox_minion and inst.canhorn_attack2hm and canspawnhorn(inst) then
            inst.sg:GoToState("taunt")
            return
        end
        idle(inst, ...)
    end
    local taunt = sg.states.taunt.onenter
    sg.states.taunt.onenter = function(inst, ...)
        if inst.canhorn_attack2hm and canspawnhorn(inst) then
            circular_horn2hm(inst)
        end
        taunt(inst, ...)
    end
    local walk = sg.states.walk.onenter
    sg.states.walk.onenter = function(inst, ...)
        if not inst.wortox_minion and inst.canhorn_attack2hm and canspawnhorn(inst) then
            inst.sg:GoToState("taunt")
            return
        end
        walk(inst, ...)
    end
end)

-- 超凡转化-双生暗影
-- 影怪转换条件,位于洞穴,转换次数少于3次,有仇恨,损失血量100点以上,关键技能正在冷却
local function canruinsnightmareexchange(inst)
    return inst.canexchange2hm and not inst.disableexchange2hm and (inst.exchangetimes2hm or 0) < 4 and inst.components.combat.target and
                not (inst.horn_atktask2hm and inst.components.health:GetPercent() >= 0.5) and
                ((inst.exchangetimes2hm or 0) > 0 or inst.components.health:GetPercent() < (1 - 0.25 / (1 - (inst.exchangetimes2hm or 0) * 0.0675))) and
                inst.components.timer and inst.components.timer:TimerExists("circular_horncd2hm")
end

local function onattacked(inst, data)
    if not inst.wortox_minion and not inst.canexchange2hm and not inst.disableexchange2hm and data then
        if data.attacker and data.attacker:HasTag("player") and data.attacker.components.locomotor and data.attacker.components.locomotor:GetRunSpeed() >=
            ((TheWorld:HasTag("cave") or inst:HasTag("nightmarecreature")) and 9 or 10.8) then
            inst.canexchange2hm = true
        elseif data.damage and data.damage >= ((TheWorld:HasTag("cave") or inst:HasTag("nightmarecreature")) and 150 or 200) then
            inst.canexchange2hm = true
        end
    end
end

local exchangetargets = {
        "oceanhorror2hm",
        "crawlingnightmare",
    }

local exchangeradius = -7

local function parentdeath(inst, parent)
    inst.connect_ent2hm = nil
    local size = 1 - (inst.exchangetimes2hm or 0) * 0.0675
    inst:RemoveTag("notarget")
    inst:RemoveTag("noattack")
    inst:RemoveTag("NOBLOCK")
    inst.Physics:SetActive(true)
    inst.Physics:SetCollides(true)
    inst.cantaunt2hm = true
    if inst.updataPStask then
        inst.updataPStask:Cancel()
        inst.updataPStask = nil
    end
end

local function parentremove(inst, parent)
    if not inst:HasTag("NOBLOCK") then return end
    if inst.sg then inst.sg:GoToState("disappear") end
end

local function UpdateChildPosition(child, parent, offset)
    offset = offset or {x = 0, y = 1.5, z = 0}
    
    child.updataPStask = child:DoPeriodicTask(FRAMES, function()
        if not child:IsValid() or not parent:IsValid() then
            return
        end
        local px, py, pz = parent.Transform:GetWorldPosition()
        child.Transform:SetPosition(px + offset.x, 0, pz + offset.z)
    end)
end

if enableexchange then
    AddPrefabPostInit("ruinsnightmare", function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("attacked", onattacked)
    end)

    AddStategraphPostInit("shadowcreature", function(sg)
        local idle = sg.states.idle.onenter
        sg.states.idle.onenter = function(inst, ...)
            if canruinsnightmareexchange(inst) and
            ((inst.connect_ent2hm and not inst.connect_ent2hm.nootherexchange2hm) or inst.connect_ent2hm == nil) then
                inst.sg:GoToState("ruinsnightmare_exchange2hm")
                return
            end
            idle(inst, ...)
        end
    end)

    -- 影怪转换动画
    AddStategraphState("shadowcreature", State {
        name = "ruinsnightmare_exchange2hm",
        tags = {"busy", "attack", "teleporting"},
        onenter = function(inst, playanim)
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
                local target = inst.components.combat.target
                local x, y, z = target.Transform:GetWorldPosition()
                local sx, sy, sz = inst.Transform:GetWorldPosition()
                local radius = exchangeradius or 0
                local theta = inst:GetAngleToPoint(Vector3(x, y, z)) * DEGREES
                sx = sx + radius * math.cos(theta)
                sz = sz - radius * math.sin(theta)
                SpawnPrefab("shadow_teleport_in2hm").Transform:SetPosition(sx, sy, sz)

                local shadow1 = SpawnPrefab("crawlingnightmare")
                -- shadow1:AddChild(shadow2)
                shadow1.canexchange2hm = true
                shadow1.exchangetimes2hm = (inst.exchangetimes2hm or 0) + 1
                shadow1.exchangeprefab2hm = inst.prefab
                shadow1.Transform:SetPosition(sx, sy, sz)
                local size = 1 - (shadow1.exchangetimes2hm or 0) * 0.0675
                shadow1.AnimState:SetScale(size, size, size)
                shadow1.components.combat:SetTarget(target)
                shadow1.components.combat.attackrange = shadow1.components.combat.attackrange * size * size
                shadow1.components.combat.externaldamagemultipliers:SetModifier(shadow1, size, "exchange2hm")
                shadow1.components.locomotor:SetExternalSpeedMultiplier(shadow1, "exchange2hm", size)
                shadow1.components.health.maxhealth = shadow1.components.health.maxhealth * size
                shadow1.components.health:SetVal(inst.components.health:GetPercent() * shadow1.components.health.maxhealth or 400)
                shadow1.components.health:ForceUpdateHUD(true)
                shadow1.sg:GoToState("appear")
                if inst.spawnbyepic2hm then shadow1.spawnbyepic2hm = inst.spawnbyepic2hm end

                if hardmode then
                    local shadow2 = SpawnPrefab("oceanhorror2hm")
                    shadow2:AddTag("notarget")
                    shadow2:AddTag("noattack")
                    shadow2:AddTag("NOBLOCK")
                    shadow2.cantaunt2hm = false
                    shadow2.Physics:SetActive(false)
                    shadow2.Physics:SetCollides(false)
                    shadow2.canexchange2hm = true
                    shadow2.exchangetimes2hm = (inst.exchangetimes2hm or 0) + 1
                    shadow2.exchangeprefab2hm = inst.prefab
                    shadow2.Transform:SetPosition(sx, sy, sz)
                    local size = 1 - (shadow2.exchangetimes2hm or 0) * 0.0675
                    shadow2.AnimState:SetScale(size, size, size)
                    shadow2.components.combat:SetTarget(target)
                    shadow2.components.combat.attackrange = shadow2.components.combat.attackrange * size * size
                    shadow2.components.combat.externaldamagemultipliers:SetModifier(shadow2, size, "exchange2hm")
                    shadow2.components.locomotor:SetExternalSpeedMultiplier(shadow2, "exchange2hm", size)
                    shadow2.components.health.maxhealth = shadow2.components.health.maxhealth * size
                    shadow2.components.health:SetVal(inst.components.health:GetPercent() * shadow2.components.health.maxhealth or 400)
                    shadow2.components.health:ForceUpdateHUD(true)
                    shadow2.sg:GoToState("appear")
                    TheWorld:PushEvent("ms_exchangeshadowcreature", {ent = inst, exchangedent = shadow2})

                    shadow1.connect_ent2hm = shadow2
                    shadow2.connect_ent2hm = shadow1
                    TheWorld:PushEvent("ms_exchangeshadowcreature", {ent = inst, exchangedent = shadow1})

                    UpdateChildPosition(shadow2,shadow1)
                    shadow2:ListenForEvent("death", function(shadow1) parentdeath(shadow2, shadow1) end, shadow1)
                    shadow2:ListenForEvent("onremove", function(shadow1) parentremove(shadow2) end, shadow1)
                    if inst.spawnbyepic2hm then shadow2.spawnbyepic2hm = inst.spawnbyepic2hm end
                end
                
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

-- 新界兼容
if not ModManager:GetMod("workshop-3191348907") or ModManager:GetMod("workshop-3645180511") then return end
AddStategraphPostInit("ruinsnightmare", function(sg)
    if sg.events and sg.events.attacked and sg.events.attacked.fn then
        local _fn = sg.events.attacked.fn
        sg.events.attacked.fn = function(inst, data)
            if inst.prefab == "ruinsnightmare" then
                if not (inst.sg:HasAnyStateTag("attack", "hit", "noattack") or inst.components.health:IsDead()) then
                    inst.sg:GoToState(math.random() <= TUNING.RUINSNIGHTMARE_HORNATTACK_CHANCE and "horn_attack2hm" or "hit", data.attacker)
                end
            else
                _fn(inst, data)
            end
        end
    end
end)

AddStategraphPostInit("ruinsnightmare", function(sg)
    local idle = sg.states.idle.onenter
    sg.states.idle.onenter = function(inst, ...)
        if not inst.wortox_minion and inst.canhorn_attack2hm and canspawnhorn(inst) then
            inst.sg:GoToState("taunt")
            return
        end
        idle(inst, ...)
    end
    local taunt = sg.states.taunt.onenter
    sg.states.taunt.onenter = function(inst, ...)
        if inst.canhorn_attack2hm and canspawnhorn(inst) then
            circular_horn2hm(inst)
        end
        taunt(inst, ...)
    end
    local walk = sg.states.walk.onenter
    sg.states.walk.onenter = function(inst, ...)
        if not inst.wortox_minion and inst.canhorn_attack2hm and canspawnhorn(inst) then
            inst.sg:GoToState("taunt")
            return
        end
        walk(inst, ...)
    end
end)

if enableexchange then
    AddStategraphPostInit("ruinsnightmare", function(sg)
        local idle = sg.states.idle.onenter
        sg.states.idle.onenter = function(inst, ...)
            if canruinsnightmareexchange(inst) and
            ((inst.connect_ent2hm and not inst.connect_ent2hm.nootherexchange2hm) or inst.connect_ent2hm == nil) then
                inst.sg:GoToState("ruinsnightmare_exchange2hm")
                return
            end
            idle(inst, ...)
        end
    end)
end