local Report = function(self, inRemove)
    -- print(" do Report " .. tostring(self.original) .. " " .. tostring(self.superparent) .. " " .. tostring(self.superhat))
    if self.original and self.superparent and self.superparent:IsValid() then
        if self.superhat and self.superhat:IsValid() then
            if self.superhat.components.finiteuses then
                local value = 0
                if self.inst and self.inst:IsValid() and self.inst.components.finiteuses then
                    value = self.inst.components.finiteuses.current
                end
                if value < self.original then
                    local delta = (self.original - value) * TUNING.HatReduceRate.finiteuses
                    if false then -- self.superhat.components.finiteuses.current then
                        self.superhat.components.finiteuses:SetUses(0.01)
                        self.original = 0.01
                        if self.superparent.components.inventory then
                            local slot = self.superparent.components.inventory:IsItemEquipped(self.superhat)
                            if slot then
                                self.superparent.components.inventory:GiveItem(self.superparent.components.inventory:Unequip(slot))
                            end
                        end
                        --     self.superparent.components.inventory:GiveItem(self.superhat)
                        --     -- print("掉落帽子")
                        -- end
                    else
                        self.superhat.components.finiteuses:Use(delta)
                        if self.inst and self.inst:IsValid() and self.inst.components.finiteuses then
                            self.inst.components.finiteuses:SetUses(self.superhat.components.finiteuses.current)
                            self.original = self.inst.components.finiteuses.current
                        end
                        -- print("消耗 " .. delta)
                        return
                    end
                else
                    if self.inst and self.inst:IsValid() and self.inst.components.finiteuses then
                        self.inst.components.finiteuses:SetUses(self.superhat.components.finiteuses.current)
                        self.original = self.inst.components.finiteuses.current
                    end
                    return
                end
            elseif self.superhat.components.armor then
                local value = 0
                if self.inst and self.inst:IsValid() and self.inst.components.armor then
                    value = self.inst.components.armor.condition
                end
                -- print(value .. " " .. self.original)
                if value < self.original then
                    local delta = (self.original - value) * TUNING.HatReduceRate.armor
                    -- print("delta " .. tostring(delta) .. " " .. self.superhat.components.armor.condition)
                    -- 检查是否为临时护甲（使用新鲜度系统）
                    if self.superhat.components.tempequip2hm and self.superhat.components.perishable then
                        -- 临时护甲：消耗新鲜度而不是耐久
                        local freshness_delta = delta / self.superhat.components.armor.maxcondition
                        local current_percent = self.superhat.components.perishable:GetPercent()
                        
                        if current_percent - freshness_delta < TUNING.HatTrickDropRate then
                            -- 新鲜度过低，卸下帽子
                            self.superhat.components.perishable:SetPercent(math.max(current_percent - freshness_delta, 0.01))
                            self.original = self.inst.components.armor.condition
                            if self.superparent.components.inventory then
                                local slot = self.superparent.components.inventory:IsItemEquipped(self.superhat)
                                if slot then
                                    self.superparent.components.inventory:GiveItem(self.superparent.components.inventory:Unequip(slot))
                                    if self.superparent.components.talker then
                                        self.superparent.components.talker:Say((TUNING.isCh2hm and "我的帽子被戏法变没了" or "hat trick drop my hat"))
                                    end
                                end
                            end
                            -- print("掉落临时护甲帽子")
                        else
                            -- 消耗新鲜度
                            self.superhat.components.perishable:ReducePercent(freshness_delta)
                            if self.inst and self.inst:IsValid() and self.inst.components.armor then
                                self.inst.components.armor:SetCondition(self.inst.components.armor.maxcondition)
                                self.original = self.inst.components.armor.condition
                            end
                            -- print("消耗临时护甲新鲜度 " .. delta)
                            return
                        end
                    else
                        -- 原版护甲：使用原有耐久系统
                        if self.superhat.components.armor.condition - delta < self.superhat.components.armor.maxcondition * TUNING.HatTrickDropRate then
                            self.superhat.components.armor:SetCondition(math.max(self.superhat.components.armor.condition - delta, 1))
                            self.original = self.inst.components.armor.condition
                            if self.superparent.components.inventory then
                                local slot = self.superparent.components.inventory:IsItemEquipped(self.superhat)
                                if slot then
                                    self.superparent.components.inventory:GiveItem(self.superparent.components.inventory:Unequip(slot))
                                    if self.superparent.components.talker then
                                        self.superparent.components.talker:Say((TUNING.isCh2hm and "我的帽子被戏法变没了" or "hat trick drop my hat"))
                                    end
                                end
                            end
                                -- print("掉落帽子")
                        else
                            self.superhat.components.armor:SetCondition(self.superhat.components.armor.condition - delta)
                            if self.inst and self.inst:IsValid() and self.inst.components.armor then
                                self.inst.components.armor:SetCondition(self.inst.components.armor.maxcondition)
                                self.original = self.inst.components.armor.condition
                            end
                            -- print("消耗 " .. delta)
                            return
                        end
                    end
                else
                    if self.inst and self.inst:IsValid() and self.inst.components.armor then
                        self.inst.components.armor:SetCondition(self.inst.components.armor.maxcondition)
                        self.original = self.inst.components.armor.condition
                    end
                    return
                end
            elseif self.superhat.components.fueled then
                local value = 0
                if self.inst and self.inst:IsValid() and self.inst.components.fueled then
                    value = self.inst.components.fueled.currentfuel
                end
                if value < self.original then
                    local delta = (self.original - value) * TUNING.HatReduceRate.fueled
                    if false then -- self.superhat.components.fueled.currentfuel then
                        self.superhat.components.fueled:DoDelta(0.01 - self.superhat.components.fueled.currentfuel)
                        self.original = 0.01
                        if self.superparent.components.inventory then
                            local slot = self.superparent.components.inventory:IsItemEquipped(self.superhat)
                            if slot then
                                self.superparent.components.inventory:GiveItem(self.superparent.components.inventory:Unequip(slot))
                            end
                        end
                    else
                        self.superhat.components.fueled:DoDelta(-delta)
                        if self.inst and self.inst:IsValid() and self.inst.components.fueled then
                            self.inst.components.fueled:DoDelta(self.superhat.components.fueled.currentfuel - value)
                            self.original = self.inst.components.fueled.currentfuel
                        end
                        -- print("消耗 " .. delta)
                        return
                    end
                else
                    if self.inst and self.inst:IsValid() and self.inst.components.fueled then
                        self.inst.components.fueled:DoDelta(self.superhat.components.fueled.currentfuel - value)
                        self.original = self.inst.components.fueled.currentfuel
                    end
                    return
                end
            elseif self.superhat.components.perishable then
                local value = 0
                if self.inst and self.inst:IsValid() and self.inst.components.perishable then
                    value = self.inst.components.perishable.perishremainingtime
                end
                if value < self.original then
                    local delta = (self.original - value) * (value > 0 and TUNING.HatReduceRate.perishable or 1)
                    if false then -- self.superhat.components.perishable.perishremainingtime then
                        self.superhat.components.perishable:AddTime(0.01 - self.superhat.components.perishable.perishremainingtime)
                        self.original = 0.01
                        if self.superparent.components.inventory then
                            local slot = self.superparent.components.inventory:IsItemEquipped(self.superhat)
                            if slot then
                                self.superparent.components.inventory:GiveItem(self.superparent.components.inventory:Unequip(slot))
                            end
                        end
                    else
                        self.superhat.components.perishable:AddTime(-delta)
                        if self.inst and self.inst:IsValid() and self.inst.components.perishable then
                            self.inst.components.perishable:AddTime(self.superhat.components.perishable.perishremainingtime - value)
                            self.original = self.inst.components.perishable.perishremainingtime
                        end
                        -- print("消耗 " .. delta)
                        return
                    end
                else
                    if self.inst and self.inst:IsValid() and self.inst.components.perishable then
                        self.inst.components.perishable:AddTime(self.superhat.components.perishable.perishremainingtime - value)
                        self.original = self.inst.components.perishable.perishremainingtime
                    end
                    return
                end
            end
        end
        if not inRemove then
            self.inst:DoTaskInTime(0, function()
                self.original = nil
                self.inst:Remove()
            end)
            -- print("移除 2")
        end
    end
end

local Check = function(self)
    if self.owner and self.owner:IsValid() then
        if self.owner.components.inventory then
            if self.owner.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD) == self.inst then
                return
            end
        end
    end
    self.inst:DoTaskInTime(0, function()
        Report(self)
        self.original = nil
        self.inst:Remove()
    end)
    -- print("移除 1")
end

local Record = function(self)
    if self.superhat and self.superhat:IsValid() then
        if self.inst.components.finiteuses and self.superhat.components.finiteuses then
            self.inst.components.finiteuses:SetUses(self.superhat.components.finiteuses.current)
            self.original = self.inst.components.finiteuses.current
        elseif self.inst.components.armor and self.superhat.components.armor then
            self.inst.components.armor:SetCondition(self.superhat.components.armor.maxcondition)
            self.original = self.inst.components.armor.condition
            local armor = self.inst.components.armor
            local nofreeze = TUNING.NoFreezePercent
            local nofireandscare = TUNING.NoFireAndScarePercent
            -- 妥测护甲重制将原 80%/90% 档映射为 65%/75%，仅同步戏法免疫门槛。
            -- 检查实际组件标记，避免单开、正式版或关闭护甲重制时误降门槛。
            if TUNING.DSTU and armor.umabsorbremap ~= nil and type(armor.UMOverrideAbsorption) == "function" then
                nofreeze = math.min(nofreeze, 0.65)
                nofireandscare = math.min(nofireandscare, 0.75)
            end
            -- print("穿戴护甲 " .. tostring(self.inst.components.armor.absorb_percent))
            -- print(TUNING.NoFreezePercent)
            -- print(TUNING.NoFireAndScarePercent)
            if armor.absorb_percent and armor.absorb_percent >= nofreeze then
                -- print(tostring(self.owner.components.freezable))
                -- print(tostring(self.owner.components.sleeper))
                if self.owner.components.freezable then
                    -- print("激活免疫冻结 " .. tostring(self.owner))
                    if not self.owner.components.freezable.setFreeze2hm then
                        self.owner.components.freezable.setFreeze2hm = true
                        local oldFreeze = self.owner.components.freezable.Freeze
                        self.owner.components.freezable.Freeze = function(self, freezetime)
                            -- print("Freeze " .. tostring(self.inst.components.freezable.setFreeze2hm_set))
                            if self.inst.components.freezable.setFreeze2hm_set then
                                return
                            else
                                return oldFreeze(self, freezetime)
                            end
                        end
                    end
                    self.owner.components.freezable.setFreeze2hm_set = true
                end
                if self.owner.components.sleeper then
                    if not self.owner.components.sleeper.setGoToSleep2hm then
                        -- print("激活免疫睡眠 " .. tostring(self.owner))
                        self.owner.components.sleeper.setGoToSleep2hm = true
                        local oldGoToSleep = self.owner.components.sleeper.GoToSleep
                        self.owner.components.sleeper.GoToSleep = function(self, sleeptime)
                            -- print("GoToSleep " .. tostring(self.inst.components.sleeper.setGoToSleep2hm_set))
                            if self.inst.components.sleeper.setGoToSleep2hm_set then
                                return
                            else
                                return oldGoToSleep(self, sleeptime)
                            end
                        end
                    end
                    self.owner.components.sleeper.setGoToSleep2hm_set = true
                end
            end
            if armor.absorb_percent and armor.absorb_percent >= nofireandscare then
                self.owner:AddTag("noscare2hm")
                if self.owner.components.health then
                    if not self.owner.components.health.setDoFireDamage2hm then
                        -- print("激活免疫火焰 " .. tostring(self.owner))
                        self.owner.components.health.setDoFireDamage2hm = true
                        local oldDoFireDamage = self.owner.components.health.DoFireDamage
                        self.owner.components.health.DoFireDamage = function(self, amount, doer, instant)
                            -- print("DoFireDamage " .. tostring(self.inst.components.health.setDoFireDamage2hm_set))
                            if self.inst.components.health.setDoFireDamage2hm_set then
                                return
                            else
                                return oldDoFireDamage(self, amount, doer, instant)
                            end
                        end
                    end
                    self.owner.components.health.setDoFireDamage2hm_set = true
                end
            end
        elseif self.inst.components.fueled and self.superhat.components.fueled then
            self.inst.components.fueled:DoDelta(self.superhat.components.fueled.currentfuel - self.inst.components.fueled.currentfuel)
            self.original = self.inst.components.fueled.currentfuel
        elseif self.inst.components.perishable and self.superhat.components.perishable then
            self.inst.components.perishable:AddTime(self.superhat.components.perishable.perishremainingtime - self.inst.components.perishable.perishremainingtime)
            self.original = self.inst.components.perishable.perishremainingtime
        end
        -- print("记录数值 " .. tostring(self.original))
    else
        self.inst:DoTaskInTime(0, function()
            Report(self)
            self.original = nil
            self.inst:Remove()
        end)
        -- print("移除 3")
    end
end

local removeleaveinventory2hm = Class(function(self, inst)
    self.inst = inst

    self.inst:ListenForEvent("onremove", function(inst)
        self:OnRemoveFromEntity()
    end)
end)

function removeleaveinventory2hm:OnRemoveFromEntity()
    -- print("OnRemoveFromEntity")
    if self.owner and self.owner:IsValid() then
        if self.owner.components.freezable then
            self.owner.components.freezable.setFreeze2hm_set = false
        end
        if self.owner.components.sleeper then
            self.owner.components.sleeper.setGoToSleep2hm_set = false
        end
        self.owner:RemoveTag("noscare2hm")
        if self.owner.components.health then
            self.owner.components.health.setDoFireDamage2hm_set = false
        end
    end
    if self.OnUnequip and self.owner and self.owner:IsValid() then
        self.inst:RemoveEventCallback("unequip", self.OnUnequip, self.owner)
        self.OnUnequip = nil
    end
    Report(self, true)
end

function removeleaveinventory2hm:SetOwner(inst, superparent, superhat)
    -- print(tostring(self.inst) .. " 帽子属于 " .. tostring(inst))
    self.owner = inst
    self.superparent = superparent
    self.superhat = superhat
    -- {item=item, eslot=equipslot, slip=slip}
    self.OnUnequip = function(inst, data)
        -- print("OnUnequip " .. tostring(inst))
        if data.eslot == EQUIPSLOTS.HEAD then
            -- print("触发 换装备")
            Check(self)
        end
    end
    Record(self)
    self.inst:DoPeriodicTask(0.5, function(inst)
        Report(self)
    end)
    self.inst:ListenForEvent("unequip", self.OnUnequip, inst)
    Check(self)
end

return removeleaveinventory2hm