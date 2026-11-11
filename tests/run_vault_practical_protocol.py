"""Actual journal protocol; asynchronous local commits and independent crash cuts."""
from pathlib import Path
from zipfile import ZipFile
import sys,json
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'work/test-python'))
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
loader=lua.eval('function(s,n)return assert(loadstring(s,n))end')
with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as z:
    util=z.read('scripts/util.lua').decode('utf-8-sig');a=util.index('function deepcopy(')
    lua.execute(util[a:util.index('\nend',a)+4])
for name in ('worldexchangeprotocol2hm','shadowvaultdurable2hm'):
    lua.globals().module_loader=loader((ROOT/'content/scripts'/(name+'.lua')).read_text(encoding='utf-8'),name)
    lua.execute('package.preload["'+name+'"]=module_loader')
lua.execute('Durable=require("shadowvaultdurable2hm")')
s=(ROOT/'tests/world_exchange_regression.lua').read_text(encoding='utf-8')
s=s[:s.index('\nlocal sim = simulation()')]
s=s.replace('checkpoint = function() sim:save() end,','checkpoint = function() error("world save forbidden") end,')
s=s.replace('        world.protocol = Protocol.new(io, saved)',r'''        local journal={ready=true,v={}}
        world.journal=journal
        function journal:Flush(cb)
            if self.busy then event(.2,function() if world.journal==self then self:Flush(cb) end end);return end
            self.busy=true
            local snapshot={protocol=world.protocol:Save(),goods=copy(world.goods)}
            event(.01+math.random()*.15,function()
                if world.journal~=self then return end
                world.disk=snapshot;self.busy=nil;cb(true)
            end)
        end
        world.locked=saved and saved.active~=nil or false
        world.protocol = Durable.new(io, saved,journal)''')
s=s.replace('return not self.worlds["1"].protocol.active and not self.worlds["2"].protocol.active','return not self.worlds["1"].protocol.active and not self.worlds["2"].protocol.active and not self.worlds["1"].journal.busy and not self.worlds["2"].journal.busy')
lua.execute(s+r'''
local completed,cancelled,crashes=0,0,0
for seed=1,1200 do
    math.randomseed(seed)
    local sim=simulation({jitter=.7,duplicate=true,drop=function()return math.random()<.2 end})
    sim:start("1")
    if seed<=600 then
        sim:run(math.random()*12)
        local target=seed%3
        if target~=2 then sim:restart("1");crashes=crashes+1 end
        if target~=1 then sim:restart("2");crashes=crashes+1 end
    end
    check(sim:run(240,function(s)return s:finished()end),"fault sweep settles seed="..seed)
    local a,b=sim.worlds["1"],sim.worlds["2"]
    local swapped=equal(a.goods,initial["2"]) and equal(b.goods,initial["1"])
    local original=equal(a.goods,initial["1"]) and equal(b.goods,initial["2"])
    check(swapped or original,"exact item conservation seed="..seed)
    if swapped then completed=completed+1 else cancelled=cancelled+1 end
    check(sim.saves==0,"no world save")
    -- Consume all outputs, commit only the vault, reboot both, replay every
    -- old message. Durable terminal receipts must not resurrect these items.
    sim:run(5)
    a.goods.items={};b.goods.items={}
    a.journal:Flush(function()end);b.journal:Flush(function()end);sim:run(1)
    sim:restart("1");sim:restart("2")
    for _,packet in ipairs(copy(sim.sent))do sim.worlds[packet.peer].protocol:Receive(packet.from,packet.message)end
    sim:run(15)
    check(next(a.goods.items)==nil and next(b.goods.items)==nil,"consumed items not recreated seed="..seed)
end
RESULT={runs=1200,completed=completed,cancelled=cancelled,independent_crashes=crashes,assertions=assertions,world_saves=0}
''')
result=dict(lua.globals().RESULT.items())
result['scope']='Actual Lua durable protocol with simulated delayed local persistence; native tests are separate.'
(ROOT/'development/validation/vault-practical-protocol-20261106.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result,indent=2))
