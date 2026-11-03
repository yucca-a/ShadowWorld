-- Only for an isolated world with the actual NewConstant Nightmare prefabs.
AddSimPostInit(function()
    if not TheWorld.ismastersim or TheNet:GetServerName() ~= "ShadowWorld isolated eyeturret compatibility test" then return end
    TheWorld:PushEvent("ms_setautosaveenabled", false)
    local function check(ok, why) assert(ok, "[EYETURRET_COMPAT] " .. why) end
    local function near(a, b, why) check(math.abs(a - b) < .001, why .. ": " .. tostring(a) .. " / " .. tostring(b)) end
    local function stop(inst)
        inst.entity:SetCanSleep(false)
        if inst.StopBrain then inst:StopBrain() end
        if inst.components.locomotor then inst.components.locomotor:Stop() end
    end
    local function VerifyEnemy(inst)
        check(inst:HasTag("shadoweyeturret") and inst:HasTag("hostile"), "real hostile turret identity")
        near(inst.components.health.maxhealth, TUNING.EYETURRET_HEALTH2, "enemy health")
        near(inst.components.health.regen.amount, TUNING.EYETURRET_REGEN, "enemy native regeneration")
        near(inst.components.combat.defaultdamage, TUNING.EYETURRET_DAMAGE2, "enemy combat damage")
        local weapon = inst.components.combat:GetWeapon().components.weapon
        near(weapon:GetDamage(inst), TUNING.EYETURRET_DAMAGE2, "enemy weapon damage")
        check(weapon.stimuli ~= "electric", "enemy weapon never becomes electric")
        check(not inst.eyeturretenhanced2hm and not inst.eyeturretfire2hm and not inst.eyeturretspore2hm, "no enhancement flags")
        check(inst.components.trader == nil and not inst:HasTag("alltrader"), "no material upgrade receiver")
        check(not inst:HasTag("eyeturretsporeproof2hm"), "no added spore immunity")
        check(not inst.components.health.nofadeout and not inst.eyeturretrecovering2hm, "no recovery immortality")
        inst:PushEvent("healthdelta", {oldpercent=1,newpercent=.3})
        check(not inst.allmiss2hm and not inst.poor_33cdtask2hm, "no added shield")
    end
    local function Hit(turret, target)
        local shot = SpawnPrefab("eye_charge")
        shot.Transform:SetPosition(target.Transform:GetWorldPosition())
        shot.components.projectile.owner = turret.components.combat:GetWeapon()
        shot.components.projectile:Hit(target)
    end
    TheWorld:DoTaskInTime(3, function()
        local x, _, z = TheWorld.components.playerspawner:GetAnySpawnPoint()
        local spawners, enemies = {}, {}
        for index, prefab in ipairs({"shadoweyeturret", "shadoweyeturret2"}) do
            local spawner = SpawnPrefab(prefab .. "_spawner")
            spawner.Transform:SetPosition(x + index * 12, 0, z)
            spawners[index] = spawner
        end
        local friendly = SpawnPrefab("eyeturret")
        friendly.Transform:SetPosition(x, 0, z + 12)
        stop(friendly)
        TheWorld:DoTaskInTime(2, function()
            for index, spawner in ipairs(spawners) do
                local enemy = spawner.components.objectspawner.objects[1]
                check(enemy ~= nil, "actual ruins worldgen spawner created enemy")
                stop(enemy); VerifyEnemy(enemy)
                enemies[index] = enemy
                local record = enemy:GetSaveRecord()
                local gemindex, typeid = enemy.gemindex, enemy._typeid
                enemy:Remove()
                local restored = SpawnSaveRecord(record)
                stop(restored)
                enemies[index] = restored
                check(restored.gemindex == gemindex and restored._typeid == typeid, "enemy gem save restored")
            end
            near(friendly.components.health.maxhealth, 2000, "friendly enhanced health")
            near(friendly.components.combat:GetWeapon().components.weapon:GetDamage(friendly), 200, "friendly enhanced damage")
            check(friendly.components.combat:GetWeapon().components.weapon.stimuli == "electric", "friendly electric damage")
            check(friendly.components.trader:AcceptGift(nil, SpawnPrefab("dragon_scales")), "friendly upgrade remains available")
            TheWorld:DoTaskInTime(.5, function()
                for _, enemy in ipairs(enemies) do VerifyEnemy(enemy) end
                print("[EYETURRET_COMPAT] SPAWN_SAVE_PASS")
                local victim = SpawnPrefab("pigman")
                local nearby = SpawnPrefab("pigman")
                victim.Transform:SetPosition(x + 40, 0, z)
                nearby.Transform:SetPosition(x + 43, 0, z)
                stop(victim); stop(nearby); nearby:AddTag("hostile")
                victim.components.health:SetMaxHealth(10000)
                nearby.components.health:SetMaxHealth(10000)
                local enemy = enemies[1]
                -- Use the actual NewConstant red-gem hit callback. Also verify
                -- stale copied flags cannot activate our shared projectile hook.
                enemy.colours = {"red", "red", "red"}; enemy.gemindex = 1
                enemy.eyeturretenhanced2hm = true; enemy.eyeturretfire2hm = true
                Hit(enemy, victim)
                near(10000 - victim.components.health.currenthealth, TUNING.EYETURRET_DAMAGE2, "enemy shared projectile retains damage")
                near(nearby.components.health.currenthealth, 10000, "enemy projectile never chains")
                check(victim.eyeturretsafefire2hm == nil, "enemy gets no isolated flames")
                check(victim.components.burnable:IsBurning(), "enemy original red-gem ignition retained")
                victim:Remove(); nearby:Remove()
                for _, inst in ipairs(enemies) do
                    inst.components.health:ForceKill()
                    check(inst.components.health:IsDead() and not inst.eyeturretrecovering2hm, "enemy still dies normally")
                end
                TheWorld:DoTaskInTime(4, function()
                    for _, inst in ipairs(enemies) do check(not inst:IsValid(), "enemy native death removes entity") end
                    TheWorld:PushEvent("resetruins")
                    TheWorld:DoTaskInTime(2, function()
                        for _, spawner in ipairs(spawners) do
                            local enemy2 = spawner.components.objectspawner.objects[1]
                            check(enemy2 ~= nil, "actual resetruins respawn")
                            stop(enemy2); VerifyEnemy(enemy2)
                        end
                        print("[EYETURRET_COMPAT] PROJECTILE_RESPAWN_PASS")
                        print("[EYETURRET_COMPAT] ENEMY_DEATH_PASS")
                        print("[EYETURRET_COMPAT] ALL_PASS")
                        c_shutdown(false)
                    end)
                end)
            end)
        end)
    end)
end)
