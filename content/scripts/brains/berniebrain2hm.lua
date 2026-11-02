require "behaviours/wander"
require "behaviours/follow"

local BernieBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
    self._targets = nil
    self._leader = nil
end)

local MIN_FOLLOW_DIST = 0
local MAX_FOLLOW_DIST = 12
local TARGET_FOLLOW_DIST = 6
local TAUNT_DIST = 16

local wander_times = {minwalktime = 1, minwaittime = 1}

local function IsTauntable(inst, target)
    return target.components.combat ~= nil and not target.components.combat:TargetIs(inst) and target.components.combat:CanTarget(inst)
end

local SHADOWCREATURE_MUST_TAGS = {"shadowcreature", "_combat", "locomotor"}
local SHADOWCREATURE_CANT_TAGS = {"INLIMBO", "notaunt"}
local function FindShadowCreatures(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, TAUNT_DIST, SHADOWCREATURE_MUST_TAGS, SHADOWCREATURE_CANT_TAGS)
    for i = #ents, 1, -1 do if not IsTauntable(inst, ents[i]) then table.remove(ents, i) end end
    return #ents > 0 and ents or nil
end

local function TauntCreatures(self)
    local taunted = false
    if self._targets ~= nil then
        for i, v in ipairs(self._targets) do
            if IsTauntable(self.inst, v) then
                v.components.combat:SetTarget(self.inst)
                taunted = true
            end
        end
    end
    if taunted then self.inst.sg:GoToState("taunt") end
end

local function GetLeader(self)
    local leader
    if self.inst.swp2hm and self.inst.swp2hm:IsValid() and self.inst.swp2hm.bernieleader and self.inst.swp2hm.bernieleader:IsValid() then
        leader = self.inst.swp2hm.bernieleader
    end
    if self._leader ~= leader then self._leader = leader end
    return leader
end

function BernieBrain:OnStart()
    local root = PriorityNode({
        WhileNode(function()
            self._targets = not (self.inst.sg:HasStateTag("busy") or self.inst.components.timer:TimerExists("taunt_cd")) and FindShadowCreatures(self.inst) or
                                nil
            return self._targets ~= nil
        end, "Can Taunt", ActionNode(function() TauntCreatures(self) end)),
        Follow(self.inst, function() return GetLeader(self) end, MIN_FOLLOW_DIST, TARGET_FOLLOW_DIST, MAX_FOLLOW_DIST),
        Wander(self.inst, nil, nil, wander_times)
    }, 1)
    self.bt = BT(self.inst, root)
end

return BernieBrain
