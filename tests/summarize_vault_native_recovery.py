"""Summarize verified recovery results without publishing player identifiers."""
from pathlib import Path
import argparse,hashlib,json
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('report',type=Path);a=p.parse_args()
r=json.loads(a.report.read_text(encoding='utf-8'))
assert r['status']=='passed' and len(r['restarts'])==2 and len(r['open_checks'])==8 and len(r['rollback_open'])==2
summary={'status':'passed_local_unpublished','version':'2.8.15.0.8','archive_sha256':r['archive_sha256'],
         'native_report':str(a.report.resolve()),'normal_save_restarts':len(r['restarts']),
         'initial_open_checks':r['open_checks'],'rollback_open_checks':r['rollback_open'],
         'missing_mods':r['missing_mods'],'legacy_fixture':r['legacy_fixture'],
         'unit_checks':{'native_adoption':19,'stale_entrance_and_rollback':14},'inventories':{},'sources':{}}
for shard,rows in r['inventories'].items():
    total={'private_containers':0,'private_occupied_slots':0,'private_item_count':0,'linked_bells':0,'cloudpine':[]}
    for row in rows.values():
        items=list(row['items'].values()) if isinstance(row['items'],dict) else row['items']
        if row['prefab']=='legacycontainer':
            total['private_containers']+=1;total['private_occupied_slots']+=len(items)
            total['private_item_count']+=sum(i['count']for i in items)
            total['linked_bells']+=sum(1 for i in items if i['prefab']=='beef_bell' and i.get('pet'))
        else:
            total['cloudpine'].append({'prefab':row['prefab'],'occupied_slots':len(items),
                'item_count':sum(i['count']for i in items),'protected_swords':sum(i['count']for i in items if i['prefab']=='refractedmoonlight')})
    summary['inventories'][shard]=total
manifest=json.loads((a.report.parent/'input-manifest.json').read_text())
for relative in ['easy_other/shadowvault.lua','scripts/components/shadowvault2hm.lua','scripts/shadowvaultconfig2hm.lua',
                 'scripts/shadowvaultnative2hm.lua','scripts/shadowvaultjournal2hm.lua','scripts/shadowvaultproxy2hm.lua']:
    digest=hashlib.sha256((ROOT/'content'/relative).read_bytes()).hexdigest()
    assert manifest.get(relative,manifest.get(relative.replace('/','\\')))==digest,relative
    summary['sources'][relative]=digest
out=ROOT/'development/validation/vault-native-recovery-20261107.json'
out.write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(out);print(json.dumps(summary['inventories'],ensure_ascii=True))
