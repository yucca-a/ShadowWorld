-- Only imported by run_native_equip_slot_tests.py in a disposable offline world.
AddSimPostInit(function()
    if not TheWorld.ismastersim then return end
    assert(TheNet:GetServerName() == "ShadowWorld isolated equip slot test")
    TheWorld:PushEvent("ms_setautosaveenabled", false)
    TheWorld:DoStaticTaskInTime(1, function()
        local fixed = EQUIP_SLOT_TEST_FIXED
        local checks, failures, cases = 0, 0, 0
        local function check(value, why)
            checks = checks + 1
            assert(value, why)
        end
        local function run(name, fn, oncomplete)
            cases = cases + 1
            local spawned = {}
            local function spawn(prefab)
                local item = assert(SpawnPrefab(prefab), prefab)
                spawned[#spawned + 1] = item
                return item
            end
            local function finish(ok, err)
                for i = #spawned, 1, -1 do
                    if spawned[i]:IsValid() then spawned[i]:Remove() end
                end
                if not ok then failures = failures + 1 end
                print("[EQUIP_SLOT_TEST]", ok and "PASS" or "FAIL", name, err or "")
                if oncomplete then oncomplete() end
            end
            local ok, result = xpcall(function()
                local p = spawn("wilson")
                p.entity:SetCanSleep(false)
                p.sg:GoToState("idle")
                p:AddComponent("playercontroller")
                p:AddComponent("playeractionpicker")
                local inv = p.components.inventory
                inv:Open()
                inv:DropEverything()
                local a, b = spawn("spear"), spawn("axe")
                inv:GiveItem(a, 1)
                inv:GiveItem(b, 2)
                return fn(p, inv, a, b, spawn)
            end, tostring)
            if ok and type(result) == "table" and result.step then
                assert(oncomplete, "timed tests must report completion before shutdown")
                local index = 0
                local function step()
                    index = index + 1
                    local success, err = xpcall(function() result.step(index) end, tostring)
                    if not success or index == result.count then
                        finish(success, err)
                    else
                        TheWorld:DoStaticTaskInTime(result.interval, step)
                    end
                end
                TheWorld:DoStaticTaskInTime(result.interval, step)
            else
                finish(ok, ok and nil or result)
            end
        end

        local function press(inv, slot, actioncode)
            local item = inv:GetItemInSlot(slot)
            check(item ~= nil, "hotkey has a real item in slot " .. slot)
            inv:UseItemFromInvTile(item, actioncode)
        end

        run("empty_hands_selected_slot_swap", function(p, inv, a, b)
            press(inv, 1)
            check(inv:GetItemInSlot(1) == nil, "empty hand leaves selected slot empty")
            press(inv, 2)
            check(inv:GetEquippedItem(EQUIPSLOTS.HANDS) == b, "2 equips axe")
            check(inv:GetItemInSlot(1) == nil and inv:GetItemInSlot(2) == a, "old hand goes to selected slot 2")
            for i = 1, 200 do
                local selected = inv:GetItemInSlot(2)
                local old = inv:GetEquippedItem(EQUIPSLOTS.HANDS)
                press(inv, 2)
                check(inv:GetEquippedItem(EQUIPSLOTS.HANDS) == selected, "same slot toggles weapons")
                check(inv:GetItemInSlot(2) == old and inv:GetItemInSlot(1) == nil, "no historical slot lock")
            end
        end)

        run("duplicate_equip", function(p, inv, a, b)
            press(inv, 2)
            local events = 0
            p:ListenForEvent("equip", function() events = events + 1 end)
            p:ListenForEvent("unequip", function() events = events + 1 end)
            local result = inv:Equip(b)
            if fixed then
                check(result == true, "duplicate request succeeds without replay")
                check(inv:GetEquippedItem(EQUIPSLOTS.HANDS) == b, "duplicate does not empty hands")
                check(b.prevslot == 2 and b.components.inventoryitem.owner == p, "source and owner preserved")
                check(events == 0, "no duplicate equip/unequip callbacks")
            else
                check(result == nil and inv:GetEquippedItem(EQUIPSLOTS.HANDS) == nil, "baseline reproduces empty hands")
                check(b.prevslot == nil and b.components.inventoryitem.owner == nil, "baseline loses source and owner")
            end
        end)

        run("cursor_equip_then_hotkey", function(p, inv, a, b)
            press(inv, 1)
            inv:TakeActiveItemFromAllOfSlot(2)
            check(inv:GetActiveItem() == b and b.prevslot == 2, "cursor has source 2")
            inv:SwapEquipWithActiveItem()
            check(inv:GetActiveItem() == a and inv:GetEquippedItem(EQUIPSLOTS.HANDS) == b, "native cursor swap works")
            inv:ReturnActiveItem()
            press(inv, 1)
            check(inv:GetEquippedItem(EQUIPSLOTS.HANDS) == a, "hotkey equips spear")
            check(inv:GetItemInSlot(1) == b, "old hand enters selected slot 1")
        end)

        run("temporary_unequip_then_hotkey", function(p, inv, a, b)
            press(inv, 2)
            check(inv:Unequip(EQUIPSLOTS.HANDS) == b, "temporarily detached")
            check(b.components.inventoryitem.owner == p and b.prevslot == 2, "temporary source still recorded")
            inv:Equip(b)
            press(inv, 1)
            check(inv:GetItemInSlot(1) == b, "temporary equip then selected-slot swap")
        end)

        run("manual_relocation", function(p, inv, a, b)
            inv:GiveItem(inv:RemoveItem(b, true), 5)
            inv:TakeActiveItemFromAllOfSlot(5)
            inv:EquipActiveItem()
            press(inv, 1)
            check(inv:GetItemInSlot(1) == b, "manual relocation does not lock future swaps")
        end)

        run("occupied_source_slot", function(p, inv, a, b, spawn)
            inv:TakeActiveItemFromAllOfSlot(2)
            inv:EquipActiveItem()
            local twigs = spawn("twigs")
            inv:GiveItem(twigs, 2)
            press(inv, 1)
            check(inv:GetItemInSlot(2) == twigs, "does not displace another item")
            check(inv:GetItemInSlot(1) == b, "native fallback to available space")
            check(b.components.inventoryitem.owner == p, "no item loss")
        end)

        run("full_inventory", function(p, inv, a, b, spawn)
            for i = 3, inv.maxslots do inv:GiveItem(spawn("spear"), i) end
            press(inv, 2)
            press(inv, 1)
            check(inv:GetItemInSlot(1) == b and inv:GetEquippedItem(EQUIPSLOTS.HANDS) == a, "full inventory swaps safely")
            local count = 0
            inv:ForEachItem(function() count = count + 1 end)
            check(count == inv.maxslots, "item count unchanged")
        end)

        run("explicit_unequip", function(p, inv, a, b)
            press(inv, 2)
            inv:UseItemFromInvTile(b, ACTIONS.UNEQUIP.code)
            check(inv:GetEquippedItem(EQUIPSLOTS.HANDS) == nil, "intentional unequip still empties hands")
            check(inv:GetItemInSlot(2) == b, "intentional unequip returns to 2")
        end)

        run("late_equip_action", function(p, inv, a, b)
            press(inv, 2, ACTIONS.EQUIP.code)
            inv:UseItemFromInvTile(b, ACTIONS.EQUIP.code)
            check(inv:GetEquippedItem(EQUIPSLOTS.HANDS) == b, "stale action cannot turn equip into unequip")
            press(inv, 1, ACTIONS.EQUIP.code)
            check(inv:GetEquippedItem(EQUIPSLOTS.HANDS) == a and inv:GetItemInSlot(1) == b, "validated next action works")
        end)

        run("restricted_and_locked_equipment", function(p, inv, a, b)
            b.components.equippable.restrictedtag = "equip_slot_test_missing_tag"
            check(not inv:Equip(b), "restricted item remains rejected")
            check(inv:GetItemInSlot(2) == b, "failed equip does not remove item")
            b.components.equippable.restrictedtag = nil
            press(inv, 1)
            local oldslot, oldcontainer = a.prevslot, a.prevcontainer
            a.components.equippable:SetPreventUnequipping(true)
            check(not inv:Equip(b), "locked current equipment still blocks swap")
            check(inv:GetEquippedItem(EQUIPSLOTS.HANDS) == a and inv:GetItemInSlot(2) == b, "locked swap preserves both items")
            check(a.prevslot == oldslot and a.prevcontainer == oldcontainer, "rejected swap restores source metadata")
            a.components.equippable:SetPreventUnequipping(false)
        end)

        run("controller_swap", function(p, inv, a, b)
            p.components.playercontroller.isclientcontrollerattached = true
            inv:Equip(a)
            inv:Equip(b)
            check(inv:GetItemInSlot(2) == a, "controller keeps native swap-to-selected-slot behavior")
            check(inv:GetEquippedItem(EQUIPSLOTS.HANDS) == b, "controller equipment works")
        end)

        run("ground_pickup", function(p, inv, a, b)
            inv:DropItem(b, true, true)
            check(b.prevslot == nil, "dropping clears old source")
            inv:Equip(b)
            check(b.prevslot == nil, "ground equip does not resurrect stale source")
            press(inv, 1)
            check(inv:GetItemInSlot(1) == b, "ground item uses normal first available slot")
        end)

        for _, close in ipairs({false, true}) do
            run(close and "closed_container_source" or "open_container_source", function(p, inv, a, b, spawn)
                local chest = spawn("treasurechest").components.container
                chest:GiveItem(inv:RemoveItem(b, true), 2)
                chest:Open(p)
                chest:TakeActiveItemFromAllOfSlot(2, p)
                check(inv:GetActiveItem() == b and b.prevcontainer == chest, "cursor remembers original container")
                inv:EquipActiveItem()
                if close then chest:Close(p) end
                press(inv, 1)
                check(inv:GetItemInSlot(1) == b, "inventory selection overrides historical container source")
                check(chest:GetItemInSlot(2) == nil, "old equipment does not return to historical chest")
            end)
        end

        if fixed then require("equip_return_fixture")(run, check) end
        require("equip_input_fixture")(run, check, fixed, function()
            print("[EQUIP_SLOT_TEST] RESULT", "cases=" .. cases, "checks=" .. checks, "failures=" .. failures,
                fixed and "PATCHED" or "VANILLA_BASELINE")
            c_shutdown(false)
        end)
    end)
end)
