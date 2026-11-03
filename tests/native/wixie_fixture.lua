-- Disposable server only: creates characters, crowds and exercises native SGs.
AddPrefabPostInit("world", function(world)
    if not world.ismastersim then return end
    assert(TheNet:GetServerName() == "ShadowWorld isolated Wixie test", "isolated Wixie world required")
    world:PushEvent("ms_setautosaveenabled", false)
    local function check(ok, why) assert(ok, "WIXIE_NATIVE: " .. why) end
    local function near(a, b, why) check(math.abs(a - b) < .0001, why .. ": " .. tostring(a) .. "/" .. tostring(b)) end
    world:DoTaskInTime(5, function()
        local x, y, z = world.components.playerspawner:GetAnySpawnPoint()
        local wixie, walter = SpawnPrefab("wixie"), SpawnPrefab("walter")
        check(wixie ~= nil, "Beta Wixie available")
        wixie.entity:SetCanSleep(false)
        walter.entity:SetCanSleep(false)
        wixie.Transform:SetPosition(x, 0, z)
        walter.Transform:SetPosition(x + 2, 0, z)
        wixie.components.health:SetInvincible(false)
        wixie.components.hunger:SetPercent(.5)
        walter.components.hunger:SetPercent(.5)
        local wixieHard, walterHard = GetModConfigData("wixie"), GetModConfigData("walter")
        local shared = wixie.sg.sg.states.slingshot_charge
        check(shared ~= nil and shared == walter.sg.sg.states.slingshot_charge, "characters share native charge descriptor")
        local timing = shared.timeline[1].time
        wixie.sg:GoToState("slingshot_charge")
        check(wixie.sg.currentstate.name == "slingshot_charge", "Wixie entered native charge state")
        if wixieHard then
            check(wixie.sg.currentstate ~= shared, "Wixie slowdown has private state")
            near(wixie.sg.currentstate.rate2hm, 1 / 2.1, "Wixie original hunger-dependent slowdown")
        else
            check(wixie.sg.currentstate == shared and shared.rate2hm == nil, "disabled Wixie receives no slowdown")
        end
        walter.sg:GoToState("slingshot_charge")
        if walterHard then
            check(walter.sg.currentstate ~= shared, "Walter slowdown has private state")
            near(walter.sg.currentstate.rate2hm, 1 / 2.2, "Walter original hunger-dependent slowdown")
        else
            check(walter.sg.currentstate == shared and shared.rate2hm == nil, "disabled Walter receives no slowdown")
        end
        near(shared.timeline[1].time, timing, "simultaneous players do not change shared timeline")
        wixie.sg:GoToState("idle")
        walter.sg:GoToState("idle")
        wixie.wixiequickshot = false
        wixie.components.combat:StartAttack()
        wixie.sg:GoToState("slingshot_charge")
        check(wixie.sg.currentstate.name == "idle", "native cooldown-aborted charge is not resurrected")
        print("[WIXIE_NATIVE] INDEPENDENT_SG_PASS", wixieHard, walterHard)

        for i = 1, 8 do
            local crowd = SpawnPrefab("pigman")
            crowd.Transform:SetPosition(x + math.cos(i) * 2, 0, z + math.sin(i) * 2)
            if crowd.StopBrain then crowd:StopBrain() end
        end
        local wall = SpawnPrefab("wall_wood")
        wall.Transform:SetPosition(x + 2, 0, z + 1)
        wixie.components.inventory:Equip(SpawnPrefab("armorwood"))
        local remove = GetModConfigData("Wixie No Claustrophobia")
        if remove then wixie.claustrophobia:set(.9) end
        world:DoTaskInTime(2, function()
            if remove then
                check(wixie.noclaustrophobia2hm and not wixie:CanGainClaustrophobia(), "independent fear prevention enabled")
                near(tonumber(wixie.claustrophobia:value()), 0, "server fear and client overlay netvar reset")
                near(wixie:GetClaustrophobia(), 0, "crowds and armor cannot gain fear")
                wixie:PushEvent("um_claustrophobiapanic")
                wixie.sg:GoToState("claustrophobic")
                check(wixie.sg.currentstate.name == "idle", "queued and direct panic blocked")
                print("[WIXIE_NATIVE] BETA_NO_FEAR_PASS")
            else
                check(not wixie.noclaustrophobia2hm, "fear removal disabled")
                check(wixie:GetClaustrophobia() > 0, "native Beta fear still accumulates with general UM patch enabled")
                print("[WIXIE_NATIVE] BETA_NATIVE_FEAR_PASS", wixie:GetClaustrophobia())
            end
            print("[WIXIE_NATIVE] ALL_PASS")
            c_shutdown(false)
        end)
    end)
end)
