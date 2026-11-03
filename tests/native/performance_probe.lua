-- Isolated disposable servers only. Never import this into a player world.
AddSimPostInit(function()
    if not TheWorld.ismastersim then return end
    local last, worst, samples = GetTimeReal(), 0, 0
    local function report(label)
        local before = collectgarbage("count")
        collectgarbage("collect")
        print("[PERF_PROBE]", label, "lua_kb", before, "live_kb", collectgarbage("count"), "max_gap_ms", worst, "samples", samples)
        worst, samples = 0, 0
    end
    TheWorld:DoStaticPeriodicTask(.05, function()
        local now = GetTimeReal()
        worst = math.max(worst, now - last); last = now; samples = samples + 1
    end)
    TheWorld:DoStaticTaskInTime(12, function() report("loaded") end)
    for _, delay in ipairs({20, 40, 60}) do
        TheWorld:DoStaticTaskInTime(delay, function()
            if TheShard:IsMaster() then
                local started = GetTimeReal()
                local cpu = os.clock()
                SaveGame(false, function() print("[PERF_PROBE] save_ms", GetTimeReal() - started, "cpu_ms", (os.clock() - cpu) * 1000) end)
            end
        end)
        TheWorld:DoStaticTaskInTime(delay + 10, function() report("after_save_" .. delay) end)
    end
    TheWorld:DoStaticTaskInTime(75, function() report("final"); c_shutdown(false) end)
end)
