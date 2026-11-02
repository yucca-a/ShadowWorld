local sanityrate = GetModConfigData("role_sanity") == -1 and 0.5 or 1
-- 掉血掉理智
local function OnHealthDelta(inst, data)
    if data and data.amount and data.amount < 0 and inst.components.sanity and (inst.prefab ~= "walter" or TUNING.WALTER_SANITY_DAMAGE_RATE == 0) then
        if inst.components.health and inst.prefab ~= "walter" then
            if inst.components.sanity:IsLunacyMode() then
                if inst.components.sanity:GetPercent() > inst.components.health:GetPercent() then return end
            else
                if inst.components.sanity:GetPercent() < inst.components.health:GetPercent() then return end
            end
        end
        if inst.components.health and inst.components.sanity.max < inst.components.health.maxhealth then
            data.amount = data.amount * inst.components.sanity.max / inst.components.health.maxhealth
        end
        inst.components.sanity:DoDelta(data.amount * (inst.components.sanity:IsLunacyMode() and -sanityrate or sanityrate))
    end
end
AddPlayerPostInit(function(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("healthdelta", OnHealthDelta)
end)
-- 食物溢出掉理智
local function processoverflowvalue(inst, overflowvalue)
    -- 兼容沃比
    if inst.components.rider and inst.components.rider:IsRiding() and inst.woby and inst.woby:IsValid() and inst.woby.components.hunger and
        inst.components.rider:GetMount() == inst.woby then
        if (overflowvalue + inst.woby.components.hunger.current) > TUNING.WOBY_BIG_HUNGER and inst.woby.components.rideable then
            inst.woby.components.rideable:Buck()
        end
        inst.woby.components.hunger:DoDelta(overflowvalue, nil, true)
    elseif inst.components.sanity then
        -- 饱食度溢出掉理智
        inst.components.sanity:DoDelta(overflowvalue * (inst.components.sanity:IsLunacyMode() and 0.5 or -0.5))
        if inst.components.talker and not inst.stophungeroverflowspeech2hm then
            inst:DoTaskInTime(0, function()
                local name = STRINGS.NAMES[string.upper(inst.prefab)]
                inst.components.talker:Say(name and (name .. (TUNING.isCh2hm and "吃不下啦~" or " is full!")) or
                                               (TUNING.isCh2hm and "我吃不下啦~" or "I am full!"))
            end)
        end
    end
end
AddComponentPostInit("hunger", function(self)
    if not self.inst:HasTag("player") then return end
    local oldDoDelta = self.DoDelta
    self.DoDelta = function(self, delta, overtime, ignore_invincible, ...)
        if delta > 0 and self.redirect == nil and
            not (not ignore_invincible and self.inst.components.health and self.inst.components.health:IsInvincible() or self.inst.is_teleporting) then
            local overflowvalue = delta + self.current - (self.penalty2hm and self.penalty2hm > 0 and (self.max - self.max * self.penalty2hm) or self.max)
            if overflowvalue > 0 then
                if self.delayoverflow2hm then
                    -- 兼容蜘蛛人和鱼人吃食物增强
                    self.inst:DoTaskInTime(0, function()
                        if self and self.inst then
                            local emptyvalue = (self.penalty2hm and self.penalty2hm > 0 and (self.max - self.max * self.penalty2hm) or self.max) - self.current
                            local newoverflowvalue = overflowvalue - emptyvalue
                            if newoverflowvalue > 0 then processoverflowvalue(self.inst, newoverflowvalue) end
                            if emptyvalue > 0 then oldDoDelta(self, overflowvalue, overtime, ignore_invincible) end
                        end
                    end)
                else
                    processoverflowvalue(self.inst, overflowvalue)
                end
            end
        end
        return oldDoDelta(self, delta, overtime, ignore_invincible, ...)
    end
end)
-- 理智光环不叠加
AddComponentPostInit("sanityaura", function(self)
    local GetAura = self.GetAura
    self.GetAura = function(self, observer, ...)
        local aura_val = GetAura(self, observer, ...) or 0
        if self.inst.prefab and observer and observer.sl2hm and
            (aura_val > 0 or (observer.components.sanity and observer.components.sanity.neg_aura_absorb > 0)) then
            if observer.sl2hm[self.inst.prefab] then
                local val = observer.sl2hm[self.inst.prefab]
                observer.sl2hm[self.inst.prefab] = aura_val < 0 and math.min(aura_val, val) or math.max(aura_val, val)
                return aura_val < 0 and math.min(aura_val - val, 0) or math.max(aura_val - val, 0)
            else
                observer.sl2hm[self.inst.prefab] = aura_val
            end
        end
        return aura_val
    end
end)
local function cancelbuildersanity(inst, self)
    self:RemoveSanityPenalty("builder2hm")
    self.buildersanitytask2hm = nil
    self.builderpenalty2hm = nil
end
AddComponentPostInit("sanity", function(self)
    local Recalc = self.Recalc
    self.Recalc = function(self, ...)
        self.inst.sl2hm = {}
        local res = Recalc(self, ...)
        self.inst.sl2hm = nil
        return res
    end
    -- 制作科技掉理智
    local DoDelta = self.DoDelta
    self.DoDelta = function(self, delta, ...)
        DoDelta(self, delta, ...)
        if delta and delta < 0 and self.inst.sanitybuildertest2hm then
            self.builderpenalty2hm = (self.builderpenalty2hm or 0) - delta / self.max / 2
            self:AddSanityPenalty("builder2hm", self.builderpenalty2hm)
            if self.buildersanitytask2hm then self.buildersanitytask2hm:Cancel() end
            self.buildersanitytask2hm = self.inst:DoTaskInTime(120, cancelbuildersanity, self)
        end
    end
    local OnSave = self.OnSave
    self.OnSave = function(self, ...)
        local data = OnSave(self, ...)
        if self.builderpenalty2hm then data.builderpenalty2hm = self.builderpenalty2hm end
        return data
    end
    local OnLoad = self.OnLoad
    self.OnLoad = function(self, data, ...)
        if self.builderpenalty2hm then
            self:AddSanityPenalty("builder2hm", self.builderpenalty2hm)
            self.buildersanitytask2hm = self.inst:DoTaskInTime(120, cancelbuildersanity, self)
        end
        OnLoad(self, data, ...)
    end
end)
AddComponentPostInit("builder", function(self)
    local RemoveIngredients = self.RemoveIngredients
    self.RemoveIngredients = function(self, ...)
        self.inst.sanitybuildertest2hm = true
        RemoveIngredients(self, ...)
        self.inst.sanitybuildertest2hm = nil
    end
end)
