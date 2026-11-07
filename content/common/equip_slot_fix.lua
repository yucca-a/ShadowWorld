-- 旧版额外装备栏会整表替换 EQUIPSLOTS，漏掉威尔逊的胡须槽。
-- 在原生生成网络槽位 ID 之前补回，客户端和服务端使用同一份槽位表。
local EquipSlot = require("equipslotutil")
local Initialize = EquipSlot.Initialize
EquipSlot.Initialize = function(...)
    local slots = GLOBAL.EQUIPSLOTS
    if slots.BEARD == nil then slots.BEARD = "beard" end
    return Initialize(...)
end

-- 手部装备重复装备会被原版先移除；从鼠标或临时卸下状态装备则会丢失来源格。
-- 始终加载，不受难度或功能开关控制。正常换装、主动卸下仍交给原版处理。
AddComponentPostInit("inventory", function(self)
    local Equip = self.Equip
    self.Equip = function(self, item, ...)
        local equippable = item and item.components.equippable
        if not (equippable and equippable.equipslot == EQUIPSLOTS.HANDS and item:IsValid()) then
            return Equip(self, item, ...)
        end

        -- Equip 是装备请求；主动卸下走 Unequip/GiveItem，不应在这里把同一件装备移除。
        if self:GetEquippedItem(EQUIPSLOTS.HANDS) == item then return true end

        local inventoryitem = item.components.inventoryitem
        local controller = self.inst.components.playercontroller
        local prevslot, prevcontainer
        if inventoryitem and inventoryitem.owner == self.inst and
            not (controller and controller.isclientcontrollerattached) and
            self:GetItemSlot(item) == nil then
            -- 鼠标拿取及临时卸下仍属于本角色，保留原生 RemoveItem 记录的来源。
            -- 地面拾取、他人交接和手柄交换使用原版规则。
            prevslot, prevcontainer = item.prevslot, item.prevcontainer
        end

        local result = Equip(self, item, ...)
        if result and prevslot and self:GetEquippedItem(EQUIPSLOTS.HANDS) == item and item.prevslot == nil then
            item.prevslot, item.prevcontainer = prevslot, prevcontainer
        end
        return result
    end
end)
