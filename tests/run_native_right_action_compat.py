"""Real prefabs and medal in a disposable offline server; no player saves used."""
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
MEDAL = Path("D:/SteamLibrary/steamapps/workshop/content/322330/1909182187")
parser = argparse.ArgumentParser()
parser.add_argument("--probe", choices=("right-action", "random-trap"), default="right-action")
args = parser.parse_args()
capture = args.probe == "random-trap"
marker = "[RANDOM_TRAP]" if capture else "[RIGHT_ACTION]"
cluster_name = "ShadowWorld isolated random trap test" if capture else "ShadowWorld isolated right action test"
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
out = Path(tempfile.mkdtemp(prefix="native-" + args.probe + "-", dir=ROOT / "work"))
runtime = out / "runtime"
runtime.mkdir()
for name in ("bin64", "data"):
    _winapi.CreateJunction(str(GAME / name), str(runtime / name))
mod = runtime / "mods/ShadowWorldLocal"
shutil.copytree(ROOT / "content", mod)
if not capture:
    _winapi.CreateJunction(str(MEDAL), str(runtime / "mods/workshop-1909182187"))
with (mod / "modmain.lua").open("a", encoding="utf-8") as f:
    fixture = "random_trap_fixture.lua" if capture else "right_action_compat_fixture.lua"
    f.write("\n" + (ROOT / "tests/native" / fixture).read_text(encoding="utf-8"))
master = out / "config/Audit/Master"
shutil.copytree(ROOT / "work/reuse-audit/config/Audit/Master/save", master / "save")
(master.parent / "cluster.ini").write_text(
    "[GAMEPLAY]\ngame_mode=survival\nmax_players=1\npause_when_empty=false\n"
    f"[NETWORK]\nserver_port={port}\ncluster_name={cluster_name}\noffline_cluster=true\nlan_only_cluster=true\n"
    "[MISC]\nconsole_enabled=true\n[SHARD]\nshard_enabled=false\n", encoding="utf-8")
(master / "server.ini").write_text(
    f"[NETWORK]\nserver_port={port}\n[SHARD]\nis_master=true\nname=Master\nid=1\n"
    "[STEAM]\nmaster_server_port=28973\nauthentication_port=9793\n", encoding="utf-8")
(master / "modoverrides.lua").write_text(
    'return {ShadowWorldLocal={enabled=true,configuration_options={'
    '["enable hard mode"]=false,["All Right Dodge"]=true,["aoespell change"]=false,'
    '["right Wrapback need ctrl"]=false,["right Lunge need ctrl"]=false,'
    '["Random Sized"]=1,["Trap Guaranteed Catch"]=true}}'
    + (',["workshop-1909182187"]={enabled=true,configuration_options={}}' if not capture else '')
    + '}', encoding="utf-8")
log = out / "native.log"
print(out, flush=True)
with log.open("wb") as f:
    process = subprocess.Popen(
        [str(runtime / "bin64/dontstarve_dedicated_server_nullrenderer_x64.exe"),
         "-persistent_storage_root", str(out), "-conf_dir", "config", "-cluster", "Audit",
         "-shard", "Master", "-port", str(port), "-console"], cwd=runtime / "bin64",
        stdout=f, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
    try:
        deadline = time.monotonic() + 100
        while process.poll() is None and time.monotonic() < deadline:
            output = log.read_bytes()
            if b"LUA ERROR" in output or b"Server failed to start" in output:
                break
            time.sleep(0.3)
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=10)
lines = log.read_text(encoding="utf-8", errors="replace").splitlines()
for i, line in enumerate(lines):
    if marker in line:
        print(line)
    if "LUA ERROR" in line:
        print("\n".join(lines[max(0, i - 1):i + 18]))
        break
passed = any(marker + " ALL_PASS" in line for line in lines) and not any("LUA ERROR" in line for line in lines)
limits = ("Offline server uses real creatures, traps, inventory, save records and native murder; stackability is supplied by a fixture component, not a particular stack mod. No rendered client."
          if capture else "Offline native server checks action selection with real prefabs/medal. Ctrl is supplied on fixture controllers. No rendered client or specific cross-character skill-tree patch tested.")
report = {"passed": passed, "log": str(log), "checks": [line for line in lines if marker in line], "limitations": limits}
path = ROOT / ("development/validation/" + ("random-trap" if capture else "right-action-compat") + "-native-20261111.json")
path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
print(path)
raise SystemExit(not passed)
