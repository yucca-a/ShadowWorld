-- 掉血多掉20%/33%,制作栏掉血除外
local healthrate = GetModConfigData("role_battle") == -1 and 0.2 or 0.33
-- 制作栏掉血会收到血量上限惩罚
local function DeltaPenalty(inst, self, amount) self:DeltaPenalty(amount) end
AddComponentPostInit("health", function(self)
    if not self.inst:HasTag("player") then return end
    local oldDoDelta = self.DoDelta
    self.DoDelta = function(self, amount, overtime, cause, ...)
        -- NaN/∞防御: 拦截上游模组(永不妥协 deathamp 分支等)产生的非有限值, 防止血量损坏崩服
        if type(amount) == "number" and (amount ~= amount or amount == math.huge or amount == -math.huge) then
            return 0
        end
        if amount < 0 and cause == "builder" and not self.disable_penalty then
            self.inst:DoTaskInTime(0, DeltaPenalty, self, -amount / self.maxhealth / 2)
        end
        if (self.inst.prefab ~= "wanda" or (self.inst.components.oldager and self.inst.components.oldager._taking_time_damage)) then
            if amount > 0 then
                amount = amount * (1 - healthrate)
            elseif cause ~= "builder" then
                amount = amount * (1 + healthrate)
            end
        end
        return oldDoDelta(self, amount, overtime, cause, ...)
    end
    -- 继承血量惩罚
    local TransferComponent = self.TransferComponent
    self.TransferComponent = function(self, newinst, ...)
        TransferComponent(self, newinst, ...)
        if self.penalty > 0 then newinst.components.health:SetPenalty(self.penalty) end
    end
    -- 禁用妥协的泛滥日志
    -- local SetPenalty = self.SetPenalty
    -- self.SetPenalty = function(self, penalty, ...)
    --     local print = GLOBAL.print
    --     GLOBAL.print = nilfn
    --     SetPenalty(self, penalty, ...)
    --     GLOBAL.print = print
    -- end
end)
-- 药膏可以回复血量上限
AddComponentPostInit("healer", function(self)
    local Heal = self.Heal
    self.Heal = function(self, target, ...)
        local health = 0
        local healhealth = self.health
        if self.inst.prefab == "brine_balm" then
            healhealth = 40
        elseif self.inst.prefab == "tillweedsalve" then
            healhealth = 20
        end
        if healhealth > 0 and target:HasTag("player") and target.components.health and target.components.health.penalty > 0 then
            -- health = (target.components.health.currenthealth + healhealth - target.components.health:GetMaxWithPenalty()) / 2 -- 原本的满血才能回
            health = healhealth / 2 -- 2025.9.10 melon:不满血也能回
        end
        local result = Heal(self, target, ...)
        if result and health > 0 then target.components.health:DeltaPenalty(-health / 200) end
        return result
    end
end)
-- 2025.5.31 melon:犁地草膏回上限,材料改变-------------------------------------------------------
AddRecipePostInit("tillweedsalve",function(inst)
    inst.ingredients = { -- 3种杂草+木炭
        Ingredient("tillweed", 1), Ingredient("forgetmelots", 1), Ingredient("firenettles", 1), 
        Ingredient("charcoal", 1)
    }
end)
AddPrefabPostInit("tillweedsalve", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.perishable then inst:RemoveComponent("perishable") end -- 去除新鲜度?
    if inst.components.healer then
        local _onhealfn = inst.components.healer.onhealfn
        inst.components.healer.onhealfn = function(inst, target)
            if _onhealfn ~= nil then _onhealfn(inst, target) end
            if target.components.health ~= nil then
                target.components.health:DeltaPenalty(-0.05) -- 回血量5%的上限
            end
        end
    end
end)
-- 强心针需要2个蚊子血囊
AddRecipePostInit("lifeinjector", function(inst) table.insert(inst.ingredients, Ingredient("mosquitosack", 2)) end)
