"""Exercise repeated shard travel with a real DST client on a disposable LAN cluster."""
import _winapi
import argparse
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
import zipfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("suite", choices=("islands", "newconstant"))
parser.add_argument("--cycles", type=int, choices=range(1, 7), default=3)
parser.add_argument("--port", type=int, default=11011)
parser.add_argument("--seed", type=Path, help="Copy shard saves from this disposable fixture cluster")
parser.add_argument("--unrelated-outage", action="store_true", help="Stop Volcano during Master to Islands travel")
parser.add_argument("--quick-worthies", action="store_true", help="Enable Island Adventures' instant Worthy portals")
parser.add_argument("--verify-restart", action="store_true", help="Check player data from the previous completed run")
parser.add_argument("--game", type=Path, default=Path("D:/SteamLibrary/steamapps/common/Don't Starve Together"))
parser.add_argument("--newconstant-mods", type=Path,
                    default=root / "work/newconstant-research/steamcmd/steamapps/workshop/content/322330")
args = parser.parse_args()

game = args.game
workshop = game.parent.parent / "workshop/content/322330"
islands = args.suite == "islands"
shards = [("Master", "SURVIVAL_TOGETHER"), ("Caves", "DST_CAVE")]
modpaths = {"ShadowWorld": root / "content"}
if islands:
    shards.extend([("Islands", "SURVIVAL_SHIPWRECKED_CLASSIC"), ("Volcano", "SURVIVAL_VOLCANO_CLASSIC")])
    modpaths.update({f"workshop-{uid}": workshop / uid for uid in ("1467214795", "3435352667")})
else:
    modpaths.update(newcs_core=args.newconstant_mods / "3645179905",
                    newcs_abyss=args.newconstant_mods / "3645181516", newcs_base=workshop / "3191348907")
if not 10998 <= args.port <= 11019 - len(shards):
    parser.error("All shard ports must be in the DST LAN range 10998–11018")
if (args.unrelated_outage or args.quick_worthies) and not islands:
    parser.error("--unrelated-outage and --quick-worthies require the islands suite")
if args.verify_restart and (not args.seed or args.unrelated_outage):
    parser.error("--verify-restart requires --seed from a completed travel run")
for path in modpaths.values():
    if not (path / "modinfo.lua").is_file():
        parser.error(f"Missing mod: {path}")

out = Path(tempfile.mkdtemp(prefix=f"native-travel-{args.suite}-", dir=root / "work"))
print(out, flush=True)
runtime = out / "runtime"
shutil.copytree(game / "bin64", runtime / "bin64")
for name in ("bin", "bin64"):
    (runtime / name).mkdir(exist_ok=True)
    (runtime / name / "steam_appid.txt").write_text("322330")
data = runtime / "data"
bundles = data / "databundles"
bundles.mkdir(parents=True)
for path in (game / "data").iterdir():
    if path.is_file():
        shutil.copyfile(path, data / path.name)
    elif path.name != "databundles":
        _winapi.CreateJunction(str(path), str(data / path.name))
for path in (game / "data/databundles").iterdir():
    if path.name != "scripts.zip":
        (bundles / path.name).hardlink_to(path)

# The copy automates joining and character selection. All travel runs in the
# actual server components and the client handles native reconnects.
client_boot = f"""
    if not TheNet:IsDedicated() then
        Profile:SetWarnModsEnabled(false)
        DoLoadingPortal = function(cb) cb() end
        if IsInFrontEnd() and Settings.last_reset_action == nil then
            scheduler:ExecuteInTime(5, function() c_connect("127.0.0.1", {args.port}) end)
        end
        local task
        task = scheduler:ExecutePeriodic(.5, function()
            local screen = TheFrontEnd:GetActiveScreen()
            if screen and screen.name == "LobbyScreen" and screen.cb then
                task:Cancel()
                screen.cb("wilson", "wilson_none", "", "", "", "")
            end
        end)
    end
"""
with zipfile.ZipFile(game / "data/databundles/scripts.zip") as original, zipfile.ZipFile(
    bundles / "scripts.zip", "w", compression=zipfile.ZIP_DEFLATED, compresslevel=1
) as patched:
    for entry in original.infolist():
        content = original.read(entry)
        if entry.filename == "scripts/mainfunctions.lua":
            needle = b"    CheckControllers()"
            assert needle in content
            content = content.replace(needle, client_boot.encode() + needle, 1)
        patched.writestr(entry.filename, content)

mods = runtime / "mods"
probe = mods / "TravelAudit"
probe.mkdir(parents=True)
for name, path in modpaths.items():
    _winapi.CreateJunction(str(path), str(mods / name))
(probe / "modinfo.lua").write_text(
    'name="Travel Audit"\nauthor="Local"\ndescription="Disposable fixture"\nversion="1"\napi_version=10\n'
    'dst_compatible=true\nserver_only_mod=true\npriority=-99999\n'
    'configuration_options={{name="suite",default="islands",options={}},'
    '{name="cycles",default=3,options={}},{name="outage",default=false,options={}},'
    '{name="verify_restart",default=false,options={}}}\n'
)
shutil.copyfile(root / "tests/native/world_exchange_travel_fixture.lua", probe / "modmain.lua")
cluster = out / "config/Audit"
cluster.mkdir(parents=True)
(cluster / "cluster.ini").write_text(
    "[GAMEPLAY]\ngame_mode=survival\npause_when_empty=false\n[NETWORK]\n"
    "cluster_name=ShadowWorld isolated travel audit\noffline_cluster=true\n"
    "[MISC]\nconsole_enabled=true\n[SHARD]\nshard_enabled=true\nbind_ip=127.0.0.1\nmaster_ip=127.0.0.1\n"
    f"master_port={args.port + 3000}\ncluster_key=travel-audit\n"
)

children = {}
logs = {}


def launch(name, exe, parameters):
    logs[name] = out / f"{name}.log"
    with logs[name].open("wb") as stream:
        children[name] = subprocess.Popen(
            [str(runtime / "bin64" / exe), "-persistent_storage_root", str(out), *parameters],
            cwd=runtime / "bin64", stdout=stream, stderr=subprocess.STDOUT,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )


def log(name):
    return logs[name].read_text(encoding="utf-8", errors="replace")


try:
    for i, (name, preset) in enumerate(shards):
        shard = cluster / name
        shard.mkdir()
        if args.seed:
            shutil.copytree(args.seed / name / "save", shard / "save",
                            ignore=shutil.ignore_patterns("boot_modindex", "modindex", "mod_config_data"))
        (shard / "worldgenoverride.lua").write_text(
            f'return {{override_enabled=true,preset="{preset}",overrides={{world_size="small"}}}}'
        )
        (shard / "server.ini").write_text(
            f"[NETWORK]\nserver_port={args.port + i}\n[SHARD]\nis_master={str(i == 0).lower()}\nname={name}\nid={i + 1}\n"
            f"[STEAM]\nmaster_server_port={args.port + 16500 + i}\nauthentication_port={args.port - 1200 + i}\n"
        )
        entries = [f'["{name}"]={{enabled=true}}' for name in modpaths if name != "ShadowWorld"]
        if args.quick_worthies:
            entries.remove('["workshop-3435352667"]={enabled=true}')
            entries.append('["workshop-3435352667"]={enabled=true,configuration_options={quick_worthies=true}}')
        entries += ['ShadowWorld={enabled=true,configuration_options={["World Exchange"]="coordinated"}}',
                    f'TravelAudit={{enabled=true,configuration_options={{suite="{args.suite}",cycles={args.cycles},'
                    f'outage={str(args.unrelated_outage).lower()},verify_restart={str(args.verify_restart).lower()}}}}}']
        (shard / "modoverrides.lua").write_text("return {" + ",".join(entries) + "}")
        launch(name, "dontstarve_dedicated_server_nullrenderer_x64.exe",
               ["-conf_dir", "config", "-cluster", "Audit", "-shard", name, "-port", str(args.port + i)])
    deadline = time.monotonic() + 500
    total = 1 if args.unrelated_outage else (6 if islands else 2) * args.cycles
    final_shard = "Islands" if args.unrelated_outage else "Master"
    stopped = set()
    while time.monotonic() < deadline:
        outputs = {name: log(name) for name in children}
        if any((name not in stopped and child.poll() is not None) or "LUA ERROR stack traceback" in outputs[name] or
               "SOCKET_PORT_ALREADY_IN_USE" in outputs[name] for name, child in children.items()):
            raise RuntimeError("DST process exited or logged an error")
        if args.unrelated_outage and "Volcano" not in stopped and "[TRAVEL AUDIT] DROP_VOLCANO" in outputs["Master"]:
            children["Volcano"].terminate()
            children["Volcano"].wait(10)
            stopped.add("Volcano")
        if "client" not in children and all("[TRAVEL AUDIT] LOADED" in outputs[name] for name, _ in shards) and all(
                f"World {i}({name}) is now connected" in outputs["Master"]
                for i, (name, _) in enumerate(shards[1:], 2)):
            launch("client", "dontstarve_steam_x64.exe",
                   ["-conf_dir", "client", "-skipintromovie", "-console", "-offline", "-windowed"])
        if args.verify_restart and f"[TRAVEL AUDIT] RESTART_PASS {total}" in outputs["Master"]:
            break
        if f"[TRAVEL AUDIT] PASS {total}" in outputs[final_shard]:
            arrivals = sorted(int(value) for name, _ in shards for value in
                              re.findall(r"\[TRAVEL AUDIT\] ARRIVED (\d+)", outputs[name]))
            assert arrivals == list(range(total + 1)), arrivals
            if not islands:
                assert "[TRAVEL AUDIT] ABYSS_PORTAL" in outputs["Caves"]
                assert "[TRAVEL AUDIT] ABYSS_REJECTION_CLEARED" in outputs["Caves"]
            break
        time.sleep(.4)
    else:
        raise RuntimeError("Timed out waiting for complete migration route")
finally:
    for child in children.values():
        if child.poll() is None:
            child.terminate()
        child.wait(10)
    for name in logs:
        for line in log(name).splitlines():
            if "[TRAVEL AUDIT]" in line or "LUA ERROR" in line:
                print(name, line, flush=True)
