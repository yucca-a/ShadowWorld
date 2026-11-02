-- 本模组的诅咒道具增强,防掉落,防拆堆叠
local function ForceOntoOwnerItem(inst, item) if inst.components.cursable and item and item:IsValid() then inst.components.cursable:ForceOntoOwner(item) end end
AddComponentPostInit("inventory", function(self)
    local oldDropItem = self.DropItem
    self.DropItem = function(self, item, ...)
        if type(item) == "table" and item:HasTag("curse2hm") then return end
        return oldDropItem(self, item, ...)
    end
    local oldSetActiveItem = self.SetActiveItem
    self.SetActiveItem = function(self, item, ...)
        if type(item) == "table" and item.components and item.components.curseditem then
            if item.EndCurse2hm then
                if not item.lockowner2hm then item.lockowner2hm = self.inst end
                item:EndCurse2hm()
            elseif item.DoCurse2hm then
                if not item.lockowner2hm then item.lockowner2hm = self.inst end
                item:DoCurse2hm()
            else
                self.inst:DoTaskInTime(0, ForceOntoOwnerItem, item)
            end
            return
        end
        return oldSetActiveItem(self, item, ...)
    end
    local oldSwapEquipment = self.SwapEquipment
    self.SwapEquipment = function(self, other, equipslot_to_swap, ...)
        if other == nil then return false end
        local other_inventory = other.components.inventory
        if other_inventory == nil or other_inventory.equipslots == nil then return false end
        local item = other_inventory:GetEquippedItem(equipslot_to_swap)
        -- IA/其他模组在 equipslot_to_swap 为 nil 时可能返回 boolean false，
        -- 这里必须先判断类型，不能直接对 boolean 取 HasTag。
        if type(item) == "table" and item:HasTag("curse2hm") then return false end
        return oldSwapEquipment(self, other, equipslot_to_swap, ...)
    end
    local GiveItem = self.GiveItem
    self.GiveItem = function(self, item, ...)
        if type(item) == "table" and item:IsValid() and item.Transform then item.Transform:SetPosition(self.inst.Transform:GetWorldPosition()) end
        return GiveItem(self, item, ...)
    end
end)
AddComponentPostInit("curseditem", function(self)
    self.CheckForOwner = function(self, ...)
        if self.cursed_target and
            (not self.inst:HasTag("INLIMBO") or (self.inst.components.inventoryitem.owner and self.inst.components.inventoryitem.owner ~= self.cursed_target)) then
            self.cursed_target.components.cursable:ForceOntoOwner(self.inst)
        end
    end
    local checkplayersinventoryforspace = self.checkplayersinventoryforspace
    self.checkplayersinventoryforspace = function(self, player, ...)
        if not checkplayersinventoryforspace(self, player, ...) then
            local invcmp = player.components.inventory
            local test_item = invcmp:FindItem(function(itemtest)
                return itemtest.EndCurse2hm and itemtest ~= invcmp.activeitem and itemtest.components.inventoryitem.owner == player
            end)
            if test_item then return true end
            return false
        end
        return true
    end
end)
AddPrefabPostInit("cursed_monkey_token", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.inventoryitem then
        inst.components.inventoryitem.keepondeath = true
        inst.components.inventoryitem.keepondrown = true
    end
end)
AddComponentPostInit("cursable", function(self)
    self.Died = nilfn
    local ApplyCurse = self.ApplyCurse
    self.ApplyCurse = function(self, item, curse, ...)
        if not (item and type(item) == "table" and item.IsValid and item:IsValid() and item.components and item.components.curseditem) then return end
        return ApplyCurse(self, item, curse, ...)
    end
    local IsCursable = self.IsCursable
    self.IsCursable = function(self, item, ...)
        if not IsCursable(self, item, ...) then
            if self.inst.components.debuffable and self.inst.components.debuffable:HasDebuff("spawnprotectionbuff") then return false end
            local invcmp = self.inst.components.inventory
            local test_item = invcmp:FindItem(function(itemtest)
                return itemtest.EndCurse2hm and itemtest ~= invcmp.activeitem and itemtest.components.inventoryitem.owner == self.inst
            end)
            if test_item then return true end
            return false
        end
        return true
    end
    local ForceOntoOwner = self.ForceOntoOwner
    self.ForceOntoOwner = function(self, item, ...)
        if self.inst and self.inst:IsValid() and not (self.inst.components.health and self.inst.components.health:IsDead()) and item and item:IsValid() then
            local drop = true
            local inventory = self.inst.components.inventory
            if inventory:IsFull() then
                if item.components.stackable then
                    local test_items = inventory:FindItems(function(itemtest) return itemtest.prefab == item.prefab end) -- and itemtest ~= inventory.activeitem
                    for i, stack in ipairs(test_items) do
                        if stack.components.stackable and not stack.components.stackable:IsFull() then
                            drop = false
                            break
                        end
                    end
                end
                if drop then
                    local test_item = inventory:FindItem(function(itemtest)
                        return not itemtest:HasTag("nosteal") and itemtest ~= inventory.activeitem and itemtest.components.inventoryitem.owner == self.inst
                    end)
                    if not test_item then
                        for j = 1, inventory.maxslots do
                            local item = inventory.itemslots[j]
                            if item and item:IsValid() and not item.components.curseditem and not item.components.inventoryitem.canonlygoinpocket then
                                inventory:DropItem(item)
                                drop = false
                                break
                            end
                        end
                        if drop then
                            if item.EndCurse2hm then
                                if not item.lockowner2hm then item.lockowner2hm = self.inst end
                                item:EndCurse2hm()
                                return
                            else
                                for j = 1, inventory.maxslots do
                                    local item = inventory.itemslots[j]
                                    if item and item.EndCurse2hm then
                                        if not item.lockowner2hm then item.lockowner2hm = self.inst end
                                        item:EndCurse2hm()
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        return ForceOntoOwner(self, item, ...)
    end
end)
AddPlayerPostInit(function(inst)
    if not TheWorld.ismastersim then return end
    TUNING.deathcursedequip2hm = TUNING.deathcursedequip2hm or {}
    local LoadForReroll = inst.LoadForReroll
    inst.LoadForReroll = function(inst, data, ...)
        if data.curses then
            local hasequipcurse
            for curse, num in pairs(data.curses) do
                if table.contains(TUNING.deathcursedequip2hm, curse) then
                    hasequipcurse = true
                    for i = 1, num do
                        local item = SpawnPrefab(curse)
                        inst.components.inventory:GiveItem(item)
                    end
                end
            end
            if hasequipcurse then
                for _, curse in ipairs(TUNING.deathcursedequip2hm) do data.curses[curse] = nil end
                for j = 1, inst.components.inventory.maxslots do
                    local item = inst.components.inventory.itemslots[j]
                    if item and item.components.equippable then inst.components.inventory:Equip(item) end
                end
            end
        end
        LoadForReroll(inst, data, ...)
    end
end)
AddPrefabPostInitAny(function(inst) if inst:HasTag("curse2hm") then MakeUnlimitStackSize(inst) end end)
