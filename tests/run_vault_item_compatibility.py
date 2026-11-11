"""Native inventory conservation with UM beta, Legion and Medal enabled."""
from pathlib import Path
import sys,json,_winapi,traceback,time
sys.path.insert(0,str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster,ROOT,ledger
sys.stdout.reconfigure(encoding='utf-8')
c=Cluster('hosted',2,ROOT/'work/native-shadow-vault-2j510173/config/Audit',ROOT/'content')
mods=['3193922031','1392778117','1909182187']
for uid in mods:
 _winapi.CreateJunction(str(Path('D:/SteamLibrary/steamapps/workshop/content/322330')/uid),str(c.runtime/'mods'/('workshop-'+uid)))
for name in c.names:
 p=c.cluster/name/'modoverrides.lua';s=p.read_text()
 s=s.replace('["Container Sort"]=-3','["Container Sort"]=-3,["Nightsword Infused"]=true,["Glass Cutter Leap Attack"]=true')
 p.write_text(s[:-1]+''.join(f',["workshop-{uid}"]={{enabled=true,configuration_options={{}}}}'for uid in mods)+'}')
with(c.runtime/'mods/VaultAudit/modmain.lua').open('a',encoding='utf-8')as f:f.write((ROOT/'tests/native/vault_item_compatibility_probe.lua').read_text(encoding='utf-8'))
r={'cluster':str(c.out),'mods':mods,'checks':[]}
expected={}
def verify(label):
 state=c.settle();actual=ledger(state)
 assert actual==expected,(label,actual,expected)
 assert all(not x.get('error')and x['pending']==0 for x in state.values()),label
 for shard in state.values():
  for detail in shard.get('details',[]):
   if detail['token']in ('nightsword','glasscutter'):assert detail['data']['uses']==31,(label,detail)
   if detail['token']=='gift':
    nested=detail['data']['nested'];records=list(nested.values())if isinstance(nested,dict)else nested
    assert sorted(x['prefab']for x in records)==['goldnugget','medal_tentaclespike'],(label,nested)
    gold=next(x for x in records if x['prefab']=='goldnugget');assert gold['data']['stackable']['stack']==23
 r['checks'].append({'label':label,'goods':actual})
 print(label,flush=True)
try:
 c.start();c.open('Caves');c.open('Master',page=2)
 r['blocked']=b=c.call('Master','VaultAudit.compat_blocked()','compat_blocked');assert all(b['outcomes'].values()),b
 r['refresh']=b=c.call('Master','VaultAudit.compat_refresh()','compat_refresh');assert all(all(x.values())for x in b['results'].values()),b
 items=['nightsword','glasscutter','skeletonmeat','medal_tentaclespike','neverfade']
 for slot,prefab in enumerate(items,1):
  expected[prefab]=31 if prefab=='skeletonmeat'else 1;c.seed('Master','bank',2,prefab,31,prefab,slot)
 c.call('Master','VaultAudit.compat_gift()','compat_gift');expected['gift']=1;items.append('gift')
 verify('seed_native_and_mod_items')
 for turn in range(3):
  for slot,prefab in enumerate(items,1):
   c.action('Caves',1,'withdraw',slot);verify(f'{turn}_{prefab}_withdraw')
   c.action('Caves',1,'deposit',slot);verify(f'{turn}_{prefab}_deposit')
 before=len(c.events('Master'));c.call('Master','VaultAudit.compat_transient()','compat_transient')
 r['recovery']=b=c.wait('Master','compat_recovered',after=before,timeout=25)
 assert b['valid']and b['same']and not b.get('error')and not b.get('journal_error'),b
 verify('automatic_current_custody_recovery')
 for turn in range(2):
  c.saveall();c.stop();c.start();verify('saved_restart_'+str(turn))
 r['status']='passed'
except Exception:
 r.update(status='failed',error=traceback.format_exc());print(r['error'],flush=True)
finally:
 c.stop();path=c.out/'compatibility-report.json';path.write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8');print('REPORT',path,flush=True)
raise SystemExit(0 if r['status']=='passed'else 1)
