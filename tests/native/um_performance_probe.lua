local G=GLOBAL
G.setmetatable(env,{__index=function(_,key)return G.rawget(G,key)end})
local json=require("json")
local A={owned={},loaded={},cases={}}
G.VaultAudit=A
local function emit(row)print("[VAUDIT] "..json.encode(row))end
local function check(ok,name,detail)
    A.cases[#A.cases+1]={name=name,passed=not not ok,detail=detail}
    assert(ok,name..": "..tostring(detail))
end
local function spawn(name)
    local inst=assert(SpawnPrefab(name),name)
    A.owned[#A.owned+1]=inst
    return inst
end
local function pos()
    for _,inst in pairs(Ents)do if inst:HasTag("multiplayer_portal")then return inst:GetPosition()end end
    return Vector3(0,0,0)
end
local function marked(name)
    local result={}
    for _,inst in pairs(Ents)do if inst.prefab==name and inst.um_perf_fixture2hm then result[#result+1]=inst end end
    return result
end
for _,name in ipairs({"snowpile","hooded_fern","air_conditioner_smoke"})do
    AddPrefabPostInit(name,function(inst)
        if not TheWorld.ismastersim then return end
        local save,load=inst.OnSave,inst.OnLoad
        inst.OnSave=function(inst,data,...)
            if inst.um_perf_fixture2hm then data.um_perf_fixture2hm=true end
            if save then return save(inst,data,...)end
        end
        inst.OnLoad=function(inst,data,...)
            if data and data.um_perf_fixture2hm then inst.um_perf_fixture2hm=true;A.loaded[#A.loaded+1]=inst end
            if load then return load(inst,data,...)end
        end
    end)
end
AddSimPostInit(function()TheWorld:DoTaskInTime(1,function()emit({kind="ready"})end)end)
function A.status()
    emit({kind="performance_status",statuses=TUNING.UM_COMPAT_STATUS2HM or {}})
end
function A.run()
    A.cases={}
    local function finish(ok,err)
        emit({kind="performance_done",passed=ok,error=not ok and tostring(err):gsub("'", "")or nil,cases=A.cases,
            statuses=TUNING.UM_COMPAT_STATUS2HM or {}})
    end
    local function safe(fn)local ok,err=pcall(fn);if not ok then finish(false,err)end return ok end
    local function later(t,fn)TheWorld:DoTaskInTime(t,function()safe(fn)end)end
    safe(function()
        local p=pos();A.origin=p
        if PERF_COMBINED then
            local s=assert(TUNING.UM_COMPAT_STATUS2HM)
            for _,id in ipairs({"snowstorm_idle","weather_particles","tornado_weather_tasks"})do
                check(s[id]and s[id].applied,"native_guard_"..id)
            end
            if PERF_BETA then
                for _,id in ipairs({"fern_pathfinding","ocupus_eye_tasks","ocupus_day_tasks","ocupus_references","ocupus_location","snowpile_registry","snowpile_local_count"})do
                    check(s[id]and s[id].applied,"native_guard_"..id)
                end
            end
        end
        TheWorld:PushEvent("ms_setseason","winter")
        later(.3,function()
            local actor=spawn("wilson");actor.userid="KU_PERFORMANCE_FIXTURE"
            actor.Transform:SetPosition(p.x+2,0,p.z)
            actor.components.health:SetInvincible(true)
            actor.components.hunger:SetRate(0)
            A.actor=actor
            if PERF_COMBINED then
                -- Same native channelable path that previously crashed when a
                -- cloud sleeps during Transform:SetPosition and brain is nil.
                local device=spawn("air_conditioner")
                device.Transform:SetPosition(p:Get());device.entity:SetCanSleep(false)
                local food=spawn("blue_mushed_room")
                assert(device.components.container:GiveItem(food,1))
                device.components.channelable:StartChanneling(actor)
                A.device=device
            end
            for i=1,64 do
                local smoke=spawn("air_conditioner_smoke")
                smoke.um_perf_fixture2hm=true
                smoke.Transform:SetPosition(p.x+800+i,4,p.z+800)
            end
            for i=1,96 do
                local pile=spawn("snowpile")
                pile.um_perf_fixture2hm=true
                pile.Transform:SetPosition(p.x+30+(i%12)*5,0,p.z+30+math.floor(i/12)*5)
            end
            if PERF_BETA then
                for i=1,16 do
                    local fern=spawn("hooded_fern");fern.um_perf_fixture2hm=true
                    fern.Transform:SetPosition(p.x+120+(i%4)*8,0,p.z+120+math.floor(i/4)*8)
                end
            end
            later(3,function()
                local smoke=marked("air_conditioner_smoke")
                check(PERF_COMBINED and #smoke==0 or not PERF_COMBINED and #smoke==64,"dormant_smoke_lifecycle",#smoke)
                local piles=marked("snowpile")
                check(#piles>=80,"winter_resources_preserved",#piles)
                if PERF_COMBINED then
                    check(A.device:IsValid()and A.actor:IsValid(),"native_air_channel_survived")
                    local cloud_count,stopped=0,0
                    for _,e in pairs(Ents)do
                        if e.prefab=="air_conditioner_cloud"and e.host==actor then
                            cloud_count=cloud_count+1
                            if e._brainstopped and e._brainstopped.air_conditioner_host2hm then stopped=stopped+1 end
                        end
                    end
                    check(cloud_count>0 and stopped==cloud_count,"cloud_brain_stopped_through_wake",stopped)
                end
                if PERF_BETA then
                    local manager=TheWorld.components.um_snowstormmanager
                    local before=manager.snowpiles
                    local elapsed=os.clock()
                    for _,e in ipairs(piles)do e:Remove()end
                    elapsed=os.clock()-elapsed
                    check(PERF_COMBINED and before==manager.snowpiles or not PERF_COMBINED and before~=manager.snowpiles,
                        "registry_table_identity",elapsed)
                    emit({kind="performance_registry_benchmark",combined=PERF_COMBINED,count=#piles,seconds=elapsed})
                    for i=1,48 do
                        local pile=spawn("snowpile");pile.um_perf_fixture2hm=true
                        pile.Transform:SetPosition(p.x+30+(i%12)*5,0,p.z+30+math.floor(i/12)*5)
                    end
                end
                if A.device and A.device:IsValid()then A.device.components.channelable:StopChanneling()end
                for _,e in ipairs({A.actor,A.device})do if e and e:IsValid()then e:Remove()end end
                later(.5,function()finish(true)end)
            end)
        end)
    end)
end
function A.ecology()
    local Guard=require("umcompatguard2hm")
    local ok,err=pcall(function()
        local logger=assert(TheWorld.components.um_tilelogger)
        local previous=logger.Hazardous
        local host=CreateEntity();host.entity:AddTransform()
        A.owned[#A.owned+1]=host
        host:AddComponent("um_ocupusappearinator")
        local finder=host.components.um_ocupusappearinator
        local anchors,tiles={},{}
        for _,cx in ipairs({-260,260})do
            local anchor=CreateEntity();anchor.entity:AddTransform();anchor.Transform:SetPosition(cx,0,0)
            anchors[#anchors+1]=anchor;A.owned[#A.owned+1]=anchor;finder:RegisterOcupus(anchor)
            for dx=-248,248,4 do for dz=-248,248,4 do
                if dx*dx+dz*dz<62500 and #tiles<24000 then tiles[#tiles+1]={x=cx+dx,z=dz}end
            end end
        end
        logger.Hazardous=tiles
        local returned,failure=pcall(function()finder:SpawnOcupi()end)
        logger.Hazardous=previous
        for _,anchor in ipairs(anchors)do anchor:Remove()end
        host:Remove()
        check(returned,"native_24000_blocked_candidates",failure)
        local point
        for x=-512,512,16 do
            for z=-512,512,16 do
                local ocean=true
                for _,offset in ipairs({{0,0},{16,0},{-16,0},{0,16},{0,-16}})do
                    if not TheWorld.Map:IsOceanAtPoint(x+offset[1],0,z+offset[2])then ocean=false;break end
                end
                if ocean then point=Vector3(x,0,z);break end
            end
            if point then break end
        end
        assert(point,"controlled ocean point")
        local boat=spawn("boat");boat.Transform:SetPosition(point:Get())
        local eye=spawn("um_ocupus_eyetacle");eye.Transform:SetPosition(point.x+6,0,point.z)
        eye.boatvictim=boat
        local watch=assert(Guard.Find(G.Prefabs.um_ocupus_eyetacle.fn,"CheckForVictimsLong")).value
        for i=1,100 do watch(eye)end
        local watchers=0
        for task in pairs(eye.pendingtasks or {})do
            local info=debug.getinfo(task.fn,"S")
            if task.period==10 and info and info.source:find("um_ocupus_eyetacle.lua",1,true)then watchers=watchers+1 end
        end
        check(watchers==1,"native_single_eye_observer",watchers)
        local core=spawn("um_ocupus");core.Transform:SetPosition(point:Get())
        local born=assert(Guard.Find(G.Prefabs.um_ocupus.fn,"Born")).value
        for i=1,20 do
            for _,child in ipairs(core.undertents or {})do if child:IsValid()then child:Remove()end end
            born(core)
            check(#core.undertents>=6 and #core.undertents<=10,"native_live_eye_references_"..i,#core.undertents)
        end
        for _,child in ipairs(core.undertents or {})do if child:IsValid()then child:Remove()end end
        core:Remove();eye:Remove();boat:Remove()
    end)
    if not ok then emit({kind="performance_ecology",passed=false,error=tostring(err):gsub("'", "")});return end
    local fern=marked("hooded_fern")[1]
    local ok,err=pcall(function()
        assert(fern and fern._pfpos,"fern pathfinding registered before pick")
        fern.components.pickable:Pick(A.actor and A.actor:IsValid()and A.actor or nil)
    end)
    if not ok then emit({kind="performance_ecology",passed=false,error=tostring(err):gsub("'", "")});return end
    TheWorld:DoTaskInTime(.2,function()
        local ok,err=pcall(function()
            check(fern._pfpos==nil,"native_picked_fern_unregisters_once")
            fern.components.pickable:Regen()
        end)
        if not ok then emit({kind="performance_ecology",passed=false,error=tostring(err):gsub("'", "")});return end
        TheWorld:DoTaskInTime(.2,function()
            local ok,err=pcall(function()check(fern._pfpos~=nil and fern.components.pickable:CanBePicked(),"native_fern_regrows")end)
            emit({kind="performance_ecology",passed=ok,error=not ok and tostring(err):gsub("'", "")or nil,cases=A.cases})
        end)
    end)
end
function A.after_reload()
    local ok,err=pcall(function()
        check(TheWorld.state.iswinter,"saved_winter_restored")
        check(#marked("snowpile")>0,"snowpiles_survive_save_load",#marked("snowpile"))
        if PERF_COMBINED then check(#marked("air_conditioner_smoke")==0,"smoke_not_saved")end
        if PERF_BETA then check(#marked("hooded_fern")==16,"fern_density_survives_save_load",#marked("hooded_fern"))end
        TheWorld:PushEvent("ms_setseason","spring")
    end)
    if not ok then emit({kind="performance_reload",passed=false,error=tostring(err):gsub("'", "")});return end
    TheWorld:DoTaskInTime(2,function()
        local ok,err=pcall(function()
            check(TheWorld.state.season=="spring" and not TheWorld.state.iswinter,"native_spring_state_committed")
            local remaining=#marked("snowpile")
            check(PERF_COMBINED and remaining==0 or not PERF_COMBINED and remaining>0,
                PERF_COMBINED and "natural_spring_melt"or"original_season_state_order_misses_melt",remaining)
            if PERF_BETA then check(#marked("hooded_fern")==16,"spring_does_not_clean_ferns")end
        end)
        emit({kind="performance_reload",passed=ok,error=not ok and tostring(err):gsub("'", "")or nil,cases=A.cases,statuses=TUNING.UM_COMPAT_STATUS2HM or {}})
    end)
end
