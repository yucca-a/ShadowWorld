-- Merged from original Workshop 2886753796 v2.8.14.112 (2026-11-07).
-- Original authors and MulanPSL-2.0 license retained; loaded only by its mode switch.
---此文件拍配置总的德爷生存。

---护甲失效。
if GetModConfigData("护甲失效") then
-- The original kept this part in its always-on kernel. Keep only the shadow
-- interaction required by Armor Invalid, inside the same optional switch.
AddComponentPostInit("combat", function(self)
    local SetTarget = self.SetTarget
    function self:SetTarget(target, ...)
        if target and target:HasTag("ray_lishijieguaiwu") then return end
        if self.inst:HasTag("ray_lishijieguaiwu") and target and not target:HasTag("player") then return end
        return SetTarget(self, target, ...)
    end
    local GetAttacked = self.GetAttacked_Internal
    function self:GetAttacked_Internal(attacker, ...)
        if self.inst:HasTag("ray_lishijieguaiwu") then
            if not attacker or not attacker:HasTag("player") then return end
            if attacker.ray_yunxvlishijieshengwushanghaiwanjia then
                attacker.ray_yunxvlishijieshengwushanghaiwanjia:Cancel()
            end
            attacker.ray_yunxvlishijieshengwushanghaiwanjia = attacker:DoTaskInTime(23, function(inst)
                inst.ray_yunxvlishijieshengwushanghaiwanjia = nil
            end)
        end
        if attacker and attacker:HasTag("ray_lishijieguaiwu") and
            (not self.inst:HasTag("player") or not self.inst.ray_yunxvlishijieshengwushanghaiwanjia) then return end
        return GetAttacked(self, attacker, ...)
    end
end)
AddComponentPostInit("inventory", function(self)
	local OldApplyDamage = self.ApplyDamage
	function self:ApplyDamage(damage, attacker, weapon, spdamage,...)
		if self and self.inst and not self.inst:HasTag("player")  then
			return OldApplyDamage(self, damage, attacker, weapon, spdamage,...)
		else
			return damage, spdamage
		end
	end
end)
-- 通用retarget hook函数：自主选目标时跳过shadowdominance玩家，共享仇恨不受影响
	local function HookShadowCreatureRetarget(inst)
		if not TheWorld.ismastersim then return end
		if not inst.components.combat then return end

		if not inst:HasTag("ray_lishijieguaiwu")  then
			inst:AddTag("ray_lishijieguaiwu") ---添加一个里世界怪物的特殊标签
		end
	end


-- 陆地影怪
	AddPrefabPostInit("terrorbeak", HookShadowCreatureRetarget)
	AddPrefabPostInit("crawlinghorror", HookShadowCreatureRetarget)
	AddPrefabPostInit("oceanhorror", HookShadowCreatureRetarget)

end

-- Also originally implemented in the always-on kernel. Preserve explicit
-- multi-serving recipes and decorative/drink/potion exclusions. Keeping the
-- component retains saved stack counts when this option is enabled in an old
-- world; those stacks cannot grow or recombine after splitting.
if GetModConfigData("料理禁止堆叠") then
    local cooking = require("cooking")
    AddPrefabPostInitAny(function(inst)
        if not TheWorld.ismastersim or not inst:HasTag("preparedfood") then return end
        for _, tag in ipairs({"mofayaoshui", "fooddrink", "winter_ornament",
            "halloween_ornament", "hermithouse_ornament", "wintersfeastfood"}) do
            if inst:HasTag(tag) then return end
        end
        local recipe = cooking.GetRecipe("cookpot", inst.prefab)
        if not recipe or not recipe.stacksize or recipe.stacksize <= 1 then
            if inst.components.stackable then
                inst.components.stackable.maxsize = 1
                inst.stackable_CanStackWithFn = function() return false end
            end
        end
    end)
end
------难以冻结
if GetModConfigData("难以冻结") then
local function FreezablePostConstruct(self)
	-- print("[Freezable] 尝试冰冻，时长:", freezetime)
		local jiude_Freeze = self.Freeze
		function self:Freeze(freezetime,...)
			if self and self.inst and self.inst.entity:IsVisible() and not (self.inst.components.health ~= nil and self.inst.components.health:IsDead()) and self.inst.ray_bingfengzhuangtaidaojishi == nil then
				self.inst.ray_bingfengzhuangtaidaojishi = self.inst:DoPeriodicTask(23, function()
					if self.inst.ray_bingfengzhuangtaidaojishi ~= nil then
						self.inst.ray_bingfengzhuangtaidaojishi:Cancel()
						self.inst.ray_bingfengzhuangtaidaojishi = nil
					end
				end)
				local jixianzhi = 20/5
				if freezetime and freezetime >= jixianzhi then
					freezetime = jixianzhi
				end
				return jiude_Freeze(self,freezetime,...)
			else
				self:StartWearingOff(1)
			end
			
		end

		local jiude_SetDefaultWearOffTime = self.SetDefaultWearOffTime
		function self:SetDefaultWearOffTime(wearofftime,...)
			local jixianzhi = 20/5
			if wearofftime and wearofftime >= jixianzhi then
				wearofftime = jixianzhi
			end
			return jiude_SetDefaultWearOffTime(self,wearofftime,...)
		end
		
end

AddClassPostConstruct("components/freezable", FreezablePostConstruct)
end

------下雨禁火:下雨时玩家无法点燃火焰,火把瞬间熄灭
if GetModConfigData("下雨禁火") then

	local SHELTERED_MUST_TAGS = { "shelter" }
	local SHELTERED_CANT_TAGS = { "FX", "NOCLICK", "DECOR", "INLIMBO", "stump", "burnt" }
	local function ray_you_fangshui(inst)
		if inst == nil or inst.Transform == nil then
			return false
		end
		local panding = true
		local x, y, z = inst.Transform:GetWorldPosition()
		local ents = TheSim:CountEntities(x, y, z, 3, SHELTERED_MUST_TAGS, SHELTERED_CANT_TAGS)
		panding = ents > 0
		return panding
	end

	local function ray_zai_xiayu(inst)
		if TheWorld ~= nil and TheWorld.state ~= nil and TheWorld.state.israining then
			if ray_you_fangshui(inst) then
				return false
			else
				return true
			end
		end
		return false
	end

---① 玩家无法点燃火焰:下雨时非火把的点燃一律拒绝
---(覆盖打火机/火把点篝火火坑、火魔杖、往熄灭篝火加燃料重燃等全部路径;
---  火把本身走②单独处理,它没有 doer 且 onequip 会在点燃后创建火焰特效)
---豁免:龙鳞火炉(dragonfurnace)、咩咩火堆(COTL联动祭坛火炉 cotl_tabernacle_level1/2/3,
---      即「低微/有所改进/完美无瑕咩咩雕像」)、火炉保护类(campfire2hm:chiminea/海中烟囱/
---      暗影祭坛火炉,由 weather_change 的 seasons.lua 打标签),以及被点燃目标周围较近 3 格
---      有树(shelter 标签,大树等挡雨)时允许点燃
local ray_miehuodui = {
	["cotl_tabernacle_level1"] = true,
	["cotl_tabernacle_level2"] = true,
	["cotl_tabernacle_level3"] = true,
}
AddClassPostConstruct("components/burnable", function(self)
	local jiude_Ignite = self.Ignite
	function self:Ignite(immediate, source, doer,...)
		if ray_zai_xiayu(self.inst)  and self.inst ~= nil and not self.inst:HasTag("torch") then
			if self.inst.prefab == "dragonflyfurnace" or self.inst.prefab == "dragonfurnace" or self.inst:HasTag("campfire2hm") or ray_miehuodui[self.inst.prefab] then
				return jiude_Ignite(self, immediate, source, doer,...)
			end
			-- if ray_you_fangshui(self.inst) then
				-- return jiude_Ignite(self, immediate, source, doer,...)
			-- end
			return false
		end
		return jiude_Ignite(self, immediate, source, doer,...)
	end
end)

---② 火把/打火机瞬间熄灭:
---   装备/投掷的火把在下雨时点燃后立即熄灭;已经点燃的火把,下雨一开始就熄灭
---   豁免:火把/打火机周围较近 3 格有树(shelter 标签,大树等挡雨)时,
---   下雨也能保持点燃,火焰特效保留(手持时物品位置≈玩家位置,旁边的树能命中)
local function ray_torch_xiaomie(inst)
	-- if ray_you_fangshui(inst) then
		-- return
	-- end
	if inst.fires ~= nil then
		for i, fx in ipairs(inst.fires) do
			if fx ~= nil and fx:IsValid() then
				fx:Remove()
			end
		end
		inst.fires = nil
	end
	if inst.components.burnable ~= nil then
		inst.components.burnable:Extinguish()
	end
end

AddPrefabPostInit("torch", function(inst)
	if not TheWorld.ismastersim then
		return inst
	end

	--- 下雨时点燃(装备/投掷) → 下一帧立即熄灭(等 onequip/IgniteTossed 把 fires 建完再清)
	inst:ListenForEvent("onignite", function()
		if ray_zai_xiayu(inst) then
			inst:DoTaskInTime(0, function()
				if inst ~= nil and inst:IsValid() then
					ray_torch_xiaomie(inst)
				end
			end)
		end
	end)

	--- 正在燃烧时开始下雨 → 瞬间熄灭
	local function ray_xiayu_kaitou(inst, israining)
		if israining and ray_zai_xiayu(inst) and inst.components.burnable ~= nil and inst.components.burnable:IsBurning() then
			ray_torch_xiaomie(inst)
		end
	end
	inst:WatchWorldState("israining", ray_xiayu_kaitou)
	ray_xiayu_kaitou(inst, TheWorld.state.israining)

	return inst
end)

--- ④ 火女打火机:与火把一致——下雨时点燃立即熄灭,已点燃的开始下雨即熄灭;附加火焰温度
AddPrefabPostInit("lighter", function(inst)
	if not TheWorld.ismastersim then
		return inst
	end

	inst:ListenForEvent("onignite", function()
		if ray_zai_xiayu(inst) then
			inst:DoTaskInTime(0, function()
				if inst ~= nil and inst:IsValid() then
					ray_torch_xiaomie(inst)
				end
			end)
		end
	end)

	--- 打火机的 fires 是 onequip 函数体直接创建的(不走 burnable 点燃的 onignite),
	--- 下雨时拦截 Ignite 拦不住它 → 在装备事件(onequip 建完 fires 之后)再清
	inst:ListenForEvent("equipped", function()
		if ray_zai_xiayu(inst) then
			inst:DoTaskInTime(0, function()
				if inst ~= nil and inst:IsValid() then
					ray_torch_xiaomie(inst)
				end
			end)
		end
	end)

	local function ray_xiayu_kaitou(inst, israining)
		if israining and ray_zai_xiayu(inst) and inst.components.burnable ~= nil and inst.components.burnable:IsBurning() then
			ray_torch_xiaomie(inst)
		end
	end
	inst:WatchWorldState("israining", ray_xiayu_kaitou)
	ray_xiayu_kaitou(inst, TheWorld.state.israining)

	return inst
end)

end

------火把传热:点燃的火把/打火机火焰特效本身是热源(与官方 campfirefire 同机制)
if GetModConfigData("火把传热") then
local function ray_fire_wendu(inst)
	if not TheWorld.ismastersim then return inst end
	if inst.components.heater == nil then
		inst:AddComponent("heater")
	end
	inst.components.heater:SetThermics(true, false)
	inst.components.heater.heatfn = function() return 50 end
	inst.components.heater:SetHeatRadiusCutoff(4)
	return inst
end
local ray_fire_prefabs = {
	"torchfire", "torchfire_barber", "torchfire_carrat", "torchfire_cawnival",
	"torchfire_nautical", "torchfire_pillar", "torchfire_pronged", "torchfire_rag",
	"torchfire_shadow", "torchfire_spooky", "torchfire_tesla", "torchfire_yotrpillowfight",
	"lighterfire", "lighterfire_glass", "lighterfire_haunteddoll", "lighterfire_heart",
	"lighterfire_old", "lighterfire_ragged", "lighterfire_rose",
}
for _, p in ipairs(ray_fire_prefabs) do
	AddPrefabPostInit(p, ray_fire_wendu)
end
end

------空挥武器:攻击时原地挥刀,不移动到最远攻击距离
if GetModConfigData("空挥武器") then
	ACTIONS.ATTACK.do_not_locomote = true
end
