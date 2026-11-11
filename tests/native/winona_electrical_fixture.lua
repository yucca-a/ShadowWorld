AddSimPostInit(function()
    if not TheWorld.ismastersim then return end
    assert(TheNet:GetServerName() == "ShadowWorld isolated electrical test")
    TheWorld:PushEvent("ms_setautosaveenabled", false)
    TheWorld:DoTaskInTime(1, function()
        local checks = 0
        local function check(value, message)
            checks = checks + 1
            assert(value, "electrical: " .. message)
        end
        local function near(a, b) return math.abs(a - b) < 0.001 end
        local e = require("winonaelectrical2hm")
        local recipe = AllRecipes.winona_upgradekit_electrical
        check((recipe ~= nil) == not ELECTRICAL_DISABLED, "one recipe, including UM winona_items=false")
        local winona = assert(SpawnPrefab("winona"))
        local wilson = assert(SpawnPrefab("wilson"))
        local generator = assert(SpawnPrefab("winona_battery_low"))
        for i = 1, 80 do generator.components.fueled:TakeFuelItem(SpawnPrefab("nitre"), winona) end
        local function charge(item, doer)
            -- Stable UM consumes a fixed quarter of a low generator per interaction.
            for i = 1, 20 do generator.components.fueled:TakeFuelItem(SpawnPrefab("nitre"), winona) end
            return ACTIONS.CHARGE_FROM.fn({invobject = item, doer = doer, target = generator})
        end
        local function pulse(item, n)
            for i = 1, n do item.nextgroundcharge2hm = nil; item:AddBatteryPower(1) end
        end
        for _, name in ipairs({"lantern", "minerhat", "molehat"}) do
            local item = assert(SpawnPrefab(name))
            local max = item.components.fueled.maxfuel
            local kit = assert(SpawnPrefab("winona_upgradekit_electrical"))
            if ELECTRICAL_DISABLED then
                check(not recipe, "disabled standalone recipe")
                local record = item:GetSaveRecord()
                record.data = record.data or {}
                record.data.upgraded, record.data.electrical2hm = true, true
                record.data.electricalfuel2hm = max * 1.5
                record.data.electricalunlocked2hm = true
                local restored = assert(SpawnSaveRecord(record))
                check(restored.upgraded and near(restored.components.fueled:GetPercent(), 1), name .. " disabled restores converted item bounded to 100%")
                restored:Remove()
                kit:Remove(); item:Remove()
            else
                check(kit.components.upgrader:CanUpgrade(item, winona), name .. " upgrade permission")
                check(not kit.components.upgrader:CanUpgrade(item, wilson), name .. " non-Winona denied")
                item.components.upgradeable:Upgrade(kit, winona)
                check(not kit:IsValid(), name .. " kit consumed")
                local s = item.components.fueled
                check(item.upgraded and s.fueltype == FUELTYPE.BATTERYPOWER, name .. " electrical conversion")
                check(s.maxfuel == max and near(s.rate_modifiers:Get(), 0.75), name .. " native capacity and efficiency")
                local fuel = SpawnPrefab("transistor")
                if not fuel.components.fuel then fuel:AddComponent("fuel") end
                fuel.components.fuel.fueltype = FUELTYPE.BATTERYPOWER
                fuel.components.fuel.fuelvalue = max * 5
                s:SetPercent(0.5)
                check(s:TakeFuelItem(fuel, winona), name .. " native battery fuel accepted")
                check(near(s:GetPercent(), 1) and not item.electricalunlocked2hm, name .. " battery fuel cannot unlock overcharge")
                s:SetPercent(0.9)
                pulse(item, 30)
                check(near(s:GetPercent(), 1) and not item.electricalunlocked2hm, name .. " ground capped before first overcharge")
                winona.components.inventory:GiveItem(item)
                check(charge(item, winona) == false, name .. " backpack alone cannot overcharge")
                winona.components.inventory:Equip(item)
                local otherbattery = SpawnPrefab("transistor")
                otherbattery:AddComponent("battery")
                check(ACTIONS.CHARGE_FROM.fn({invobject = item, doer = winona, target = otherbattery}) == false,
                    name .. " other batteries cannot unlock overcharge")
                otherbattery:Remove()
                check(charge(item, winona), name .. " Winona equipped generator charge")
                check(s:GetPercent() > 1 and item.electricalunlocked2hm, name .. " first unlock")
                local classified = item.replica.inventoryitem.classified
                check(classified and classified.percentused:value() > 100, name .. " network percentage exceeds 100")
                check(near(s.rate * s.rate_modifiers:Get(), 0.75), name .. " no overcharge drain penalty")
                if name == "minerhat" then
                    check(item._light and near(item._light.Light:GetRadius(), 5), "UM minerhat overcharge light radius")
                end
                local before = s.currentfuel
                s:StartConsuming(); s:DoUpdate(10); s:StopConsuming()
                check(near(before - s.currentfuel, 7.5), name .. " actual native depletion")
                s.rate = -7.5
                before = s.currentfuel
                s:StartConsuming(); s:DoUpdate(1); s:StopConsuming()
                check(s.currentfuel < before, name .. " legacy negative rate cannot regenerate")
                winona.components.inventory:DropItem(item, true, true)
                pulse(item, 150)
                check(near(s:GetPercent(), 2), name .. " ground now reaches 200%")
                s:SetPercent(1.5)
                item.nextgroundcharge2hm = nil
                item:AddBatteryPower(1)
                local onepulse = s.currentfuel
                item:AddBatteryPower(1)
                check(s.currentfuel == onepulse, name .. " multiple generators share pulse limit")
                pulse(item, 60)
                pulse(item, 20)
                check(near(s:GetPercent(), 2), name .. " bounded ground charge")
                wilson.components.inventory:GiveItem(item)
                wilson.components.inventory:Equip(item)
                s:SetPercent(1)
                wilson:AddTag("handyperson")
                check(charge(item, wilson) == false, name .. " non-Winona cannot manually overcharge")
                wilson:RemoveTag("handyperson")
                wilson.components.inventory:DropItem(item, true, true)
                pulse(item, 120)
                local raw = s.currentfuel
                for i = 1, 8 do
                    local record = item:GetSaveRecord()
                    local restored = assert(SpawnSaveRecord(record))
                    check(restored.components.fueled.maxfuel == max, name .. " load never expands capacity " .. i)
                    check(near(restored.components.fueled.currentfuel, raw), name .. " raw charge preserved " .. i)
                    check(restored.electricalunlocked2hm, name .. " unlock saved " .. i)
                    item:Remove(); item = restored; s = item.components.fueled
                end
                -- Native moggles are destroyed at zero; retain that existing behavior.
                s:SetPercent(name == "molehat" and 0.01 or 0)
                pulse(item, 220)
                check(near(s:GetPercent(), 2), name .. " unlock survives empty battery")
                s:StartConsuming()
                before = s.currentfuel
                for i = 1, 1000 do s:DoUpdate(0.1) end
                s:StopConsuming()
                check(near(before - s.currentfuel, 75), name .. " repeated usage always depletes")
                item:Remove()
                print("[ELECTRICAL] PASS", name)
            end
        end
        if ELECTRICAL_DISABLED then
            for _, name in ipairs({"nightstick", "spear_wathgrithr_lightning"}) do
                local item = SpawnPrefab(name)
                local storage = e.Storage(item)
                local max = storage.maxfuel or storage.total
                local record = item:GetSaveRecord()
                record.data = record.data or {}
                record.data.electricalunlocked2hm = true
                if item.components.fueled then record.data.fueled = {fuel = max * 1.5}
                else record.data.finiteuses = {uses = max * 1.5} end
                local restored = SpawnSaveRecord(record)
                check(near(e.Storage(restored):GetPercent(), 1), name .. " disabled load caps at 100%")
                check(restored.electricalunlocked2hm, name .. " disabled load retains unlock history")
                item:Remove(); restored:Remove()
            end
        else
            local spear = assert(SpawnPrefab("spear_wathgrithr_lightning"))
            winona.components.inventory:GiveItem(spear); winona.components.inventory:Equip(spear)
            for i = 1, 4 do charge(spear, winona) end
            local uses = spear.components.finiteuses
            check(near(uses:GetPercent(), 2) and spear.electricalunlocked2hm, "finiteuses charge to 200%")
            local before = uses.current
            uses:Use(10)
            check(near(before - uses.current, 7.5), "finiteuses consumption remains positive")
            local restored = assert(SpawnSaveRecord(spear:GetSaveRecord()))
            check(near(restored.components.finiteuses.current, uses.current) and restored.electricalunlocked2hm, "finiteuses reload")
            winona.components.inventory:Unequip(EQUIPSLOTS.HANDS)
            winona.components.inventory:GiveItem(spear)
            local slot = winona.components.inventory:GetItemSlot(spear)
            spear.components.upgradeable.onupgradefn(spear)
            local permanent = winona.components.inventory.itemslots[slot]
            check(permanent and permanent.prefab == "spear_wathgrithr_lightning_charged" and permanent.electricalunlocked2hm,
                "native permanent spear upgrade preserves unlock")
            local stick = assert(SpawnPrefab("nightstick"))
            winona.components.inventory:GiveItem(stick); winona.components.inventory:Equip(stick)
            for i = 1, 4 do charge(stick, winona) end
            check(stick.overcharged, "morning star overcharged")
            local knight = assert(SpawnPrefab("knight"))
            local hp = knight.components.health.currenthealth
            stick.components.weapon.onattack(stick, winona, knight)
            check(near(hp - knight.components.health.currenthealth, 17), "UM mechanical extra damage once")
            check(knight.components.debuffable and knight.components.debuffable:HasDebuff("shockstundebuff"), "UM shock applied")
            check(near(stick.components.fueled.rate * stick.components.fueled.rate_modifiers:Get(), 0.75), "weapon drain has no overcharge penalty")
            if TUNING.DSTU then
                local zapper = SpawnPrefab("bugzapper")
                winona.components.inventory:GiveItem(zapper); winona.components.inventory:Equip(zapper)
                for i = 1, 4 do charge(zapper, winona) end
                local primary, chain = SpawnPrefab("spider"), SpawnPrefab("spider")
                primary.Transform:SetPosition(1000, 0, 1000)
                chain.Transform:SetPosition(1001, 0, 1000)
                local hp = chain.components.health.currenthealth
                zapper.components.weapon.onattack(zapper, winona, primary)
                check(near(hp - chain.components.health.currenthealth, 25), "UM bugzapper chain damage is 25 once")
                primary:Remove(); chain:Remove()
            end
            -- Both native generator kinds must support the first overcharge.
            local high = assert(SpawnPrefab("winona_battery_high"))
            for i = 1, 3 do high.components.trader:AcceptGift(winona, SpawnPrefab("redgem")) end
            local highitem = SpawnPrefab("lantern")
            highitem.components.upgradeable:Upgrade(SpawnPrefab("winona_upgradekit_electrical"), winona)
            highitem.components.fueled:SetPercent(1)
            winona.components.inventory:GiveItem(highitem); winona.components.inventory:Equip(highitem)
            check(ACTIONS.CHARGE_FROM.fn({invobject = highitem, doer = winona, target = high}), "high generator charge")
            check(highitem.electricalunlocked2hm and highitem.components.fueled:GetPercent() > 1, "high generator unlock")
            winona.components.inventory:DropItem(highitem, true, true)
            highitem:Remove(); high:Remove()

            local locked = SpawnPrefab("lantern")
            local unlocked = SpawnPrefab("lantern")
            for _, item in ipairs({locked, unlocked}) do
                item.components.upgradeable:Upgrade(SpawnPrefab("winona_upgradekit_electrical"), winona)
            end
            winona.components.inventory:GiveItem(unlocked); winona.components.inventory:Equip(unlocked)
            unlocked.components.fueled:SetPercent(1)
            for i = 1, 4 do check(charge(unlocked, winona), "native circuit fixture first unlock") end
            winona.components.inventory:DropItem(unlocked, true, true)
            locked.components.fueled:SetPercent(0.95)
            unlocked.components.fueled:SetPercent(1.9)
            local x, y, z = generator.Transform:GetWorldPosition()
            locked.Transform:SetPosition(x + 1, 0, z)
            unlocked.Transform:SetPosition(x - 1, 0, z)
            generator.components.fueled:TakeFuelItem(SpawnPrefab("nitre"), winona)
            TheWorld:DoTaskInTime(12, function()
                print("[ELECTRICAL] CIRCUIT", locked.components.fueled:GetPercent(), unlocked.components.fueled:GetPercent())
                check(locked.components.circuitnode:IsConnected() and unlocked.components.circuitnode:IsConnected(), "real circuit connections")
                check(near(locked.components.fueled:GetPercent(), 1), "real generator locks at 100%")
                check(unlocked.components.fueled:GetPercent() > 1.9 and unlocked.components.fueled:GetPercent() <= 2, "real generator continues overcharging")
                local amount = unlocked.components.fueled.currentfuel
                wilson.components.inventory:GiveItem(unlocked)
                TheWorld:DoTaskInTime(1, function()
                    check(near(unlocked.components.fueled.currentfuel, amount), "pickup disconnects real charging")
                    check(not unlocked.components.circuitnode:IsConnected(), "no circuit connection in inventory")
                    print("[ELECTRICAL] ALL_PASS", checks)
                    c_shutdown(false)
                end)
            end)
            return
        end
        print("[ELECTRICAL] ALL_PASS", checks)
        c_shutdown(false)
    end)
end)
