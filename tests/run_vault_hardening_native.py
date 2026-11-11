"""Run native vault hardening cases sequentially; preserve each isolated result."""
from pathlib import Path
from types import SimpleNamespace
import json
import sys
import argparse
sys.path.insert(0,str(Path(__file__).resolve().parent))
from run_vault_comparison import run,ROOT

cases=[('matrix',4,None),('dup_cut',2,'native-shadow-vault-2j510173'),
       ('torn_save',2,'native-shadow-vault-2j510173'),('full_restart',2,'native-shadow-vault-2j510173'),
       ('recover_saved',2,'vault-compare-hosted-befwyffp'),('offline_rollback',2,'native-shadow-vault-2j510173'),
       ('interrupted',2,'native-shadow-vault-2j510173'),('complex',2,'native-shadow-vault-2j510173')]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--case',nargs='+',choices=[c[0] for c in cases])
parser.add_argument('--report',type=Path,default=ROOT/'development/validation/vault-hardening-20261106-native.json')
args=parser.parse_args()
if args.case:cases=[c for c in cases if c[0] in args.case]
results=[]
for scenario,shards,seed in cases:
    result=run(SimpleNamespace(variant='hosted',scenario=scenario,shards=shards,rounds=3,
        source=ROOT/'content',seed=ROOT/'work'/seed/'config/Audit' if seed else None))
    results.append(result)
    args.report.write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
    if result['status']!='finished':break
failures=[(r['scenario'],c['name']) for r in results for c in r['checks']
          if (c.get('conserved') is False and all(s['pending']==0 for s in c['state'].values()))
          or any(c.get(k) is False for k in ('stale_rejected','completed','held','one_delivery','other_item_untouched'))]
print('NATIVE FAILURES',failures,flush=True)
raise SystemExit(1 if len(results)!=len(cases) or any(r['status']!='finished' for r in results) or failures else 0)
