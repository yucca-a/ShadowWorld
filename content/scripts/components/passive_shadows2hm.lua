--[[
Copyright (C) 2018 Forged Forge

This file is part of Forged Forge.

The source code of this program is shared under the RECEX
SHARED SOURCE LICENSE (version 1.0).
The source code is shared for referrence and academic purposes
with the hope that people can read and learn from it. This is not
Free and Open Source software, and code is not redistributable
without permission of the author. Read the RECEX SHARED
SOURCE LICENSE for details
The source codes does not come with any warranty including
the implied warranty of merchandise.
You should have received a copy of the RECEX SHARED SOURCE
LICENSE in the form of a LICENSE file in the root of the source
directory. If not, please refer to
<https://raw.githubusercontent.com/Recex/Licenses/master/SharedSourceLicense/LICENSE.txt>
]]
local SHADOW_DISTANCE = 5
local MAX_SHADOW_SPAWN = 5
local angle_per_shadow = 2*math.pi/MAX_SHADOW_SPAWN
local SPAWN_DELAY = 0.1

local function OnHitOther(inst, data)
	if data.weapon and not (data.weapon.components.aoespell and data.weapon.components.aoespell.casting) and
	not (inst.components.rider and inst.components.rider:IsRiding()) 
	and inst.components.passive_shadows2hm.weapon == data.weapon then
		inst.components.passive_shadows2hm:OnDamageDealt(data.target)
	end
end

local function OnDeath(inst, data)
	inst.components.passive_shadows2hm:UpdateTarget()
end

local function GenerateOffsets()
	local offsets = {}
	local ang = math.random() * 2 * math.pi
	for i=1, MAX_SHADOW_SPAWN, 1 do
		local angle = ang + angle_per_shadow * i -- mutliplying by 2 gives it the star pattern
		offsets[i] = Vector3(SHADOW_DISTANCE * math.sin(angle), 0, SHADOW_DISTANCE * math.cos(angle))
	end
	return offsets
end

local function costsanity(inst)
    if inst and inst.components.sanity and inst.components.sanity.current > 0 then
        inst.components.sanity:DoDelta(-MAX_SHADOW_SPAWN * 1 * (inst.components.passive_shadows2hm.costsanitypercent or 1))
    end
end

local PassiveShadows2hm = Class(function(self, player)
	self.debug_mode = false
	self.debug_type = "Shadows"
    self.player = player
	self.damage_threshold = 5
	self.damage_dealt = 0
	self.damage = 11
	self.canuse = false
	self.current_target = nil
	self.shouldcostsanity = false
	self.offsets = GenerateOffsets()

	self.player:ListenForEvent("onhitother", OnHitOther)
	self.player:ListenForEvent("death", OnDeath)
end)

function PassiveShadows2hm:UpdateTarget(target)
	-- Reset damage if new target
	if not target or target ~= self.current_target then
		self.current_target = target or self.current_target
	end
end

-- Update the Shadows status every time damage is dealt
function PassiveShadows2hm:OnDamageDealt(target)
	self:UpdateTarget(target)
	self.damage_dealt = self.damage_dealt + 1
	-- Shadows trigger check
	if self.damage_dealt >= self.damage_threshold then
		self:ApplyShadows()
	end
end

-- Attack the current target with Shadows
function PassiveShadows2hm:ApplyShadows()
	self:SetDamageThreshold(math.random(5,8))
	if self.shouldcostsanity then costsanity(self.player) end
	self.damage_dealt = 0
	self.offsets = GenerateOffsets()
	if self.current_target then
		for i=1, MAX_SHADOW_SPAWN do
			self.player:DoTaskInTime(SPAWN_DELAY*i, function()
				local shadow_fx = SpawnPrefab("passive_shadow_fx2hm")
				if self.player and self.player:HasTag("player") then
					shadow_fx.components.skinner:CopySkinsFromPlayer(self.player)
				end
				shadow_fx:SetDamage(self.damage)
				if self.shouldcostsanity and not self.costsanitypercent then shadow_fx.shouldcostsanity = true end
				-- shadow_fx:SetOwner(self.player)
				shadow_fx:SetTarget(self.current_target, self.offsets[i])
			end)
		end
	end
end

function PassiveShadows2hm:SetDamage(val)
	self.damage = val
end

function PassiveShadows2hm:SetDamageThreshold(val)
	self.damage_threshold = val
end

function PassiveShadows2hm:SetMaxShadows(val)
	MAX_SHADOW_SPAWN = val
	angle_per_shadow = 2*math.pi/MAX_SHADOW_SPAWN
end

function PassiveShadows2hm:SetShadowDistance(val)
	SHADOW_DISTANCE = val
end

function PassiveShadows2hm:SetSpawnDelay(val)
	SPAWN_DELAY = val
end

function PassiveShadows2hm:OnRemoveFromEntity()
	self.player:RemoveEventCallback("onhitother", OnHitOther)
	self.player:RemoveEventCallback("death", OnDeath)
end

function PassiveShadows2hm:GetDebugString()
    return string.format("Target: %s, Damage Dealt: %d", tostring(self.current_target), self.damage_dealt)
end

return PassiveShadows2hm
