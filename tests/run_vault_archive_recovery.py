"""Read-only input archive; boot independent copies with private ports and storage."""
from pathlib import Path,PurePosixPath
import sys,tarfile,json,_winapi,time,traceback,argparse
sys.path.insert(0,str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster,ROOT
p=argparse.ArgumentParser()
p.add_argument('--archive',type=Path,required=True)
p.add_argument('--source',type=Path,default=ROOT/'content')
p.add_argument('--seconds',type=int,default=25)
p.add_argument('--verify',action='store_true')
a=p.parse_args()
sys.stdout.reconfigure(encoding='utf-8')
c=Cluster('hosted',2,None,a.source)
report={'cluster':str(c.out),'missing_mods':[]}
try:
 with tarfile.open(a.archive)as archive:
  for member in archive.getmembers():
   parts=PurePosixPath(member.name).parts
   if not member.isfile()or '..'in parts or not parts or parts[0]not in c.names:continue
   if len(parts)>2 and parts[1]=='save':
    dest=c.cluster.joinpath(*parts);dest.parent.mkdir(parents=True,exist_ok=True)
    dest.write_bytes(archive.extractfile(member).read())
  for name in c.names:
   config=archive.extractfile(name+'/modoverrides.lua').read().decode('utf-8')
   import re
   for mod in re.findall(r'\["(workshop-\d+)"\]',config):
    if mod=='workshop-3832182265':continue
    src=Path('D:/SteamLibrary/steamapps/workshop/content/322330')/mod[9:]
    dest=c.runtime/'mods'/mod
    if src.is_dir():
     if not dest.exists():_winapi.CreateJunction(str(src),str(dest))
    elif mod not in report['missing_mods']:report['missing_mods'].append(mod)
   config=config.replace('workshop-3832182265','ShadowWorld')
   at=config.rfind('}')
   config=config[:at]+',VaultAudit={enabled=true,configuration_options={}}'+config[at:]
   (c.cluster/name/'modoverrides.lua').write_text(config,encoding='utf-8')
 # Preserve real shard ID: protocol custody is keyed by it.
 f=c.cluster/'Caves/server.ini';f.write_text(f.read_text().replace('id = 2','id = 756880888'))
 (c.runtime/'mods/VaultAudit/modmain.lua').write_text((ROOT/'tests/native/vault_archive_probe.lua').read_text(encoding='utf-8'),encoding='utf-8')
 c.start()
 time.sleep(a.seconds)
 report['results']={n:c.call(n,'VaultArchiveProbe()','archive_state')for n in c.names}
 report['diagnostics']={n:[e for e in c.events(n)if e['kind']=='snapshot_rejected']for n in c.names}
 if a.verify:
  def verified(result):
   for row in result.values():assert not row.get('error')and not row.get('journal_error')and not row.get('active')and row['rows']==0,row
   assert result['Master']['pages']['756880888']['6']=={'prefab':'nightsword','count':1}
  verified(report['results'])
  report['restarts']=[]
  initial=report['results']['Master']['pages']
  for turn in range(2):
   before={n:len(c.events(n))for n in c.names}
   c.command('Master','TheWorld:PushEvent("ms_save")')
   for n in c.names:c.wait(n,'archive_saved',after=before[n],timeout=40)
   c.stop();c.start();time.sleep(15)
   state={n:c.call(n,'VaultArchiveProbe()','archive_state')for n in c.names}
   verified(state);assert state['Master']['pages']==initial,'page inventory changed across save/restart'
   report['restarts'].append(state)
 report['status']='observed'
 if a.verify:report['status']='passed'
except Exception:
 report.update(status='failed',error=traceback.format_exc());print(report['error'])
finally:
 c.stop();path=c.out/'archive-report.json';path.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
 print('REPORT',path,flush=True)
 print(json.dumps({'status':report['status'],'missing_mods':report['missing_mods'],'restarts':len(report.get('restarts',[]))},ensure_ascii=False),flush=True)
raise SystemExit(0 if report['status']!='failed'else 1)
