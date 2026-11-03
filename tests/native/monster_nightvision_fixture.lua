-- ONLY import into a disposable test mod/world. This spawns and changes players.
AddSimPostInit(function()
    if not TheWorld.ismastersim or TheNet:GetServerName() ~= "ShadowWorld isolated monster vision test" then return end
    local function check(ok, why) assert(ok, "[MONSTER_VISION_NATIVE] " .. why) end
    local function CheckWoodie(done)
        local x, _, z = TheWorld.components.playerspawner:GetAnySpawnPoint()
        local forms = {}
        TheWorld:PushEvent("ms_setclocksegs", {day=0,dusk=0,night=16})
        for index, mode in ipairs({"beaver", "moose", "goose"}) do
            local p = SpawnPrefab("woodie")
            p.entity:SetCanSleep(false)
            p.Transform:SetPosition(x + index * 3, 0, z + 6)
            p.components.health:SetInvincible(false)
            p.components.wereeater:ForceTransformToWere(mode)
            forms[index] = p
        end
        TheWorld:DoTaskInTime(6, function()
            for index, p in ipairs(forms) do
                check(p.weremode:value() == index and not p:HasTag("monster"), "native non-monster transformation " .. index)
                local vision = p.components.playervision
                local cc = vision:GetCCTable()
                vision:ForceNightVision(false) -- Same legacy disable used by Fenghua.
                check(vision:HasNightVision() and vision:GetCCTable() == cc, "native form survives legacy disable " .. index)
                check(p.components.grue.immunity.nightvision and not p.components.grue:CheckForStart(), "server dark protection retained " .. index)
                p.components.wereness:SetPercent(0)
            end
            TheWorld:DoTaskInTime(6, function()
                for index, p in ipairs(forms) do
                    check(p.weremode:value() == 0, "native human transform completed " .. index)
                    check(not p.components.playervision:HasNightVision(), "human has no permanent bonus " .. index)
                    check(not p.components.grue.immunity.nightvision, "human releases native dark immunity " .. index)
                end
                print("[MONSTER_VISION_NATIVE] WOODIE_THREE_FORMS_PASS")
                done()
            end)
        end)
    end
    TheWorld:DoTaskInTime(2, function()
        local x, _, z = TheWorld.components.playerspawner:GetAnySpawnPoint()
        local players = {}
        for index, name in ipairs({"webber", "wathom", "wortox", "wilson"}) do
            local p = SpawnPrefab(name)
            check(p ~= nil, "spawn " .. name)
            p.entity:SetCanSleep(false)
            p.Transform:SetPosition(x + index * 2, 0, z)
            players[name] = p
        end
        local enabled = GetModConfigData("Monster Night Vision")
        local wathom_enabled = enabled or GetModConfigData("wathom nightvision")
        TheWorld:PushEvent("ms_setclocksegs", {day=0,dusk=0,night=16})
        TheWorld:DoTaskInTime(4, function()
            local webber, wathom, wortox, wilson = players.webber, players.wathom, players.wortox, players.wilson
            check(webber.components.playervision:HasNightVision() == enabled, "Webber option")
            check(wathom._monsternightvision2hm:value() == (wathom_enabled and 2 or 0), "Wathom authoritative mode")
            check(not wortox.components.playervision:HasNightVision(), "Wortox blacklist")
            check(not wilson.components.playervision:HasNightVision(), "normal player unchanged")
            if wathom_enabled then
                check(wathom.components.playervision:HasNightVision(), "Wathom stable night vision")
                check(wathom.components.playervision.nonightvisioncc, "normal palette")
                check(not wathom:HasTag("WathomInDark"), "original native CheckLight tasks suppressed")
                check(wathom.updatewathomvisiontask == nil, "no queued UM reset")
                check(wathom._wathomlight2hm == nil, "old artificial light removed")
            end
            wilson:AddTag("monster")
            webber:RemoveTag("monster")
            TheWorld:PushEvent("ms_setclocksegs", {day=16,dusk=0,night=0})
            TheWorld:DoTaskInTime(3, function()
                check(wilson.components.playervision:HasNightVision() == enabled, "dynamic grant")
                check(not webber.components.playervision:HasNightVision(), "dynamic revoke")
                if wathom_enabled then
                    check(wathom.components.playervision:HasNightVision(), "day transition cannot disable vision")
                    wathom.components.playervision:SetGhostVision(true)
                    check(not wathom.components.playervision:HasNightVision(), "ghost releases own source")
                    wathom.components.playervision:SetGhostVision(false)
                    check(wathom.components.playervision:HasNightVision(), "resurrection restores own source")
                end
                CheckWoodie(function()
                    print("[MONSTER_VISION_NATIVE] ALL_PASS", enabled, wathom_enabled, TheWorld:HasTag("cave") and "cave" or "forest")
                    c_shutdown(false)
                end)
            end)
        end)
    end)
end)
