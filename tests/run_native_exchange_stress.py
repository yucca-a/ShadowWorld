"""Compare the two exchange modes on disposable copies of native shard saves."""
import _winapi
import argparse
import ctypes
from pathlib import Path
import shutil
import statistics
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("seed", type=Path, help="Native cluster containing Master/Caves or all four Island Adventures shards")
parser.add_argument("mode", choices=("traditional", "coordinated"))
parser.add_argument("--shards", type=int, choices=(2, 4), default=4)
parser.add_argument("--rounds", type=int, default=48)
parser.add_argument("--mask", type=lambda s: int(s, 0), default=3)
parser.add_argument("--port", type=int, default=11011)
parser.add_argument("--drop-open", action="store_true", help="Drop a final confirmation and immediately request another save")
parser.add_argument("--recover", action="store_true", help="Kill and restart a shard after stress, then roll back and shut down")
parser.add_argument("--shutdown", action="store_true", help="Shut down every shard together, dropping one shard's final confirmations")
parser.add_argument("--game", type=Path, default=Path("D:/SteamLibrary/steamapps/common/Don't Starve Together"))
args = parser.parse_args()
if (args.drop_open or args.recover or args.shutdown) and args.mode != "coordinated":
    parser.error("--drop-open, --recover and --shutdown require coordinated mode")
if args.recover and args.shutdown:
    parser.error("--shutdown runs separately from --recover")

work = ROOT / "work"
work.mkdir(exist_ok=True)
out = Path(tempfile.mkdtemp(prefix=f"native-exchange-{args.mode}-", dir=work))
print(out, flush=True)
runtime = out / "runtime"
shutil.copytree(args.game / "bin64", runtime / "bin64")
_winapi.CreateJunction(str(args.game / "data"), str(runtime / "data"))
mods = runtime / "mods"
mods.mkdir()
_winapi.CreateJunction(str(ROOT / "content"), str(mods / "ShadowWorld"))
modlist = []
if args.shards == 4:
    workshop = args.game.parent.parent / "workshop/content/322330"
    for uid in ("1467214795", "3435352667"):
        name = "workshop-" + uid
        _winapi.CreateJunction(str(workshop / uid), str(mods / name))
        modlist.append(f'["{name}"]={{enabled=true}}')
probe = mods / "ExchangeStress"
probe.mkdir()
(probe / "modinfo.lua").write_text(
    'name="Exchange Stress"\ndescription="Disposable test"\nauthor="Local"\nversion="1"\n'
    'api_version=10\ndst_compatible=true\nserver_only_mod=true\nall_clients_require_mod=false\npriority=-99999\n'
    'configuration_options={{name="shards",default=4,options={}},{name="mode",default="coordinated",options={}},'
    '{name="rounds",default=48,options={}},{name="drop_open",default=false,options={}},'
    '{name="recover",default=false,options={}},{name="shutdown",default=false,options={}}}\n'
)
shutil.copyfile(ROOT / "tests/native/world_exchange_stress_fixture.lua", probe / "modmain.lua")
cluster = out / "config/Audit"
cluster.mkdir(parents=True)
(cluster / "cluster.ini").write_text(
    "[GAMEPLAY]\ngame_mode=survival\npause_when_empty=false\n[NETWORK]\n"
    "cluster_name=ShadowWorld isolated exchange stress\noffline_cluster=true\nlan_only_cluster=false\n"
    f"[MISC]\nconsole_enabled=true\n[SHARD]\nshard_enabled=true\nbind_ip=127.0.0.1\nmaster_ip=127.0.0.1\n"
    f"master_port={args.port + 3600}\ncluster_key=exchange-audit\n"
)
shards = ("Master", "Caves", "Islands", "Volcano")[:args.shards]
config_mode = "classic" if args.mode == "traditional" else args.mode
for i, name in enumerate(shards, 1):
    shard = cluster / name
    shutil.copytree(args.seed / name / "save", shard / "save",
                    ignore=shutil.ignore_patterns("boot_modindex", "modindex", "mod_config_data"))
    (shard / "server.ini").write_text(
        f"[NETWORK]\nserver_port = {args.port + i - 1}\n[SHARD]\nis_master = {'true' if i == 1 else 'false'}\n"
        f"name = {name}\nid = {i}\n[STEAM]\nmaster_server_port = {args.port + 16830 + i}\nauthentication_port = {args.port - 1200 + i}\n"
        "[ACCOUNT]\nencode_user_path = true\n"
    )
    (shard / "modoverrides.lua").write_text("return {" + ",".join([
        f'ExchangeStress={{enabled=true,configuration_options={{shards={args.shards},mode="{args.mode}",rounds={args.rounds},'
        f'drop_open={str(args.drop_open).lower()},recover={str(args.recover).lower()},shutdown={str(args.shutdown).lower()}}}}}',
        f'ShadowWorld={{enabled=true,configuration_options={{["World Exchange"]="{config_mode}",["Container Sort"]=-3}}}}',
        *modlist,
    ]) + "}")

logs = [out / (name + ".log") for name in shards]


def start(i):
    with logs[i].open("ab") as stream:
        child = subprocess.Popen(
            [str(runtime / "bin64/dontstarve_dedicated_server_nullrenderer_x64.exe"),
             "-persistent_storage_root", str(out), "-conf_dir", "config", "-cluster", "Audit",
             "-shard", shards[i], "-port", str(args.port + i)],
            cwd=runtime / "bin64", stdout=stream, stderr=subprocess.STDOUT,
            stdin=subprocess.PIPE, creationflags=subprocess.CREATE_NO_WINDOW,
        )
    if not ctypes.windll.kernel32.SetProcessAffinityMask(ctypes.c_void_p(int(child._handle)), ctypes.c_size_t(args.mask)):
        child.terminate()
        child.wait(10)
        raise ctypes.WinError()
    return child


def command(child, code):
    child.stdin.write((code + "\n").encode())
    child.stdin.flush()


processes = []
recovery = "arming"
try:
    for i in range(len(shards)):
        processes.append(start(i))
    deadline = time.monotonic() + 450
    while time.monotonic() < deadline:
        output = [log.read_bytes() for log in logs]
        if not (args.recover or args.shutdown) and b"[EXCHANGE_STRESS] PASS" in output[0]:
            break
        if args.shutdown:
            if recovery == "arming" and b"[EXCHANGE_STRESS] PASS" in output[0]:
                for child in processes:
                    command(child, "c_shutdown()")
                recovery = "shutdown"
            elif recovery == "shutdown" and all(child.poll() == 0 for child in processes):
                if b"DROPPED_SHUTDOWN_OPEN" in output[0]:
                    recovery = "passed"
                break
        if args.recover:
            if recovery == "arming" and all(b"[EXCHANGE_STRESS] ARMED" in log for log in output):
                processes[-1].terminate()
                processes[-1].wait(10)
                recovery = "offline"
            elif recovery == "offline" and b"[EXCHANGE_STRESS] OFFLINE_HELD" in output[0]:
                processes[-1] = start(len(shards) - 1)
                recovery = "rejoin"
            elif recovery == "rejoin" and all(b"[EXCHANGE_STRESS] REJOINED" in log for log in output):
                command(processes[0], "c_rollback(1)")
                recovery = "rollback"
            elif recovery == "rollback" and all(b"[EXCHANGE_STRESS] ROLLED_BACK" in log for log in output):
                for child in processes:
                    command(child, "c_shutdown()")
                recovery = "shutdown"
            elif recovery == "shutdown" and all(child.poll() == 0 for child in processes):
                recovery = "passed"
                break
        if any(b"LUA ERROR stack traceback" in log or b"SOCKET_PORT_ALREADY_IN_USE" in log for log in output):
            break
        if recovery not in ("offline", "shutdown") and any(child.poll() is not None for child in processes):
            break
        time.sleep(.4)
finally:
    for child in processes:
        if child.poll() is None:
            child.terminate()
        child.wait(10)

results = [line.split() for line in logs[0].read_text(encoding="utf-8", errors="replace").splitlines()
           if "[EXCHANGE_STRESS]" in line]
times = sorted(float(line[-1]) for line in results if "ROUND" in line)
if times:
    p95 = times[(95 * len(times) + 99) // 100 - 1]
    print(f"{len(times)} rounds, median {statistics.median(times):.3f}s, p95 {p95:.3f}s, max {max(times):.3f}s")
passed = [line for line in results if "PASS" in line]
if passed and (not (args.recover or args.shutdown) or recovery == "passed"):
    print(" ".join(passed[-1]))
    if args.recover:
        print("Forced shard restart, common rollback and normal shutdown passed")
    if args.shutdown:
        print("Every shard exited after dropped shutdown confirmations")
else:
    raise SystemExit(f"Native stress did not finish ({recovery}). Check {out}")
