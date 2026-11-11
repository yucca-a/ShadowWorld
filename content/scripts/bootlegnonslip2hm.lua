local M = {}

function M.IsProtected(owner)
    for _, item in ipairs(owner.bootlegs2hm or {}) do
        if item:IsValid() and item.oldowner2hm == owner and item.components.inventoryitem:GetGrandOwner() == owner then return true end
    end
    return false
end

function M.Remove(item)
    local owner = item.oldowner2hm
    item.oldowner2hm = nil
    if owner and owner.bootlegs2hm then
        for index = #owner.bootlegs2hm, 1, -1 do
            if owner.bootlegs2hm[index] == item then table.remove(owner.bootlegs2hm, index) end
        end
        if #owner.bootlegs2hm == 0 then owner.bootlegs2hm = nil end
    end
    -- Removing an item must never create a component on its departing owner.
end

function M.Update(item)
    local owner = item.components.inventoryitem:GetGrandOwner()
    if owner == item.oldowner2hm then return end
    M.Remove(item)
    if owner and owner:IsValid() and owner:HasTag("player") and not owner:HasTag("playerghost") then
        item.oldowner2hm = owner
        owner.bootlegs2hm = owner.bootlegs2hm or {}
        table.insert(owner.bootlegs2hm, item)
        if owner.components.slipperyfeet then owner.components.slipperyfeet:SetCurrent(0) end
    end
end

local function CancelTasks(self)
    for _, name in ipairs({"inittask", "inittask2", "checknearbyentitytask"}) do
        if self[name] then self[name]:Cancel(); self[name] = nil end
    end
end

function M.Install(self)
    local function IsActive(inst)
        return not self._nonslip_removed2hm and inst:IsValid() and inst.components.slipperyfeet == self
    end
    local OnInit = self.OnInit
    if OnInit then
        self.OnInit = function(inst, ...) if IsActive(inst) then return OnInit(inst, ...) end end
    end
    -- UM has a second, private initializer for floodwater. Guard both queued
    -- callbacks, including tasks already collected by the current scheduler tick.
    for _, name in ipairs({"inittask", "inittask2", "checknearbyentitytask"}) do
        local task = self[name]
        if task and task.fn then
            local fn = task.fn
            task.fn = function(inst, ...) if IsActive(inst) then return fn(inst, ...) end end
        end
    end
    local SlowUpdateCheck = self.SlowUpdateCheck
    if SlowUpdateCheck then
        self.SlowUpdateCheck = function(inst, ...) if IsActive(inst) then return SlowUpdateCheck(inst, ...) end end
    end
    local SetCurrent, DoDelta = self.SetCurrent, self.DoDelta
    self.SetCurrent = function(self, value, ...)
        return SetCurrent(self, M.IsProtected(self.inst) and 0 or value, ...)
    end
    self.DoDelta = function(self, delta, ...)
        if M.IsProtected(self.inst) then return self:SetCurrent(0) end
        return DoDelta(self, delta, ...)
    end
    local OnRemoveFromEntity, OnRemoveEntity = self.OnRemoveFromEntity, self.OnRemoveEntity
    self.OnRemoveFromEntity = function(self, ...)
        self._nonslip_removed2hm = true
        if OnRemoveFromEntity then OnRemoveFromEntity(self, ...) end
        -- Native cleanup can reschedule a nearby-ice check while the component
        -- is still attached; cancel after all native/UM cleanup has finished.
        CancelTasks(self)
    end
    self.OnRemoveEntity = function(self, ...)
        self:OnRemoveFromEntity()
        if OnRemoveEntity then OnRemoveEntity(self, ...) end
    end
    self.inst:ListenForEvent("onremove", function()
        self._nonslip_removed2hm = true
        CancelTasks(self)
    end)
end

return M
