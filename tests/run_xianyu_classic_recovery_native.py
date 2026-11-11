"""Owned, frozen-input two-shard save switches; no access to player worlds."""
from pathlib import Path
from copy import deepcopy
import argparse,json,time,traceback,sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster,ROOT
p=argparse.ArgumentParser();p.add_argument('--before',action='store_true');p.add_argument('--source',type=Path,default=ROOT/'content');args=p.parse_args()
c=Cluster('hosted',2,ROOT/'work/native-shadow-vault-2j510173/config/Audit',args.source)
(c.runtime/'mods/VaultAudit/modmain.lua').write_text((ROOT/'tests/native/xianyu_classic_recovery.lua').read_text(encoding='utf-8'),encoding='utf-8')
report={'cluster':str(c.out),'before':args.before,'checks':[]}
def check(name,ok,**extra):
 report['checks'].append(dict(name=name,passed=bool(ok),**deepcopy(extra)));print(name,bool(ok),flush=True);assert ok,extra
def boot(mode):
 c.stop()
 for n in c.names:
  (c.cluster/n/'modoverrides.lua').write_text('return {VaultAudit={enabled=true},ShadowWorld={enabled=true,configuration_options={['+'"World Exchange"]="exchange_v1_'+mode+'",["Container Sort"]=-3,["Tackle Receptacle Use Fish Redeem"]=-1}}}')
 c.start();time.sleep(3)
def state():return {n:c.call(n,'XiInspect()','xi_state')for n in c.names}
def values(v):return v.values()if isinstance(v,dict)else []
def save():
 before={n:len(c.events(n))for n in c.names};c.command('Master','TheWorld:PushEvent("ms_save")')
 for n in c.names:c.wait(n,'archive_saved',after=before[n],timeout=40)
 time.sleep(1)
def totals(s):
 result={}
 for row in s.values():
  # Count canonical inventories only once; banks contains references to them.
  for items in [row['shadow'],row['tackle'],row['second'],row['tacklesecond']]+[
    items for mode,bank in row['banks'].items()if mode!=row['mode']for items in values(bank)]:
   for item in values(items):result[item['prefab']]=result.get(item['prefab'],0)+item['count']
  for entry in row['importrecords']+row['mailrecords']:
   record=entry['record'];count=record.get('data',{}).get('stackable',{}).get('stack',1)
   result[record['prefab']]=result.get(record['prefab'],0)+count
 return result
def empty():
 row=c.call('Master','XiEmpty()','emptied')
 for prefab,count in row['removed'].items():
  report['seed_totals'][prefab]-=count
  if not report['seed_totals'][prefab]:del report['seed_totals'][prefab]
try:
 boot('xianyu')
 for n in c.names:c.call(n,'XiSeed()','seeded')
 s=state();report['seed']=s;report['seed_totals']=totals(s)
 if not args.before:
  c.call('Master','XiLoseAck()','faulted');c.call('Caves','XiPending()','queued');time.sleep(3)
  s=state();report['queued']=s
  check('lost acknowledgement leaves a received import and pending sender',s['Caves']['pending']==1 and s['Master']['imports']==1)
  report['seed_totals']['goldnugget']=report['seed_totals'].get('goldnugget',0)+9
 report['initial_totals']=dict(report['seed_totals']);save()
 boot('original');s=state();report['switched']=s
 opened={n:c.call(n,'XiOpen()','opened')for n in c.names};report['opened']=opened
 check('real saved tackle entrances open without Lua error',all(r['canonical']for r in opened.values()))
 if args.before:
  check('baseline reproduces hidden Xianyu inventory',not s['Master']['shadow'] and bool(s['Master']['banks']['xianyu']['shadow']) and bool(s['Master']['second']))
 else:
  check('old outgoing transfer settles by saved receipt',all(r['pending']==0 for r in s.values()) and s['Master']['imports']==1)
  check('first bank restored as original',all(r['shadow'] and r['tackle']for r in s.values()))
  check('over-capacity extra banks retained',bool(s['Master']['second']) and bool(s['Master']['tacklesecond']))
  check('initial item conservation',totals(s)==report['seed_totals'],actual=totals(s),expected=report['seed_totals'])
  save();boot('original');s=state();check('full overflow survives restart',totals(s)==report['seed_totals'])
  empty();time.sleep(3);s=state();report['drained']=s
  check('freeing capacity resumes both overflow banks',bool(s['Master']['shadow']) and bool(s['Master']['tackle']) and len(s['Master']['second'])<12)
  check('overflow and imports conserved after taking items',totals(s)==report['seed_totals'],actual=totals(s),expected=report['seed_totals'])
  check('tool durability survives real entity movement',all(x.get('uses')==55 for x in values(s['Master']['shadow'])if x['prefab']=='spear'))
  empty();time.sleep(3);s=state()
  check('all retained records eventually restored',not s['Master']['second'] and not s['Master']['tacklesecond'] and s['Master']['imports']==0)
  check('final conservation',totals(s)==report['seed_totals'],actual=totals(s),expected=report['seed_totals'])
  save();boot('original');s2=state();check('drained state persists without replay',totals(s2)==totals(s))
 report['status']='passed'
except Exception:report.update(status='failed',error=traceback.format_exc());print(report['error'],flush=True)
finally:
 c.stop();dest=c.out/'xianyu-classic-report.json';dest.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');print('REPORT',dest,flush=True)
raise SystemExit(report['status']!='passed')
