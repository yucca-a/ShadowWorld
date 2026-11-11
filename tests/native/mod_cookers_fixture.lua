local G = GLOBAL
G.setmetatable(env, {__index=function(_,key)return G.rawget(G,key)end})
local created = {}
for _,name in ipairs({"simmeredmoonlight","simmeredmoonlight_pro","simmeredmoonlight_inf","simmeredmoonlight_pro_inf",
    "simmeredmoonlight_pro_item","simmeredmoonlight_pro_inf_item"}) do
    AddPrefabPostInit(name,function(inst) created[#created+1]=inst end)
end
AddSimPostInit(function()
    if not TheWorld.ismastersim then return end
    assert(TheNet:GetServerName()=="ShadowWorld isolated five-slot cooking test")
    TheWorld:PushEvent("ms_setautosaveenabled",false)
    TheWorld:DoTaskInTime(1,function()
        local checks,cases,failures=0,0,0
        local function check(value,message)checks=checks+1;assert(value,message)end
        local function spawn(name)return assert(SpawnPrefab(name),name)end
        local player=spawn("wilson")
        player.components.health:SetInvincible(true)
        local names={"meat","meat","meat","berries","carrot"}
        local cooking=require("cooking")
        local function fill(pot,row,count)
            row=row or 1;count=count or 5
            local rows=pot.fiveslotrows2hm
            for i=1,count do
                local slot=rows and (i==5 and rows*5+row or (row-1)*5+i) or i
                check(pot.components.container:GiveItem(spawn(names[i]),slot),"insert "..slot)
            end
        end
        local function finish(s)
            local task=assert(s.task);local fn=task.fn;task:Cancel();fn(s.inst,s)
            check(s.done,"native stewer finished")
        end
        local function run(name,fn)
            cases=cases+1
            local ok,err=pcall(fn);if not ok then failures=failures+1 end
            print("[FIVE_SLOT_TEST]",ok and "PASS" or "FAIL",name,err or "")
        end
        run("medal_cookpot",function()
            local pot=spawn("medal_cookpot");local c=pot.components.container;local s=pot.components.stewer
            check(c:GetNumSlots()==5,"medal slots")
            fill(pot,1,4);pot.components.fueled:SetPercent(1)
            check(not s:CanCook(),"medal waits for fifth")
            check(c:GiveItem(spawn(names[5]),5),"medal fifth")
            pot.components.fueled:SetPercent(0);check(not s:CanCook(),"medal requires fuel")
            pot.components.fueled:SetPercent(1);check(s:CanCook(),"medal ready")
            s:StartCooking(player)
            check(#s.ingredient_prefabs==5,"medal uses five ingredients")
            check(s.product==cooking.CalculateRecipe("medal_cookpot",names),"medal native recipe book")
            if FIVE_TEST_DYNAMIC then check(#s.food_stats==5,"medal five dynamic rows")end
            finish(s)
            local copy=assert(SpawnSaveRecord(pot:GetSaveRecord()));pot:Remove()
            check(copy.components.container:GetNumSlots()==5 and copy.components.stewer.done,"medal save/load")
            check(copy.components.stewer:Harvest(player),"medal native harvest")
            copy:Remove()
        end)
        for _,name in ipairs({"simmeredmoonlight","simmeredmoonlight_pro","simmeredmoonlight_inf","simmeredmoonlight_pro_inf"})do
            run(name,function()
                local pot=spawn(name);local c=pot.components.container;local m=pot.components.moonsimmered
                local rows=pot.fiveslotrows2hm
                check(rows~=nil and c:GetNumSlots()==rows*6,"moon input/output slots")
                pot.components.fueled:SetPercent(1)
                fill(pot,1,4);m:TryCooking(player)
                check(m.todos==nil,"moon four ingredients cannot cook")
                check(c:GiveItem(spawn(names[5]),rows*5+1),"moon fifth")
                m:OnBoxOpen(player)
                local task=assert(m.task_slotfix);local predict=task.fn;task:Cancel();predict(pot)
                check(m.show.name==cooking.CalculateRecipe("portablecookpot",names),"moon five-input preview")
                m:OnBoxClose()
                for row=2,rows do fill(pot,row)end
                m:TryCooking(player)
                check(c:GetNumSlots()==rows*6,"native grouping does not leak temporary slot count")
                for row=1,rows do check(m.todos[row] and #m.todos[row].items==5,"five ingredients in row "..row)end
                local record=pot:GetSaveRecord()
                check(record.data.container.items[rows*5+1]~=nil,"fifth ingredient saved")
                local copy=assert(SpawnSaveRecord(record));copy:Remove()
                m.time_pass=100000;m:DoCooking()
                for row=1,rows do
                    local food=c:GetItemInSlot(row*5)
                    check(food and food.prefab==cooking.CalculateRecipe("portablecookpot",names),"native output slot "..row)
                    check(not c:GetItemInSlot(rows*5+row),"fifth ingredient consumed once")
                    if FIVE_TEST_DYNAMIC then check(food.components.edible.cookstat_hunger~=nil,"moon dynamic meal")end
                end
                pot:Remove()
            end)
        end
        for _,phase in ipairs({"ingredients","cooking","finished"})do
            run("kit_upgrade_"..phase,function()
                local pot=spawn("cookpot");pot.components.fueled:SetPercent(.8);fill(pot)
                if phase~="ingredients"then
                    pot.components.fueled:SetPercent(1);pot.components.stewer:StartCooking(player)
                    if phase=="finished"then finish(pot.components.stewer)end
                end
                local fuel=pot.components.fueled:GetPercent()
                local kit=spawn("simmeredmoonlight_item")
                check(kit.components.upgradekit:Upgrade(player,pot),"native kit upgrade")
                local moon=created[#created];local c=moon.components.container
                check(moon.prefab=="simmeredmoonlight"and c:GetNumSlots()==6,"kit creates expanded moon cooker")
                check(math.abs(moon.components.fueled:GetPercent()-fuel)<.0001,"upgrade preserves fuel")
                if phase=="finished"then
                    check(c:GetItemInSlot(5)~=nil and c:GetItemInSlot(6)==nil,"finished dish stays in output")
                else
                    check(c:GetItemInSlot(6)and c:GetItemInSlot(6).prefab==names[5],"upgrade preserves fifth ingredient")
                    check(c:GetItemInSlot(5)==nil,"upgrade does not turn ingredient into output")
                    if phase=="cooking"then check(#moon.components.moonsimmered.todos[1].items==5,"cooking upgrade uses five")end
                end
                moon:Remove()
            end)
        end
        run("infinite_upgrade",function()
            local pot=spawn("simmeredmoonlight");pot.components.fueled:SetPercent(.75);fill(pot)
            local fifth=pot.components.container:GetItemInSlot(6)
            local dish=spawn("meatballs");pot.components.container:GiveItem(dish,5)
            pot.legionfn_chestupgrade(pot,spawn("chestupgrade_stacksize"),player)
            local result=created[#created];local c=result.components.container
            check(result.prefab=="simmeredmoonlight_inf"and c:GetNumSlots()==24,"native infinite upgrade")
            check(c:GetItemInSlot(21)==fifth and c:GetItemInSlot(5)==dish,"infinite upgrade preserves slot roles")
            check(math.abs(result.components.fueled:GetPercent()-.75)<.0001,"infinite upgrade fuel")
            result:Remove()
        end)
        for _,name in ipairs({"simmeredmoonlight_pro","simmeredmoonlight_pro_inf"})do
            run("pack_deploy_"..name,function()
                local pot=spawn(name);pot.components.fueled:SetPercent(.75);fill(pot)
                local rows=pot.fiveslotrows2hm
                pot.components.portablestructure:Dismantle(player)
                local item=created[#created]
                check(item.prefab==name.."_item","portable native item")
                local copy=assert(SpawnSaveRecord(item:GetSaveRecord()));item:Remove()
                check(copy.boxitems_l[rows*5+1]~=nil,"portable fifth saved")
                copy.components.deployable.ondeploy(copy,Vector3(2,0,2),player)
                local result=created[#created]
                check(result.prefab==name and result.components.container:GetNumSlots()==rows*6,"portable deploy slots")
                check(result.components.container:GetItemInSlot(rows*5+1).prefab==names[5],"portable fifth restored")
                check(math.abs(result.components.fueled:GetPercent()-.75)<.0001,"portable fuel restored")
                result:Remove()
            end)
        end
        run("packed_infinite_upgrade",function()
            local pot=spawn("simmeredmoonlight_pro");pot.components.fueled:SetPercent(.75);fill(pot)
            pot.components.container:GiveItem(spawn("meatballs"),5)
            pot.components.portablestructure:Dismantle(player)
            local item=created[#created]
            item.legionfn_chestupgrade(item,spawn("chestupgrade_stacksize"),player)
            item=created[#created]
            check(item.prefab=="simmeredmoonlight_pro_inf_item","packed infinite upgrade")
            check(item.boxitems_l[21]and not item.boxitems_l[6],"packed upgrade remaps fifth input")
            check(item.boxitems_l[5].saved.prefab=="meatballs","packed upgrade keeps output")
            local copy=assert(SpawnSaveRecord(item:GetSaveRecord()));item:Remove()
            copy.components.deployable.ondeploy(copy,Vector3(2,0,2),player)
            local result=created[#created]
            check(result.components.container:GetItemInSlot(21).prefab==names[5],"expanded packed fifth restored")
            check(result.components.container:GetItemInSlot(5).prefab=="meatballs","expanded packed output restored")
            check(math.abs(result.components.fueled:GetPercent()-.75)<.0001,"packed upgrade fuel restored")
            result:Remove()
        end)
        run("moon_spicing_fifth_slot",function()
            local pot=spawn("simmeredmoonlight");pot.components.fueled:SetPercent(1)
            pot.components.container:GiveItem(spawn("spice_salt"),1)
            pot.components.container:GiveItem(spawn("meatballs"),6)
            local m=pot.components.moonsimmered;m:TryCooking(player)
            check(m.todos[1].spice~=nil,"native spicing remains a two-item operation")
            local expected=cooking.CalculateRecipe("portablespicer",{"meatballs","spice_salt"})
            m.time_pass=10000;m:DoCooking()
            check(pot.components.container:GetItemInSlot(5).prefab==expected,"spiced output")
            pot:Remove()
        end)
        run("moon_fuel_pause_resume",function()
            local pot=spawn("simmeredmoonlight");fill(pot)
            local fuel,m=pot.components.fueled,pot.components.moonsimmered
            fuel:SetPercent(0);m:TryCooking(player)
            check(m.todos==nil,"empty fuel blocks initial cooking")
            fuel:SetPercent(1);m:TryCooking(player)
            fuel:SetPercent(0);m:DoCooking()
            check(m.todos~=nil and m.task_simmer==nil,"batch pauses without deleting ingredients")
            check(fuel:TakeFuelItem(spawn("log"),player),"native refuel action")
            check(m.task_simmer~=nil,"batch resumes after refuel")
            pot:Remove()
        end)
        local clearpot, clearbox
        run("prepare_moon_clear_row",function()
            local pot=spawn("simmeredmoonlight_inf");fill(pot,3)
            local box=spawn("icebox");box.Transform:SetPosition(pot.Transform:GetWorldPosition())
            local c=pot.components.container
            check(require("containers").params.simmeredmoonlight_inf.widget.btns_legion.clearrow3.validfn(pot),"row clear button")
            clearpot,clearbox=pot,box
        end)
        local restores={}
        run("prepare_moon_reload",function()
            local pot=spawn("simmeredmoonlight_inf");pot.components.fueled:SetPercent(1)
            fill(pot,1);fill(pot,4);pot.components.container:GiveItem(spawn("meatballs"),10)
            pot.components.moonsimmered:TryCooking(player)
            local record=pot:GetSaveRecord();pot:Remove()
            check(record.data.fueled.fuel>0,"full fuel saved explicitly")
            restores.full=assert(SpawnSaveRecord(record))
            local legacy=deepcopy(record);legacy.data.container.items[21]=nil;legacy.data.container.items[24]=nil
            restores.legacy=assert(SpawnSaveRecord(legacy))
        end)
        TheWorld:DoTaskInTime(.5,function()
            run("moon_clear_row",function()
                local pot=assert(clearpot)
                pot.legion_cleardd={idx1=11,idx2=15};pot.components.moonsimmered:BtnClear(player)
                check(pot.components.container:GetItemInSlot(23)==nil,"row clear includes fifth ingredient")
                check(pot.legion_cleardd.idx1==11,"clear action context restored")
                clearbox:Remove();pot:Remove()
            end)
            run("moon_deferred_reload",function()
                local pot=assert(restores.full);local m=pot.components.moonsimmered
                check(m.todos[1]and #m.todos[1].items==5 and m.todos[4]and #m.todos[4].items==5,"native delayed load restores both five-input rows")
                check(pot.components.container:GetItemInSlot(10).prefab=="meatballs","saved output keeps slot")
                pot:Remove()
                pot=assert(restores.legacy)
                check(not pot.components.moonsimmered.todos,"old four-input rows wait for fifth")
                check(pot.components.container:GetItemInSlot(1)and pot.components.container:GetItemInSlot(16),"old input rows retained")
                pot:Remove()
            end)
            player:Remove()
            print("[FIVE_SLOT_TEST] RESULT","cases="..cases,"checks="..checks,"failures="..failures)
            c_shutdown(false)
        end)
    end)
end)
