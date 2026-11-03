local checks, clock, guid, tasks, entities = 0, 0, 0, {}, {}
local function check(ok, why) checks = checks + 1; assert(ok, why) end
local function run(source, name) return assert(loadstring(source, name))() end
GLOBAL = _G
table.contains = function(t, x) for _, v in pairs(t) do if v == x then return true end end; return false end
local function entity(name, monster)
    guid = guid + 1
    local inst = {prefab=name, GUID=guid, components={}, entity={SetCanSleep=function()end}, watches={}, tags={player=true, monster=monster}, events={}, pendingtasks={}}
    entities[guid] = inst
    function inst:IsValid() return not self.removed end
    function inst:HasTag(t) return self.tags[t] == true end
    function inst:AddTag(t) self.tags[t] = true end
    function inst:RemoveTag(t) self.tags[t] = nil end
    function inst:IsInLight() return self.inlight or false end
    function inst:ListenForEvent(n, fn, source)
        source = source or self; source.events[n] = source.events[n] or {}
        table.insert(source.events[n], {owner=self, fn=fn})
    end
    function inst:WatchWorldState(n, fn) self.watches[n]=fn end
    function inst:PushEvent(n, data)
        if n == "nightvision" then self.vision_events = (self.vision_events or 0) + 1 end
        for _, cb in ipairs(self.events[n] or {}) do if cb.owner:IsValid() then cb.fn(cb.owner, data) end end
    end
    function inst:DoTaskInTime(delay, fn, ...)
        local task = {fn=fn, at=clock+delay, inst=self, args={...}}
        function task:Cancel() self.cancelled=true; self.inst.pendingtasks[self]=nil end
        self.pendingtasks[task]=true; table.insert(tasks, task); return task
    end
    function inst:DoPeriodicTask(period, fn, initialdelay, ...)
        local task=self:DoTaskInTime(initialdelay or period, fn, ...); task.period=period; return task
    end
    function inst:Remove() self:PushEvent("onremove"); self.removed=true; for t in pairs(self.pendingtasks) do t:Cancel() end end
    function inst:StartUpdatingComponent() self.updating=true end
    function inst:StopUpdatingComponent() self.updating=false end
    inst.Transform={GetWorldPosition=function() return 0,0,0 end}
    inst.replica={inventory={EquipHasTag=function(_, tag) return inst.equipment == tag end}}
    inst.components.health={IsDead=function() return inst.dead or false end, IsInvincible=function() return false end}
    return inst
end
local function tick(dt)
    local limit=clock+dt
    while true do
        local first
        for _, t in ipairs(tasks) do
            if not t.cancelled and t.inst:IsValid() and t.at<=limit and (not first or t.at<first.at) then first=t end
        end
        if not first then break end
        clock=first.at
        if not first.period then first.cancelled=true; first.inst.pendingtasks[first]=nil end
        first.fn(first.inst, unpack(first.args))
        if first.period and not first.cancelled then first.at=clock+first.period end
    end
    clock=limit
end
net_tinybyte=function(id, name, dirty)
    local value=0
    return {value=function()return value end,set=function(_,v)value=v end,
        deliver=function(_,v)value=v;entities[id]:PushEvent(dirty)end}
end
net_bool=function(id,name,dirty)
    local value=false
    return {value=function()return value end,set=function(_,v)value=v end,
        deliver=function(_,v)value=v;entities[id]:PushEvent(dirty)end}
end
local hooks, widgethooks, configs
local function setup(master, monster, wathom, dedicated, options)
    tasks, entities, clock = {}, {}, 0
    TheWorld={ismastersim=master,state={phase="night",isday=false,isdusk=false,isnight=true,isfullmoon=false},
        HasTag=function(_,tag)return tag=="cave" and TheWorld.cave or false end}
    TheNet={IsDedicated=function()return dedicated end,IsServerPaused=function()return false end}
    TheSim={GetLightAtPoint=function()return TheWorld.light or 0 end,GetAmbientColour=function()return 0,0,0 end}
    TUNING={DSTU={WATHOM_NIGHTVISON_CC="test"}}
    configs={["Monster Night Vision"]=monster,["wathom nightvision"]=wathom}
    for k,value in pairs(options or {})do configs[k]=value end
    TUNING.easymode2hm=configs["enable easy mode"]
    TUNING.hardmode2hm=configs["enable hard mode"]
    GetModConfigData=function(k)return configs[k]end
    hooks, widgethooks={},{}
    AddPlayerPostInit=function(fn)table.insert(hooks,fn)end
    AddClassPostConstruct=function(n,fn)widgethooks[n]=fn end
    run(patch_source, "@content/common/monster_nightvision.lua")
    run(role_source, "@content/common/role_nightvision.lua")
end
local Vision=run(vision_source,"@scripts/components/playervision.lua")
local Grue=run(grue_source,"@scripts/components/grue.lua")
run(see_source,"@scripts/simutil.lua")
local function make(name, monster, before)
    local inst=entity(name,monster);inst.components.playervision=Vision(inst)
    if before then before(inst) end
    for _,fn in ipairs(hooks)do fn(inst)end
    tick(0)
    return inst,inst.components.playervision
end
local function sourcecount(v)
    local n=0;for _,x in ipairs(v.forcednightvisionstack)do if x.source=="monster_nightvision2hm"then n=n+1 end end;return n
end

setup(true,true,true,true)
check(next(widgethooks)==nil,"dedicated server never requires UI")
for _,name in ipairs({"webber","wathom","modded_monster"})do
    local p,v=make(name,true)
    check(v:HasNightVision(),name.." receives night vision")
    check(sourcecount(v)==1 and v.nonightvisioncc,"plain stable native source")
    local before=p.vision_events;tick(5)
    check(sourcecount(v)==1 and before==p.vision_events,"refresh never toggles/duplicates source")
end
for _,monster in ipairs({true,false})do
    local p,v=make("wortox",monster)
    check(not v:HasNightVision() and sourcecount(v)==0,"Wortox always blacklisted")
    p:AddTag("monster");tick(1)
    check(not v:HasNightVision(),"Wortox remains excluded after inclination changes")
    v:PushForcedNightVision("food",0)
    check(v:HasNightVision(),"blacklist does not strip Wortox food/equipment")
end
local p,v=make("wilson",false)
check(not v:HasNightVision(),"non-monster unchanged")
p:AddTag("monster");tick(1)
check(v:HasNightVision(),"dynamic monster tag grants vision")
v:ForceNightVision(false)
check(v:HasNightVision(),"legacy disable does not erase active source")
local custom={night="skill"}
v:PushForcedNightVision("skill",1,custom)
check(v:GetCCTable()==custom and not v.nonightvisioncc,"higher priority visual retained")
v:PopForcedNightVision("skill")
check(v:HasNightVision() and v.nonightvisioncc and v:GetCCTable()==nil,"plain vision restored after skill expires")
p.equipment="nightvision";p:PushEvent("equip")
p:RemoveTag("monster");tick(1)
check(sourcecount(v)==0 and v:HasNightVision(),"tag removal preserves equipment night vision")
p.equipment=nil;p:PushEvent("unequip")
check(not v:HasNightVision(),"no permanent leftover vision")
p:AddTag("monster");tick(1)
v:ForceNightVision(true);p:RemoveTag("monster");tick(1)
check(v:HasNightVision(),"legacy external source restored on removal")
v:ForceNightVision(false);check(not v:HasNightVision(),"external source may subsequently turn off")
p:AddTag("monster");tick(1)
v:PushForcedNightVision("fruit",0)
p:RemoveTag("monster");tick(1)
check(v:HasNightVision() and sourcecount(v)==0,"tag removal preserves native fruit")
v:PopForcedNightVision("fruit");check(not v:HasNightVision(),"fruit expiry clean")

p,v=make("webber",true)
p:AddTag("playerghost");v:SetGhostVision(true)
check(sourcecount(v)==0 and v:HasGhostVision(),"death releases only our source and keeps ghost CC")
p:RemoveTag("playerghost");v:SetGhostVision(false);p:PushEvent("ms_respawnedfromghost")
check(sourcecount(v)==1 and v:HasNightVision(),"respawn restores source")
for _,phase in ipairs({"day","dusk","night"})do
    TheWorld.state.isday=phase=="day";TheWorld.state.isdusk=phase=="dusk";TheWorld.state.isnight=phase=="night"
    tick(1);check(v:HasNightVision() and sourcecount(v)==1,"stable across "..phase)
end
TheWorld.cave=true;tick(1);check(v:HasNightVision(),"cave vision")
local savedprefab=p.prefab;p:Remove();local q,qv=make(savedprefab,true)
check(qv:HasNightVision() and sourcecount(qv)==1,"fresh entity after reload/migration initializes")

setup(false,false,false,false)
p,v=make("webber",true)
tick(25);check(not v:HasNightVision(),"client waits for authoritative setting")
p._monsternightvision2hm:deliver(1)
check(v:HasNightVision(),"late setting beyond old 20s cutoff works")
p._monsternightvision2hm:deliver(0)
check(not v:HasNightVision(),"server revoke reaches client")
for _,pair in ipairs({{false,false},{false,true},{true,false},{true,true}})do
    setup(true,pair[1],pair[2],false)
    p,v=make("wathom",true)
    check(v:HasNightVision()==(pair[1] or pair[2]),"Wathom OR combination")
    local other,ov=make("modded_monster",true)
    check(ov:HasNightVision()==pair[1],"independent general switch")
end

-- Run actual UM functions and whole widgets, including queued resets and both
-- periodic tasks in the stable prefab. Preserve unrelated tasks and CC calls.
local Widget=Class(function(self)self.inst=entity("widget",false);self.visible=true end)
function Widget:SetClickable()end
function Widget:AddChild(c)return c end
function Widget:Hide()self.visible=false end
function Widget:Show()self.visible=true end
function Widget:StartUpdating()self.updating=true end
function Widget:StopUpdating()self.updating=false end
package.preload["widgets/widget"]=function()return Widget end
package.preload["widgets/uianim"]=function()return {}end
Image=function()return setmetatable({SetTint=function(self,r,g,b,a)self.alpha=a end},{__index=function()return function()end end})end
Remap=function(v,a,b,c,d)return c+(v-a)/(b-a)*(d-c)end
local sounds,rings=0,0
TheFocalPoint={SoundEmitter={PlaySound=function()sounds=sounds+1 end}}
SpawnPrefab=function()rings=rings+1;return {Transform={SetScale=function()end,SetPosition=function()end}}end
for _,version in ipairs({"stable","beta"})do
    for _,master in ipairs({true,false})do
        setup(master,true,true,false)
        local lightcheck=run(_G[version.."_check"],_G[version.."_path"])
        local reset,unrelated=0,0
        p,v=make("wathom",true,function(i)
            i:AddTag("wathom")
            i:DoPeriodicTask(.3,lightcheck)
            if version=="stable" and master then i:DoPeriodicTask(.3,lightcheck)end
            i:DoPeriodicTask(.3,function()unrelated=unrelated+1 end)
            i.updatewathomvisiontask=i:DoTaskInTime(2,function()reset=reset+1;i.components.playervision:ForceNightVision(false)end)
        end)
        local Sonar=run(_G[version.."_widget"],"@widgets/wathom_sonar.lua")
        local sonar=Sonar(p)
        widgethooks["widgets/wathom_sonar"](sonar,p)
        if not master then p._monsternightvision2hm:deliver(2) end
        check(not sonar.active and not sonar.visible and sonar.bg2.alpha==0,version.." sonar hidden")
        local events=p.vision_events
        for _,light in ipairs({0,1,0,1})do
            p.inlight=light==1;TheWorld.light=light;tick(3)
            sonar:StartSonar();sonar:SetSonar(false);sonar:OnUpdate(.3)
            check(v:HasNightVision() and v:GetCCTable()==nil,version.." stable light/dark transitions")
            check(not p:HasTag("WathomInDark") and not sonar.active,version.." no echo mode")
        end
        check(reset==0 and unrelated>0,version.." only native vision tasks suppressed")
        check(events==p.vision_events,version.." no nightvision flicker events")
        check(sounds==0 and rings==0,version.." no heartbeat/ring generation")
        local effect={night="unrelated_filter"};v:SetCustomCCTable(effect)
        check(v:GetCCTable()==effect,version.." custom filters remain usable")
        v:SetCustomCCTable(nil)
        -- A late registered original CheckLight is guarded as well.
        p:DoPeriodicTask(.3,lightcheck);tick(1)
        check(v:GetCCTable()==nil,version.." late periodic init guarded")
        if not master then
            p._monsternightvision2hm:deliver(0)
            check(sonar.active and sonar.visible,version.." disabled optimization restores sonar")
            p.inlight=false;TheWorld.light=0;tick(.5)
            check(v:HasNightVision() and v:GetCCTable().night=="um_sonar",version.." original CheckLight resumes")
        end
    end
end

-- Actual Fenghua smart-night-vision UI and dawn callbacks, not a reimplementation.
local function load_fenghua(player)
    ThePlayer=player
    local settings={state=true,ori=true,say=false}
    local screen, toggle
    s_mana={GetSettingLine=function()return settings end,
        SaveSettingLine=function(_,_,data,changes)for k,value in pairs(changes)do data[k]=value end end,
        LoadDefaults=function(_,data,defaults)for k,value in pairs(defaults)do if data[k]==nil then data[k]=value end end end}
    m_util={IsServer=function()return false end,IsLava=function()return false end,IsHuxi=function()return false end,
        AddBindShowScreen=function(_,data)screen=data;return function()end end,
        AddBindConf=function(_,id,left)toggle=left end}
    t_util={GetRecur=function(_,obj,path)
        for key in path:gmatch("[^.]+")do obj=obj and obj[key]end;return obj
    end,GetMetaIndex=function(_,obj)return obj end,BuildNumInsert=function()return {}end}
    local activated
    i_util={AddWorldActivatedFunc=function(_,fn)activated=fn end,
        DoTaskInTime=function(_,delay,fn)return player:DoTaskInTime(delay,fn)end}
    u_util={Say=function()end};STRINGS={LMB="LMB",RMB="RMB"}
    package.preload["data/valuetable"]=function()return {RGB_datatable={}}end
    TheWorld.watches={}
    TheWorld.WatchWorldState=function(self,key,fn)self.watches[key]=fn end
    TheSim.SetVisualAmbientColour=function(self,r,g,b)self.visual={r,g,b}end
    run(fenghua_source,"@workshop-3413376081/modtable/13.lua")
    activated(TheWorld)
    local controls={};for _,data in ipairs(screen.data)do controls[data.id]=data.fn end
    return settings,controls,toggle
end
local SetWereVision=run(were_vision_source,"@scripts/prefabs/woodie.lua")
for _,master in ipairs({true,false})do
    for mode=1,3 do
        -- Native transformations must work even with both new bonuses disabled.
        setup(master,false,false,master)
        p,v=make("woodie",false)
        SetWereVision(p,mode)
        local werecc=v:GetCCTable()
        check(werecc.night=="images/colour_cubes/beaver_vision_cc.tex","actual native were filter")
        local g
        if master then g=Grue(p);p.components.grue=g;tick(0)end
        local settings,controls,toggle=load_fenghua(p)
        controls.state(false)
        check(v:HasNightVision(),"Fenghua disable keeps native were vision "..mode)
        check(v:GetCCTable()==werecc,"Fenghua disable keeps were filter")
        settings.state=true;toggle()
        check(v:HasNightVision(),"Fenghua hotkey keeps native were vision")
        settings.ori=true;controls.ori(false)
        check(v:HasNightVision(),"Fenghua old/new switch keeps native were vision")
        settings.ori=true;TheWorld.watches.startday();tick(5)
        check(v:HasNightVision(),"Fenghua five-second dawn reset keeps native were vision")
        if g then check(g.immunity.nightvision and not g:CheckForStart(),"server Charlie immunity retains native source")end
        -- New smart mode changes only screen light; it is not a server grant.
        settings.ori=false;settings.state=true
        TheSim:SetVisualAmbientColour(0,0,0);TheSim:SetVisualAmbientColour(0,0,0)
        check(TheSim.visual[1]>0 and v:HasNightVision(),"new smart mode and native ability coexist")
        SetWereVision(p,0)
        check(not v:HasNightVision() and v:GetCCTable()==nil,"human form loses transformation vision normally")
        check(sourcecount(v)==0,"no monster bonus was given to Woodie")
        if g then check(not g.immunity.nightvision and g:CheckForStart(),"human form has no residual Charlie immunity")end
    end
end
-- Distinguish actual server authority from a client-only brightness cheat.
setup(true,false,false,true)
local serverwoodie,servervision=make("woodie",false)
SetWereVision(serverwoodie,1)
local servergrue=Grue(serverwoodie);serverwoodie.components.grue=servergrue;tick(0)
setup(false,false,false,false)
local clientwoodie,clientvision=make("woodie",false)
SetWereVision(clientwoodie,1)
local settings,controls=load_fenghua(clientwoodie)
controls.state(false)
check(clientvision:HasNightVision() and servervision:HasNightVision(),"client toggle preserves both sides' independent ability")
check(not servergrue:CheckForStart(),"local toggle does not revoke server immunity")
SetWereVision(serverwoodie,0)
check(servergrue:CheckForStart(),"local renderer cannot grant server immunity")
setup(false,true,true,false)
p,v=make("wathom",true);p._monsternightvision2hm:deliver(2)
local fenghua_settings,fenghua_controls,fenghua_toggle=load_fenghua(p)
fenghua_controls.state(false)
check(v:HasNightVision() and v.nonightvisioncc,"Wathom plain vision survives Fenghua disable")
fenghua_settings.ori=true;TheWorld.watches.startday();tick(5)
check(v:HasNightVision() and sourcecount(v)==1,"Wathom source survives Fenghua dawn reset")
setup(true,false,false,true)
p,v=make("wortox",true)
v:PushForcedNightVision("existing_skill",2,{night="skill"})
v:ForceNightVision(false)
check(v:HasNightVision() and sourcecount(v)==0,"Wortox exclusion does not break existing legitimate skills")
v:PopForcedNightVision("existing_skill")
check(not v:HasNightVision(),"Wortox gains no permanent vision from compatibility")

-- The change grants ordinary night vision, not an unrelated light/Charlie
-- immunity bypass: execute native grue + the existing dangerous dusk hooks.
setup(true,true,true,true)
p,v=make("webber",true)
local grue=Grue(p);p.components.grue=grue;tick(0)
check(grue.immunity.nightvision and not grue:CheckForStart(),"native nightvision protection works")
local components={}
AddComponentPostInit=function(n,fn)components[n]=fn end
AddPrefabPostInit=function()end;AddRecipePostInit=function()end
ModManager={mods={}};KnownModIndex={}
GetModConfigData=function(k)return k=="dusk_change" and -1 or configs[k]end
run(dusk_source,"@content/weather/dusk.lua")
p,v=make("webber",true);components.playervision(v)
grue=Grue(p);p.components.grue=grue;components.grue(grue);tick(0)
check(v:HasNightVision(),"dangerous dusk does not remove visible nightvision")
check(not grue.immunity.nightvision and grue:CheckForStart(),"existing dangerous dusk rule remains authoritative")

-- The old dangerous-mode Woodie compensation must only own its light, never
-- clear the native transformation's palette or turn off its vision in daytime.
setup(true,false,false,true)
local prefabhooks={}
AddComponentPostInit=function()end
AddPrefabPostInit=function(name,fn)prefabhooks[name]=fn end
GetModConfigData=function(k)return k=="dusk_change" and -1 or configs[k]end
run(dusk_source,"@content/weather/dusk.lua")
p,v=make("woodie",false)
local weremode=1
p.weremode={value=function()return weremode end};p.entity={}
p.WatchWorldState=function(self,key,fn)self.phase_callback=fn end
SpawnPrefab=function(name)
    check(name=="deathcurselight2hm","only the existing dangerous-mode light is created")
    local light={entity={SetParent=function()end},Light=setmetatable({},{__index=function()return function()end end})}
    function light:IsValid()return not self.removed end
    function light:Remove()self.removed=true end
    return light
end
SetWereVision(p,1);local woodiecc=v:GetCCTable()
prefabhooks.woodie(p);tick(.3)
check(p._weremodelight2hm and v:HasNightVision() and v:GetCCTable()==woodiecc,"night compensation preserves native vision and palette")
TheWorld.state.isnight=false;TheWorld.state.isday=true
p.phase_callback(p,"day");tick(.3)
check(p._weremodelight2hm==nil and v:HasNightVision() and v:GetCCTable()==woodiecc,"day removes light but preserves transformation vision")
weremode=0;SetWereVision(p,0);p:PushEvent("transform_person");tick(.3)
check(not v:HasNightVision() and v:GetCCTable()==nil,"returning human cleanly releases native vision")

-- Migrate the three legacy role abilities without relying on monster tags.
local function role_options(overrides)
    local opts={["enable easy mode"]=true,role_easy=true,webber_easy=true,wurt_easy=true,wonkey_easy=true,
        ["Webber Night Version"]=true,["Wurt Night Version"]=true,["Wonkey Night Version"]=true,
        ["enable hard mode"]=true,weather_change=true,dusk_change=true}
    for key,value in pairs(overrides or {})do opts[key]=value end
    return opts
end
local function phase(value)
    TheWorld.state.phase=value -- Native OnPhaseChanged dispatches this first.
    for _,inst in pairs(entities)do
        if inst:IsValid() and inst.watches.phase then inst.watches.phase(inst,value)end
    end
    TheWorld.state.isday=value=="day";TheWorld.state.isdusk=value=="dusk";TheWorld.state.isnight=value=="night"
    tick(0)
end
local function rolecount(vision)
    local n=0
    for _,entry in ipairs(vision.forcednightvisionstack)do if entry.source=="role_nightvision2hm"then n=n+1 end end
    return n
end
local lights
local function install_dusk()
    local componenthooks={}
    AddComponentPostInit=function(name,fn)componenthooks[name]=fn end
    AddPrefabPostInit=function()end;AddRecipePostInit=function()end
    lights={}
    SpawnPrefab=function(name)
        assert(name=="deathcurselight2hm")
        local light=entity(name,false)
        light.entity.SetParent=function(_,parent)light.parent=parent end
        light.Light={SetFalloff=function()end,SetIntensity=function()end,SetColour=function()end,
            SetRadius=function(_,r)light.radius=r end,Enable=function(_,v)light.enabled=v end}
        table.insert(lights,light)
        return light
    end
    if TUNING.hardmode2hm and configs.weather_change and configs.dusk_change then
        run(dusk_source,"@content/weather/dusk.lua")
    end
    return componenthooks
end
for _,name in ipairs({"webber","wurt","wonkey"})do
    for _,mode in ipairs({false,true,-2,-1})do
        setup(true,false,false,true,role_options({dusk_change=mode}))
        local ch=install_dusk()
        p,v=make(name,false,function(i)if ch.playervision then ch.playervision(i.components.playervision)end end)
        grue=Grue(p);p.components.grue=grue;if ch.grue then ch.grue(grue)end;tick(0)
        check(v:HasNightVision() and rolecount(v)==1,name.." role option works without monster bonus")
        check(v.nonightvisioncc and v:GetCCTable()==nil,"role keeps normal palette")
        local light=p._rolevisionlight2hm
        check((light~=nil)==(mode==-1),"physical role light only in dangerous classic")
        if mode==-1 then
            check(light.radius==.5 and light.parent==p.entity and light.enabled,"original tiny light parameters and parent")
            check(not grue.immunity.nightvision,"danger rule still strips native NV immunity")
        else
            check(#lights==0 and grue.immunity.nightvision and not grue:CheckForStart(),"ordinary role NV is safe without any artificial light")
        end
        local settings,controls,toggle=load_fenghua(p)
        controls.state(false);settings.state=true;toggle();settings.ori=true;controls.ori(false)
        check(v:HasNightVision() and rolecount(v)==1,"Fenghua toggles cannot erase role source")
        local eventcount=p.vision_events
        phase("night");tick(2)
        check(eventcount==p.vision_events and p._rolevisionlight2hm==light,"repeat refresh never flickers or duplicates light")
        local cc={night="temporary_skill"}
        v:PushForcedNightVision("temporary_skill",2,cc)
        phase("day")
        check(rolecount(v)==0 and v:HasNightVision() and v:GetCCTable()==cc,"dawn releases only the role ability")
        check(p._rolevisionlight2hm==nil and (not light or not light:IsValid()),"dawn removes physical compensation")
        v:PopForcedNightVision("temporary_skill")
        check(not v:HasNightVision(),"day has no leftover legacy forced vision")
        phase("dusk")
        check(v:HasNightVision() and rolecount(v)==1,"dusk restores role source")
        p.dead=true;p:PushEvent("death")
        check(rolecount(v)==0 and p._rolevisionlight2hm==nil,"death immediately clears role and light")
        p:AddTag("playerghost");v:SetGhostVision(true);p.dead=false
        check(v:HasGhostVision() and not v:HasNightVision(),"ghost visuals remain authoritative")
        p:RemoveTag("playerghost");v:SetGhostVision(false);p:PushEvent("ms_respawnedfromghost");tick(0)
        check(rolecount(v)==1 and v:HasNightVision(),"respawn restores role vision")
        local oldlight=p._rolevisionlight2hm
        p:Remove()
        check(not oldlight or not oldlight:IsValid(),"entity removal releases child light")
        p,v=make(name,false);check(rolecount(v)==1,"new entity after reconnect/character change initializes")
        phase("day");TheWorld.cave=true;phase("day")
        check(rolecount(v)==1 and v:HasNightVision(),"cave daytime keeps role ability")
        check((p._rolevisionlight2hm~=nil)==(mode==-1),"cave light obeys dangerous mode")
    end
    for _,gate in ipairs({"enable easy mode","role_easy",name.."_easy",name:sub(1,1):upper()..name:sub(2).." Night Version"})do
        setup(true,false,false,true,role_options({[gate]=false,dusk_change=-1}))
        install_dusk();p,v=make(name,false)
        check(not v:HasNightVision() and p._rolevisionlight2hm==nil,"disabled parent/role option grants neither vision nor light: "..gate)
    end
    for _,gate in ipairs({"enable hard mode","weather_change"})do
        setup(true,false,false,true,role_options({[gate]=false,dusk_change=-1}))
        install_dusk();p,v=make(name,false)
        check(v:HasNightVision() and p._rolevisionlight2hm==nil,"inactive dangerous parent leaves pure NV: "..gate)
    end
    setup(false,false,false,false,role_options({dusk_change=-1}))
    install_dusk();p,v=make(name,false);tick(25)
    check(not v:HasNightVision(),"client does not grant ability from local settings")
    p._rolenightvision2hm:deliver(true)
    local settings,controls=load_fenghua(p);controls.state(false)
    check(v:HasNightVision() and v.nonightvisioncc and #lights==0,"late server role grant survives actual Fenghua client callback; client spawns no light")
    p._rolenightvision2hm:deliver(false)
    check(not v:HasNightVision() and rolecount(v)==0,"server revoke removes client role source")
end
setup(true,true,true,true,role_options({dusk_change=-1}))
install_dusk();p,v=make("webber",true)
check(rolecount(v)==1 and sourcecount(v)==1,"Webber has two independent sources")
phase("day")
check(rolecount(v)==0 and sourcecount(v)==1 and v:HasNightVision() and not p._rolevisionlight2hm,"role dawn cannot erase generic monster vision or leave its light")
phase("night");p:RemoveTag("monster");tick(1)
check(sourcecount(v)==0 and rolecount(v)==1 and v:HasNightVision(),"loss of monster tag cannot erase role vision")
for _,name in ipairs({"wortox","wathom","modded_monster"})do
    local other,ov=make(name,true)
    check(other._rolevisionlight2hm==nil and rolecount(ov)==0,"tiny light whitelist excludes "..name)
end
setup(true,true,true,true,role_options({["Webber Night Version"]=false,dusk_change=-1}))
install_dusk();p,v=make("webber",true)
check(v:HasNightVision() and rolecount(v)==0 and not p._rolevisionlight2hm,"generic bonus alone never grants compensating light")

-- Load the real modinfo rather than mirroring defaults in the test.
locale="zh";folder_name="ShadowWorld";ChooseTranslationTable=function(t)return t[1]end
run(config_source,"@content/modinfo.lua")
local defaults={};for _,c in ipairs(configuration_options)do defaults[c.name]=c.default end
check(defaults["Monster Night Vision"]==true and defaults["wathom nightvision"]==true,"both options default on")
print("Monster nightvision: "..checks.." checks passed (native vision/grue, stable/Beta UM, client/server).")
