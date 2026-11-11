"""Final-input native recovery smoke plus native shutdown with a pending offer."""
from pathlib import Path
import sys,json,time,traceback
sys.path.insert(0,str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster,ROOT,ledger
seed=ROOT/'work/vault-hardened-hosted-4vaj5382/config/Audit'
c=Cluster('hosted',2,seed,ROOT/'content');r={'cluster':str(c.out),'checks':[],'status':'running'}
def check(label):
    s=c.settle();r['checks'].append({'label':label,'state':s,'actual':ledger(s)})
    assert ledger(s)=={'gold':17} and all(x['pending']==0 and not x.get('error') for x in s.values()),label
    print(label,ledger(s),flush=True)
try:
    c.start();c.call('Caves','VaultAudit.restoreuid("KU_VA_2_1",1)','profile');check('final_input_recovers_saved_cluster')
    c.open('Caves');c.action('Caves',1,'deposit',1);check('deposit_after_restore')
    c.stop();c.start();c.call('Caves','VaultAudit.restoreuid("KU_VA_2_1",1)','profile');check('both_shards_recover_without_world_save')
    c.open('Caves');c.fault('blackhole');c.action('Caves',1,'withdraw',1);time.sleep(.3)
    s=c.state('pending_offer');assert s['Caves']['pending']>0
    start=time.monotonic();c.command('Caves','c_shutdown(true)');code=c.children['Caves'].wait(timeout=20)
    r['shutdown_seconds']=time.monotonic()-start;r['shutdown_exit_code']=code
    assert code==0;r['status']='passed'
except Exception:
    r['status']='failed';r['error']=traceback.format_exc();print(r['error'],flush=True)
finally:
    c.stop();dest=ROOT/'development/validation/vault-practical-final-recovery-20261106.json'
    dest.write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8');print('REPORT',dest,flush=True)
raise SystemExit(0 if r['status']=='passed' else 1)
