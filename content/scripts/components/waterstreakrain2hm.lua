--------------------------------------------------------------------------
--[[ WaterStreakRain class definition ]] --------------------------------------------------------------------------
return Class(function(self, inst)

    assert(TheWorld.ismastersim, "WaterStreakRain should not exist on client")

    --------------------------------------------------------------------------
    --[[ Member variables ]]
    --------------------------------------------------------------------------

    -- Public
    self.inst = inst
    self.enablesnow = false
    self.enablerain = false
    self.enablesand = false
    -- Private
    local _activeplayers = {}
    local _scheduledtasks = {}
    local _enable = false
    local _spawntime = {min = 0.25, max = 1}
    local _updating = false
    local _chance = 0.25

    --------------------------------------------------------------------------
    --[[ Private member functions ]]
    --------------------------------------------------------------------------
    local function GetSpawnPoint(pt)
        local theta = math.random() * 2 * PI
        local radius = math.random() * (self.quakering2hm and 15 or 20)
        local offset = Vector3(radius * math.cos(theta), 0, -radius * math.sin(theta))
        return pt + offset
    end
    -- 坠落水球或雪球
    local function bouncethrow2hmfn(firstprojectile, prefab, addcoldness, addwetness, temperaturereduction, extinguish, nexty)
        local spawn_point = firstprojectile:GetPosition()
        spawn_point.y = 0
        local projectile = SpawnPrefab(prefab)
        projectile:AddTag("DynamicShadow2hm")
        local wateryprotection = projectile.components.wateryprotection
        for i = #wateryprotection.ignoretags, 1, -1 do
            if wateryprotection.ignoretags[i] == "player" then
                table.remove(wateryprotection.ignoretags, i)
                break
            end
        end
        wateryprotection:AddIgnoreTag("playerghost")
        wateryprotection.addcoldness = addcoldness
        wateryprotection.addwetness = addwetness
        wateryprotection.temperaturereduction = temperaturereduction
        wateryprotection.extinguish = true
        if not extinguish then wateryprotection:AddIgnoreTag("campfire2hm") end
        wateryprotection:AddIgnoreTag("nightlight2hm")
        projectile.components.complexprojectile:SetHorizontalSpeed(4)
        projectile.Transform:SetPosition(spawn_point.x, nexty or 0.1, spawn_point.z)
        local targetpos = Vector3(spawn_point.x, 0, spawn_point.z)
        if TheWorld.components.worldwind then
            local angle = firstprojectile.Transform:GetRotation() or TheWorld.components.worldwind:GetWindAngle()
            projectile.Transform:SetRotation(angle)
            local radius = TheWorld.components.worldwind:GetWindVelocity() * 6
            local theta = math.rad(angle)
            local offset = Vector3(radius * math.cos(theta), 0, -radius * math.sin(theta))
            targetpos = spawn_point + offset
        end
        projectile.components.complexprojectile:Launch(targetpos, projectile, projectile)
        return projectile
    end
    local function SpawnWaterStreak(spawn_point, prefab, addcoldness, addwetness, temperaturereduction, extinguish, nexty)
        spawn_point.y = 0
        local projectile = SpawnPrefab(prefab)
        projectile:AddTag("DynamicShadow2hm")
        local wateryprotection = projectile.components.wateryprotection
        for i = #wateryprotection.ignoretags, 1, -1 do
            if wateryprotection.ignoretags[i] == "player" then
                table.remove(wateryprotection.ignoretags, i)
                break
            end
        end
        wateryprotection:AddIgnoreTag("playerghost")
        wateryprotection.addcoldness = addcoldness
        wateryprotection.addwetness = addwetness
        wateryprotection.temperaturereduction = temperaturereduction
        wateryprotection.extinguish = true
        if not extinguish then wateryprotection:AddIgnoreTag("campfire") end
        wateryprotection:AddIgnoreTag("nightlight2hm")
        projectile.components.complexprojectile:SetHorizontalSpeed(1)
        local targetpos = Vector3(spawn_point.x, 0, spawn_point.z)
        if TheWorld.components.worldwind then
            local angle = TheWorld.components.worldwind:GetWindAngle()
            projectile.Transform:SetRotation(angle)
            local radius = TheWorld.components.worldwind:GetWindVelocity() * 3 * GetRandomMinMax(1, 2)
            local theta = math.rad(angle)
            local offset = Vector3(radius * math.cos(theta), 0, -radius * math.sin(theta))
            spawn_point = spawn_point - offset
        end
        projectile.Transform:SetPosition(spawn_point.x, 24, spawn_point.z)
        if math.random() < 0.15 then
            projectile.bouncethrow2hm = 2
            projectile.bouncethrow2hmfn = function()
                return bouncethrow2hmfn(projectile, prefab, addcoldness, addwetness, temperaturereduction, extinguish, nexty)
            end
        end
        projectile.components.complexprojectile:Launch(targetpos, projectile, projectile)
        return projectile
    end
    -- 坠落树枝草或石头
    local function UpdateShadowSize(shadow, height)
        local scaleFactor = Lerp(.5, 1.5, height / 35)
        shadow.Transform:SetScale(scaleFactor, scaleFactor, scaleFactor)
    end
    local _defaultdebrisdata = {
        {weight = 0.8, loot = {"flint", "flint", "twigs", "twigs", "cutgrass", "cutgrass", "rocks", "seeds"}},
        {weight = 0.2, loot = {"goldnugget", "nitre"}}
    }
    local _oceandebrisdata = {{weight = 0.8, loot = {"waterstreak_projectile"}}, {weight = 0.2, loot = {"kelp", "driftwood_log"}}}
    local _tagdebrisdata = {lunacyarea = {{weight = 0.6, loot = {"rocks", "flint", "moonglass"}}, {weight = 0.4, loot = {"rock_avocado_fruit"}}}}
    local function GetDebris(spawn_point, node_data)
        local x, y, z = spawn_point:Get()
        local node_index = TheWorld.Map:GetNodeIdAtPoint(x, y, z)
        local node_data = TheWorld.topology.nodes[node_index]
        local debris_table = nil
        if TheWorld.has_ocean and not TheWorld.Map:IsVisualGroundAtPoint(x, y, z) then
            debris_table = _oceandebrisdata
        elseif node_data == nil or node_data.tags == nil then
            debris_table = _defaultdebrisdata
        else
            local tag_found = false
            for _, tag in ipairs(node_data.tags) do
                local tag_table = _tagdebrisdata[tag]
                if tag_table ~= nil then
                    tag_found = true
                    debris_table = tag_table
                    break
                end
            end
            if not tag_found then debris_table = _defaultdebrisdata end
        end
        local val = math.random()
        local droptable = nil
        for i, v in ipairs(debris_table) do
            if val < v.weight then
                droptable = v.loot
                break
            else
                val = val - v.weight
            end
        end
        local todrop = nil
        if droptable ~= nil then
            while todrop == nil and #droptable > 0 do
                local index = math.random(1, #droptable)
                todrop = droptable[index]
            end
        end
        return todrop
    end
    local function _BreakDebris(debris)
        local x, y, z = debris.Transform:GetWorldPosition()
        if debris.prefab == "waterstreak_projectile" then
            SpawnPrefab("waterstreak_burst").Transform:SetPosition(x, 0, z)
            if inst.components.wateryprotection then
                local wateryprotection = inst.components.wateryprotection
                for i = #wateryprotection.ignoretags, 1, -1 do
                    if wateryprotection.ignoretags[i] == "player" then
                        table.remove(wateryprotection.ignoretags, i)
                        break
                    end
                end
                wateryprotection:AddIgnoreTag("playerghost")
                wateryprotection:AddIgnoreTag("nightlight2hm")
                wateryprotection:SpreadProtection(inst, TUNING.WATERSTREAK_AOE_DIST)
            end
        else
            SpawnPrefab("ground_chunks_breaking").Transform:SetPosition(x, 0, z)
        end
        if not TheWorld.Map:IsPassableAtPoint(x, y, z) then SpawnPrefab("ocean_splash_small2").Transform:SetPosition(x, 0, z) end
        debris:Remove()
    end
    local SMASHABLE_TAGS = {"smashable", "quakedebris", "_combat"}
    local NON_SMASHABLE_TAGS = {"INLIMBO", "playerghost", "irreplaceable", "outofreach"}
    local DENSITYRADIUS = 5
    local QUAKEDEBRIS_CANT_TAGS = {"quakedebris"}
    local QUAKEDEBRIS_ONEOF_TAGS = {"INLIMBO"}
    local function delayremoveshadow(debris)
        if debris.shadow then
            debris.shadow:Remove()
            debris.shadow = nil
        end
    end
    local function _GroundDetectionUpdate(debris)
        local x, y, z = debris.Transform:GetWorldPosition()
        if y <= .2 then
            local softbounce = false
            local ents = TheSim:FindEntities(x, 0, z, 2, nil, NON_SMASHABLE_TAGS, SMASHABLE_TAGS)
            for i, v in ipairs(ents) do
                if v ~= debris and v:IsValid() and not v:IsInLimbo() then
                    softbounce = true
                    if v:HasTag("quakedebris") then
                        local vx, vy, vz = v.Transform:GetWorldPosition()
                        SpawnPrefab("ground_chunks_breaking").Transform:SetPosition(vx, 0, vz)
                        v:Remove()
                    elseif v.components.combat ~= nil and not (v:HasTag("epic") or v:HasTag("wall")) then
                        v.components.combat:GetAttacked_Internal(debris, debris.debrisdmg2hm or 5, nil)
                    end
                end
            end
            debris.Physics:SetDamping(.9)
            if softbounce then
                local speed = 3.2 + math.random()
                local angle = math.random() * 2 * PI
                debris.Physics:SetMotorVel(0, 0, 0)
                debris.Physics:SetVel(speed * math.cos(angle), speed * 2.3, speed * math.sin(angle))
            end
            debris.updatetask:Cancel()
            debris.updatetask = nil
            if debris.prefab == "waterstreak_projectile" then
                _BreakDebris(debris)
            elseif not (math.random() < .75 or #TheSim:FindEntities(x, 0, y, DENSITYRADIUS, nil, QUAKEDEBRIS_CANT_TAGS, QUAKEDEBRIS_ONEOF_TAGS) > 1) then
                debris.persists = true
                debris.entity:SetCanSleep(true)
                if debris.components.inventoryitem ~= nil and debris._restorepickup then
                    debris._restorepickup = nil
                    debris.components.inventoryitem.canbepickedup = true
                end
                debris:DoTaskInTime(softbounce and .4 or .6, delayremoveshadow)
            elseif debris:GetTimeAlive() < 1.5 then
                debris:DoTaskInTime(softbounce and .4 or .6, _BreakDebris)
            else
                _BreakDebris(debris)
            end
        elseif debris:GetTimeAlive() < 3 then
            if y < 2 then debris.Physics:SetMotorVel(0, 0, 0) end
            UpdateShadowSize(debris.shadow, y)
        elseif debris:IsInLimbo() then
            debris.persists = true
            debris.entity:SetCanSleep(true)
            if debris.shadow then
                debris.shadow:Remove()
                debris.shadow = nil
            end
            debris.updatetask:Cancel()
            debris.updatetask = nil
            if debris.components.inventoryitem ~= nil and debris._restorepickup then
                debris._restorepickup = nil
                debris.components.inventoryitem.canbepickedup = true
            end
        else
            _BreakDebris(debris)
        end
    end
    local function OnRemoveDebris(debris) debris.shadow:Remove() end
    local function SpawnDebris(spawn_point)
        local prefab = GetDebris(spawn_point)
        if not prefab then return end
        local debris = SpawnPrefab(prefab)
        if debris ~= nil then
            debris.debrisdmg2hm = 10
            if not debris:HasTag("quakedebris") then
                debris:AddTag("quakedebris")
                debris.debrisdmg2hm = 5
            end
            debris.entity:SetCanSleep(false)
            debris.persists = false
            if debris.components.inventoryitem ~= nil and debris.components.inventoryitem.canbepickedup then
                debris.components.inventoryitem.canbepickedup = false
                debris._restorepickup = true
            end
            if math.random() < .5 then debris.Transform:SetRotation(180) end
            debris.Physics:Teleport(spawn_point.x, 35, spawn_point.z)
            debris.shadow = SpawnPrefab("warningshadow")
            debris.shadow:ListenForEvent("onremove", OnRemoveDebris, debris)
            debris.shadow.Transform:SetPosition(spawn_point.x, 0, spawn_point.z)
            UpdateShadowSize(debris.shadow, 35)
            debris.updatetask = debris:DoPeriodicTask(FRAMES, _GroundDetectionUpdate)
            debris:PushEvent("startfalling")
        end
        return debris
    end
    -- 生成火焰风滚草
    local function SpawnFireTumbleweed(inst, self)
        if not (self and self.quakering2hm) then return end
        local x, y, z = inst.Transform:GetWorldPosition()
        local newtumbleweed = SpawnPrefab("mod_hardmode_tumbleweed")
        newtumbleweed.Transform:SetPosition(x - math.cos(newtumbleweed.angle) * 30, y, z + math.sin(newtumbleweed.angle) * 30)
    end

    -- 循环生成
    local function SpawnWaterStreakForPlayer(player, reschedule)
        if _enable and (self.raining2hm or self.snowing2hm or self.quakering2hm) then
            local pt = player:GetPosition()
            local spawn_point = GetSpawnPoint(pt)
            if spawn_point ~= nil then
                if self.snowing2hm then
                    local rate = TheWorld.state.precipitationrate
                    SpawnWaterStreak(spawn_point, "snowball", rate * 0.5, rate * 0.5, rate * 3, math.random() < (rate * 0.15), 0.1)
                elseif self.raining2hm then
                    local rate = TheWorld.state.precipitationrate
                    SpawnWaterStreak(spawn_point, "waterstreak_projectile", 0, rate * 10, rate * 0.5, math.random() < (rate * 0.35), 2)
                elseif self.quakering2hm then
                    SpawnDebris(spawn_point)
                    if TheWorld.state.issummer and not player.firetumbleweedtask2hm then
                        player.firetumbleweedtask2hm = player:DoTaskInTime(math.random(30) + 15, SpawnFireTumbleweed, self)
                    end
                end
            end
        end
        _scheduledtasks[player] = nil
        reschedule(player)
    end
    local function ScheduleSpawn(player, initialspawn)
        if _scheduledtasks[player] == nil and _spawntime ~= nil then
            local time = GetRandomMinMax(_spawntime.min, _spawntime.max) +
                             math.clamp(0, self.quakering2hm and TheWorld.state.precipitationrate or (1 - TheWorld.state.precipitationrate), 1)
            if self.quakering2hm then time = math.max(time * 3, 1.25) end
            if player.components.sheltered and player.components.sheltered.sheltered and
                (player.components.sheltered.level2hm or player.components.sheltered.sheltered_level or 1) > 1 then time = time * 2 end
            _scheduledtasks[player] = player:DoTaskInTime(time, SpawnWaterStreakForPlayer, ScheduleSpawn)
        end
    end
    local function CancelSpawn(player)
        if _scheduledtasks[player] ~= nil then
            _scheduledtasks[player]:Cancel()
            _scheduledtasks[player] = nil
        end
        if player.firetumbleweedtask2hm then player.firetumbleweedtask2hm = nil end
    end

    local function endsandtask(inst)
        if inst.endsandquaker2hmtask then
            inst.endsandquaker2hmtask:Cancel()
            inst.endsandquaker2hmtask = nil
        end
        if inst.endsand2hmtask then inst.endsand2hmtask = nil end
        if _enable and self.sanding2hm then
            self.disablesanding2hm = true
            self:Enable(false)
        end
    end
    local function endsandquakertask(inst)
        if inst.endsandquaker2hmtask then inst.endsandquaker2hmtask = nil end
        if self.quakering2hm then self.quakering2hm = false end
    end

    -- 刷新状态
    local function ToggleUpdate(force)
        local rain, snow, sand
        if _enable then
            self.raining2hm = self.enablerain and TheWorld.state.israining and not TheWorld.state.issnowing and TheWorld.state.precipitationrate >
                                  TUNING.FROG_RAIN_PRECIPITATION and TheWorld.state.moistureceil > TUNING.FROG_RAIN_MOISTURE
            self.snowing2hm = self.enablesnow and TheWorld.state.issnowing and TheWorld.state.precipitationrate > TUNING.FROG_RAIN_PRECIPITATION / 2 and
                                  TheWorld.state.moistureceil > TUNING.FROG_RAIN_MOISTURE / 2
            self.sanding2hm = self.enablesand and not self.disablesanding2hm and not TheWorld.state.israining and not TheWorld.state.issnowing and
                                  TheWorld.components.sandstorms ~= nil and TheWorld.state.precipitationrate < TUNING.FROG_RAIN_PRECIPITATION * 3 / 10
            if self.sanding2hm then
                if not inst.endsand2hmtask then inst.endsand2hmtask = inst:DoTaskInTime(math.random(60, 180), endsandtask) end
                self.quakering2hm = TheWorld.state.precipitationrate < TUNING.FROG_RAIN_PRECIPITATION / 5
                if self.quakering2hm then
                    if not inst.endsandquaker2hmtask then
                        inst.endsandquaker2hmtask = inst:DoTaskInTime(math.random(30, 120), endsandquakertask)
                    end
                end
            else
                self.quakering2hm = false
            end
        else
            self.raining2hm = false
            self.snowing2hm = false
            self.sanding2hm = false
            self.quakering2hm = false
        end
        if not self.sanding2hm and inst.endsand2hmtask then
            inst.endsand2hmtask:Cancel()
            inst.endsand2hmtask = nil
        end
        if not self.quakering2hm and inst.endsandquaker2hmtask then
            inst.endsandquaker2hmtask:Cancel()
            inst.endsandquaker2hmtask = nil
        end
        TUNING.worldsand2hm = self.sanding2hm
        if _enable and (self.raining2hm or self.snowing2hm or self.quakering2hm) then
            if not _updating then
                _updating = true
                for i, v in ipairs(_activeplayers) do ScheduleSpawn(v, true) end
            elseif force == true then
                for i, v in ipairs(_activeplayers) do
                    CancelSpawn(v)
                    ScheduleSpawn(v, true)
                end
            end
        elseif _updating then
            _updating = false
            for i, v in ipairs(_activeplayers) do CancelSpawn(v) end
        end
    end

    --------------------------------------------------------------------------
    --[[ Private event handlers ]]
    --------------------------------------------------------------------------

    local function OnIsRaining(inst)
        if POPULATING then return end
        local chance = (TheWorld.state.israining or TheWorld.state.issnowing or TheWorld.state.issummer) and _chance or 0
        _enable = math.random() < chance
        ToggleUpdate()
    end

    local function delaycheck(inst)
        if self.delaycyclestask2hm then self.delaycyclestask2hm = nil end
        if self.disablesanding2hm then self.disablesanding2hm = nil end
        local chance = (TheWorld.state.israining or TheWorld.state.issnowing) and _chance or
                           (_enable and inst.endsand2hmtask and 1 or
                               (TheWorld.state.issummer and _chance / 2 or (TheWorld.state.iswinter and 0 or _chance / 25)))
        _enable = math.random() < chance
        ToggleUpdate()
    end

    local function OnCycles(inst)
        if POPULATING then return end
        if not self.delaycyclestask2hm then self.delaycyclestask2hm = inst:DoTaskInTime(math.random(0, 360), delaycheck) end
    end

    local function OnPlayerJoined(src, player)
        for i, v in ipairs(_activeplayers) do if v == player then return end end
        table.insert(_activeplayers, player)
        if _updating then ScheduleSpawn(player, true) end
    end

    local function OnPlayerLeft(src, player)
        for i, v in ipairs(_activeplayers) do
            if v == player then
                CancelSpawn(player)
                table.remove(_activeplayers, i)
                return
            end
        end
    end

    --------------------------------------------------------------------------
    --[[ Initialization ]]
    --------------------------------------------------------------------------

    -- Initialize variables
    for i, v in ipairs(AllPlayers) do table.insert(_activeplayers, v) end

    -- Register events
    inst:WatchWorldState("israining", OnIsRaining)
    inst:WatchWorldState("issnowing", OnIsRaining)
    inst:WatchWorldState("cycles", OnCycles)
    inst:WatchWorldState("precipitationrate", ToggleUpdate)

    inst:ListenForEvent("ms_playerjoined", OnPlayerJoined, TheWorld)
    inst:ListenForEvent("ms_playerleft", OnPlayerLeft, TheWorld)

    ToggleUpdate(true)

    --------------------------------------------------------------------------
    --[[ Public member functions ]]
    --------------------------------------------------------------------------

    function self:Enable(status)
        if not status == not _enable then return end
        _enable = status ~= false
        ToggleUpdate(true)
    end

    function self:IsEnabled() return _enable end
    --------------------------------------------------------------------------
    --[[ Save/Load ]]
    --------------------------------------------------------------------------

    function self:OnSave() return {enable = _enable, delay = self.delaycyclestask2hm ~= nil} end

    function self:OnLoad(data)
        _enable = data.enable == true
        ToggleUpdate(true)
        if data.delay and not self.delaycyclestask2hm then self.delaycyclestask2hm = inst:DoTaskInTime(math.random(0, 120), delaycheck) end
    end

    --------------------------------------------------------------------------
    --[[ End ]]
    --------------------------------------------------------------------------

end)
