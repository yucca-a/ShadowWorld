"""Precise shadow-magic deadlines, station prices, migration and cleanup."""
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'work/test-python'))
from lupa.lua51 import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().source = (ROOT/'content/scripts/shadowmagic2hm.lua').read_text(encoding='utf-8')
lua.execute('''
TUNING={TOTAL_DAY_TIME=480};EQUIPSLOTS={HEAD="head"}
TheWorld={state={cycles=100,time=.999}}
math.clamp=function(v,a,b)return math.max(a,math.min(b,v))end
SpawnPrefab=function()return {}end
local M=assert(loadstring(source))()
local checks=0
local function check(v,why)checks=checks+1;assert(v,why)end
local function near(a,b)check(math.abs(a-b)<1e-6,tostring(a).." ~= "..tostring(b))end
local function p()
    local inst={components={persistent2hm={data={}}},tags={},tasks={}}
    function inst:HasTag(t)return self.tags[t]end
    function inst:AddTag(t)self.tags[t]=true end
    function inst:RemoveTag(t)self.tags[t]=nil end
    function inst:AddComponent(t)self.components[t]={}end
    function inst:RemoveComponent(t)self.components[t]=nil;if t=='magician'then self:RemoveTag('magician')end end
    function inst:AddChild()end
    function inst:DoTaskInTime(t,fn)
        local job={delay=t};function job:Cancel()self.cancelled=true end
        self.tasks[#self.tasks+1]=job;return job
    end
    return inst
end
local x=p();check(M.Cost(x)==4,'initial costs four')
M.SetRemaining(x,20*480);near(M.Remaining(x),20*480);check(M.Cost(x)==0,'full costs zero')
TheWorld.state.cycles=101;TheWorld.state.time=.001
near(M.Remaining(x),20*480-.002*480)
check(x:HasTag('shadowmagic')and x.components.magician,'active abilities')
for _,case in ipairs({{0,4},{.01,4},{5,3},{10,2},{14,2},{15,1},{19.9,1},{20,0}})do
    M.SetRemaining(x,case[1]*480);check(M.Cost(x)==case[2],'price '..case[1])
end
M.SetRemaining(x,20*480);M.RenewJournal(x);near(M.Remaining(x),20*480)
M.SetRemaining(x,19.5*480);M.RenewJournal(x);near(M.Remaining(x),20*480)
M.SetRemaining(x,0);M.RenewJournal(x);near(M.Remaining(x),480)
local never=p();check(not M.RenewJournal(never),'journal cannot enroll a new player')
for _,delta in ipairs({-80,-1,0,6,19,20,21,100})do
    local old=p();local d=old.components.persistent2hm.data
    d.shadowmagiccycle=TheWorld.state.cycles-delta
    local expected=math.clamp(20-delta,0,20)*480
    near(M.Remaining(old),expected)
    local deadline=d.shadowmagicexpires2hm
    TheWorld.state.time=TheWorld.state.time+.0001
    M.Ensure(old);near(d.shadowmagicexpires2hm,deadline)
end
local original=p();original:AddTag('shadowmagic');original:AddTag('magician');original:AddComponent('magician')
check(M.Cost(original)==0,'native mage is not charged')
M.SetRemaining(original,1);TheWorld.state.time=TheWorld.state.time+.01;M.Refresh(original)
check(original:HasTag('shadowmagic')and original.components.magician,'innate abilities preserved')
local reader=p();reader.components.reader={sanity_mult=2.5,SetSanityPenaltyMultiplier=function(self,v)self.sanity_mult=v end}
reader:AddTag('magician')
M.SetRemaining(reader,10);near(reader.components.reader.sanity_mult,1)
M.SetRemaining(reader,10)
check(not reader.components.persistent2hm.data.shadowmagic_tag,'renewal never captures borrowed tags as innate')
TheWorld.state.time=TheWorld.state.time+.1;M.Refresh(reader)
check(not reader:HasTag('shadowmagic')and not reader.components.magician,'temporary abilities expire')
check(reader:HasTag('magician'),'pre-existing magician tag survives native component cleanup')
near(reader.components.reader.sanity_mult,2.5)
check(not reader.shadowmagicexpirycheck2hm,'expired player has no recurring expiry job')
TUNING.SEG_TIME=30
local clock={cycles=100,phase='night',totaltimeinphase=120,remainingtimeinphase=.5,segs={day=8,dusk=4,night=4}}
TheWorld.net={components={clock={OnSave=function()return clock end}}}
local dawn=p();M.SetRemaining(dawn,20*480)
clock.cycles=101;clock.phase='day';clock.totaltimeinphase=240;clock.remainingtimeinphase=239.5
near(M.Remaining(dawn),20*480-1)
check(M.Cost(dawn)==1,'authoritative clock avoids a daybreak state-field race')
print('SHADOWMAGIC_PASS '..checks..' checks')
''')
