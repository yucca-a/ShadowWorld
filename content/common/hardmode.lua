-- 三叉戟无法攻击飞行单位
AddPrefabPostInit("trident", function(inst)
    if not TheWorld.ismastersim then return end
    local _DoWaterExplosionEffect = inst.DoWaterExplosionEffect
    inst.DoWaterExplosionEffect = function(inst, v, ...)
        if not v or not v:IsValid() then return end
        if v.Physics == nil then return end -- 无物理组件的实体(如风暴碎片garbagepatchflotsam漂浮物)跳过,避免launch_away访问Physics崩溃
        if v:HasTag("flying") or v:HasTag("swc2hm") or (v.components.health and v:IsOnValidGround()) then return end
        _DoWaterExplosionEffect(inst, v, ...)
    end
end)
AddStategraphPostInit("wilson", function(sg)
    local chop = sg.states.chop.onenter
    sg.states.chop.onenter = function(inst, ...)
        chop(inst, ...)
        inst.sg.statemem.recoilstate = "gnaw_recoil"
    end
    local dig = sg.states.dig.onenter
    sg.states.dig.onenter = function(inst, ...)
        dig(inst, ...)
        inst.sg.statemem.recoilstate = "gnaw_recoil"
    end
end)

-- -- 小丑牌堆禁止检测战斗状态
-- if NON_LIFEFORM_TARGET_TAGS then
-- 	table.insert(NON_LIFEFORM_TARGET_TAGS, 1, "card")
-- end
-- AddPrefabPostInit("deck_of_cards", function(inst)
-- 	if not inst:HasTag("card") then inst:AddTag("card") end
-- end)

-- 流浪商人
TUNING.WANDERINGTRADER_SHOP_REFRESH_INTERVAL = TUNING.WANDERINGTRADER_SHOP_REFRESH_INTERVAL * 5
AddRecipePostInit("wanderingtradershop_gears", function(inst)
    inst.ingredients = {
        Ingredient("pigskin", 3),
        Ingredient("silk", 3),
    }
end)

AddRecipePostInit("wanderingtradershop_pigskin", function(inst)
    inst.ingredients = {
        Ingredient("carrotcake2hm", 1)
    }
    inst.numtogive = 3
end)

AddRecipePostInit("wanderingtradershop_livinglog", function(inst)
    inst.ingredients = {
        Ingredient("pigskin", 3)
    }
end)

-- 扫描工具在裂隙启动前无法扫描启迪碎片
AddPrefabPostInit("winona_recipescanner", function(inst)
	if not TheWorld.ismastersim then return end
	if inst.components.recipescanner then
		local oldfn = inst.components.recipescanner.Scan
		inst.components.recipescanner.Scan = function(self, target, doer, ...)
			if target.prefab == "alterguardianhatshard" and TheWorld.components.riftspawner and not TheWorld.components.riftspawner:GetLunarRiftsEnabled() then
				if doer.components.talker then
					doer:DoTaskInTime(0,function()
						doer.components.talker:Say((TUNING.isCh2hm and "月灵之力阻止我窥探内部..." or "The power of the Moon Spirit prevents me from peering inside..."))
					end)
				end
				return false
			end
			local canlearn , reason = oldfn(self, target, doer, ...)
			return canlearn , reason
		end
	end
end)

-- 幸运值影响概率效能削弱
if GetModConfigData("luck value") then
    local multiplier = 0.25
    local oldGetEntityLuckChance = GLOBAL.GetEntityLuckChance
    if oldGetEntityLuckChance then
        GLOBAL.GetEntityLuckChance = function(inst, chance, ...)
            local result =  oldGetEntityLuckChance(inst, chance, ...)
            if chance and result and chance < 1 and chance < result  then
                local max = math.min(result, 1)
                local change = max - chance
                change = change * multiplier
                result = change + chance
            end
            return result
        end
    end
end

-- 镀金盔甲防御削弱，四骑士刷新时间削弱
if TUNING.ARMOR_YOTH_KNIGHTHAT_ABSORPTION >= .9 then TUNING.ARMOR_YOTH_KNIGHTHAT_ABSORPTION = TUNING.ARMOR_YOTH_KNIGHTHAT_ABSORPTION - 0.05 end
if TUNING.ARMOR_YOTH_KNIGHT_ABSORPTION >= .9 then TUNING.ARMOR_YOTH_KNIGHT_ABSORPTION = TUNING.ARMOR_YOTH_KNIGHT_ABSORPTION - 0.05 end
TUNING.YOTH_PRINCESS_SUMMON_COOLDOWN = TUNING.YOTH_PRINCESS_SUMMON_COOLDOWN * 8

-- 掉落削弱
local cantdrop = {
    "gears",
    "yoth_knighthat",
    "armor_yoth_knight",
}
AddPrefabPostInit("knight_yoth", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.lootdropper then
        local oldfn = inst.components.lootdropper.SpawnLootPrefab
        inst.components.lootdropper.SpawnLootPrefab = function(self, lootprefab, ...)
            if table.contains(cantdrop, lootprefab) then
                if lootprefab == "gears" then return end
                return math.random() < 0.25 and oldfn(self, lootprefab, ...) or nil
            end
            return oldfn(self, lootprefab, ...)
        end
    end
end)

local UpvalueHacker = require("upvaluehacker2hm")
-- -- 小丑机惩罚加大
AddPrefabPostInit("balatro_machine", function(inst)
	 if not TheWorld.ismastersim then return end
     if inst.ondoerremoved then
        if inst.components.activatable then
            local oldfn = inst.components.activatable.CanActivate
            inst.components.activatable.CanActivate = function(self, doer, ...)
                local success, msg
                if oldfn then success, msg = oldfn(self, doer, ...) end
                if self.inst:HasTag("cantusebalatro2hm") then
                    if doer and doer.components.talker then
                        doer:DoTaskInTime(0, function()
                            doer.components.talker:Say((TUNING.isCh2hm and "需要等待60s才能玩" or "You need to wait 60 seconds to play again..."))
                        end)
                    end
                    return false, msg 
                end
                return success, msg
            end
        end
        local _EndInteraction = UpvalueHacker.GetUpvalue(inst.ondoerremoved, "EndInteraction")
        if _EndInteraction then
            local rewards = UpvalueHacker.GetUpvalue(inst.ondoerremoved, "EndInteraction", "REWARDS")
            if rewards and type(rewards) == "table" then
                rewards[1] = {
                    { string = "BEES",      loot = {{"beeguard",   2,  "BEEHIVE_ENABLED" }}    },
                    { string = "HOUNDS",    loot = {{"warglet",   1,      "HOUNDMOUND_ENABLED" }} },
                    { string = "SPIDERS",   loot = {{"spider_dropper",  2,      "SPIDERDEN_ENABLED" }}  },
                }
                rewards[#rewards] = {
                    { string = "BEES",      loot = {{"powder_monkey", 2,  "BEEHIVE_ENABLED" }}    },
                }

                local EndInteraction = function(inst, doer, ...)
                    local score = inst._currentgame.score
                    if score == nil and inst._currentgame.joker ~= nil then
                        -- Game has started, punish people for running away.
                        score = #rewards
                    end
                    _EndInteraction(inst, doer, ...)
                    if score ~= nil and rewards[score] and not inst.task2hm then
                        inst:AddTag("cantusebalatro2hm")
                        inst.task2hm = inst:DoTaskInTime(60, function()
                            inst:RemoveTag("cantusebalatro2hm")
                            inst.task2hm = nil
                        end)
                    end
                end
                UpvalueHacker.SetUpvalue(inst.ondoerremoved, EndInteraction, "EndInteraction")
            end
        end
    end
end)

-- AddPrefabPostInit("powder_monkey", function(inst)
-- 	if not TheWorld.ismastersim then return end
-- 	local _onsve = inst.OnSave
-- 	inst.OnSave = function(inst, data, ...)
-- 		if _onsve then _onsve(inst, data, ...) end
-- 		if inst.components.lootdropper and inst.components.lootdropper.chanceloottable ~= nil then
-- 			data.loots = inst.components.lootdropper.chanceloottable
-- 		end
-- 	end
-- 	local _onload = inst.OnLoad
-- 	inst.OnLoad = function(inst, data, ...)
-- 		if _onload then _onload(inst, data, ...) end
-- 		if data and data.loots == nil then
-- 			if inst.components.lootdropper then
-- 				inst.components.lootdropper:SetChanceLootTable(data.loots)
-- 			end
-- 		end
-- 	end
-- end)

-- 棋子雕像每种类型当天世界只限生成一种
local chesspieces = {
    "chesspiece_bishop_stone",
    "chesspiece_bishop_marble",
    "chesspiece_knight_stone",
    "chesspiece_knight_marble",
    "chesspiece_rook_stone",
    "chesspiece_rook_marble",
    "chesspiece_bishop",
    "chesspiece_knight",
    "chesspiece_rook",
}

local PIECES = {
    chesspiece_bishop = "bishop",
    -- chesspiece_bishop_marble = "bishop",
    chesspiece_knight = "knight",
    -- chesspiece_knight_marble = "knight",
    chesspiece_rook = "rook",
    -- chesspiece_rook_marble = "rook",
}

local MOONCHESS_MUST_TAGS = { "chess_moonevent" }

local function onworkfinished(inst)
    local creaturename = PIECES[inst.prefab]
	local rook_sized_collapse
    if TheWorld.state.isnewmoon or inst.forcebreak == "shadow" then
        creaturename = "shadow_" .. creaturename
    elseif creaturename == "rook" then
        rook_sized_collapse = true
    end
    if creaturename and TheWorld and not TheWorld[creaturename .. "2hm"] and (inst._task ~= nil or inst.forcebreak) then
        inst.SoundEmitter:PlaySound("dontstarve/wilson/rock_break")

        local creature = SpawnPrefab(creaturename)
        creature.Transform:SetPosition(inst.Transform:GetWorldPosition())
        creature.Transform:SetRotation(inst.Transform:GetRotation())
        creature.sg:GoToState("taunt")
        if TheWorld and TheWorld[creaturename .. "2hm"] == nil then TheWorld[creaturename .. "2hm"] = true end
        local player = creature:GetNearestPlayer(true)
        if player ~= nil and creature:IsNear(player, 20) then
            creature.components.combat:SetTarget(player)
        end

        local x, y, z = inst.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities(x, y, z, 12, MOONCHESS_MUST_TAGS)
        local typechess = {}
        typechess[creaturename] = true
        for i, v in ipairs(ents) do
            local prefab_ = PIECES[v.prefab]
            if prefab_ then
                if TheWorld.state.isnewmoon then prefab_ = "shadow_" .. prefab_ end
                if prefab_ and TheWorld and not TheWorld[prefab_ .. "2hm"] and not typechess[prefab_] and v._task and v.forcebreak ~= "shadow" then
                    typechess[prefab_] = true
                    v.forcebreak = inst.forcebreak or "auto"
                end
            end
        end
    end

    inst.components.lootdropper:DropLoot()

	local fx
	if rook_sized_collapse then
		fx = SpawnPrefab("collapse_big")
		fx.Transform:SetScale(0.8, 0.8, 0.8)
	else
		fx = SpawnPrefab("collapse_small")
	end
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("stone")
    inst:Remove()
end

for i, v in pairs(chesspieces) do
    AddPrefabPostInit(v, function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.workable then
            inst.components.workable:SetOnFinishCallback(onworkfinished)
        end
    end)
end

local function cancelstate(world, inst) if inst and inst:HasTag("player") then processplayertags(inst) end end
AddPrefabPostInit("world", function(inst)
    if not inst.ismastersim then return end
    inst:ListenForEvent("phasechanged", function()
        inst.bishop2hm = nil
        inst.shadow_bishop2hm = nil
        inst.knight2hm = nil
        inst.shadow_knight2hm = nil
        inst.rook2hm = nil
        inst.shadow_rook2hm = nil
    end)
end)

-- 煤炭无法灼烧巨兽生物
AddComponentPostInit("trapfumaroleburning", function(self)
    if self.OnUpdate then
        local oldOnUpdate = self.OnUpdate
        self.OnUpdate = function(self, ...)
            if not self.inst:HasTag("player") and self.inst:HasTag("epic") then return end
            return oldOnUpdate(self, ...)
        end
    end
end)