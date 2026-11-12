local BEEFALO_SIZE_BASE2HM = 1000
local BEEFALO_HERD_RANGE2HM = 20
local BEEFALO_SALTLICK_RANGE2HM = TUNING.SALTLICK_CHECK_DIST or 20
local GROWTH_CHECK_INTERVAL2HM = 10
local randomsizeenabled2hm = GetModConfigData("Random Sized")

local function GetHerdHealthReference2hm(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local herd = TheSim:FindEntities(x, y, z, BEEFALO_HERD_RANGE2HM, {"beefalo"}, {"INLIMBO"})
    local total, count = 0, 0
    for _, beefalo in ipairs(herd) do
        local health = beefalo ~= inst and beefalo.components.health or nil
        if health ~= nil and not beefalo:HasTag("baby") and not health:IsDead() then
            total = total + health.maxhealth
            count = count + 1
        end
    end
    return count > 0 and total / count or BEEFALO_SIZE_BASE2HM
end

local function GetSaltlickGrowthStep2hm(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local saltlicks = TheSim:FindEntities(x, y, z, BEEFALO_SALTLICK_RANGE2HM, {"saltlick"}, {"INLIMBO", "fire", "burnt"})
    local step = 0
    for _, saltlick in ipairs(saltlicks) do
        local uses = saltlick.components.finiteuses
        if uses == nil or uses:GetUses() > 0 then
            if saltlick.prefab == "saltlick_improved" then
                return 20
            elseif saltlick.prefab == "saltlick" then
                step = 10
            end
        end
    end
    return step
end

local function AdvanceBeefaloGrowth2hm(inst)
    local growable = inst.components.growable
    if growable == nil or growable:GetStage() >= #growable.stages then return end
    local step = GetSaltlickGrowthStep2hm(inst)
    if step <= 0 then return end
    if growable.targettime ~= nil then
        local remain = growable.targettime - GetTime() - step
        if remain <= 0 then
            if growable.task ~= nil then
                growable.task:Cancel()
                growable.task = nil
            end
            growable:DoGrowth()
        else
            growable.targettime = GetTime() + remain
            if growable.task ~= nil then
                growable.task:Cancel()
                growable.task = nil
            end
            growable:StartGrowingTask(remain)
        end
    elseif growable.pausedremaining ~= nil then
        growable.pausedremaining = math.max(0, growable.pausedremaining - step)
    end
end

local function GrowBeefaloWithHerdSize2hm(inst)
    local herd = inst.components.herdmember ~= nil and inst.components.herdmember:GetHerd() or nil
    local reference = GetHerdHealthReference2hm(inst)
    local targethealth = math.min(3000, math.max(1, reference * (1 + math.random() * 0.3 - 0.2)))
    local size = targethealth / BEEFALO_SIZE_BASE2HM
    local grown = SpawnPrefab("beefalo")
    if grown == nil then return end
    grown.Transform:SetPosition(inst.Transform:GetWorldPosition())
    grown.Transform:SetRotation(inst.Transform:GetRotation())
    if randomsizeenabled2hm then
        grown.myscale = size
        grown.ray_suijidaxiao = 1
    else
        grown.components.health:SetMaxHealth(math.ceil(targethealth))
        grown.Transform:SetScale(size, size, size)
    end
    grown.sg:GoToState("grow_up_pop")
    inst:Remove()
    if herd ~= nil and herd.components.herd ~= nil and herd:IsValid() then
        herd.components.herd:AddMember(grown)
    end
end

AddPrefabPostInit("babybeefalo", function(inst)
    if not TheWorld.ismastersim or inst.components.growable == nil then return end
    local growable = inst.components.growable
    local stages = {}
    for i, stage in ipairs(growable.stages) do
        stages[i] = {}
        for key, value in pairs(stage) do stages[i][key] = value end
    end
    stages[#stages].fn = GrowBeefaloWithHerdSize2hm
    growable.stages = stages
    inst:DoPeriodicTask(GROWTH_CHECK_INTERVAL2HM, AdvanceBeefaloGrowth2hm)
end)
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

local CombatBenefits = require("combatbenefits2hm")
CombatBenefits.beefaloprotection = true
-- 2025.10.13 melon:绑牛铃的牛只能被空手打到。鬼魂复仇、阿比也不打。
AddPrefabPostInit("beefalo", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.combat ~= nil then
        local _GetAttacked_Internal = inst.components.combat.GetAttacked_Internal
        inst.components.combat.GetAttacked_Internal = function(self, attacker, damage, weapon, stimuli, spdamage, ...)
            -- 有鞍的
            -- if self.inst:HasTag("saddled") or self.inst:HasTag("swc2hm") and self.inst.swp2hm and self.inst.swp2hm:HasTag("saddled") then
            -- 有牛铃的
            if CombatBenefits.IsBellBoundBeefalo(self.inst) then
                if attacker and attacker:HasTag("player") and weapon then return end -- 玩家的武器不打 10.4
                -- 鬼魂复仇、阿比不打有鞍牛
                if attacker and (attacker:HasTag("playerghost") or attacker.prefab == "abigail") then return end
            end
            return _GetAttacked_Internal(self, attacker, damage, weapon, stimuli, spdamage, ...)
        end
    end
end)
