local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Text = require("widgets/text")
local UIAnim = require("widgets/uianim")

local function isremote(container)
    return container and container.inst and container.inst:HasTag("shadowbankremote2hm")
end

local function send(action, slot, mode, source)
    local view = TUNING.util2hm.shadowbankview2hm
    if not view then return end
    local entry = view.items and view.items[slot]
    local active = ThePlayer and ThePlayer.replica.inventory:GetActiveItem()
    SendModRPCToServer(GetModRPC("MOD_HARDMODE", "shadowbankaction2hm"), action, slot,
        entry and entry.token, mode, view.session, source or active)
end

return function(postconstruct)
    postconstruct("widgets/containerwidget", function(self)
        local refresh = self.Refresh
        self.Refresh = function(self, ...)
            local container = self.container and self.container.replica.container
            if not isremote(container) then return refresh(self, ...) end
            local view = TUNING.util2hm.shadowbankview2hm
            local signature = view and DataDumper(view.items or {}, nil, true)
            if self.shadowbanksignature2hm == signature then return end
            self.shadowbanksignature2hm = signature
            for index, slot in pairs(self.inv) do
                local entry = view and view.items and view.items[index]
                local tile
                if entry then
                    tile = Widget("ItemTile")
                    if entry.spoilage then
                        tile:AddChild(Image("images/hud.xml", "inv_slot_spoiled.tex")):SetClickable(false)
                        local meter = tile:AddChild(UIAnim())
                        meter:GetAnimState():SetBank("spoiled_meter")
                        meter:GetAnimState():SetBuild("spoiled_meter")
                        meter:GetAnimState():SetPercent("anim", math.max(0, math.min(.99, 1 - entry.percent)))
                        meter:SetClickable(false)
                    end
                    tile:AddChild(Image(entry.atlas, entry.image)):SetClickable(false)
                    if entry.stackable then
                        local count = tile:AddChild(Text(NUMBERFONT, entry.count > 999 and 36 or 42, entry.count > 999 and "999+" or tostring(entry.count)))
                        count:SetPosition(2, 16)
                        count:SetClickable(false)
                    end
                    if entry.percent and not entry.spoilage then
                        local percent = tile:AddChild(Text(NUMBERFONT, 42, string.format("%2.0f%%", entry.percent * 100)))
                        percent:SetPosition(5, -17)
                        percent:SetClickable(false)
                    end
                end
                slot:SetTile(tile)
                slot:SetTooltip(entry and entry.name or nil)
            end
        end
        local open = self.Open
        self.Open = function(self, ...)
            self.shadowbanksignature2hm = nil
            return open(self, ...)
        end
        local function refreshremote()
            if self.isopen and self.container and self.container:HasTag("shadowbankremote2hm") then self:Refresh() end
        end
        self.inst:ListenForEvent("shadowbankviewdirty2hm", refreshremote, TheWorld)
        self.inst:DoPeriodicTask(.2, refreshremote)
    end)

    postconstruct("widgets/invslot", function(self)
        local tradeitem = self.TradeItem
        self.TradeItem = function(self, stack)
            if not isremote(self.container) and self.owner and self.owner.replica.inventory and self.container then
                local inventory = self.owner.replica.inventory
                if self.container == inventory or self.container == inventory:GetOverflowContainer() then
                    for container in pairs(inventory:GetOpenContainers() or {}) do
                        if container:HasTag("shadowbankremote2hm") then
                            local item = self.container:GetItemInSlot(self.num)
                            if item then send("depositinventory", nil, stack and "half" or nil, item) end
                            return
                        end
                    end
                end
            end
            return tradeitem(self, stack)
        end
        local oncontrol = self.OnControl
        self.OnControl = function(self, control, down)
            if not isremote(self.container) then return oncontrol(self, control, down) end
            if not down then return false end
            if control == CONTROL_ACCEPT and TheInput:IsControlPressed(CONTROL_FORCE_INSPECT) then return true end
            local active = self.owner.replica.inventory:GetActiveItem()
            local stack = TheInput:IsControlPressed(CONTROL_FORCE_STACK)
            local trade = TheInput:IsControlPressed(CONTROL_FORCE_TRADE)
            if control == CONTROL_ACCEPT or control == CONTROL_SECONDARY or control == CONTROL_SPLITSTACK or
                control == CONTROL_TRADEITEM or control == CONTROL_TRADESTACK then
                if active then
                    send("deposit", self.num, (stack or control == CONTROL_SECONDARY) and "one" or nil)
                else
                    local mode = (trade or control == CONTROL_TRADEITEM or control == CONTROL_TRADESTACK) and "inventory" or
                        control == CONTROL_SECONDARY and "one" or (stack or control == CONTROL_SPLITSTACK) and "half" or nil
                    send("take", self.num, mode)
                end
                return true
            elseif control == CONTROL_INSPECT then
                return true
            end
            return false
        end
    end)
end
