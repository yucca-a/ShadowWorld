require("componentactions")
-- 动作组件检测防止崩溃
if EntityScript then
    local component_actions = getupvalue2hm(EntityScript.CollectActions, "COMPONENT_ACTIONS")
    local scene_actions = component_actions and component_actions.SCENE
    local collect_construction = scene_actions and scene_actions.constructionsite
    if collect_construction then
        scene_actions.constructionsite = function(inst, ...)
            -- 建造动作可能已注册，但客户端还读不到建造点副本。
            -- 仅跳过本次建造动作收集，副本可用后仍由原生逻辑判断。
            if inst.replica.constructionsite ~= nil then
                return collect_construction(inst, ...)
            end
        end
    end

    local UnregisterComponentActions = EntityScript.UnregisterComponentActions
    local HasActionComponent = EntityScript.HasActionComponent
    local MOD_ACTION_COMPONENT_IDS = getupvalue2hm(EntityScript.RegisterComponentActions, "MOD_ACTION_COMPONENT_IDS")
    if MOD_ACTION_COMPONENT_IDS == nil then
        local CheckModComponentIds = getupvalue2hm(UnregisterComponentActions, "CheckModComponentIds") or
                                         getupvalue2hm(HasActionComponent, "CheckModComponentIds")
        MOD_ACTION_COMPONENT_IDS = CheckModComponentIds and getupvalue2hm(CheckModComponentIds, "MOD_ACTION_COMPONENT_IDS")
    end
    if MOD_ACTION_COMPONENT_IDS then
        EntityScript.UnregisterComponentActions = function(self, name, ...)
            local modactioncomponents = self.modactioncomponents
            self.modactioncomponents = nil
            UnregisterComponentActions(self, name, ...)
            self.modactioncomponents = modactioncomponents
            if self.modactioncomponents ~= nil then
                for modname, cmplist in pairs(self.modactioncomponents) do
                    local id = MOD_ACTION_COMPONENT_IDS[modname] and MOD_ACTION_COMPONENT_IDS[modname][name]
                    if id ~= nil then
                        for i, v in ipairs(cmplist) do
                            if v == id then
                                table.remove(cmplist, i)
                                if self.actionreplica ~= nil then self.actionreplica.modactioncomponents[modname]:set(cmplist) end
                                break
                            end
                        end
                    end
                end
            end
        end
        EntityScript.HasActionComponent = function(self, name, ...)
            local modactioncomponents = self.modactioncomponents
            self.modactioncomponents = nil
            local result = HasActionComponent(self, name, ...)
            self.modactioncomponents = modactioncomponents
            if result then return true end
            if self.modactioncomponents ~= nil then
                for modname, cmplist in pairs(self.modactioncomponents) do
                    local id = MOD_ACTION_COMPONENT_IDS[modname] and MOD_ACTION_COMPONENT_IDS[modname][name]
                    if id ~= nil then for i, v in ipairs(cmplist) do if v == id then return true end end end
                end
            end
            return false
        end
    end
end
-- 终极修复 replica 补丁
AddPrefabPostInit("world", function(inst)
    local ValidateReplicaComponent = EntityScript.ValidateReplicaComponent
    if inst.ismastersim or TheNet:IsDedicated() then
        function EntityScript:ValidateReplicaComponent(name, cmp) return cmp or nil end
    else
        -- 有些时候，actioncomponents有组件，但却没有该组件的replica
        function EntityScript:ValidateReplicaComponent(name, cmp)
            return ValidateReplicaComponent(self, name, cmp) or
                       ((self.components and self.components[name] ~= nil or self.userid ~= nil or self:HasActionComponent(name)) and cmp or nil)
        end
    end
end)
-- 给inventoryitem组件函数打补丁
local classifiedreplicafns = {
    inventoryitem_replica = {
        "SetPickupPos",
        "SerializeUsage",
        "SetChargeTime",
        "SetDeployMode",
        "SetDeploySpacing",
        "SetDeployRestrictedTag",
        "SetUseGridPlacer",
        "SetAttackRange",
        "SetWalkSpeedMult",
        "SetEquipRestrictedTag"
    },
    constructionsite_replica = {"SetBuilder", "SetSlotCount"}
}
for replica, replicafns in pairs(classifiedreplicafns) do
    AddClassPostConstruct("components/" .. replica, function(self)
        for _, fnname in ipairs(replicafns) do
            local fn = self[fnname]
            self[fnname] = function(self, ...) if self.classified ~= nil then return fn(self, ...) end end
        end
    end)
end
AddClassPostConstruct("components/equippable_replica", function(self)
    local IsEquipped = self.IsEquipped
    self.IsEquipped = function(self, ...)
        if self.inst.components.equippable == nil and (ThePlayer == nil or ThePlayer.replica.inventory == nil) then return false end
        return IsEquipped(self, ...)
    end
end)

-- 农场BUG修复
AddComponentPostInit("growable", function(self)
    local DoGrowth = self.DoGrowth
    self.DoGrowth = function(self, ...) if self.inst and self.inst:IsValid() then return DoGrowth(self, ...) end end
    local SetStage = self.SetStage
    self.SetStage = function(self, stage, ...)
        if self.inst and self.inst.prefab == "weed_ivy" and stage == 4 then stage = 3 end
        if SetStage then SetStage(self, stage, ...) end
    end
end)
AddComponentPostInit("farming_manager", function(self)
    local CycleNutrientsAtPoint = self.CycleNutrientsAtPoint
    self.CycleNutrientsAtPoint = function(self, x, y, z, ...)
        if not x or not z then return end
        return CycleNutrientsAtPoint(self, x, y, z, ...)
    end
end)
-- 勋章坎普斯添加妥协所需的组件
if TUNING.DSTU then
    AddPrefabPostInit("medal_naughty_krampus", function(inst)
        if not TheWorld.ismastersim then return end
        if not inst.components.thief then inst:AddComponent("thief") end
    end)
end
-- 每日时长防止崩溃
local function GetModifiedSegs(retsegs)
    local importance = {"night", "dusk", "day"}
    retsegs.day = math.max(0, retsegs.day or 0)
    retsegs.dusk = math.max(0, retsegs.dusk or 0)
    retsegs.night = math.max(0, retsegs.night or 0)
    local total = retsegs.day + retsegs.dusk + retsegs.night
    if total <= 0 then
        -- 冬季/季节切换时 uiclock 可能收到全 0 的时段数据。
        -- 原循环在 total 为 0 时三个分支都不执行，会卡死客户端。
        retsegs.day, retsegs.dusk, retsegs.night = 10, 3, 3
        return retsegs
    end
    local guard = 0
    while total ~= 16 and guard < 64 do
        guard = guard + 1
        for _, k in ipairs(importance) do
            if total >= 16 and retsegs[k] > 1 then
                retsegs[k] = retsegs[k] - 1
            elseif total < 16 and retsegs[k] > 0 then
                retsegs[k] = retsegs[k] + 1
            end
            total = retsegs.day + retsegs.dusk + retsegs.night
            if total == 16 then break end
        end
    end
    if total ~= 16 then
        local diff = 16 - total
        if diff > 0 then
            retsegs.day = retsegs.day + diff
        else
            for _, k in ipairs(importance) do
                local take = math.min(retsegs[k], -diff)
                retsegs[k] = retsegs[k] - take
                diff = diff + take
                if diff == 0 then break end
            end
        end
    end
    return retsegs
end
AddClassPostConstruct("widgets/uiclock", function(self)
    local OnClockSegsChanged = self.OnClockSegsChanged
    function self:OnClockSegsChanged(data, ...)
        data.day = data.day or 0
        data.dusk = data.dusk or 0
        data.night = data.night or 0
        if (data.day + data.dusk + data.night) ~= 16 then data = GetModifiedSegs(data) end
        return OnClockSegsChanged(self, data, ...)
    end
end)

-- 现在单位被删除之后：无法创建新的计时器，所有计时器API置空，所有组件无法调用更新函数，从而防止无效单位崩溃
if EntityScript then
    local CancelAllPendingTasks = EntityScript.CancelAllPendingTasks
    EntityScript.CancelAllPendingTasks = function(self, ...)
        self.DoTaskInTime = nilfn
        self.DoPeriodicTask = nilfn
        self.ListenForEvent = nilfn
        self.WatchWorldState = nilfn
        -- self.AddComponent
        -- if self.pendingtasks then
        --     for k, v in pairs(self.pendingtasks) do if k and k.fn then k.fn = nilfn end end
        --     self.pendingtasks = nil
        -- end
        for k, v in pairs(self.components) do if v and type(v) == "table" and v.OnUpdate then v.OnUpdate = nilfn end end
        CancelAllPendingTasks(self, ...)
    end
end
AddPrefabPostInit("world", function(inst)
    local Map = getmetatable(inst.Map).__index
    local GetTileCenterPoint = Map.GetTileCenterPoint
    if GetTileCenterPoint ~= nil then
        Map.GetTileCenterPoint = function(self, tx, ty, ...)
            local x, y, z, t = GetTileCenterPoint(self, tx, ty, ...)
            return x or 0, y or 0, z or 0, t
        end
    end
end)

-- 妥协火荨麻防止崩溃
local function delayremove(inst) inst:DoTaskInTime(0, inst.Remove2hm) end
local function makedelayremove(inst)
    if not TheWorld.ismastersim then return end
    inst.Remove2hm = inst.Remove
    inst.Remove = delayremove
end
if TUNING.DSTU then AddPrefabPostInit("um_pyre_nettles", makedelayremove) end

-- 20260215 YeFeng 妥协荨麻甲PVP分支AddDebuff笔误修复(友伤险境导致PVP分支误触发崩溃)
if TUNING.DSTU then
    AddPrefabPostInit("um_armor_pyre_nettles", function(inst)
        if not TheWorld.ismastersim then return end
        local old_bumpcheck = inst._bumpcheck
        local guard = require("umcompatguard2hm")
        local bump = old_bumpcheck and guard.Find(old_bumpcheck, "bumpcheck")
        if bump and guard.Known(bump.value, "legacy_nettles_bump") then
            inst._bumpcheck = function(owner, data)
                local oldPVP2hm = TUNING.oldPVP2hm
                TUNING.oldPVP2hm = true
                old_bumpcheck(owner, data)
                TUNING.oldPVP2hm = oldPVP2hm
            end
        end
    end)
end

-- 妥协地下蟹兵螃蟹生成的发条重上游戏掉落物重置bug修复
if TUNING.DSTU then AddPrefabPostInit("knook", function(inst)
		if not TheWorld.ismastersim then return end
		SetOnSave(inst, function(inst, data)
		data.chanceloottable = inst.components.lootdropper.chanceloottable
		-- print(data.chanceloottable)
		end)
		SetOnLoad(inst, function(inst, data)
			if data and data.chanceloottable then
				inst.components.lootdropper:SetChanceLootTable(data.chanceloottable)
			end
		end)
	end)
end
if TUNING.DSTU then AddPrefabPostInit("roship",function(inst)
		if not TheWorld.ismastersim then return end
		SetOnSave(inst, function(inst, data)
		data.chanceloottable = inst.components.lootdropper.chanceloottable
		-- print(data.chanceloottable)
		end)
		SetOnLoad(inst, function(inst, data)
			if data and data.chanceloottable then
				inst.components.lootdropper:SetChanceLootTable(data.chanceloottable)
			end
		end)
	end)
end
if TUNING.DSTU then AddPrefabPostInit("bight",function(inst)
		if not TheWorld.ismastersim then return end
		SetOnSave(inst, function(inst, data)
		data.chanceloottable = inst.components.lootdropper.chanceloottable
		-- print(data.chanceloottable)
		end)
		SetOnLoad(inst, function(inst, data)
			if data and data.chanceloottable then
				inst.components.lootdropper:SetChanceLootTable(data.chanceloottable)
			end
		end)
	end)
end

-- 为爽pvp启用时妥协牛上受伤时崩溃问题,给官方打个补丁
if TUNING.DSTU then
	AddComponentPostInit("rider", function(self)
    local oldMount = self.Mount
		self.Mount = function(self, target, instant, ...)
			oldMount(self, target, instant, ...)
			if self.inst.components.combat.redirectdamagefn ~= nil then
				local oldredirectdamagefn = function(inst, attacker, damage, weapon, stimuli, ...)
					return target:IsValid()
						and not (target.components.health ~= nil and target.components.health:IsDead())
						and not (weapon ~= nil and (
							weapon.components.projectile ~= nil or
							weapon.components.complexprojectile ~= nil or
							(weapon.components.weapon and weapon.components.weapon:CanRangedAttack())
						))
						and stimuli ~= "electric"
						and stimuli ~= "darkness"
						and target
						or nil
				end
				self.inst.components.combat.redirectdamagefn = function(inst, attacker, damage, weapon, stimuli, ...)
					return stimuli ~= "beefalo_half_damage" and oldredirectdamagefn(inst, attacker, damage, weapon, stimuli, ...) or nil
				end
			end
		end
	end)
end

-- 妥协气垫船被帝王蟹炮塔识别摧毁的崩溃问题
if TUNING.DSTU then
	local function InstantlyBreakBoat(inst)
		-- This is not for SGboat but is for safety on physics.
		if inst.components.boatphysics then
			inst.components.boatphysics:SetHalting(true)
		end
		--Keep this in sync with SGboat.
		for entity_on_platform in pairs(inst.components.walkableplatform:GetEntitiesOnPlatform()) do
			entity_on_platform:PushEvent("abandon_ship")
		end
		for player_on_platform in pairs(inst.components.walkableplatform:GetPlayersOnPlatform()) do
			player_on_platform:PushEvent("onpresink")
		end
		inst:sinkloot()
		if inst.postsinkfn then
			inst:postsinkfn()
		end
		inst:Remove()
	end
	AddPrefabPostInit("portableboat", function(inst)
	if not TheWorld.ismastersim then return end
		if not inst.InstantlyBreakBoat then
			inst.InstantlyBreakBoat = InstantlyBreakBoat
		end
	end)
end

-- 妥协猪王不可用蒸数枝雇佣且会根据食物削弱选项的数值调整雇佣食物所需的饱食度
if TUNING.DSTU then
	local fooddatachange
	local change
	local updata
	fooddatachange = GetModConfigData("fooddata_change")
	if fooddatachange then
		change = math.abs(fooddatachange)
		updata = {0.9, 0.8, 0.6667}
	end
	local function IsGuard(guy)
		return guy.prefab == "pigking_pigguard" and
			not (guy.components.follower ~= nil and guy.components.follower.leader ~= nil)
	end
	local function FindRecruit(inst)
		local guard = FindEntity(inst, 20, IsGuard)
		if guard ~= nil then
			return guard
		else
			return false
		end
	end
	local function SendRecruit(inst, hunger, guard, giver)
		giver:PushEvent("makefriend")
		giver.components.leader:AddFollower(guard)
		guard.components.follower.leader = giver
		guard.components.follower:AddLoyaltyTime(hunger * TUNING.PIG_LOYALTY_PER_HUNGER)
		guard.components.follower.maxfollowtime =
		giver:HasTag("polite")
			and TUNING.PIG_LOYALTY_MAXTIME + TUNING.PIG_LOYALTY_POLITENESS_MAXTIME_BONUS
			or TUNING.PIG_LOYALTY_MAXTIME
	end
	AddPrefabPostInit("pigking", function(inst)
	if not TheWorld.ismastersim then return end
		if inst.components.trader then
			local oldtest = inst.components.trader.test
			inst.components.trader.test = function(inst, item, giver, ...)
				if giver:HasTag("merm") and item.prefab ~= "pig_token" or item.prefab == "beefalofeed" then
					return
				end
				if item.components.edible ~= nil and item.components.edible.hungervalue > 70 * (updata and updata[change] or 1) and FindRecruit(inst) then
					return true
				else
					return oldtest(inst, item, giver, ...)
				end
			end
			local oldonaccept = inst.components.trader.onaccept
			inst.components.trader.onaccept = function(inst, giver, item, ...)
				if item.components.edible ~= nil and item.components.edible.hungervalue > 70 * (updata and updata[change] or 1) and FindRecruit(inst) then
                SendRecruit(inst, item.components.edible.hungervalue, FindRecruit(inst), giver)
                inst.sg:GoToState("cointoss")
				else
					oldonaccept(inst, giver, item, ...)
				end
			end
		end
	end)
end

-- 滑倒组件防止崩溃
AddComponentPostInit("slipperyfeet", function(self)
    require("bootlegnonslip2hm").Install(self)
end)

-- 死亡后禁止前往hit状态
local deathstates = {"death", "seamlessplayerswap_death"}
AddStategraphPostInit("wilson", function(sg)
    for index, state in ipairs(deathstates) do
        if sg.states[state] and sg.states[state].onenter then
            local onenter = sg.states[state].onenter
            sg.states[state].onenter = function(inst, ...)
                onenter(inst, ...)
                if inst.sg and inst.sg.GoToState then
                    local old = inst.sg.GoToState
                    inst.sg.GoToState = function(self, statename, params, ...)
                        if statename == "hit" and self.currentstate and self.currentstate.name == state then return end
                        inst.sg.GoToState = old
                        return old(self, statename, params, ...)
                    end
                end
            end
        end
    end
end)

-- 客户端游戏自动更新时防止崩溃
if GetModConfigData("ignore client error") and not TheNet:IsDedicated() then
    require("update")
    if GLOBAL.Update then
        local lastreason
        local old = GLOBAL.Update
        GLOBAL.Update = function(dt)
            if TheWorld and not TheWorld.ismastersim then
                local result, reason = pcall(function() old(dt) end)
                if not result and (TheWorld and TheWorld.errortask2hm == nil or lastreason ~= reason) then
                    if TheWorld and TheWorld.errortask2hm == nil then
                        TheWorld.errortask2hm = TheWorld:DoTaskInTime(60, function(inst) inst.errortask2hm = nil end)
                    end
                    lastreason = reason
                    if reason and type and type(reason) == "string" and print then
                        print("intercept update error:" .. reason)
                        pcall(function() if ThePlayer and ThePlayer.components.talker then ThePlayer.components.talker:Say(reason) end end)
                    end
                end
            else
                old(dt)
            end
        end
    end
end

-- 玩家标签数目扩展
local PlayerTagEntitiesNumber = GetModConfigData("player tags limit")
if TUNING.PlayerTagEntitiesNumber == nil and PlayerTagEntitiesNumber and PlayerTagEntitiesNumber > 0 then
    TUNING.PlayerTagEntitiesNumber = PlayerTagEntitiesNumber
    local ignoretags = {"DECOR", "NOCLICK", "prototyper", "nightmaretracker", "maprevealer"}
    local function onplayerremove(inst)
        for _, entity in ipairs(inst.tagsentities) do
            if entity:value() and entity:value():IsValid() and entity:value().realRemove then entity:value().Remove = entity:value().realRemove end
        end
    end
    local function processplayertags(inst)
        if inst.tagsentities then return end
        inst.tagsentities = {}
        for i = 1, PlayerTagEntitiesNumber, 1 do
            table.insert(inst.tagsentities, net_entity(inst.GUID, "tagsentities" .. tostring(i)))
            if TheWorld.ismastersim then
                local proxyentity = SpawnPrefab("playertagentity2hm")
                inst:AddChild(proxyentity)
                proxyentity.entity:Hide()
                proxyentity.Transform:SetPosition(0, 0, 0)
                proxyentity.infinitetags = 0
                proxyentity.realRemove = proxyentity.Remove
                proxyentity.Remove = nilfn
                inst.tagsentities[i]:set(proxyentity)
            end
        end
        -- 客户端和服务器查询标签时,先从副实体上检测标签
        local HasTag = inst.HasTag
        inst.HasTag = function(self, tag, ...)
            if not table.contains(ignoretags, tag) then
                for _, entity in ipairs(self.tagsentities) do if entity:value() and entity:value().entity:HasTag(tag) then return true end end
            end
            return HasTag(self, tag, ...)
        end
        inst.HasTags = function(self, tag, ...)
            local tags = type(tag) == "table" and tag or {tag, ...}
            for _, tag in ipairs(tags) do if not self:HasTag(tag) then return false end end
            return true
        end
        local HasOneOfTags = inst.HasOneOfTags
        inst.HasOneOfTags = function(self, tag, ...)
            local tags = type(tag) == "table" and tag or {tag, ...}
            for _, tag in ipairs(tags) do
                if not table.contains(ignoretags, tag) then
                    for _, entity in ipairs(self.tagsentities) do
                        if entity:value() and entity:value().entity:HasTag(tag) then return true end
                    end
                end
            end
            return HasOneOfTags(self, tags, ...)
        end
        inst.HasAllTags = inst.HasTags
        inst.HasAnyTag = inst.HasOneOfTags
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("onremove", onplayerremove)
        -- 客户端和服务器添加标签时,下划线开头的标签必定存放在角色本体来便于角色客户端检测replica ValidateReplicaComponent
        local AddTag = inst.AddTag
        inst.AddTag = function(self, tag, ...)
            if tag == nil or self:HasTag(tag) then return end
            if string.byte(tag, 1, 1) ~= 95 and not table.contains(ignoretags, tag) then -- 95代表字符"_"
                for _, entity in ipairs(self.tagsentities) do
                    if entity:value() and entity:value().infinitetags < 50 then
                        entity:value().infinitetags = entity:value().infinitetags + 1
                        entity:value().entity:AddTag(tag)
                        return
                    end
                end
            end
            return AddTag(self, tag, ...)
        end
        -- 客户端和服务器移除标签时
        local RemoveTag = inst.RemoveTag
        inst.RemoveTag = function(self, tag, ...)
            if tag == nil then return end
            if not table.contains(ignoretags, tag) then
                for _, entity in ipairs(self.tagsentities) do
                    if entity:value() and entity:value().entity:HasTag(tag) then
                        entity:value().infinitetags = entity:value().infinitetags - 1
                        entity:value().entity:RemoveTag(tag)
                    end
                end
            end
            return RemoveTag(self, tag, ...)
        end
        inst.AddOrRemoveTag = function(self, tag, condition, ...)
            if condition then
                self:AddTag(tag)
            else
                self:RemoveTag(tag)
            end
        end
    end
    local function processplayer(world, inst) if inst and inst:HasTag("player") then processplayertags(inst) end end
    AddPrefabPostInit("world", function(inst) inst:ListenForEvent("entity_spawned", processplayer) end)
    -- 标签扩展会导致FindEntity函数中的标签参数识别对玩家目标无法遍历到除玩家自带标签以外的标签，导致部分物品功能失效
    -- 需要再次使用HasTag函数对玩家目标再次识别
    -- 修复标签扩展功能导致牛牛锁定牛帽玩家
    AddPrefabPostInit("beefalo", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.combat then
            local oldtargetfn = inst.components.combat.targetfn
            inst.components.combat.targetfn = function(...)
                local target = oldtargetfn(...)
                if target and target:HasTag("player") and target:HasTag("beefalo") then
                    return nil
                end
                return target
            end
        end
    end)
    -- 修复温蒂强健精油不免疫蜂蜜尾迹
    local UpvalueHacker = require("upvaluehacker2hm")
    local HONEYTRAILSLOWDOWN_MUST_TAGS = { "locomotor" }
    local HONEYTRAILSLOWDOWN_CANT_TAGS = { "flying", "playerghost", "INLIMBO", "honey_ammo_afflicted", "vigorbuff" }
    local function newonupdate(inst, x, y, z, rad, ...)
        for i, v in ipairs(TheSim:FindEntities(x, y, z, rad, HONEYTRAILSLOWDOWN_MUST_TAGS, HONEYTRAILSLOWDOWN_CANT_TAGS)) do
            if v.components.locomotor ~= nil then
                if v:HasTag("player") and v:HasTag("vigorbuff") then return end
                v.components.locomotor:PushTempGroundSpeedMultiplier(TUNING.BEEQUEEN_HONEYTRAIL_SPEED_PENALTY, WORLD_TILES.MUD)
            end
        end
    end
    AddPrefabPostInit("honey_trail", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.SetVariation then
            local old_OnUpdate = UpvalueHacker.GetUpvalue(inst.SetVariation, "OnInit", "OnUpdate")
            if old_OnUpdate then
                UpvalueHacker.SetUpvalue(inst.SetVariation, newonupdate, "OnInit", "OnUpdate")
            end
        end
    end)
end
-- AddComponentPostInit("playercontroller", function(self)
--     print()
-- end)

-- 哈奇缺失电击动画   妥协或科雷已修复?
-- AddStategraphPostInit("chester", function(sg)
--     if sg.states.electrocute then
--         local oldonenter = sg.states.electrocute.onenter
--         sg.states.electrocute.onenter = function(inst, ...)
--             if inst.prefab == "hutch" or inst.prefab == "shadowhutch2hm" then
--                 inst.sg:GoToState("hit")
--                 return
--             end
--             oldonenter(inst, ...)
--         end
--     end
-- end)

-- 燃烧后的延迟清理也会经 OnRemoveFromEntity 调用 OnUpdate。
-- 实体已被移除时不再查询坐标，仍让原来的组件清理取消任务。
AddComponentPostInit("propagator", function(self)
    local function HasPosition(inst)
        if not (inst and inst:IsValid() and inst.Transform) then return false end
        local x, y, z = inst.Transform:GetWorldPosition()
        return type(x) == "number" and type(y) == "number" and type(z) == "number"
    end
    local oldOnUpdate = self.OnUpdate
    self.OnUpdate = function(self, ...)
        if not HasPosition(self.inst) then
            self:StopUpdating()
            return
        end
        return oldOnUpdate(self, ...)
    end
    local oldOnRemoveEntity = self.OnRemoveEntity
    self.OnRemoveEntity = function(self, ...)
        if not HasPosition(self.inst) then return end
        return oldOnRemoveEntity(self, ...)
    end
end)

-- 自我堆叠组件添加其他物品的组件检测
AddComponentPostInit("selfstacker", function(self)
    local oldFindItemToStackWith = self.FindItemToStackWith
    self.FindItemToStackWith = function(self, ...)
        local stackpartner = oldFindItemToStackWith(self, ...)
        if self.inst.components.perishable and stackpartner and not stackpartner.components.perishable then return end
        return stackpartner
    end
end)

-- 喝水模组芯片无类型崩溃修复
AddPrefabPostInit("wx78module_nonedrunk", function(inst)
    inst._type = inst._type or CIRCUIT_BARS.GAMMA
	if not TheWorld.ismastersim then return end
    if inst.components.upgrademodule and not inst.components.upgrademodule:GetType() then
        inst.components.upgrademodule:SetType(CIRCUIT_BARS.GAMMA)
    end
end)
