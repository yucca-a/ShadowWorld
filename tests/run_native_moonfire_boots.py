"""Actual sword casts/recharge and slipperyfeet ownership/removal in disposable DST."""
from pathlib import Path
import argparse, json, sys, traceback, _winapi

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster, ROOT

sys.stdout.reconfigure(encoding="utf-8")
p = argparse.ArgumentParser(description=__doc__)
p.add_argument("--um", choices=["none", "stable", "beta"], default="beta")
p.add_argument("--before", action="store_true")
args = p.parse_args()
source = ROOT / ("work/vault-hardened-hosted-ot54qttt/input" if args.before else "content")
c = Cluster("hosted", 1, ROOT / "work/reuse-audit/config/Audit", source)
(c.runtime / "mods/VaultAudit/modmain.lua").write_text(
    "FIX_BEFORE=" + str(args.before).lower() + "\n" +
    (ROOT / "tests/native/moonfire_boots_probe.lua").read_text(encoding="utf-8"), encoding="utf-8")
extra = ""
if args.um != "none":
    uid = {"stable": "2039181790", "beta": "3193922031"}[args.um]
    _winapi.CreateJunction(str(Path("D:/SteamLibrary/steamapps/workshop/content/322330") / uid),
                          str(c.runtime / "mods" / ("workshop-" + uid)))
    extra = ',["workshop-' + uid + '"]={enabled=true}'
(c.cluster / "Master/modoverrides.lua").write_text('''return {
VaultAudit={enabled=true},ShadowWorld={enabled=true,configuration_options={
["enable easy mode"]=true,["enable hard mode"]=true,["Shadow World"]=false,
["rangesupermonster"]=false,["specialsupermonster"]=false,
["Celestial Jewel Upgrade Sword Lunarplant"]=true,["sharkboi"]=false
}}''' + extra + '}', encoding="utf-8")
report = {"cluster": str(c.out), "um": args.um, "before": args.before}
try:
    c.start()
    for kind in ["moonfire", "boots"]:
        result = c.call("Master", "VaultAudit." + kind + "()", kind, timeout=75)
        report[kind] = result
        assert result["passed"], result
    report["status"] = "reproduced" if args.before else "passed"
except Exception:
    report.update(status="failed", error=traceback.format_exc())
    print(report["error"], flush=True)
finally:
    c.stop()
    path = c.out / "moonfire-boots-result.json"
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(path, flush=True)
raise SystemExit(0 if report["status"] != "failed" else 1)
