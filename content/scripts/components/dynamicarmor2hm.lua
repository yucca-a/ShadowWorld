-- Pressure is stored as a fraction of max health, so health changes preserve it.
local THRESHOLD = 0.2
local BAND = 0.1
local LIMIT = THRESHOLD + BAND
local UPDATE_PERIOD = 3 * FRAMES
local COOLING_DELAY = 1

local function IsFinite(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function Multiplier(value)
    return IsFinite(value) and math.max(1, value) or 1
end

local function IsEligible(inst)
    return not inst:HasTag("player") and not inst:HasTag("swc2hm")
        and inst.prefab ~= "lordfruitfly" and inst.prefab ~= "antlion"
        and (inst:HasTag("epic") or inst.prefab == "crabking" or inst.prefab == "crabking2hm")
end

-- Lua 5.1 has no expm1. Keep small damage packets accurate near the threshold.
local function OneMinusExpNegative(x)
    if x < 0.0001 then
        return x * (1 - x * (0.5 - x * (1 / 6 - x / 24)))
    end
    return 1 - math.exp(-x)
end

local DynamicArmor = Class(function(self, inst)
    self.inst = inst
    self.pressure = 0
    self.lasttime = GetTime()
    self.externalhealthmult = 1
end)

DynamicArmor.IsEligible = function(self) return IsEligible(self.inst) end

function DynamicArmor:GetHealthMultiplier()
    local multiplier = Multiplier(TUNING.DYNAMIC_ARMOR_BOSS_HEALTH_MULT2HM) * self.externalhealthmult
    return Multiplier(multiplier)
end

-- Compatibility API: only the extra multiplier supplied by another mod, excluding
-- this mod's boss_health setting. Never infer multipliers from final max health.
function DynamicArmor:SetExternalHealthMultiplier(multiplier)
    self:Decay()
    self.externalhealthmult = Multiplier(multiplier)
end

function DynamicArmor:GetDecayRate()
    local rate = 0.02 / math.sqrt(self:GetHealthMultiplier())
    local health = self.inst.components.health
    local maximum = health ~= nil and health.maxhealth or 0
    return IsFinite(maximum) and maximum > 0 and math.max(rate, 400 / maximum) or rate
end

function DynamicArmor:Cool(elapsed, grace)
    -- Continuous damage still cools proportionally, so sustained attacks cannot
    -- pin a boss at almost 100% resistance. Delay only the 400 HP/sec floor.
    local active = math.min(elapsed, math.max(0, grace))
    local rate = 0.02 / math.sqrt(self:GetHealthMultiplier())
    self.pressure = math.max(0, self.pressure - active * rate - (elapsed - active) * self:GetDecayRate())
end

function DynamicArmor:Decay()
    local now = GetTime()
    local elapsed = math.max(0, now - self.lasttime)
    self:Cool(elapsed, (self.coolinguntil or self.lasttime) - self.lasttime)
    self.lasttime = now
    return self.pressure
end

function DynamicArmor:GetResistance()
    return math.clamp((self:Decay() - THRESHOLD) / BAND, 0, 1)
end

function DynamicArmor:RemoveFX()
    if self.fx ~= nil then
        if self.fx:IsValid() then self.fx:Remove() end
        self.fx = nil
    end
end

function DynamicArmor:UpdateFX()
    local resistance = self:GetResistance()
    local health = self.inst.components.health
    if resistance <= 0 or not self:IsEligible() or health == nil or health:IsDead() or self.inst:IsAsleep() then
        self:RemoveFX()
        return false
    end
    if self.fx == nil or not self.fx:IsValid() then
        self.fx = SpawnPrefab("dynamicarmor_indicator2hm")
        if self.fx == nil then return true end -- Retry a temporarily unavailable effect.
        self.fx.persists = false
        self.fx.entity:SetParent(self.inst.entity)
        self.fx.Transform:SetPosition(0, 0, 0)
        self.fx:SetTarget(self.inst)
    end
    self.fx:SetResistance(resistance)
    return true
end

function DynamicArmor:StopTask()
    if self.task ~= nil then self.task:Cancel(); self.task = nil end
end

function DynamicArmor:Refresh()
    -- Damage/save queries already decay by elapsed game time. Below the visual
    -- threshold there is nothing to animate, including while the boss sleeps.
    if not self:UpdateFX() then
        self:StopTask()
    elseif self.task == nil then
        self.task = self.inst:DoPeriodicTask(UPDATE_PERIOD, function() self:Refresh() end)
    end
end

function DynamicArmor:OnEntitySleep()
    self:StopTask()
    self:RemoveFX()
end

DynamicArmor.OnEntityWake = DynamicArmor.Refresh

function DynamicArmor:CalculateDamage(damage)
    local health = self.inst.components.health
    local maximum = health ~= nil and health.maxhealth or 0
    if not self:IsEligible() or not IsFinite(maximum) or maximum <= 0 or damage <= 0 then return damage end
    -- Applied after existing defenses/health caps, before continuous resistance.
    -- A smaller existing cap remains effective; this never raises incoming damage.
    damage = math.min(damage, maximum * 0.1)
    local pressure = self:Decay() * maximum
    local free = math.min(damage, math.max(0, THRESHOLD * maximum - pressure))
    local remaining = damage - free
    local room = math.max(0, LIMIT * maximum - pressure - free)
    local reduced = free + room * OneMinusExpNegative(remaining / (BAND * maximum))
    return math.max(0, math.min(damage, reduced))
end

function DynamicArmor:RecordDamage(damage)
    local health = self.inst.components.health
    if health ~= nil and IsFinite(health.maxhealth) and health.maxhealth > 0 and damage > 0 then
        self:Decay()
        self.pressure = math.min(LIMIT, self.pressure + damage / health.maxhealth)
        self.coolinguntil = GetTime() + COOLING_DELAY
        self:Refresh()
    end
end

function DynamicArmor:OnSave()
    self:Decay()
    if self.pressure > 0 or self.externalhealthmult ~= 1 then
        return {pressure = self.pressure, externalhealthmult = self.externalhealthmult,
            cooling = math.max(0, (self.coolinguntil or 0) - GetTime())}
    end
end

function DynamicArmor:OnLoad(data)
    self.pressure = data ~= nil and IsFinite(data.pressure) and math.clamp(data.pressure, 0, LIMIT) or 0
    self.externalhealthmult = Multiplier(data ~= nil and data.externalhealthmult or nil)
    -- Loading does not count wall-clock/offline time as in-game cooling.
    self.lasttime = GetTime()
    self.coolinguntil = self.lasttime + (data ~= nil and IsFinite(data.cooling)
        and math.clamp(data.cooling, 0, COOLING_DELAY) or 0)
    self:Refresh()
end

function DynamicArmor:TransferTo(other)
    if other ~= nil and other.components.dynamicarmor2hm ~= nil then
        other.components.dynamicarmor2hm:OnLoad(self:OnSave())
    end
end

function DynamicArmor:LongUpdate(dt)
    self:Decay()
    local elapsed = math.max(0, dt)
    local grace = math.max(0, (self.coolinguntil or 0) - GetTime())
    self:Cool(elapsed, grace)
    self.coolinguntil = GetTime() + math.max(0, grace - elapsed)
    self.lasttime = GetTime()
    self:Refresh()
end

function DynamicArmor:OnRemoveFromEntity()
    self:StopTask()
    self:RemoveFX()
end
DynamicArmor.OnRemoveEntity = DynamicArmor.OnRemoveFromEntity

function DynamicArmor:GetDebugString()
    return string.format("pressure=%.3f%% resistance=%.1f%% healthmult=%.3f", self:Decay() * 100,
        self:GetResistance() * 100, self:GetHealthMultiplier())
end

return DynamicArmor
