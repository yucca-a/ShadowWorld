AddSimPostInit(function()
    if not TheWorld.ismastersim then return end
    assert(TheNet:GetServerName() == "ShadowWorld isolated electrical test")
    TheWorld:PushEvent("ms_setautosaveenabled", false)
    TheWorld:DoTaskInTime(1, function()
        local checks = 0
        local function check(value, message)
            checks = checks + 1
            assert(value, "Winona worker: " .. message)
        end
        local function near(a, b) return math.abs(a - b) < 0.001 end
        local Guard = require("umcompatguard2hm")
        local config = rawget(GLOBAL, "UM_CONFIG")
        local beta = config ~= nil
        local active = beta and config.WINONAWORKER and GetModConfigData("um_patch")
        local worker = beta and config.WINONAWORKER or not beta and TUNING.DSTU and TUNING.DSTU.WINONA_WORKER
        local roleenabled = TUNING.easymode2hm and GetModConfigData("role_easy") and GetModConfigData("winona_easy")
        local enhanced = worker and roleenabled
        local winona = SpawnPrefab("winona")
        check(not not winona.umworkerpatched2hm == not not active, "only configured known beta receives repair")
        local function listeners(inst, event, id)
            local count = 0
            local group = inst.event_listeners[event]
            for _, fn in ipairs(group and group[inst] or {}) do
                if Guard.Known(fn, id) then count = count + 1 end
            end
            return count
        end
        local work, uses = winona.components.workmultiplier, winona.components.efficientuser
        local grass = SpawnPrefab("grass")
        local function pick(inst)
            return inst.sg.sg.actionhandlers[ACTIONS.PICK].deststate(inst, BufferedAction(inst, grass, ACTIONS.PICK))
        end
        if not enhanced then
            if worker then check(near(work:GetMultiplier(ACTIONS.CHOP), 1), "upstream lifecycle patch does not initialize disabled local enhancement") end
            if beta and not config.WINONAWORKER then
                check(listeners(winona, "performaction", "winona_worker_drain") == 0, "disabled upstream worker remains disabled")
            end
            check(winona:HasTag("hungrybuilder"), "native character tag is not deleted")
            winona.components.hunger:SetPercent(0.1)
            local route = winona.sg.sg.actionhandlers[ACTIONS.BUILD].deststate(winona, BufferedAction(winona, nil, ACTIONS.BUILD, nil, nil, "axe"))
            local nohungry = roleenabled and GetModConfigData("Winona No Hungry Builder")
            check(route == (nohungry and "domediumaction" or "dohungrybuild"), "crafting respects only local enhancement gate")
            winona.sg:GoToState(route)
            check(near(winona.sg.timeout, nohungry and 0.5 or 2), "real low-hunger crafting timeout with worker unavailable or local role disabled")
            winona.sg:GoToState("idle")
            print("[ELECTRICAL] ALL_PASS", checks)
            c_shutdown(false)
            return
        end
        check(near(work:GetMultiplier(ACTIONS.CHOP), 1.5) and near(uses:GetMultiplier(ACTIONS.CHOP), 0.5), "full-hunger spawn initialized")
        local gatherstate = beta and "dohungrybuild" or "domediumaction"
        check(pick(winona) == gatherstate, "native UM gathering route preserved")
        check(winona:HasTag("hungrybuilder"), "native work and gathering tag preserved")
        local function build(inst)
            return inst.sg.sg.actionhandlers[ACTIONS.BUILD].deststate(inst, BufferedAction(inst, nil, ACTIONS.BUILD, nil, nil, "axe"))
        end
        check(build(winona) == (GetModConfigData("Winona No Hungry Builder") and "domediumaction" or "dohungrybuild"), "crafting enhancement scoped to BUILD")
        if GetModConfigData("Winona No Hungry Builder") then
            local clientgraph = require("stategraphs/SGwilson_client")
            local clienthook
            require("winonabuilder2hm").Install({GLOBAL = GLOBAL, AddPrefabPostInit = function() end,
                AddStategraphPostInit = function(name, fn) if name == "wilson_client" then clienthook = fn end end}, true)
            clienthook(clientgraph)
            check(clientgraph.actionhandlers[ACTIONS.BUILD].deststate(winona,
                BufferedAction(winona, nil, ACTIONS.BUILD, nil, nil, "axe")) == "domediumaction", "real client BUILD handler agrees")
        end
        for i = 1, 5 do
            local other = SpawnPrefab("winona")
            check(pick(other) == gatherstate and debug.getinfo(other.sg.sg.actionhandlers[ACTIONS.PICK].deststate, "S").source:find("init/init_character_changes/winona.lua", 1, true), "native PICK remains upstream-owned " .. i)
            other:Remove()
        end
        local wilson = SpawnPrefab("wilson")
        check(pick(wilson) ~= "dohungrybuild", "other characters retain native picking")
        local axe = SpawnPrefab("axe")
        winona.components.inventory:GiveItem(axe); winona.components.inventory:Equip(axe)
        local function chop()
            local tree = SpawnPrefab("evergreen")
            local h, w, u = winona.components.hunger.current, tree.components.workable:GetWorkLeft(), axe.components.finiteuses.current
            winona.bufferedaction = BufferedAction(winona, tree, ACTIONS.CHOP, axe)
            check(winona:PerformBufferedAction(), "native chop succeeds")
            local result = {h - winona.components.hunger.current, w - tree.components.workable:GetWorkLeft(), u - axe.components.finiteuses.current}
            tree:Remove()
            return unpack(result)
        end
        for _, row in ipairs({{0.9, 1.5, 0.5, 0.2}, {0.4, 1, 1, 0.1}, {0.1, 0.666, 1.333, 0}}) do
            winona.components.hunger:SetPercent(row[1])
            if winona._cdtask then winona._cdtask:Cancel(); winona._cdtask = nil end
            check(near(work:GetMultiplier(ACTIONS.CHOP), row[2]), "hunger tier work amount " .. row[1])
            check(near(uses:GetMultiplier(ACTIONS.CHOP), row[3]), "hunger tier tool efficiency " .. row[1])
            check(build(winona) == (GetModConfigData("Winona No Hungry Builder") and "domediumaction" or "dohungrybuild"), "crafting hunger preference preserved " .. row[1])
            local hunger, worked, used = chop()
            check(near(hunger, row[4] * winona.components.hunger.burnratemodifiers:Get()), "native action hunger cost " .. row[1])
            check(near(worked, row[2]) and near(used, row[3]), "native work and durability " .. row[1])
        end
        winona.components.hunger:SetPercent(0.9)
        if winona._cdtask then winona._cdtask:Cancel(); winona._cdtask = nil end
        chop()
        local cost = chop()
        check(near(cost, 0), "original hunger cooldown preserved")
        -- Enter and advance real states through their native timeout callbacks.
        local gather = SpawnPrefab("grass")
        winona.components.hunger:SetPercent(0.9)
        if winona._cdtask then winona._cdtask:Cancel(); winona._cdtask = nil end
        winona.bufferedaction = BufferedAction(winona, gather, ACTIONS.PICK)
        local beforepick = winona.components.hunger.current
        winona.sg:GoToState(pick(winona))
        check(near(winona.sg.timeout, 0.5), "native gathering state uses accelerated duration")
        winona.sg:UpdateState(0.5 + FRAMES)
        check(not gather.components.pickable:CanBePicked(), "native gathering timeout actually picks")
        check(near(beforepick - winona.components.hunger.current, 0.1 * winona.components.hunger.burnratemodifiers:Get()), "native gathering consumes original hunger once")
        winona.sg:GoToState("idle")
        for _, name in ipairs({"twigs", "flint"}) do
            local material = SpawnPrefab(name)
            material.components.stackable:SetStackSize(4)
            winona.components.inventory:GiveItem(material)
        end
        local function countaxes()
            local count = 0
            for _, slots in ipairs({winona.components.inventory.itemslots, winona.components.inventory.equipslots}) do
                for _, item in pairs(slots) do if item.prefab == "axe" then count = count + 1 end end
            end
            return count
        end
        winona.components.hunger:SetPercent(0.1)
        local axes = countaxes()
        winona.bufferedaction = BufferedAction(winona, nil, ACTIONS.BUILD, nil, winona:GetPosition(), "axe")
        winona.sg:GoToState(build(winona))
        local duration = GetModConfigData("Winona No Hungry Builder") and 0.5 or 2
        check(near(winona.sg.timeout, duration), "native crafting state honors local hunger option")
        winona.sg:UpdateState(duration + FRAMES)
        check(countaxes() == axes + 1, "native crafting timeout actually makes axe")
        winona.sg:GoToState("idle")
        winona.components.hunger:SetPercent(0.9)
        if active then for i = 1, 5 do
            winona:PushEvent("ms_becameghost")
            check(listeners(winona, "performaction", "winona_worker_drain") == 0, "ghost removes drain listener " .. i)
            check(near(work:GetMultiplier(ACTIONS.CHOP), 1) and near(uses:GetMultiplier(ACTIONS.CHOP), 1), "ghost clears only own modifiers " .. i)
            winona:PushEvent("ms_respawnedfromghost")
            check(listeners(winona, "performaction", "winona_worker_drain") == 1 and
                listeners(winona, "hungerdelta", "winona_worker_update") == 1, "revive restores exactly one callback " .. i)
            check(near(work:GetMultiplier(ACTIONS.CHOP), 1.5), "revive immediately restores work " .. i)
        end end
        local record = winona:GetSaveRecord()
        local restored = SpawnSaveRecord(record)
        check(restored and near(restored.components.workmultiplier:GetMultiplier(ACTIONS.CHOP), 1.5), "native player save reload restores worker")
        print("[ELECTRICAL] ALL_PASS", checks)
        c_shutdown(false)
    end)
end)
