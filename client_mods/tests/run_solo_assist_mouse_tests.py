"""Mouse intent lifecycle and native pathfinder integration regression."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().source = (ROOT / "client_mods/vanilla_solo_assist/scripts/soloassist2hm.lua").read_text(encoding="utf-8")
lua.execute(r'''
local checks=0
local function check(value,msg)checks=checks+1;assert(value,msg)end
hash=function(x)return x end
FRAMES=1/30
KEY_F6,KEY_F7=6,7
CONTROL_MOVE_RIGHT,CONTROL_MOVE_LEFT,CONTROL_MOVE_UP,CONTROL_MOVE_DOWN=1,2,3,4
CONTROL_SECONDARY,CONTROL_CANCEL,CONTROL_ACTION,CONTROL_ATTACK,CONTROL_INSPECT=5,6,7,8,9
TUNING={CONTROLLER_DEADZONE_RADIUS=.2}
ACTIONS={WALKTO={},PICK={},MAPDELIVER_MAP={code=99}}
RPC={SetMovementPredictionEnabled=1,PredictWalking=2,InspectButton=3,StopWalking=4}
Vector3=function(x,y,z)return {x=x,y=y,z=z}end
local time,x,z,focus,busy,keys,packets,killed,searches=0,0,0,false,false,{},{},0,0
local pulse,cleanup
GetTime=function()return time end
local hud={HasInputFocus=function()return focus end}
TheFrontEnd={GetActiveScreen=function()return hud end}
local blocked,status=false,0
local finder={
 IsClear=function(_,ax,ay,az,bx,by,bz)return not blocked or bz~=0 end,
 SubmitSearch=function()searches=searches+1;return searches end,
 KillSearch=function()killed=killed+1 end,
 GetSearchStatus=function()return status end,
 GetSearchResult=function()return {steps={{x=0,z=0},{x=0,z=2},{x=6,z=2},{x=6,z=0}}}end,
}
TheWorld={ismastersim=false,Pathfinder=finder,Map={
 IsPassableAtPoint=function()return true end,IsOceanAtPoint=function()return false end,
 IsPointNearHole=function()return false end}}
local mousepoint={x=6,z=0}
local releases={}
TheInput={
 AddKeyDownHandler=function(_,k,fn)keys[k]=fn;return {Remove=function()end}end,
 AddKeyUpHandler=function(_,k,fn)releases[k]=fn;return {Remove=function()end}end,
 GetAnalogControlValue=function()return 0 end,
 GetWorldPosition=function()return mousepoint end,
}
-- A non-networked notice stub; network/chat APIs deliberately absent.
TALKINGFONT="font"
CreateEntity=function()
 local noop=function()end
 return {IsValid=function()return true end,Remove=noop,AddTag=noop,
 entity={AddTransform=noop,AddLabel=noop,SetParent=noop},Transform={SetPosition=noop},
 Label={SetFont=noop,SetFontSize=noop,SetWorldOffset=noop,SetColour=noop,SetText=noop,Enable=noop}}
end
local original_calls=0
local original_action=function()original_calls=original_calls+1;return "native result" end
local original_control=function()return "native control" end
local pc={DoAction=original_action,OnControl=original_control,IsBusy=function()return busy end}
local p={components={playercontroller=pc},HUD=hud,entity={},
 IsValid=function()return true end,HasTag=function(_,tag)return tag=="busy" and busy end,
 GetCurrentPlatform=function()return nil end,
 Transform={GetWorldPosition=function()return x,0,z end},
 DoPeriodicTask=function(_,_,fn)pulse=fn;return {Cancel=function()end}end,
 DoStaticTaskInTime=function()return {Cancel=function()end}end,
 ListenForEvent=function(_,_,fn)cleanup=fn end}
ThePlayer=p
SendRPCToServer=function(code,a,b)
 packets[#packets+1]={code,a,b}
 if code==RPC.PredictWalking then x,z=a,b end
end
local M=assert(loadstring(source))()
local keyboard
M.Attach(p,{direction=function()return keyboard end})
local state=p._soloassist2hm
local function speedkey()keys[KEY_F6]();releases[KEY_F6]()end
local function setmode(mode)
 for i=1,4 do if state.mode==mode then return end;speedkey()end
 assert(state.mode==mode)
end
local function frames(n)for i=1,n do time=time+FRAMES;pulse()end end
local function click(tx,tz,kind,target)
 local act={action=kind or ACTIONS.WALKTO,target=target,GetActionPoint=function()return {x=tx,z=tz}end}
 check(pc:DoAction(act)=="native result","preserve native DoAction result")
end
click(6,0);check(not state.mouse,"disabled click stays native")
setmode(1)
click(6,0);check(state.mouse and state.mouse.x==6,"capture native WALKTO destination")
local destination=state.mouse
speedkey();check(state.mode==2 and state.mouse==destination,"gentle to accelerated preserves active mouse destination")
speedkey();check(state.mode==3 and state.mouse==destination,"accelerated to turbo preserves active mouse destination")
frames(40)
check(x>5.6 and x<=6 and math.abs(z)<.01,"accelerate to target without overshooting")
check(not state.mouse,"arrival clears intent")
local stops=0
for _,packet in ipairs(packets)do if packet[1]==RPC.StopWalking then stops=stops+1 end end
check(stops==1,"arrival explicitly stops server movement once")
local count=#packets;frames(5);check(#packets==count,"arrival stops extra requests")
x,z=0,0;click(6,0);click(0,0,ACTIONS.PICK,{})
check(not state.mouse,"interaction cancels previous destination")
click(6,0);check(pc:OnControl(CONTROL_ATTACK,true)=="native control","preserve native control result")
check(not state.mouse,"attack control cancels destination")
click(6,0);pc:OnControl(CONTROL_SECONDARY,true)
check(not state.mouse,"right click cancels destination")
click(6,0);focus=true;frames(1);focus=false
check(not state.mouse,"opening menu clears intent")
click(6,0);busy=true;frames(1);busy=false
check(not state.mouse,"busy state cancels old mouse movement")
click(6,0);pc.draggingonground=true;mousepoint={x=0,z=6};frames(1)
check(state.mouse and state.mouse.z==6,"held ground drag updates target")
pc.draggingonground=false;frames(1)
check(not state.mouse,"release drag stops acceleration")
x,z=0,0;blocked=true;click(6,0);frames(1)
check(searches==1 and state.mouse.handle,"blocked line uses native path search")
local before=#packets;frames(2)
check(#packets==before,"pending path does not accelerate straight through obstacle")
status=1;frames(5)
check(z>1.4 and x<6,"follow native route waypoint around obstacle")
check(killed==1,"completed native search released")
click(6,0);frames(1)
local kills=killed
click(0,0,ACTIONS.PICK,{})
check(killed==kills+1,"cancel releases pending native search")
blocked=false;x,z=0,0
click(6,0);keyboard={x=1,z=0,LengthSq=function()return 1 end};frames(6)
check(not state.mouse and x>0,"keyboard takes over without losing existing acceleration")
keyboard=nil
click(6,0);speedkey()
check(not state.enabled and not state.mouse,"F6 off clears mouse destination")
before=#packets;frames(5)
check(#packets==before,"disabled mouse intent never resumes")
setmode(3);x,z=0,0
local stopped,cleared=0,0
p.components.locomotor={GetRunSpeed=function()return 6 end,
 Stop=function()stopped=stopped+1 end,Clear=function()cleared=cleared+1 end}
click(1,0);frames(15)
check(stopped==1 and cleared==1,"arrival clears native predicted movement as well")
cleanup()
check(pc.DoAction==original_action and pc.OnControl==original_control,"cleanup restores controller hooks")
check(original_calls>=10,"all actions forwarded to native controller")
print("SOLO_ASSIST_MOUSE checks="..checks.." failures=0")
''')
