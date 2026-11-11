-----------------------------------------------------------------------------------------
-- 掉落物改动、克劳斯加强、宝石鹿加强、赃物袋奖励不可回档刷
-- 2025.8.17 melon:将(克劳斯加强、宝石鹿加强)从klaus2hm.lua/deer2hm.lua移动到此，改为兼容写法
-- 兼容其它mod的加强及掉落奖励(目前兼容:新界克劳斯及鹿加强、新界掉落、妥协掉无锁、勋章掉包裹)
-----------------------------------------------------------------------------------------
-- 特别的 [若想将克劳斯改回原来的覆盖形式]:
-- 1.取消186-202的注释(包改为召唤klaus2hm)
-- 2.将219行之后全部注释
-----------------------------------------------------------------------------------------
-- 增加赃物袋奖励
-- 远古物品及杂项
local resourcebundle_loot1 =
{
	"orangeamulet",
	"yellowamulet", 
	"greenamulet", 
	"orangestaff", 
	"yellowstaff", 
	"greenstaff", 
	"ruinshat",
	"armorruins", 
	"ruins_bat", 
}

local resourcebundle_loot2 =
{
	"moonglassaxe",
	"glasscutter",
	{"dragonfruit_seeds", 4},
	{"waterplant_planter", 5},
	{"bullkelp_root", 8},
	{"rock_avocado_fruit_sprout", 4},
}

local resourcebundle_loot3 =
{
	{"onion_seeds", 4},
	{"garlic_seeds", 4},
	{"pepper_seeds", 4},
}

local resourcebundle_loot4 =
{
	{"lureplantbulb", 2},
	"armorsnurtleshell",
	{"livinglog", 10},
	{"lightninggoathorn", 3},
	{"walrus_tusk", 2},
}
-- boss物品
local bossbundle_loot1 =
{
	"dragon_scales",
	"bearger_fur",
	"shroom_skin",
	{"royal_jelly", 2},
}

local bossbundle_loot2 =
{
	"minotaurhorn",
	"mandrake",
	"hivehat",
	"deerclops_eyeball",
}

local bossbundle_loot3 =
{
	"mast_malbatross_item",
	"malbatross_beak",
	"trident",
}

local bossbundle_loot4 =
{
	"blue_mushroomhat_blueprint",
	"mushroom_light2_blueprint",
	"mushroom_light_blueprint",
	"bundlewrap_blueprint",
	"sleepbomb_blueprint",
}

local funcaplist =
{
	"red_mushroomhat_blueprint",
	"green_mushroomhat_blueprint",
	"blue_mushroomhat_blueprint",
}

-- melon:用于删除原版的boss包
local delete_loot =
{
    "deerclops_eyeball",
    "dragon_scales",
    "hivehat",
    "shroom_skin",
    "mandrake",
}
local function p(item) -- 区分单个物品或表的情况
    return tostring(type(item) == "table" and item[1] or item)
end
local function p2(loot, before) -- 输出测试用
    TheNet:SystemMessage("删除" .. (before and "前" or "后"))
    for k, i in ipairs(loot) do
        TheNet:SystemMessage(k)
        if type(i) == "table" then
            for _, j in ipairs(i) do
                TheNet:SystemMessage("      " .. p(j))
            end
        end
    end
end
-- 增加赃物袋奖励
AddComponentPostInit("klaussackloot", function(self)
    local oldRollKlausLoot = self.RollKlausLoot
    self.RollKlausLoot = function(self, ...)
        if self.worldstart2hm then return end -- 奖励固定
        oldRollKlausLoot(self, ...)
        -- 去除原有的boss物品包  (新界的boss包也会去除)
        -- p2(self.loot, true) -- 测试输出用
        for k, i in ipairs(self.loot) do
            if type(i) == "table" then
                if table.contains(delete_loot, p(i[1])) then -- 含有boss物品
                    table.remove(self.loot, k) -- 移除这个包
                    break
                end
            end
        end
        -- p2(self.loot) -- 测试输出用
        -- 远古物品及杂项
        local items
        items = {}
        table.insert(items, resourcebundle_loot1[math.random(#resourcebundle_loot1)])
        table.insert(items, resourcebundle_loot2[math.random(#resourcebundle_loot2)])
        table.insert(items, resourcebundle_loot3[math.random(#resourcebundle_loot3)])
        table.insert(items, resourcebundle_loot4[math.random(#resourcebundle_loot4)])
        table.insert(self.loot, items)
        -- 50%概率给懒人塔蓝图
        items = 
        {
            {"goldnugget", 2},
            {"townportaltalisman", math.random(3, 5)},
        }
        if math.random() < .5 then table.insert(items, "townportal_blueprint") end
        table.insert(self.loot, items)
        -- boss物品(会和原版的重复,已去掉原版的)
        items = {}
        table.insert(items, bossbundle_loot1[math.random(#bossbundle_loot1)])
        table.insert(items, bossbundle_loot2[math.random(#bossbundle_loot2)])
        table.insert(items, bossbundle_loot3[math.random(#bossbundle_loot3)])
        local loot = bossbundle_loot4[math.random(#bossbundle_loot4)]
        if math.random(#bossbundle_loot4) == 1 then
            loot = funcaplist[math.random(#funcaplist)]
        end
        table.insert(items, loot)

        table.insert(self.loot, items)
        if not self.worldstart2hm then self.worldstart2hm = 1 end -- 奖励固定
    end
    -- 奖励固定
    local _OnSave = self.OnSave
    self.OnSave = function(self, ...)
        local data
        if _OnSave then data = _OnSave(self, ...) end
        if data and self.worldstart2hm then data.worldstart2hm = self.worldstart2hm end
        return data
    end
    local _OnLoad = self.OnLoad
    self.OnLoad = function(self, data, ...)
        if data ~= nil then
            if _OnLoad then _OnLoad(self, data, ...) end
            if data.worldstart2hm ~= nil then self.worldstart2hm = data.worldstart2hm end
        end
    end
    local oldGetLoot = self.GetLoot
    self.GetLoot = function(self, ...)
        if self.worldstart2hm ~= nli then self.worldstart2hm = nli end
        return oldGetLoot(self, ...)
    end
end)
-----------------------------------------------------------------------------------------
-- 包改为召唤klaus2hm    melon:注释掉,改召原来的
-- AddPrefabPostInit("klaus_sack", function(inst)
--     if not TheWorld.ismastersim then return end
--     if inst.components.klaussacklock then
--         local oldonusekeyfn = inst.components.klaussacklock.onusekeyfn
--         inst.components.klaussacklock.onusekeyfn = function(inst, key, doer, ...)
--             local _SpawnPrefab = GLOBAL.SpawnPrefab
--             GLOBAL.SpawnPrefab = function(name, ...)
--                 if name == "klaus" then name = "klaus2hm" end
--                 local ent = _SpawnPrefab(name, ...)
--                 return ent
--             end
--             local reason, word, cause = oldonusekeyfn(inst, key, doer, ...)
--             GLOBAL.SpawnPrefab = _SpawnPrefab
--             return reason, word, cause
--         end
--     end
-- end)
-----------------------------------------------------------------------------------------
-- 奖励固定?
AddPrefabPostInit("klaus_sack", function(inst)
    if not TheWorld.ismastersim then return end
    inst:DoTaskInTime(0, function(inst)
        if TheWorld.components.klaussackloot then
            TheWorld.components.klaussackloot:RollKlausLoot()
        end
    end)
end)

-----------------------------------------------------------------------------------------
-- 2025.8.17 melon:克劳斯加强移动到这里---------------------------------------------------
-----------------------------------------------------------------------------------------
-- 脑部
-- local brain = require("brains/klausbrain2hm")
local function ShouldEnrage(inst)
    -- 2025.9.3 melon:因为是DoTask(0.2,) 开始访问不到TotalDeer会报nil
    return not inst.enraged and
        (inst.components.commander:GetNumSoldiers() < (inst.TotalDeer or 2) or inst.soulcount and inst.soulcount>=30) -- 兼容新界的吸魂，2025.9.3 melon:20魂狂暴改成30魂
end
AddBrainPostInit("klausbrain", function(self)
    -- 2025.8.26 melon:需要排除影子，否则影子很容易狂暴
    if self.inst.prefab~="klaus" or self.inst:HasTag("swc2hm") then return end
    self.bt.root.children[1].children[1].fn = function() return ShouldEnrage(self.inst) end
end)
-----------------------------------------------------------------------------------------
local loot =
{
    "monstermeat",
    "charcoal",
	"krampus_sack",
	"chesspiece_klaus_sketch",
}

local function SetPhysicalScale(inst, scale)
    local xformscale = 1.2 * scale
    inst.Transform:SetScale(xformscale, xformscale, xformscale)
    inst.DynamicShadow:SetSize(3.5 * scale, 1.5 * scale)
    if scale > 1 then
        inst.Physics:SetMass(1000 * scale)
        inst.Physics:SetCapsule(1.2 * scale, 1)
    end
end

local function SetStatScale(inst, scale)
    inst.deer_dist = 3.5 * scale
    inst.hit_recovery = TUNING.KLAUS_HIT_RECOVERY * scale
    inst.attack_range = TUNING.KLAUS_ATTACK_RANGE * scale
    inst.hit_range = TUNING.KLAUS_HIT_RANGE * scale
    inst.chomp_cd = TUNING.KLAUS_CHOMP_CD / scale
    inst.chomp_range = math.min(TUNING.KLAUS_CHOMP_MAX_RANGE, TUNING.KLAUS_CHOMP_RANGE * scale)
    inst.chomp_min_range = TUNING.KLAUS_CHOMP_MIN_RANGE * scale
    inst.chomp_hit_range = TUNING.KLAUS_CHOMP_HIT_RANGE * scale

    inst.components.combat:SetRange(inst.attack_range, inst.hit_range)
    inst.components.combat:SetAttackPeriod(TUNING.KLAUS_ATTACK_PERIOD / scale)

    scale = scale * scale * scale
    local health_percent = inst.components.health:GetPercent()
    inst.components.health:SetMaxHealth(TUNING.KLAUS_HEALTH * scale)
    inst.components.health:SetPercent(health_percent)
    inst.components.health:SetAbsorptionAmount(scale > 1 and 1 - 1 / scale or 0) --don't want any floating point errors!
    inst.components.combat:SetDefaultDamage(TUNING.KLAUS_DAMAGE * scale)
end

local function PushWarning(inst, strid)
    for k, v in pairs(inst.recentattackers) do
        if k:IsValid() then
            inst:DoTaskInTime(math.random(), AnnounceWarning, k, strid)
        end
    end
end

local function UpdatePlayerTargets(inst)
    local toadd = {}
    local toremove = {}
    local pos = inst.components.knownlocations:GetLocation("spawnpoint")

    for k, v in pairs(inst.components.grouptargeter:GetTargets()) do
        toremove[k] = true
    end
    for i, v in ipairs(FindPlayersInRange(pos.x, pos.y, pos.z, inst.DeaggroRange, true)) do
        if toremove[v] then
            toremove[v] = nil
        else
            table.insert(toadd, v)
        end
    end

    for k, v in pairs(toremove) do
        inst.components.grouptargeter:RemoveTarget(k)
    end
    for i, v in ipairs(toadd) do
        inst.components.grouptargeter:AddTarget(v)
    end
end
local function RetargetFn(inst)
    UpdatePlayerTargets(inst)

    local target = inst.components.combat.target
    local inrange = target ~= nil and inst:IsNear(target, inst.attack_range + target:GetPhysicsRadius(0))

    if target ~= nil and target:HasTag("player") then
        local newplayer = inst.components.grouptargeter:TryGetNewTarget()
        return newplayer ~= nil
            and newplayer:IsNear(inst, inrange and inst.attack_range + newplayer:GetPhysicsRadius(0) or TUNING.KLAUS_AGGRO_DIST)  --kaxzer
            and newplayer
            or nil,
            true
    end

    local nearplayers = {}
    for k, v in pairs(inst.components.grouptargeter:GetTargets()) do
        if inst:IsNear(k, inrange and inst.attack_range + k:GetPhysicsRadius(0) or TUNING.KLAUS_AGGRO_DIST) then
            table.insert(nearplayers, k)
        end
    end
    return #nearplayers > 0 and nearplayers[math.random(#nearplayers)] or nil, true
end
local function KeepTargetFn(inst, target)
    return inst.components.combat:CanTarget(target)
        and target:GetDistanceSqToPoint(inst.components.knownlocations:GetLocation("spawnpoint")) < inst.DeaggroRange * inst.DeaggroRange
end
local function SummonHelpersTwo(inst, warning)

    if inst.nohelpers then
		if inst.nohelpers == false then
			return false
		end
    end
    inst.nohelpers = false

    local x, y, z = inst.Transform:GetWorldPosition()
    local rangesq = TUNING.KLAUS_DEAGGRO_DIST * TUNING.KLAUS_DEAGGRO_DIST
    local targets = {}
    for k, v in pairs(inst.recentattackers) do
        if k:IsValid() and not (k.components.health:IsDead() or k:HasTag("playerghost")) then
            local distsq = k:GetDistanceSqToPoint(x, y, z)
            if distsq < rangesq then
                table.insert(targets, { inst = k, distsq = distsq })
            end
        end
    end
    local target = inst.components.combat.target
    if target ~= nil and
        inst.recentattackers[target] == nil and
        target:IsValid() and
        target:HasTag("player") and
        not (target.components.health:IsDead() or target:HasTag("playerghost")) then
        local distsq = target:GetDistanceSqToPoint(x, y, z)
        if distsq < rangesq then
            table.insert(targets, { inst = target, distsq = distsq })
        end
    end
    if #targets > 0 then
        table.sort(targets, NearToFar)
        local stock = TUNING.KLAUS_NAUGHTY_MAX_SPAWNS
        for i, v in ipairs(targets) do
            local numspawns = stock > 0 and math.min(TUNING.KLAUS_NAUGHTY_MIN_SPAWNS, math.ceil(stock / #targets)) or 0
            --PKaxzerush event even if numspawns is 0
            TheWorld:PushEvent("ms_forcenaughtiness", { player = v.inst, numspawns = numspawns })
            stock = stock - numspawns
        end
        if warning then
            PushWarning(inst, "ANNOUNCE_KLAUS_CALLFORHELP")
        end
        return true
    end
    return false
end
local function UpdateDeerOffsets(inst)
    if inst.components.commander:GetNumSoldiers() > 0 then
	
	local phase = inst:GetCurrentPhase()
	
	if inst.components.explosiveresist ~= nil then
		inst.components.explosiveresist:SetResistance(1)
	end
	
	if phase == 2 then
		if inst.rotationTimer == nil then
			inst.rotationTimer = 0
		else
			inst.rotationTimer = inst.rotationTimer + 45
			if inst.rotationTimer >= 360 then
				inst.rotationTimer = 0
			end
		end
	
	
        local deers = inst.components.commander:GetAllSoldiers()
		local theta = inst.rotationTimer * DEGREES
        local xoffs = 1.2 * inst.deer_dist * math.sin(theta)
        local zoffs = 1.2 * inst.deer_dist * math.cos(theta)
        local x, y, z = inst.Transform:GetWorldPosition()
        local x1, z1 = x - xoffs, z - zoffs
        x, z = x + xoffs, z + zoffs
        if #deers > 1 then
			for i = 1, #deers do
				if i % 2 == 0 then
					deers[i]:OnUpdateOffset(Vector3(xoffs, 0, zoffs))
				else
					deers[i]:OnUpdateOffset(Vector3(-xoffs, 0, -zoffs))
				end
			end
        elseif #deers > 0 then
            deers[1]:OnUpdateOffset(deers[1]:GetDistanceSqToPoint(x, 0, z) < deers[1]:GetDistanceSqToPoint(x1, 0, z1) and Vector3(xoffs, 0, zoffs) or Vector3(-xoffs, 0, -zoffs))
        end
	elseif phase == 3 then
		if inst.rotationTimer == nil then
			inst.rotationTimer = 0
		else
			inst.rotationTimer = inst.rotationTimer + 45
			if inst.rotationTimer >= 360 then
				inst.rotationTimer = 0
			end
		end
		
		local distfactor = 0
		if inst.rotationTimer < 180 then
			distfactor = inst.rotationTimer / 180
		else
			distfactor = 1 - (inst.rotationTimer - 180) / 180
		end
	
        local deers = inst.components.commander:GetAllSoldiers()
		local theta = inst.rotationTimer * DEGREES
        local xoffs = inst.deer_dist * math.sin(theta)
        local zoffs = inst.deer_dist * math.cos(theta)
        local x, y, z = inst.Transform:GetWorldPosition()
        local x1, z1 = x - xoffs, z - zoffs
        x, z = x + xoffs, z + zoffs
        if #deers > 1 then
			for i = 1, #deers do
			
				local xoffs_new = xoffs
				local zoffs_new = zoffs
			
				if i > 2 then
					xoffs_new = xoffs_new * (1.2 + (1 - distfactor) * 2.8)
					zoffs_new = zoffs_new * (1.2 + (1 - distfactor) * 2.8)
				else
					xoffs_new = xoffs_new * (1.2 + distfactor * 2.8)
					zoffs_new = zoffs_new * (1.2 + distfactor * 2.8)
				end
				if i == 1 then
					deers[i]:OnUpdateOffset(Vector3(inst.deer_dist * (1.0 + distfactor * 2.5), 0, 0))
				elseif i == 2 then
					deers[i]:OnUpdateOffset(Vector3(0, 0, inst.deer_dist * (1.0 + (1 - distfactor) * 2.5)))
				elseif i == 3 then
					deers[i]:OnUpdateOffset(Vector3(-inst.deer_dist * (1.0 + distfactor * 2.5), 0, 0))
				elseif i == 4 then
					deers[i]:OnUpdateOffset(Vector3(0, 0, -inst.deer_dist * (1.0 + (1 - distfactor) * 2.5)))
				end
			end
        elseif #deers > 0 then
            deers[1]:OnUpdateOffset(deers[1]:GetDistanceSqToPoint(x, 0, z) < deers[1]:GetDistanceSqToPoint(x1, 0, z1) and Vector3(xoffs, 0, zoffs) or Vector3(-xoffs, 0, -zoffs))
        end
	elseif phase == 7 then
	
		local currentHealth = inst.components.health:GetPercent()
	
		inst.chomp_cd = 6 - 2 * (1 - (currentHealth - 0.1) / 0.2)
	
		if inst.rotationTimer == nil then
			inst.rotationTimer = 0
		else
			inst.rotationTimer = inst.rotationTimer + 45
			if inst.rotationTimer >= 360 then
				inst.rotationTimer = 0
			end
		end
		
		local distfactor = 0
		if inst.rotationTimer < 180 then
			distfactor = inst.rotationTimer / 180
		else
			distfactor = 1 - (inst.rotationTimer - 180) / 180
		end
	
        local deers = inst.components.commander:GetAllSoldiers()
		local theta = inst.rotationTimer * DEGREES
        local xoffs = inst.deer_dist * math.sin(theta)
        local zoffs = inst.deer_dist * math.cos(theta)
        local x, y, z = inst.Transform:GetWorldPosition()
        local x1, z1 = x - xoffs, z - zoffs
        x, z = x + xoffs, z + zoffs
        if #deers > 1 then
			for i = 1, #deers do
			
				local xoffs_new = xoffs
				local zoffs_new = zoffs
			
				if i > 2 then
					xoffs_new = xoffs_new * (1.2 + (1 - distfactor) * 2.8)
					zoffs_new = zoffs_new * (1.2 + (1 - distfactor) * 2.8)
				else
					xoffs_new = xoffs_new * (1.2 + distfactor * 2.8)
					zoffs_new = zoffs_new * (1.2 + distfactor * 2.8)
				end
				if i == 1 then
					deers[i]:OnUpdateOffset(Vector3(inst.deer_dist * (1.0 + distfactor * 2.5), 0, 0))
				elseif i == 2 then
					deers[i]:OnUpdateOffset(Vector3(0, 0, inst.deer_dist * (1.0 + (1 - distfactor) * 2.5)))
				elseif i == 3 then
					deers[i]:OnUpdateOffset(Vector3(-inst.deer_dist * (1.0 + distfactor * 2.5), 0, 0))
				elseif i == 4 then
					deers[i]:OnUpdateOffset(Vector3(0, 0, -inst.deer_dist * (1.0 + (1 - distfactor) * 2.5)))
				end
			end
        elseif #deers > 0 then
            deers[1]:OnUpdateOffset(deers[1]:GetDistanceSqToPoint(x, 0, z) < deers[1]:GetDistanceSqToPoint(x1, 0, z1) and Vector3(xoffs, 0, zoffs) or Vector3(-xoffs, 0, -zoffs))
        end
	elseif phase == 4 then
	
		if inst.spellForceTimer == nil then
			inst.spellForceTimer = 1
		else
			inst.spellForceTimer = inst.spellForceTimer + 1
			if inst.spellForceTimer > 1 then
				inst:DoTaskInTime(2, function() inst:PushEvent("doforcecast") end)
				inst.spellForceTimer = 0
			end
		end
	
        local deers = inst.components.commander:GetAllSoldiers()
        local theta = inst.Transform:GetRotation() * DEGREES
        local xoffs = inst.deer_dist * math.sin(theta)
        local zoffs = inst.deer_dist * math.cos(theta)
        local x, y, z = inst.Transform:GetWorldPosition()
        local x1, z1 = x - xoffs, z - zoffs
        if #deers > 3 then
			if inst.components.combat.target ~= nil then
				local x2, y2, z2 = inst.components.combat.target.Transform:GetWorldPosition()
				x2 = x2 - x
				z2 = z2 - z
				deers[1]:OnUpdateOffset(Vector3(x2 + 4.7, 0, z2))
				deers[2]:OnUpdateOffset(Vector3(x2, 0, z2 + 4.7))
				deers[3]:OnUpdateOffset(Vector3(x2 - 4.7, 0, z2))
				deers[4]:OnUpdateOffset(Vector3(x2, 0, z2 - 4.7))
			end
			
        elseif #deers > 0 then
            deers[1]:OnUpdateOffset(deers[1]:GetDistanceSqToPoint(x, 0, z) < deers[1]:GetDistanceSqToPoint(x1, 0, z1) and Vector3(xoffs, 0, zoffs) or Vector3(-xoffs, 0, -zoffs))
        end
	elseif phase == 5 then
	
		if inst.spellForceTimer == nil then
			inst.spellForceTimer = 1
		else
			inst.spellForceTimer = inst.spellForceTimer + 1
			if inst.spellForceTimer > 1 then
				inst:DoTaskInTime(2, function() inst:PushEvent("doforcecast") end)
				inst.spellForceTimer = 0
			end
		end
		
		if inst.rotationTimer == nil then
			inst.rotationTimer = 0
		else
			inst.rotationTimer = inst.rotationTimer + 20
			if inst.rotationTimer >= 360 then
				inst.rotationTimer = 0
			end
		end
	
        local deers = inst.components.commander:GetAllSoldiers()
        local theta = inst.rotationTimer * DEGREES
        local xoffs = inst.deer_dist * math.sin(theta)
        local zoffs = inst.deer_dist * math.cos(theta)
        local x, y, z = inst.Transform:GetWorldPosition()
        local x1, z1 = x - xoffs, z - zoffs
        if #deers > 3 then


			deers[1]:OnUpdateOffset(Vector3(xoffs * 1.2, 0, zoffs * 1.2))
			deers[2]:OnUpdateOffset(Vector3(-xoffs * 1.2, 0, -zoffs * 1.2))

			if inst.components.combat.target ~= nil then
			if inst.spellForceTimer == 1 then
				local x2, y2, z2 = inst.components.combat.target.Transform:GetWorldPosition()
				x2 = x2 - x
				z2 = z2 - z
				deers[3]:OnUpdateOffset(Vector3(x2 + xoffs * 3.5, 0, z2 + zoffs * 3.5))
				deers[4]:OnUpdateOffset(Vector3(x2 - xoffs * 3.5, 0, z2 - zoffs * 3.5))
			end
			end
			
        elseif #deers > 0 then
            deers[1]:OnUpdateOffset(deers[1]:GetDistanceSqToPoint(x, 0, z) < deers[1]:GetDistanceSqToPoint(x1, 0, z1) and Vector3(xoffs, 0, zoffs) or Vector3(-xoffs, 0, -zoffs))
        end
	elseif phase == 6 then
		if inst.spellForceTimer == nil then
			inst.spellForceTimer = 1
		else
			inst.spellForceTimer = inst.spellForceTimer + 1
			if inst.spellForceTimer > 1 then
				inst:DoTaskInTime(2, function() inst:PushEvent("doforcecast") end)
				inst.spellForceTimer = 0
			end
		end
	
        local deers = inst.components.commander:GetAllSoldiers()
        local theta = inst.Transform:GetRotation() * DEGREES
        local xoffs = inst.deer_dist * math.sin(theta)
        local zoffs = inst.deer_dist * math.cos(theta)
        local x, y, z = inst.Transform:GetWorldPosition()
        local x1, z1 = x - xoffs, z - zoffs
        if #deers > 3 then
			if inst.components.combat.target ~= nil then
				local x2, y2, z2 = inst.components.combat.target.Transform:GetWorldPosition()
				x2 = x2 - x
				z2 = z2 - z
				deers[1]:OnUpdateOffset(Vector3(x2 + 5.5, 0, z2))
				deers[2]:OnUpdateOffset(Vector3(x2, 0, z2 + 5.5))
				deers[3]:OnUpdateOffset(Vector3(x2 - 5.5, 0, z2))
				deers[4]:OnUpdateOffset(Vector3(x2, 0, z2 - 5.5))
			end
			
        elseif #deers > 0 then
            deers[1]:OnUpdateOffset(deers[1]:GetDistanceSqToPoint(x, 0, z) < deers[1]:GetDistanceSqToPoint(x1, 0, z1) and Vector3(xoffs, 0, zoffs) or Vector3(-xoffs, 0, -zoffs))
        end
	elseif phase == 8 then
	
		inst.DeaggroRange = TUNING.KLAUS_DEAGGRO_DIST * 3
	
		local currentHealth = inst.components.health:GetPercent()
	
		if currentHealth <= 0.03 then
			inst.chomp_cd = 2.4
		else
			inst.chomp_cd = 4 - 1.6 * (1 - (currentHealth - 0.03) / 0.07)
		end
        local deers = inst.components.commander:GetAllSoldiers()
        local theta = inst.Transform:GetRotation() * DEGREES
        local xoffs = inst.deer_dist * math.sin(theta)
        local zoffs = inst.deer_dist * math.cos(theta)
        local x, y, z = inst.Transform:GetWorldPosition()
        local x1, z1 = x - xoffs, z - zoffs
        if #deers > 3 then
			if inst.components.combat.target ~= nil then
				local x2, y2, z2 = inst.components.combat.target.Transform:GetWorldPosition()
				x2 = x2 - x
				z2 = z2 - z
				deers[1]:OnUpdateOffset(Vector3(x2 + 12.0, 0, z2))
				deers[2]:OnUpdateOffset(Vector3(x2, 0, z2 + 12.0))
				deers[3]:OnUpdateOffset(Vector3(x2 - 12.0, 0, z2))
				deers[4]:OnUpdateOffset(Vector3(x2, 0, z2 - 12.0))
			end
			
        elseif #deers > 0 then
            deers[1]:OnUpdateOffset(deers[1]:GetDistanceSqToPoint(x, 0, z) < deers[1]:GetDistanceSqToPoint(x1, 0, z1) and Vector3(xoffs, 0, zoffs) or Vector3(-xoffs, 0, -zoffs))
        end
	else
        local deers = inst.components.commander:GetAllSoldiers()
        local theta = inst.Transform:GetRotation() * DEGREES
        local xoffs = inst.deer_dist * math.sin(theta)
        local zoffs = inst.deer_dist * math.cos(theta)
        local x, y, z = inst.Transform:GetWorldPosition()
        local x1, z1 = x - xoffs, z - zoffs
        x, z = x + xoffs, z + zoffs
        if #deers > 1 then
            local score1 = deers[1]:GetDistanceSqToPoint(x, 0, z) + deers[2]:GetDistanceSqToPoint(x1, 0, z1)
            local score2 = deers[2]:GetDistanceSqToPoint(x, 0, z) + deers[1]:GetDistanceSqToPoint(x1, 0, z1)
            if score1 < score2 then
                deers[1]:OnUpdateOffset(Vector3(xoffs, 0, zoffs))
                deers[2]:OnUpdateOffset(Vector3(-xoffs, 0, -zoffs))
            else
                deers[2]:OnUpdateOffset(Vector3(xoffs, 0, zoffs))
                deers[1]:OnUpdateOffset(Vector3(-xoffs, 0, -zoffs))
            end
        elseif #deers > 0 then
            deers[1]:OnUpdateOffset(deers[1]:GetDistanceSqToPoint(x, 0, z) < deers[1]:GetDistanceSqToPoint(x1, 0, z1) and Vector3(xoffs, 0, zoffs) or Vector3(-xoffs, 0, -zoffs))
        end
	end
    end
end

local function EnterPhase2Trigger(inst)
    if not (inst.enraged or inst:IsUnchained() or inst.components.health:IsDead()) then
		inst.tasktime = 4.0
		inst.taskPG:Cancel()
		inst.taskPG = inst:DoPeriodicTask(inst.tasktime, UpdateDeerOffsets)
        inst:PushEvent("transition")
	elseif inst:IsUnchained() and inst.components.health:IsDead() == false then
		inst.tasktime = 5.0
		inst.taskPG:Cancel()
		inst.taskPG = inst:DoPeriodicTask(inst.tasktime, UpdateDeerOffsets)
    end
end

local function SpawnDeer(inst)
	--for i = 1, 4 do
    local pos = inst:GetPosition()
    local rot = inst.Transform:GetRotation()
    local theta = (rot - 90) * DEGREES
    local offset =
        FindWalkableOffset(pos, theta, inst.deer_dist, 5, true, false) or
        FindWalkableOffset(pos, theta, inst.deer_dist * .5, 5, true, false) or
        Vector3(0, 0, 0)

    local deer = SpawnPrefab("deer_red") -- test##  原本deer_red2hm
    deer.Transform:SetRotation(rot)
    deer.Transform:SetPosition(pos.x + offset.x, 0, pos.z + offset.z)
    deer.components.spawnfader:FadeIn()
    inst.components.commander:AddSoldier(deer)

    theta = (rot + 90) * DEGREES
    offset =
        FindWalkableOffset(pos, theta, inst.deer_dist, 5, true, false) or
        FindWalkableOffset(pos, theta, inst.deer_dist * .5, 5, true, false) or
        Vector3(0, 0, 0)

    deer = SpawnPrefab("deer_blue") -- test##  原本deer_blue2hm
    deer.Transform:SetRotation(rot)
    deer.Transform:SetPosition(pos.x + offset.x, 0, pos.z + offset.z)
    deer.components.spawnfader:FadeIn()
    inst.components.commander:AddSoldier(deer)
	--end
end
local function Unchain(inst, warning)
    if not inst._unchained:value() then
        inst.AnimState:Hide("swap_chain")
        inst.AnimState:Hide("swap_chain_lock")
        inst.components.sanityaura.aura = inst.enraged and -TUNING.SANITYAURA_HUGE or -TUNING.SANITYAURA_LARGE
        inst.components.burnable.nocharring = false
		inst:SummonHelpersTwo(false)
        inst.DoFoleySounds = DoNothing
        inst._unchained:set(true)
        OnMusicDirty(inst)
        if warning then
            PushWarning(inst, "ANNOUNCE_KLAUS_UNCHAINED")
        end
    end
end
local function Enrage(inst, warning)
    if not inst.enraged then
        inst.enraged = true
        inst.nohelpers = nil --redundant when enraged
        inst.Physics:Stop()
        inst.Physics:Teleport(inst.Transform:GetWorldPosition())
        SetPhysicalScale(inst, TUNING.KLAUS_ENRAGE_SCALE)
        SetStatScale(inst, TUNING.KLAUS_ENRAGE_SCALE)
        inst.components.sanityaura.aura = inst:IsUnchained() and -TUNING.SANITYAURA_HUGE or -TUNING.SANITYAURA_LARGE
        if warning then
            PushWarning(inst, "ANNOUNCE_KLAUS_ENRAGE")
        end
    end
end
local function TrickAttack(inst)
	if not inst:IsUnchained() then
        if not inst.components.health:IsDead() then
            if not inst.sg:HasStateTag("transition") then
                inst.sg:GoToState("attack")
            end
        end
	end
end
local function OnSave(inst, data)
    data.nohelpers = inst.nohelpers or nil
    data.unchained = inst:IsUnchained() or nil
    data.enraged = inst.enraged or nil
	data.deerWaveOne = inst.deerWaveOne or nil
	data.tasktime = inst.tasktime or nil
	data.TotalDeer = inst.TotalDeer or 2
end
local function OnPreLoad(inst, data)
    if data ~= nil then
        if data.nohelpers then
            inst.nohelpers = true
        end
        if data.unchained then
            Unchain(inst)
        end
        if data.enraged then
            Enrage(inst)
        end
        if data.deerWaveOne then
            inst.deerWaveOne = data.deerWaveOne
        end
		if data.tasktime then
			inst.tasktime = data.tasktime
		end
		if data.TotalDeer then
			inst.TotalDeer = data.TotalDeer
		end
    end
end
local function getrandomposition(caster, teleportee)
    local centers = {}
    for i, node in ipairs(TheWorld.topology.nodes) do
        if TheWorld.Map:IsPassableAtPoint(node.x, 0, node.y) and node.type ~= NODE_TYPE.SeparatedRoom then
            table.insert(centers, {x = node.x, z = node.y})
        end
    end
    if #centers > 0 then
        local pos = centers[math.random(#centers)]
        return Point(pos.x, 0, pos.z)
    else
        return caster:GetPosition()
    end
end
local function OnCollide(inst, other)
    if other ~= nil and
        other:IsValid() and
        other.components.workable ~= nil and
        other.components.workable:CanBeWorked() and
        other.components.workable.action ~= ACTIONS.DIG and
        other.components.workable.action ~= ACTIONS.NET and
        not inst.recentlycharged[other] then
        inst:DoTaskInTime(2 * FRAMES, OnDestroyOther, other)
			if other:HasTag("stagehand") then
				local locpos = getrandomposition(inst, other)
				if other.Physics ~= nil then
					other.Physics:Teleport(locpos.x, 0, locpos.z)
				else
					other.Transform:SetPosition(locpos.x, 0, locpos.z)
				end
			end
    end
	
    if other ~= nil and
        other:IsValid() and
		other.components.health ~= nil then
			if other:HasTag("lureplant") or other:HasTag("spiderden") then
				other.components.health:Kill()
			end
    end
end

local function NoHoles(pt)
    return not TheWorld.Map:IsPointNearHole(pt)
end

local function GetSpawnPoint(pt)
    if not TheWorld.Map:IsAboveGroundAtPoint(pt:Get()) then
        pt = FindNearbyLand(pt, 1) or pt
    end
    local offset = FindWalkableOffset(pt, math.random() * 2 * PI, 30, 12, true, true, NoHoles)
    if offset ~= nil then
        offset.x = offset.x + pt.x
        offset.z = offset.z + pt.z
        return offset
    end
end

local function ChangeDeerTaskTime(inst, newtasktime, phaseID)
	if phaseID == 1 then
		if inst:IsUnchained() then
			return nil
		end
	elseif phaseID == 2 then
		if not inst:IsUnchained() then
			return nil
		end
	end
	inst.tasktime = newtasktime
	inst.taskPG:Cancel()
    inst.taskPG = inst:DoPeriodicTask(inst.tasktime, UpdateDeerOffsets)
	
end

local function SpawnDeerWaveOne(inst)
	if inst.deerWaveOne == true then
		return nil
	end

	inst.deerWaveOne = true

    local pt = inst:GetPosition()
    local spawn_pt = GetSpawnPoint(pt)
    if spawn_pt ~= nil then
        local deer = SpawnPrefab("deer_red") -- test##  原本deer_red2hm
        deer.Physics:Teleport(spawn_pt:Get())
        deer:FacePoint(pt)
		deer.components.spawnfader:FadeIn()
		inst.components.commander:AddSoldier(deer)
		inst.TotalDeer = inst.TotalDeer + 1
    end
	
	spawn_pt = nil
	
	pt = inst:GetPosition()
    spawn_pt = GetSpawnPoint(pt)
    if spawn_pt ~= nil then
        local deer = SpawnPrefab("deer_blue") -- test##  原本deer_blue2hm
        deer.Physics:Teleport(spawn_pt:Get())
        deer:FacePoint(pt)
		deer.components.spawnfader:FadeIn()
		inst.components.commander:AddSoldier(deer)
		inst.TotalDeer = inst.TotalDeer + 1
    end
end

local function GetCurrentPhase(inst)
	local healthPercentage = inst.components.health:GetPercent()
	if inst:IsUnchained() then
		if healthPercentage <= 0.1 then
			return 8
		elseif healthPercentage <= 0.3 then
			return 7
		else
			return 6
		end
	else
		if healthPercentage <= 0.25 then
			return 5
		elseif healthPercentage <= 0.5 then
			return 4
		elseif healthPercentage <= 0.75 then
			return 3
		elseif healthPercentage <= 0.9 then
			return 2
		else
			return 1
		end
	end
end

local function OnHitOther(inst, other, damage)
	if math.random() <= 0.15 * inst:GetCurrentPhase() then
		inst.components.thief:StealItemRandom(other)
	end
end

AddPrefabPostInit("klaus", function(inst)
    if not TheWorld.ismastersim then return end
    inst.changetask2hm = inst:DoTaskInTime(0.2,function(inst) -- 0可能访问不到swc2hm标签
        if inst:HasTag("swc2hm") then return end -- 2025.8.28 melon:不用task访问不到swc2hm标签
        local src = "scripts/prefabs/klaus.lua"
        local periodtask = nil
        local count_task = 0
        if inst.pendingtasks then
            -- TheNet:SystemMessage(tostring(GetTableSize(inst.pendingtasks)))
            for a,b in pairs(inst.pendingtasks) do
                -- TheNet:SystemMessage(debug.getinfo(a.fn, "S").source or "nil")
                -- 路径对、间隔对
                if debug.getinfo(a.fn, "S").source == src and a.period == 0.5 then
                    periodtask = a
                    count_task = count_task + 1
                end
            end
        end
        -- 满足条件对克劳斯进行修改
        if periodtask ~= nil and count_task == 1 then
            -- 新增
            inst:AddComponent("thief")
            inst.deerWaveOne = false
            inst.components.healthtrigger:AddTrigger(0.75, SpawnDeerWaveOne)
            inst.components.healthtrigger:AddTrigger(0.9, function() ChangeDeerTaskTime(inst, 1.5, 1) end)
            inst.components.healthtrigger:AddTrigger(0.25, function() ChangeDeerTaskTime(inst, 1.5, 1) end)
            inst.components.healthtrigger:AddTrigger(0.3, function() ChangeDeerTaskTime(inst, 1.5, 2) end)
            -- 2025.8.22 melon:兼容写法  兼容新界
            local _onhitotherfn = inst.components.combat.onhitotherfn
            inst.components.combat.onhitotherfn = function(inst, other, damage, ...)
                if _onhitotherfn ~= nil then _onhitotherfn(inst, other, damage, ...) end
                OnHitOther(inst, other, damage, ...)
            end
            inst.components.commander:SetTrackingDistance(30 * 12)
            inst:SetStateGraph("SGklaus2hm")
            inst.DeaggroRange = TUNING.KLAUS_DEAGGRO_DIST
            inst.TotalDeer = 2
            inst.GetCurrentPhase = GetCurrentPhase
            inst.SpawnDeerWaveOne = SpawnDeerWaveOne
            inst.SummonHelpersTwo = SummonHelpersTwo
            inst.TrickAttack = TrickAttack
            inst.ChangeDeerTaskTime = ChangeDeerTaskTime
            -- 修改task
            periodtask:Cancel() -- 取消原有task
            inst.tasktime = 0.5
            inst.taskPG = inst:DoPeriodicTask(inst.tasktime, UpdateDeerOffsets)
            -- 其它修改
            inst.components.lootdropper:SetLoot(loot)
            inst.Physics:SetCollisionCallback(OnCollide)
            inst.components.combat:SetRetargetFunction(3, RetargetFn)
            inst.components.combat:SetKeepTargetFunction(KeepTargetFn)
            -- 2025.8.26 melon:克劳斯狂暴回到1/3血
            inst.Enrage = function(inst, warning) -- 直接覆盖
                -- TheNet:SystemMessage(tostring(inst.components.health:GetPercent()))
                if inst.components.health ~= nil and inst.components.health:GetPercent() < 0.33 then
                    inst.components.health:SetPercent(0.33, 0.5, "enrage")
                end
                Enrage(inst, warning)
            end
        end
    end)
end)

-- 对其它地方的改动-------------------------------
AddPrefabPostInit("stagehand", function(inst) inst:AddTag("stagehand") end)

AddComponentPostInit("inventory", function(self)
    function self:FindItemRandom(fn) -- 添加新function
        local itemList = {}
        for k = 1, self.maxslots do
            if self.itemslots[k] and fn(self.itemslots[k]) then
                table.insert(itemList, self.itemslots[k])
            end
        end
        if #itemList <= 0 then return nil end
        return itemList[math.random(1, #itemList)]
    end
end)

AddComponentPostInit("thief", function(self)
    function self:StealItemRandom(victim, itemtosteal, attack) -- 添加新function
        if victim.components.inventory ~= nil and victim.components.inventory.isopen then
            local item = itemtosteal or victim.components.inventory:FindItemRandom(function(item) return not item:HasTag("nosteal") end)
            if attack then
                self.inst.components.combat:DoAttack(victim)
            end
            if item then
                local direction = Vector3(self.inst.Transform:GetWorldPosition()) - Vector3(victim.Transform:GetWorldPosition())
                victim.components.inventory:DropItem(item, false, direction:GetNormalized())
                table.insert(self.stolenitems, item)
                if self.onstolen then
                    self.onstolen(self.inst, victim, item)
                end
            end
        elseif victim.components.container then
            local item = itemtosteal or victim.components.container:FindItem(function(item) return not item:HasTag("nosteal") end)
            if attack then
                if victim.components.equippable and victim.components.inventoryitem and victim.components.inventoryitem.owner  then 
                    self.inst.components.combat:DoAttack(victim.components.inventoryitem.owner)
                end
            end
            victim.components.container:DropItem(item)
            table.insert(self.stolenitems, item)
            if self.onstolen then
                self.onstolen(self.inst, victim, item)
            end
        end
    end
end)

-----------------------------------------------------------------------------------------
-- 2025.8.17 melon:宝石鹿加强移动到这里---------------------------------------------------
if true then -- 为了区分上面克劳斯的同名函数
    TUNING.DEER_GEMMED_CAST_RANGE = 20 -- 宝石鹿施法范围
    TUNING.DEER_GEMMED_CAST_MAX_RANGE = 25 -- 宝石鹿施法最大范围

    local function ValidShedAntlerTarget(inst, other)
        return inst.hasantler ~= nil and
            other ~= nil and
            other:IsValid() and
            other:HasTag("tree") and not other:HasTag("stump") and
            other.components.workable ~= nil and
            other.components.workable:CanBeWorked()
    end

    local function OnShedAntler(inst, other)
        if ValidShedAntlerTarget(inst, other) then
            inst.components.lootdropper:SpawnLootPrefab("deer_antler"..tostring(inst.hasantler))
            if not (inst.components.health:IsDead() or inst.sg:HasStateTag("busy")) then
                inst.sg:GoToState("knockoffantler")
            end
            inst:SetAntlered(nil, false)

            SpawnPrefab("collapse_small").Transform:SetPosition(other.Transform:GetWorldPosition())
            other.components.workable:WorkedBy(inst, 1)
        end
    end

    local function ClearRecentlyCharged(inst, other)
        inst.recentlycharged[other] = nil
    end

    local function OnDestroyOther(inst, other)
        if other:IsValid() and
            other.components.workable ~= nil and
            other.components.workable:CanBeWorked() and
            other.components.workable.action ~= ACTIONS.DIG and
            other.components.workable.action ~= ACTIONS.NET and
            not inst.recentlycharged[other] then
            SpawnPrefab("collapse_small").Transform:SetPosition(other.Transform:GetWorldPosition())
            other.components.workable:Destroy(inst)
            if other:IsValid() and other.components.workable ~= nil and other.components.workable:CanBeWorked() then
                inst.recentlycharged[other] = true
                inst:DoTaskInTime(3, ClearRecentlyCharged, other)
            end
        end
    end

    local function getrandomposition(caster, teleportee)
            local centers = {}
            for i, node in ipairs(TheWorld.topology.nodes) do
                if TheWorld.Map:IsPassableAtPoint(node.x, 0, node.y) and node.type ~= NODE_TYPE.SeparatedRoom then
                    table.insert(centers, {x = node.x, z = node.y})
                end
            end
            if #centers > 0 then
                local pos = centers[math.random(#centers)]
                return Point(pos.x, 0, pos.z)
            else
                return caster:GetPosition()
            end
    end

    local function OnCollide(inst, other)
        if inst.hasantler ~= nil then
            if ValidShedAntlerTarget(inst, other) and
                Vector3(inst.Physics:GetVelocity()):LengthSq() >= 60 then

                inst:DoTaskInTime(2 * FRAMES, OnShedAntler, other)
            end
        end
        
        if inst.gem ~= nil then
        if other ~= nil and
            other:IsValid() and
            other.components.workable ~= nil and
            other.components.workable:CanBeWorked() and
            other.components.workable.action ~= ACTIONS.DIG and
            other.components.workable.action ~= ACTIONS.NET and
            not inst.recentlycharged[other] then
            inst:DoTaskInTime(2 * FRAMES, OnDestroyOther, other)
                if other:HasTag("stagehand") then
                    local locpos = getrandomposition(inst, other)
                    if other.Physics ~= nil then
                        other.Physics:Teleport(locpos.x, 0, locpos.z)
                    else
                        other.Transform:SetPosition(locpos.x, 0, locpos.z)
                    end
                end
        end
        
        if other ~= nil and
            other:IsValid() and
            other.components.health ~= nil then
                if other:HasTag("lureplant") or other:HasTag("spiderden") then
                    other.components.health:Kill()
                end
        end
        end
    end

    local function ShowAntler(inst)
        if inst.hasantler ~= nil then
            inst.AnimState:Show("swap_antler")
            inst.AnimState:OverrideSymbol("swap_antler_red", "deer_build", "swap_antler"..tostring(inst.hasantler))
        else
            inst.AnimState:Hide("swap_antler")
        end
    end

    local function setantlered(inst, antler, animate)
        inst.hasantler = antler
        inst.Physics:SetCollisionCallback(antler ~= nil and OnCollide or nil)

        if animate then
            inst:PushEvent("growantler")
        else
            inst:ShowAntler()
        end
    end
    -------------------------------------------------------------------
    local WALLS_ONEOF_TAGS = { "wall", "structure" }
    local function OnMigrate(inst)
        local x, y, z = inst.Transform:GetWorldPosition()
        local buildings = TheSim:FindEntities(x, y, z, 30, nil, nil, WALLS_ONEOF_TAGS)
        if #buildings < 10 then
            inst:Remove()
        end
    end
    local function StartMigrationTask(inst)
        if inst.migrationtask == nil then
            inst.migrationtask = inst:DoTaskInTime(TUNING.TOTAL_DAY_TIME * .5 + math.random() * TUNING.SEG_TIME, OnMigrate)
        end
    end
    local function StopMigrationTask(inst)
        if inst.migrationtask ~= nil then
            inst.migrationtask:Cancel()
            inst.migrationtask = nil
        end
    end
    local function SetMigrating(inst, migrating)
        if migrating then
            if not inst.migrating then
                inst.migrating = true
                inst.OnEntitySleep = StartMigrationTask
                inst.OnEntityWake = StopMigrationTask
                if inst:IsAsleep() then
                    StartMigrationTask(inst)
                end
            end
        elseif inst.migrating then
            inst.migrating = nil
            inst.OnEntitySleep = nil
            inst.OnEntityWake = nil
            StopMigrationTask(inst)
        end
    end
    local SPELL_OVERLAP_MIN = 3
    local SPELL_OVERLAP_MAX = 6
    local NOSPELLOVERLAP_ONEOF_TAGS = { "deer_ice_circle", "deer_fire_circle" }
    local function NoSpellOverlap(x, y, z, r)
        return #TheSim:FindEntities(x, 0, z, r or SPELL_OVERLAP_MIN, nil, nil, NOSPELLOVERLAP_ONEOF_TAGS) <= 0
    end
    local function SpawnSpell(inst, x, z)
        local spell = SpawnPrefab(inst.castfx)
        spell.Transform:SetPosition(x, 0, z)
        spell:DoTaskInTime(inst.castduration, spell.KillFX)
        return spell
    end

    local function SpawnSpells(inst, targets)
        local spells = {}
        local nextpass = {}
        for i, v in ipairs(targets) do
            if v:IsValid() and v:IsNear(inst, TUNING.DEER_GEMMED_CAST_MAX_RANGE) then
                local x, y, z = v.Transform:GetWorldPosition()
                if NoSpellOverlap(x, 0, z, SPELL_OVERLAP_MAX) then
                    table.insert(spells, SpawnSpell(inst, x, z))
                    if #spells >= TUNING.DEER_GEMMED_MAX_SPELLS then
                        return spells
                    end
                else
                    table.insert(nextpass, { x = x, z = z })
                end
            end
        end
        if #nextpass <= 0 then
            return spells
        end
        for range = SPELL_OVERLAP_MAX - 1, SPELL_OVERLAP_MIN, -1 do
            local i = 1
            while i <= #nextpass do
                local v = nextpass[i]
                if NoSpellOverlap(v.x, 0, v.z, range) then
                    table.insert(spells, SpawnSpell(inst, v.x, v.z))
                    if #spells >= TUNING.DEER_GEMMED_MAX_SPELLS or #nextpass <= 1 then
                        return spells
                    end
                    table.remove(nextpass, i)
                else
                    i = i + 1
                end
            end
        end
        return #spells > 0 and spells or nil
    end

    local function SpawnSpells_Prediction(inst, targets)
        local spells = {}
        for i, v in ipairs(targets) do
            if v:IsValid() and v:IsNear(inst, TUNING.DEER_GEMMED_CAST_MAX_RANGE) then
                local x, y, z = v.Transform:GetWorldPosition()
                local theta = (v.Transform:GetRotation() + 90) * DEGREES
                local xoffs = 4.5 * math.sin(theta)
                local zoffs = 4.5 * math.cos(theta)
                x = x + xoffs
                z = z + zoffs
                table.insert(spells, SpawnSpell(inst, x, z))
                if #spells >= TUNING.DEER_GEMMED_MAX_SPELLS then
                    return spells
                end
            end
        end
        return spells
    end

    local function SpawnSpells_Self(inst, targets)
        local spells = {}
        local x, y, z = inst.Transform:GetWorldPosition()
        table.insert(spells, SpawnSpell(inst, x, z))
        return spells
    end

    local function DoCast(inst, targets)

        if inst.SpellMode == nil then
            local spells = targets ~= nil and SpawnSpells(inst, targets) or nil
            inst.components.timer:StopTimer("deercast_cd")
            inst.components.timer:StartTimer("deercast_cd", spells ~= nil and inst.castcd or TUNING.DEER_GEMMED_FIRST_CAST_CD)
            return spells
        elseif inst.SpellMode == "Predict" then
            local spells = targets ~= nil and SpawnSpells_Prediction(inst, targets) or nil
            inst.components.timer:StopTimer("deercast_cd")
            inst.components.timer:StartTimer("deercast_cd", spells ~= nil and inst.castcd or TUNING.DEER_GEMMED_FIRST_CAST_CD)
            return spells
        elseif inst.SpellMode == "Direct" then
            local spells = targets ~= nil and SpawnSpells_Self(inst, targets) or nil
            inst.components.timer:StopTimer("deercast_cd")
            inst.components.timer:StartTimer("deercast_cd", spells ~= nil and inst.castcd or TUNING.DEER_GEMMED_FIRST_CAST_CD)
            return spells
        else
            local spells = targets ~= nil and SpawnSpells(inst, targets) or nil
            inst.components.timer:StopTimer("deercast_cd")
            inst.components.timer:StartTimer("deercast_cd", spells ~= nil and inst.castcd or TUNING.DEER_GEMMED_FIRST_CAST_CD)
            return spells
        end
    end
    local function OnUpdateOffset(inst, offset)
        inst.components.knownlocations:RememberLocation("keeperoffset", offset)
    end
    local function onload(inst, data)
        if data ~= nil then
            if data.hasantler ~= nil then
                setantlered(inst, data.hasantler)
            end
            SetMigrating(inst, data.migrating)
        end
    end
    local function PiercingDamage(inst, target, damage, weapon) -- 2025.9.5 melon:削弱鹿真实伤害0.1->0.05
        return (target.components.health ~= nil and target.components.health.currenthealth * 0.05) or 0
    end
    local DEERS = {"deer_red", "deer_blue"}
    for _, prefab in ipairs(DEERS) do
        AddPrefabPostInit(prefab, function(inst)
            if not TheWorld.ismastersim then return end
            inst.changetask2hm = inst:DoTaskInTime(0.2, function(inst)
                if inst:HasTag("swc2hm") then return end -- 不改影子
                -- 新增
                -- inst.Physics:SetCollisionCallback(OnCollide) -- 2025.9.3 melon:注释掉撞坏建筑
                inst.recentlycharged = {}
                -- 修改
                inst.SetAntlered = setantlered
                inst.OnLoad = onload
                inst.DoCast = DoCast
                -- 修复combat组件为nil报错
            
                if inst.components.combat then
                    inst.components.combat.bonusdamagefn = PiercingDamage
                end
                if inst.components.sleeper then
                    inst.components.sleeper:SetResistance(40)
                end
            end)
        end)
    end
end
