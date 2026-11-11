"""Exercise real surprise gifts and native delayed unwrapping in an isolated server."""
from pathlib import Path
import _winapi
import argparse
import json
import random
import shutil
import socket
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--variant", choices=["on", "off"], default="on")
parser.add_argument("--patch-source", type=Path, help="Override cheap_wrap.lua for before/after regression checks")
parser.add_argument("--game", type=Path, default=Path("D:/SteamLibrary/steamapps/common/Don't Starve Together"))
parser.add_argument("--seed", type=Path, default=ROOT / "work/reuse-audit/config/Audit/Master/save",
                    help="Disposable test save under this repository's work directory; never a player save")
args = parser.parse_args()
seed = args.seed.resolve()
if not seed.is_relative_to((ROOT / "work").resolve()):
    parser.error("Seed must be an isolated test save under this repository's work directory")
if not seed.is_dir():
    parser.error("Missing disposable seed; provide --seed with an existing isolated test world's Master/save")
out = Path(tempfile.mkdtemp(prefix="native-gift-unwrap-" + args.variant + "-", dir=ROOT / "work"))
runtime = out / "runtime"
(runtime / "bin64").mkdir(parents=True)
for source in (args.game / "bin64").iterdir():
    if source.is_file():
        shutil.copy2(source, runtime / "bin64" / source.name)
_winapi.CreateJunction(str(args.game / "data"), str(runtime / "data"))
mod = runtime / "mods/EquipSlotProbe"
shutil.copytree(ROOT / "content", mod)
if args.patch_source:
    shutil.copy2(args.patch_source, mod / "tech/cheap_wrap.lua")
shutil.copy2(ROOT / "tests/native/gift_unwrap_fixture.lua", mod / "gift_unwrap_fixture.lua")
with (mod / "modmain.lua").open("a", encoding="utf-8") as file:
    file.write('\nGIFT_TEST_CHEAP=' + ("false" if args.variant == "off" else "true") + '\nmodimport("gift_unwrap_fixture.lua")\n')
cluster = out / "config/Audit"
master = cluster / "Master"
shutil.copytree(seed, master / "save")
(cluster / "cluster.ini").write_text("""[GAMEPLAY]
game_mode = survival
max_players = 1
pause_when_empty = false
[NETWORK]
cluster_name = ShadowWorld isolated gift unwrap test
offline_cluster = true
lan_only_cluster = true
[MISC]
console_enabled = true
[SHARD]
shard_enabled = false
""", encoding="utf-8")
ports = []
# Offline LAN worlds reject ports outside this native range and fall back to
# 10999, which would make concurrent isolated tests collide.
lan_ports = list(range(10998, 11019))
random.SystemRandom().shuffle(lan_ports)
for port in lan_ports:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_EXCLUSIVEADDRUSE, 1)
        try:
            sock.bind(("0.0.0.0", port))
        except OSError:
            continue
        ports.append(port)
        break
if not ports:
    raise SystemExit("No free DST LAN test port")
while len(ports) < 3:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
        if port not in ports:
            ports.append(port)
(master / "server.ini").write_text(
    f"[NETWORK]\nserver_port={ports[0]}\n[SHARD]\nis_master=true\nname=Master\nid=1\n"
    f"[STEAM]\nmaster_server_port={ports[1]}\nauthentication_port={ports[2]}\n", encoding="utf-8")
options = '["enable hard mode"]=true,["other_change"]=true,["cheap_wrap"]=' + ("false" if args.variant == "off" else "true")
(master / "modoverrides.lua").write_text(
    'return {EquipSlotProbe={enabled=true,configuration_options={' + options + '}}}', encoding="utf-8")
logpath = out / "native.log"
timed_out = False
with logpath.open("wb") as log:
    process = subprocess.Popen([
        str(runtime / "bin64/dontstarve_dedicated_server_nullrenderer_x64.exe"),
        "-persistent_storage_root", str(out), "-conf_dir", "config", "-cluster", "Audit",
        "-shard", "Master", "-port", str(ports[0]),
    ], cwd=runtime / "bin64", stdout=log, stderr=subprocess.STDOUT,
        creationflags=subprocess.CREATE_NO_WINDOW)
    print("Started disposable gift test", args.variant, "PID", process.pid, "output", out, flush=True)
    try:
        process.wait(timeout=180)
    except subprocess.TimeoutExpired:
        timed_out = True
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=15)
logtext = logpath.read_text(encoding="utf-8", errors="replace")
lines = [line for line in logtext.splitlines() if "[GIFT_UNWRAP_TEST]" in line or "LUA ERROR" in line]
passed = (not timed_out and process.returncode == 0 and "LUA ERROR" not in logtext
          and any("RESULT" in line and "failures=0" in line for line in lines))
result = {"pass": passed, "variant": args.variant, "exit_code": process.returncode,
          "timed_out": timed_out, "log": str(logpath), "checks": lines,
          "limitation": "Native gift entities, actions, delayed tasks, scenario callbacks and component save/load in an isolated headless server; no rendered client or physical input."}
(out / "result.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(result, ensure_ascii=False, indent=2), flush=True)
raise SystemExit(0 if passed else 1)
