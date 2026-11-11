"""Frozen Lua implementations: packet fault sweeps and independent persistence model."""
from pathlib import Path
import json
import sys
from zipfile import ZipFile

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'work/test-python'))
from lupa.lua51 import LuaRuntime

lua=LuaRuntime(unpack_returned_tuples=True)
loader=lua.eval('function(s,name)return assert(loadstring(s,name))end')
inputs=ROOT/'work/vault-comparison-20261106'
with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as archive:
    util=archive.read('scripts/util.lua').decode('utf-8-sig')
    start=util.index('function deepcopy(')
    lua.execute(util[start:util.index('\nend',start)+4])
lua.globals().Protocol=loader((inputs/'hosted/scripts/worldexchangeprotocol2hm.lua').read_text(encoding='utf-8'),'hosted protocol')()
source=(ROOT/'tests/world_exchange_regression.lua').read_text(encoding='utf-8')
lua.execute(source)
prefix=source[:source.index('\nlocal sim = simulation()')]
lua.execute(prefix+'''
local completed,cancelled=0,0
for seed=1,1000 do
    math.randomseed(seed)
    local sim=simulation({jitter=2,duplicate=true,drop=function()return math.random()<.2 end})
    sim:start("1");sim:run(240,function(s)return s:finished()end)
    check(sim:finished(),"random fault run settles seed="..seed)
    if sim.worlds["1"].applies==0 then
        check(equal(sim.worlds["1"].goods,initial["1"]) and equal(sim.worlds["2"].goods,initial["2"]),"cancel conserves")
        cancelled=cancelled+1
    else sim:swapped();completed=completed+1 end
end
HOSTED_RESULT={seeds=1000,completed=completed,cancelled=cancelled,checks=assertions}
''')
lua.globals().Transfer=loader((inputs/'xianyu/test/scripts/shadowbanktransfer2hm.lua').read_text(encoding='utf-8'),'xianyu transfer')()
lua.execute('''
local function sim(seed,fault)
    math.randomseed(seed)
    local s={worlds={},events={},now=0,boot=0,sent=0,dropped=0}
    function s:build(id,saved)
        self.boot=self.boot+1
        local w=self.worlds[id]
        w.transfer=Transfer.new({boot=tostring(self.boot),available=function()return true end,
            apply=function(peer,payload)w.goods=w.goods+payload.amount;return true end,
            send=function(peer,m)
                self.sent=self.sent+1
                if fault and math.random()<.2 then self.dropped=self.dropped+1;return end
                local raw=deepcopy(m)
                self.events[#self.events+1]={at=self.now+(fault and math.random()*2 or .05),to=peer,from=id,m=raw}
                if fault then self.events[#self.events+1]={at=self.now+math.random()*3,to=peer,from=id,m=deepcopy(m)}end
            end},saved)
    end
    for _,id in ipairs({"1","2"})do s.worlds[id]={goods=id=="2" and 17 or 0}end
    for _,id in ipairs({"1","2"})do s:build(id);s.worlds[id].disk={goods=s.worlds[id].goods,transfer=deepcopy(s.worlds[id].transfer:Save())}end
    function s:save(id)
        local w=self.worlds[id];w.disk={goods=w.goods,transfer=deepcopy(w.transfer:Save())}
    end
    function s:restart()
        self.events={}
        for _,id in ipairs({"1","2"})do local w=self.worlds[id];w.goods=w.disk.goods;self:build(id,deepcopy(w.disk.transfer))end
    end
    function s:run(seconds)
        for tick=1,seconds*20 do
            self.now=self.now+.05
            local events=self.events;self.events={}
            for _,e in ipairs(events)do
                if e.at<=self.now then self.worlds[e.to].transfer:Receive(e.from,e.m)
                else self.events[#self.events+1]=e end
            end
            for _,w in pairs(self.worlds)do w.transfer:Tick(self.now)end
        end
    end
    assert(s.worlds["2"].transfer:Queue("1",{kind="item",amount=17}))
    s.worlds["2"].goods=0
    return s
end
local packets,dropped=0,0
for seed=1,1000 do
    local s=sim(seed,true);s:run(30)
    assert(s.worlds["1"].goods==17 and s.worlds["2"].goods==0,"fault conservation seed="..seed)
    assert(not next(s.worlds["2"].transfer.pending),"eventual completion seed="..seed)
    packets=packets+s.sent;dropped=dropped+s.dropped
end
local cuts={}
for mask=0,3 do
    local s=sim(1,false);s:run(5)
    if mask%2==1 then s:save("1")end
    if mask>=2 then s:save("2")end
    s:restart();s:run(5)
    cuts[#cuts+1]={saved_master=mask%2==1,saved_source=mask>=2,total=s.worlds["1"].goods+s.worlds["2"].goods,expected=17}
end
XIAN_RESULT={seeds=1000,completed=1000,packets=packets,dropped=dropped,independent_save_cuts=cuts}
''')
def native(value):
    if hasattr(value,'items'):
        d={k:native(v) for k,v in value.items()}
        if d and all(isinstance(k,int) for k in d) and set(d)==set(range(1,len(d)+1)):return [d[k] for k in sorted(d)]
        return d
    return value
result={'hosted':native(lua.globals().HOSTED_RESULT),'xianyu':native(lua.globals().XIAN_RESULT),'scope':'Actual Lua protocol modules; simulated I/O and checkpoints; hosted exchanges two snapshots, xianyu transfers one payload. Native game cases are separate.'}
dest=inputs/'protocol-stress-result.json'
dest.write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result,indent=2))
