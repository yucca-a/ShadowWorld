-- Disposable world only. Real prefabs, inventory restrictions and buffered SG
-- events reproduce the 2.8.14.97 locomote crash without touching player saves.
-- This headless world has no logged-in player keeping projectile entities awake.
AddPrefabPostInit("slingshotammo_rock_proj", function(inst) inst.entity:SetCanSleep(false) end)
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
        for index, name in ipairs(weapons) do
            local weapon = SpawnPrefab(name)
            check(weapon ~= nil, "weapon exists: " .. name)
            local allowed = index <= 4 or access
            check(weapon.components.equippable:IsRestricted(walter) == not allowed, "Walter equipment permission: " .. name)
            check(not weapon.components.equippable:IsRestricted(wixie), "Wixie equipment permission: " .. name)
            if allowed then
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
            actor.components.inventory:Equip(weapon)
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
            local function shoot(index)
                if index > 4 then
                    print("[SLINGSHOT_HOTFIX] ALL_PASS")
                    c_shutdown(false)
                    return
                end
                walter.sg:GoToState("idle")
                local previous = walter.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                if previous then previous:Remove() end
                local weapon = SpawnPrefab(weapons[index])
                walter.components.inventory:GiveItem(weapon)
                check(BufferedAction(walter, nil, ACTIONS.EQUIP, weapon):Do(), "shoot equip")
                check(weapon.components.weapon.attackrange >= TUNING.SLINGSHOT_DISTANCE, "native shooting range")
                local ammo = SpawnPrefab("slingshotammo_rock")
                ammo.components.stackable:SetStackSize(2)
                weapon.components.container:GiveItem(ammo, 1)
                check(weapon.components.weapon.projectile ~= nil, "ammo loaded")
                local target = SpawnPrefab("pigman")
                target.entity:SetCanSleep(false)
                target.Transform:SetPosition(x + 7, 0, z)
                target:StopBrain()
                target.components.health:SetMaxHealth(1000)
                local health = target.components.health.currenthealth
                local action = BufferedAction(walter, target, ACTIONS.ATTACK)
                local state = walter.sg.sg.actionhandlers[ACTIONS.ATTACK].deststate(walter, action)
                check(state == "slingshot_shoot", "native ATTACK route: " .. weapons[index])
                walter.bufferedaction = action
                walter.sg:GoToState(state)
                world:DoTaskInTime(3, function()
                    check(ammo:IsValid() and ammo.components.stackable:StackSize() == 1, "shot consumes one round: " .. weapons[index])
                    check(target.components.health.currenthealth < health, "projectile hits target: " .. weapons[index])
                    print("[SLINGSHOT_HOTFIX] LIVE_SHOT_PASS", weapons[index], access)
                    target:Remove()
                    weapon:Remove()
                    shoot(index + 1)
                end)
            end
            shoot(1)
        end)
    end)
end)
