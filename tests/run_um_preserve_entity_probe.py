"""Observe original UM callbacks with bounded stubs; do not modify production code."""
from pathlib import Path
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

UM = ROOT / "work/um-memory-beta-frozen"
OUT = ROOT / "development/validation/um-preserve-entity-performance-20261110.json"
lua = LuaRuntime(unpack_returned_tuples=True, max_memory=64 * 1024 * 1024)
g = lua.globals()
paths = {
    "thicket": "init/init_weather/init_thicket.lua",
    "eyes": "scripts/prefabs/um_ocupus_eyetacle.lua",
    "core": "scripts/prefabs/um_ocupus.lua",
    "fern": "scripts/prefabs/hooded_fern.lua",
}
sources = {key: (UM / path).read_text(encoding="utf-8-sig") for key, path in paths.items()}
for key, source in sources.items():
    g[key + "_source"] = source

lua.execute(r'''
PI = math.pi
Asset = function() return {} end
Prefab = function(name, fn) return {name=name, fn=fn} end
SetSharedLootTable = function() end
require = function() return {} end
local function load(source, name)
    return assert(loadstring(source, '@'..name))()
end
local function find(fn, name, seen)
    seen = seen or {}
    if seen[fn] then return end
    seen[fn] = true
    for i=1,100 do
        local key, value = debug.getupvalue(fn, i)
        if not key then break end
        if key == name then return value end
        if type(value) == 'function' then
            local found = find(value, name, seen)
            if found then return found end
        end
    end
end
local function alive(tasks)
    local n=0
    for _, task in ipairs(tasks) do if not task.cancelled then n=n+1 end end
    return n
end

-- Original long-range observation callback. The native scheduler is replaced
-- by cancellable handles so the test measures registrations, not server speed.
local eyes = load(eyes_source, 'um_ocupus_eyetacle.lua')
local watch = assert(find(eyes.fn, 'CheckForVictimsLong'))
local tasks = {}
local distance = 0
local boat = {IsValid=function() return true end,
    GetDistanceSqToInst=function() return distance*distance end}
FindEntity = function() return boat end
local eye = {DoPeriodicTask=function(self, interval, callback)
    local task={interval=interval, callback=callback}
    task.Cancel=function(self) self.cancelled=true end
    tasks[#tasks+1]=task
    return task
end}
for i=1,100 do watch(eye) end
watchers_before = alive(tasks)
distance=30
for _,task in ipairs(tasks) do
    if not task.cancelled then task.callback(eye) end
end
watchers_after_target_leaves = alive(tasks)
watcher_reference_cleared = eye.droptask == nil
assert(watchers_before == 100 and watchers_after_target_leaves == 99)
assert(watcher_reference_cleared)

-- Original eye hide callback: stop both timers and inspect their stored handles.
local _, submerged = load(eyes_source, 'um_ocupus_eyetacle.lua')
local hide = assert(find(submerged.fn, 'Hide'))
local submerged_eye={components={locomotor={Stop=function()end}},
    AnimState={PlayAnimation=function()end,PushAnimation=function()end},
    Light={Enable=function()end},grabtask={Cancel=function(self)self.cancelled=true end},
    movin={Cancel=function(self)self.cancelled=true end}}
hide(submerged_eye)
cancelled_movement_reference_remains = submerged_eye.movin ~= nil and submerged_eye.movin.cancelled
assert(cancelled_movement_reference_remains)

-- Repeated successful birth cycles after prior eyes have departed. The stub
-- explicitly invalidates old eyes: list retention does not imply live entities.
local core = load(core_source, 'um_ocupus.lua')
local born = assert(find(core.fn, 'Born'))
local children={}
TheSim={FindEntities=function()return {}end}
TheWorld={Map={IsVisualGroundAtPoint=function()return false end}}
SpawnPrefab=function(name)
    local child={valid=true,Transform={SetPosition=function()end}}
    child.IsValid=function(self)return self.valid end
    children[#children+1]=child
    return child
end
local controller={Transform={GetWorldPosition=function()return 0,0,0 end},
    IsValid=function()return true end}
math.randomseed(20261110)
local last_births=0
for cycle=1,100 do
    for _,child in ipairs(children)do child.valid=false end
    local before=#children
    born(controller)
    last_births=#children-before
end
stored_eye_references=#controller.undertents
live_eyes=0
for _,child in ipairs(controller.undertents)do
    if child:IsValid()then live_eyes=live_eyes+1 end
end
assert(stored_eye_references >= 600 and stored_eye_references <= 1000)
assert(live_eyes == last_births and live_eyes <= 10)

-- Original fern pathfinder callbacks, measuring only API calls.
local fern=load(fern_source,'hooded_fern.lua')
local register=assert(find(fern.fn,'RegisterPathFinding'))
local unregister=assert(find(fern.fn,'UnregisterPathFinding'))
local added,removed=0,0
TheWorld.Pathfinder={AddWall=function()added=added+1 end,
    RemoveWall=function()removed=removed+1 end}
local plant={GetPosition=function()return {x=0,z=0}end}
register(plant)
unregister(plant)
unregister(plant)
fern_wall_add_calls,fern_wall_remove_calls=added,removed
assert(added==16 and removed==32)

-- Load original global locomotor wrapper; queries return an eligible fern.
-- Six actors get identical update counts; only one can trigger fern behavior.
GLOBAL=_G
local component_init
env={AddComponentPostInit=function(name,fn)
    assert(name=='locomotor');component_init=fn
end}
JoinArrays=function(a,b)
    local result={}
    for _,v in ipairs(a)do result[#result+1]=v end
    for _,v in ipairs(b)do result[#result+1]=v end
    return result
end
UMCommonFns={GHOSTLIKE_TAGS={'ghost','playerghost','shadow','shadowcreature',
    'nightmarecreature','shadowminion','shadowthrall','shadowchesspiece','brightmare','brightmareboss'}}
load(thicket_source,'init_thicket.lua')
local queries,triggers,base_updates=0,0,0
TheSim.FindEntities=function()
    queries=queries+1
    return {{prefab='hooded_fern',um_thicketnear=function()triggers=triggers+1 end}}
end
for _,kind in ipairs({'living','dead','no_health','bird','smallcreature','shadow'})do
    local actor={Transform={GetWorldPosition=function()return 0,0,0 end},components={}}
    if kind~='no_health' then actor.components.health={IsDead=function()return kind=='dead'end}end
    actor.HasAnyTag=function(self,tags)
        for _,tag in ipairs(tags)do if tag==kind then return true end end
        return false
    end
    local locomotor={inst=actor,OnUpdate=function()base_updates=base_updates+1 end}
    component_init(locomotor)
    for i=1,100 do locomotor:OnUpdate(1/30,false)end
end
thicket_queries,thicket_triggers,original_updates=queries,triggers,base_updates
assert(queries==600 and triggers==100 and base_updates==600)
''')

keys = ["watchers_before", "watchers_after_target_leaves", "watcher_reference_cleared",
        "cancelled_movement_reference_remains", "stored_eye_references", "live_eyes",
        "fern_wall_add_calls", "fern_wall_remove_calls", "thicket_queries", "thicket_triggers", "original_updates"]
report = {
    "method": "Original frozen UM 6.0.3.9 Lua51 callbacks with stubbed engine/scheduler; not native server timing or affected-save reproduction.",
    "production_fixes_applied": False,
    "workshop_adjust_enabled": False,
    "source_hashes": {path: hashlib.sha256((UM / path).read_bytes()).hexdigest() for path in paths.values()},
    "observations": {key: g[key] for key in keys},
    "limits": [
        "Repeated long-range checks use one constant nearby boat and 100 direct callback invocations; real scheduling and entity lifetimes limit impact.",
        "Birth cycles invalidate prior eye stubs; retained references are not proof of growing live entity counts.",
        "Thicket actors and fern responses are synthetic; query counts are not CPU savings or FPS measurements.",
        "Two unregister calls demonstrate non-idempotence; actual callback ordering and pathfinder semantics need native coverage before a fix.",
    ],
}
OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(report["observations"], ensure_ascii=False, indent=2))
