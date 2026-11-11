"""Disposable DST: silksack custody, Wathom staff attacks, WX-78 descriptions."""
from pathlib import Path
import argparse, hashlib, json, sys, traceback, _winapi

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster, ROOT

sys.stdout.reconfigure(encoding="utf-8")
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--um", choices=["stable", "beta"], default="beta")
parser.add_argument("--before", action="store_true")
parser.add_argument("--optional-off", action="store_true")
parser.add_argument("--packing", action="store_true", help="Bell payload transfer, read-only peeking and restart")
args = parser.parse_args()
if args.packing and (args.um != "beta" or args.before):
    parser.error("--packing requires the beta mod and the current implementation")
c = Cluster("hosted", 1, ROOT / "work/reuse-audit/config/Audit", ROOT / "content")
if args.before:
    main = c.out / "input/modmain.lua"
    main.write_text(main.read_text(encoding="utf-8").replace(
        'if TUNING.DSTU then modimport("common/um_compat_fixes.lua") end', ''), encoding="utf-8")
    common = c.out / "input/common/common.lua"
    common.write_text(common.read_text(encoding="utf-8").replace(
        'if type(script) == "string" then script = script:gsub("only_used_by_[%w_]+", "") end',
        'if script and type(script) == "string" and string.find(script, "only_used_by_") then script = "" end'), encoding="utf-8")
    wathom = c.out / "input/easy_role/wathom_easy.lua"
    wathom.write_text(wathom.read_text(encoding="utf-8").replace(
        '(weapon:HasTag("icestaff") or weapon.prefab == "firestaff")',
        '(weapon.prefab == "icestaff" or weapon.prefab == "firestaff")'), encoding="utf-8")
uid = {"stable": "2039181790", "beta": "3193922031"}[args.um]
_winapi.CreateJunction(str(Path("D:/SteamLibrary/steamapps/workshop/content/322330") / uid),
                      str(c.runtime / "mods" / ("workshop-" + uid)))
(c.runtime / "mods/VaultAudit/modmain.lua").write_text(
    "UM_COMPAT_BEFORE=" + str(args.before).lower() + "\nUM_COMPAT_BETA=" + str(args.um == "beta").lower() + "\n" +
    (ROOT / ("tests/native/beef_bell_packing_probe.lua" if args.packing else "tests/native/um_compat_fixes_probe.lua")).read_text(encoding="utf-8"), encoding="utf-8")
options = {
    "enable easy mode": True, "enable hard mode": True, "role_easy": True,
    "other_role_easy": True, "wathom upgrade": 2, "role_nerf": True,
    "beef_bell use orangegem upgrade": True, "lunar shadow items": True,
    "Prestihatitator Redeem shadowmagic Tag": True, "minotaur": 2, "nutrient": -3,
    "food_change": True, "um_patch": not args.optional_off,
    "Language In Game": -1, "Shadow World": False,
    "rangesupermonster": False, "specialsupermonster": False,
}
def lua_value(value):
    return str(value).lower() if isinstance(value, bool) else str(value)
config = ",".join("[" + json.dumps(k) + "]=" + lua_value(v) for k, v in options.items())
(c.cluster / "Master/modoverrides.lua").write_text(
    'return {VaultAudit={enabled=true},ShadowWorld={enabled=true,configuration_options={' + config +
    '}},["workshop-' + uid + '"]={enabled=true}}', encoding="utf-8")
manifest = {str(p.relative_to(c.out / "input")): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in (c.out / "input").rglob("*") if p.is_file()}
(c.out / "input-manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
report = {"cluster": str(c.out), "um": args.um, "before": args.before, "optional_off": args.optional_off, "packing": args.packing}
try:
    c.start()
    kind = "bell_packing" if args.packing else "um_compat"
    result = c.call("Master", "VaultAudit." + kind + "()", kind, timeout=120)
    report["result"] = result
    report["cases"] = [r for r in c.events("Master") if r.get("kind") == ("bell_packing_case" if args.packing else "um_compat_case")]
    assert result["passed"], report
    assert result["cases"] == len(report["cases"]) == (7 if args.packing else 12 if args.um == "beta" else 10), report
    if args.packing:
        c.command("Master", "c_shutdown(true)")
        assert c.children["Master"].wait(timeout=45) == 0
        c.stop()
        c.start()
        restart = c.call("Master", "VaultAudit.bell_packing_restart()", "bell_packing_restart", timeout=30)
        report["restart"] = restart
        assert restart["passed"], restart
    elif not args.before:
        casts = c.call("Master", "VaultAudit.um_staff_casts()", "um_staff_casts", timeout=30)
        report["casts"] = casts
        assert casts["passed"] and casts["checks"] == 10, casts
        report["cast_cases"] = [r for r in c.events("Master") if r.get("name", "").startswith("wathom_real_cast_")]
    report["status"] = "reproduced" if args.before else "passed"
except Exception:
    report.update(status="failed", error=traceback.format_exc())
    print(report["error"], flush=True)
finally:
    c.stop()
    path = c.out / "um-compat-result.json"
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(path, flush=True)
raise SystemExit(0 if report["status"] != "failed" else 1)
