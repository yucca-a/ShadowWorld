"""Native DST comparison, frozen inputs, owned disposable clusters and item ledgers."""
from pathlib import Path
import _winapi
import argparse
import json
import hashlib
import shutil
import socket
import subprocess
import tempfile
import time
import traceback

ROOT=Path(__file__).resolve().parents[1]
INPUT=ROOT/'work/vault-comparison-20261106'
GAME=Path("D:/SteamLibrary/steamapps/common/Don't Starve Together")

def freeports(start,stop,count):
    found=[]
    for port in range(start,stop):
        with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as s:
            s.setsockopt(socket.SOL_SOCKET,socket.SO_EXCLUSIVEADDRUSE,1)
            try:s.bind(('0.0.0.0',port))
            except OSError:continue
            found.append(port)
        if len(found)==count:return found
    raise RuntimeError('No free ports')

class Cluster:
    def __init__(self,variant,shards=2,seed=None,source=None):
        self.variant=variant
        self.names=['Master','Caves','Layer3','Layer4'][:shards]
        self.ports=freeports(10998 if variant=='xianyu' else 11008,11008 if variant=='xianyu' else 11019,shards)
        self.out=Path(tempfile.mkdtemp(prefix=('vault-hardened-' if source else 'vault-compare-')+variant+'-',dir=ROOT/'work'))
        self.runtime=self.out/'runtime'
        self.cluster=self.out/'config/Audit'
        self.children={};self.generation={};self.logs={}
        print('CLUSTER',self.out,flush=True)
        shutil.copytree(GAME/'bin64',self.runtime/'bin64')
        _winapi.CreateJunction(str(GAME/'data'),str(self.runtime/'data'))
        mods=self.runtime/'mods';mods.mkdir()
        if source:
            shutil.copytree(source,self.out/'input')
            source=self.out/'input'
            manifest={str(p.relative_to(source)):hashlib.sha256(p.read_bytes()).hexdigest() for p in source.rglob('*') if p.is_file()}
            (self.out/'input-manifest.json').write_text(json.dumps(manifest,indent=2))
        else:source=INPUT/('xianyu/test' if variant=='xianyu' else 'hosted')
        _winapi.CreateJunction(str(source.resolve()),str(mods/'ShadowWorld'))
        probe=mods/'VaultAudit';(probe/'scripts/components').mkdir(parents=True)
        (probe/'modinfo.lua').write_text('name="Vault Audit"\ndescription="Disposable"\nauthor="Local"\nversion="1"\napi_version=10\ndst_compatible=true\nserver_only_mod=true\nall_clients_require_mod=false\npriority=-99999\n')
        fixture=(ROOT/'tests/native/vault_comparison_fixture.lua').read_text(encoding='utf-8')
        (probe/'modmain.lua').write_text(fixture.replace('local variant=GetModConfigData("variant")','local variant="'+variant+'"'),encoding='utf-8')
        shutil.copyfile(ROOT/'tests/native/vaultauditmark.lua',probe/'scripts/components/vaultauditmark.lua')
        self.cluster.mkdir(parents=True)
        offset=0 if variant=='xianyu' else 100
        mp=freeports(17860+offset,17960+offset,1)[0]
        steam=freeports(28900+offset,29000+offset,shards)
        auth=freeports(9900+offset,10000+offset,shards)
        (self.cluster/'cluster.ini').write_text('[GAMEPLAY]\ngame_mode = survival\npause_when_empty = false\n[NETWORK]\ncluster_name = Vault comparison\noffline_cluster = true\nlan_only_cluster = false\n[MISC]\nconsole_enabled = true\n[SHARD]\nshard_enabled = true\nbind_ip = 127.0.0.1\nmaster_ip = 127.0.0.1\nmaster_port = '+str(mp)+'\ncluster_key = vault-audit\n')
        for i,name in enumerate(self.names):
            shard=self.cluster/name;shard.mkdir()
            if seed:
                shutil.copytree(seed/name/'save',shard/'save',ignore=shutil.ignore_patterns('boot_modindex','modindex','mod_config_data'))
            (shard/'server.ini').write_text(f'[NETWORK]\nserver_port = {self.ports[i]}\n[SHARD]\nis_master = {str(i==0).lower()}\nname = {name}\nid = {i+1}\n[STEAM]\nmaster_server_port = {steam[i]}\nauthentication_port = {auth[i]}\n')
            (shard/'worldgenoverride.lua').write_text('return {override_enabled=true,preset="'+('SURVIVAL_TOGETHER' if i==0 else 'DST_CAVE')+'",overrides={world_size="small"}}')
            setting=('exchange_v1_xianyu' if variant=='xianyu' else 'exchange_v1_nexus') if (source/'scripts/exchangemode2hm.lua').exists() else ('classic' if variant=='xianyu' else 'hosted')
            (shard/'modoverrides.lua').write_text('return {VaultAudit={enabled=true,configuration_options={variant="'+variant+'"}},ShadowWorld={enabled=true,configuration_options={["World Exchange"]="'+setting+'",["Container Sort"]=-3}}}')
    def start(self,names=None):
        for name in names or self.names:
            self.generation[name]=self.generation.get(name,0)+1
            path=self.out/(name+'-'+str(self.generation[name])+'.log');self.logs[name]=path
            with path.open('wb') as f:
                self.children[name]=subprocess.Popen([str(self.runtime/'bin64/dontstarve_dedicated_server_nullrenderer_x64.exe'),'-persistent_storage_root',str(self.out),'-conf_dir','config','-cluster','Audit','-shard',name,'-port',str(self.ports[self.names.index(name)])],cwd=self.runtime/'bin64',stdout=f,stderr=subprocess.STDOUT,stdin=subprocess.PIPE,creationflags=subprocess.CREATE_NO_WINDOW)
        for name in names or self.names:self.wait(name,'ready',timeout=240)
    def stop(self,names=None):
        for name in names or list(self.children):
            p=self.children.pop(name,None)
            if p:
                if p.poll() is None:p.terminate()
                p.wait(15)
    def events(self,name):
        raw=self.logs[name].read_text(encoding='utf-8',errors='replace')
        if 'LUA ERROR' in raw or 'SOCKET_PORT_ALREADY_IN_USE' in raw:
            raise RuntimeError(name+' native error; '+str(self.logs[name])+'\n'+raw[-7000:])
        rows=[]
        for line in raw.splitlines():
            if '[VAUDIT] ' in line:
                try:rows.append(json.loads(line.split('[VAUDIT] ',1)[1]))
                except ValueError:pass
        return rows
    def command(self,name,lua):
        p=self.children[name]
        if p.poll() is not None:raise RuntimeError(name+' exited '+str(p.returncode))
        p.stdin.write((lua+'\n').encode());p.stdin.flush()
    def wait(self,name,kind,after=0,timeout=30,**match):
        start=time.monotonic()
        while time.monotonic()-start<timeout:
            for row in self.events(name)[after:]:
                if row.get('kind')==kind and all(row.get(k)==v for k,v in match.items()):return row
            if self.children[name].poll() is not None:raise RuntimeError(name+' exited; '+str(self.logs[name]))
            time.sleep(.15)
        raise TimeoutError(name+' '+kind+' '+str(match)+'; '+str(self.logs[name]))
    def call(self,name,lua,kind,**match):
        before=len(self.events(name));self.command(name,lua)
        return self.wait(name,kind,after=before,**match)
    def state(self,label,names=None):
        return {n:self.call(n,'VaultAudit.inspect('+json.dumps(label)+')','state',label=label) for n in names or list(self.children)}
    def settle(self,timeout=35):
        start=time.monotonic()
        while time.monotonic()-start<timeout:
            state=self.state('settle')
            if all(r['pending']==0 for r in state.values()):
                time.sleep(1.1)
                state=self.state('settle_confirm')
                if all(r['pending']==0 for r in state.values()):return state
            time.sleep(.6)
        return self.state('unsettled')
    def saveall(self):
        before={n:len(self.events(n)) for n in self.children}
        self.command('Master','VaultAudit.cluster_save()')
        for n in self.children:self.wait(n,'saved',after=before[n],timeout=40)
        deadline=time.monotonic()+40
        while time.monotonic()<deadline:
            states=self.state('save_complete')
            if all(s.get('snapshotphase') in (None,'ready') for s in states.values()):break
            time.sleep(.2)
        else:raise TimeoutError('Normal save captured bytes but recovery decision did not finish')
        time.sleep(.4)
    def open(self,name,index=1,page=2):
        self.call(name,f'VaultAudit.open({index},{page})','opened')
        time.sleep(1.5)
    def seed(self,name,where,index,prefab,amount,token,slot=1):
        self.call(name,f'VaultAudit.seed("{where}",{index},"{prefab}",{amount},"{token}",{slot})','seeded',token=token)
    def action(self,name,index,op,slot=1,mode='inventory'):
        return self.call(name,f'VaultAudit.action({index},"{op}",{slot},"{mode}")','action')
    def fault(self,kind,names=None):
        for n in names or self.children:self.call(n,'VaultAudit.setfault("'+kind+'")','fault')

def ledger(state):
    total={}
    for row in state.values():
        for token,count in (row['goods'] or {}).items():total[token]=total.get(token,0)+count
    return total

def run(args):
    c=Cluster(args.variant,args.shards,args.seed,getattr(args,'source',None))
    result={'variant':args.variant,'scenario':args.scenario,'cluster':str(c.out),'checks':[]}
    def check(name,state,expected,**extra):
        row={'name':name,'expected':dict(expected),'actual':ledger(state),'conserved':ledger(state)==expected,
             'quiescent':all(s['pending']==0 for s in state.values()),'state':state,**extra}
        result['checks'].append(row)
        print(json.dumps({k:v for k,v in row.items() if k!='state'}),flush=True)
        return row
    try:
        c.start();time.sleep(3)
        if args.scenario=='recover_saved':
            c.call('Caves','VaultAudit.restore(1)','restored');time.sleep(2)
            check('old_journal_recovered',c.settle(),{'gold':17,'axe':1})
            c.open('Caves');c.action('Caves',1,'withdraw',3)
            check('new_request_after_old_recovery',c.settle(),{'gold':17,'axe':1})
            result['status']='finished'
            return result
        c.open('Caves')
        if args.scenario in ('smoke','stress','full','restart','rollback','offline','matrix','interrupted','complex','offline_rollback','full_restart'):
            c.seed('Master','bank',2,'goldnugget',17,'gold',1)
            c.seed('Master','bank',2,'axe',43,'axe',2)
            expected={'gold':17,'axe':1}
        else:
            c.seed('Caves','player',1,'goldnugget',17,'gold')
            expected={'gold':17}
        if args.scenario=='complex':
            c.call('Master','VaultAudit.richseed()','rich_seeded');expected.update(bundle=1,armor=1)
        c.saveall();check('baseline',c.state('baseline'),expected)
        if args.scenario=='full_restart':
            c.call('Caves','VaultAudit.fill(1)','filled');c.action('Caves',1,'withdraw',1);time.sleep(8)
            state=c.state('held_full');check('held_full',state,expected,held=state['Caves']['pending']==1)
            c.saveall();c.stop();c.start()
            c.call('Caves','VaultAudit.restore(1)','restored');time.sleep(2)
            c.open('Caves');c.action('Caves',1,'withdraw',2);time.sleep(2)
            state=c.state('held_after_restart')
            check('held_after_restart',state,expected,one_delivery=state['Caves']['pending']==1,
                  other_item_untouched=(state['Master']['goods'] or {}).get('axe')==1)
            c.call('Caves','VaultAudit.unfill(1)','unfilled');state=c.settle()
            check('delivered_once',state,expected,completed=(state['Caves']['goods'] or {}).get('gold')==17 and state['Caves']['pending']==0)
            c.saveall();c.stop();c.start();c.call('Caves','VaultAudit.restore(1)','restored');time.sleep(2)
            check('delivered_reload',c.settle(),expected)
        if args.scenario=='complex':
            c.call('Caves','VaultAudit.cache(1,1)','cached')
            c.call('Master','VaultAudit.swap()','swapped');time.sleep(1.5)
            c.call('Caves','VaultAudit.cachedaction(1,1)','cached_action')
            state=c.settle();check('stale_slot_request',state,expected,stale_rejected=not state['Caves']['goods'])
            for n in c.children:c.call(n,'VaultAudit.wireloss(true)','wirefault')
            c.action('Caves',1,'withdraw',4)
            state=c.settle(timeout=65);check('large_nested_bundle_chunk_loss',state,expected)
            for n in c.children:c.call(n,'VaultAudit.wireloss(false)','wirefault')
            state=c.settle(timeout=50)
            if not (state['Caves']['goods'] or {}).get('bundle'):
                c.action('Caves',1,'withdraw',4);state=c.settle(timeout=50)
            check('large_nested_bundle_recovered',state,expected,completed=(state['Caves']['goods'] or {}).get('bundle')==1)
            c.action('Caves',1,'withdraw',5);state=c.settle();check('armor_properties',state,expected)
            c.saveall();c.stop();c.start();c.call('Caves','VaultAudit.restore(1)','restored');time.sleep(2)
            check('complex_items_reload',c.settle(),expected)
        if args.scenario=='interrupted':
            c.fault('blackhole');c.action('Caves',1,'withdraw',1);time.sleep(4)
            check('blackhole_pending',c.state('blackhole_pending'),expected)
            c.fault('none');check('blackhole_recovered',c.settle(),expected)
            c.fault('ackloss');c.action('Caves',1,'deposit',3);time.sleep(9)
            ackstate=c.state('lost_final_ack');check('lost_final_ack',ackstate,expected)
            if ackstate['Master'].get('snapshotphase'):
                before=len(c.events('Master'));c.command('Master','VaultAudit.save()')
                time.sleep(2);check('normal_save_waits_for_receipt',c.state('normal_save_waits_for_receipt'),expected)
                c.fault('none');c.wait('Master','explicit_saved',after=before,timeout=45)
                time.sleep(2);check('save_resumed_after_ack',c.settle(),expected)
            else:c.saveall()
            c.stop();c.start()
            c.call('Caves','VaultAudit.restore(1)','restored');time.sleep(3)
            check('pending_crash_recovered',c.settle(),expected)
        if args.scenario in ('smoke','stress','restart','rollback','offline','matrix','offline_rollback'):
            start=time.monotonic();c.action('Caves',1,'withdraw');state=c.settle()
            check('withdraw',state,expected,seconds=time.monotonic()-start,completed=state['Caves']['goods'].get('gold')==17 if isinstance(state['Caves']['goods'],dict) else False)
            start=time.monotonic();c.action('Caves',1,'deposit',3);state=c.settle()
            check('deposit',state,expected,seconds=time.monotonic()-start,completed=state['Master']['banks']['2'].get('3',{}).get('count')==17)
        if args.scenario=='stress':
            for fault in ('duplicate','loss','reorder','none'):
                c.fault(fault)
                for i in range(args.rounds):
                    start=time.monotonic()
                    c.action('Caves',1,'withdraw',3);c.settle()
                    c.action('Caves',1,'deposit',3);state=c.settle()
                    check(fault+'_'+str(i+1),state,expected,seconds=time.monotonic()-start)
            c.fault('none')
        if args.scenario=='full':
            c.call('Caves','VaultAudit.fill(1)','filled');c.action('Caves',1,'withdraw')
            time.sleep(8);check('full_inventory',c.state('full_inventory'),expected)
        if args.scenario=='matrix':
            for n in c.names[1:]:c.open(n,1,2)
            for fault in ('duplicate','loss','reorder','none'):
                c.fault(fault)
                for i in range(args.rounds):
                    start=time.monotonic()
                    for n in c.names[1:]:
                        c.command(n,'for i=1,50 do VaultAudit.action(1,"withdraw",3) end')
                    time.sleep(1)
                    state=c.settle()
                    winner=sum((s['goods'] or {}).get('gold',0) for n,s in state.items() if n!='Master')==17
                    completed=winner and not (state['Master']['goods'] or {}).get('gold') and all(s['pending']==0 for s in state.values())
                    check(fault+'_race_'+str(i+1),state,expected,attempts=50*(len(c.names)-1),seconds=time.monotonic()-start,completed=completed)
                    for n in c.names[1:]:c.action(n,1,'deposit',3)
                    state=c.settle();check(fault+'_return_'+str(i+1),state,expected,
                        completed=(state['Master']['goods'] or {}).get('gold')==17 and all(s['pending']==0 for s in state.values()))
            c.fault('none')
            c.open('Caves',2,2);c.call('Caves','VaultAudit.fill(2)','filled')
            c.action('Caves',2,'withdraw',3);time.sleep(8)
            check('full_inventory',c.state('full_inventory'),expected)
            c.call('Caves','VaultAudit.unfill(2)','unfilled');time.sleep(3)
            state=c.settle();check('full_inventory_recovered',state,expected)
            c.action('Caves',1,'withdraw',2);state=c.settle()
            check('durability_withdraw',state,expected)
            c.saveall();c.stop();c.start()
            for n in c.names[1:]:
                c.call(n,'VaultAudit.restore(1)','restored')
            c.call('Caves','VaultAudit.restore(2)','restored');time.sleep(3)
            check('restart_four_shards',c.settle(),expected)
            c.stop(c.names[1:]);time.sleep(10)
            c.open('Master',1,2)
            state=c.state('offline',['Master'])
            # Remote players' saved inventory is offline, so only compare the main page here.
            result['checks'].append({'name':'offline_pages','state':state,'page_count':len(state['Master']['banks'])})
            c.seed('Master','bank',2,'rocks',23,'offline_rocks',7)
            c.call('Master','VaultAudit.localroundtrip(1,2,7)','local_roundtrip')
            result['checks'].append({'name':'offline_local_roundtrip','state':c.state('offline_local_roundtrip',['Master'])})
        if args.scenario in ('loss_cut','dup_cut','player_exit','torn_save'):
            if args.scenario=='torn_save':c.call('Master','VaultAudit.save()','explicit_saved')
            c.action('Caves',1,'deposit');check('completed_before_partial_save',c.settle(),expected)
            if args.scenario=='player_exit':c.call('Caves','VaultAudit.disconnect(1)','player_disconnected')
            else:
                side='Caves' if args.scenario in ('loss_cut','torn_save') else 'Master'
                c.call(side,'VaultAudit.save()','explicit_saved')
            c.stop();c.start()
            c.call('Caves','VaultAudit.restore(1)','restored')
            time.sleep(3);check('after_partial_save_crash_reload',c.settle(),expected)
        if args.scenario=='restart':
            c.saveall();c.stop();c.start()
            c.call('Caves','VaultAudit.restore(1)','restored')
            time.sleep(3);check('saved_restart',c.settle(),expected)
        if args.scenario=='rollback':
            c.saveall()
            c.action('Caves',1,'withdraw',3);c.settle();c.saveall()
            before={n:len(c.events(n)) for n in c.children}
            c.command('Master','VaultAudit.rollback()')
            for n in c.children:c.wait(n,'ready',after=before[n],timeout=120)
            c.call('Caves','VaultAudit.restore(1)','restored');time.sleep(3)
            check('coordinated_rollback',c.settle(),expected)
        if args.scenario=='offline':
            c.saveall();c.stop(c.names[1:]);time.sleep(10)
            c.open('Master',1,2)
            check('secondary_offline_access',c.state('offline',['Master']),expected)
        if args.scenario=='offline_rollback':
            c.saveall();c.stop(c.names[1:]);time.sleep(8)
            c.seed('Master','bank',2,'rocks',23,'offline_rocks',7);expected['offline_rocks']=23
            c.call('Master','VaultAudit.save()','explicit_saved')
            c.call('Master','VaultAudit.bank(2).slots[7].components.stackable:SetStackSize(24);VaultAudit.save()','explicit_saved')
            before=len(c.events('Master'));c.command('Master','VaultAudit.rollback()')
            c.wait('Master','ready',after=before,timeout=120)
            c.open('Master',1,2)
            c.call('Master','VaultAudit.localroundtrip(1,2,7)','local_roundtrip')
            check('offline_rollback_access',c.state('offline_rollback_access',['Master']),expected)
        result['status']='finished'
    except Exception:
        result['status']='harness_or_runtime_error';result['error']=traceback.format_exc();print(result['error'],flush=True)
    finally:
        c.stop()
        (c.out/'result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
        print('RESULT',c.out/'result.json',flush=True)
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--variant',choices=['hosted','xianyu'],required=True)
    p.add_argument('--scenario',choices=['smoke','stress','full','restart','rollback','offline','loss_cut','dup_cut','player_exit','torn_save','matrix','interrupted','complex','offline_rollback','full_restart','recover_saved'],default='smoke')
    p.add_argument('--seed',type=Path)
    p.add_argument('--source',type=Path,help='Freeze and test this implementation separately from the original comparison')
    p.add_argument('--shards',type=int,choices=[2,4],default=2)
    p.add_argument('--rounds',type=int,default=3)
    result=run(p.parse_args())
    failed=any((c.get('conserved') is False and all(s['pending']==0 for s in c['state'].values()))
               or any(c.get(k) is False for k in ('stale_rejected','completed','held','one_delivery','other_item_untouched'))
               for c in result['checks'])
    raise SystemExit(1 if result['status']!='finished' else 2 if failed else 0)
