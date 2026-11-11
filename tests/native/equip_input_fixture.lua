-- Input/UI layout is a test shell. All input decision methods are extracted
-- verbatim from the installed game; inventories, items and server actions are real.
local InstallNativeControls = require("equip_native_controls")

return function(run, check, fixed, oncomplete)
    local pairs_tested, presses, queued_messages = 0, 0, 0
    local function controls(p, queued)
        local scope = setmetatable({Input = {}, FrontEnd = {}, PlayerHud = {}, InvSlot = {}, PlayerController = {}}, {__index = _G})
        local input, frontend, hud = {mouse_enabled = true}, {}, {owner = p, shown = true}
        local keys, widgets, queue = {}, {}, {}
        scope.TheInput, scope.TheFrontEnd, scope.ThePlayer = input, frontend, p
        input.IsControlPressed = function(_, control) return keys[control] == true end
        input.oncontrol = {HandleEvent = function() end} -- no other gameplay input listeners
        frontend.IsControlsDisabled = function(self) return self.disabled end
        frontend.screenstack = {hud}
        local notification = {CheckControl = function() return false end}
        hud.controls = {
            status = {GetResurrectButton = function() end},
            item_notification = notification,
            skilltree_notification = notification,
            craftingmenu = {SelectPin = function(_, slot) hud.selectedpin = slot end},
        }
        -- Rendering/focus substitutes: send the control to the selected native
        -- InvSlot before the HUD, exactly where Screen/Widget focus dispatch sits.
        scope.PlayerHud._base = {OnControl = function(_, control, down)
            return hud.consume or (hud.focused ~= nil and hud.focused:OnControl(control, down)) or false
        end}
        scope.InvSlot._base = {OnControl = function() return false end}
        scope.SendRPCToServer = function(rpc, action, item, modifiers, modname)
            check(rpc == RPC.UseItemFromInvTile, "native client sends inventory RPC")
            queue[#queue + 1] = {action = action, item = item, modifiers = modifiers, modname = modname}
            queued_messages = queued_messages + 1
        end
        InstallNativeControls(scope)
        input.OnControl = scope.Input.OnControl
        frontend.OnControl = scope.FrontEnd.OnControl
        hud.OnControl = scope.PlayerHud.OnControl
        for i = 1, 15 do
            widgets[i] = {
                owner = p, container = p.replica.inventory, num = i,
                OnControl = scope.InvSlot.OnControl, UseItem = scope.InvSlot.UseItem,
            }
        end
        if queued then
            -- No client-side entity prediction is claimed here. A burst observes
            -- the still-unmodified authoritative inventory until Flush delivers
            -- its queued packets; the original RPC validates each action again.
            local pc = p.components.playercontroller
            local remote = {ismastersim = false, EncodeControlMods = function() return nil end}
            pc.RemoteUseItemFromInvTile = function(_, act, item)
                return scope.PlayerController.RemoteUseItemFromInvTile(remote, act, item)
            end
            local classified = {_parent = p}
            p.replica.inventory.UseItemFromInvTile = function(_, item)
                return scope.InventoryClassifiedUse(classified, item)
            end
        end
        return {
            hud = hud, keys = keys, frontend = frontend,
            Press = function(_, mode, slot, duplicate_down)
                local control
                if mode == "keyboard" then
                    hud.focused = nil
                    control = assert(_G["CONTROL_INV_" .. slot])
                else
                    local widget = widgets[slot]
                    local item = p.replica.inventory:GetItemInSlot(slot)
                    widget.tile = item and {item = item} or nil
                    hud.focused = widget
                    control = CONTROL_SECONDARY
                end
                input:OnControl(control, true)
                presses = presses + 1
                -- Key-repeat events observe updated slots; GUI tiles also refresh
                -- synchronously in this host shell. Queued mode observes old state.
                if duplicate_down then
                    if mode ~= "keyboard" then
                        local item = p.replica.inventory:GetItemInSlot(slot)
                        widgets[slot].tile = item and {item = item} or nil
                    end
                    input:OnControl(control, true)
                    presses = presses + 1
                end
                input:OnControl(control, false)
            end,
            Flush = function(_, duplicate)
                local pending = queue
                queue = {}
                for _, packet in ipairs(pending) do
                    scope.NativeUseItemRPC(p, packet.action, packet.item, packet.modifiers, packet.modname)
                    if duplicate then
                        scope.NativeUseItemRPC(p, packet.action, packet.item, packet.modifiers, packet.modname)
                    end
                end
                return #pending
            end,
        }
    end

    -- Independent oracle: every selection exchanges the current hand with the
    -- contents of that slot. No historical prevslot/prevcontainer is consulted.
    local function setup(inv, a, b, spawn)
        check(inv.maxslots == 15, "covers every native player inventory slot")
        local all = {a, b}
        local prefabs = {"spear", "axe", "pickaxe", "shovel", "hammer", "pitchfork", "bugnet"}
        for i = 3, 16 do all[i] = spawn(prefabs[(i - 1) % #prefabs + 1]) end
        return all
    end
    local function reset(inv, all, first, second, equipped)
        for _, item in ipairs(all) do inv:RemoveItem(item, true) end
        local model = {slots = {}, hand = nil}
        for slot = 1, 15 do
            if first == nil or slot == first or slot == second then
                inv:GiveItem(all[slot], slot)
                model.slots[slot] = all[slot]
            end
        end
        if equipped then
            inv:Equip(all[16])
            model.hand = all[16]
        end
        return model
    end
    local function exchange(model, slot)
        if model.slots[slot] then
            model.hand, model.slots[slot] = model.slots[slot], model.hand
        end
    end
    local function layout(inv, model)
        check(inv:GetEquippedItem(EQUIPSLOTS.HANDS) == model.hand, "selected weapon is equipped")
        local seen = {}
        if model.hand then
            seen[model.hand] = true
            check(model.hand.components.inventoryitem.owner == inv.inst, "hand remains owned")
        end
        for slot = 1, 15 do
            local item = inv:GetItemInSlot(slot)
            check(item == model.slots[slot], "selected-slot exchange layout at " .. slot)
            if item then
                check(not seen[item], "no duplicate item references")
                check(item.components.inventoryitem.owner == inv.inst, "inventory item remains owned")
                seen[item] = true
            end
        end
        check(inv:GetActiveItem() == nil, "hotkey/right-click does not pick up cursor item")
    end
    local function press(ui, inv, model, mode, slot, repeat_down)
        exchange(model, slot)
        if repeat_down then exchange(model, slot) end
        ui:Press(mode, slot, repeat_down)
        layout(inv, model)
    end

    for _, mode in ipairs({"keyboard", "rightclick"}) do
        for _, full in ipairs({false, true}) do
            for _, equipped in ipairs({false, true}) do
                run(mode .. "_all_pairs_" .. tostring(full) .. "_" .. tostring(equipped), function(p, inv, a, b, spawn)
                    local ui, all = controls(p), setup(inv, a, b, spawn)
                    for first = 1, 15 do
                        for second = 1, 15 do
                            local model = reset(inv, all, not full and first or nil, not full and second or nil, equipped)
                            press(ui, inv, model, mode, first)
                            press(ui, inv, model, mode, second)
                            -- Same-slot key repeat swaps back when the slot now
                            -- holds the outgoing weapon; release has no action.
                            press(ui, inv, model, mode, second, true)
                            pairs_tested = pairs_tested + 1
                        end
                    end
                end)
            end
        end
    end
    for _, mode in ipairs({"keyboard", "rightclick", "mixed"}) do
        run(mode .. "_1500_selected_swaps", function(p, inv, a, b, spawn)
            local ui, all = controls(p), setup(inv, a, b, spawn)
            local model = reset(inv, all, nil, nil, true)
            for i = 1, 1500 do
                local input = mode == "mixed" and (i % 2 == 0 and "keyboard" or "rightclick") or mode
                press(ui, inv, model, input, (i * 7) % 15 + 1)
            end
        end)
    end
    for _, mode in ipairs({"keyboard", "rightclick"}) do
        run(mode .. "_occupied_history_all_pairs", function(p, inv, a, b, spawn)
            local ui, all = controls(p), setup(inv, a, b, spawn)
            for first = 1, 15 do
                for second = 1, 15 do
                    if first ~= second then
                        local model = reset(inv, all, first, second)
                        press(ui, inv, model, mode, first)
                        local blocker = spawn("twigs")
                        inv:GiveItem(blocker, first)
                        model.slots[first] = blocker
                        press(ui, inv, model, mode, second)
                        press(ui, inv, model, mode, second)
                        inv:RemoveItem(blocker, true)
                        pairs_tested = pairs_tested + 1
                    end
                end
            end
        end)
        run(mode .. "_queued_native_rpc_all_pairs", function(p, inv, a, b, spawn)
            local ui, all = controls(p, true), setup(inv, a, b, spawn)
            for first = 1, 15 do
                for second = 1, 15 do
                    local model = reset(inv, all, nil, nil, true)
                    local requests = {model.slots[first], model.slots[second], model.slots[first]}
                    ui:Press(mode, first)
                    ui:Press(mode, second)
                    ui:Press(mode, first)
                    for _, item in ipairs(requests) do
                        -- RPCs identify items, not the stale client slot. Each
                        -- duplicate EQUIP is a no-op once that item is held.
                        for slot = 1, 15 do
                            if model.slots[slot] == item then exchange(model, slot) break end
                        end
                    end
                    check(ui:Flush(true) == 3, "three pending requests delivered twice each")
                    layout(inv, model)
                    pairs_tested = pairs_tested + 1
                end
            end
        end)
    end
    run("keyboard_modifiers_and_focus", function(p, inv, a, b, spawn)
        local ui, all = controls(p), setup(inv, a, b, spawn)
        local model = reset(inv, all, nil, nil, true)
        ui.keys[CONTROL_CRAFTING_MODIFIER] = true
        for slot = 1, 15 do
            -- Native slots 11-15 have no crafting pins; modifier still equips.
            if slot > 10 then exchange(model, slot) end
            ui:Press("keyboard", slot)
            layout(inv, model)
        end
        ui.keys[CONTROL_CRAFTING_MODIFIER] = nil
        for _, gate in ipairs({"consume", "disabled"}) do
            ui.hud.consume = gate == "consume"
            ui.frontend.disabled = gate == "disabled"
            for slot = 1, 15 do ui:Press("keyboard", slot) layout(inv, model) end
        end
    end)

    local timed = {}
    for _, frames in ipairs({1, 3}) do
        for _, mode in ipairs({"keyboard", "rightclick", "mixed"}) do
            timed[#timed + 1] = {frames = frames, mode = mode}
        end
    end
    local function nexttimed(index)
        local case = timed[index]
        if not case then
            print("[EQUIP_SLOT_TEST] INPUT_COVERAGE", "slots=15", "ordered_pairs=" .. pairs_tested,
                "control_down_events=" .. presses, "queued_native_rpcs=" .. queued_messages,
                "timed_switches=360", "intervals=1_frame,3_frames")
            oncomplete()
            return
        end
        run(case.mode .. "_60_switches_interval_" .. case.frames .. "_frames", function(p, inv, a, b, spawn)
            local ui, all = controls(p), setup(inv, a, b, spawn)
            local model = reset(inv, all, nil, nil, true)
            return {count = 60, interval = case.frames * FRAMES, step = function(i)
                layout(inv, model)
                local mode = case.mode == "mixed" and (i % 2 == 0 and "keyboard" or "rightclick") or case.mode
                press(ui, inv, model, mode, (i * 7) % 15 + 1)
            end}
        end, function() nexttimed(index + 1) end)
    end
    nexttimed(1)
end
