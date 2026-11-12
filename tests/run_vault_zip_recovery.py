"""Boot only isolated copies of a zipped player cluster; never edit the input."""
from pathlib import Path, PurePosixPath
from zipfile import ZipFile
import argparse,sys,re,json,_winapi,time,traceback,hashlib
sys.path.insert(0,str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster,ROOT,freeports
p=argparse.ArgumentParser()
p.add_argument('--archive',type=Path,required=True)
p.add_argument('--source',type=Path,default=ROOT/'content')
p.add_argument('--verify',action='store_true')
p.add_argument('--legacy-fixture',action='store_true')
p.add_argument('--rollback',action='store_true')
p.add_argument('--restarts',type=int,default=2)
p.add_argument('--migration',action='store_true')
a=p.parse_args();sys.stdout.reconfigure(encoding='utf-8')
c=Cluster('hosted',2,None,a.source)
# Keep game/Steam ports separated; loaded workshop networking may bind adjacent ports.
c.ports=[freeports(11008+i*5,11013+i*5,1)[0] for i in range(2)]
for i,shard in enumerate(c.names):
 f=c.cluster/shard/'server.ini'
 text=f.read_text()
 text=re.sub(r'^server_port = \d+','server_port = '+str(c.ports[i]),text,flags=re.M)
 text=re.sub(r'^master_server_port = \d+','master_server_port = '+str(freeports(29120+i*30,29140+i*30,1)[0]),text,flags=re.M)
 text=re.sub(r'^authentication_port = \d+','authentication_port = '+str(freeports(10120+i*30,10140+i*30,1)[0]),text,flags=re.M)
 f.write_text(text)
report={'cluster':str(c.out),'missing_mods':[],'legacy_fixture':a.legacy_fixture,
        'archive_sha256':hashlib.sha256(a.archive.read_bytes()).hexdigest()}
def inventory():
 result={}
 for n in c.names:
  before=len(c.events(n));c.command(n,'VaultArchiveInventory()');c.wait(n,'inventory_done',after=before)
  result[n]={r['family']:r for r in c.events(n)[before:]if r['kind']=='archive_inventory'}
 return result
try:
 with ZipFile(a.archive) as z:
  prefixes=[n[:-len('Master/modoverrides.lua')] for n in z.namelist() if n.endswith('Master/modoverrides.lua')]
  assert len(prefixes)==1
  prefix=prefixes[0]
  for info in z.infolist():
   if not info.filename.startswith(prefix):continue
   parts=PurePosixPath(info.filename[len(prefix):]).parts
   if info.is_dir() or '..' in parts or len(parts)<3 or parts[0] not in c.names or parts[1]!='save':continue
   if parts[-1] in ('boot_modindex','modindex','mod_config_data'):continue
   dest=c.cluster.joinpath(*parts);dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(z.read(info))
  for shard in c.names:
   config=z.read(prefix+shard+'/modoverrides.lua').decode('utf-8-sig')
   mods=re.findall(r'\["(workshop-\d+)"\]',config)
   if a.legacy_fixture:
    mods.append('workshop-2564938022')
    at=config.rfind('}');config=config[:at]+',["workshop-2564938022"]={enabled=true,configuration_options={}}'+config[at:]
   for mod in mods:
    if mod=='workshop-3832182265':continue
    src=Path('D:/SteamLibrary/steamapps/workshop/content/322330')/mod[9:]
    if not src.is_dir():src=ROOT/'work/newconstant-research/steamcmd/steamapps/workshop/content/322330'/mod[9:]
    dest=c.runtime/'mods'/mod
    if src.is_dir():
     if not dest.exists():_winapi.CreateJunction(str(src),str(dest))
    elif mod not in report['missing_mods']:report['missing_mods'].append(mod)
   config=config.replace('workshop-3832182265','ShadowWorld')
   at=config.rfind('}');config=config[:at]+',VaultAudit={enabled=true,configuration_options={}}'+config[at:]
   if not a.migration:
    config='local overrides=(function()\n'+config+'\nend)()\noverrides.ShadowWorld.configuration_options["World Exchange"]="exchange_v1_nexus"\nreturn overrides'
   (c.cluster/shard/'modoverrides.lua').write_text(config,encoding='utf-8')
   original=z.read(prefix+shard+'/server.ini').decode('utf-8-sig')
   match=re.search(r'^id\s*=\s*(\d+)',original,re.M)
   shardid=match[1] if match else '1'
   f=c.cluster/shard/'server.ini';f.write_text(re.sub(r'^id = \d+', 'id = '+shardid,f.read_text(),flags=re.M))
 fixture='exchange_modes_probe.lua' if a.migration else 'vault_archive_probe.lua'
 (c.runtime/'mods/VaultAudit/modmain.lua').write_text((ROOT/'tests/native'/fixture).read_text(encoding='utf-8'),encoding='utf-8')
 c.start();time.sleep(15)
 if a.migration:
  assert not report['missing_mods'],report['missing_mods']
  def mode_state(n):
   before=len(c.events(n));row=c.call(n,'ExchangeModeProbe()','mode_state')
   row['inventory']={e['family']:e for e in c.events(n)[before:]if e['kind']=='mode_bank'}
   return row
  report['samples']=[]
  for _ in range(60):
   state={n:mode_state(n)for n in c.names}
   report['samples'].append(state)
   print('MIGRATION',json.dumps({n:{k:v for k,v in r.items()if k not in ('banks','states','inventory','owners')}for n,r in state.items()}),flush=True)
   if all(r['ready'] for r in state.values()):break
   time.sleep(2)
  assert all(r['ready'] and r['mode'] in ('classic','off') and r.get('migrated') for r in state.values()),state
  report['migrated']=state
  for n in c.names:
   for family in ('shadow','tacklestation2hm','cloudpine_l4'):
    row=c.call(n,'ExchangeModeOpen('+json.dumps(family)+')','mode_opened');assert row['opened'],row
  c.stop();c.start();time.sleep(5)
  report['reloaded']={n:mode_state(n)for n in c.names}
  for n,row in report['reloaded'].items():
   assert row['ready'] and row['mode'] in ('classic','off') and row.get('migrated') and not row.get('error'),row
   assert row['banks']==report['migrated'][n]['banks'],'migrated inventories changed on reload'
   assert row['inventory']==report['migrated'][n]['inventory'],'migrated item records changed on reload'
  report['status']='passed'
  raise SystemExit(0)
 report['results']={n:c.call(n,'VaultArchiveProbe()','archive_state') for n in c.names}
 report['diagnostics']={n:[e for e in c.events(n)if e['kind']=='snapshot_rejected'] for n in c.names}
 if a.verify:
  for row in report['results'].values():assert not row.get('error') and not row.get('journal_error') and not row.get('active') and row['rows']==0,row
  report['inventories']=inventory()
  for shard,rows in report['inventories'].items():
   clouds=[r for r in rows.values()if r['prefab'].startswith('cloudpine_box')]
   assert any(r['retained']=='linked_items' for r in clouds),shard
   for r in rows.values():assert not r['managed'] and not r['readonly'],r['prefab']
  report['open_checks']=[]
  for family,stale in [('shadow',False),('tacklestation2hm',False),('cloudpine_l4',False),('tacklestation2hm',True)]:
   for n in c.names:c.call(n,'VaultArchiveOpen('+json.dumps(family)+','+str(stale).lower()+')','archive_open_started')
   time.sleep(4)
   for n in c.names:
    row=c.call(n,'VaultArchiveOpened()','archive_opened')
    if not row['opened']:
     time.sleep(8);row=c.call(n,'VaultArchiveOpened(true)','archive_opened')
    assert row['opened'],row
    report['open_checks'].append(row)
  assert inventory()==report['inventories'],'Native local round trip changed inventory'
  report['restarts']=[]
  for _ in range(a.restarts):
   before={n:len(c.events(n))for n in c.names}
   c.command('Master','TheWorld:PushEvent("ms_save")')
   for n in c.names:c.wait(n,'archive_saved',after=before[n],timeout=40)
   c.stop();c.start();time.sleep(15)
   states={n:c.call(n,'VaultArchiveProbe()','archive_state')for n in c.names}
   for row in states.values():assert not row.get('error') and not row.get('journal_error') and not row.get('active') and row['rows']==0,row
   goods=inventory()
   assert goods==report['inventories'],'Native retained inventories changed across restart'
   report['restarts'].append(states)
  if a.rollback:
   # Two ordinary native saves, then the engine's coordinated rollback path.
   for _ in range(2):
    before={n:len(c.events(n))for n in c.names};c.command('Master','TheWorld:PushEvent("ms_save")')
    for n in c.names:c.wait(n,'archive_saved',after=before[n],timeout=40)
    time.sleep(2)
   before={n:len(c.events(n))for n in c.names}
   c.command('Master','WorldRollbackFromSim(1)')
   for n in c.names:c.wait(n,'ready',after=before[n],timeout=240)
   time.sleep(15)
   report['rollback']={n:c.call(n,'VaultArchiveProbe()','archive_state')for n in c.names}
   for row in report['rollback'].values():assert not row.get('error') and not row.get('journal_error') and not row.get('active') and row['rows']==0,row
   assert inventory()==report['inventories'],'Retained inventories changed during rollback'
   report['rollback_open']=[]
   for n in c.names:c.call(n,'VaultArchiveOpen("tacklestation2hm")','archive_open_started')
   time.sleep(4)
   for n in c.names:
    row=c.call(n,'VaultArchiveOpened(true)','archive_opened');assert row['opened'],row
    report['rollback_open'].append(row)
  assert hashlib.sha256(a.archive.read_bytes()).hexdigest()==report['archive_sha256'],'Input archive changed'
 report['status']='passed' if a.verify else 'observed'
except Exception:
 report.update(status='failed',error=traceback.format_exc());print(report['error'])
finally:
 c.stop();path=c.out/'archive-zip-report.json';path.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
 print('REPORT',path);print('STATUS',report['status'],'missing mods',report['missing_mods'])
raise SystemExit(report['status']=='failed')
