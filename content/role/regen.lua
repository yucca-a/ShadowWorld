local REGEN_TICK2HM = 2 -- 每 2 秒
local REGEN_RATE2HM = 0.1 -- 每次恢复原本数值的 10%
local REGEN_COUNT2HM = 10 -- 共 10 次
local REGEN_SOURCE2hm = "regen_danger2hm"

local function TickRegen2hm(inst)
    if inst == nil or not inst:IsValid() then return end
    local q = inst._regen2hm_queue
    local active = false

    local hlist = q ~= nil and q.health or nil
    if hlist ~= nil and #hlist > 0 then
        active = true
        local total = 0
        for i = #hlist, 1, -1 do
            local e = hlist[i]
            total = total + e.per
            e.left = e.left - 1
            if e.left <= 0 then table.remove(hlist, i) end
        end
        local comp = inst.components.health
        if total > 0 and comp ~= nil and not comp:IsDead() and not inst:HasTag("playerghost") then
            comp:DoDelta(total, nil, REGEN_SOURCE2hm)
        end
    end

    local slist = q ~= nil and q.sanity or nil
    if slist ~= nil and #slist > 0 then
        active = true
        local total = 0
        for i = #slist, 1, -1 do
            local e = slist[i]
            total = total + e.per
            e.left = e.left - 1
            if e.left <= 0 then table.remove(slist, i) end
        end
        local comp = inst.components.sanity
        if total > 0 and comp ~= nil and not inst:HasTag("playerghost") then
            comp:DoDelta(total, nil, REGEN_SOURCE2hm)
        end
    end

    if not active then
        if inst._regen2hm_task ~= nil then
            inst._regen2hm_task:Cancel()
            inst._regen2hm_task = nil
        end
        inst._regen2hm_queue = nil
    end
end

local function StartRegen2hm(inst, kind, total)
    if total == nil or total <= 0 then return end
    local q = inst._regen2hm_queue
    if q == nil then
        q = {}
        inst._regen2hm_queue = q
    end
    local list = q[kind]
    if list == nil then
        list = {}
        q[kind] = list
    end
    table.insert(list, { per = total * REGEN_RATE2HM, left = REGEN_COUNT2HM })
    if inst._regen2hm_task == nil then
        inst._regen2hm_task = inst:DoPeriodicTask(REGEN_TICK2HM, TickRegen2hm, REGEN_TICK2HM)
    end
end

local function OnEat2hm(inst, data)
    if inst == nil or not inst.regen2hm_enabled then return end
    if inst:HasTag("UM_foodregen") then return end
    if data == nil or data.food == nil then return end

    local eater = inst.components.eater
    local food = data.food
    if eater == nil or food.components == nil or food.components.edible == nil then return end
    local edible = food.components.edible

    local base_mult = inst.components.foodmemory ~= nil and inst.components.foodmemory:GetFoodMultiplier(food.prefab) or 1
    local stack_mult = eater.eatwholestack and edible.GetStackMultiplier ~= nil and edible:GetStackMultiplier() or 1

    local health_delta = 0
    if inst.components.health ~= nil and (edible.healthvalue >= 0 or eater:DoFoodEffects(food)) then
        health_delta = edible:GetHealth(inst) * base_mult * (inst._regen2hm_modded_health or 1)
    end
    local sanity_delta = 0
    if inst.components.sanity ~= nil and (edible.sanityvalue >= 0 or eater:DoFoodEffects(food)) then
        sanity_delta = edible:GetSanity(inst) * base_mult * (inst._regen2hm_modded_sanity or 1)
    end
    local hunger_delta = 0
    if eater.custom_stats_mod_fn ~= nil then
        health_delta, hunger_delta, sanity_delta = eater.custom_stats_mod_fn(inst, health_delta, hunger_delta, sanity_delta, food, data.feeder)
    end
    health_delta = health_delta * stack_mult
    sanity_delta = sanity_delta * stack_mult

    if health_delta > 0 then
        StartRegen2hm(inst, "health", health_delta)
    elseif health_delta < 0 then
        inst.components.health:DoDelta(health_delta, nil, food.prefab)
    end

    if sanity_delta > 0 then
        StartRegen2hm(inst, "sanity", sanity_delta)
    elseif sanity_delta < 0 then
        inst.components.sanity:DoDelta(sanity_delta, nil, food.prefab)
    end
end

AddComponentPostInit("eater", function(self)
    local oldset = self.SetAbsorptionModifiers
    self.SetAbsorptionModifiers = function(self, health, hunger, sanity, ...)
        local inst = self.inst
        if inst ~= nil and inst.regen2hm_enabled and (health ~= 0 or sanity ~= 0) then
            inst._regen2hm_modded_health = health
            inst._regen2hm_modded_sanity = sanity
            inst._regen2hm_modded_hunger = hunger
            return oldset(self, 0, hunger, 0)
        end
        return oldset(self, health, hunger, sanity, ...)
    end
end)

AddPlayerPostInit(function(inst)
    if not TheWorld.ismastersim then return end
    inst:DoTaskInTime(0, function(inst)
        if inst == nil or not inst:IsValid() or inst.regen2hm_enabled then return end
        if inst:HasTag("UM_foodregen") then return end
        local eater = inst.components.eater
        if eater == nil then return end
        inst._regen2hm_modded_health = eater.healthabsorption
        inst._regen2hm_modded_sanity = eater.sanityabsorption
        inst._regen2hm_modded_hunger = eater.hungerabsorption
        inst.regen2hm_enabled = true
        eater:SetAbsorptionModifiers(0, inst._regen2hm_modded_hunger, 0)
        inst:ListenForEvent("oneat", OnEat2hm)
    end)
end)

local function IsNightmarePie2hm(inst)
    return inst ~= nil and inst.prefab ~= nil and string.find(inst.prefab, "nightmarepie") ~= nil
end

AddComponentPostInit("edible", function(self)
    local oldOnEaten = self.OnEaten
    self.OnEaten = function(self, eater, ...)
        if eater ~= nil and eater:IsValid() and eater:HasTag("player") and eater.components.health ~= nil and
            IsNightmarePie2hm(self.inst) then
            local health = eater.components.health
            local origDoDelta = health.DoDelta
            health.DoDelta = function(hself, amount, overtime, cause, ...)
                if cause == "nightmarepie" and type(amount) == "number" and amount > 0 then
                    StartRegen2hm(eater, "health", amount)
                    return 0
                end
                return origDoDelta(hself, amount, overtime, cause, ...)
            end
            local ok, err = pcall(oldOnEaten, self, eater, ...)
            health.DoDelta = origDoDelta
            if not ok then print("[regen2hm] nightmarepie OnEaten failed:", err) end
            return
        end
        return oldOnEaten(self, eater, ...)
    end
end)

-- 防站撸: 挨打后获得10秒"重伤", 期间玩家的一切恢复效果减半
local WOUND_TAG2HM = "woundedregen2hm"
local WOUND_TIME2HM = 10
local WOUND_HEAL_MULT2HM = 0.5

local function ClearWound2hm(inst)
    if inst == nil or not inst:IsValid() then return end
    inst:RemoveTag(WOUND_TAG2HM)
    inst.woundtask2hm = nil
end

local function OnWounded2hm(inst, data)
    if data == nil or data.attacker == nil then return end
    if data.attacker.components == nil or data.attacker.components.combat == nil then return end
    inst:AddTag(WOUND_TAG2HM)
    if inst.woundtask2hm ~= nil then inst.woundtask2hm:Cancel() end
    inst.woundtask2hm = inst:DoTaskInTime(WOUND_TIME2HM, ClearWound2hm)
end

AddComponentPostInit("health", function(self)
    local oldDoDelta = self.DoDelta
    self.DoDelta = function(self, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb, ...)
        if amount ~= nil and amount > 0 and self.inst ~= nil and self.inst:HasTag("player") and self.inst:HasTag(WOUND_TAG2HM) then
            amount = amount * WOUND_HEAL_MULT2HM
        end
        return oldDoDelta(self, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb, ...)
    end
end)

AddPlayerPostInit(function(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("attacked", OnWounded2hm)
    inst:ListenForEvent("death", ClearWound2hm)
    inst:ListenForEvent("respawn", ClearWound2hm)
end)
