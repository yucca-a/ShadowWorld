local G = GLOBAL
G.setmetatable(env, {__index = function(_, key) return G.rawget(G, key) end})
local cooking = require("cooking")
local function MarkPot(inst)
    if not TheWorld.ismastersim then return end
    local save, load = inst.OnSave, inst.OnLoad
    inst.OnSave = function(inst, data, ...)
        data.five_slot_test_marker = inst.five_slot_test_marker
        if save then return save(inst, data, ...) end
    end
    inst.OnLoad = function(inst, data, ...)
        inst.five_slot_test_marker = data and data.five_slot_test_marker
        if load then return load(inst, data, ...) end
    end
end
AddPrefabPostInit("cookpot", MarkPot)
AddPrefabPostInit("portablecookpot", MarkPot)
AddSimPostInit(function()
    if not TheWorld.ismastersim then return end
    assert(TheNet:GetServerName() == "ShadowWorld isolated five-slot cooking test")
    TheWorld:PushEvent("ms_setautosaveenabled", false)
    TheWorld:DoStaticTaskInTime(1, function()
        local checks, cases, failures = 0, 0, 0
        local function check(ok, why) checks = checks + 1; assert(ok, why) end
        local function same(a,b,why) check(type(a)=="number" and math.abs(a-b)<.0001, why.." "..tostring(a).." vs "..tostring(b)) end
        local player = assert(SpawnPrefab("warly"))
        player.components.health:SetInvincible(true)
        player.components.hunger:SetRate(0)
        local names = {"meat","berries","carrot","berries","meat"}
        local function spawn(name) return assert(SpawnPrefab(name),name) end
        local function fill(pot, list)
            local c = pot.components.container
            for i,name in ipairs(list) do check(c:GiveItem(spawn(name),i),"insert slot "..i) end
        end
        local function finish(s)
            if not s.done then
                local task = assert(s.task,"cooking task")
                local fn = task.fn;task:Cancel();fn(s.inst,s)
            end
            check(s.done,"finished")
        end
        local function harvest(s)
            local product = assert(s.product)
            player.components.inventory:DropEverything()
            check(s:Harvest(player),"harvest")
            local dish
            for _,item in pairs(player.components.inventory.itemslots) do if item.prefab==product then dish=item end end
            check(dish~=nil,"product delivered")
            check(not s:Harvest(player),"no duplicate harvest")
            return dish
        end
        local function stats(s, dish, slots)
            slots=slots or FIVE_TEST_SLOTS
            local ed = dish.components.edible
            if not FIVE_TEST_DYNAMIC then check(ed.cookstat_hunger==nil,"dynamic stats remain disabled");return end
            check(s.food_stats~=nil and #s.food_stats==slots,"all ingredient rows captured")
            check((s.food_stats[slots].hunger or 0)>0,"last ingredient contributes")
            local base=spawn(dish.prefab)
            for field,scale in pairs({hunger=200,health=80,sanity=33}) do
                local sum=0
                for _,row in ipairs(s.food_stats) do sum=sum+math.max(0,row[field] or 0) end
                same(ed[field.."value"],sum*(1+base.components.edible[field.."value"]/scale),"dynamic "..field)
            end
            base:Remove()
            local restored=assert(SpawnSaveRecord(dish:GetSaveRecord()))
            same(restored.components.edible.cookstat_hunger,ed.cookstat_hunger,"dish reload")
            restored:Remove()
        end
        local function run(name, fn)
            cases=cases+1
            local ok,err=pcall(fn)
            if not ok then failures=failures+1 end
            print("[FIVE_SLOT_TEST]",ok and "PASS" or "FAIL",name,err or "")
        end
        if FIVE_TEST_PHASE=="verify" then
            for _,pot in pairs(Ents) do
                if pot.five_slot_test_marker then
                    local marker=pot.five_slot_test_marker
                    run("cold_reload_"..marker,function()
                        check(pot.components.container:GetNumSlots()==5,"cold slots")
                        if marker=="ingredients" then
                            check(pot.components.container:GetItemInSlot(5).prefab==names[5],"fifth item survives cold load")
                            pot.components.fueled:SetPercent(1)
                            pot.components.stewer:StartCooking(player)
                        elseif marker=="cooking" then
                            check(pot.components.stewer:IsCooking(),"mid-cook resumes after cold load")
                        else check(pot.components.stewer.done,"completed meal survives cold load") end
                        local s=pot.components.stewer
                        local capture={food_stats=s.food_stats}
                        finish(s);local dish=harvest(s);stats(capture,dish)
                        pot:Remove()
                    end)
                end
            end
            check(cases==3,"all three cold saved pots recovered")
        else
            run("rules",function()
                local containers=require("containers")
                check(#containers.params.cookpot.widget.slotpos==FIVE_TEST_SLOTS,"cookpot layout")
                check(#containers.params.portablecookpot.widget.slotpos==FIVE_TEST_SLOTS,"portable layout")
                if FIVE_TEST_SLOTS==5 then
                    check(containers.params.cookpot~=containers.params.portablecookpot,"pot definitions are independent")
                    check(TUNING.PERISH_OLD2HM==.7,"old-food threshold installed")
                    local r=cooking.recipes.cookpot.beefalofeed
                    check(r.priority==11 and r.test("cookpot",{}, {inedible=3}),"filler limit installed")
                    check(not r.test("cookpot",{}, {inedible=2,frozen=1}),"filler boundary allowed")
                    check(cooking.recipes.portablecookpot.gazpacho.test("portablecookpot",{asparagus=2},{frozen=1.5}),"cold soup threshold")
                    same(cooking.ingredients.meat.tags.meat,.75,"ordinary pot reduced meat")
                    if cooking.WithCookerRules2hm then
                        cooking.WithCookerRules2hm("dragonflyfurnace",function()
                            same(cooking.ingredients.meat.tags.meat,1,"furnace original meat value")
                            check(cooking.recipes.cookpot.beefalofeed.priority~=11,"furnace exempt five-slot filler rule")
                        end)
                        same(cooking.ingredients.meat.tags.meat,.75,"normal rule restored after furnace")
                    end
                    local food=spawn("meat")
                    food.components.perishable:SetPercent(.6)
                    local base=food.components.edible.hungervalue
                    same(food.components.edible:GetHunger(player),base*.75,"70 percent hunger band")
                    food:Remove()
                end
            end)
            for _,prefab in ipairs({"cookpot","portablecookpot"}) do
                run(prefab,function()
                    local pot=spawn(prefab)
                    check(pot.components.container:GetNumSlots()==FIVE_TEST_SLOTS,"server slots")
                    check(pot.replica.container:GetNumSlots()==FIVE_TEST_SLOTS,"replica slots")
                    local ingredients={unpack(names,1,FIVE_TEST_SLOTS)}
                    for i=1,FIVE_TEST_SLOTS-1 do
                        check(pot.components.container:GiveItem(spawn(ingredients[i]),i),"initial ingredient")
                    end
                    check(not pot.components.stewer:CanCook(),"incomplete pot blocked")
                    check(pot.components.container:GiveItem(spawn(ingredients[FIVE_TEST_SLOTS]),FIVE_TEST_SLOTS),"final ingredient")
                    if FIVE_TEST_SLOTS==5 then
                        local legacy=pot:GetSaveRecord()
                        legacy.data.container.items[5]=nil
                        local oldpot=assert(SpawnSaveRecord(legacy))
                        for i=1,4 do check(oldpot.components.container:GetItemInSlot(i)~=nil,"old four-slot ingredients retained") end
                        check(oldpot.components.container:GetItemInSlot(5)==nil,"old fifth slot stays empty")
                        check(not oldpot.components.stewer:CanCook(),"old pot waits for fifth ingredient")
                        oldpot:Remove()
                    end
                    local raw=assert(SpawnSaveRecord(pot:GetSaveRecord()))
                    check(raw.components.container:GetItemInSlot(FIVE_TEST_SLOTS).prefab==ingredients[FIVE_TEST_SLOTS],"last raw slot restored")
                    pot:Remove();pot=raw
                    pot.components.fueled:SetPercent(1)
                    check(pot.components.stewer:CanCook(),"full fueled pot ready")
                    pot.components.stewer:StartCooking(player)
                    check(pot.components.stewer.product~=nil,"cook started")
                    check(#pot.components.stewer.ingredient_prefabs==FIVE_TEST_SLOTS,"recipe uses every ingredient")
                    if FIVE_TEST_DYNAMIC then check(#pot.components.stewer.food_stats==FIVE_TEST_SLOTS,"dynamic snapshot uses every ingredient") end
                    local record=pot:GetSaveRecord()
                    if FIVE_TEST_DYNAMIC then
                        local legacy=deepcopy(record)
                        legacy.data.stewer.food_stats[5]=nil
                        local oldpot=assert(SpawnSaveRecord(legacy))
                        finish(oldpot.components.stewer)
                        local olddish=harvest(oldpot.components.stewer)
                        check(olddish.components.edible.cookstat_hunger~=nil,"old four-row dynamic meal loads and harvests")
                        oldpot:Remove()
                    end
                    local copy=assert(SpawnSaveRecord(record));pot:Remove()
                    local s=copy.components.stewer
                    local capture={food_stats=s.food_stats}
                    finish(s)
                    local done=assert(SpawnSaveRecord(copy:GetSaveRecord()));copy:Remove()
                    local dish=harvest(done.components.stewer)
                    stats(capture,dish)
                    done:Remove()
                end)
            end
            run("dragonflyfurnace_remains_four_ingredients",function()
                local pot=spawn("dragonflyfurnace")
                local c=pot.components.container
                check(c:GetNumSlots()==5,"furnace keeps ruby plus four ingredients")
                check(c:GiveItem(spawn("redgem"),1),"ruby in dedicated slot")
                for i=1,4 do check(c:GiveItem(spawn(names[i]),i+1),"furnace ingredient") end
                pot.components.stewer:StartCooking(player)
                local s=pot.components.stewer
                check(#s.ingredient_prefabs==4,"ruby excluded from cooking ingredients")
                local capture={food_stats=s.food_stats}
                finish(s);local dish=harvest(s);stats(capture,dish,4)
                check(c:GetItemInSlot(1) and c:GetItemInSlot(1).prefab=="redgem","Warly does not consume ruby charge")
                pot:Remove()
            end)
            if FIVE_TEST_PHASE=="seed" and failures==0 then
                for _,marker in ipairs({"ingredients","cooking","finished"}) do
                    local pot=spawn(marker=="cooking" and "portablecookpot" or "cookpot")
                    pot.five_slot_test_marker=marker
                    fill(pot,names)
                    pot.components.fueled:SetPercent(1)
                    if marker~="ingredients" then
                        local s=pot.components.stewer;s:StartCooking(player)
                        if marker=="finished" then finish(s)
                        else
                            local fn=s.task.fn;s.task:Cancel();s.targettime=GetTime()+300
                            s.task=pot:DoTaskInTime(300,fn,s)
                        end
                    end
                end
                player:Remove()
                print("[FIVE_SLOT_TEST] SEED_SAVED")
                c_shutdown(true)
                return
            end
        end
        player:Remove()
        print("[FIVE_SLOT_TEST] RESULT","cases="..cases,"checks="..checks,"failures="..failures)
        c_shutdown(false)
    end)
end)
