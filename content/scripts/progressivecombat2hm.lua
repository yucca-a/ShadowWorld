-- Attack-side only. Target armor, vulnerability, health caps and dynamic armor
-- remain in the original GetAttacked/DoDelta pipeline.
local SpDamageUtil = require("components/spdamageutil")
local SourceModifierList = require("util/sourcemodifierlist")
local Weapon = require("components/weapon")
local PlanarDamage = require("components/planardamage")
local DamageTypeBonus = require("components/damagetypebonus")

local WIDTH = 0.5
local SPECIAL_THRESHOLD = 2
local ROLE_THRESHOLDS = {wolfgang = 3.5, wathom = 4}
local M = {}

function M.SoftLimit(value, threshold)
    if value <= threshold then return value end
    -- Equivalent to C + W*x/(W+x), without inf/inf on extreme modifier stacks.
    return threshold + WIDTH - WIDTH * WIDTH / (WIDTH + value - threshold)
end

local function Add(factors, value)
    if type(value) == "number" and value == value then factors[#factors + 1] = value end
end

local function Copy(factors)
    local copy = {}
    for i, value in ipairs(factors) do copy[i] = value end
    return copy
end

local function Append(to, from)
    for _, value in ipairs(from) do to[#to + 1] = value end
end

local function AddList(factors, list)
    if list == nil then return end
    if list._fn == SourceModifierList.multiply and list._modifiers ~= nil then
        Add(factors, list._base or 1)
        for _, source in pairs(list._modifiers) do
            for _, value in pairs(source.modifiers) do Add(factors, value) end
        end
    else
        -- Non-multiplicative/opaque modifier lists retain their public semantics.
        Add(factors, list:Get())
    end
end

local function TypeFactors(inst, target)
    local factors = {}
    local bonus = inst ~= nil and inst.components.damagetypebonus or nil
    if bonus ~= nil then
        if bonus.GetBonus == DamageTypeBonus.GetBonus then
            for tag, list in pairs(bonus.tags) do
                if target:HasTag(tag) then AddList(factors, list) end
            end
            if bonus.bonuscallbacks ~= nil then
                for _, fn in ipairs(bonus.bonuscallbacks) do Add(factors, fn(inst, target) or 1) end
            end
        else
            Add(factors, bonus:GetBonus(target))
        end
    end
    return factors
end

local function Evaluate(amount, factors, threshold, linear)
    local positive, negative = 1, 1
    for _, value in ipairs(factors) do
        if value > 1 then positive = positive * value else negative = negative * value end
    end
    return amount * M.SoftLimit(positive, threshold) * negative * (linear or 1)
end

local function AddSpecial(result, kind, amount)
    if amount > 0 then result[kind] = (result[kind] or 0) + amount end
end

local function ReadSpecial(inst, report)
    local result = {}
    for kind in pairs(SpDamageUtil._SpTypeMap) do
        local raw = SpDamageUtil.GetSpDamageForType(inst, kind)
        if raw > 0 then
            local planar = kind == "planar" and inst.components.planardamage or nil
            if planar ~= nil and planar.GetDamage == PlanarDamage.GetDamage
                and raw == planar.basedamage * planar.externalmultipliers:Get() + planar.externalbonuses:Get() then
                -- Component bonuses do not inherit component multipliers. Both
                -- contributions still receive their applicable outer multipliers.
                local basefactors = {}
                AddList(basefactors, planar.externalmultipliers)
                result[kind] = {{amount = planar.basedamage, factors = basefactors},
                    {amount = planar.externalbonuses:Get()}}
            else
                -- Registered special types and custom GetDamage retain their raw
                -- amount; do not guess hidden internal multipliers from that amount.
                result[kind] = {{amount = raw}}
                report.opaque = true
            end
        end
    end
    return result
end

-- Optional weapon adapter: weapon.components.weapon.progressiveterms2hm(self,
-- attacker, target) returns {regular={{amount=..., factors={...}}, ...},
-- special={planar={{amount=..., factors={...}}, ...}, ...}}. Amounts are before
-- the listed factors. Include weapon-local tag bonuses exactly once in factors.
local function EvaluateTerms(terms, outer, threshold, linear)
    local total = 0
    for _, term in ipairs(terms or {}) do
        local factors = Copy(outer)
        Append(factors, term.factors or {})
        total = total + Evaluate(term.amount or 0, factors, threshold, linear)
    end
    return total
end

function M.CalcDamage(self, target, weapon, multiplier)
    if target:HasTag("alwaysblock") then return 0 end
    local player = self.inst
    local mount, saddle
    if weapon == nil and player.components.rider ~= nil and player.components.rider:IsRiding() then
        mount = player.components.rider:GetMount()
        saddle = player.components.rider:GetSaddle()
    end
    local mounted = mount ~= nil and mount.components.combat ~= nil
    local source = mounted and mount or player
    local combat = mounted and mount.components.combat or self
    local threshold = mounted and 2.5 or (ROLE_THRESHOLDS[player.prefab] or 2.5)
    local report = {threshold = threshold, specialthreshold = SPECIAL_THRESHOLD}
    local targetplayer = CanApplyPlayerDamageMod(target)
    local pvp = targetplayer and player.isplayer and self.pvp_damagemod or 1
    local playerdamage = weapon == nil and targetplayer and self.playerdamagepercent or 1
    local regularlinear = pvp * playerdamage
    local base = combat.defaultdamage or 0
    local weaponfactors, shared, adapter
    local specialgroups = {}
    -- Read the weapon and source-local contributions before character callbacks,
    -- in the native order; stateful GetDamage/custom callbacks run only once.
    if weapon ~= nil then
        local wc = weapon.components.weapon
        if wc.progressiveterms2hm ~= nil then
            adapter = wc:progressiveterms2hm(player, target)
            specialgroups[#specialgroups + 1] = {terms = adapter.special or {}}
        elseif wc.GetDamage == Weapon.GetDamage then
            base = FunctionOrValue(wc.damage, weapon, player, target) or 0
            local terms = ReadSpecial(weapon, report)
            weaponfactors = TypeFactors(weapon, target)
            specialgroups[#specialgroups + 1] = {terms = terms, factors = weaponfactors}
        else
            local rawspecial
            base, rawspecial = wc:GetDamage(player, target)
            local terms = {}
            for kind, value in pairs(rawspecial or {}) do terms[kind] = {{amount = value}} end
            specialgroups[#specialgroups + 1] = {terms = terms}
            report.opaque = true
        end
        shared = TypeFactors(player, target)
        specialgroups[#specialgroups + 1] = {terms = ReadSpecial(player, report)}
    else
        shared = TypeFactors(source, target)
        specialgroups[#specialgroups + 1] = {terms = ReadSpecial(source, report)}
        if saddle ~= nil and saddle.components.saddler ~= nil then
            base = base + saddle.components.saddler:GetBonusDamage()
            Append(shared, TypeFactors(saddle, target))
            specialgroups[#specialgroups + 1] = {terms = ReadSpecial(saddle, report)}
        end
    end

    local regular = Copy(shared)
    Add(regular, combat.damagemultiplier or 1)
    AddList(regular, combat.externaldamagemultipliers)
    Add(regular, multiplier or 1)
    -- Callbacks are evaluated once. A callback returning a mixed net factor is
    -- treated as one factor unless its owner explicitly supplies separate terms.
    if self.customdamagemultfn ~= nil then Add(regular, self.customdamagemultfn(player, target, weapon, multiplier, mount) or 1) end

    local damage, spdamage = 0, {}
    if adapter ~= nil then
        damage = EvaluateTerms(adapter.regular, regular, threshold, regularlinear)
    else
        if weaponfactors ~= nil then Append(regular, weaponfactors) end
        damage = Evaluate(base or 0, regular, threshold, regularlinear)
    end
    local special
    for _, group in ipairs(specialgroups) do
        if next(group.terms) ~= nil then
            if special == nil then
                special = Copy(shared)
                if self.customspdamagemultfn ~= nil then
                    Add(special, self.customspdamagemultfn(player, target, weapon, multiplier, mount) or 1)
                end
            end
            local factors = Copy(special)
            Append(factors, group.factors or {})
            for kind, terms in pairs(group.terms) do
                AddSpecial(spdamage, kind, EvaluateTerms(terms, factors, SPECIAL_THRESHOLD, pvp))
            end
        end
    end
    damage = damage + (combat.damagebonus or 0)
    return damage, next(spdamage) ~= nil and spdamage or nil, report
end

return M
