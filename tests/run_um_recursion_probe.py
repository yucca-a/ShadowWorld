"""Reproduce UM's occupied-location recursion in isolated Lua, without patching it."""
from pathlib import Path
from zipfile import ZipFile
import argparse, json, sys, time

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"work/test-python"))
from lupa.lua51 import LuaRuntime

p=argparse.ArgumentParser(description=__doc__)
p.add_argument("--um-source",type=Path,default=ROOT/"work/um-memory-beta-frozen")
p.add_argument("--out",type=Path,default=ROOT/"work/um-memory-recursion-probe.json")
a=p.parse_args()
source=a.um_source/"scripts/components/um_ocupusappearinator.lua"
with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip")as z:
    cls=z.read("scripts/class.lua").decode("utf-8-sig")
    util=z.read("scripts/util.lua").decode("utf-8-sig")
start=util.index("function deepcopy(")
deepcopy=util[start:util.index("\nend",start)+4]
rows=[]
for n in [100,1000,4000,10000,16000,24000]:
    lua=LuaRuntime(unpack_returned_tuples=True,max_memory=256*1024*1024)
    lua.execute(cls);lua.execute(deepcopy)
    g=lua.globals();g.component_source=source.read_text(encoding="utf-8-sig");g.n=n
    started=time.perf_counter()
    lua.execute(r'''
TheWorld={ismastersim=true,components={um_tilelogger={Hazardous={}}}}
local checks=0
local c=assert(loadstring(component_source,"@scripts/components/um_ocupusappearinator.lua"))()({ListenForEvent=function()end})
-- Synthetic predicate isolates candidate-count depth. Native-server coverage
-- uses real entity distances in tests/native/um_memory_probe.lua instead.
c:RegisterOcupus({GUID=1,IsValid=function()return true end,GetDistanceSqToPoint=function()checks=checks+1;return 0 end})
for i=1,n do TheWorld.components.um_tilelogger.Hazardous[i]={x=i,z=0}end
collectgarbage('collect');before=collectgarbage('count')
local started=os.clock()
debug.sethook(function()if os.clock()-started>2 then error('PROBE_TIME_BUDGET')end end,'',10000)
local ok,err=xpcall(function()c:SpawnOcupi()end,debug.traceback)
debug.sethook()
status=ok and 'returned' or tostring(err)
transient=collectgarbage('count');collectgarbage('collect');retained=collectgarbage('count');calls=checks
''')
    row={"tiles":n,"status":g.status,"distance_tests":g.calls,"wall_seconds":time.perf_counter()-started,
         "before_kb":g.before,"before_final_gc_kb":g.transient,"after_gc_kb":g.retained}
    rows.append(row)
    print(json.dumps({k:v for k,v in row.items()if k!="status"}|{"status":row["status"].splitlines()[0]}),flush=True)
report={"source":str(source),"conditions":"Synthetic all-blocked candidates; actual component, no production fixes. 256 MiB Lua safety cap and 2 second instruction-time budget.","results":rows}
a.out.parent.mkdir(parents=True,exist_ok=True)
a.out.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8")
