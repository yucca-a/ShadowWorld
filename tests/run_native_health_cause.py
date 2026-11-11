"""Full-mod, disposable native server verification; never joins a player world."""
from pathlib import Path
import sys,json,_winapi,traceback
sys.path.insert(0,str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster,ROOT

sys.stdout.reconfigure(encoding='utf-8')
c=Cluster('hosted',1,ROOT/'work/native-shadow-vault-2j510173/config/Audit',ROOT/'content')
uid='3193922031'
_winapi.CreateJunction(str(Path('D:/SteamLibrary/steamapps/workshop/content/322330')/uid),str(c.runtime/'mods'/('workshop-'+uid)))
p=c.cluster/'Master/modoverrides.lua'
config=p.read_text()
p.write_text(config[:-1]+f',["workshop-{uid}"]={{enabled=true,configuration_options={{}}}}}}')
with(c.runtime/'mods/VaultAudit/modmain.lua').open('a',encoding='utf-8')as f:
    f.write((ROOT/'tests/native/health_cause_probe.lua').read_text(encoding='utf-8'))
report={'cluster':str(c.out),'edition':'UM beta'}
try:
    c.start();c.settle()
    report['result']=r=c.call('Master','VaultAudit.health_cause()','health_cause')
    assert r['native_name_crashed'] and 'concatenate' in r['native_error'],r
    for row in r['rows']:
        assert abs(row['current']-row['maximum']*.75)<1e-7,row
        if row['method']!='SetVal':assert row['cause']=='unnamed_health_source_audit2hm',row
    report['status']='passed'
except Exception:
    report.update(status='failed',error=traceback.format_exc());print(report['error'])
finally:
    c.stop()
    path=ROOT/'work/health-cause-native.json'
    path.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(str(path))
raise SystemExit(0 if report['status']=='passed' else 1)
