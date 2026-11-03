-- Destructive test: only the runner's disposable cluster is allowed.
local stages = {}
AddShardModRPCHandler("SW_REGEN_PROBE", "ready", function(peer, stage) stages[tostring(peer)] = stage end)
AddSimPostInit(function()
    if not TheWorld.ismastersim then return end
    assert(TheNet:GetServerName() == "ShadowWorld isolated exchange test", "isolated test cluster required")
    local world, stage, started = TheWorld, "loading", GetStaticTime()
    local session = world.meta.session_identifier
    local Engine = require("worldexchangeengine2hm")
    print("[REGEN_PROBE] WORLD", session, "loaded_cut", Engine.boot and Engine.boot.loaded)
    TheSim:GetPersistentString("sw_regen_probe_session", function(ok, old)
        stage = ok and old ~= session and "regenerated" or "original"
        if stage == "original" then TheSim:SetPersistentString("sw_regen_probe_session", session, false) end
        print("[REGEN_PROBE] STAGE", stage, session)
    end)
    local nativeSave, saves = Engine.nativeSave, 0
    Engine.nativeSave = function(shutdown, callback)
        saves = saves + 1
        local cpu = os.clock()
        print("[REGEN_PROBE] SAVE_BEGIN", stage, GetStaticTime() - started)
        return nativeSave(shutdown, function(...)
            print("[REGEN_PROBE] SAVE_END", stage, "cpu_ms", (os.clock() - cpu) * 1000)
            if callback then callback(...) end
        end)
    end
    local previous, reset, ready, player, saved, requested, traded, box
    world:DoStaticPeriodicTask(.1, function()
        local elapsed = GetStaticTime() - started
        local service = world.components.worldexchange2hm
        local e = service and service.engine
        if not e then return end
        if not player then
            player = SpawnPrefab("wilson")
            player.userid = "KU_RegenProbe" .. TheShard:GetShardId()
            -- A generated world's origin can be ocean; native drowning would
            -- disable the probe's controls independently of exchange locks.
            local portal
            for _, ent in pairs(Ents) do
                if ent.prefab == "multiplayer_portal" or ent.prefab == "multiplayer_portal_moonrock" then portal = ent; break end
            end
            assert(portal, "isolated forest fixture must contain its spawn portal")
            player.Transform:SetPosition(portal.Transform:GetWorldPosition())
            player.components.health:SetInvincible(true)
            player:AddComponent("playercontroller")
            player.components.playercontroller:Enable(true)
            e:Joined(player, false)
        end
        local state = e.core.phase .. "/hold=" .. tostring(e.holding) .. "/paused=" .. tostring(TheNet:IsServerPaused(true)) ..
            "/control=" .. tostring(player.components.playercontroller:IsEnabled())
        if state ~= previous then print("[REGEN_PROBE] STATE", stage, elapsed, state); previous = state end
        if e.core:IsReady() then
            stages[service.id] = stage
            SendModRPCToShard(GetShardModRPC("SW_REGEN_PROBE", "ready"), e.core.peer, stage)
            if stage == "original" and elapsed > 5 and not saved then
                saved = true
                if TheShard:IsMaster() then SaveGame(false) end
            end
            if stage == "original" and e.core.generation and stages[e.core.peer] == stage and elapsed > 15 and not reset then
                reset = true
                if TheShard:IsMaster() then print("[REGEN_PROBE] RESET_REQUEST"); c_regenerateworld() end
            elseif stage == "regenerated" and not ready then
                ready = elapsed
                print("[REGEN_PROBE] READY_AFTER_REGEN", elapsed, session)
                box = world:GetPocketDimensionContainer("shadow")
                box.components.container:DestroyContents()
                box.components.container:GiveItem(SpawnPrefab(TheShard:IsMaster() and "goldnugget" or "rocks"), 1)
            end
        end
        if ready and elapsed > ready + 5 and not requested then
            requested = true
            print("[REGEN_PROBE] IDLE_SAVES", saves)
            if TheShard:IsMaster() then
                box.components.container:Open(player)
                service:Request(player, box)
                print("[REGEN_PROBE] FIRST_EXCHANGE_CLICK")
            end
        end
        if requested and not traded and e.core.generation and not service.protocol.active then
            local item = box.components.container.slots[1]
            if item and item.prefab == (TheShard:IsMaster() and "rocks" or "goldnugget") then
                traded = true
                print("[REGEN_PROBE] FIRST_EXCHANGE_DONE", saves)
                assert(not e.holding and player.components.playercontroller:IsEnabled(), "first use must preserve movement")
                print("[REGEN_PROBE] VERIFIED", session, "holding", e.holding, "control", player.components.playercontroller:IsEnabled())
            end
        end
        if ready and elapsed > ready + 15 then
            assert(traded, "first exchange did not finish from one click")
            -- The runner stops both children after both VERIFIED markers.
        elseif elapsed > 120 then print("[REGEN_PROBE] TIMEOUT", stage, state); c_shutdown(false) end
    end)
end)
