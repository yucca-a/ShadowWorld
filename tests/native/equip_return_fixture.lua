return function(run, check, equip_slot)
    local EQUIP_TEST_SLOT = equip_slot or EQUIPSLOTS.HANDS
    run("save_reload_selected_swap_all_15_slots", function(p, inv, a, b, spawn)
        for slot = 1, 15 do
            inv:RemoveItem(a, true)
            inv:RemoveItem(b, true)
            local target = slot % 15 + 1
            inv:GiveItem(a, slot)
            inv:GiveItem(b, target)
            inv:Equip(a)
            local data = inv:OnSave()
            local restored = spawn("wilson")
            restored.components.inventory:DropEverything()
            restored.components.inventory:OnLoad(data, {})
            local loaded = restored.components.inventory
            local held = loaded:GetEquippedItem(EQUIP_TEST_SLOT)
            check(held ~= nil, "equipment restored")
            loaded:Equip(loaded:GetItemInSlot(target))
            check(loaded:GetItemInSlot(target) == held and loaded:GetItemInSlot(slot) == nil, "reloaded equipment enters selected slot " .. target)
        end
    end)

    run("occupied_return_slot_uses_selected_slot", function(p, inv, a, b, spawn)
        for source = 2, 15 do
            inv:RemoveItem(a, true)
            inv:RemoveItem(b, true)
            local target = source % 14 + 2
            inv:GiveItem(a, source)
            inv:GiveItem(b, target)
            inv:Equip(a)
            local blocker = spawn("twigs")
            inv:GiveItem(blocker, source)
            inv:Equip(b)
            check(inv:GetItemInSlot(source) == blocker, "pickup occupying source is untouched")
            check(inv:GetItemInSlot(target) == a, "weapon returns to newly vacated selected slot")
            check(inv:GetItemInSlot(1) == nil, "does not jump into unrelated first empty slot")
            inv:RemoveItem(blocker, true)
        end
    end)

    run("legacy_fixed_slot_field_ignored", function(p, inv, a, b, spawn)
        inv:GiveItem(inv:RemoveItem(a, true), 8)
        inv:GiveItem(inv:RemoveItem(b, true), 12)
        inv:Equip(a)
        local data = inv:OnSave()
        data.handreturnslot2hm = 8 -- Legacy custom field must not lock the outgoing item.
        local restored = spawn("wilson").components.inventory
        restored:DropEverything()
        restored:OnLoad(data, {})
        local held = restored:GetEquippedItem(EQUIP_TEST_SLOT)
        restored:Equip(restored:GetItemInSlot(12))
        check(restored:GetItemInSlot(12) == held, "legacy equipped item uses selected slot rather than first empty")
    end)

    run("source_not_persisted_or_locked", function(p, inv, a, b)
        inv:Equip(a)
        inv:GiveItem(a, 10)
        inv:Equip(a)
        local data = inv:OnSave()
        check(data.handreturnslot2hm == nil, "no custom fixed return slot is saved")
        inv:Equip(b)
        check(inv:GetItemInSlot(2) == a and inv:GetItemInSlot(10) == nil, "manual relocation does not lock outgoing position")
    end)
end
