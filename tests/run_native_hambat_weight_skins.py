"""Isolated rendered comparison of weighted official skin resources.
Use --hold-final 300 for visual review; this never connects to the user's world.
Offline items have no ownership: the scene uses the game's skin preview renderer,
while production still uses original item ownership and OverrideItemSkinSymbol.
"""
from pathlib import Path
import sys,shutil,zipfile,_winapi,subprocess,time,json,re,traceback,argparse
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tests'))
from run_vault_comparison import Cluster,GAME
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--hold-final',type=int,default=0)
args=parser.parse_args()
TASK=ROOT/'work/hambat-weight-render-20261112'
TASK.mkdir(exist_ok=True)
c=Cluster('hosted',1,ROOT/'work/reuse-audit/config/Audit',ROOT/'content')
client=None
report={'cluster':str(c.out),'mode':'offline_resource_preview','actual_owned_item_flow_verified':False}
if (TASK/'control.json').exists():(TASK/'control.json').unlink()
try:
 probe=c.runtime/'mods/VaultAudit'
 (probe/'modinfo.lua').write_text('name="Hambat Skin Render"\ndescription="Disposable rendering observation"\nauthor="Local"\nversion="1"\napi_version=10\ndst_compatible=true\nall_clients_require_mod=true\npriority=-99999\n')
 (probe/'modmain.lua').write_bytes((ROOT/'tests/native/hambat_weight_skin_scene.lua').read_bytes())
 (c.cluster/'Master/modoverrides.lua').write_text('return {VaultAudit={enabled=true},ShadowWorld={enabled=true,configuration_options={["enable easy mode"]=true,["New Hambat 2"]=10,["Shadow World"]=false,["Random Sized"]=false}}}')
 runtime=c.out/'client-runtime';shutil.copytree(GAME/'bin64',runtime/'bin64');(runtime/'bin64/steam_appid.txt').write_text('322330')
 (runtime/'mods').mkdir()
 for mod in (c.runtime/'mods').iterdir():
  if mod.is_dir():_winapi.CreateJunction(str(mod),str(runtime/'mods'/mod.name))
 (runtime/'mods/modsettings.lua').write_text('')
 data=runtime/'data';bundles=data/'databundles';bundles.mkdir(parents=True)
 for source in (GAME/'data').iterdir():
  if source.is_file():shutil.copyfile(source,data/source.name)
  elif source.name!='databundles':_winapi.CreateJunction(str(source),str(data/source.name))
 for source in (GAME/'data/databundles').iterdir():
  if source.name!='scripts.zip':(bundles/source.name).hardlink_to(source)
 c.start()
 ports=re.findall(r'\bServerPort:\s*(\d+)',c.logs['Master'].read_text(encoding='utf-8',errors='replace'))
 if ports:c.ports[0]=int(ports[-1])
 boot='\n if not TheNet:IsDedicated() then\n  Profile:SetWarnModsEnabled(false)\n  DoLoadingPortal=function(cb)cb()end\n  if IsInFrontEnd() and Settings.last_reset_action==nil then scheduler:ExecuteInTime(5,function()c_connect("127.0.0.1",%d)end)end\n  local t;t=scheduler:ExecutePeriodic(.5,function()\n   local screen=TheFrontEnd:GetActiveScreen()\n   if screen and screen.name=="LobbyScreen"and screen.cb then t:Cancel();screen.cb("webber","webber_none","","","","")end\n  end)\n end\n'%c.ports[0]
 with zipfile.ZipFile(GAME/'data/databundles/scripts.zip')as src,zipfile.ZipFile(bundles/'scripts.zip','w',zipfile.ZIP_DEFLATED,compresslevel=1)as dst:
  for entry in src.infolist():
   raw=src.read(entry)
   if entry.filename=='scripts/mainfunctions.lua':raw=raw.replace(b'    CheckControllers()',boot.encode()+b'    CheckControllers()',1)
   dst.writestr(entry.filename,raw)
 log=c.out/'client.log';startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=1 if args.hold_final else 0
 with log.open('wb')as stream:
  client=subprocess.Popen([str(runtime/'bin64/dontstarve_steam_x64.exe'),'-persistent_storage_root',str(c.out),'-conf_dir','client','-skipintromovie','-console','-offline','-windowed'],cwd=runtime/'bin64',stdout=stream,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW,startupinfo=startup)
 deadline=time.monotonic()+160
 while time.monotonic()<deadline:
  raw=c.logs['Master'].read_text(encoding='utf-8',errors='replace')
  if 'LUA ERROR' in raw:raise RuntimeError(raw[-5000:])
  if 'assigned ownership to entity'in raw:break
  if client.poll()is not None:raise RuntimeError('client exited '+str(client.returncode))
  time.sleep(.5)
 time.sleep(4)
 result=c.call('Master','VaultAudit.skin_scene()','skin_scene',timeout=30)
 (TASK/'session.json').write_text(json.dumps({'cluster':str(c.out),'client_pid':client.pid,'client_exe':str(runtime/'bin64/dontstarve_steam_x64.exe'),'scene':result},indent=2))
 deadline=time.monotonic()+30
 while '[HAMRENDER] Preview applied'not in log.read_text(encoding='utf-8',errors='replace'):
  c.events('Master')
  if time.monotonic()>deadline:raise TimeoutError('client did not apply resource preview')
  time.sleep(.2)
 report.update(status='rendered',cases=[r for r in c.events('Master')if r['kind']=='skin_actor'],visual_review_required=True)
 assert len(report['cases'])==8
 print('SCENE READY',str(c.out),flush=True)
 control=TASK/'control.json';last=''
 deadline=time.monotonic()+args.hold_final
 while time.monotonic()<deadline:
  if control.exists():
   command=control.read_text()
   if command!=last:
    last=command;data=json.loads(command)
    if data.get('stop'):break
    c.command('Master',data['lua'])
  if client.poll()is not None:break
  time.sleep(.5)
except Exception:report.update(status='failed',error=traceback.format_exc());print(report['error'],flush=True)
finally:
 if client is not None:
  if client.poll()is None:client.terminate()
  client.wait(15)
 c.stop()
 (c.out/'hambat-weight-render-result.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
raise SystemExit(report.get('status')=='failed')
