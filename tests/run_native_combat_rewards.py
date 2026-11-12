"""Exercise real weapons, songs, protected bell-bound beefalo and playing cards."""
from pathlib import Path
import argparse
import json
import sys
import traceback
import _winapi

sys.path.insert(0,str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster,ROOT
sys.stdout.reconfigure(encoding='utf-8')
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--edition',choices=['solo','stable','beta'],default='beta')
parser.add_argument('--observe-only',action='store_true')
parser.add_argument('--source',type=Path,default=ROOT/'content')
args=parser.parse_args()
c=Cluster('hosted',1,ROOT/'work/reuse-audit/config/Audit',args.source)
(c.runtime/'mods/VaultAudit/modmain.lua').write_text('WITH_WATHOM='+('false'if args.edition=='solo'else'true')+'\n'+(ROOT/'tests/native/combat_rewards_probe.lua').read_text(encoding='utf-8'),encoding='utf-8')
extra=''
if args.edition!='solo':
    uid='3193922031'if args.edition=='beta'else'2039181790'
    _winapi.CreateJunction('D:/SteamLibrary/steamapps/workshop/content/322330/'+uid,str(c.runtime/'mods'/('workshop-'+uid)))
    extra=',["workshop-'+uid+'"]={enabled=true}'
(c.cluster/'Master/modoverrides.lua').write_text('return {VaultAudit={enabled=true},ShadowWorld={enabled=true,configuration_options={'
    '["enable hard mode"]=true,["enable easy mode"]=true,["beefalo"]=true,["Shieldofterror Eat Owner"]=true,'
    '["Shadow World"]=false,["Random Sized"]=false}}'+extra+'}',encoding='utf-8')
report={'cluster':str(c.out),'edition':args.edition,'observe_only':args.observe_only}
try:
    c.start()
    report['result']=c.call('Master','VaultAudit.combat_rewards()','combat_rewards',timeout=100)
    report['cases']=[row for row in c.events('Master')if row['kind']=='combat_reward_case']
    assert len(report['cases'])==(6 if args.edition=='solo'else 16),report
    if not args.observe_only:
        for row in report['cases']:
            name=row['case']
            if name.startswith('protected_cow_'):
                assert row['healing']==0 and row['damage']==0 and row['adrenaline']==0,row
            if name.startswith('enemy_'):
                assert row['damage']>0,row
                if name not in ('enemy_spear','enemy_leap'):assert row['healing']>0,row
            if name.startswith('songs_deck'):
                assert row['healing']==0 and row['sanity']==0,row
            if name.startswith('songs_pigman'):
                assert row['healing']>0 and row['sanity']>0,row
            if name=='shield_deck_of_cards':assert row['condition']<0 and row['bites']==0 and row['valid']and not row['canfeed'],row
            if name=='shield_pigman':assert row['condition']>0,row
            if name.endswith('_leap'):assert row['hits']==1 and row['paused']==(name=='enemy_leap'),row
            if name=='enemy_leap':assert row['adrenaline']>0,row
            if name=='protected_cow_stacked_axe':assert not row['buffed'],row
    report['status']='observed'if args.observe_only else'passed'
except Exception:
    report.update(status='failed',error=traceback.format_exc());print(report['error'],flush=True)
finally:
    c.stop()
    path=c.out/'combat-rewards-result.json'
    path.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(path,flush=True)
raise SystemExit(report['status']=='failed')
