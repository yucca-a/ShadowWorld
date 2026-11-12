"""Test real WX-78 circuits, armor, food and saved items in an isolated DST server."""
from pathlib import Path
import argparse,json,sys,traceback,_winapi
sys.path.insert(0,str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster,ROOT
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--edition',choices=['solo','stable','beta'],default='solo')
parser.add_argument('--mode',choices=['draft','legacy','easy','hard','off'],default='draft')
parser.add_argument('--roundtrip',action='store_true',help='Save actual legacy WX-78, restart into draft, then restart back to legacy')
args=parser.parse_args()
sys.stdout.reconfigure(encoding='utf-8')
c=Cluster('hosted',1,ROOT/'work/reuse-audit/config/Audit',ROOT/'content')
script=(ROOT/'tests/native/wx78_modes_probe.lua').read_text(encoding='utf-8')
(c.runtime/'mods/VaultAudit/modmain.lua').write_text('WX_MODE="'+args.mode+'"\n'+script,encoding='utf-8')
extra=''
if args.edition!='solo':
    uid='3193922031'if args.edition=='beta'else'2039181790'
    _winapi.CreateJunction('D:/SteamLibrary/steamapps/workshop/content/322330/'+uid,str(c.runtime/'mods'/('workshop-'+uid)))
    extra=',["workshop-'+uid+'"]={enabled=true}'
# Explicit modes must work with both global role gates disabled.
def configure(mode):
    enabled='true'if mode=='legacy'else'false'
    selector=''if mode=='legacy'else'["WX-78 Mode"]="'+mode+'",'
    (c.cluster/'Master/modoverrides.lua').write_text('return {VaultAudit={enabled=true},ShadowWorld={enabled=true,configuration_options={'
        '["enable hard mode"]='+enabled+',["enable easy mode"]='+enabled+','+selector+
        '["Shadow World"]=false,["Random Sized"]=false}}'+extra+'}',encoding='utf-8')
configure('legacy'if args.roundtrip else args.mode)
report={'cluster':str(c.out),'edition':args.edition,'mode':args.mode}
try:
    c.start()
    if args.roundtrip:
        report['legacy_export']=c.call('Master','VaultAudit.wx78_export()','wx78_export',timeout=30)
        c.stop();configure('draft');c.start()
        report['draft_import']=c.call('Master','VaultAudit.wx78_import(false)','wx78_import',timeout=30)
        c.stop();configure('legacy');c.start()
        report['legacy_return']=c.call('Master','VaultAudit.wx78_import(true)','wx78_import',timeout=30)
        c.stop();configure(args.mode);c.start()
    report['result']=c.call('Master','VaultAudit.wx78_modes()','wx78_modes',timeout=60)
    report['cases']=[r for r in c.events('Master')if r['kind']=='wx78_case']
    report['status']='passed'
except Exception:
    report.update(status='failed',error=traceback.format_exc());print(report['error'],flush=True)
finally:
    c.stop()
    path=c.out/'wx78-modes-result.json'
    path.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(path,flush=True)
raise SystemExit(report['status']=='failed')
