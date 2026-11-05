local hardmode = TUNING.hardmode2hm and GetModConfigData("role_nerf") and GetModConfigData("webber")

-- 韦伯吃肉收买蜘蛛
if GetModConfigData("Webber Eat Meat Lead Wild Spider") then
    local function OnEat(inst, data)
        if data.food ~= nil and data.food.components.edible and data.food.components.edible.foodtype == FOODTYPE.MEAT and inst.components.leader then
            local self = inst.components.leader
            local num = 1
            local max = 1
            if inst.components.hunger.current > 102 then
                max = 1 + math.floor((inst.components.hunger.current - 100) / 3)
            end
            if TUNING.maxfollowernum2hm and self.calculaterepeatfollowers2hm then
                local followers = self:calculaterepeatfollowers2hm()
                max = math.min(TUNING.maxfollowernum2hm - #followers, max)
                if max <= 0 then return end
            end
            num = max
            local x, y, z = inst.Transform:GetWorldPosition()
            local ents = TheSim:FindEntities(x, y, z, 20, {"spider"}, {"swc2hm"})
            for k, v in pairs(ents) do
                if v.components.follower and not v.components.follower.leader then
                    self:AddFollower(v)
                    num = num - 1
                    if num <= 0 then break end
                end
            end
            if max and num ~= max and max - num > 1 then inst.components.hunger:DoDelta(-(max - num - 1) * 3) end
        end
    end
    AddPrefabPostInit("webber", function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("oneat", OnEat)
        if inst.components.hunger then inst.components.hunger.delayoverflow2hm = true end
    end)
    local function CanEat(self, food)
        return self:TestFood(food, self.caneat) and
                   (not (self.inst.components.follower and self.inst.components.follower.leader and self.inst.components.follower.leader:HasTag("player")) or
                       (food and food.components.inventoryitem and food.components.inventoryitem.owner ~= nil))
    end
    local function OnStartLeashing(inst, data)
        inst:PushEvent("detachchild")
        if inst.components.homeseeker then
            inst.components.homeseeker:SetHome(nil)
            inst:RemoveComponent("homeseeker")
        end
    end
    AddPrefabPostInitAny(function(inst)
        if not TheWorld.ismastersim then return end
        if inst:HasTag("spider") then
            if inst.components.follower then
                inst.components.follower.keepdeadleader = true
                inst:ListenForEvent("startleashing", OnStartLeashing)
            end
            if inst.components.eater then inst.components.eater.CanEat = CanEat end
        end
    end)
end

-- 韦伯吃涂鸦升级蜘蛛
if GetModConfigData("Webber Eat Switcherdoodle Switch Spider") then
    local function delayprocess(new_spider, inst) if new_spider.components.follower then new_spider.components.follower:SetLeader(inst) end end
    local function delaymutate(spider, inst, self)
        spider.mutation_target = self.mutation_target
        spider.mutator_giver = inst
        spider:PushEvent("mutate")
    end
    local function OnEat(inst, data)
        if data.food ~= nil and data.food:HasTag("spidermutator") and data.food.components.spidermutator and data.food.components.spidermutator.mutation_target and
            inst.components.leader and inst.components.leader.followers then
            local num = 1
            local max
            if inst.components.hunger.current >= 125 then
                max = 1 + math.floor((inst.components.hunger.current - 100) / 25)
                num = max
            end
            local self = data.food.components.spidermutator
            for spider, v in pairs(inst.components.leader.followers) do
                if num > 0 and spider.prefab == "spider" and not spider:HasTag("swc2hm") and spider.components.inventoryitem and
                    spider.components.inventoryitem.owner == nil and data.food.components.spidermutator:CanMutate(spider) then
                    spider:DoTaskInTime(0, delaymutate, inst, self)
                    num = num - 1
                end
            end
            local enablefx = false
            if num > 0 then
                for spider, v in pairs(inst.components.leader.followers) do
                    if num > 0 and spider.prefab == "spider" and not spider:HasTag("swc2hm") and spider.components.inventoryitem and
                        spider.components.inventoryitem.owner == inst and data.food.components.spidermutator:CanMutate(spider) then
                        local container = spider.components.inventoryitem.owner.components.inventory
                        if container then
                            local slot = container:GetItemSlot(spider)
                            container:RemoveItem(spider)
                            spider:DoTaskInTime(0, spider.Remove)
                            local new_spider = SpawnPrefab(self.mutation_target)
                            if new_spider.components.inventoryitem then container:GiveItem(new_spider, slot) end
                            new_spider:DoTaskInTime(0, delayprocess, inst)
                            num = num - 1
                            enablefx = true
                        end
                    end
                end
            end
            if num > 0 then
                for spider, v in pairs(inst.components.leader.followers) do
                    if num > 0 and spider.prefab == "spider" and not spider:HasTag("swc2hm") and spider.components.inventoryitem and
                        spider.components.inventoryitem.owner ~= nil and spider.components.inventoryitem:GetGrandOwner() == inst and
                        data.food.components.spidermutator:CanMutate(spider) then
                        local container = spider.components.inventoryitem.owner.components.container
                        if container and container.canbeopened then
                            local slot = container:GetItemSlot(spider)
                            container:RemoveItem(spider)
                            spider:DoTaskInTime(0, spider.Remove)
                            local new_spider = SpawnPrefab(self.mutation_target)
                            if new_spider.components.inventoryitem then container:GiveItem(new_spider, slot) end
                            new_spider:DoTaskInTime(0, delayprocess, inst)
                            num = num - 1
                            enablefx = true
                        end
                    end
                end
            end
            if enablefx then
                local x, y, z = inst.Transform:GetWorldPosition()
                local fx = SpawnPrefab("spider_mutate_fx")
                fx.Transform:SetPosition(x, y, z)
            end
            if max and num ~= max and max - num > 1 then inst.components.hunger:DoDelta(-(max - num - 1) * 25) end
        end
    end
    AddPrefabPostInit("webber", function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("oneat", OnEat)
    end)
end

-- -- 护士蜘蛛
-- if GetModConfigData("spider_healer") then
--     -- 回血卡顿
--     local SpawnHealFx
--     local GetOtherSpiders
--     local function checkextraheal(inst, prefab)
--         inst.extrahealidx = inst.extrahealidx + 1
--         if inst.extraheal2hm > 0 and inst.components.health and not inst.components.health:IsDead() and inst.components.health:IsHurt() then
--             if hardmode then SpawnHealFx(inst, "spider_heal_target_fx", 0.7) end
--             local oldhealth = inst.components.health.currenthealth
--             inst.components.health:DoDelta(inst.extraheal2hm, false, prefab)
--             local newhealth = inst.components.health.currenthealth
--             inst.extraheal2hm = TUNING.SPIDER_HEALING_AMOUNT + oldhealth - newhealth
--         end
--         if inst.extraheal2hm <= 0 or inst.extrahealidx >= TUNING.SPIDER_HEALING_COOLDOWN * 3 / 4 then
--             inst.extrahealidx = nil
--             inst.extraheal2hm = nil
--             inst.extrahealtask2hm:Cancel()
--             inst.extrahealtask2hm = nil
--         end
--     end
--     local function newDoHeal(inst)
--         local scale = 1.35
--         SpawnHealFx(inst, "spider_heal_ground_fx", scale)
--         SpawnHealFx(inst, "spider_heal_fx", scale)
--         local other_spiders = GetOtherSpiders(inst, TUNING.SPIDER_HEALING_RADIUS, {"spider", "spiderwhisperer", "spiderqueen"})
--         local leader = inst.components.follower.leader
--         local hurtspiders = {}
--         local nohurtspiders = {}
--         for i, spider in ipairs(other_spiders) do
--             local target = inst.components.combat.target
--             if (not hardmode or spider.healtime == nil or GetTime() - spider.healtime >= TUNING.SPIDER_HEALING_COOLDOWN) and
--                 not ((target ~= nil and (target == inst or (leader ~= nil and (target == leader or leader.components.leader:IsFollower(target))))) or
--                     (inst.components.combat.target == spider or
--                         (leader ~= nil and (leader.components.combat:TargetIs(spider) or leader.components.leader:IsTargetedByFollowers(spider))))) then
--                 if spider.components.health:IsHurt() then
--                     table.insert(hurtspiders, spider)
--                 else
--                     table.insert(nohurtspiders, spider)
--                 end
--             end
--         end
--         if #hurtspiders < TUNING.SPIDER_HEALING_COOLDOWN then for i, spider in ipairs(nohurtspiders) do table.insert(hurtspiders, spider) end end
--         -- 限制蜘蛛数目，优先受伤单位，限制
--         local idx = 0
--         for i, spider in ipairs(hurtspiders) do
--             local heal_amount = spider:HasTag("player") and TUNING.HEALING_MEDSMALL or TUNING.SPIDER_HEALING_AMOUNT
--             local oldhealth = spider.components.health.currenthealth
--             spider.components.health:DoDelta(heal_amount, false, inst.prefab)
--             local newhealth = spider.components.health.currenthealth
--             if newhealth > oldhealth then SpawnHealFx(spider, "spider_heal_target_fx") end
--             if not spider:HasTag("player") then
--                 idx = idx + 1
--                 -- if hardmode then
--                 --     spider.healtime = GetTime()
--                 --     spider:PushEvent("transfercombattarget", inst)
--                 -- end
--                 local extra = TUNING.SPIDER_HEALING_AMOUNT + oldhealth - newhealth
--                 if extra > 0 then
--                     spider.extraheal2hm = hardmode and math.min((spider.extraheal2hm or 0) + extra, TUNING.SPIDER_HEALING_AMOUNT) or
--                                               ((spider.extraheal2hm or 0) + extra)
--                     if not spider.extrahealtask2hm then spider.extrahealtask2hm = spider:DoPeriodicTask(2, checkextraheal, nil, inst.prefab) end
--                     spider.extrahealidx = 0
--                 elseif spider.extrahealtask2hm then
--                     spider.extrahealidx = 0
--                 end
--                 if hardmode and idx >= TUNING.SPIDER_HEALING_COOLDOWN then break end
--             end
--             inst.healtime = GetTime()
--             if hardmode then inst.components.health:DeltaPenalty(0.0125 * idx) end
--         end
--     end
--     AddPrefabPostInit("spider_healer", function(inst)
--         if not TheWorld.ismastersim then return end
--         if inst.DoHeal then
--             if not SpawnHealFx then SpawnHealFx = getupvalue2hm(inst.DoHeal, "SpawnHealFx") end
--             if not GetOtherSpiders then GetOtherSpiders = getupvalue2hm(inst.DoHeal, "GetOtherSpiders") end
--             if SpawnHealFx and GetOtherSpiders then inst.DoHeal = newDoHeal end
--         end
--     end)
-- end

-- 韦伯谋杀蜘蛛获得涂鸦
if GetModConfigData("Webber Murder Spider Get Switcherdoodle") then
    local needhunger = GetModConfigData("Webber Murder Spider Get Switcherdoodle")
    local function OnMurdered(inst, data)
        if data.victim ~= nil and data.victim:HasTag("spider") and data.victim.prefab ~= "spider" and inst.components.hunger.current >= 150 and
            string.match(data.victim.prefab, "spider_") then
            local persistentdata = inst.components.persistent2hm.data
            if hardmode and (persistentdata.murderspidercd or 0) >= TheWorld.state.cycles + 1 then return end
            local doodle = SpawnPrefab("mutator_" .. string.sub(data.victim.prefab, 8))
            if doodle ~= nil then
                persistentdata.murderspidercd = math.max(persistentdata.murderspidercd or 0, TheWorld.state.cycles) + 0.15
                inst.components.inventory:GiveItem(doodle)
                inst.components.hunger:DoDelta(-needhunger)
            end
        end
    end
    AddPrefabPostInit("webber", function(inst)
        if not TheWorld.ismastersim then return end
        if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
        inst:ListenForEvent("murdered", OnMurdered)
    end)
end

-- 韦伯升级三级蜘蛛巢为女皇
if GetModConfigData("Webber Uprade SpiderDen SpiderQueen") then
    local function OnUpgrade(inst, upgrade_doer)
        inst.SoundEmitter:PlaySound("webber2/common/spiderden_upgrade")
        if inst.components.growable:GetStage() < 3 then
            inst.AnimState:PlayAnimation(inst.anims.hit)
            inst.AnimState:PushAnimation(inst.anims.idle)
        else
            inst.AnimState:PlayAnimation(inst.anims.hit_combat)
            inst.AnimState:PushAnimation(inst.anims.idle)
            inst.components.growable:LongUpdate((inst.components.growable.targettime or 0) / 10 + 150 * (1 + 2 * math.random()))
        end
    end
    local function OnStageAdvance(inst)
        if inst.components.upgradeable.stage == 4 then
            inst.components.upgradeable.stage = 3
            if math.random() < 0.45 then inst.components.growable:DoGrowth() end
        else
            inst.components.growable:DoGrowth()
        end
        return true
    end
    local function oneat(inst, data)
        if inst.components.hunger and inst.components.upgradeable and data then
            for i = 1, 4 do
                if inst:IsValid() and inst.components.hunger then
                    if inst.components.hunger.current >= 50 then
                        inst.components.hunger:DoDelta(-50, nil, true)
                        inst.components.upgradeable.numupgrades = inst.components.upgradeable.numupgrades + 1
                        if inst.components.upgradeable.onupgradefn then
                            inst.components.upgradeable.onupgradefn(inst, data.feeder, data.food)
                        end
                        if inst.components.childspawner then
                            inst.components.childspawner:AddChildrenInside(math.random(1, 3))
                            inst.components.childspawner:SpawnChild()
                        end
                        if inst.components.upgradeable.numupgrades >= inst.components.upgradeable.upgradesperstage then
                            inst.components.upgradeable:AdvanceStage()
                        end
                    else
                        if i == 1 then
                            inst.AnimState:PlayAnimation(inst.anims.hit)
                            inst.AnimState:PushAnimation(inst.anims.idle)
                        end
                        break
                    end
                end
            end
        end
    end
    local DIET = {FOODTYPE.MEAT}
    AddPrefabPostInit("spiderden", function(inst)
        if not TheWorld.ismastersim or not inst.components.upgradeable then return end
        inst.components.upgradeable.numstages = 4
        inst.components.upgradeable.onupgradefn = OnUpgrade
        inst.components.upgradeable.onstageadvancefn = OnStageAdvance
        if hardmode and not inst.components.eater and not inst.components.hunger then
            inst.components.upgradeable.upgradetype = "none"
            inst:AddTag("handfed")
            inst:AddTag("fedbyall")
            inst:AddComponent("eater")
            inst.components.eater:SetDiet(DIET, DIET)
            inst.components.eater:SetCanEatHorrible()
            inst.components.eater:SetStrongStomach(true) -- can eat monster meat!
            inst.components.eater:SetCanEatRawMeat(true)
            inst:AddComponent("hunger")
            inst.components.hunger:SetMax(200)
            inst.components.hunger:SetKillRate(0)
            inst.components.hunger:SetRate(0)
            inst.components.hunger:Pause()
            inst.components.hunger:SetPercent(0)
            inst:StopUpdatingComponent(inst.components.hunger)
            inst:StopWallUpdatingComponent(inst.components.hunger)
            inst:ListenForEvent("oneat", oneat)
        end
    end)
end

-- 韦伯200理智(独立选项)
if GetModConfigData("Webber 200 Sanity") then
    TUNING.WEBBER_SANITY = TUNING.WILSON_SANITY
end

-- 韦伯右键加强(0关闭,1蛛网恐惧=右键自己读蛛网魔法书,2蜘蛛容器=右键自己打开3×3蜘蛛窝)
local webberrightself = GetModConfigData("Webber Right Self Overcoming Arachnophobia")
if webberrightself == 2 then
    -- 档位2:蜘蛛容器(3×3虚拟物品栏,只放蜘蛛,蜘蛛在其中缓慢恢复新鲜度)
    local containers = require("containers")
    containers.params.spiderbag2hm = {}
    containers.params.spiderbag2hm.widget = containers.params.treasurechest.widget
    containers.params.spiderbag2hm.type = "chest"
    containers.params.spiderbag2hm.itemtestfn = function(container, item, slot)
        -- 只能按 tag 判断,排除蜘蛛女王
        return container.init2hm or (item ~= nil and item:HasTag("spider") and not item:HasTag("epic"))
    end
    containers.params.spiderbag2hm.acceptsstacks = false
    local function initspiderbag(inst)
        if not (inst.spiderbag2hm and inst.spiderbag2hm:IsValid()) then
            local spiderbag = SpawnPrefab("spiderbag2hm")
            if spiderbag and spiderbag:IsValid() and spiderbag.components.container then
                if inst.components.persistent2hm.data.spiderbag then
                    spiderbag.components.container.init2hm = true
                    spiderbag:SetPersistData(inst.components.persistent2hm.data.spiderbag)
                    spiderbag.components.container.init2hm = nil
                    inst.components.persistent2hm.data.spiderbag = nil
                end
                spiderbag:AddTag("dcs2hm")
                inst.spiderbag2hm = spiderbag
                spiderbag.master2hm = inst
                spiderbag.components.container.skipautoclose = true
                spiderbag:Hide()
                inst:AddChild(spiderbag)
                spiderbag:AddTag("NOBLOCK")
                spiderbag.persists = false
            end
        end
    end
    local function OnSave(inst, data)
        data.spiderbag = InGamePlay() and (inst.spiderbag2hm and inst.spiderbag2hm:IsValid() and inst.spiderbag2hm:GetPersistData() or nil) or data.spiderbag
    end
    AddPrefabPostInit("webber", function(inst)
        if not TheWorld.ismastersim then return end
        if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
        SetOnSave2hm(inst, OnSave)
        inst:DoTaskInTime(0, initspiderbag)
    end)
    AddRightSelfAction("webber", 1, "dolongaction", nil, function(act)
        if act.doer and act.doer.prefab == "webber" and act.doer.spiderbag2hm then
            local spiderbag = act.doer.spiderbag2hm
            if spiderbag and spiderbag:IsValid() and spiderbag.components.container and act.doer == spiderbag.master2hm then
                if spiderbag.components.container.openlist[act.doer] then
                    spiderbag.components.container:Close(act.doer)
                else
                    spiderbag.components.container:Open(act.doer)
                end
                return true
            else
                act.doer:DoTaskInTime(0, initspiderbag)
            end
        end
    end, TUNING.isCh2hm and "蜘蛛容器" or "Spider Bag")
elseif webberrightself == 1 or (webberrightself and webberrightself ~= 0) then
    -- 档位1:蛛网恐惧(右键自己读蛛网魔法书)
    AddReadBookRightSelfAction("webber", "book_web", 15, STRINGS.CHARACTERS.WEBBER.ANNOUNCE_CARRAT_ERROR_WALKING)
end

-- 蜘蛛协助工作
if GetModConfigData("Spider Help Work") then
    local BrainCommon = require "brains/braincommon"
    local AssistLeaderDefaults = BrainCommon.AssistLeaderDefaults
    local CHOPparameters, MINEparameters
    AddBrainPostInit("spiderbrain", function(self)
        if self.inst:HasOneOfTags({"spider_warrior", "spider_dropper"}) then
            if hardmode and not self.inst.components.workmultiplier then
                self.inst:AddComponent("workmultiplier")
                self.inst.components.workmultiplier:AddMultiplier(ACTIONS.CHOP, 0.5, "hard2hm")
            end
            local parameters = CHOPparameters
            if parameters == nil then
                parameters = {
                    action = "CHOP" -- Required.
                }
                local Starter = AssistLeaderDefaults.CHOP.Starter
                parameters.starter = function(inst, ...) return not inst.no_targeting and Starter(inst, ...) end
                local KeepGoing = AssistLeaderDefaults.CHOP.KeepGoing
                parameters.keepgoing = function(inst, ...) return not inst.no_targeting and KeepGoing(inst, ...) end
                CHOPparameters = parameters
            end
            local CHOPaction = BrainCommon.NodeAssistLeaderDoAction(self, parameters)
            table.insert(self.bt.root.children, 4, CHOPaction)
        elseif self.inst:HasOneOfTags({"spider_hider", "spider_moon"}) then
            if hardmode and not self.inst.components.workmultiplier then
                self.inst:AddComponent("workmultiplier")
                self.inst.components.workmultiplier:AddMultiplier(ACTIONS.MINE, 0.5, "hard2hm")
            end
            local parameters = MINEparameters
            if parameters == nil then
                parameters = {
                    action = "MINE" -- Required.
                }
                local Starter = AssistLeaderDefaults.MINE.Starter
                parameters.starter = function(inst, ...) return not inst.no_targeting and Starter(inst, ...) end
                local KeepGoing = AssistLeaderDefaults.MINE.KeepGoing
                parameters.keepgoing = function(inst, ...) return not inst.no_targeting and KeepGoing(inst, ...) end
                local MINE_CANT_TAGS = getupvalue2hm(AssistLeaderDefaults.MINE.FindNew, "MINE_CANT_TAGS")
                if MINE_CANT_TAGS ~= nil then
                    local FindNew = AssistLeaderDefaults.MINE.FindNew
                    parameters.finder = function(...)
                        table.insert(MINE_CANT_TAGS, "spiderden")
                        local result = FindNew(...)
                        for i = #MINE_CANT_TAGS, 1, -1 do if MINE_CANT_TAGS[i] == "spiderden" then table.remove(MINE_CANT_TAGS, i) end end
                        return result
                    end
                end
                MINEparameters = parameters
            end
            local MINEaction = BrainCommon.NodeAssistLeaderDoAction(self, parameters)
            table.insert(self.bt.root.children, 4, MINEaction)
        end
    end)
    local function SoundPath(inst, event) return inst:SoundPath(event) end
    AddStategraphState("spider", State {
        name = "work2hm",
        tags = {"busy"},
        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("atk")
        end,
        timeline = {
            TimeEvent(10 * FRAMES, function(inst) inst.SoundEmitter:PlaySound(SoundPath(inst, "Attack")) end),
            TimeEvent(10 * FRAMES, function(inst) inst.SoundEmitter:PlaySound(SoundPath(inst, "attack_grunt")) end),
            TimeEvent(25 * FRAMES, function(inst) inst:PerformBufferedAction() end)
        },
        events = {EventHandler("animover", function(inst) inst.sg:GoToState("idle") end)}
    })
    AddStategraphActionHandler("spider", ActionHandler(ACTIONS.CHOP, "work2hm"))
    AddStategraphActionHandler("spider", ActionHandler(ACTIONS.MINE, "work2hm"))
end

-- 帽子戏法
if GetModConfigData("Hat Trick") then
    TUNING.HatTrickDropRate = 0.05
    TUNING.NoFreezePercent = 0.8
    TUNING.NoFireAndScarePercent = 0.9
    TUNING.HatReduceRate = {
        finiteuses = 0.2,
        armor = 0.1,
        fueled = 0.02,
        perishable = 0.02,
    }
    AddComponentPostInit("follower", function(self)
        local oldSetLeader = self.SetLeader
        function self:SetLeader(new_leader)
            if self.leader then
                -- print(tostring(self.leader) .. " removefollower " .. tostring(self.inst))
                self.leader:PushEvent("removefollower", {follower = self.inst})
            end
            if new_leader then
                -- print(tostring(new_leader) .. " addfollower " .. tostring(self.inst))
                new_leader:PushEvent("addfollower", {follower = self.inst})
            end
            return oldSetLeader(self, new_leader)
        end
    end)
    AddPrefabPostInit("webber", function(inst)
        if not TheWorld.ismastersim then return end
        inst:AddComponent("hattrickparent2hm")
        -- print("韦伯添加帽子戏法")
    end)
end

-- 怪物角色夜视开启时，保留韦伯的夜晚理智效果。
if GetModConfigData("Monster Night Vision") then
    AddPrefabPostInit("webber", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.sanity then inst.components.sanity.night_drain_mult = 0 end
    end)
end
