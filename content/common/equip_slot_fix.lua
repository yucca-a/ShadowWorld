-- 旧版额外装备栏会整表替换 EQUIPSLOTS，漏掉威尔逊的胡须槽。
-- 在原生生成网络槽位 ID 之前补回，客户端和服务端使用同一份槽位表。
local EquipSlot = require("equipslotutil")
local Initialize = EquipSlot.Initialize
EquipSlot.Initialize = function(...)
    local slots = GLOBAL.EQUIPSLOTS
    if slots.BEARD == nil then slots.BEARD = "beard" end
    return Initialize(...)
end

-- 手部换装与本次选中的物品栏格交换，复用原版 Equip/GiveItem 的归位流程。
-- 始终加载，不受难度或功能开关控制。
AddComponentPostInit("inventory", function(self)
    local Equip = self.Equip
    self.Equip = function(self, item, old_to_active, ...)
        local equippable = item and item.components.equippable
        if not (equippable and equippable.equipslot == EQUIPSLOTS.HANDS and item:IsValid()) then
            return Equip(self, item, old_to_active, ...)
        end

        -- 重复的装备请求不应先移除手中的同一件物品；主动卸下仍走原版 Unequip。
        local olditem = self:GetEquippedItem(EQUIPSLOTS.HANDS)
        if olditem == item then return true end

        local source = self:GetItemSlot(item)
        local swap = olditem and not old_to_active and source and self:CanTakeItemInSlot(olditem, source)
        local oldslot, oldcontainer
        if swap then
            oldslot, oldcontainer = olditem.prevslot, olditem.prevcontainer
            -- 与原版手柄换装一致，旧装备进入新装备腾出的格子，而不是历史来源格。
            olditem.prevslot, olditem.prevcontainer = source, nil
        end
        local result = Equip(self, item, old_to_active, ...)
        if swap and self:GetEquippedItem(EQUIPSLOTS.HANDS) == olditem then
            -- 装备限制、禁止卸下等拒绝换装时，保留原来的元数据。
            olditem.prevslot, olditem.prevcontainer = oldslot, oldcontainer
        end
        return result
    end
end)
