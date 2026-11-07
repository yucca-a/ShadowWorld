-- Merged from original Workshop 2886753796 v2.8.14.112 (2026-11-07).
-- Original authors and MulanPSL-2.0 license retained; loaded only by its mode switch.
-- ============================================================
-- AI_zhizao_shichang.lua
-- 制造（BUILD）时长按配方复杂度计算，并显示环形进度条。
-- 淬炼版：仅在「贝爷求生」总开关开启时加载。
-- ============================================================

-- ============================================================
-- 制造时长按配方复杂度计算 + 环形进度条
--   原版：ACTIONS.BUILD 的 ActionHandler 返回 "dolongaction"，时长固定 1 秒，
--         而 dolongaction.onenter(inst, timeout) 支持自定义时长，
--         并且当 bufferedaction.action.actionmeter 为真时会调用 StartActionMeter(inst, timeout)
--         画一个环形进度（其它玩家也能看到，靠 player_classified 的 actionmeter 同步）。
--   这里：按「材料种类 / 材料总量 / 科技等级」算时长，并给 BUILD 打开 actionmeter。
-- ============================================================

---- 时长公式参数（上限 25.5 秒）
local ZHIZAO_JICHU = 3.5        ---- 基础秒数
local ZHIZAO_MEIZHONG = 1.35    ---- 每种材料 +1.35 秒
local ZHIZAO_MEIDANWEI = 0.20   ---- 每 1 个材料总量 +0.20 秒
local ZHIZAO_MEIKEJI = 0.5      ---- 每 1 级科技要求 +0.5 秒
---- 上限：25.5 秒。进度条时长走 player_classified.actionmetertime（255/10），
---- 超过它进度圈会和动作不同步，所以这里对齐到该最大值
local ZHIZAO_SHANGXIAN = 25.5
---- 制造时长总体减半:总时长 ×0.5
local ZHIZAO_ZONGBEILV = 0.5

---- 建造护符加速系数：+50% 速率 → 时长 ÷1.5
local JIANZAOHUFU_JIASU = 1.5

---- 熟练度(随机耐久的制造次数表 ray_zhizao_manufactured_items):次数越多,制造越快
local SHULIAN_MEICI = 0.005     ---- 每 1 熟练点(制造1次=+3点)时长 -0.5%
local SHULIAN_SHANGXIAN = 0.5   ---- 熟练缩减上限 50%

---- 玩家是否装备了建造护符（绿护符 greenamulet）
---- ① 主判定与「制造页面那个绿护符图标」同源：builder.ingredientmod < 1
----    （戴建造护符时被设成 0.5，UI 就是靠这个值画图标的）
---- ② 再退到护符槽 / 装备栏 / 折扣系数兜底
local function you_jianzaohufu(inst)
	if inst == nil or inst.components == nil then
		return false
	end

	local jianzao = inst.components.builder
	if jianzao ~= nil and type(jianzao.ingredientmod) == "number" and jianzao.ingredientmod < 1 then
		return true
	end

	if EQUIPSLOTS ~= nil and TUNING ~= nil and jianzao ~= nil
		and jianzao.ingredientmod == TUNING.GREENAMULET_INGREDIENTMOD then
		return true
	end

	local bei = inst.components.inventory
	if bei == nil then
		return false
	end

	---- 直接看护符槽
	if EQUIPSLOTS ~= nil and EQUIPSLOTS.NECK ~= nil then
		local guazhe = bei:GetEquippedItem(EQUIPSLOTS.NECK)
		if guazhe ~= nil and guazhe.prefab == "greenamulet" then
			return true
		end
	end
	if bei.equipslots ~= nil then
		for _, v in pairs(bei.equipslots) do
			if v ~= nil and v.prefab == "greenamulet" then
				return true
			end
		end
	end
	return false
end

---- 监听那个信号本身：
----   客户端 UI 读的是 player_classified.ingredientmod（由 builder.ingredientmod 同步过去），
----   任何来源（护符、模组物品、角色特性）改变折扣都会触发 "ingredientmoddirty"。
----   这里把当前折扣系数缓存到玩家身上，方便其它系统复用 / 排查。
AddPrefabPostInit("player_classified", function(inst)
	if inst.ingredientmod == nil then
		return
	end

	local function shuaxin()
		local wanjia = inst.entity ~= nil and inst.entity:GetParent() or nil
		if wanjia == nil then
			return
		end
		local zhi = nil
		if INGREDIENT_MOD_LOOKUP ~= nil then
			zhi = INGREDIENT_MOD_LOOKUP[inst.ingredientmod:value()]
		end
		wanjia.ray_zhizao_kouzhi = zhi
	end

	inst:ListenForEvent("ingredientmoddirty", shuaxin)
	inst:DoTaskInTime(0, shuaxin)
end)

---- 根据当前缓冲动作里的配方算时长
local function ray_zhizao_shichang(inst)
	local dongzuo = inst ~= nil and inst.bufferedaction or nil
	if dongzuo == nil or dongzuo.recipe == nil then
		return ZHIZAO_JICHU
	end
	local peifang = GetValidRecipe(dongzuo.recipe)
	if peifang == nil then
		return ZHIZAO_JICHU
	end

	local zhonglei, zongliang = 0, 0
	if type(peifang.ingredients) == "table" then
		for _, cailiao in ipairs(peifang.ingredients) do
			if cailiao ~= nil then
				zhonglei = zhonglei + 1
				zongliang = zongliang + (type(cailiao.amount) == "number" and cailiao.amount or 1)
			end
		end
	end

	local keji = 0
	if type(peifang.level) == "table" then
		for _, v in pairs(peifang.level) do
			if type(v) == "number" and v > 0 then
				keji = keji + v
			end
		end
	end

	local shichang = (ZHIZAO_JICHU
		+ zhonglei * ZHIZAO_MEIZHONG
		+ zongliang * ZHIZAO_MEIDANWEI
		+ keji * ZHIZAO_MEIKEJI) * ZHIZAO_ZONGBEILV

	---- 熟练度 + 绿符 合计缩减(加性,封顶 50%):
	----   熟练满(-50%)、绿符(÷1.5 ≈ -33.3%) 加进同一个缩减槽,
	----   配合总体减半 ×0.5 → 制造时间最终剩 25%
	local jianshao = 0

	if inst ~= nil and inst.ray_zhizao_manufactured_items ~= nil then
		local chanwu = peifang.name or dongzuo.recipe
		local shulian = type(chanwu) == "string" and inst.ray_zhizao_manufactured_items[chanwu] or nil
		if type(shulian) == "number" and shulian > 0 then
			jianshao = jianshao + math.min(shulian * SHULIAN_MEICI, SHULIAN_SHANGXIAN)
		end
	end

	if you_jianzaohufu(inst) then
		jianshao = jianshao + (1 - 1 / JIANZAOHUFU_JIASU)
	end

	jianshao = math.min(jianshao, 0.5)
	shichang = shichang * (1 - jianshao)

	if shichang < 1 then
		shichang = 1                       ---- 再快也不低于 1 秒
	elseif shichang > ZHIZAO_SHANGXIAN then
		shichang = ZHIZAO_SHANGXIAN        ---- 与进度条上限一致，避免不同步
	end
	return shichang
end

---- 让 BUILD 动作打开环形进度条
if ACTIONS ~= nil and ACTIONS.BUILD ~= nil then
	ACTIONS.BUILD.actionmeter = true
end

---- 服务器端状态：转发到 dolongaction，带按配方算出来的时长
AddStategraphState("wilson", State{
	name = "ray_manzuozhizao",
	tags = { "doing", "busy", "nodangle", "keep_pocket_rummage" },
	onenter = function(inst)
		inst.sg:GoToState("dolongaction", ray_zhizao_shichang(inst))
	end,
})

---- 客户端预测状态：同名状态转发原版 dolongaction（真实时长由服务器驱动，进度条靠 netvar 同步）
AddStategraphState("wilson_client", State{
	name = "ray_manzuozhizao",
	tags = { "doing", "busy" },
	server_states = { "ray_manzuozhizao" },
	onenter = function(inst)
		inst.sg:GoToState("dolongaction")
	end,
})

---- 两边都把 BUILD 指向新状态；配方自带 sg_state 的仍然优先
local function ray_zhizao_zhuangtai(inst, action)
	local peifang = GetValidRecipe(action.recipe)
	local zidingyi = peifang ~= nil and FunctionOrValue(peifang.sg_state, peifang, inst) or nil
	if zidingyi ~= nil then
		return zidingyi
	end
	return "ray_manzuozhizao"
end

AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.BUILD, ray_zhizao_zhuangtai))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.BUILD, ray_zhizao_zhuangtai))
