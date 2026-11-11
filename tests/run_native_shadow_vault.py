"""Run the master-owned vault on a disposable two-shard native DST cluster."""
from pathlib import Path
import _winapi
import argparse
import shutil
import subprocess
import tempfile
import time
import json
import socket

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument("--seed",type=Path)
parser.add_argument("--scenario",choices=("transfer","cut","recover","reload","rollback","migrate","migrate_cut"),default="transfer")
parser.add_argument("--shards",type=int,choices=(2,4),default=2)
parser.add_argument("--game",type=Path,default=Path("D:/SteamLibrary/steamapps/common/Don't Starve Together"))
args=parser.parse_args()
ports=[]
for port in range(10998,11019):
    with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as sock:
        sock.setsockopt(socket.SOL_SOCKET,socket.SO_EXCLUSIVEADDRUSE,1)
        try: sock.bind(("0.0.0.0",port))
        except OSError: continue
        ports.append(port)
    if len(ports)==args.shards:break
if len(ports)<args.shards:raise SystemExit("Not enough available DST LAN ports")
names=("Master","Caves","Layer3","Layer4")[:args.shards]
if args.seed and args.shards==4 and (args.seed/"Islands").exists():names=("Master","Caves","Islands","Volcano")
out=Path(tempfile.mkdtemp(prefix="native-shadow-vault-",dir=ROOT/"work"))
print(out,flush=True)
runtime=out/"runtime"
shutil.copytree(args.game/"bin64",runtime/"bin64")
_winapi.CreateJunction(str(args.game/"data"),str(runtime/"data"))
mods=runtime/"mods";mods.mkdir()
_winapi.CreateJunction(str(ROOT/"content"),str(mods/"ShadowWorld"))
extra_mods=[]
if "Islands" in names:
    workshop=args.game.parent.parent/"workshop/content/322330"
    for uid in ("1467214795","3435352667"):
        name="workshop-"+uid
        _winapi.CreateJunction(str(workshop/uid),str(mods/name))
        extra_mods.append('["'+name+'"]={enabled=true}')
probe=mods/"VaultProbe";probe.mkdir()
(probe/"modinfo.lua").write_text('name="Vault Probe"\ndescription="Disposable"\nauthor="Local"\nversion="1"\napi_version=10\ndst_compatible=true\nserver_only_mod=true\nall_clients_require_mod=false\npriority=-99999\n')
shutil.copyfile(ROOT/"tests/native/shadow_vault_fixture.lua",probe/"modmain.lua")
cluster=out/"config/Audit";cluster.mkdir(parents=True)
(cluster/"cluster.ini").write_text(
    "[GAMEPLAY]\ngame_mode = survival\npause_when_empty = false\n[NETWORK]\n"
    "cluster_name = Shadow Vault Isolated\noffline_cluster = true\nlan_only_cluster = false\n"
    "[MISC]\nconsole_enabled = true\n[SHARD]\nshard_enabled = true\nbind_ip = 127.0.0.1\n"
    "master_ip = 127.0.0.1\nmaster_port = 17851\ncluster_key = shadow-vault-audit\n")
for i,name in enumerate(names):
    shard=cluster/name;shard.mkdir()
    if args.seed:shutil.copytree(args.seed/name/"save",shard/"save",ignore=shutil.ignore_patterns("boot_modindex","modindex","mod_config_data"))
    (shard/"server.ini").write_text(
        f"[NETWORK]\nserver_port = {ports[i]}\n[SHARD]\nis_master = {'true' if i==0 else 'false'}\n"
        f"name = {name}\nid = {i+1}\n[STEAM]\nmaster_server_port = {28851+i}\nauthentication_port = {9851+i}\n"
        +("[ACCOUNT]\nencode_user_path = true\n" if "Islands" in names else ""))
    (shard/"worldgenoverride.lua").write_text(f'return {{override_enabled=true,preset="{"SURVIVAL_TOGETHER" if i==0 else "DST_CAVE"}",overrides={{world_size="small"}}}}')
    (shard/"modoverrides.lua").write_text('return {VaultProbe={enabled=true},ShadowWorld={enabled=true,configuration_options={["World Exchange"]="hosted",["Container Sort"]=-3}},'+','.join(extra_mods)+'}')
(probe/"modmain.lua").write_text('local VAULT_SCENARIO="'+args.scenario+'"\nlocal VAULT_SHARDS='+str(args.shards)+'\n'+(ROOT/"tests/native/shadow_vault_fixture.lua").read_text(encoding="utf-8"),encoding="utf-8")
logs=[out/(name+".log") for name in names]
children=[]
stopped=False
try:
    for i,name in enumerate(names):
        if args.scenario=="rollback" and i==1:
            logs[i].write_bytes(b"");continue
        with logs[i].open("wb") as stream:
            proc=subprocess.Popen([str(runtime/"bin64/dontstarve_dedicated_server_nullrenderer_x64.exe"),
                "-persistent_storage_root",str(out),"-conf_dir","config","-cluster","Audit","-shard",name,"-port",str(ports[i])],
                cwd=runtime/"bin64",stdout=stream,stderr=subprocess.STDOUT,stdin=subprocess.PIPE,creationflags=subprocess.CREATE_NO_WINDOW)
        children.append(proc)
    deadline=time.monotonic()+260
    while time.monotonic()<deadline:
        data=[p.read_bytes() for p in logs]
        if any(b"LUA ERROR" in s or b"SOCKET_PORT_ALREADY_IN_USE" in s for s in data):break
        if args.scenario=="cut" and b"CUT_READY" in data[1]:break
        if args.scenario=="migrate_cut" and b"MIGRATION_CUT_READY" in data[0]:break
        if args.scenario=="recover" and b"RECOVER_MASTER_PASS" in data[0] and b"RECOVER_SECONDARY_PASS" in data[1]:break
        if args.scenario=="reload" and b"RELOAD_MASTER_PASS" in data[0] and b"RELOAD_SECONDARY_PASS" in data[1]:break
        if not stopped and b"READY_FOR_OFFLINE" in data[0] and b"TRANSFER_PASS" in data[1]:
            for p in children[1:]:p.terminate();p.wait(10)
            stopped=True
        if b"[VAULT_NATIVE] PASS" in data[0] or b"[VAULT_NATIVE]\tPASS" in data[0]:
            if args.scenario!="migrate" or all(b"MIGRATE_SOURCE_PASS" in s for s in data[1:]):break
        if any(p.poll() is not None for p in children[:1]):break
        time.sleep(.3)
finally:
    for p in children:
        if p.poll() is None:p.terminate()
        p.wait(10)
results={}
for path in logs:
    lines=path.read_text(encoding="utf-8",errors="replace").splitlines()
    results[path.stem]=[s for s in lines if "[VAULT_NATIVE]" in s or "[ShadowVault2hm]" in s or "LUA ERROR" in s]
    print(path.stem,flush=True)
    print("\n".join(results[path.stem][-60:]),flush=True)
(out/"result.json").write_text(json.dumps(results,indent=2),encoding="utf-8")
passed=any("\tPASS" in s or "] PASS" in s for s in results["Master"])
if args.scenario=="reload":passed=any("RELOAD_MASTER_PASS" in s for s in results["Master"]) and any("RELOAD_SECONDARY_PASS" in s for s in results["Caves"])
if args.scenario=="cut":passed=any("CUT_READY" in s for s in results["Caves"])
if args.scenario=="migrate_cut":passed=any("MIGRATION_CUT_READY" in s for s in results["Master"])
if args.scenario=="recover":passed=any("RECOVER_MASTER_PASS" in s for s in results["Master"]) and any("RECOVER_SECONDARY_PASS" in s for s in results["Caves"])
if args.scenario=="migrate":
    import re
    baseline={};pages={}
    for rows in results.values():
        for line in rows:
            match=re.search(r"(?:BASELINE|MIGRATE_PAGE)\t([^\t]+)\t([^\r\n]*)",line)
            if match:(baseline if "\tBASELINE\t" in line else pages)[match[1]]=match[2].strip()
    passed=passed and len(baseline)==args.shards and baseline==pages
raise SystemExit(0 if passed else 1)
