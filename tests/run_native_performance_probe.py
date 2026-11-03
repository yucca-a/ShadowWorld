"""Run disposable native shard pairs against identical copied fixture worlds.

Uses an existing isolated test world, never player saves or installed mods.
Both shards use copies of the same forest fixture to control entity counts.
"""
import argparse
import ctypes
from ctypes import wintypes
import io
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import time
import _winapi

ROOT = Path(__file__).resolve().parents[1]
GAME = Path("D:/SteamLibrary/steamapps/common/Don't Starve Together")
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("variant", choices=["upstream", "published", "working"])
parser.add_argument("--run", default="first")
parser.add_argument("--fixture", choices=["performance", "recovery-exit", "recovery-crash", "regeneration"], default="performance")
parser.add_argument("--resume-from", help="Copy an earlier isolated run's saves, never modify them")
args = parser.parse_args()
if not args.run.replace("-", "").isalnum():
    parser.error("run name must be alphanumeric")
if args.resume_from and not args.resume_from.replace("-", "").isalnum():
    parser.error("resume source must name an isolated run")
out = ROOT / "work/performance-audit" / (args.variant + "-" + args.run)
out.mkdir(parents=True, exist_ok=False)
runtime = out / "runtime"
(runtime / "bin64").mkdir(parents=True)
for binary in (GAME / "bin64").iterdir():
    if binary.is_file(): shutil.copy2(binary, runtime / "bin64" / binary.name)
_winapi.CreateJunction(str(GAME / "data"), str(runtime / "data"))
mod = runtime / "mods/PerformanceProbe"
mod.mkdir(parents=True)
if args.variant == "working":
    shutil.copytree(ROOT / "content", mod, dirs_exist_ok=True)
else:
    ref = "upstream-v2.8.14.95" if args.variant == "upstream" else "v2.8.14.97.3"
    raw = subprocess.check_output(["git", "archive", ref, "content"], cwd=ROOT)
    with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
        for member in archive.getmembers():
            if member.isfile():
                path = Path(member.name).relative_to("content")
                target = mod / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(archive.extractfile(member).read())
with (mod / "modmain.lua").open("ab") as stream:
    stream.write(b'\nmodimport("performance_probe.lua")\n')
if args.fixture == "performance":
    shutil.copyfile(ROOT / "tests/native/performance_probe.lua", mod / "performance_probe.lua")
elif args.fixture == "regeneration":
    shutil.copyfile(ROOT / "tests/native/regeneration_probe.lua", mod / "performance_probe.lua")
else:
    fixture = (ROOT / "tests/native/world_exchange_fast_recovery_fixture.lua").read_text(encoding="utf-8")
    if args.fixture == "recovery-exit": fixture = fixture.replace('"boot", "crash"', '"boot", "exit"')
    (mod / "performance_probe.lua").write_text(fixture, encoding="utf-8")
cluster = out / "config/Perf"
cluster.mkdir(parents=True)
(cluster / "cluster.ini").write_text("""[GAMEPLAY]
game_mode = survival
max_players = 1
pause_when_empty = false
[NETWORK]
cluster_name = ShadowWorld disposable performance comparison
offline_cluster = true
lan_only_cluster = true
[MISC]
console_enabled = true
[SHARD]
shard_enabled = true
bind_ip = 127.0.0.1
master_ip = 127.0.0.1
master_port = 14991
cluster_key = shadowworld-performance-only
""", encoding="utf-8")
if args.fixture != "performance":
    config = cluster / "cluster.ini"
    config.write_text(config.read_text(encoding="utf-8").replace("ShadowWorld disposable performance comparison", "ShadowWorld isolated exchange test"), encoding="utf-8")

class Memory(ctypes.Structure):
    _fields_ = [("cb", wintypes.DWORD), ("PageFaultCount", wintypes.DWORD)] + [
        (name, ctypes.c_size_t) for name in ["PeakWorkingSetSize", "WorkingSetSize", "QuotaPeakPagedPoolUsage",
        "QuotaPagedPoolUsage", "QuotaPeakNonPagedPoolUsage", "QuotaNonPagedPoolUsage", "PagefileUsage", "PeakPagefileUsage", "PrivateUsage"]]

psapi = ctypes.WinDLL("psapi")
psapi.GetProcessMemoryInfo.argtypes = [wintypes.HANDLE, ctypes.POINTER(Memory), wintypes.DWORD]
processes, logs, samples = [], [], []
try:
    for i, shard in enumerate(["Master", "Caves"]):
        folder = cluster / shard
        template = (ROOT / "work/performance-audit" / args.resume_from / "config/Perf" / shard / "save"
                    if args.resume_from else ROOT / "work/reuse-audit/config/Audit/Master/save")
        shutil.copytree(template, folder / "save")
        (folder / "modoverrides.lua").write_text('return {PerformanceProbe={enabled=true,configuration_options={}}}', encoding="utf-8")
        (folder / "server.ini").write_text(f"""[NETWORK]
server_port = {11012 + i}
[SHARD]
is_master = {'true' if i == 0 else 'false'}
name = {shard}
id = {i + 1}
[STEAM]
master_server_port = {28961 + i}
authentication_port = {9691 + i}
[ACCOUNT]
encode_user_path = true
""", encoding="utf-8")
        log = (out / (shard + ".log")).open("wb"); logs.append(log)
        cmd = [str(runtime / "bin64/dontstarve_dedicated_server_nullrenderer_x64.exe"),
               "-persistent_storage_root", str(out), "-conf_dir", "config", "-cluster", "Perf", "-shard", shard,
               "-port", str(11012 + i)]
        p = subprocess.Popen(cmd, cwd=runtime / "bin64", stdout=log, stderr=subprocess.STDOUT,
                             stdin=subprocess.PIPE, creationflags=subprocess.CREATE_NO_WINDOW)
        processes.append(p)
    (out / "processes.json").write_text(json.dumps([p.pid for p in processes]))
    print("Started isolated probes:", out, [p.pid for p in processes], flush=True)
    started = time.monotonic()
    while any(p.poll() is None for p in processes) and time.monotonic() - started < (360 if args.fixture == "regeneration" else 200):
        if args.fixture == "regeneration" and all("[REGEN_PROBE] VERIFIED" in
                (out / (shard + ".log")).read_text(encoding="utf-8", errors="replace") for shard in ["Master", "Caves"]):
            print("Both disposable shards verified regeneration and first use; stopping only these child processes.", flush=True)
            break
        if args.fixture == "recovery-crash" and not args.resume_from:
            if all("READY_KILL_CAVES_ONLY" in (out / (shard + ".log")).read_text(encoding="utf-8", errors="replace")
                   for shard in ["Master", "Caves"]):
                print("Both disposable shards reached crash point; stopping only these child processes.", flush=True)
                break
        for shard, p in zip(["Master", "Caves"], processes):
            if p.poll() is None:
                mem = Memory(); mem.cb = ctypes.sizeof(mem)
                if psapi.GetProcessMemoryInfo(int(p._handle), ctypes.byref(mem), mem.cb):
                    samples.append({"time": round(time.monotonic() - started, 1), "shard": shard,
                                    "working": mem.WorkingSetSize, "private": mem.PrivateUsage})
        time.sleep(1)
finally:
    for p in processes:
        if p.poll() is None:
            p.terminate()  # Only the disposable child processes created above.
            p.wait(timeout=15)
    for log in logs: log.close()
    (out / "memory.json").write_text(json.dumps(samples, indent=2))
for shard in ["Master", "Caves"]:
    lines = (out / (shard + ".log")).read_text(encoding="utf-8", errors="replace").splitlines()
    print(shard, "\n".join(line for line in lines if "[PERF_PROBE]" in line or "[FAST_RECOVERY]" in line or "[REGEN_PROBE]" in line or "LUA ERROR" in line))
print("Saved measurements to", out)
