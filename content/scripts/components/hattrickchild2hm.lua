local RemoveHat = function(self)
    if self.my_hat and self.my_hat:IsValid() then
        if self.watch_hat_func then
            self.inst:RemoveEventCallback("onremove", self.watch_hat_func, self.my_hat)
            self.watch_hat_func = nil
        end
        -- print(tostring(self.inst) .. " 拿掉帽子 " .. tostring(self.my_hat))
        self.my_hat:Remove()
        self.my_hat = nil
    end
end

local CopyHat = nil
CopyHat = function(self, hat)
    if (not self.inst.components.health or not self.inst.components.health:IsDead()) and self.inst.components.inventory and hat and hat:IsValid() then
        local myhat = self.inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
        if myhat then return end
        self.my_hat = SpawnPrefab(hat.prefab, hat.skinname, hat.skin_id)
        self.watch_hat_func = function(hat)
            if self and self.watch_hat_func and self.my_hat and self.my_hat:IsValid() then
            else
                return
            end
            -- print(tostring(hat) .. " " .. tostring(self) .. " " .. tostring(self.watch_hat_func) .. " " .. tostring(self.my_hat))
            self.inst:RemoveEventCallback("onremove", self.watch_hat_func, self.my_hat)
            self.watch_hat_func = nil
            -- print("检查到帽子没了")
            self.inst:DoTaskInTime(0, function(inst)
                if self.parent and self.parent:IsValid() and self.parent.components.inventory then
                    local his_hat = self.parent.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
                    if his_hat then
                        -- print("但是主人有帽子，所以装备一个")
                        CopyHat(self, his_hat)
                    end
                end
            end)
        end
        self.inst:ListenForEvent("onremove", self.watch_hat_func, self.my_hat)
        -- print("listforfunc " .. " " .. tostring(self) .. " " .. tostring(self.watch_hat_func) .. " " .. tostring(self.my_hat))
        -- print(tostring(self.inst) .. " 装备帽子 " .. tostring(self.my_hat))
        self.inst.components.inventory:Equip(self.my_hat)
        local removeleaveinventory2hm = self.my_hat:AddComponent("removeleaveinventory2hm")
        self.my_hat.persists = false
        removeleaveinventory2hm:SetOwner(self.inst, self.parent, hat)
    end
end

local OnHattrickEquip = function(self, hat)
    CopyHat(self, hat)
end

local OnHattrickUnequip = function(self, hat)
    RemoveHat(self)
end

local AddListener = function(self)
    if self.addedListener then return end
    self.addedListener = self.parent
    self.OnParentRemove = function(inst)
        self.inst:RemoveComponent("hattrickchild2hm")
    end
    self.inst:ListenForEvent("onremove", self.OnParentRemove, self.addedListener)
    self.OnHattrickEquip = function(inst, data)
        OnHattrickEquip(self, data.hat)
    end
    self.inst:ListenForEvent("hattrick_equip", self.OnHattrickEquip, self.addedListener)
    self.OnHattrickUnequip = function(inst, data)
        OnHattrickUnequip(self, data.hat)
    end
    self.inst:ListenForEvent("hattrick_unequip", self.OnHattrickUnequip, self.addedListener)
end

local RemoveListener = function(self)
    if not self.addedListener then return end
    self.inst:RemoveEventCallback("onremove", self.OnParentRemove, self.addedListener)
    self.OnParentRemove = nil
    self.inst:RemoveEventCallback("hattrick_equip", self.OnHattrickEquip, self.addedListener)
    self.OnHattrickEquip = nil
    self.inst:RemoveEventCallback("hattrick_unequip", self.OnHattrickUnequip, self.addedListener)
    self.OnHattrickUnequip = nil
    self.addedListener = nil
end

local hattrickchild2hm = Class(function(self, inst)
    self.inst = inst
    self.parent = nil

    self.my_hat = nil
end)

function hattrickchild2hm:SetParent(parent, inithat)
    if self.parent then
        RemoveListener(self)
    end
    self.parent = parent
    if self.parent then
        AddListener(self)
        if inithat then
            CopyHat(self, inithat)
        end
    else
        self.inst:RemoveComponent("hattrickchild2hm")
    end
end

function hattrickchild2hm:OnRemoveFromEntity()
    self.parent = nil
    RemoveListener(self)
    RemoveHat(self)
end

return hattrickchild2hm