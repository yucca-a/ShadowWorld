-- Merged from original Workshop 2886753796 v2.8.14.112 (2026-11-07).
-- Original authors and MulanPSL-2.0 license retained; loaded only by its mode switch.
local function IsNeedFix(item_check) --参数:被检测物体实体
		if item_check and item_check.components and not item_check:HasTag("bukeyingxiang")
			and ((item_check.components.finiteuses and item_check.components.finiteuses:GetPercent() >= 0.3)
			or (item_check.components.armor and item_check.components.armor:GetPercent() >= 0.3)
			or (item_check.components.fueled and item_check.components.fueled:GetPercent() >= 0.3)) then
			return true --符合条件就返回true
		end
		return false
	end

	local function ray_suijizhizaonaijiu(inst, data) ---- 随机耐久

		-- 初始化 inst 上的物品数量表（仅首次调用时）
		if not inst.ray_zhizao_manufactured_items then
			inst.ray_zhizao_manufactured_items = {}
		end
		
		if data and data.item and data.item:IsValid() and IsNeedFix(data.item) and data.item.components and data.item.prefab
			and data.item.prefab ~= "torch" then
			-- 获取当前物品的 prefab 名称
			local prefab = data.item.prefab

			-- 检查该物品是否已存在于表中，如果存在，则增加数量，否则初始化为 1
			if inst.ray_zhizao_manufactured_items[prefab] then
				inst.ray_zhizao_manufactured_items[prefab] = inst.ray_zhizao_manufactured_items[prefab] + 3
			else
				inst.ray_zhizao_manufactured_items[prefab] = 3
			end

			-- 随机数生成
			local suijinaijiu = math.random()

			-- 检查是否存在 ray_molizhi 组件
			if inst then
				local currentlv = 10
				-- 动态计算耐久值
				local max_lv = 25  -- 最大等级
				local min_value = 33  -- 最小耐久
				local max_value = 65  -- 最大耐久
				local dynamic_value = min_value + (max_value - min_value) * (currentlv / max_lv)

				-- 根据动态耐久值生成随机耐久
				suijinaijiu = math.random(math.floor(dynamic_value / 2), math.floor(dynamic_value))
				suijinaijiu = (suijinaijiu * 0.01)
			end

			-- 根据物品数量表的数量加成额外耐久
			local additional_durability = 0
			if inst.ray_zhizao_manufactured_items[prefab] then
				additional_durability = inst.ray_zhizao_manufactured_items[prefab] * 0.01  -- 每个物品增加 1% 的耐久
				suijinaijiu = suijinaijiu + additional_durability
			end
			if inst.ray_ewai_zhizao_naijiu then
				suijinaijiu = suijinaijiu + (inst.ray_ewai_zhizao_naijiu*0.01)
			end
			
			suijinaijiu = math.min(1, math.max(0, suijinaijiu))
			-- 处理不同类型的耐久组件
			if data.item.components.finiteuses then
				data.item.components.finiteuses:SetPercent(suijinaijiu)  -- 恢复耐久
			elseif data.item.components.armor then
				data.item.components.armor:SetPercent(suijinaijiu)  -- 恢复护甲耐久
			elseif data.item.components.fueled then
				data.item.components.fueled:SetPercent(suijinaijiu)  -- 恢复燃料耐久
			end

			-- 通知其他部分
			-- ray_jihuozhounenguitongzhi(inst, data.item, nil, nil)
		end
	end
	AddPlayerPostInit(function(inst) -- 人物API

		if not TheWorld.ismastersim then   ----服务器
			return inst
		end

		if not inst:HasTag("bookbuilder") then
			inst:AddTag("bookbuilder")
		end
		if not inst.components.reader then
			inst:AddComponent("reader")
			inst.components.reader:SetSanityPenaltyMultiplier(1)  -- 可选：理智消耗倍率
		end
		if inst.components.grue then
			inst.components.grue:AddImmunity("ray_heizhaotiaozhan")
		end
		
		inst:ListenForEvent("builditem", ray_suijizhizaonaijiu)
		inst:ListenForEvent("buildstructure", ray_suijizhizaonaijiu)
		
		local baocun, zairu

		if inst["OnSave"] ~= nil then
			baocun = inst["OnSave"]
		end
		if inst["OnLoad"] ~= nil then
			zairu = inst["OnLoad"]
		end
	   
		inst["OnSave"] = function(inst, McNxKV)
			if McNxKV then
				McNxKV.ray_zhizao_manufactured_items = inst.ray_zhizao_manufactured_items
			end
			if baocun then return baocun(inst, McNxKV) end
		end
		inst["OnLoad"] = function(inst, McNxKV)
			if zairu ~= nil then
				zairu(inst, McNxKV)
			end
			inst.ray_zhizao_manufactured_items = McNxKV and McNxKV.ray_zhizao_manufactured_items or nil
		end
	end)

	modimport("ray/beye_actions.lua")
	modimport("ray/beye_crafting.lua")
	
	AddClientModRPCHandler("ray_hud_sound", "play_getgold", function()
		if TheFrontEnd then
			TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/get_gold")
		end
	end)

	local RAY_MODAOCASHI = GLOBAL.Action({priority = 999})
	RAY_MODAOCASHI.id = "RAY_MODAOCASHI"
	RAY_MODAOCASHI.str = "磨锋刀刃"
	RAY_MODAOCASHI.fn = function(act)
		local spawn_fx_at = act.target or act.invobject
		local inst = act.invobject
		local doer = act.doer
		if spawn_fx_at and inst and doer then

			if doer.userid then
				SendModRPCToClient(GetClientModRPC("ray_hud_sound", "play_getgold"), doer.userid)
			end
			if spawn_fx_at.components.planardamage == nil then
				spawn_fx_at:AddComponent("planardamage")
				spawn_fx_at.components.planardamage:SetBaseDamage(0)
			end
			if spawn_fx_at.components.damagetypebonus == nil then
				spawn_fx_at:AddComponent("damagetypebonus")
			end
			
			if inst:HasTag("purebrilliance")  or inst.prefab == "purebrilliance"  then ---月亮
				if spawn_fx_at.components.damagetypebonus then
					spawn_fx_at.components.damagetypebonus:RemoveBonus("shadow_aligned", spawn_fx_at, inst.prefab)
				end
				if spawn_fx_at.components.planardamage then
					spawn_fx_at.components.planardamage:RemoveBonus(spawn_fx_at, inst.prefab)
				end
				spawn_fx_at.components.damagetypebonus:AddBonus("shadow_aligned", spawn_fx_at, 3,inst.prefab)
				spawn_fx_at.components.planardamage:AddBonus(spawn_fx_at, 15, inst.prefab)
				if spawn_fx_at[inst.prefab] then
					spawn_fx_at[inst.prefab]:Cancel()
					spawn_fx_at[inst.prefab] = nil
				end
				
				spawn_fx_at[inst.prefab] = spawn_fx_at:DoTaskInTime(120, function()
					if spawn_fx_at.components.planardamage then
						spawn_fx_at.components.planardamage:RemoveBonus(spawn_fx_at, inst.prefab)
					end
					if spawn_fx_at.components.damagetypebonus then
						spawn_fx_at.components.damagetypebonus:RemoveBonus("shadow_aligned", spawn_fx_at, inst.prefab)
					end
					if spawn_fx_at[inst.prefab] then
						spawn_fx_at[inst.prefab]:Cancel()
						spawn_fx_at[inst.prefab] = nil
					end
				end)
			elseif inst:HasTag("dreadstone") or inst.prefab == "dreadstone" then ---暗影
				if spawn_fx_at.components.damagetypebonus then
					spawn_fx_at.components.damagetypebonus:RemoveBonus("lunar_aligned", spawn_fx_at, inst.prefab)
				end
				if spawn_fx_at.components.planardamage then
					spawn_fx_at.components.planardamage:RemoveBonus(spawn_fx_at, inst.prefab)
				end
				spawn_fx_at.components.damagetypebonus:AddBonus("lunar_aligned", spawn_fx_at, 3,inst.prefab)
				spawn_fx_at.components.planardamage:AddBonus(spawn_fx_at, 15, inst.prefab)
				if spawn_fx_at[inst.prefab] then
					spawn_fx_at[inst.prefab]:Cancel()
					spawn_fx_at[inst.prefab] = nil
				end
				spawn_fx_at[inst.prefab] = spawn_fx_at:DoTaskInTime(120, function()
					if spawn_fx_at.components.planardamage then
						spawn_fx_at.components.planardamage:RemoveBonus(spawn_fx_at, inst.prefab)
					end
					if spawn_fx_at.components.damagetypebonus then
						spawn_fx_at.components.damagetypebonus:RemoveBonus("lunar_aligned", spawn_fx_at, inst.prefab)
					end
					if spawn_fx_at[inst.prefab] then
						spawn_fx_at[inst.prefab]:Cancel()
						spawn_fx_at[inst.prefab] = nil
					end
				end)
			else
				if spawn_fx_at.components.planardamage then
					spawn_fx_at.components.planardamage:RemoveBonus(spawn_fx_at, inst.prefab)
				end
				spawn_fx_at.ray_modaofenglijianren = nil
				spawn_fx_at.components.planardamage:AddBonus(spawn_fx_at, 15, inst.prefab)
				if spawn_fx_at[inst.prefab] then
					spawn_fx_at[inst.prefab]:Cancel()
					spawn_fx_at[inst.prefab] = nil
				end
				if spawn_fx_at[inst.prefab.."jianren"] then
					spawn_fx_at[inst.prefab.."jianren"]:Cancel()
					spawn_fx_at[inst.prefab.."jianren"] = nil
				end
				if spawn_fx_at.components.tool then
					spawn_fx_at.ray_modaofenglijianren = true
				end
				spawn_fx_at[inst.prefab] = spawn_fx_at:DoTaskInTime(120, function()
					if spawn_fx_at.components.planardamage then
						spawn_fx_at.components.planardamage:RemoveBonus(spawn_fx_at, inst.prefab)
					end
					-- spawn_fx_at.ray_modaofenglijianren = nil
					if spawn_fx_at[inst.prefab] then
						spawn_fx_at[inst.prefab]:Cancel()
						spawn_fx_at[inst.prefab] = nil
					end
				end)
				spawn_fx_at[inst.prefab.."jianren"] = spawn_fx_at:DoTaskInTime(6, function()
					spawn_fx_at.ray_modaofenglijianren = nil
					if spawn_fx_at[inst.prefab.."jianren"] then
						spawn_fx_at[inst.prefab.."jianren"]:Cancel()
						spawn_fx_at[inst.prefab.."jianren"] = nil
					end
				end)
			end
			
			
			if inst and inst:IsValid() then ---删除一个给予的物品
				if inst.components.stackable then
					inst.components.stackable:Get(1):Remove()
				else
					inst:Remove()
				end
			end
			if spawn_fx_at:HasTag("ray_fenglidu") and spawn_fx_at.components.finiteuses then ----恢复锋利度
				spawn_fx_at.components.finiteuses:SetPercent(1)
			end
		end
	   

		return true	
	end
	AddAction(RAY_MODAOCASHI) 
	ACTIONS.RAY_MODAOCASHI.canforce = true
	ACTIONS.RAY_MODAOCASHI.mount_valid = true
	AddComponentPostInit("finiteuses", function(self)
		local old_SetUses = self.SetUses
		function self:SetUses(val, ...)
			if self and self.inst and self.inst.ray_modaofenglijianren and val and self.current and self.current > val then
				val = self.current
			end
			return old_SetUses(self, val, ...)
		end
	end)
	-- 注册到 USEITEM 容器：物品作用在目标身上时，添加 ACTIONS.RAY_MODAOCASHI
	table.insert(TUNING.USEITEMFNS2HM, function(inst, doer, target, actions)
		-- 这里可以加判定条件，比如 inst、target、doer 的标签/预制体判断
		-- 示例：如果不限制条件就直接插入动作
		local controller = doer.components.playercontroller
		if target ~= nil and inst:HasTag("ray_modaoshi") and controller and not controller:IsControlPressed(CONTROL_FORCE_STACK)  and target:HasTag("weapon") and not target:HasTag("ray_bukedamo") then  ---磨刀石，和物品锋利度
			table.insert(actions, ACTIONS.RAY_MODAOCASHI)
		end
	end)
	
	local beiyuankeyichi2 = {
		"purebrilliance", "dreadstone","flint"
	}
	for a, b in pairs(beiyuankeyichi2) do
		AddPrefabPostInit(b, function(inst, p, n)
		
		if not inst:HasTag("ray_modaoshi") then
			inst:AddTag("ray_modaoshi")
		end
			
			if not TheWorld.ismastersim then
				return inst
			end


		end)
	end
AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.RAY_MODAOCASHI, "dolongaction"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.RAY_MODAOCASHI, "dolongaction")) ---缓慢的
