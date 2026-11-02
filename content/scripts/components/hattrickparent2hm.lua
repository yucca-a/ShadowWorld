local EquipHat = function(inst, hat)
    -- print(tostring(inst) .. " 装备帽子 " .. tostring(hat))
    inst:PushEvent("hattrick_equip", {hat = hat})
end

local UnequipHat = function(inst, hat)
    -- print(tostring(inst) .. " 拿掉帽子 " .. tostring(hat))
    inst:PushEvent("hattrick_unequip", {hat = hat})
end

local RemoveHat = function(inst, hat)
    if inst and inst:IsValid() and hat and hat:IsValid() then
        local slot = inst.components.inventory:IsItemEquipped(hat)
        if slot then
            inst.components.inventory:GiveItem(inst.components.inventory:Unequip(slot))
        end
    end
end

-- { item = item, eslot = eslot, no_animation = no_animation }
local OnEquip = function(inst, data)
    if data.eslot == EQUIPSLOTS.HEAD then
        local hat = data.item
        if hat.components.armor then
            -- 检查临时护甲（使用新鲜度）还是原版护甲（使用耐久）
            if hat.components.tempequip2hm and hat.components.perishable then
                -- 临时护甲：检查新鲜度
                if hat.components.perishable:GetPercent() <= TUNING.HatTrickDropRate then
                    inst:DoTaskInTime(0, function()
                        RemoveHat(inst, hat)
                    end)
                    if inst.components.talker then
                        inst.components.talker:Say((TUNING.isCh2hm and "这个帽子坏了不能变戏法了" or "It's too bad to do hat trick"))
                    end
                    return
                end
            else
                -- 原版护甲：检查耐久
                if hat.components.armor.condition <= hat.components.armor.maxcondition * TUNING.HatTrickDropRate then
                    inst:DoTaskInTime(0, function()
                        RemoveHat(inst, hat)
                    end)
                    if inst.components.talker then
                        inst.components.talker:Say((TUNING.isCh2hm and "这个帽子坏了不能变戏法了" or "It's too bad to do hat trick"))
                    end
                    return
                end
            end
        end
        EquipHat(inst, data.item)
    end
end

-- {item=item, eslot=equipslot, slip=slip}
local OnUnequip = function(inst, data)
    if data.eslot == EQUIPSLOTS.HEAD then
        UnequipHat(inst, data.item)
    end
end

local GetHat = function(inst)
    if inst.components.inventory then
        return inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
    end
end

local OnCheckHat = function(inst)
    local hat = GetHat(inst)
    if hat then
        if hat.components.armor then
            if hat.components.armor.condition <= hat.components.armor.maxcondition * TUNING.HatTrickDropRate then
                inst.components.inventory:GiveItem(hat)
                if inst.components.talker then
                    inst.components.talker:Say((TUNING.isCh2hm and "这个帽子坏了不能变戏法了" or "It's too bad to do hat trick"))
                end
                return
            end
        end
    end
end

-- {follower = self.inst}
local OnAddfollower = function(inst, data)
    local follower = data.follower
    local hattrickchild2hm = follower:AddComponent("hattrickchild2hm")
    local initHat = GetHat(inst)
    hattrickchild2hm:SetParent(inst, initHat)
    -- print(tostring(inst) .. " 增加随从 " .. tostring(follower))
end

-- {follower = self.inst}
local OnRemovefollower = function(inst, data)
    local follower = data.follower
    if follower.components.hattrickchild2hm then
        follower.components.hattrickchild2hm:SetParent(nil)
        -- print(tostring(inst) .. " 移除随从 " .. tostring(follower))
    end
end

local Init = function(inst)
    if inst.components.leader then
        local initHat = GetHat(inst)
        for _, follower in pairs(inst.components.leader.followers) do
            if follower and follower:IsValid() then
                local hattrickchild2hm = follower:AddComponent("hattrickchild2hm")
                hattrickchild2hm:SetParent(inst, initHat)
            end
        end
    end
end

local hattrickparent2hm = Class(function(self, inst)
    self.inst = inst

    self.inst:ListenForEvent("equip", OnEquip)
    self.inst:ListenForEvent("unequip", OnUnequip)
    self.inst:ListenForEvent("addfollower", OnAddfollower)
    self.inst:ListenForEvent("removefollower", OnRemovefollower)

    self.inst:DoPeriodicTask(0.5, OnCheckHat)

    Init(inst)
end)

function hattrickparent2hm:OnRemoveFromEntity()
    self.inst:RemoveEventCallback("equip", OnEquip)
    self.inst:RemoveEventCallback("unequip", OnUnequip)
    self.inst:RemoveEventCallback("addfollower", OnAddfollower)
    self.inst:RemoveEventCallback("removefollower", OnRemovefollower)
end

return hattrickparent2hm