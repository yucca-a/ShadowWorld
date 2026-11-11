"""Observe native Halloween housing with/without Shadow World over normal restarts."""
from pathlib import Path
import argparse, json, sys, traceback, _winapi
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster, ROOT

sys.stdout.reconfigure(encoding="utf-8")
p = argparse.ArgumentParser(description=__doc__)
p.add_argument("--mode", choices=["vanilla", "off", "on"], default="on")
p.add_argument("--um", choices=["none", "beta", "stable"], default="none")
p.add_argument("--event-off", action="store_true")
p.add_argument("--rounds", type=int, default=2)
p.add_argument("--source", type=Path, default=ROOT / "content")
p.add_argument("--verify", action="store_true", help="Require matching event forms, bounded residents and native shadow cleanup")
a = p.parse_args()
c = Cluster("hosted", 1, ROOT / "work/reuse-audit/config/Audit", a.source)
fixture = "POPULATION_EVENT=" + str(not a.event_off).lower() + "\n" + (ROOT / "tests/native/hallowed_population_probe.lua").read_text(encoding="utf-8")
(c.runtime / "mods/VaultAudit/modmain.lua").write_text(fixture, encoding="utf-8")
extras = ""
if a.um != "none":
    uid = {"beta": "3193922031", "stable": "2039181790"}[a.um]
    _winapi.CreateJunction(str(Path("D:/SteamLibrary/steamapps/workshop/content/322330") / uid), str(c.runtime / "mods" / ("workshop-" + uid)))
    extras = ',["workshop-' + uid + '"]={enabled=true}'
shadow = '1' if a.mode == "on" else 'false'
enabled = str(a.mode != "vanilla").lower()
(c.cluster / "Master/modoverrides.lua").write_text('''return {
VaultAudit={enabled=true},ShadowWorld={enabled=''' + enabled + ''',configuration_options={
["enable easy mode"]=true,["enable hard mode"]=true,
["Shadow World"]=''' + shadow + ''',["Shadow Animals"]=1,["Shadow Num Limit"]=false,
["Shadow Attack Player Actively"]=false,["Shadow Harder Level"]=false,
["rangesupermonster"]=false,["specialsupermonster"]=false
}}''' + extras + '}', encoding="utf-8")
r = {"cluster": str(c.out), "source":str(a.source), "mode": a.mode, "um": a.um, "event": not a.event_off, "snapshots": [], "cleanup":[]}
try:
    c.start()
    r["setup"] = c.call("Master", "VaultAudit.population_setup()", "population_setup", timeout=30)
    assert r["setup"]["event"] == (not a.event_off)
    for i in range(a.rounds + 1):
        if i:
            c.command("Master", "c_shutdown(true)")
            assert c.children["Master"].wait(timeout=45) == 0
            c.stop(); c.start()
        r["snapshots"].append(c.call("Master", f'VaultAudit.population_sample("loaded_{i}")', "population_sample"))
        r["snapshots"].append(c.call("Master", f'VaultAudit.population_exercise("cycled_{i}")', "population_sample", timeout=30))
        r["snapshots"].append(c.call("Master", f'VaultAudit.population_lifecycle("lifecycle_{i}")', "population_sample", timeout=30))
        r["cleanup"].append(c.call("Master", f'VaultAudit.population_cleanup("cleanup_{i}")', "population_cleanup", timeout=30))
    r["events"] = c.events("Master")
    if a.verify:
        for snapshot in r["snapshots"]:
            for row in snapshot["rows"]:
                assert row["real"] <= row["max"], (snapshot["label"], row)
                assert row["shadow"] <= row["real"], (snapshot["label"], row)
                assert all(row[key] == 0 for key in ["untracked", "wronghome", "clonespawner", "shadowtracked", "formmismatch", "shadowpersist"]), (snapshot["label"], row)
        assert all(x["remaining"] == 0 for x in r["cleanup"]), r["cleanup"]
        lifecycle = [s["lifecyclecleanup"] for s in r["snapshots"] if s["label"].startswith("lifecycle_")]
        assert all(x["remaining"] == 0 for x in lifecycle), lifecycle
        if a.mode == "on":
            assert all(x["attempted"] > 0 for x in r["cleanup"]), r["cleanup"]
            if not a.event_off:
                rows = r["snapshots"][2]["rows"]
                assert rows[1]["shadowmummy"] == rows[1]["shadow"] > 0, rows[1]
                assert rows[4]["shadow"] > 0 and rows[4]["shadowfranken"] == 0, rows[4]
                assert rows[5]["shadowfranken"] == rows[5]["shadow"] > 0, rows[5]
    r["status"] = "passed" if a.verify else "observed"
except Exception:
    r.update(status="failed", error=traceback.format_exc()); print(r["error"], flush=True)
finally:
    c.stop()
    out = c.out / "hallowed-population-result.json"
    out.write_text(json.dumps(r, ensure_ascii=False, indent=2), encoding="utf-8")
    print(out, flush=True)
raise SystemExit(0 if r["status"] in ["observed", "passed"] else 1)
