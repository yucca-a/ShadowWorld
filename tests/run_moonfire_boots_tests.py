"""Native slipperyfeet + UM callbacks, and actual server/client sword action guards."""
from pathlib import Path
from zipfile import ZipFile
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as z:
    native = {name: z.read("scripts/" + name + ".lua").decode("utf-8-sig") for name in
              ["class", "util/sourcemodifierlist", "components/slipperyfeet"]}
helper = (ROOT / "content/scripts/bootlegnonslip2hm.lua").read_text(encoding="utf-8-sig")
for version, uid in [("native", None), ("stable", "2039181790"), ("beta", "3193922031")]:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(native["class"])
    g = lua.globals()
    g.modifiers_source, g.slip_source, g.helper_source = native["util/sourcemodifierlist"], native["components/slipperyfeet"], helper
    g.um_source = Path(f"D:/SteamLibrary/steamapps/workshop/content/322330/{uid}/postinit/components/slipperyfeet.lua").read_text(encoding="utf-8-sig") if uid else ""
    g.variant = version
    lua.execute(r'''
GLOBAL = _G
TUNING = {WILSON_RUN_SPEED = 6}
FRAMES = 1/30
WORLD_TILES = {UM_FLOODWATER = 10}
local checks, mapreads = 0, 0
local function check(ok, why) checks=checks+1; assert(ok, why) end
local modifiers = assert(loadstring(modifiers_source))()
function require(name) assert(name == "util/sourcemodifierlist"); return modifiers end
TheWorld = {Map = {IsOceanIceAtPoint = function(x,y,z) assert(x and y and z); mapreads=mapreads+1; return false end,
    GetTileAtPoint = function(x,y,z) assert(x and y and z); mapreads=mapreads+1; return 0 end}}
local Native = assert(loadstring(slip_source))()
local M = assert(loadstring(helper_source))()
local um
env = {AddComponentPostInit = function(name, fn) assert(name == "slipperyfeet"); um=fn end}
if #um_source > 0 then assert(loadstring(um_source))() end
local function actor()
    local a = {valid=true, components={}, events={}, tasks={}, slipped=0}
    function a:IsValid() return self.valid end
    function a:HasTag(tag) return tag == "player" end
    function a:AddComponent() error("protection must never add components") end
    function a:RemoveComponent() error("protection must never remove components") end
    function a:DoTaskInTime(delay, fn, ...)
        local t = {fn=fn, Cancel=function(self) self.cancelled=true; self.fn=nil end}
        self.tasks[#self.tasks+1]=t; return t
    end
    function a:ListenForEvent(event, fn) self.events[event]=fn end
    function a:RemoveEventCallback(event) self.events[event]=nil end
    function a:StartUpdatingComponent() end
    function a:StopUpdatingComponent() end
    function a:PushEvent(event) if event == "feetslipped" then self.slipped=self.slipped+1 end end
    a.Transform={GetWorldPosition=function() assert(a.valid, "retired position access");return 0,0,0 end}
    a.sg={HasAnyStateTag=function()return false end, HasStateTag=function()return false end}
    local s = Native(a);a.components.slipperyfeet=s
    if um then um(s) end
    M.Install(s)
    return a,s
end
local a,s=actor()
local function item()
    local e={owner=a,components={},IsValid=function()return true end}
    e.components.inventoryitem={GetGrandOwner=function()return e.owner end}
    return e
end
local first,second=item(),item()
M.Update(first);M.Update(second)
check(#a.bootlegs2hm==2 and a.components.slipperyfeet==s,"all boots track without component churn")
s:DoDelta(100);s:SetCurrent(100)
check(s.slippiness==0 and a.slipped==0,"native slip threshold suppressed")
first.owner=nil;M.Update(first);s:DoDelta(3)
check(s.slippiness==0 and #a.bootlegs2hm==1,"second source keeps protection")
second.owner=nil;M.Update(second);s:DoDelta(1)
check(s.slippiness==1 and not a.bootlegs2hm,"normal native slipping restored after final source")
first.owner=a;M.Update(first)
check(s.slippiness==0,"pickup clears accumulated slipping")
M.Remove(first);M.Remove(first)
check(not a.bootlegs2hm,"removal is idempotent")
local queued={}
for _,field in ipairs({"inittask","inittask2"}) do if s[field] then queued[#queued+1]=s[field].fn end end
s:OnRemoveEntity();a.valid=false
local before=mapreads
for _,fn in ipairs(queued) do fn(a) end
check(mapreads==before and not s.inittask and not s.inittask2 and not s.checknearbyentitytask,"retired callbacks never touch map; tasks cleaned")
local b,old=actor();local stale=old.inittask.fn
b.components.slipperyfeet={}
stale(b)
check(mapreads==before,"old callback cannot initialize replacement component")
b.components.slipperyfeet=old
old.OnInit(b)
check(mapreads>before,"active native initializer still checks ice")
old:OnRemoveFromEntity()
check(not old.inittask and not old.inittask2 and not old.checknearbyentitytask,"component cleanup cancels rescheduled nearby checks")
first.oldowner2hm=a;a.bootlegs2hm={first};M.Remove(first)
check(not a.bootlegs2hm,"departing owner cleanup schedules nothing")
print(variant .. " slipperyfeet: " .. checks .. " checks passed")
''')

lua = LuaRuntime(unpack_returned_tuples=True)
source = (ROOT / "content/epic/sword_lunarplant_moonfire2hm.lua").read_text(encoding="utf-8-sig")
g = lua.globals()
g.helpers = source[:source.index("local function FindEnemies2hm")]
g.routes = source[source.index('AddStategraphPostInit("wilson"'):source.index("local function SwordActFn2hm")]
lua.execute(r'''
local checks=0
local function check(ok,msg) checks=checks+1; assert(ok,msg) end
ACTIONS={CASTSPELL={},ATTACK={}};EQUIPSLOTS={HANDS="hands"}
function hash(x)return x end
local graphs={}
function AddStategraphPostInit(name,fn) graphs[name]=graphs[name] or {};table.insert(graphs[name],fn) end
local install=assert(loadstring(helpers..routes))
install()
for _,name in ipairs({"wilson","wilson_client"}) do
    local played=0
    local graph={actionhandlers={[ACTIONS.CASTSPELL]={deststate=function()return "fallback" end},[ACTIONS.ATTACK]={deststate=function()return "attack" end}},
        states={combat_leap_start={server_states={},onenter=function()played=played+1 end}}}
    for _,fn in ipairs(graphs[name])do fn(graph)end
    for _,ready in ipairs({false,true})do
        local sword={prefab="sword_lunarplant",components={},IsValid=function()return true end,HasTag=function(_,tag)return tag=="swordleap2hm"end,
            _moonfire_ready2hm={value=function()return ready end}}
        if name=="wilson"then sword.components.rechargeable={IsCharged=function()return ready end}end
        local inv={GetEquippedItem=function()return sword end}
        local action={action=ACTIONS.CASTSPELL,invobject=sword}
        local p={components={inventory=inv},replica={inventory=inv},sg={currentstate={name="combat_leap_start"}},
            GetBufferedAction=function()return action end,ClearBufferedAction=function(self)self.cleared=true end}
        p.sg.GoToState=function(self,state)self.currentstate.name=state end
        check((graph.actionhandlers[ACTIONS.CASTSPELL].deststate(p,action)=="combat_leap_start")==ready,name.." readiness before wind-up")
        local before=played;graph.states.combat_leap_start.onenter(p)
        check(played-before==(ready and 1 or 0),name.." no cooldown anticipation animation")
        check(ready or p.cleared and p.sg.currentstate.name=="idle",name.." queued cast recovers idle")
        action.action=ACTIONS.ATTACK;p.sg.currentstate.name="combat_leap_start"
        graph.states.combat_leap_start.onenter(p)
        check(played-before==(ready and 2 or 1),name.." ordinary attacks keep anticipation")
    end
end
print("Moonfire action guards: "..checks.." checks passed")
''')
for file in ["epic/sword_lunarplant_moonfire2hm.lua", "scripts/bootlegnonslip2hm.lua", "common/patch.lua", "scripts/prefabs/bootleg2hm.lua", "scripts/prefabs/bootleg_2hm.lua", "epic/alterguardian.lua"]:
    lua.execute("assert(loadstring(...))", (ROOT / "content" / file).read_text(encoding="utf-8-sig"))
print("Six production files compile in Lua 5.1")
