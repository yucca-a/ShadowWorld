"""Native player migration must succeed even when every vault RPC is discarded."""
from pathlib import Path
import sys,json,time,argparse,traceback
sys.path.insert(0,str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster,ROOT,ledger
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--case',nargs='+',choices=['native','enabled','blackhole','full','inflight','save','crash','source_restart','four'],required=True)
p.add_argument('--report',type=Path,default=ROOT/'development/validation/vault-native-only-20261106.json')
args=p.parse_args();results=[]
for case in args.case:
    c=Cluster('hosted',4 if case=='four' else 2,None if case=='four' else ROOT/'work/native-shadow-vault-2j510173/config/Audit',ROOT/'content')
    r={'case':case,'cluster':str(c.out),'checks':[],'travel':[]};results.append(r)
    def check(label):
        state=c.state(label);actual=ledger(state)
        row={'label':label,'actual':actual,'conserved':actual=={'gold':17},'state':state};r['checks'].append(row)
        print(json.dumps({k:v for k,v in row.items() if k!='state'}),flush=True)
        assert row['conserved'] and not any(s.get('error') for s in state.values()),label
        return state
    def travel(origin,destination):
        before={n:len(c.events(n)) for n in (origin,destination)}
        requested=c.call(origin,'VaultAudit.migrate(1,"'+str(c.names.index(destination)+1)+'",1)','migrate_requested')
        departed=c.wait(origin,'migrant_departed',after=before[origin],timeout=8)
        c.wait(destination,'migrant_arrived',after=before[destination],timeout=8)
        seconds=round(departed['time']-requested['time'],4)
        assert seconds<2,'a mod acknowledgement must not delay native departure'
        r['travel'].append({'from':origin,'to':destination,'departure_seconds':seconds})
        print('TRAVEL',seconds,flush=True);time.sleep(.5)
    try:
        if case=='native':
            for name in c.names:
                (c.cluster/name/'modoverrides.lua').write_text('return {VaultAudit={enabled=true},ShadowWorld={enabled=true,configuration_options={["World Exchange"]="off",["Container Sort"]=-3}}}')
            with (c.runtime/'mods/VaultAudit/modmain.lua').open('a',encoding='utf-8') as f:
                f.write('\nAddSimPostInit(function() TheWorld:DoStaticTaskInTime(2,function() A.ready=true;emit({kind="ready"}) end) end)\n')
        c.start()
        if case in ('native','enabled','blackhole','four'):
            c.seed('Caves','player',1,'goldnugget',17,'gold');c.saveall()
            if case in ('blackhole','four'):c.fault('blackhole')
            if case=='four':
                c.stop(['Layer4']);travel('Caves','Layer3');travel('Layer3','Master');travel('Master','Caves')
            else:
                for _ in range(3):travel('Caves','Master');travel('Master','Caves')
            check('native_handoffs')
            c.fault('none')
            if case=='four':
                # The absent clean shard retains an older referenced image.
                # Its later recovery proof must match that per-shard reference.
                c.saveall();check('saved_while_layer4_offline')
                c.start(['Layer4'])
            c.saveall();c.stop();c.start();c.call('Caves','VaultAudit.restoreuid("KU_VA_2_1",1)','profile')
            check('saved_restart')
        else:
            c.open('Caves');c.seed('Master','bank',2,'goldnugget',17,'gold',1);c.saveall()
            if case=='full':c.call('Caves','VaultAudit.fill(1)','filled')
            if case=='inflight':c.fault('exchange_blackhole',['Caves'])
            c.action('Caves',1,'withdraw',1)
            if case=='inflight':time.sleep(.3)
            elif case=='full':time.sleep(3)
            else:c.settle()
            if case=='save':
                c.fault('snapshot_capture',['Master'])
                before=len(c.events('Master'));c.command('Master','VaultAudit.save()')
                c.wait('Master','saved',after=before,timeout=40);time.sleep(.5)
                assert c.state('frozen')['Master']['snapshotphase']=='prepared'
            elif case!='inflight':c.fault('blackhole')
            travel('Caves','Master');time.sleep(1);check('arrival')
            if case=='full':
                assert c.state('held')['Master']['pending']==1,'native background transfer holds overflow on destination'
                travel('Master','Caves');time.sleep(1);check('full_return')
                c.fault('none');c.saveall();c.stop();c.start();c.call('Caves','VaultAudit.restoreuid("KU_VA_2_1",1)','profile')
                check('full_saved_restart');c.call('Caves','VaultAudit.unfill(1)','unfilled');c.settle();check('delivered_once')
            elif case in ('crash','source_restart'):
                if case=='crash':c.stop();c.start()
                else:
                    c.fault('none',['Master']);before=len(c.events('Master'))
                    c.stop(['Caves']);c.start(['Caves']);c.wait('Master','ready',after=before,timeout=150)
                c.call('Master','VaultAudit.restoreuid("KU_VA_2_1",1)','profile')
                c.call('Caves','VaultAudit.restoreuid("KU_VA_2_1",1)','profile')
                check('interrupted_recovered')
            else:
                c.fault('none');c.settle();settled=check('settled')
                assert all(s['pending']==0 for s in settled.values())
                assert settled['Master']['locations'].get('KU_VA_2_1')==17
                c.saveall();c.stop();c.start();c.call('Master','VaultAudit.restoreuid("KU_VA_2_1",1)','profile')
                check('saved_restart')
        r['status']='passed'
    except Exception:
        r['status']='failed';r['error']=traceback.format_exc();print(r['error'],flush=True)
    finally:
        c.stop();(c.out/'native-only-result.json').write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8')
        args.report.write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
    if r['status']!='passed':break
raise SystemExit(0 if len(results)==len(args.case) and all(r['status']=='passed' for r in results) else 1)
