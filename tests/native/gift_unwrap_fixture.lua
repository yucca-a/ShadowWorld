-- Test-only: real entities, native action, scheduler and gift_surprise scenario.
local active
for _, prefab in ipairs({"hound", "berries", "waxpaper"}) do
    AddPrefabPostInit(prefab, function(inst)
        if not TheWorld.ismastersim or not active then return end
        local case = active
        case.spawned[#case.spawned + 1] = inst
        if prefab == "hound" then
            case.hounds[#case.hounds + 1] = inst
            inst:ListenForEvent("newstate", function(_, data)
                if data and data.statename == "surprise_spawn" then case.surprise = case.surprise + 1 end
            end)
        elseif prefab == "berries" then
            inst:ListenForEvent("unwrappeditem", function(item)
                case.foodtime = item.components.perishable.perishremainingtime
                case.foodcount = case.foodcount + 1
                case.foodat = GetTime()
            end)
        else
            case.paper = case.paper + 1
        end
    end)
end
AddSimPostInit(function()
    if not TheWorld.ismastersim then return end
    assert(TheNet:GetServerName() == "ShadowWorld isolated gift unwrap test")
    TheWorld:PushEvent("ms_setautosaveenabled", false)
    TheWorld:DoStaticTaskInTime(1, function()
        local checks, failures, cases = 0, 0, 0
        local function check(ok, why) checks = checks + 1; assert(ok, why) end
        local definitions = {
            {name="ground_large_variation_1", surprise=true, variation=1},
            {name="ground_large_variation_2", surprise=true, variation=2},
            {name="inventory_drop_then_unwrap", surprise=true, held=true},
            {name="cursor_drop_then_unwrap", surprise=true, cursor=true},
            {name="saved_surprise_gift", surprise=true, reload=true},
            {name="save_while_jiggling_then_reload", surprise=true, pendingreload=true},
            {name="explicit_nodelay", surprise=true, nodelay=true},
            {name="invalid_doer_during_delay", surprise=true, removedoer=true},
            {name="ordinary_gift_food"},
            {name="bundle_keeps_food_fresh", bundle=true},
            {name="native_scenario_opens_nearby_gifts", scenario=true},
        }
        local function nextcase(index)
            local def = definitions[index]
            if not def then
                active = nil
                print("[GIFT_UNWRAP_TEST] RESULT", "cases="..cases, "checks="..checks, "failures="..failures)
                c_shutdown(false)
                return
            end
            cases = cases + 1
            local state = {spawned={}, hounds={}, surprise=0, foodcount=0, paper=0, unwrapped=0}
            active = state
            local function spawn(name)
                local inst = assert(SpawnPrefab(name), name)
                state.spawned[#state.spawned+1] = inst
                return inst
            end
            local function cleanup(ok, err)
                active = nil
                for i=#state.spawned,1,-1 do
                    local inst=state.spawned[i]
                    if inst:IsValid() then inst:Remove() end
                end
                if not ok then failures=failures+1 end
                print("[GIFT_UNWRAP_TEST]", ok and "PASS" or "FAIL", def.name, err or "")
                TheWorld:DoStaticTaskInTime(0, function() nextcase(index+1) end)
            end
            local ok, err = xpcall(function()
                local player = spawn("wilson")
                player.components.health:SetInvincible(true)
                player.Transform:SetPosition(0,0,0)
                player.sg:GoToState("idle")
                player.components.inventory:DropEverything()
                local function gift(surprise, bundle)
                    local g = spawn(bundle and "bundle" or "gift")
                    g.Transform:SetPosition(1,0,0)
                    g.variation = def.variation or 1
                    local contents = {}
                    if surprise then
                        contents[1] = spawn("giftsurprise"):SetCreatureSurprise("hound")
                        contents[2] = spawn("giftsurprise")
                        contents[3] = spawn("giftsurprise")
                    end
                    local food = spawn("berries")
                    food.components.perishable.perishremainingtime = 100
                    contents[#contents+1] = food
                    g.components.unwrappable:WrapItems(contents)
                    for _, item in ipairs(contents) do item:Remove() end
                    local u = g.components.unwrappable
                    if GIFT_TEST_CHEAP then
                        check(u.wrap_time ~= nil, "cheap wrap patch loaded")
                        u.wrap_time = u.wrap_time - 10
                    end
                    return g
                end
                local function watch(g)
                    g:ListenForEvent("unwrapped", function(_, data)
                        state.unwrapped = state.unwrapped+1
                        state.eventdoer = data and data.doer
                    end)
                end
                local function open(g)
                    check(BufferedAction(player,g,ACTIONS.UNWRAP):Do(), "native unwrap action accepted")
                end
                if def.scenario then
                    state.expectedhounds, state.expectedunwraps = 3, 4
                    state.gifts = {}
                    for i=1,3 do
                        local g=gift(true)
                        watch(g)
                        state.gifts[i]=g
                    end
                    local trigger=gift(false)
                    trigger:AddComponent("scenariorunner")
                    trigger.components.scenariorunner:SetScript("gift_surprise")
                    trigger.components.scenariorunner:Run()
                    watch(trigger)
                    state.started=GetTime()
                    open(trigger)
                else
                    local g=gift(def.surprise,def.bundle)
                    if def.held then player.components.inventory:GiveItem(g,7) end
                    if def.cursor then player.components.inventory:GiveActiveItem(g) end
                    if def.reload then
                        local record=g:GetSaveRecord()
                        g:Remove()
                        g=assert(SpawnSaveRecord(record))
                        state.spawned[#state.spawned+1]=g
                        check(g.jiggle, "surprise behavior survives native save/load")
                    end
                    state.started=GetTime()
                    if def.pendingreload then
                        open(g)
                        check(g.pendingunwrap and g:IsValid(), "gift waits for original delay")
                        local record=g:GetSaveRecord()
                        g:Remove()
                        g=assert(SpawnSaveRecord(record))
                        state.spawned[#state.spawned+1]=g
                        check(g.components.unwrappable.canbeunwrapped, "saved jiggling gift can be opened again")
                    end
                    watch(g)
                    state.gift, state.player = g, player
                    if def.nodelay then
                        g.components.unwrappable:Unwrap(player,true)
                        check(not g:IsValid(), "nodelay completes immediately")
                    else
                        open(g)
                        if def.surprise then
                            check(g:IsValid() and g.pendingunwrap, "surprise retains native jiggle delay")
                            check(not BufferedAction(player,g,ACTIONS.UNWRAP):Do(), "second action rejected while pending")
                        end
                    end
                    if def.removedoer then player:Remove() end
                    state.expectedhounds=def.surprise and 1 or 0
                    state.expectedunwraps=1
                end
            end,tostring)
            if not ok then cleanup(false,err);return end
            TheWorld:DoStaticTaskInTime(2, function()
                local good, why=xpcall(function()
                    check(state.unwrapped==state.expectedunwraps, "unwrap event fires exactly once per gift")
                    check(#state.hounds==state.expectedhounds, "correct number of hounds released")
                    check(state.surprise==state.expectedhounds, "native surprise_spawn state retained")
                    if state.gift then check(not state.gift:IsValid(), "opened package removed after delay") end
                    if state.gifts then
                        for _,g in ipairs(state.gifts) do check(not g:IsValid(), "nearby surprise gift opened") end
                    end
                    check(state.foodcount==state.expectedunwraps, "each food released once")
                    if not def.scenario then
                        local age=GIFT_TEST_CHEAP and not def.bundle and (10+state.foodat-state.started) or 0
                        check(math.abs(state.foodtime-(100-age))<0.15, "food age deducted once, including native delay")
                        check(state.paper==(def.bundle and 1 or 0), "native wrapping material loot preserved")
                        local expecteddoer = not def.removedoer and state.player or nil
                        check(state.eventdoer==expecteddoer, "native doer preserved or invalid doer removed")
                    end
                end,tostring)
                cleanup(good,why)
            end)
        end
        nextcase(1)
    end)
end)
