-- Import only in an offline disposable test mod, never in a player save.
AddPrefabPostInit("world", function(world)
    if not world.ismastersim then return end
    assert(TheNet:GetServerName() == "ShadowWorld isolated slingshot hotfix test")
    world:PushEvent("ms_setautosaveenabled", false)
    local function check(ok, why) assert(ok, "WALTER_CHARGE: " .. why) end
    world:DoTaskInTime(5, function()
        local x, y, z = world.components.playerspawner:GetAnySpawnPoint()
        local function player(name)
            local p = SpawnPrefab(name)
            p.Transform:SetPosition(x, 0, z)
            p.entity:SetCanSleep(false)
            p.components.health:SetInvincible(true)
            p.components.hunger:SetPercent(.5)
            p.userid = "KU_CHARGETEST_" .. name
            p:AddComponent("playercontroller")
            p:AddComponent("playeractionpicker")
            p.components.playercontroller.remote_authority = true
            p:PushEvent("setowner")
            p.sg:GoToState("idle")
            return p
        end
        local walter = player("walter")
        local skills = walter.components.skilltreeupdater
        skills:SetSkipValidation(true)
        for _, s in ipairs({"modding", "frames", "bands", "handles"}) do
            skills:ActivateSkill("walter_slingshot_" .. s, nil, true)
        end
        skills:SetSkipValidation(false)
        local queue = {}
        local function nextcase()
            local fn = table.remove(queue, 1)
            if fn then fn() else print("[WALTER_CHARGE] ALL_PASS"); c_shutdown(false) end
        end
        local function equip(p, name)
            p.sg:GoToState("idle")
            local prev = p.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if prev then p.components.inventory:Unequip(EQUIPSLOTS.HANDS); prev:Remove() end
            local w = SpawnPrefab(name)
            p.components.inventory:GiveItem(w)
            p.components.inventory:Equip(w)
            check(p.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) == w, name .. " equipped")
            local ammo = SpawnPrefab("slingshotammo_rock")
            ammo.components.stackable:SetStackSize(10)
            w.components.container:GiveItem(ammo, 1)
            return w, ammo
        end
        for _, name in ipairs({"slingshotex", "slingshot999ex"}) do
            for _, mode in ipairs({"release", "cancel", "unequip"}) do
                local prefab, testmode = name, mode
                table.insert(queue, function()
                    local w, ammo = equip(walter, prefab)
                    w.components.slingshotmods:CreateContainer_Internal()
                    local parts = w.components.slingshotmods.containerinst.components.container
                    for slot, part in ipairs({"slingshot_band_pigskin", prefab == "slingshotex" and "slingshot_frame_wagpunk_0" or "slingshot_frame_wagpunk", "slingshot_handle_sticky"}) do
                        parts:GiveItem(SpawnPrefab(part), slot)
                        check(parts:GetItemInSlot(slot) ~= nil, part .. " installed")
                    end
                    check(w.components.slingshotmods:CheckRequiredSkillsForPlayer(walter), "skills accepted")
                    local launched = 0
                    local onlaunch = w.components.weapon.onprojectilelaunched
                    w.components.weapon:SetOnProjectileLaunched(function(inst, attacker, target, proj, ...)
                        launched = launched + 1
                        check(inst.chargedmult and inst.chargedmult > 0, "native charge multiplier supplied")
                        if onlaunch then return onlaunch(inst, attacker, target, proj, ...) end
                    end)
                    local pc = walter.components.playercontroller
                    pc:OnRemoteAOECharging(90, 1)
                    check(walter.sg:HasStateTag("aoecharging"), "native charge state selected")
                    world:DoTaskInTime(1.6, function()
                        check(w.components.aoecharging.owner == walter and w.components.aoecharging:GetChargeTicks() > 0, "charge progresses")
                        if testmode == "cancel" then
                            walter.sg:HandleEvent("chargingreticulecancelled")
                        elseif testmode == "unequip" then
                            walter.components.inventory:Unequip(EQUIPSLOTS.HANDS)
                        end
                        -- Actual release path: the component notices released input.
                        pc:OnRemoteStopControl(CONTROL_SECONDARY)
                        world:DoTaskInTime(2, function()
                            check(launched == (testmode == "release" and 1 or 0), "projectile count " .. testmode)
                            check(ammo.components.stackable:StackSize() == (testmode == "release" and 9 or 10), "ammo count " .. testmode)
                            check(w.components.aoecharging.owner == nil, "charging owner cleaned up")
                            print("[WALTER_CHARGE] PASS", prefab, testmode)
                            nextcase()
                        end)
                    end)
                end)
            end
        end
        if TUNING.DSTU then
            for _, character in ipairs({"walter", "wixie"}) do
                if character ~= "walter" or GetModConfigData("Walter Use Wixie Slingshot") then
                    for _, name in ipairs({"slingshot", "slingshot_gnasher", "slingshot_matilda"}) do
                        local who, prefab = character, name
                        table.insert(queue, function()
                            local p = who == "walter" and walter or player("wixie")
                            local w, ammo = equip(p, prefab)
                            local casts = 0
                            local spell = w.components.spellcaster.spell
                            w.components.spellcaster:SetSpellFn(function(...)
                                casts = casts + 1
                                return spell(...)
                            end)
                            local pos = Vector3(x + 5, 0, z)
                            -- Headless equivalent of UM's GetTheInput mouse RPC.
                            p.wixiepointx, p.wixiepointy, p.wixiepointz = pos:Get()
                            local function shoot()
                                local action = ACTIONS.WIXIE_SLINGSHOT
                                p.components.playercontroller:OnRemoteRightClick(action.code, pos, nil, 0, true, 0, true, action.mod_name)
                            end
                            shoot()
                            check(p.sg.currentstate.name == "slingshot_charge", "UM charge state retained")
                            world:DoTaskInTime(3, function()
                                check(p.sg:HasStateTag("slingshot_ready"), "UM charge ready")
                                shoot()
                                world:DoTaskInTime(1, function()
                                    check(casts == 1, "UM spell fired")
                                    check(ammo.components.stackable:StackSize() < 10, "UM ammo consumed")
                                    p.sg:GoToState("idle")
                                    print("[WALTER_CHARGE] PASS", who, prefab, "UM")
                                    nextcase()
                                end)
                            end)
                        end)
                    end
                end
            end
        end
        nextcase()
    end)
end)
