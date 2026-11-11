"""Dedicated-server current UM queen-torch AI test and labelled wrong-argument control."""
from pathlib import Path
import argparse
import hashlib
import json
import sys
import time
import traceback
import _winapi

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster, ROOT

sys.stdout.reconfigure(encoding="utf-8")
p = argparse.ArgumentParser(description=__doc__)
p.add_argument("--mode", choices=["um", "combined"], required=True)
p.add_argument("--historical-control", action="store_true")
a = p.parse_args()
c = Cluster("hosted", 1, ROOT / "work/reuse-audit/config/Audit", ROOT / "content")
uid = "3193922031"
source = ROOT / "work/newconstant-research/steamcmd/steamapps/workshop/content/322330" / uid
_winapi.CreateJunction(str(source), str(c.runtime / "mods" / ("workshop-" + uid)))
fixture = 'QUEEN_MODE=' + json.dumps(a.mode) + '\n'
fixture += (ROOT / "tests/native/queen_torch_probe.lua").read_text(encoding="utf-8")
(c.runtime / "mods/VaultAudit/modmain.lua").write_text(fixture, encoding="utf-8")
config = '''return {
VaultAudit={enabled=true},
ShadowWorld={enabled=COMBINED,configuration_options={
    ["enable easy mode"]=true,["enable hard mode"]=true,["um_patch"]=true,
    ["Shadow World"]=false,["rangesupermonster"]=false,["specialsupermonster"]=false}},
["workshop-3193922031"]={enabled=true,configuration_options={}}
}'''.replace("COMBINED", str(a.mode == "combined").lower())
(c.cluster / "Master/modoverrides.lua").write_text(config, encoding="utf-8")
relevant = ["modinfo.lua", "scripts/brains/dreadeyebrain.lua", "scripts/brains/trepidationbrain.lua",
            "scripts/brains/viperlingbrain.lua", "scripts/prefabs/dreadeye.lua"]
report = {"cluster": str(c.out), "mode": a.mode, "um_source": str(source),
          "source_sha256": {n: hashlib.sha256((source / n).read_bytes()).hexdigest() for n in relevant},
          "historical_control_is_artificial": True, "modoverrides": config}
try:
    c.start()
    report["startup"] = c.call("Master", 'print("[VAUDIT] "..require("json").encode({kind="queen_metadata",dedicated=TheNet:IsDedicated(),version=APP_VERSION}))', "queen_metadata")
    report["normal"] = c.call("Master", "VaultAudit.run()", "queen_done", timeout=90)
    assert report["normal"]["passed"], report["normal"]
    c.command("Master", "c_shutdown(true)")
    assert c.children["Master"].wait(timeout=45) == 0
    c.stop()
    c.start()
    report["reload"] = c.call("Master", "VaultAudit.after_reload()", "queen_reload", timeout=25)
    assert report["reload"]["passed"], report["reload"]
    report["normal_status"] = "passed_no_crash"
    if a.historical_control:
        # Generic Cluster.events intentionally rejects any LUA ERROR. The
        # positive-control marker and expected error can arrive in one read,
        # so observe raw logs here instead of using that normal-test checker.
        c.command("Master", "VaultAudit.invalid_argument_control()")
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            raw = c.logs["Master"].read_text(encoding="utf-8", errors="replace")
            if '"kind":"historical_control_start"' in raw and "LUA ERROR" in raw:
                break
            time.sleep(.15)
        else:
            raise AssertionError("Artificial wrong-argument control did not produce native LUA ERROR")
        assert "queen_torch.lua:39" in raw and "runaway.lua:121" in raw, raw[-7000:]
        marker = raw.index('"kind":"historical_control_start"')
        assert "LUA ERROR" not in raw[:marker], "Unexpected crash before artificial control"
        report["historical_control"] = {"status": "native_crash_reproduced_with_deliberately_wrong_argument",
                                         "log": str(c.logs["Master"]), "excerpt": raw[raw.index("LUA ERROR"):][-6500:]}
    report["status"] = "passed"
except Exception:
    report.update(status="failed", error=traceback.format_exc())
    print(report["error"], flush=True)
finally:
    c.stop()
    out = c.out / "queen-torch-result.json"
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(out, flush=True)
    print("STATUS", report["status"], flush=True)
raise SystemExit(0 if report["status"] == "passed" else 1)
