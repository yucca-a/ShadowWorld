"""Serial disposable servers: actual UM standalone vs guarded ShadowWorld adapters."""
from pathlib import Path
import argparse
import json
import sys
import traceback
import _winapi

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster, ROOT

sys.stdout.reconfigure(encoding="utf-8")
p=argparse.ArgumentParser(description=__doc__)
p.add_argument("--um",choices=["stable","beta"],default="beta")
p.add_argument("--mode",choices=["um","combined"],default="combined")
p.add_argument("--status-only",action="store_true")
a=p.parse_args()
c=Cluster("hosted",1,ROOT/"work/reuse-audit/config/Audit",ROOT/"content")
uid={"stable":"2039181790","beta":"3193922031"}[a.um]
source=ROOT/"work/newconstant-research/steamcmd/steamapps/workshop/content/322330"/uid
_winapi.CreateJunction(str(source),str(c.runtime/"mods"/("workshop-"+uid)))
fixture='PERF_COMBINED='+str(a.mode=="combined").lower()+'\nPERF_BETA='+str(a.um=="beta").lower()+'\n'
fixture+=(ROOT/"tests/native/um_performance_probe.lua").read_text(encoding="utf-8")
(c.runtime/"mods/VaultAudit/modmain.lua").write_text(fixture,encoding="utf-8")
options={"enable easy mode":True,"enable hard mode":True,"um_patch":True,"um_weather_particles2hm":4,
    "Shadow World":False,"rangesupermonster":False,"specialsupermonster":False}
def lv(v):return str(v).lower()if isinstance(v,bool)else str(v)
config=",".join("["+json.dumps(k)+"]="+lv(v)for k,v in options.items())
(c.cluster/"Master/modoverrides.lua").write_text('return {VaultAudit={enabled=true},ShadowWorld={enabled='+str(a.mode=="combined").lower()+',configuration_options={'+config+'}},["workshop-'+uid+'"]={enabled=true}}',encoding="utf-8")
report={"cluster":str(c.out),"um":a.um,"mode":a.mode,"source":str(source)}
try:
    c.start()
    report["startup"]=c.call("Master","VaultAudit.status()","performance_status")
    print(json.dumps(report["startup"],ensure_ascii=False),flush=True)
    if not a.status_only:
        report["run"]=c.call("Master","VaultAudit.run()","performance_done",timeout=60)
        assert report["run"]["passed"],report["run"]
        if a.mode=="combined" and a.um=="beta":
            report["ecology"]=c.call("Master","VaultAudit.ecology()","performance_ecology",timeout=45)
            assert report["ecology"]["passed"],report["ecology"]
        c.command("Master","c_shutdown(true)")
        assert c.children["Master"].wait(timeout=60)==0
        c.stop();c.start()
        report["reload"]=c.call("Master","VaultAudit.after_reload()","performance_reload",timeout=30)
        assert report["reload"]["passed"],report["reload"]
    report["status"]="passed"
except Exception:
    report.update(status="failed",error=traceback.format_exc())
    print(report["error"],flush=True)
finally:
    c.stop()
    report["events"]=[]
    try:report["events"]=c.events("Master")
    except Exception:pass
    result=c.out/"um-performance-result.json"
    result.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8")
    print(result,flush=True)
raise SystemExit(0 if report["status"]=="passed"else 1)
