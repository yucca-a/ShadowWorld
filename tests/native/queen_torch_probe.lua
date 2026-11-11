-- Observe real AI calls without suppressing errors or changing the UM brains.
local G = GLOBAL
G.setmetatable(env, {__index = function(_, key) return G.rawget(G, key) end})
local json = require("json")
local A = {owned = {}, stats = {calls = 0, hits = 0, invalid = 0, prefabs = {}}, checks = {}}
G.VaultAudit = A
local function emit(row) print("[VAUDIT] " .. json.encode(row)) end
local function check(ok, name, detail)
    A.checks[#A.checks + 1] = {name = name, passed = not not ok, detail = detail}
    assert(ok, name .. ": " .. tostring(detail))
end
local function spawn(name, x, z)
    local e = assert(SpawnPrefab(name), name)
    A.owned[#A.owned + 1] = e
    e.Transform:SetPosition(x, 0, z)
    e.entity:SetCanSleep(false)
    if e.components.health then e.components.health:SetInvincible(true) end
    return e
end
local function origin()
    local x, y, z = TheWorld.components.playerspawner:GetAnySpawnPoint()
    return x, z
end
local function group()
    A.mobs = {}
    for _, name in ipairs({"dreadeye", "ancient_trepidation", "viperling"}) do
        for i = 1, 4 do
            local e = spawn(name, A.x + 2 + i, A.z + (#A.mobs % 3) * 2)
            e.spawnedforplayer = A.actor
            e.components.combat:SetTarget(A.actor)
            A.mobs[#A.mobs + 1] = e
        end
    end
end
local function torch_ground()
    if A.torch and A.torch:IsValid() then A.torch:Remove() end
    A.torch = spawn("queen_torch", A.x, A.z)
    check(A.torch._light and A.torch._light:IsValid(), "native_lit_torch_registered")
end
local function finish(kind, ok, err)
    emit({kind = kind, passed = ok, error = err and tostring(err) or nil,
        stats = A.stats, checks = A.checks})
end
local function later(t, fn)
    TheWorld:DoTaskInTime(t, function()
        local ok, err = pcall(fn)
        if not ok then finish(A.finishing or "queen_done", false, err) end
    end)
end
AddSimPostInit(function()
    local original = assert(G.FindClosestQueenTorch)
    G.FindClosestQueenTorch = function(inst, ...)
        local s = A.stats
        s.calls = s.calls + 1
        local name = inst and inst.prefab or "non_entity"
        s.prefabs[name] = (s.prefabs[name] or 0) + 1
        if not inst or not inst.Transform then s.invalid = s.invalid + 1 end
        local result = original(inst, ...)
        if result then s.hits = s.hits + 1 end
        return result
    end
    TheWorld:DoTaskInTime(1, function()
        emit({kind = "ready", dedicated = TheNet:IsDedicated(), mode = QUEEN_MODE,
            build = APP_VERSION, torch_guard_source = debug.getinfo(original, "S").source})
    end)
end)

function A.run()
    A.x, A.z = origin()
    A.actor = spawn("wilson", A.x, A.z)
    A.actor.userid = "KU_QUEEN_TORCH_AUDIT"
    A.actor.persists = false
    A.actor.components.hunger:SetRate(0)
    A.actor.components.sanity:SetPercent(.1)
    group()
    later(5, function()
        check(A.stats.calls > 0, "unlit_ai_ran", A.stats.calls)
        check(A.stats.invalid == 0, "unlit_entity_arguments", A.stats.invalid)
        torch_ground()
        A.actor.components.inventory:GiveItem(A.torch)
        A.actor.components.inventory:Equip(A.torch)
        A.firsthits = A.stats.hits
        later(8, function()
            check(A.stats.hits > A.firsthits, "held_torch_seen_by_native_ai", A.stats.hits)
            for _, name in ipairs({"dreadeye", "ancient_trepidation", "viperling"}) do
                check((A.stats.prefabs[name] or 0) > 0, "brain_called_" .. name, A.stats.prefabs[name])
            end
            A.actor.components.inventory:DropItem(A.torch, true, true)
            A.torch.Transform:SetPosition(A.x, 0, A.z)
            check(A.torch._light and A.torch._light:IsValid(), "dropped_torch_keeps_light")
            -- Repeated genuine inventory/equip/drop events; AI ticks between each.
            for i = 1, 24 do
                later(i * .35, function()
                    if i % 3 == 1 then
                        A.actor.components.inventory:GiveItem(A.torch)
                    elseif i % 3 == 2 then
                        A.actor.components.inventory:Equip(A.torch)
                    else
                        A.actor.components.inventory:DropItem(A.torch, true, true)
                        A.torch.Transform:SetPosition(A.x, 0, A.z)
                    end
                end)
            end
            later(9, function()
                check(A.stats.invalid == 0, "equip_drop_cycles_entity_arguments", A.stats.invalid)
                -- Move creatures across the real 10/15 unit fear thresholds.
                for i = 1, 12 do
                    later(i * .5, function()
                        for j, e in ipairs(A.mobs) do
                            if e:IsValid() then e.Transform:SetPosition(A.x + (i % 2 == 0 and 4 or 24), 0, A.z + j * .2) end
                        end
                    end)
                end
                later(7, function()
                    -- Kill/remove creatures while the actual brain manager runs.
                    for i = 1, 12 do
                        later(i * .25, function()
                            local e = spawn("dreadeye", A.x + 3, A.z + 2)
                            e.spawnedforplayer = A.actor
                            e.components.combat:SetTarget(A.actor)
                            later(.1, function()
                                if e:IsValid() then
                                    if i % 2 == 0 then e:Remove()
                                    else e.components.health:SetInvincible(false); e.components.health:Kill() end
                                end
                            end)
                        end)
                    end
                    later(5, function()
                        check(A.stats.invalid == 0, "death_remove_entity_arguments", A.stats.invalid)
                        check(A.stats.hits > 20, "repeated_actual_light_hits", A.stats.hits)
                        -- Exercise native throw path too, rather than constructing a fake light.
                        A.actor.components.inventory:GiveItem(A.torch)
                        A.actor.components.inventory:Equip(A.torch)
                        A.torch.components.complexprojectile:Launch(Vector3(A.x + 5, 0, A.z), A.actor)
                        later(3, function()
                            check(A.torch:IsValid(), "native_throw_survived")
                            -- Ground a fresh persistent lit torch for normal save/reload.
                            torch_ground()
                            A.torch.queen_audit_torch = true
                            finish("queen_done", true)
                        end)
                    end)
                end)
            end)
        end)
    end)
end

function A.after_reload()
    A.finishing = "queen_reload"
    A.x, A.z = origin()
    local torches = 0
    for _, e in pairs(Ents) do
        if e.prefab == "queen_torch" and e._light and e._light:IsValid() then torches = torches + 1; A.torch = e end
    end
    check(torches > 0, "saved_lit_torch_restored", torches)
    A.actor = spawn("wilson", A.x, A.z)
    A.actor.userid = "KU_QUEEN_TORCH_AUDIT"
    A.actor.persists = false
    A.actor.components.hunger:SetRate(0)
    A.actor.components.sanity:SetPercent(.1)
    group()
    later(8, function()
        check(A.stats.hits > 0, "reload_actual_fear_ai", A.stats.hits)
        check(A.stats.invalid == 0, "reload_entity_arguments", A.stats.invalid)
        finish("queen_reload", true)
    end)
end

function A.invalid_argument_control()
    -- Explicitly artificial positive control for the old brain-vs-entity mistake.
    -- This is NOT part of the unchanged-current-UM reproduction result.
    torch_ground()
    local e = spawn("dreadeye", A.x + 3, A.z)
    later(.5, function()
        local brain = assert(e.brain)
        emit({kind = "historical_control_start", has_transform = brain.Transform ~= nil,
            actual_entity_has_transform = e.Transform ~= nil})
        local node = require("brains/braincommon").RunAwayFromQueenTorch(brain)
        -- Leave this actual engine callback unprotected so native logs prove the crash.
        TheWorld:DoTaskInTime(.1, function() node:Visit(); emit({kind = "historical_control_survived"}) end)
    end)
end
