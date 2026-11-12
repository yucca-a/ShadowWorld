"""Real hat/tool/container and native moonstorm movement in a disposable server."""
from pathlib import Path
import json,sys,traceback
sys.path.insert(0,str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster,ROOT
c=Cluster('hosted',1,ROOT/'work/reuse-audit/config/Audit',ROOT/'content')
(c.runtime/'mods/VaultAudit/modmain.lua').write_text((ROOT/'tests/native/moonstorm_goggles_probe.lua').read_text(encoding='utf-8'),encoding='utf-8')
(c.cluster/'Master/modoverrides.lua').write_text('''return {VaultAudit={enabled=true},ShadowWorld={enabled=true,configuration_options={
["enable easy mode"]=true,["enable hard mode"]=true,["weather_change"]=true,["moonisland"]=true,
["Turf-Raiser Helm Plant Tree Cone"]=true}}}''',encoding='utf-8')
report={'cluster':str(c.out)}
try:
    c.start();before=len(c.events('Master'));c.command('Master','VaultAudit.moonstorm_goggles()')
    report['result']=c.wait('Master','moonstorm_goggles',after=before,timeout=40)
    assert report['result']['passed'],report['result']
    report['status']='passed'
except Exception:
    report.update(status='failed',error=traceback.format_exc());print(report['error'])
finally:
    c.stop();p=c.out/'moonstorm-goggles-result.json';p.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');print(p,flush=True)
raise SystemExit(report['status']!='passed')
