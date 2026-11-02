-- AddRecipePostInit(
--     "bernie_inactive",
--     function(inst)
--         table.insert(inst.ingredients, Ingredient("shadowheart", 1))
--     end
-- )
-- TUNING.BERNIE_HEALTH = TUNING.BERNIE_HEALTH * 2
-- TUNING.BERNIE_BIG_HEALTH = TUNING.BERNIE_BIG_HEALTH * 2
local bernies = {"bernie_active", "bernie_big"}

local function OnAttacked(inst, data) if inst:GetIsWet() and inst.components.health then inst.components.health:DoDelta(-34) end end

for index, bernie in ipairs(bernies) do
    AddPrefabPostInit(bernie, function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("blocked", OnAttacked)
        inst:ListenForEvent("attacked", OnAttacked)
    end)
end

-- 巨熊和熊着火都会让火女黑化
local function OnLighterLight(inst)
    if not inst:HasTag("swc2hm") and inst.fire_fx and inst.fire_fx:IsValid() and inst.bernieleader and inst.bernieleader:IsValid() and inst.bernieleader.prefab ==
        "willow" and inst.bernieleader.components.sanity then
        inst:ListenForEvent("onremove", inst._onfirelost2hm, inst.fire_fx)
        inst.bernieleader.components.sanity:AddSanityPenalty(inst.fire_fx, 0.15)
    end
end
local function delayOnLighterLight(inst) inst:DoTaskInTime(0, OnLighterLight) end
local function onbernie_bigremove(inst)
    if not inst:HasTag("swc2hm") and inst.bernieleader and inst.bernieleader:IsValid() and inst.bernieleader.prefab == "willow" and
        inst.bernieleader.components.sanity then
        inst.bernieleader.components.sanity:RemoveSanityPenalty(inst)
        if inst.fire_fx and inst.fire_fx:IsValid() then
            inst:RemoveEventCallback("onremove", inst._onfirelost2hm, inst.fire_fx)
            inst.bernieleader.components.sanity:RemoveSanityPenalty(inst.fire_fx)
        end
    end
end
AddPrefabPostInit("bernie_big", function(inst)
    if not TheWorld.ismastersim then return end
    inst._onfirelost2hm = function(firefx)
        if not inst:HasTag("swc2hm") and inst.bernieleader and inst.bernieleader:IsValid() and inst.bernieleader.prefab == "willow" and
            inst.bernieleader.components.sanity then inst.bernieleader.components.sanity:RemoveSanityPenalty(firefx) end
    end
    local onLeaderChanged = inst.onLeaderChanged
    inst.onLeaderChanged = function(inst, leader, ...)
        if not inst:HasTag("swc2hm") and leader ~= inst.bernieleader and inst.bernieleader and inst.bernieleader:IsValid() and inst.bernieleader.prefab ==
            "willow" and inst.bernieleader.components.sanity then
            inst.bernieleader.components.sanity:RemoveSanityPenalty(inst)
            if inst.fire_fx and inst.fire_fx:IsValid() then
                inst:RemoveEventCallback("onremove", inst._onfirelost2hm, inst.fire_fx)
                inst.bernieleader.components.sanity:RemoveSanityPenalty(inst.fire_fx)
            end
        end
        onLeaderChanged(inst, leader, ...)
        if not inst:HasTag("swc2hm") and inst.bernieleader and inst.bernieleader:IsValid() and inst.bernieleader.prefab == "willow" and
            inst.bernieleader.components.sanity then
            inst.bernieleader.components.sanity:AddSanityPenalty(inst, 0.15)
            if inst.fire_fx and inst.fire_fx:IsValid() then
                inst:ListenForEvent("onremove", inst._onfirelost2hm, inst.fire_fx)
                inst.bernieleader.components.sanity:AddSanityPenalty(inst.fire_fx, 0.15)
            end
        end
    end
    inst:ListenForEvent("onremove", onbernie_bigremove)
    inst:ListenForEvent("onlighterlight", delayOnLighterLight)
end)
-- 火女施法也会黑化
local function cancelembersanity(inst)
    inst.components.persistent2hm.data.willow_ember_amount = nil
    inst.components.sanity:RemoveSanityPenalty("ember2hm")
    inst.embersanitytask2hm = nil
end
local function checkember(inst, amount)
    if inst.components.persistent2hm.data.willow_ember_amount and inst.components.sanity then
        if inst.embersanitytask2hm then inst.embersanitytask2hm:Cancel() end
        if inst.components.persistent2hm.data.willow_ember_amount > 0 then
            inst.embersanitytask2hm = inst:DoTaskInTime(60, cancelembersanity) -- 2025.9.3 melon:120->60
            local oldpercent = inst.components.sanity:GetPercent() * 1000 + 1
            inst.components.sanity:AddSanityPenalty("ember2hm", 0.025 * inst.components.persistent2hm.data.willow_ember_amount)
            if amount and TUNING.easymode2hm then
                local newpercent = inst.components.sanity:GetPercent() * 1000
                if oldpercent - newpercent >= 25 then return math.floor((oldpercent - newpercent) / 25) end
            end
        else
            cancelembersanity(inst)
        end
    end
end
local function OnDeath(inst)
    if inst.embersanitytask2hm then inst.embersanitytask2hm:Cancel() end
    cancelembersanity(inst)
end
local _consumewillowember
AddComponentPostInit("aoespell", function(self)
    if self.inst and self.inst:HasTag("willow_ember") then
        local CastSpell = self.CastSpell
        self.CastSpell = function(self, ...)
            _consumewillowember = true
            local result, reason = CastSpell(self, ...)
            if result and self.spellfn and _consumewillowember ~= nil and _consumewillowember ~= true and _consumewillowember.inst then
                local inst = _consumewillowember.inst
                local amount = _consumewillowember.amount
                -- 火焰BUFF不太一样
                if inst.notconsumewillowembertask2hm then
                    inst.notconsumewillowembertask2hm:Cancel()
                    inst.notconsumewillowembertask2hm = nil
                end
                if amount and inst.components and inst.components.sanity and inst.components.persistent2hm and inst.components.inventory then
                    local regive
                    if inst.willowembersrc2hm then
                        if inst.willowembersrc2hm:IsValid() then
                            local oldpercent = inst.components.sanity:GetPercent() * 1000 + 1
                            inst.components.sanity:AddSanityPenalty(inst.willowembersrc2hm, 0.025 * amount)
                            if TUNING.easymode2hm then
                                local newpercent = inst.components.sanity:GetPercent() * 1000
                                if oldpercent - newpercent >= 25 then
                                    regive = math.clamp(math.floor((oldpercent - newpercent) / 25), 0, amount)
                                end
                            end
                        end
                        inst.willowembersrc2hm = nil
                    else
                        -- 正常施法黑化
                        inst.components.persistent2hm.data.willow_ember_amount = (inst.components.persistent2hm.data.willow_ember_amount or 0) + amount
                        regive = math.clamp(checkember(inst, amount) or 0, 0, amount)
                    end
                    if regive and regive > 0 then for i = 1, regive, 1 do inst.components.inventory:GiveItem(SpawnPrefab("willow_ember")) end end
                end
            end
            _consumewillowember = nil
            return result, reason
        end
    end
end)
AddPrefabPostInit("willow", function(inst)
    if not TheWorld.ismastersim then return end
    if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
    if inst.components.inventory then
        local Has = inst.components.inventory.Has
        inst.components.inventory.Has = function(self, item, amount, ...)
            if item == "willow_ember" and _consumewillowember == true and amount and amount > 0 then
                _consumewillowember = {amount = amount, inst = inst}
            end
            return Has(self, item, amount, ...)
        end
    end
    inst:DoTaskInTime(0, checkember)
    inst:ListenForEvent("death", OnDeath)
end)
-- 火焰BUFF
local function onfirefrenzyremove(inst)
    if inst.target2hm and inst.target2hm:IsValid() and inst.target2hm.prefab == "willow" and inst.target2hm.components.sanity then
        inst.target2hm.components.sanity:RemoveSanityPenalty(inst)
    end
end
local function firefrenzyinit(inst)
    if inst.components.debuff and inst.components.debuff.target:IsValid() and inst.components.debuff.target.prefab == "willow" and
        inst.components.debuff.target.components.sanity and inst.components.debuff.target.components.persistent2hm then
        inst.target2hm = inst.components.debuff.target
        if inst.target2hm.notconsumewillowembertask2hm == nil then
            inst.target2hm.willowembersrc2hm = inst
            inst.target2hm.notconsumewillowembertask2hm = inst.target2hm:DoTaskInTime(0, function(inst)
                inst.willowembersrc2hm = nil
                inst.notconsumewillowembertask2hm = nil
            end)
        end
    end
end
AddPrefabPostInit("buff_firefrenzy", function(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("onremove", onfirefrenzyremove)
    inst:DoTaskInTime(0, firefrenzyinit)
end)
-- 月火伤害持续递减,对单每次减少2%,对群每次减少更多
local function cancelflamethrowerdamagetask(inst)
    inst.flamethrowerdamagetask2hm = nil
    inst.flamethrowerdamagereduce2hm = nil
end

local function cancelshadowflamethrowerdamagetask(inst)
    inst.shadowflamethrowerdamagereduce2hm = nil
    inst.shadowflamethrowerdamagereduce2hm = nil
end

AddPrefabPostInit("flamethrower_fx", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.weapon then
        inst:DoTaskInTime(0, function()
            inst.recenttargets2hm = {}
            local GetDamage = inst.components.weapon.GetDamage
            inst.components.weapon.GetDamage = function(self, attacker, target, ...)
                local dmg, spdmg = GetDamage(self, attacker, target, ...)
                if target and target:IsValid() then
                    if target.components.burnable and (target.components.burnable:IsBurning() or target.components.burnable:IsSmoldering()) then
                        target.components.burnable:Extinguish()
                    end
                    -- 群体减免
                    if not table.contains(self.inst.recenttargets2hm, target) then table.insert(self.inst.recenttargets2hm, target) end
                    -- 单体连续减免
                    target.flamethrowerdamagereduce2hm = target.flamethrowerdamagereduce2hm or 0
                    if target.flamethrowerdamagetask2hm then target.flamethrowerdamagetask2hm:Cancel() end
                    target.flamethrowerdamagetask2hm = target:DoTaskInTime(10, cancelflamethrowerdamagetask)
                    local rate = math.max(0.6, 1 - target.flamethrowerdamagereduce2hm * 0.01)
                    if dmg then dmg = dmg * rate end
                    if spdmg then for k, v in pairs(spdmg) do spdmg[k] = v * rate end end
                    target.flamethrowerdamagereduce2hm = target.flamethrowerdamagereduce2hm + #self.inst.recenttargets2hm
                end
                return dmg, spdmg
            end
        end)
    end
end)

-- 影火伤害持续递减,对单每次减少10%
AddPrefabPostInit("willow_shadow_flame", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.weapon then
        inst:DoTaskInTime(0, function()
            local GetDamage = inst.components.weapon.GetDamage
            inst.components.weapon.GetDamage = function(self, attacker, target, ...)
                local dmg, spdmg = GetDamage(self, attacker, target, ...)
                if target and target:IsValid() then
                    -- 单体连续减免
                    target.shadowflamethrowerdamagereduce2hm = target.shadowflamethrowerdamagereduce2hm or 0
                    if target.flamethrowerdamagetask2hm then target.flamethrowerdamagetask2hm:Cancel() end
                    target.flamethrowerdamagetask2hm = target:DoTaskInTime(TUNING.WILLOW_SHADOW_FIRE_COOLDOWN + 10, cancelshadowflamethrowerdamagetask)
                    local rate = math.max(0.6, 1 - target.shadowflamethrowerdamagereduce2hm)
                    if dmg then dmg = dmg * rate end
                    if spdmg then for k, v in pairs(spdmg) do spdmg[k] = v * rate end end
                    target.shadowflamethrowerdamagereduce2hm = target.shadowflamethrowerdamagereduce2hm + 0.1
                end
                return dmg, spdmg
            end
        end)
    end
end)

-- 月/影火不吃伤害倍率加成
AddPrefabPostInit("willow", function(inst)
    if not TheWorld.ismastersim then return end
    inst:DoTaskInTime(2, function()
        if inst.components.combat then
            local oldCalcDamage = inst.components.combat.CalcDamage
            inst.components.combat.CalcDamage = function(self, target, weapon, ...)
                if weapon and (weapon.prefab == "willow_shadow_flame" or weapon.prefab == "flamethrower_fx") then
                    local basedamage, spdamage = weapon.components.weapon:GetDamage(self.inst, target)
                    return basedamage, spdamage
                else
                    return oldCalcDamage(self, target, weapon, ...)
                end
            end
        end
    end)
end)

-- 2025.9.3 melon:蜜蜂33%掉余烬
local willow_ember_common = require("prefabs/willow_ember_common")
local _SpawnEmbersAt = willow_ember_common.SpawnEmbersAt
willow_ember_common.SpawnEmbersAt = function(victim, numembers)
    if victim.prefab == "bee" and math.random() < 0.67 then return end
    return _SpawnEmbersAt(victim, numembers)
end

