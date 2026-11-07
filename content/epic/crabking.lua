local UpvalueHacker = require("upvaluehacker2hm")
-- 蟹钳和炮塔能重生
local BOAT_MUST_TAGS = { "boat" }
local function IsValidArmSpawnPoint(x, z)
    if TheWorld.Map:IsVisualGroundAtPoint(x, 0, z) then
        return false
    end

    local self_radius = 0.7
    local check_radius = self_radius + (MAX_PHYSICS_RADIUS + 0.18)

    local boats = TheSim:FindEntities(x, 0, z, check_radius, BOAT_MUST_TAGS) -- Biggest radius check may include smaller boats.

    for _, boat in ipairs(boats) do
        local boat_radius = boat.GetSafePhysicsRadius and boat:GetSafePhysicsRadius() or (boat.components.hull ~= nil and boat.components.hull:GetRadius() or TUNING.BOAT.RADIUS) + 0.18 -- Add a small offset for item overhangs.
        local bx, by, bz = boat.Transform:GetWorldPosition()
        local dx, dz = bx - x, bz - z
        local dist = math.sqrt(dx * dx + dz * dz)

        if dist - boat_radius <= self_radius then
            return false
        end
    end

    return true
end

local function TrySpawningArm(inst, armpos, numclaws)
    if inst.arms == nil then
        return
    end

    local x, y, z = inst.Transform:GetWorldPosition()

    local wedge = TWOPI/numclaws
    local theta = armpos*wedge + (math.random() * wedge - wedge/2)
    local radius = 4 + 8*math.random()

    x, z = x + radius * math.cos(theta), z - radius * math.sin(theta)

    if IsValidArmSpawnPoint(x, z) then
        local arm = SpawnPrefab("crabking_claw")
        arm.Transform:SetPosition(x, 0, z)

        if inst.arms[armpos].task ~= nil then
            inst.arms[armpos].task:Cancel()
            inst.arms[armpos].task = nil
        end

        inst.arms[armpos] = arm

        local health = TUNING.CRABKING_CLAW_HEALTH
        if inst.gemcount.green > 4 then health = health + TUNING.CRABKING_CLAW_HEALTH_BOOST end
        if inst.gemcount.green > 7 then health = health + TUNING.CRABKING_CLAW_HEALTH_BOOST end
        if inst.gemcount.green >= 11 then health = health + TUNING.CRABKING_CLAW_HEALTH_BOOST_MAXGEM end

        arm.components.health:SetMaxHealth(health)
        arm.components.combat:SetDefaultDamage(TUNING.CRABKING_CLAW_PLAYER_DAMAGE + (math.floor(inst.gemcount.green/2) * TUNING.CRABKING_CLAW_DAMAGE_BOOST))
        
        arm.armpos = armpos
        arm.crabking = inst -- Saved in prefab.

        arm:PushEvent("emerge")
        arm:ListenForEvent("attacked", arm.crabkingattacked, inst)
        inst:ListenForEvent("onremove", inst.onarmremoved, arm)

        return arm -- Mods.
    end
end
local function SpawnCannons2hm(inst)
    if inst.cannontowers == nil then return end
    local firsttower
    local numcannons = TUNING.CRABKING_BASE_CANNONS + inst.gemcount.yellow
    for i=1, numcannons do
        if not inst.cannontowers[i] and not firsttower then
            firsttower = 1
            inst:SpawnCannonTower(i, nil, numcannons)
        end
    end
end
AddPrefabPostInit("crabking", function(inst)
    if not TheWorld.ismastersim then return end
    inst.TrySpawningArm = TrySpawningArm
    -- local oldOnArmRemoved = inst.onarmremoved
    -- inst.onarmremoved = function(arm, ...)
    --     oldOnArmRemoved(arm, ...)
    --     local numclaws = TUNING.CRABKING_BASE_CLAWS + (math.floor(inst.gemcount.green/2))
    --     if inst.arms[armpos].task ~= nil then
    --         inst.arms[armpos].task:Cancel()
    --         inst.arms[armpos].task = inst:DoTaskInTime(15, inst.TrySpawningArm, armpos, numclaws)
    --     end
    -- end
    -- local oldSpawnCannons = inst.SpawnCannons
    -- inst.SpawnCannons = function(inst, ...)
    --     oldSpawnCannons(inst, ...)
    --     if inst.respawnarmandcannon2hm == nil then
    --         inst.respawnarmandcannon2hm = inst:DoPeriodicTask(20, function(inst)
    --             SpawnCannons2hm(inst)
    --         end)
    --     end
    -- end
    -- local oldOnRemoveEntity = inst.OnRemoveEntity
    -- inst.OnRemoveEntity = function(inst, ...)
    --     oldOnRemoveEntity(inst, ...)
    --     if inst.respawnarmandcannon2hm ~= nil then
    --         inst.respawnarmandcannon2hm:Cancel()
    --         inst.respawnarmandcannon2hm = nil
    --     end
    -- end
    -- local oldCleanUpArena = inst.CleanUpArena
    -- inst.CleanUpArena = function(inst, remove, ...)
    --     oldCleanUpArena(inst, remove, ...)
    --     if inst.respawnarmandcannon2hm ~= nil then
    --         inst.respawnarmandcannon2hm:Cancel()
    --         inst.rpawnarmandcannon2hm = nil
    --     end
    -- end
    local oldDoSpawnArm = inst.DoSpawnArm
    inst.DoSpawnArm = function(inst, armpos, ...)
        oldDoSpawnArm(inst, armpos, ...)
        if inst.arms and armpos and inst.arms[armpos] and inst.arms[armpos].task then
            inst.arms[armpos].task.fn = inst.TrySpawningArm
        end
    end
end)

local LEAK_MUST_TAGS = { "boatleak" }
local function SpawnCannonTower(inst, i, pt, numcannons)
    pt = pt or inst:FindCannonPositions(numcannons, i)

    if pt == nil then
        inst.cannontowers[i] = false

        return
    end

    local tower = SpawnPrefab("crabking_cannontower")

    tower.Transform:SetPosition(pt.x, 0, pt.z)

    local health = TUNING.CRABKING_CANNONTOWER_HEALTH
    if inst.gemcount.yellow ~= nil and inst.gemcount.yellow > 4 then health = health + TUNING.CRABKING_CANNONTOWER_HEALTH end
    if inst.gemcount.yellow ~= nil and inst.gemcount.yellow > 7 then health = health + TUNING.CRABKING_CANNONTOWER_HEALTH end

    if inst.gemcount.yellow ~= nil and inst.gemcount.yellow >= 11 then
       health = health + TUNING.CRABKING_CANNONTOWER_HEALTH
    end

    tower.components.health:SetMaxHealth(health)
    tower.components.health:SetPercent(1) -- For pushing events?
    tower.redgemcount = inst.gemcount.red -- Saved in prefab.
    tower.yellowgemcount = inst.gemcount.yellow -- Saved in prefab.

    inst:ListenForEvent("onremove", inst.oncannontowerremoved, tower)

    inst.cannontowers[i] = tower

    local platform = tower:GetBoatIntersectingPhysics()
    local max_dist = platform ~= nil and math.max(0, platform:GetSafePhysicsRadius() - 2.5) or nil -- Maximum distance from platform origin.

    -- Too close to the platform border.
    if max_dist ~= nil and not tower:IsNear(platform, max_dist) then
        pt = tower:GetPositionAdjacentTo(platform, max_dist)

        -- Moves the tower closer to the platform origin and get the platform again for safety.
        tower.Transform:SetPosition(pt.x, 0, pt.z)
        platform = tower:GetBoatIntersectingPhysics()
    end

    if platform == nil or platform.components.health == nil then
        tower:PushEvent("ck_spawn") -- Open ocean, just spawn.

        return tower
    end

    -- Platform is leak proof, destroy it instantly.
    if platform ~= nil and platform.components.hullhealth.leakproof then
        platform:InstantlyBreakBoat()

        tower:PushEvent("ck_spawn")

        return tower
    end

    local destruction_radius = tower.Physics:GetRadius() + 0.8
    local leaks = TheSim:FindEntities(pt.x, 0, pt.z, destruction_radius, LEAK_MUST_TAGS)

    for i, leak in pairs(leaks) do
        leak:Remove()
    end

    platform.components.health:DoDelta(-TUNING.CRABKING_CANNONTOWER_HULL_SMASH_DAMAGE)
    platform.components.boatphysics:AddEmergencyBrakeSource("crabking_cannontower"..tower.GUID)

    if platform.leak_build_override ~= nil then
        tower.AnimState:AddOverrideBuild(platform.leak_build_override)
    end

    tower:PushEvent("ck_breach")

    tower:ListenForEvent("onremove", function()
        if platform:IsValid() then
            platform.components.boatphysics:RemoveEmergencyBrakeSource("crabking_cannontower"..tower.GUID)
        end
    end)

    return tower -- Mods.
end

AddPrefabPostInit("crabking", function(inst)
    if not TheWorld.ismastersim then return end
    inst.SpawnCannonTower = SpawnCannonTower
end)

-- 蟹钳掉落削弱
AddPrefabPostInit("crabking_claw", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.lootdropper then
        local oldfn = inst.components.lootdropper.SpawnLootPrefab
        inst.components.lootdropper.SpawnLootPrefab = function(self, lootprefab, ...)
            if (lootprefab == "meat" or  lootprefab == "cookedmeat")and math.random() > 0.25 then return end
            return oldfn(self, lootprefab, ...)
        end
    end
end)

-- 再生之炮
-- 加农炮塔击中船只或地形时概率生成蟹卫、击中海面概率生成炮塔
AddPrefabPostInit("crabking", function(inst)
    if not TheWorld.ismastersim then return end
    -- 额外生成的蟹钳被移除时删除占有的生成名额
    local oldonarmremoved = inst.onarmremoved
    inst.onarmremoved = function(arm, ...)
        if inst.arms and inst.arms[arm.armpos] then
            oldonarmremoved(arm, ...)
            if inst.arms[arm.armpos].task ~= nil then
                local numclaws = TUNING.CRABKING_BASE_CLAWS + (math.floor(inst.gemcount.green/2))
                inst.arms[arm.armpos].task:Cancel()
                inst.arms[arm.armpos].task = inst:DoTaskInTime(15, inst.TrySpawningArm, arm.armpos, numclaws)
            end
        end
        if inst.arms2hm ~= nil then
            for i, claw in pairs(inst.arms2hm) do
                if arm == claw then
                    table.remove(inst.arms2hm,i)
                    break
                end
            end
        end
    end
    -- 创造冰面移除额外生成的蟹钳
    local oldStartCastSpell = inst.StartCastSpell
    inst.StartCastSpell = function(inst, ...)
        oldStartCastSpell(inst, ...)
        if inst.arms2hm == nil then
            return
        end

        for i, arm in ipairs(inst.arms2hm) do
            arm:PushEvent("submerge")
        end
        inst.arms2hm = nil
    end
    -- 额外生成的炮塔被移除时删除占有的生成名额
    local oldoncannontowerremoved = inst.oncannontowerremoved
    inst.oncannontowerremoved = function(tower, ...)
        oldoncannontowerremoved(tower, ...)
        if inst.cannontowers2hm ~= nil then
            for i, cannon in pairs(inst.cannontowers2hm) do
                if tower == cannon then
                    table.remove(inst.cannontowers2hm,i)
                    break
                end
            end
        end
    end
    local oldspawncannontower = inst.SpawnCannonTower
    inst.SpawnCannonTower = function(inst, ...)
        local tower = oldspawncannontower(inst, ...)
        if tower then
            tower.crabking2hm = inst
            tower.greengemcout = inst.gemcount.green
        end
        return tower
    end
    -- 帝王蟹休眠或死亡时删除各种额外函数以及实体
    local oldCleanUpArena = inst.CleanUpArena
    inst.CleanUpArena = function(inst, remove, ...)
        oldCleanUpArena(inst, remove, ...)
        if inst.arms2hm ~= nil then
            for i, arm in pairs(inst.arms2hm) do
                inst:RemoveEventCallback("onremove", inst.onarmremoved, arm)
                if remove then
                    arm:Remove()
                elseif arm.components.health ~= nil then
                    arm.components.health:Kill()
                end
            end

            inst.arms2hm = nil
        end
        if inst.cannontowers2hm ~= nil then
            for i, tower in pairs(inst.cannontowers2hm) do
                -- Tower can be false...
                if tower then
                    inst:RemoveEventCallback("onremove", inst.oncannontowerremoved, tower)

                    if remove then
                        tower:Remove()
                    elseif tower.components.health ~= nil then
                        tower.components.health:Kill()
                    end
                end
            end
            inst.cannontowers2hm = nil
        end
    end
    -- 保存关联的实体数据
    local _OnSave = inst.OnSave
    inst.OnSave = function(inst, data, ...)
        local ents
        if _OnSave then ents = _OnSave(inst, data, ...) end
        if ents == nil then ents = {} end
        if inst.cannontowers2hm ~= nil then
            data.cannontowers2hm = {}

            for i, tower in pairs(inst.cannontowers2hm) do
                if tower and tower:IsValid() then
                    data.cannontowers2hm[i] = tower.GUID
                    table.insert(ents, tower.GUID)
                end
            end
        end
        if inst.arms2hm ~= nil then
            data.arms2hm = {}

            for i, arm in pairs(inst.arms2hm) do
                if arm.prefab ~= nil and arm:IsValid() then
                    data.arms2hm[i] = arm.GUID
                    table.insert(ents, arm.GUID)
                end
            end
        end
        if inst.epic_armor2hm ~= nil then data.epic_armor2hm = true end
        return ents
    end
    -- 加载额外关联数据及实体
    local _OnLoadPostPass = inst.OnLoadPostPass
    inst.OnLoadPostPass = function(inst, newents, data, ...)
        if _OnLoadPostPass then _OnLoadPostPass(inst, newents, data, ...) end
        if inst.components.freezable then 
            inst.components.freezable.diminishingreturns = true 
        end
        if data and data.epic_armor2hm then inst.epic_armor2hm = true end
        if data and data.icewall then inst:ListenForEvent("attacked", inst.oniceattacked2hm) end
        if data.arms2hm ~= nil then
            inst.arms2hm = {}

            for i, arm in pairs(data.arms2hm) do
                if newents[arm] ~= nil then
                    inst.arms2hm[i] = newents[arm].entity
                    inst:RemoveEventCallback("onremove", inst.onarmremoved, inst.arms2hm[i])
                end
            end
        end
        if data.cannontowers2hm ~= nil then
            inst.cannontowers2hm = {}
            for i, tower in pairs(data.cannontowers2hm) do
                if newents[tower] ~= nil then
                    local cannontower = newents[tower].entity

                    inst.cannontowers2hm[i] = cannontower
                    inst:ListenForEvent("onremove", inst.oncannontowerremoved, cannontower)

                    local platform = cannontower:GetCurrentPlatform() -- Intentionally not using GetBoatIntersectingPhysics. We should be already at a proper position on load.

                    if platform ~= nil and platform.components.boatphysics ~= nil then
                        cannontower.sg:GoToState("breach")

                        platform.components.boatphysics:AddEmergencyBrakeSource("crabking_cannontower"..cannontower.GUID)

                        if platform.leak_build_override ~= nil then
                            tower.AnimState:AddOverrideBuild(platform.leak_build_override)
                        end

                        cannontower:ListenForEvent("onremove", function()
                            if platform:IsValid() then
                                platform.components.boatphysics:RemoveEmergencyBrakeSource("crabking_cannontower"..cannontower.GUID)
                            end
                        end)
                    end
                end
            end
        end
    end
end)

AddPrefabPostInit("crabking_cannontower", function(inst)
    if not TheWorld.ismastersim then return end
    local _onsave = inst.OnSave
    inst.OnSave = function(inst, data, ...)
        local ents
        if _onsave then ents = _onsave(inst, data, ...) end
        if ents == nil then ents = {} end
        if inst.crabking2hm ~= nil and inst.crabking2hm:IsValid() then
            data.crabking2hm = inst.crabking2hm.GUID
            table.insert(ents, inst.crabking2hm.GUID)
        end
        data.greengemcout = inst.greengemcout
        return ents
    end
    local _onload = inst.OnLoad
    inst.OnLoadPostPass = function(inst, newents, data, ...)
        if _onload then _onload(inst, data, ...) end
        if data and data.crabking2hm ~= nil and newents[data.crabking2hm] ~= nil then
            local crabking = newents[data.crabking2hm].entity
            inst.crabking2hm = crabking
        end
        inst.greengemcout = data ~= nil and data.greengemcout or nil
    end
    inst.OnLoad = nilfn
    local oldlaunchprojectile = inst.LaunchProjectile
    inst.LaunchProjectile = function(inst, ...)
        local proj = oldlaunchprojectile(inst, ...)
        proj.yellowgemcount = inst.yellowgemcount
        proj.greengemcout = inst.greengemcout
        proj.crabking2hm = inst.crabking2hm
        return proj
    end
end)

local LEAK_MUST_TAGS = { "boatleak" }
local function onhitspawn(inst)
    local chance = math.random()
    chance = chance + ((inst.redgemcount or 3 + inst.yellowgemcount or 3) * 0.02)
    local x, y, z = inst.Transform:GetWorldPosition()
    local island = TheWorld.Map:IsVisualGroundAtPoint(x, 0, z)
    local platform = TheWorld.Map:GetPlatformAtPoint(x,z)
    -- 击中地面或船上生成蟹卫
    if inst.crabking2hm ~= nil and inst.crabking2hm:IsValid() and chance > 0.8 and (platform or island) then
        local spawnclaws = SpawnPrefab("crabking_mob")
        spawnclaws.Transform:SetPosition(x, 0, z)
        local platform2 = spawnclaws:GetBoatIntersectingPhysics()
        local max_dist = platform2 ~= nil and math.max(0, platform2:GetSafePhysicsRadius() - 2.5) or nil -- Maximum distance from platform origin.
        if max_dist ~= nil and not spawnclaws:IsNear(platform2, max_dist) then
            local pt = spawnclaws:GetPositionAdjacentTo(platform2, max_dist)

            spawnclaws.Transform:SetPosition(pt.x, 0, pt.z)
        end
        if spawnclaws.components.combat and spawnclaws.components.combat.target == nil then
            local player = FindClosestPlayerToInst(spawnclaws, 10, true)
            if player ~= nil then
                spawnclaws.components.combat:SuggestTarget(player)
            end
        end
    -- 击中海面生成炮塔或蟹钳
    elseif chance > 0.9 and not island and not platform and inst.crabking2hm ~= nil and inst.crabking2hm:IsValid() then
        if inst:GetDistanceSqToPoint(inst.crabking2hm.Transform:GetWorldPosition()) <= 20 * 20 then
            if inst.crabking2hm.arms2hm == nil then
                inst.crabking2hm.arms2hm = {}
            end
            if #inst.crabking2hm.arms2hm > 10 then return end
            local spawnarm = SpawnPrefab("crabking_claw")
            spawnarm.Transform:SetPosition(x, 0, z)
            local health = TUNING.CRABKING_CLAW_HEALTH
            if inst.greengemcout ~= nil and inst.greengemcout > 4 then health = health + TUNING.CRABKING_CLAW_HEALTH_BOOST end
            if inst.greengemcout ~= nil and inst.greengemcout > 7 then health = health + TUNING.CRABKING_CLAW_HEALTH_BOOST end
            if inst.greengemcout ~= nil and inst.greengemcout >= 11 then health = health + TUNING.CRABKING_CLAW_HEALTH_BOOST_MAXGEM end

            spawnarm.components.health:SetMaxHealth(health)
            spawnarm.components.combat:SetDefaultDamage(TUNING.CRABKING_CLAW_PLAYER_DAMAGE + (math.floor((inst.greengemcout or 3) /2) * TUNING.CRABKING_CLAW_DAMAGE_BOOST)) 
            spawnarm.crabking = inst.crabking2hm
            spawnarm:PushEvent("emerge")
            spawnarm:ListenForEvent("attacked", spawnarm.crabkingattacked, inst.crabking2hm)
            inst.crabking2hm:ListenForEvent("onremove", inst.crabking2hm.onarmremoved, spawnarm)
            table.insert(inst.crabking2hm.arms2hm, spawnarm)
            return
        end
        if inst.crabking2hm.cannontowers2hm == nil then
            inst.crabking2hm.cannontowers2hm = {}
        end
        if #inst.crabking2hm.cannontowers2hm > 10 then return end
        local spawncannontower = SpawnPrefab("crabking_cannontower")
        spawncannontower.Transform:SetPosition(x, 0, z)
        spawncannontower.redgemcount = inst.redgemcount or 3
        spawncannontower.yellowgemcount = inst.yellowgemcount or 3
        spawncannontower.crabking2hm = inst.crabking2hm

        local pt = Vector3(x, 0, z)
        local health = TUNING.CRABKING_CANNONTOWER_HEALTH
        if inst.yellowgemcount ~= nil and inst.yellowgemcount > 4 then 
            health = health + TUNING.CRABKING_CANNONTOWER_HEALTH 
        end
        if inst.yellowgemcount ~= nil and inst.yellowgemcount > 7 then 
            health = health + TUNING.CRABKING_CANNONTOWER_HEALTH 
        end
        if inst.yellowgemcount ~= nil and inst.yellowgemcount >= 11 then
            health = health + TUNING.CRABKING_CANNONTOWER_HEALTH
        end

        spawncannontower.components.health:SetMaxHealth(health)
        spawncannontower.components.health:SetPercent(1) -- For pushing events?
        inst.crabking2hm:ListenForEvent("onremove", inst.crabking2hm.oncannontowerremoved, spawncannontower)

        local platform = spawncannontower:GetBoatIntersectingPhysics()
        local max_dist = platform ~= nil and math.max(0, platform:GetSafePhysicsRadius() - 2.5) or nil -- Maximum distance from platform origin.

        -- Too close to the platform border.
        if max_dist ~= nil and not spawncannontower:IsNear(platform, max_dist) then
            pt = spawncannontower:GetPositionAdjacentTo(platform, max_dist)

            -- Moves the tower closer to the platform origin and get the platform again for safety.
            spawncannontower.Transform:SetPosition(pt.x, 0, pt.z)
            platform = spawncannontower:GetBoatIntersectingPhysics()
        end

        if platform == nil or platform.components.health == nil then
            spawncannontower:PushEvent("ck_spawn") -- Open ocean, just spawn.
            table.insert(inst.crabking2hm.cannontowers2hm, spawncannontower)
            return
        end

        -- Platform is leak proof, destroy it instantly.
        if platform ~= nil and platform.components.hullhealth.leakproof then
            platform:InstantlyBreakBoat()
            spawncannontower:PushEvent("ck_spawn")
            table.insert(inst.crabking2hm.cannontowers2hm, spawncannontower)
            return
        end

        local destruction_radius = spawncannontower.Physics:GetRadius() + 0.8
        local leaks = TheSim:FindEntities(pt.x, 0, pt.z, destruction_radius, LEAK_MUST_TAGS)

        for i, leak in pairs(leaks) do
            leak:Remove()
        end

        platform.components.health:DoDelta(-TUNING.CRABKING_CANNONTOWER_HULL_SMASH_DAMAGE)
        platform.components.boatphysics:AddEmergencyBrakeSource("crabking_cannontower"..spawncannontower.GUID)

        if platform.leak_build_override ~= nil then
            spawncannontower.AnimState:AddOverrideBuild(platform.leak_build_override)
        end

        spawncannontower:PushEvent("ck_breach")

        spawncannontower:ListenForEvent("onremove", function()
            if platform:IsValid() then
                platform.components.boatphysics:RemoveEmergencyBrakeSource("crabking_cannontower"..spawncannontower.GUID)
            end
        end)
        table.insert(inst.crabking2hm.cannontowers2hm, spawncannontower)
    end
end

AddPrefabPostInit("mortarball", function(inst)
    if not TheWorld.ismastersim then return end
    inst.onhitspawn = onhitspawn
    if inst.components.complexprojectile then
        local oldonhit = inst.components.complexprojectile.onhitfn
        inst.components.complexprojectile.onhitfn = function(inst, ...)
            oldonhit(inst, ...)
            inst.onhitspawn(inst)
        end
    end
end)

-- 冰面期间炮塔索敌大幅提升，让玩家不得不先清理炮台
local TARGET_ONEOF_TAGS = { "smallcreature", "largecreature", "animal", "monster", "character" }
local TARGETS_CANT_TAGS = { "FX", "NOCLICK", "DECOR", "INLIMBO", "noattack", "crabking_ally" }
AddPrefabPostInit("crabking_cannontower", function(inst)
    if not TheWorld.ismastersim then return end
    local TryShootCannon = inst.TryShootCannon
    inst.TryShootCannon = function(inst, ...)
        if inst.crabking2hm ~= nil and inst.crabking2hm:IsValid() and inst.crabking2hm:HasTag("icewall") then
            if not inst.sg:HasStateTag("loaded") then
                if inst.reloadtask == nil then
                    inst:StartReloadTask(1)
                end
                return
            end
            local x, y, z = inst.Transform:GetWorldPosition()
            local ents = TheSim:FindEntities(x, 0, z, 30, nil, TARGETS_CANT_TAGS, TARGET_ONEOF_TAGS)
            if ents ~= nil and #ents > 0 then
                for i, ent in ipairs(ents) do
                    if ent:HasTag("player") then
                        return inst:DoShootCannon(ent)
                    end

                    local leader = ent.components.follower ~= nil and ent.components.follower:GetLeader() or nil

                    if leader ~= nil and leader:HasTag("player") then
                        return inst:DoShootCannon(ent)
                    end
                end
            end
            inst:StartReloadTask(2)
        else
            TryShootCannon(inst, ...)
        end
    end
end)

-- 守护蟹钳
-- 距离目标过远或目标距离帝王蟹过近则直接传送到目标附近
local function shouldteleport(inst, target)
    return not inst:IsNear(target,20) or 
    (inst.crabking and inst.crabking:IsValid() and target:IsNear(inst.crabking, 10) and not inst:IsNear(target,10))
end

-- 攻击帝王蟹目标与追击目标不是同一个则立刻转变目标传送至目标附近保护帝王蟹
local function crabkingattacked(inst, crabking, data)
    if inst.shouldretarget then return end
    if crabking and crabking:IsValid() and data and data.attacker and data.attacker:IsValid() and data.attacker:IsOnOcean(true) and data.attacker.components.combat and data.attacker.components.health then
        local attacker = data.attacker
        if inst.components.combat and not inst.components.combat:TargetIs(attacker) and not inst:IsNear(attacker, 10) then
            inst.shouldretarget = true
            inst.sg:GoToState("submergePG", attacker)
            inst.components.combat:SetTarget(attacker)
            inst:DoTaskInTime(10, function()
                inst.shouldretarget = nil
            end)
        end
    end
end

-- 可以仇恨飞行生物
-- local TARGET_DIST = TUNING.CRABKING_ATTACK_TARGETRANGE
-- local RETARGET_MUST_TAGS = { "_combat" }
-- local RETARGET_CANT_TAGS = { "INLIMBO", "playerghost", "crabking_ally"}
-- local RETARGET_ONEOF_TAGS = { "flying"}
-- local function newRetarget(inst)
--     local gx, gy, gz = inst.Transform:GetWorldPosition()
--     local potential_targets = TheSim:FindEntities(
--         gx, gy, gz, TARGET_DIST,
--         RETARGET_MUST_TAGS, RETARGET_CANT_TAGS, RETARGET_ONEOF_TAGS
--     )

--     local newtarget = nil
--     for _, target in ipairs(potential_targets)do
--         local pos =  Vector3(target.Transform:GetWorldPosition())
--         if target ~= inst and target.entity:IsVisible()
--                 and inst.components.combat:CanTarget(target)
--                 and TheWorld.Map:IsOceanAtPoint(pos.x, 0, pos.z, true) then
--             newtarget = target
--             break
--         end
--     end

--     if newtarget ~= nil and newtarget ~= inst.components.combat.target then
--         return newtarget, true
--     else
--         return nil
--     end
-- end

AddPrefabPostInit("crabking_claw", function(inst)
    if not TheWorld.ismastersim then return end
    inst.crabkingattacked = function(crabking, data) crabkingattacked(inst, crabking, data) end
    local oldOnLoadPostPass = inst.OnLoadPostPass
    inst.OnLoadPostPass = function(inst, newents, data, ...)
        oldOnLoadPostPass(inst, newents, data, ...)
        if inst.crabking ~= nil and inst.crabking:IsValid() then
            local crabking = inst.crabking
            inst:ListenForEvent("attacked", inst.crabkingattacked, crabking)
        end
    end
    inst.teleport2hm = nil
    if inst.components.combat then
        local oldkeeptargetfn = inst.components.combat.keeptargetfn
        inst.components.combat.keeptargetfn = function(inst, target, ...)
            local keep = oldkeeptargetfn(inst, target, ...)
            if inst.sg:HasStateTag("busy") or inst.teleport2hm == true then return keep end
            if keep and target and target:IsValid() and target:IsOnOcean(true) and shouldteleport(inst, target) then
                inst.sg:GoToState("submergePG", target)
            end
            return keep
        end
        local RETARGET_ONEOF_TAGS = UpvalueHacker.GetUpvalue(inst.components.combat.targetfn, "RETARGET_ONEOF_TAGS")
        if RETARGET_ONEOF_TAGS ~= nil then table.insert(RETARGET_ONEOF_TAGS, "flying") end
        -- inst.components.combat.targetfn = function(inst, ...)
        --     local newtarget, retarget = oldtargetfn(inst, ...)
        --     if newtarget ~= nil then return newtarget, retarget end
        --     newtarget, retarget = newRetarget(inst, ...)
        --     if newtarget ~= nil and newtarget ~= inst.components.combat.target then
        --         return newtarget, true
        --     else
        --         return nil
        --     end
        -- end
    end
end)

local function play_shadow_animation(inst, anim, loop)
    --addshadow(inst)
    inst.AnimState:PlayAnimation(anim,loop)
    if inst.shadow then
        inst.shadow.AnimState:PlayAnimation(anim,loop)
    end
end

AddStategraphState("crabkingclaw", State{
    name = "submergePG",
    tags = { "busy", "canrotate" ,"noelectrocute"},

    onenter = function(inst, target)
        play_shadow_animation(inst, "submerge")
        inst.SoundEmitter:PlaySound("turnoftides/common/together/water/emerge/medium")
        inst.AnimState:SetDeltaTimeMultiplier(1.7)
        inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
        inst.sg.statemem.target = target
        if not inst.teleport2hm then
            inst.teleport2hm = true
        end
    end,

    onexit = function(inst)
        inst.AnimState:SetDeltaTimeMultiplier(1)
    end,

    events =
    {
        EventHandler("animover", function(inst)
            if inst.sg.statemem.target and inst.sg.statemem.target:IsValid() then
                local target = inst.sg.statemem.target
                local x, y, z = target.Transform:GetWorldPosition()
                local radius = 4
                local arc = math.random() * TWOPI
                local pt = Vector3(x + radius * math.cos(arc), 0, z - radius * math.sin(arc))
                local targetplatform = target:GetBoatIntersectingPhysics()
                if targetplatform then
                    inst.Transform:SetPosition(pt.x, 0, pt.z)
                    pt = inst:GetPositionAdjacentTo(targetplatform, 7)
                    inst.Transform:SetPosition(pt.x, 0, pt.z)
                else
                    inst.Transform:SetPosition(pt.x, 0, pt.z)
                end
                inst.sg:GoToState("emergePG")
            end
        end),
    },
})

AddStategraphState("crabkingclaw", State{
    name = "emergePG",
    tags = { "busy", "canrotate" ,"noelectrocute"},

    onenter = function(inst, pushanim)
        play_shadow_animation(inst, "emerge")
        --inst.AnimState:PlayAnimation("emerge")
        inst.SoundEmitter:PlaySound("turnoftides/common/together/water/emerge/medium")
        inst.AnimState:SetDeltaTimeMultiplier(1.7)

    end,

    onexit = function(inst)
        inst.AnimState:SetDeltaTimeMultiplier(1)
    end,

    events =
    {
        EventHandler("animover", function(inst)
            inst.sg:GoToState("idle")
            if inst.teleport2hm == true then
                inst:DoTaskInTime(3, function() inst.teleport2hm = nil end)
            end
        end),
    },
})

-- 冰面存在时攻击者脚下的冰会裂开
local function oniceattacked2hm(inst, data)
    if inst.shouldremoveice2hm ~= nil then return end
    if data and data.attacker and data.attacker:IsValid() and data.attacker:HasTag("player") then
        local attacker = data.attacker
        inst.shouldremoveice2hm = inst:DoTaskInTime(2, function(inst, attacker)
            inst.shouldremoveice2hm = nil
            if attacker and attacker:IsValid() and TheWorld.components.oceanicemanager then
                local pt = attacker:GetPosition()
                TheWorld.components.oceanicemanager:QueueDestroyForIceAtPoint(pt.x, 0, pt.z)
            end
        end, attacker)
    end
end

-- 优化坐标位置冰面检测函数
AddComponentPostInit("oceanicemanager", function(self)
    if not TheWorld.ismastersim then return end
    local QueueDestroyForIceAtPoint = self.QueueDestroyForIceAtPoint
    self.QueueDestroyForIceAtPoint = function(self, x,y,z, data, ...)
        local tile = TheWorld.Map:IsOceanIceAtPoint(x,y,z)
        if not tile then
            for i = 0, 7 do
                local angle = i * math.pi / 4
                local offset_x = math.cos(angle) * 0.8
                local offset_z = math.sin(angle) * 0.8
                
                local check_x, check_z = x + offset_x, z + offset_z       
                local check_health = TheWorld.Map:IsOceanIceAtPoint(check_x, 0,check_z)
                if check_health then
                    local dist = math.sqrt(offset_x^2 + offset_z^2)
                    if dist < 2.5 then
                        x, z = check_x, check_z
                    end
                end
            end
        end
        QueueDestroyForIceAtPoint(self, x,y,z, data, ...)
    end
end)

-- 延长巨兽装甲的持续时间
local function epic_armor(inst)
    if inst.onkeystoneremoved then
        local oldstartendicetask = UpvalueHacker.GetUpvalue(inst.onkeystoneremoved, "OnKeyStoneRemoved", "startendicetask")
        if oldstartendicetask then
            local startendicetask = function(inst)
                oldstartendicetask(inst)
                if not inst.firstwallbreaktime2hm then
                inst.firstwallbreaktime2hm = GetTime()
                end
            end
            UpvalueHacker.SetUpvalue(inst.onkeystoneremoved, startendicetask, "OnKeyStoneRemoved", "startendicetask")
        end
    end
end

AddPrefabPostInit("crabking", function(inst)
    if not TheWorld.ismastersim then return end
    inst.firstwallbreaktime2hm = nil
    inst.epic_armor2hm = nil
    inst.oniceattacked2hm = oniceattacked2hm
    if inst.components.trader and inst.components.trader.onaccept then
        -- 镶嵌6种宝石会升级为彩虹宝石，最后1个宝石不触发
        local onaccept = inst.components.trader.onaccept
        inst.components.trader.onaccept = function(inst, giver, item, ...)
            onaccept(inst, giver, item, ...)
            if inst:HasTag("hostile") or #inst.socketed < 6 then return end
            local gems = {redgem = 0, bluegem = 0, purplegem = 0, orangegem = 0, yellowgem = 0, greengem = 0}
            for i, socket in ipairs(inst.socketed) do if socket.itemprefab and gems[socket.itemprefab] then gems[socket.itemprefab] = 1 end end
            for itemprefab, value in pairs(gems) do if value == 0 then return end end
            local realgems = {}
            for i, socket in ipairs(inst.socketed) do
                if gems[socket.itemprefab] == 1 then
                    gems[socket.itemprefab] = 0
                else
                    table.insert(realgems, SpawnPrefab(socket.itemprefab))
                end
            end
            table.insert(realgems, SpawnPrefab("opalpreciousgem"))
            inst.socketed = {}
            inst.socketlist = {1, 2, 3, 4, 6, 7, 8, 9}
            inst.AnimState:ClearOverrideSymbol("gems_blue")
            for i = 1, 9 do inst.AnimState:ClearOverrideSymbol("gem" .. i) end
            for i, gem in ipairs(realgems) do
                onaccept(inst, giver, gem, ...)
                if gem:IsValid() then gem:Remove() end
            end
        end
        -- 非战败，只掉落最后2~3个宝石
        local dropgems = inst.DropSocketedGems
        inst.DropSocketedGems = function(inst, ...)
            if inst.components.health and inst.components.health:IsDead() then return dropgems(inst, ...) end
            local drop = math.random(7, 8)
            if #inst.socketed < drop then return end
            local realgems = {}
            for i, socket in ipairs(inst.socketed) do
                if i < drop then
                    table.insert(realgems, SpawnPrefab(socket.itemprefab))
                else
                    local gem = SpawnPrefab(socket.itemprefab)
                    inst.components.lootdropper:FlingItem(gem)
                end
            end
            inst.socketed = {}
            inst.socketlist = {1, 2, 3, 4, 6, 7, 8, 9}
            inst.AnimState:ClearOverrideSymbol("gems_blue")
            for i = 1, 9 do inst.AnimState:ClearOverrideSymbol("gem" .. i) end
            for i, gem in ipairs(realgems) do
                onaccept(inst, inst, gem, ...)
                if gem:IsValid() then gem:Remove() end
            end
        end
    end
    if inst.SocketItem then
        local oldSocketItem = inst.SocketItem
        inst.SocketItem = function(inst, ...)
            oldSocketItem(inst, ...)
            if inst.components.freezable then 
                inst.components.freezable.diminishingreturns = true 
            end
        end
    end
    local oldDoSpawnIceTile = inst.DoSpawnIceTile
    inst.DoSpawnIceTile = function(inst, ...)
        oldDoSpawnIceTile(inst, ...)
        if inst.startfreezetim2hm  then inst.startfreezetim2hm = nil end
        inst:ListenForEvent("attacked", inst.oniceattacked2hm)
        if inst.freezefx2hm then inst.freezefx2hm:Remove() end
        if inst.components.timer and inst.components.timer:TimerExists("invincible2hm") and not inst.epic_armor2hm then
            local oldtime = inst.components.timer:GetTimeLeft("invincible2hm")
            local iceEndTime = math.max(3, Remap(inst.gemcount.blue, 0, 11, 25, 3 ))
            if oldtime and iceEndTime then
                local invTime = oldtime + iceEndTime
                inst.components.timer:SetTimeLeft("invincible2hm", invTime)
                inst.epic_armor2hm = true
            end
        end
    end
    local oldEndIceStage = inst.EndIceStage
    inst.EndIceStage = function(inst, ...)
        oldEndIceStage(inst, ...)
        inst:RemoveEventCallback("attacked", inst.oniceattacked2hm)
        inst.epic_armor2hm = nil
        inst.firstwallbreaktime2hm = nil
    end
    epic_armor(inst)
end)

-- 苏醒时推走附近的船
local NEARBY_PLATFORM_MUST_TAGS = { "boat", "walkableplatform" }
local NEARBY_PLATFORM_CANT_TAGS = { "FX", "NOCLICK", "DECOR", "INLIMBO" }
local NEARBY_PLATFORM_TEST_RADIUS = 3 + TUNING.MAX_WALKABLE_PLATFORM_RADIUS
local function push_nearby_boats(inst)
    local ix, iy, iz = inst.Transform:GetWorldPosition()
    local radius = inst:GetPhysicsRadius(1)
    local min_range_sq = math.max(0, radius - NEARBY_PLATFORM_TEST_RADIUS)
    min_range_sq = min_range_sq * min_range_sq

    local i0
    local platform_ents = TheSim:FindEntities(ix, 0, iz, radius + NEARBY_PLATFORM_TEST_RADIUS, NEARBY_PLATFORM_MUST_TAGS, NEARBY_PLATFORM_CANT_TAGS)
    for i, platform_entity in ipairs(platform_ents) do
        if platform_entity:GetDistanceSqToPoint(ix, 0, iz) >= min_range_sq then
            i0 = i
            break
        end
    end
    if i0 then
        for i = i0, #platform_ents do
            local platform_entity = platform_ents[i]
            if platform_entity ~= inst
                    and platform_entity.Transform
                    and platform_entity.components.boatphysics then
                local v2x, v2y, v2z = platform_entity.Transform:GetWorldPosition()
                local mx, mz = v2x - ix, v2z - iz
                if mx ~= 0 or mz ~= 0 then
                    local normalx, normalz = VecUtil_Normalize(mx, mz)
                    local count = 0
                    for _, _ in pairs(platform_entity.components.boatphysics.boatdraginstances) do count = count + 1 end
                    local force = 2 + (count * 2)
                    platform_entity.components.boatphysics:ApplyForce(normalx, normalz, force)
                end
            end
        end
    end
end

-- 帝王蟹施法期间释放冰冻
local function startfeeze2(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local fx = SpawnPrefab("crabking_feeze2hm")
    fx.crab = inst
    fx.Transform:SetPosition(x, y, z)
    local scale = 0.75 + Remap(inst.gemcount.blue or 3, 0, 9, 0, 1.55)
    fx.Transform:SetScale(scale, scale, scale)
    inst.SoundEmitter:PlaySound("hookline_2/creatures/boss/crabking/magic_LP", "crabmagic")
    inst.freezefx2hm = fx
end
AddStategraphPostInit("crabking", function(sg)
    if sg.states.inert_pst then
        local oldonenter = sg.states.inert_pst.onenter
        sg.states.inert_pst.onenter = function(inst, ...)
            oldonenter(inst, ...)
            push_nearby_boats(inst)
            SpawnAttackWaves(inst:GetPosition(), nil, 2.2, 8, nil, 2.25, nil, 2, true)
        end
    end
    if sg.states.cast_pre and sg.states.cast_pre.events and sg.states.cast_pre.events.animover then
        local oldfn = sg.states.cast_pre.events.animover.fn
        sg.states.cast_pre.events.animover.fn = function(inst, ...)
            oldfn(inst, ...)
            inst.startfreezetim2hm = nil
            inst.startfreezetim2hm = GetTime()
        end
    end
    if sg.states.cast_loop then
        local oldonenter = sg.states.cast_loop.onenter
        sg.states.cast_loop.onenter = function(inst, wavetime, ...)
            oldonenter(inst, wavetime, ...)
            if inst.startfreezetim2hm and (GetTime() - inst.startfreezetim2hm) >= 3 then
                if inst.components.timer and not inst.components.timer:TimerExists("casting_timer2hm") then
                    inst.components.timer:StartTimer("casting_timer2hm", 10)
                    startfeeze2(inst)
                end
            end
        end
    end
end)

-- 没苏醒别再受伤了
AddPrefabPostInit("crabking", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.health then
        local oldDoDelta = inst.components.health.DoDelta
        inst.components.health.DoDelta = function(self, amount, ...)
            if amount < 0 and not self.inst:HasTag("hostile") then return end
            oldDoDelta(self, amount, ...)
        end
    end
end)

-- 天体贡品可以解锁瓦套
local TechTree = require("techtree")
local WAGPUNk_Armor = {"wagpunkhat", "armorwagpunk"}
for i, v in pairs(WAGPUNk_Armor)do
    AddRecipePostInit(v, function(inst)
        inst.level = TechTree.Create({CELESTIAL = 4})
        inst.nounlock = false
    end)
end

AddPrefabPostInit("moon_altar_cosmic", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.prototyper then
        inst.components.prototyper.trees = TechTree.Create({CELESTIAL = 4})
    end
end)

-- 能力勋章-ban踏水，附近佩戴踏水勋章的玩家强制落水
if ModManager:GetMod("workshop-1909182187") then
    local function try_sinkplayerinoeacn(player)
        if player.components.drownable and player.components.drownable:IsOverWater() and player.medal_canTread then
            local x,y,z = player.Transform:GetWorldPosition()
            SpawnPrefab("crab_king_waterspout").Transform:SetPosition(x,0,z)
            player.medal_canTread = nil
            player.sinkbycrabking2hm = true
            player:PushEvent("onsink")
        end
    end

    local function onattacked2hm(inst, data)
        if inst.sinkplayer2hm then return end
        if data and data.attacker and data.attacker:IsValid() and data.attacker:HasTag("player") then
            local x,y,z = inst.Transform:GetWorldPosition()
            local ents = TheSim:FindEntities(x, 0, z, 20, {"player"}, {"playerghost"})
            for i, v in pairs(ents) do
                if v and v.components.health and not v.components.health:IsDead() and not v.components.health:IsInvincible() and v.medal_canTread then
                    try_sinkplayerinoeacn(v)
                end
            end
            inst.sinkplayer2hm = true
            inst:DoTaskInTime(1, function() inst.sinkplayer2hm = nil end)
        end
    end

    AddPrefabPostInit("crabking", function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("attacked", onattacked2hm)
    end)

    AddStategraphPostInit("wilson", function(sg)
        if sg.states and sg.states.sink and sg.states.sink.onexit then
            local oldonexit = sg.states.sink.onexit
            sg.states.sink.onexit = function(inst, ...)
                oldonexit(inst, ...)
                if inst.sinkbycrabking2hm and inst.medal_canTread ~= false then
                    inst.medal_canTread = true
                end
                if inst.sinkbycrabking2hm then inst.sinkbycrabking2hm = nil end
            end
        end
        if sg.states and sg.states.sink_fast and sg.states.sink_fast.onexit then
            local oldonexit = sg.states.sink_fast.onexit
            sg.states.sink_fast.onexit = function(inst, ...)
                oldonexit(inst, ...)
                if inst.sinkbycrabking2hm and inst.medal_canTread ~= false then
                    inst.medal_canTread = true
                end
                if inst.sinkbycrabking2hm then inst.sinkbycrabking2hm = nil end
            end
        end
    end)
end

-- 削弱妥协粗炮弹
if not ModManager:GetMod("workshop-2039181790") then return end
-- 帝王蟹驱散附近的蒸腾海域
local function clearboilingwater(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 16, {"CLASSIFIED"})
    for index, ent in ipairs(ents) do if ent and ent:IsValid() and ent.prefab == "boiling_water_spawner" then ent:DoTaskInTime(0, ent:Remove()) end end
end
-- 帝王蟹释放冰冻
local function startfeeze(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local fx = SpawnPrefab("crabking_feeze2hm")
    fx.crab = inst
    fx.Transform:SetPosition(x, y, z)
    local scale = 0.75 + Remap(inst.gemcount.blue or 0, 0, 9, 0, 1.55)
    fx.Transform:SetScale(scale, scale, scale)
    inst.SoundEmitter:PlaySound("hookline_2/creatures/boss/crabking/magic_LP", "crabmagic")
    clearboilingwater(inst)
end
-- 蒸腾海域会被海浪吹走,帝王蟹检测到就会释放冰霜领域
local function checkcrabkingfreeze(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 16, nil, nil, {"crabking_spellgenerator", "CLASSIFIED", "crabking"})
    for index, ent in ipairs(ents) do
        if ent and ent:IsValid() then
            if ent.prefab == "crabking_feeze2hm" or (ent.prefab == "boiling_water_spawner" and ent ~= inst) then
                inst:Remove()
            elseif ent.prefab == "crabking" and ent:HasTag("hostile") and not ent.components.timer:TimerExists("casting_timer2hm") then
                ent.components.timer:StartTimer("casting_timer2hm", (TUNING.CRABKING_CAST_TIME_FREEZE - math.floor((ent.gemcount.yellow or 0) / 2)) * 2)
                startfeeze(ent)
            end
        end
    end
end
AddPrefabPostInit("boiling_water_spawner", function(inst)
    if not TheWorld.ismastersim then return end
    if not inst.components.inventoryitem then
        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem.canbepickedup = false
        inst.components.inventoryitem.pushlandedevents = false
    end
    inst:DoTaskInTime(0, checkcrabkingfreeze)
end)
