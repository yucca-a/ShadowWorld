"""Native consumption, withheld delivery and journal write failure probes."""
from pathlib import Path
import sys,json,time,traceback
sys.path.insert(0,str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster,ROOT,ledger
c=Cluster('hosted',2,ROOT/'work/native-shadow-vault-2j510173/config/Audit',ROOT/'content')
r={'cluster':str(c.out),'checks':[],'status':'running'}
def check(label,expected,pending=0):
    s=c.settle(20) if pending==0 else c.state(label)
    row={'label':label,'expected':expected,'actual':ledger(s),'state':s};r['checks'].append(row)
    print(label,ledger(s),flush=True)
    assert ledger(s)==expected,label
    assert sum(x['pending'] for x in s.values())==pending,label+' pending'
    return s
try:
    c.start();c.open('Caves');c.seed('Master','bank',2,'goldnugget',17,'gold',1);c.saveall()
    c.action('Caves',1,'withdraw',1);check('initial_delivery',{'gold':17})
    c.command('Caves','local p=VaultAudit.player(1) local i=p.components.inventory:FindItem(function(i)return i.prefab=="goldnugget"end) i.components.stackable:Get(5):Remove()')
    time.sleep(.7);check('partially_consumed',{'gold':12})
    c.stop(['Caves']);c.start(['Caves']);c.call('Caves','VaultAudit.restore(1)','restored')
    check('only_remaining_quantity_recovered',{'gold':12})
    c.command('Caves','local p=VaultAudit.player(1) local i=p.components.inventory:FindItem(function(i)return i.prefab=="goldnugget"end) i:Remove()')
    time.sleep(.7);check('fully_consumed',{})
    c.stop(['Caves']);c.start(['Caves']);c.call('Caves','VaultAudit.restore(1)','restored')
    check('consumed_goods_not_refunded',{})
    # Interrupt the issuance after its journal commit but before GiveItem. With
    # no delivery proof this must stay held, while native migration still runs.
    c.seed('Master','bank',2,'goldnugget',17,'gold',1);c.open('Caves')
    c.command('Caves',"local j=TheWorld.components.shadowvault2hm.journal local f=j.Flush j.Flush=function(self,cb) for _,r in pairs(self.v.rows) do if r.state=='issuing' then cb=nil;VaultAudit.heldissuance=true;break end end return f(self,cb) end")
    c.action('Caves',1,'withdraw',1);time.sleep(3);check('issuance_interrupt_held',{'gold':17},1)
    c.stop(['Caves']);c.start(['Caves']);c.call('Caves','VaultAudit.restore(1)','restored')
    check('uncertain_issuance_not_guessed',{'gold':17},1)
    before=len(c.events('Master'));req=c.call('Caves','VaultAudit.migrate(1,"1",1)','migrate_requested')
    arrived=c.wait('Master','migrant_arrived',after=before,timeout=8)
    r['native_migration_with_held_record']=arrived['time']
    # Fail an independent journal commit on the master, then migrate back.
    c.command('Master','local j=TheWorld.components.shadowvault2hm.journal j.store.io.write=function(k,raw,cb)cb(false)end j.v.registry["2"].audit_fault=true j:Flush()')
    time.sleep(.4);s=c.state('journal_failure');assert s['Master'].get('error')=='journal_write_failed'
    before=len(c.events('Caves'));c.call('Master','VaultAudit.migrate(1,"2",1)','migrate_requested')
    c.wait('Caves','migrant_arrived',after=before,timeout=8)
    r['journal_failure_did_not_gate_native_migration']=True
    r['status']='passed'
except Exception:
    r['status']='failed';r['error']=traceback.format_exc();print(r['error'],flush=True)
finally:
    c.stop();out=ROOT/'development/validation/vault-practical-faults-20261106.json'
    out.write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8');print('REPORT',out,flush=True)
raise SystemExit(0 if r['status']=='passed' else 1)
