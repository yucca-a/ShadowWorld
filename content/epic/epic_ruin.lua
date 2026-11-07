local epic_ruin_rate = GetModConfigData("epic_ruin")
-- Numeric 1 was stored by the old 100% default. Use a new value for an
-- explicit 100% selection made after the upgrade.
if epic_ruin_rate == nil or epic_ruin_rate == 1 then
    epic_ruin_rate = 0.8
elseif epic_ruin_rate == "full" then
    epic_ruin_rate = 1
end

local function IsEpic2hm(inst)
    return inst ~= nil and inst:IsValid() and (inst:HasTag("epic") or inst:HasTag("epic_child2hm"))
end

local function InitEpicRuinData(inst)
    if not inst.components.persistent2hm then
        inst:AddComponent("persistent2hm")
    end
    if not inst.components.persistent2hm.data.epicruin2hm then
        inst.components.persistent2hm.data.epicruin2hm = {
            totalEpicDamage = 0,
            lastDecayDay = TheWorld.state.cycles or 0,
        }
    end
    return inst.components.persistent2hm.data.epicruin2hm
end

local function GetEpicRuinData(inst)
    local persistent = inst.components.persistent2hm
    return persistent and persistent.data.epicruin2hm
end

local function DailyDecayEpicDamage(inst)
    if not inst.components.health then return end

    local data = GetEpicRuinData(inst)
    if not data or data.totalEpicDamage <= 0 then return end

    local currentDay = TheWorld.state.cycles or 0
    local lastDecayDay = data.lastDecayDay or 0
    local daysPassed = currentDay - lastDecayDay

    if daysPassed > 0 then
        local maxHealth = inst.components.health.maxhealth
        local decayAmount = maxHealth * 0.2 * daysPassed

        data.totalEpicDamage = math.max(0, data.totalEpicDamage - decayAmount)
        data.lastDecayDay = currentDay
    end
end

local function RecordEpicDamage(inst, damage, attacker)
    if not inst.components.health then return end
    if inst:HasTag("player") then return end
    if not IsEpic2hm(attacker) then return end

    local data = GetEpicRuinData(inst) or InitEpicRuinData(inst)

    DailyDecayEpicDamage(inst)
    if data.totalEpicDamage <= 0 then data.lastDecayDay = TheWorld.state.cycles or 0 end

    local maxHealth = inst.components.health.maxhealth
    data.totalEpicDamage = math.min(data.totalEpicDamage + damage, maxHealth)
end

local function CalculateReduceRatio(inst)
    if not inst.components.health then return 0 end
    local data = GetEpicRuinData(inst)
    if not data or data.totalEpicDamage <= 0 then return 0 end

    DailyDecayEpicDamage(inst)

    local maxHealth = inst.components.health.maxhealth
    local epicDamageRatio = data.totalEpicDamage / maxHealth
    return math.min(epicDamageRatio * epic_ruin_rate, 1)
end

local function ModifyLootDropper(inst)
    if not inst.components.lootdropper then return end

    local oldGenerateLoot = inst.components.lootdropper.GenerateLoot
    inst.components.lootdropper.GenerateLoot = function(self)
        local loots = oldGenerateLoot(self)

        local reduceRatio = CalculateReduceRatio(inst)
        if reduceRatio <= 0 or not loots or #loots == 0 then
            return loots
        end

        local removeCount = math.floor(#loots * reduceRatio)

        for i = 1, removeCount do
            if #loots > 0 then
                table.remove(loots, math.random(#loots))
            end
        end

        return loots
    end
end

local function ModifyHealthComponent(inst)
    if not inst.components.health then return end

    local oldSetVal = inst.components.health.SetVal
    inst.components.health.SetVal = function(self, val, cause, afflicter)
        local delta = self.currenthealth - val

        if delta > 0 and afflicter then
            RecordEpicDamage(inst, delta, afflicter)
        end

        return oldSetVal(self, val, cause, afflicter)
    end
end

AddPrefabPostInitAny(function(inst)
    if not TheWorld.ismastersim then return end
    if inst:HasTag("player") then return end
    if not inst.components.health then return end

    if not inst.components.persistent2hm then
        local oldOnPreLoad = inst.OnPreLoad
        inst.OnPreLoad = function(self, saved, ...)
            -- DST loads component data only after OnPreLoad. Recreate the
            -- lazily added component so older snapshots can load it as well.
            local persistent = saved and saved.persistent2hm
            if persistent and persistent.epicruin2hm and not self.components.persistent2hm then
                self:AddComponent("persistent2hm")
            end
            if oldOnPreLoad then return oldOnPreLoad(self, saved, ...) end
        end
    end

    inst:DoTaskInTime(0, function()
        if not inst:IsValid() then return end

        ModifyHealthComponent(inst)

        ModifyLootDropper(inst)

        inst:WatchWorldState("cycles", function()
            DailyDecayEpicDamage(inst)
        end)
    end)
end)
