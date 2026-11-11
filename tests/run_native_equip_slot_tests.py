"""Exercise real DST inventory/actions in a disposable, offline native server."""
from pathlib import Path
from hashlib import sha256
from zipfile import ZipFile
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
parser.add_argument("--variant", choices=["vanilla", "patch", "full", "disabled"], default="patch")
parser.add_argument("--equip-patch-source", type=Path, help="Override only the equipment patch for before/after regression checks")
parser.add_argument("--game", type=Path, default=Path("D:/SteamLibrary/steamapps/common/Don't Starve Together"))
parser.add_argument("--seed", type=Path, default=ROOT / "work/reuse-audit/config/Audit/Master/save",
                    help="Disposable test save under this repository's work directory; never a player save")
args = parser.parse_args()
seed = args.seed.resolve()
if not seed.is_relative_to((ROOT / "work").resolve()):
    parser.error("Seed must be an isolated test save under this repository's work directory")
if not seed.is_dir():
    parser.error("Missing disposable seed; provide --seed with an existing isolated test world's Master/save")
out = Path(tempfile.mkdtemp(prefix="native-equip-slot-" + args.variant + "-", dir=ROOT / "work"))
runtime = out / "runtime"
(runtime / "bin64").mkdir(parents=True)
for source in (args.game / "bin64").iterdir():
    if source.is_file():
        shutil.copy2(source, runtime / "bin64" / source.name)
_winapi.CreateJunction(str(args.game / "data"), str(runtime / "data"))
mod = runtime / "mods/EquipSlotProbe"
if args.variant in ("full", "disabled"):
    shutil.copytree(ROOT / "content", mod)
else:
    mod.mkdir(parents=True)
    (mod / "modinfo.lua").write_text(
        'name="Equip slot probe"\nversion="1"\napi_version=10\ndst_compatible=true\nall_clients_require_mod=true\n', encoding="utf-8")
    (mod / "modmain.lua").write_text(
        'GLOBAL.setmetatable(env, {__index=function(t,k) return GLOBAL.rawget(GLOBAL,k) end})\n', encoding="utf-8")
    if args.variant == "patch":
        shutil.copy2(ROOT / "content/common/equip_slot_fix.lua", mod / "equip_slot_fix.lua")
        with (mod / "modmain.lua").open("a", encoding="utf-8") as file:
            file.write('modimport("equip_slot_fix.lua")\n')
shutil.copy2(ROOT / "tests/native/equip_slot_fixture.lua", mod / "equip_slot_fixture.lua")
if args.equip_patch_source:
    target = mod / ("equip_slot_fix.lua" if args.variant == "patch" else "common/equip_slot_fix.lua")
    shutil.copy2(args.equip_patch_source, target)
(mod / "scripts").mkdir(exist_ok=True)
shutil.copy2(ROOT / "tests/native/equip_return_fixture.lua", mod / "scripts/equip_return_fixture.lua")
shutil.copy2(ROOT / "tests/native/equip_input_fixture.lua", mod / "scripts/equip_input_fixture.lua")
# Run installed game input methods verbatim in a headless UI shell. Extract
# complete functions, including early exits and both hotkey ranges (1-10/11-15).
# These generated game sources stay in the ignored disposable test directory.
native_sources = {}
chunks = []
with ZipFile(args.game / "data/databundles/scripts.zip") as archive:
    for source, names in {
        "input.lua": ["function Input:OnControl("],
        "frontend.lua": ["function FrontEnd:OnControl("],
        "screens/playerhud.lua": ["function PlayerHud:OnControl("],
        "widgets/invslot.lua": ["function InvSlot:OnControl(", "function InvSlot:UseItem("],
        "components/playercontroller.lua": ["function PlayerController:RemoteUseItemFromInvTile("],
        "prefabs/inventory_classified.lua": ["local function IsBusy(", "local function TryNonNetworkedAction(", "local function UseItemFromInvTile("],
    }.items():
        content = archive.read("scripts/" + source).decode("utf-8-sig")
        for name in names:
            start = content.index(name)
            snippet = content[start:content.index("\nend", start) + 4]
            chunks.append(snippet)
            native_sources[source + ":" + name] = sha256(snippet.encode("utf-8")).hexdigest()
    content = archive.read("scripts/networkclientrpc.lua").decode("utf-8-sig")
    start = content.index("    UseItemFromInvTile = function(")
    snippet = content[start:content.index("\n    end,", start) + len("\n    end")]
    native_sources["networkclientrpc.lua:UseItemFromInvTile"] = sha256(snippet.encode("utf-8")).hexdigest()
    chunks.append(snippet.replace("UseItemFromInvTile = function(", "NativeUseItemRPC = function(", 1))
chunks.append("InventoryClassifiedUse = UseItemFromInvTile")
source = "\n\n".join(chunks)
assert "]====]" not in source
(mod / "scripts/equip_native_controls.lua").write_text(
    "return function(scope)\nlocal fn = assert(loadstring([====[\n" + source
    + "\n]====], '@installed_dst_input_methods'))\nsetfenv(fn, scope)\nfn()\nend\n", encoding="utf-8")
(out / "native-input-manifest.json").write_text(json.dumps(native_sources, indent=2), encoding="utf-8")
with (mod / "modmain.lua").open("a", encoding="utf-8") as file:
    file.write('\nEQUIP_SLOT_TEST_FIXED=' + ("false" if args.variant == "vanilla" else "true") + '\nmodimport("equip_slot_fixture.lua")\n')
cluster = out / "config/Audit"
master = cluster / "Master"
shutil.copytree(seed, master / "save")
(cluster / "cluster.ini").write_text("""[GAMEPLAY]
game_mode = survival
max_players = 1
pause_when_empty = false
[NETWORK]
cluster_name = ShadowWorld isolated equip slot test
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
options = '["enable easy mode"]=false,["enable hard mode"]=false' if args.variant == "disabled" else ""
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
    print("Started disposable equip test", args.variant, "PID", process.pid, "output", out, flush=True)
    try:
        process.wait(timeout=180)
    except subprocess.TimeoutExpired:
        timed_out = True
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=15)
logtext = logpath.read_text(encoding="utf-8", errors="replace")
lines = [line for line in logtext.splitlines() if "[EQUIP_SLOT_TEST]" in line or "LUA ERROR" in line]
passed = (not timed_out and process.returncode == 0 and "LUA ERROR" not in logtext
          and any("RESULT" in line and "failures=0" in line for line in lines))
result = {"pass": passed, "variant": args.variant, "exit_code": process.returncode,
          "timed_out": timed_out, "log": str(logpath), "checks": lines,
          "limitation": "Installed native Input/FrontEnd/HUD/InvSlot methods in a headless UI shell; real server items/actions; queued native client/RPC methods simulate pending messages without client prediction. No physical keyboard/mouse, rendered client or real network."}
(out / "result.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(result, ensure_ascii=False, indent=2), flush=True)
raise SystemExit(0 if passed else 1)
