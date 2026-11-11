"""Record actual song healing on bosses in each UM edition before/after repair."""
import argparse
import json
from pathlib import Path
from run_native_winona_electrical import ROOT, run

parser = argparse.ArgumentParser()
parser.add_argument("--edition", choices=("solo", "stable", "beta", "all"), default="all")
parser.add_argument("--label", default="audit")
args = parser.parse_args()
results = []
for edition in (("stable", "beta") if args.edition == "all" else (args.edition,)):
    result = run(edition, fixture_path=ROOT / "tests/native/wigfrid_recovery_audit.lua",
                 options_extra=',["enable hard mode"]=true,["Shadow World"]=false,["Random Sized"]=false')
    text = Path(result["log"]).read_text(encoding="utf-8", errors="replace")
    result["cases"] = [json.loads(line.split("WIG_CASE", 1)[1].strip())
                       for line in text.splitlines() if "[ELECTRICAL] WIG_CASE" in line]
    required = {(target, label) for target in ("antlion", "bearger")
                for label in ("matching_target", "no_stored_target", "stale_passive_target")}
    required.add(("bearger", "near_punchingbag"))
    measured = {(case["target"], case["label"]): case for case in result["cases"]}
    result["recovery_verified"] = all(
        key in measured and measured[key]["hits"] == 1 and measured[key]["damage"] > 0
        and measured[key]["health"] > 0 and measured[key]["sanity"] > 0
        and measured[key]["health_song"] and measured[key]["sanity_song"] for key in required)
    if args.label != "before":
        result["passed"] = result["passed"] and result["recovery_verified"]
    results.append(result)
path = ROOT / ("development/validation/wigfrid-recovery-20261111-" + args.label + ".json")
path.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
print(path)
raise SystemExit(not all(r["passed"] for r in results))
