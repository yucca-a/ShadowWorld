"""Actual rendered client and Craft Pot widgets against an isolated five-slot server."""
from pathlib import Path
import argparse, hashlib, json, re, shutil, subprocess, sys, time, traceback, zipfile, _winapi
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster, ROOT, GAME

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--kind', choices=['bundled', 'classic', 'refresh'], default='bundled')
parser.add_argument('--source', type=Path, default=ROOT/'content')
parser.add_argument('--audit', action='store_true')
parser.add_argument('--mod-cookers', action='store_true')
parser.add_argument('--port', type=int)
parser.add_argument('--hold-final', type=int, default=0)
args = parser.parse_args()
sys.stdout.reconfigure(encoding='utf-8')
c = Cluster('hosted', 1, ROOT/'work/reuse-audit/config/Audit', args.source.resolve())
if args.port:
    c.ports[0]=args.port
    server=c.cluster/'Master/server.ini'
    server.write_text(re.sub(r'(?m)^server_port\s*=\s*\d+',f'server_port = {args.port}',server.read_text()),encoding='utf-8')
client = None
report = {'cluster': str(c.out), 'kind': args.kind, 'audit': args.audit,
          'mod_cookers': args.mod_cookers,
          'source': str(args.source.resolve()),
          'helper_sha256': hashlib.sha256((c.out/'input/common/food_util.lua').read_bytes()).hexdigest()}
try:
    probe = c.runtime/'mods/CookingPreviewAudit'
    probe.mkdir()
    (probe/'modinfo.lua').write_text('name="Cooking Preview Audit"\ndescription="Disposable"\nauthor="Local"\nversion="1"\napi_version=10\ndst_compatible=true\nall_clients_require_mod=true\npriority=-99998\n')
    (probe/'modmain.lua').write_text(('COOK_PREVIEW_MOD_COOKERS=true\n' if args.mod_cookers else '')+(ROOT/'tests/native/craftpot_client_probe.lua').read_text(encoding='utf-8'), encoding='utf-8')
    cp = c.runtime/'mods/CraftPotAudit'
    original = (Path('D:/SteamLibrary/steamapps/workshop/content/322330/3161120380') if args.kind=='bundled' else
                ROOT/'work/smartpot-workshop-audit/steamapps/workshop/content/322330'/('727774324' if args.kind=='classic' else '3822775840'))
    shutil.copytree(original, cp)
    # Only the isolated copy's defaults change; the real modmain/widgets stay intact.
    with (cp/'modinfo.lua').open('a', encoding='utf-8') as f:
        f.write('\nfor i=1,#configuration_options do local o=configuration_options[i]; if o.default==true then o.default=false end; if o.name=="sw_craftpot" or o.name=="has_popup" then o.default=true end end\n')
    if args.kind=='bundled':
        shutil.copytree(Path('D:/SteamLibrary/steamapps/workshop/content/322330/3161117403'),c.runtime/'mods/BirdSpringAudit')
    extra=''
    if args.mod_cookers:
        for uid in ['1392778117','1909182187']:
            _winapi.CreateJunction(str(Path('D:/SteamLibrary/steamapps/workshop/content/322330')/uid),str(c.runtime/'mods'/('workshop-'+uid)))
            extra+=',["workshop-'+uid+'"]={enabled=true}'
    (c.cluster/'Master/modoverrides.lua').write_text('return {ShadowWorld={enabled=true,configuration_options={["cooking_change"]=-3,["food_change"]=true,["fooddata_change"]=false,["做饭需要书"]=false}},CookingPreviewAudit={enabled=true}'+extra+'}', encoding='utf-8')
    runtime = c.out/'client-runtime'
    shutil.copytree(GAME/'bin64', runtime/'bin64')
    (runtime/'bin64/steam_appid.txt').write_text('322330')
    (runtime/'mods').mkdir()
    for mod in (c.runtime/'mods').iterdir():
        if mod.is_dir(): _winapi.CreateJunction(str(mod),str(runtime/'mods'/mod.name))
    (runtime/'mods/modsettings.lua').write_text('ForceEnableMod("CraftPotAudit")\n'+('ForceEnableMod("BirdSpringAudit")\n' if args.kind=='bundled' else ''))
    data = runtime/'data'; bundles=data/'databundles'; bundles.mkdir(parents=True)
    for source in (GAME/'data').iterdir():
        if source.is_file(): shutil.copyfile(source, data/source.name)
        elif source.name!='databundles': _winapi.CreateJunction(str(source),str(data/source.name))
    for source in (GAME/'data/databundles').iterdir():
        if source.name!='scripts.zip': (bundles/source.name).hardlink_to(source)
    c.start()
    # Use the listening port reported by this owned server, including engine fallback.
    ports=re.findall(r'\bServerPort:\s*(\d+)',c.logs['Master'].read_text(encoding='utf-8',errors='replace'))
    if ports: c.ports[0]=int(ports[-1])
    boot = '''
    if not TheNet:IsDedicated() then
        Profile:SetWarnModsEnabled(false)
        DoLoadingPortal=function(cb)cb()end
        if IsInFrontEnd() and Settings.last_reset_action==nil then
            scheduler:ExecuteInTime(5,function()c_connect("127.0.0.1",%d)end)
        end
        local t;t=scheduler:ExecutePeriodic(.5,function()
            local screen=TheFrontEnd:GetActiveScreen()
            if screen and screen.name=="LobbyScreen" and screen.cb then
                t:Cancel();screen.cb("warly","warly_none","","","","")
            end
        end)
    end
''' % c.ports[0]
    with zipfile.ZipFile(GAME/'data/databundles/scripts.zip') as src, zipfile.ZipFile(bundles/'scripts.zip','w',zipfile.ZIP_DEFLATED,compresslevel=1) as dst:
        for entry in src.infolist():
            raw=src.read(entry)
            if entry.filename=='scripts/mainfunctions.lua': raw=raw.replace(b'    CheckControllers()',boot.encode()+b'    CheckControllers()',1)
            dst.writestr(entry.filename,raw)
    startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=1 if args.hold_final else 0
    log=c.out/'client.log'
    with log.open('wb') as stream:
        client=subprocess.Popen([str(runtime/'bin64/dontstarve_steam_x64.exe'),'-persistent_storage_root',str(c.out),'-conf_dir','client','-skipintromovie','-console','-offline','-windowed'],cwd=runtime/'bin64',stdout=stream,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW,startupinfo=startup)
    deadline=time.monotonic()+240
    dispatched=0
    while time.monotonic()<deadline:
        c.events('Master')
        text=log.read_text(encoding='utf-8',errors='replace')
        if 'LUA ERROR' in text: raise RuntimeError('Client Lua error:\n'+text[-6000:])
        rows=[]
        for line in text.splitlines():
            if '[COOK PREVIEW] ' in line:
                try: rows.append(json.loads(line.split('[COOK PREVIEW] ',1)[1]))
                except ValueError: pass
        if any(r.get('kind')=='client_ready' for r in rows):
            target=1+len([r for r in rows if r.get('kind')=='case'])
            if target<=(13 if args.mod_cookers else 6) and target>dispatched:
                c.command('Master',f'CookingPreviewAuditStep({target})')
                dispatched=target
        finished=next((r for r in rows if r.get('kind')=='finished'),None)
        if finished:
            report['cases']=[r for r in rows if r.get('kind')=='case']
            report['result']=finished
            failures=[r for r in report['cases'] if not r['passed']]
            assert finished.get('error') is None, finished
            if args.audit: assert failures, 'Original unexpectedly passed'
            else: assert not failures and len(report['cases'])>=(13 if args.mod_cookers else 6), report['cases']
            report['status']='reproduced' if args.audit else 'passed'
            if args.hold_final:
                print('Holding rendered client: '+str(c.out),flush=True)
                time.sleep(args.hold_final)
            break
        if client.poll() is not None: raise RuntimeError('client exited '+str(client.returncode)+'; '+str(log))
        time.sleep(.5)
    else: raise TimeoutError('Client preview probe did not finish: '+str(log))
except Exception:
    report.update(status='failed',error=traceback.format_exc());print(report['error'],flush=True)
finally:
    if client is not None:
        if client.poll() is None: client.terminate()
        client.wait(15)
    c.stop()
    report['client_log']=str(c.out/'client.log')
    path=c.out/'craftpot-client-result.json';path.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');print(path,flush=True)
raise SystemExit(0 if report['status']!='failed' else 1)
