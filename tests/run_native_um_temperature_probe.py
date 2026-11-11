"""Run the real game and the installed Workshop build in an isolated copy of a surface save."""
import argparse
from pathlib import Path
import shutil
import subprocess
import time
import _winapi

parser = argparse.ArgumentParser()
parser.add_argument("mode", choices=["default", "legacy1", "legacy2", "legacy3", "off", "um-disabled"])
parser.add_argument("edition", choices=["stable", "beta"])
parser.add_argument("--game", type=Path, default=Path("D:/SteamLibrary/steamapps/common/Don't Starve Together"))
parser.add_argument("--workshop", type=Path, default=Path("D:/SteamLibrary/steamapps/workshop/content/322330"))
parser.add_argument("--save", type=Path, default=Path("work/reuse-audit/config/Audit/Master/save"))
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
out = root / "work" / f"um-temperature-{args.edition}-{args.mode}-{time.strftime('%H%M%S')}"
runtime = out / "runtime"
shutil.copytree(args.game / "bin64", runtime / "bin64")
_winapi.CreateJunction(str(args.game.resolve() / "data"), str(runtime / "data"))
mods = runtime / "mods"
probe = mods / "UMTemperatureProbe"
probe.mkdir(parents=True)
(probe / "modinfo.lua").write_text(
    'name="UM Temperature Probe"\ndescription="Native regression"\nauthor="Local"\nversion="1"\napi_version=10\n'
    'dst_compatible=true\nserver_only_mod=true\nall_clients_require_mod=false\npriority=-99999\n'
    'configuration_options={{name="probe_mode",default="default",options={}}}\n', encoding="utf-8")
shutil.copyfile(root / "tests/native/um_temperature_probe.lua", probe / "modmain.lua")
shutil.copytree(root / "content", mods / "ShadowWorldLocal")
uid = "2039181790" if args.edition == "stable" else "3193922031"
_winapi.CreateJunction(str(args.workshop.resolve() / uid), str(mods / ("workshop-" + uid)))
port = 11250 + 2 * ("default", "legacy1", "legacy2", "legacy3", "off", "um-disabled").index(args.mode)
port += args.edition == "beta"
cluster = out / "config" / "Thermal"
master = cluster / "Master"
shutil.copytree(args.save, master / "save")
(cluster / "cluster.ini").write_text(
    "[GAMEPLAY]\ngame_mode=survival\nmax_players=1\npause_when_empty=false\n"
    "[NETWORK]\ncluster_name=ShadowWorld UM temperature regression\noffline_cluster=true\nlan_only_cluster=true\n"
    "[MISC]\nconsole_enabled=true\n[SHARD]\nshard_enabled=false\n", encoding="utf-8")
(master / "server.ini").write_text(
    f"[NETWORK]\nserver_port={port}\n[SHARD]\nis_master=true\nname=Master\nid=1\n"
    f"[STEAM]\nmaster_server_port={28400 + port - 11250}\nauthentication_port={9550 + port - 11250}\n", encoding="utf-8")
switch = {
    "legacy1": ",um_patch=1", "legacy2": ",um_patch=2", "legacy3": ",um_patch=3", "off": ",um_patch=false"
}.get(args.mode, "")
temperature = "false" if args.mode == "um-disabled" else "true"
(master / "modoverrides.lua").write_text(
    f'return {{UMTemperatureProbe={{enabled=true,configuration_options={{probe_mode="{args.mode}"}}}},'
    f'ShadowWorldLocal={{enabled=true,configuration_options={{["enable easy mode"]=false,["enable hard mode"]=false{switch}}}}},'
    f'["workshop-{uid}"]={{enabled=true,configuration_options={{maxtempdamage={temperature},maxhungerdamage=true}}}}}}',
    encoding="utf-8")
logpath = out / "native.log"
print(out, flush=True)
with logpath.open("wb") as log:
    process = subprocess.Popen(
        [str(runtime / "bin64/dontstarve_dedicated_server_nullrenderer_x64.exe"),
         "-persistent_storage_root", str(out), "-conf_dir", "config", "-cluster", "Thermal", "-shard", "Master",
         "-port", str(port), "-console"],
        cwd=runtime / "bin64", stdout=log, stderr=subprocess.STDOUT, stdin=subprocess.PIPE,
        creationflags=subprocess.CREATE_NO_WINDOW)
    deadline = time.monotonic() + 80
    while process.poll() is None and time.monotonic() < deadline:
        output = logpath.read_bytes()
        if b"LUA ERROR" in output or b"SOCKET_PORT_ALREADY_IN_USE" in output:
            break
        time.sleep(.5)
    if process.poll() is None:
        process.terminate()
        process.wait(timeout=15)
trace = logpath.read_text(encoding="utf-8", errors="replace")
print(*(line for line in trace.splitlines() if "[UM TEMP]" in line or "LUA ERROR" in line
        or "SOCKET_PORT_ALREADY_IN_USE" in line), sep="\n", flush=True)
raise SystemExit(0 if "[UM TEMP] COMPLETE" in trace and "LUA ERROR" not in trace else 1)
