"""Native classic pause RPC, manual resume and real 30 second timeout."""
from pathlib import Path
import argparse
import _winapi
import json
import random
import shutil
import socket
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
GAME = Path("D:/SteamLibrary/steamapps/common/Don't Starve Together")
parser = argparse.ArgumentParser(description=__doc__)
args = parser.parse_args()
out = Path(tempfile.mkdtemp(prefix="native-classic-pause-", dir=ROOT / "work"))
runtime = out / "runtime"
(runtime / "bin64").mkdir(parents=True)
for file in (GAME / "bin64").iterdir():
    if file.is_file(): shutil.copy2(file, runtime / "bin64" / file.name)
_winapi.CreateJunction(str(GAME / "data"), str(runtime / "data"))
mod = runtime / "mods/ElixirProbe"
shutil.copytree(ROOT / "content", mod)
shutil.copy2(ROOT / "tests/native/classic_pause_fixture.lua", mod / "fixture.lua")
with (mod / "modmain.lua").open("a", encoding="utf-8") as file:
    file.write('\nmodimport("fixture.lua")\n')
master = out / "config/Audit/Master"
shutil.copytree(ROOT / "work/reuse-audit/config/Audit/Master/save", master / "save")
(master.parent / "cluster.ini").write_text("""[GAMEPLAY]
game_mode = survival
pause_when_empty = false
[NETWORK]
cluster_name = ShadowWorld isolated classic pause test
offline_cluster = true
lan_only_cluster = true
[MISC]
console_enabled = true
[SHARD]
shard_enabled = false
""", encoding="utf-8")
ports = []
candidates = list(range(10998, 11019))
random.SystemRandom().shuffle(candidates)
for port in candidates:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        try: sock.bind(("0.0.0.0", port))
        except OSError: continue
        ports.append(port)
        break
if not ports: raise SystemExit("No available LAN test port")
while len(ports) < 3:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
        if port not in ports: ports.append(port)
(master / "server.ini").write_text(f"[NETWORK]\nserver_port={ports[0]}\n[SHARD]\nis_master=true\nname=Master\nid=1\n[STEAM]\nmaster_server_port={ports[1]}\nauthentication_port={ports[2]}\n", encoding="utf-8")
options = '["World Exchange"]="exchange_v1_original",["Container Sort"]=-3'
(master / "modoverrides.lua").write_text('return {ElixirProbe={enabled=true,configuration_options={' + options + '}}}', encoding="utf-8")
logpath = out / "native.log"
with logpath.open("wb") as log:
    process = subprocess.Popen([str(runtime / "bin64/dontstarve_dedicated_server_nullrenderer_x64.exe"), "-persistent_storage_root", str(out), "-conf_dir", "config", "-cluster", "Audit", "-shard", "Master", "-port", str(ports[0])], cwd=runtime / "bin64", stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
    print("Started classic pause test", process.pid, out, flush=True)
    try: process.wait(timeout=180)
    finally:
        if process.poll() is None: process.terminate(); process.wait(timeout=15)
text = logpath.read_text(encoding="utf-8", errors="replace")
lines = [line for line in text.splitlines() if "[CLASSIC_PAUSE_TEST]" in line or "LUA ERROR" in line]
passed = process.returncode == 0 and "LUA ERROR" not in text and any("RESULT" in line and "failures=0" in line for line in lines)
result = {"pass": passed, "log": str(logpath), "checks": lines, "limitation": "Real server RPC handler and 30 second timer; pause requests forwarded to engine, reads use requested state because no client is connected. Actual engine pause and remote-client clicks are not verified."}
(out / "result.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(result, ensure_ascii=False, indent=2), flush=True)
raise SystemExit(0 if passed else 1)
