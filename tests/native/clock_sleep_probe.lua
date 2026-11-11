-- Disposable world only; run actual clock-peril code and native tent stategraphs.
local G = GLOBAL
G.setmetatable(env, {__index = function(_, key) return G.rawget(G, key) end})
local json = require("json")
G.VaultAudit = {}
local function emit(data) print("[VAUDIT] " .. json.encode(data)) end
AddSimPostInit(function() TheWorld:DoTaskInTime(1, function() emit({kind = "ready"}) end) end)

function G.VaultAudit.clock_sleep()
    local checks, rows, owned = 0, 0, {}
    local done = false
    local function check(value, message) checks = checks + 1; assert(value, message) end
    local function remove(ent)
        if ent:IsValid() then
            -- Leave native sleep while player_classified still exists, before entity teardown.
            if ent:HasTag("player") and ent.sg then ent.sg:GoToState("idle") end
            ent:Remove()
        end
    end
    local function finish(ok, err)
        if done then return end
        done = true
        for _, ent in ipairs(owned) do remove(ent) end
        emit({kind = "clock_sleep", passed = ok, checks = checks, cases = rows,
            error = not ok and tostring(err):gsub("'", "") or nil})
    end
    local function safe(fn)
        if done then return end
        local ok, err = pcall(fn)
        if not ok then finish(false, err) end
    end
    local function later(delay, fn) TheWorld:DoTaskInTime(delay, function() safe(fn) end) end
    local function spawn(name)
        local ent = assert(SpawnPrefab(name), name)
        owned[#owned + 1] = ent
        return ent
    end
    safe(function()
        local server = assert(CLOCK_PERIL and CLOCK_PERIL.Server, "clock peril enabled")
        local task
        for i = 1, 40 do
            local name, value = debug.getupvalue(server.Init, i)
            if name == "_tick_task" then task = value; break end
        end
        check(task and task.fn, "real clock-peril periodic enforcement found")
        local tick = task.fn
        task:Cancel() -- Exercise the real callback at deterministic test steps.
        local function force(value, callback)
            server.current_schedule = {}
            for i = 1, 16 do server.current_schedule[i] = value end
            server.SyncTimeProgress(0)
            tick()
            later(0.2, function()
                check(TheWorld.state.phase == value, "clock-peril forced phase " .. value)
                callback()
            end)
        end
        local function sleeping(p)
            return p.sleepingbag ~= nil and p.components.sleepingbaguser.sleeptask ~= nil and p.sg:HasStateTag("sleeping")
        end
        local specs = {
            {"tent", "dusk", "night", true}, {"tent", "night", "dusk", true},
            {"tent", "dusk", "dusk", true}, {"tent", "night", "night", true},
            {"tent", "dusk", "day", false}, {"tent", "night", "day", false},
            {"siestahut", "day", "day", true}, {"siestahut", "day", "dusk", false},
            {"siestahut", "day", "night", false},
            {"tent", "night", "day", true, "upgrade"},
            {"tent", "day", "dusk", true, "upgrade"},
            {"siestahut", "night", "day", true, "upgrade"},
            {"tent", "dusk", "night", false, "manual"},
            {"tent", "night", "dusk", false, "hammer"},
            {"tent", "night", "dusk", false, "hunger"},
            {"tent", "dusk", "dusk", true, "repeat"},
        }
        local index = 0
        local nextcase
        nextcase = function()
            index = index + 1
            local spec = specs[index]
            if not spec then finish(true); return end
            force(spec[2], function()
                local bed = spawn(spec[1])
                bed.Transform:SetPosition(0, 0, 0)
                local players = {spawn("wilson"), spawn("wilson")}
                for i, p in ipairs(players) do
                    p.userid = "KU_CLOCK_SLEEP_" .. index .. "_" .. i
                    p.Transform:SetPosition(i * 2, 0, 0)
                    p.components.hunger:SetRate(0)
                    p.components.hunger:SetPercent(1)
                    p.components.health:SetPercent(0.8)
                    p.components.sanity:SetPercent(0.8)
                end
                if spec[5] == "upgrade" then
                    local material = spawn("sleepbomb")
                    check(bed.components.repairable2hm:Repair(players[1], material), "existing bed upgrade succeeds")
                end
                later(0.1, function()
                    for _, p in ipairs(players) do
                        p.bufferedaction = BufferedAction(p, bed, ACTIONS.SLEEPIN)
                        p.sg:GoToState("tent")
                    end
                end)
                later(0.5, function()
                    for i, p in ipairs(players) do
                        check(sleeping(p), "sleeper " .. i .. " entered native tent: state=" .. p.sg.currentstate.name ..
                            " bed=" .. tostring(p.sleepingbag ~= nil) .. " phase=" .. TheWorld.state.phase ..
                            " isday=" .. tostring(TheWorld.state.isday))
                    end
                    local uses = bed.components.finiteuses:GetUses()
                    local function evaluate()
                        if spec[5] == "manual" then
                            for _, p in ipairs(players) do p.sleepingbag.components.sleepingbag:DoWakeUp() end
                        elseif spec[5] == "hammer" then
                            bed.components.workable:WorkedBy(players[1], 1)
                        elseif spec[5] == "hunger" then
                            for _, p in ipairs(players) do
                                p.components.hunger:SetPercent(0)
                                p.components.sleepingbaguser:SleepTick()
                            end
                        end
                        later(0.1, function()
                            for _, p in ipairs(players) do
                                check(sleeping(p) == spec[4], "correct sleep state for " .. spec[1] .. " " .. spec[2] .. " to " .. spec[3])
                            end
                            if spec[4] then check(bed.components.finiteuses:GetUses() == uses, "allowed transition does not spend tent uses") end
                            rows = rows + 1
                            emit({kind = "clock_sleep_case", prefab = spec[1], from = spec[2], to = spec[3],
                                asleep = spec[4], mode = spec[5] or "normal", people = #players})
                            for _, p in ipairs(players) do remove(p) end
                            remove(bed)
                            later(0.05, nextcase)
                        end)
                    end
                    if spec[5] == "repeat" then
                        force("night", function()
                            for _, p in ipairs(players) do check(sleeping(p), "intermediate night remains asleep") end
                            force("dusk", evaluate)
                        end)
                    else force(spec[3], evaluate) end
                end)
            end)
        end
        nextcase()
    end)
end
