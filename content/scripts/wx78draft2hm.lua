local M = {}
local KEY = "wx78draft2hm"
local function Skill(inst, name)
    local updater = inst.components.skilltreeupdater
    if not updater and inst.components.follower then
        local leader = inst.components.follower:GetLeader()
        updater = leader and leader.components.skilltreeupdater
    end
    return updater and updater:IsActivated(name) or false
end

function M.Values(inst)
    local alpha2 = Skill(inst, "wx78_circuitry_alphabuffs_2")
    local alpha1 = alpha2 or Skill(inst, "wx78_circuitry_alphabuffs_1")
    local block, remaining, small, large = 0, 1, 0, 0
    local owner = inst.components.upgrademoduleowner
    for _, modules in pairs(owner and owner.module_bars or {}) do
        for _, item in ipairs(modules) do
            if item.components.upgrademodule.activated then
                if item.prefab == "wx78module_maxhealth" then
                    block = block + (alpha2 and 3 or 2)
                elseif item.prefab == "wx78module_maxhealth2" then
                    block = block + (alpha2 and 7.5 or 5)
                elseif item.prefab == "wx78module_maxsanity1" then
                    small = small + 1
                    remaining = remaining * (alpha2 and .75 or alpha1 and .8 or .9)
                elseif item.prefab == "wx78module_maxsanity" then
                    large = large + 1
                    remaining = remaining * (alpha2 and .4 or alpha1 and .5 or .75)
                end
            end
        end
    end
    return math.min(20, block), math.max(.2, remaining), small, large
end

function M.Refresh(inst)
    local block, aura, small, large = M.Values(inst)
    inst.wx78draftblock2hm = block
    local sanity = inst.components.sanity
    if sanity then
        sanity.neg_aura_modifiers:SetModifier(inst, aura, KEY)
        -- Cancel only the native large circuit's passive term. Clothing and all
        -- other sanity sources retain their own native calculations.
        sanity.externalmodifiers:SetModifier(inst,
            small / 60 - large * TUNING.WX78_MAXSANITY_DAPPERNESS, KEY)
    end
end

function M.Feed(inst, gain, electric)
    local owner = inst.components.upgrademoduleowner
    if not owner then return end
    if owner:GetChargeLevel() >= owner:GetMaxChargeLevel() then
        inst.wx78nutrition2hm = 0
        return
    end
    if electric or gain <= 0 then return end
    local total = (inst.wx78nutrition2hm or 0) + gain
    local charge = math.floor(total / 45)
    inst.wx78nutrition2hm = total - charge * 45
    if charge > 0 then owner:DoDeltaCharge(charge) end
    if owner:GetChargeLevel() >= owner:GetMaxChargeLevel() then inst.wx78nutrition2hm = 0 end
end

function M.Install(E)
    E.AddComponentPostInit("upgrademoduleowner", function(self)
        local update = self.UpdateActivatedModules
        self.UpdateActivatedModules = function(self, ...)
            local result = update(self, ...)
            if self.inst.wx78draft2hm then M.Refresh(self.inst) end
            return result
        end
    end)
    for _, prefab in ipairs({"wx78", "wx78_backupbody", "wx78_possessedbody"}) do
        E.AddPrefabPostInit(prefab, function(inst)
            if not TheWorld.ismastersim then return end
            inst.wx78draft2hm = true
            -- Suppress the native Alpha II percentage bonus only. Its circuit
            -- callbacks and skill subscriptions still run normally.
            if inst.components.combat then
                local list = inst.components.combat.externaldamagetakenmultipliers
                local set = list.SetModifier
                list.SetModifier = function(self, source, value, key, ...)
                    if key == "maxhealthmoduleskill" then
                        value = 1
                        M.Refresh(inst)
                    end
                    return set(self, source, value, key, ...)
                end
                list:RemoveModifier(inst, "maxhealthmoduleskill")
            end
            if inst.components.sanity then
                local list = inst.components.sanity.neg_aura_modifiers
                local set = list.SetModifier
                list.SetModifier = function(self, source, value, key, ...)
                    if source and (source.prefab == "wx78module_maxsanity" or source.prefab == "wx78module_maxsanity1") then
                        M.Refresh(inst)
                        return
                    end
                    return set(self, source, value, key, ...)
                end
                local remove = list.RemoveModifier
                list.RemoveModifier = function(self, source, ...)
                    if source and (source.prefab == "wx78module_maxsanity" or source.prefab == "wx78module_maxsanity1") then
                        M.Refresh(inst)
                        return
                    end
                    return remove(self, source, ...)
                end
            end
            -- Inventory is called only after native redirects, parries and
            -- dodges, immediately before armor absorption and armor wear.
            if inst.components.inventory then
                local apply = inst.components.inventory.ApplyDamage
                inst.components.inventory.ApplyDamage = function(self, damage, attacker, weapon, spdamage, ...)
                    local block = M.Values(inst)
                    return apply(self, math.max(0, damage - block), attacker, weapon, spdamage, ...)
                end
            end
            if inst.components.eater then
                local eat = inst.components.eater.Eat
                inst.components.eater.Eat = function(self, food, ...)
                    local hunger = inst.components.hunger
                    local before = hunger and hunger.current or 0
                    local edible = food and food.components.edible
                    local electric = edible and edible.chargevalue and edible.chargevalue ~= 0
                    local result = eat(self, food, ...)
                    if result and hunger then M.Feed(inst, math.max(0, hunger.current - before), electric) end
                    return result
                end
            end
            local function refresh() M.Refresh(inst) end
            inst:ListenForEvent("onactivateskill_server", refresh)
            inst:ListenForEvent("ondeactivateskill_server", refresh)
            inst:ListenForEvent("energylevelupdate", function()
                local owner = inst.components.upgrademoduleowner
                if owner and owner:GetChargeLevel() >= owner:GetMaxChargeLevel() then inst.wx78nutrition2hm = 0 end
            end)
            inst:DoTaskInTime(0, refresh)
        end)
    end
end

return M
