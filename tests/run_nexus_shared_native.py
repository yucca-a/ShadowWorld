from pathlib import Path
import sys,time,json,traceback
sys.path.insert(0,str(Path("tests").resolve()))
from run_vault_comparison import Cluster,ROOT,ledger

c=Cluster("hosted",4,None,ROOT/"content")
for n in c.names:
 p=c.cluster/n/"modoverrides.lua"
 p.write_text(p.read_text().replace('["World Exchange"]="hosted",','').replace('["Container Sort"]=-3','["Container Sort"]=-3,["Tackle Receptacle Use Fish Redeem"]=-1'))
with (c.runtime/"mods/VaultAudit/modmain.lua").open("a",encoding="utf-8") as f:
 f.write(r'''
function A.native_open(page,index)
    index=index or 1
    local v=service();local p=A.player(index)
    p.components.playervision:ForceNightVision(true)
    if not p.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)then p.components.inventory:Equip(SpawnPrefab("minerhat"))end
    p.Transform:SetPosition(TheWorld.components.playerspawner:GetAnySpawnPoint())
    A.nativeanchors=A.nativeanchors or {}
    local anchor=A.nativeanchors[index]
    if not valid(anchor) then anchor=SpawnPrefab("magician_chest");A.nativeanchors[index]=anchor end
    anchor.Transform:SetPosition(p.Transform:GetWorldPosition())
    if not anchor.components.container_proxy.master then anchor.components.container_proxy:SetMaster(v.base) end
    assert(v.native:Open(p,anchor,tostring(page)),"native open accepted")
    emit({kind="native_requested",page=page})
end
function A.native_inspect(index)
    local v=service();local p=A.player(index or 1)
    local view=v.views[p.userid]
    local proxy=view and view.anchor.components.container_proxy
    local page=proxy and proxy:GetMaster()
    emit({kind="native_state",opened=proxy and proxy:IsOpenedBy(p) or false,page=view and view.page,
        actual=page and page.shadowvault_page2hm,readonly=page and page.components.container.readonlycontainer,
        owner=deepcopy(v.native.state.owners),active=v.protocol.active and v.protocol.active.phase,
        pending=v.native.pending[p.userid]~=nil,error=v.error or v.journal.error})
end
function A.native_close(index)
    local v=service();v.native:Close(A.player(index or 1))
    emit({kind="native_closed"})
end
function A.native_move(slot,toinventory)
    local p=A.player(1);local v=service();local view=assert(v.views[p.userid])
    local c=assert(view.anchor.components.container_proxy:GetMaster()).components.container
    if toinventory then
        local item=assert(c:RemoveItemBySlot(slot,true))
        item.prevcontainer=nil;item.prevslot=nil
        assert(p.components.inventory:GiveItem(item,1))
    else
        local item=assert(p.components.inventory:RemoveItem(p.components.inventory:GetItemInSlot(1),true))
        assert(c:GiveItem(item,slot))
    end
    emit({kind="native_moved"})
end
''')

with(c.runtime/"mods/VaultAudit/modmain.lua").open("a",encoding="utf-8")as f:
 f.write(r'''
function A.shared_state()
    local v=service();local p=A.player(1);local view=v.views[p.userid]
    local e=view and view.anchor.components.container_proxy:GetMaster()
    local item=e and e.components.container.slots[1]
    local active=p.components.inventory:GetActiveItem()
    emit({kind="shared_state",opened=e and e.components.container:IsOpenedBy(p)or false,view=view and view.page,
        count=item and qty(item)or 0,active=active and qty(active)or 0,error=v.error or v.journal.error,
        phase=v.protocol.active and v.protocol.active.phase,rows=v.rows and GetTableSize(v.rows)or 0})
end
function A.shared_gesture(which,slot)
    slot=slot or 1
    local v=service();local p=A.player(1);local view=assert(v.views[p.userid])
    local c=view.anchor.components.container_proxy:GetMaster().components.container
    if which=="put"then c:PutAllOfActiveItemInSlot(slot,p)
    elseif which=="half"then c:TakeActiveItemFromHalfOfSlot(slot,p)
    elseif which=="take"then c:TakeActiveItemFromAllOfSlot(slot,p)
    elseif which=="merge"then c:AddAllOfActiveItemToSlot(slot,p)
    elseif which=="count3"then c:TakeActiveItemFromCountOfSlot(slot,3,p)
    elseif which=="one"then c:PutOneOfActiveItemInSlot(slot,p)end
    emit({kind="shared_gesture"})
end
''')
def opened(n,page):
 end=time.monotonic()+28
 while time.monotonic()<end:
  row=call(n,"native_inspect()","native_state")
  assert not row.get("error"),row
  if row["opened"] and row.get("actual")==str(page) and not row.get("readonly"):return row
  time.sleep(.2)
 raise RuntimeError(row)

r={"cluster":str(c.out),"cases":[]}
def call(n,cmd,event):return c.call(n,"VaultAudit."+cmd,event)
def state(n):return call(n,"shared_state()","shared_state")
def expect(n,count,active):
 end=time.monotonic()+30
 while time.monotonic()<end:
  row=state(n)
  assert not row.get('error'),row
  if row['count']==count and row['active']==active:return row
  time.sleep(.15)
 raise RuntimeError(row)
try:
 c.start();c.settle()
 c.seed('Master','bank',2,'goldnugget',17,'gold',1)
 for n in c.names:call(n,'native_open("2")','native_requested');opened(n,'2')
 for round in range(4):
  order=c.names if round==0 else c.names[1:]+c.names[:1]
  for n in order:
   c.command(n,'VaultAudit.shared_gesture("take")')
   if round>0 and n==order[0]:time.sleep(.35)
  c.settle();time.sleep(.5)
  rows={n:state(n)for n in c.names}
  assert all(x['opened']and x['count']==0 for x in rows.values()),rows
  assert sum(x['active']for x in rows.values())==17,rows
  winner=[n for n,x in rows.items()if x['active']][0]
  call(winner,'shared_gesture("put")','shared_gesture');c.settle()
  for n in c.names:expect(n,17,0)
  assert ledger(c.settle())=={'gold':17}
  r['cases'].append({'race_round':round+1,'winner':winner});print('FOUR SHARED RACE',round+1,winner,flush=True)
 call('Caves','shared_gesture("count3")','shared_gesture')
 expect('Caves',14,3);expect('Master',14,0)
 call('Caves','shared_gesture("one")','shared_gesture')
 expect('Caves',15,2);expect('Master',15,0)
 call('Caves','shared_gesture("put")','shared_gesture')
 expect('Caves',17,0);expect('Master',17,0)
 r['cases'].append('counted_take_and_put_one')
 for slot,n,prefab in [(2,'Caves','flint'),(3,'Layer3','nitre'),(4,'Layer4','rocks')]:
  c.seed('Master','bank',2,prefab,17,prefab,slot)
 time.sleep(.7)
 for slot,n in [(2,'Caves'),(3,'Layer3'),(4,'Layer4')]:c.command(n,'VaultAudit.shared_gesture("take",'+str(slot)+')')
 c.settle();time.sleep(.7)
 for n in ['Caves','Layer3','Layer4']:expect(n,17,17)
 for slot,n in [(2,'Caves'),(3,'Layer3'),(4,'Layer4')]:c.command(n,'VaultAudit.shared_gesture("put",'+str(slot)+')')
 c.settle();time.sleep(.5)
 expected={'gold':17,'flint':17,'nitre':17,'rocks':17}
 assert ledger(c.settle())==expected,ledger(c.settle())
 r['cases'].append('parallel_different_slots')
 c.saveall()
 for n in reversed(c.names):c.command(n,'c_shutdown(true)');c.children[n].wait(45)
 c.stop();c.start();c.settle()
 for n in c.names:call(n,'native_open("2")','native_requested');opened(n,'2');expect(n,17,0)
 assert ledger(c.settle())==expected,ledger(c.settle())
 r['cases'].append('normal_save_restart_all_views_reopen')
 r['status']='passed'
except Exception:r.update(status='failed',error=traceback.format_exc());print(r['error'],flush=True)
finally:
 c.stop();(c.out/'shared-result.json').write_text(json.dumps(r,indent=2))
 (ROOT/'work/nexus-shared-four-latest.json').write_text(json.dumps(r,indent=2))
 print(json.dumps(r),flush=True)
raise SystemExit(0 if r['status']=='passed'else 1)
