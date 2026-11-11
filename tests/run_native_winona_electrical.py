"""Run electrical conversion/overcharge against the real game in disposable offline worlds."""
from pathlib import Path
import argparse
import json
import shutil
import socket
import subprocess
import tempfile
import time
import _winapi

ROOT = Path(__file__).resolve().parents[1]
GAME = Path("D:/SteamLibrary/steamapps/common/Don't Starve Together")
WORKSHOP = Path("D:/SteamLibrary/steamapps/workshop/content/322330")


def run(edition, disabled=False, *, fixture_path=None, options_extra="", um_options_extra="", source=None):
    port = None
    for candidate in range(11008, 11019):
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
            try:
                probe.bind(("0.0.0.0", candidate))
            except OSError:
                continue
            port = candidate
            break
    if port is None:
        raise RuntimeError("No free port in DST's supported test range")
    out = Path(tempfile.mkdtemp(prefix=f"winona-electric-{edition}-", dir=ROOT / "work"))
    runtime = out / "runtime"
    runtime.mkdir()
    _winapi.CreateJunction(str(GAME / "bin64"), str(runtime / "bin64"))
    _winapi.CreateJunction(str(GAME / "data"), str(runtime / "data"))
    mod = runtime / "mods/ShadowWorldLocal"
    shutil.copytree(source or ROOT / "content", mod)
    fixture = (fixture_path or ROOT / "tests/native/winona_electrical_fixture.lua").read_text(encoding="utf-8")
    with (mod / "modmain.lua").open("a", encoding="utf-8") as f:
        f.write(f'\nlocal ELECTRICAL_DISABLED = {str(disabled).lower()}\n')
        f.write(fixture)
    cluster = out / "config/Audit"
    master = cluster / "Master"
    shutil.copytree(ROOT / "work/reuse-audit/config/Audit/Master/save", master / "save")
    (cluster / "cluster.ini").write_text(
        "[GAMEPLAY]\ngame_mode=survival\nmax_players=1\npause_when_empty=false\n"
        f"[NETWORK]\nserver_port={port}\ncluster_name=ShadowWorld isolated electrical test\noffline_cluster=true\nlan_only_cluster=true\n"
        "[MISC]\nconsole_enabled=true\n[SHARD]\nshard_enabled=false\n", encoding="utf-8")
    (master / "server.ini").write_text(
        f"[NETWORK]\nserver_port={port}\n[SHARD]\nis_master=true\nname=Master\nid=1\n"
        "[STEAM]\nmaster_server_port=28971\nauthentication_port=9791\n", encoding="utf-8")
    um = ""
    if edition != "solo":
        uid = {"stable": "2039181790", "beta": "3193922031"}[edition]
        _winapi.CreateJunction(str(WORKSHOP / uid), str(runtime / "mods" / ("workshop-" + uid)))
        um = f',["workshop-{uid}"]={{enabled=true,configuration_options={{winona_items=false{um_options_extra}}}}}'
    options = '["enable hard mode"]=false,["Winona Electrical Upgrades"]=' + str(not disabled).lower() + options_extra
    (master / "modoverrides.lua").write_text(
        f'return {{ShadowWorldLocal={{enabled=true,configuration_options={{{options}}}}}{um}}}', encoding="utf-8")
    log = out / "native.log"
    print(edition, "disabled=" + str(disabled), out, flush=True)
    with log.open("wb") as f:
        p = subprocess.Popen([str(runtime / "bin64/dontstarve_dedicated_server_nullrenderer_x64.exe"),
            "-persistent_storage_root", str(out), "-conf_dir", "config", "-cluster", "Audit", "-shard", "Master",
            "-port", str(port), "-console"], cwd=runtime / "bin64", stdout=f, stderr=subprocess.STDOUT,
            creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            deadline = time.monotonic() + 110
            while p.poll() is None and time.monotonic() < deadline:
                output = log.read_bytes()
                if b"LUA ERROR" in output or b"Server failed to start" in output:
                    break
                time.sleep(0.3)
        finally:
            if p.poll() is None:
                p.terminate()
                p.wait(timeout=10)
    lines = log.read_text(encoding="utf-8", errors="replace").splitlines()
    for i, line in enumerate(lines):
        if "[ELECTRICAL]" in line or "Could not find an asset" in line:
            print(line, flush=True)
        if "LUA ERROR" in line:
            print("\n".join(lines[max(0, i-1):i+16]), flush=True)
            break
    passed = any("[ELECTRICAL] ALL_PASS" in line for line in lines) and not any("LUA ERROR" in line for line in lines)
    return {"edition": edition, "disabled": disabled, "passed": passed, "log": str(log)}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--edition", choices=("solo", "stable", "beta", "all"), default="all")
    parser.add_argument("--disabled", action="store_true")
    args = parser.parse_args()
    editions = ("solo", "stable", "beta") if args.edition == "all" else (args.edition,)
    results = [run(edition, args.disabled) for edition in editions]
    suffix = "-disabled" if args.disabled else ""
    report = ROOT / f"development/validation/winona-electrical-20261111{suffix}.json"
    report.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    print(report, flush=True)
    raise SystemExit(not all(result["passed"] for result in results))
