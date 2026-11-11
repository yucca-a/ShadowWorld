"""Input binding and automatic-control regression for the standalone client mod."""
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"work/test-python"))
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
source=(ROOT/"client_mods/vanilla_solo_assist/scripts/soloassist2hm.lua").read_text(encoding="utf-8")
lua.globals().module_source=source
lua.execute(r'''
local checks=0
local function check(ok,msg) checks=checks+1;assert(ok,msg) end
hash=function(s)return s end
KEY_F6,KEY_F7,KEY_F8,KEY_F9=6,7,8,9
FRAMES=1/30
ACTIONS={MAPDELIVER_MAP={code=99}}
RPC={DoActionOnMap=1}
Vector3=function(x,y,z)return {x=x,y=y,z=z}end
local now,requests,focus,current,legacy_frozen,removed=0,{},false,"idle",false,0
GetTime=function()return now end
TheWorld={ismastersim=false}
local hud={HasInputFocus=function()return focus end}
TheFrontEnd={GetActiveScreen=function()return hud end}
TheNet={} -- A toggle must not send chat/system messages.
local labels, timers={},{}
TALKINGFONT="talkingfont"
CreateEntity=function()
 local n={entity={},Transform={},Label={}}
 n.entity.AddTransform=function()end
 n.entity.AddLabel=function()end
 n.entity.SetParent=function(_,parent)n.parent=parent end
 n.Transform.SetPosition=function()end
 n.AddTag=function()end
 n.IsValid=function()return not n.removed end
 n.Remove=function()n.removed=true end
 for _,name in ipairs({"SetFont","SetFontSize","SetWorldOffset","SetColour"})do n.Label[name]=function()end end
 n.Label.SetText=function(_,text)n.text=text end
 n.Label.Enable=function(_,value)n.visible=value end
 labels[#labels+1]=n
 return n
end
local downs,ups={},{ }
local function handler(t,key,fn)
 t[key]=t[key] or {};local h={fn=fn}
 h.Remove=function(self)self.removed=true;removed=removed+1 end
 table.insert(t[key],h);return h
end
TheInput={AddKeyDownHandler=function(_,key,fn)return handler(downs,key,fn)end,
 AddKeyUpHandler=function(_,key,fn)return handler(ups,key,fn)end}
local cleanup,pulse
local p={HUD=hud,components={},entity={},sg={currentstate={name="idle"}},
 player_classified={currentstate={value=function()return current end}},
 AnimState={IsCurrentAnimation=function()return false end},
 IsValid=function()return true end,HasTag=function(_,tag)return tag=="frozen" and legacy_frozen end,
 Transform={GetWorldPosition=function()return 0,0,0 end},CanSeePointOnMiniMap=function()return true end,
 DoPeriodicTask=function(_,_,fn)pulse=fn;return {Cancel=function()pulse=nil end}end,
 DoStaticTaskInTime=function(_,delay,fn)
 local t={time=now+delay,fn=fn,Cancel=function(self)self.cancelled=true end};timers[#timers+1]=t;return t
 end,
 ListenForEvent=function(_,_,fn)cleanup=fn end}
ThePlayer=p
SendRPCToServer=function(...)requests[#requests+1]={time=now,args={...}}end
local M=assert(loadstring(module_source))()
local function down(k)for _,h in ipairs(downs[k] or {})do if not h.removed then h.fn()end end end
local function up(k)for _,h in ipairs(ups[k] or {})do if not h.removed then h.fn()end end end
local function key(k)down(k);up(k)end
local function frames(count)for i=1,count do
 now=now+FRAMES;pulse()
 for _,t in ipairs(timers)do if not t.cancelled and t.time<=now then t.cancelled=true;t.fn()end end
 end end
for _,s in ipairs({"frozen","thaw","knockout","yawn","hit","hit_souloverload","electrocute","knockback","knockbacklanded","knockback_pst","pinned_pre","pinned","pinned_hit"})do
 current=s;check(M.IsControlled(p),"detect server control state "..s)
end
legacy_frozen=true
for _,s in ipairs({"idle","attack","dolongaction","domediumaction","finishcontinuousaction","openwardrobe","talk","bedroll","tent","death"})do
 current=s;check(not M.IsControlled(p),"do not interrupt normal/unsafe state "..s)
end
p.sg.currentstate.name="hit";current="dolongaction"
check(not M.IsControlled(p),"authoritative state takes precedence over stale prediction")
p.sg.currentstate.name="idle";current="frozen"
M.Attach(p,{speed_key=KEY_F8,recover_key=KEY_F9})
frames(90);check(#requests==0,"automatic recovery starts off")
key(KEY_F6);key(KEY_F7)
check(not p._soloassist2hm.enabled and not p._soloassist2hm.auto_recover,"old bindings do nothing")
down(KEY_F9);down(KEY_F9)
check(p._soloassist2hm.auto_recover,"key repeats toggle only once")
check(#labels==1 and labels[1].parent==p.entity and labels[1].persists==false,"local-only label follows own character")
check(labels[1].visible and labels[1].text:find("自动解控：开启",1,true),"head text shows enabled status")
check(not labels[1].text:find("快速移动",1,true),"recovery key shows only recovery status")
up(KEY_F9);frames(1)
check(#requests==1,"controlled character triggers recovery without another key")
current="finishcontinuousaction";frames(30);current="idle";frames(60)
check(#requests==1,"recovery and lingering frozen effect do not trigger another attempt")
check(not labels[1].visible,"local head notice expires")
current="dolongaction";frames(90)
check(#requests==1,"normal crafting never triggers recovery")
current="frozen";frames(91)
check(#requests>=4 and #requests<=5,"failed requests retry at bounded rate")
for i=2,#requests do check(requests[i].time-requests[i-1].time>=.799,"retry cooldown") end
key(KEY_F9);local count=#requests;frames(90)
check(not p._soloassist2hm.auto_recover and #requests==count,"turning off stops automatic requests")
focus=true;key(KEY_F8);key(KEY_F9)
check(not p._soloassist2hm.enabled and not p._soloassist2hm.auto_recover,"typing does not toggle features")
focus=false;key(KEY_F8)
check(p._soloassist2hm.mode==1 and labels[1].text:find("快速移动：温和",1,true),"first custom-key press selects gentle and shows name")
check(not labels[1].text:find("自动解控",1,true),"speed key shows only the speed mode")
down(KEY_F8);down(KEY_F8)
check(p._soloassist2hm.mode==2 and labels[1].text:find("快速移动：加速",1,true),"key repeat advances only one speed mode")
up(KEY_F8);key(KEY_F8)
check(p._soloassist2hm.mode==3 and labels[1].text:find("快速移动：极速",1,true),"third press selects turbo and shows name")
key(KEY_F8)
check(p._soloassist2hm.mode==0 and not p._soloassist2hm.enabled and labels[1].text:find("快速移动：关闭",1,true),"fourth press returns to off")
cleanup()
check(pulse==nil and removed==4,"remove both key-down/up handlers and task")
check(labels[1].removed,"head label removed with character")
-- Shared binding deliberately controls both features.
p._soloassist2hm=nil;downs={};ups={};current="idle";removed=0
M.Attach(p,{speed_key=KEY_F8,recover_key=KEY_F8})
key(KEY_F8);check(p._soloassist2hm.enabled and p._soloassist2hm.auto_recover,"same binding switches both")
check(labels[#labels].text:find("快速移动：温和",1,true) and labels[#labels].text:find("自动解控：开启",1,true),"shared binding shows both features actually triggered")
key(KEY_F8);check(p._soloassist2hm.mode==2 and not p._soloassist2hm.auto_recover,"shared binding advances speed and switches recovery off")
key(KEY_F8);key(KEY_F8)
check(not p._soloassist2hm.enabled and not p._soloassist2hm.auto_recover,"four shared presses return both features to off")
cleanup();check(removed==2,"shared binding registers one down/up pair")
-- Runtime prediction negotiation must not alter local components or Profile.
Profile=setmetatable({},{__index=function()error("must not read or write persistent profile")end})
TheWorld.Map={IsPassableAtPoint=function()return true end,IsOceanAtPoint=function()return false end,IsPointNearHole=function()return false end}
p.GetCurrentPlatform=function()return nil end
RPC.SetMovementPredictionEnabled=2;RPC.PredictWalking=3;RPC.InspectButton=4
local protocol,invalid=false,0
requests={}
SendRPCToServer=function(...)
 local args={...};requests[#requests+1]={time=now,args=args}
 if args[1]==RPC.SetMovementPredictionEnabled then protocol=args[2]
 elseif args[1]==RPC.PredictWalking and not protocol then invalid=invalid+1 end
end
p._soloassist2hm=nil;downs={};ups={};p.components.locomotor=nil
M.Attach(p,{speed_key=KEY_F8,recover_key=KEY_F9,direction=function()return {x=1,z=0,LengthSq=function()return 1 end}end})
key(KEY_F8);key(KEY_F8);key(KEY_F8);frames(1)
check(#requests==1 and requests[1].args[1]==RPC.SetMovementPredictionEnabled and requests[1].args[2]==true,"negotiate before prediction packets")
frames(6)
check(invalid==0 and #requests>1,"prediction packets follow warmup and accepted protocol")
local perframe,peak={},0
for _,r in ipairs(requests)do
 if r.args[1]==RPC.PredictWalking or r.args[1]==RPC.InspectButton then
  perframe[r.time]=(perframe[r.time] or 0)+1
  peak=math.max(peak,perframe[r.time])
 end
end
check(peak>8 and peak<=16,"upgraded fast mode increases throughput with native RPC budget headroom")
check(p.components.locomotor==nil,"local prediction remains disabled")
focus=true;frames(1)
check(not protocol,"pausing input restores protocol")
focus=false;frames(5)
check(protocol and invalid==0,"resume re-negotiates before prediction packets")
key(KEY_F8)
check(not protocol,"toggle off restores disabled native mode")
local total=#requests;frames(10)
check(#requests==total,"idle frames do not spam mode changes")
cleanup()
-- An already enabled native prediction component must never be turned off.
requests={};protocol=true;p._soloassist2hm=nil;downs={};ups={}
p.components.locomotor={GetRunSpeed=function()return 6 end}
M.Attach(p,{speed_key=KEY_F8,direction=function()return {x=1,z=0,LengthSq=function()return 1 end}end})
key(KEY_F8);key(KEY_F8);key(KEY_F8);frames(4);key(KEY_F8);cleanup()
local switches=0
for _,r in ipairs(requests)do if r.args[1]==RPC.SetMovementPredictionEnabled then switches=switches+1 end end
check(switches==0 and protocol,"preserve existing native prediction without overrides")
check(invalid==0,"all protocol paths valid")
-- The direct host path must use the existing multiplier API, including cleanup.
TheWorld.ismastersim=true
local speeds={}
for _,mode in ipairs({1,2,3})do
 requests={};p._soloassist2hm=nil;downs={};ups={}
 local speed
 p.components.locomotor={
  SetExternalSpeedMultiplier=function(_,owner,key,value)
   check(owner==p and key=="soloassist2hm","host multiplier belongs to this mod and player")
   speed=value
  end,
  RemoveExternalSpeedMultiplier=function()speed=nil end,
 }
 M.Attach(p,{speed_key=KEY_F8,direction=function()return {x=1,z=0,LengthSq=function()return 1 end}end})
 for i=1,mode do key(KEY_F8)end
 frames(1);speeds[mode]=speed
 for i=mode,3 do key(KEY_F8)end
 check(speed==nil,"host toggle off removes its multiplier")
 check(#requests==0,"host uses native speed API without remote correction packets")
 cleanup()
end
check(speeds[1]==1.8 and speeds[2]==3.5 and speeds[3]==5,"gentle, previous fast and upgraded turbo host modes remain distinct")
print("SOLO_ASSIST_REGRESSION checks="..checks.." failures=0")
''')
# Use the installed game's actual modinfo loader and its empty environment.
from zipfile import ZipFile
from hashlib import sha256
with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as archive:
    index=archive.read("scripts/modindex.lua").decode("utf-8-sig")
    util=archive.read("scripts/util.lua").decode("utf-8-sig")
def native_function(source, signature):
    start=source.index(signature)
    return source[start:source.index("\nend",start)+4]
loader=native_function(index,"function ModIndex:InitializeModInfo(")
runner=native_function(util,"function RunInEnvironment(")
config=LuaRuntime(unpack_returned_tuples=True)
config.execute("ModIndex={}; LOC={GetLocaleCode=function()return 'zh' end}; MOD_API_VERSION=10; MODS_ROOT=''; native_messages={}; print=function(...)native_messages[#native_messages+1]=tostring((...))end; ModInfoname=function(s)return s end")
config.execute(runner)
config.execute(loader)
config.execute("kleiloadlua=function(path)return assert(loadstring(modinfo_source,'@'..path))end")
config.globals().modinfo_source=(ROOT/"client_mods/vanilla_solo_assist/modinfo.lua").read_text(encoding="utf-8")
info=config.globals().ModIndex.InitializeModInfo(config.globals().ModIndex,"vanilla_solo_assist")
assert not info["failed"],"Native empty-environment modinfo load failed"
assert info["string"] is None and info["tostring"] is None,"Loader environment must not accidentally contain libraries"
for _,option in info["configuration_options"].items():
    values=[entry["data"] for _,entry in option["options"].items()]
    assert option["default"] in values,option["name"]
    assert len(values)==len(set(values)),option["name"]
# Failure-before regression: the old dynamic alphabet cannot load in this environment.
config.globals().modinfo_source='name="Probe";description="Probe";author="Local";version="1";api_version=10;local key=string.char(65)'
bad=config.globals().ModIndex.InitializeModInfo(config.globals().ModIndex,"old_modinfo_probe")
assert bad["failed"],"The regression must catch the unavailable string library"
print("Native modinfo sandbox: fixed version passed; old string.char reproduced failure")
print("Native loader SHA256:",sha256(loader.encode()).hexdigest())

# Exercise the actual modmain hook contract: PlayerHud starts with no owner.
wiring=LuaRuntime(unpack_returned_tuples=True)
wiring.globals().modmain_source=(ROOT/"client_mods/vanilla_solo_assist/modmain.lua").read_text(encoding="utf-8")
wiring.execute(r'''
local attached,queued=0,{}
local Assist={Attach=function(owner,options)assert(owner.ready);attached=attached+1 end}
require=function(name)assert(name=="soloassist2hm");return Assist end
GLOBAL={KEY_F6=6,KEY_F7=7}
GetModConfigData=function()end
local post
AddClassPostConstruct=function(path,fn)assert(path=="screens/playerhud");post=fn end
assert(loadstring(modmain_source))()
local hud={SetMainCharacter=function(self,owner)self.owner=owner;if owner then owner.ready=true end end}
post(hud)
assert(hud.owner==nil and attached==0,"constructor may not access a missing owner")
hud:SetMainCharacter(nil)
local owner={IsValid=function()return true end,DoTaskInTime=function(_,_,fn)queued[#queued+1]=fn end}
hud:SetMainCharacter(owner)
assert(attached==0 and owner.ready,"attach is deferred until native initialization completed")
queued[1]()
assert(attached==1,"actual SetMainCharacter callback attaches helper")
print("Native HUD lifecycle regression passed")
''')
