-- Loaded exclusively instead of epic_armor.lua. Do not reuse invincible2hm.
PrefabFiles[#PrefabFiles + 1] = "dynamicarmor_indicator2hm"
local configuredmult = GetModConfigData("extra_change") and GetModConfigData("boss_health") or 1
TUNING.DYNAMIC_ARMOR_BOSS_HEALTH_MULT2HM = type(configuredmult) == "number"
    and configuredmult == configuredmult and configuredmult < math.huge and math.max(1, configuredmult) or 1

local nextphase = {alterguardian_phase1 = "alterguardian_phase2", alterguardian_phase2 = "alterguardian_phase3"}
local transitioncontext

local function Eligible(inst)
    return inst.components.health ~= nil and not inst:HasTag("player") and not inst:HasTag("swc2hm")
        and inst.prefab ~= "lordfruitfly" and inst.prefab ~= "antlion"
        and (inst:HasTag("epic") or inst.prefab == "crabking" or inst.prefab == "crabking2hm")
end

local function Attach(inst)
    if not TheWorld.ismastersim or not Eligible(inst) then return end
    if inst.components.dynamicarmor2hm == nil then inst:AddComponent("dynamicarmor2hm") end
    if inst.dynamicarmor2hm_events then return end
    inst.dynamicarmor2hm_events = true
    -- Settle at the old maximum before changing the HP-based cooling floor.
    -- Only eligible bosses need this hook; ordinary health components do not.
    local health = inst.components.health
    local SetMaxHealth = health.SetMaxHealth
    health.SetMaxHealth = function(self, ...)
        local armor = self.inst.components.dynamicarmor2hm
        if armor ~= nil then armor:Decay() end
        return SetMaxHealth(self, ...)
    end
    local PushEvent = inst.PushEvent
    inst.PushEvent = function(self, event, data, ...)
        local health = self.components.health
        local context = health ~= nil and health.dynamicarmor2hm_context or nil
        if event == "healthdelta" and data ~= nil and context ~= nil and context.actualdelta ~= nil then
            data.amount = context.actualdelta
        elseif event == "phasetransition" and nextphase[self.prefab] ~= nil
            and self.components.dynamicarmor2hm:IsEligible() then
            -- The original transition removes this entity BEFORE spawning the next.
            -- Scope inheritance to this exact synchronous transition, never a nearby boss.
            local previous = transitioncontext
            transitioncontext = {prefab = nextphase[self.prefab], data = self.components.dynamicarmor2hm:OnSave()}
            local ok, result = pcall(PushEvent, self, event, data, ...)
            transitioncontext = previous
            if not ok then error(result) end
            return result
        end
        return PushEvent(self, event, data, ...)
    end
end

AddPrefabPostInitAny(function(inst)
    if not TheWorld.ismastersim then return end
    Attach(inst) -- Before component OnLoad; no replacement of prefab save callbacks.
    if transitioncontext ~= nil and inst.prefab == transitioncontext.prefab and inst.components.dynamicarmor2hm ~= nil then
        inst.components.dynamicarmor2hm:OnLoad(transitioncontext.data)
    end
    if inst.components.health ~= nil then
        inst:DoTaskInTime(0, function()
            Attach(inst) -- Some creatures gain their boss tags during initialization.
            if inst.components.dynamicarmor2hm ~= nil and inst.components.dynamicarmor2hm:IsEligible() then
                -- Explicit mode changes must not leave the old crabking shield timer active.
                if inst.components.timer ~= nil then inst.components.timer:StopTimer("invincible2hm") end
                inst.epic_armor2hm = nil
            end
        end)
    end
end)

AddComponentPostInit("health", function(health)
    local DoDelta = health.DoDelta
    health.DoDelta = function(self, amount, ...)
        if amount ~= nil and amount < 0 and self.inst.components.dynamicarmor2hm == nil then Attach(self.inst) end
        local armor = self.inst.components.dynamicarmor2hm
        local previous = self.dynamicarmor2hm_context
        local context = armor ~= nil and armor:IsEligible() and amount ~= nil and amount < 0
            and not self._ignore_maxdamagetakenperhit and not self.inst.bypassdynamicarmor2hm and {armor = armor} or nil
        self.dynamicarmor2hm_context = context
        local result = DoDelta(self, amount, ...)
        self.dynamicarmor2hm_context = previous
        return context ~= nil and context.actualdelta ~= nil and context.actualdelta or result
    end

    local SetVal = health.SetVal
    health.SetVal = function(self, value, cause, afflicter, ...)
        local context = self.dynamicarmor2hm_context
        -- SetPercent, load, initialization and scripted phase changes are structural
        -- writes. Only a normal negative DoDelta enters this damage context.
        if context ~= nil and not context.consumed and value < self.currenthealth then
            context.consumed = true
            local damage = context.armor:CalculateDamage(self.currenthealth - value)
            local minimum = math.min(self.minhealth or 0, self:GetMaxWithPenalty())
            damage = math.min(damage, math.max(0, self.currenthealth - minimum))
            value = self.currenthealth - damage
            context.actualdelta = -damage
            -- Reserve the clamped actual loss before minhealth/death callbacks can
            -- revive this boss or synchronously spawn its next phase.
            context.armor:RecordDamage(damage)
        end
        return SetVal(self, value, cause, afflicter, ...)
    end

    local TransferComponent = health.TransferComponent
    if TransferComponent ~= nil then
        health.TransferComponent = function(self, other, ...)
            local result = TransferComponent(self, other, ...)
            if self.inst.components.dynamicarmor2hm ~= nil then
                Attach(other)
                self.inst.components.dynamicarmor2hm:TransferTo(other)
            end
            return result
        end
    end
end)

AddComponentPostInit("inspectable", function(inspectable)
    local GetDescription = inspectable.GetDescription
    inspectable.GetDescription = function(self, viewer, ...)
        local description, filter, author = GetDescription(self, viewer, ...)
        local armor = self.inst.components.dynamicarmor2hm
        if type(description) == "string" and armor ~= nil and armor:IsEligible() and viewer ~= nil
            and not viewer:HasTag("mime") and not viewer:HasTag("playerghost") and CanEntitySeeTarget(viewer, self.inst) then
            local resistance = math.floor(armor:GetResistance() * 100 + 0.5)
            description = description .. "\n" .. string.format(TUNING.isCh2hm and "[巨兽装甲：单次上限10%%最大生命；动态减伤 %d%%]"
                or "[Epic Armor: per-hit cap 10%% max health; dynamic resistance %d%%]", resistance)
        end
        return description, filter, author
    end
end)
