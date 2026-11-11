"""Verify the reminder with native bells, inventories and mounted beefalo."""
from pathlib import Path
import json
import sys
import traceback

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster, ROOT

sys.stdout.reconfigure(encoding="utf-8")
c = Cluster("hosted", 1, ROOT / "work/reuse-audit/config/Audit", ROOT / "content")
(c.runtime / "mods/VaultAudit/modmain.lua").write_text(
    (ROOT / "tests/native/beef_bell_reminder_probe.lua").read_text(encoding="utf-8"), encoding="utf-8"
)
(c.cluster / "Master/modoverrides.lua").write_text('''return {
VaultAudit={enabled=true,configuration_options={}},
ShadowWorld={enabled=true,configuration_options={
    ["enable easy mode"]=true,["beef_bell use orangegem upgrade"]=true,["lunar shadow items"]=true
}}}''', encoding="utf-8")
report = {"cluster": str(c.out)}
try:
    c.start()
    result = c.call("Master", "VaultAudit.bell_reminder()", "bell_reminder", timeout=60)
    report["result"] = result
    report["cases"] = [r for r in c.events("Master") if r.get("kind") == "bell_reminder_case"]
    assert result["passed"] and result["cases"] == len(report["cases"]) == 3, result
    for name in ("common/common.lua", "modinfo.lua"):
        assert (c.out / "input" / name).read_bytes() == (ROOT / "content" / name).read_bytes(), name
    report["status"] = "passed"
except Exception:
    report.update(status="failed", error=traceback.format_exc())
    print(report["error"])
finally:
    c.stop()
    path = c.out / "beef-bell-reminder-result.json"
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(path, flush=True)
raise SystemExit(0 if report["status"] == "passed" else 1)
