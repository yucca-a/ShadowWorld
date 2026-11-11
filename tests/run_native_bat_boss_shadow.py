"""Reproduce attached-bat removal and verify real shadow lifecycle in disposable DST."""
from pathlib import Path
import argparse
import hashlib
import json
import sys
import traceback
import _winapi

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster, ROOT

sys.stdout.reconfigure(encoding="utf-8")
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--before", type=Path, help="Pre-fix shadowworld.lua for crash reproduction")
parser.add_argument("--um", action="store_true", help="Also load installed UM beta")
args = parser.parse_args()
c = Cluster("hosted", 1, ROOT / "work/reuse-audit/config/Audit", ROOT / "content")
if args.before:
    (c.out / "input/shadowworld.lua").write_bytes(args.before.read_bytes())
    manifest_path = c.out / "input-manifest.json"
    manifest = json.loads(manifest_path.read_text())
    manifest["shadowworld.lua"] = hashlib.sha256(args.before.read_bytes()).hexdigest()
    manifest_path.write_text(json.dumps(manifest, indent=2))
probe = (ROOT / "tests/native/bat_boss_shadow_probe.lua").read_text(encoding="utf-8")
(c.runtime / "mods/VaultAudit/modmain.lua").write_text(probe, encoding="utf-8")
config = '''return {
VaultAudit={enabled=true,configuration_options={}},
ShadowWorld={enabled=true,configuration_options={
    ["enable hard mode"]=true,["Shadow World"]=1,["Shadow Animals"]=false,
    ["Shadow Attack Player Actively"]=false,["Shadow Harder Level"]=false
}}
}'''
if args.um:
    uid = "3193922031"
    _winapi.CreateJunction(str(Path("D:/SteamLibrary/steamapps/workshop/content/322330") / uid),
                          str(c.runtime / "mods" / ("workshop-" + uid)))
    config = config[:-1] + ',["workshop-' + uid + '"]={enabled=true,configuration_options={}}}'
(c.cluster / "Master/modoverrides.lua").write_text(config, encoding="utf-8")
report = {"cluster": str(c.out), "before": str(args.before) if args.before else None, "um": args.um}
try:
    c.start()
    report["result"] = result = c.call("Master", "VaultAudit.bat_shadow()", "bat_shadow", timeout=60)
    assert not args.before, "Pre-fix code unexpectedly survived"
    assert result["passed"], result
    report["cases"] = [r for r in c.events("Master") if r.get("kind") == "bat_shadow_case"]
    assert len(report["cases"]) == result["cases"] == 10, result
    report["status"] = "passed"
except Exception:
    error = traceback.format_exc()
    raw = c.logs["Master"].read_text(encoding="utf-8", errors="replace")
    if args.before and all(s in raw for s in ("physicstask", "SGbat.lua", "onunequipfn", "shadowworld.lua")):
        report.update(status="reproduced", error=raw[raw.index("LUA ERROR"):][-9000:])
        print("Reproduced attached-bat physicstask crash", flush=True)
    else:
        report.update(status="failed", error=error)
        print(error, flush=True)
finally:
    c.stop()
    path = c.out / "bat-boss-shadow-result.json"
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(path, flush=True)
raise SystemExit(0 if report["status"] in ("passed", "reproduced") else 1)
