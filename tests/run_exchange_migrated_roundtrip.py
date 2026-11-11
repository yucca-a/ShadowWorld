"""Verify a migrated archive cannot replay its retired journal on mode changes."""
from pathlib import Path
import sys,json,re,_winapi,time,traceback,argparse
sys.path.insert(0,str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster,ROOT,freeports
p=argparse.ArgumentParser();p.add_argument('--seed',type=Path,required=True);a=p.parse_args()
c=Cluster('hosted',2,a.seed,ROOT/'content')
c.ports=[freeports(11008+i*5,11013+i*5,1)[0]for i in range(2)]
configs={}
for i,n in enumerate(c.names):
 configs[n]=(a.seed/n/'modoverrides.lua').read_text(encoding='utf-8')
 for mod in re.findall(r'workshop-\d+',configs[n]):
  source=Path('D:/SteamLibrary/steamapps/workshop/content/322330')/mod[9:];dest=c.runtime/'mods'/mod
  if source.is_dir()and not dest.exists():_winapi.CreateJunction(str(source),str(dest))
 oldid=re.search(r'^id\s*=\s*(\d+)',(a.seed/n/'server.ini').read_text(),re.M)[1]
 f=c.cluster/n/'server.ini';t=re.sub(r'^id = \d+','id = '+oldid,f.read_text(),flags=re.M)
 t=re.sub(r'^server_port = \d+','server_port = '+str(c.ports[i]),t,flags=re.M);f.write_text(t)
(c.runtime/'mods/VaultAudit/modmain.lua').write_text((ROOT/'tests/native/exchange_modes_probe.lua').read_text(encoding='utf-8'),encoding='utf-8')
def config(mode):
 for n in c.names:
  text='local overrides=(function()\n'+configs[n]+'\nend)()\noverrides.ShadowWorld.configuration_options["World Exchange"]="'+mode+'"\nreturn overrides'
  (c.cluster/n/'modoverrides.lua').write_text(text,encoding='utf-8')
def state(n):
 before=len(c.events(n));row=c.call(n,'ExchangeModeProbe()','mode_state')
 row['inventory']={e['family']:e for e in c.events(n)[before:]if e['kind']=='mode_bank'};return row
def boot(mode):
 c.stop();config(mode);c.start();time.sleep(10)
 for _ in range(40):
  s={n:state(n)for n in c.names}
  if all(r['ready'] and (mode!='exchange_v1_nexus' or r.get('journal',{}).get('ready'))for r in s.values()):return s
  time.sleep(1)
 raise RuntimeError('mode not ready')
report={'cluster':str(c.out),'seed':str(a.seed)}
try:
 report['nexus']=boot('exchange_v1_nexus')
 for n,r in report['nexus'].items():
  assert r['namespace'].endswith('_exchange_v1')and not r.get('error'),n
  for f in ('shadow','tacklestation2hm'):assert not r['inventory'][f]['items'],(n,f,'retired journal replayed')
 print('Migrated archive: new Nexus journal is empty on both shards',flush=True)
 before={n:len(c.events(n))for n in c.names};c.command('Master','TheWorld:PushEvent("ms_save")')
 for n in c.names:c.wait(n,'archive_saved',after=before[n],timeout=40)
 time.sleep(1)
 report['original']=boot('exchange_v1_original')
 baseline=json.loads((a.seed.parent.parent/'archive-zip-report.json').read_text(encoding='utf-8'))['reloaded']
 for n,r in report['original'].items():
  assert r['inventory']==baseline[n]['inventory'],(n,'original inventory changed')
 print('Migrated archive: all original inventory records survived explicit Nexus selection and return',flush=True)
 report['status']='passed'
except Exception:report.update(status='failed',error=traceback.format_exc());print(report['error'])
finally:
 c.stop();out=c.out/'migrated-mode-roundtrip.json';out.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');print('REPORT',out)
raise SystemExit(report['status']!='passed')
