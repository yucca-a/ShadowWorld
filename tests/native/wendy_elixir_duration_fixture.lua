AddSimPostInit(function()
    if not TheWorld.ismastersim then return end
    assert(TheNet:GetServerName() == "ShadowWorld isolated Wendy elixir test")
    TheWorld:PushEvent("ms_setautosaveenabled", false)
    TheWorld:DoStaticTaskInTime(1, function()
        local checks, failures, cases = 0, 0, 0
        local function check(ok, why) checks = checks + 1; assert(ok, why) end
        for _, name in ipairs({"slowregen", "fastregen", "attack", "speed", "shield", "retaliation", "revive", "lunar", "shadow"}) do
            for _, skilled in ipairs({false, true}) do
                for _, shared in ipairs({false, true}) do
                    cases = cases + 1
                    local p, ghost, potion
                    local ok, err = xpcall(function()
                        p = assert(SpawnPrefab("wendy"))
                        p.sg:GoToState("idle")
                        p.components.health:SetInvincible(true)
                        local skills = p.components.skilltreeupdater
                        skills:SetSkipValidation(true)
                        if skilled then skills:ActivateSkill("wendy_potion_duration", nil, true) end
                        check(skills:IsActivated("wendy_potion_duration") == skilled, "skill state")
                        if shared then
                            ghost = assert(SpawnPrefab("abigail"))
                            ghost._playerlink = p
                        end
                        potion = assert(SpawnPrefab("ghostlyelixir_" .. name))
                        potion.components.stackable:SetStackSize(10)
                        local prefab = potion.buff_prefab
                        local first
                        for dose = 1, 8 do
                            local target = shared and ghost or p
                            local old = p:GetDebuff(prefab) or p:GetDebuff("super_elixir_buff") or p:GetDebuff("elixir_buff")
                            local previous = old and old.components.timer:GetTimeLeft("decay") / 2 or 0
                            if old then old.components.timer:SetTimeLeft("decay", previous) end
                            -- Actual potion callback and real debuffs/timers. Self
                            -- application bypasses input targeting only; shared
                            -- application also uses the native consuming component.
                            if shared then
                                check(potion.components.ghostlyelixir:Apply(p, target), "shared apply")
                            else
                                check(potion.components.ghostlyelixir.doapplyelixerfn(potion, p, target), "self apply")
                            end
                            local buff = p:GetDebuff(prefab) or p:GetDebuff("super_elixir_buff") or p:GetDebuff("elixir_buff")
                            check(buff and buff.prefab == prefab, "correct player buff")
                            local time = buff.components.timer:GetTimeLeft("decay")
                            if dose == 1 then first = time end
                            check(math.abs(time - (previous + first)) < 0.01, "must add exactly one dose: previous=" .. previous .. " dose=" .. first .. " got=" .. time)
                        end
                        if skilled and potion.potion_tunings.skill_modifier_long_duration then
                            skills:DeactivateSkill("wendy_potion_duration")
                            check(not skills:IsActivated("wendy_potion_duration"), "skill removed")
                            local old = p:GetDebuff(prefab) or p:GetDebuff("super_elixir_buff") or p:GetDebuff("elixir_buff")
                            local previous = old.components.timer:GetTimeLeft("decay")
                            local target = shared and ghost or p
                            potion.components.ghostlyelixir.doapplyelixerfn(potion, p, target)
                            local buff = p:GetDebuff(prefab) or p:GetDebuff("super_elixir_buff") or p:GetDebuff("elixir_buff")
                            local time = buff.components.timer:GetTimeLeft("decay")
                            local multiplier = shared and ELIXIR_TEST_HARD and 1.5 or (1 + TUNING.SKILLS.WENDY.POTION_DURATION_MOD)
                            local expected = previous + first / multiplier
                            check(math.abs(time - expected) < 0.01, "skill change affects only newly added dose")
                        end
                    end, tostring)
                    if not ok then failures = failures + 1 end
                    print("[WENDY_ELIXIR_TEST]", ok and "PASS" or "FAIL", name, skilled and "skilled" or "plain", shared and "shared" or "self", err or "")
                    if ghost and ghost:IsValid() then ghost:Remove() end
                    if potion and potion:IsValid() then potion:Remove() end
                    if p and p:IsValid() then p:Remove() end
                end
            end
        end
        for _, skilled in ipairs({false, true}) do
            for _, shared in ipairs({false, true}) do
                cases = cases + 1
                local p, ghost, potions
                local ok, err = xpcall(function()
                    p = assert(SpawnPrefab("wendy"))
                    p.components.health:SetInvincible(true)
                    if skilled then
                        p.components.skilltreeupdater:SetSkipValidation(true)
                        p.components.skilltreeupdater:ActivateSkill("wendy_potion_duration", nil, true)
                    end
                    if shared then ghost = assert(SpawnPrefab("abigail")); ghost._playerlink = p end
                    potions = {attack = SpawnPrefab("ghostlyelixir_attack"), speed = SpawnPrefab("ghostlyelixir_speed")}
                    for _, potion in pairs(potions) do potion.components.stackable:SetStackSize(10) end
                    local function buff(who, prefab)
                        local b = who:GetDebuff(prefab) or who:GetDebuff("elixir_buff")
                        return b and b.prefab == prefab and b or nil
                    end
                    local basetimes = {}
                    for _, name in ipairs({"attack", "speed", "attack", "speed", "attack", "speed"}) do
                        local potion = potions[name]
                        local target = ghost or p
                        local before = {}
                        for _, who in ipairs(shared and {p, ghost} or {p}) do
                            before[who] = {}
                            for key, other in pairs(potions) do
                                local b = buff(who, other.buff_prefab)
                                if b then
                                    local left = b.components.timer:GetTimeLeft("decay")
                                    if key == name then left = left / 2; b.components.timer:SetTimeLeft("decay", left) end
                                    before[who][key] = left
                                end
                            end
                        end
                        if shared then check(potion.components.ghostlyelixir:Apply(p, target), "interleaved shared")
                        else check(potion.components.ghostlyelixir.doapplyelixerfn(potion, p, target), "interleaved self") end
                        for who, old in pairs(before) do
                            basetimes[who] = basetimes[who] or {}
                            for key, other in pairs(potions) do
                                local b = buff(who, other.buff_prefab)
                                if key == name then
                                    check(b ~= nil, "selected buff present")
                                    local left = b.components.timer:GetTimeLeft("decay")
                                    basetimes[who][key] = basetimes[who][key] or left
                                    check(math.abs(left - ((old[key] or 0) + basetimes[who][key])) < .01,
                                        "interleaved same drug adds one dose")
                                elseif old[key] then
                                    check(b ~= nil, "different drug is not cleared")
                                    check(math.abs(b.components.timer:GetTimeLeft("decay") - old[key]) < .01,
                                        "different drug timer remains independent")
                                end
                            end
                        end
                    end
                end, tostring)
                if not ok then failures = failures + 1 end
                print("[WENDY_ELIXIR_TEST]", ok and "PASS" or "FAIL", "interleaved_attack_speed", skilled, shared, err or "")
                if ghost and ghost:IsValid() then ghost:Remove() end
                if potions then for _, potion in pairs(potions) do if potion:IsValid() then potion:Remove() end end end
                if p and p:IsValid() then p:Remove() end
            end
        end
        print("[WENDY_ELIXIR_TEST] RESULT", "cases=" .. cases, "checks=" .. checks, "failures=" .. failures)
        c_shutdown(false)
    end)
end)
