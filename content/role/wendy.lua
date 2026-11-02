-- 阿比盖尔现在有温度了，且会热得掉血了,且成长速度更慢了
TUNING.ABIGAIL_BOND_LEVELUP_TIME = TUNING.ABIGAIL_BOND_LEVELUP_TIME * 2
local maxoverheattemp = TUNING.OVERHEAT_TEMP * 5 / 7
local newmaxoverheattemp = TUNING.OVERHEAT_TEMP
local function processtempcolour(inst, force)
    local self = inst.components.temperature
    if not inst:HasTag("swc2hm") and self then
        local gbhundred = self.current > 0 and
                              math.ceil((self.current > self.overheattemp and 75 or (self.overheattemp - self.current) / self.overheattemp * 25 + 75)) or 100
        if inst:IsInLimbo() then gbhundred = math.max(76, gbhundred) end
        if not self.lastFrames2hm then self.lastFrames2hm = GetTime() - FRAMES end
        if force then
            local gb = gbhundred / 100
            inst.AnimState:SetMultColour(1, gb, gb, 1)
        elseif GetTime() - FRAMES > self.lastFrames2hm then
            self.lastFrames2hm = GetTime()
            local r, g, b, alpha = inst.AnimState:GetMultColour()
            local oldgbhundred = math.ceil((g + b) * 50)
            if oldgbhundred == gbhundred then return end
            gbhundred = gbhundred > oldgbhundred and (oldgbhundred + 1) or (oldgbhundred - 1)
            local gb = oldgbhundred / 100
            inst.AnimState:SetMultColour(1, gb, gb, 1)
        end
        if inst._playerlink and inst._playerlink:IsValid() and inst._playerlink.abigailgbhundred2hm then
            inst._playerlink.abigailgbhundred2hm:set(gbhundred)
        end
    end
end
local function updatetemperature(inst)
    if inst.components.temperature and inst.components.temperature.current > -20 then
        inst.components.temperature:SetTemperature(inst.components.temperature.current - 1)
    elseif inst.temptask2hm then
        inst.temptask2hm:Cancel()
        inst.temptask2hm = nil
    end
end
local function onstartoverheating(inst)
    if inst._playerlink and inst._playerlink:IsValid() and inst._playerlink.components.talker then
        inst._playerlink.components.talker:Say(GetString(inst._playerlink, "ANNOUNCE_ABIGAIL_LOW_HEALTH"))
    end
    if not inst:IsInLimbo() and not inst.hottrailfx2hm then
        inst.hottrailfx2hm = SpawnPrefab("hotcold_fx")
        inst.hottrailfx2hm.entity:SetParent(inst.entity)
        inst.hottrailfx2hm.AnimState:SetScale(0.7, 0.7)
        inst.hottrailfx2hm.entity:AddFollower():FollowSymbol(inst.GUID, "ghost_eyes", 10, -140, 0)
        -- inst.hottrailfx2hm.AnimState:SetDeltaTimeMultiplier(0.75)
    end
end
local function onstopoverheating(inst)
    if inst.hottrailfx2hm then
        inst.hottrailfx2hm:Remove()
        inst.hottrailfx2hm = nil
    end
end
local function onenterlimbo(inst)
    if inst.components.temperature then
        inst:StopUpdatingComponent(inst.components.temperature)
        if not inst.temptask2hm then inst.temptask2hm = inst:DoPeriodicTask(1, updatetemperature) end
        processtempcolour(inst, true)
    end
    if inst.hottrailfx2hm then
        inst.hottrailfx2hm:Remove()
        inst.hottrailfx2hm = nil
    end
    if not inst:HasTag("swc2hm") and inst._playerlink ~= nil and inst._playerlink:IsValid() and inst._playerlink.components.ghostlybond then
        inst._playerlink.components.ghostlybond:SetBondTimeMultiplier("abigail2hm", 0)
    end
end
local function onexitlimbo(inst)
    if inst.temptask2hm then
        inst.temptask2hm:Cancel()
        inst.temptask2hm = nil
    end
    if inst.components.temperature then
        inst:StartUpdatingComponent(inst.components.temperature)
        processtempcolour(inst, true)
        if inst.components.temperature.current > inst.components.temperature.overheattemp then onstartoverheating(inst) end
    end
    if not inst:HasTag("swc2hm") and inst._playerlink ~= nil and inst._playerlink:IsValid() and inst._playerlink.components.ghostlybond then
        inst._playerlink.components.ghostlybond:SetBondTimeMultiplier("abigail2hm")
    end
end
local function checkoverheating(inst)
    if inst.components.temperature and not inst:IsInLimbo() then
        processtempcolour(inst, true)
        if inst.components.temperature.current > inst.components.temperature.overheattemp then onstartoverheating(inst) end
    end
end
local function ontemperaturedelta(inst, data)
    if data and data.new and data.last then
        if data.new > 0 and data.last <= 0 then
            inst.components.health:StopRegen()
        elseif data.new <= 0 and data.last > 0 then
            inst.components.health:StartRegen(1, 10)
        end
    end
    processtempcolour(inst, true)
end
local function ondeath(inst) if inst.components.temperature then inst.components.temperature:SetTemperature(-20) end end
local function abigailHeatFn(inst, observer)
    return (observer == nil or observer.prefab ~= "wendy" or TheWorld.state.issummer) and
               (TheWorld.state.issummer and math.min(inst.components.temperature.current, TheWorld.state.temperature, 50) or
                   (inst.components.temperature.current - 40) / 3) or nil
end
AddPrefabPostInit("abigail", function(inst)
    if not TheWorld.ismastersim then return end
    inst.components.health:StartRegen(1, 10)
    if not inst.components.temperature then
        inst:AddComponent("temperature")
        inst.components.temperature.current = -20
        inst.components.temperature.mintemp = -20
        inst.components.temperature.coldtemp2hm = -30
        inst.components.temperature.overheattemp = maxoverheattemp
        inst.components.temperature.inherentinsulation = TUNING.INSULATION_TINY
        inst.components.temperature.inherentsummerinsulation = -TUNING.INSULATION_TINY
        inst.components.temperature:IgnoreTags("ghost")
        inst.components.temperature:IgnoreTags("abigail_flower")
        inst.components.temperature:SetFreezingHurtRate(0)
        inst.components.temperature:SetOverheatHurtRate(1)
        inst:ListenForEvent("temperaturedelta", ontemperaturedelta)
        inst:ListenForEvent("enterlimbo", onenterlimbo)
        inst:ListenForEvent("exitlimbo", onexitlimbo)
        inst:ListenForEvent("startoverheating", onstartoverheating)
        inst:ListenForEvent("stopoverheating", onstopoverheating)
        inst:ListenForEvent("death", ondeath)
        inst:DoTaskInTime(0, checkoverheating)
    end
    if not inst.components.heater then
        inst:AddComponent("heater")
        inst.components.heater.heatfn = abigailHeatFn
        inst.components.heater:SetThermics(false, true)
    end
end)
local function abigailbadge2hmdirty(inst)
    if inst.abigailgbhundred2hm and inst == ThePlayer and ThePlayer.HUD and ThePlayer.HUD.controls and ThePlayer.HUD.controls and ThePlayer.HUD.controls.status and
        ThePlayer.HUD.controls.status.pethealthbadge then
        local badge = ThePlayer.HUD.controls.status.pethealthbadge
        local gbhundred = inst.abigailgbhundred2hm:value()
        local gb = gbhundred / 100
        if badge.circleframe and badge.circleframe:GetAnimState() then badge.circleframe:GetAnimState():SetMultColour(1, gb, gb, gb) end
        local arrowdir2hm = gbhundred <= 75 and -1 or 0
        if not badge.arrowdir2hm then
            badge.arrowdir2hm = arrowdir2hm
            local SetValues = badge.SetValues
            badge.SetValues = function(self, symbol, symbol2, percent, arrowdir, ...) SetValues(self, symbol, symbol2, percent, arrowdir + self.arrowdir2hm, ...) end
            ThePlayer.HUD.controls.status:RefreshPetHealth()
        elseif badge.arrowdir2hm ~= arrowdir2hm then
            badge.arrowdir2hm = arrowdir2hm
            ThePlayer.HUD.controls.status:RefreshPetHealth()
        end
    end
end
AddPrefabPostInit("wendy", function(inst)
    inst.abigailgbhundred2hm = net_byte(inst.GUID, "abigail.gbhundred2hm", "abigailbadge2hmdirty")
    inst.abigailgbhundred2hm:set(100)
    if not TheWorld.ismastersim then inst:ListenForEvent("abigailbadge2hmdirty", abigailbadge2hmdirty) end
end)
-- 阿比盖尔之花也能传达部分姐姐的温度
local function abigailflowerHeatFn(inst)
    if TheWorld.state.issummer and inst.components.inventoryitem and inst.components.inventoryitem.owner then
        local owner = inst.components.inventoryitem.owner
        if owner:IsValid() and owner:HasTag("player") and owner.prefab == "wendy" and owner.components.temperature then
            local ghost = owner.components.ghostlybond and owner.components.ghostlybond.ghost
            if ghost and ghost:IsValid() and ghost:IsInLimbo() and ghost.components.heater then
                if not ghost.flower2hm then
                    ghost.flower2hm = inst
                elseif ghost.flower2hm ~= inst and ghost.flower2hm:IsValid() then
                    if ghost.flower2hm.components.inventoryitem.owner == owner then return end
                    ghost.flower2hm = inst
                end
                return math.min(TheWorld.state.temperature, 65)
            end
        end
    end
end
AddPrefabPostInit("abigail_flower", function(inst)
    if not TheWorld.ismastersim then return end
    if not inst.components.heater then
        inst:AddComponent("heater")
        inst.components.heater.carriedheatfn = abigailflowerHeatFn
        inst.components.heater:SetThermics(false, true)
    end
end)
-- 夜影万金油可以提高姐姐的温度上限
AddPrefabPostInit("ghostlyelixir_attack_buff", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.potion_tunings and not inst.potion_tunings.tempprocess2hm then
        inst.potion_tunings.tempprocess2hm = true
        local ONAPPLY = inst.potion_tunings.ONAPPLY
        inst.potion_tunings.ONAPPLY = function(inst, target, ...)
            if target and target:IsValid() and target:HasTag("abigail") and target.components.temperature then
                target.components.temperature.overheattemp = newmaxoverheattemp
                if target.components.temperature.current > maxoverheattemp and target.components.temperature.current < newmaxoverheattemp then
                    target:PushEvent("stopoverheating")
                end
            end
            ONAPPLY(inst, target, ...)
        end
        local ONDETACH = inst.potion_tunings.ONDETACH
        inst.potion_tunings.ONDETACH = function(inst, target, ...)
            if target and target:IsValid() and target:HasTag("abigail") and target.components.temperature then
                target.components.temperature.overheattemp = maxoverheattemp
                if target.components.temperature.current < newmaxoverheattemp and target.components.temperature.current > maxoverheattemp then
                    target:PushEvent("startoverheating")
                end
            end
            ONDETACH(inst, target, ...)
        end
    end
end)
-- 鬼魂有温度了，冷气森森
local function ghostHeatFn(inst, observer)
    return (observer == nil or observer.prefab ~= "wendy" or TheWorld.state.issummer) and
               (TheWorld.state.issummer and math.min(TheWorld.state.temperature, 60) or -10) or nil
end
AddPrefabPostInit("ghost", function(inst)
    if not TheWorld.ismastersim then return end
    if not inst.components.heater then
        inst:AddComponent("heater")
        inst.components.heater.heatfn = ghostHeatFn
        inst.components.heater:SetThermics(false, true)
    end
end)
local function smallghostHeatFn(inst, observer)
    return (observer == nil or observer.prefab ~= "wendy" or TheWorld.state.issummer) and
               (TheWorld.state.issummer and math.min(TheWorld.state.temperature, 70) or 0) or nil
end
AddPrefabPostInit("smallghost", function(inst)
    if not TheWorld.ismastersim then return end
    if not inst.components.heater then
        inst:AddComponent("heater")
        inst.components.heater.heatfn = smallghostHeatFn
        inst.components.heater:SetThermics(false, true)
    end
end)
-- 骨灰罐保鲜
if TUNING.DSTU then
    AddPrefabPostInit("sisturn", function(inst)
        if not TheWorld.ismastersim then return end
		local old_listener = nil
		for k, v in pairs(inst.event_listening or {}) do
			for i, listener in ipairs(v) do
				if listener.event == "wendy_sisturnskillchanged" and listener.source == TheWorld then
					old_listener = listener.fn
					inst:RemoveEventCallback("wendy_sisturnskillchanged", listener.fn, TheWorld)
					break
				end
			end
		end
		inst:ListenForEvent("wendy_sisturnskillchanged", function(_, user)
			if old_listener then
				old_listener(_, user)
			end
			if inst.components.preserver then
			inst.components.preserver:SetPerishRateMultiplier(0)
        end
		end, TheWorld)
        if inst.components.preserver then
			inst:DoTaskInTime(0,function()
				inst.components.preserver:SetPerishRateMultiplier(0)
			end)
        end
    end)
end

-- 阿比盖尔护盾吸收值削弱
AddPrefabPostInit("abigailforcefieldretaliation", function(inst)
	if not TheWorld.ismastersim then return end
	if inst.components.debuff then
		local oldonattachedfn = inst.components.debuff.onattachedfn
		inst.components.debuff.onattachedfn = function(inst, target, ...)
			oldonattachedfn(inst, target, ...)
			if target.prefab == "abigail" and target.components.health ~= nil then
				target.components.health.externalabsorbmodifiers:SetModifier(inst, 0.9, "forcefield")
			end
		end
	end
end)
AddPrefabPostInit("abigailforcefieldbuffed", function(inst)
	if not TheWorld.ismastersim then return end
	if inst.components.debuff then
		local oldonattachedfn = inst.components.debuff.onattachedfn
		inst.components.debuff.onattachedfn = function(inst, target, ...)
			oldonattachedfn(inst, target, ...)
			if target.prefab == "abigail" and target.components.health ~= nil then
				target.components.health.externalabsorbmodifiers:SetModifier(inst, 0.8, "forcefield")
			end
		end
	end
end)
AddPrefabPostInit("abigailforcefield", function(inst)
	if not TheWorld.ismastersim then return end
	if inst.components.debuff then
		local oldonattachedfn = inst.components.debuff.onattachedfn
		inst.components.debuff.onattachedfn = function(inst, target, ...)
			oldonattachedfn(inst, target, ...)
			if target.prefab == "abigail" and target.components.health ~= nil then
				target.components.health.externalabsorbmodifiers:SetModifier(inst, 0.7, "forcefield")
			end
		end
	end
end)
-- 修复阿比盖尔附身bug
-- AddPrefabPostInit("abigail", function(inst)
-- 	if not TheWorld.ismastersim then return end
-- 	local oldauratest = inst.auratest
-- 	inst.auratest = function(inst, target, can_initiate, ...)
-- 		if inst and inst:IsInLimbo() then return false end
-- 		return oldauratest(inst, target, can_initiate, ...)
-- 	end
-- 	if inst.components.combat then
-- 		local keeptargetfn = inst.components.combat.keeptargetfn
-- 		inst.components.combat.keeptargetfn = function(inst, target, can_initiate, ...)
-- 			if inst and inst:IsInLimbo() then return false end
-- 			keeptargetfn(inst, target, can_initiate, ...)
-- 		end
-- 	end
-- end)

-- 2025.9.19 melon:修复阿比盖尔附身bug
AddPrefabPostInit("abigail", function(inst)
	if not TheWorld.ismastersim then return end
	inst:ListenForEvent("do_ghost_escape", function(inst) -- 加个标记
        inst.escape_mark2hm = inst:DoTaskInTime(1,function(inst) inst.escape_mark2hm = nil end)
    end)
end)
AddPrefabPostInit("wendy", function(inst)
	if not TheWorld.ismastersim then return end
    if inst.components.ghostlybond then
        local _Recall = inst.components.ghostlybond.Recall
        inst.components.ghostlybond.Recall = function(self, was_killed, ...)
            if self.ghost ~= nil and self.summoned and not self.inst.sg:HasStateTag("dissipate") and self.ghost.escape_mark2hm then
                return false -- escape_mark2hm则不收回
            end
            return _Recall(self, was_killed, ...)
        end
    end
end)

-- AddRecipePostInit(
--     "sisturn",
--     function(inst)
--         inst.builder_tag = nil
--     end
-- )

-- AddRecipePostInit(
--     "abigail_flower",
--     function(inst)
--         table.insert(inst.ingredients, Ingredient("shadowheart", 1))
--     end
-- )

-- local pigmans = {
--     "pigman",
--     "pigguard"
-- }

-- local function OnAttacked(inst, data)
--     if
--         inst.components.werebeast and not inst.components.werebeast:IsInWereState() and data.attacker and
--             data.attacker:HasTag("ghost") and
--             math.random() < 0.51
--      then
--         inst.components.werebeast:TriggerDelta(1)
--     end
-- end

-- for _, pigman in ipairs(pigmans) do
--     AddPrefabPostInit(
--         pigman,
--         function(inst)
--             if not TheWorld.ismastersim then
--                 return inst
--             end
--             inst:ListenForEvent("blocked", OnAttacked, inst)
--             inst:ListenForEvent("attacked", OnAttacked, inst)
--         end
--     )
-- end

AddPrefabPostInit("wendy", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.combat then
        local oldfn = inst.components.combat.customdamagemultfn
        inst.components.combat.customdamagemultfn = function(inst, target, weapon, multiplier, mount, ...)
            local mult 
            if oldfn then mult = oldfn(inst, target, weapon, multiplier, mount, ...) end
            return mount and 1 or mult
        end
    end
    if inst.components.ghostlybond and inst.components.ghostlybond.onrecallfn then
        local oldfn = inst.components.ghostlybond.onrecallfn
        inst.components.ghostlybond.onrecallfn = function(inst, _ghost, ...)
            local ghost = inst.components.ghostlybond.ghost
            if ghost and ghost:IsValid() then
                local x, y, z = ghost.Transform:GetWorldPosition()
                local ents = TheSim:FindEntities(x, y, z, 10, {"_health", "_combat"}, {"FX", "DECOR", "INLIMBO", "player"}, {"hostile", "epic"})
                for i, v in pairs(ents) do
                    if v and v ~= ghost and v:IsValid() and not v.components.health:IsDead() and v.components.combat:TargetIs(ghost) then
                        v:DoTaskInTime(0.5, function()
                            if v and v:IsValid() then
                                v.components.combat:SetTarget(inst)
                            end
                        end)
                    end
                end
            end
            return oldfn(inst, _ghost, ...)
        end
    end
end)

-- local ghostcommand_defs = require("prefabs/ghostcommand_defs")
-- if ghostcommand_defs and ghostcommand_defs.GetGhostCommandsFor then
--     local oldGetGhostCommandsFor = ghostcommand_defs.GetGhostCommandsFor
--     ghostcommand_defs.GetGhostCommandsFor = function(owner, ...)
--         local commands = oldGetGhostCommandsFor(owner, ...)
--         if commands and type(commands) == "table" then
--             for i, v in ipairs(commands) do
--                 if v.label == STRINGS.GHOSTCOMMANDS.ATTACK_AT then
--                     local oldfn = v.onselect
--                     v.onselect = function(inst, ...)
--                         if oldfn then oldfn(inst, ...) end
--                         inst.components.aoetargeting:SetRange(12.5)
--                     end
--                     break
--                 end
--             end
--         end
--         return commands
--     end

-- 药水配方变贵:哀悼荣耀需求提升
AddRecipePostInit("ghostlyelixir_speed", function(inst) -- 强健精油:1蜂蜜+1哀悼荣耀+2活蝴蝶
	inst.ingredients = {
		Ingredient("honey", 1),
		Ingredient("ghostflower", 1),
		Ingredient("butterfly", 2),
	}
end)

AddRecipePostInit("ghostlyelixir_slowregen", function(inst) -- 亡者补药:3哀悼荣耀+1治疗药膏
	inst.ingredients = { Ingredient("ghostflower", 3), Ingredient("healingsalve", 1) }
end)
AddRecipePostInit("ghostlyelixir_fastregen", function(inst) -- 灵魂万能药:6哀悼荣耀+2亡者补药+50生命值
	inst.ingredients = { Ingredient("ghostflower", 6), Ingredient("ghostlyelixir_slowregen", 2) }
	inst.character_ingredients = { Ingredient(GLOBAL.CHARACTER_INGREDIENT.HEALTH, 50) }
	inst.tech_ingredients = {}
end)
AddRecipePostInit("ghostlyelixir_shield", function(inst) -- 不屈药剂:3哀悼荣耀+1木头
	inst.ingredients = { Ingredient("ghostflower", 3), Ingredient("log", 1) }
end)
AddRecipePostInit("ghostlyelixir_retaliation", function(inst) -- 蒸馏复仇:6哀悼荣耀+1活木
	inst.ingredients = { Ingredient("ghostflower", 6), Ingredient("livinglog", 1) }
end)
AddRecipePostInit("ghostlyelixir_attack", function(inst) -- 暗影万金油:6哀悼荣耀+1小发光浆果+1蜂刺
	inst.ingredients = { Ingredient("ghostflower", 6), Ingredient("wormlight_lesser", 1), Ingredient("stinger", 1) }
end)
AddRecipePostInit("ghostlyelixir_revive", function(inst) -- 恐怖经历:6哀悼荣耀+6红蘑菇+1必忘我
	inst.ingredients = { Ingredient("ghostflower", 6), Ingredient("red_cap", 6), Ingredient("forgetmelots", 1) }
end)
-- end
