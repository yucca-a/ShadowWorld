-- Creates and damages entities. Import ONLY in a disposable isolated world.
AddPrefabPostInit("world", function(world)
    if not world.ismastersim then return end
    assert(TheNet:GetServerName() == "ShadowWorld isolated eyeturret test", "isolated eyeturret world required")
    world:PushEvent("ms_setautosaveenabled", false)
    local function check(ok, why) assert(ok, "EYETURRET_NATIVE: " .. why) end
    local function near(a, b, why) check(math.abs(a - b) < .001, why .. ": " .. tostring(a) .. " / " .. tostring(b)) end
    local function stop(inst)
        if inst.StopBrain ~= nil then inst:StopBrain() end
        if inst.components.locomotor ~= nil then inst.components.locomotor:Stop() end
    end
    local function hit(turret, target)
        local projectile = SpawnPrefab("eye_charge")
        projectile.Transform:SetPosition(target.Transform:GetWorldPosition())
        projectile.components.projectile.owner = turret.components.combat:GetWeapon()
        projectile.components.projectile:Hit(target)
    end
    local function horns(name)
        local total = 0
        for _, ingredient in ipairs(AllRecipes[name].ingredients) do
            if ingredient.type == "lightninggoathorn" then total = total + ingredient.amount end
        end
        return total
    end
    world:DoTaskInTime(5, function()
        local sx, sy, sz = TheWorld.components.playerspawner:GetAnySpawnPoint()
        local pt = FindNearbyLand(Vector3(sx, sy, sz), 5)
        check(pt ~= nil, "spawn point")
        local x, z = pt.x, pt.z
        local turret = SpawnPrefab("eyeturret")
        turret.Transform:SetPosition(x, 0, z)
        stop(turret)
        turret:DoTaskInTime(1.3, function()
            stop(turret)
            local enabled = GetModConfigData("eyeturret")
            check(turret.components.combat:GetWeapon() ~= nil, "native weapon equipped")
            if not enabled then
                near(turret.components.health.maxhealth, TUNING.EYETURRET_HEALTH, "disabled native maximum health")
                near(turret.components.combat.defaultdamage, TUNING.EYETURRET_DAMAGE, "disabled native damage")
                near(horns("eyeturret_item"), 0, "disabled recipe")
                check(not turret.eyeturretenhanced2hm and not turret.components.trader, "disabled tower has no upgrade logic")
                print("[EYETURRET_NATIVE] DISABLED_PASS")
                c_shutdown(false)
                return
            end
            near(turret.components.health.maxhealth, 2000, "maximum health")
            near(turret.components.health.currenthealth, 2000, "placement starts full")
            near(turret.components.health.regen.amount, 50, "regen amount")
            near(turret.components.health.regen.period, 1, "regen period")
            near(turret.components.combat.defaultdamage, 200, "panel damage")
            near(turret.components.combat:GetWeapon().components.weapon:GetDamage(turret), 200, "weapon damage")
            check(turret.components.combat:GetWeapon().components.weapon.stimuli == "electric", "electric weapon")
            near(horns("eyeturret_item"), 2, "recipe horns")
            near(horns("eyeturret"), 2, "deconstruction horns")
            if AllRecipes.wathom_eyeturret_item then near(horns("wathom_eyeturret_item"), 2, "Wathom recipe horns") end
            local targets = {}
            for i = 1, 6 do
                local target = SpawnPrefab("pigman")
                target.Transform:SetPosition(x + 10 + (i - 1) * 5, 0, z)
                stop(target)
                target:AddTag("hostile")
                target.components.health:SetMaxHealth(10000)
                targets[i] = target
            end
            hit(turret, targets[1])
            for i = 1, 5 do
                near(10000 - targets[i].components.health.currenthealth,
                     200 * .8 ^ (i - 1) * TUNING.ELECTRIC_DAMAGE_MULT, "native chain damage " .. i)
            end
            near(targets[6].components.health.currenthealth, 10000, "chain stops after four extras")
            for _, target in ipairs(targets) do target:Remove() end
            print("[EYETURRET_NATIVE] STATS_CHAIN_PASS")

            local giver = SpawnPrefab("pigman")
            stop(giver)
            local function give(name)
                local item = SpawnPrefab(name)
                local actions = {}
                item:CollectActions("USEITEM", giver, turret, actions, false)
                check(table.contains(actions, ACTIONS.GIVE), "native material action offers GIVE " .. name)
                check(ACTIONS.GIVE.fn(BufferedAction(giver, turret, ACTIONS.GIVE, item)), "native GIVE upgrades " .. name)
                check(not item:IsValid(), "upgrade consumes one " .. name)
            end
            give("dragon_scales")
            give("shroom_skin")
            local duplicate = SpawnPrefab("shroom_skin")
            check(not turret.components.trader:AcceptGift(giver, duplicate) and duplicate:IsValid(), "duplicate refused without consumption")
            duplicate:Remove()
            turret.components.health:SetVal(1734)
            local record = turret:GetSaveRecord()
            turret:Remove()
            turret = SpawnSaveRecord(record)
            stop(turret)
            check(turret.eyeturretfire2hm and turret.eyeturretspore2hm and turret:HasTag("eyeturretsporeproof2hm"), "native save restores both upgrades")
            near(turret.components.health.currenthealth, 1734, "save loading does not refill injured tower")
            local plain = SpawnPrefab("eyeturret")
            plain.Transform:SetPosition(x + 2, 0, z)
            stop(plain)
            for _, prefab in ipairs({"sporecloud", "sporecloud_toad"}) do
                local cloud = SpawnPrefab(prefab)
                check(cloud ~= nil, "installed cloud " .. prefab)
                cloud.Transform:SetPosition(x + 1, 0, z)
                cloud.components.aura:Enable(false)
                turret.components.health:SetVal(2000)
                plain.components.health:SetVal(2000)
                plain.allmiss2hm = nil
                cloud.components.aura:OnTick()
                near(turret.components.health.currenthealth, 2000, "upgraded cloud immunity " .. prefab)
                check(plain.components.health.currenthealth < 2000, "ordinary turret takes cloud damage " .. prefab)
                cloud:Remove()
            end
            plain:Remove()
            print("[EYETURRET_NATIVE] UPGRADES_SAVE_SPORES_PASS")

            turret:DoTaskInTime(1.3, function()
                stop(turret)
                local target = SpawnPrefab("glacialhound")
                target.Transform:SetPosition(x + 10, 0, z)
                stop(target)
                target:DoTaskInTime(.1, function()
                    check(target:HasTag("ice_shielded") and target.ice_shield ~= nil, "UM native ice shield active")
                    target.components.health:SetInvincible(true)
                    local deaths, loot = 0, 0
                    target:ListenForEvent("death", function() deaths = deaths + 1 end)
                    target:ListenForEvent("loot_prefab_spawned", function() loot = loot + 1 end)
                    hit(turret, target)
                    check(target.components.health:IsDead() and deaths == 1, "instant kill bypasses native shield/invulnerability")
                    target:DoTaskInTime(.1, function()
                        check(target.sg.currentstate.name == "death", "native death state entered")
                        check(loot > 0, "native death loot spawned")
                        print("[EYETURRET_NATIVE] GLACIAL_EXECUTION_PASS", deaths, loot)
                        target:Remove()
                    end)
                    -- This creature also attempts native ignition on electrocute.
                    local burning = SpawnPrefab("grassgekko")
                    burning.Transform:SetPosition(x + 10, 0, z)
                    stop(burning)
                    burning.components.health:SetMaxHealth(10000)
                    local chest = SpawnPrefab("treasurechest")
                    chest.Transform:SetPosition(x + 10.5, 0, z)
                    local wall = SpawnPrefab("wall_wood")
                    wall.Transform:SetPosition(x + 10.5, 0, z + 1)
                    local wallhealth = wall.components.health.currenthealth
                    hit(turret, burning)
                    check(burning.eyeturretsafefire2hm ~= nil, "isolated flame attached")
                    local afterhit = burning.components.health.currenthealth
                    turret.components.health:SetVal(1900)
                    turret.components.health:StartRegen(50, 1)
                    burning:DoTaskInTime(1.1, function()
                        check(burning.components.health.currenthealth < afterhit, "native fire damage applied")
                        near(turret.components.health.currenthealth, 1950, "native regeneration heals exactly fifty")
                    end)
                    burning:DoTaskInTime(2.1, function()
                        near(turret.components.health.currenthealth, 2000, "regen clamps to maximum")
                    end)
                    burning:DoTaskInTime(9, function()
                        check(not burning.components.burnable:IsBurning(), "electric-hit auto-ignition cannot start spreading fire")
                        check(burning.eyeturretsafefire2hm == nil, "flame expired")
                        check(chest:IsValid() and not chest.components.burnable:IsBurning() and not chest.components.burnable:IsSmoldering(), "adjacent chest never ignited")
                        check(wall:IsValid() and not wall.components.burnable:IsBurning(), "adjacent wall never ignited")
                        near(wall.components.health.currenthealth, wallhealth, "adjacent wall takes no fire damage")
                        near(chest.components.propagator.currentheat, 0, "adjacent chest received no heat")
                        print("[EYETURRET_NATIVE] SAFE_FIRE_PASS")
                        print("[EYETURRET_NATIVE] ALL_PASS")
                        c_shutdown(false)
                    end)
                end)
            end)
        end)
    end)
end)
