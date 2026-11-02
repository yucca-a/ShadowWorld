----------------------------------------------------------------------------------------
--                              Uncompromising Mode(永不妥协模组) 
--                                        黑寡妇改动
----------------------------------------------------------------------------------------
require "behaviours/follow"
local attackspeedup = GetModConfigData("extra_change") and GetModConfigData("boss_attackspeed") or 1
local UpvalueHacker = require("upvaluehacker2hm")
-- 黑寡妇吃东西
local SEE_FOOD_DIST = 12
local EATFOOD_CANT_TAGS = {"outofreach", "INLIMBO"}
local function EatFoodAction(inst)
    if inst.sg:HasStateTag("busy") then return end
    inst.food2hm = FindEntity(inst, SEE_FOOD_DIST, function(item) return inst.components.eater:CanEat(item) and item:IsOnValidGround() end, nil,
                              EATFOOD_CANT_TAGS)
    return inst.food2hm ~= nil and BufferedAction(inst, inst.food2hm, ACTIONS.ACTION2HM) or nil
end
local function eatfood2hm(inst)
    if inst.food2hm and inst.food2hm:IsValid() and inst.food2hm:IsOnValidGround() and inst.food2hm:IsNear(inst, 4) then
        if inst.components.eater and inst.components.eater:CanEat(inst.food2hm) then
            inst.components.eater:Eat(inst.food2hm)
        else
            inst.food2hm:Remove()
        end
        inst.food2hm = nil
    end
    inst.sg:GoToState("idle")
end
-- 测试版妥协模组(后续转正需要将模组编号检测修改以兼容版本)
if ModManager:GetMod("workshop-3193922031") then
    local function OtherFollowSymbol(inst, other)
        other.components.lootdropper:SetLoot(nil)
        local diff = 10
        other.DynamicShadow:Enable(false)
        other.entity:AddFollower():FollowSymbol(inst.GUID, "c1", math.random(-diff, diff), 0, math.random(-diff, diff) / 2)
        other:DoTaskInTime(1, function(other) other:Remove() end) -- Give it a second before removal.
    end
    -- 吃蜘蛛时禁止食用影分身蜘蛛
    local function OnHitOther(inst, data)
        local other = data.target
        if other.prefab == "spider" or other.prefab == "aphid" or other.prefab == "hound" or (other.prefab == "spider_trapdoor" and other.components.health:GetPercent() < .5) then -- these guys get KO-ed
            if not inst.components.health:IsDead() and (not inst.sg:HasStateTag("ability") or inst.sg:HasStateTag("eating")) then
                inst.components.health:DoDelta(300)
                if not inst.sg:HasStateTag("eating") then inst.sg:GoToState("eat_small") end
                if other.brain then other.brain:Stop() end
                OtherFollowSymbol(inst, other)
            end
        end
    end
    AddPrefabPostInit("hoodedwidow", function(inst)
        if not TheWorld.ismastersim then return end
        -- 妥协黑寡妇,攻速提高
        if inst.components.combat then
            local oldattack_period = inst.components.combat.min_attack_period or 3
            if attackspeedup < 1.33 then oldattack_period = oldattack_period * 3 / 4 * attackspeedup end
            inst.components.combat:SetAttackPeriod(oldattack_period)
        end
        local _OnHitOther = nil -- 记录原来的函数
        local count_fn = 0 -- 记录个数  保证只有一个目标函数时才修改
        for i, func in ipairs(inst.event_listeners["onhitother"][inst]) do -- 找函数
            if UpvalueHacker.GetUpvalue(func, "OtherFollowSymbol") then
                _OnHitOther = func
                count_fn = count_fn + 1
            end
        end
        if _OnHitOther ~= nil and count_fn == 1 then
            inst:RemoveEventCallback("onhitother", _OnHitOther)
            local OnHitOther = function(inst, data, ...)
                if data and data.target and data.target:HasTag("swc2hm") then return end
                _OnHitOther(inst, data, ...)
            end
            inst:ListenForEvent("onhitother", OnHitOther)
            inst.OnHitOther2hm = OnHitOther -- 保存 方便后续修改
        end
    end)
    AddStategraphActionHandler("hoodedwidow", ActionHandler(ACTIONS.ACTION2HM, "eat2hm"))
    -- 跳跃速度计算到玩家脸上的距离
    AddStategraphPostInit("hoodedwidow", function(sg)
        if sg.states.leapattack then
            local leapattack = sg.states.leapattack.onenter
            sg.states.leapattack.onenter = function(inst, ...)
                leapattack(inst, ...)
                if inst.components.combat.target and inst.components.combat.target:IsValid() then
                    local dist = math.sqrt(inst:GetDistanceSqToInst(inst.components.combat.target))
                    inst.components.locomotor:Stop()
                    inst.Physics:SetMotorVelOverride(math.min(dist * 1.5, 10), 0, 0)
                end
            end
        end
        if sg.states.tree_leapattack then
            local tree_leapattack = sg.states.tree_leapattack.onenter
            sg.states.tree_leapattack.onenter = function(inst, ...)
                tree_leapattack(inst, ...)
                if inst.components.combat.target and inst.components.combat.target:IsValid() then
                    local dist = math.sqrt(inst:GetDistanceSqToInst(inst.components.combat.target))
                    inst.components.locomotor:Stop()
                    inst.Physics:SetMotorVelOverride(math.min(dist * 1.5, 15), 0, 0)
                end
            end
        end 
    end)
    AddStategraphState("hoodedwidow", State {
        name = "eat2hm",
        tags = {"busy"},
        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("shoot_pre")
            inst.AnimState:PushAnimation("shoot_pst", false)
            inst:ClearBufferedAction()
            inst.SoundEmitter:PlaySound("dontstarve/creatures/spiderqueen/scream")
        end,
        timeline = {TimeEvent(24 * FRAMES, eatfood2hm)},
        events = {EventHandler("animqueueover", eatfood2hm)}
    })
    local DIET = {FOODTYPE.MEAT}
    AddPrefabPostInit("hoodedwidow", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.healthtrigger then inst.components.healthtrigger:AddTrigger(0.50031, onhalfhealth) end
        if inst.components.groundpounder and inst.components.groundpounder.noTags then table.insert(inst.components.groundpounder.noTags, "queensstuff") end
        if not inst.components.eater then
            inst:AddComponent("eater")
            inst.components.eater:SetDiet(DIET, DIET)
            inst.components.eater:SetCanEatHorrible()
            inst.components.eater:SetStrongStomach(true) -- can eat monster meat!
            inst.components.eater:SetCanEatRawMeat(true)
        end
    end)
    -- 蜘蛛网范围变大
    AddPrefabPostInit("widow_web_combat", function(inst)
        if inst.GroundCreepEntity then inst.GroundCreepEntity:SetRadius(4) end
        if not TheWorld.ismastersim then return end
        if inst.components.health then inst.components.health:SetMaxHealth(150) end
    end)
    -- 控制技能增强;如果被重复控制则后续控制不触发该效果
    AddPrefabPostInit("web_bomb", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.projectile and not inst.components.projectile.range then inst.components.projectile:SetRange(50) end
    end)
    local function unstickself(inst)
        if not inst.hwuppintask2hm and not inst.delayhwuppintask2hmtask2hm and inst.components.pinnable and
            not (inst.components.health and inst.components.health:IsDead()) then inst.components.pinnable:Unstick() end
    end
    local function Unsticknewstate(inst, data)
        inst:RemoveEventCallback("newstate", Unsticknewstate)
        if data and data.statename ~= "death" and inst.components.pinnable and inst.splashprefabs2hm and
            not (inst.components.health and inst.components.health:IsDead()) then
            inst.components.pinnable:Stick("web_net_trap", inst.splashprefabs2hm)
            inst.components.pinnable.last_stuck_time = inst.laststucktime2hm or GetTime()
            inst:DoTaskInTime(1, unstickself)
        end
        inst.splashprefabs2hm = nil
        inst.laststucktime2hm = nil
        if inst.delayhwuppintask2hmtask2hm then
            inst.delayhwuppintask2hmtask2hm:Cancel()
            inst.delayhwuppintask2hmtask2hm = nil
        end
    end
    local function calcedelayhwuppintask2hmtask2hm(inst)
        inst.delayhwuppintask2hmtask2hm = nil
        inst.splashprefabs2hm = nil
        inst.laststucktime2hm = nil
    end
    local function cancelhwuppintask2hm(inst)
        inst.hwuppintask2hm = nil
        if inst.splashprefabs2hm then
            if not inst.delayhwuppintask2hmtask2hm and inst.continuestick2hm and not (inst.components.health and inst.components.health:IsDead()) then
                inst.delayhwuppintask2hmtask2hm = inst:DoTaskInTime(5, calcedelayhwuppintask2hmtask2hm)
                inst:ListenForEvent("newstate", Unsticknewstate)
            else
                inst.splashprefabs2hm = nil
                inst.laststucktime2hm = nil
            end
        end
        if inst.continuestick2hm then inst.continuestick2hm = nil end
        if TheWorld.FindFirstEntityWithTagtmp2hm then
            getmetatable(TheSim).__index["FindFirstEntityWithTag"] = TheWorld.FindFirstEntityWithTagtmp2hm
            TheWorld.FindFirstEntityWithTagtmp2hm = nil
        end
    end
    AddComponentPostInit("pinnable", function(self)
        local Stick = self.Stick
        self.Stick = function(self, goo_build, splashprefabs, ...)
            if goo_build and goo_build == "web_net_trap" and not self.inst.splashprefabs2hm and
                not (self.inst.components.health and self.inst.components.health:IsDead()) then
                if self.inst.hwuppintask2hm then self.inst.hwuppintask2hm:Cancel() end
                if TheWorld.FindFirstEntityWithTagtmp2hm then
                    getmetatable(TheSim).__index["FindFirstEntityWithTag"] = TheWorld.FindFirstEntityWithTagtmp2hm
                    TheWorld.FindFirstEntityWithTagtmp2hm = nil
                end
                self.inst.hwuppintask2hm = self.inst:DoTaskInTime(4, cancelhwuppintask2hm)
                self.inst.splashprefabs2hm = splashprefabs
                self.inst.laststucktime2hm = GetTime()
            end
            return Stick(self, goo_build, splashprefabs, ...)
        end
        local Unstick = self.Unstick
        self.Unstick = function(self, ...)
            Unstick(self, ...)
            if self.inst.hwuppintask2hm then
                self.inst.hwuppintask2hm:Cancel()
                self.inst.hwuppintask2hm = self.inst:DoTaskInTime(0, cancelhwuppintask2hm)
                local FindFirstEntityWithTag = TheWorld.FindFirstEntityWithTagtmp2hm or getmetatable(TheSim).__index["FindFirstEntityWithTag"]
                TheWorld.FindFirstEntityWithTagtmp2hm = FindFirstEntityWithTag
                getmetatable(TheSim).__index["FindFirstEntityWithTag"] = function(_self, tag, ...)
                    if tag == "widowweb" and self.inst:IsValid() then
                        self.inst.continuestick2hm = true
                        if TheWorld.FindFirstEntityWithTagtmp2hm then
                            getmetatable(TheSim).__index["FindFirstEntityWithTag"] = TheWorld.FindFirstEntityWithTagtmp2hm
                            TheWorld.FindFirstEntityWithTagtmp2hm = nil
                        end
                        tag = "hoodedwidow"
                    end
                    return FindFirstEntityWithTag(_self, tag, ...)
                end
            end
        end
    end)
    -- 触手尖刺可以扎破蜘蛛卵
    local function tentaclespikeattackwebbedcreature(target, inst)
        local chance = math.random()
        if target.components.health and not target.components.health:IsDead() then
            if target:HasTag("largecocoon") and chance <= 0.2 then -- 大包概率为0.2
                target.xueruojiangli2hm = 1
                target.components.health:SetMinHealth(0)
                target.components.health:Kill()
            elseif target:HasTag("mediumcocoon") and chance <= 0.3 then --  中包概率为0.3
                target.xueruojiangli2hm = 1
                target.components.health:SetMinHealth(0)
                target.components.health:Kill()
            elseif target:HasTag("smallcocoon") and chance <= 0.4 then  -- 小包概率为 0.4
                target.xueruojiangli2hm = 1
                target.components.health:SetMinHealth(0)
                target.components.health:Kill()
            end
        end
        if inst:IsValid() and inst.components.finiteuses and inst.components.finiteuses:GetPercent() > 0 then inst.components.finiteuses:SetUses(0) end
    end
    local function ontentaclespikeattack(inst, attacker, target)
        if target and target:IsValid() and target:HasTag("webbedcreature") and inst.components.finiteuses and inst.components.finiteuses:GetPercent() > 0 then
            target:DoTaskInTime(0, tentaclespikeattackwebbedcreature, inst)
        end
    end
    AddPrefabPostInit("tentaclespike", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.weapon and not inst.components.weapon.onattack and inst.components.finiteuses then
            inst.components.weapon:SetOnAttack(ontentaclespikeattack)
        end
    end)

    local function canceltmpSpawnPrefab2hm(inst)
        if TheWorld.tmpSpawnPrefab2hm then
            GLOBAL.SpawnPrefab = TheWorld.tmpSpawnPrefab2hm
            TheWorld.tmpSpawnPrefab2hm = nil
        end
    end
    local function cancelhealthkill(inst)
        if inst.brain then inst.brain:Start() end
        if inst.tempKill2hm then
            if inst.components.health then inst.components.health.Kill = inst.tempKill2hm end
            inst.tempKill2hm = nil
        end
    end
    -- 优化开包奖励机制
    AddPrefabPostInit("widowsgrasp", function(inst)   -- 寡妇爪耐久增加
        if not TheWorld.ismastersim then return end
        local widow_respawntime = TUNING.DRAGONFLY_RESPAWN_TIME / 480
        local widowgraspuse = math.floor(widow_respawntime * 2.4)
        local olduses = inst.components.finiteuses.total
        inst.components.finiteuses:SetMaxUses((olduses or 200) + (widowgraspuse or 0))
        inst.components.finiteuses:SetUses((olduses or 200) + (widowgraspuse or 0))
    end)
    AddPrefabPostInit("webbedcreature", function(inst)
        if not TheWorld.ismastersim then return end
        inst.xueruojiangli2hm = nil -- 削弱奖励条件触发
        local _OnKilled = nil -- 记录原来的函数
        local count_fn = 0 -- 记录个数  保证只有一个目标函数时才修改
        for i, func in ipairs(inst.event_listeners["death"][inst]) do -- 找函数
            if UpvalueHacker.GetUpvalue(func, "AddChanceLoot") then
                _OnKilled = func
                count_fn = count_fn + 1
            end
        end
        if _OnKilled ~= nil and count_fn == 1 then
            inst:RemoveEventCallback("death", _OnKilled)
            local OnKilled = function(inst, ...)
                local chance = math.random()
                local _SpawnPrefab = GLOBAL.SpawnPrefab
                if inst.xueruojiangli2hm == 1 and chance < 0.3 then
                    -- print2hm("活物")
                    GLOBAL.SpawnPrefab = function(name, ...)
                        local ent = _SpawnPrefab(name, ...)
                        if ent.components.health then
                            ent:DoTaskInTime(5 * FRAMES, cancelhealthkill)
                            local Kill = ent.components.health.Kill
                            ent.tempKill2hm = Kill
                            local chance_ = chance
                            chance_ = 0.3 - chance
                            ent.components.health.Kill = function(_self, ...) _self:SetPercent(chance_ * 4) end
                        end
                        return ent
                    end
                end
                -- print2hm(chance)
                local DropLoot = inst.components.lootdropper.DropLoot
                if inst.components.lootdropper then
                    inst.components.lootdropper.DropLoot = function(self, ...)
                        if inst.xueruojiangli2hm == 1 then
                            inst.xueruojiangli2hm = nil
                            -- 0.9概率减少额外掉落,0.1概率正常额外掉落,蜘蛛丝除保底外减少部分掉落概率
                            if self.chanceloot and chance < 0.9 then
                                -- print2hm("削弱")
                                local firstsilk
                                for i = #self.chanceloot, 1, -1 do
                                    if self.chanceloot[i].prefab ~= "silk" then
                                        table.remove(self.chanceloot, i)
                                    elseif not firstsilk and self.chanceloot[i].chance >= 1 then
                                        firstsilk = true
                                    else
                                        self.chanceloot[i].chance = self.chanceloot[i].chance * chance
                                    end
                                end
                            end
                            return DropLoot(self, ...)
                        else
                            -- print2hm("不变")
                            return DropLoot(self, ...)
                        end
                    end
                end
                local value = _OnKilled(inst, ...)
                GLOBAL.SpawnPrefab = _SpawnPrefab
                return value
            end
            inst:ListenForEvent("death", OnKilled)
            inst.OnKilled2hm = OnKilled -- 保存 方便后续修改
        end
    end)
-- 正式版妥协模组
elseif ModManager:GetMod("workshop-2039181790") then
    -- 黑寡妇和蜘蛛女王吃东西
    -- 妥协黑寡妇,攻速和AI提高,但会导致技能放不出来,所以修改ai和sg
    if attackspeedup < 1.33 then TUNING.SPIDERQUEEN_ATTACKPERIOD = TUNING.SPIDERQUEEN_ATTACKPERIOD * 3 / 4 * attackspeedup end
    local function EquipWeapon(inst, weapon)
        if weapon and weapon:IsValid() and weapon.components.equippable and not weapon.components.equippable:IsEquipped() and inst.components.inventory then
            inst.components.inventory:Equip(weapon)
        end
    end
    local neardist = 144
    local awaydist = 400
    local function cancelgohometask2hm(inst)
        if inst.components.combat.target == nil and inst.sg and not inst.sg:HasStateTag("busy") then inst.sg:GoToState("jumphome") end
        inst.gohometask2hm = nil
    end
    -- 黑寡妇的远程攻击AI被替换
    AddBrainPostInit("hoodedwidowbrain", function(self)
        if self.bt.root and self.bt.root.period == 2 and self.bt.root.children and self.inst.weaponitems then
            self.bt.root.period = 1
            local newaction = WhileNode(function()
                if self.inst.sg and self.inst.components.combat then
                    if self.inst.components.combat.target and self.inst.components.combat.target:IsValid() then
                        if self.inst.gohometask2hm then
                            self.inst.gohometask2hm:Cancel()
                            self.inst.gohometask2hm = nil
                        end
                        if self.inst.sg.currentstate and self.inst.sg.currentstate.name == "launchprojectile" then return true end
                        if self.inst.sg:HasStateTag("busy") then return end
                        -- 远程攻击可能不该有awaydist, 应该用combat.keeptargetfn,但寡妇没有
                        local distsq = self.inst:GetDistanceSqToInst(self.inst.components.combat.target)
                        return distsq > neardist and distsq < awaydist
                    elseif not self.inst.gohometask2hm then
                        self.inst.gohometask2hm = self.inst:DoTaskInTime(10, cancelgohometask2hm)
                        return
                    end
                end
            end, "Attack not Near", SequenceNode(
                {ActionNode(function() EquipWeapon(self.inst, self.inst.weaponitems.snotbomb) end, "Equip thrower"), ChaseAndAttack(self.inst)}))
            table.insert(self.bt.root.children, 2, newaction)
            if self.bt.root.children[4] and self.bt.root.children[4].name == "AttackMomentarily" then table.remove(self.bt.root.children, 4) end
            if self.bt.root.children[5] and self.bt.root.children[5].name == "AttackMomentarily" then table.remove(self.bt.root.children, 5) end
            table.insert(self.bt.root.children, 5, DoAction(self.inst, function() return EatFoodAction(self.inst) end))
        end
    end)
    AddStategraphActionHandler("hoodedwidow", ActionHandler(ACTIONS.ACTION2HM, "eat2hm"))
    AddStategraphPostInit("hoodedwidow", function(sg)
        local launchprojectile = sg.states.launchprojectile.onenter
        sg.states.launchprojectile.onenter = function(inst, ...)
            if inst.weaponitems and inst.components.combat and inst.components.combat.target and inst.components.combat.target:IsValid() and inst.components.timer then
                if not inst.components.timer:TimerExists("pounce") then
                    EquipWeapon(inst, inst.weaponitems.meleeweapon)
                    inst.sg:GoToState("preleapattack")
                    return
                elseif not inst.components.timer:TimerExists("mortar") and inst.components.combat.target:IsNear(inst, 15) then
                    EquipWeapon(inst, inst.weaponitems.meleeweapon)
                    inst.sg:GoToState("lobprojectile")
                    return
                end
            end
            launchprojectile(inst, ...)
        end
        local attack = sg.states.attack.onenter
        sg.states.attack.onenter = function(inst, ...)
            local weapon = inst.components.combat and inst.components.combat:GetWeapon()
            if weapon and not weapon:HasTag("snotbomb") and inst.components.timer then
                if not inst.components.timer:TimerExists("pounce") then
                    inst.sg:GoToState("preleapattack")
                    return
                elseif not inst.components.timer:TimerExists("mortar") then
                    inst.sg:GoToState("lobprojectile")
                    return
                end
            end
            attack(inst, ...)
        end
        local leapattack = sg.states.leapattack.onenter
        sg.states.leapattack.onenter = function(inst, ...)
            leapattack(inst, ...)
            if inst.components.combat.target and inst.components.combat.target:IsValid() then
                local dist = math.sqrt(inst:GetDistanceSqToInst(inst.components.combat.target))
                inst.components.locomotor:Stop()
                inst.Physics:SetMotorVelOverride(math.min(dist * 1.5, 20), 0, 0)
            end
        end
        if sg.states.lobprojectile.timeline then
            for key, timeevent in pairs(sg.states.lobprojectile.timeline) do
                local fn = timeevent.fn
                timeevent.fn = function(inst, ...)
                    if inst.weaponitems then
                        EquipWeapon(inst, inst.weaponitems.meleeweapon)
                    end
                    fn(inst, ...)
                end
            end
        end
    end)
    AddStategraphState("hoodedwidow", State {
        name = "eat2hm",
        tags = {"busy"},
        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("shoot_pre")
            inst.AnimState:PushAnimation("shoot_pst", false)
            inst:ClearBufferedAction()
            inst.SoundEmitter:PlaySound("dontstarve/creatures/spiderqueen/scream")
        end,
        timeline = {TimeEvent(24 * FRAMES, eatfood2hm)},
        events = {EventHandler("animqueueover", eatfood2hm)}
    })
    -- 半血时生成一批妥协蜘蛛袭击玩家
    local function processspider(inst, hoodedwidow)
        inst.hoodedwidow2hm = hoodedwidow or (inst.swp2hm and inst.swp2hm.hoodedwidow2hm)
        inst:AddTag("queensstuff")
        inst.persists = false
        inst.OnEntitySleep = inst.Remove
        local self = inst.components.combat
        local oldCanHitTarget = self.CanHitTarget
        self.CanHitTarget = function(self, target, ...) return target and oldCanHitTarget(self, target, ...) and not target:HasTag("hoodedwidow") end
        local oldIsValidTarget = self.IsValidTarget
        self.IsValidTarget = function(self, target, ...) return target and oldIsValidTarget(self, target, ...) and not target:HasTag("hoodedwidow") end
        if inst.components.follower and inst.hoodedwidow2hm and inst.hoodedwidow2hm:IsValid() then
            inst.components.follower:SetLeader(inst.hoodedwidow2hm)
        end
    end
    local function onhalfhealth(inst)
        -- 2025.7.19 melon:影子不生成 and not inst:HasTag("swc2hm")
        if inst.components.combat and inst.components.combat.target and not inst:HasTag("swc2hm") then
            for i = 1, 3, 1 do
                local spider = SpawnMonster2hm(inst.components.combat.target, "spider_trapdoor", 20)
                if spider then
                    spider.swc2hmfn = processspider
                    processspider(spider, inst)
                end
            end
        end
    end
    local DIET = {FOODTYPE.MEAT}
    AddPrefabPostInit("hoodedwidow", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.healthtrigger then inst.components.healthtrigger:AddTrigger(0.50031, onhalfhealth) end
        if inst.components.groundpounder and inst.components.groundpounder.noTags then table.insert(inst.components.groundpounder.noTags, "queensstuff") end
        -- 蛛网射线射程提高到36,但只会在20距离内释放,且飞行距离改为50
        if inst.weaponitems and inst.weaponitems.snotbomb and inst.weaponitems.snotbomb:IsValid() and inst.weaponitems.snotbomb.components.weapon then
            inst.weaponitems.snotbomb.components.weapon:SetRange(TUNING.SPAT_PHLEGM_ATTACKRANGE * 3)
        end
        if not inst.components.eater then
            inst:AddComponent("eater")
            inst.components.eater:SetDiet(DIET, DIET)
            inst.components.eater:SetCanEatHorrible()
            inst.components.eater:SetStrongStomach(true) -- can eat monster meat!
            inst.components.eater:SetCanEatRawMeat(true)
        end
    end)
    -- 蜘蛛网范围变大
    AddPrefabPostInit("widow_web_combat", function(inst)
        if inst.GroundCreepEntity then inst.GroundCreepEntity:SetRadius(4) end
        if not TheWorld.ismastersim then return end
        if inst.components.health then inst.components.health:SetMaxHealth(150) end
    end)
    -- 控制技能增强;如果被重复控制则后续控制不触发该效果
    AddPrefabPostInit("web_bomb", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.projectile and not inst.components.projectile.range then inst.components.projectile:SetRange(50) end
    end)
    local function unstickself(inst)
        if not inst.hwuppintask2hm and not inst.delayhwuppintask2hmtask2hm and inst.components.pinnable and
            not (inst.components.health and inst.components.health:IsDead()) then inst.components.pinnable:Unstick() end
    end
    local function Unsticknewstate(inst, data)
        inst:RemoveEventCallback("newstate", Unsticknewstate)
        if data and data.statename ~= "death" and inst.components.pinnable and inst.splashprefabs2hm and
            not (inst.components.health and inst.components.health:IsDead()) then
            inst.components.pinnable:Stick("web_net_trap", inst.splashprefabs2hm)
            inst.components.pinnable.last_stuck_time = inst.laststucktime2hm or GetTime()
            inst:DoTaskInTime(1, unstickself)
        end
        inst.splashprefabs2hm = nil
        inst.laststucktime2hm = nil
        if inst.delayhwuppintask2hmtask2hm then
            inst.delayhwuppintask2hmtask2hm:Cancel()
            inst.delayhwuppintask2hmtask2hm = nil
        end
    end
    local function calcedelayhwuppintask2hmtask2hm(inst)
        inst.delayhwuppintask2hmtask2hm = nil
        inst.splashprefabs2hm = nil
        inst.laststucktime2hm = nil
    end
    local function cancelhwuppintask2hm(inst)
        inst.hwuppintask2hm = nil
        if inst.splashprefabs2hm then
            if not inst.delayhwuppintask2hmtask2hm and inst.continuestick2hm and not (inst.components.health and inst.components.health:IsDead()) then
                inst.delayhwuppintask2hmtask2hm = inst:DoTaskInTime(5, calcedelayhwuppintask2hmtask2hm)
                inst:ListenForEvent("newstate", Unsticknewstate)
            else
                inst.splashprefabs2hm = nil
                inst.laststucktime2hm = nil
            end
        end
        if inst.continuestick2hm then inst.continuestick2hm = nil end
        if TheWorld.FindFirstEntityWithTagtmp2hm then
            getmetatable(TheSim).__index["FindFirstEntityWithTag"] = TheWorld.FindFirstEntityWithTagtmp2hm
            TheWorld.FindFirstEntityWithTagtmp2hm = nil
        end
    end
    AddComponentPostInit("pinnable", function(self)
        local Stick = self.Stick
        self.Stick = function(self, goo_build, splashprefabs, ...)
            if goo_build and goo_build == "web_net_trap" and not self.inst.splashprefabs2hm and
                not (self.inst.components.health and self.inst.components.health:IsDead()) then
                if self.inst.hwuppintask2hm then self.inst.hwuppintask2hm:Cancel() end
                if TheWorld.FindFirstEntityWithTagtmp2hm then
                    getmetatable(TheSim).__index["FindFirstEntityWithTag"] = TheWorld.FindFirstEntityWithTagtmp2hm
                    TheWorld.FindFirstEntityWithTagtmp2hm = nil
                end
                self.inst.hwuppintask2hm = self.inst:DoTaskInTime(4, cancelhwuppintask2hm)
                self.inst.splashprefabs2hm = splashprefabs
                self.inst.laststucktime2hm = GetTime()
            end
            return Stick(self, goo_build, splashprefabs, ...)
        end
        local Unstick = self.Unstick
        self.Unstick = function(self, ...)
            Unstick(self, ...)
            if self.inst.hwuppintask2hm then
                self.inst.hwuppintask2hm:Cancel()
                self.inst.hwuppintask2hm = self.inst:DoTaskInTime(0, cancelhwuppintask2hm)
                local FindFirstEntityWithTag = TheWorld.FindFirstEntityWithTagtmp2hm or getmetatable(TheSim).__index["FindFirstEntityWithTag"]
                TheWorld.FindFirstEntityWithTagtmp2hm = FindFirstEntityWithTag
                getmetatable(TheSim).__index["FindFirstEntityWithTag"] = function(_self, tag, ...)
                    if tag == "widowweb" and self.inst:IsValid() then
                        self.inst.continuestick2hm = true
                        if TheWorld.FindFirstEntityWithTagtmp2hm then
                            getmetatable(TheSim).__index["FindFirstEntityWithTag"] = TheWorld.FindFirstEntityWithTagtmp2hm
                            TheWorld.FindFirstEntityWithTagtmp2hm = nil
                        end
                        tag = "hoodedwidow"
                    end
                    return FindFirstEntityWithTag(_self, tag, ...)
                end
            end
        end
    end)

    -- 触手尖刺可以扎破蜘蛛卵
    local function tentaclespikeattackwebbedcreature(target, inst)
        local chance = math.random()
        if target.components.health and not target.components.health:IsDead() then
            if target:HasTag("largecocoon") and chance <= 0.2 then -- 大包概率为0.1
                target.components.health:Kill()
            elseif target:HasTag("mediumcocoon") and chance <= 0.3 then --  中包概率为0.3
                target.components.health:Kill()
            elseif target:HasTag("smallcocoon") and chance <= 0.4 then  -- 小包概率为 0.5
                target.components.health:Kill()
            end
        end
        if inst:IsValid() and inst.components.finiteuses and inst.components.finiteuses:GetPercent() > 0 then inst.components.finiteuses:SetUses(0) end
    end
    local function ontentaclespikeattack(inst, attacker, target)
        if target and target:IsValid() and target:HasTag("webbedcreature") and inst.components.finiteuses and inst.components.finiteuses:GetPercent() > 0 then
            target:DoTaskInTime(0, tentaclespikeattackwebbedcreature, inst)
        end
    end
    AddPrefabPostInit("tentaclespike", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.weapon and not inst.components.weapon.onattack and inst.components.finiteuses then
            inst.components.weapon:SetOnAttack(ontentaclespikeattack)
        end
    end)

    local function canceltmpSpawnPrefab2hm(inst)
        if TheWorld.tmpSpawnPrefab2hm then
            GLOBAL.SpawnPrefab = TheWorld.tmpSpawnPrefab2hm
            TheWorld.tmpSpawnPrefab2hm = nil
        end
    end
    local function cancelhealthkill(inst)
        if inst.tempKill2hm then
            if inst.components.health then inst.components.health.Kill = inst.tempKill2hm end
            inst.tempKill2hm = nil
        end
    end

    -- 优化开包奖励机制
    AddPrefabPostInit("widowsgrasp", function(inst)   -- 寡妇爪耐久怎加至15次
        if not TheWorld.ismastersim then return end
        local widow_respawntime = TUNING.DRAGONFLY_RESPAWN_TIME / 480
        local widowgraspuse = math.floor(widow_respawntime * 0.12)
        local olduses = inst.components.finiteuses.total
        inst.components.finiteuses:SetMaxUses((olduses or 9) + (widowgraspuse or 0))
        inst.components.finiteuses:SetUses((olduses or 9) + (widowgraspuse or 0))
    end)
    AddPrefabPostInit("webbedcreature", function(inst)
        if not TheWorld.ismastersim then return end
        inst.xueruojiangli = nil -- 削弱奖励条件触发
        local DropLoot = inst.components.lootdropper.DropLoot
        inst:ListenForEvent("attacked", function(inst, data)
            local attacker = data and data.attacker
            local weapon = data and data.weapon
            if weapon and (weapon.prefab ~= "tentaclespike" or weapon.prefab ~= "widowsgrasp") then return end
            if attacker and attacker:HasTag("player") then
                if weapon and weapon.prefab ~= "widowsgrasp" then  -- 不是寡妇爪开袋触发削弱奖励
                    inst.xueruojiangli = 1  -- 设置削弱奖励条件
                end
            end
            if  inst.xueruojiangli == 1 then -- 削弱奖励内容
                inst.xueruojiangli = nil -- 重置削弱奖励条件
                if inst.components.lootdropper then
                    inst.components.lootdropper.DropLoot = function(self, ...)
                        local chance = math.random()
                        if not TheWorld.tmpSpawnPrefab2hm then
                            TheWorld:DoTaskInTime(0, canceltmpSpawnPrefab2hm)
                            local _SpawnPrefab = GLOBAL.SpawnPrefab
                            TheWorld.tmpSpawnPrefab2hm = _SpawnPrefab
                            GLOBAL.SpawnPrefab = function(name, ...)
                                local ent = _SpawnPrefab(name, ...)
                                if ent.components.health and chance < 0.3 then --开出活物的概率为0.3
                                    ent:DoTaskInTime(0, cancelhealthkill)
                                    local Kill = ent.components.health.Kill
                                    ent.tempKill2hm = Kill
                                    ent.components.health.Kill = function(_self, ...) _self:SetPercent(chance * 4) end
                                end
                                return ent
                            end
                        end
                        -- 0.9概率减少额外掉落,0.1概率正常额外掉落,蜘蛛丝除保底外减少部分掉落概率
                        if self.chanceloot and chance < 0.9 then
                            local firstsilk
                            for i = #self.chanceloot, 1, -1 do
                                if self.chanceloot[i].prefab ~= "silk" then
                                    table.remove(self.chanceloot, i)
                                elseif not firstsilk and self.chanceloot[i].chance >= 1 then
                                    firstsilk = true
                                else
                                    self.chanceloot[i].chance = self.chanceloot[i].chance * chance
                                end
                            end
                        end
                        return DropLoot(self, ...)
                    end
                end
            elseif inst.xueruojiangli == nil then -- 没触发削弱奖励条件则正常执行原版掉落
                inst.components.lootdropper.DropLoot = DropLoot
            end
        end)
    end)
end