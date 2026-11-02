local hardmode = TUNING.hardmode2hm and GetModConfigData("role_nerf") and GetModConfigData("wormwood")

-- 沃姆伍德吃食物获得75%生命
if GetModConfigData("Wormwood Eat Food Normal") then
    AddPrefabPostInit("wormwood", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.eater ~= nil then inst.components.eater:SetAbsorptionModifiers(0.75, 1, 1) end
    end)
end

-- 沃姆伍德采集农作物再生
if GetModConfigData("Wormwood Regrow Farm Plant") then
    local function RegeneratePlant(inst, picker)
        if hardmode and picker.components.hunger then picker.components.hunger:DoDelta(-1.5) end
        local x, y, z = inst.Transform:GetWorldPosition()
        if TheWorld.Map:GetTileAtPoint(x, 0, z) ~= WORLD_TILES.FARMING_SOIL then return false end
        local plant = SpawnPrefab(inst.prefab)
        plant.Transform:SetPosition(x, y, z)
        if plant.plant_def ~= nil then
            plant.long_life = true
            plant.no_oversized = false
            if plant.components.farmsoildrinker then plant.components.farmsoildrinker:CopyFrom(inst.components.farmsoildrinker) end
            plant.AnimState:OverrideSymbol("veggie_seed", "farm_soil", "seed")
        end
        inst.grew_into = plant
    end
    AddComponentPostInit("pickable", function(self)
        if not self.inst:HasTag("farm_plant") then return end
        local oldPick = self.Pick
        self.Pick = function(self, picker, ...)
            if self.inst and self.remove_when_picked and picker and picker:IsValid() and picker.prefab == "wormwood" then
                if hardmode then
                    local equip = picker.components.inventory and picker.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
                    if equip and equip.prefab == "nutrientsgoggleshat" then RegeneratePlant(self.inst, picker) end
                else
                    RegeneratePlant(self.inst, picker)
                end
            end
            return oldPick(self, picker, ...)
        end
    end)
end

-- 沃姆伍德生长中安抚植物减少生长时间
if GetModConfigData("Wormwood TendTo Farm Plant Reduce Grow Time") then
    AddComponentPostInit("farmplanttendable", function(self)
        local oldTendTo = self.TendTo
        function self:TendTo(doer)
            local ans = oldTendTo(self, doer)
            if ans and doer and doer.prefab == "wormwood" then
                if doer.components.bloomness then
                    if self.inst.components.growable and self.wormwoodtendto2hm ~= self.inst.components.growable:GetStage() then
                        self.wormwoodtendto2hm = self.inst.components.growable:GetStage()
                        if self.inst.components.growable:IsGrowing() then
                            self.inst.components.growable:StartGrowing((self.inst.components.growable.targettime - GetTime()) * (1 - 0.09 * (doer.components.bloomness.level + 1)))
                        else
                            if self.inst.components.growable.pausedremaining then
                                self.inst.components.growable.pausedremaining = self.inst.components.growable.pausedremaining * (1 - 0.09 * (doer.components.bloomness.level + 1))
                            end
                        end
                        local level = doer.components.bloomness.level + 1
                        if level > 3 then
                            level = 3
                        elseif level < 3 then
                            level = 1
                        end
                        SpawnPrefab("halloween_firepuff_cold_" .. level).Transform:SetPosition(self.inst.Transform:GetWorldPosition())
                    end
                end
            end
            return ans
        end
    end)
end

if GetModConfigData("Wormwood Soul Heal Soil") then
    AddPrefabPostInit("player_soul2hm", function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("onremove", function(inst)
            if inst.prefabName and inst.prefabName == "wormwood" and inst.isDisappear2hm then
                if TheWorld.Map:IsFarmableSoilAtPoint(inst.Transform:GetWorldPosition()) then
                    local x, y, z = TheWorld.Map:GetTileCenterPoint(inst.Transform:GetWorldPosition())
                    SpawnPrefab("halloween_moonpuff").Transform:SetPosition(x, y, z)
                    for i, v in ipairs(TheSim:FindEntities(x, 0, z, 4, {"farmdock2hm"})) do
                        if v and v:IsValid() then
                            local x1, y1, z1 = TheWorld.Map:GetTileCenterPoint(v.Transform:GetWorldPosition())
                            if x == x1 and y == y1 and z == z1 then
                                v:Remove()
                            end
                        end
                    end
                    for i, v in ipairs(TheSim:FindEntities(x, 0, z, 4, {"farm_plant"})) do
                        if v and v:IsValid() then
                            local x1, y1, z1 = TheWorld.Map:GetTileCenterPoint(v.Transform:GetWorldPosition())
                            if x == x1 and y == y1 and z == z1 then
                                v.notlosewaterandsoil = true
                            end
                        end
                    end
                end
            end
        end)
    end)
end

if GetModConfigData("Wormwood Photosynthesis") then
    AddPrefabPostInit("wormwood", function(inst)
        if not TheWorld.ismastersim then return end
        local deltaSanity = 0
        inst.photosynthesistask = inst:DoPeriodicTask(5, function(inst)
            if TheWorld.state.isday and inst.components.health and not inst.components.health:IsDead() and inst.components.sanity then
                if inst.components.bloomness then
                    deltaSanity = deltaSanity + (inst.components.bloomness.level + 1) / (inst.components.bloomness.max + 1)
                    if deltaSanity >= 1 then
                        inst.components.sanity:DoDelta(deltaSanity)
                        deltaSanity = 0
                        local fx = SpawnPrefab("farm_plant_unhappy")
                        fx.entity:SetParent(inst.entity)
                    end
                end
            end
        end)
    end)
end

-- 沃姆伍德获得临时浆果帽进行躲藏,可以右键自己读园艺学
-- if false and GetModConfigData("Wormwood Right Self Horticulture Abridged") then
    -- AddReadBookRightSelfAction("Wormwood", "book_horticulture", GetModConfigData("Wormwood Right Self Horticulture Abridged"),
                               -- STRINGS.CHARACTERS.Wormwood.ACTIONFAIL.CARNIVALGAME_FEED.TOO_LATE)
-- end
if GetModConfigData("Wormwood Right Self To Hide") then
    local function rightselfstrfn2hm(act)
        return act.doer and act.doer:HasTag("hiding") and (act.doer:HasTag("sleeping") and "SLEEPOUT" or "SLEEPIN") or "WORMWOOD"
    end
    STRINGS.ACTIONS.RIGHTSELFACTION2HM.SLEEPIN = TUNING.isCh2hm and "休憩" or "Rest"
    STRINGS.ACTIONS.RIGHTSELFACTION2HM.SLEEPOUT = TUNING.isCh2hm and "苏醒" or "Wake"
    local function whenwakeup(doer)
        if doer:IsValid() and not doer:HasTag("hiding") and not doer:HasTag("playerghost") and
            not (doer.components.freezable ~= nil and doer.components.freezable:IsFrozen()) and
            not (doer.components.pinnable ~= nil and doer.components.pinnable:IsStuck()) and
            not (doer.components.fossilizable ~= nil and doer.components.fossilizable:IsFossilized()) then
            local sleeptime = TUNING.MOON_MUSHROOM_SLEEPTIME
            if doer.components.sleeper ~= nil then
                doer.components.sleeper:AddSleepiness(4, sleeptime)
            elseif doer.components.grogginess ~= nil then
                doer.components.grogginess:AddGrogginess(2, sleeptime)
            else
                doer:PushEvent("knockedout")
            end
        end
    end
    local function sleepfx(inst)
        if inst and inst:IsValid() and inst:HasTag("sleeping") then
            local fx = SpawnPrefab("fx_book_sleep")
            fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
            fx.Transform:SetRotation(inst.Transform:GetRotation())
            -- 主动睡眠,2秒后就可以右键苏醒
            Overriderightactioncd(inst, 2)
        end
    end
    local function onwake(inst, doer, ...)
        -- 被动苏醒,进入CD
        Overriderightactioncd(doer)
        if doer and doer:IsValid() then doer:DoTaskInTime(0.25, whenwakeup) end
        if inst.sleepingbag2hm then inst:DoTaskInTime(0, function() inst:RemoveComponent("sleepingbag") end) end
    end
    local function delaysleep(inst, hat)
        if hat and hat.prefab == "bushhat" and hat:IsValid() and hat.components.sleepingbag then
            hat.components.useableitem:StartUsingItem()
            hat.components.sleepingbag:DoSleep(inst)
            hat.disablestopuse2hm = nil
            if inst.sg then inst.sg:AddStateTag("sleeping") end
            inst:DoTaskInTime(1, sleepfx)
        end
    end
    AddRightSelfAction("wormwood", hardmode and 60 or 1, "dolongaction", function(inst, action)
        inst.bushhatnextaction2hm = inst and inst:HasTag("hiding") and (inst:HasTag("sleeping") and "SLEEPOUT" or "SLEEPIN")
        if inst.bushhatnextaction2hm == "SLEEPIN" or inst.bushhatnextaction2hm == "SLEEPOUT" then
            inst.rightselfaction2hm_handler = inst:HasTag("sleeping") and "hide" or "idle"
            if inst.rightselfaction2hm_fn then inst.rightselfaction2hm_fn(action) end
        else
            inst.rightselfaction2hm_handler = "dolongaction"
        end
    end, function(act)
        if act.doer and act.doer.components.inventory then
            if act.doer.bushhatnextaction2hm == "SLEEPIN" or act.doer.bushhatnextaction2hm == "SLEEPOUT" then
                local hat = act.doer.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
                if hat and hat.prefab == "bushhat" and hat:IsValid() then
                    if hat.components.sleepingbag then
                        hat.components.sleepingbag:DoWakeUp(true)
                        if act.doer.sg then act.doer.sg:RemoveStateTag("sleeping") end
                        -- 右键苏醒,进入CD
                        Overriderightactioncd(act.doer)
                    else
                        hat.sleepingbag2hm = true
                        hat:AddComponent("sleepingbag")
                        hat.components.sleepingbag.onwake = onwake
                        if not hat.setstop2hm and hat.components.useableitem then
                            hat.setstop2hm = true
                            local onstopusefn = hat.components.useableitem.onstopusefn
                            hat.components.useableitem:SetOnStopUseFn(function(inst, ...)
                                if hat.components.sleepingbag then 
									hat.components.sleepingbag:DoWakeUp(true) 
								end
                                if onstopusefn ~= nil then onstopusefn(inst, ...) end
                            end)
                        end
                        if act.doer.sg then
                            hat.disablestopuse2hm = true
                            act.doer.sg:GoToState("idle")
                            act.doer:DoTaskInTime(0, delaysleep, hat)
                        end
                    end
                    return true
                end
            else
                local hat = SpawnPrefab("bushhat")
                if hat then
                    hat.persists = false
                    if not act.doer.components.inventory:Equip(hat) then
                        hat:Remove()
                        return
                    end
                    hat.components.useableitem:StartUsingItem()
                    hat.components.useableitem:SetOnStopUseFn(function() if not hat.disablestopuse2hm then hat:DoTaskInTime(3, function(hat)
								hat:Remove()
							end)
						end
					end)
                    hat:ListenForEvent("unequipped", function(hat)
						hat:DoTaskInTime(3, function(hat)
							hat:Remove()
						end)
					end)
                    hat.components.inventoryitem:SetOnDroppedFn(function(hat)
						hat:DoTaskInTime(3, function(hat)
							hat:Remove()
						end)
					end)
                    if hardmode then hat:ListenForEvent("onremove", function() Overriderightactioncd(act.doer) end) end
                    Overriderightactioncd(act.doer, 1)
                    -- 生成的浆果帽立即就可以睡眠,但浆果帽消失后CD60秒
                    return true
                end
            end
            if act.doer.bushhatnextaction2hm then act.doer.bushhatnextaction2hm = nil end
        end
    end, STRINGS.NAMES.BUSHHAT)
    AddPrefabPostInit("wormwood", function(inst) 
		inst.rightselfstrfn2hm = rightselfstrfn2hm 
	end)
end

-- 沃姆伍德吃食物获得装备
if GetModConfigData("Wormwood Eat Rewards Equip") == 1 then
    require "prefabutil"
    local foodequips = {
		-- 2025.6.28 melon:削弱，不能吃出茄甲
		-- plantmeat = {equips = {"armor_lunarplant_husk"}}, --叶肉->荆棘茄甲
		-- plantmeat_cooked = {equips = {"armor_lunarplant_husk"}}, --烤叶肉->荆棘茄甲
		cactus_meat_cooked = {equips = {"armor_bramble"}}, --烤仙人掌->荆棘甲
		-- 2025.3.18 melon:发光浆果->鼹鼠帽
		wormlight = {chance = 1.0, equips = {"molehat"}},
		wormlight_lesser = {chance = 0.1, equips = {"molehat"}},
        guacamole = {chance = 0.5, equips = {"rainhat"}},-- 2025.4.22 melon:鳄梨酱->雨帽
		-- 2025.4.10 melon
		meat_dried = {chance = 1.0, equips = {"hambat"}},  --肉干->火腿棒
		nightmarepie = {equips = {"multitool_axe_pickaxe"}}, --恐怖国王饼->斧稿
		bonesoup = {equips = {"ruinshat"}}, --骨头汤->铥矿皇冠
		dragonpie = {equips = {"armordragonfly"}}, --火龙果派->麟甲
		jellybean = {equips = {"hivehat"}}, --糖豆->蜂王冠
		-- 2025.3.16
		cactus_flower = {equips = {"hawaiianshirt"}}, --仙人掌花->花衬衫
		trunk_summer = {chance = 1.0, equips = {"trunkvest_summer"}},--象鼻->象鼻衣
		trunk_cooked = {chance = 1.0, equips = {"trunkvest_summer"}},--熟象鼻->象鼻衣
		trunk_winter = {chance = 1.0, equips = {"trunkvest_winter"}},--冬象鼻->冬象衣(没有烤冬象鼻?)
		-- 
		berries = {chance = 0.5, equips = {"bushhat"}},
		berries_juicy = {chance = 0.5, equips = {"bushhat"}},
		seeds = {equips = {"plantregistryhat", "nutrientsgoggleshat"}},
		fish = {equips = {"mermhat"}},
		froglegs = {equips = {"mermhat"}},
		drumstick = {equips = {"featherhat"}},
		meat = {equips = {"footballhat"}},
		batnose = {chance = 0.05, equips = {"batnosehat"}},
		goatmilk = {chance = 0.15, equips = {"batnosehat"}},
		cutlichen = {equips = {"skeletonhat", "armorskeleton"}},
		tillweed = {equips = {"armormarble"}},
		forgetmelots = {equips = {"hivehat", "flowerhat"}},
		firenettles = {equips = {"armordragonfly"}},
		petals = {equips = {"flowerhat"}},
		kelp = {equips = {"kelphat"}},
		red_cap = {equips = {"red_mushroomhat", "spore_medium"}},
		green_cap = {equips = {"green_mushroomhat", "spore_small"}},
		blue_cap = {equips = {"blue_mushroomhat", "spore_tall"}},
		moon_cap = {equips = {"alterguardianhat"}},
		watermelon = {equips = {"watermelonhat"}},
		lightbulb = {equips = {"minerhat"}},
		carrot = {equips = {"armor_carrotlure"}},
		butterflywings = {equips = {"cane"}},
		goatmilk = {equips = {"batnosehat"}},
		milkywhites = {equips = {"batnosehat"}},
		cactus_meat = {equips = {"armor_bramble"}},
		honey = {equips = {"beehat"}},
		royal_jelly = {chance = 0.5, equips = {"hivehat"}},
		rock_avocado_fruit_ripe = {chance = 0.15, equips = {"alterguardianhat", "armormarble"}}
    }
    local function onremove(inst)
        if inst.components.inventory ~= nil then inst.components.inventory:DropEverything() end
        if inst.components.container ~= nil then inst.components.container:DropEverything() end
    end
    local function delayremove(inst) inst:DoTaskInTime(0, inst.Remove) end
    local function itemget(inst, data)
        if data and data.item and data.item:IsValid() then
            if not data.item.persists then
                data.item:DoTaskInTime(0, data.item.Remove)
            else
                data.item.persists = false
            end
        end
    end
    local function itemlose(inst, data) if data and data.prev_item and data.prev_item:IsValid() then data.prev_item.persists = true end end
    local function PercentChanged2hm(inst, data) -- 2025.5.26 melon:增加损坏掉落
        if inst.components.armor ~= nil and data.percent ~= nil then
            if data.percent <= 0 and inst.components.container ~= nil then
                -- inst.components.container:DropEverything() -- 掉落所有
                local owner = inst.components.inventoryitem ~= nil and inst.components.inventoryitem.owner or nil
                if owner and owner.components.inventory then
                    for slot = 1, inst.components.container:GetNumSlots() do
                        local item = inst.components.container:GetItemInSlot(slot) -- 获取槽位中的物品
                        if item then
                            inst.components.container:DropItemBySlot(slot) -- 掉落
                            owner.components.inventory:GiveItem(item) -- 给玩家
                        end
                    end
                end
            end
        end
    end
    local function givewormwooditem(inst, prefab, onlyequip)
        if not prefab then return end
        if TUNING.noalterguardianhat2hm and prefab == "alterguardianhat" then return end
        local equip = SpawnPrefab(prefab)
        if equip then
            if not equip.components.equippable then
                if onlyequip ~= true and equip.components.inventoryitem and equip:HasTag("spore") then
                    inst.components.inventory:GiveItem(equip)
                else
                    equip:Remove()
                end
                return
            end
            local oldequip = inst.components.inventory:GetEquippedItem(equip.components.equippable.equipslot)
            -- if oldequip and not oldequip.persists and equip.fromwormwoodeat2hm then
            if oldequip then
                -- if equip.prefab == oldequip.prefab then
                --     oldequip:Remove()
                -- else
                equip:Remove()
                return
                -- end
            end
            equip.persists = false
            equip.fromwormwoodeat2hm = true
            if not inst.components.inventory:Equip(equip) then
                equip:Remove()
                return
            end
            equip:ListenForEvent("onremove", onremove)
            equip:ListenForEvent("unequipped", delayremove)
            equip.components.inventoryitem:SetOnDroppedFn(delayremove)
            if equip.prefab == "alterguardianhat" and not equip.components.armor then
                equip:AddComponent("armor")
                equip.components.armor:InitCondition(TUNING.ARMORGRASS, TUNING.ARMOR_SKELETONHAT_ABSORPTION)
                equip:RemoveEventCallback("onattackother", equip.alterguardian_spawngestalt_fn, inst)
                equip.alterguardian_spawngestalt_fn = nilfn
                equip:ListenForEvent("onattackother", equip.alterguardian_spawngestalt_fn, inst)
                -- 2025.5.26 melon:增加损坏掉落
                equip:ListenForEvent("percentusedchange", PercentChanged2hm)
                -- 2025.6.28 melon:开新界时临时头去掉4,5本科技。二本、船科技不去掉
                if inst.components.builder then
                    inst.components.builder["magic_tempbonus"] = nil -- 4本
                    inst.components.builder["ancient_tempbonus"] = nil -- 整塔
                end
            end
            if equip.prefab == "skeletonhat" and inst.components.sanity then
                if equip.components.armor then equip.components.armor:SetKeepOnFinished(false) end
                inst.components.sanity:SetInducedInsanity(equip, false)
            end
            -- 容器管理
            if equip.components.container then
                equip:ListenForEvent("itemget", itemget)
                equip:ListenForEvent("itemlose", itemlose)
            end
            return equip
        end
    end
    local function oneat(inst, data)
        if data and data.food then
            if data.food.components.edible and data.food.components.edible.foodtype ~= FOODTYPE.MEAT and inst.components.inventory then
                local seed_name = string.lower(data.food.prefab .. "_seeds")
                if PrefabExists(seed_name) and math.random() < 0.25 then inst.components.inventory:GiveItem(SpawnPrefab(seed_name)) end
            end
            local prefab = data.food.prefab
            if data.food:HasTag("deployedfarmplant") then prefab = "seeds" end
            if not (foodequips[prefab] and foodequips[prefab].equips) then return end
            local chance = foodequips[prefab].chance or 0.25
            if not inst.components.persistent2hm.data.tempchance then inst.components.persistent2hm.data.tempchance = {} end
            local tempchance = inst.components.persistent2hm.data.tempchance
            tempchance[prefab] = tempchance[prefab] or chance
            if math.random() < tempchance[prefab] and givewormwooditem(inst, foodequips[prefab].equips[math.random(#foodequips[prefab].equips)], nil) then
                tempchance[prefab] = nil
            else
                tempchance[prefab] = tempchance[prefab] + chance / 2
            end
        end
    end
    local function OnSave(inst, data)
        if inst.components.inventory and data then
            data.saveequips = {}
            for k, v in pairs(inst.components.inventory.equipslots) do
                if v and v:IsValid() and not v.persists and v.fromwormwoodeat2hm and v.prefab then
                    -- 容器管理
                    if v.components.container then
                        for i = 1, v.components.container.numslots do
                            local item = v.components.container.slots[i]
                            if item and item:IsValid() then item.persists = true end
                        end
                    end
                    local record, references = v:GetPersistData()
                    data.saveequips[v.prefab] = record or true
                    if v.components.container then
                        for i = 1, v.components.container.numslots do
                            local item = v.components.container.slots[i]
                            if item and item:IsValid() then item.persists = false end
                        end
                    end
                    -- break -- 2025.5.26 melon:注释掉，这样可存多个装备
                end
            end
        end
    end
    local function initsaveequips(inst)
        if inst.components.inventory and inst.components.persistent2hm and inst.components.persistent2hm.data.saveequips then
            for prefab, record in pairs(inst.components.persistent2hm.data.saveequips) do
                local item = givewormwooditem(inst, prefab, true)
                if item and record ~= true then item:SetPersistData(record) end
            end
        end
    end
    -- local function delayinitsaveequips(inst) inst:DoTaskInTime(0, initsaveequips) end
    AddPrefabPostInit("wormwood", function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("oneat", oneat)
        if inst.components.persistent2hm == nil then inst:AddComponent("persistent2hm") end
        SetOnSave2hm(inst, OnSave)
        SetOnLoad2hm(inst, initsaveequips)
    end)

    -- 胡萝卜外套削弱
    if hardmode then
        AddPrefabPostInit("armor_carrotlure", function(inst)
        if not TheWorld.ismastersim then return end
            if inst.components.equippable then
                local onequipfn = inst.components.equippable.onequipfn
                inst.components.equippable.onequipfn = function(inst, owner, ...)
                    onequipfn(inst, owner, ...)
                    if inst.carrotluretask and inst.carrotluretask.fn then
                        local oldfn = inst.carrotluretask.fn
                        inst.carrotluretask.fn = function(inst)
                            local owner = inst.components.inventoryitem and inst.components.inventoryitem.owner or nil
                            oldfn(inst)
                            if owner and owner:HasTag("player") and owner.components.leader and owner.components.hunger then
                                local currentfollowers = owner.components.leader:GetFollowersByTag("regular_bunnyman")
                                local notshadowfollowers = {}
                                for i, v in pairs(currentfollowers) do
                                    if v and not v:HasTag("swc2hm") then table.insert(notshadowfollowers,v) end
                                end
                                local currentfollowerscount = #notshadowfollowers
                                owner.components.hunger.burnratemodifiers:SetModifier("armor_carrotlure2hm", 1 + (0.2 * currentfollowerscount))
                            end
                        end
                    end
                end
                local oldonunequipfn = inst.components.equippable.onunequipfn
                inst.components.equippable.onunequipfn = function(inst, owner, ...)
                    oldonunequipfn(inst, owner, ...)
                    if owner and owner:HasTag("player") and owner.components.hunger then
                        owner.components.hunger.burnratemodifiers:RemoveModifier("armor_carrotlure2hm")
                    end 
                end
            end
        end)
    end
end
if true then
    require "prefabutil"
    local foodequips = {
        -- 头部
        cookedmeat = {equips = {"footballhat"}},                -- 猪皮头盔
        seeds_cooked = {equips = {"nutrientsgoggleshat"}},      -- 耕作帽
        lightbulb = {equips = {"minerhat"}},                    -- 矿工帽
        wormlight_lesser = {equips = {"molehat"}},              -- 鼹鼠帽
        red_cap_cooked = {equips = {"red_mushroomhat"}},        -- 红蘑菇帽
        green_cap_cooked = {equips = {"green_mushroomhat"}},    -- 绿蘑菇帽
        blue_cap_cooked = {equips = {"blue_mushroomhat"}},      -- 蓝蘑菇帽
        moon_cap_cooked = {equips = {"moon_mushroomhat"}},      -- 月亮蘑菇帽
        moonbutterflywings = {equips = {"alterguardianhat"}},   -- 启迪之冠
        -- 手部
        moon_tree_blossom = {equips = {"moonglassaxe"}},        -- 月光玻璃斧
        batwing_cooked = {equips = {"batbat"}},                 -- 蝙蝠棒
        cookedmonstermeat = {equips = {"tentaclespike"}},       -- 触手尖刺   
        goatmilk = {equips = {"nightstick"}},          -- 晨星     
        -- milkywhites = {equips = {"shieldofterror"}},            -- 恐怖盾牌
        butterflywings = {equips = {"cane"}},                   -- 手杖
        -- 身体
        potato_cooked = {equips = {"armormarble"}},             -- 大理石甲
        dragonfruit_cooked = {equips = {"armordragonfly"}},     -- 火龙甲
        cutlichen = {equips = {"armorskeleton"}},               -- 骨甲
        cactus_meat_cooked = {equips = {"armor_bramble"}},      -- 荆棘甲
        fishmeat_small_cooked = {equips = {"raincoat"}},        -- 雨衣
        froglegs_cooked = {equips = {"raincoat"}},              -- 雨衣     
        
    }
    -- 变为临时装备
    local function processequip(inst, data)

        if not inst.components.tempequip2hm then
            inst:AddComponent("tempequip2hm")
        end

        inst.components.tempequip2hm.perishtime = TUNING.TOTAL_DAY_TIME * 6
        inst.components.tempequip2hm.remainingtime2hm = TUNING.TOTAL_DAY_TIME * 6

        if data and data.remainingtime2hm then
            inst.components.tempequip2hm.remainingtime2hm = data.remainingtime2hm
        end
        if inst.components.persistent2hm then
            inst.components.persistent2hm.data.food_equip = true -- 标记为食物装备
        end
        inst.components.tempequip2hm:BecomePerishable()

        -- 武器和工具隐藏耐久，拦截耐久消耗转为新鲜度消耗
        if inst.components.finiteuses then
            inst:AddTag("hide_percentage") 
            
            local old_Use = inst.components.finiteuses.Use
            inst.components.finiteuses.Use = function(self, amount, ...)

                -- 如果是临时装备，拦截耐久消耗，改为消耗新鲜度
                if inst.components.tempequip2hm and inst.components.perishable then
                    local loss = (amount or 1) * 0.007  -- 每次使用消耗0.7%新鲜度
                    inst.components.perishable:ReducePercent(loss)
                    return
                end
                
                return old_Use(self, amount, ...)
            end
        end

        -- 护甲额外损耗（兼容原版平摊机制）
        if inst.components.armor then
            inst:AddTag("hide_percentage")
            local absorb_percent = inst.components.armor.absorb_percent 
            local maxcondition = inst.components.armor.maxcondition
            
            -- 将护甲设为不可摧毁，禁用标准耐久度系统
            inst.components.armor:InitIndestructible(absorb_percent)
            
            -- 恐怖盾牌捉虫子等特殊工具行为
            if inst.components.armor.OnUsedAsItem then
                local old_OnUsedAsItem = inst.components.armor.OnUsedAsItem
                inst.components.armor.OnUsedAsItem = function(self, action, doer, target)
                    if inst.components.tempequip2hm and inst.components.perishable then

                        if action == ACTIONS.NET then
                            inst.components.perishable:ReducePercent(0.03)
                            return
                        end
                    end
                    return old_OnUsedAsItem(self, action, doer, target)
                end
            end
            
            -- 原版护甲平摊逻辑在ApplyDamage中计算，我们需要根据实际吸收的伤害来扣除新鲜度
            inst._onattacked_tempequip = function(owner, data)
                if not inst.components.perishable then return end
                if not data then return end
                if not owner or not owner.components.inventory then return end
                
                local original_damage = data.original_damage or data.damage or 0
                if original_damage <= 0 then return end
                
                -- 收集所有护甲的吸收率（包括原版和临时）
                local absorbers = {}
                local total_absorption = 0
                
                for k, v in pairs(owner.components.inventory.equipslots) do
                    if v and v.components.armor then
                        local absorption = v.components.armor:GetAbsorption(data.attacker, data.weapon)
                        if absorption and absorption > 0 then
                            if not v.components.armor:IsIndestructible() then
                                -- 原版护甲也要计入总吸收率
                                absorbers[v] = {
                                    absorption = absorption,
                                    maxcondition = v.components.armor.maxcondition,
                                    is_temp = false
                                }
                                total_absorption = total_absorption + absorption
                            elseif v.components.perishable then
                                -- 临时护甲
                                absorbers[v] = {
                                    absorption = absorption,
                                    maxcondition = v.components.armor.maxcondition,
                                    is_temp = true
                                }
                                total_absorption = total_absorption + absorption
                            end
                        end
                    end
                end
                
                if total_absorption <= 0 then return end
                
                -- 计算最大吸收率（用于确定实际吸收的伤害）
                local max_absorb_percent = 0
                for v, info in pairs(absorbers) do
                    if info.absorption > max_absorb_percent then
                        max_absorb_percent = info.absorption
                    end
                end
                
                -- 被护甲吸收的总伤害
                local absorbed_damage = original_damage * max_absorb_percent
                
                -- 本护甲承受的额外伤害
                local bonus_damage = 0
                if data.attacker and inst.components.armor then
                    bonus_damage = inst.components.armor:GetBonusDamage(data.attacker, data.weapon) or 0
                end
                
                -- 本护甲承受的伤害（按比例平摊）
                local my_info = absorbers[inst]
                if not my_info then return end
                
                local my_absorption = my_info.absorption
                local armor_damage = absorbed_damage * (my_absorption / total_absorption) + bonus_damage
                
                -- 转换为新鲜度损失百分比
                local freshness_loss = armor_damage / maxcondition
                inst.components.perishable:ReducePercent(freshness_loss)
            end
            
            local old_onequip = inst.components.equippable.onequipfn
            inst.components.equippable:SetOnEquip(function(inst, owner)
                if old_onequip then
                    old_onequip(inst, owner)
                end
                inst:ListenForEvent("attacked", inst._onattacked_tempequip, owner)
            end)
            
            local old_onunequip = inst.components.equippable.onunequipfn
            inst.components.equippable:SetOnUnequip(function(inst, owner)
                if old_onunequip then
                    old_onunequip(inst, owner)
                end
                inst:RemoveEventCallback("attacked", inst._onattacked_tempequip, owner)
            end)
        end
    end

    local all_equip_prefabs = {}
    for food, config in pairs(foodequips) do
        if config.equips then
            for _, equip in ipairs(config.equips) do
                if not table.contains(all_equip_prefabs, equip) then
                    table.insert(all_equip_prefabs, equip)
                end
            end
        end
    end

    for _, prefab_name in ipairs(all_equip_prefabs) do
        AddPrefabPostInit(prefab_name, function(inst)
            if not TheWorld.ismastersim then return end
            
            if not inst.components.persistent2hm then
                inst:AddComponent("persistent2hm")
            end

            inst.components.persistent2hm.data.id = inst.GUID

            local function OnSave(inst, data) 
                if inst.components.tempequip2hm and inst.components.perishable then
                    data.remainingtime2hm = inst.components.perishable.perishremainingtime
                end
            end
            
            local function OnLoad(inst, data) 
                if data and data.remainingtime2hm and data.food_equip and not data.treasure_equip then
                    processequip(inst, data)
                end
            end
            
            SetOnSave2hm(inst, OnSave)
            SetOnLoad2hm(inst, OnLoad)
        end)
    end

    -- 吃食物获取装备
    local function onunequip_2(inst,data)
        inst:DoTaskInTime(0, function()
            local builder = data.owner.components.builder
            if builder then
                builder["magic_tempbonus"] = nil -- 4本
                builder["ancient_tempbonus"] = nil -- 整塔
            end
        end)
    end

    local function oneat(inst, data)
        if data and data.food then
            local prefab = data.food.prefab
            if not (foodequips[prefab] and foodequips[prefab].equips) then return end
            local persistentdata = inst.components.persistent2hm.data
            if hardmode and (persistentdata.equipcd or 0) > TheWorld.state.cycles + 1 then 
                if inst.components.talker then
                    inst.components.talker:Say((TUNING.isCh2hm and "今天已经吃过了" or "Have already eaten today"))
                end
                return 
            end
            
            -- 随机选择一个装备
            local selected_equip = foodequips[prefab].equips[math.random(#foodequips[prefab].equips)]
            local item = SpawnPrefab(selected_equip)
            if item then
                -- 处理为临时装备
                processequip(item, nil)
                
                if inst and inst.components.inventory then
                    inst.components.inventory:GiveItem(item, nil, inst:GetPosition())
                else
                    item.Transform:SetPosition(inst.Transform:GetWorldPosition())
                end
                persistentdata.equipcd = math.max(persistentdata.equipcd or 0, TheWorld.state.cycles) + 0.6 -- 每天限1次
                item:ListenForEvent("equipped",onunequip_2)
            end
        end
    end

    -- 让原版护甲和临时护甲能正确平摊
    AddComponentPostInit("inventory", function(self)
        local old_ApplyDamage = self.ApplyDamage
        self.ApplyDamage = function(self, damage, attacker, weapon, spdamage)
            -- 先收集所有护甲（包括临时和原版）
            local all_absorbers = {}
            local total_absorption = 0
            local has_temp_armor = false
            
            for k, v in pairs(self.equipslots) do
                if v and v.components.armor then
                    local absorption = v.components.armor:GetAbsorption(attacker, weapon)
                    if absorption and absorption > 0 then
                        if v.components.armor:IsIndestructible() and v.components.perishable then
                            -- 临时护甲
                            has_temp_armor = true
                            all_absorbers[v] = {
                                absorption = absorption,
                                is_temp = true
                            }
                            total_absorption = total_absorption + absorption
                        elseif not v.components.armor:IsIndestructible() then
                            -- 原版护甲
                            all_absorbers[v] = {
                                absorption = absorption,
                                is_temp = false
                            }
                            total_absorption = total_absorption + absorption
                        end
                    end
                end
            end
            
            -- 如果有临时护甲和原版护甲混搭，需要修改原版护甲的耐久损耗
            if has_temp_armor and total_absorption > 0 then
                local old_TakeDamages = {}
                for armor, info in pairs(all_absorbers) do
                    if not info.is_temp and armor.components.armor then
                        local old_TakeDamage = armor.components.armor.TakeDamage
                        old_TakeDamages[armor] = old_TakeDamage
                        
                        -- 计算这个护甲的平摊比例
                        local armor_ratio = info.absorption / total_absorption
                        
                        armor.components.armor.TakeDamage = function(self, damage_amount, ...)
                            -- 按平摊比例调整伤害
                            local adjusted_damage = damage_amount * armor_ratio
                            return old_TakeDamage(self, adjusted_damage, ...)
                        end
                    end
                end
                
                local result1, result2 = old_ApplyDamage(self, damage, attacker, weapon, spdamage)
                
                for armor, old_TakeDamage in pairs(old_TakeDamages) do
                    if armor and armor.components.armor then
                        armor.components.armor.TakeDamage = old_TakeDamage
                    end
                end
                
                return result1, result2
            else
                return old_ApplyDamage(self, damage, attacker, weapon, spdamage)
            end
        end
    end)

    -- 应用给沃姆伍德
    AddPrefabPostInit("wormwood", function(inst)
        if not TheWorld.ismastersim then return end
        if not inst.components.persistent2hm then
            inst:AddComponent("persistent2hm")
        end
        if GetModConfigData("Wormwood Eat Rewards Equip") == 2 then
            inst:ListenForEvent("oneat", oneat)
        end
    end)

    -- 恐怖盾牌喂食恢复新鲜度（临时装备）
    AddPrefabPostInit("shieldofterror", function(inst)
        if not TheWorld.ismastersim then return end
        
        -- 检查是否为临时装备，如果是则添加喂食恢复新鲜度功能
        local function check_and_add_feeding(inst)
            if inst.components.tempequip2hm and inst.components.perishable and inst.components.eater then
                local old_oneatfn = inst.components.eater.oneatfn
                inst.components.eater.oneatfn = function(inst, food)
                    -- 先执行原有的喂食逻辑（恢复耐久）
                    if old_oneatfn then
                        old_oneatfn(inst, food)
                    end
                    
                    -- 计算食物营养值(同永不妥协计算公式)
                    local health = food.components.edible:GetHealth(inst) * inst.components.eater.healthabsorption
                    local hunger = food.components.edible:GetHunger(inst) * inst.components.eater.hungerabsorption
                    
                    if health < 0 then
                        health = food.components.edible:GetHealth(inst)
                    end
                    
                    if hunger < 0 then
                        hunger = food.components.edible:GetHunger(inst)
                    end
                    
                    if (health + hunger) < 0 then
                        health = 0
                        hunger = 0
                    end
                    
                    -- 恢复新鲜度，根据食物营养价值
                    if health + hunger > 0 and inst.components.perishable then
                        local freshness_restore = (health + hunger) / inst.components.armor.maxcondition -- 将营养值转换为新鲜度恢复比例
                        inst.components.perishable:SetPercent(math.min(1, inst.components.perishable:GetPercent() + freshness_restore))
                    end
                end
            end
            
            -- 恐怖盾牌作为武器攻击时的新鲜度消耗
            if inst.components.tempequip2hm and inst.components.perishable and inst.components.armor then
                local old_weaponused_callback = inst._weaponused_callback
                inst._weaponused_callback = function(owner, data)
                    if data.weapon ~= nil and data.weapon == inst then
                        -- 原版调用的armor:TakeDamage已经是Indestructible，改为消耗新鲜度
                        local weapon_damage = TUNING.SHIELDOFTERROR_USEDAMAGE or 2 -- 武器使用损耗
                        local freshness_loss = weapon_damage / inst.components.armor.maxcondition
                        inst.components.perishable:ReducePercent(freshness_loss)
                    end
                end
                
                -- 如果已经装备了，需要重新监听事件
                if inst.components.inventoryitem and inst.components.inventoryitem.owner then
                    local owner = inst.components.inventoryitem.owner
                    owner:RemoveEventCallback("onattackother", old_weaponused_callback)
                    owner:ListenForEvent("onattackother", inst._weaponused_callback)
                end
            end
        end
        
        inst:DoTaskInTime(0, check_and_add_feeding)
    end)
end

-- 沃姆伍德吃种子果蔬杂草获得BUFF --2025.4.10 melon:仅保留辣椒和蒜
if GetModConfigData("Wormwood Eat Seeds Debuff") then
    -- 定义添加增益效果的函数
    local function addBuff(inst, buff, hunger)
        local hungerDelta = 0
        if inst.components.debuffable and inst.components.debuffable:GetDebuff(buff) and inst.components.hunger then
            hungerDelta = hunger and hunger / 4 or -5
        elseif inst.components.hunger then
            hungerDelta = hunger or -20
        end
        if inst.components.hunger then
            inst.components.hunger:DoDelta(hungerDelta)
        end
        inst:AddDebuff(buff, buff)
    end
    -- -- 定义杂草列表
    -- local weeds = {"tillweed", "forgetmelots", "firenettles"}
    -- -- 定义随机增益效果列表
    -- local randombuffs = {
    --     "buff_playerabsorption",
    --     "buff_workeffectiveness",
    --     "buff_attack",
	-- 	 "buff_moistureimmunity",
    --     "buff_sleepresistance",
    --     "buff_shadowdominance2hm"
    -- }
    -- 定义语音提示函数
    local function saySpeech(inst, chineseText, englishText)
        inst.components.talker:Say((TUNING.isCh2hm and chineseText or englishText))
    end
    -- -- 定义增益效果处理函数表
    -- local debuffs = {
    --     tillweed = function(inst)
    --         saySpeech(inst, "唔,实实的", "Oh,heavy")
    --         addBuff(inst, "buff_heavybody2hm")
    --     end,
    --     forgetmelots = function(inst)
    --         saySpeech(inst, "唔,爽爽的", "Oh,nice")
    --         addBuff(inst, "buff_sanitynegaura2hm")
    --     end,
    --     firenettles = function(inst)
    --         saySpeech(inst, "唔,火辣辣", "Oh,hot")
    --         addBuff(inst, "buff_fireabsorption2hm")
    --     end,
    --     speedup = function(inst)
    --         saySpeech(inst, "哇唔", "Wow")
    --         addBuff(inst, "buff_shortspeedup2hm", -10)
    --     end,
    --     random = function(inst)
    --         saySpeech(inst, "唔,神秘力量", "Oh,secret power")
    --         addBuff(inst, randombuffs[math.random(#randombuffs)])
    --     end
    -- }
    -- 定义食物食用事件处理函数
    local function oneat(inst, data)
        if data and data.food and data.food.components.edible and inst.components.talker then
            local foodPrefab = data.food.prefab
            local foodType = data.food.components.edible.foodtype

            if (foodPrefab == "pepper" or foodPrefab == "pepper_cooked") and math.random() < 0.2 then
            -- if table.contains(weeds, foodPrefab) and debuffs[foodPrefab] and math.random() < 0.75 then
            --     debuffs[foodPrefab](inst)
            -- -- elseif foodPrefab == "pepper" and math.random() < 0.2 then
                saySpeech(inst, "唔,神秘力量", "Oh,secret power")
                addBuff(inst, "buff_attack") -- 增伤
            elseif (foodPrefab == "garlic" or foodPrefab == "garlic_cooked") and math.random() < 0.2 then
                saySpeech(inst, "唔,神秘力量", "Oh,secret power")
                addBuff(inst, "buff_playerabsorption") -- 吸收伤害
            elseif foodPrefab == "honey" and math.random() < 0.2 then
                saySpeech(inst, "唔,神秘力量", "Oh,secret power")
                addBuff(inst, "buff_workeffectiveness") -- 工作效率
            elseif foodPrefab == "rock_avocado_fruit" and math.random() < 0.2 then
                saySpeech(inst, "唔,神秘力量", "Oh,secret power")
                addBuff(inst, "buff_sleepresistance") -- 睡眠抵抗
            -- elseif foodPrefab == "cutlichen" and math.random() < 0.1 then
            --     saySpeech(inst, "唔,神秘力量", "Oh,secret power")
            --     addBuff(inst, "buff_shadowdominance2hm")
            -- elseif foodType == FOODTYPE.SEEDS and math.random() < 0.3 then
            --     debuffs.speedup(inst)
            -- elseif foodType == FOODTYPE.SEEDS and math.random() < 0.05 then
            --     debuffs.random(inst)
            -- elseif foodType == FOODTYPE.VEGGIE and math.random() < 0.2 then
            --     debuffs.speedup(inst)
            -- elseif foodType == FOODTYPE.VEGGIE and math.random() < 0.05 then
            --     debuffs.random(inst)
            end
        end
    end

    -- 对“wormwood”预制体进行初始化后处理
    AddPrefabPostInit("wormwood", function(inst)
        if not TheWorld.ismastersim then return end
        inst.stophungeroverflowspeech2hm = true
        inst:ListenForEvent("oneat", oneat)
    end)
end --2025.4.10 end

-- 沃姆伍德刺针旋花
if GetModConfigData("Wormwood Thorns Generate Spiny Bindweed") then
    local function GetSpawnPoint(pt)
        if not TheWorld.Map:IsAboveGroundAtPoint(pt:Get()) then pt = FindNearbyLand(pt, 1) or pt end
        local offset = FindWalkableOffset(pt, math.random() * 2 * PI, 5, 12, true, true, NoHoles2hm)
        if offset ~= nil then
            offset.x = offset.x + pt.x
            offset.z = offset.z + pt.z
            return offset
        end
    end
    local function growweed_ivy(inst)
        if math.random() < 0.25 then
            local pt = inst:GetPosition()
            local spawn_pt = GetSpawnPoint(pt)
            local weed_ivy = SpawnPrefab("weed_ivy")
            weed_ivy.Transform:SetPosition(spawn_pt:Get())
        end
    end
    AddPrefabPostInit("wormwood", function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("thorns", growweed_ivy)
    end)
end

-- 2025.3.16 melon：荆棘甲反伤34且每次攻击都反伤    (沃姆伍德wormwood)
if GetModConfigData("armor_bramble damage") then
    TUNING.ARMORBRAMBLE_DMG = 34 -- 荆棘甲反伤
    -- TUNING.ARMORBRAMBLE_DMG_PLANAR_UPGRADE = 16 -- 2025.5.31 melon:荆棘茄甲位面反伤 加荆棘的34=50
    TUNING.TRAP_BRAMBLE_DAMAGE = 60 -- 荆棘陷阱伤害
    -- TUNING.WORMWOOD_ARMOR_BRAMBLE_RELEASE_SPIKES_HITCOUNT = 1  --累计1次触发荆棘

    -- 2025.8.17 melon:荆棘甲不反伤牛/鹿/玩家----------------------
    local NO_TAGS_NO_PLAYERS =	{ "bramble_resistant", "INLIMBO", "notarget", "noattack", "flight", "invisible", "wall", "player", "companion", "beefalo", "deer" } -- 增加牛、鹿
    AddPrefabPostInit("bramblefx_armor", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.updatelooper then
            for _, func in ipairs(inst.components.updatelooper.onupdatefns) do
                if UpvalueHacker.GetUpvalue(func, "NO_TAGS_NO_PLAYERS") then
                    UpvalueHacker.SetUpvalue(func, NO_TAGS_NO_PLAYERS, "NO_TAGS_NO_PLAYERS")
                end
                if UpvalueHacker.GetUpvalue(func, "NO_TAGS") then -- 都搞一样，避免打到跳劈
                    UpvalueHacker.SetUpvalue(func, NO_TAGS_NO_PLAYERS, "NO_TAGS")
                end
            end
        end
    end)
end  -- 2025.3.16 end

-- 植物人吃东西2秒后给自己灭火
if GetModConfigData("wormwood_eat_fire") then
    if TUNING.WORMWOOD_FIRE_DAMAGE > 1.25 then TUNING.WORMWOOD_FIRE_DAMAGE = TUNING.WORMWOOD_FIRE_DAMAGE - 0.25 end
    TUNING.WORMWOOD_BURN_TIME = TUNING.PLAYER_BURN_TIME
    local function oneat_burnable(inst, data)
        inst:DoTaskInTime(2, function(inst)
            if inst.components.burnable then inst.components.burnable:Extinguish() end
        end)
    end
    AddPrefabPostInit("wormwood", function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("oneat", oneat_burnable)
        inst.oneat_burnabletask2hm = oneat_burnable
    end)
end
