"""Isolated five-slot cooking, UM dynamic food and cold save/reload regression."""
from pathlib import Path
import _winapi
import argparse
import json
import random
import shutil
import socket
import subprocess
import tempfile
import time

ROOT=Path(__file__).resolve().parents[1]
GAME=Path("D:/SteamLibrary/steamapps/common/Don't Starve Together")
WORKSHOP=Path("D:/SteamLibrary/steamapps/workshop/content/322330")
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument("--edition",choices=["solo","stable","beta"],default="beta")
parser.add_argument("--stats",action="store_true")
parser.add_argument("--patch-off",action="store_true")
parser.add_argument("--mode",type=int,choices=[-1,-2,-3],default=-3)
parser.add_argument("--baseline",action="store_true",help="Re-enable five slots in old source without the compatibility layer")
parser.add_argument("--disk",action="store_true",help="Save and restart the copied world")
parser.add_argument("--mod-cookers",action="store_true",help="Use real Legion/Medal cooker, upgrade and portable-item scenarios")
parser.add_argument("--port",type=int,help="Reserve a server port outside another fixture's pending startup range")
args=parser.parse_args()
if args.disk and args.mode!=-3:parser.error("disk scenario requires five slots")
out=Path(tempfile.mkdtemp(prefix=f"native-five-slot-{args.edition}-",dir=ROOT/"work"))
runtime=out/"runtime"
shutil.copytree(GAME/"bin64",runtime/"bin64")
_winapi.CreateJunction(str(GAME/"data"),str(runtime/"data"))
mod=runtime/"mods/ShadowWorldLocal"
shutil.copytree(ROOT/"content",mod)
if args.baseline:
    old=(ROOT/"work/five-slot-baseline-cooking.lua").read_text(encoding="utf-8-sig")
    old=old.replace('if cookingchange == -3 and not ModManager:GetMod("workshop-3193922031") then','if cookingchange == -3 then')
    (mod/"food/cooking.lua").write_text(old,encoding="utf-8")
    # Deliberately leave the original UM fixed-four-row hook in place to
    # reproduce the historical fifth-ingredient nil indexing failure.
    main=(mod/"modmain.lua").read_text(encoding="utf-8-sig")
    main=main.replace('if TUNING.DSTU then modimport("easy_other/um_patch.lua") end',
                      'if TUNING.DSTU and GetModConfigData("um_patch") then modimport("easy_other/um_patch.lua") end')
    (mod/"modmain.lua").write_text(main,encoding="utf-8")
uid={"stable":"2039181790","beta":"3193922031"}.get(args.edition)
if uid:_winapi.CreateJunction(str(WORKSHOP/uid),str(runtime/"mods"/("workshop-"+uid)))
if args.mod_cookers:
    if args.disk or args.mode!=-3: parser.error("mod cooker fixture requires five slots and uses native save records")
    for compat_uid in ["1392778117","1909182187"]:
        _winapi.CreateJunction(str(WORKSHOP/compat_uid),str(runtime/"mods"/("workshop-"+compat_uid)))
fixture="mod_cookers_fixture.lua" if args.mod_cookers else "five_slot_cooking_fixture.lua"
shutil.copy2(ROOT/"tests/native"/fixture,mod/"five_slot_fixture.lua")
phase="seed" if args.disk else "normal"
dynamic=args.stats and args.edition=="beta"
with (mod/"modmain.lua").open("a",encoding="utf-8") as f:
    f.write(f'\nFIVE_TEST_DYNAMIC={str(dynamic).lower()}\nFIVE_TEST_SLOTS={5 if args.mode==-3 else 4}\nFIVE_TEST_PHASE="{phase}"\nmodimport("five_slot_fixture.lua")\n')
master=out/"config/Audit/Master"
shutil.copytree(ROOT/"work/reuse-audit/config/Audit/Master/save",master/"save")
(master.parent/"cluster.ini").write_text("""[GAMEPLAY]
game_mode = survival
max_players = 1
pause_when_empty = false
[NETWORK]
cluster_name = ShadowWorld isolated five-slot cooking test
offline_cluster = true
lan_only_cluster = true
[MISC]
console_enabled = true
[SHARD]
shard_enabled = false
""",encoding="utf-8")
ports=[]
candidates=[args.port] if args.port else list(range(10998,11019));random.SystemRandom().shuffle(candidates)
for port in candidates:
    with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as sock:
        sock.setsockopt(socket.SOL_SOCKET,socket.SO_EXCLUSIVEADDRUSE,1)
        try:sock.bind(("0.0.0.0",port))
        except OSError:continue
        ports.append(port);break
if not ports:raise SystemExit("No free native LAN port")
while len(ports)<3:
    with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as sock:
        sock.bind(("127.0.0.1",0));port=sock.getsockname()[1]
        if port not in ports:ports.append(port)
(master/"server.ini").write_text(f"[NETWORK]\nserver_port={ports[0]}\n[SHARD]\nis_master=true\nname=Master\nid=1\n[STEAM]\nmaster_server_port={ports[1]}\nauthentication_port={ports[2]}\n",encoding="utf-8")
options=f'["cooking_change"]={args.mode},["enable hard mode"]=true,["food_change"]=true,["fooddata_change"]=false,["做饭需要书"]=false,["um_patch"]={str(not(args.patch_off or args.baseline)).lower()}'
um=f',["workshop-{uid}"]={{enabled=true,configuration_options={{food_stats={str(args.stats).lower()}}}}}' if uid else ''
if args.mod_cookers:
    um+=',["workshop-1392778117"]={enabled=true},["workshop-1909182187"]={enabled=true}'
(master/"modoverrides.lua").write_text('return {ShadowWorldLocal={enabled=true,configuration_options={'+options+'}}'+um+'}',encoding="utf-8")
reports=[]
for phase in (["seed","verify"] if args.disk else ["normal"]):
    if phase=="verify":
        main=(mod/"modmain.lua").read_text(encoding="utf-8-sig").replace('FIVE_TEST_PHASE="seed"','FIVE_TEST_PHASE="verify"')
        (mod/"modmain.lua").write_text(main,encoding="utf-8")
    logpath=out/(phase+".log")
    with logpath.open("wb") as log:
        process=subprocess.Popen([str(runtime/"bin64/dontstarve_dedicated_server_nullrenderer_x64.exe"),"-persistent_storage_root",str(out),"-conf_dir","config","-cluster","Audit","-shard","Master","-port",str(ports[0])],cwd=runtime/"bin64",stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
        print("Started",args.edition,phase,process.pid,out,flush=True)
        try:
            deadline=time.monotonic()+180
            while process.poll() is None and time.monotonic()<deadline:
                data=logpath.read_bytes()
                if b"LUA ERROR" in data or b"SOCKET_PORT_ALREADY_IN_USE" in data:break
                time.sleep(.25)
        finally:
            if process.poll() is None:process.terminate();process.wait(timeout=15)
    text=logpath.read_text(encoding="utf-8",errors="replace")
    lines=[s for s in text.splitlines() if "[FIVE_SLOT_TEST]" in s or "LUA ERROR" in s]
    success=process.returncode==0 and "LUA ERROR" not in text and ("[FIVE_SLOT_TEST] SEED_SAVED" in text if phase=="seed" else any("RESULT" in s and "failures=0" in s for s in lines))
    reports.append({"phase":phase,"pass":success,"log":str(logpath),"checks":lines})
    if not success:break
result={"pass":all(r["pass"] for r in reports),"arguments":vars(args),"runs":reports,
        "limitation":"Real server components/entities/save files and server-side replica metadata. No rendered client or arbitrary third-party mod combinations."}
(out/"result.json").write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding="utf-8")
print(json.dumps(result,ensure_ascii=False,indent=2),flush=True)
raise SystemExit(0 if result["pass"] else 1)
