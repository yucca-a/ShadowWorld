TUNING.upatkanim2hm = GetModConfigData("Monster Harder Level")
if TUNING.upatkanim2hm and TUNING.upatkanim2hm <= 1 then TUNING.upatkanim2hm = nil end
TUNING.epicupatkanim2hm = GetModConfigData("extra_change") and GetModConfigData("boss_attackanim")
if TUNING.epicupatkanim2hm and TUNING.epicupatkanim2hm <= 1 then TUNING.epicupatkanim2hm = nil end
TUNING.notepicupatkanim2hm = GetModConfigData("extra_change") and GetModConfigData("notboss_attackanim")
if TUNING.notepicupatkanim2hm and TUNING.notepicupatkanim2hm <= 1 then TUNING.notepicupatkanim2hm = nil end
if TUNING.upatkanim2hm == nil and TUNING.epicupatkanim2hm == nil and TUNING.notepicupatkanim2hm == nil then return end
local notbossrange = GetModConfigData("notboss_range")

require "stategraph"
local specialprefabs = {"antlion", "beeguard", "crabking", "sharkboi"}

local function canprocesssg(self, inst)
    if inst and self.sg and self.sg.states then
        if inst:HasTag("player") then return end
        if TUNING.upatkanim2hm and (inst:HasTag("hostile") or table.contains(specialprefabs, inst.prefab) or inst:HasTag("pig") or
            (inst.components.combat and inst.components.combat.defaultdamage > 0 and not inst.components.follower and not inst:HasTag("companion"))) then
            return true
        end
        if TUNING.epicupatkanim2hm and (inst:HasTag("epic") or inst:HasTag("shadowchesspiece") or inst:HasTag("crabking")) then
            return true
        elseif TUNING.notepicupatkanim2hm and (not notbossrange or inst:HasTag("hostile")) then
            return true
        end
    end
end
local function getanimtate(inst)
    local rate = 1
    if TUNING.upatkanim2hm and TheWorld.components.riftspawner and
        (TheWorld.components.riftspawner.lunar_rifts_enabled or TheWorld.components.riftspawner.shadow_rifts_enabled) and
        (inst:HasTag("hostile") or table.contains(specialprefabs, inst.prefab) or inst:HasTag("pig")) then rate = TUNING.upatkanim2hm end
    if TUNING.epicupatkanim2hm and (inst:HasTag("epic") or inst:HasTag("shadowchesspiece") or inst:HasTag("crabking")) then
        rate = math.max(rate, TUNING.epicupatkanim2hm)
    elseif TUNING.notepicupatkanim2hm and (not notbossrange or inst:HasTag("hostile")) then
        rate = math.max(rate, TUNING.notepicupatkanim2hm)
    end
    return rate
end

-- 攻击动画加速
local function updateattackspeed(sg, inst)
    for _, state in pairs(sg.states) do
        if state and state.tags and state.tags.attack and not state.tags.jumping and not state.tags.moving and not state.tags.running and
            not state.tags.runningattack and not state.tags.leapattack and not state.tags.charge and not state.tags.tackle and not state.upanim2hm then
            state.upanim2hm = true
            local onenter = state.onenter
            state.onenter = function(inst, ...)
                onenter(inst, ...)
                if inst.sg.currentstate == state then SpeedUpState2hm(inst, state, getanimtate(inst)) end
            end
            local onexit = state.onexit
            state.onexit = function(inst, ...)
                if onexit then onexit(inst, ...) end
                RemoveSpeedUpState2hm(inst, state, true)
            end
        end
    end
end
local function delayprocesssg(inst, self) if canprocesssg(self, inst) then updateattackspeed(self.sg, inst) end end
local constructor = StateGraphInstance._ctor
StateGraphInstance._ctor = function(self, ...)
    constructor(self, ...)
    if self and self.inst then self.inst:DoTaskInTime(0, delayprocesssg, self) end
end
