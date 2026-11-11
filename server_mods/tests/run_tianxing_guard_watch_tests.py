"""Deterministic countdown, stopping, false-config and kick-boundary tests."""
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"work/test-python"))
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.globals().source=(ROOT/"server_mods/tianxing_guard/scripts/tianxing_guard_watch.lua").read_text(encoding="utf-8")
lua.execute(r'''
local checks=0
local function check(v,msg)checks=checks+1;assert(v,msg)end
local Watch=assert(loadstring(source))()
local now,tasks,messages,kicks,valid,p,watch
GetTime=function()return now end
local function reset(enabled)
 now=0;tasks={};messages={};kicks={};valid=true
 p={userid="KU_test",name="测试玩家",IsValid=function()return valid end,
 DoTaskInTime=function(_,delay,fn)
  local t={time=now+delay,fn=fn,Cancel=function(self)self.cancelled=true end}
  tasks[#tasks+1]=t;return t
 end}
 watch=Watch.New({auto_kick=enabled,
  announce=function(text)messages[#messages+1]={time=now,text=text}end,
  kick=function(inst,reason)kicks[#kicks+1]={time=now,inst=inst,reason=reason}end})
end
local function advance(to)
 while true do
  local nexttask
  for _,t in ipairs(tasks)do
   if not t.cancelled and t.time<=to and (not nexttask or t.time<nexttask.time)then nexttask=t end
  end
  if not nexttask then break end
  now=nexttask.time;nexttask.cancelled=true;nexttask.fn()
 end
 now=to
end
reset(true)
for i=0,60 do advance(i/10);watch.Report(p,"speed")end
check(#messages==5,"exactly five announcements for one continued incident")
for i=1,5 do
 check(messages[i].time==i-1 and messages[i].text:find("倒计时"..(6-i).."秒",1,true),"countdown order and timing "..i)
end
check(#kicks==1 and kicks[1].time>=5,"continued post-deadline violation kicks once")
check(kicks[1].reason:find("快速移动辅助",1,true),"kick carries the detected reason")
reset(true)
for i=0,6 do advance(i*.8);watch.Report(p,"recover")end
advance(4.999);watch.Report(p,"recover")
advance(9)
check(#messages==5 and #kicks==0,"stopping immediately before five seconds never kicks using stale evidence")
reset(true)
watch.Report(p,"recover");advance(8)
check(#messages==5 and #kicks==0,"a stopped incident still has five conditional warnings and no kick")
watch.Report(p,"recover");advance(12.9);watch.Report(p,"recover")
check(#kicks==0,"resumed behavior after a long quiet period receives new grace")
reset(false)
for i=0,100 do advance(i/10);watch.Report(p,"speed")end
check(#messages==5 and #kicks==0,"disabled auto kick still protects and announces once without kicking")
check(messages[1].text:find("自动踢出已关闭",1,true),"disabled configuration does not threaten a kick")
reset(true)
watch.Report(p,"speed");advance(.2);watch.Report(p,"recover");advance(1)
check(#messages==2 and messages[2].text:find("快速移动辅助",1,true) and messages[2].text:find("自动解控辅助",1,true),"two behaviors share one countdown and list both causes")
reset(true)
watch.Report(p,"speed");valid=false;advance(10);watch.Report(p,"speed")
check(#messages==1 and #kicks==0,"disconnected player receives no further messages or kick")
reset(nil)
for i=0,55 do advance(i/10);watch.Report(p,"recover")end
check(#kicks==1,"auto kick defaults enabled")
print("TIANXING_WATCH_REGRESSION checks="..checks.." failures=0")
''')
