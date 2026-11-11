"""Two real UM branches, independent weapon permission, craft/fire/save identity."""
from pathlib import Path
import argparse,json,sys,traceback,_winapi
sys.path.insert(0,str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster,ROOT

sys.stdout.reconfigure(encoding="utf-8")
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--um',choices=['stable','beta'],default='beta')
p.add_argument('--access',choices=['on','off'],default='off')
p.add_argument('--restart',action='store_true')
a=p.parse_args()
c=Cluster('hosted',1,ROOT/'work/reuse-audit/config/Audit',ROOT/'content')
uid={'stable':'2039181790','beta':'3193922031'}[a.um]
source=ROOT/'work/newconstant-research/steamcmd/steamapps/workshop/content/322330'/uid
_winapi.CreateJunction(str(source),str(c.runtime/'mods'/('workshop-'+uid)))
fixture='MOONAMMO_ACCESS='+str(a.access=='on').lower()+'\n'+(ROOT/'tests/native/walter_moonglass_probe.lua').read_text(encoding='utf-8')
(c.runtime/'mods/VaultAudit/modmain.lua').write_text(fixture,encoding='utf-8')
options={'enable easy mode':a.access=='on','enable hard mode':a.access=='on','um_patch':False,
 'Walter Use Wixie Slingshot':a.access=='on','Shadow World':False,'rangesupermonster':False,'specialsupermonster':False}
def lv(v):return str(v).lower()if isinstance(v,bool)else str(v)
cfg=','.join('['+json.dumps(k)+']='+lv(v)for k,v in options.items())
(c.cluster/'Master/modoverrides.lua').write_text('return {VaultAudit={enabled=true},ShadowWorld={enabled=true,configuration_options={'+cfg+'}},["workshop-'+uid+'"]={enabled=true}}',encoding='utf-8')
r={'um':a.um,'access':a.access,'restart':a.restart,'cluster':str(c.out)}
try:
 c.start()
 r['result']=c.call('Master','VaultAudit.run()','moonammo',timeout=60)
 assert r['result']['passed'],r['result']
 if a.restart:
  c.command('Master','c_shutdown(true)');assert c.children['Master'].wait(timeout=60)==0
  c.stop();c.start()
  r['reload']=c.call('Master','VaultAudit.reload()','moonammo_reload',timeout=30)
  assert r['reload']['passed'],r['reload']
 r['status']='passed'
except Exception:
 r.update(status='failed',error=traceback.format_exc());print(r['error'],flush=True)
finally:
 c.stop();out=c.out/'walter-moonammo-result.json';out.write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8');print(out,flush=True)
raise SystemExit(0 if r['status']=='passed'else 1)
