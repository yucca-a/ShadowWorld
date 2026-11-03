-- Disposable native worlds only: creates/kills players and forces world phases.
AddSimPostInit(function()
    if not TheWorld.ismastersim or TheNet:GetServerName() ~= "ShadowWorld isolated role vision test" then return end
    local function check(ok, why) assert(ok, "[ROLE_VISION_NATIVE] " .. why) end
    local options = {webber = "Webber Night Version", wurt = "Wurt Night Version", wonkey = "Wonkey Night Version"}
    local dangerous = TUNING.hardmode2hm and GetModConfigData("weather_change") and GetModConfigData("dusk_change") == -1
    local cave = TheWorld:HasTag("cave")
    local players = {}
    local function Enabled(name)
        return TUNING.easymode2hm and GetModConfigData("role_easy") and GetModConfigData(name .. "_easy") and
            GetModConfigData(options[name]) or false
    end
    local function SetPhase(phase)
        TheWorld:PushEvent("ms_setphase", phase)
    end
    local function CheckPhase(phase)
        -- Native cave worldstate keeps phase="night" permanently and exposes
        -- the running day/night clock separately through cavephase.
        local actualphase = cave and TheWorld.state.cavephase or TheWorld.state.phase
        check(actualphase == phase, "world phase reached " .. phase)
        for name, p in pairs(players) do
            local active = Enabled(name) and (cave or phase ~= "day")
            local vision = p.components.playervision
            print("[ROLE_VISION_NATIVE] STATE", name, phase, active, vision:HasNightVision(),
                p._rolevisionstate2hm and p._rolevisionstate2hm.enabled,
                p._rolevisionstate2hm and p._rolevisionstate2hm.active,
                p._rolenightvision2hm and p._rolenightvision2hm:value(), p.components.health:IsDead(),
                vision:HasGhostVision(), #vision.forcednightvisionstack, TUNING.easymode2hm, GetModConfigData("role_easy"))
            check(vision:HasNightVision() == active, name .. " vision at " .. phase)
            check(p._rolenightvision2hm:value() == active, name .. " replicated role mode")
            check((p._rolevisionlight2hm ~= nil) == (active and dangerous), name .. " physical light at " .. phase)
            check(p._webberlight2hm == nil and p._wurtlight2hm == nil and p._wonkeylight2hm == nil, name .. " no old light")
            if active then
                check(vision.nonightvisioncc, name .. " normal palette")
                vision:ForceNightVision(false) -- The actual legacy call used by Fenghua.
                check(vision:HasNightVision(), name .. " survives legacy disable")
                check(p.components.sanity.night_drain_mult == 0, name .. " original sanity effect")
                if dangerous then
                    check(not p.components.grue.immunity.nightvision, name .. " dangerous rule still applies")
                    local px,py,pz=p.Transform:GetWorldPosition()
                    local light=p._rolevisionlight2hm
                    local lx,ly,lz=light.Transform:GetWorldPosition()
                    print("[ROLE_VISION_NATIVE] LIGHT", name, px,py,pz,lx,ly,lz,
                        light.Light:IsEnabled(), light.Light:GetRadius(), light:IsAsleep(), TheSim:GetLightAtPoint(px,py,pz),p:IsInLight())
                    check(p:IsInLight(), name .. " tiny real light reaches native LightWatcher")
                else
                    check(p.components.grue.immunity.nightvision, name .. " native immunity without physical light")
                end
                check(not p.components.grue:CheckForStart(), name .. " protected from actual grue start")
            end
        end
        print("[ROLE_VISION_NATIVE] PHASE_PASS", phase, cave, dangerous)
    end
    TheWorld:DoTaskInTime(2, function()
        TheWorld:PushEvent("ms_setclocksegs", {day=8,dusk=4,night=4})
        TheWorld:PushEvent("ms_setmoonphase", {moonphase="new",iswaxing=true})
        SetPhase("night")
        local x, _, z = TheWorld.components.playerspawner:GetAnySpawnPoint()
        for index, name in ipairs({"webber", "wurt", "wonkey"}) do
            local p = SpawnPrefab(name)
            check(p ~= nil, "spawn " .. name)
            p.entity:SetCanSleep(false)
            p.Transform:SetPosition(x + index * 2, 0, z)
            p.components.health:SetInvincible(false)
            players[name] = p
        end
        TheWorld:DoTaskInTime(2, function()
            CheckPhase("night")
            local function ContinueAfterNight()
                for name, p in pairs(players) do
                    local light = p._rolevisionlight2hm
                    local vision = p.components.playervision
                    vision:SetGhostVision(true)
                    check(not vision:HasNightVision() and p._rolevisionlight2hm == nil, name .. " ghost releases ability and light")
                    check(light == nil or not light:IsValid(), name .. " old child light removed")
                    vision:SetGhostVision(false)
                    p:PushEvent("ms_respawnedfromghost")
                    check(vision:HasNightVision() == Enabled(name), name .. " resurrection restores ability")
                end
                SetPhase("day")
                TheWorld:DoTaskInTime(2, function()
                    CheckPhase("day")
                    SetPhase("dusk")
                    TheWorld:DoTaskInTime(2, function()
                        CheckPhase("dusk")
                        for name, p in pairs(players) do
                            local light = p._rolevisionlight2hm
                            p.components.health:Kill()
                            check(p._rolevisionlight2hm == nil and (light == nil or not light:IsValid()), name .. " real death removes light")
                            check(not p._rolenightvision2hm:value(), name .. " real death revokes replicated role")
                            p:Remove()
                        end
                        local p = SpawnPrefab("wonkey")
                        p.entity:SetCanSleep(false)
                        p.Transform:SetPosition(x, 0, z)
                        TheWorld:DoTaskInTime(1, function()
                            local light = p._rolevisionlight2hm
                            check(p.components.playervision:HasNightVision() == Enabled("wonkey"), "new entity reinitializes")
                            p:Remove()
                            check(light == nil or not light:IsValid(), "character removal destroys physical light")
                            print("[ROLE_VISION_NATIVE] ALL_PASS", cave, dangerous, Enabled("wonkey"))
                            c_shutdown(false)
                        end)
                    end)
                end)
            end
            if dangerous and cave and Enabled("wonkey") then
                for _,p in pairs(players) do p._rolevisionlight2hm.Light:Enable(false) end
                TheWorld:DoTaskInTime(1, function()
                    for name,p in pairs(players) do
                        check(p.components.playervision:HasNightVision(), name .. " vision survives physical light removal")
                        check(not p:IsInLight() and p.components.grue:CheckForStart(), name .. " danger without physical compensation")
                        p._rolevisionlight2hm.Light:Enable(true)
                    end
                    TheWorld:DoTaskInTime(1, function()
                        for name,p in pairs(players) do
                            check(p:IsInLight() and not p.components.grue:CheckForStart(), name .. " physical light restores safety")
                        end
                        print("[ROLE_VISION_NATIVE] LIGHT_SAFETY_CONTROL_PASS")
                        ContinueAfterNight()
                    end)
                end)
            else
                ContinueAfterNight()
            end
        end)
    end)
end)
