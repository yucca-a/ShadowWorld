require "behaviours/wander"
require "behaviours/runaway"
require "behaviours/doaction"
require "behaviours/panic"
require "behaviours/chaseandattack"
require "behaviours/leash"
require "behaviours/follow"

local HaiTang = { "for the HaiTang！", "protect the HaiTang! ", "for the monkeyking!"}
if TUNING.isCh2hm then
	HaiTang = { "为了海棠！", "保卫海棠！", "让猴族强大！" }
end


local BrainCommon = require("brains/braincommon")
local AssistLeaderDefaults = BrainCommon.AssistLeaderDefaults
local parameters_MINE
local parameters_CHOP
local MINE_CANT_TAGS = { "carnivalgame_part", "event_trigger", "waxedplant" }

local parameters_MINE = {
    action = "MINE" -- Required.
}

local Starter = AssistLeaderDefaults.MINE.Starter
parameters_MINE.starter = function(inst, ...) return not inst.no_targeting and Starter(inst, ...) end

local KeepGoing = AssistLeaderDefaults.MINE.KeepGoing
parameters_MINE.keepgoing = function(inst, ...) return not inst.no_targeting and KeepGoing(inst, ...) end

local FindNew = AssistLeaderDefaults.MINE.FindNew
parameters_MINE.finder = FindNew

local parameters_CHOP = {
    action = "CHOP" -- Required.
}
local Starter_CHOP = AssistLeaderDefaults.CHOP.Starter
parameters_CHOP.starter = function(inst, ...) return not inst.no_targeting and Starter_CHOP(inst, ...) end

local KeepGoing_CHOP = AssistLeaderDefaults.CHOP.KeepGoing
parameters_CHOP.keepgoing = function(inst, ...) return not inst.no_targeting and KeepGoing_CHOP(inst, ...) end

local RETURN_DIST = 4
local BASE_DIST = 2
local TRADE_DIST = 20

local MAX_WANDER_DIST = 20

local MIN_FOLLOW_DIST = 2
local TARGET_FOLLOW_DIST = 5
local MAX_FOLLOW_DIST = 9

local MAX_CHASE_TIME = 10
local MAX_CHASE_DIST = 30

local SEE_PLAYER_DIST = 5
local STOP_RUN_DIST = 10

local NO_LOOTING_TAGS = { "INLIMBO", "catchable", "fire", "irreplaceable", "heavy", "outofreach", "spider" }
local NO_PICKUP_TAGS = deepcopy(NO_LOOTING_TAGS)
table.insert(NO_PICKUP_TAGS, "_container")

local PowderMonkeyBrain = Class(Brain, function(self, inst)
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

local function findmaxwanderdistfn(inst)
    local dist = MAX_WANDER_DIST
    local boat = inst:GetCurrentPlatform()
    if boat then
        dist = boat.components.walkableplatform and boat.components.walkableplatform.platform_radius -0.3 or dist
    end
    return dist
end

local function findwanderpointfn(inst)
    local boat = inst:GetCurrentPlatform()
    return (boat ~= nil and boat:GetPosition())
        or inst.components.knownlocations:GetLocation("home")
end


local ROWBLOCKER_MUSTNOT = {"FX", "NOCLICK", "DECOR", "INLIMBO", "_inventoryitem"}

local function reversemastcheck(ent)
    return ent.components.mast ~= nil
        and ent.components.mast.inverted
        and ent:HasTag("saillowered")
        and not ent:HasTag("sail_transitioning")
end

local function mastcheck(ent)
    return ent.components.mast ~= nil
        and not ent.components.mast.inverted
        and ent:HasTag("sailraised")
end

local function anchorcheck(ent)
    return ent.components.anchor ~= nil
        and ent:HasTag("anchor_raised")
        and not ent:HasTag("anchor_transitioning")
end

local function chestcheck(ent)
    return
        ent.components.container ~= nil and
        not ent.components.container:IsEmpty() and
        ent:HasTag("chest") and
        not ent:HasTag("outofreach")
end

local DOTINKER_MUST_HAVE = {"structure"}

local ITEM_MUST = {"_inventoryitem"}
local ITEM_MUSTNOT = { "INLIMBO", "NOCLICK", "knockbackdelayinteraction", "catchable", "fire", "minesprung", "mineactive", "spider", "nosteal", "irreplaceable" }

local RETARGET_MUST_TAGS = { "_combat" }
local RETARGET_CANT_TAGS = { "playerghost" }
local RETARGET_ONEOF_TAGS = { "character", "monster" }

local CHEST_MUST_TAGS = { "chest", "_container" }
local CHEST_CANT_TAGS = { "outofreach" }


local function ShouldRunFn(inst)
    local bc = (inst.components.crewmember and inst.components.crewmember.boat and inst.components.crewmember.boat.components.boatcrew)
        or nil
    if bc and bc.status == "retreat" then
        return true
    end
end

local function shouldattack(inst)
    if inst.sg:HasStateTag("busy") and not inst.sg:HasStateTag("working2hm") then
        return nil
    end

    local retreat = false
    local crewboat = (inst.components.crewmember and inst.components.crewmember.boat) or nil
    local bc = (crewboat ~= nil and crewboat.components.boatcrew) or nil
    if bc and bc.status == "retreat" then
        retreat = true
    end

    return inst.components.combat.target ~= nil
        and (not retreat or inst.components.combat.target:GetCurrentPlatform() == crewboat)
end

local function count_loot(inst)
    local loot = 0
    for k,v in pairs(inst.components.inventory.itemslots) do
        if not v:HasTag("personal_possession") then
            if v.components.stackable then
                loot = loot + v.components.stackable.stacksize
            else
                loot = loot + 1
            end
        end
    end
    return loot
end

local function GetLeader(inst)
    return inst.components.follower.leader
end

local function DoAbandon(inst)
    if inst.components.crewmember and (inst.components.crewmember.boat == nil or not inst.components.crewmember.boat:IsValid()) then
        if (inst.nothingtosteal or count_loot(inst) > 3) and inst:GetCurrentPlatform() then
            inst.abandon = true
        end
    end

    if inst:GetCurrentPlatform() and inst:GetCurrentPlatform().components.health:IsDead() then
        inst.abandon = true
    end

    if not inst.abandon then
        return nil
    end

    local pos = Vector3(0,0,0)
    local platform = inst:GetCurrentPlatform()
    if platform then
        local x,y,z = inst.Transform:GetWorldPosition()
        local clear = false
        local count = 0
        while clear == false and count < 16 do
            local theta = platform:GetAngleToPoint(x, y, z)* DEGREES + (count * PI/8)
            count = count + 1
            local radius = platform.components.walkableplatform.platform_radius - 0.5
            local offset = Vector3(radius * math.cos( theta ), 0, -radius * math.sin( theta ))

            local boatpos = platform:GetPosition()

            pos = Vector3( boatpos.x+offset.x,0,boatpos.z+offset.z )

            -- SAM should offest be getting applied twice here...?
            if not TheWorld.Map:GetPlatformAtPoint(pos.x+ offset.x, pos.z+offset.z) then
                clear = true
            end
        end

        return BufferedAction(inst, nil, ACTIONS.ABANDON, nil, pos)
    end

    return nil
end

local function GoToHut(inst)
    local home = (inst.components.homeseeker ~= nil and inst.components.homeseeker.home)
        or nil
    if home == nil
            or (home.components.burnable ~= nil and home.components.burnable:IsBurning())
            or home:HasTag("burnt") then
        return nil
    end

    if inst.components.combat.target == nil then
        return BufferedAction(inst, home, ACTIONS.GOHOME)
    end
end

local function hastargetboat(inst, arc)
    local px, py, pz = inst.Transform:GetWorldPosition()

    local cannons
    if inst.components.crewmember and inst.components.crewmember.boat then
        cannons = inst.components.crewmember.boat.cannons or {}
    else
        cannons = TheSim:FindEntities(px, py, pz, 25, CANNON_MUST) or {}
    end

    if #cannons > 0 then
        local targetboats = TheSim:FindEntities(px, py, pz, 25, BOAT_MUST)

        if #targetboats > 0 then
            for _, boat in ipairs(targetboats) do
                if not inst.components.crewmember or boat ~= inst.components.crewmember.boat then
                    for _, cannon in ipairs(cannons) do
                        if cannon:IsValid() and not cannon.components.timer:TimerExists("monkey_biz") and cannon:GetDistanceSqToInst(boat) < 25*25 then
                            return {cannon=cannon,boat=boat}
                        end
                    end
                end
            end
        end
    end
end

local function findcannonspot(inst, cannon, boat)
    local cannonpos = cannon:GetPosition()
    local radius = 2
    local theta = boat:GetAngleToPoint(cannonpos.x, cannonpos.y, cannonpos.z)* DEGREES
    local offset = Vector3(radius * math.cos( theta ), 0, -radius * math.sin( theta ))

    if offset and inst:GetDistanceSqToPoint(cannonpos+offset) > (0.25*0.25) then
        return cannonpos+offset
    end
end

local function monkeyinarc(inst, cannon, target)


    local tx,ty,tz = target.Transform:GetWorldPosition()
    local mx,my,mz = inst.Transform:GetWorldPosition()
    local angle_to_target = cannon:GetAngleToPoint(tx, ty, tz)
    local angle_to_monkey = cannon:GetAngleToPoint(mx, my, mz)

    local function finddiff(a1,a2)
        local diff = math.abs(a1 - a2)
        if diff > 180 then
            diff = math.abs(diff - 360)
        end
        return diff
    end
    local anglediff =  finddiff(angle_to_target,angle_to_monkey)
    
    --print(inst.GUID, anglediff)

    if anglediff < 90 then
        return true
    end
end

local function shouldrun(inst)
    return inst.components.combat.target ~= nil and inst.components.timer:TimerExists("hit")
end

function PowderMonkeyBrain:OnStart()

    local root = PriorityNode(
    {
		BrainCommon.PanicTrigger(self.inst),

        WhileNode(function() return shouldrun(self.inst) end, "Should run",
            RunAway(self.inst, function(guy) return self.inst.components.combat.target and self.inst.components.combat.target == guy or nil end, SEE_PLAYER_DIST, STOP_RUN_DIST, nil, true)),

        -- if has a combat target fight it, unless in cooldown or has the order to retreat and not on their own boat.
        WhileNode(function() return shouldattack(self.inst) end, "Should attack",
            ChaseAndAttack(self.inst, MAX_CHASE_TIME, MAX_CHASE_DIST)),
        

        -- if should run away, go to and stay on your own boat.
        WhileNode(function() return ShouldRunFn(self.inst) end, "running away",
            Leash(self.inst, function() return self.inst.components.crewmember ~= nil and 
                self.inst.components.crewmember.boat ~= nil and 
                self.inst.components.crewmember.boat:GetPosition()
            end, RETURN_DIST, BASE_DIST)),

        ChattyNode(self.inst, HaiTang,
            FaceEntity(self.inst, GetTraderFn, KeepTraderFn)),

        BrainCommon.NodeAssistLeaderDoAction(self, parameters_MINE),
        BrainCommon.NodeAssistLeaderDoAction(self, parameters_CHOP),

        ChattyNode(self.inst, HaiTang,
                Follow(self.inst, GetLeader, MIN_FOLLOW_DIST, TARGET_FOLLOW_DIST, MAX_FOLLOW_DIST)),

        Wander(self.inst,
            function() return findwanderpointfn(self.inst) end,
            function() return findmaxwanderdistfn(self.inst) end,
            {minwalktime=0.2,randwalktime=.8,minwaittime=1,randwaittime=5}
        )

    }, .25)
    self.bt = BT(self.inst, root)
end

return PowderMonkeyBrain
