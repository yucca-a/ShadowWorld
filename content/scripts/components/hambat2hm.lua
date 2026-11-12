-- [火腿棒强化套件] --

-- 肉度 范围 1 - 10
-- (重量)
-- 新鲜度 0 - 100
-- 7200 = PERISH_SLOW
-- 污染度 0 - 100
-- 原版默认满新鲜攻击 59.5 = wilson_attack*1.75

local weightTable = {
    [1.00] = "1_00",
    [1.17] = "1_17",
    [1.31] = "1_31",
    [1.44] = "1_44",
    [1.55] = "1_55",
    [1.65] = "1_65",
    [1.74] = "1_74",
    [1.82] = "1_82",
    [1.90] = "1_90",
    [1.97] = "1_97",
    [2.04] = "2_04",
    [2.11] = "2_11",
    [2.23] = "2_23",
    [2.29] = "2_29",
    [2.35] = "2_35",
    [2.40] = "2_40",
    [2.46] = "2_46",
    [2.50] = "2_50",
}

local function GetWeightName(weight)
    local select_weight = nil
    for k in pairs(weightTable) do
        if not select_weight or math.abs(k - weight) < math.abs(select_weight - weight) then
            select_weight = k
        end
    end
    return "swap_ham_bat_" .. weightTable[select_weight]
end

local function UpdateAttack(perishtime, weight, dirty)
    return (1 - math.pow((1 - perishtime), 1.4)) * math.pow(weight or 0, 0.1005) * (2 - math.pow((dirty or 0) + 1, 0.15)) * TUNING.HAMBAT_DAMAGE
end

local function MoveSpeedReduce(weight)
    local base = math.max(0, weight - 4)
    return math.floor(math.max(0, math.pow(base, 0.105) - 1) * 100) / 100
end

local function AttackDistance(weight)
    return math.floor(math.max(0, math.pow(weight, 0.231) - 1) * 100) / 100
end

local function TransformScale(weight)
    return math.max(1, math.pow(weight + 0, 0.4))
end

local weightedskins = require("hambatweightedskins2hm")

-- Skin geometry uses the same discrete weight scale as the original hand art.
local function UpdateHeldSymbol(self, owner)
    local skin_build = self.inst:GetSkinBuild()
    local name = GetWeightName(TransformScale(self.weight))
    if weightedskins[skin_build] ~= nil then
        owner.AnimState:OverrideItemSkinSymbol("swap_object", weightedskins[skin_build], name, self.inst.GUID, name, name)
    elseif skin_build ~= nil then
        owner.AnimState:OverrideItemSkinSymbol("swap_object", skin_build, "swap_ham_bat", self.inst.GUID, "swap_ham_bat")
    else
        owner.AnimState:OverrideSymbol("swap_object", name, name)
    end
end

local function UpdateDamage(inst, weight, dirty)
    local perishtime = inst.components.perishable and inst.components.perishable:GetPercent() or 0
    inst.components.weapon:SetDamage(UpdateAttack(perishtime, weight, dirty))
end

local function UpdateHover(self)
    local str = {
        (TUNING.isCh2hm and "火腿重量: " or "Hambat Weight: ") .. tostring(math.floor((self.weight or 0) * 10) / 10),
        (TUNING.isCh2hm and "污染程度: " or "Hambat Dirty: ") .. tostring(math.floor((self.dirty or 0) * 100) / 100),
    }
    self.inst.components.hoverer2hm.hoverStr = table.concat(str, "\n")
end

local function onweight(self, weight)
    UpdateHover(self)
    UpdateDamage(self.inst, self.weight, self.dirty)
    local scale = TransformScale(self.weight)
    self.inst.Transform:SetScale(scale, scale, scale)
    if self.inst.components.equippable then
        local speedmult = 1 - (MoveSpeedReduce(self.weight) or 0)
        self.inst.components.equippable.walkspeedmult = speedmult
    end
    if self.inst.components.weapon then
        local attackrange = AttackDistance(self.weight)
        self.inst.components.weapon:SetRange(attackrange)
    end
    if self.inst.components.inventoryitem then
        local owner = self.inst.components.inventoryitem:GetGrandOwner()
        if owner and owner.components.inventory and owner.components.inventory:IsItemEquipped(self.inst) then
            UpdateHeldSymbol(self, owner)
        end
    end
end

local function ondirty(self, dirty)
    UpdateHover(self)
    UpdateDamage(self.inst, self.weight, self.dirty)
end

local hambat2hm = Class(function(self, inst)
    self.inst = inst
    self.weight = 1
    self.dirty = 0

    if inst.components.weapon then
        local oldOnAttack = inst.components.weapon.OnAttack
        inst.components.weapon.OnAttack = function(class, attacker, target, projectile)
            oldOnAttack(class, attacker, target, projectile)
            UpdateDamage(inst, self.weight, self.dirty)
        end
    end

    self.owner = nil

    self.euipFunc = function(inst, data)
        UpdateDamage(inst, self.weight, self.dirty)
        UpdateHeldSymbol(self, data.owner)
        data.owner.AnimState:Show("ARM_carry")
        data.owner.AnimState:Hide("ARM_normal")
    end
    self.inst:ListenForEvent("equipped", self.euipFunc)
    self.unequipFunc = function(inst, data)
        UpdateDamage(inst, self.weight, self.dirty)
        data.owner.AnimState:Hide("ARM_carry")
        data.owner.AnimState:Show("ARM_normal")
    end
    self.inst:ListenForEvent("unequipped", self.unequipFunc)
    self.onDecontructStructure = function(inst, caster)
        if caster then
            local curse = SpawnPrefab("cursed_monkey_token")
            if caster.components.inventory then
                caster.components.inventory:GiveItem(curse)
            else
                curse.Transform:SetPosition(caster.Transform:GetWorldPosition())
            end
        end
    end
    self.inst:ListenForEvent("ondeconstructstructure", self.onDecontructStructure)

    UpdateDamage(inst, self.weight, self.dirty)
end, nil, {
    weight = onweight,
    dirty = ondirty,
})

function hambat2hm:AddMeat(recipe, item)
    local meatValue = recipe.tags.meat
    if self.weight >= TUNING.MAXHAMBATWEIGHT2HM then
        return false
    end
    if self.inst.components.perishable and item.components.perishable then
        local origin_perishable = self.inst.components.perishable:GetPercent() * (math.max(self.weight, 3))
        local new_perishable = item.components.perishable:GetPercent() * meatValue * (1 + 0.05 * meatValue) * (recipe.tags.dried and 1.2 or 1)
        self.inst.components.perishable:SetPercent((origin_perishable + new_perishable) / (self.weight + meatValue))
    end

    local dirtyValue = recipe.tags.monster or 0
    if item.components.perishable then
        if item.components.perishable:IsStale() then
            dirtyValue = dirtyValue + 0.5
        elseif item.components.perishable:IsSpoiled() then
            dirtyValue = dirtyValue + 1
        end
    end

    self.dirty = (self.dirty * self.weight + dirtyValue * meatValue) / (self.weight + meatValue)

    if recipe.tags.dried then
        self.dirty = self.dirty + 0 * meatValue
    elseif recipe.tags.precook then
        self.dirty = self.dirty + 0.1 * meatValue
    else
        self.dirty = self.dirty + 0.2 * meatValue
    end

    self.weight = math.min(TUNING.MAXHAMBATWEIGHT2HM, self.weight + meatValue)
    if item.components.stackable and item.components.stackable.stacksize > 1 then
        item.components.stackable:SetStackSize(item.components.stackable.stacksize - 1)
    else
        item:Remove()
    end
    return true
end

function hambat2hm:Taste(doer)
    if not doer or not doer.components.hunger or not doer.components.sanity or not self.inst.components.perishable then
        return
    end
    if self.weight < 1 then
        return false
    end
    local scale = 1 - (TUNING.food_change_2hm or 0) * 0.1
    if self.inst.components.perishable then
        local foodValue = TUNING.CALORIES_SMALL * scale
        if self.inst.components.perishable:IsStale() then
            foodValue = foodValue * 0.75
        elseif self.inst.components.perishable:IsSpoiled() then
            foodValue = foodValue * 0.5
        end
        doer.components.hunger:DoDelta(foodValue)
        local sanityValue = -TUNING.SANITY_SMALL * (self.dirty - 1) * 0.5
        if sanityValue < 0 then
            if self.inst.components.perishable:IsStale() then
                sanityValue = math.min(sanityValue * 1.5, -2.5)
            elseif self.inst.components.perishable:IsSpoiled() then
                sanityValue = math.min(sanityValue * 1.5, -5)
            end
        else
            if self.inst.components.perishable:IsStale() then
                sanityValue = sanityValue * 0
            elseif self.inst.components.perishable:IsSpoiled() then
                sanityValue = sanityValue * -1
            end
        end
        doer.components.sanity:DoDelta(sanityValue)
    end

    self.weight = math.max(0.5, self.weight - 0.5)
    return true
end

function hambat2hm:OnRemoveFromEntity()
    if self.euipFunc then
        self.inst:RemoveEventCallback("equipped", self.euipFunc)
        self.euipFunc = nil
    end
    if self.unequipFunc then
        self.inst:RemoveEventCallback("unequipped", self.unequipFunc)
        self.unequipFunc = nil
    end
    if self.onDecontructStructure then
        self.inst:RemoveEventCallback("ondeconstructstructure", self.onDecontructStructure)
        self.onDecontructStructure = nil
    end
end

function hambat2hm:OnSave()
    return {
        weight = self.weight,
        dirty = self.dirty,
    }
end

function hambat2hm:OnLoad(data)
    if data then
        self.weight = data.weight or self.weight
        self.dirty = data.dirty or self.dirty
    end
end

return hambat2hm
