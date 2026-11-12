local checks=0
local function check(ok,why)checks=checks+1;assert(ok,why)end
local function near(a,b,why)check(math.abs(a-b)<.000001,why)end
local function env()return setmetatable({},{__index=_G})end
local clock,tasks=0,{}
local function tick(dt)
    local finish=clock+dt
    while true do
        local first
        for _,t in ipairs(tasks)do if not t.cancelled and t.time<=finish and (not first or t.time<first.time)then first=t end end
        if not first then break end
        clock=first.time;first.fn(first.inst)
        if not first.period then first.cancelled=true else first.time=clock+first.period end
    end
    clock=finish
end
local function actor(name)
    local i={prefab=name or 'wixie',components={},replica={},event_listeners={},tags={},sg={statemem={}}}
    function i:IsValid()return true end
    function i:HasTag(t)return self.tags[t]or false end
    function i:AddTag(t)self.tags[t]=true end
    function i:RemoveTag(t)self.tags[t]=nil end
    function i:HasAnyTag(...)for _,t in ipairs({...})do if self:HasTag(t)then return true end end;return false end
    function i:ListenForEvent(e,f)self.event_listeners[e]=self.event_listeners[e]or{};self.event_listeners[e][self]=self.event_listeners[e][self]or{};table.insert(self.event_listeners[e][self],f)end
    function i:RemoveEventCallback(e,f)local a=self.event_listeners[e]and self.event_listeners[e][self]or{};for n=#a,1,-1 do if a[n]==f then table.remove(a,n)end end end
    function i:PushEvent(e,d)local a=self.event_listeners[e]and self.event_listeners[e][self]or{};for _,f in ipairs(a)do f(self,d)end end
    function i:DoTaskInTime(dt,f)local t={inst=self,time=clock+dt,fn=f,Cancel=function(t)t.cancelled=true end};tasks[#tasks+1]=t;return t end
    function i:DoPeriodicTask(dt,f)local t=self:DoTaskInTime(dt,f);t.period=dt;return t end
    function i:GetDistanceSqToInst()return 1 end
    i.Transform={GetWorldPosition=function()return 0,0,0 end}
    i.AnimState={SetDeltaTimeMultiplier=function(_,v)i.animspeed=v end}
    i.components.health={IsDead=function()return false end,IsInvincible=function()return false end}
    i.components.hunger={GetPercent=function()return .5 end}
    i.components.inventory={GetEquippedItem=function()return nil end}
    i.sg.HasStateTag=function()return false end
    i.sg.GoToState=function(s,name)s.laststate=name end
    return i
end
FRAMES=1/30;EQUIPSLOTS={HEAD='head',BODY='body',HANDS='hands'}
math.clamp=function(v,a,b)return math.max(a,math.min(b,v))end
IsTableEmpty=function(t)return next(t)==nil end
JoinArrays=function(a,b)local r={};for _,v in ipairs(a)do r[#r+1]=v end;for _,v in ipairs(b)do r[#r+1]=v end;return r end
UMCommonFns={GHOSTLIKE_TAGS={}}
TheSim={FindEntities=function()return{{IsValid=function()return true end,HasTag=function()return false end,HasAnyTag=function()return false end}}end}

for _,version in ipairs({'stable','beta'})do
    for _,master in ipairs({false,true})do
        clock=0;tasks={};TheWorld={ismastersim=master}
        local code=version=='beta'and beta_fear or stable_fear
        local native=assert(loadstring(code,version=='beta'and beta_fear_path or stable_fear_path))()
        local i=actor();i.GetClaustrophobia=native.get;i.CanGainClaustrophobia=native.can
        local value=0
        if version=='beta'then i.claustrophobia={value=function()return tostring(value)end,set=function(_,v)check(master,'clients never write authoritative fear netvar');value=v end}
        else i.claustrophobia=0 end
        i.claustrophobiamodifier=0;i.wixiepanic=false
        i:ListenForEvent('equip',native.equip);i:ListenForEvent('unequip',native.unequip);i:ListenForEvent('newstate',native.newstate)
        if native.panic then i:ListenForEvent('um_claustrophobiapanic',native.panic)end
        local unrelated=0;i:ListenForEvent('equip',function()unrelated=unrelated+1 end)
        local e=env();local hook,graphs
        e.AddPrefabPostInit=function(n,f)check(n=='wixie','fear patch limited to Wixie');hook=f end
        graphs={};e.AddStategraphPostInit=function(n,f)graphs[n]=f end
        assert(setfenv(assert(loadstring(fear_patch)),e))()
        hook(i);i:DoTaskInTime(0,native.init);tick(.2)
        check(i.wixietask and i.wixietask.cancelled,'native '..version..' frame task cancelled')
        check(i.no_claustrophobia and not i:CanGainClaustrophobia(),'native '..version..' fear gain blocked')
        near(i:GetClaustrophobia(),0,'fear getter cleared')
        if version=='beta'then near(tonumber(i.claustrophobia:value()),0,'replicated fear is zero')else near(i.claustrophobia,0,'legacy client fear is zero')end
        i:PushEvent('equip',{});check(unrelated==1,'other mod equipment listeners preserved')
        check(#i.event_listeners.equip[i]==1,'only native fear equipment handler removed')
        native.init(i);check(i.wixietask.cancelled,'later native init cannot recreate task')
        for _,graph in ipairs({'wilson','wilson_client'})do
            local called=0;local state={onenter=function()called=called+1 end};local sg={states={claustrophobic=state}}
            graphs[graph](sg);state.onenter(i);check(i.sg.laststate=='idle'and called==0,'queued panic blocked on '..graph)
            local other=actor('walter');state.onenter(other);check(called==1,'other characters retain panic handler')
        end
    end
    -- Disabled option loads no patch: the real upstream algorithm still works.
    clock=0;tasks={};TheWorld={ismastersim=true}
    local n=assert(loadstring(version=='beta'and beta_fear or stable_fear))();local i=actor()
    local value=0;i.claustrophobia=version=='beta'and{value=function()return value end,set=function(_,v)value=v end}or 0
    i.GetClaustrophobia=n.get;i.CanGainClaustrophobia=n.can;i.claustrophobiamodifier=0
    n.init(i);tick(.1);check(i:GetClaustrophobia()>0,'disabled '..version..' fear accumulates normally')
end

-- Actual native GUI option selection and CollectSettings, without rendering widgets.
Screen={_ctor=function()end}
ModConfigurationScreen={};assert(loadstring(native_collect))()
local collect=ModConfigurationScreen.CollectSettings
local class={_ctor=assert(loadstring(native_config_ctor))()}
local all={{name='walter',default=true,saved=false,options={}},{name='wixie',default=true,saved=false,options={}},
    {name='Wixie No Claustrophobia',default=true,saved=false,options={}},
    {name='Walter Use Wixie Slingshot',default=true,saved=false,options={}},
    {name='wathom nightvision',default=true,saved=false,options={}}}
local enabled={}
KnownModIndex={GetModsToLoad=function()return enabled end,GetModInfo=function(_,n)return {name=n}end,
    LoadModConfigurationOptions=function()return all end}
local originalLoad=KnownModIndex.LoadModConfigurationOptions
local config=assert(loadstring(config_patch))()
config.Install({KnownModIndex=KnownModIndex,require=function()return class end,TheNet={IsDedicated=function()return false end}},'ours')
local function screen(name)
    local s={CollectSettings=collect};class._ctor(s,name or 'ours',false);return s
end
local s=screen();check(#s.options==1,'no UM: Wixie and Wathom options hidden')
check(KnownModIndex.LoadModConfigurationOptions==originalLoad,'GUI config loader restored')
check(#all==5,'underlying runtime options never removed')
s.options[1].value=true;local saved=s:CollectSettings()
check(#saved==5,'hidden settings included when saving')
for _,o in ipairs(saved)do if o.name~='walter'then check(o.saved==false,'hidden saved preference retained')end end
for _,id in ipairs({'workshop-2039181790','workshop-3193922031','2039181790','Uncompromising Mode: Public Beta'})do
    enabled={id};s=screen();check(#s.options==5,'enabled stable/Beta/local exposes Wixie and Wathom options '..id)
end
local beforewx=all
all={{name='WX-78 Mode',default='legacy',saved='draft',options={}},
    {name='wx78_easy',default=true,saved=false,options={}},
    {name='wx-78',default=true,saved=true,options={}}}
s=screen();check(#s.options==1,'WX-78 exposes only the merged mode selector')
saved=s:CollectSettings();check(#saved==3,'WX-78 hidden old switches survive a settings save')
for _,o in ipairs(saved)do
    if o.name=='wx78_easy'then check(o.saved==false,'WX-78 preserves disabled old easy setting')end
    if o.name=='wx-78'then check(o.saved==true,'WX-78 preserves enabled old hard setting')end
end
all=beforewx
enabled={};check(#screen('other').options==5,'other mods never filtered')
local failing=function()error('injected GUI constructor failure')end
KnownModIndex.LoadModConfigurationOptions=failing
check(not pcall(screen),'constructor error propagated')
check(KnownModIndex.LoadModConfigurationOptions==failing,'constructor failure still restores config loader')
KnownModIndex.LoadModConfigurationOptions=originalLoad
local originalctor=class._ctor
config.Install({require=function()return class end},'second_copy');check(class._ctor==originalctor,'repeated frontend loading does not stack wrappers')
check(#screen('second_copy').options==1,'multiple mod copies supported')
local dedicated=false;config.Install({TheNet={IsDedicated=function()return true end},require=function()dedicated=true end},'dedicated')
check(not dedicated,'dedicated server never loads GUI')
local umoption={name='um_patch',default=true,options={{data=false},{data=true}}}
table.insert(all,umoption)
for _,mods in ipairs({{}, {'workshop-2039181790'}, {'workshop-3193922031'}}) do
    enabled=mods
    for _,legacy in ipairs({1,2,3,true,false}) do
        umoption.saved=legacy
        local configured=screen():CollectSettings()
        local saved
        for _,option in ipairs(configured) do
            if option.name=='um_patch' then saved=option.saved end
        end
        check(saved==(legacy~=false),'UM patch settings keep legacy levels on and explicit off off')
        check(umoption.saved==legacy,'UM patch GUI migration does not mutate the runtime options')
    end
end
table.remove(all)

local furnace = {name = "dragonfly furnace stewer", default = true, options = {{data = false}, {data = true}}}
table.insert(all, furnace)
for _, value in ipairs({-1, true, false}) do
    furnace.saved = value
    local selected
    for _, option in ipairs(screen():CollectSettings()) do
        if option.name == furnace.name then selected = option.saved end
    end
    check(selected == (value ~= false), "Furnace migrates the old enabled selection and preserves explicit off")
    check(furnace.saved == value, "Furnace GUI migration leaves runtime settings intact")
end
table.remove(all)

local ruin = {name = "epic_ruin", default = 0.8, options = {
    {data = false}, {data = 0.6}, {data = 0.8}, {data = "full"}, {data = 2},
}}
table.insert(all, ruin)
for _, value in ipairs({1, false, 0.6, 0.8, "full", 2}) do
    ruin.saved = value
    local selected
    for _, option in ipairs(screen():CollectSettings()) do
        if option.name == "epic_ruin" then selected = option.saved end
    end
    check(selected == (value == 1 and 0.8 or value), "Epic Ruin migrates the old 100% selection in the configuration screen")
end
table.remove(all)

local exchange = {name = "World Exchange", default = "coordinated", options = {
    {data = "off"}, {data = "classic"}, {data = "coordinated"},
}}
table.insert(all, exchange)
for _, value in ipairs({false, "traditional", "coordinated", "off", "classic"}) do
    exchange.saved = value
    local selected
    for _, option in ipairs(screen():CollectSettings()) do
        if option.name == "World Exchange" then selected = option.saved end
    end
    local legacy = value == false or value == "traditional"
    check(selected == (legacy and "coordinated" or value), "World Exchange migrates old settings and saves explicit selections")
end
table.remove(all)

-- Native screen collection migrates the obsolete default but preserves every
-- explicit traditional selection through multiple close/reopen cycles.
for _,name in ipairs({"combat","epic_armor_5"})do
    local default=name=="combat"and 4 or "dynamic"
    local option={name=name,default=default,options={{data=false},{data="traditional_1"},{data=default}}}
    table.insert(all,option)
    for _,value in ipairs({1,true,false,"traditional_1",2,3,4,5,default})do
        option.saved=value
        local expected=(value==1 or value==true)and default or value
        for round=1,3 do
            local selected
            for _,saved in ipairs(screen():CollectSettings())do if saved.name==name then selected=saved.saved end end
            check(selected==expected,"combat GUI migration/manual choice survives reopen "..name.." "..round)
            option.saved=selected
        end
    end
    table.remove(all)
end

-- Native speed helpers exercise real timeline mutation, with both independent switches.
local function runrole(source,w,wix)
    local e=env();e.TUNING={DSTU=true,WIXIE_HEALTH=1};e.TheWorld={ismastersim=true}
    e.GetModConfigData=function(n)if n=='walter'then return w elseif n=='wixie'then return wix end end
    local hooks,recipes,graphs={},{},{}
    e.AddPrefabPostInit=function(n,f)hooks[n]=f end;e.AddRecipePostInit=function(n,f)recipes[n]=f end
    e.AddStategraphPostInit=function(n,f)graphs[n]=graphs[n]or{};table.insert(graphs[n],f)end
    assert(setfenv(assert(loadstring(native_speed)),e))();assert(setfenv(assert(loadstring(source)),e))()
    return e,hooks,recipes,graphs
end
for _,w in ipairs({false,true})do for _,wix in ipairs({false,true})do
    local e,hooks,recipes,graphs=runrole(role_patch,w,wix)
    check((recipes.portabletent_item~=nil)==w,'Wixie setting does not change Walter tent recipe')
    for _,graph in ipairs({'wilson','wilson_client'})do
        for _,name in ipairs({'slingshot_charge','slingshot_shoot','slingshot_special'})do
            local state={name=name,timeline={{time=1,fn=function()end}},onenter=function()end,onexit=function()end}
            local sg={states={[name]=state}};for _,f in ipairs(graphs[graph])do f(sg)end
            for _,character in ipairs({'wixie','walter'})do
                local i=actor(character);i.sg.currentstate=state;i.sg.timeout=10;state.onenter(i)
                local applied=character=='wixie'and wix or character=='walter'and w
                if applied then
                    local factor=1/((name=='slingshot_special'and 2 or character=='wixie'and 1.6 or 1.7)+.5)
                    near(i.animspeed,factor,'character-specific speed '..character..name)
                    check(i.sg.currentstate~=state,'active slowdown uses private state')
                    near(i.sg.currentstate.timeline[1].time,1/factor,'private timeline slowed')
                else check(i.animspeed==nil,'disabled character never slowed '..character..name)end
                near(state.timeline[1].time,1,'shared timeline remains native for other player')
                state.onexit(i)
                if applied then near(i.animspeed,1,'exit restores speed')end
            end
        end
    end
    for _,character in ipairs({'wixie','walter'})do
        local owner=actor(character);local proj={range=99,SetOnThrownFn=function(s,f)s.onthrown=f end}
        hooks.slingshotammo_rock_proj({components={projectile=proj}})
        proj.onthrown({},owner,{},owner)
        near(proj.range,(character=='wixie'and wix or character=='walter'and w)and 20 or 99,'projectile range follows shooter switch')
        proj={range=99,SetOnThrownFn=function(s,f)s.onthrown=f end}
        hooks.slingshotammo_rock_proj({components={projectile=proj}})
        proj.onthrown({},{components={inventoryitem={owner=owner}}},{})
        near(proj.range,(character=='wixie'and wix or character=='walter'and w)and 20 or 99,'weapon owner resolves shooter switch')
    end
end end
for _,character in ipairs({'wixie','walter'})do for _,name in ipairs({'slingshot_charge','slingshot_shoot','slingshot_special'})do
    local rates={}
    for _,source in ipairs({old_role,role_patch})do
        local e,h,r,graphs=runrole(source,true,true)
        local state={name=name,timeline={{time=1,fn=function()end}},onenter=function()end,onexit=function()end}
        local sg={states={[name]=state}};for _,f in ipairs(graphs.wilson)do f(sg)end
        local i=actor(character);i.sg.currentstate=state;i.sg.timeout=10;state.onenter(i)
        rates[#rates+1]=i.animspeed;state.onexit(i)
    end
    near(rates[1],rates[2],'default numeric speed preserved against previous source '..character..name)
end end
do
    local e,h,r,graphs=runrole(role_patch,true,true)
    local idle={name='idle'}
    local state={name='slingshot_charge',timeline={{time=1}},onenter=function(i)i.sg.currentstate=idle end}
    local sg={states={slingshot_charge=state}};for _,f in ipairs(graphs.wilson)do f(sg)end
    local i=actor('wixie');i.sg.currentstate=state;state.onenter(i)
    check(i.sg.currentstate==idle and i.animspeed==nil,'native aborted charge stays idle without applying slowdown')
end
-- Exercise the engine's actual buffered event dispatch while the private
-- slingshot state is active. Plain table fixtures miss inherited State methods.
for _,graph in ipairs({'wilson','wilson_client'})do
    for _,name in ipairs({'slingshot_charge','slingshot_shoot','slingshot_special'})do
        for _,character in ipairs({'wixie','walter'})do
            local e,h,r,graphs=runrole(role_patch,true,true)
            local handled,fallback,fired=0,0,0
            local state=State{name=name,onenter=function()end,onexit=function()end,
                timeline={TimeEvent(1,function()fired=fired+1 end)},
                events={EventHandler('locomote',function()handled=handled+1;return true end)}}
            local sg={name=graph,states={[name]=state},events={
                animover=EventHandler('animover',function()fallback=fallback+1 end)}}
            for _,f in ipairs(graphs[graph])do f(sg)end
            local i=actor(character);i.sg=StateGraphInstance(sg,i)
            i.sg.currentstate=state;i.sg.timeout=10;state.onenter(i)
            i.sg:PushEvent('locomote');i.sg:PushEvent('animover');i.sg:HandleEvents()
            check(handled==1 and fallback==1,'native event dispatch survives '..graph..character..name)
            check(i.sg.currentstate:is_a(State),'private state retains native State class')
            check(i.sg.currentstate.timeline[1]:is_a(TimeEvent),'private timeline retains native TimeEvent class')
            i.sg.currentstate.timeline[1].fn(i);check(fired==1,'private timeline callback preserved')
            state.onexit(i);near(i.animspeed,1,'native state exit restores speed')
        end
    end
end
-- Native restrictions and both actual UM action wrappers, on server and client.
ACTIONS={ATTACK='attack'}
IsEntityDead=function(i)return i.dead or false end
hash=function(name)return 'hash:'..name end
for _,master in ipairs({false,true})do for _,enabled in ipairs({false,true})do
    local e=env();local hooks,components,graphs={},{},{}
    e.TUNING={DSTU=true,WIXIE_HEALTH=1,easymode2hm=false,SLINGSHOT_DISTANCE=10,SLINGSHOT_DISTANCE_MAX=14}
    e.TheWorld={ismastersim=master}
    e.STRINGS={NAMES={},RECIPE_DESC={}}
    e.TECH={CELESTIAL_THREE={}}
    e.Ingredient=function(name,count)return {type=name,amount=count}end
    e.AddRecipe2=function(name,ingredients,tech,config)
        config.name=name;config.product=name;config.ingredients=ingredients;config.level=tech
        e.AllRecipes[name]=config
    end
    e.ModManager={GetPostInitFns=function()return {} end}
    e.GetModConfigData=function(n)return n=='Walter Use Wixie Slingshot'and enabled or false end
    e.AddPrefabPostInit=function(n,f)
        local previous=hooks[n]
        hooks[n]=previous and function(inst)previous(inst);f(inst)end or f
    end
    e.AddComponentPostInit=function(n,f)components[n]=f end
    e.AddStategraphPostInit=function(n,f)graphs[n]=f end
    local rock,firecrackers,coconut=actor('slingshotammo_rock'),actor('slingshotammo_firecrackers'),actor('coconut')
    coconut:AddTag('slingshotammo')
    local recipes={native={product=rock.prefab},exclusive={product=firecrackers.prefab,builder_tag='pebblemaker'},
        coconut={product=coconut.prefab}}
    e.AllRecipes=recipes
    e.GetValidRecipe=function(name)return recipes[name]end
    local containers={widgetsetup=function(container)
        container.itemtestfn=function(_,_,slot)return slot==1 end
    end}
    e.require=function(name)assert(name=='containers');return containers end
    assert(setfenv(assert(loadstring(access_patch)),e))()
    do
        local recipe=recipes.slingshotammo_moonglass_walter2hm
        check(recipe and recipe.builder_tag=='walter_moonglass2hm','round recipe has separate Walter permission')
        check(recipe.builder_skill=='walter_ammo_shattershots'and recipe.numtogive==20,'native glass skill and yield')
        check(recipe.no_builder_tag==nil,'round recipe is not classified as Wixie ammo')
        check(recipe.atlas=='images/inventoryimages3.xml'and recipe.image=='slingshotammo_moonglass.tex','native round icon bypasses UM override')
        local crafter={components={skilltreeupdater={IsActivated=function()return false end}}}
        check(recipe.override_numtogive_fn(recipe,crafter)==nil,'normal native yield')
        crafter.components.skilltreeupdater.IsActivated=function()return true end
        check(recipe.override_numtogive_fn(recipe,crafter)==30 and recipe.sg_state(recipe,crafter)=='domediumaction','native efficiency yield and crafting state')
    end
    do
        local graph=master and 'wilson' or 'wilson_client'
        local released=0
        local native=State{name='slingshot_charge',tags={'busy','aoecharging'},
            server_states=not master and {'slingshot_charge'} or nil,
            events={EventHandler('chargingreticulereleased',function()released=released+1 end)}}
        local sg={name=graph,states={slingshot_charge=native},actionhandlers={}}
        for _,f in ipairs(e.ModManager:GetPostInitFns('StategraphPostInit',graph))do f(sg)end
        local saved=sg.states.slingshot_charge_native2hm
        check(saved and saved:is_a(State),'saved charge retains engine State methods')
        check(native.name=='slingshot_charge','original State name untouched')
        if not master then
            check(saved.server_states[hash(saved.name)] and not saved.server_states[hash(native.name)],'client predicts matching native charge alias')
        end
        saved:HandleEvent({inst={}},'chargingreticulereleased',{})
        check(released==1,'native release handler survives UM replacement')
        local entered,exited=0,0
        local um=State{name='slingshot_charge',tags={'abouttoattack'},
            onenter=function()entered=entered+1 end,onexit=function()exited=exited+1 end}
        sg.states.slingshot_charge=um
        graphs[graph](sg)
        for _,prefab in ipairs({'slingshotex','slingshot999ex','slingshot','slingshot_gnasher','slingshot_matilda'})do
            local p=actor('walter');local charged=prefab=='slingshotex' or prefab=='slingshot999ex'
            local weapon={prefab=prefab,components={aoecharging=charged and {} or nil}}
            p.replica.inventory={GetEquippedItem=function()return weapon end}
            p.components.inventory=master and p.replica.inventory or nil
            local selected
            p.sg.GoToState=function(_,name)selected=name;um.onexit(p)end
            local before=entered;um.onenter(p)
            check(charged and selected==saved.name or not charged and selected==nil,'charge route '..graph..prefab)
            check(entered==before+(charged and 0 or 1),'only UM weapons invoke UM charge')
            if charged then check(exited==0,'redirect skips unentered UM cleanup')end
        end
        check(#e.ModManager:GetPostInitFns('StategraphPostInit','spider')==0,'unrelated graph hooks unchanged')
    end
    local w=actor('walter');w:AddTag('player')
    local built=0
    if master then w.components.builder={DoBuild=function()built=built+1;return true end} end
    hooks.walter(w)
    check(w:HasTag('troublemaker')==enabled,'only exclusive permission follows switch')
    check(w:HasTag(recipes.exclusive.no_builder_tag),'exclusive ammo recipes reject Walter in crafting')
    check(not actor('wixie'):HasTag(recipes.exclusive.no_builder_tag) and recipes.exclusive.builder_tag=='pebblemaker',
        'Wixie retains her recipe requirement')
    check(recipes.native.no_builder_tag==nil and recipes.coconut.no_builder_tag==nil,'native ammo and ordinary items keep their recipes')
    if master then
        check(not w.components.builder:DoBuild('exclusive') and built==0,'server rejects direct exclusive ammo crafting')
        check(w.components.builder:DoBuild('native') and built==1,'server still crafts native ammo')
    end
    for _,widget in ipairs({'slingshot','slingshot2ex','matilda','jessie'}) do
        local owner=w
        local gun=actor(widget)
        if master then gun.components.inventoryitem={GetGrandOwner=function()return owner end} end
        local container={inst=gun,IsOpenedBy=function(_,player)return player==owner end}
        e.ThePlayer=owner
        containers.widgetsetup(container,widget)
        check(not container:itemtestfn(firecrackers,1),'Walter cannot load UM ammo in '..widget)
        check(not container:itemtestfn(coconut,1),'Walter cannot use a coconut as UM ammo in '..widget)
        check(container:itemtestfn(rock,1) and not container:itemtestfn(rock,2),'slot rules preserved in '..widget)
        owner=actor('wixie')
        e.ThePlayer=owner
        check(container:itemtestfn(firecrackers,1),'Wixie can load UM ammo in '..widget)
    end
    for _,tag in ipairs({'troublemaker','slingshot_sharpshooter','pebblemaker'})do
        local weapon={components={},replica={inventoryitem={GetEquipRestrictedTag=function()return tag end}}}
        local restricted=assert(loadstring(master and server_restricted or client_restricted))()
        check(restricted({inst=weapon,restrictedtag=tag},w)==(tag=='troublemaker'and not enabled),'native restriction '..tag)
        local other=actor('wilson');other:AddTag('player')
        check(restricted({inst=weapon,restrictedtag=tag},other),'other characters remain restricted')
        weapon.components.linkeditem={IsEquippableRestrictedToOwner=function()return true end,GetOwnerUserID=function()return 'other_player' end}
        w.userid='walter_player'
        check(restricted({inst=weapon,restrictedtag=tag},w),'linked ownership remains enforced on '..tag)
    end
    for _,version in ipairs({'stable','beta'})do
        local graph=master and 'wilson'or'wilson_client'
        local sg={actionhandlers={[ACTIONS.ATTACK]={deststate=assert(loadstring(_G['SG'..graph..'_attack']))()}}}
        assert(loadstring(_G[version..'_fear_SGwixie'..(master and ''or'_client')]))()(sg)
        graphs[graph](sg)
        local selected
        w.sg.mem={};w.components.combat=master and{GetWeapon=function()return selected end}or nil
        w.replica.combat={GetWeapon=function()return selected end}
        for _,name in ipairs({'slingshot','slingshotex','slingshot999ex','slingshot2','slingshot2ex'})do
            selected=actor(name);selected:AddTag('slingshot')
            check(sg.actionhandlers[ACTIONS.ATTACK].deststate(w,{target={}})=='slingshot_shoot','actual '..version..' '..graph..' fires '..name)
        end
        selected=actor('slingshot_matilda');selected:AddTag('slingshot')
        if enabled then check(sg.actionhandlers[ACTIONS.ATTACK].deststate(w,{target={}})=='shove','exclusive attack remains UM')end
        local wixie=actor('wixie');wixie:AddTag('troublemaker');wixie.sg.mem={}
        wixie.components.combat=w.components.combat;wixie.replica.combat=w.replica.combat
        selected=actor('slingshot');selected:AddTag('slingshot')
        check(sg.actionhandlers[ACTIONS.ATTACK].deststate(wixie,{target={}})=='shove','Wixie retains her base slingshot shove')
        w.dead=true;w.components.health.IsDead=function()return true end
        check(sg.actionhandlers[ACTIONS.ATTACK].deststate(w,{target={}})==nil,'dead Walter cannot attack')
        w.dead=false;w.components.health.IsDead=function()return false end
    end
    if master then
        local contents={firecrackers,rock,firecrackers}
        local dropped=0
        local container={
            GetNumSlots=function()return 3 end,
            GetItemInSlot=function(_,slot)return contents[slot]end,
            DropItemBySlot=function(_,slot,_,keepstack)assert(keepstack);dropped=dropped+1;contents[slot]=nil end,
        }
        w.GetPosition=function()return {} end
        local equip={SetOnEquip=function(self,fn)self.onequipfn=fn end,
            onequipfn=function(_,owner)check(dropped==(owner==w and 2 or 0),'unload before original equip callback')end}
        local matilda={components={container=container,equippable=equip}}
        hooks.slingshot_matilda(matilda)
        equip.onequipfn(matilda,actor('wixie'))
        check(contents[1]==firecrackers and contents[3]==firecrackers,'Wixie keeps preloaded UM ammo')
        equip.onequipfn(matilda,w)
        check(contents[1]==nil and contents[2]==rock and contents[3]==nil,'Walter ejects only preloaded UM ammo')
        local called=0
        local equip={restrictedtag='troublemaker',onequipfn=function()called=called+1 end,onunequipfn=function()called=called+1 end}
        function equip:SetOnEquip(f)self.onequipfn=f end
        function equip:SetOnUnequip(f)self.onunequipfn=f end
        local weapon={damage=10,attackrange=.5,hitrange=.5}
        function weapon:SetDamage(n)self.damage=n end
        function weapon:SetRange(a,b)self.attackrange=a;self.hitrange=b end
        local item={components={equippable=equip,weapon=weapon}}
        hooks.slingshot(item)
        check(equip.restrictedtag=='slingshot_sharpshooter','base slingshot restores replicated native restriction')
        equip.onequipfn(item,w)
        check(weapon.damage==0 and weapon.attackrange==10 and weapon.hitrange==14,'Walter native projectile range')
        equip.onunequipfn(item,w)
        check(weapon.damage==10 and weapon.attackrange==.5 and weapon.hitrange==.5,'unequip restores UM weapon values')
        equip.onequipfn(item,actor('wixie'));equip.onunequipfn(item,actor('wixie'))
        check(weapon.damage==10 and weapon.attackrange==.5 and called==4,'Wixie values and callbacks unchanged')
        local ammo={components={container={restrictedtag='troublemaker'}}};hooks.slingshotammo_container(ammo)
        check(ammo.components.container.restrictedtag=='slingshot_sharpshooter','native ammo container access restored')
    end
    if enabled then
        local seen
        local spawner={SpawnAtLocation=function(_,_,p)seen=p:HasTag('troublemaker');return 'spawned' end}
        components.playerspawner(spawner)
        check(spawner:SpawnAtLocation({},w)=='spawned'and not seen,'Walter keeps native spawn route')
        check(w:HasTag('troublemaker'),'exclusive permission restored after spawn')
        local wixie=actor();wixie:AddTag('troublemaker');spawner:SpawnAtLocation({},wixie)
        check(seen and wixie:HasTag('troublemaker'),'Wixie retains wardrobe spawn')
    else check(components.playerspawner==nil,'disabled option needs no spawn workaround')end
end end
locale='zh';assert(loadstring(modinfo_source))()
local found={};for _,v in ipairs(configuration_options)do found[v.name]=v end
check(found.wixie and found.wixie.default==true,'independent hard option defaults on')
check(found['Wixie No Claustrophobia']and found['Wixie No Claustrophobia'].default==true,'independent fear removal defaults on')
check(found['Walter Use Wixie Slingshot'].default==true,'Walter can equip Wixie slingshots by default')
local patchOption=found.um_patch
check(patchOption.default==true and #patchOption.options==2,'UM patch has two choices and defaults on')
check(patchOption.options[1].data==false and patchOption.options[2].data==true,'UM patch choices use booleans')
print('WIXIE_CHECKS_PASS '..checks)
