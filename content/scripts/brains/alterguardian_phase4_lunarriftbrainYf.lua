require("behaviours/chaseandattack")
require("behaviours/wander")

local AlterGuardian_Phase4_LunarRiftBrainYf = Class(Brain, function(self, inst)
	Brain._ctor(self, inst)
end)

local function GetHome(inst)
	local map = TheWorld.Map
	local x, y, z = inst.Transform:GetWorldPosition()
	if map:IsPointInWagPunkArena(x, y, z) then
		local cx, cz = map:GetWagPunkArenaCenterXZ()
		return cx and Vector3(cx, 0, cz) or nil
	end
	if inst.swp2hm and inst.swp2hm:IsValid() then
		return inst.swp2hm:GetPosition()
	end
end

function AlterGuardian_Phase4_LunarRiftBrainYf:OnStart()
	local root = PriorityNode({
		WhileNode(
			function()
				return not self.inst.sg:HasAnyStateTag("jumping", "dead", "busy")
			end,
			"<busy state guard>",
			PriorityNode({
				ParallelNode{
					ConditionWaitNode(function()
						if self.inst.components.combat:HasTarget() and not self.inst.components.combat:InCooldown() then
							self.inst.components.combat.ignorehitrange = true
							self.inst.components.combat:TryAttack()
							self.inst.components.combat.ignorehitrange = false
						end
						return false
					end, "TryRangedAttack"),
					FailIfSuccessDecorator(ChaseAndAttack(self.inst)),
				},
				Wander(self.inst, GetHome, 4),
			}, 0.5)),
	}, 0.5)

	self.bt = BT(self.inst, root)
end

return AlterGuardian_Phase4_LunarRiftBrainYf