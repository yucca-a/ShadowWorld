"""Disposable real-game regression for boss damage and shelter transitions."""
from pathlib import Path
import argparse,json,sys,time,traceback,_winapi
sys.path.insert(0,str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster,ROOT
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source',type=Path,default=ROOT/'content')
parser.add_argument('--edition',choices=['none','stable','beta'],default='beta')
parser.add_argument('--label',default='current')
parser.add_argument('--um-eyebrella',action='store_true',help='Also enable the installed UM eyebrella rule')
parser.add_argument('--legacy-defaults',action='store_true',help='Start with the obsolete numeric tier-1 host settings')
args=parser.parse_args()
sys.stdout.reconfigure(encoding='utf-8')
c=Cluster('hosted',1,ROOT/'work/native-shadow-vault-2j510173/config/Audit',args.source)
uid={'stable':'2039181790','beta':'3193922031'}.get(args.edition)
if uid:_winapi.CreateJunction(str(Path('D:/SteamLibrary/steamapps/workshop/content/322330')/uid),str(c.runtime/'mods'/('workshop-'+uid)))
p=c.cluster/'Master/modoverrides.lua'
cfg=p.read_text().replace('["World Exchange"]="hosted",','').replace('["Container Sort"]=-3','["Container Sort"]=-3,boss_health=false')
if args.legacy_defaults:cfg=cfg.replace('boss_health=false','boss_health=false,combat=1,epic_armor_5=1')
if uid:cfg=cfg[:-1]+f',["workshop-{uid}"]={{enabled=true,configuration_options={{eyebrellarework={str(args.um_eyebrella).lower()}}}}}}}'
p.write_text(cfg)
with(c.runtime/'mods/VaultAudit/modmain.lua').open('a',encoding='utf-8')as f:
    f.write((ROOT/'tests/native/combat_shade_probe.lua').read_text(encoding='utf-8'))
r={'cluster':str(c.out),'edition':args.edition,'label':args.label,'um_eyebrella':args.um_eyebrella,'legacy_defaults':args.legacy_defaults,'cases':[]}
def call(cmd,event):return c.call('Master','VaultAudit.'+cmd,event)
try:
    c.start();c.settle()
    r['hat']=call('balance_setup()','balance_setup')
    for label,natural,level,temp,mounted in [
        ('hat_hot',False,1,70,False),('enter_real_canopy',True,2,70,False),
        ('leave_canopy_cool',False,1,40,False),('mount',False,1,40,True),
        ('dismount',False,1,40,False),('ordinary_shade_hot',True,1,70,False),
    ]:
        row=call(f'shade_step("{label}",{str(natural).lower()},{level},{temp},{str(mounted).lower()})','shade_step')
        r['cases'].append(row)
    for prefab in ['bearger','deerclops','dragonfly']:
        r['cases'].append(call(f'armor_burst("{prefab}")','armor_burst'))
    r['combat']=call('combat_values()','combat_values')
    r['mount']=call('actual_mount(true)','actual_mount')
    r['dismount']=call('actual_mount(false)','actual_mount')
    r['weather']=call('hat_weather()','hat_weather')
    r['saved_hat']=call('hat_save_load()','hat_save_load')
    r['lifecycle']=call('shade_lifecycle()','shade_lifecycle')
    r['sustained']=call('armor_sustained()','armor_sustained')
    if args.label!='published':
        assert r['hat']['fueltype']=='EYE'and r['hat']['maxfuel']==5760 and r['hat']['insulation']>=240,r['hat']
        for row in r['cases']:
            if row['kind']=='shade_step':assert row['level']==row['temperaturelevel'],row
            else:
                assert row['component']and row['fx']and row['rows'][2]['loss']<row['rows'][0]['loss'],row
        for name in ['mount','dismount']:
            assert r[name]['mounted']==(name=='mount')and r[name]['sheltered']and r[name]['temperaturelevel']==2,r[name]
        assert r['weather']['healed']and not r['weather']['acidhealed']and r['weather']['accepts_milk'],r['weather']
        assert r['weather']['repaired'],r['weather']
        assert abs(r['combat']['values']['10']-3.75)<1e-6,r['combat']
        assert abs(r['saved_hat']['before']-r['saved_hat']['after'])<2,r['saved_hat']
        assert not r['lifecycle']['bare']and r['lifecycle']['stopped']and r['lifecycle']['sheltered']and r['lifecycle']['temperaturelevel']==2,r['lifecycle']
        peak=r['sustained']['peak']
        assert 0<peak<.95,peak
    r['status']='observed'if args.label=='published'else'passed'
except Exception:
    r.update(status='failed',error=traceback.format_exc());print(r['error'],flush=True)
finally:
    c.stop()
    path=ROOT/f'work/combat-shade-{args.edition}-{args.label}.json'
    path.write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8')
    print(str(path),flush=True)
raise SystemExit(1 if r['status']=='failed'else 0)
