"""Exercise real DST client migration on a frozen, disposable two-shard cluster."""
from pathlib import Path
import sys,shutil,zipfile,_winapi,subprocess,time,json,traceback,argparse
sys.path.insert(0,str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster,ROOT,GAME
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--blackhole',action='store_true')
parser.add_argument('--report',type=Path,default=ROOT/'development/validation/vault-native-only-real-client-20261106.json')
args=parser.parse_args()
c=Cluster('hosted',2,ROOT/'work/native-shadow-vault-2j510173/config/Audit',ROOT/'content')
result={'cluster':str(c.out),'status':'running','blackhole':args.blackhole};client=None
try:
    fixture=c.runtime/'mods/VaultAudit/modmain.lua'
    with fixture.open('a',encoding='utf-8') as f:f.write(r'''
local client_blackhole=__BLACKHOLE__
AddShardModRPCHandler("VaultAudit","clientfault",function(_,fault) A.fault=fault end)
local function ClientFault(fault)
    A.fault=fault
    SendModRPCToShard(GetShardModRPC("VaultAudit","clientfault"),TheShard:IsMaster() and "2" or "1",fault)
end
AddPlayerPostInit(function(p)
    if not TheWorld.ismastersim then return end
    local save,load=p.OnSave,p.OnLoad
    p.OnSave=function(inst,data,...)local refs=save and save(inst,data,...);data.vaultclientstep=inst._vaultclientstep;return refs end
    p.OnLoad=function(inst,data,...)if load then load(inst,data,...)end;inst._vaultclientstep=data and data.vaultclientstep end
end)
AddSimPostInit(function()
    TheWorld:ListenForEvent("ms_playerjoined",function(_,p)
        if p.userid:sub(1,6)=="KU_VA_" then return end
        p:DoStaticTaskInTime(3,function()
            p.components.health:SetInvincible(true);p.components.hunger:SetRate(0)
            local step=p._vaultclientstep or 0
            local gold=p.components.inventory:FindItem(function(i)return i.prefab=="goldnugget"end)
            if step==0 then
                assert(not gold,"clean client fixture")
                gold=SpawnPrefab("goldnugget");gold.components.stackable:SetStackSize(17);p.components.inventory:GiveItem(gold)
            end
            assert(gold and gold.components.stackable:StackSize()==17,"client migration retains inventory")
            assert(p.components.playercontroller:IsEnabled() and not p._despawning,"arrived client can control character")
            emit({kind="real_client_arrived",step=step,userid=p.userid})
            if step==6 and client_blackhole then ClientFault("none") end
            local function proceed()
                if step==6 then emit({kind="real_client_pass",step=step});return end
                if step==0 and client_blackhole then ClientFault("blackhole") end
                p._vaultclientstep=step+1
                local destination=TheShard:IsMaster() and "2" or "1"
                TheWorld:PushEvent("ms_playerdespawnandmigrate",{player=p,worldid=destination,x=0,y=0,z=0})
            end
            if step==0 or step==6 then SaveGame(false,proceed) else proceed() end
        end)
    end)
end)
'''.replace('__BLACKHOLE__','true' if args.blackhole else 'false'))
    runtime=c.out/'client-runtime';shutil.copytree(GAME/'bin64',runtime/'bin64')
    (runtime/'bin64/steam_appid.txt').write_text('322330')
    _winapi.CreateJunction(str((c.runtime/'mods').resolve()),str(runtime/'mods'))
    data=runtime/'data';bundles=data/'databundles';bundles.mkdir(parents=True)
    for source in (GAME/'data').iterdir():
        if source.is_file():shutil.copyfile(source,data/source.name)
        elif source.name!='databundles':_winapi.CreateJunction(str(source),str(data/source.name))
    for source in (GAME/'data/databundles').iterdir():
        if source.name!='scripts.zip':(bundles/source.name).hardlink_to(source)
    boot='''
    if not TheNet:IsDedicated() then
        Profile:SetWarnModsEnabled(false)
        DoLoadingPortal=function(cb)cb()end
        if IsInFrontEnd() and Settings.last_reset_action==nil then
            scheduler:ExecuteInTime(5,function()c_connect("127.0.0.1",%d)end)
        end
        local task
        task=scheduler:ExecutePeriodic(.5,function()
            local screen=TheFrontEnd:GetActiveScreen()
            if screen and screen.name=="LobbyScreen" and screen.cb then
                task:Cancel();screen.cb("wilson","wilson_none","","","","")
            end
        end)
    end
'''%c.ports[0]
    with zipfile.ZipFile(GAME/'data/databundles/scripts.zip') as src,zipfile.ZipFile(bundles/'scripts.zip','w',zipfile.ZIP_DEFLATED,compresslevel=1) as dst:
        for entry in src.infolist():
            raw=src.read(entry)
            if entry.filename=='scripts/mainfunctions.lua':
                needle=b'    CheckControllers()';assert needle in raw
                raw=raw.replace(needle,boot.encode()+needle,1)
            dst.writestr(entry.filename,raw)
    c.start()
    startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
    log=c.out/'real-client.log'
    with log.open('wb') as stream:
        client=subprocess.Popen([str(runtime/'bin64/dontstarve_steam_x64.exe'),'-persistent_storage_root',str(c.out),'-conf_dir','real-client','-skipintromovie','-console','-offline','-windowed'],cwd=runtime/'bin64',stdout=stream,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW,startupinfo=startup)
    deadline=time.monotonic()+240
    while time.monotonic()<deadline:
        rows=[r for n in c.names for r in c.events(n)]
        if any(r['kind']=='real_client_pass' for r in rows):
            arrivals=sorted(r['step'] for r in rows if r['kind']=='real_client_arrived')
            assert arrivals==list(range(7)),arrivals
            result.update(status='passed',arrivals=arrivals,client_log=str(log));break
        if client.poll() is not None:raise RuntimeError('client exited: '+str(client.returncode))
        time.sleep(.5)
    else:raise TimeoutError('real client did not finish six migrations; '+str(log))
except Exception:
    result.update(status='failed',error=traceback.format_exc());print(result['error'],flush=True)
finally:
    if client is not None:
        if client.poll() is None:client.terminate()
        client.wait(15)
    c.stop();args.report.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(result),flush=True)
raise SystemExit(0 if result['status']=='passed' else 1)
