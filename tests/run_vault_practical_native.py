"""Native vault journal tests: independent recovery, overflow, packets and travel."""
from pathlib import Path
import sys,json,time,traceback,argparse
sys.path.insert(0,str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster,ROOT,ledger
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--four',action='store_true')
p.add_argument('--report',type=Path,default=ROOT/'development/validation/vault-practical-native-20261106.json')
a=p.parse_args()
c=Cluster('hosted',4 if a.four else 2,None if a.four else ROOT/'work/native-shadow-vault-2j510173/config/Audit',ROOT/'content')
r={'cluster':str(c.out),'four':a.four,'checks':[],'travel':[],'status':'running'}
def check(label,expected=None,settle=True):
    s=c.settle(65) if settle else c.state(label)
    expected={'gold':17} if expected is None else expected
    row={'label':label,'actual':ledger(s),'expected':expected,'state':s};r['checks'].append(row)
    print(label,ledger(s),flush=True)
    assert ledger(s)==expected and not any(x.get('error') for x in s.values()),label
    if settle:assert all(x['pending']==0 for x in s.values()),label+' pending'
    return s
def travel(origin,dest):
    before={n:len(c.events(n)) for n in (origin,dest)}
    requested=c.call(origin,'VaultAudit.migrate(1,"'+str(c.names.index(dest)+1)+'",1)','migrate_requested')
    departed=c.wait(origin,'migrant_departed',after=before[origin],timeout=8)
    c.wait(dest,'migrant_arrived',after=before[dest],timeout=8)
    delay=departed['time']-requested['time'];assert delay<2
    r['travel'].append({'from':origin,'to':dest,'seconds':delay});time.sleep(.3)
try:
    c.start();c.open('Caves');c.seed('Master','bank',2,'goldnugget',17,'gold',1);c.saveall()
    baseline=check('baseline');masterboot=baseline['Master']['runtimeboot']
    if a.four:
        c.stop(['Layer4']);c.open('Layer3',page=2)
        c.action('Layer3',1,'withdraw',1);check('cross_page_with_fourth_offline')
        c.action('Layer3',1,'deposit',1);check('cross_page_return')
        c.stop(['Caves']);c.open('Master',page=2)
        c.action('Master',1,'withdraw',1);check('master_with_owner_offline')
        c.action('Master',1,'deposit',1);check('master_offline_return')
        c.start(['Caves','Layer4']);check('four_rejoined')
    else:
        for fault in ('none','duplicate','loss','reorder'):
            c.fault(fault)
            for i in range(2):
                c.action('Caves',1,'withdraw',1);s=check(fault+'_withdraw_'+str(i))
                assert s['Caves']['locations'].get('KU_VA_2_1')==17
                c.action('Caves',1,'deposit',1);s=check(fault+'_deposit_'+str(i))
                assert s['Master']['banks']['2']['1']['count']==17
        c.fault('none');s=check('no_forced_world_save')
        assert all(s[n]['saves']==baseline[n]['saves'] for n in s),'transfers forced a world save'
        # Only the cave process restarts. Unrelated unsaved master progress must
        # survive; restoration reads only the local independent vault journal.
        c.command('Master','TheWorld._audit_unrelated_progress=77')
        c.stop(['Caves']);c.start(['Caves']);s=check('source_only_restart')
        assert s['Master']['runtimeboot']==masterboot
        c.command('Master','assert(TheWorld._audit_unrelated_progress==77)')
        c.call('Caves','VaultAudit.restore(1)','restored');check('deposited_profile_deduplicated')
        c.open('Caves');c.action('Caves',1,'withdraw',1);check('withdraw_before_unsaved_crash')
        c.stop(['Caves']);c.start(['Caves']);c.call('Caves','VaultAudit.restore(1)','restored')
        s=check('withdrawal_survives_source_crash');assert s['Master']['runtimeboot']==masterboot
        c.open('Caves');c.action('Caves',1,'deposit',1);check('return_before_overflow')
        c.call('Caves','VaultAudit.fill(1)','filled');c.action('Caves',1,'withdraw',1);time.sleep(3)
        s=check('overflow',settle=False);assert s['Caves']['pending']==1
        c.fault('blackhole');travel('Caves','Master');travel('Master','Caves')
        c.fault('none');time.sleep(3);check('overflow_returns_with_player',settle=False)
        c.call('Caves','VaultAudit.unfill(1)','unfilled');check('overflow_delivered_once')
        c.open('Caves');c.action('Caves',1,'deposit',1);check('return_before_master_restart')
        c.stop(['Master']);c.start(['Master']);check('master_independent_restart')
        c.open('Caves');c.action('Caves',1,'withdraw',1);check('remote_after_master_restart')
        c.saveall();c.stop();c.start();c.call('Caves','VaultAudit.restoreuid("KU_VA_2_1",1)','profile')
        check('saved_whole_cluster_restart')
    r['status']='passed'
except Exception:
    r['status']='failed';r['error']=traceback.format_exc();print(r['error'],flush=True)
finally:
    c.stop();a.report.write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8')
    print('REPORT',a.report,flush=True)
raise SystemExit(0 if r['status']=='passed' else 1)
