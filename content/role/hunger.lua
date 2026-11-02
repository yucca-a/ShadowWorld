AddRecipePostInit("lifeinjector", function(inst) table.insert(inst.ingredients, Ingredient("froglegs", 1)) end)
AddComponentPostInit("maxhealer", function(self)
    local Heal = self.Heal
    self.Heal = function(self, target, ...)
        local hungerp = target and target.components.hunger and target.components.hunger.penalty2hm or 0
        local healthp = target and target.components.health and target.components.health.penalty or 0
        if hungerp == 0 and healthp == 0 then return false end
        local healamount = self.healamount
        if hungerp < 0.25 then self.healamount = healamount - 0.25 + hungerp end
        local result = Heal(self, target, ...)
        if result and target:HasTag("player") and target.components.hunger and target.components.hunger.penalty2hm and target.components.hunger.penalty2hm > 0 then
            if healthp < 0.25 then
                self.healamount = healamount - 0.25 + healthp
            else
                self.healamount = healamount
            end
            target.components.hunger:DeltaPenalty2hm(self.healamount)
        end
        self.healamount = healamount
        return result
    end
end)
AddPrefabPostInit("pocketwatch_heal", function(inst)
    if inst.components.pocketwatch then
        local cast = inst.components.pocketwatch.DoCastSpell
        inst.components.pocketwatch.DoCastSpell = function(inst, doer, ...)
            local result = cast(inst, doer, ...)
            if result and doer and doer:IsValid() and doer.components.hunger and doer.components.hunger.penalty2hm and doer.components.hunger.penalty2hm > 0 then
                doer.components.hunger:DeltaPenalty2hm(-TUNING.POCKETWATCH_HEAL_HEALING / doer.components.hunger.max / 4)
                return true
            end
            return result
        end
    end
end)
-- 2025.7.12 melon:改为靠maxhealer组件回饥饿上限，并且不开妥协也回饥饿上限。
AddPrefabPostInit("lifeinjector", function(inst)
    if not TheWorld.ismastersim or not inst.components.maxhealer then return end
    local _Heal = inst.components.maxhealer.Heal
    inst.components.maxhealer.Heal = function(self, target)
        local ifhealmaxhealth = _Heal(self, target)
        local ifhealmaxhunger = false
        if target and target:IsValid() and target:HasTag("player") and target.components.hunger and target.components.hunger.penalty2hm and target.components.hunger.penalty2hm > 0 then
            local healthp = target and target.components.health and target.components.health.penalty or 0
            target.components.hunger:DeltaPenalty2hm(TUNING.MAX_HEALING_NORMAL - (healthp < 0.25 and (0.25 - healthp) or 0))
            ifhealmaxhunger = true
            if not ifhealmaxhealth then -- _Heal没扣数量,就扣1个
                if self.inst.components.stackable ~= nil and self.inst.components.stackable:IsStack() then
                    self.inst.components.stackable:Get():Remove()
                else
                    self.inst:Remove()
                end
            end
        end
        return ifhealmaxhunger or ifhealmaxhealth
    end
end)
local driedfood = {"kelp_dried", "smallfishmeat_dried", "smallmeat_dried", "fishmeat_dried", "meat_dried"}
local function OnEat(inst, data)
    if inst.components.hunger and inst.components.hunger.penalty2hm and inst.components.hunger.penalty2hm > 0 and inst.components.eater and data and data.food and
        (data.food:HasTag("fresh") or data.food.dryseeds2hm or data.food.dryveggies2hm) and data.food.components.edible and
        data.food.components.edible.healthvalue and data.food.components.edible.healthvalue > 0 then
        inst.cantusesinginginspiration = true
        local health_delta = data.food.components.edible:GetHealth(inst)
        if inst.components.eater.custom_stats_mod_fn ~= nil then
            health_delta = inst.components.eater.custom_stats_mod_fn(inst, health_delta, data.food.components.edible.hungervalue,
                                                                     data.food.components.edible.sanityvalue, data.food, data.feeder)
        end
        inst.cantusesinginginspiration = nil
        local value = 0
        if data.food.dryveggies2hm or data.food.dryseeds2hm then
            value = -health_delta / 300
        elseif table.contains(driedfood, data.food.prefab) then
            if data.food.components.edible.foodtype == FOODTYPE.MEAT then
                value = -health_delta / 300
            else
                value = -health_delta / 75
            end
        else
            value = -health_delta / 1500
        end
        inst.components.hunger:DeltaPenalty2hm(value)
    end
end
local function addhungerpenalty(inst) inst.components.hunger:DeltaPenalty2hm(0.01) end
local function onstopstarving(inst)
    if inst.hungerpenalty2hmtask then
        inst.hungerpenalty2hmtask:Cancel()
        inst.hungerpenalty2hmtask = nil
    end
end
local function onstartstarving(inst)
    if inst.components.hunger and inst.components.hunger.penalty2hm and not inst.hungerpenalty2hmtask then
        inst.components.hunger:DeltaPenalty2hm(0.01)
        inst.hungerpenalty2hmtask = inst:DoPeriodicTask(8, addhungerpenalty)
    end
end
local function ondeath(inst, data)
    onstopstarving(inst)
    if inst.components.hunger and inst.components.hunger.penalty2hm then
        local v = 0.15
        if data and data.cause == "hunger" or inst.components.hunger.current == 0 then v = v + 0.1 end
        inst.components.hunger:DeltaPenalty2hm(v)
    end
end
AddPrefabPostInit("player_classified", function(inst) inst.hungerpenalty2hm = net_byte(inst.GUID, "hunger.penalty2hm", "hungerdirty") end)
AddPlayerPostInit(function(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("oneat", OnEat)
    inst:ListenForEvent("startstarving", onstartstarving)
    inst:ListenForEvent("stopstarving", onstopstarving)
    inst:ListenForEvent("death", ondeath)
end)
local function SetHungerPenalty(self, penalty)
    if not self.disable_penalty and self.penalty2hm then
        self.penalty2hm = math.clamp(penalty, 0, TUNING.MAXIMUM_HEALTH_PENALTY)
        if self.inst.player_classified and self.inst.player_classified and self.inst.player_classified.hungerpenalty2hm then
            self.inst.player_classified.hungerpenalty2hm:set(math.floor(self.penalty2hm * 200 + .5))
        end
        local max2hm = self.max - self.max * self.penalty2hm
        if self.current > max2hm and self.current > 0 then self.current = max2hm end
        self:DoDelta(0)
    end
end
local function DeltaHungerPenalty(self, delta) if not self.disable_penalty and self.penalty2hm then self:SetPenalty2hm(self.penalty2hm + delta) end end
AddComponentPostInit("hunger", function(self)
    if not self.inst:HasTag("player") then return end
    self.penalty2hm = 0
    if self.penalty and (self.SetPenalty or self.DeltaPenalty) then
        self.SetPenalty2hm = self.SetPenalty or self.DeltaPenalty
        self.DeltaPenalty2hm = self.DeltaPenalty or self.SetPenalty
        return
    end
    self.SetPenalty2hm = SetHungerPenalty
    self.DeltaPenalty2hm = DeltaHungerPenalty
    local OnSave = self.OnSave
    self.OnSave = function(self, ...)
        local data = OnSave(self, ...)
        if data == nil then data = {} end
        data.penalty2hm = self.penalty2hm
        return data
    end
    local OnLoad = self.OnLoad
    self.OnLoad = function(self, data, ...)
        local haspenalty = data.penalty2hm ~= nil and data.penalty2hm > 0 and data.penalty2hm < 1
        if haspenalty and self.SetPenalty2hm then self:SetPenalty2hm(data.penalty2hm) end
        return OnLoad(self, data, ...)
    end
    local TransferComponent = self.TransferComponent
    self.TransferComponent = function(self, newinst, ...)
        TransferComponent(self, newinst, ...)
        if self.penalty2hm > 0 then newinst.components.hunger.penalty2hm = self.penalty2hm end
    end
    local oldDoDelta = self.DoDelta
    self.DoDelta = function(self, delta, overtime, ignore_invincible, ...)
        if self.penalty2hm > 0 and self.redirect == nil and
            not (not ignore_invincible and self.inst.components.health and self.inst.components.health:IsInvincible() or self.inst.is_teleporting) then
            local max2hm = self.max - self.max * self.penalty2hm
            local mathclamp = math.clamp
            math.clamp = function(v, min, max, ...)
                if max == self.max then max = max2hm end
                local res = mathclamp(v, min, max, ...)
                math.clamp = mathclamp
                return res
            end
        end
        return oldDoDelta(self, delta, overtime, ignore_invincible, ...)
    end
end)
AddClassPostConstruct("widgets/statusdisplays", function(self)
    local SetHungerPercent = self.SetHungerPercent
    self.SetHungerPercent = function(self, pct, ...)
        if self.owner.components.hunger then
            self.stomach.penalty2hm = self.owner.components.hunger.penalty2hm
        elseif self.owner.player_classified and self.owner.player_classified.hungerpenalty2hm then
            self.stomach.penalty2hm = self.owner.player_classified.hungerpenalty2hm:value() / 200
        else
            self.stomach.penalty2hm = 0
        end
        if SetHungerPercent then SetHungerPercent(self, pct, ...) end
        if self.stomach.SetPercent2hm then self.stomach:SetPercent2hm(self.stomach.penalty2hm) end
    end
end)
local function processmaxnumshow(self)
    if self.CombinedStatusUpdateNumbers then
        local CombinedStatusUpdateNumbers = self.CombinedStatusUpdateNumbers
        self.CombinedStatusUpdateNumbers = function(self, max, ...)
            CombinedStatusUpdateNumbers(self, max, ...)
            if self.active and self.maxnum and self.penalty2hm and self.penalty2hm > 0 then
                self.maxval2hm = max or self.maxval2hm
                self.maxnum:SetString(tostring(math.ceil((1 - self.penalty2hm) * self.maxval2hm)) .. "<" .. tostring(math.ceil(self.maxval2hm)))
            end
        end
    end
end
local UIAnim = require "widgets/uianim"
AddClassPostConstruct("widgets/hungerbadge", function(self)
    if self.topperanim then return end
    self.topperanim2hm = self.underNumber:AddChild(UIAnim())
    self.topperanim2hm:GetAnimState():SetBank("status_meter")
    self.topperanim2hm:GetAnimState():SetBuild("status_meter")
    self.topperanim2hm:GetAnimState():PlayAnimation("anim")
    self.topperanim2hm:GetAnimState():AnimateWhilePaused(false)
    self.topperanim2hm:GetAnimState():SetMultColour(0, 0, 0, 1)
    self.topperanim2hm:SetScale(1, -1, 1)
    self.topperanim2hm:SetClickable(false)
    self.topperanim2hm:GetAnimState():SetPercent("anim", 1)
    self.SetPercent2hm = function(self, penaltypercent)
        if self.topperanim2hm then self.topperanim2hm:GetAnimState():SetPercent("anim", 1 - (penaltypercent or 0)) end
    end
    local SetPercent = self.SetPercent
    self.SetPercent = function(self, val, max, ...)
        self.maxval2hm = max or self.maxval2hm or 150
        SetPercent(self, val, max, ...)
        if not self.CombinedStatusUpdateNumbers and self.num and self.penalty2hm and self.penalty2hm > 0 then
            local str = self.num:GetString()
            self.num:SetString(str .. "/" .. tostring(math.ceil((1 - self.penalty2hm) * self.maxval2hm)))
        end
    end
    processmaxnumshow(self)
end)
AddClassPostConstruct("widgets/healthbadge", function(self)
    local SetPercent = self.SetPercent
    self.SetPercent = function(self, val, max, penaltypercent, ...)
        self.penalty2hm = penaltypercent or self.penalty2hm or 0
        self.maxval2hm = max or self.maxval2hm or 150
        SetPercent(self, val, max, penaltypercent, ...)
        if not self.CombinedStatusUpdateNumbers and self.num and self.penalty2hm and self.penalty2hm > 0 then
            local str = self.num:GetString()
            self.num:SetString(str .. "/" .. tostring(math.ceil((1 - self.penalty2hm) * self.maxval2hm)))
        end
    end
    processmaxnumshow(self)
end)
AddClassPostConstruct("widgets/sanitybadge", function(self)
    local SetPercent = self.SetPercent
    self.SetPercent = function(self, val, max, penaltypercent, ...)
        self.maxval2hm = max or self.maxval2hm or 200
        self.penalty2hm = penaltypercent or self.penalty2hm or 0
        SetPercent(self, val, max, penaltypercent, ...)
        if not self.CombinedStatusUpdateNumbers and self.num and self.penalty2hm and self.penalty2hm > 0 then
            local str = self.num:GetString()
            self.num:SetString(str .. "/" .. tostring(math.ceil((1 - self.penalty2hm) * self.maxval2hm)))
        end
    end
    processmaxnumshow(self)
end)
