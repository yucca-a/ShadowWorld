"""Build isolated native fixtures; does not install mods, start DST or touch saves."""
from pathlib import Path
import argparse
from datetime import datetime
import re

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("mode", choices=["speed", "crash", "savecrash", "exit"])
parser.add_argument("--run-id", default=datetime.now().strftime("%Y%m%d%H%M%S"))
args = parser.parse_args()
if not re.fullmatch(r"[a-zA-Z0-9_-]{1,40}", args.run_id):
    parser.error("run-id must contain 1-40 letters, numbers, underscores or hyphens")
fixture = "world_exchange_speed_fixture.lua" if args.mode == "speed" else "world_exchange_fast_recovery_fixture.lua"
source = (root / "tests/native" / fixture).read_text(encoding="utf-8")
if args.mode != "speed":
    source = source.replace('"boot", "crash"', f'"boot", "{args.mode}"')
    source = source.replace("sw_fast_recovery_", f"sw_fast_{args.mode}_{args.run_id}_")
    source = source.replace("KU_FastRecovery", f"KU_FastRecovery_{args.run_id}_")
    source = source.replace("KU_FastLate", f"KU_FastLate_{args.run_id}_")
output = root / "work/fast-exchange-probes" / args.run_id / args.mode
output.mkdir(parents=True, exist_ok=True)
(output / "exchange_runtime_diagnostic.lua").write_text(source, encoding="utf-8")
print(output)
