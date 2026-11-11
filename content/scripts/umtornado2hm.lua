-- Reviewed UM movement bodies; keep movement, lightning and pulling timings.
-- Only the cancelled/recreated weather-expiry timer is replaced by a deadline.
local M = {}
local function RefreshWeather(target)
    target:AddTag("under_the_weather")
    target.um_tornado_weatheruntil2hm = GetTime() + 1
    if target.um_tornado_weathertask == nil then
        target.um_tornado_weathertask = target:DoTaskInTime(1, M.ExpireWeather)
    end
end
function M.ExpireWeather(target)
    local remaining = (target.um_tornado_weatheruntil2hm or 0) - GetTime()
    if remaining > 0 then
        target.um_tornado_weathertask = target:DoTaskInTime(remaining, M.ExpireWeather)
    else
        target.um_tornado_weathertask = nil
        target.um_tornado_weatheruntil2hm = nil
        target:RemoveTag("under_the_weather")
    end
end

M["77375e3b:04cc5c3f:5144"] = function(values, globals)
    local config = values.config
    local getrandomposition = values.getrandomposition
    local teleport_continue = values.teleport_continue
local function TornadoTask(inst)
    if inst.startmoving then
        local x, y, z = inst.Transform:GetWorldPosition()
        local destination = TheSim:FindFirstEntityWithTag("um_tornado_destination")
        local players = TheSim:FindEntities(x, y, z, 300, nil, { "playerghost" }, { "player", "um_windturbine" })

        if math.random() > 0.99 and config ~= "minimal" then
            local _x, _y, _z = x + math.random(-150, 150), 0, z + math.random(-150, 150)

            if not IsUnderRainDomeAtXZ(_x, _z) then
                local lightning = SpawnPrefab("hound_lightning")

                lightning.Transform:SetPosition(_x, _y, _z)
                lightning.NoTags = { "INLIMBO", "shadow", "structure", "wall", "companion", "abigail", "bird", "prey" }
                lightning.Delay = 1.25 + math.random() / 2
            end
        end

        for k, v in pairs(players) do
            local px, py, pz = v.Transform:GetWorldPosition()
            if v:HasTag("player") or v:HasTag("um_windturbine") then
                RefreshWeather(v)
            end
            if not IsUnderRainDomeAtXZ(px, pz) then
                if not v:HasTag("um_windturbine") then
                    local rand = math.random()
                    local px, py, pz = v.Transform:GetWorldPosition()
                    if (v.prefab == "wes" and rand > 0.95 or rand > 0.99) then
                        local lightning_targeted = SpawnPrefab("hound_lightning")
                        lightning_targeted.Transform:SetPosition(px + math.random(-5, 5), 0, pz + math.random(-5, 5))
                        lightning_targeted.NoTags = { "INLIMBO", "shadow", "structure", "wall", "companion", "abigail", "bird",
                            "prey" }
                        lightning_targeted.Delay = 1.5
                    end

                    if v ~= nil and v:IsValid() and v:HasTag("player") and v.sg ~= nil and not v.sg:HasStateTag("gotgrabbed") and v:GetDistanceSqToInst(inst) < 300 or v.prefab ~= "bullkelp_beachedroot" and v.components.inventoryitem ~= nil and v:GetDistanceSqToInst(inst) < 600 and not v:HasTag("tornado_nosucky") or v.components.oceanfishable ~= nil and not v:HasTag("INLIMBO") then
                        local hat = v.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)

                        if hat ~= nil and not hat:HasTag("gotgrabbed") then
                            hat:AddTag("tornado_nosucky")
                            hat:AddTag("gotgrabbed")

                            hat:DoTaskInTime(1.5, function(inst)
                                hat:RemoveTag("tornado_nosucky")
                            end)

                            hat:DoTaskInTime(3.5, function(inst)
                                hat:RemoveTag("gotgrabbed")
                            end)

                            v.SoundEmitter:PlaySound("dontstarve/common/tool_slip")
                            v.components.inventory:DropItem(hat, true, true)
                            if hat.Physics ~= nil then
                                local x, y, z = hat.Transform:GetWorldPosition()
                                hat.Physics:Teleport(x, .8, z)

                                local angle = (math.random() * 20 - 10) * DEGREES
                                if inst ~= nil and inst:IsValid() then
                                    x, y, z = v.Transform:GetWorldPosition()
                                    local x1, y1, z1 = inst.Transform:GetWorldPosition()
                                    angle = angle + (
                                        (x1 == x and z1 == z and math.random() * 2 * PI) or
                                        math.atan2(z1 - z, x1 - x)
                                    )
                                else
                                    angle = angle + math.random() * 2 * PI
                                end
                                local speed = 3 + math.random() * 2
                                hat.Physics:SetVel(math.cos(angle) * speed, 10, math.sin(angle) * speed)
                            end
                        end

                        local rad = math.rad(v:GetAngleToPoint(x, y, z))
                        local velx = math.cos(rad)
                        local velz = -math.sin(rad)

                        local multiplierplayer = inst:GetDistanceSqToPoint(px, py, pz)

                        multiplierplayer = multiplierplayer / 60

                        if multiplierplayer < .4 then
                            multiplierplayer = .4

                            if v.components.health ~= nil and not v.components.health:IsDead() and v.sg ~= nil and not v.sg:HasStateTag("nointerrupt") and not v.components.health:IsInvincible() and v:HasTag("player") then
                                local locpos = getrandomposition(v)
                                v.sg:GoToState("um_tornado_teleport")
                                v.sg.statemem.teleport_task = v:DoTaskInTime(3,
                                    function() teleport_continue(v, locpos, inst) end)
                            end
                        end

                        local dx, dy, dz = px + (((.1 * 5) * velx) / multiplierplayer) * inst.Transform:GetScale(), 0,
                            pz + (((.1 * 5) * velz) / multiplierplayer) * inst.Transform:GetScale()

                        local ground = TheWorld.Map:IsOceanTileAtPoint(dx, dy, dz) -- changed to IsOceanTile for better ocean support, don't want tornado scuking things into the void.
                        local boat = TheWorld.Map:GetPlatformAtPoint(dx, dz)
                        local p_ground = TheWorld.Map:IsOceanTileAtPoint(px, py, pz)

                        if dx ~= nil and (ground == p_ground or boat) then
                            v.Transform:SetPosition(dx, dy, dz)
                        end
                    end
                end
            end
        end

        if destination ~= nil then
            local x_dest, y_dest, z_dest = destination.Transform:GetWorldPosition()
            local dest_rad = math.rad(inst:GetAngleToPoint(x_dest, y_dest, z_dest) + inst.danumber)
            local dest_velx = math.cos(dest_rad)
            local dest_velz = -math.sin(dest_rad)

            local x_dest2, y_dest2, z_dest2 = x + ((.1 * 3) * dest_velx), 0, z + ((.1 * 3) * dest_velz)

            if x_dest2 ~= nil then
                inst.Transform:SetPosition(x_dest2, y_dest2, z_dest2)
            end

            local ocean_anim = TheWorld.Map:IsOceanTileAtPoint(x_dest2, 0, z_dest2)
            local ground_anim = TheWorld.Map:IsPassableAtPoint(x_dest2, 0, z_dest2)

            if inst.persists and (destination:IsValid() and inst:GetDistanceSqToInst(destination) < 50) --[[or (not TheWorld.Map:IsPassableAtPoint(x, 0, z) and not TheWorld.Map:IsOceanAtPoint(x, 0, z)))]] then
                inst.AnimState:PlayAnimation("tornado_pst", false)

                inst:ListenForEvent("animover", function()
                    inst.startmoving = false


                    local inv = TheWorld.components.garbagepatch_manager:GetInventory()
                    inst.components.inventory:TransferInventory(inv)

                    TheWorld.components.garbagepatch_manager:SpawnPatch()
                    if destination ~= nil then
                        destination:Remove()
                    end

                    inst:Remove()
                end)

                inst.persists = false

                if destination ~= nil then
                    destination.persists = false
                end
            end
        else
            if inst.persists then
                inst.AnimState:PlayAnimation("tornado_pst", false)

                inst:ListenForEvent("animover", function()
                    for k, v in ipairs(inst.components.inventory.itemslots) do
                        local item = inst.components.inventory:RemoveItem(v, true)
                        local pos = getrandomposition(inst)
                        item.Transform:SetPosition(pos.x + math.random(-8, 8), pos.y, pos.z + math.random(-8, 8))
                    end

                    inst.startmoving = false

                    inst:Remove()
                end)

                inst.persists = false
            end
        end

        if inst.whirlpool == nil and TheWorld.Map:IsOceanAtPoint(inst.Transform:GetWorldPosition()) and not TestForIA() then
            inst.whirlpool = SpawnPrefab("um_whirlpool")
            inst.whirlpool.entity:SetParent(inst.entity)
            inst.whirlpool.Transform:SetPosition(0, 0, 0)
            inst.whirlpool.Transform:SetScale(2, 2, 2)
        elseif inst.whirlpool ~= nil and not TheWorld.Map:IsOceanAtPoint(inst.Transform:GetWorldPosition()) then
            inst.whirlpool.components.timer:StartTimer("kill_whirlpool", 1)
            inst.whirlpool = nil
        end
    end
end
    setfenv(TornadoTask, globals)
    return TornadoTask
end

M["5f939fb7:49d4bfe3:4547"] = function(values, globals)
    local config = values.config
    local HOUND_LIGHNTING_CANT_TAGS = values.HOUND_LIGHNTING_CANT_TAGS
    local getrandomposition = values.getrandomposition
    local teleport_continue = values.teleport_continue
local function TornadoTask(inst)
    if inst.startmoving then
        local x, y, z = inst.Transform:GetWorldPosition()
        local destination = TheSim:FindFirstEntityWithTag("um_tornado_destination")
        local players = TheSim:FindEntities(x, y, z, 300, nil, {"playerghost"}, {"player", "um_windturbine"})

        if math.random() > 0.99 and config ~= "minimal" then
            local _x, _y, _z = x + math.random(-150, 150), 0, z + math.random(-150, 150)

            if not IsUnderRainDomeAtXZ(_x, _z) then
                UMCommonFns.SpawnHoundLightning(inst, {pos = {x = _x, z = _z}, delay = 1.25 + math.random() / 2, canttags = HOUND_LIGHNTING_CANT_TAGS})
            end
        end

        for k, v in pairs(players) do
            local px, py, pz = v.Transform:GetWorldPosition()
            if v:HasTag("player") or v:HasTag("um_windturbine") then
                RefreshWeather(v)
            end
            if not IsUnderRainDomeAtXZ(px, pz) then
                if not v:HasTag("um_windturbine") then
                    local rand = math.random()
                    local px, py, pz = v.Transform:GetWorldPosition()
                    if (v.prefab == "wes" and rand > 0.95 or rand > 0.99) then
                        UMCommonFns.SpawnHoundLightning(inst, {pos = {x = px + math.random(-5, 5), z = pz + math.random(-5, 5)}, delay = 1.5, canttags = HOUND_LIGHNTING_CANT_TAGS})
                    end

                    if v ~= nil and v:IsValid() and v:HasTag("player") and v.sg ~= nil and not v.sg:HasStateTag("gotgrabbed") and v:GetDistanceSqToInst(inst) < 300 or v.prefab ~= "bullkelp_beachedroot" and v.components.inventoryitem ~= nil and v:GetDistanceSqToInst(inst) < 600 and not v:HasTag("tornado_nosucky") or v.components.oceanfishable ~= nil and not v:HasTag("INLIMBO") then
                        local hat = v.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)

                        if hat ~= nil and not hat:HasTag("gotgrabbed") then
                            hat:AddTag("tornado_nosucky")
                            hat:AddTag("gotgrabbed")

                            hat:DoTaskInTime(1.5, function(inst)
                                hat:RemoveTag("tornado_nosucky")
                            end)

                            hat:DoTaskInTime(3.5, function(inst)
                                hat:RemoveTag("gotgrabbed")
                            end)

                            v.SoundEmitter:PlaySound("dontstarve/common/tool_slip")
                            v.components.inventory:DropItem(hat, true, true)
                            if hat.Physics ~= nil then
                                local x, y, z = hat.Transform:GetWorldPosition()
                                hat.Physics:Teleport(x, .8, z)

                                local angle = (math.random() * 20 - 10) * DEGREES
                                if inst ~= nil and inst:IsValid() then
                                    x, y, z = v.Transform:GetWorldPosition()
                                    local x1, y1, z1 = inst.Transform:GetWorldPosition()
                                    angle = angle + (
                                        (x1 == x and z1 == z and math.random() * 2 * PI) or
                                        math.atan2(z1 - z, x1 - x)
                                    )
                                else
                                    angle = angle + math.random() * 2 * PI
                                end
                                local speed = 3 + math.random() * 2
                                hat.Physics:SetVel(math.cos(angle) * speed, 10, math.sin(angle) * speed)
                            end
                        end

                        local rad = math.rad(v:GetAngleToPoint(x, y, z))
                        local velx = math.cos(rad)
                        local velz = -math.sin(rad)

                        local multiplierplayer = inst:GetDistanceSqToPoint(px, py, pz)

                        multiplierplayer = multiplierplayer / 60

                        if multiplierplayer < .4 then
                            multiplierplayer = .4

                            if v.components.health ~= nil and not v.components.health:IsDead() and v.sg ~= nil and not v.sg:HasStateTag("nointerrupt") and not v.components.health:IsInvincible() and v:HasTag("player") then
                                local locpos = getrandomposition(v)
                                v.sg:GoToState("um_tornado_teleport")
                                v.sg.statemem.teleport_task = v:DoTaskInTime(3,
                                    function() teleport_continue(v, locpos, inst) end)
                            end
                        end

                        local dx, dy, dz = px + (((.1 * 5) * velx) / multiplierplayer) * inst.Transform:GetScale(), 0,
                            pz + (((.1 * 5) * velz) / multiplierplayer) * inst.Transform:GetScale()

                        local ground = TheWorld.Map:IsOceanTileAtPoint(dx, dy, dz) -- changed to IsOceanTile for better ocean support, don't want tornado scuking things into the void.
                        local boat = TheWorld.Map:GetPlatformAtPoint(dx, dz)
                        local p_ground = TheWorld.Map:IsOceanTileAtPoint(px, py, pz)

                        if dx ~= nil and (ground == p_ground or boat) then
                            v.Transform:SetPosition(dx, dy, dz)
                        end
                    end
                end
            end
        end

        if destination ~= nil then
            local x_dest, y_dest, z_dest = destination.Transform:GetWorldPosition()
            local dest_rad = math.rad(inst:GetAngleToPoint(x_dest, y_dest, z_dest) + inst.danumber)
            local dest_velx = math.cos(dest_rad)
            local dest_velz = -math.sin(dest_rad)

            local x_dest2, y_dest2, z_dest2 = x + ((.1 * 3) * dest_velx), 0, z + ((.1 * 3) * dest_velz)

            if x_dest2 ~= nil then
                inst.Transform:SetPosition(x_dest2, y_dest2, z_dest2)
            end

            local ocean_anim = TheWorld.Map:IsOceanTileAtPoint(x_dest2, 0, z_dest2)
            local ground_anim = TheWorld.Map:IsPassableAtPoint(x_dest2, 0, z_dest2)

            if inst.persists and (destination:IsValid() and inst:GetDistanceSqToInst(destination) < 50) --[[or (not TheWorld.Map:IsPassableAtPoint(x, 0, z) and not TheWorld.Map:IsOceanAtPoint(x, 0, z)))]] then
                inst.AnimState:PlayAnimation("tornado_pst", false)

                inst:ListenForEvent("animover", function()
                    inst.startmoving = false


                    if destination ~= nil then
                        destination:Remove()
                    end

                    inst:Remove()
                end)

                inst.persists = false

                if destination ~= nil then
                    destination.persists = false
                end
            end
        else
            if inst.persists then
                inst.AnimState:PlayAnimation("tornado_pst", false)

                inst:ListenForEvent("animover", function()
                    inst.startmoving = false
                    inst:Remove()
                end)

                inst.persists = false
            end
        end

        if inst.whirlpool == nil and TheWorld.Map:IsOceanAtPoint(inst.Transform:GetWorldPosition()) and not IsIslandOrVolcanoWorld() then
            inst.whirlpool = SpawnPrefab("um_whirlpool")
            inst.whirlpool.entity:SetParent(inst.entity)
            inst.whirlpool.Transform:SetPosition(0, 0, 0)
            inst.whirlpool.Transform:SetScale(2, 2, 2)
        elseif inst.whirlpool ~= nil and not TheWorld.Map:IsOceanAtPoint(inst.Transform:GetWorldPosition()) then
            inst.whirlpool.components.timer:StartTimer("kill_whirlpool", 1)
            inst.whirlpool = nil
        end
    end
end
    setfenv(TornadoTask, globals)
    return TornadoTask
end

return M
