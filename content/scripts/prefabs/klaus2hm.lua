

local assets =
{
    Asset("ANIM", "anim/klaus_basic.zip"),
    Asset("ANIM", "anim/klaus_actions.zip"),
    Asset("ANIM", "anim/klaus_build.zip"),
}

local prefabs =
{
    "monstermeat",
    "charcoal",
    "klaussackkey",
    "deer_red2hm",
    "deer_blue2hm",
    "staff_castinglight",
	"chesspiece_klaus_sketch",

    --winter loot
    "winter_food3", --Candy Cane
}

local loot =
{
    "monstermeat",
    "charcoal",
	"krampus_sack",
	"chesspiece_klaus_sketch",
}

--------------------------------------------------------------------------

local brain = require("brains/klausbrain2hm")

--------------------------------------------------------------------------

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

--------------------------------------------------------------------------

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

local function ClearRecentAttacker(inst, attacker)
    inst.recentattackers[attacker] = nil
end

local function OnAttacked(inst, data)
    if data.attacker ~= nil then
        if data.attacker:HasTag("player") then
            if inst.recentattackers[data.attacker] ~= nil then
                inst.recentattackers[data.attacker]:Cancel()
            end
            inst.recentattackers[data.attacker] = inst:DoTaskInTime(30, ClearRecentAttacker, data.attacker)
        end
        local target = inst.components.combat.target
        if not (target ~= nil and
                target:HasTag("player") and
                target:IsNear(inst, inst.attack_range + target:GetPhysicsRadius(0))) then
            inst.components.combat:SetTarget(data.attacker)
        end
        inst.components.commander:ShareTargetToAllSoldiers(data.attacker)
    end
end

local function FindChompTarget(inst)
    local chomp_range_sq = inst.chomp_range * inst.chomp_range
    local chomp_min_range_sq = inst.chomp_min_range * inst.chomp_min_range
    local fartargets, neartargets = {}, {}
    for i, v in ipairs(AllPlayers) do
        if not (v.components.health:IsDead() or v:HasTag("playerghost")) then
            local distsq = inst:GetDistanceSqToInst(v)
            if distsq < chomp_range_sq then
                table.insert(distsq >= chomp_min_range_sq and fartargets or neartargets, v)
            end
        end
    end
    return (#fartargets > 0 and fartargets[math.random(#fartargets)])
        or (#neartargets > 0 and neartargets[math.random(#neartargets)])
        or inst.components.combat.target
        or nil
end

--------------------------------------------------------------------------

local function AnnounceWarning(inst, player, strid)
    if player:IsValid() and player.entity:IsVisible() and
        not (player.components.health ~= nil and player.components.health:IsDead()) and
        not player:HasTag("playerghost") and
        player:IsNear(inst, 15) and
        not inst.components.health:IsDead() and
        player.components.talker ~= nil then
        player.components.talker:Say(GetString(player, strid))
    end
end

local function PushWarning(inst, strid)
    for k, v in pairs(inst.recentattackers) do
        if k:IsValid() then
            inst:DoTaskInTime(math.random(), AnnounceWarning, k, strid)
        end
    end
end

--------------------------------------------------------------------------

local PHASE2_HEALTH = .5

local function NearToFar(a, b)
    return a.distsq < b.distsq
end

local function SummonHelpers(inst, warning)
    if inst.nohelpers then
        return false
    end
    inst.nohelpers = true

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
            --Push event even if numspawns is 0
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

local function OnNewTarget(inst, data)
    if data.target ~= nil then
        inst:SetEngaged(true)
    end
end

local function SetEngaged(inst, engaged)
    --NOTE: inst.engaged is nil at instantiation, and engaged must not be nil
    if inst.engaged ~= engaged then
        inst.engaged = engaged
        inst.components.timer:StopTimer("command_cd")
        if engaged then
            if inst.nohelpers and not inst.components.health:IsHurt() then
                inst.nohelpers = nil
            end
            inst.components.health:StopRegen()
            inst.components.timer:StartTimer("command_cd", TUNING.KLAUS_COMMAND_CD)
            inst:RemoveEventCallback("newcombattarget", OnNewTarget)
        else
            inst.components.health:StartRegen(TUNING.KLAUS_HEALTH_REGEN, 1)
            inst:ListenForEvent("newcombattarget", OnNewTarget)
        end
    end
end

--kaxzer was here

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
			

				-- if i == 1 then
					-- deers[i]:OnUpdateOffset(Vector3(xoffs_new, 0, zoffs_new))
				-- elseif i == 2 then
					-- deers[i]:OnUpdateOffset(Vector3(xoffs_new, 0, -zoffs_new))
				-- elseif i == 3 then
					-- deers[i]:OnUpdateOffset(Vector3(-xoffs_new, 0, -zoffs_new))
				-- elseif i == 4 then
					-- deers[i]:OnUpdateOffset(Vector3(-xoffs_new, 0, zoffs_new))
				-- end
				
				if i == 1 then
					deers[i]:OnUpdateOffset(Vector3(inst.deer_dist * (1.0 + distfactor * 2.5), 0, 0))
				elseif i == 2 then
					deers[i]:OnUpdateOffset(Vector3(0, 0, inst.deer_dist * (1.0 + (1 - distfactor) * 2.5)))
				elseif i == 3 then
					deers[i]:OnUpdateOffset(Vector3(-inst.deer_dist * (1.0 + distfactor * 2.5), 0, 0))
				elseif i == 4 then
					deers[i]:OnUpdateOffset(Vector3(0, 0, -inst.deer_dist * (1.0 + (1 - distfactor) * 2.5)))
				end
			
				-- local theta_new = theta + (i - 1) * 90 * DEGREES
				-- local xoffs_new = 5 * inst.deer_dist * math.sin(theta_new)
				-- local zoffs_new = 5 * inst.deer_dist * math.sin(theta_new)
				
				-- if i % 2 == 0 then
					-- xoffs_new = xoffs_new * (1.2 + (1 - distfactor) * 3.8)
					-- zoffs_new = zoffs_new * (1.2 + (1 - distfactor) * 3.8)
				-- else
					-- xoffs_new = xoffs_new * (1.2 + distfactor * 3.8)
					-- zoffs_new = zoffs_new * (1.2 + distfactor * 3.8)
				-- end
			
				-- deers[i]:OnUpdateOffset(Vector3(xoffs_new, 0, zoffs_new))
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
			

				-- if i == 1 then
					-- deers[i]:OnUpdateOffset(Vector3(xoffs_new, 0, zoffs_new))
				-- elseif i == 2 then
					-- deers[i]:OnUpdateOffset(Vector3(xoffs_new, 0, -zoffs_new))
				-- elseif i == 3 then
					-- deers[i]:OnUpdateOffset(Vector3(-xoffs_new, 0, -zoffs_new))
				-- elseif i == 4 then
					-- deers[i]:OnUpdateOffset(Vector3(-xoffs_new, 0, zoffs_new))
				-- end
				
				if i == 1 then
					deers[i]:OnUpdateOffset(Vector3(inst.deer_dist * (1.0 + distfactor * 2.5), 0, 0))
				elseif i == 2 then
					deers[i]:OnUpdateOffset(Vector3(0, 0, inst.deer_dist * (1.0 + (1 - distfactor) * 2.5)))
				elseif i == 3 then
					deers[i]:OnUpdateOffset(Vector3(-inst.deer_dist * (1.0 + distfactor * 2.5), 0, 0))
				elseif i == 4 then
					deers[i]:OnUpdateOffset(Vector3(0, 0, -inst.deer_dist * (1.0 + (1 - distfactor) * 2.5)))
				end
			
				-- local theta_new = theta + (i - 1) * 90 * DEGREES
				-- local xoffs_new = 5 * inst.deer_dist * math.sin(theta_new)
				-- local zoffs_new = 5 * inst.deer_dist * math.sin(theta_new)
				
				-- if i % 2 == 0 then
					-- xoffs_new = xoffs_new * (1.2 + (1 - distfactor) * 3.8)
					-- zoffs_new = zoffs_new * (1.2 + (1 - distfactor) * 3.8)
				-- else
					-- xoffs_new = xoffs_new * (1.2 + distfactor * 3.8)
					-- zoffs_new = zoffs_new * (1.2 + distfactor * 3.8)
				-- end
			
				-- deers[i]:OnUpdateOffset(Vector3(xoffs_new, 0, zoffs_new))
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
        -- local thetaForward0 = (inst.Transform:GetRotation() + 60) * DEGREES
        -- local thetaForward1 = (inst.Transform:GetRotation() + 120) * DEGREES
        local xoffs = inst.deer_dist * math.sin(theta)
        local zoffs = inst.deer_dist * math.cos(theta)
        -- local xoffsForward0 = 3 * inst.deer_dist * math.sin(thetaForward0)
        -- local zoffsForward0 = 3 * inst.deer_dist * math.cos(thetaForward0)
        -- local xoffsForward1 = 3 * inst.deer_dist * math.sin(thetaForward1)
        -- local zoffsForward1 = 3 * inst.deer_dist * math.cos(thetaForward1)
        local x, y, z = inst.Transform:GetWorldPosition()
        local x1, z1 = x - xoffs, z - zoffs
        -- x, z = x + xoffs, z + zoffs
        if #deers > 3 then
            -- local score1 = deers[1]:GetDistanceSqToPoint(x, 0, z) + deers[2]:GetDistanceSqToPoint(x1, 0, z1)
            -- local score2 = deers[2]:GetDistanceSqToPoint(x, 0, z) + deers[1]:GetDistanceSqToPoint(x1, 0, z1)
            -- if score1 < score2 then
                -- deers[1]:OnUpdateOffset(Vector3(xoffs, 0, zoffs))
                -- deers[2]:OnUpdateOffset(Vector3(-xoffs, 0, -zoffs))
            -- else
                -- deers[2]:OnUpdateOffset(Vector3(xoffs, 0, zoffs))
                -- deers[1]:OnUpdateOffset(Vector3(-xoffs, 0, -zoffs))
            -- end
			
            -- deers[3]:OnUpdateOffset(Vector3(xoffsForward0, 0, zoffsForward0))
            -- deers[4]:OnUpdateOffset(Vector3(xoffsForward1, 0, zoffsForward1))
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
        -- local thetaForward0 = (inst.Transform:GetRotation() + 60) * DEGREES
        -- local thetaForward1 = (inst.Transform:GetRotation() + 120) * DEGREES
        local xoffs = inst.deer_dist * math.sin(theta)
        local zoffs = inst.deer_dist * math.cos(theta)
        -- local xoffsForward0 = 3 * inst.deer_dist * math.sin(thetaForward0)
        -- local zoffsForward0 = 3 * inst.deer_dist * math.cos(thetaForward0)
        -- local xoffsForward1 = 3 * inst.deer_dist * math.sin(thetaForward1)
        -- local zoffsForward1 = 3 * inst.deer_dist * math.cos(thetaForward1)
        local x, y, z = inst.Transform:GetWorldPosition()
        local x1, z1 = x - xoffs, z - zoffs
        -- x, z = x + xoffs, z + zoffs
        if #deers > 3 then


			deers[1]:OnUpdateOffset(Vector3(xoffs * 1.2, 0, zoffs * 1.2))
			deers[2]:OnUpdateOffset(Vector3(-xoffs * 1.2, 0, -zoffs * 1.2))

			if inst.components.combat.target ~= nil then
			if inst.spellForceTimer == 1 then
				local x2, y2, z2 = inst.components.combat.target.Transform:GetWorldPosition()
				x2 = x2 - x
				z2 = z2 - z
				--deers[1]:OnUpdateOffset(Vector3(x2 + 4.5, 0, z2))
				--deers[2]:OnUpdateOffset(Vector3(x2, 0, z2 + 4.5))
				deers[3]:OnUpdateOffset(Vector3(x2 + xoffs * 3.5, 0, z2 + zoffs * 3.5))
				deers[4]:OnUpdateOffset(Vector3(x2 - xoffs * 3.5, 0, z2 - zoffs * 3.5))
			end
			end
			
        elseif #deers > 0 then
            deers[1]:OnUpdateOffset(deers[1]:GetDistanceSqToPoint(x, 0, z) < deers[1]:GetDistanceSqToPoint(x1, 0, z1) and Vector3(xoffs, 0, zoffs) or Vector3(-xoffs, 0, -zoffs))
        end
	elseif phase == 6 then
	
		-- local currentHealth = inst.components.health:GetPercent()
	
		-- inst.chomp_cd = 6 - 2 * (1 - (currentHealth - 0.1) / 0.2)
		
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
        -- local thetaForward0 = (inst.Transform:GetRotation() + 60) * DEGREES
        -- local thetaForward1 = (inst.Transform:GetRotation() + 120) * DEGREES
        local xoffs = inst.deer_dist * math.sin(theta)
        local zoffs = inst.deer_dist * math.cos(theta)
        -- local xoffsForward0 = 3 * inst.deer_dist * math.sin(thetaForward0)
        -- local zoffsForward0 = 3 * inst.deer_dist * math.cos(thetaForward0)
        -- local xoffsForward1 = 3 * inst.deer_dist * math.sin(thetaForward1)
        -- local zoffsForward1 = 3 * inst.deer_dist * math.cos(thetaForward1)
        local x, y, z = inst.Transform:GetWorldPosition()
        local x1, z1 = x - xoffs, z - zoffs
        -- x, z = x + xoffs, z + zoffs
        if #deers > 3 then
            -- local score1 = deers[1]:GetDistanceSqToPoint(x, 0, z) + deers[2]:GetDistanceSqToPoint(x1, 0, z1)
            -- local score2 = deers[2]:GetDistanceSqToPoint(x, 0, z) + deers[1]:GetDistanceSqToPoint(x1, 0, z1)
            -- if score1 < score2 then
                -- deers[1]:OnUpdateOffset(Vector3(xoffs, 0, zoffs))
                -- deers[2]:OnUpdateOffset(Vector3(-xoffs, 0, -zoffs))
            -- else
                -- deers[2]:OnUpdateOffset(Vector3(xoffs, 0, zoffs))
                -- deers[1]:OnUpdateOffset(Vector3(-xoffs, 0, -zoffs))
            -- end
			
            -- deers[3]:OnUpdateOffset(Vector3(xoffsForward0, 0, zoffsForward0))
            -- deers[4]:OnUpdateOffset(Vector3(xoffsForward1, 0, zoffsForward1))
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
		
		-- if inst.spellForceTimer == nil then
			-- inst.spellForceTimer = 1
		-- else
			-- inst.spellForceTimer = inst.spellForceTimer + 1
			-- if inst.spellForceTimer > 1 then
				-- inst:DoTaskInTime(2, function() inst:PushEvent("doforcecast") end)
				-- inst.spellForceTimer = 0
			-- end
		-- end
	
        local deers = inst.components.commander:GetAllSoldiers()
        local theta = inst.Transform:GetRotation() * DEGREES
        -- local thetaForward0 = (inst.Transform:GetRotation() + 60) * DEGREES
        -- local thetaForward1 = (inst.Transform:GetRotation() + 120) * DEGREES
        local xoffs = inst.deer_dist * math.sin(theta)
        local zoffs = inst.deer_dist * math.cos(theta)
        -- local xoffsForward0 = 3 * inst.deer_dist * math.sin(thetaForward0)
        -- local zoffsForward0 = 3 * inst.deer_dist * math.cos(thetaForward0)
        -- local xoffsForward1 = 3 * inst.deer_dist * math.sin(thetaForward1)
        -- local zoffsForward1 = 3 * inst.deer_dist * math.cos(thetaForward1)
        local x, y, z = inst.Transform:GetWorldPosition()
        local x1, z1 = x - xoffs, z - zoffs
        -- x, z = x + xoffs, z + zoffs
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
	
	-- print("phase:")
	-- print(phase)
	-- print(inst.tasktime)
	
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

    local deer = SpawnPrefab("deer_red2hm")
    deer.Transform:SetRotation(rot)
    deer.Transform:SetPosition(pos.x + offset.x, 0, pos.z + offset.z)
    deer.components.spawnfader:FadeIn()
    inst.components.commander:AddSoldier(deer)

    theta = (rot + 90) * DEGREES
    offset =
        FindWalkableOffset(pos, theta, inst.deer_dist, 5, true, false) or
        FindWalkableOffset(pos, theta, inst.deer_dist * .5, 5, true, false) or
        Vector3(0, 0, 0)

    deer = SpawnPrefab("deer_blue2hm")
    deer.Transform:SetRotation(rot)
    deer.Transform:SetPosition(pos.x + offset.x, 0, pos.z + offset.z)
    deer.components.spawnfader:FadeIn()
    inst.components.commander:AddSoldier(deer)
	--end
end

--------------------------------------------------------------------------

local function DoNothing()
end

local function DoFoleySounds(inst, volume)
    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/klaus/chain_foley", nil, volume)
end

local function PushMusic(inst, level)
    if ThePlayer == nil or inst:HasTag("flight") then
        inst._playingmusic = false
    elseif ThePlayer:IsNear(inst, inst._playingmusic and 40 or 20) then
        inst._playingmusic = true
        ThePlayer:PushEvent("triggeredevent", { name = "klaus", level = level })
    elseif inst._playingmusic and not ThePlayer:IsNear(inst, 50) then
        inst._playingmusic = false
    end
end

local function OnMusicDirty(inst)
    --Dedicated server does not need to trigger music
    if not TheNet:IsDedicated() then
        if inst._musictask ~= nil then
            inst._musictask:Cancel()
        end
        local level = inst._pausemusic:value() and 2 or (inst._unchained:value() and 3 or 1)
        inst._musictask = inst:DoPeriodicTask(1, PushMusic, nil, level)
        PushMusic(inst, level)
    end
end

local function PauseMusic(inst, paused)
    if inst._pausemusic:value() == (paused == false) then
        inst._pausemusic:set(paused ~= false)
        OnMusicDirty(inst)
    end
end

local function IsUnchained(inst)
    return inst._unchained:value()
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

--------------------------------------------------------------------------

local function ShouldSleep(inst)
    return false
end

local function ShouldWake(inst)
    return true
end

--------------------------------------------------------------------------

local function DoRemove(inst)
    for i, v in ipairs(inst.components.commander:GetAllSoldiers()) do
        if v:IsAsleep() then
            v:Remove()
        end
    end
    inst:Remove()
end

local function OnEntitySleep(inst)
    if inst._sleeptask ~= nil then
        inst._sleeptask:Cancel()
    end
    inst._sleeptask = not (inst:IsUnchained() and inst.components.health:IsDead()) and inst:DoTaskInTime(10, DoRemove) or nil
end

local function OnEntityWake(inst)
    if inst._sleeptask ~= nil then
        inst._sleeptask:Cancel()
        inst._sleeptask = nil
    end
end

--------------------------------------------------------------------------

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
        local deer = SpawnPrefab("deer_red2hm")
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
        local deer = SpawnPrefab("deer_blue2hm")
        deer.Physics:Teleport(spawn_pt:Get())
        deer:FacePoint(pt)
		deer.components.spawnfader:FadeIn()
		inst.components.commander:AddSoldier(deer)
		inst.TotalDeer = inst.TotalDeer + 1
    end
end

function GetCurrentPhase(inst)
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
--------------------------------------------------------------------------

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddLight()
    inst.entity:AddDynamicShadow()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst.Transform:SetSixFaced()
    MakeGiantCharacterPhysics(inst, 1000, 1.2)
    SetPhysicalScale(inst, 1)

    inst.AnimState:SetBank("klaus")
    inst.AnimState:SetBuild("klaus_build")
    inst.AnimState:PlayAnimation("idle_loop", true)
    if IsSpecialEventActive(SPECIAL_EVENTS.WINTERS_FEAST) then
        inst.AnimState:OverrideSymbol("swap_chain", "klaus_build", "swap_chain_winter")
        inst.AnimState:OverrideSymbol("swap_chain_link", "klaus_build", "swap_chain_link_winter")
        inst.AnimState:OverrideSymbol("swap_chain_lock", "klaus_build", "swap_chain_lock_winter")
        inst.AnimState:OverrideSymbol("swap_klaus_antler", "klaus_build", "swap_klaus_antler_winter")
    end

    inst:AddTag("epic")
    inst:AddTag("noepicmusic")
    inst:AddTag("monster")
    inst:AddTag("hostile")
    inst:AddTag("scarytoprey")
    inst:AddTag("largecreature")
    inst:AddTag("deergemresistance")

    inst._unchained = net_bool(inst.GUID, "klaus._unchained", "musicdirty")
    inst._pausemusic = net_bool(inst.GUID, "klaus_pausemusic", "musicdirty")
    inst._playingmusic = false
    inst._musictask = nil
    OnMusicDirty(inst)

    inst:AddComponent("spawnfader")

    inst.entity:SetPristine()

    inst.displaynamefn = function() 
        return (TUNING.isCh2hm and "克劳斯") or "Klaus"
    end

    if not TheWorld.ismastersim then
        inst:ListenForEvent("musicdirty", OnMusicDirty)

        return inst
    end

    inst.recentlycharged = {}
    inst.Physics:SetCollisionCallback(OnCollide)

    inst:AddComponent("inspectable")
    inst.components.inspectable:RecordViews()

    inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetLoot(loot)
    if IsSpecialEventActive(SPECIAL_EVENTS.WINTERS_FEAST) then
        inst.components.lootdropper:AddChanceLoot("winter_food3", 1)
        inst.components.lootdropper:AddChanceLoot("winter_food3", 1)
    end

    inst:AddComponent("sleeper")
    inst.components.sleeper:SetResistance(4)
    inst.components.sleeper:SetSleepTest(ShouldSleep)
    inst.components.sleeper:SetWakeTest(ShouldWake)
    inst.components.sleeper.diminishingreturns = true

    inst:AddComponent("locomotor")
    inst.components.locomotor.pathcaps = { ignorewalls = true }
    inst.components.locomotor.walkspeed = TUNING.KLAUS_SPEED

    inst:AddComponent("health")
    --inst.components.health:SetMaxHealth(TUNING.KLAUS_HEALTH)
    inst.components.health.nofadeout = true

	inst:AddComponent("thief")

	inst.deerWaveOne = false

    inst:AddComponent("healthtrigger")
	inst.components.healthtrigger:AddTrigger(0.75, SpawnDeerWaveOne)
    inst.components.healthtrigger:AddTrigger(PHASE2_HEALTH, EnterPhase2Trigger)
	inst.components.healthtrigger:AddTrigger(0.9, function() ChangeDeerTaskTime(inst, 1.5, 1) end)
	inst.components.healthtrigger:AddTrigger(0.25, function() ChangeDeerTaskTime(inst, 1.5, 1) end)
	inst.components.healthtrigger:AddTrigger(0.3, function() ChangeDeerTaskTime(inst, 1.5, 2) end)
	
    inst:AddComponent("combat")
    --inst.components.combat:SetDefaultDamage(TUNING.KLAUS_DAMAGE)
    --inst.components.combat:SetAttackPeriod(TUNING.KLAUS_ATTACK_PERIOD)
    inst.components.combat.playerdamagepercent = .5
    --inst.components.combat:SetRange(TUNING.KLAUS_ATTACK_RANGE, TUNING.KLAUS_HIT_RANGE)
    inst.components.combat:SetRetargetFunction(3, RetargetFn)
    inst.components.combat:SetKeepTargetFunction(KeepTargetFn)
    inst.components.combat.hiteffectsymbol = "swap_fire"
	inst.components.combat.onhitotherfn = OnHitOther

    inst:AddComponent("explosiveresist")

    inst:AddComponent("grouptargeter")
    inst:AddComponent("commander")
    inst.components.commander:SetTrackingDistance(30 * 12)

    inst:AddComponent("timer")

    inst:AddComponent("sanityaura")

    inst:AddComponent("epicscare")
    inst.components.epicscare:SetRange(TUNING.KLAUS_EPICSCARE_RANGE)

    inst:AddComponent("knownlocations")

    MakeLargeBurnableCharacter(inst, "swap_fire")
    inst.components.burnable.nocharring = true
    MakeLargeFreezableCharacter(inst, "swap_fire")
    inst.components.freezable:SetResistance(4)
    inst.components.freezable.diminishingreturns = true

    inst.DoFoleySounds = DoFoleySounds

    inst:SetStateGraph("SGklaus2hm")
    inst:SetBrain(brain)

	inst.DeaggroRange = TUNING.KLAUS_DEAGGRO_DIST
	inst.TotalDeer = 2

    SetStatScale(inst, 1)

	inst.GetCurrentPhase = GetCurrentPhase
	inst.SpawnDeerWaveOne = SpawnDeerWaveOne
    inst.SummonHelpersTwo = SummonHelpersTwo
	inst.TrickAttack = TrickAttack
	inst.ChangeDeerTaskTime = ChangeDeerTaskTime
	
    inst.SetEngaged = SetEngaged
    inst.SpawnDeer = SpawnDeer
    inst.SummonHelpers = SummonHelpers
    inst.PauseMusic = PauseMusic
    inst.IsUnchained = IsUnchained
    inst.Unchain = Unchain
    inst.Enrage = Enrage
    inst.FindChompTarget = FindChompTarget
    inst.OnSave = OnSave
    inst.OnPreLoad = OnPreLoad
    inst.OnEntitySleep = OnEntitySleep
    inst.OnEntityWake = OnEntityWake

    inst.recentattackers = {}
	inst.tasktime = 0.5
    inst.taskPG = inst:DoPeriodicTask(inst.tasktime, UpdateDeerOffsets)
    inst:ListenForEvent("attacked", OnAttacked)
    SetEngaged(inst, false)

    return inst
end

return Prefab("klaus2hm", fn, assets, prefabs)
