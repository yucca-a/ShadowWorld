"""Real Legion boss recall and vanilla underground-boss corruption in disposable DST."""
from pathlib import Path
import argparse, hashlib, json, sys, traceback, _winapi
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster, ROOT
sys.stdout.reconfigure(encoding='utf-8')
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--before',type=Path)
parser.add_argument('--um',action='store_true')
parser.add_argument('--filter',help='Run case names containing this literal substring')
args=parser.parse_args()
c=Cluster('hosted',1,ROOT/'work/reuse-audit/config/Audit',ROOT/'content')
if args.before:
    (c.out/'input/shadowworld.lua').write_bytes(args.before.read_bytes())
    manifest_path=c.out/'input-manifest.json'
    manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
    manifest['shadowworld.lua']=hashlib.sha256(args.before.read_bytes()).hexdigest()
    manifest_path.write_text(json.dumps(manifest,indent=2),encoding='utf-8')
prefix=('SHADOW_TRANSFORM_FILTER='+json.dumps(args.filter)+'\n') if args.filter else ''
(c.runtime/'mods/VaultAudit/modmain.lua').write_text(prefix+(ROOT/'tests/native/shadow_transform_probe.lua').read_text(encoding='utf-8'),encoding='utf-8')
extra=''
for uid in ['1392778117']+(['3193922031'] if args.um else []):
    _winapi.CreateJunction(str(Path('D:/SteamLibrary/steamapps/workshop/content/322330')/uid),str(c.runtime/'mods'/('workshop-'+uid)))
    extra+=',["workshop-'+uid+'"]={enabled=true}'
(c.cluster/'Master/modoverrides.lua').write_text('return {VaultAudit={enabled=true},ShadowWorld={enabled=true,configuration_options={["enable hard mode"]=true,["Shadow World"]=1,["Shadow Animals"]=false,["Shadow Attack Player Actively"]=false,["Shadow Harder Level"]=false}}'+extra+'}',encoding='utf-8')
report={'cluster':str(c.out),'before':str(args.before) if args.before else None,'um':args.um,
        'filter':args.filter,
        'shadowworld_sha256':hashlib.sha256((c.out/'input/shadowworld.lua').read_bytes()).hexdigest()}
try:
    c.start()
    result=c.call('Master','VaultAudit.shadow_transform()','shadow_transform',timeout=180)
    report['result']=result
    report['cases']=[r for r in c.events('Master') if r.get('kind')=='shadow_transform_case']
    names=['tree_'+p+'_'+m for p in ['shyerrycored','shyerrycored_lunar'] for m in ['parent_death','child_lethal','child_remove','original_retire']]
    names += [s+p for p in ['rocky_boss','bat_boss','worm_boss'] for s in ['single_','pair_']]
    if args.filter:names=[n for n in names if args.filter in n]
    assert names and [r['name'] for r in report['cases']]==names,report
    if args.before:
        failed=[r for r in report['cases'] if not r['passed']]
        for category in ['tree_','pair_']:
            if any(n.startswith(category) for n in names):assert any(r['name'].startswith(category) for r in failed),failed
        assert all(r['passed'] for r in report['cases'] if r['name'].startswith('single_')),report['cases']
    else:
        assert result['passed'],report['cases']
    report['status']='reproduced' if args.before else 'passed'
except Exception:
    report.update(status='failed',error=traceback.format_exc());print(report['error'],flush=True)
finally:
    c.stop()
    path=c.out/'shadow-transform-result.json'
    path.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');print(path,flush=True)
raise SystemExit(0 if report['status']!='failed' else 1)
