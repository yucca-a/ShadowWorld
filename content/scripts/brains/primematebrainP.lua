require "behaviours/wander"
require "behaviours/runaway"
require "behaviours/doaction"
require "behaviours/chaseandattack"
require "behaviours/leash"
require "behaviours/follow"
local BrainCommon = require("brains/braincommon")
local AssistLeaderDefaults = BrainCommon.AssistLeaderDefaults
local parameters_MINE
local parameters_CHOP

parameters_MINE = {
    action = "MINE" -- Required.
}

local Starter_MINE = AssistLeaderDefaults.MINE.Starter
parameters_MINE.starter = function(inst, ...) return not inst.no_targeting and Starter_MINE(inst, ...) end

local KeepGoing_MINE = AssistLeaderDefaults.MINE.KeepGoing
parameters_MINE.keepgoing = function(inst, ...) return not inst.no_targeting and KeepGoing_MINE(inst, ...) end

local FindNew_MINE = AssistLeaderDefaults.MINE.FindNew
parameters_MINE.finder = FindNew_MINE

parameters_CHOP = {
    action = "CHOP" -- Required.
}
local Starter_CHOP = AssistLeaderDefaults.CHOP.Starter
parameters_CHOP.starter = function(inst, ...) return not inst.no_targeting and Starter_CHOP(inst, ...) end

local KeepGoing_CHOP = AssistLeaderDefaults.CHOP.KeepGoing
parameters_CHOP.keepgoing = function(inst, ...) return not inst.no_targeting and KeepGoing_CHOP(inst, ...) end

local HaiTang = { "for the HaiTang！", "protect the HaiTang! ", "for the monkeyking!"}
if TUNING.isCh2hm then
	HaiTang = { "为了海棠！", "保卫海棠！", "让猴族强大！" }
end

local MIN_FOLLOW_DIST = 2
local TARGET_FOLLOW_DIST = 5
local MAX_FOLLOW_DIST = 9
local TRADE_DIST = 20

local RUN_AWAY_DIST = 7
local STOP_RUN_AWAY_DIST = 15

local SEE_FOOD_DIST = 10

local MAX_WANDER_DIST = 20

local MAX_CHASE_TIME = 60
local MAX_CHASE_DIST = 40

local TIME_BETWEEN_EATING = 30

local LEASH_RETURN_DIST = 15
local LEASH_MAX_DIST = 20

local NO_LOOTING_TAGS = { "INLIMBO", "catchable", "fire", "irreplaceable", "heavy", "outofreach", "spider" }
local NO_PICKUP_TAGS = deepcopy(NO_LOOTING_TAGS)
table.insert(NO_PICKUP_TAGS, "_container")

local PICKUP_ONEOF_TAGS = { "_inventoryitem", "pickable", "readyforharvest" }

local PrimemateBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

local function GetTraderFn(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local players = FindPlayersInRange(x, y, z, TRADE_DIST, true)
    for _, player in ipairs(players) do
        if inst.components.trader:IsTryingToTradeWithMe(player) then
            return player
        end
    end
end

local function KeepTraderFn(inst, target)
    return inst.components.trader:IsTryingToTradeWithMe(target)
end

local function ShouldRunFn(inst, hunter)
    --[[
    if inst.components.combat.target then
        return hunter:HasTag("player")
    end
    ]]
end


local function findmaxwanderdistfn(inst)
    local dist = MAX_WANDER_DIST
    local boat = inst:GetCurrentPlatform()
    if boat then
        dist = boat.components.walkableplatform and boat.components.walkableplatform.platform_radius -1 or dist
    end
    return dist
end

local function GetLeader(inst)
    return inst.components.follower.leader
end

local function findwanderpointfn(inst)
    local loc = inst.components.knownlocations:GetLocation("home")
    local boat = inst:GetCurrentPlatform()
    if boat then
        loc = Vector3(boat.Transform:GetWorldPosition())
    end
    return loc
end

local NO_TAGS = { "FX", "NOCLICK", "DECOR", "INLIMBO" }

local function DoAbandon(inst)
    if inst:GetCurrentPlatform() and inst:GetCurrentPlatform().components.health:IsDead() then
        inst.abandon = true
    end

    if not inst.abandon then
        return
    end

    local pos = Vector3(0,0,0)
    local platform = inst:GetCurrentPlatform()
    if platform then
        local x,y,z = inst.Transform:GetWorldPosition()
        local theta = platform:GetAngleToPoint(x, y, z)* DEGREES
        local radius = platform.components.walkableplatform.platform_radius - 0.5
        local offset = Vector3(radius * math.cos( theta ), 0, -radius * math.sin( theta ))

        local boat_x, boat_y, boat_z = platform.Transform:GetWorldPosition()

        pos = Vector3( boat_x+offset.x, 0, boat_z+offset.z )

        return BufferedAction(inst, nil, ACTIONS.ABANDON, nil, pos)
    end

    return nil
end

local function cangettotarget(inst)
    -- IF NOT ON A BOAT, IGNORE ALL THIS
    if not inst:GetCurrentPlatform() and inst.components.combat and inst.components.combat.target then
        return true
    end

    local boat = inst:GetCurrentPlatform()
    if inst.components.combat and inst.components.combat.target then
        local target = inst.components.combat.target
        local range = inst.components.combat:GetAttackRange() + boat.components.walkableplatform.platform_radius
        if target:GetCurrentPlatform() == inst:GetCurrentPlatform() or boat:GetDistanceSqToInst(target) <  range*range then
            return true
        end
    end
end

function PrimemateBrain:OnStart()

    local root = PriorityNode(
    {
		BrainCommon.PanicTrigger(self.inst),

        WhileNode( function() return cangettotarget(self.inst) end, "canGetToTarget",
            ChaseAndAttack(self.inst, MAX_CHASE_TIME, MAX_CHASE_DIST)),

        ChattyNode(self.inst, HaiTang,
            FaceEntity(self.inst, GetTraderFn, KeepTraderFn)),

        BrainCommon.NodeAssistLeaderDoAction(self, parameters_MINE),
        BrainCommon.NodeAssistLeaderDoAction(self, parameters_CHOP),
			
		ChattyNode(self.inst, HaiTang,
                Follow(self.inst, GetLeader, MIN_FOLLOW_DIST, TARGET_FOLLOW_DIST, MAX_FOLLOW_DIST)),

        Wander(self.inst, function() return findwanderpointfn(self.inst) end, function() return findmaxwanderdistfn(self.inst) end, {minwalktime=0.2,randwalktime=0.2,minwaittime=1,randwaittime=5})

    }, .25)
    self.bt = BT(self.inst, root)
end

return PrimemateBrain