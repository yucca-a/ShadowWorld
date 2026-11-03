-- Isolated, offline server only. Exercise the native special/charged shots.
AddPrefabPostInit("world", function(world)
    if not world.ismastersim then return end
    assert(TheNet:GetServerName() == "ShadowWorld isolated slingshot hotfix test")
    world:PushEvent("ms_setautosaveenabled", false)
    local function check(ok, why) assert(ok, "WALTER_SPECIAL: " .. why) end
    world:DoTaskInTime(5, function()
        local x, y, z = world.components.playerspawner:GetAnySpawnPoint()
        local walter = SpawnPrefab("walter")
        walter.Transform:SetPosition(x, 0, z)
        walter.entity:SetCanSleep(false)
        walter.components.health:SetInvincible(true)
        walter.components.hunger:SetPercent(.5)
        walter.sg:GoToState("idle")
        walter.userid = "KU_WALTERTEST"
        print("[WALTER_SPECIAL] ADD_CONTROLLER")
        walter:AddComponent("playercontroller")
        walter:AddComponent("playeractionpicker")
        print("[WALTER_SPECIAL] CONTROLLER_READY")
        local weapon = SpawnPrefab("slingshot2ex")
        walter.components.inventory:GiveItem(weapon)
        walter.components.inventory:Equip(weapon)
        local ordinary, special = SpawnPrefab("slingshotammo_rock"), SpawnPrefab("slingshotammo_gold")
        ordinary.components.stackable:SetStackSize(3)
        special.components.stackable:SetStackSize(3)
        weapon.components.container:GiveItem(ordinary, 1)
        check(not weapon.components.aoetargeting:IsEnabled(), "first slot alone does not enable special shot")
        weapon.components.container:GiveItem(special, 2)
        check(weapon.components.aoetargeting:IsEnabled(), "second slot enables targeting")
        local launched = 0
        local onlaunch = weapon.components.weapon.onprojectilelaunched
        weapon.components.weapon:SetOnProjectileLaunched(function(inst, attacker, target, proj, ...)
            check(proj.prefab == special.prefab .. "_proj", "uses second slot projectile")
            check(inst.magicamplified == true, "thulecite amplification remains active")
            launched = launched + 1
            if onlaunch then return onlaunch(inst, attacker, target, proj, ...) end
        end)
        local pc = walter.components.playercontroller
        local picker = walter.components.playeractionpicker
        walter:PushEvent("setowner")
        local cases = { "host", "remote" }
        if GLOBAL.Prefabs.childlike_certificate then
            table.insert(cases, "medal_host")
            table.insert(cases, "medal_remote")
            table.insert(cases, "ammo_host")
            table.insert(cases, "ammo_remote")
        end
        table.insert(cases, "parts_host")
        table.insert(cases, "parts_remote")
        local index, failures = 0, 0
        local function shoot()
            index = index + 1
            local case = cases[index]
            if not case then
                print("[WALTER_SPECIAL] MATRIX_DONE", "failures=" .. failures)
                if failures == 0 then print("[WALTER_SPECIAL] ALL_PASS") end
                c_shutdown(false)
                return
            end
            if case == "medal_host" then
                local medal = SpawnPrefab("childlike_certificate")
                walter.components.inventory:GiveItem(medal)
                walter.components.inventory:Equip(medal)
                check(walter:HasTag("senior_childishness"), "real childlike medal equipped")
            elseif case == "ammo_host" then
                weapon.components.container:RemoveItemBySlot(2):Remove()
                special = SpawnPrefab("medalslingshotammo_water")
                weapon.components.container:GiveItem(special, 2)
            elseif case == "parts_host" then
                local skills = walter.components.skilltreeupdater
                skills:SetSkipValidation(true)
                for _, skill in ipairs({ "walter_slingshot_modding", "walter_slingshot_frames", "walter_slingshot_bands", "walter_slingshot_handles" }) do
                    skills:ActivateSkill(skill, nil, true)
                end
                skills:SetSkipValidation(false)
                weapon.components.slingshotmods:CreateContainer_Internal()
                local parts = weapon.components.slingshotmods.containerinst.components.container
                for slot, name in ipairs({ "slingshot_band_mimic", "slingshot_frame_gems", "slingshot_handle_jelly" }) do
                    parts:GiveItem(SpawnPrefab(name), slot)
                    check(parts:GetItemInSlot(slot) ~= nil, "real part installed: " .. name)
                end
                check(weapon.components.slingshotmods:CheckRequiredSkillsForPlayer(walter), "installed parts have required skills")
            end
            walter.sg:GoToState("idle")
            ordinary.components.stackable:SetStackSize(3)
            special.components.stackable:SetStackSize(3)
            local before = launched
            local pos = Vector3(x + 5, 0, z)
            check(pc:IsEnabled(), "controller enabled")
            if case:sub(-4) == "host" then
                -- Headless fixture supplies only visual reticule data; action
                -- collection, LMB confirmation and state transitions are native.
                pc.reticule = { inst = weapon, targetpos = pos, PingReticuleAt = function() end }
                local stop = weapon.components.aoetargeting.StopTargeting
                weapon.components.aoetargeting.StopTargeting = function() pc.reticule = nil end
                local oldplayer = GLOBAL.ThePlayer
                GLOBAL.ThePlayer = walter
                pc.LMBaction, pc.RMBaction = picker:DoGetMouseActions()
                print("[WALTER_SPECIAL] PICKER", case, pc.RMBaction and pc.RMBaction.action.id, pc:IsAOETargeting())
                pc:OnLeftClick(true)
                GLOBAL.ThePlayer = oldplayer
                weapon.components.aoetargeting.StopTargeting = stop
                pc.reticule = nil
            else
                pc:OnRemoteLeftClick(ACTIONS.CASTAOE.code, pos, nil, true, 0)
            end
            print("[WALTER_SPECIAL] ENTER", case, walter.sg.currentstate.name)
            world:DoTaskInTime(3, function()
                local passed = launched == before + 1 and ordinary.components.stackable:StackSize() == 3 and special.components.stackable:StackSize() == 2
                if not passed then failures = failures + 1 end
                print("[WALTER_SPECIAL] RESULT", case, passed and "PASS" or "FAIL", launched - before, special.components.stackable:StackSize(), walter.sg.currentstate.name)
                shoot()
            end)
        end
        world:DoTaskInTime(.1, shoot)
    end)
end)
