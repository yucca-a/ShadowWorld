-- Creates/kills/deconstructs entities. Import ONLY in a disposable isolated world.
local tracked = {}
local SERVER_NAME = "ShadowWorld isolated eyeturret recovery test"
local TIMER = "eyeturret_recovery2hm"
AddPrefabPostInitAny(function(inst)
    if not TheWorld.ismastersim or TheNet:GetServerName() ~= SERVER_NAME then return end
    inst:ListenForEvent("on_loot_dropped", function(loot, data)
        local counts = data ~= nil and tracked[data.dropper] or nil
        if counts ~= nil then counts[loot.prefab] = (counts[loot.prefab] or 0) + 1 end
    end)
end)
AddSimPostInit(function()
    if not TheWorld.ismastersim or TheNet:GetServerName() ~= SERVER_NAME then return end
    TheWorld:PushEvent("ms_setautosaveenabled", false)
    local function check(ok, why) assert(ok, "[EYETURRET_RECOVERY] " .. why) end
    local function near(a, b, why) check(math.abs(a - b) < .05, why .. ": " .. tostring(a) .. " / " .. tostring(b)) end
    local function alpha(inst) local _, _, _, a = inst.AnimState:GetMultColour(); return a end
    TheWorld:DoTaskInTime(3, function()
        local sx, sy, sz = TheWorld.components.playerspawner:GetAnySpawnPoint()
        local pt = FindNearbyLand(Vector3(sx, sy, sz), 5)
        check(pt ~= nil, "land point")
        local tower = SpawnPrefab("eyeturret")
        tower.Transform:SetPosition(pt.x, 0, pt.z)
        tracked[tower] = {}
        TheWorld:DoTaskInTime(1.3, function()
            if not GetModConfigData("eyeturret") then
                check(not tower.components.health.nofadeout and not tower.components.timer, "disabled native lifecycle")
                tower.components.health:ForceKill()
                TheWorld:DoTaskInTime(4, function()
                    check(not tower:IsValid(), "disabled tower is removed after death")
                    check(next(tracked[tower]) ~= nil, "disabled death drops native loot")
                    print("[EYETURRET_RECOVERY] DISABLED_PASS")
                    c_shutdown(false)
                end)
                return
            end
            local player = SpawnPrefab("wilson")
            player.entity:SetCanSleep(false)
            player.Transform:SetPosition(pt.x, 0, pt.z + 3)
            player.components.health:SetInvincible(true)
            if player.components.playeractionpicker == nil then player:AddComponent("playeractionpicker") end
            local staff = SpawnPrefab("greenstaff")
            player.components.inventory:GiveItem(staff)
            player.components.inventory:Equip(staff)
            for _, prefab in ipairs({"dragon_scales", "shroom_skin"}) do
                check(tower.components.trader:AcceptGift(player, SpawnPrefab(prefab)), "upgrade " .. prefab)
            end
            local deaths = 0
            tower:ListenForEvent("death", function() deaths = deaths + 1 end)
            local weapon = tower.components.combat:GetWeapon()
            local radius = tower.Physics:GetRadius()
            tower.components.health:ForceKill()
            near(tower.components.health.currenthealth, 0, "actual zero health")
            near(tower.components.timer:GetTimeLeft(TIMER), 5 * TUNING.TOTAL_DAY_TIME, "exact recovery duration")
            check(tower.eyeturretrecovering2hm and tower.persists and not tower:HasTag("NOCLICK"), "resting entity persists and is selectable")
            check(tower.components.combat:GetWeapon() == weapon, "native projectile weapon retained")
            check(tower.entity:IsVisible() and tower.base.entity:IsVisible(), "base and spell target remain visible")
            check(tower.base.client_forward_target == tower, "base forwards mouse target to tower")
            near(alpha(tower), 1, "eye starts fade-out without snapping")
            near(alpha(tower.base), 1, "separate native base stays opaque")
            near(tower.Physics:GetRadius(), radius, "obstacle radius retained")
            tower.components.health:DoDelta(1000, nil, "test heal", true)
            near(tower.components.health.currenthealth, 0, "external heal cannot end rest")
            check(deaths == 1 and next(tracked[tower]) == nil, "single death without loot")
            tower:PushEvent("doattack", {target = player})
            TheWorld:DoTaskInTime(.3, function()
                check(alpha(tower) > 0 and alpha(tower) < 1, "native fade-out has intermediate opacity")
                near(alpha(tower.base), 1, "base does not fade with eye")
                near(tower.components.health.currenthealth, 0, "fade-out does not delay death")
            end)
            TheWorld:DoTaskInTime(.75, function()
                near(alpha(tower), 0, "fade-out completes")
                check(tower.eyeturretfadetask2hm == nil, "completed fade releases task")
                print("[EYETURRET_RECOVERY] FADE_OUT_PASS")
            end)
            TheWorld:DoTaskInTime(4, function()
                check(tower:IsValid() and tower.sg.currentstate.name == "eyeturret_recover2hm", "death animation/attack cannot remove or wake tower")
                check(next(tracked[tower]) == nil, "no delayed death loot")
                near(tower.components.health.currenthealth, 0, "native regeneration remains stopped")
                -- Actual native save/restore, including arbitrary component load order.
                local record = tower:GetSaveRecord()
                local left = tower.components.timer:GetTimeLeft(TIMER)
                tower:Remove()
                local restored = SpawnSaveRecord(record)
                tracked[restored] = {}
                check(restored.eyeturretrecovering2hm and restored.eyeturretfire2hm and restored.eyeturretspore2hm,
                    "save restores rest and both upgrades")
                near(restored.components.timer:GetTimeLeft(TIMER), left, "reload retains remaining time")
                near(alpha(restored), 0, "loaded eye hidden")
                near(alpha(restored.base), 1, "loaded base visible")
                check(staff.components.spellcaster:CanCast(player, restored), "native greenstaff accepts dormant target")
                check(not staff.components.spellcaster.canuseondead, "staff exception is temporary")
                print("[EYETURRET_RECOVERY] DEATH_SAVE_PASS")
                -- Advance elapsed simulation time through the native timer.
                restored.components.timer:LongUpdate(left - 1)
                TheWorld:DoTaskInTime(.5, function()
                    check(restored.eyeturretrecovering2hm, "does not wake before five days")
                end)
                TheWorld:DoTaskInTime(1.35, function()
                    check(not restored.eyeturretrecovering2hm and restored.components.health.currenthealth == 2000,
                        "gameplay recovers at timer deadline before fade-in completes")
                    check(alpha(restored) > 0 and alpha(restored) < 1, "native fade-in has intermediate opacity")
                    near(alpha(restored.base), 1, "base stays opaque during fade-in")
                end)
                TheWorld:DoTaskInTime(1.95, function()
                    check(not restored.eyeturretrecovering2hm and not restored.components.health:IsDead(), "timer restores tower")
                    near(restored.components.health.currenthealth, 2000, "full health on recovery")
                    near(alpha(restored), 1, "eye restored")
                    check(restored.eyeturretfadetask2hm == nil, "fade-in completes without lingering task")
                    print("[EYETURRET_RECOVERY] FADE_IN_PASS")
                    near(restored.components.health.regen.amount, 50, "regen restarted")
                    check(not (restored._brainstopped and restored._brainstopped[TIMER]), "recovery releases its brain stop")
                    check(restored.components.combat:GetWeapon() ~= nil, "loaded tower has projectile weapon")
                    local victim = SpawnPrefab("pigman")
                    victim.Transform:SetPosition(pt.x + 8, 0, pt.z)
                    victim:StopBrain()
                    victim.components.health:SetMaxHealth(10000)
                    local shot = SpawnPrefab("eye_charge")
                    shot.components.projectile.owner = restored.components.combat:GetWeapon()
                    shot.components.projectile:Hit(victim)
                    near(10000 - victim.components.health.currenthealth, 200 * TUNING.ELECTRIC_DAMAGE_MULT, "recovered projectile damage")
                    check(victim.eyeturretsafefire2hm ~= nil, "scale upgrade survives recovery")
                    victim:Remove()
                    restored.components.health:ForceKill()
                    near(restored.components.timer:GetTimeLeft(TIMER), 5 * TUNING.TOTAL_DAY_TIME, "second defeat restarts full duration")
                    print("[EYETURRET_RECOVERY] RECOVER_ATTACK_PASS")
                    local function Deconstruct(target, fire, spore)
                        tracked[target] = {}
                        local uses = staff.components.finiteuses:GetUses()
                        local sanity = player.components.sanity.current
                        local actions = {}
                        staff:CollectActions("EQUIPPED", player, target, actions, true)
                        local found = false
                        for _, a in ipairs(actions) do if a == ACTIONS.CASTSPELL then found = true end end
                        check(found, "native equipped action offers deconstruction")
                        check(staff.components.spellcaster:CanCast(player, target), "native spell validation")
                        check(ACTIONS.CASTSPELL.fn(BufferedAction(player, target, ACTIONS.CASTSPELL, staff)), "native CASTSPELL action")
                        check(not target:IsValid() and target.eyeturretfadetask2hm == nil, "deconstruction removes target and cancels any eye fade")
                        near(uses - staff.components.finiteuses:GetUses(), 1, "native staff use consumed")
                        near(sanity - player.components.sanity.current, TUNING.SANITY_MEDLARGE, "native sanity cost")
                        local counts = tracked[target]
                        check(counts.dragon_scales == (fire and 1 or nil), "only installed dragon scale refunded")
                        check(counts.shroom_skin == (spore and 1 or nil), "only installed mushroom skin refunded")
                        for _, ingredient in ipairs(AllRecipes[target.prefab].ingredients) do
                            if string.sub(ingredient.type, -3) ~= "gem" then
                                near(counts[ingredient.type] or 0, ingredient.amount, "native recipe refund " .. ingredient.type)
                            end
                        end
                    end
                    Deconstruct(restored, true, true)
                    local active = SpawnPrefab("eyeturret")
                    active.Transform:SetPosition(pt.x + 5, 0, pt.z)
                    check(active.components.trader:AcceptGift(player, SpawnPrefab("dragon_scales")), "active scale upgrade")
                    Deconstruct(active, true, false)
                    local plain = SpawnPrefab("eyeturret")
                    plain.Transform:SetPosition(pt.x + 10, 0, pt.z)
                    Deconstruct(plain, false, false)
                    -- Material refund also covers the native deployable item.
                    local packed = SpawnPrefab("eyeturret_item")
                    packed.Transform:SetPosition(pt.x + 15, 0, pt.z)
                    check(packed.components.trader:AcceptGift(player, SpawnPrefab("shroom_skin")), "portable mushroom upgrade")
                    -- Portable fallback drops directly, so count its creation rather than native loot event.
                    local count = 0
                    for _, e in pairs(Ents) do if e.prefab == "shroom_skin" then count = count + 1 end end
                    check(ACTIONS.CASTSPELL.fn(BufferedAction(player, packed, ACTIONS.CASTSPELL, staff)), "native portable deconstruction")
                    check(not packed:IsValid(), "portable removed")
                    local after = 0
                    for _, e in pairs(Ents) do if e.prefab == "shroom_skin" then after = after + 1 end end
                    near(after - count, 1, "portable skin refunded")
                    print("[EYETURRET_RECOVERY] DECONSTRUCTION_PASS")
                    TheWorld:DoTaskInTime(1, function()
                        check(not restored:IsValid(), "removed rest timer cannot resurrect deconstructed tower")
                        print("[EYETURRET_RECOVERY] ALL_PASS")
                        c_shutdown(false)
                    end)
                end)
            end)
        end)
    end)
end)
