"""Full-mod native tests in disposable offline worlds, never a player save."""
from pathlib import Path
import argparse
import json
import traceback
import _winapi
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster, ROOT

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--variant", choices=("default", "base", "all", "um"), default="default")
args = parser.parse_args()
variant = args.variant
c = Cluster("hosted", 1, ROOT / "work/native-shadow-vault-2j510173/config/Audit", ROOT / "content")
config = {"World Exchange": "hosted", "Container Sort": -3}
if variant != "default":
    config.update({"贝爷求生": 1, "德爷生存": 1})
if variant in ("all", "um"):
    config.update({key: 1 for key in ("种地种树需要书", "做饭需要书", "材料制造翻倍", "低san采集失败", "捡东西变慢",
        "料理禁止堆叠", "护甲失效", "空挥武器")})
encoded = ",".join("[" + json.dumps(k, ensure_ascii=False) + "]=" + json.dumps(v) for k, v in config.items())
extra = ""
if variant == "um":
    uid = "3193922031"
    _winapi.CreateJunction(str(Path("D:/SteamLibrary/steamapps/workshop/content/322330") / uid),
        str(c.runtime / "mods" / ("workshop-" + uid)))
    extra = ',["workshop-' + uid + '"]={enabled=true,configuration_options={}}'
(c.cluster / "Master/modoverrides.lua").write_text(
    'return {VaultAudit={enabled=true},ShadowWorld={enabled=true,configuration_options={' + encoded + '}}' + extra + '}', encoding="utf-8")
with (c.runtime / "mods/VaultAudit/modmain.lua").open("a", encoding="utf-8") as f:
    f.write((ROOT / "tests/native/survival_difficulty_probe.lua").read_text(encoding="utf-8"))
report = {"variant": variant, "cluster": str(c.out)}
try:
    c.start()
    result = c.call("Master", "VaultAudit.survival_difficulty(" + json.dumps(variant) + ")", "survival_difficulty")
    report["result"] = result
    assert result["passed"], result
    report["status"] = "passed"
except Exception:
    report.update(status="failed", error=traceback.format_exc())
    print(report["error"], flush=True)
finally:
    c.stop()
    path = ROOT / ("work/survival-difficulty-native-" + variant + ".json")
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(path, flush=True)
raise SystemExit(0 if report["status"] == "passed" else 1)
