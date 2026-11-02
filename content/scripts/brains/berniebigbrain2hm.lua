require("behaviours/chaseandattack")
require("behaviours/follow")
require("behaviours/faceentity")
require("behaviours/wander")

local BernieBigBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
    self._leader = nil
    self._isincombat = false
end)

local MIN_FOLLOW_DIST = 1
local MAX_FOLLOW_DIST = 8
local TARGET_FOLLOW_DIST = 5
local WALK_FOLLOW_THRESHOLD = 11 -- beyond this distance will start running
local RUN_FOLLOW_THRESHOLD = TARGET_FOLLOW_DIST + 1 -- run until within this distance
local MIN_COMBAT_TARGET_DIST = 11
local MAX_COMBAT_TARGET_DIST = 14

local function GetLeader(self)
    local leader
    if self.inst.changeswp2hm and self.inst.swp2hm and self.inst.swp2hm:IsValid() then
        leader = self.inst.swp2hm
    elseif self.inst.swp2hm and self.inst.swp2hm:IsValid() and self.inst.swp2hm.bernieleader and self.inst.swp2hm.bernieleader:IsValid() then
        leader = self.inst.swp2hm.bernieleader
    end
    if self._leader ~= leader then self._leader = leader end
    return leader
end

local function ShouldWalkToLeader(self)
    return not self.inst.sg:HasStateTag("running") and GetLeader(self) ~= nil and self.inst:IsNear(self._leader, WALK_FOLLOW_THRESHOLD)
end

local function ShouldRunToLeader(self)
    return GetLeader(self) ~= nil and
               not (self.inst:IsNear(self._leader, RUN_FOLLOW_THRESHOLD) and self._leader.sg ~= nil and self._leader.sg:HasStateTag("moving"))
end

function BernieBigBrain:OnStart()
    local root = PriorityNode({
        WhileNode(function()
            local target = self.inst.components.combat.target
            if target ~= nil and target:IsValid() then
                local leader = GetLeader(self)
                self._isincombat = leader == nil or leader:IsNear(target, self._isincombat and MAX_COMBAT_TARGET_DIST or MIN_COMBAT_TARGET_DIST)
            else
                self._isincombat = false
            end
            return self._isincombat
        end, "Combat", ChaseAndAttack(self.inst, nil, nil, nil, nil, true)),

        NotDecorator(ActionNode(function() self._isincombat = false end)),

        -- V2C: smooth transitions between walk/run without stops when following the player
        WhileNode(function() return ShouldWalkToLeader(self) end, "Walk Follow",
                  Follow(self.inst, function() return self._leader end, MIN_FOLLOW_DIST, TARGET_FOLLOW_DIST, MAX_FOLLOW_DIST, false)),
        WhileNode(function() return ShouldRunToLeader(self) end, "Run Follow",
                  Follow(self.inst, function() return self._leader end, MIN_FOLLOW_DIST, TARGET_FOLLOW_DIST, MAX_FOLLOW_DIST, true)),
        IfNode(function() return self.inst.sg:HasStateTag("running") end, "Continue Walk Follow",
               Follow(self.inst, function() return GetLeader(self) end, MIN_FOLLOW_DIST, TARGET_FOLLOW_DIST, TARGET_FOLLOW_DIST, false)),

        FaceEntity(self.inst, function() return self._leader end, function() return true end),
        Wander(self.inst)
    }, .2)
    self.bt = BT(self.inst, root)
end

return BernieBigBrain
