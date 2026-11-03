-- Import only into the isolated test mod. Replays the crash-log lifecycle.
AddPrefabPostInit("world", function(world)
    if not world.ismastersim then return end
    assert(TheNet:GetServerName() == "ShadowWorld isolated slingshot hotfix test")
    world:DoTaskInTime(4, function()
        local tree = SpawnPrefab("evergreen")
        local propagator = tree.components.propagator
        tree:Remove()
        assert(not tree:IsValid(), "test tree removed")
        -- The native delayed burn callback reaches RemoveComponent after the
        -- tree is invalid. Its OnRemoveFromEntity must still cancel timers.
        local ok, err = pcall(function() tree:RemoveComponent("propagator") end)
        print("[PROPAGATOR_CLEANUP]", ok and "PASS" or "FAIL", err)
        assert(ok, err)
        assert(propagator.task == nil and propagator.delay == nil)

        local burnt = SpawnPrefab("evergreen")
        local delayed
        local schedule = burnt.DoTaskInTime
        burnt.DoTaskInTime = function(inst, time, fn, ...)
            if time == .5 then delayed = fn end
            return schedule(inst, time, fn, ...)
        end
        burnt.components.burnable.onburnt(burnt)
        burnt.DoTaskInTime = schedule
        assert(delayed, "native evergreen burn callback captured")
        burnt:Remove()
        -- Replay the whole stale callback, not just the failing component call.
        local burnok, burnerr = pcall(delayed, burnt)
        print("[PROPAGATOR_CLEANUP] FULL_BURN_CALLBACK", burnok and "PASS" or "FAIL", burnerr)
        assert(burnok, burnerr)
    end)
end)
