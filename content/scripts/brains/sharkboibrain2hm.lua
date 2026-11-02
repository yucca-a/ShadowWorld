require("behaviours/chaseandattack")
require("behaviours/faceentity")
require("behaviours/leash")
require "behaviours/follow"
require("behaviours/wander")

local SharkboiBrain2hm = Class(Brain, function(self, inst)
	Brain._ctor(self, inst)
end)

local function ShouldStalk(inst)
	return true
end

local function ShouldChase(inst)
	return inst.components.combat:HasTarget() and not inst.components.combat:InCooldown()
end

local function Shouldgohome(inst)
	return not inst.components.combat:HasTarget() and inst.components.knownlocations:GetLocation("home")
end

local function GetFaceTargetFn(inst)
	return inst.components.combat.target
end

local function KeepFaceTargetFn(inst, target)
	return inst.components.combat:TargetIs(target)
end

function SharkboiBrain2hm:OnStart()
	local root = PriorityNode({
		WhileNode(
			function()
				return not self.inst.sg:HasAnyStateTag("jumping", "defeated", "sleeping")
			end,
			"<busy state guard>",
			PriorityNode({
				WhileNode(function() return ShouldChase(self.inst) end, "Chasing",
						ChaseAndAttack(self.inst)
						),
				WhileNode( function() return self.inst.components.combat.target and self.inst.components.combat:InCooldown() end, "Follow",
                    Follow(self.inst, function() return self.inst.components.combat.target end, 8, 10 ,13) ),
				FaceEntity(self.inst, GetFaceTargetFn, KeepFaceTargetFn),
				Leash(self.inst, Shouldgohome, 16, 2, true),
				}, 0.5)
			),
	}, 0.5)

	self.bt = BT(self.inst, root)
end

return SharkboiBrain2hm
