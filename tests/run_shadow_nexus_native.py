"""Validate new integration with old config values, offline pages, restart and disable."""
from pathlib import Path
import sys,json,time,traceback
sys.path.insert(0,str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster,ROOT,ledger
c=Cluster('hosted',2,ROOT/'work/native-shadow-vault-2j510173/config/Audit',ROOT/'content')
r={'cluster':str(c.out),'checks':[],'status':'running'}
fixture=c.runtime/'mods/VaultAudit/modmain.lua'
with fixture.open('a',encoding='utf-8') as f:f.write(r'''
function A.nexus_runtime()
    for name in pairs(package.loaded) do
        for _,old in ipairs({"worldexchangeengine2hm","worldexchangecheckpoint2hm","worldexchangeinstant2hm","shadowvaultsnapshot2hm","shadowvaultsnapshotcore2hm"}) do
            assert(not tostring(name):find(old,1,true),"retired coordinator was loaded: "..name)
        end
    end
    local v=service();assert(v.journal and v.journal.ready and v.protocol.mode=="journal")
    local legacy=TheWorld.components.worldexchange2hm
    assert(legacy and not legacy.Update and not legacy.Request and not legacy.task,"old reader must be passive")
    emit({kind="nexus_runtime",enabled=TUNING.SHADOWVAULT_ENABLED2HM})
end
''')
def mode(value):
    for name in c.names:
        (c.cluster/name/'modoverrides.lua').write_text('return {VaultAudit={enabled=true},ShadowWorld={enabled=true,configuration_options={["World Exchange"]="'+value+'",["Container Sort"]=-3}}}',encoding='utf-8')
def check(label):
    s=c.settle();r['checks'].append({'label':label,'actual':ledger(s),'state':s})
    assert ledger(s)=={'gold':17} and all(x['pending']==0 and not x.get('error') for x in s.values()),label
    print(label,ledger(s),flush=True)
def runtime():
    return {n:c.call(n,'VaultAudit.nexus_runtime()','nexus_runtime') for n in c.children}
try:
    mode('coordinated');c.start();r['old_setting_runtime']=runtime()
    c.open('Caves');c.seed('Master','bank',2,'goldnugget',17,'gold',1);c.saveall();check('legacy_setting_uses_nexus')
    c.action('Caves',1,'withdraw',1);check('remote_withdraw')
    c.action('Caves',1,'deposit',1);check('remote_deposit')
    c.stop(['Caves']);c.open('Master',page=2)
    c.action('Master',1,'withdraw',1);check('offline_page_withdraw')
    c.action('Master',1,'deposit',1);check('offline_page_deposit')
    c.start(['Caves']);check('source_rejoined')
    c.stop();c.start();r['restart_runtime']=runtime();c.call('Caves','VaultAudit.restore(1)','restored');check('journal_restart')
    c.stop();mode('off');c.start();r['disabled_runtime']=runtime();check('disabled_preserves_existing_spaces')
    assert not any(x['enabled'] for x in r['disabled_runtime'].values())
    c.call('Caves','VaultAudit.restore(1)','restored');before=len(c.events('Master'))
    c.fault('blackhole');c.call('Caves','VaultAudit.migrate(1,"1",1)','migrate_requested')
    c.wait('Master','migrant_arrived',after=before,timeout=8)
    r['disabled_native_migration']='passed'
    r['status']='passed'
except Exception:
    r['status']='failed';r['error']=traceback.format_exc();print(r['error'],flush=True)
finally:
    c.stop();out=ROOT/'development/validation/shadow-nexus-integration-native-20261106.json'
    out.write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8');print('REPORT',out,flush=True)
raise SystemExit(0 if r['status']=='passed' else 1)
