local G = GLOBAL
G.setmetatable(env, {__index = function(_, key) return G.rawget(G, key) end})
local json = require("json")
G.VaultAudit = {}
local function emit(data) print("[VAUDIT] " .. json.encode(data)) end
AddSimPostInit(function() TheWorld:DoTaskInTime(1, function() emit({kind = "ready"}) end) end)

local function Harness(kind)
    local h = {owned = {}, checks = 0, done = false}
    function h.check(ok, message) h.checks = h.checks + 1; assert(ok, message) end
    function h.spawn(prefab)
        local ent = assert(SpawnPrefab(prefab), prefab)
        h.owned[#h.owned + 1] = ent
        if ent.components.hunger then ent.components.hunger:SetRate(0) end
        if ent.components.health then ent.components.health:SetInvincible(true) end
        if ent.brain then ent.brain:Stop() end
        return ent
    end
    function h.finish(ok, err)
        if h.done then return end
        h.done = true
        for i = #h.owned, 1, -1 do if h.owned[i]:IsValid() then h.owned[i]:Remove() end end
        emit({kind = kind, passed = ok, checks = h.checks, error = not ok and tostring(err):gsub("'", "") or nil})
    end
    function h.safe(fn)
        if h.done then return end
        local ok, err = pcall(fn)
        if not ok then h.finish(false, err) end
    end
    function h.later(t, fn) TheWorld:DoTaskInTime(t, function() h.safe(fn) end) end
    return h
end

function G.VaultAudit.moonfire()
    local h = Harness("moonfire")
    h.safe(function()
        local p, sword = h.spawn("wilson"), h.spawn("sword_lunarplant")
        p.userid = "KU_MOONFIRE"
        p:AddComponent("playeractionpicker")
        p:AddComponent("playercontroller")
        p.entity:SetCanSleep(false)
        local pos = Vector3(0, 0, 0)
        for _, e in pairs(Ents) do if e:HasTag("multiplayer_portal") then pos = e:GetPosition(); break end end
        p.Physics:Teleport(pos:Get())
        local dest
        for x = 1, 4 do
            local point = pos + Vector3(x, 0, 0)
            if TheWorld.Map:IsAboveGroundAtPoint(point:Get()) then dest = point; break end
        end
        dest = assert(dest, "land target")
        local material = h.spawn("lunar_seed")
        h.check(sword.components.repairable2hm.customrepair(sword, 1, p, material), "real celestial jewel upgrade")
        h.check(not material:IsValid() and sword:HasTag("swordleap2hm"), "material consumed and upgrade applied")
        p.components.inventory:GiveItem(sword)
        p.components.inventory:Equip(sword)
        local graph = p.sg.sg
        local cast = graph.actionhandlers[ACTIONS.CASTSPELL].deststate
        local client = require("stategraphs/SGwilson_client")
        local function action() return BufferedAction(p, nil, ACTIONS.CASTSPELL, sword, dest) end
        if FIX_BEFORE then
            p.sg:GoToState("combat_leap_start")
            sword.components.spellcaster.spell(sword, nil, dest, p)
            p.sg:GoToState("idle")
            h.check(not sword.components.rechargeable, "old skill has no native cooldown circle")
            h.check(cast(p, action()) == "combat_leap_start", "old server accepts wind-up during cooldown")
            h.check(client.actionhandlers[ACTIONS.CASTSPELL].deststate(p, action()) == "combat_leap_start", "old prediction accepts wind-up")
            h.finish(true)
            return
        end
        h.check(sword.components.rechargeable:IsCharged() and sword._moonfire_ready2hm:value(), "upgrade starts ready")
        local a = action()
        h.check(cast(p, a) == "combat_leap_start", "ready server route")
        p:PushBufferedAction(a)
        p.sg:GoToState("combat_leap_start")
        h.later(1.2, function()
            local recharge = sword.components.rechargeable
            h.check(not recharge:IsCharged() and recharge:GetTimeToCharge() > 7, "actual leap starts ten-second cooldown")
            h.check(not sword._moonfire_ready2hm:value() and not sword._reticule2hm:value(), "cooldown replicated and aiming disabled")
            local classified = sword.replica.inventoryitem.classified
            h.check(classified.recharge:value() < 180 and classified.rechargetime:value() == 10, "native item-tile cooldown circle data")
            h.check(not sword:HasTag("castonpoint") and not sword:HasTag("castontargets") and not sword:HasTag("castonpointwater"), "right-click collection disabled")
            p.sg:GoToState("idle")
            for i = 1, 5 do
                h.check(cast(p, action()) == nil, "no server wind-up during cooldown")
                h.check(client.actionhandlers[ACTIONS.CASTSPELL].deststate(p, action()) == nil, "no predicted wind-up during cooldown")
            end
            p.bufferedaction = action() -- a request queued while the skill was ready
            p.sg:GoToState("combat_leap_start")
            h.check(p.sg.currentstate.name == "idle" and not p:GetBufferedAction(), "stale queued cast cancels before wind-up")
            -- idle may play its own animation; the pre-leap animation must never start.
            h.check(not p.AnimState:IsCurrentAnimation("atk_leap_pre"), "cooldown never plays anticipation")
            h.check(not p.sg:HasStateTag("busy") and p.components.playercontroller:IsEnabled(), "rejected cast leaves controls enabled")
            local attack = BufferedAction(p, h.spawn("pigman"), ACTIONS.ATTACK, sword)
            h.check(graph.actionhandlers[ACTIONS.ATTACK].deststate(p, attack) == "swordleapstate2hm", "ordinary attacks remain available during cooldown")
            -- Saved cooldowns use the same native component as the ring.
            local before = recharge:GetPercent()
            local saved = sword:GetSaveRecord()
            p.components.inventory:Unequip(EQUIPSLOTS.HANDS)
            sword:Remove()
            sword = assert(SpawnSaveRecord(saved)); h.owned[#h.owned + 1] = sword
            h.check(math.abs(sword.components.rechargeable:GetPercent() - before) < .001, "cooldown survives native save/load")
            h.check(not sword._moonfire_ready2hm:value() and not sword.components.spellcaster.spell, "loaded cooldown has no cast action")
            p.components.inventory:GiveItem(sword); p.components.inventory:Equip(sword)
            h.later(10.1, function()
                h.check(sword.components.rechargeable:IsCharged() and sword._moonfire_ready2hm:value(), "timer naturally finishes")
                h.check(sword.components.spellcaster.spell and sword:HasTag("castonpoint") and sword._reticule2hm:value(), "skill and aiming restore on charge")
                h.check(cast(p, action()) == "combat_leap_start", "casting available again")
                h.finish(true)
            end)
        end)
    end)
end

function G.VaultAudit.boots()
    local h = Harness("boots")
    h.safe(function()
        local p = h.spawn("wanda")
        local original = assert(p.components.slipperyfeet)
        local first, second = h.spawn("bootleg2hm"), h.spawn("bootleg_2hm")
        p.components.inventory:GiveItem(first)
        p.components.inventory:GiveItem(second)
        h.later(.15, function()
            if FIX_BEFORE then
                h.check(p.components.slipperyfeet == nil, "old boots remove component instead of suppressing slipping")
            else
                h.check(p.components.slipperyfeet == original, "carrying boots keeps original component")
                h.check(#p.bootlegs2hm == 2, "both protection sources tracked")
                original:DoDelta(1000); h.check(original.slippiness == 0, "slip accumulation suppressed")
                original:SetCurrent(1000); h.check(original.slippiness == 0, "direct slip assignment suppressed")
                p.components.inventory:DropItem(first)
                h.later(.1, function()
                    original:DoDelta(3); h.check(original.slippiness == 0, "remaining boot still protects")
                    p.components.inventory:DropItem(second)
                    h.later(.1, function()
                        original:DoDelta(1); h.check(original.slippiness > 0, "last boot removed restores normal slipping")
                        p.components.inventory:GiveItem(first)
                        h.later(.1, function()
                            h.check(original.slippiness == 0 and p.components.slipperyfeet == original, "pickup clears slip without replacing component")
                        end)
                    end)
                end)
            end
            -- Reproduce both log callbacks with real native entity retirement and
            -- callbacks captured from native/UM scheduled initialization tasks.
            local index, nextcase = 0
            nextcase = function()
                index = index + 1
                local name = ({"wanda", "wathgrithr"})[index]
                if not name then h.finish(true); return end
                local actor = h.spawn(name)
                local component = actor.components.slipperyfeet
                local queued = {}
                for _, field in ipairs({"inittask", "inittask2"}) do
                    local task = component[field]
                    if task and task.fn then queued[#queued + 1] = task.fn; task:Cancel() end
                end
                actor:Remove()
                h.later(.1, function()
                    local errors = 0
                    for _, callback in ipairs(queued) do if not pcall(callback, actor) then errors = errors + 1 end end
                    h.check(#queued >= 1, "captured actual queued initializers")
                    h.check(FIX_BEFORE and errors >= 1 or not FIX_BEFORE and errors == 0, "retired-entity callbacks " .. name)
                    if not FIX_BEFORE then
                        h.check(not component.inittask and not component.inittask2 and not component.checknearbyentitytask, "all init/nearby tasks cleaned")
                    end
                    nextcase()
                end)
            end
            h.later(.6, nextcase)
        end)
    end)
end
