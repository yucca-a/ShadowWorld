local Guard = require("umcompatguard2hm")
local Profiles = require("umcompatprofiles2hm")
local M = {}

function M.Install(env, optional)
    local G = env.GLOBAL
    local statuses = {}
    local reported = {}
    G.TUNING.UM_COMPAT_STATUS2HM = statuses
    local function Status(id, applied, reason)
        local record = statuses[id] or {applied = false}
        record.applied = record.applied or applied
        record.skipped = record.skipped or not applied
        if reason then record.reason = reason end
        statuses[id] = record
        local key = id .. (applied and ":applied" or ":skipped")
        if reported[key] then return end
        reported[key] = true
        print("[ShadowWorld UM] " .. id .. ": " .. (applied and "applied" or "skipped") .. (reason and " (" .. reason .. ")" or ""))
    end
    local function Match(fn, id)
        local p = Profiles[id]
        return p and Guard.Match(fn, p.file, p.hashes) or false
    end
    local function Slot(root, name, id)
        local slot = Guard.Find(root, name)
        return slot and Match(slot.value, id) and slot or nil
    end
    local function Value(fn, name)
        local slot = Guard.Slot(fn, name)
        return slot and slot.value
    end
    local function Valid(inst) return inst ~= nil and inst:IsValid() end

    -- Correctness remains enabled when optional gameplay adjustments are off.
    env.AddPrefabPostInit("air_conditioner_cloud", function(inst)
        if not G.TheWorld.ismastersim then return end
        local prox = inst.components.playerprox
        local near = prox and prox.onnear
        local bite = Value(near, "bite")
        if not Match(near, "cloud_near") or type(bite) ~= "function" or type(inst.StopBrain) ~= "function" or
            not inst.components.timer or not inst.components.health then
            Status("air_conditioner_cloud", false, "upstream callback changed")
            return
        end
        prox:SetOnPlayerNear(function(inst, target)
            if Valid(target) and not target:HasTag("ac_smoke_host") then
                inst.Physics:Stop()
                inst.host = target
                inst:RemoveComponent("playerprox")
                inst.entity:SetParent(target.entity)
                inst.Transform:SetPosition(0, 0, 0)
                inst.components.timer:SetTimeLeft("die", 31.1)
                -- Sleeping entities legitimately have brainfn but no brain.
                -- StopBrain also prevents it restarting when the cloud wakes.
                inst:StopBrain("air_conditioner_host2hm")
                bite(inst)
                inst.bitetask = inst:DoPeriodicTask(1, bite)
            end
        end)
        Status("air_conditioner_cloud", true)
    end)

    env.AddPrefabPostInit("air_conditioner_smoke", function(inst)
        if not G.TheWorld.ismastersim then return end
        local prefab = G.Prefabs.air_conditioner_smoke
        if not prefab or not Match(prefab.fn, "smoke_constructor") or inst.OnEntitySleep then
            Status("air_conditioner_smoke", false, "upstream effect lifecycle changed")
            return
        end
        -- This is a one-shot animation, not the playable cloud or a resource.
        inst.persists = false
        inst.OnEntitySleep = inst.Remove
        local duration = inst.AnimState:GetCurrentAnimationLength()
        inst:DoTaskInTime((duration > 0 and duration or 1) + .5, inst.Remove)
        Status("air_conditioner_smoke", true)
    end)

    if not optional then return end

    env.AddComponentPostInit("locomotor", function(self)
        local old = self.OnUpdate
        if not Match(old, "thicket_update") then return end -- stable uses playerprox
        local check = Value(old, "ThicketCheck")
        local base = Value(old, "_OnUpdate")
        local excluded = Value(check, "cant_thicket")
        if not Match(check, "thicket_check") or type(base) ~= "function" or type(excluded) ~= "table" then
            Status("thicket_filter", false, "upstream dependencies changed")
            return
        end
        self.OnUpdate = function(self, ...)
            local inst = self.inst
            local health = inst.components.health
            if health and not health:IsDead() and not inst:HasAnyTag(excluded) then return old(self, ...) end
            return base(self, ...)
        end
        Status("thicket_filter", true)
    end)

    env.AddComponentPostInit("snowstormwatcher", function(self)
        if Match(self.OnUpdate, "watcher_update") and Match(self.UpdateSnowstormLevel, "watcher_level") and
            Match(self.UpdateSnowstormWalkSpeed, "watcher_speed") then
            self.OnUpdate = function(self)
                self:UpdateSnowstormLevel()
                self:StartSnowPileTask()
            end
            Status("snowstorm_duplicate_update", true)
        else
            Status("snowstorm_duplicate_update", false, "upstream update chain changed")
        end

        local slot = Slot(self.StartSnowPileTask, "SnowpileChance", "pile_chance")
        local try = self.TrySpawning or G.rawget(G, "TrySpawning")
        if not slot or not Match(try, "pile_try") then
            -- A shared upvalue may already have been patched by another player.
            if not statuses.snowpile_generation then Status("snowpile_generation", false, "upstream generation changed") end
            return
        end
        local beta = self.TrySpawning ~= nil
        local invalid = Value(slot.value, "INVALID_TILES")
        if type(invalid) ~= "table" then Status("snowpile_generation", false, "missing terrain rules"); return end
        local function Chance(inst, self)
            if G.TheWorld.state.iswinter and
                ((G.TheWorld.net and G.TheWorld.net:HasTag("snowstormstartnet")) or G.TheWorld:HasTag("snowstormstart")) then
                local x, y, z = self.inst.Transform:GetWorldPosition()
                local count = 0
                if beta then
                    for _, player in pairs(G.AllPlayers) do
                        if player:GetDistanceSqToPoint(x, y, z) <= 2500 then count = count + 1 end
                    end
                else
                    count = #G.TheSim:FindEntities(x, y, z, 50, nil, nil, {"player"})
                end
                local chance = math.random()
                if not G.IsUnderRainDomeAtXZ(x, z) then
                    if chance < .40 - count * .025 then
                        local px, pz = x + math.random(-20, 20), z + math.random(-20, 20)
                        local piles = G.TheSim:FindEntities(px, y, pz, 6, nil, nil, {"snowpileradius"})
                        local fire = G.TheSim:FindEntities(px, y, pz, 8, nil, nil, {"fire"})
                        if G.TheWorld.Map:IsPassableAtPoint(px, 0, pz, false, true) and #piles < 1 and #fire < 1 and
                            not invalid[G.TheWorld.Map:GetTileAtPoint(px, 0, pz)] and
                            #G.TheSim:FindEntities(px, 0, pz, 5, {"snowpileblocker"}) == 0 then
                            G.SpawnPrefab("snowpile").Transform:SetPosition(px, .05, pz)
                        end
                    else
                        -- The original eagerly searches structures even when
                        -- this branch will never use them. Keep its radius/rules.
                        local structures = G.TheSim:FindEntities(x, y, z, beta and 32 or 50, nil,
                            {"snowpiledin", "hive", "snowpileblocker"}, {"structure"})
                        for _, structure in ipairs(structures) do
                            if beta then try(self, structure) else try(structure) end
                        end
                    end
                end
            end
            self.task = nil
        end
        Guard.Replace(slot, Chance)
        Status("snowpile_generation", true)
    end)

    env.AddComponentPostInit("um_snow_stormspawner", function(self)
        local old = self.OnUpdate
        local stop = Slot(old, "StopSnowstorm", "storm_stop")
        local stops = Slot(old, "StopSnowstorms", "storms_stop")
        if not Match(old, "storm_update") or not stop or not stops or
            not Match(self.OnPostInit, "storm_post") or not Match(self.OnLoad, "storm_load") or
            not Match(self.ToggleSnowstorm, "storm_toggle") then
            Status("snowstorm_idle", false, "upstream weather controller changed")
            return
        end
        local inst = self.inst
        local function Sync()
            if G.TheWorld.state.iswinter then
                inst:StartUpdatingComponent(self)
            else
                local timer = G.TheWorld.components.worldsettingstimer
                if G.TheWorld.snowstorm_task or G.TheWorld:HasTag("snowstormstart") or
                    (G.TheWorld.net and G.TheWorld.net:HasTag("snowstormstartnet")) or
                    (timer and (timer:GetTimeLeft("um_snowstorm_timer") or timer:GetTimeLeft("um_stopsnowstorm_timer") or
                        timer:GetTimeLeft("um_rimeweed_timer"))) then
                    stop.value(); stops.value()
                end
                inst:StopUpdatingComponent(self)
            end
        end
        self.OnUpdate = function(self, dt)
            if G.TheWorld.state.iswinter then return old(self, dt) end
            Sync()
        end
        local post, load, toggle = self.OnPostInit, self.OnLoad, self.ToggleSnowstorm
        self.OnPostInit = function(self, ...) post(self, ...); Sync() end
        self.OnLoad = function(self, ...) load(self, ...); inst:DoTaskInTime(0, Sync) end
        self.ToggleSnowstorm = function(self, ...) local result = toggle(self, ...); Sync(); return result end
        inst:WatchWorldState("season", function() inst:DoTaskInTime(0, Sync) end)
        -- Preserve a failsafe for console/other-mod forced weather without
        -- restarting and cancelling timers every simulation frame all year.
        inst:DoPeriodicTask(2, Sync)
        Status("snowstorm_idle", true)
    end)

    env.AddComponentPostInit("um_snowstormmanager", function(self)
        if Match(self.UnregisterSnowpile, "pile_unregister") then
            self.UnregisterSnowpile = function(self, inst) self.snowpiles[inst.GUID] = nil end
            Status("snowpile_registry", true)
        else Status("snowpile_registry", false, "upstream registry changed") end
        if Match(self.CheckForOtherSnowpiles, "pile_count") then
            self.CheckForOtherSnowpiles = function(self, pos, dist_sq)
                local count = 0
                for _, ent in ipairs(G.TheSim:FindEntities(pos.x, 0, pos.z, math.sqrt(dist_sq), {"snowpile_basic"})) do
                    if self.snowpiles[ent.GUID] == ent and ent:IsValid() and ent:GetDistanceSqToPoint(pos.x, 0, pos.z) <= dist_sq then
                        count = count + 1
                    end
                end
                return count
            end
            Status("snowpile_local_count", true)
        else Status("snowpile_local_count", false, "upstream density rules changed") end
    end)

    env.AddComponentPostInit("um_ocupusappearinator", function(self)
        local location = Slot(self.SpawnOcupi, "FindLocation", "ocupus_location")
        local tiles = location and Slot(location.value, "IterateThroughTiles", "ocupus_tiles")
        local spacing = tiles and Slot(tiles.value, "CheckForOtherOcupi", "ocupus_spacing")
        if not location or not tiles or not spacing then Status("ocupus_location", false, "upstream placement changed"); return end
        Guard.Replace(location, function()
            local logger = G.TheWorld.components.um_tilelogger
            if logger and logger.Hazardous then
                for _, tile in ipairs(logger.Hazardous) do
                    local offset = math.random() * 4
                    if spacing.value({x = tile.x, z = tile.z}) then return {x = tile.x + offset, z = tile.z + offset} end
                end
            end
        end)
        Status("ocupus_location", true)
    end)

    env.AddComponentPostInit("weather", function(self)
        local old = self.OnUpdate
        if not Match(old, "weather_update") then Status("weather_particles", false, "upstream weather effects changed"); return end
        local base = Value(old, "_OnUpdate")
        local rate = Value(old, "_CalculatePrecipitationRate")
        local hasfx = Value(old, "_hasfx")
        local rain, snow, pollen = Value(old, "_rainfx"), Value(old, "_snowfx"), Value(old, "_pollenfx")
        if type(base) ~= "function" or (rate ~= nil and type(rate) ~= "function") then
            Status("weather_particles", false, "upstream precipitation changed"); return
        end
        local density = env.GetModConfigData("um_weather_particles2hm") or 4
        if density ~= 2 and density ~= 4 and density ~= 10 then density = 4 end
        local clientconfig = G.rawget(G, "UM_CLIENT_CONFIG")
        local beta = type(clientconfig) == "table"
        self.OnUpdate = function(self, dt)
            base(self, dt)
            if not hasfx then return end
            if G.TheWorld.state.issummer and G.TheWorld.net:HasTag("heatwavestartnet") and pollen then
                pollen.particles_per_tick = pollen.particles_per_tick * 20 + 1
            end
            if G.TheWorld.state.iswinter and G.TheWorld.net:HasTag("snowstormstartnet") and snow then
                snow.particles_per_tick = snow.particles_per_tick * density + 1
            end
            if rain and G.ThePlayer and G.ThePlayer:HasTag("under_the_weather") then
                local tornado = G.TheSim:FindFirstEntityWithTag("um_tornado")
                if Valid(tornado) then
                    local distance = math.sqrt(G.ThePlayer:GetDistanceSqToInst(tornado))
                    local reduced = beta and clientconfig.UM_STORMS_OVER or (not beta and G.TUNING.DSTU.REDUCED_TORNADO_VFX)
                    local intensity = G.Lerp(reduced and 5 or 15, 1, distance / 300) * density / 10
                    local preciprate = rate and rate() or 1
                    rain.particles_per_tick = preciprate * 5 + intensity
                    rain.splashes_per_tick = preciprate * 3 + intensity
                end
            end
        end
        Status("weather_particles", true)
    end)

    local prefabsinstalled = false
    local function InstallPrefabs()
        if prefabsinstalled or not G.Prefabs.snowpile or not G.Prefabs.um_tornado then return end
        prefabsinstalled = true
        local snowpile = G.Prefabs.snowpile
        local season = snowpile and Slot(snowpile.fn, "OnSeasonChange", "pile_season")
        if season then
            local old = season.value
            Guard.Replace(season, function(inst, value)
                -- Native worldstate publishes "season" before "iswinter".
                -- UM's callback reads the latter and otherwise misses melting
                -- until a later regeneration timer. Wait only for this mismatch.
                if type(value) == "string" and ((value == "winter") ~= G.TheWorld.state.iswinter) then
                    if not inst.um_snowseason2hm then
                        inst.um_snowseason2hm = inst:DoTaskInTime(0, function(inst)
                            inst.um_snowseason2hm = nil
                            old(inst)
                        end)
                    end
                else old(inst) end
            end)
            Status("snowpile_season_state", true)
        elseif snowpile then Status("snowpile_season_state", false, "upstream seasonal melt changed") end
        local tornado = G.Prefabs.um_tornado
        local tick = tornado and Slot(tornado.fn, "TornadoTask", "tornado_tick")
        if tick then
            local adapter = require("umtornado2hm")
            local make = adapter[Guard.Fingerprint(tick.value)]
            if make then
                local values = {}
                for _, name in ipairs({"config", "HOUND_LIGHNTING_CANT_TAGS", "getrandomposition", "teleport_continue"}) do
                    values[name] = Value(tick.value, name)
                end
                if type(values.getrandomposition) == "function" and type(values.teleport_continue) == "function" then
                    Guard.Replace(tick, make(values, G))
                    Status("tornado_weather_tasks", true)
                end
            end
        elseif tornado then Status("tornado_weather_tasks", false, "upstream tornado changed") end
        local fern = G.Prefabs.hooded_fern
        local register = fern and Slot(fern.fn, "RegisterPathFinding", "fern_register")
        local unregister = register and Slot(register.value, "UnregisterPathFinding", "fern_unregister")
        if register and unregister and Value(register.value, "PF_DIMS") == 4 and Value(unregister.value, "PF_DIMS") == 4 then
            local oldregister, oldunregister = register.value, unregister.value
            Guard.Replace(unregister, function(inst)
                if inst._pfpos == nil then return end
                oldunregister(inst)
                inst._pfpos = nil
            end)
            Guard.Replace(register, function(inst)
                local pos = inst:GetPosition()
                if inst._pfpos then
                    if inst._pfpos.x == pos.x and inst._pfpos.z == pos.z then return end
                    oldunregister(inst)
                    inst._pfpos = nil
                end
                oldregister(inst)
            end)
            Status("fern_pathfinding", true)
        elseif fern then Status("fern_pathfinding", false, "no matching upstream pathfinding callbacks") end

        local eyes = G.Prefabs.um_ocupus_eyetacle
        local watch = eyes and Slot(eyes.fn, "CheckForVictimsLong", "eye_watch")
        if watch then
            local old = watch.value
            Guard.Replace(watch, function(inst, ...)
                local previous = inst.droptask
                old(inst, ...)
                if previous and previous ~= inst.droptask then previous:Cancel() end
            end)
            Status("ocupus_eye_tasks", true)
        elseif eyes then Status("ocupus_eye_tasks", false, "upstream eye observation changed") end
        local submerged = G.Prefabs.um_ocupus_eye
        local hide = submerged and Slot(submerged.fn, "Hide", "eye_hide")
        local appear = submerged and Slot(submerged.fn, "Appear", "eye_appear")
        if hide and appear then
            local oldhide, oldappear = hide.value, appear.value
            Guard.Replace(hide, function(inst) oldhide(inst); inst.movin = nil end)
            Guard.Replace(appear, function(inst)
                if inst.grabtask then inst.grabtask:Cancel(); inst.grabtask = nil end
                if inst.movin then inst.movin:Cancel(); inst.movin = nil end
                oldappear(inst)
            end)
            Status("ocupus_day_tasks", true)
        elseif submerged then Status("ocupus_day_tasks", false, "upstream eye daylight behavior changed") end

        local core = G.Prefabs.um_ocupus
        if core then
            local slots = {}
            for name, id in pairs({Born = "ocupus_born", RemoveAllTentacles = "ocupus_remove", PullOut = "ocupus_pullout",
                AddOcupusEyeTentacle = "ocupus_add_eye", SpawnTentacle = "ocupus_spawn_tentacle"}) do
                slots[name] = Slot(core.fn, name, id)
            end
            local respawn = eyes and Slot(eyes.fn, "SpawnNewEyeTentacle", "eye_respawn")
            if slots.Born and slots.RemoveAllTentacles and slots.PullOut and slots.AddOcupusEyeTentacle and slots.SpawnTentacle and respawn then
                local function Track(inst)
                    for _, field in ipairs({"undertents", "surfacetents", "regulartents"}) do
                        local list = inst[field]
                        if list then
                            for i = #list, 1, -1 do if not Valid(list[i]) then table.remove(list, i) end end
                            for _, child in ipairs(list) do
                                if not child.um_ocupus_tracked2hm then
                                    child.um_ocupus_tracked2hm = true
                                    child:ListenForEvent("onremove", function()
                                        if Valid(inst) and not inst.um_ocupus_prune2hm then
                                            -- Never mutate a list during UM's own ipairs/Leave loop.
                                            inst.um_ocupus_prune2hm = inst:DoTaskInTime(0, function(inst)
                                                inst.um_ocupus_prune2hm = nil
                                                Track(inst)
                                            end)
                                        end
                                    end)
                                end
                            end
                        end
                    end
                end
                for name, slot in pairs(slots) do
                    local old, kind = slot.value, name
                    Guard.Replace(slot, function(inst, ...)
                        Track(inst)
                        if kind == "PullOut" then inst.um_ocupus_epoch2hm = (inst.um_ocupus_epoch2hm or 0) + 1 end
                        old(inst, ...)
                        if Valid(inst) then Track(inst) end
                    end)
                end
                Guard.Replace(respawn, function(inst)
                    local core, boat = inst.core, inst.boatvictim
                    if Valid(core) then
                        local splash = G.SpawnPrefab("splash_ocean")
                        splash.Transform:SetPosition(inst.Transform:GetWorldPosition())
                        splash.Transform:SetScale(1.5, 1.5, 1.5)
                        local epoch = core.um_ocupus_epoch2hm
                        core:DoTaskInTime(math.random(3, 5), function(core)
                            if core.boatvictim == boat and boat and boat:IsValid() and core.um_ocupus_epoch2hm == epoch then
                                core:AddOcupusEyeTentacle()
                            end
                        end)
                    end
                    inst:Remove()
                end)
                Status("ocupus_references", true)
            else Status("ocupus_references", false, "upstream battle lifecycle changed") end
        end
    end
    -- World post-init precedes saved entities being constructed. SimPostInit
    -- alone is too late: those entities already captured their old callbacks.
    env.AddPrefabPostInit("world", InstallPrefabs)
    env.AddSimPostInit(InstallPrefabs)
end

return M
