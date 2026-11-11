"""Exercise actual UM worker actions and the optional guarded compatibility repair."""
from pathlib import Path
import argparse
import json
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_native_winona_electrical import ROOT, run

parser = argparse.ArgumentParser()
parser.add_argument("--case", choices=("all", "beta", "patch-off", "worker-off", "hungry-builder", "role-off", "stable", "solo"), default="all")
args = parser.parse_args()
cases = {
    "beta": ("beta", True, True, True),
    "patch-off": ("beta", False, True, True),
    "worker-off": ("beta", True, False, True),
    "hungry-builder": ("beta", True, True, False),
    "role-off": ("beta", True, True, True),
    "stable": ("stable", True, True, True),
    "solo": ("solo", True, True, True),
}
results = []
for label in (cases if args.case == "all" else [args.case]):
    edition, patch, worker, nohungry = cases[label]
    options = ',um_patch=' + str(patch).lower() + ',["Winona No Hungry Builder"]=' + str(nohungry).lower()
    if label == "role-off": options += ',winona_easy=false'
    result = run(edition, fixture_path=ROOT / "tests/native/winona_worker_fixture.lua", options_extra=options,
        um_options_extra=",winonaworker=" + str(worker).lower())
    result["case"] = label
    results.append(result)
path = ROOT / ("development/validation/winona-worker-20261111" + ("" if args.case == "all" else "-" + args.case) + ".json")
path.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
print(path, flush=True)
raise SystemExit(not all(result["passed"] for result in results))
