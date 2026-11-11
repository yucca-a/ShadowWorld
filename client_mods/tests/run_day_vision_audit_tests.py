"""Verify the temporary vision logger observes native state without changing behavior."""
from pathlib import Path
from zipfile import ZipFile
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as z:
    lua.execute(z.read("scripts/class.lua").decode("utf-8-sig"))
    lua.globals().vision_source = z.read("scripts/components/playervision.lua").decode("utf-8-sig")
    lua.globals().grue_source = z.read("scripts/components/grue.lua").decode("utf-8-sig")
lua.globals().see_source = ""
lua.globals().patch_source = (ROOT / "content/common/monster_nightvision.lua").read_text(encoding="utf-8-sig")
lua.globals().audit_source = (ROOT / "client_mods/day_vision_audit/modmain.lua").read_text(encoding="utf-8-sig")
prefix = (ROOT / "tests/monster_nightvision_regression.lua").read_text(encoding="utf-8-sig").split("setup(true,true,true,true)", 1)[0]
lua.execute(prefix + r'''
setup(false,false,false,false)
TheWorld.events={}
TheWorld.components={colourcube={GetDebugString=function()return 'actual cube: spring_day_cc.tex'end}}
local encoded, failencode = {}, false
package.preload.json=function()return {encode=function(value)
    if failencode then error('injected logging failure')end
    encoded[#encoded+1]=value
    return 'encoded'
end}end
GetTime=function()return clock end
local worldtick,init
TheWorld.DoPeriodicTask=function(_,_,fn)worldtick=fn end
AddSimPostInit=function(fn)init=fn end
local oldprint=print; print=function()end
run(audit_source,'@mods/day_vision_audit/modmain.lua');init()
worldtick() -- Local player has not been assigned yet.
local p,v=make('wx78',false);ThePlayer=p
p.replica.inventory.GetEquips=function()return {head={prefab='dreadstonehat',GUID=100,
    HasTag=function()return false end}}end
p.components.skilltreeupdater={IsActivated=function()return false end}
local original=v.ForceNightVision
v.ForceNightVision=function(self,enabled)original(self,enabled);return nil,'preserved',3 end
worldtick()
check(v.dayvisionaudit,'late local player is attached')
check(encoded[#encoded].state.colourcube=='actual cube: spring_day_cc.tex','actual renderer state is captured')
check(encoded[#encoded].state.equipped.head.nightvision==false,'equipment without nightvision is captured')
check(encoded[#encoded].state.wx78_plainvision==false,'false skill state is preserved')
local wrapped=v.ForceNightVision;worldtick()
check(v.ForceNightVision==wrapped,'polling never wraps twice')
TheWorld.state.isday=true;TheWorld.state.isnight=false;TheWorld.state.phase='day'
local function returns(...)return select('#',...),... end
local n,a,b,c=returns(v:ForceNightVision(true))
check(n==3 and a==nil and b=='preserved'and c==3,'nil and multiple return values preserved')
check(v:HasNightVision()and v:GetCCTable().day:find('mole_vision_off',1,true),'diagnostics do not repair or suppress observed whiteout palette')
local found=false
for _,record in ipairs(encoded)do
 if record.reason=='day-call'then
  for _,call in ipairs(record.calls)do
   if call.method=='ForceNightVision'and call.trace:find('day_vision_audit',1,true)then found=true end
  end
 end
end
check(found,'record contains method and call location')
local override=TheWorld.events.overridecolourcube[1]
override.fn(TheWorld,'test_override.tex');tick(0)
local eventfound=false
for _,record in ipairs(encoded)do
 for _,call in ipairs(record.calls or {})do
  if call.method=='event:overridecolourcube'and call.argument=='test_override.tex'then eventfound=true end
 end
end
check(eventfound,'world override bypassing playervision is captured')
v:ForceNightVision(false)
check(not v:HasNightVision()and v:GetCCTable()==nil,'normal disable still clears palette')
for i=1,50 do v:PushForcedNightVision(p,0,nil,nil,nil,true);v:PopForcedNightVision(p)end
check(not v:HasNightVision()and #v.forcednightvisionstack==0,'repeated source changes still clean up')
clock=clock+2;v:ForceNightVision(true)
local bounded=false
for _,record in ipairs(encoded)do if record.calls then check(#record.calls<=24,'history remains bounded');bounded=true end end
check(bounded,'history emitted')
failencode=true
v:ForceNightVision(false)
check(not v:HasNightVision(),'logging failure cannot prevent disable')
-- A failure while formatting metadata must also leave the original call intact.
local getinfo=debug.getinfo;debug.getinfo=function()error('injected trace failure')end
v:ForceNightVision(true);v:ForceNightVision(false)
debug.getinfo=getinfo
check(not v:HasNightVision(),'trace failure cannot prevent original behavior')
failencode=false
local q,w=make('wx78',false);ThePlayer=q;worldtick()
check(w.dayvisionaudit,'new local player after migration is attached')
oldprint('Day vision audit: '..checks..' checks passed')
''')
