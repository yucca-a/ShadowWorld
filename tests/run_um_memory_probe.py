"""Observe native UM allocations/entities, with bounded disposable servers."""
from pathlib import Path
from zipfile import ZipFile
import argparse, ctypes, hashlib, json, shutil, subprocess, sys, threading, time, traceback, _winapi

sys.path.insert(0,str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster, ROOT

sys.stdout.reconfigure(encoding="utf-8")
p=argparse.ArgumentParser(description=__doc__)
p.add_argument("--mode",choices=["vanilla","um","combined"],default="um")
p.add_argument("--scenario",choices=["effects","air","idle","recursion","save"],default="effects")
p.add_argument("--rounds",type=int,default=3)
p.add_argument("--batch",type=int,default=32)
p.add_argument("--age",type=float,default=8)
p.add_argument("--shadows",type=int,default=0)
p.add_argument("--restart",action="store_true")
p.add_argument("--dormant",action="store_true",help="Let native effects sleep normally rather than forcing the test batches awake")
p.add_argument("--gps",action="store_true",help="Include the screenshot's Global Positions CompleteSync mod")
p.add_argument("--wake-after-load",action="store_true",help="Observe whether retained smoke clears when forced awake after reload")
p.add_argument("--world",choices=["surface","cave"],default="surface")
a=p.parse_args()
if a.wake_after_load and not(a.dormant and a.restart):p.error("--wake-after-load requires --dormant --restart")
baseline=ROOT/"work/um-memory-published-019"
if not baseline.exists():
    baseline.mkdir()
    with ZipFile(ROOT/"backups/releases/v2.8.15.0.19-content.zip")as z:z.extractall(baseline)
um=ROOT/"work/um-memory-beta-frozen"
if not um.exists():
    shutil.copytree(Path("D:/SteamLibrary/steamapps/workshop/content/322330/3193922031"),um)
    hashes={str(p.relative_to(um)):hashlib.sha256(p.read_bytes()).hexdigest() for p in um.rglob("*")if p.is_file()}
    (ROOT/"work/um-memory-beta-frozen-manifest.json").write_text(json.dumps(hashes,indent=2),encoding="utf-8")
c=Cluster("hosted",1,ROOT/"work/reuse-audit/config/Audit" if a.world=="surface" else None,baseline)
if a.world=="cave":
    (c.cluster/"Master/worldgenoverride.lua").write_text('return {override_enabled=true,preset="DST_CAVE",overrides={world_size="small"}}',encoding="utf-8")
(c.runtime/"mods/VaultAudit/modmain.lua").write_text((ROOT/"tests/native/um_memory_probe.lua").read_text(encoding="utf-8"),encoding="utf-8")
if a.mode!="vanilla":_winapi.CreateJunction(str(um),str(c.runtime/"mods/workshop-3193922031"))
if a.gps:
    gps=ROOT/"work/um-memory-gps-frozen"
    if not gps.exists():shutil.copytree(Path("D:/SteamLibrary/steamapps/workshop/content/322330/3138571948"),gps)
    _winapi.CreateJunction(str(gps),str(c.runtime/"mods/workshop-3138571948"))
options={'enable easy mode':True,'enable hard mode':True,'Shadow World':a.shadows or False,
    'Shadow Animals':1,'Shadow Num Limit':False,'Shadow Harder Level':False,'rangesupermonster':False,'specialsupermonster':False}
def lv(x):return str(x).lower()if isinstance(x,bool)else str(x)
config=",".join("["+json.dumps(k)+"]="+lv(v)for k,v in options.items())
(c.cluster/"Master/modoverrides.lua").write_text('return {VaultAudit={enabled=true},ShadowWorld={enabled='+str(a.mode=="combined").lower()+',configuration_options={'+config+'}}'+(',["workshop-3193922031"]={enabled=true}'if a.mode!="vanilla"else '')+(',["workshop-3138571948"]={enabled=true}'if a.gps else '')+'}',encoding="utf-8")

class Counters(ctypes.Structure):
    _fields_=[("cb",ctypes.c_ulong),("PageFaultCount",ctypes.c_ulong)]+[(n,ctypes.c_size_t)for n in ['PeakWorkingSetSize','WorkingSetSize','QuotaPeakPagedPoolUsage','QuotaPagedPoolUsage','QuotaPeakNonPagedPoolUsage','QuotaNonPagedPoolUsage','PagefileUsage','PeakPagefileUsage','PrivateUsage']]
def memory(proc):
    m=Counters();m.cb=ctypes.sizeof(m)
    ok=ctypes.windll.psapi.GetProcessMemoryInfo(ctypes.c_void_p(int(proc._handle)),ctypes.byref(m),m.cb)
    return {"private_bytes":m.PrivateUsage,"working_set_bytes":m.WorkingSetSize,"peak_working_set_bytes":m.PeakWorkingSetSize}if ok else {}
stop=threading.Event();os_samples=[];guard=[]
def monitor():
    started=time.monotonic()
    while not stop.wait(.5):
        proc=c.children.get("Master")
        if proc and proc.poll()is None:
            row={"elapsed":time.monotonic()-started,**memory(proc)};os_samples.append(row)
            if row.get("private_bytes",0)>3*1024**3:
                guard.append("Owned test server exceeded 3 GiB private-memory observation limit; stopped before risking host resources.")
                proc.terminate();break
thread=threading.Thread(target=monitor,daemon=True);thread.start()
r={"mode":a.mode,"scenario":a.scenario,"cluster":str(c.out),"shadows":a.shadows,"dormant":a.dormant,"gps":a.gps,"world":a.world,
   "um_source":str(um),"source":str(baseline),"snapshots":[],"batches":[],"saves":[],"guard":guard,
   "architecture":"native x64 dedicated server","production_fixes_applied":False}
mid_restart=False
def sample(label):
    row=c.call("Master",f'VaultAudit.sample({json.dumps(label)})',"memory_sample",timeout=30)
    row["process"]=memory(c.children["Master"]);r["snapshots"].append(row)
    print(json.dumps({k:row[k]for k in ["label","lua_retained_kb","entities","tasks","details"]}),flush=True)
def wait(seconds):
    deadline=time.monotonic()+seconds
    while time.monotonic()<deadline:
        if guard:raise RuntimeError(guard[0])
        if c.children['Master'].poll()is not None:raise RuntimeError('Owned server exited during observation')
        time.sleep(min(.5,max(0,deadline-time.monotonic())))
try:
    c.start();sample("baseline");wait(10);sample("idle_10s")
    if a.scenario=="effects":
        for prefab in ["small_puff"]+(["air_conditioner_smoke"]if a.mode!="vanilla"else []):
            for i in range(a.rounds):
                r["batches"].append(c.call("Master",f'VaultAudit.batch("{prefab}",{a.batch},{str(not a.dormant).lower()})',"memory_batch"))
                wait(a.age);sample(prefab+"_aged_"+str(i))
            r["saves"].append(c.call("Master","VaultAudit.save()","memory_saved",timeout=60))
            if a.dormant and a.restart and prefab=="air_conditioner_smoke":
                c.command("Master","c_shutdown(true)");assert c.children["Master"].wait(timeout=45)==0
                c.stop();c.start();sample("smoke_loaded_before_cleanup")
                mid_restart=True
                if a.wake_after_load:
                    r["wake"]=c.call("Master","VaultAudit.wake_smoke()","memory_wake")
                    wait(a.age);sample("smoke_after_waking")
            c.call("Master","VaultAudit.cleanup()","memory_cleanup");wait(3);sample(prefab+"_cleaned")
    elif a.scenario=="air":
        r["air"]=c.call("Master",f'VaultAudit.air({a.rounds})',"memory_air")
        wait(max(8,r["air"]["duration"]+4));sample("air_after_uses")
        wait(40);sample("air_after_40s")
        r["saves"].append(c.call("Master","VaultAudit.save()","memory_saved",timeout=60))
    elif a.scenario=="recursion":
        r["recursion"]=[]
        for n in [1000,10000,24000]:
            started=time.monotonic()
            row=c.call("Master",f'VaultAudit.recursion({n})',"memory_recursion",timeout=30)
            row["host_call_seconds"]=time.monotonic()-started;r["recursion"].append(row);print(json.dumps(row),flush=True)
            sample("recursion_"+str(n))
        r["saves"].append(c.call("Master","VaultAudit.save()","memory_saved",timeout=60))
    elif a.scenario=="save":
        c.call("Master","VaultAudit.player()","memory_player")
        for i in range(a.rounds):
            started=time.monotonic();row=c.call("Master","VaultAudit.save()","memory_saved",timeout=60)
            row["host_call_seconds"]=time.monotonic()-started;r["saves"].append(row)
            wait(a.age);sample("save_"+str(i))
    else:
        for i in range(a.rounds):wait(a.age);sample("idle_"+str(i))
        r["saves"].append(c.call("Master","VaultAudit.save()","memory_saved",timeout=60))
    if a.restart and not mid_restart:
        c.command("Master","c_shutdown(true)");assert c.children["Master"].wait(timeout=45)==0
        c.stop();c.start();sample("restarted")
    r["status"]="observed"
except Exception:
    r.update(status="failed",error=traceback.format_exc());print(r["error"],flush=True)
finally:
    stop.set();thread.join(timeout=3);c.stop();r["os_memory"]=os_samples
    out=c.out/"um-memory-result.json";out.write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding="utf-8");print(out,flush=True)
raise SystemExit(0 if r["status"]=="observed"else 1)
