"""Verify real hat/container/tool/statue entities in a disposable full-mod DST server."""
from pathlib import Path
import argparse
import json
import sys
import traceback

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster, ROOT

sys.stdout.reconfigure(encoding="utf-8")
parser = argparse.ArgumentParser()
mode = parser.add_mutually_exclusive_group()
mode.add_argument("--audit", action="store_true", help="Reproduce compatibility gaps on an unfixed source")
mode.add_argument("--fixes", action="store_true", help="Verify trap, dark axe, tilling and bottler fixes")
parser.add_argument("--source", type=Path, default=ROOT / "content", help="Mod source to copy, including a frozen pre-fix input")
args = parser.parse_args()
c = Cluster("hosted", 1, ROOT / "work/reuse-audit/config/Audit", args.source.resolve())
audit = c.runtime / "mods/VaultAudit/modmain.lua"
fixture = "antlionhat_tools_audit_probe.lua" if args.audit or args.fixes else "antlionhat_tools_probe.lua"
probe = (ROOT / "tests/native" / fixture).read_text(encoding="utf-8")
if args.fixes:
    probe = probe.replace("local VERIFY_FIXED = false", "local VERIFY_FIXED = true")
audit.write_text(probe, encoding="utf-8")
(c.cluster / "Master/modoverrides.lua").write_text('''return {
VaultAudit={enabled=true,configuration_options={}},
ShadowWorld={enabled=true,configuration_options={
    ["enable easy mode"]=true,["enable hard mode"]=true,
    ["minotaur"]=2,["ancient_statue"]=true,
    ["Multi Tool Is Almighty Tool"]=true,["Turf-Raiser Helm Plant Tree Cone"]=true
}}}''', encoding="utf-8")
report = {"cluster": str(c.out), "purpose": "fixes" if args.fixes else "audit" if args.audit else "regression"}
try:
    c.start()
    result = c.call("Master", "VaultAudit.antlionhat_tools()", "antlionhat_tools")
    report["result"] = result
    report["cases"] = [row for row in c.events("Master") if row.get("kind") == "antlionhat_case"]
    assert result["passed"], result
    assert result["cases"] == len(report["cases"]) == (27 if args.fixes else 15 if args.audit else 56), result
    report["status"] = "passed"
except Exception:
    report.update(status="failed", error=traceback.format_exc())
    print(report["error"])
finally:
    c.stop()
    path = c.out / "antlionhat-tools-result.json"
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(path, flush=True)
raise SystemExit(0 if report["status"] == "passed" else 1)
