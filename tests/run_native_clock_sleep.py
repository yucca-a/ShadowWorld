"""Exercise clock-peril phase forcing and real tent sleep in a disposable server."""
from pathlib import Path
import argparse
import json
import sys
import traceback

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster, ROOT

parser = argparse.ArgumentParser()
parser.add_argument("--mode", type=int, choices=(1, 2), default=2)
args = parser.parse_args()
sys.stdout.reconfigure(encoding="utf-8")
c = Cluster("hosted", 1, ROOT / "work/reuse-audit/config/Audit", ROOT / "content")
(c.runtime / "mods/VaultAudit/modmain.lua").write_text(
    (ROOT / "tests/native/clock_sleep_probe.lua").read_text(encoding="utf-8"), encoding="utf-8"
)
(c.cluster / "Master/modoverrides.lua").write_text('''return {
VaultAudit={enabled=true,configuration_options={}},
ShadowWorld={enabled=true,configuration_options={
    ["enable easy mode"]=true,["enable hard mode"]=true,["role_nerf"]=true,
    ["clock_peril"]=''' + str(args.mode) + ''',
    ["Sleep In Tent Even Danger"]=true,["The tent supports multiple people sharing it"]=true
}}}''', encoding="utf-8")
report = {"cluster": str(c.out), "mode": args.mode}
try:
    c.start()
    result = c.call("Master", "VaultAudit.clock_sleep()", "clock_sleep")
    report["result"] = result
    report["cases"] = [r for r in c.events("Master") if r.get("kind") == "clock_sleep_case"]
    assert result["passed"] and result["cases"] == len(report["cases"]) == 16, result
    report["status"] = "passed"
except Exception:
    report.update(status="failed", error=traceback.format_exc())
    print(report["error"])
finally:
    c.stop()
    path = c.out / "clock-sleep-result.json"
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(path, flush=True)
raise SystemExit(0 if report["status"] == "passed" else 1)
