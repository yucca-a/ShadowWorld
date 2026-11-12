"""Verify idle-task optimizations using real entities in an isolated offline DST server."""
from pathlib import Path
import json
import sys
import traceback
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster, ROOT

c = Cluster("hosted", 1, ROOT / "work/reuse-audit/config/Audit", ROOT / "content")
(c.runtime / "mods/VaultAudit/modmain.lua").write_text(
    (ROOT / "tests/native/performance_phase1_probe.lua").read_text(encoding="utf-8"), encoding="utf-8"
)
(c.cluster / "Master/modoverrides.lua").write_text('''return {
VaultAudit={enabled=true,configuration_options={}},
ShadowWorld={enabled=true,configuration_options={
    ["enable easy mode"]=true,["enable hard mode"]=true,["minotaur"]=2,
    ["epic_armor_5"]="dynamic",["epic_ruin"]=0.8,["clock_peril"]=false,
    ["Shadow World"]=false,["Random Sized"]=false,["World Exchange"]="classic"
}}}''', encoding="utf-8")
report = {"cluster": str(c.out), "phases": []}
try:
    c.start()
    for index in range(1, 21):
        result = c.call("Master", f"VaultAudit.step({index})", "performance_phase1", phase=index)
        report["phases"].append(result)
        assert result["passed"], result
        print(json.dumps(result, ensure_ascii=False), flush=True)
    report["status"] = "passed"
except Exception:
    report.update(status="failed", error=traceback.format_exc())
    print(report["error"], flush=True)
finally:
    c.stop()
    path = c.out / "performance-phase1-result.json"
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(path, flush=True)
raise SystemExit(0 if report["status"] == "passed" else 1)
