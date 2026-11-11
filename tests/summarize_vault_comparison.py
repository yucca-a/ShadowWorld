"""Collect reproducible native evidence without counting in-flight escrow as loss."""
from pathlib import Path
import hashlib
import json
import statistics

ROOT=Path(__file__).resolve().parents[1]
INPUT=ROOT/'work/vault-comparison-20261106'
DEST=ROOT/'development/validation'
manifest=json.loads((INPUT/'input-manifest.json').read_text(encoding='utf-8'))
selected={};excluded=[]
for path in sorted((ROOT/'work').glob('vault-compare-*/result.json'),key=lambda p:p.stat().st_mtime):
    result=json.loads(path.read_text(encoding='utf-8'))
    if result['status']!='finished':
        excluded.append({'result':str(path),'reason':'Harness setup/runtime failure; excluded from implementation comparison'})
        continue
    selected[(result['variant'],result['scenario'])]=(path,result)

cases=[]
for (variant,scenario),(path,result) in sorted(selected.items()):
    rows=[]
    for check in result['checks']:
        if scenario=='matrix' and check['name']=='offline_local_roundtrip':
            # Earlier fixture used Inventory.GiveItem without clearing prevcontainer,
            # then attempted to give an item it never actually held a second time.
            # The later offline_rollback case checks real player ownership explicitly.
            excluded.append({'result':str(path),'check':check['name'],'reason':'Superseded by corrected offline_rollback fixture; native GiveItem previous-container routing was misused'})
            continue
        row={k:v for k,v in check.items() if k!='state'}
        state=check['state']
        row['pending']={n:s['pending'] for n,s in state.items()}
        row['quiescent']=all(s['pending']==0 for s in state.values())
        row['physical_count_is_final']=row['quiescent']
        if row.get('conserved') is False and not row['quiescent']:
            row['interpretation']='Pending serialized transfer/escrow; physical entities alone cannot establish loss. Compare post-recovery check.'
        row['properties']=[d for s in state.values() for d in s['details']]
        rows.append(row)
    case={'variant':variant,'scenario':scenario,'evidence':str(path),'checks':rows}
    if scenario=='matrix':
        checks=result['checks'];base=next(x for x in checks if x['name']=='baseline')['state']
        end=next(x for x in checks if x['name']=='durability_withdraw')['state']
        case['additional_native_save_callbacks']={n:end[n]['saves']-s['saves'] for n,s in base.items()}
        races=[x for x in checks if '_race_' in x['name']]
        case['request_attempts']=sum(x['attempts'] for x in races)
        case['race_count']=len(races)
        case['race_settle_seconds_median']=statistics.median(x['seconds'] for x in races)
        case['every_race_one_winner']=all(sum((s['goods'] or {}).get('gold',0) for n,s in x['state'].items() if n!='Master')==17 and (x['state']['Master']['goods'] or {}).get('gold',0)==0 for x in races)
    cases.append(case)

integrity={}
for variant,folder in [('hosted',INPUT/'hosted'),('xianyu',INPUT/'xianyu/test'),('working_content',ROOT/'content')]:
    expected=manifest['versions']['hosted' if variant=='working_content' else variant]
    changes=[name for name,digest in expected.items() if hashlib.sha256((folder/name).read_bytes()).hexdigest()!=digest]
    integrity[variant]={'checked_files':len(expected),'changed_files':changes}
summary={'date':'2026-11-06','game_build':761239,'archive_sha256':manifest['archive_sha256'],
    'scope':'Frozen Workshop implementations; actual native dedicated servers with scripted native player entities. No real client UI, WAN emulator, or production saves.',
    'integrity':integrity,'cases':cases,'excluded':excluded,
    'protocol_model':json.loads((INPUT/'protocol-stress-result.json').read_text()),
    'limitations':['Burst attempts are not all successful transfers.','Latency includes harness polling and settling; not a production throughput benchmark.',
                   'Native SaveGame calls deliberately split save timing to inject failures; not a measured frequency of normal server failures.',
                   'In-flight serialized records must not be counted as destroyed physical items.',
                   'No long-duration soak, complete mod compatibility matrix, real client UI, or arbitrary old-save repair certification.']}
DEST.mkdir(exist_ok=True)
out=DEST/'vault-comparison-20261106.json'
out.write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
(DEST/'vault-comparison-20261106-input-manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print(out)
for c in cases:
    bad=[x['name'] for x in c['checks'] if x.get('conserved') is False and x['quiescent']]
    print(c['variant'],c['scenario'],'settled_count_failures=',bad)
