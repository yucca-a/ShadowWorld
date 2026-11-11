"""Compare native travel and vault travel; fault-test saving and portable custody."""
from pathlib import Path
import sys,json,time,argparse,traceback
sys.path.insert(0,str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster,ROOT,ledger
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--case',nargs='+',choices=['native','enabled','save','full','inflight','unrelated','controls','yield_crash'],required=True)
p.add_argument('--report',type=Path,default=ROOT/'development/validation/vault-travel-priority-20261106.json')
args=p.parse_args();results=[]
for case in args.case:
    c=Cluster('hosted',4 if case=='unrelated' else 2,None if case=='unrelated' else ROOT/'work/native-shadow-vault-2j510173/config/Audit',ROOT/'content')
    r={'case':case,'cluster':str(c.out),'checks':[],'travel':[]};results.append(r)
    def check(label):
        state=c.state(label);total=ledger(state)
        row={'label':label,'actual':total,'conserved':total=={'gold':17},'state':state}
        r['checks'].append(row);print(json.dumps({k:v for k,v in row.items() if k!='state'}),flush=True)
        assert row['conserved'],label
        return state
    def travel(origin,destination,index=1):
        before={n:len(c.events(n)) for n in (origin,destination)}
        requested=c.call(origin,'VaultAudit.migrate(1,"'+str(c.names.index(destination)+1)+'",1)','migrate_requested')
        departed=c.wait(origin,'migrant_departed',after=before[origin],timeout=12)
        c.wait(destination,'migrant_arrived',after=before[destination],timeout=12)
        seconds=round(departed['time']-requested['time'],4)
        r['travel'].append({'from':origin,'to':destination,'departure_seconds':seconds})
        print('TRAVEL',seconds,flush=True);time.sleep(.5)
    try:
        if case=='native':
            for n in c.names:
                (c.cluster/n/'modoverrides.lua').write_text('return {VaultAudit={enabled=true},ShadowWorld={enabled=true,configuration_options={["World Exchange"]="off",["Container Sort"]=-3}}}')
            fixture=c.runtime/'mods/VaultAudit/modmain.lua'
            with fixture.open('a',encoding='utf-8') as f:f.write('\nAddSimPostInit(function() TheWorld:DoStaticTaskInTime(2,function() A.ready=true;emit({kind="ready"}) end) end)\n')
        c.start()
        if case=='native':
            for n in c.names:c.command(n,'assert(not TheWorld.components.shadowvault2hm.snapshot,"comparison must have vault disabled")')
        if case in ('native','enabled'):
            c.seed('Caves','player',1,'goldnugget',17,'gold');c.saveall()
            for _ in range(3):travel('Caves','Master');travel('Master','Caves')
            check('six_native_handoffs')
        else:
            c.open('Caves');c.seed('Master','bank',2,'goldnugget',17,'gold',1);c.saveall()
            if case=='full':c.call('Caves','VaultAudit.fill(1)','filled')
            if case=='inflight':c.fault('exchange_blackhole',['Caves'])
            c.action('Caves',1,'withdraw',1)
            if case=='inflight':
                time.sleep(.3)
            elif case=='full':time.sleep(3)
            else:c.settle()
            if case=='controls':
                c.fault('blackhole',['Caves']);c.call('Caves','VaultAudit.control(1,true)','control_pass')
                time.sleep(21)
                c.command('Caves','assert(not VaultAudit.players[1]._shadowvault_departing,"cancelled request must release its marker")')
                c.fault('none',['Caves']);c.settle();check('controls_and_timeout');r['status']='passed'
                continue
            if case in ('save','unrelated','yield_crash'):
                c.fault('snapshot_capture',['Master'])
                before=len(c.events('Master'));c.command('Master','VaultAudit.save()')
                c.wait('Master','saved',after=before,timeout=40);time.sleep(.5)
                if case=='unrelated':c.stop(['Layer4']);time.sleep(1)
            travel('Caves','Master')
            check('arrival')
            if case=='yield_crash':
                c.stop();c.start()
                c.call('Master','VaultAudit.restoreuid("KU_VA_2_1",1)','profile')
                c.call('Caves','VaultAudit.restoreuid("KU_VA_2_1",1)','profile')
                check('abandoned_save_crash_recovered')
            elif case=='full':
                assert c.state('full_arrival')['Master']['pending']==1,'overflow follows the player'
                # A second full-bag journey must not grow or duplicate parcel IDs.
                travel('Master','Caves');check('full_bag_return')
                c.saveall();c.stop();c.start();c.call('Caves','VaultAudit.restoreuid("KU_VA_2_1",1)','profile')
                check('full_bag_saved_restart')
                c.call('Caves','VaultAudit.unfill(1)','unfilled');c.settle();check('delivered_once')
            elif case=='unrelated':
                travel('Master','Layer3');check('unrelated_outage_arrival')
                assert all(t['departure_seconds']<3 for t in r['travel']),'unrelated world must not delay travel'
            else:
                c.fault('none');c.settle();settled=check('transaction_settled_after_travel')
                assert all(s['pending']==0 and not s.get('error') for s in settled.values()),'source and destination custody fully settle'
                assert settled['Master']['locations'].get('KU_VA_2_1')==17,'late transaction result reaches the player on the destination'
                c.saveall();c.stop();c.start()
                c.call('Master','VaultAudit.restoreuid("KU_VA_2_1",1)','profile');check('saved_restart')
        r['status']='passed'
    except Exception:
        r['status']='failed';r['error']=traceback.format_exc();print(r['error'],flush=True)
    finally:
        c.stop();(c.out/'travel-result.json').write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8')
        args.report.write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
    if r['status']!='passed':break
raise SystemExit(0 if len(results)==len(args.case) and all(r['status']=='passed' for r in results) else 1)
