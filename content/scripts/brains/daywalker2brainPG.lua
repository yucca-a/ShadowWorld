require("behaviours/chaseandattack")
require("behaviours/faceentity")
require("behaviours/leash")
require("behaviours/runaway")
require("behaviours/wander")

local AVOID_JUNK_DIST = 7
local function GetJunk(inst)
	return inst.components.entitytracker:GetEntity("junk")
end

local function ShouldChase(inst)
	inst.hit_recovery = TUNING.DAYWALKER_HIT_RECOVERY
	return (inst.canswing or inst.cancannon) and not inst.components.combat:InCooldown()
end

local function GetJunkPos(inst)
	local junk = GetJunk(inst)
	return junk and junk:GetPosition() or nil
end

local function ShouldRunToJunk(inst)
	return inst.components.combat:HasTarget()
end

local function ShouldTackle(inst)
	if inst.cantackle then
		local target = inst.components.combat.target
		if target then
			return inst:TestTackle(target, TUNING.DAYWALKER2_TACKLE_RANGE)
		end
	end
	return false
end

local RESET_COMBAT_DELAY = 10

local MIN_STALKING_TIME = 2 --before triggering proximity attack
local MAX_STALKING_CHASE_TIME = 4

local RUN_AWAY_DIST = 8
local STOP_RUN_AWAY_DIST = 13
local HUNTER_PARAMS =
{
	tags = { "_combat" },
	notags = { "INLIMBO", "playerghost", "invisible", "hidden", "flight", "shadowcreature" },
	oneoftags = { "character", "monster", "largecreature", "shadowminion" },
	fn = function(ent, inst)
		--Don't run away from non-hostile animals unless they are attacking us
		return ent.components.combat:TargetIs(inst)
			or ent:HasTag("character")
			or ent:HasTag("monster")
			or ent:HasTag("shadowminion")
	end,
}

local DaywalkerBrain = Class(Brain, function(self, inst)
	Brain._ctor(self, inst)
end)

local function ShouldStalk(inst)
	return true
end

local function ShouldChase(inst)
	inst.hit_recovery = TUNING.DAYWALKER_HIT_RECOVERY
	return inst.components.combat:HasTarget() and not inst.components.combat:InCooldown()
end

local function Shouldgohome(inst)
	if GetJunk(inst) then
		local junk = GetJunk(inst)
		if not inst:IsNear(junk, 20) then
			return true
		end
	end
	return false
end

local function DoStalking(inst)
	local target = inst.components.combat.target
	if target ~= nil then
		local x, y, z = inst.Transform:GetWorldPosition()
		local x1, y1, z1 = target.Transform:GetWorldPosition()
		local dx = x1 - x
		local dz = z1 - z
		local dist = math.sqrt(dx * dx + dz * dz)
		local strafe_angle = Remap(math.clamp(dist, 4, RUN_AWAY_DIST), 4, RUN_AWAY_DIST, 135, 75)
		local rot = inst.Transform:GetRotation()
		local rot1 = math.atan2(-dz, dx) * RADIANS
		local rota = rot1 - strafe_angle
		local rotb = rot1 + strafe_angle
		if DiffAngle(rot, rota) < 30 then
			rot1 = rota
		elseif DiffAngle(rot, rotb) < 30 then
			rot1 = rotb
		else
			rot1 = math.random() < 0.5 and rota or rotb
		end
		rot1 = rot1 * DEGREES
		return Vector3(x + math.cos(rot1) * 10, 0, z - math.sin(rot1) * 10)
	end
end

local function GetFaceTargetFn(inst)
	return inst.components.combat.target
end

local function KeepFaceTargetFn(inst, target)
	return inst.components.combat:TargetIs(target)
end

function DaywalkerBrain:OnStart()
	local root = PriorityNode({
		WhileNode(
			function()
				return not (self.inst.sg:HasStateTag("jumping") or
							self.inst.sg:HasStateTag("tired"))
			end,
			"<busy state guard>",
			PriorityNode({
				WhileNode(function() return ShouldChase(self.inst) end, "Chasing",
						ChaseAndAttackAndAvoid(self.inst, GetJunk, AVOID_JUNK_DIST)
						),
				WhileNode(function() return ShouldStalk(self.inst) end, "Stalking",
						Leash(self.inst, DoStalking, 0, 0, false)),
				FaceEntity(self.inst, GetFaceTargetFn, KeepFaceTargetFn),
				Wander(self.inst, GetJunkPos, 4, nil, nil, nil, nil, { should_run = true }),
				}, 2)
			),
	}, 0.5)

	self.bt = BT(self.inst, root)
end

return DaywalkerBrain
