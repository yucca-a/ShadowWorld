-- Merged from original Workshop 2886753796 v2.8.14.112 (2026-11-07).
-- Original authors and MulanPSL-2.0 license retained; loaded only by its mode switch.
-- ============================================================
-- AI_dafeiyu.lua
-- 功能一：玩家制造配方所需的材料 ×2
--   1) 加载时，把已有配方（原版 + 本模组）的 ingredients 数量乘上倍率
--   2) 之后再注册的配方（AddRecipe / AddRecipe2）同样会自动翻倍
-- 说明：
--   * 只翻倍 ingredients（制造材料），不动 character_ingredients（生命/精神等代价）
--     也不动 construction_ingredients（放置类建造消耗）
--   * 用 weak 表按「实例」去重，避免同一个 Ingredient 被翻倍两次
--
-- 功能二：没有「烹饪指南」（cookbook）不能烹饪食物
--   * 拦截所有烹饪锅（stewer 组件）的开始烹饪，包括随身锅
--   * 烹饪指南有耐久：最多 5 次，每真正开始烹饪消耗 1 次，用完即毁
-- ============================================================

-- 功能一由配置「材料制造翻倍」控制，默认关闭（关闭时恢复原版材料）
if GetModConfigData("材料制造翻倍") then

local BEILV = 2

---- 已处理过的 Ingredient 实例（weak，随对象回收）
local yichuli = setmetatable({}, { __mode = "k" })

local function fangbei(ingredients)
	if type(ingredients) ~= "table" then
		return
	end
	for _, v in ipairs(ingredients) do
		if type(v) == "table"
			and type(v.amount) == "number"
			and v.amount > 0
			and yichuli[v] == nil then
			v.amount = v.amount * BEILV
			yichuli[v] = true
		end
	end
end

local function fangbei_peifang(recipe)
	if type(recipe) ~= "table" then
		return
	end
	fangbei(recipe.ingredients)
end

local function quanbufangbei()
	local all = GLOBAL.rawget(GLOBAL, "AllRecipes")
	if type(all) ~= "table" then
		return
	end
	for _, recipe in pairs(all) do
		fangbei_peifang(recipe)
	end
end

quanbufangbei()

---- 之后注册的配方也自动翻倍
local function baozhuang_addrecipe(mingzi)
	local yuanshi = GLOBAL.rawget(GLOBAL, mingzi)
	if type(yuanshi) ~= "function" then
		return
	end
	GLOBAL[mingzi] = function(...)
		local jieguo = yuanshi(...)
		if type(jieguo) == "table" then
			if jieguo.ingredients ~= nil then
				fangbei_peifang(jieguo)
			else
				for _, v in ipairs(jieguo) do
					fangbei_peifang(v)
				end
			end
		end
		return jieguo
	end
end

baozhuang_addrecipe("AddRecipe")
baozhuang_addrecipe("AddRecipe2")


end


-- ============================================================
-- 功能二：没有「烹饪指南」（cookbook）不能烹饪食物
--   所有烹饪锅（含随身锅）都用 stewer 组件，这里统一拦截 StartCooking
--   开关：配置「做饭需要书」控制，默认关闭（关闭时恢复原版烹饪）
-- ============================================================

if GetModConfigData("做饭需要书") then

---- 烹饪指南耐久：总共可用 5 次
local KAI_NAIJIU = 5

---- 给原版烹饪指南挂上 finiteuses（自带耐久条）
AddPrefabPostInit("cookbook", function(inst)
	if inst == nil or not TheWorld.ismastersim then
		return inst
	end
	if inst.components.finiteuses == nil then
		inst:AddComponent("finiteuses")
		inst.components.finiteuses:SetMaxUses(KAI_NAIJIU)
		inst.components.finiteuses:SetUses(KAI_NAIJIU)
		---- 用完即毁（不保留 0 耐久的书，避免「还能拿出来看」的错觉）
		inst.components.finiteuses:SetOnFinished(function(inst2)
			if inst2 ~= nil and inst2:IsValid() then
				local fasheng = SpawnPrefab("collapse_small")
				if fasheng ~= nil then
					fasheng.Transform:SetPosition(inst2.Transform:GetWorldPosition())
				end
				inst2:Remove()
			end
		end)
	end
	return inst
end)

---- 找一本「还有耐久」的烹饪指南
local function zhao_pengrenzhinan(wanjia)
	if wanjia == nil or not wanjia:IsValid() then
		return nil
	end
	local beibao = wanjia.components ~= nil and wanjia.components.inventory or nil
	if beibao == nil or beibao.FindItem == nil then
		return nil
	end
	return beibao:FindItem(function(item)
		if item == nil or item.prefab ~= "cookbook" then
			return false
		end
		local nai = item.components ~= nil and item.components.finiteuses or nil
		return nai == nil or nai:GetUses() > 0
	end)
end

AddComponentPostInit("stewer", function(self)
	local yuanshi_startcooking = self.StartCooking
	if type(yuanshi_startcooking) ~= "function" then
		return
	end

	self.StartCooking = function(self, cooker, ...)
		---- cooker 为空（异常调用）时不拦，避免误伤
		if cooker == nil or not cooker:IsValid() then
			return yuanshi_startcooking(self, cooker, ...)
		end

		local shu = zhao_pengrenzhinan(cooker)
		if shu == nil then
			if cooker.components ~= nil and cooker.components.talker ~= nil then
				cooker.components.talker:Say("没有可用的烹饪指南，我可不敢乱动这口锅。")
			end
			return false
		end

		local jieguo = yuanshi_startcooking(self, cooker, ...)

		---- 只有真正开始烹饪才扣一次耐久
		if self:IsCooking() and shu:IsValid() and shu.components.finiteuses ~= nil then
			local nai = shu.components.finiteuses
			---- 先算剩余次数，再扣：扣到 0 时物品会被 OnFinished 直接删除
			local shengyu = math.max(0, (nai:GetUses() or 0) - 1)
			nai:Use(1)
			if cooker.components ~= nil and cooker.components.talker ~= nil then
				if shengyu <= 0 then
					cooker.components.talker:Say("烹饪指南已经翻烂了……")
				else
					cooker.components.talker:Say("烹饪指南还可以用 " .. tostring(shengyu) .. " 次。")
				end
			end
		end

		return jieguo
	end
end)


end

-- ============================================================
-- 功能三：捡东西的动作换成 dolongaction（默认关，贝爷分区「捡东西变慢」开关）
--   原版 ACTIONS.PICKUP 用的是 doshortaction（短动作），这里改成 dolongaction
--   wilson 与 wilson_client 两边都要换，否则客户端预测动作会和服务器不一致
-- ============================================================
if GetModConfigData("捡东西变慢") then
	AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.PICKUP, "dolongaction"))
	AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.PICKUP, "dolongaction"))

	---- 采摘花草 / 收作物也一起变长动作
	AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.PICK, "dolongaction"))
	AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.PICK, "dolongaction"))
	AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.HARVEST, "dolongaction"))
	AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.HARVEST, "dolongaction"))
end


-- ============================================================
-- 功能四：种植需要对应的书，且每次种植消耗 1 点书的耐久
--
--   源码要点（饥荒联机版 scripts/）：
--     * scripts/prefabs/veggies.lua、seeds.lua 里，作物种子同时挂了
--         farmplantable（新农田，PLANTSOIL 动作调用 Plant）
--         plantable（旧机制，PLANT 动作 → grower:PlantItem）
--         deployable(DEPLOYMODE.CUSTOM)  ← 种子也能用「放置」动作直接种
--       松果 / 橡实等树苗则是 deployable(DEPLOYMODE.PLANT) → DEPLOY
--     * Inventory:FindItem 只扫 itemslots + 手持 activeitem + overflow，
--       不扫 equipslots（手/身体栏），也不进背包内部 → 这里自己遍历
--
--   所以拦截点：
--     farmplantable:Plant(target, planter)   ---- 新农田
--     grower:PlantItem(item, doer)           ---- 旧农田
--     deployable:Deploy(pt, deployer, rot)   ---- 种树 / 种子直接种
-- ============================================================

---- 树木类种植物
local SHUZHONG_ZHONGZI = {
	pinecone = true,
	acorn = true,
	birchnut = true,
	twiggy_nut = true,
	mooncone = true,
	moon_tree_seed = true,
}

---- 种地用的书（园艺学类，含拓展版）
local NONGYE_SHU = {
	book_gardening = true,
	book_horticulture = true,
	book_horticulture_upgraded = true,   ---- 应用园艺学拓展版，只能种种子
}

---- 种树用的书（造林学）
local SHU_ZAOLIN = {
	book_silviculture = true,
}

---- 已经扣过耐久的「种植物实例」（防止同一次种植被多层拦截重复扣）
local yijing_kou = setmetatable({}, { __mode = "k" })

local function shifou_shu(item, biao)
	if item == nil or biao[item.prefab] ~= true then
		return false
	end
	local nai = item.components ~= nil and item.components.finiteuses or nil
	return nai == nil or nai:GetUses() > 0
end

---- 递归找书：物品栏 + 装备栏(手持) + 容器内部
local function sousuo_shu(rongqi, biao, shenceng)
	if rongqi == nil then
		return nil
	end

	if rongqi.itemslots ~= nil then
		for _, v in pairs(rongqi.itemslots) do
			if shifou_shu(v, biao) then
				return v
			end
		end
	end

	if rongqi.equipslots ~= nil then
		for _, v in pairs(rongqi.equipslots) do
			if shifou_shu(v, biao) then
				return v
			end
		end
	end

	local liebiao = nil
	if rongqi.GetItems ~= nil then
		local ok, jieguo = pcall(rongqi.GetItems, rongqi)
		if ok and type(jieguo) == "table" then
			liebiao = jieguo
		end
	end

	if liebiao ~= nil then
		for _, v in pairs(liebiao) do
			if shifou_shu(v, biao) then
				return v
			end
		end
		if shenceng ~= nil and shenceng > 0 then
			for _, v in pairs(liebiao) do
				if v ~= nil and v:IsValid() and v.components ~= nil and v.components.container ~= nil then
					local nei = sousuo_shu(v.components.container, biao, shenceng - 1)
					if nei ~= nil then
						return nei
					end
				end
			end
		end
	end

	return nil
end

local function zhao_kexvan_shu(wanjia, biao)
	if wanjia == nil or not wanjia:IsValid() then
		return nil
	end
	local beibao = wanjia.components ~= nil and wanjia.components.inventory or nil
	return sousuo_shu(beibao, biao, 2)
end

---- hua：要说的话；yanchi：true 时用 0 秒延迟说
----   （动作被拒时客户端会先播「我做不到」，延迟 0 秒可以让正确的台词覆盖它）
---- 拦截时兜底：物品如果已经被别的代码从容器/背包里取出（例如血腥红莲的密集栽种），
---- 这里把它还给施法者，避免种子凭空消失
local function tuihui_wupin(doer, dongxi)
	if dongxi == nil or not dongxi:IsValid() then
		return
	end
	if doer == nil or not doer:IsValid() then
		return
	end
	local beibao = doer.components ~= nil and doer.components.inventory or nil
	if beibao == nil then
		return
	end
	---- 已经在某人身上的不重复给
	local yi = dongxi.components ~= nil and dongxi.components.inventoryitem or nil
	if yi ~= nil and yi.owner ~= nil then
		return
	end
	beibao:GiveItem(dongxi)
end

local function tishi(doer, hua, yanchi)
	if doer == nil or not doer:IsValid() then
		return
	end
	if yanchi and doer.DoTaskInTime ~= nil then
		doer:DoTaskInTime(0, function()
			if doer:IsValid() and doer.components ~= nil and doer.components.talker ~= nil then
				doer.components.talker:Say(hua)
			end
		end)
		return
	end
	if doer.components ~= nil and doer.components.talker ~= nil then
		doer.components.talker:Say(hua)
	end
end

---- 扣一次耐久；dongxi 是这一次被种下的实体，用来防止多层拦截重复扣
local function kou_naijiu(shu, doer, dongxi)
	if shu == nil or not shu:IsValid() or shu.components == nil or shu.components.finiteuses == nil then
		return
	end
	if dongxi ~= nil and yijing_kou[dongxi] then
		return
	end
	if dongxi ~= nil then
		yijing_kou[dongxi] = true
	end

	local nai = shu.components.finiteuses
	local shengyu = math.max(0, (nai:GetUses() or 0) - 1)
	nai:Use(1)
	if shengyu <= 0 then
		tishi(doer, "这本书已经被我翻烂了……")
	else
		tishi(doer, "书还能用 " .. tostring(shengyu) .. " 次。")
	end
end

---- 统一的「要书 + 扣耐久」流程
local function yaoqiu_shu(doer, shu_biao, hua)
	local shu = zhao_kexvan_shu(doer, shu_biao)
	if shu == nil then
		tishi(doer, hua, true)   ---- 延迟 0 秒，避免被「我做不到」盖住
		return nil
	end
	return shu
end

---- 新农田：FarmPlantable:Plant(target, planter)
if GetModConfigData("种地种树需要书") then
AddComponentPostInit("farmplantable", function(self)
	local yuanshi = self.Plant
	if type(yuanshi) ~= "function" then
		return
	end
	self.Plant = function(self, target, planter, ...)
		if planter == nil or not planter:IsValid() then
			return yuanshi(self, target, planter, ...)
		end
		-- if not GetModConfigData("种地种树需要书") then
			-- return yuanshi(self, target, planter, ...)
		-- end
		local shu = yaoqiu_shu(planter, NONGYE_SHU, "没有园艺类的书，我不知道该怎么下种。")
		if shu == nil then
			return false
		end
		local jieguo = yuanshi(self, target, planter, ...)
		if jieguo then
			kou_naijiu(shu, planter, self.inst)
		end
		return jieguo
	end
end)

---- 旧农田：Grower:PlantItem(item, doer)
AddComponentPostInit("grower", function(self)
	local yuanshi = self.PlantItem
	if type(yuanshi) ~= "function" then
		return
	end
	self.PlantItem = function(self, item, doer, ...)
		if doer == nil or not doer:IsValid() then
			return yuanshi(self, item, doer, ...)
		end
		-- if not GetModConfigData("种地种树需要书") then
			-- return yuanshi(self, item, doer, ...)
		-- end
		local shu = yaoqiu_shu(doer, NONGYE_SHU, "没有园艺类的书，我不知道该怎么下种。")
		if shu == nil then
			return false
		end
		local jieguo = yuanshi(self, item, doer, ...)
		if jieguo then
			kou_naijiu(shu, doer, item)
		end
		return jieguo
	end
end)

---- 种树 / 种子直接种：Deployable:Deploy(pt, deployer, rot)
AddComponentPostInit("deployable", function(self)
	local yuanshi = self.Deploy
	if type(yuanshi) ~= "function" then
		return
	end

	self.Deploy = function(self, pt, deployer, rot)
		local inst = self.inst
		if inst == nil or deployer == nil or not deployer:IsValid() then
			return yuanshi(self, pt, deployer, rot)
		end

		---- 本模组自己的物品（ray_ 开头，例如血腥红莲）不参与拦截，避免误伤
		if inst.prefab ~= nil and string.sub(inst.prefab, 1, 4) == "ray_" then
			return yuanshi(self, pt, deployer, rot)
		end

		---- 种树判定：白名单 或 deployable 模式为 DEPLOYMODE.PLANT
		----（松果 / 橡实 / 桦木坚果 / 树枝果 / 月树果 以及其它模组的自定义树苗都是这个模式）
		local moshi = nil
		if type(self.GetDeployMode) == "function" then
			moshi = self:GetDeployMode()
		end
		if moshi == nil then
			moshi = self.mode
		end
		local shi_shuzhong = SHUZHONG_ZHONGZI[inst.prefab] == true
			or (DEPLOYMODE ~= nil and moshi == DEPLOYMODE.PLANT)
		local shi_zhongzi = (not shi_shuzhong)
			and inst.components ~= nil
			and inst.components.farmplantable ~= nil
		if not shi_shuzhong and not shi_zhongzi then
			return yuanshi(self, pt, deployer, rot)
		end

		-- 开关控制：默认关闭则不拦截
		-- if not GetModConfigData("种地种树需要书") then
			-- return yuanshi(self, pt, deployer, rot)
		-- end

		local biao = shi_shuzhong and SHU_ZAOLIN or NONGYE_SHU
		local hua = shi_shuzhong and "没有《造林学》，我根本不会种树。"
			or "没有园艺类的书，我不知道该怎么下种。"

		local shu = yaoqiu_shu(deployer, biao, hua)
		if shu == nil then
			tuihui_wupin(deployer, inst)   ---- 种子/树苗不消失
			return false
		end

		local jieguo = yuanshi(self, pt, deployer, rot)
		if jieguo then
			kou_naijiu(shu, deployer, inst)
		end
		return jieguo
	end
end)

end
-- ============================================================
-- 功能五：玩家挖矿 / 砍树 / 采集草与树枝等「收获资源」减半
--   * 拦截 workable:WorkedBy、pickable:Pick、harvestable:Harvest，
--     在目标身上打一个「本次收获由玩家完成」的标记（1 秒后自动清除）
--   * 在 lootdropper:SpawnLootPrefab 里按「保留第 1、3、5…个，跳过第 2、4、6…个」
--     的方式把掉落数量砍半，最少保留 1 个
-- ============================================================

---- 标记持续时间（秒）：勾住同一次收获里所有同步/异步掉的战利品
local SHOUHUO_BIAOJI_CHIXU = 1

local function shifou_wanjia(ent)
	return ent ~= nil and ent:IsValid() and ent:HasTag("player")
end

local function kaishi_shouhuo(inst, doer)
	if inst == nil or not inst:IsValid() then
		return
	end
	if shifou_wanjia(doer) then
		inst.ray_shouhuo_jianban = true
		inst.ray_shouhuo_jishu = 0
		inst.ray_shouhuo_tongji = {}
		inst:DoTaskInTime(SHOUHUO_BIAOJI_CHIXU, function()
			if inst:IsValid() then
				inst.ray_shouhuo_jianban = nil
				inst.ray_shouhuo_jishu = nil
				inst.ray_shouhuo_tongji = nil
			end
		end)
	else
		inst.ray_shouhuo_jianban = nil
	end
end

local function baozhuang_shouhuo(zujian, fangfaming, qudoer)
	AddComponentPostInit(zujian, function(self)
		local yuanshi = self[fangfaming]
		if type(yuanshi) ~= "function" then
			return
		end
		self[fangfaming] = function(self, ...)
			if self.inst ~= nil and self.inst:IsValid() then
				kaishi_shouhuo(self.inst, qudoer(...))
			end
			return yuanshi(self, ...)
		end
	end)
end

---- 挖矿 / 砍树 / 敲石头
----   注意：原版 DoToolWork 是直接调 WorkedBy_Internal 的（注释写明「call the internal
----   function directly」），所以两个都要钩，否则砍树挖矿根本不会打上标记
baozhuang_shouhuo("workable", "WorkedBy", function(worker, numworks) return worker end)
baozhuang_shouhuo("workable", "WorkedBy_Internal", function(worker, numworks) return worker end)

---- 采集草、树枝、浆果、芦苇等
baozhuang_shouhuo("pickable", "Pick", function(picker) return picker end)

---- 收获灌木（Harvestable）/ 农田作物（Crop）
baozhuang_shouhuo("harvestable", "Harvest", function(picker) return picker end)
baozhuang_shouhuo("crop", "Harvest", function(picker) return picker end)

---- 数量换算：减半后向上取整，最少 1 个
local function jianban_shuliang(shuliang)
	if type(shuliang) ~= "number" or shuliang <= 0 then
		return 0
	end
	return math.max(1, math.ceil(shuliang / 2))
end

---- 把一份掉落清单按「物品类型」分别减半
----   例：{"log","log","pinecone"} → {"log","log" 减半成 1 个"log"} + {"pinecone"}（每种至少 1 个）
local function jianban_qingdan(qingdan)
	local tongji = {}
	local shunxu = {}
	for i = 1, #qingdan do
		local mingzi = qingdan[i]
		if tongji[mingzi] == nil then
			tongji[mingzi] = 0
			table.insert(shunxu, mingzi)
		end
		tongji[mingzi] = tongji[mingzi] + 1
	end

	local xin = {}
	for _, mingzi in ipairs(shunxu) do
		for _ = 1, jianban_shuliang(tongji[mingzi]) do
			table.insert(xin, mingzi)
		end
	end
	return xin
end

AddComponentPostInit("lootdropper", function(self)
	---- ① 主路径：裁掉 GenerateLoot 生成清单的后半段
	----    为什么不裁 DropLoot：本模组 modmain 里已经包过一次 DropLoot，而且签名是
	----    function DropLoot(pt)，会把外部传进来的 prefabs 丢掉、重新 Generate，
	----    所以只能在 GenerateLoot 这一层裁
	local yuanshi_generate = self.GenerateLoot
	if type(yuanshi_generate) == "function" then
		self.GenerateLoot = function(self)
			local loot = yuanshi_generate(self)
			local inst = self.inst
			---- 采集失败：整份清单作废
			if inst ~= nil and inst.ray_caiji_shibai then
				return {}
			end
			if inst ~= nil and inst.ray_shouhuo_jianban and type(loot) == "table" then
				local zongshu = #loot
				-- loot = jianban_qingdan(loot)
				if #loot < zongshu then
					---- 裁过之后，紧接着的逐个别掉不要再减半
					self.ray_gang_jianban = true
					if inst.DoTaskInTime ~= nil then
						inst:DoTaskInTime(0.5, function()
							if self ~= nil then
								self.ray_gang_jianban = nil
							end
						end)
					end
				end
			end
			return loot
		end
	end

	---- ② 兜底：有些代码不经过 DropLoot，直接 SpawnLootPrefab 逐个别掉
	local yuanshi_spawn = self.SpawnLootPrefab
	if type(yuanshi_spawn) == "function" then
		self.SpawnLootPrefab = function(self, lootprefab, ...)
			local inst = self.inst
			---- 采集失败：什么都不给
			if inst ~= nil and inst.ray_caiji_shibai then
				return nil
			end
			if inst ~= nil
				and inst.ray_shouhuo_jianban
				and not self.ray_gang_jianban
				and lootprefab ~= nil then
				---- 按「物品类型」分别计数，每种保留 ceil(个数/2) 个（至少 1 个）
				local tongji = inst.ray_shouhuo_tongji
				if tongji == nil then
					tongji = {}
					inst.ray_shouhuo_tongji = tongji
				end
				local jishu = (tongji[lootprefab] or 0) + 1
				tongji[lootprefab] = jishu
				if jishu % 2 == 0 then
					return nil
				end
			end
			return yuanshi_spawn(self, lootprefab, ...)
		end
	end
end)


-- ============================================================
-- 功能六：采集失败
--   * 触发条件：玩家执行采集（pickable:Pick）
--   * 基础概率 15%，精神越低越高，精神见底时 35%（线性）
--   * 失败后什么都不给，而且植物保持原状（不会被摘掉）
--   * 由配置「低san采集失败」控制；默认关 = 已移除该机制
-- ============================================================
if GetModConfigData("低san采集失败") then

local CAIJI_SHIBAI_BASE = 0.00   ---- 精神满时的失败率（满精神不失败）
local CAIJI_SHIBAI_MAX = 0.50    ---- 精神为 0 时的失败率

local function caiji_shibai_gailv(wanjia)
	local jingshen = wanjia ~= nil and wanjia.components ~= nil and wanjia.components.sanity or nil
	if jingshen == nil or jingshen.GetPercent == nil then
		return CAIJI_SHIBAI_BASE
	end
	local baifen = jingshen:GetPercent() or 1
	if baifen < 0 then
		baifen = 0
	elseif baifen > 1 then
		baifen = 1
	end
	---- 精神 100% → 0%，精神 0% → 50%
	local gailv = CAIJI_SHIBAI_BASE + (1 - baifen) * (CAIJI_SHIBAI_MAX - CAIJI_SHIBAI_BASE)
	---- 精神拉满时绝不失败（浮点误差兜底）
	if baifen >= 0.999 then
		gailv = 0
	end
	return gailv
end

local function shifou_wanjia(ent)
	return ent ~= nil and ent:IsValid() and ent:HasTag("player")
end

AddComponentPostInit("pickable", function(self)
	---- 产物通道直接掐掉：草/树枝这类 droppicked=false 的采集物是
	---- SpawnProductLoot 里 SpawnPrefab + inventory:GiveItem，不经过 lootdropper
	local yuanshi_chanpin = self.SpawnProductLoot
	if type(yuanshi_chanpin) == "function" then
		self.SpawnProductLoot = function(self, picker, ...)
			if self.inst ~= nil and self.inst.ray_caiji_shibai then
				return nil
			end
			return yuanshi_chanpin(self, picker, ...)
		end
	end

end)

---- 掷骰放在动作层：ACTIONS.PICK.fn 只要目标有 pickable 就一定会走这里，
---- 比包组件方法更稳（组件方法可能被别的模组再包一层）
if ACTIONS ~= nil and ACTIONS.PICK ~= nil and type(ACTIONS.PICK.fn) == "function" then
	local yuanshi_pick_fn = ACTIONS.PICK.fn
	ACTIONS.PICK.fn = function(act)
		local doer = act ~= nil and act.doer or nil
		local mubiao = act ~= nil and act.target or nil
		if shifou_wanjia(doer)
			and mubiao ~= nil
			and mubiao:IsValid()
			and mubiao.components ~= nil
			and mubiao.components.pickable ~= nil
			and math.random() < caiji_shibai_gailv(doer) then

			---- 采集失败：照常采（作物进入已采集状态），但产物全部作废
			mubiao.ray_caiji_shibai = true
			if mubiao.DoTaskInTime ~= nil then
				mubiao:DoTaskInTime(0.5, function()
					if mubiao:IsValid() then
						mubiao.ray_caiji_shibai = nil
					end
				end)
			end

			local jieguo = yuanshi_pick_fn(act)

			if doer.components ~= nil and doer.components.talker ~= nil then
				doer.components.talker:Say("我的san值太低了，采集失败了……")
			end
			return jieguo
		end
		return yuanshi_pick_fn(act)
	end
end
end


-- ============================================================
-- 功能七：制造不会「永久学会」科技配方（只能站原型机旁制造）
--
--   原版 scripts/components/builder.lua 里，制造成功的回调会解锁配方：
--     Builder:MakeRecipeFromMenu / MakeRecipeAtPoint / _TryMakeIngredientRecipe
--         elseif not knows_no_temp and canproto_no_temp and canlearn then
--             self:ActivateCurrentResearchMachine(recipe)
--             self:UnlockRecipe(recipe.name)        ---- → self:AddRecipe
--         elseif not recipe.nounlock then
--             --V2C: still want to unlock in case we reroll characters
--             self:AddRecipe(recipe.name)           ---- ← 制造一次就永久学会
--
--   本功能只掐这一条路：制造科技配方期间（MakeRecipe 的成功回调里）
--   对科技配方的 AddRecipe 直接丢弃。
--   ⚠ 蓝图 / 图鉴（teacher:Teach）、读档恢复等其它路径完全保持原版，不做任何干预或记录。
-- ============================================================

local jishu_peifang_huancun = {}

local function shifou_xuyao_yuanxingji(mingzi)
	if mingzi == nil then
		return false
	end
	local huancun = jishu_peifang_huancun[mingzi]
	if huancun ~= nil then
		return huancun
	end

	local peifang = nil
	if AllRecipes ~= nil then
		peifang = AllRecipes[mingzi]
	end

	local jieguo = false
	if peifang ~= nil and type(peifang.level) == "table" then
		---- 注意：TechTree 是 require("techtree") 出来的，模组环境里没有这个全局，
		---- 所以直接遍历 recipe.level（任何一项 > 0 就说明需要科技等级）
		for _, shuzhi in pairs(peifang.level) do
			if type(shuzhi) == "number" and shuzhi > 0 then
				jieguo = true
				break
			end
		end
	end

	jishu_peifang_huancun[mingzi] = jieguo
	return jieguo
end

-- Scope the guard to the successful craft callback, not a ten-second timer:
-- slow crafts can outlive that timer, and blueprints used meanwhile must work.
local function without_craft_unlock(self, fn, ...)
    local previous = self.ray_zhizao_zhengzai_jiesuo
    self.ray_zhizao_zhengzai_jiesuo = true
    local function finish(ok, ...)
        self.ray_zhizao_zhengzai_jiesuo = previous
        if not ok then error((...), 0) end
        return ...
    end
    return finish(pcall(fn, ...))
end
AddComponentPostInit("builder", function(self)
    local AddRecipe = self.AddRecipe
    function self:AddRecipe(name, ...)
        if self.ray_zhizao_zhengzai_jiesuo and shifou_xuyao_yuanxingji(name) then return end
        return AddRecipe(self, name, ...)
    end
    local MakeRecipe = self.MakeRecipe
    function self:MakeRecipe(recipe, pt, rot, skin, onsuccess)
        if not recipe or not onsuccess or not shifou_xuyao_yuanxingji(recipe.name) then
            return MakeRecipe(self, recipe, pt, rot, skin, onsuccess)
        end
        return MakeRecipe(self, recipe, pt, rot, skin, function(...)
            return without_craft_unlock(self, onsuccess, ...)
        end)
    end
    -- Placeable structures learn during buffering, before their BUILD action.
    local BufferBuild = self.BufferBuild
    function self:BufferBuild(name, ...)
        if shifou_xuyao_yuanxingji(name) then
            return without_craft_unlock(self, BufferBuild, self, name, ...)
        end
        return BufferBuild(self, name, ...)
    end
end)


-- ============================================================
-- 功能八：猪王不给金子，但「小玩具换图纸」这类兑换保留
--
--   源码要点（scripts/prefabs/pigking.lua）：
--     AcceptTest：goldvalue > 0 or 节日糖果 or prefab == "pig_token"
--     OnGetItemFromPlayer：goldvalue > 0 时 → 播 cointoss → DoTaskInTime(2/3, ontradeforgold)
--     ontradeforgold：for k = 1, goldvalue → SpawnPrefab("goldnugget")
--                     再按 tradable.tradefor 里的东西逐个生成（棋子素描等图纸）
--
--   scripts/prefabs/trinkets.lua 里 15/16/28/29/30/31 号小玩具有：
--     tradable.tradefor = {"chesspiece_knight_sketch"} 之类
--   所以不能动全局 goldvalue（那样连收都不收了），只在实际发货时把金子数量压成 0。
-- ============================================================
AddPrefabPostInit("pigking", function(inst)
	if inst == nil or not TheWorld.ismastersim then
		return inst
	end

	local jiaoyi = inst.components ~= nil and inst.components.trader or nil
	if jiaoyi == nil then
		return inst
	end

	---- ① 只给金子、没有图纸可换的东西：直接拒收（避免玩家白送物品）
	if type(jiaoyi.test) == "function" then
		local yuanshi_test = jiaoyi.test
		jiaoyi.test = function(zhu, dongxi, giver, shuliang)
			local kejiaoyi = dongxi ~= nil and dongxi.components ~= nil and dongxi.components.tradable or nil
			if kejiaoyi ~= nil
				and (kejiaoyi.goldvalue or 0) > 0
				and kejiaoyi.tradefor == nil
				and dongxi.prefab ~= "pig_token" then
				return false
			end
			return yuanshi_test(zhu, dongxi, giver, shuliang)
		end
	end

	---- ② 收下之后：照常播 cointoss、照常给图纸，但把金子数量压成 0
	if type(jiaoyi.onaccept) == "function" then
		local yuanshi_onaccept = jiaoyi.onaccept
		jiaoyi.onaccept = function(zhu, giver, dongxi)
			local kejiaoyi = dongxi ~= nil and dongxi.components ~= nil and dongxi.components.tradable or nil
			if kejiaoyi == nil or (kejiaoyi.goldvalue or 0) <= 0 then
				return yuanshi_onaccept(zhu, giver, dongxi)
			end

			local jiuzhi = kejiaoyi.goldvalue
			---- 先让原版走「有金子价值」的分支（播动作 + 排定 2/3 秒后的发放）
			local jieguo = yuanshi_onaccept(zhu, giver, dongxi)
			---- 立刻清零：2/3 秒后 ontradeforgold 的 for k = 1, 0 不会刷金子，
			---- 但 tradefor 里的图纸照发
			kejiaoyi.goldvalue = 0
			zhu:DoTaskInTime(1, function()
				if dongxi ~= nil and dongxi:IsValid() then
					kejiaoyi.goldvalue = jiuzhi
				end
			end)
			return jieguo
		end
	end

	return inst
end)
