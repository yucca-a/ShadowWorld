-- Real entities/stategraph/equipment; only the chomp timeline is advanced explicitly.
local G = GLOBAL
G.setmetatable(env, {__index = function(_, key) return G.rawget(G, key) end})
local json = require("json")
G.VaultAudit = {}
local function emit(data) print("[VAUDIT] " .. json.encode(data)) end
AddSimPostInit(function() TheWorld:DoTaskInTime(1, function() emit({kind = "ready"}) end) end)

function G.VaultAudit.bat_shadow()
    local checks, cases, done, owned = 0, 0, false, {}
    local function check(ok, msg) checks = checks + 1; assert(ok, msg) end
    local function finish(ok, err)
        if done then return end
        done = true
        emit({kind = "bat_shadow", passed = ok, checks = checks, cases = cases, error = err and tostring(err)})
        -- Server is disposable; avoid masking a failure with secondary cleanup errors.
    end
    local function safe(fn)
        if done then return end
        local ok, err = pcall(fn)
        if not ok then finish(false, err) end
    end
    local function later(delay, fn) TheWorld:DoTaskInTime(delay, function() safe(fn) end) end
    local function spawn(prefab)
        local inst = assert(SpawnPrefab(prefab), prefab)
        owned[#owned + 1] = inst
        inst.entity:SetCanSleep(false)
        inst:StopBrain()
        return inst
    end
    local function row(name)
        cases = cases + 1
        emit({kind = "bat_shadow_case", name = name, checks = checks})
    end
    local parent = spawn("bat_boss")
    local owner = spawn("spider_warrior")
    if not owner.components.inventory then owner:AddComponent("inventory") end
    owner:AddTag("canwearhat")
    owner.components.health:SetInvincible(true)
    local x, y, z = TheWorld.components.playerspawner:GetAnySpawnPoint()
    parent.Transform:SetPosition(x + 30, y, z)
    owner.Transform:SetPosition(x, y, z)
    owner.sg:Stop()
    local spawner
    local function shadow(prefab)
        spawner.childreninside = 1
        local child = assert(spawner:SpawnChild(nil, prefab), "shadow spawned")
        child.entity:SetCanSleep(false)
        child:StopBrain()
        child.components.playerprox2hm:Stop()
        child.Transform:SetPosition(x, y, z)
        check(child:HasTag("swc2hm") and not child.persists, "actual shadow initialized")
        return child
    end
    local function attach(child, target)
        child.Transform:SetPosition(target.Transform:GetWorldPosition())
        child.sg:GoToState("chomp_attack", target)
        local state = child.sg.currentstate
        for _, event in ipairs(state.timeline) do
            if event.time <= 10 * FRAMES then event.fn(child) end
        end
        state.onupdate(child, FRAMES)
        check(target.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD) == child, "native chomp equipped bat")
        check(child:IsInLimbo() and child.sg.mem.ischaracterpassthrough, "attached during collision passthrough")
    end
    later(.2, function()
        spawner = assert(parent.components.childspawner2hm, "parent shadow spawner")
        spawner:StopSpawning()
        spawner:StopRegen()
        parent.components.playerprox2hm:Stop()
        local child = shadow("bat_boss")
        attach(child, owner)
        -- Before the fix, the pickup event schedules Remove and crashes on the next tick.
        later(.2, function()
            check(child:IsValid() and child.removetask2hm == nil, "attachment is not pickup death")
            check(child.components.equippable:IsEquipped(), "remains attached")
            row("attached_attack_survives")
            child.components.playerprox2hm.onfar(child)
            later(.2, function()
                check(not child:IsValid(), "attached shadow recalled")
                check(owner.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD) == nil, "owner head released")
                check(not child.fx and not child.chomptask and not child.unequiptask, "native unequip cleaned FX and tasks")
                check(spawner.numchildrenoutside == 0, "parent released child")
                row("attached_recall")

                local nextchild = shadow("bat_boss")
                attach(nextchild, owner)
                owner.components.inventory:DropItem(nextchild, true, true)
                check(nextchild:IsValid() and not nextchild:IsInLimbo(), "normal unequip survives")
                check(not nextchild.components.equippable:IsEquipped(), "normal unequip clears equipment")
                check(nextchild.sg.currentstate.name == "stun_pre", "native stun retained")
                check(nextchild.components.timer:TimerExists("chompcd"), "native cooldown retained")
                row("ordinary_unequip")
                nextchild.components.playerprox2hm.onfar(nextchild)
                later(1.8, function()
                    check(not nextchild:IsValid(), "unattached fade completes")
                    row("ground_recall")
                    local original = spawn("bat_boss")
                    attach(original, owner)
                    owner.components.inventory:DropItem(original, true, true)
                    check(original:IsValid() and original.sg.currentstate.name == "stun_pre", "original boss unchanged")
                    original:Remove()
                    row("original_boss")

                    -- Shadow-aligned native boss shares SGbat and the same equip callbacks.
                    local dark = shadow("bat_boss_shadow")
                    attach(dark, owner)
                    later(.2, function()
                        check(dark:IsValid() and dark.removetask2hm == nil, "dark boss attachment survives")
                        dark.components.playerprox2hm.onfar(dark)
                        later(.2, function()
                            check(not dark:IsValid() and not dark.fx, "dark boss recall cleans up")
                            check(owner.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD) == nil, "dark head released")
                            row("dark_boss_recall")
                            local rabbit = shadow("rabbit")
                            rabbit:PushEvent("onputininventory", {owner = owner})
                            check(rabbit.isdead2hm and rabbit.removetask2hm, "ordinary shadow pickup still recalls")
                            later(1.8, function()
                                check(not rabbit:IsValid(), "ordinary pickup removal completes")
                                row("ordinary_pickup")
                                local slurper = shadow("slurper")
                                slurper:PushEvent("onputininventory", {owner = owner})
                                check(not slurper.removetask2hm, "slurper attachment exception retained")
                                slurper:Remove()
                                row("slurper_exception")
                                local blocker = spawn("pigman")
                                blocker.Transform:SetPosition(x, y, z)
                                blocker.sg:Stop()
                                check(blocker:HasTag("character") and blocker:HasTag("locomotor"), "real collision blocker")
                                local crowded = shadow("bat_boss")
                                attach(crowded, owner)
                                crowded.components.playerprox2hm.onfar(crowded)
                                later(.2, function()
                                    check(not crowded:IsValid(), "crowded attached recall completes")
                                    check(crowded.pendingtasks == nil, "pending collision task cancelled on removal")
                                    row("crowded_recall")
                                    blocker:Remove()
                                    local dying = shadow("bat_boss")
                                    attach(dying, owner)
                                    dying.components.health:SetVal(0, "bat_shadow_regression")
                                    check(dying.isdead2hm and dying.removetask2hm, "lethal hit schedules recall")
                                    later(.2, function()
                                        check(not dying:IsValid(), "attached lethal recall completes")
                                        check(owner.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD) == nil, "lethal recall releases owner")
                                        check(spawner.numchildrenoutside == 0, "no tracked shadows remain")
                                        row("attached_lethal_hit")
                                        finish(true)
                                    end)
                                end)
                            end)
                        end)
                    end)
                end)
            end)
        end)
    end)
end
