"""Real station/sweeper trades and continuous shadow-magic expiry in isolated DST."""
from pathlib import Path
import argparse,json,sys,traceback,_winapi
sys.path.insert(0,str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster,ROOT
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--edition',choices=['solo','stable','beta'],default='solo')
parser.add_argument('--disabled',action='store_true')
parser.add_argument('--restart',action='store_true')
args=parser.parse_args()
sys.stdout.reconfigure(encoding='utf-8')
c=Cluster('hosted',1,ROOT/'work/reuse-audit/config/Audit',ROOT/'content')
script=(ROOT/'tests/native/shadowmagic_probe.lua').read_text(encoding='utf-8')
(c.runtime/'mods/VaultAudit/modmain.lua').write_text('SHADOWMAGIC_DISABLED='+('true'if args.disabled else'false')+'\n'+script,encoding='utf-8')
extra=''
if args.edition!='solo':
    uid='3193922031'if args.edition=='beta'else'2039181790'
    _winapi.CreateJunction('D:/SteamLibrary/steamapps/workshop/content/322330/'+uid,str(c.runtime/'mods'/('workshop-'+uid)))
    extra=',["workshop-'+uid+'"]={enabled=true}'
(c.cluster/'Master/modoverrides.lua').write_text('return {VaultAudit={enabled=true},ShadowWorld={enabled=true,configuration_options={'
    '["enable hard mode"]=true,["enable easy mode"]=true,["Prestihatitator Redeem shadowmagic Tag"]='+('false'if args.disabled else'true')+','
    '["Reskin Tool Upgrade"]=true,["Shadow World"]=false,["Random Sized"]=false}}'+extra+'}',encoding='utf-8')
report={'cluster':str(c.out),'edition':args.edition,'disabled':args.disabled}
try:
    c.start()
    report['result']=c.call('Master','VaultAudit.shadowmagic()','shadowmagic',timeout=60)
    report['cases']=[r for r in c.events('Master')if r['kind']=='shadowmagic_case']
    if args.restart and not args.disabled:
        report['export']=c.call('Master','VaultAudit.export_shadowmagic()','shadowmagic_export',timeout=30)
        c.stop();c.start()
        report['import']=c.call('Master','VaultAudit.import_shadowmagic()','shadowmagic_import',timeout=30)
    report['status']='passed'
except Exception:
    report.update(status='failed',error=traceback.format_exc());print(report['error'],flush=True)
finally:
    c.stop()
    path=c.out/'shadowmagic-result.json'
    path.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(path,flush=True)
raise SystemExit(report['status']=='failed')
