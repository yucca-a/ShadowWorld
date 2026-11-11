"""Open real magician hats, save twice, roll back and restore native player sessions."""
from pathlib import Path
import argparse
import json
import sys
import traceback
import _winapi

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster, ROOT, freeports

sys.stdout.reconfigure(encoding="utf-8")
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--source", type=Path, default=ROOT / "content")
parser.add_argument("--audit", action="store_true", help="Expect missing hats on granted non-Maxwell characters")
parser.add_argument("--mode", choices=("classic", "xianyu", "nexus"), default="classic")
parser.add_argument("--um", action="store_true")
args = parser.parse_args()
c = Cluster("hosted", 1, ROOT / "work/reuse-audit/config/Audit", args.source.resolve())
# Keep mode suites apart even while another suite releases ports for a cold restart.
port_group = 3 if args.audit else ("classic", "xianyu", "nexus").index(args.mode)
port_base = 13000 + port_group * 100
c.ports = freeports(port_base, port_base + 100, 1)
(c.cluster / "Master/server.ini").write_text(
    f"[NETWORK]\nserver_port = {c.ports[0]}\n[SHARD]\nis_master = true\nname = Master\nid = 1\n"
    f"[STEAM]\nmaster_server_port = {33000 + port_group * 100}\nauthentication_port = {34000 + port_group * 100}\n")
cluster_ini = c.cluster / "cluster.ini"
lines = cluster_ini.read_text().splitlines()
cluster_ini.write_text("\n".join(f"master_port = {42000 + port_group * 100}" if line.startswith("master_port") else line
                                 for line in lines) + "\n")
(c.runtime / "mods/VaultAudit/modmain.lua").write_text(
    (ROOT / "tests/native/magician_rollback_probe.lua").read_text(encoding="utf-8"), encoding="utf-8")
mode = {"classic": "exchange_v1_original", "xianyu": "exchange_v1_xianyu", "nexus": "exchange_v1_nexus"}[args.mode]
config = '''return {
VaultAudit={enabled=true,configuration_options={}},
ShadowWorld={enabled=true,configuration_options={
    ["enable easy mode"]=true,["Prestihatitator Redeem shadowmagic Tag"]=true,
    ["World Exchange"]="MODE",["Container Sort"]=-3
}}
}'''.replace("MODE", mode)
if args.um:
    uid = "3193922031"
    _winapi.CreateJunction(str(Path("D:/SteamLibrary/steamapps/workshop/content/322330") / uid),
                          str(c.runtime / "mods" / ("workshop-" + uid)))
    config = config[:-1] + ',["workshop-' + uid + '"]={enabled=true,configuration_options={}}}'
(c.cluster / "Master/modoverrides.lua").write_text(config, encoding="utf-8")
report = {"cluster": str(c.out), "mode": args.mode, "um": args.um, "audit": args.audit}
try:
    c.start()
    report["prepared"] = c.call("Master", "VaultAudit.prepare()", "prepared", timeout=60)
    c.call("Master", "VaultAudit.save()", "saved", timeout=60)
    report["saved_sessions"] = c.call("Master", "VaultAudit.sessions()", "sessions")
    assert all(row["saved_hat"] for row in report["saved_sessions"]["rows"] if row["index"] != 10)
    c.call("Master", "VaultAudit.close()", "closed")
    c.call("Master", "VaultAudit.save()", "saved", timeout=60)
    before = len(c.events("Master"))
    c.command("Master", "WorldRollbackFromSim(1)")
    c.wait("Master", "ready", after=before, timeout=150)
    report["restored"] = c.call("Master", "VaultAudit.restore()", "restored", timeout=60)
    rows = report["restored"]["rows"]
    def verify(rows):
        assert len(rows) == 10, rows
        for row in rows:
            expected = 0 if args.audit and row["role"] == "wilson" and row["opened"] else 1
            assert row["hats"] == expected, row
            if expected:
                assert row["valid_hat"] and row["available"] and row["upgraded"] == row["expected_upgrade"], row
                assert abs(row["fuel"] - .43) < .01, row
                assert not row["using"] and not row["tool_user"] and row["magician"], row
    verify(rows)
    if not args.audit:
        report["reopened"] = c.call("Master", "VaultAudit.reopen()", "reopened")
        assert report["reopened"]["open"] == 9
        c.call("Master", "VaultAudit.save()", "saved", timeout=60)
        c.stop()
        c.start()
        report["restarted"] = c.call("Master", "VaultAudit.restore()", "restored", timeout=60)
        verify(report["restarted"]["rows"])
    report["status"] = "reproduced" if args.audit else "passed"
except Exception:
    report.update(status="failed", error=traceback.format_exc())
    print(report["error"], flush=True)
finally:
    c.stop()
    path = c.out / "magician-rollback-result.json"
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(path, flush=True)
raise SystemExit(0 if report["status"] != "failed" else 1)
