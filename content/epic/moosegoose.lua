-- AddStategraphPostInit("mossling",function (inst)
--     local spin_pre = sg.states.
-- end)

-- local SINKHOLD_BLOCKER_TAGS = {"hound_lightning"}
-- local function Zap(posx, posz)
--     --local projectile = SpawnPrefab("hound_lightning")
--     --projectile.Transform:SetPosition(posx, 0, posz)

--     local x = GetRandomWithVariance(posx, TUNING.ANTLION_SINKHOLE.RADIUS)
--     local z = GetRandomWithVariance(posz, TUNING.ANTLION_SINKHOLE.RADIUS)

--     local function IsValidSinkholePosition(offset)
--         local x1, z1 = x + offset.x, z + offset.z
--         if #TheSim:FindEntities(x1, 0, z1, TUNING.ANTLION_SINKHOLE.RADIUS * 1.9, SINKHOLD_BLOCKER_TAGS) > 0 then
--             return false
--         end
--         return true
--     end

--     local offset = Vector3(0, 0, 0)
--     offset =
--         IsValidSinkholePosition(offset) and offset or
--         FindValidPositionByFan(
--             math.random() * 2 * PI,
--             TUNING.ANTLION_SINKHOLE.RADIUS * 1.8 + math.random(),
--             9,
--             IsValidSinkholePosition
--         ) or
--         FindValidPositionByFan(
--             math.random() * 2 * PI,
--             TUNING.ANTLION_SINKHOLE.RADIUS * 2.9 + math.random(),
--             17,
--             IsValidSinkholePosition
--         ) or
--         FindValidPositionByFan(
--             math.random() * 2 * PI,
--             TUNING.ANTLION_SINKHOLE.RADIUS * 3.9 + math.random(),
--             17,
--             IsValidSinkholePosition
--         ) or
--         nil

--     if offset ~= nil then
--         local sinkhole = SpawnPrefab("hound_lightning")
--         sinkhole.NoTags = {"INLIMBO", "shadow", "hound", "houndfriend"}
--         sinkhole.Transform:SetPosition(x + offset.x, 0, z + offset.z)
--     end
-- end

-- local function LaunchProjectile(inst, targetpos)
--     local x, y, z = targetpos.Transform:GetWorldPosition()
--     inst:DoTaskInTime(
--         0,
--         function(inst)
--             Zap(x, z)
--         end
--     )
--     inst:DoTaskInTime(
--         0.4,
--         function(inst)
--             Zap(x, z)
--         end
--     )
--     inst:DoTaskInTime(
--         0.8,
--         function(inst)
--             Zap(x, z)
--         end
--     )
-- end

-- local function Charging(inst)
--     local x, y, z = inst.Transform:GetWorldPosition()

--     local x1 = x + math.random(-0.5, 0.5)
--     local z1 = z + math.random(-0.5, 0.5)

--     if math.random() >= 0.8 then
--         SpawnPrefab("electricchargedfx").Transform:SetPosition(x1, 0, z1)
--     end

--     SpawnPrefab("sparks").Transform:SetPosition(x1, 0 + 0.25 * math.random(), z1)
-- end

-- local function CancelCharge(inst)
--     if inst.task ~= nil then
--         inst.task:Cancel()
--         inst.task = nil
--     end
-- end

-- local function Charge(inst)
--     inst.task =
--         inst:DoPeriodicTask(
--         0.15,
--         function(inst)
--             Charging(inst)
--         end
--     )
-- end
