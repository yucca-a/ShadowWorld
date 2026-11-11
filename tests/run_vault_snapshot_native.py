"""Native interruption and migration cases for the no-forced-save vault."""
from pathlib import Path
import sys,json,time,argparse,traceback
sys.path.insert(0,str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster,ROOT,ledger

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--case',nargs='+',choices=['capture_crash','commit_crash','master_restart','secondary_restart','migration','item_migration','history','shutdown','shutdown_outage','controls'],required=True)
p.add_argument('--report',type=Path,default=ROOT/'development/validation/vault-no-forced-save-faults-20261106.json')
args=p.parse_args();results=[]
for case in args.case:
    c=Cluster('hosted',2,ROOT/'work/native-shadow-vault-2j510173/config/Audit',ROOT/'content')
    r={'case':case,'cluster':str(c.out),'checks':[]};results.append(r)
    def check(name,**flags):
        state=c.state(name)
        row={'name':name,'actual':ledger(state),'conserved':ledger(state)=={'gold':17},'state':state,**flags}
        r['checks'].append(row);print(json.dumps({k:v for k,v in row.items() if k!='state'}),flush=True)
        assert row['conserved'] and not any(v is False for v in flags.values()),name
        return state
    try:
        c.start();c.open('Caves');c.seed('Master','bank',2,'goldnugget',17,'gold',1);c.saveall()
        baseline=check('baseline')
        c.action('Caves',1,'withdraw',1);c.settle()
        runtime=check('runtime_transfer')
        assert all(runtime[s]['saves']==baseline[s]['saves'] and runtime[s]['snapshot']==baseline[s]['snapshot'] for s in runtime)
        if case=='capture_crash':
            c.command('Caves','VaultAudit.players[1].components.inventory:DropEverything()')
            c.fault('snapshot_capture',['Master'])
            before=len(c.events('Master'));c.command('Master','VaultAudit.save()')
            c.wait('Master','saved',after=before,timeout=45);time.sleep(2)
            assert c.state('undecided')['Master']['snapshotphase']=='prepared'
            c.stop();c.start();c.call('Caves','VaultAudit.restore(1)','restored')
            c.settle();check('uncommitted_capture_recovered')
        elif case=='commit_crash':
            c.fault('snapshot_commit',['Master']);c.call('Master','VaultAudit.save()','explicit_saved')
            assert c.state('commit_lost')['Caves']['snapshotphase']=='prepared'
            c.stop();c.start();c.call('Caves','VaultAudit.restore(1)','restored');c.settle()
            check('committed_receiver_recovered')
        elif case in ('master_restart','secondary_restart'):
            restarting='Master' if case=='master_restart' else 'Caves'
            other='Caves' if restarting=='Master' else 'Master'
            before=len(c.events(other));c.stop([restarting]);time.sleep(1);c.start([restarting])
            c.wait(other,'ready',after=before,timeout=150)
            c.call('Caves','VaultAudit.restore(1)','restored');c.settle();check('single_shard_restart_recovered')
        elif case=='migration':
            before=len(c.events('Master'));c.call('Caves','VaultAudit.migrate(1,"1",1)','migrate_requested')
            c.wait('Master','migrant_arrived',after=before,timeout=45)
            time.sleep(2);check('migrated_to_master')
            c.saveall();c.stop();c.start()
            a=c.call('Master','VaultAudit.restoreuid("KU_VA_2_1",1)','profile')
            b=c.call('Caves','VaultAudit.restoreuid("KU_VA_2_1",1)','profile')
            check('migration_saved_restart',destination_has_profile=a['found'],origin_has_no_profile=not b['found'])
        elif case=='item_migration':
            pos=c.call('Master','VaultAudit.spawnpoint()','spawnpoint')
            c.command('Caves','local p=VaultAudit.players[1];local e=p.components.inventory:FindItem(function(i)return i.prefab=="goldnugget"end);assert(e);Shard_CreateTransaction_TransferInventoryItem("1",e,{worldid="2",sessionid=TheWorld.meta.session_identifier,dest_x='+str(pos['x'])+',dest_y=0,dest_z='+str(pos['z'])+'})')
            time.sleep(4);check('native_item_arrived')
            c.saveall();c.stop();c.start();c.call('Caves','VaultAudit.restore(1)','restored')
            check('native_item_migration_restart')
        elif case=='history':
            for _ in range(12):c.saveall()
            time.sleep(2)
            r['history']={n:c.call(n,'VaultAudit.history()','history') for n in c.names}
            assert all(v['prepared']==0 and v['committed']<=v['limit']+1 for v in r['history'].values()),'committed image history bounded by native retained snapshots'
            c.stop();c.start();c.call('Caves','VaultAudit.restore(1)','restored');check('pruned_history_restart')
        elif case=='controls':
            c.fault('blackhole',['Caves'])
            c.call('Caves','VaultAudit.control(1,true)','control_pass')
            time.sleep(21)
            c.command('Caves','assert(not VaultAudit.players[1]._shadowvault_departing,"migration timeout released pending request")')
            c.fault('none',['Caves']);time.sleep(2)
            c.fault('snapshot_capture',['Master'])
            before=len(c.events('Master'));c.command('Master','VaultAudit.save()')
            c.wait('Master','saved',after=before,timeout=45);time.sleep(2)
            c.call('Caves','VaultAudit.control(1)','control_pass')
            c.fault('none',['Master']);time.sleep(4);check('controls_after_save_resumed')
        elif case in ('shutdown','shutdown_outage'):
            if case=='shutdown_outage':c.fault('blackhole',['Caves'])
            started=time.monotonic()
            before=len(c.events('Master'));c.command('Caves','c_shutdown()')
            deadline=time.monotonic()+50
            while c.children['Caves'].poll() is None and time.monotonic()<deadline:time.sleep(.2)
            assert c.children['Caves'].poll() is not None,'graceful shutdown finished'
            r['shutdown_seconds']=round(time.monotonic()-started,3)
            c.stop(['Caves']);c.stop(['Master']);c.start()
            c.call('Caves','VaultAudit.restore(1)','restored');c.settle();check('graceful_shutdown_recovered')
        r['status']='passed'
    except Exception:
        r['status']='failed';r['error']=traceback.format_exc();print(r['error'],flush=True)
    finally:
        c.stop();(c.out/'snapshot-result.json').write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8')
        args.report.write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
    if r['status']!='passed':break
raise SystemExit(0 if len(results)==len(args.case) and all(r['status']=='passed' for r in results) else 1)
