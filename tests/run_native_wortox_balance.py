"""Run genuine lethal hits, saved timers and passive souls in a disposable DST server."""
from pathlib import Path
import argparse,json,sys,traceback,_winapi
sys.path.insert(0,str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster,ROOT
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--edition',choices=['solo','stable','beta'],default='beta')
parser.add_argument('--overhaul',choices=['on','off'],default='on')
parser.add_argument('--real-time',action='store_true')
args=parser.parse_args()
sys.stdout.reconfigure(encoding='utf-8')
c=Cluster('hosted',1,ROOT/'work/reuse-audit/config/Audit',ROOT/'content')
script=(ROOT/'tests/native/wortox_balance_probe.lua').read_text(encoding='utf-8')
(c.runtime/'mods/VaultAudit/modmain.lua').write_text('BALANCE_EDITION="'+args.edition+'"\nBALANCE_OVERHAUL='+('true'if args.overhaul=='on'else'false')+'\nBALANCE_REAL_TIME='+('true'if args.real_time else'false')+'\n'+script,encoding='utf-8')
extra=''
if args.edition!='solo':
    uid='3193922031'if args.edition=='beta'else'2039181790'
    _winapi.CreateJunction('D:/SteamLibrary/steamapps/workshop/content/322330/'+uid,str(c.runtime/'mods'/('workshop-'+uid)))
    extra=',["workshop-'+uid+'"]={enabled=true,configuration_options={wortox='+('true'if args.overhaul=='on'else'false')+'}}'
(c.cluster/'Master/modoverrides.lua').write_text('return {VaultAudit={enabled=true},ShadowWorld={enabled=true,configuration_options={'
    '["enable hard mode"]=true,["enable easy mode"]=true,["Wortox Auto Receive Soul"]=true,'
    '["Shadow World"]=false,["Random Sized"]=false}}'+extra+'}',encoding='utf-8')
report={'cluster':str(c.out),'edition':args.edition,'overhaul':args.overhaul,'real_time':args.real_time}
try:
    c.start()
    report['result']=c.call('Master','VaultAudit.wortox_balance()','wortox_balance',timeout=180 if args.real_time else 45)
    report['cases']=[r for r in c.events('Master')if r['kind']=='wortox_balance_case']
    report['status']='passed'
except Exception:
    report.update(status='failed',error=traceback.format_exc());print(report['error'],flush=True)
finally:
    c.stop()
    path=c.out/'wortox-balance-result.json'
    path.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(path,flush=True)
raise SystemExit(report['status']=='failed')
