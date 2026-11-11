"""Exercise guard hooks against installed DST action-correction and map methods."""
from pathlib import Path
from zipfile import ZipFile
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as archive:
    controller = archive.read("scripts/components/playercontroller.lua").decode("utf-8-sig")
    locomotor = archive.read("scripts/components/locomotor.lua").decode("utf-8-sig")

def method(text, signature):
    start = text.index(signature)
    return text[start:text.index("\nend", start) + 4]

assert 'self.inst.components.playercontroller:OnRemoteBufferedAction()' in method(locomotor, 'function LocoMotor:PushAction(')
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().native_snap = method(controller, "function PlayerController:OnRemoteBufferedAction(")
lua.globals().native_map = method(controller, "function PlayerController:OnMapAction(")
lua.globals().guard_source = (ROOT / "server_mods/tianxing_guard/scripts/tianxing_guard.lua").read_text(encoding="utf-8")
lua.execute(r'''
local checks=0
local function check(v,msg)checks=checks+1;assert(v,msg)end
local clock,x,z,busy=0,0,0,false
GetTime=function()return clock end
GetTick=function()return math.floor(clock/FRAMES+.01) end
RADIANS=180/math.pi
PREDICT_STOP_ERROR_DISTANCE_SQ=.25
FRAMES=1/30
Vector3=function(a,b,c)return {x=a,y=b,z=c,Get=function()return a,b,c end}end
ACTIONS={LOOKAT={instant=true},CHOP={},MAPDELIVER_MAP={code=99,map_only=true},OTHERMAP={code=100,map_only=true}}
ACTIONS_BY_ACTION_CODE={[99]=ACTIONS.MAPDELIVER_MAP,[100]=ACTIONS.OTHERMAP}
MOD_ACTIONS_BY_ACTION_CODE={another_mod={[99]=ACTIONS.OTHERMAP}}
PlayerController={}
assert(loadstring(native_snap))();assert(loadstring(native_map))()
local inst={userid="test-user",components={},sg={
 HasStateTag=function()return false end,HandleEvent=function()end},
 Transform={GetWorldPosition=function()return x,0,z end,SetPosition=function(_,a,_,c)x,z=a,c end}}
local queued=0
local pc={inst=inst,ismastersim=true,remote_vector={x=0,y=0,z=0},
 IsBusy=function()return busy end,
 GetRemotePredictPosition=function(self)
  local v=self.remote_vector
  if v.y>=3 then return {x=v.x,y=v.y,z=v.z,Get=function()return v.x,0,v.z end}end
 end,
 map={IsPassableAtPoint=function()return true end},
 OnRemoteBufferedAction=PlayerController.OnRemoteBufferedAction,
 OnMapAction=PlayerController.OnMapAction,
 GetMapActions=function(_,position,target,act)return {action=act,target=target}end,
}
local native_entry_y
local loco={inst=inst,ismastersim=true,GetRunSpeed=function()return 6 end,
 SetMoveDir=function()end,Stop=function()end,
 PushAction=function(self,action,...)
  if not action then return end
  native_entry_y=pc.remote_vector.y
  pc:OnRemoteBufferedAction() -- actual native PushAction entry contract, asserted above
  queued=queued+1
  return "native-return",action
 end}
pc.locomotor=loco;inst.components.playercontroller=pc;inst.components.locomotor=loco
local function predict(dx,kind)
 pc.remote_vector.x=x+dx;pc.remote_vector.y=3;pc.remote_vector.z=z
 return loco:PushAction({action=kind or ACTIONS.LOOKAT})
end
for i=1,8 do predict(.15)end
check(x>1,"native correction primitive reproduced before guard")
x=0;queued=0
local Guard=assert(loadstring(guard_source))()
Guard.AttachLocomotor(loco);Guard.AttachController(pc)
local hook=loco.PushAction;Guard.AttachLocomotor(loco)
check(loco.PushAction==hook,"locomotor hook idempotent")
hook=pc.OnMapAction;Guard.AttachController(pc)
check(pc.OnMapAction==hook,"controller hook idempotent")
for i=1,80 do predict(.15)end
check(x==0 and queued==80,"burst cannot accumulate distance while every inspect action still executes")
check(inst._tianxing_guard.inspect_corrections==80,"suppressed corrections counted without punishment")
local result,action=predict(.15)
check(result=="native-return" and action.action==ACTIONS.LOOKAT,"preserve action arguments and multiple return values")
predict(.15,ACTIONS.CHOP)
check(math.abs(x-.15)<.00001,"non-inspect action retains native correction")
pc.remote_vector.y=6;loco:PushAction({action=ACTIONS.LOOKAT})
check(native_entry_y==6,"hopping marker reaches native code unchanged")
pc.remote_vector.y=2;loco:PushAction({action=ACTIONS.LOOKAT})
check(native_entry_y==2,"drag walking marker reaches native code unchanged")
pc.handler={};predict(.15)
check(native_entry_y==3,"direct host inspection is not treated as remote movement")
pc.handler=nil
local before=queued;pc.remote_vector.y=0;loco:PushAction({action=ACTIONS.LOOKAT})
check(queued==before+1,"normal stationary inspect still executes")
inst.components.playercontroller=nil
loco:PushAction({action=ACTIONS.LOOKAT})
check(queued==before+2,"entities without controller retain original action dispatch")
inst.components.playercontroller=pc

local selftarget={IsValid=function()return true end,components={}}
local point=Vector3(0,0,0)
before=queued
pc:OnMapAction(99,point,selftarget)
check(queued==before,"forged self map delivery rejected before locomotor")
pc:OnMapAction(99,point,nil)
check(queued==before,"nil map target rejected")
local other={}
local owner=inst
local pending={IsValid=function()return true end,GetAction=function()return ACTIONS.MAPDELIVER_MAP end,
 IsDoer=function(_,p)return p==owner end}
local target={IsValid=function()return true end,components={mapdeliverable={bufferedmapaction=pending}}}
pc:OnMapAction(99,point,target)
check(queued==before+1,"authorized native delivery still dispatched")
owner=other;pc:OnMapAction(99,point,target)
check(queued==before+1,"another player's pending map action rejected")
owner=inst;busy=true;pc:OnMapAction(99,point,target)
check(queued==before+1,"controlled player cannot use a real target to recover")
busy=false;target.components.mapdeliverable.bufferedmapaction=nil
pc:OnMapAction(99,point,target)
check(queued==before+1,"delivery without native pending authorization rejected")
pc:OnMapAction(100,point,selftarget)
check(queued==before+2,"other vanilla map actions retain native behavior")
pc:OnMapAction(99,point,selftarget,"another_mod")
check(queued==before+3,"mod action namespace does not collide with vanilla code")
pc:OnMapAction(999,point,selftarget)
check(queued==before+3,"unknown map action retains native rejection")
local client={ismastersim=false,PushAction=function()end,OnMapAction=function()end}
local push,map=client.PushAction,client.OnMapAction
Guard.AttachLocomotor(client);Guard.AttachController(client)
check(client.PushAction==push and client.OnMapAction==map,"client methods untouched")
local reports={}
Guard.SetReporter(function(_,kind)reports[#reports+1]=kind end)
inst._tianxing_guard=nil
for tick=1,45 do clock=tick*FRAMES;predict(.15)end
check(#reports==0,"ordinary one-inspect-per-frame pattern does not trigger punishment")
for tick=46,65 do clock=tick*FRAMES;for i=1,3 do predict(.15)end end
check(#reports>0 and reports[1]=="speed","sustained multi-correction bursts trigger speed classification")
reports={};inst._tianxing_guard=nil
for i=1,3 do clock=clock+.8;pc:OnMapAction(99,point,selftarget)end
check(#reports==1 and reports[1]=="recover","repeated forged map actions trigger recovery classification")
print("TIANXING_GUARD_REGRESSION checks="..checks.." failures=0")
''')

meta = LuaRuntime(unpack_returned_tuples=True)
meta.globals().source = (ROOT / "server_mods/tianxing_guard/modinfo.lua").read_text(encoding="utf-8")
meta.execute('local env={};local f=assert(loadstring(source));setfenv(f,env);f();assert(env.server_only_mod and not env.client_only_mod and not env.all_clients_require_mod and env.api_version==10);assert(env.configuration_options[1].name=="auto_kick" and env.configuration_options[1].default==true)')
print("Server mod metadata passed in empty environment")

for configured in (True, False, None):
    wiring=LuaRuntime(unpack_returned_tuples=True)
    wiring.globals().configured=configured
    wiring.globals().source=(ROOT/"server_mods/tianxing_guard/modmain.lua").read_text(encoding="utf-8")
    wiring.execute(r'''
        local captured,hooks
        local report=function()end
        local guard={SetReporter=function(fn)assert(fn==report)end,AttachController=function()end,AttachLocomotor=function()end}
        local watch={New=function(options)captured=options;return {Report=report}end}
        GLOBAL=setmetatable({TheNet={Announce=function()end,Kick=function()end}},{__index=_G})
        require=function(name)if name=="tianxing_guard" then return guard else assert(name=="tianxing_guard_watch");return watch end end
        GetModConfigData=function(name)assert(name=="auto_kick");return configured end
        hooks=0
        AddComponentPostInit=function(name,fn)assert(name=="locomotor" or name=="playercontroller");assert(type(fn)=="function");hooks=hooks+1 end
        assert(loadstring(source))()
        assert(captured.auto_kick==(configured~=false) and hooks==2)
    ''')
print("Actual modmain configuration wiring: on, off, default passed")
