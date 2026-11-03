local checks = 0
local function check(ok, label) checks = checks + 1; assert(ok, label) end
GLOBAL = _G
TUNING = native_fire_tuning
TUNING.TOTAL_DAY_TIME,TUNING.PVP_DAMAGE_MOD,TUNING.DSTU=480,.5,{WINTER_FIRE_MOD=.65}
math.clamp = function(v,a,b) return math.max(a,math.min(b,v)) end
Remap = function(v,a,b,c,d) return c+(v-a)/(b-a)*(d-c) end
VecUtil_LengthSq = function(x,z) return x*x+z*z end
SpawnPrefab = function() end -- Visual smoke/FX have no heat propagation component.
local Propagator = assert(loadstring(propagator_source))()
local Burnable = assert(loadstring(burnable_source))()
local hooks, entities, jobs, clock
AddComponentPostInit = function(name,fn)
    hooks[name]=hooks[name] or {};table.insert(hooks[name],fn)
end
AddPrefabPostInit=function()end
AddRecipePostInit=function()end
AddStategraphState=function()end
AddStategraphPostInit=function()end
State=function(t)return t end
EventHandler=function()end
GetModConfigData=function(name)return name=='willow_improve' or name=='Willow Fire Weapon Attack'end
env={AddComponentPostInit=AddComponentPostInit}
UMSimTempOverride={}
UMCommonFns={IsNotFriendly=function()return true end}

local function entity(name,x,tag,tile)
    local inst={prefab=name,x=x,tags={},components={},tile=tile or {}}
    if tag then inst.tags[tag]=true end
    inst.Transform={GetWorldPosition=function()return inst.x,0,0 end}
    function inst:IsValid()return not self.removed end
    function inst:HasTag(t)return self.tags[t]==true end
    function inst:HasOneOfTags(tags)for _,t in ipairs(tags)do if self:HasTag(t)then return true end end;return false end
    function inst:HasAnyTag(...)return self:HasOneOfTags({...})end
    function inst:AddTag(t)self.tags[t]=true end
    function inst:RemoveTag(t)self.tags[t]=nil end
    function inst:AddOrRemoveTag(t,v)self.tags[t]=v==true end
    function inst:GetCurrentTileType()return 1,self.tile end
    function inst:ListenForEvent()end
    function inst:PushEvent()end
    function inst:DoTaskInTime(delay,fn,...)
        local args={...}
        local job={at=clock+delay,inst=self,fn=function()fn(self,unpack(args))end,Cancel=function(t)t.cancelled=true end}
        table.insert(jobs,job);return job
    end
    function inst:DoPeriodicTask(period,fn,initial,...)
        local job=self:DoTaskInTime(initial or period,fn,...);job.period=period;return job
    end
    function inst:AddComponent(name)
        local component=(name=='propagator' and Propagator or Burnable)(self)
        self.components[name]=component
        if name=='burnable' then
            component.SpawnFX=function()end
            component.onsmoldering=function()self.smoldered=self.smoldered or clock end
            component.onignite=function()self.ignited=self.ignited or clock end
        end
        for _,hook in ipairs(hooks[name] or {})do hook(component)end
        return component
    end
    entities[#entities+1]=inst;return inst
end
TheSim={FindEntities=function(_,x,y,z,r,must,cant,oneof)
    local result={}
    for _,inst in ipairs(entities)do
        local valid=inst:IsValid() and (inst.x-x)^2<=r*r
        for _,t in ipairs(must or {})do valid=valid and inst:HasTag(t)end
        if valid and (not cant or not inst:HasOneOfTags(cant)) and (not oneof or inst:HasOneOfTags(oneof))then
            result[#result+1]=inst
        end
    end
    return result
end}
local function advance(untiltime)
    while true do
        local nextjob
        for _,job in ipairs(jobs)do
            if not job.cancelled and job.at<=untiltime and (not nextjob or job.at<nextjob.at)then nextjob=job end
        end
        if not nextjob then break end
        clock=nextjob.at
        if nextjob.period then nextjob.at=nextjob.at+nextjob.period else nextjob.cancelled=true end
        if nextjob.inst:IsValid()then nextjob.fn()end
    end
    clock=untiltime
end

local function run(mode,season,size,distance,sources,controlled,tile,direct)
    hooks,entities,jobs,clock={},{},{},0;math.randomseed(8842)
    TheWorld={ismastersim=true,state={season=season,isspring=season=='spring',iswinter=season=='winter',
        israining=season=='rain',precipitationrate=1},HasTag=function()return false end}
    local function loadum()assert(loadstring(um_propagator))();assert(loadstring(um_burnable))()end
    if mode:find('um',1,true) and not mode:find('reverse',1,true)then loadum()end
    if mode:find('baseline',1,true)then assert(loadstring(baseline_patch))();assert(loadstring(baseline_willow))()
    elseif mode:find('current',1,true)then
        assert(loadstring(current_patch))();assert(loadstring(current_willow))();assert(loadstring(turret_source))()
    end
    if mode:find('reverse',1,true)then loadum()end
    local fires={}
    for i=1,sources do
        local inst=entity('campfire',(i-1)*.15,controlled and 'player' or nil)
        inst:AddComponent('burnable');local p=inst:AddComponent('propagator')
        -- Actual native campfire's highest fuel section (checked below).
        p.propagaterange,p.heatoutput,p.damages=4,10,true
        if controlled then
            inst:AddTag('controlled_burner')
            inst.components.skilltreeupdater={IsActivated=function()return false end}
        end
        fires[#fires+1]=inst
    end
    local target=entity('target',distance,nil,tile)
    target:AddComponent('burnable')
    local makepropagator=({small=MakeSmallPropagator,medium=MakeMediumPropagator,large=MakeLargePropagator})[size]
    makepropagator(target)
    for _,inst in ipairs(fires)do inst.components.burnable:Ignite(true,controlled and inst or nil)end
    if direct then target.components.burnable:Ignite(true,fires[1])end
    local trace={}
    for step=1,120 do
        advance(step*.5)
        trace[#trace+1]=string.format('%.9f/%s/%s',target.components.propagator.currentheat,
            tostring(target.components.burnable.smoldering),tostring(target.components.burnable.burning))
    end
    return table.concat(trace,';')..';'..tostring(target.smoldered)..';'..tostring(target.ignited),target.smoldered,target.ignited
end

check(campfire_source:find('local PROPAGATE_RANGES = { 1, 2, 3, 4 }',1,true) and
    campfire_source:find('local HEAT_OUTPUTS = { 2, 5, 5, 10 }',1,true),'scenario uses actual installed campfire heat values')
for _,season in ipairs({'autumn','spring','winter','rain'})do
    for _,size in ipairs({'small','medium','large'})do
        for _,distance in ipairs({1,2.5,4.5})do
            for _,sources in ipairs({1,4})do
                local native=run('native',season,size,distance,sources)
                local baseline=run('baseline',season,size,distance,sources)
                local current=run('current',season,size,distance,sources)
                check(native==baseline,'upstream ordinary fire trace equals native')
                check(baseline==current,'current ordinary fire trace equals upstream')
                local um=run('um',season,size,distance,sources)
                check(um==run('um_baseline',season,size,distance,sources),'upstream leaves UM ordinary fire trace unchanged')
                check(um==run('um_current',season,size,distance,sources),'current leaves UM ordinary fire trace unchanged')
                check(um==run('um_baseline_reverse',season,size,distance,sources),'upstream and UM reverse hook order retain ordinary fire trace')
                check(um==run('um_current_reverse',season,size,distance,sources),'current and UM reverse hook order retain ordinary fire trace')
            end
        end
    end
end
for _,mode in ipairs({'native','baseline','current','um','um_baseline','um_current','um_baseline_reverse','um_current_reverse'})do
    local _,smolder,burn=run(mode,'autumn','small',1,1,true)
    check(not smolder and not burn,'controlled burn does not ignite neighbour: '..mode)
    _,smolder,burn=run(mode,'autumn','small',1,1,false,{no_fire_spread=true})
    check(not smolder and not burn,'fireproof ground retains native resistance: '..mode)
end
local _,smolder,burn=run('current','autumn','small',1,1)
check(smolder and burn and burn>smolder and smolder>0,'nearby propagation keeps both heating and smoldering stages')
print('Fixed-seed small target: smolder',smolder,'ignite',burn)
local _,directsmolder,directburn=run('current','autumn','small',1,1,false,nil,true)
check(not directsmolder and directburn==0,'direct native Ignite bypasses smoldering by design')
print('Fire spread differential checks:',checks)
