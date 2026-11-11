local G = GLOBAL
G.setmetatable(env, {__index = function(_, key) return G.rawget(G, key) end})

local function Near(actual, expected)
    assert(math.abs(actual - expected) < 1e-6, tostring(actual) .. " ~= " .. tostring(expected))
end

local function Run(player)
    assert(TheNet:GetServerName() == "Thermal isolated host")
    local world, health = TheWorld, player.components.health
    assert(world.one_player_mode and TUNING.DSA_ONE_PLAYER_MODE, "expected Don't Starve Alone host")
    local shard = world.one_player_mode_shard
    player:StopUpdatingComponent(player.components.temperature)
    print("[UM MIGRATION] arrived", shard, health.penalty, health.currenthealth)
    if shard == "Master" and health.penalty > .025 then
        Near(health.penalty, .04)
        Near(health.currenthealth, 144)
        player:DoTaskInTime(.35, function()
            Near(health.penalty, .04)
            print("[UM MIGRATION] COMPLETE Master to Caves to Master, no duplicate")
            print("[THERMAL] COMPLETE")
            TheSim:Quit()
        end)
        return
    end

    assert(shard == "Master" or shard == "Caves")
    local before = shard == "Master" and 0 or .02
    Near(health.penalty, before)
    Near(health.currenthealth, 150 * (1 - before))
    local destination = assert(world.one_player_mode_shardid_secondary, "missing destination shard")
    local OnDespawn = player.OnDespawn
    function player:OnDespawn(migration, ...)
        OnDespawn(self, migration, ...)
        assert(migration ~= nil, "expected migration despawn")
        self.um_temp_healthdelta = 20
        health:DoDelta(-3, true, shard == "Master" and "cold" or "hot", true, nil, true)
        Near(health.penalty, before)
        Near(health:GetMaxWithPenalty(), 150 * (1 - before - .02))
        print("[UM MIGRATION] pending at serialization", shard, before, health:OnSave().penalty)
    end
    world:PushEvent("ms_playerdespawnandmigrate", {player = player, worldid = destination, portalid = 1})
end

AddSimPostInit(function()
    local task, chose
    task = TheGlobalInstance:DoStaticPeriodicTask(.5, function()
        local screen = TheFrontEnd:GetActiveScreen()
        if not chose and screen and screen.name == "LobbyScreen" and screen.cb then
            chose = true
            assert(TheWorld.one_player_mode_shard == "Master", "migration failed to resume player")
            screen.cb("wilson", "wilson_none", "", "", "", "")
        end
        if TheWorld and TheWorld.ismastersim and ThePlayer and ThePlayer.HUD then
            task:Cancel()
            TheNet:SetAutopaused(false)
            TheNet:SetServerPaused(false)
            ThePlayer:DoStaticTaskInTime(1, Run)
        end
    end)
end)
