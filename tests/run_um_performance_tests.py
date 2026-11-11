"""Exercise guarded adapters against both real workshop Lua implementations."""
from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))
from build_um_compat_profiles import BASE, runtime

SETUP = r'''
local checks=0
function check(ok,msg)checks=checks+1;assert(ok,msg)end
function totalchecks()return checks end
if beta then UM_CLIENT_CONFIG={UM_STORMS_OVER=false}end
setmetatable(_G,{__index=function(_,name)
    if name=='UM_CLIENT_CONFIG'or name=='TrySpawning'then error('undeclared global '..name)end
end})
function original(path)return readfn(sources[path],path)end
local modules={}
local base_require=require
require=function(name)
    if module_sources[name] then
        if not modules[name]then modules[name]=assert(loadstring(module_sources[name],'@scripts/'..name..'.lua'))()end
        return modules[name]
    end
    return base_require(name)
end
Guard=require('umcompatguard2hm')
local components,prefabhooks,simhooks={},{},{}
env={GLOBAL=_G,GetModConfigData=function(name)return name=='um_weather_particles2hm'and density or nil end,
    AddComponentPostInit=function(name,fn)components[name]=fn end,
    AddPrefabPostInit=function(name,fn)prefabhooks[name]=fn end,
    AddSimPostInit=function(fn)simhooks[#simhooks+1]=fn end}
require('umperformance2hm').Install(env,optional)
Ghooks={components=components,prefabs=prefabhooks,sim=simhooks}
Prefabs={}
for _,path in ipairs({'scripts/prefabs/hooded_fern.lua','scripts/prefabs/um_ocupus.lua',
    'scripts/prefabs/um_ocupus_eyetacle.lua','scripts/prefabs/snowpile.lua',
    'scripts/prefabs/air_conditioner_smoke.lua','scripts/prefabs/um_tornado.lua'})do
    if sources[path]then
        local result={original(path)}
        for _,p in ipairs(result)do Prefabs[p.name]=p end
    end
end
function apply(name,obj)if components[name]then components[name](obj)end return obj end
function hookprefab(name,obj)prefabhooks[name](obj)end
'''

CASES = r'''
-- Fingerprints accept relocated debug metadata but reject changed bodies.
local A=assert(loadstring('return function(a)return a+1 end','@x/a.lua'))()
local B=assert(loadstring('\n\nreturn function(a)return a+1 end','@y/b.lua'))()
local C=assert(loadstring('return function(a)return a+2 end','@y/b.lua'))()
check(Guard.Fingerprint(A)==Guard.Fingerprint(B),'ignore paths and line tables')
check(Guard.Fingerprint(A)~=Guard.Fingerprint(C),'reject changed instructions/constants')
check(not Guard.Match(A,'scripts/components/snowstormwatcher.lua',{}),'reject wrong source')
check(Guard.Fingerprint(print)==nil,'C functions safely skipped')
for _,fn in ipairs(Ghooks.sim)do fn()end

-- One active weather watcher; keep all original protection checks once.
local q,speed,events=0,0,0
TheWorld.state={iswinter=true};TheWorld.HasTag=function()return true end
TheWorld.net={HasTag=function()return true end}
TheSim={FindEntities=function()q=q+1;return {}end}
IsUnderRainDomeAtXZ=function()return false end
EQUIPSLOTS={BODY='body'}
local deferred={}
local function later(self,delay,fn,...)
    local args={...}
    local task={delay=delay,fn=fn,args=args,Cancel=function(t)t.cancelled=true end}
    deferred[#deferred+1]={task=task,inst=self}
    return task
end
local actor={Transform={GetWorldPosition=function()return 0,0,0 end},
    ListenForEvent=function()end,StartUpdatingComponent=function()end,
    HasTag=function()return false end,PushEvent=function()events=events+1 end,
    DoTaskInTime=later,
    components={playervision={HasGoggleVision=function()return false end,HasGhostVision=function()return false end},
        rider={IsRiding=function()return false end},inventory={GetEquippedItem=function()end},
        locomotor={SetExternalSpeedMultiplier=function()speed=speed+1 end}}}
local WC=original('scripts/components/snowstormwatcher.lua')
local watcher=apply('snowstormwatcher',WC(actor))
for i=1,300 do watcher:OnUpdate(1/30)end
check(speed==(optional and 300 or 600),'one speed update per tick')
check(q==(beta and (optional and 300 or 600)or(optional and 1200 or 2400)),'preserve branch protection queries')
check(#deferred==1,'one scheduled spawn opportunity')
if optional then check(TUNING.UM_COMPAT_STATUS2HM.snowpile_generation.applied,'generation hook applied')end

if optional then
    -- A changed upstream update remains exactly the supplied function.
    local future=assert(loadstring('return function(self,dt)return dt+5 end','@scripts/components/snowstormwatcher.lua'))()
    local changed={OnUpdate=future,UpdateSnowstormLevel=WC.UpdateSnowstormLevel,
        UpdateSnowstormWalkSpeed=WC.UpdateSnowstormWalkSpeed,StartSnowPileTask=function()end}
    apply('snowstormwatcher',changed)
    check(changed.OnUpdate==future,'changed code at same upstream path remains untouched')

    -- No structure query when the random-position spawn branch is used.
    q=0;local structure_queries=0;local random_calls=0
    TheSim.FindEntities=function(x,y,z,r,must,cant,oneof)
        q=q+1;if oneof and oneof[1]=='structure'then structure_queries=structure_queries+1 end
        return {}
    end
    TheWorld.Map={IsPassableAtPoint=function()return true end,GetTileAtPoint=function()return 0 end}
    AllPlayers={actor};actor.GetDistanceSqToPoint=function()return 0 end
    SpawnPrefab=function()return {Transform={SetPosition=function()end}}end
    local oldrand=math.random
    math.random=function(a,b)random_calls=random_calls+1;if a then return 0 else return .1 end end
    local chance=assert(Guard.Find(watcher.StartSnowPileTask,'SnowpileChance')).value
    chance(actor,watcher)
    math.random=oldrand
    check(structure_queries==0,'defer unused building query')
    check(random_calls==3 and watcher.task==nil,'preserve random opportunity and release handle')

    -- A non-winter controller stops updating instead of churning its timers.
    local starts,stops,active=0,0,{}
    local timer={AddTimer=function()end,ActiveTimerExists=function()return false end,
        GetTimeLeft=function(self,name)return active[name]end,
        StartTimer=function(self,name,t)starts=starts+1;active[name]=t end,
        StopTimer=function(self,name)stops=stops+1;active[name]=nil end,ResumeTimer=function()end}
    TheWorld.components.worldsettingstimer=timer
    TheWorld.state={iswinter=false,season='spring',issnowing=false}
    TheWorld.HasTag=function()return false end;TheWorld.RemoveTag=function()end
    TheWorld.net.HasTag=function()return false end;TheWorld.net.RemoveTag=function()end
    local SC=original('scripts/components/um_snow_stormspawner.lua')
    SC.WatchWorldState=function()end
    local stopped_component=0
    local world={StartUpdatingComponent=function()end,StopUpdatingComponent=function()stopped_component=stopped_component+1 end,
        WatchWorldState=function()end,DoTaskInTime=later,DoPeriodicTask=function()return {}end}
    local stormcontrol=apply('um_snow_stormspawner',SC(world))
    stormcontrol:OnPostInit()
    local before=starts
    for i=1,300 do stormcontrol:OnUpdate(1/30)end
    check(stopped_component>0 and starts==before,'non-winter controller does not recreate timers')
    check(TUNING.UM_COMPAT_STATUS2HM.snowstorm_idle.applied,'reviewed weather controller accepted')
end

-- Native sleeping-brain absence: exact cloud callback must not dereference nil.
local near=assert(Guard.Find(Prefabs.air_conditioner_cloud.fn,'OnNear')).value
local attached,stopped,bites=0,0,0
local host={entity={},IsValid=function()return true end,HasTag=function()return false end,
    AddTag=function()end,DoTaskInTime=later,
    components={health={DoDelta=function()bites=bites+1 end,DeltaPenalty=function()end},
        sanity={DoDelta=function()end}}}
local cloud={components={playerprox={onnear=near,SetOnPlayerNear=function(self,fn)self.onnear=fn end},
    health={},timer={SetTimeLeft=function()end}},
    Physics={Stop=function()end},entity={SetParent=function()attached=attached+1 end},
    Transform={SetPosition=function()end},RemoveComponent=function(self,name)self.components[name]=nil end,
    StopBrain=function()stopped=stopped+1 end,GetDistanceSqToInst=function()return 0 end,
    DoPeriodicTask=function(self,period,fn)return {period=period,fn=fn}end,
    red=0,green=0,blue=0}
hookprefab('air_conditioner_cloud',cloud)
local callback=cloud.components.playerprox.onnear
callback(cloud,host)
check(attached==1 and stopped==1 and bites==1 and cloud.bitetask~=nil,'cloud attaches without a brain, keeps original effects')
local changedcloud={components={health={},timer={},playerprox={onnear=C}},StopBrain=function()end}
hookprefab('air_conditioner_cloud',changedcloud)
check(changedcloud.components.playerprox.onnear==C,'unknown cloud left intact')
local missing={components={health={},timer={}},StopBrain=function()end}
check(pcall(function()hookprefab('air_conditioner_cloud',missing)end),'missing upstream component safely skips hook')
local smoke={AnimState={GetCurrentAnimationLength=function()return .9 end},DoTaskInTime=later,Remove=function()end}
hookprefab('air_conditioner_smoke',smoke)
check(smoke.persists==false and smoke.OnEntitySleep==smoke.Remove,'one-shot smoke never persists asleep')

if optional and beta then
    -- Early fern eligibility preserves original movement updates and arguments.
    local locomotor_hook
    local savedenv=env
    env={AddComponentPostInit=function(name,fn)locomotor_hook=fn end}
    original('init/init_weather/init_thicket.lua');env=savedenv
    local base_updates=0;q=0
    local mover={components={},Transform={GetWorldPosition=function()return 0,0,0 end},HasAnyTag=function()return false end}
    local motor={inst=mover,OnUpdate=function(self,dt,flag)base_updates=base_updates+1;return dt,flag end}
    locomotor_hook(motor);apply('locomotor',motor)
    local dt,flag=motor:OnUpdate(.25,true)
    check(q==0 and base_updates==1 and dt==.25 and flag==true,'excluded actor skips fern scan only')
    mover.components.health={IsDead=function()return false end}
    motor:OnUpdate(.25,false)
    check(q==1 and base_updates==2,'eligible actor retains scan')

    -- Finder never recursively removes/copied candidate tiles.
    TheWorld.components.um_tilelogger={Hazardous={}}
    local OC=original('scripts/components/um_ocupusappearinator.lua')
    local finder=apply('um_ocupusappearinator',OC({ListenForEvent=function()end}))
    finder:RegisterOcupus({GUID=1,IsValid=function()return true end,GetDistanceSqToPoint=function()return 0 end})
    for i=1,24000 do TheWorld.components.um_tilelogger.Hazardous[i]={x=i,z=0}end
    check(pcall(function()finder:SpawnOcupi()end),'24000 blocked tiles do not overflow stack')
    check(#TheWorld.components.um_tilelogger.Hazardous==24000,'placement never mutates original tiles')

    local MC=original('scripts/components/um_snowstormmanager.lua')
    local manager=apply('um_snowstormmanager',MC({}))
    local registry=manager.snowpiles
    manager.snowpiles[7]={};manager:UnregisterSnowpile({GUID=7});manager:UnregisterSnowpile({GUID=7})
    check(manager.snowpiles==registry and next(registry)==nil,'constant-time idempotent unregistration')
    local inside={GUID=1,IsValid=function()return true end,GetDistanceSqToPoint=function()return 4 end}
    local outside={GUID=2,IsValid=function()return true end,GetDistanceSqToPoint=function()return 101 end}
    local unrelated={GUID=3,IsValid=function()return true end,GetDistanceSqToPoint=function()return 1 end}
    registry[1],registry[2]=inside,outside
    TheSim.FindEntities=function()return {inside,outside,unrelated}end
    check(manager:CheckForOtherSnowpiles({x=0,z=0},100)==1,'local count respects registry and exact distance')

    -- Shared original fern callbacks now unregister once and handle relocation.
    local register=assert(Guard.Find(Prefabs.hooded_fern.fn,'RegisterPathFinding')).value
    local unregister=assert(Guard.Find(Prefabs.hooded_fern.fn,'UnregisterPathFinding')).value
    local adds,removes,x=0,0,0
    TheWorld.Pathfinder={AddWall=function()adds=adds+1 end,RemoveWall=function()removes=removes+1 end}
    local plant={GetPosition=function()return {x=x,z=0}end}
    register(plant);register(plant);unregister(plant);unregister(plant)
    check(adds==16 and removes==16 and plant._pfpos==nil,'fern pathfinding is paired and idempotent')
    register(plant);x=8;register(plant)
    check(adds==48 and removes==32,'moving a fern unregisters its old location')

    -- Repeated eye observations replace, rather than accumulate, watchers.
    local watch=assert(Guard.Find(Prefabs.um_ocupus_eyetacle.fn,'CheckForVictimsLong')).value
    local tasks={};local distance=0
    FindEntity=function()return {IsValid=function()return true end,GetDistanceSqToInst=function()return distance*distance end}end
    local eye={DoPeriodicTask=function(self,period,fn)
        local task={fn=fn,Cancel=function(t)t.cancelled=true end};tasks[#tasks+1]=task;return task
    end}
    for i=1,100 do watch(eye)end
    local live=0;for _,task in ipairs(tasks)do if not task.cancelled then live=live+1 end end
    check(live==1,'one live observation task after 100 refreshes')
    distance=30;tasks[#tasks].fn(eye)
    check(eye.droptask==nil and tasks[#tasks].cancelled,'last watcher exits with its target')
    local hide=assert(Guard.Find(Prefabs.um_ocupus_eye.fn,'Hide')).value
    local sub={components={locomotor={Stop=function()end}},AnimState={PlayAnimation=function()end,PushAnimation=function()end},
        Light={Enable=function()end},grabtask={Cancel=function()end},movin={Cancel=function()end}}
    hide(sub);check(sub.grabtask==nil and sub.movin==nil,'both submerged eye handles released')

    -- Repeated eye births retain live references only; removal callbacks defer
    -- compaction so native ipairs/Leave loops cannot skip the next child.
    local born=assert(Guard.Find(Prefabs.um_ocupus.fn,'Born')).value
    local remove=assert(Guard.Find(Prefabs.um_ocupus.fn,'RemoveAllTentacles')).value
    TheSim.FindEntities=function()return {}end
    TheWorld.Map={IsVisualGroundAtPoint=function()return false end}
    local pending,children={},{}
    local core={Transform={GetWorldPosition=function()return 0,0,0 end},IsValid=function()return true end,
        DoTaskInTime=function(self,delay,fn)pending[#pending+1]=fn;return {}end}
    local function child()
        local obj={valid=true,callbacks={},Transform={SetPosition=function()end}}
        obj.IsValid=function(self)return self.valid end
        obj.ListenForEvent=function(self,event,fn)self.callbacks[#self.callbacks+1]=fn end
        obj.Leave=function(self)
            self.valid=false
            for _,fn in ipairs(self.callbacks)do fn(self)end
        end
        children[#children+1]=obj
        return obj
    end
    SpawnPrefab=function()return child()end
    for i=1,100 do
        for _,obj in ipairs(children)do if obj.valid then obj:Leave()end end
        while #pending>0 do local fn=table.remove(pending,1);fn(core)end
        born(core)
        check(#core.undertents>=6 and #core.undertents<=10,'bounded live eye reference list')
    end
    core.surfacetents={child(),child(),child()}
    -- Register callbacks on the new surface children through the same wrapper.
    born(core);remove(core)
    check(#core.surfacetents==0,'remove loop visits every child without mutation skips')

    local respawn=assert(Guard.Find(Prefabs.um_ocupus_eyetacle.fn,'SpawnNewEyeTentacle')).value
    local boat={IsValid=function()return true end}
    core.boatvictim=boat;core.um_ocupus_epoch2hm=5
    local replacements=0
    core.AddOcupusEyeTentacle=function()replacements=replacements+1 end
    SpawnPrefab=function()return {Transform={SetPosition=function()end,SetScale=function()end}}end
    local limb={core=core,boatvictim=boat,Transform={GetWorldPosition=function()return 0,0,0 end},Remove=function()end}
    pending={};respawn(limb);core.um_ocupus_epoch2hm=6
    for _,fn in ipairs(pending)do fn(core)end
    check(replacements==0,'old battle cannot respawn into a new battle with same boat')
end

if optional then
    -- Weather respects original density mode, with no exponential accumulation.
    local savedenv=env;local weather_hook
    env={AddComponentPostInit=function(name,fn)weather_hook=fn end}
    Ents={{prefab='snow',particles_per_tick=0},{prefab='rain',particles_per_tick=0}}
    original('postinit/components/weather.lua');env=savedenv
    TheWorld.state={iswinter=true};TheWorld.net={HasTag=function()return true end}
    local weather={OnUpdate=function()Ents[1].particles_per_tick=20 end}
    weather_hook(weather);apply('weather',weather)
    for i=1,300 do weather:OnUpdate(1/30)end
    check(Ents[1].particles_per_tick==20*density+1,'bounded configurable particle density')

    -- Deadline refresh keeps the original one-second exit, shared by storms.
    local now,starts,cancels=0,0,0
    GetTime=function()return now end
    TheWorld.Map={IsOceanAtPoint=function()return false end}
    TheSim.FindFirstEntityWithTag=function()end
    local target={Transform={GetWorldPosition=function()return 100,0,0 end},
        HasTag=function(self,tag)return tag=='um_windturbine'end,
        AddTag=function(self,tag)self.weather=true end,RemoveTag=function(self,tag)self.weather=nil end,
        DoTaskInTime=function(self,delay,fn)starts=starts+1;return {fn=fn,Cancel=function()cancels=cancels+1 end}end}
    TheSim.FindEntities=function()return {target}end
    local tick=assert(Guard.Find(Prefabs.um_tornado.fn,'TornadoTask')).value
    local oldrand=math.random;math.random=function()return .5 end
    local storm={startmoving=true,persists=false,Transform={GetWorldPosition=function()return 0,0,0 end}}
    for i=1,300 do now=i*.1;tick(storm)end
    math.random=oldrand
    check(starts==1 and cancels==0 and target.weather,'refresh never recreates pending timer')
    local expire=target.um_tornado_weathertask.fn
    now=30.5;expire(target);check(target.weather and starts==2,'early expiry reschedules to latest deadline')
    now=31.01;expire(target);check(not target.weather and target.um_tornado_weathertask==nil,'weather clears one second after last sighting')
end
'''

results = []
for branch, uid in [("stable", "2039181790"), ("beta", "3193922031")]:
    for optional, density in [(True, 4), (False, 10), (True, 10)]:
        lua = runtime()
        g = lua.globals()
        g.beta, g.optional, g.density = branch == "beta", optional, density
        files = {p.relative_to(BASE / uid).as_posix(): p.read_text(encoding="utf-8-sig") for p in (BASE / uid).rglob("*.lua")}
        g.sources = lua.table_from(files)
        g.module_sources = lua.table_from({p.stem: p.read_text(encoding="utf-8") for p in (ROOT / "content/scripts").glob("um*2hm.lua")})
        lua.execute(SETUP)
        lua.execute(CASES)
        row = {"branch": branch, "optional": optional, "density": density, "checks": g.totalchecks()}
        results.append(row)
        print(json.dumps(row), flush=True)

(ROOT / "development/validation/um-performance-unit-20261110.json").write_text(
    json.dumps({"passed": True, "cases": results, "checks": sum(r["checks"] for r in results)}, indent=2), encoding="utf-8")
