"""Read-only BWB input, owned offline two-shard cluster, real components and gems."""
from pathlib import Path
import argparse, json, sys, traceback, _winapi, time

sys.path.insert(0,str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster, ROOT

sys.stdout.reconfigure(encoding="utf-8")
p=argparse.ArgumentParser(description=__doc__)
p.add_argument("--source",type=Path,default=ROOT/"content")
p.add_argument("--observe-only",action="store_true")
p.add_argument("--without-bwb",action="store_true")
a=p.parse_args()
bwb=ROOT/"work/newconstant-research/steamcmd/steamapps/workshop/content/322330/3360553731"
c=Cluster("hosted",2,ROOT/"work/native-shadow-vault-2j510173/config/Audit",a.source)
_winapi.CreateJunction(str(bwb),str(c.runtime/"mods/workshop-3360553731"))
(c.runtime/"mods/VaultAudit/modmain.lua").write_text((ROOT/"tests/native/bwb_compat_probe.lua").read_text(encoding="utf-8"),encoding="utf-8")
options={"enable easy mode":False,"enable hard mode":True,"role_nerf":True,"role_hunger":True,
         "autumn_change":-3,"weather_change":True,"seasons_change":False,"Shadow World":False,
         "death_curse":False,"role_battle":False,"role_sanity":False,"clock_peril":False}
def lv(v): return str(v).lower() if isinstance(v,bool) else str(v)
config=",".join("["+json.dumps(k)+"]="+lv(v) for k,v in options.items())
for name in c.names:
    (c.cluster/name/"modoverrides.lua").write_text('return {VaultAudit={enabled=true},ShadowWorld={enabled=true,configuration_options={'+config+'}},["workshop-3360553731"]={enabled='+str(not a.without_bwb).lower()+',configuration_options={}}}',encoding="utf-8")
report={"cluster":str(c.out),"source":str(a.source),"bwb_source":str(bwb),"observe_only":a.observe_only}
try:
    c.start()
    report["hunger"]=c.call("Master","BWBCompatAudit.hunger()","bwb_hunger",timeout=30)
    report["real_death"]=c.call("Master","BWBCompatAudit.real_death()","bwb_real_death",timeout=30)
    if not a.without_bwb: report["cave_clock"]=c.call("Caves","BWBCompatAudit.cave_clock()","bwb_state")
    report["summer"]=c.call("Master","BWBCompatAudit.force_seasons()","bwb_state")
    time.sleep(2)
    report["before"]={n:c.call(n,"BWBCompatAudit.state()","bwb_state") for n in c.names}
    c.call("Caves","BWBCompatAudit.prepare_sockets()","bwb_sockets_ready")
    report["gift"]=c.call("Caves","BWBCompatAudit.give_gems()","bwb_state")
    time.sleep(2)
    report["after"]={n:c.call(n,"BWBCompatAudit.state()","bwb_state") for n in c.names}
    report["second_gift"]=c.call("Caves","BWBCompatAudit.give_gems()","bwb_state")
    if not a.observe_only:
        rows=report["hunger"]["rows"]
        death=report["real_death"]
        assert death["ghost"] and death["revived"] and death["ate"] and death["after"]["own"]<death["before"]["own"],death
        assert rows["death"]["own"]>0 and rows["food"]["own"]<rows["death"]["own"], rows
        assert rows["unified"]["own"]<rows["before_unified"]["own"], rows
        assert report["after"]["Master"]["default_season"]=="autumn",report["after"]
        if not a.without_bwb: assert report["after"]["Master"]["cave_season"]=="tranquil",report["after"]
        assert report["after"]["Caves"]["season"]==("autumn" if a.without_bwb else "tranquil"),report["after"]
        assert report["second_gift"]["gems"]==3 and report["second_gift"]["powered"],report["second_gift"]
        for name in c.names: c.command(name,"c_shutdown(true)")
        for process in c.children.values(): assert process.wait(timeout=60)==0
        c.stop();c.start()
        report["reload"]={n:c.call(n,"BWBCompatAudit.load_sockets()","bwb_state") for n in c.names}
        assert report["reload"]["Master"]["default_season"]=="autumn",report["reload"]
        assert report["reload"]["Caves"]["season"]==("autumn" if a.without_bwb else "tranquil"),report["reload"]
        assert report["reload"]["Caves"]["gems"]==3 and report["reload"]["Caves"]["powered"],report["reload"]
    report["status"]="observed" if a.observe_only else "passed"
except Exception:
    report.update(status="failed",error=traceback.format_exc())
    print(report["error"],flush=True)
finally:
    c.stop()
    path=c.out/"bwb-compat-result.json"
    path.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({k:report.get(k)for k in ["status","real_death","after","second_gift","reload"]},ensure_ascii=False),flush=True)
    print(path,flush=True)
raise SystemExit(0 if report["status"] in ("passed","observed") else 1)
