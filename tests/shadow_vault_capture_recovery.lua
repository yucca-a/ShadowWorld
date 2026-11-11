local Journal=require("shadowvaultjournal2hm")
local Adapter=require("shadowvaultitems2hm")
local checks=0
local function check(ok,why)checks=checks+1;assert(ok,why)end
local now=100
local clock=GetStaticTime
GetStaticTime=function()return now end
local function setup()
    local page=VA_TEST.box(false)
    local item=SpawnPrefab("goldnugget");page.components.container:GiveItem(item,1)
    local t={name="held",id="transaction",phase="applied"}
    local v={id="1",session="capture_session",registry={},pages={page=page},rows={},
        Fail=function(self,why)self.error=why end}
    local core={active=t,retry=99,Save=function(self)return {mode="journal",active=deepcopy(self.active)}end,
        Marker=function(self)return {id=self.active.id,phase=self.active.phase}end,
        OnSaved=function(self,m)self.durable=self.active.id==m.id and self.active.phase==m.phase end}
    v.protocol=core
    local escrow=VA_TEST.box(true)
    v.rows.held={escrow=escrow,op="D",state="active"}
    local j=setmetatable({v=v,ready=true,waiters={},deposits={},receipts={},deliveries={},mail={},store={}},Journal)
    function j.store:Update(update,cb)
        self.writes=(self.writes or 0)+1
        self.state={};update(self.state)
        self.callback=cb
    end
    v.journal=j
    return j,v,item,t
end
local j,v,item,t=setup()
item.persists=false
j:Flush(function(ok)if not ok then t.error="journal_write_failed"end end)
check(j.error=="linked_items"and v.error=="linked_items","capture refuses temporarily nonpersistent goods")
check(not j.store.writes,"failed capture never writes partial custody")
check(not j:TryRecover(),"still invalid item stays protected")
item.persists=true
check(not j:TryRecover(),"repeated requests are throttled")
now=111
check(j:TryRecover()and j.recovering and v.error and not v.protocol.durable,"repair waits for durable write before unlocking")
check(v.pages.page.components.container.slots[1]==item and item:IsValid(),"repair keeps original entity and quantity")
j.store.callback(true)
check(not v.error and not j.error and not t.error and v.protocol.durable and v.protocol.retry==0,"verified write resumes same transaction")
check(t.id=="transaction"and t.phase=="applied"and j.store.state.vault.protocol.active.error==nil,"repair persists current phase without replay or rollback")
check(not j:TryRecover()and j.store.writes==1,"repeated repair does not reissue items")
j,v,item,t=setup();item.valid=false
j:Flush();now=122
check(not j:TryRecover()and v.error and not j.store.writes,"deleted item reference cannot be guessed or refunded")
j,v,item,t=setup();j.error="corrupt_committed_journal";v.error=j.error
check(not j:TryRecover()and not j.store.writes,"corrupt journal is never cleared")
j,v,item,t=setup();j.capture_error="linked_items";j.error=j.capture_error;v.error=j.error;t.error="snapshot_mismatch"
check(not j:TryRecover()and not j.store.writes,"ownership mismatch is not a capture retry")
t.error="journal_write_failed";v.rows.held=nil;now=133
check(not j:TryRecover(),"missing transaction custody cannot be repaired")
j,v,item,t=setup();j.capture_error="linked_items";j.error=j.capture_error;v.error=j.error;t.error="journal_write_failed"
check(j:TryRecover(),"valid current custody may retry")
j.store.callback(false,"disk_failed")
check(v.error=="disk_failed"and j.error=="disk_failed"and t.error=="journal_write_failed","failed durable write keeps protection")
now=144;check(not j:TryRecover(),"disk failure requires diagnosis, not capture retry")
GetStaticTime=clock
-- Treat mod records generically, rejecting only data that cannot be carried.
local custom=SpawnPrefab("custom_mod_item")
Prefabs.custom_mod_item=true
custom.data={charge=.37,nested={ingredients={"rocks","twigs"}},customskin="test"}
check(Adapter.CheckItem(custom),"registered mod prefab and custom component data are accepted")
local get=custom.GetSaveRecord
custom.GetSaveRecord=function(...)return get(...),"bad reference type"end
check(not Adapter.CheckItem(custom),"malformed mod reference result is safely rejected")
custom.GetSaveRecord=function()error("mod save failure")end
check(not Adapter.CheckItem(custom),"throwing mod save callback is safely rejected")
custom.GetSaveRecord=get;custom.data.bad=function()end
check(not Adapter.CheckItem(custom),"nonportable executable value is rejected before movement")
print("Vault capture recovery: "..checks.." checks passed")
