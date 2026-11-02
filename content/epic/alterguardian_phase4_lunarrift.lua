-----------------------------------------------------------------------
--              天体后裔（Yefeng版本）影子系统 - 完整强化方案
--              alterguardian_phase4_lunarrift Enhancement System
-----------------------------------------------------------------------
-- 功能：
-- 1. 影子独立AI
-- 2. 本体与影子共享血量
-- 3. 技能状态同步
-- 4. 可扩展的技能框架
-- 5. 冲刺时持续喷射冷火效果
-- 6. 本体裂隙60秒后消失
-- 7. 影子重击释放「暗影雷狱」替代裂隙
-----------------------------------------------------------------------

local brainYf = require("brains/alterguardian_phase4_lunarriftbrainYf")

-- HappyPatch 的 BOSS 血量倍率是通过 health:SetMaxHealth 包装器生效的。
-- 这里主动 SetMaxHealth 时会被再乘一次，所以先除掉该倍率，避免 16 倍变 32 倍。
local function GetBossHealthMult2hm()
    if not GetModConfigData("extra_change") then return 1 end
    local mult = GetModConfigData("boss_health")
    return type(mult) == "number" and mult > 0 and mult or 1
end

-----------------------------------------------------------------------
-- 1. 技能配置表
-----------------------------------------------------------------------
local SKILL_CONFIG = {
	-- 冷火配置
	COLDFIRE = {
		SPAWN_PERIOD = 4 * FRAMES, -- 冷火生成周期（降低密度）
		DISTANCES = { 4, 8, 12 }, -- 冷火生成距离（3层）
		ROWS = 3,            -- 喷射排数
		SPREAD_ANGLE = 30,   -- 扇形角度
		DAMAGE = 5,          -- 冷火伤害
		PLANAR_DAMAGE = 2.5, -- 冷火位面伤害
	},

	-- 裂隙配置
	FISSURE = {
		LIFETIME = 40, -- 本体裂隙存在时间（秒）
	},

	-- 雷电配置
	LIGHTNING = {
		COUNT = 15,        -- 雷电数量（每排）
		ROWS = 12,         -- 排数（扇形扩散）
		MIN_DIST = 3,      -- 最小距离
		MAX_DIST = 60,     -- 最大距离
		DELAY_PER_DIST = 0.0125, -- 每单位距离的延迟（秒）
		SPREAD_ANGLE = 120, -- 扇形角度（扩大覆盖范围）
		DAMAGE_NEAR = 100, -- 近距离位面伤害（翻倍）
		DAMAGE_FAR = 50,   -- 远距离位面伤害（翻倍）
		HIT_RANGE = 2,     -- 雷电命中范围
	},

	-- 预判配置
	PREDICTION = {
		SLAM_PREDICT_TIME = 1.5, -- 重击/雷狱预判时间（秒）
		MAX_PREDICT_DISTANCE = 25, -- 最大预判距离
	},

	-- 技能解锁阈值配置
	THRESHOLDS = {
		{ percent = 0.95, name = "phase1" },
		{ percent = 0.75, name = "phase2" },
		{ percent = 0.65, name = "phase3" },
	},

	-- 技能参数配置（根据血量百分比）
	PHASE_PARAMS = {
		phase1 = {
			-- 第一阶段（95% - 100%）
			dashcombo = 1,
			dashrnd = false,
			dashcenter = false,
			slamcombo = nil,
			slamrnd = false,
			cansupernova = false,
		},
		phase2 = {
			-- 第二阶段（75% - 95%）
			dashcombo = 2,
			dashrnd = false,
			dashcenter = false,
			slamcombo = 1,
			slamrnd = false,
			cansupernova = false,
		},
		phase3 = {
			-- 第三阶段（65% - 75%）
			dashcombo = 2,
			dashrnd = false,
			dashcenter = false,
			slamcombo = 2,
			slamrnd = false,
			cansupernova = false,
		},
		phase4 = {
			-- 第四阶段（0% - 65%）
			dashcombo = 2,
			dashrnd = true,
			dashcenter = true,
			slamcombo = 2,
			slamrnd = true,
			cansupernova = true,
		},
	},
}

-- 根据血量百分比获取阶段
local function GetPhaseByHealth(healthpct)
	if healthpct <= 0.65 then
		return "phase4"
	elseif healthpct <= 0.75 then
		return "phase3"
	elseif healthpct <= 0.95 then
		return "phase2"
	else
		return "phase1"
	end
end

-----------------------------------------------------------------------
-- 1.5 目标位置预判系统
-----------------------------------------------------------------------

-- 获取目标的预测位置
local function GetPredictedPosition(inst, target, predict_time)
	if not (target and target:IsValid()) then
		return nil
	end

	local tx, ty, tz = target.Transform:GetWorldPosition()

	-- 如果目标有移动组件且是玩家，进行预判
	if target.components.locomotor and target:HasTag("player") then
		-- 使用实际速度方向（而不是面朝方向），面朝boss时不会反向预判
		local vx, vy, vz = target.Physics:GetVelocity()
		local actual_speed = math.sqrt(vx * vx + vz * vz)

		-- 只有实际移动时才预判（速度 > 1.5 避免微小抖动）
		if actual_speed > 1.5 then
			local config = SKILL_CONFIG.PREDICTION
			local predict_dist = math.min(actual_speed * predict_time, config.MAX_PREDICT_DISTANCE)

			-- 用速度方向计算预测位置
			local vx_norm = vx / actual_speed
			local vz_norm = vz / actual_speed
			tx = tx + vx_norm * predict_dist
			tz = tz + vz_norm * predict_dist
		end
	end

	return tx, ty, tz
end

-- 计算朝向目标位置的角度（弧度）
local function GetAngleToPosition(inst, tx, tz)
	local x, y, z = inst.Transform:GetWorldPosition()
	local dx = tx - x
	local dz = tz - z
	return math.atan2(-dz, dx)
end

-- 获取预判角度（用于技能释放）
local function GetPredictedAngle(inst, predict_time)
	local target = inst.components.combat and inst.components.combat.target

	if target and target:IsValid() then
		local tx, ty, tz = GetPredictedPosition(inst, target, predict_time)
		if tx then
			return GetAngleToPosition(inst, tx, tz)
		end
	end

	-- 如果无法预判，使用当前朝向
	return inst.Transform:GetRotation() * DEGREES
end

-- 获取预判位置（Vector3格式，用于直接使用）
local function GetPredictedPositionVector(inst, target, predict_time)
	if not (target and target:IsValid()) then
		return nil
	end

	local tx, ty, tz = GetPredictedPosition(inst, target, predict_time)
	if tx then
		return Vector3(tx, ty, tz)
	end

	return target:GetPosition()
end

-----------------------------------------------------------------------
-- 2. 血量共享系统
-----------------------------------------------------------------------

-- 设置技能解锁参数
local function ApplySkillParams(target, phase)
	local params = SKILL_CONFIG.PHASE_PARAMS[phase]
	if not params then return end

	target.dashcombo = params.dashcombo
	target.dashrnd = params.dashrnd
	target.dashcenter = params.dashcenter
	target.slamcombo = params.slamcombo
	target.slamrnd = params.slamrnd
	target.cansupernova = params.cansupernova

	-- 初始化计数器（如果不存在）
	if target.dashcount == nil then target.dashcount = 0 end
	if target.slamcombo and target.slamcount == nil then target.slamcount = 0 end
end

-- 同步所有影子的血量
local function SyncShadowsHealth(parent)
	if not (parent.components.childspawner2hm and parent.components.health) then return end

	local healthpct = parent.components.health:GetPercent()

	if parent.components.childspawner2hm.childrenoutside then
		for k, child in pairs(parent.components.childspawner2hm.childrenoutside) do
			if child and child:IsValid() and child:HasTag("swc2hm") and child.components.health then
				-- 同步血量百分比
				child._syncing_health = true
				child.components.health:SetPercent(healthpct)
				child._syncing_health = false
			end
		end
	end
end

-- 设置本体到影子的血量同步
local function SetupParentToShadowHealthSync(parent)
	if not parent.components.health then return end

	parent:ListenForEvent("healthdelta", function(inst, data)
		if inst._syncing_health then return end
		SyncShadowsHealth(inst)
	end)
end

-- 设置影子到本体的血量同步
local function SetupShadowToParentHealthSync(child, parent)
	if not (child.components.health and parent.components.health) then return end

	child:ListenForEvent("healthdelta", function(child, data)
		if child._syncing_health or not parent:IsValid() or not parent.components.health then return end

		-- 影子受伤，本体同步扣血
		local damage = data.oldpercent - data.newpercent
		if damage > 0 then
			parent._syncing_health = true
			parent.components.health:DeltaPenalty(damage)
			parent._syncing_health = false

			-- 同步给其他影子
			SyncShadowsHealth(parent)
		end
	end)
end

-----------------------------------------------------------------------
-- 3. 技能状态同步系统
-----------------------------------------------------------------------

-- 同步单个实体的技能状态
local function SyncSkillState(target, healthpct)
	local phase = GetPhaseByHealth(healthpct)
	ApplySkillParams(target, phase)
end

-- 同步所有影子的技能状态
local function SyncAllShadowsSkills(parent)
	if not (parent.components.childspawner2hm and parent.components.health) then return end

	local healthpct = parent.components.health:GetPercent()

	-- 同步本体
	SyncSkillState(parent, healthpct)

	-- 同步所有影子
	if parent.components.childspawner2hm.childrenoutside then
		for k, child in pairs(parent.components.childspawner2hm.childrenoutside) do
			if child and child:IsValid() and child:HasTag("swc2hm") then
				SyncSkillState(child, healthpct)
			end
		end
	end
end

-----------------------------------------------------------------------
-- 4. 冷火喷射系统
-----------------------------------------------------------------------

-- 冷火伤害目标（无僵直，持续检测）
local COLDFIRE_TARGET_TAGS = { "_combat" }
local COLDFIRE_CANT_TAGS = { "INLIMBO", "invisible", "notarget", "noattack", "flight", "playerghost", "shadow",
	"shadowcreature", "shadowminion", "shadowchesspiece" }
local COLDFIRE_HIT_RANGE = 3
local COLDFIRE_DURATION = 1       -- 持续检测时间
local COLDFIRE_CHECK_INTERVAL = 1 -- 检测间隔（1秒检测一次）

local function DoColdFireDamage(attacker, fx_x, fx_z, hit_targets)
	local config = SKILL_CONFIG.COLDFIRE

	-- 查找范围内的目标
	local targets = TheSim:FindEntities(fx_x, 0, fx_z, COLDFIRE_HIT_RANGE, COLDFIRE_TARGET_TAGS, COLDFIRE_CANT_TAGS)

	for _, target in ipairs(targets) do
		-- 排除施法者自身
		if target == attacker then
			-- 跳过自己
			-- 排除同类（相同prefab，如本体与影子都是alterguardian_phase4_lunarrift）
		elseif target.prefab == attacker.prefab then
			-- 跳过同类
			-- 排除本体与影子之间的互相伤害
		elseif target:HasTag("swc2hm") and attacker.swp2hm == target then
			-- 影子不伤害自己的本体
		elseif attacker:HasTag("swc2hm") and target == attacker.swp2hm then
			-- 影子不伤害自己的本体
		elseif target.components.childspawner2hm and target.components.childspawner2hm.childrenoutside and target.components.childspawner2hm.childrenoutside[attacker] then
			-- 本体不伤害自己的影子
			-- 正常伤害检测
		elseif not hit_targets[target] and target:IsValid() and target.components.health and not target.components.health:IsDead() then
			hit_targets[target] = true
			-- 直接扣血，无僵直效果
			local total_damage = config.DAMAGE + config.PLANAR_DAMAGE
			target.components.health:DoDelta(-total_damage, false, attacker.prefab, false, attacker)
		end
	end
end

-- 生成冷火特效
local function SpawnColdFireFX(inst, dist, angle_offset)
	local base_angle = inst.Transform:GetRotation() * DEGREES
	local angle = base_angle + (angle_offset or 0)
	local x, y, z = inst.Transform:GetWorldPosition()

	-- 在前方指定距离生成冷火
	local fx_x = x + math.cos(angle) * dist
	local fx_z = z - math.sin(angle) * dist

	-- 只生成特效，不使用原版伤害系统
	local fx = SpawnPrefab("warg_mutated_breath_fx")
	if fx then
		fx.Transform:SetPosition(fx_x, 0, fx_z)
	end

	-- 持续检测伤害（不依赖特效状态）
	local hit_targets = {}
	local check_count = math.floor(COLDFIRE_DURATION / COLDFIRE_CHECK_INTERVAL)
	for i = 0, check_count do
		inst:DoTaskInTime(i * COLDFIRE_CHECK_INTERVAL, function()
			if inst:IsValid() then
				DoColdFireDamage(inst, fx_x, fx_z, hit_targets)
			end
		end)
	end

	return fx
end

-- 开始冷火喷射
local function StartColdFireBreath(inst)
	if inst._coldfire_task then return end

	local config = SKILL_CONFIG.COLDFIRE
	local half_spread = math.rad(config.SPREAD_ANGLE / 2)

	inst._coldfire_task = inst:DoPeriodicTask(config.SPAWN_PERIOD, function()
		if not inst:IsValid() then
			if inst._coldfire_task then
				inst._coldfire_task:Cancel()
				inst._coldfire_task = nil
			end
			return
		end

		-- 多排扇形喷射冷火
		for row = 1, config.ROWS do
			local angle_offset = (row - 1) / (config.ROWS - 1) * half_spread * 2 - half_spread
			if config.ROWS == 1 then angle_offset = 0 end

			for _, dist in ipairs(config.DISTANCES) do
				SpawnColdFireFX(inst, dist, angle_offset)
			end
		end
	end)

	-- 播放音效
	if inst.SoundEmitter and not inst.SoundEmitter:PlayingSound("coldfire_loop") then
		inst.SoundEmitter:PlaySound("rifts3/mutated_varg/blast_lp", "coldfire_loop")
	end
end

-- 停止冷火喷射
local function StopColdFireBreath(inst)
	if inst._coldfire_task then
		inst._coldfire_task:Cancel()
		inst._coldfire_task = nil
	end
	if inst.SoundEmitter then
		inst.SoundEmitter:KillSound("coldfire_loop")
	end
end

-----------------------------------------------------------------------
-- 5. 暗影雷狱系统（影子专用）
-----------------------------------------------------------------------

-- 雷电伤害目标（平面伤害，根据距离衰减）
local LIGHTNING_TARGET_TAGS = { "_combat" }
local LIGHTNING_CANT_TAGS = { "INLIMBO", "invisible", "notarget", "noattack", "flight", "playerghost", "shadow",
	"shadowcreature", "shadowminion", "shadowchesspiece" }

local function DoLightningDamage(inst, lightning_x, lightning_z, dist_from_caster)
	local config = SKILL_CONFIG.LIGHTNING

	-- 根据距离计算伤害（近距离高，远距离低）
	local dist_ratio = (dist_from_caster - config.MIN_DIST) / (config.MAX_DIST - config.MIN_DIST)
	dist_ratio = math.max(0, math.min(1, dist_ratio))
	local damage = config.DAMAGE_NEAR - (config.DAMAGE_NEAR - config.DAMAGE_FAR) * dist_ratio

	-- 查找范围内的目标
	local targets = TheSim:FindEntities(lightning_x, 0, lightning_z, config.HIT_RANGE, LIGHTNING_TARGET_TAGS,
		LIGHTNING_CANT_TAGS)

	for _, target in ipairs(targets) do
		if target:IsValid() and target.components.health and not target.components.health:IsDead() then
			-- 平面伤害走combat管线(planardefense正常工作)
			if target.components.combat then
				target.components.combat:GetAttacked_Internal(inst, damage)
			else
				target.components.health:DoDelta(-damage, false, inst.prefab, false, inst)
			end
		end
	end
end

-- 从近至远依次生成雷电（扇形密集分布）
-- predicted_angle: 可选，使用预判角度（弧度）
local function SpawnLightningSequence(inst, predicted_angle)
	local x, y, z = inst.Transform:GetWorldPosition()
	-- 使用预判角度或当前朝向
	local base_angle = predicted_angle or inst.Transform:GetRotation() * DEGREES

	local config = SKILL_CONFIG.LIGHTNING
	local dist_step = (config.MAX_DIST - config.MIN_DIST) / (config.COUNT - 1)
	local half_spread = math.rad(config.SPREAD_ANGLE / 2)

	-- 生成多排扇形雷电
	for row = 1, config.ROWS do
		-- 每排的角度偏移
		local row_angle_offset = (row - 1) / (config.ROWS - 1) * half_spread * 2 - half_spread
		if config.ROWS == 1 then row_angle_offset = 0 end

		for i = 1, config.COUNT do
			local dist = config.MIN_DIST + (i - 1) * dist_step
			local delay = dist * config.DELAY_PER_DIST + (row - 1) * 0.02 -- 每排略微延迟

			inst:DoTaskInTime(delay, function()
				if not inst:IsValid() then return end

				-- 计算雷电位置
				local angle = base_angle + row_angle_offset + (math.random() - 0.5) * 0.1 -- 轻微随机
				local lightning_x = x + math.cos(angle) * dist
				local lightning_z = z - math.sin(angle) * dist

				-- 生成雷电特效
				local lightning = SpawnPrefab("lightning")
				if lightning then
					lightning.Transform:SetPosition(lightning_x, 0, lightning_z)
				end

				-- 造成自定义平面伤害
				DoLightningDamage(inst, lightning_x, lightning_z, dist)
			end)
		end
	end
end

-----------------------------------------------------------------------
-- 6. 本体技能框架
-----------------------------------------------------------------------
local ParentSkills = {
	-- 冲刺时喷射冷火
	OnDashStart = function(inst)
		StartColdFireBreath(inst)
	end,

	OnDashEnd = function(inst)
		StopColdFireBreath(inst)
	end,

	-- 重击技能修改
	OnSlam = function(inst)
		-- 本体保留裂隙生成，但会在60秒后消失
	end,

	-- 超新星技能修改
	OnSupernova = function(inst)
		-- 可在此添加自定义超新星行为
	end,
}

-- 应用本体技能框架
local function ApplyParentSkills(inst)
	inst.alterguardian_skills = inst.alterguardian_skills or {}

	for skill_name, skill_func in pairs(ParentSkills) do
		inst.alterguardian_skills[skill_name] = skill_func
	end
end

-----------------------------------------------------------------------
-- 7. 影子技能框架
-----------------------------------------------------------------------
local ShadowSkills = {
	-- 冲刺时喷射冷火（与本体相同）
	OnDashStart = function(inst)
		StartColdFireBreath(inst)
	end,

	OnDashEnd = function(inst)
		StopColdFireBreath(inst)
	end,

	-- 重击技能：暗影雷狱（替代裂隙）
	-- 释放两次，第一次结束后间隔0.5秒释放第二次
	-- 使用预判角度瞄准玩家预测位置
	OnSlam = function(inst, predicted_angle)
		SpawnLightningSequence(inst, predicted_angle)
		-- 第一次释放耗时约0.89秒 + 0.5秒间隔 = 1.39秒后释放第二次
		-- 第二次使用相同的预判角度（保持一致性）
		inst:DoTaskInTime(0.89 + 0.5, function()
			if inst:IsValid() then
				SpawnLightningSequence(inst, predicted_angle)
			end
		end)
	end,

	-- 超新星技能修改
	OnSupernova = function(inst)
		-- 可在此添加影子自定义超新星行为
	end,
}

-- 应用影子技能框架
local function ApplyShadowSkills(child)
	child.alterguardian_skills = child.alterguardian_skills or {}

	for skill_name, skill_func in pairs(ShadowSkills) do
		child.alterguardian_skills[skill_name] = skill_func
	end
end

-----------------------------------------------------------------------
-- 8. 影子初始化
-----------------------------------------------------------------------
local function swc2hmfn(child)
	local parent = child.swp2hm
	if not parent or not parent:IsValid() then return end

	-- 1. 设置独立AI
	child:SetBrain(brainYf)

	-- 2. 设置血量共享（延迟到本体血量翻倍完成后）
	child:DoTaskInTime(0.2, function(child)
		if not child:IsValid() or not parent:IsValid() then return end

		-- 血量同步：影子 -> 本体
		SetupShadowToParentHealthSync(child, parent)

		-- 等待本体血量翻倍完成后再同步
		-- 本体在 DoTaskInTime(0) 中翻倍，所以 0.2 秒后肯定完成了
		if child.components.health and parent.components.health then
			child._syncing_health = true
			-- 同步本体的最大血量（应该是翻倍后的值）
			local parent_maxhealth = parent.components.health.maxhealth
			child.components.health:SetMaxHealth(parent_maxhealth / GetBossHealthMult2hm())
			-- 同步血量百分比
			child.components.health:SetPercent(parent.components.health:GetPercent())
			child._syncing_health = false

			-- 标记影子已同步血量，防止后续被其他逻辑覆盖
			child._health_synced_from_parent = true
		end
	end)

	-- 3. 初始化技能状态
	if parent.components.health then
		local healthpct = parent.components.health:GetPercent()
		SyncSkillState(child, healthpct)
	end

	-- 4. 添加 ResetCombo 函数（影子需要这个函数）
	child.ResetCombo = function(inst)
		inst.dashcount = inst.dashcount and 0 or nil
		inst.slamcount = inst.slamcount and 0 or nil
	end

	-- 5. 覆盖脱战逻辑（影子不应该独立回满血，血量由本体同步控制）
	-- 移除原版的脱战事件监听
	child:RemoveEventCallback("droppedtarget",
		child.event_listeners and child.event_listeners.droppedtarget and child.event_listeners.droppedtarget[child] and
		child.event_listeners.droppedtarget[child][1])

	-- 取消可能存在的脱战任务
	if child._engagetask then
		child._engagetask:Cancel()
		child._engagetask = nil
	end

	-- 影子脱战时不回血，只重置连招计数
	child:ListenForEvent("droppedtarget", function(inst)
		if inst._engagetask then
			inst._engagetask:Cancel()
			inst._engagetask = nil
		end
		-- 延迟重置连招，但不回血
		inst._engagetask = inst:DoTaskInTime(10, function()
			inst._engagetask = nil
			if inst:IsValid() and inst.ResetCombo then
				inst:ResetCombo()
			end
		end)
	end)

	-- 6. 应用影子技能框架
	ApplyShadowSkills(child)

	-- 7. 双向协作：影子被攻击时通知本体参战
	child:ListenForEvent("attacked", function(inst, data)
		if not parent or not parent:IsValid() then return end
		if not data or not data.attacker then return end

		-- 如果本体没有目标，或者本体已经脱战，则让本体也攻击攻击者
		if parent.components.combat then
			local parent_target = parent.components.combat.target

			-- 本体无目标或目标无效时，设置攻击者为目标
			if not parent_target or not parent_target:IsValid() then
				parent.components.combat:SetTarget(data.attacker)
			end

			-- 如果攻击者是玩家，确保本体进入战斗状态
			if data.attacker:HasTag("player") then
				parent.components.combat:SuggestTarget(data.attacker)
			end
		end
	end)

	-- 8. 基本设置
	child.persists = false
end

-----------------------------------------------------------------------
-- 9. 本体配置
-----------------------------------------------------------------------
AddPrefabPostInit("alterguardian_phase4_lunarrift", function(inst)
	if not TheWorld.ismastersim then return end

	-- 注册影子初始化函数
	inst.swc2hmfn = swc2hmfn

	-- 应用本体技能框架
	ApplyParentSkills(inst)

	-- 血量翻倍（仅本体，影子会从本体同步）
	-- 使用延迟检查确保 swc2hm 标签已设置
	inst:DoTaskInTime(0, function(inst)
		if not inst:IsValid() then return end

		-- 只有非影子（本体）才翻倍血量
		-- 影子有 swc2hm 标签，会在 swc2hmfn 中从本体同步血量
		if not inst:HasTag("swc2hm") and inst.components.health then
			local base_max_health = inst.components.health.maxhealth
			-- 避免重复翻倍（检查是否已经翻倍过）
			if not inst._health_doubled then
				inst._health_doubled = true
				-- 开了多倍血时不再额外翻倍，避免 16 倍变 32 倍；1 倍时保留后裔的 2 倍血特性。
				local health_mult = GetBossHealthMult2hm()
				local double_mult = health_mult > 1 and 1 or 2
				inst.components.health:SetMaxHealth(base_max_health * double_mult / health_mult)
				inst.components.health:SetPercent(1) -- 满血
			end
		end
	end)

	-- 设置血量共享：本体 -> 影子
	SetupParentToShadowHealthSync(inst)

	-- 监听血量变化，同步技能状态
	local last_phase = nil
	inst:ListenForEvent("healthdelta", function(inst, data)
		if not inst.components.health then return end

		local current_phase = GetPhaseByHealth(inst.components.health:GetPercent())

		-- 只在跨越阶段时同步
		if last_phase ~= current_phase then
			inst:DoTaskInTime(0, function(inst)
				if inst:IsValid() then
					SyncAllShadowsSkills(inst)
					last_phase = current_phase
				end
			end)
		end
	end)

	-- 初始化技能状态
	inst:DoTaskInTime(0, function(inst)
		if inst:IsValid() and inst.components.health then
			local healthpct = inst.components.health:GetPercent()
			last_phase = GetPhaseByHealth(healthpct)
			SyncAllShadowsSkills(inst)
		end
	end)

	-- 影子生成时同步状态
	if inst.components.childspawner2hm then
		local old_onspawn = inst.components.childspawner2hm.onspawnfn
		inst.components.childspawner2hm.onspawnfn = function(inst, child, ...)
			if old_onspawn then old_onspawn(inst, child, ...) end

			if child and child:IsValid() and child:HasTag("swc2hm") and inst.components.health then
				-- 同步技能状态
				local healthpct = inst.components.health:GetPercent()
				SyncSkillState(child, healthpct)
			end
		end
	end
end)

-----------------------------------------------------------------------
-- 10. Stategraph Hook - 冷火和暗影雷狱效果
-----------------------------------------------------------------------

-- 影子随机技能选择函数
-- 完全独立于本体的技能系统
local function ShadowRandomAttack(inst, target)
	target = target or inst.components.combat.target
	if not (target and target:IsValid()) then
		return false
	end

	-- 使用影子专属计数器（与本体分离）
	if inst._shadow_dashcount == nil then inst._shadow_dashcount = 0 end
	if inst._shadow_slamcount == nil then inst._shadow_slamcount = 0 end
	if inst._shadow_last_skill == nil then inst._shadow_last_skill = "" end

	-- 使用基于GUID的随机种子，确保与本体不同
	local guid_seed = (inst.GUID or 0) + GetTime() * 1000
	math.randomseed(guid_seed)

	-- 技能权重配置（根据上次技能调整权重，避免连续使用同一技能）
	local skill_weights = {
		dash = 1.0,
		slam = 1.0,
		supernova = 0.5, -- 超新星权重较低
	}

	-- 如果上次使用了某技能，降低其权重（防止重复）
	if inst._shadow_last_skill == "dash" then
		skill_weights.dash = 0.3
	elseif inst._shadow_last_skill == "slam" then
		skill_weights.slam = 0.3
	elseif inst._shadow_last_skill == "supernova" then
		skill_weights.supernova = 0.1
	end

	-- 收集可用技能及其权重
	local available_skills = {}
	local total_weight = 0

	-- 检查超新星是否可用
	if inst.cansupernova and inst.components.timer and not inst.components.timer:TimerExists("supernova_cd") then
		table.insert(available_skills, { name = "supernova", weight = skill_weights.supernova })
		total_weight = total_weight + skill_weights.supernova
	end

	-- 检查冲刺是否可用（使用影子专属计数器）
	if inst.dashcombo and inst._shadow_dashcount < 3 then -- 固定3次上限
		table.insert(available_skills, { name = "dash", weight = skill_weights.dash })
		total_weight = total_weight + skill_weights.dash
	end

	-- 检查重击是否可用（使用影子专属计数器）
	if inst.slamcombo and inst._shadow_slamcount < 3 then -- 固定3次上限
		table.insert(available_skills, { name = "slam", weight = skill_weights.slam })
		total_weight = total_weight + skill_weights.slam
	end

	-- 如果没有可用技能，重置影子专属计数器
	if #available_skills == 0 then
		inst._shadow_dashcount = 0
		inst._shadow_slamcount = 0
		-- 重新收集
		if inst.dashcombo then
			table.insert(available_skills, { name = "dash", weight = skill_weights.dash })
			total_weight = total_weight + skill_weights.dash
		end
		if inst.slamcombo then
			table.insert(available_skills, { name = "slam", weight = skill_weights.slam })
			total_weight = total_weight + skill_weights.slam
		end
	end

	-- 仍然没有可用技能，返回false
	if #available_skills == 0 or total_weight <= 0 then
		return false
	end

	-- 权重随机选择技能
	local roll = math.random() * total_weight
	local selected_skill = nil
	local accumulated = 0

	for _, skill_data in ipairs(available_skills) do
		accumulated = accumulated + skill_data.weight
		if roll <= accumulated then
			selected_skill = skill_data.name
			break
		end
	end

	-- 备选：如果权重选择失败，随机选一个
	if not selected_skill then
		selected_skill = available_skills[math.random(#available_skills)].name
	end

	-- 添加随机延迟（0.1~0.5秒），使影子与本体不同步
	local delay = 0.1 + math.random() * 0.4

	inst:DoTaskInTime(delay, function()
		if not inst:IsValid() or not inst.sg or inst.sg:HasStateTag("busy") then
			return
		end

		-- 再次检查目标
		local attack_target = inst.components.combat and inst.components.combat.target
		if not (attack_target and attack_target:IsValid()) then
			return
		end

		-- 记录本次使用的技能
		inst._shadow_last_skill = selected_skill

		if selected_skill == "supernova" then
			inst.sg:GoToState("supernova")
		elseif selected_skill == "dash" then
			inst._shadow_dashcount = inst._shadow_dashcount + 1
			inst.sg:GoToState("dash_pre", attack_target)
		elseif selected_skill == "slam" then
			inst._shadow_slamcount = inst._shadow_slamcount + 1
			inst.sg:GoToState("taunt", attack_target)
		end
	end)

	return true -- 返回true表示已处理，即使技能延迟执行
end

AddStategraphPostInit("alterguardian_phase4_lunarrift", function(sg)
	-- Hook doattack 事件：影子随机技能选择
	for i, event in ipairs(sg.events) do
		if event.name == "doattack" then
			local old_fn = event.fn
			sg.events[i].fn = function(inst, data)
				-- 影子使用随机技能选择
				if inst:HasTag("swc2hm") and not inst.sg:HasStateTag("busy") then
					if ShadowRandomAttack(inst, data and data.target or nil) then
						return
					end
				end
				-- 本体使用原版逻辑
				return old_fn(inst, data)
			end
			break
		end
	end

	-- Hook dash_loop 状态：冷火喷射
	if sg.states.dash_loop then
		local dash_loop_onenter = sg.states.dash_loop.onenter
		sg.states.dash_loop.onenter = function(inst, ...)
			dash_loop_onenter(inst, ...)
			if inst.alterguardian_skills and inst.alterguardian_skills.OnDashStart then
				inst.alterguardian_skills.OnDashStart(inst)
			end
		end

		local dash_loop_onexit = sg.states.dash_loop.onexit
		sg.states.dash_loop.onexit = function(inst, ...)
			if dash_loop_onexit then dash_loop_onexit(inst, ...) end
			if inst.alterguardian_skills and inst.alterguardian_skills.OnDashEnd then
				inst.alterguardian_skills.OnDashEnd(inst)
			end
		end
	end

	-- Hook slam 状态：动态预判目标位置+ 暗影雷狱（影子）
	if sg.states.slam then
		-- 在 slam 状态进入时初始化预判系统
		local slam_onenter = sg.states.slam.onenter
		sg.states.slam.onenter = function(inst, ...)
			-- 初始化预判角度
			local predict_time = SKILL_CONFIG.PREDICTION.SLAM_PREDICT_TIME
			inst._predicted_slam_angle = GetPredictedAngle(inst, predict_time)

			-- 启用动态跟踪标记
			inst._slam_dynamic_tracking = true

			if slam_onenter then slam_onenter(inst, ...) end
		end

		-- 添加 onupdate 持续更新预判朝向（应对瞬移）
		local slam_onupdate = sg.states.slam.onupdate
		sg.states.slam.onupdate = function(inst, ...)
			-- 如果启用了动态跟踪，持续更新朝向
			if inst._slam_dynamic_tracking then
				local target = inst.components.combat and inst.components.combat.target
				if target and target:IsValid() then
					-- 每帧重新计算预判位置
					local predict_time = SKILL_CONFIG.PREDICTION.SLAM_PREDICT_TIME
					local new_angle = GetPredictedAngle(inst, predict_time)

					-- 更新存储的预判角度
					inst._predicted_slam_angle = new_angle

					-- 实时调整BOSS朝向（平滑转向）
					local current_rot = inst.Transform:GetRotation()
					local target_rot = new_angle / DEGREES
					local diff = math.abs(current_rot - target_rot)

					-- 如果角度差异较大，平滑转向
					if diff > 5 then
						-- 限制每帧最大旋转角度，避免太突兀
						local max_turn = 3 -- 每帧最多转3度
						local delta = target_rot - current_rot

						-- 处理角度循环（-180到180）
						if delta > 180 then
							delta = delta - 360
						elseif delta < -180 then
							delta = delta + 360
						end

						-- 限制旋转速度
						if delta > max_turn then
							delta = max_turn
						elseif delta < -max_turn then
							delta = -max_turn
						end

						inst.Transform:SetRotation(current_rot + delta)
					end
				end
			end

			-- 调用原始 onupdate
			if slam_onupdate then slam_onupdate(inst, ...) end
		end

		-- 在 slam 状态退出时清理预判系统
		local slam_onexit = sg.states.slam.onexit
		sg.states.slam.onexit = function(inst, ...)
			inst._predicted_slam_angle = nil
			inst._slam_dynamic_tracking = nil
			if slam_onexit then slam_onexit(inst, ...) end
		end

		-- Hook timeline 事件
		if sg.states.slam.timeline then
			for i, event in ipairs(sg.states.slam.timeline) do
				-- 找到 frame 59 (76-17) 的事件，这是裂隙生成的时机（也是砸地时刻）
				if event.time == (76 - 17) * FRAMES then
					local old_fn = event.fn
					event.fn = function(inst, ...)
						-- 在释放前的最后一刻再次更新预判角度
						-- 确保即使玩家刚刚瞬移也能追踪
						local target = inst.components.combat and inst.components.combat.target
						if target and target:IsValid() then
							local predict_time = SKILL_CONFIG.PREDICTION.SLAM_PREDICT_TIME
							inst._predicted_slam_angle = GetPredictedAngle(inst, predict_time)
						end

						-- 停止动态跟踪（技能即将释放）
						inst._slam_dynamic_tracking = false

						-- 获取最终预判角度
						local predicted_angle = inst._predicted_slam_angle

						-- 影子：阻止裂隙生成，改为释放暗影雷狱（使用预判角度）
						if inst:HasTag("swc2hm") then
							if inst.alterguardian_skills and inst.alterguardian_skills.OnSlam then
								inst.alterguardian_skills.OnSlam(inst, predicted_angle)
							end
							return
						end

						-- 本体：旋转朝向预判位置后生成裂隙
						if predicted_angle then
							inst.Transform:SetRotation(predicted_angle / DEGREES)
						end
						old_fn(inst, ...)
					end
					break
				end
			end
		end
	end

	-- Hook supernova 状态：影子CD减半
	if sg.states.supernova then
		local supernova_onenter = sg.states.supernova.onenter
		sg.states.supernova.onenter = function(inst, ...)
			supernova_onenter(inst, ...)
			if inst:HasTag("swc2hm") and inst.components.timer then
				local current_cd = inst.components.timer:GetTimeLeft("supernova_cd")
				if current_cd then
					inst.components.timer:SetTimeLeft("supernova_cd", current_cd / 2)
				end
			end
		end
	end

	-- Hook supernova_loop 状态：影子CD减半（备用）
	if sg.states.supernova_loop then
		local supernova_loop_onenter = sg.states.supernova_loop.onenter
		sg.states.supernova_loop.onenter = function(inst, ...)
			supernova_loop_onenter(inst, ...)
			if inst:HasTag("swc2hm") and inst.components.timer then
				local current_cd = inst.components.timer:GetTimeLeft("supernova_cd")
				if current_cd then
					inst.components.timer:SetTimeLeft("supernova_cd", current_cd / 2)
				end
			end
		end
	end
end)

-----------------------------------------------------------------------
-- 11. 裂隙定时消失（本体专用）
-----------------------------------------------------------------------
local WagBossUtil = require("prefabs/wagboss_util")
AddPrefabPostInit("alterguardian_lunar_fissures", function(inst)
	if not TheWorld.ismastersim then return end

	if not inst.task2hm then
		inst.task2hm = inst:DoTaskInTime(SKILL_CONFIG.FISSURE.LIFETIME, function()
			if inst:IsValid() and inst.KillFx and inst._wagpunkarena_fissure_id then
				inst:KillFx()
			end
		end)
	end

	local oldkillfx = inst.KillFx
	inst.KillFx = function(inst, ...)
		if inst.task2hm then
			inst.task2hm:Cancel()
			inst.task2hm = nil
		end
		-- 裂隙已被移除(不在注册表)时原版Despawn重复触发OnRemoveFissure崩溃
		if inst._wagpunkarena_fissure_id and not WagBossUtil.HasFissure(inst._wagpunkarena_fissure_id) then
			return
		end
		oldkillfx(inst, ...)
	end
end)
