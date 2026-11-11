"""Count original weather callbacks in both UM branches without product patches."""
from pathlib import Path
from zipfile import ZipFile
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

sources = {
    "stable": ROOT / "work/um-weather-stable-frozen",
    "beta": ROOT / "work/um-memory-beta-frozen",
}
paths = {
    "watcher": "scripts/components/snowstormwatcher.lua",
    "spawner": "scripts/components/um_snow_stormspawner.lua",
    "pile": "scripts/prefabs/snowpile.lua",
    "manager": "scripts/components/um_snowstormmanager.lua",
    "tornado": "scripts/prefabs/um_tornado.lua",
    "weather": "postinit/components/weather.lua",
}
with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as z:
    class_source = z.read("scripts/class.lua").decode("utf-8-sig")

rows = {}
for branch, source in sources.items():
    lua = LuaRuntime(unpack_returned_tuples=True, max_memory=64 * 1024 * 1024)
    lua.execute(class_source)
    g = lua.globals()
    hashes = {}
    for key, path in paths.items():
        file = source / path
        g[key + "_source"] = file.read_text(encoding="utf-8-sig") if file.exists() else None
        if file.exists():
            hashes[path] = hashlib.sha256(file.read_bytes()).hexdigest()
    lua.execute(r'''
local function load(source, name)return assert(loadstring(source,'@'..name))()end
local function find(fn,name,seen)
    seen=seen or {};if seen[fn]then return end;seen[fn]=true
    for i=1,100 do
        local key,value=debug.getupvalue(fn,i);if not key then break end
        if key==name then return value end
        if type(value)=='function'then local f=find(value,name,seen);if f then return f end end
    end
end
Asset=function()return {}end
Prefab=function(name,fn)return {name=name,fn=fn}end
require=function()return {}end
PI=math.pi;RADIANS=math.pi/180
GROUND={SCALE=999};TUNING={TOTAL_DAY_TIME=480,DSTU={STORMS_PERFORMANCE='off'}}
UM_CONFIG={UM_STORMS_PERFORMANCE='off'}
table.invert=function(a)local r={}for _,v in ipairs(a)do r[v]=true end return r end
EQUIPSLOTS={BODY='body'}
local queries,speed_sets,vision_events=0,0,0
TheSim={FindEntities=function()queries=queries+1;return {}end}
TheWorld={ismastersim=true,state={iswinter=true},components={},
    HasTag=function()return true end,net={HasTag=function()return true end}}
IsUnderRainDomeAtXZ=function()return false end
local actor={Transform={GetWorldPosition=function()return 0,0,0 end},
    ListenForEvent=function()end,StartUpdatingComponent=function()end,
    HasTag=function()return false end,PushEvent=function()vision_events=vision_events+1 end,
    DoTaskInTime=function()return {Cancel=function()end}end,
    components={playervision={HasGoggleVision=function()return false end,HasGhostVision=function()return false end},
        rider={IsRiding=function()return false end},inventory={GetEquippedItem=function()end},
        locomotor={SetExternalSpeedMultiplier=function()speed_sets=speed_sets+1 end}}}
local Watcher=load(watcher_source,'snowstormwatcher.lua')
local watcher=Watcher(actor)
for i=1,300 do watcher:OnUpdate(1/30)end
watcher_queries_300_updates=queries
watcher_speed_writes_300_updates=speed_sets
watcher_vision_events_300_updates=vision_events
assert(speed_sets==600)
assert(queries==600 or queries==2400)

-- Exercise the actually installed spawner component outside winter. No timer
-- callbacks run; count redundant stop/start API operations per update.
local starts,stops,resumes,removes=0,0,0,0
local timers={}
local timer={AddTimer=function()end,
    GetTimeLeft=function(self,key)return timers[key]end,
    StartTimer=function(self,key,time)starts=starts+1;timers[key]=time end,
    StopTimer=function(self,key)stops=stops+1;timers[key]=nil end,
    ResumeTimer=function()resumes=resumes+1 end}
TheWorld.state={iswinter=false,issnowing=false,season='spring'}
TheWorld.components.worldsettingstimer=timer
TheWorld.HasTag=function()return false end
TheWorld.RemoveTag=function()removes=removes+1 end
TheWorld.net.RemoveTag=function()removes=removes+1 end
AllPlayers={}
local Spawner=load(spawner_source,'um_snow_stormspawner.lua')
Spawner.WatchWorldState=function()end
local spawner=Spawner({StartUpdatingComponent=function()end})
for i=1,300 do spawner:OnUpdate(1/30)end
outside_winter_timer_starts=starts
outside_winter_timer_stops=stops
outside_winter_timer_resumes=resumes
outside_winter_tag_removes=removes
assert(starts==300 and resumes==300 and removes==600)

-- Original season handler: immediate removal vs a half-second burst of tasks.
local pile=load(pile_source,'snowpile.lua')
local season=assert(find(pile.fn,'OnSeasonChange'))
local removed,queued,maxdelay=0,0,0
math.randomseed(20261110)
for i=1,1000 do
    local entity={Remove=function()removed=removed+1 end,
        DoTaskInTime=function(self,delay,fn)
            queued=queued+1;maxdelay=math.max(maxdelay,delay);return {}
        end}
    season(entity)
end
season_immediate_removes=removed;season_queued_removes=queued;season_max_delay=maxdelay
assert(removed+queued==1000 and maxdelay<=.5)

-- Count registry traversal directly, including every original pairs iteration.
registry_copy_entries=0
if manager_source then
    local Manager=load(manager_source,'um_snowstormmanager.lua')
    local manager=Manager({})
    for i=1,1000 do manager.snowpiles[i]={}end
    local original_pairs=pairs
    pairs=function(t)
        local iterator,state,key=original_pairs(t)
        return function(s,k)
            local nextkey,value=iterator(s,k)
            if nextkey~=nil then registry_copy_entries=registry_copy_entries+1 end
            return nextkey,value
        end,state,key
    end
    for i=1,1000 do manager:UnregisterSnowpile({GUID=i})end
    pairs=original_pairs
    assert(registry_copy_entries==499500)
end

-- Client weather wrapper with original engine's per-update reset contract.
-- This checks amplification, not actual rendering or the full weather engine.
GLOBAL=_G
local postinit
env={AddComponentPostInit=function(name,fn)postinit=fn end}
local snow,rain={particles_per_tick=0},{particles_per_tick=0,splashes_per_tick=0}
Ents={{prefab='snow',particles_per_tick=0}, {prefab='rain',particles_per_tick=0,splashes_per_tick=0}}
snow,rain=Ents[1],Ents[2]
TheNet={IsDedicated=function()return false end}
require=function()return {GetUpvalue=function()return function()return 1 end end}end
local global_queries=0
TheSim.FindFirstEntityWithTag=function()global_queries=global_queries+1 end
TheWorld.state={iswinter=true}
TheWorld.net.HasTag=function()return true end
load(weather_source,'weather.lua')
local weather={OnUpdate=function()snow.particles_per_tick=20 end}
postinit(weather)
for i=1,300 do weather:OnUpdate(1/30)end
snow_particles_per_tick_at_full_precip=snow.particles_per_tick
weather_global_queries_300_updates=global_queries
assert(snow.particles_per_tick==201 and global_queries==300)

-- One wind turbine inside the storm radius: count the original refresh-task
-- churn without exercising player pulling, damage or random lightning.
require=function()return {}end
local tornado=load(tornado_source,'um_tornado.lua')
local movement=assert(find(tornado.fn,'TornadoTask'))
local task_starts,task_cancels,nearby_queries=0,0,0
local turbine={Transform={GetWorldPosition=function()return 100,0,0 end},
    HasTag=function(self,tag)return tag=='um_windturbine'end,AddTag=function()end,
    DoTaskInTime=function()
        task_starts=task_starts+1
        return {Cancel=function()task_cancels=task_cancels+1 end}
    end}
TheSim.FindEntities=function()nearby_queries=nearby_queries+1;return {turbine}end
TheSim.FindFirstEntityWithTag=function()end
TheWorld.Map={IsOceanAtPoint=function()return false end}
local storm={startmoving=true,persists=false,
    Transform={GetWorldPosition=function()return 0,0,0 end}}
local original_random=math.random
math.random=function()return .5 end
for i=1,300 do movement(storm)end
math.random=original_random
tornado_nearby_queries_300_ticks=nearby_queries
tornado_refresh_tasks_300_ticks=task_starts
tornado_refresh_cancels_300_ticks=task_cancels
assert(nearby_queries==300 and task_starts==300 and task_cancels==299)
''')
    keys = ["watcher_queries_300_updates", "watcher_speed_writes_300_updates", "watcher_vision_events_300_updates",
            "outside_winter_timer_starts", "outside_winter_timer_stops", "outside_winter_timer_resumes", "outside_winter_tag_removes",
            "season_immediate_removes", "season_queued_removes", "season_max_delay", "registry_copy_entries",
            "snow_particles_per_tick_at_full_precip", "weather_global_queries_300_updates",
            "tornado_nearby_queries_300_ticks", "tornado_refresh_tasks_300_ticks", "tornado_refresh_cancels_300_ticks"]
    rows[branch] = {"source": str(source), "source_hashes": hashes, "observations": {key: g[key] for key in keys}}

report = {
    "method": "Original Lua51 component/callback execution with stubbed world, scheduler and entity APIs; operation counts only, no native server or rendered client benchmark.",
    "production_fixes_applied": False,
    "versions": {"stable": "1.5.4.6", "beta": "6.0.3.9"},
    "results": rows,
    "limits": [
        "300 weather/watcher updates are direct calls (10 seconds at an assumed 30 updates/s); 300 tornado ticks represent its 0.1-second schedule (30 seconds). Neither is wall-clock timing.",
        "1000 snowpiles and registry entries are synthetic workloads; native remove cost and affected-save density are not measured.",
        "The stable branch has no um_snowstormmanager, um_ocupus or global thicket locomotor hook from the tested beta.",
        "The native weather OnUpdate normally resets snow particles each update; 10x+1 is amplification, not evidence of exponential accumulation.",
        "The user confirmed snowball rain means dense blizzard particles; no independent physical projectile rain is being claimed.",
    ],
}
out = ROOT / "development/validation/um-weather-performance-20261110.json"
out.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps({key: value["observations"] for key, value in rows.items()}, ensure_ascii=False, indent=2))
