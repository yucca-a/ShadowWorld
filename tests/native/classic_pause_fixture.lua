AddSimPostInit(function()
    if not TheWorld.ismastersim then return end
    assert(TheNet:GetServerName() == "ShadowWorld isolated classic pause test")
    TheWorld:PushEvent("ms_setautosaveenabled", false)
    TheWorld:DoStaticTaskInTime(3, function()
        local ok, err = pcall(function()
            assert(TUNING.EXCHANGE_MODE2HM == "classic")
            assert(TheWorld.components.exchangevariants2hm.ready)
            local p = assert(SpawnPrefab("wilson"))
            p.userid = "KU_ClassicPauseTest"
            if not table.contains(AllPlayers, p) then table.insert(AllPlayers, p) end
            local entrance = SpawnPrefab("treasurechest")
            entrance:RemoveComponent("container")
            entrance:AddComponent("container_proxy")
            local box = assert(TheWorld:GetPocketDimensionContainer("shadow"))
            entrance.components.container_proxy:SetMaster(box)
            entrance.components.container_proxy:Open(p)
            local native = TheNet
            local requested, nativepaused = false, false
            -- No real client is connected in this isolated server. Record the
            -- native requests and use requested state only for callback flow;
            -- this does not assert that the engine accepted server pause.
            local network = setmetatable({
                SetServerPaused = function(_, value)
                    requested = value
                    native:SetServerPaused(value)
                end,
                IsServerPaused = function() return requested end,
            }, {__index = function(_, key)
                local value = native[key]
                if type(value) == "function" then return function(_, ...) return value(native, ...) end end
                return value
            end})
            local pause = assert(GetModRPCHandler("MOD_HARDMODE", "pausebtn2hm"))
            local installed = false
            for i = 1, 20 do
                local name, fn = debug.getupvalue(pause, i)
                if not name then break end
                if name == "fn" then
                    setfenv(fn, setmetatable({TheNet = network}, {__index = getfenv(fn)}))
                    installed = true
                    break
                end
            end
            assert(installed, "pause callback dependency isolated without replacing engine globals")
            pause(p, box)
            TheWorld:DoStaticTaskInTime(.2, function()
                nativepaused = native:IsServerPaused()
                assert(requested, "actual RPC requests pause")
                print("[CLASSIC_PAUSE_TEST] PASS pause request; engine accepted:", nativepaused)
                pause(p, box)
                assert(box.cancelpausetask2hm == nil, "manual resume cancels deadline")
                TheWorld:DoStaticTaskInTime(.2, function()
                assert(not requested, "RPC requests resume while paused")
                print("[CLASSIC_PAUSE_TEST] PASS manual resume while paused")
                pause(p, box)
                local start = GetStaticTime()
                TheWorld:DoStaticTaskInTime(.2, function()
                    assert(requested, "second native pause request")
                end)
                TheWorld:DoStaticTaskInTime(31, function()
                    assert(not requested, "30 second static deadline requests resume")
                    assert(box.cancelpausetask2hm == nil)
                    assert(GetStaticTime() - start >= 30)
                    entrance:Remove();table.removearrayvalue(AllPlayers,p);p:Remove()
                    print("[CLASSIC_PAUSE_TEST] RESULT failures=0 native RPC requests/manual resume/30 second timeout; engine_pause_verified=", nativepaused)
                    c_shutdown(false)
                end)
                end)
            end)
        end)
        if not ok then print("[CLASSIC_PAUSE_TEST] FAIL", err); c_shutdown(false) end
    end)
end)
