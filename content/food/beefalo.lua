STRINGS.CHARACTERS.GENERIC.ACTIONFAIL.USEITEMON.SCARYTOPREY2HM = TUNING.isCh2hm and "它很警惕我" or "It's very vigilant to me."
STRINGS.CHARACTERS.GENERIC.ACTIONFAIL.USEITEMON.MOTHER2HM = TUNING.isCh2hm and "它正在带娃呢" or "It has child."
STRINGS.CHARACTERS.GENERIC.ACTIONFAIL.USEITEMON.STRANGER2HM = TUNING.isCh2hm and "它还不熟悉我" or "It's very unfamiliar to me."
if STRINGS.CHARACTERS then
    for _, data in pairs(STRINGS.CHARACTERS) do
        if data and data.ACTIONFAIL and data.ACTIONFAIL.USEITEMON then
            data.ACTIONFAIL.USEITEMON.SCARYTOPREY2HM = STRINGS.CHARACTERS.GENERIC.ACTIONFAIL.USEITEMON.SCARYTOPREY2HM
            data.ACTIONFAIL.USEITEMON.MOTHER2HM = STRINGS.CHARACTERS.GENERIC.ACTIONFAIL.USEITEMON.MOTHER2HM
            data.ACTIONFAIL.USEITEMON.STRANGER2HM = STRINGS.CHARACTERS.GENERIC.ACTIONFAIL.USEITEMON.STRANGER2HM
        end
    end
end
local function resetonuse(inst)
    if not inst:HasTag("minotaurhorn2hm") and inst.components.useabletargeteditem then
        local onusefn = inst.components.useabletargeteditem.onusefn
        inst.components.useabletargeteditem:SetOnUseFn(function(inst, target, user, ...)
            if target and target:IsValid() and not POPULATING and GetTime() - target.spawntime > FRAMES then
                if target:HasTag("swc2hm") or (target.components.persistent2hm and target.components.persistent2hm.data.supermonster) then
                    return false, "BEEF_BELL_INVALID_TARGET"
                elseif target:HasTag("scarytoprey") then
                    return false, "SCARYTOPREY2HM"
                elseif target.components.leader and target.components.leader:CountFollowers() >= 1 then
                    return false, "MOTHER2HM"
                -- elseif target.components.domesticatable and target.components.domesticatable.obedience < 0.7 then
                --     return false, "STRANGER2HM" -- 2025.10.21 melon:有驯服度要求就不要顺从要求了
                elseif target.components.domesticatable and target.components.domesticatable.domestication < 0.1 then
                    return false, "STRANGER2HM" -- 2025.10.13 melon:驯服度<10%不可绑
                end
            end
            return unpack({onusefn(inst, target, user, ...)})
        end)
    end
end
AddPrefabPostInit("beef_bell", function(inst)
    if not TheWorld.ismastersim then return end
    inst:DoTaskInTime(FRAMES, resetonuse)
end)
-- 2025.10.13 melon:配方不再加橙
-- AddRecipePostInit("beef_bell", function(inst) table.insert(inst.ingredients, Ingredient("orangegem", 1)) end)

local function OnTrade(inst, data)
    local item = data.item
    if item and data.giver and item.components.edible ~= nil and
        (item.components.edible.secondaryfoodtype == FOODTYPE.MONSTER or item.components.edible.healthvalue < 0) and inst.components.combat then
        inst.components.combat:SetTarget(data.giver)
    end
end

AddPrefabPostInit("beefalo", function(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("trade", OnTrade)
    if inst.components.combat and inst.components.combat.min_attack_period > 3 then
        inst.components.combat.min_attack_period = math.max(3, inst.components.combat.min_attack_period * 3 / 4)
    end
end)

local TENDENCY = {ORNERY = "ORNERY", RIDER = "RIDER", PUDGY = "PUDGY"}
local tendencies = {TENDENCY.ORNERY, TENDENCY.RIDER, TENDENCY.PUDGY}
local function setTendency(inst) if inst.SetTendency then inst:SetTendency() end end
AddComponentPostInit("domesticatable", function(self)
    if self.inst and self.tendencies and math.random() < 0.5 then
        self.tendencies[tendencies[math.random(#tendencies)]] = 0.15
        self.inst:DoTaskInTime(0, setTendency)
    end
    local CheckForChanges = self.CheckForChanges
    self.CheckForChanges = function(self, ...)
        local tendencies = self.tendencies
        CheckForChanges(self, ...)
        self.tendencies = tendencies
    end
end)

-- 2025.10.13 melon:绑牛铃的牛只能被空手打到。鬼魂复仇、阿比也不打。
AddPrefabPostInit("beefalo", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.combat ~= nil then
        local _GetAttacked_Internal = inst.components.combat.GetAttacked_Internal
        inst.components.combat.GetAttacked_Internal = function(self, attacker, damage, weapon, stimuli, spdamage, ...)
            -- 有鞍的
            -- if self.inst:HasTag("saddled") or self.inst:HasTag("swc2hm") and self.inst.swp2hm and self.inst.swp2hm:HasTag("saddled") then
            -- 有牛铃的
            if self.inst.components.follower:GetLeader() or self.inst:HasTag("swc2hm") and self.inst.swp2hm and self.inst.swp2hm.components.follower:GetLeader() then
                if attacker and attacker:HasTag("player") and weapon then return end -- 玩家的武器不打 10.4
                -- 鬼魂复仇、阿比不打有鞍牛
                if attacker and (attacker:HasTag("playerghost") or attacker.prefab == "abigail") then return end
            end
            return _GetAttacked_Internal(self, attacker, damage, weapon, stimuli, spdamage, ...)
        end
    end
end)
