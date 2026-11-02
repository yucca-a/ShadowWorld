require "behaviours/chaseandattack"
require "behaviours/runaway"
require "behaviours/wander"
require "behaviours/doaction"
require "behaviours/attackwall"
require "behaviours/panic"
require "behaviours/minperiod"
require "behaviours/leash"

local WAMDER_DIST = 2
local LEASH_DIST = 6

local BOAT_TAGS = {"boat"}

local function ShouldClampCrabking(inst)
    if inst:HasTag("swc2hm") then return end
    if inst:IsValid() and not inst.sg:HasStateTag("busy") then
        local x, y, z = inst.Transform:GetWorldPosition()
        if inst.tofindcrab2hm and inst.crabking2hm and inst.crabking2hm:IsValid() and inst:IsNear(inst.crabking2hm, 2.5) then
            inst:PushEvent("clamp", {target = inst.crabking2hm})
            return
        end
        local ents = TheSim:FindEntities(x, y, z, 4.5, {"boat"})
        if #ents > 0 then for i = #ents, 1, -1 do if not ents[i]:IsValid() or ents[i].components.health:IsDead() then table.remove(ents, i) end end end
        if #ents > 0 then inst:PushEvent("clamp", {target = ents[1]}) end
    end
end
local function findcrabkingtoclamp(inst)
    if inst:HasTag("swc2hm") then return end
    if not inst.tofindcrab2hm then
        local x, y, z = inst.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities(x, y, z, TUNING.crabkinghide2hm and 20 or 10, {"boat"})
        if #ents > 0 then
            return Vector3(ents[1].Transform:GetWorldPosition())
        else
            inst.tofindcrab2hm = true
        end
    end
    if inst.tofindcrab2hm then
        local x, y, z = inst.Transform:GetWorldPosition()
        if not (inst.crabking2hm and inst.crabking2hm:IsValid()) then
            local ents = TheSim:FindEntities(x, y, z, 10, {"crabking", "epic"})
            if #ents > 0 and ents[1] and ents[1]:IsValid() then inst.crabking2hm = ents[1] end
        end
        if inst.crabking2hm and inst.crabking2hm:IsValid() and inst.crabking2hm.components.health and not inst.crabking2hm.components.health:IsDead() and
            inst.crabking2hm.components.health:GetPercent() < 0.35 and inst.crabking2hm.arms and inst.armpos and inst.crabking2hm.arms[inst.armpos] == inst then
            if inst.components.locomotor ~= nil then inst.components.locomotor:SetExternalSpeedMultiplier(inst, "crabkingclaw2hm", 2) end
            return Vector3(inst.crabking2hm.Transform:GetWorldPosition())
        else
            if inst.components.locomotor ~= nil then inst.components.locomotor:SetExternalSpeedMultiplier(inst, "crabkingclaw2hm", 0) end
            inst.tofindcrab2hm = nil
        end
    end
end

local function ShouldClamp(inst)
    if inst:IsValid() and not inst.sg:HasStateTag("busy") then
        local x,y,z = inst.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities(x,y,z, 4.5, BOAT_TAGS)
        if #ents > 0 then
            for i=#ents, 1, -1 do
                if not ents[i]:IsValid() or ents[i].components.health:IsDead() then
                    table.remove(ents,i)
                end
            end
        end
        if #ents > 0 then
            inst:PushEvent("clamp",{target = ents[1]})
        end
    end
    return nil
end

local function findboattoclamp(inst)
    local x,y,z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x,y,z, 10, BOAT_TAGS)
    if #ents>0 then
        return Vector3(ents[1].Transform:GetWorldPosition())
    end
end


local dwxClawBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

function dwxClawBrain:OnStart()
    local root = PriorityNode(
    {
       WhileNode(function() return not self.inst.sg:HasStateTag("clampped") end, "not clamping",
        PriorityNode({

            Leash(self.inst, function() return self.inst.components.knownlocations:GetLocation("spawnpoint") end, LEASH_DIST, 5, false),

            DoAction(self.inst, ShouldClampCrabking, "clamp!"),
            Leash(self.inst, function() return findcrabkingtoclamp(self.inst) end, 0, 0, false),
            
            DoAction(self.inst, ShouldClamp, "clamp!"),
            Leash(self.inst, function() return findboattoclamp(self.inst) end, 0, 0, false),

            Wander(self.inst, function() return self.inst.components.knownlocations:GetLocation("spawnpoint") end, WAMDER_DIST,
                {
                    minwalktime=0.5,
                    randwalktime=0.5,
                    minwaittime=1,
                    randwaittime=5,
                }
            )
        }, 0.2)),
    }, 0.2)

    self.bt = BT(self.inst, root)
end

function dwxClawBrain:OnInitializationComplete()
    self.inst.components.knownlocations:RememberLocation("spawnpoint", Point(self.inst.Transform:GetWorldPosition()))
end

return dwxClawBrain
