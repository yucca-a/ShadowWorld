AddSimPostInit(function()
    if not TheWorld.ismastersim then return end
    assert(TheNet:GetServerName() == "ShadowWorld isolated right action test")
    TheWorld:PushEvent("ms_setautosaveenabled", false)
    TheWorld:DoTaskInTime(2, function()
        local checks = 0
        local function check(ok, why)
            checks = checks + 1
            assert(ok, "RIGHT_ACTION: " .. why)
            print("[RIGHT_ACTION] PASS", why)
        end
        local x, _, z = TheWorld.components.playerspawner:GetAnySpawnPoint()
        local players = {}
        for _, name in ipairs({"winona", "wilson", "wes", "wanda", "waxwell"}) do
            local p = SpawnPrefab(name)
            p.entity:SetCanSleep(false)
            p.Transform:SetPosition(x, 0, z)
            p.components.health:SetInvincible(true)
            p:AddComponent("playercontroller")
            p:AddComponent("playeractionpicker")
            p.components.playercontroller.IsControlPressed = function() return p.fixturectrl2hm == true end
            p:PushEvent("setowner")
            players[#players + 1] = p
        end
        TheWorld:DoTaskInTime(.2, function()
            local pos = Vector3(x + 2, 0, z)
            for _, p in ipairs(players) do
                local picker = p.components.playeractionpicker
                check(picker.rightaction2hm ~= nil, p.prefab .. " shared character ability installed")
                p.last_rightaction2hm_time = GetTime() - 20
                if p.prefab == "waxwell" then
                    for _, name in ipairs({"armor_sanity", "dreadstonehat"}) do
                        local gear = SpawnPrefab(name)
                        p.components.inventory:GiveItem(gear)
                        p.components.inventory:Equip(gear)
                    end
                    check(p:HasTag("shadowlunge2hm"), "Maxwell native shadow equipment satisfies lunge requirement")
                end
                local axe = SpawnPrefab("axe")
                p.components.inventory:GiveItem(axe)
                p.components.inventory:Equip(axe)
                local function pick()
                    local _, right = picker:DoGetMouseActions(pos)
                    return right and right.action
                end
                local ordinary = pick()
                check(ordinary ~= nil, p.prefab .. " ordinary held tool allows own ability")
                local medal = SpawnPrefab("devour_soul_certificate")
                p.components.inventory:GiveItem(medal)
                p.components.inventory:Equip(medal)
                p.components.inventory:GiveItem(SpawnPrefab("wortox_soul"))
                check(p:HasTag("medal_blinker"), p.prefab .. " real soul medal equipped")
                -- Dedicated servers have no local net-dirty UI consumer.
                p:PushEvent("medalblinkabledirty")
                check(pick() == ACTIONS.BLINK, p.prefab .. " medal blink keeps plain RMB")
                p.fixturectrl2hm = true
                check(pick() == ordinary, p.prefab .. " Ctrl selects own ability with real medal")
                p.fixturectrl2hm = false
                local spear = SpawnPrefab("spear_wathgrithr_lightning")
                local restricted = spear.components.equippable.restrictedtag
                if restricted then p:AddTag(restricted) end
                p.components.inventory:GiveItem(spear)
                p.components.inventory:Equip(spear)
                check(not spear.components.aoetargeting:IsEnabled(), p.prefab .. " locked native spear skill")
                check(pick() == ACTIONS.BLINK, p.prefab .. " locked spear leaves medal blink usable")
                p.components.inventory:Unequip(medal.components.equippable.equipslot)
                check(pick() == ordinary, p.prefab .. " locked spear leaves own ability usable")
                -- Emulate the standard enabled state a skill-tree patch grants;
                -- do not replace the real spear's spell or character states.
                spear.components.aoetargeting:SetEnabled(true)
                p.fixturectrl2hm = true
                check(pick() == ordinary, p.prefab .. " Ctrl selects own ability with enabled native spear")
                p.fixturectrl2hm = false
                local normal = pick()
                check(normal == nil or normal == ACTIONS.CASTAOE, p.prefab .. " native spear aiming is not replaced")
                p:Remove()
            end
            print("[RIGHT_ACTION] ALL_PASS", checks)
            c_shutdown(false)
        end)
    end)
end)
