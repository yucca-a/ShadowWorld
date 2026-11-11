local function IsBell(item)
    return type(item) == "table" and (item.prefab == "beef_bell" or item.prefab == "shadow_beef_bell")
end

local function ContainsRecord(component, record)
    for _, entry in ipairs(component.itemdata or {}) do
        if entry == record then return true end
    end
    return false
end

local function InitBell(inst)
    if not TheWorld.ismastersim then return end

    -- A read-only peek creates temporary item entities. Its bell must display the
    -- saved state without restoring a live beefalo or starting upgrade timers.
    local OnPreLoad, OnLoad, OnSave = inst.OnPreLoad, inst.OnLoad, inst.OnSave
    inst.OnPreLoad = function(inst, data, ...)
        inst.beefbellpreview2hm = data and data.beefbellpreview2hm or nil
        if OnPreLoad then return OnPreLoad(inst, data, ...) end
    end
    inst.OnLoad = function(inst, data, ...)
        inst.beefbellrevivetime2hm = data and data.beefbellrevivetime2hm or nil
        if inst.beefbellpreview2hm then
            local saved = data and data.persistent2hm
            if data.beef_record or saved and (saved.bell_upgrade or saved.minotaurhorn) then
                inst.components.inventoryitem:ChangeImageName((inst:GetSkinName() or inst.prefab) .. "_linked")
                inst.AnimState:PlayAnimation("idle2", true)
                if inst.isbonded then inst.isbonded:set(true) end
            end
            return
        end
        if OnLoad then return OnLoad(inst, data, ...) end
    end
    inst.OnSave = function(inst, data, ...)
        if inst.relivetask2hm then data.beefbellrevivetime2hm = math.max(0, inst.relivetask2hm:NextTime() - GetTime()) end
        if OnSave then return OnSave(inst, data, ...) end
    end

    local Remove = inst.Remove
    inst.Remove = function(inst, ...)
        local transfer = inst.beefbelltransfer2hm
        inst.beefbelltransfer2hm = nil
        if transfer and transfer.bundle:IsValid() and ContainsRecord(transfer.component, transfer.record) and
            transfer.cow:IsValid() and inst:GetBeefalo() == transfer.cow then
            -- WrapItems has finished successfully and the caller is now consuming
            -- the source bell. Remove the source cow without death, loot, or revival.
            local cow, leader = transfer.cow, inst.components.leader
            cow._marked_for_despawn = true
            local onremovefollower = leader.onremovefollower
            leader.onremovefollower = nil
            leader:RemoveFollower(cow, true)
            leader.onremovefollower = onremovefollower
            cow.components.follower:SetLeader(nil)
            cow:Remove()
        end
        return Remove(inst, ...)
    end
end
AddPrefabPostInit("beef_bell", InitBell)
AddPrefabPostInit("shadow_beef_bell", InitBell)

AddComponentPostInit("unwrappable", function(self)
    local WrapItems = self.WrapItems
    self.WrapItems = function(self, items, ...)
        local bells = {}
        for index, item in ipairs(items) do
            if IsBell(item) then
                item.beefbelltransfer2hm = nil
                local cow = item:GetBeefalo()
                if cow and cow:IsValid() then
                    local rider = cow.components.rideable and cow.components.rideable:GetRider()
                    if rider and rider.components.rider then rider.components.rider:ActualDismount() end
                    bells[index] = {bell = item, cow = cow}
                end
            end
        end
        -- No ownership changes before serialization and onwrapped callbacks succeed.
        local previous, origin = self.itemdata, self.origin
        local ok, result = pcall(WrapItems, self, items, ...)
        if not ok then
            self.itemdata, self.origin = previous, origin
            error(result, 0)
        end
        for index, source in pairs(bells) do
            local record = self.itemdata and self.itemdata[index]
            if record and record.prefab == source.bell.prefab and record.data and record.data.beef_record then
                source.bell.beefbelltransfer2hm = {bundle = self.inst, component = self, record = record, cow = source.cow}
            end
        end
        return result
    end

    local PeekInContainer = self.PeekInContainer
    self.PeekInContainer = function(self, ...)
        local original, preview = self.itemdata, nil
        for index, record in ipairs(original or {}) do
            if IsBell(record) and record.data then
                preview = preview or shallowcopy(original)
                local copy = shallowcopy(record)
                copy.data = shallowcopy(record.data)
                copy.data.beefbellpreview2hm = true
                preview[index] = copy
            end
        end
        if not preview then return PeekInContainer(self, ...) end
        self.itemdata = preview
        local ok, result = pcall(PeekInContainer, self, ...)
        self.itemdata = original
        if not ok then error(result, 0) end
        return result
    end
end)
