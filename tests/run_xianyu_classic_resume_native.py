"""Verify final-source reload of a completed isolated recovery, without replay."""
from pathlib import Path
import json,sys,time,traceback
sys.path.insert(0,str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster,ROOT
previous=Path(sys.argv[1]).resolve()
expected=json.loads((previous/'xianyu-classic-report.json').read_text(encoding='utf-8'))
assert expected['status']=='passed'
c=Cluster('hosted',2,previous/'config/Audit',ROOT/'content')
(c.runtime/'mods/VaultAudit/modmain.lua').write_text((ROOT/'tests/native/xianyu_classic_recovery.lua').read_text(encoding='utf-8'),encoding='utf-8')
for n in c.names:
 (c.cluster/n/'modoverrides.lua').write_text('return {VaultAudit={enabled=true},ShadowWorld={enabled=true,configuration_options={["World Exchange"]="exchange_v1_original",["Container Sort"]=-3,["Tackle Receptacle Use Fish Redeem"]=-1}}}')
report={'cluster':str(c.out),'seed':str(previous),'checks':[]}
def check(name,ok,**extra):
 report['checks'].append(dict(name=name,passed=bool(ok),**extra));print(name,bool(ok),flush=True);assert ok,extra
def values(v):return v.values()if isinstance(v,dict)else []
try:
 c.start();time.sleep(3)
 states={n:c.call(n,'XiInspect()','xi_state')for n in c.names};report['state']=states
 check('final-source two-shard reload ready',all(r['ready'] and not r.get('error')for r in states.values()))
 totals={}
 for r in states.values():
  check('recovered transfers and overflow stay empty',not r['pending'] and not r['imports'] and not r['second'] and not r['tacklesecond'])
  for bank in [r['shadow'],r['tackle']]+[i for mode,b in r['banks'].items()if mode!='classic'for i in values(b)]:
   for item in values(bank):totals[item['prefab']]=totals.get(item['prefab'],0)+item['count']
 check('completed recovery never replays old goods',totals==expected['seed_totals'],actual=totals,expected=expected['seed_totals'])
 for n in c.names:
  row=c.call(n,'XiOpen()','opened');check('saved native tackle entrance opens '+n,row['canonical'])
 before={n:len(c.events(n))for n in c.names};c.command('Master','TheWorld:PushEvent("ms_save")')
 for n in c.names:c.wait(n,'archive_saved',after=before[n],timeout=40)
 check('ordinary coordinated save completes',True)
 report['status']='passed'
except Exception:report.update(status='failed',error=traceback.format_exc());print(report['error'],flush=True)
finally:
 c.stop();dest=c.out/'xianyu-classic-resume-report.json';dest.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');print('REPORT',dest,flush=True)
raise SystemExit(report['status']!='passed')
