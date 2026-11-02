-----------------------------------------------------------------------									
--				Go,Pig!   加油，猪！
--				揍正太的时间到了！
-----------------------------------------------------------------------
-- 重生时间削弱
TUNING.DAYWALKER_RESPAWN_DAYS_COUNT = TUNING.DAYWALKER_RESPAWN_DAYS_COUNT * 2.5
-- 拾荒和梦魇猪刷新时间相互独立
AddComponentPostInit("forestdaywalkerspawner",function(self)
	self.CanSpawnFromJunk = function(self, ...)
		if self:ShouldShakeJunk() then
			return true
		end
		if self.daywalker ~= nil then
			return false
		end
		return self.days_to_spawn <= 0
	end
	self.OnDayChange = function(self, ...)
		if self.daywalker ~= nil or self.bigjunk ~= nil then
			return
		end
		local days_to_spawn = self.days_to_spawn
		if days_to_spawn > 0 then
			self.days_to_spawn = days_to_spawn - 1
			return
		end
		if not self:TryToSetDayWalkerJunkPile() then
			return
		end
		self.bigjunk:StartDaywalkerBuried()
		self.days_to_spawn = TUNING.DAYWALKER_RESPAWN_DAYS_COUNT
	end
end)
AddComponentPostInit("daywalkerspawner",function(self)
	self.OnDayChange = function(self, ...)
		if self.daywalker ~= nil then
			return
		end
		local days_to_spawn = self.days_to_spawn
		if days_to_spawn > 0 then
			self.days_to_spawn = days_to_spawn - 1
			return
		end
		local daywalker = self:TryToSpawnDayWalkerArena()
		if daywalker == nil then
			return
		end
		self:WatchDaywalker(daywalker)
		self.days_to_spawn = TUNING.DAYWALKER_RESPAWN_DAYS_COUNT
	end
end)

-- 各种武器耐久增强
TUNING.DAYWALKER2_ITEM_USES = 5
TUNING.DAYWALKER2_ITEM_USES = 5
TUNING.DAYWALKER2_ITEM_USES = 5 

-- 翻找武器间隔、攻击间隔减少
TUNING.DAYWALKER2_MULTIWIELD_CD = TUNING.DAYWALKER2_MULTIWIELD_CD * 3 / 4
-- TUNING.DAYWALKER2_ATTACK_PERIOD.min = TUNING.DAYWALKER2_ATTACK_PERIOD.min * 3 / 4
-- TUNING.DAYWALKER2_ATTACK_PERIOD.max = TUNING.DAYWALKER2_ATTACK_PERIOD.max * 3 / 4 

-- 血量解锁能力增强
local PHASES =
{
	[0] = {
		hp = 1,
		fn = function(inst)
			inst.canmultiwield = true
			inst.candoublerummage = false
			inst.canavoidjunk = true
		end,
	},
	--
	[1] = {
		hp = 0.75,
		fn = function(inst)
			inst.canmultiwield = true
			inst.candoublerummage = true
			inst.canavoidjunk = true
		end,
	}
}

local function newCheckHealthPhase(inst)
	local healthpct = inst.components.health:GetPercent()
	for i = #PHASES, 1, -1 do
		local v = PHASES[i]
		if healthpct <= v.hp then
			v.fn(inst)
			return
		end
	end
	PHASES[0].fn(inst)
end

local function changecheckhealth(inst)
	local oldfreefn = inst.MakeFreed
	inst.MakeFreed = function(inst)
		oldfreefn(inst)
		newCheckHealthPhase(inst)
	end
end

local function onloadcheckhealth(inst)
	local oldonload = inst.OnLoad
	inst.OnLoad = function(inst, data, ...)
		oldonload(inst, data, ...)
		newCheckHealthPhase(inst)
	end
end

-- 翻找激光炮不再需要击败天体英雄开启事件条件了
local SWING_ITEMS = { "object" }
local TACKLE_ITEMS = { "spike" }
local CANNON_ITEMS = { "cannon" }
local _temp = {}
local function newGetNextItem(inst)
	local junk = inst.components.entitytracker:GetEntity("junk")
	if junk and (
		not (inst.canswing or inst.cantackle or inst.cancannon) or
		(inst.canmultiwield and
		not (inst.canswing and inst.cantackle and inst.cancannon) and
		not inst.components.timer:TimerExists("multiwield")
		))
	then
		--Has no equip, or can multiwield and isn't fully equipped yet
		local n = 0
		if not inst.canswing then
			for i = 1, #SWING_ITEMS do
				n = n + 1
				_temp[n] = SWING_ITEMS[i]
			end
		end
		if not inst.cantackle then
			for i = 1, #TACKLE_ITEMS do
				n = n + 1
				_temp[n] = TACKLE_ITEMS[i]
			end
		end
		if not inst.cancannon then
			for i = 1, #CANNON_ITEMS do
				n = n + 1
				_temp[n] = CANNON_ITEMS[i]
			end
		end
		if inst.lastequip and n > 1 then
			for i = 1, n do
				if _temp[i] == inst.lastequip then
					_temp[i] = _temp[n]
					n = n - 1
					break
				end
			end
		end
		return junk, _temp[math.random(n)]
	end
	return junk
end

-- 普通生物攻击会触发吼叫恐惧附近生物
local function taunt2hm(inst, data)
	if data and data.attacker and not (data.attacker:HasTag("epic") or data.attacker:HasTag("player")) and not inst:HasTag("swc2hm") then
		if inst.components.timer then
			if inst.components.timer:TimerExists("roar_cd") then
				local cd = inst.components.timer:GetTimeLeft("roar_cd")
				cd = cd - 2
				inst.components.timer:SetTimeLeft("roar_cd", cd)
			elseif data.attacker:HasTag("canepicscare2hm") and not inst.components.timer:TimerExists("roar_cd") then
				if not inst.sg:HasStateTag("busy") then
					inst:PushEvent("roar", { target = inst.components.combat.target })
				end
			end
		end
	end
end

-- 恐惧附近生物使其怯战丢盔弃甲
local BrainCommon = require("brains/braincommon")
local PanicWhenScared = rawget(BrainCommon, "PanicWhenScared")
rawset(BrainCommon, "PanicWhenScared", function(inst, ...)
	if not inst:HasTag("canepicscare2hm") then inst:AddTag("canepicscare2hm") end
    return PanicWhenScared(inst, data, ...)
end)

local function _DropTargetWeapon(inst, target)
    if inst and inst:IsValid() and target ~= nil and target:IsValid() and target.components.inventory ~= nil then
        local headitem = target.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
        if headitem and headitem:HasTag("curse2hm") then headitem = nil end
        local handsitem = target.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        if handsitem and handsitem:HasTag("curse2hm") then handsitem = nil end
		if headitem ~= nil and headitem:IsValid() and headitem.components.inventoryitem then
			target.components.inventory:DropItem(headitem, not headitem.components.inventoryitem.cangoincontainer)
		end
		if handsitem ~= nil and handsitem:IsValid() and handsitem.components.inventoryitem then
			target.components.inventory:DropItem(handsitem, not handsitem.components.inventoryitem.cangoincontainer)
		end
    end
end

AddStategraphPostInit("daywalker2", function(sg)
	if sg.states and sg.states.taunt and sg.states.taunt.timeline and sg.states.taunt.timeline[2] then
		local oldtimeline = sg.states.taunt.timeline[2].fn
		sg.states.taunt.timeline[2].fn = function(inst, ...)
			oldtimeline(inst, ...)
			local range = inst.components.epicscare and inst.components.epicscare.range or 10
			local scaremusttags = inst.components.epicscare and inst.components.epicscare.scaremusttags
			local scareexcludetags = inst.components.epicscare and inst.components.epicscare.scareexcludetags or { "epic", "INLIMBO" }
			local scareoneoftags = inst.components.epicscare and inst.components.epicscare.scareoneoftags or { "_combat", "locomotor" }
			local x, y, z = inst.Transform:GetWorldPosition()
			local ents = TheSim:FindEntities(x, y, z, range, scaremusttags, scareexcludetags, scareoneoftags)
			for i, v in ipairs(ents) do
				if v ~= inst and not v:HasTag("player") and v.entity:IsVisible() and not (v.components.health ~= nil and v.components.health:IsDead()) then
					_DropTargetWeapon(inst, v)
				end
			end
		end
	end
end)
-- 被巨兽生物攻击将生命值恢复一定血量并传回垃圾堆
local function TeleportOverrideFn(inst)
    local pt = inst:GetPosition()
    local offset = FindWalkableOffset(pt, math.random() * 2 * PI, 16, 8, true, false)
    if offset ~= nil then
        pt = pt + offset
    end

    return pt
end

local function epichit(inst, data)
	if inst.willteleported or inst.defeated or inst.buriedthen then return end
	if data and data.attacker and data.attacker:HasTag("epic") and not inst:HasTag("swc2hm") then
		inst.willteleported = true
		inst:DoTaskInTime(1, function(inst)
			local locpos = inst.components.teleportedoverride and inst.components.teleportedoverride:GetDestPosition() or inst:GetPosition()
			if not locpos then return end
			if inst.components.health then
				local maxhealth = inst.components.health.maxhealth or TUNING.DAYWALKER_HEALTH
				inst.components.health:DoDelta(maxhealth * 0.05)
			end
			TheWorld:PushEvent("ms_sendlightningstrike", locpos)
			if not (inst.components.teleportedoverride and inst.components.teleportedoverride:GetDestPosition()) then
				locpos = TeleportOverrideFn(inst)
				if inst.Physics ~= nil then
					inst.Physics:Teleport(locpos.x, 0, locpos.z)
				else
					inst.Transform:SetPosition(locpos.x, 0, locpos.z)
				end
			end
			inst:PushEvent("teleported")
			inst.components.combat:DropTarget()
			data.attacker.components.combat:DropTarget()
			inst.willteleported = nil
		end)
	end
	if data and data.attacker and data.attacker.components.combat and inst:HasTag("swc2hm") then
        data.attacker.components.combat:DropTarget()
    end
	taunt2hm(inst, data)
end

-- 处理影子攻击冷却函数
local function newStartAttackCooldown(inst)
	if inst:HasTag("swc2hm") then
		inst.components.combat:SetAttackPeriod(GetRandomMinMax(9,12))
		inst.components.combat:RestartCooldown()
	else
		inst.components.combat:SetAttackPeriod(GetRandomMinMax(TUNING.DAYWALKER2_ATTACK_PERIOD.min, TUNING.DAYWALKER2_ATTACK_PERIOD.max))
		inst.components.combat:RestartCooldown()
	end
end

AddPrefabPostInit("daywalker2", function(inst)
	if not TheWorld.ismastersim then return end
	if inst.components.healthtrigger then
		for i, v in pairs(PHASES) do
			inst.components.healthtrigger:AddTrigger(v.hp, v.fn)
		end
	end
	inst:ListenForEvent("attacked", epichit)
	changecheckhealth(inst)
	onloadcheckhealth(inst)
	inst.GetNextItem = newGetNextItem
	inst.strongattackPG = 0
	inst.willteleported = nil
	inst.StartAttackCooldown = newStartAttackCooldown
end)

-- 增加脱战回血能力
local RESET_COMBAT_DELAY = 10
local function GetJunk(inst)
	return inst.components.entitytracker:GetEntity("junk")
end
local function GetJunkPos(inst)
	local junk = GetJunk(inst)
	return junk and junk:GetPosition() or nil
end

AddBrainPostInit("daywalker2brain", function(self)
	if self.bt.root.children and self.bt.root.children[1] then
		if self.bt.root.children[1].children and self.bt.root.children[1].children[2] then
			if self.bt.root.children[1].children[2].children then
				table.insert(self.bt.root.children[1].children[2].children, 5, ParallelNode{
					SequenceNode{
						WaitNode(RESET_COMBAT_DELAY),
						ActionNode(function() self.inst:SetEngaged(false) end),
					},
					PriorityNode({
						Wander(self.inst, GetJunkPos, 8),
					}, 0.5),
				})
			end
		end
	end
end)

-- 击落目标武器函数
local function DropTargetWeapon(inst, target)
    if inst and inst:IsValid() and target ~= nil and target:IsValid() and target.components.inventory ~= nil then
        -- 骨甲正常时免疫脱落
        for slot, equip in pairs(target.components.inventory.equipslots) do
            if equip and equip:IsValid() and equip.prefab == "armorskeleton" then
                if equip.components.cooldown and equip.components.cooldown.onchargedfn and equip.components.cooldown:IsCharged() then
                    return
                else
                    break
                end
            end
        end
        local headitem = target.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
        if headitem and headitem:HasTag("curse2hm") then headitem = nil end
        local handsitem = target.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        if handsitem and handsitem:HasTag("curse2hm") then handsitem = nil end
		-- 棍子拍飞玩家手部武器，尖刺顶飞玩家头部装备
        local item = (not target:HasTag("stronggrip")) and inst.attack_swingPG and handsitem or inst.tackle_liftPG and headitem
        if item ~= nil and item:IsValid() and item.components.inventoryitem then
            target.components.inventory:DropItem(item, not item.components.inventoryitem.cangoincontainer)
            if item.Physics ~= nil and item.Physics:IsActive() then
                local x, y, z = item.Transform:GetWorldPosition()
                item.Physics:Teleport(x, .1, z)
                x, y, z = inst.Transform:GetWorldPosition()
                local x1, y1, z1 = target.Transform:GetWorldPosition()
                local angle = math.atan2(z1 - z, x1 - x) + (math.random() * 20 - 10) * DEGREES
                local speed = 5 + math.random() * 2
                item.Physics:SetVel(math.cos(angle) * speed, 10, math.sin(angle) * speed)
            end
        end
    end
end

local AOE_RANGE_PADDING = 3
local AOE_TARGET_MUSTHAVE_TAGS = { "_combat" }
local AOE_TARGET_CANT_TAGS = { "INLIMBO", "flight", "invisible", "notarget", "noattack", "junk_fence" }
local NOBLOCK_AOE_TARGET_CANT_TAGS = { "INLIMBO", "flight", "invisible", "notarget", "noattack", "blocker" }

-- 处理击落武器和强制击飞判定
local function _AOEAttack(inst, dist, radius, arc, heavymult, mult, forcelanded, targets, overridenontags)
	local chance = math.random()
	if inst.strongattackPG ~= nil then chance = chance - 0.1 * inst.strongattackPG end
	local hit = false
	inst.components.combat.ignorehitrange = true
	local x, y, z = inst.Transform:GetWorldPosition()
	local arcx, cos_theta, sin_theta
	if dist ~= 0 or arc then
		local theta = inst.Transform:GetRotation() * DEGREES
		cos_theta = math.cos(theta)
		sin_theta = math.sin(theta)
		if dist ~= 0 then
			x = x + dist * cos_theta
			z = z - dist * sin_theta
		end
		if arc then
			--min-x for testing points converted to local space
			arcx = x + math.cos(arc / 2 * DEGREES) * radius
		end
	end
	for i, v in ipairs(TheSim:FindEntities(x, y, z, radius + AOE_RANGE_PADDING, AOE_TARGET_MUSTHAVE_TAGS, overridenontags and NOBLOCK_AOE_TARGET_CANT_TAGS or AOE_TARGET_CANT_TAGS)) do
		if v ~= inst and
			v:IsValid() and not v:IsInLimbo() and
			not (v.components.health and v.components.health:IsDead())
		then
			local range = radius + v:GetPhysicsRadius(0)
			local x1, y1, z1 = v.Transform:GetWorldPosition()
			local dx = x1 - x
			local dz = z1 - z
			if dx * dx + dz * dz < range * range and
				--convert to local space x, and test against arcx
				(arcx == nil or x + cos_theta * dx - sin_theta * dz > arcx) and
				inst.components.combat:CanTarget(v)
			then
				if (chance < 0.5 or inst.strongattackPG >= 2) and v:HasTag("player") then
					if inst.strongattackPG >= 2 then
						local hitfx = SpawnPrefab("round_puff_fx_lg")
						v:AddChild(hitfx)
					end
					if v.sg:HasStateTag("parrying") then v.sg:GoToState("idle") end
					if v:HasTag("wereplayer") then
						v:PushEvent("knockback", {knocker = inst, radius = 1, strengthmult = mult, forcelanded = forcelanded })
					else
						v.sg:GoToState("knockback", {knocker = inst, radius = 1, strengthmult = mult, forcelanded = forcelanded })
					end
				end
				if chance < 0.3 and v.sg and not v.sg:HasStateTag("parrying") or inst.strongattackPG >= 2 then
					if v.sg:HasStateTag("parrying") then v.sg:GoToState("idle") end
					DropTargetWeapon(inst, v)
				end
				hit = true
				if hit and inst.strongattackPG >= 2 then
					inst.strongattackPG = 0
				elseif hit and not inst:HasTag("swc2hm") then
					inst.strongattackPG = inst.strongattackPG + 1
				end
			end
		end
	end
	inst.components.combat.ignorehitrange = false
	return hit
end


-- 原状态图部分更改
local function newChooseAttack(inst)
	local target = inst.components.combat.target
	if target then
		if inst.cancannon and inst.nextATcannon == true and not inst.components.combat:InCooldown() then
			inst.sg:GoToState("cannon_pre", target)
			return true
		elseif inst.cantackle and inst.nextATtackle == true then
			inst.sg:GoToState("tackle_pre", target)
			return true
		--elseif inst.cancannon and not inst.components.combat:InCooldown() and not inst:IsNear(target, 15) then
		--	inst.sg:GoToState("cannon_pre", target)
		--	return true
		end
	end
end
local function TurnToTargetFromNoFaced(inst)
	if inst.sg.lasttags and inst.sg.lasttags["canrotate"] and inst.sg.lasttags["busy"] then
		local target = inst.components.combat.target
		if target then
			inst:ForceFacePoint(target.Transform:GetWorldPosition())
		end
	end
end
AddStategraphPostInit("daywalker2", function(sg)
	-- 处理影子进入新攻击状态
	if sg.events and sg.events.doattack then
		local oldfn = sg.events.doattack.fn
		sg.events.doattack.fn = function(inst)
		if not inst:HasTag("swc2hm") then
			oldfn(inst)
		elseif inst:HasTag("swc2hm") and not (inst.sg:HasStateTag("busy") or inst.defeated) then
			newChooseAttack(inst)
		end
	end
	end
	if sg.states.tackle_pre and sg.states.tackle_pre.events and sg.states.tackle_pre.events.animover then
		sg.states.tackle_pre.events.animover.fn = function(inst)
			if inst.AnimState:AnimDone() and inst:HasTag("swc2hm") then
				inst.sg.statemem.tackling = true
				inst.sg:GoToState("tackle_loopPG", inst.sg.statemem.target)
			elseif inst.AnimState:AnimDone() and not inst:HasTag("swc2hm") then
				inst.sg.statemem.tackling = true
				inst.sg:GoToState("tackle_loop", inst.sg.statemem.target)
			end
		end
	end
	if sg.states.cannon_pre and sg.states.cannon_pre.events and sg.states.cannon_pre.events.animover then
		sg.states.cannon_pre.events.animover.fn = function(inst)
			if inst.AnimState:AnimDone() and inst:HasTag("swc2hm") then
				inst.sg.statemem.tackling = true
				inst.sg:GoToState("cannonPG", inst.sg.statemem.target)
			elseif inst.AnimState:AnimDone() and not inst:HasTag("swc2hm") then
				inst.sg.statemem.tackling = true
				inst.sg:GoToState("cannon", inst.sg.statemem.target)
			end
		end
	end
	-- 棍子攻击
	if sg.states.attack_swing and sg.states.attack_swing.timeline and sg.states.attack_swing.timeline[3] then
		local oldsgfn = sg.states.attack_swing.timeline[3].fn
		sg.states.attack_swing.timeline[3].fn = function(inst)
		inst.attack_swingPG = true
		oldsgfn(inst)
		-- 同步执行会导致角色状态更新调用异常强制击飞失效，所以这里延时调用
		inst:DoTaskInTime(0, function(inst)
			_AOEAttack(inst, 1, 4.5, 240, nil, 0.75, nil, nil, false)
			inst.attack_swingPG = nil
		end)
		end
	end
	-- 钻头攻击
	if sg.states.tackle_lift and sg.states.tackle_lift.timeline and sg.states.tackle_lift.timeline[3] then
		local oldsgfn = sg.states.tackle_lift.timeline[2].fn
		sg.states.tackle_lift.timeline[2].fn = function(inst)
		inst.tackle_liftPG = true
		oldsgfn(inst)
		_AOEAttack(inst, 1, 2, nil, nil, 0.75, nil, nil, false, false)
		inst.tackle_liftPG = nil
		end
	end
end)

-- 影子额外构造函数
local brainPG = require("brains/daywalker2brainPG")
local function swc2hmfn(child)
	child.tacklenumberPG = 0
	-- 影子无法被仇恨和攻击
	child:AddTag("NOCLICK")
	child:AddTag("notarget")
	-- 设置新脑部文件
	child:SetBrain(brainPG)
	-- 延迟获得武器
	child:DoTaskInTime(2, function(child)
		child:SetEquip("tackle", "spike")
		child:SetEquip("cannon", "cannon")
		child.sg:GoToState("rummage_pst",{ nextstate1 = "lift_spike", nextstate2 = "lift_cannon" })
		-- 设置速度
		if child.components.locomotor then
			child.components.locomotor.runspeed = TUNING.DAYWALKER_RUNSPEED * 1.5
			child.components.locomotor.walkspeed = TUNING.DAYWALKER_WALKSPEED * 4
		end
	end)
	-- 无敌免伤
	if child.components.health then
		child.components.health:SetAbsorptionAmount(1)
	end
	-- 无法被催眠和冰冻
	if child.components.sleeper then
        child.components.sleeper:SetResistance(100000)
		child.components.sleeper.AddSleepiness = nilfn
        child.components.sleeper.GoToSleep = nilfn
    end
    if child.components.freezable then
        child.components.freezable:SetResistance(100000)
		child.components.freezable.AddColdness = nilfn
        child.components.freezable.Freeze = nilfn
    end
	-- 移除物理碰撞，无法落水，无法拉脱加载
	if child.components.playerprox2hm then
		child.components.playerprox2hm:SetDist(30, 50)
	end
	RemovePhysicsColliders(child)
	child:RemoveComponent("drownable")
	child.nextATcannon = false
	child.nextATtackle = true
end

AddPrefabPostInit("daywalker2", function(inst)
	if not TheWorld.ismastersim then return end
	inst.swc2hmfn = swc2hmfn
	inst.shadowcantout2hm = true
end)

local CHATTER_DELAYS =
{
	--NOTE: len must work for (net_tinybyte)
	["DAYWALKER_POWERDOWN"] =			{ delay = 3, len = 1.5 },
	["DAYWALKER2_CHASE_AWAY"] =			{ delay = 4, len = 1.5 },
	["DAYWALKER2_RUMMAGE_SUCCESS"] =	{ delay = 2, len = 1.5 },
	["DAYWALKER2_RUMMAGE_FAIL"] =		{ delay = 0, len = 1.5 },
}
local SGDaywalkerCommon = require("stategraphs/SGdaywalker_common")
local function TryChatter(inst, strtblname, index, ignoredelay, echotochatpriority)
	-- 'echotochatpriority' defaults to CHATPRIORITIES.LOW if nil is passed.
	SGDaywalkerCommon.TryChatter(inst, CHATTER_DELAYS, strtblname, index, ignoredelay, echotochatpriority)
end

-- 影子专用状态图
local AOE_RANGE_PADDING = 3
local AOE_TARGET_MUSTHAVE_TAGS = { "_combat" }
local AOE_TARGET_CANT_TAGS = { "INLIMBO", "flight", "invisible", "notarget", "noattack", "junk_fence" }
local NOBLOCK_AOE_TARGET_CANT_TAGS = { "INLIMBO", "flight", "invisible", "notarget", "noattack", "blocker" }
local function _AOEAttack(inst, dist, radius, arc, heavymult, mult, forcelanded, targets, overridenontags)
	local hit = false
	inst.components.combat.ignorehitrange = true
	local x, y, z = inst.Transform:GetWorldPosition()
	local arcx, cos_theta, sin_theta
	if dist ~= 0 or arc then
		local theta = inst.Transform:GetRotation() * DEGREES
		cos_theta = math.cos(theta)
		sin_theta = math.sin(theta)
		if dist ~= 0 then
			x = x + dist * cos_theta
			z = z - dist * sin_theta
		end
		if arc then
			--min-x for testing points converted to local space
			arcx = x + math.cos(arc / 2 * DEGREES) * radius
		end
	end
	for i, v in ipairs(TheSim:FindEntities(x, y, z, radius + AOE_RANGE_PADDING, AOE_TARGET_MUSTHAVE_TAGS, overridenontags and NOBLOCK_AOE_TARGET_CANT_TAGS or AOE_TARGET_CANT_TAGS)) do
		if v ~= inst and v.prefab ~= inst.prefab and
			not (targets and targets[v]) and
			v:IsValid() and not v:IsInLimbo() and
			not (v.components.health and v.components.health:IsDead())
		then
			local range = radius + v:GetPhysicsRadius(0)
			local x1, y1, z1 = v.Transform:GetWorldPosition()
			local dx = x1 - x
			local dz = z1 - z
			if dx * dx + dz * dz < range * range and
				--convert to local space x, and test against arcx
				(arcx == nil or x + cos_theta * dx - sin_theta * dz > arcx) and
				inst.components.combat:CanTarget(v)
			then
				local damage = inst.components.combat.defaultdamage
				if v:HasTag("player") then
					damage = damage / 2
				end
				v.components.combat:GetAttacked_Internal(inst,damage) -- 2025.9.19 :改为inst
				if targets then
					targets[v] = true
				end
			end
		end
	end
	inst.components.combat.ignorehitrange = false
	return hit
end
local function DoFootstep(inst, volume)
	inst.sg.mem.lastfootstep = GetTime()
	inst.SoundEmitter:PlaySound(inst.footstep, nil, volume)
end
-- 猪突猛进
AddStategraphState("daywalker2", State{
	name = "tackle_loopPG",
	tags = { "tackle", "attack", "busy", "jumping" ,"noelectrocute"},

	onenter = function(inst, target)
		inst.AnimState:PlayAnimation("tackle", true)
		inst:StartAttackCooldown()
		inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength() * 3) --16 * 3
		inst.sg.statemem.target = target
		inst.sg.statemem.targets = {}
		inst.tacklenumberPG = inst.tacklenumberPG + 1
		if inst.sg.statemem.target then
			inst.Transform:SetRotation(inst:GetAngleToPoint(inst.sg.statemem.target.Transform:GetWorldPosition()))
		end
		inst.components.combat:SetDefaultDamage(TUNING.DAYWALKER2_TACKLE_DAMAGE)
	end,

	onupdate = function(inst)
		local speedmult = inst.components.locomotor:GetSpeedMultiplier()
		inst.Physics:SetMotorVelOverride(TUNING.DAYWALKER2_TACKLE_SPEED * speedmult, 0, 0)

		local target = inst.sg.statemem.target
		if target then
			if target:IsValid() then
				local x1, y1, z1 = target.Transform:GetWorldPosition()
				local rot = inst.Transform:GetRotation()
				local rot1 = inst:GetAngleToPoint(x1, y1, z1)
				local drot = ReduceAngle(rot1 - rot)
				if math.abs(drot) < 90 then
					rot1 = rot + math.clamp(drot / 2, -1, 1)
					inst.Transform:SetRotation(rot1)
				end
			else
				inst.sg.statemem.target = nil
			end
		end
		_AOEAttack(inst, 1, 2, nil, nil, nil, nil, inst.sg.statemem.targets)
	end,

	timeline =
	{

		--loop 1
		FrameEvent(7, DoFootstep),
		FrameEvent(15, DoFootstep),
		--loop 2
		FrameEvent(23, DoFootstep),
		FrameEvent(31, DoFootstep),

		--loop 3
		FrameEvent(39, DoFootstep),
		FrameEvent(47, DoFootstep),
	},

	ontimeout = function(inst)
		if inst.tacklenumberPG >= 3 then
			inst.sg:GoToState("tackle_pst")
			inst.sg.statemem.hit = nil
			inst.tacklenumberPG = 0
			if math.random() < 0.5 then
				inst.nextATcannon = true
				inst.nextATtackle = false
				inst.components.combat:SetRange(20)
			else
				inst.nextATcannon = false
				inst.nextATtackle = true
				inst.components.combat:SetRange(10)
			end		
		else
			inst.sg:GoToState("tackle_loopPG", inst.sg.statemem.target)
			inst.sg.statemem.hit = nil
		end
	end,

	onexit = function(inst)
		if not inst.sg.statemem.tackling then
			inst.components.combat:SetDefaultDamage(TUNING.DAYWALKER_DAMAGE)
			inst.Physics:ClearMotorVelOverride()
			inst.Physics:Stop()
		end
	end,
})

local SECOND_BLAST_TIME = 22*FRAMES
local NUM_STEPS = 10
local STEP = 1.0
local OFFSET = 2 - STEP
local function SpawnBeam(inst, target_pos)
    if target_pos == nil then
        return
    end

    local ix, iy, iz = inst.Transform:GetWorldPosition()

    -- This is the "step" of fx spawning that should align with the position the beam is targeting.
    local target_step_num = RoundBiasedUp(NUM_STEPS * 2/5)

    local angle = nil

    -- gx, gy, gz is the point of the actual first beam fx
    local gx, gy, gz = nil, 0, nil
    local x_step = STEP
    if inst:GetDistanceSqToPoint(target_pos:Get()) < 4 then
        angle = math.atan2(iz - target_pos.z, ix - target_pos.x)

        -- If the target is too close, use the minimum distance
        gx, gy, gz = inst.Transform:GetWorldPosition()
        gx = gx + (2 * math.cos(angle))
        gz = gz + (2 * math.sin(angle))
    else
        angle = math.atan2(iz - target_pos.z, ix - target_pos.x)

        gx, gy, gz = target_pos:Get()
        gx = gx + (target_step_num * STEP * math.cos(angle))
        gz = gz + (target_step_num * STEP * math.sin(angle))
    end

    local targets, skiptoss = {}, {}
    local sbtargets, sbskiptoss = {}, {}
    local x, z = nil, nil
    local trigger_time = nil

    local i = -1
    while i < NUM_STEPS do
        i = i + 1
        x = gx - i * x_step * math.cos(angle)
        z = gz - i * STEP * math.sin(angle)

        local first = (i == 0)
        local prefab = (i > 0 and "alterguardian_laser") or "alterguardian_laserempty"
        local x1, z1 = x, z

        trigger_time = math.max(0, i - 1) * FRAMES

        inst:DoTaskInTime(trigger_time, function(inst2)
            local fx = SpawnPrefab(prefab)
            fx.caster = inst2
            fx.Transform:SetPosition(x1, 0, z1)
            fx:Trigger(0, targets, skiptoss)
            if first then
                ShakeAllCameras(CAMERASHAKE.FULL, .7, .02, .2, target_pos or fx, 30)
            end
        end)

        inst:DoTaskInTime(trigger_time + SECOND_BLAST_TIME, function(inst2)
            local fx = SpawnPrefab(prefab)
            fx.caster = inst2
            fx.Transform:SetPosition(x1, 0, z1)
            fx:Trigger(0, sbtargets, sbskiptoss, true)
            if first then
                ShakeAllCameras(CAMERASHAKE.FULL, .7, .02, .2, target_pos or fx, 30)
            end
        end)
    end

    inst:DoTaskInTime(i*FRAMES, function(inst2)
        local fx = SpawnPrefab("alterguardian_laser")
        fx.Transform:SetPosition(x, 0, z)
        fx:Trigger(0, targets, skiptoss)
    end)

    inst:DoTaskInTime((i+1)*FRAMES, function(inst2)
        local fx = SpawnPrefab("alterguardian_laser")
        fx.Transform:SetPosition(x, 0, z)
        fx:Trigger(0, targets, skiptoss)
    end)
end
-- 天体激光攻击
AddStategraphState("daywalker2", State{
	name = "cannonPG",
	tags = { "attack", "busy", "nosleep" ,"noelectrocute"},

	onenter = function(inst, target)
		inst.components.locomotor:Stop()
		inst.AnimState:PlayAnimation("laser_pst")
		inst.SoundEmitter:PlaySound("qol1/daywalker_scrappy/laser_pst")
		inst.SoundEmitter:PlaySound("daywalker/voice/speak_short")
		inst.components.combat:SetDefaultDamage(150)
		inst.sg.statemem.target = target
		if inst.sg.statemem.target ~= nil and inst.sg.statemem.target:IsValid() then
			inst.sg.statemem.target_pos = inst.sg.statemem.target:GetPosition()
			-- 激光的预判攻击反应时间太短了，移除
			--if inst.sg.statemem.target:HasTag("player") and math.random() > 0 then
			--	local playerpos = inst.sg.statemem.target_pos
			--	local player = inst.sg.statemem.target
			--	local radius = (player.components.locomotor and player.components.locomotor:GetRunSpeed() or 6) * 8 * FRAMES
			--	local rot = player.Transform:GetRotation()
			--	inst.sg.statemem.target_pos = playerpos + Vector3(math.cos(rot) * radius, 0, -math.sin(rot) * radius)
			--end
		end
		if math.random() < 0.5 then
			inst.nextATcannon = true
			inst.nextATtackle = false
			inst.components.combat:SetRange(20)
		else
			inst.nextATcannon = false
			inst.nextATtackle = true
			inst.components.combat:SetRange(10)
		end
	end,

	onupdate = function(inst)
		if inst.sg.statemem.target then
			if inst.sg.statemem.target:IsValid() then
				local rot = inst.Transform:GetRotation()
				local rot1 = inst:GetAngleToPoint(inst.sg.statemem.target.Transform:GetWorldPosition())
				if DiffAngle(rot, rot1) < 60 then
					inst.Transform:SetRotation(rot1)
				end
			else
				inst.sg.statemem.target = nil
			end
		end
	end,

	timeline =
	{
		FrameEvent(5, function(inst)
			inst.sg.statemem.target = nil
			local ipos = inst:GetPosition()
			local target_pos = inst.sg.statemem.target_pos
			if target_pos == nil then
				local angle = inst.Transform:GetRotation() * DEGREES
				target_pos = ipos + Vector3(OFFSET * math.cos(angle), 0, -OFFSET * math.sin(angle))
			end
			SpawnBeam(inst, target_pos)
		end),
		CommonHandlers.OnNoSleepFrameEvent(32, function(inst)
			inst.sg:RemoveStateTag("nosleep")
			inst.sg:AddStateTag("caninterrupt")
		end),
		FrameEvent(38, function(inst)
			inst.sg:RemoveStateTag("busy")
		end),
	},

	events =
	{
		EventHandler("animover", function(inst)
			if inst.AnimState:AnimDone() then
				inst.components.combat:SetDefaultDamage(TUNING.DAYWALKER_DAMAGE)
				inst.sg:GoToState("idle")
			end
		end),
	},
})

-- 扔垃圾球动画加快
local function updateattackspeed(sg)
    for _, state in pairs(sg.states) do
        if state and not state.upanim2hm and (state.name == "throw_pre" or state.name == "throw_loop" or state.name == "throw" or state.name == "throw_pst") then
            state.upanim2hm = true
            local onenter = state.onenter
            state.onenter = function(inst, ...)
                onenter(inst, ...)
                if inst.sg.currentstate == state then
                    if not inst.defeated and inst.hostile then
                        SpeedUpState2hm(inst, state, 3.5)
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
AddStategraphPostInit("daywalker2", function(sg)
	if sg.states and sg.states.rummage then
		local state = sg.states.rummage
		local onenter = state.onenter
		state.onenter = function(inst, data, ...)
			onenter(inst, data, ...)
			if data and data.loot and data.loot == "ball" then
				SpeedUpState2hm(inst, state, 5)
			end
		end
		local onexit = state.onexit
		state.onexit = function(inst, ...)
			if onexit then onexit(inst, ...) end
			RemoveSpeedUpState2hm(inst, state, true)
		end
	end
	updateattackspeed(sg)
end)
-- 扔垃圾别再生成垃圾球了
local COLLAPSIBLE_WORK_ACTIONS =
{
	CHOP = true,
	DIG = true,
	HAMMER = true,
	MINE = true,
}
local COLLAPSIBLE_TAGS = { "_combat", "pickable", "NPC_workable" }
for k, v in pairs(COLLAPSIBLE_WORK_ACTIONS) do
	table.insert(COLLAPSIBLE_TAGS, k.."_workable")
end
-- 2025.8.2 melon:不打发条"chess"
local NON_COLLAPSIBLE_TAGS = { "FX", --[["NOCLICK",]] "DECOR", "INLIMBO", "junkmob", "chess" }
local AOE_RADIUS = 1.5
local PHYSICS_PADDING = 3

local function DoDamage(inst, targets)
	local combat = inst.attacker and inst.attacker:IsValid() and inst.attacker.components.combat or inst.components.combat
	local restoredmg = combat.defaultdamage
	local restorepdp = combat.playerdamagepercent
	combat:SetDefaultDamage(TUNING.JUNK_FALL_DAMAGE)
	combat.playerdamagepercent = nil
	combat.ignorehitrange = true

	local x, y, z = inst.Transform:GetWorldPosition()
	local ents = TheSim:FindEntities(x, 0, z, AOE_RADIUS + PHYSICS_PADDING, nil, NON_COLLAPSIBLE_TAGS, COLLAPSIBLE_TAGS)
	for i, v in ipairs(ents) do
		if targets[v] == nil and v ~= inst.attacker and
			v:IsValid() and not v:IsInLimbo() and
			not (v.components.health and v.components.health:IsDead())
		then
			local r = AOE_RADIUS + v:GetPhysicsRadius(0.5)
			local x1, y1, z1 = v.Transform:GetWorldPosition()
			if distsq(x, z, x1, z1) < r * r then
				local isworkable = false
				if v.components.workable then
					local work_action = v.components.workable:GetWorkAction()
					--V2C: nil action for NPC_workable (e.g. campfires)
					isworkable =
						(   work_action == nil and v:HasTag("NPC_workable")    ) or
						(   work_action and
							v.components.workable:CanBeWorked() and
							COLLAPSIBLE_WORK_ACTIONS[work_action.id] and
							(   work_action ~= ACTIONS.DIG or
								not (v.components.spawner or v.components.childspawner)
							)
						)
				end
				if isworkable then
					v.components.workable:Destroy(inst)
					targets[v] = "worked"
					if inst.formpile and v:IsValid() and v:HasTag("stump") then
						v:Remove()
					end
				elseif v.components.pickable and v.components.pickable:CanBePicked() and not v:HasTag("intense") then
					v.components.pickable:Pick(inst)
					targets[v] = "picked"
				elseif combat:CanTarget(v) then
					if v.components.inventory and v.components.inventory:EquipHasTag("junk") then
						combat.externaldamagemultipliers:SetModifier(inst, 0, "junkabsorbed")
						combat:DoAttack(v)
						combat.externaldamagemultipliers:RemoveModifier(inst, "junkabsorbed")
					else
						combat:DoAttack(v)
					end
					targets[v] = "attacked"
				end
			end
		end
	end

	combat.ignorehitrange = false
	combat.playerdamagepercent = restorepdp
	combat:SetDefaultDamage(restoredmg)

	if targets.pile and math.random() < inst.pileupchance and targets.pile:IsValid() and targets.pile.components.workable and targets.pile.components.workable:CanBeWorked() then
		targets.pile.components.workable:WorkedBy(inst, 0)
	end

	local totoss = TheSim:FindEntities(x, 0, z, AOE_RADIUS + PHYSICS_PADDING, { "_inventoryitem" }, { "locomotor", "INLIMBO" })
	for i, v in ipairs(totoss) do
		local rsq = AOE_RADIUS + v:GetPhysicsRadius(.5)
		rsq = rsq * rsq
		local x1, y1, z1 = v.Transform:GetWorldPosition()
		local dx, dz = x1 - x, z1 - z
		local dsq = dx * dx + dz * dz
		if dsq < rsq and y1 < 0.2 then
			if v.components.mine then
				v.components.mine:Deactivate()
			end
			if not v.components.inventoryitem.nobounce and v.Physics and v.Physics:IsActive() then
				local angle
				if dsq > 0 then
					local dist = math.sqrt(dsq)
					angle = math.atan2(dz / dist, dx / dist) + (math.random() * 20 - 10) * DEGREES
				else
					angle = PI2 * math.random()
				end
				local sina, cosa = math.sin(angle), math.cos(angle)
				local speed = 2.25 - dsq / rsq + math.random()
				v.Physics:Teleport(x1, .1, z1)
				v.Physics:SetVel(cosa * speed, speed * 2 + math.random() * 2, sina * speed)
			end
		end
	end
end
local FALL_TIME = 0.5
local JUNK_PILE_TAGS = { "junk_pile", "junk_pile_big", "wall" }
local function UpdateFallPos(inst, dt)
	if inst:IsAsleep() then
		return
	end
	dt = dt * TheSim:GetTimeScale()
	inst.t = inst.t + dt
	if inst.t < FALL_TIME then
		inst.x = inst.x + inst.speedx * dt
		inst.z = inst.z + inst.speedz * dt
		inst.Transform:SetPosition(inst.x, 0, inst.z)
	else
		inst.Transform:SetPosition(inst.x1, 0, inst.z1)
		inst.components.updatelooper:RemoveOnWallUpdateFn(UpdateFallPos)
		local targets = inst.targets or {}
		DoDamage(inst, targets)

		if TheWorld.Map:IsOceanAtPoint(inst.x1, 0, inst.z1) then
			SpawnPrefab("splash_green_large").Transform:SetPosition(inst.x1, 0, inst.z1)
		elseif inst.formpile then
			local blocked = false
			for i, v in ipairs(TheSim:FindEntities(inst.x1, 0, inst.z1, 5, nil, nil, JUNK_PILE_TAGS)) do
				if v:HasTag("junk_pile_big") then
					blocked = true
					break
				end
				local dsq = v:GetDistanceSqToPoint(inst.x1, 0, inst.z1)
				if v:HasTag("wall") then
					local range = v:GetPhysicsRadius(0) + 1.5
					if dsq < range * range then
						blocked = true
						break
					end
				else--if v:HasTag("junk_pile") then --can assume this is true
					if dsq < 6.25 then
						blocked = true
						break
					end
				end
			end
			if not blocked then
				for k, v in pairs(targets) do
					if v == "worked" then
						if k:IsValid() and k:HasTag("stump") then
							k:Remove()
						end
					elseif v == "attacked" then
						local strengthmult = (k.components.inventory and k.components.inventory:ArmorHasTag("heavyarmor") or k:HasTag("heavybody")) and 0.6 or 1
						k:PushEvent("knockback", { knocker = inst, radius = AOE_RADIUS, strengthmult = strengthmult, forcelanded = true })
					end
				end
			end
		end
	end
end

local function newSetupJunkFall(inst, attacker, x, z, x1, z1, formpile, pileupchance, targets)
	inst.attacker = attacker
	inst.formpile = formpile
	inst.pileupchance = pileupchance
	inst.targets = targets

	inst.Transform:SetPosition(x, 0, z)
	inst.t = 0
	inst.x, inst.z = x, z
	inst.x1, inst.z1 = x1, z1
	inst.speedx = (x1 - x) / FALL_TIME
	inst.speedz = (z1 - z) / FALL_TIME
	inst.components.updatelooper:AddOnWallUpdateFn(UpdateFallPos)
end

AddPrefabPostInit("junkball_fall_fx", function(inst)
	if not TheWorld.ismastersim then return end
	inst.SetupJunkFall = newSetupJunkFall
end)

-- 拾荒疯猪掉落奖励相关配套改动
-- 禁用原版拾荒尖帽掉落方式
AddPrefabPostInit("daywalker2_spike_loot_fx", function(inst)
	if not TheWorld.ismastersim then return end
	if inst.loot then
		inst.loot = nil
	end
end)

-- 添加新配方
STRINGS.RECIPE_DESC.SCRAP_MONOCLEHATP2G = TUNING.isCh2hm and "洞察一切！" or "Insight Into Everything!"
STRINGS.RECIPE_DESC.WAGPUNK_BITSP2G = TUNING.isCh2hm and "金属碎片。" or "Bits Of Metal"
AddRecipe2("wagpunk_bits", {Ingredient("gears", 1), Ingredient("trinket_6", 1)}, TECH.LOST,
		   {product = "wagpunk_bits", numtogive = 2, image = "wagpunk_bits.tex", description = "wagpunk_bitsp2g"},
		   {"REFINE"})

AddRecipe2("scrap_monoclehat", {Ingredient("wagpunk_bits", 2), Ingredient("transistor", 1), Ingredient("trinket_6", 1)}, TECH.LOST,
		   {product = "scrap_monoclehat", numtogive = 1, image = "scrap_monoclehat.tex", description = "scrap_monoclehatp2g" },
		   {"CLOTHING"})
		   
-- 优化掉落奖励
local newloots ={
	-- 新增掉落
	"wagpunkbits_kit",
	"wagpunkbits_kit",
	"wagpunkbits_kit",
	"wagpunkbits_kit",
	"wagpunkbits_kit",
	"scraphat",
	"scrap_monoclehat",
	"chestupgrade_stacksize",
	-- 新增蓝图
	"wagpunk_bits_blueprint",
	"scrap_monoclehat_blueprint",
	"wagpunkbits_kit_blueprint",
	"chestupgrade_stacksize_blueprint",
}

-- 月后掉落
local lunar_shadow_items = GetModConfigData("lunar shadow items")
local afterlunarloot = {
	"wagpunkhat_blueprint",
	"armorwagpunk_blueprint",
	"wagpunkhat",
	"armorwagpunk",
}
-- 仅开启月亮裂隙才掉落瓦套蓝图和套装
-- local function lootsetfn(lootdropper)
-- 	if TheWorld.components.riftspawner and TheWorld.components.riftspawner:GetLunarRiftsEnabled() then
-- 		lootdropper:AddRandomLoot("wagpunkhat_blueprint", 1)
-- 		lootdropper:AddRandomLoot("armorwagpunk_blueprint", 1)
-- 		lootdropper:AddRandomLoot("wagpunkhat", 1)
-- 		lootdropper:AddRandomLoot("armorwagpunk", 1)
-- 	end
-- 	lootdropper.numrandomloot = 1
-- end
AddPrefabPostInit("daywalker2", function(inst)
	if not TheWorld.ismastersim then return end
	if inst.components.lootdropper then
		local loot = inst.components.lootdropper.loot 
		if loot == nil then
			inst.components.lootdropper.loot = newloots
		elseif loot ~= nil then
			for i, v in pairs(newloots) do
				if v ~= "wagpunkbits_kit" and not table.contains(loot,v) or v == "wagpunkbits_kit" then
					table.insert(loot,v)
				end
			end
		end
		local oldlootsetupfn = inst.components.lootdropper.lootsetupfn
		inst.components.lootdropper.lootsetupfn = function(lootdropper, ...)
			oldlootsetupfn(lootdropper, ...)
			if lootdropper.randomloot ~= nil then
				for i, v in ipairs(lootdropper.randomloot) do 
					if v.prefab == "wagpunkbits_kit_blueprint" or v.prefab == "chestupgrade_stacksize_blueprint" then
						table.remove(lootdropper.randomloot, i)
					end
				end
			end
		end
		local oldgenerateloot = inst.components.lootdropper.GenerateLoot
		inst.components.lootdropper.GenerateLoot = function(self, ...)
			local loots = oldgenerateloot(self, ...)
			if TheWorld.components.riftspawner then
				if TheWorld.components.riftspawner:GetLunarRiftsEnabled() then
					for i, v in pairs(afterlunarloot) do
						if not table.contains(loots,v) then
							table.insert(loots,v)
						end
					end
				elseif lunar_shadow_items and not TheWorld.components.riftspawner:GetLunarRiftsEnabled() then
					local _loots = {}
					for i, v in pairs(loots) do
						if v and not table.contains(afterlunarloot,v) then
							table.insert(_loots, v)
						end
					end
					loots = _loots
				end
			end
			return loots
		end
	end
end)
