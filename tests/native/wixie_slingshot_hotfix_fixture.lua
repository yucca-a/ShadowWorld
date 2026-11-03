-- Disposable world only. Real prefabs, inventory restrictions and buffered SG
-- events reproduce the 2.8.14.97 locomote crash without touching player saves.
AddPrefabPostInit("world", function(world)
    if not world.ismastersim then return end
    assert(TheNet:GetServerName() == "ShadowWorld isolated slingshot hotfix test")
    world:PushEvent("ms_setautosaveenabled", false)
    local function check(ok, why) assert(ok, "SLINGSHOT_HOTFIX: " .. why) end
    world:DoTaskInTime(5, function()
        local x, y, z = world.components.playerspawner:GetAnySpawnPoint()
        local walter, wixie = SpawnPrefab("walter"), SpawnPrefab("wixie")
        check(wixie ~= nil, "actual UM Wixie exists")
        local access = GetModConfigData("Walter Use Wixie Slingshot")
        local actors = {walter, wixie}
        for n, actor in ipairs(actors) do
            actor.Transform:SetPosition(x + n * 2, 0, z)
            actor.entity:SetCanSleep(false)
            actor.components.health:SetInvincible(true)
            actor.components.hunger:SetPercent(n == 1 and .5 or .8)
            actor.sg:GoToState("idle")
        end
        local weapons = {"slingshot", "slingshotex", "slingshot2", "slingshot2ex", "slingshot_matilda", "slingshot_gnasher"}
        for _, name in ipairs(weapons) do
            local weapon = SpawnPrefab(name)
            check(weapon ~= nil, "weapon exists: " .. name)
            check(weapon.components.equippable:IsRestricted(walter) == not access, "Walter equipment permission: " .. name)
            check(not weapon.components.equippable:IsRestricted(wixie), "Wixie equipment permission: " .. name)
            if access then
                walter.components.inventory:GiveItem(weapon)
                check(BufferedAction(walter, nil, ACTIONS.EQUIP, weapon):Do(), "native inventory equip action: " .. name)
                check(walter.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) == weapon, "inventory equips " .. name)
            end
            weapon:Remove()
        end
        print("[SLINGSHOT_HOTFIX] EQUIPMENT_PASS", access)
        local shared = wixie.sg.sg.states.slingshot_charge
        local original = shared.timeline[1].time
        for _, actor in ipairs(actors) do
            local weapon = SpawnPrefab("slingshot")
            actor.components.inventory:GiveItem(weapon)
            if actor == wixie or access then actor.components.inventory:Equip(weapon) end
            actor.wixiequickshot = true
            actor.sg:GoToState("slingshot_charge")
            check(actor.sg.currentstate.name == "slingshot_charge", "native charge entered")
            check(type(actor.sg.currentstate.HandleEvent) == "function", "State methods retained")
            check(actor.sg.currentstate ~= shared, "private slowed State")
            actor.sg:PushEvent("locomote")
            actor.sg:HandleEvents()
            check(shared.timeline[1].time == original, "shared timing unchanged")
            print("[SLINGSHOT_HOTFIX] LOCOMOTE_PASS", actor.prefab)
        end
        world:DoTaskInTime(1, function()
            for _, actor in ipairs(actors) do
                actor.sg:PushEvent("unequip")
                actor.sg:HandleEvents()
                local previous = actor.sg.currentstate
                actor.sg:GoToState("idle")
                check(actor.sg.currentstate.name == "idle", "native state transition exits charge")
                check(previous.rate2hm == nil, "exit releases private slowdown")
                check(shared.timeline[1].time == original, "shared timing preserved after exit")
            end
            print("[SLINGSHOT_HOTFIX] ASYNC_UPDATE_EXIT_PASS")
            print("[SLINGSHOT_HOTFIX] ALL_PASS")
            c_shutdown(false)
        end)
    end)
end)
