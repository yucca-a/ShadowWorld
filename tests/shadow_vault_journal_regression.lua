local Journal=require("shadowvaultjournal2hm")
local n=0
local function check(ok,why)n=n+1;assert(ok,why)end
local function player()
    local p=VA_TEST.entity("wilson");p.userid="KU_Journal"
    local inv={itemslots={},maxslots=15,capacity=99};p.components.inventory=inv
    function inv:GetItemInSlot(slot)return self.itemslots[slot]end
    function inv:CanTakeItemInSlot()return true end
    function inv:CanAcceptCount()return self.capacity end
    function inv:GiveItem(item,slot)self.itemslots[slot or 1]=item;item.components.inventoryitem.owner=p;return true end
    function inv:ForEachItem(fn)for _,item in pairs(self.itemslots)do fn(item)end end
    function inv:RemoveItem(item)for slot,value in pairs(self.itemslots)do if value==item then self.itemslots[slot]=nil;item.components.inventoryitem.owner=nil;return item end end end
    return p
end
local originalspawn=SpawnPrefab
SpawnPrefab=function(prefab)
    local item=originalspawn(prefab)
    function item:AddComponent(name)self.components[name]={}end
    function item:RemoveComponent(name)self.components[name]=nil end
    return item
end
local function journal()
    local v={session="journal_session",rows={},pages={},registry={},base=VA_TEST.box(false),
        LocalBase=require("components/shadowvault2hm").LocalBase,
        Fail=function(self,why)self.error=why end,Notify=function()end,Refresh=function()end}
    local j=setmetatable({v=v,ready=true,issued={},deliveries={},deposits={},receipts={},mail={}},Journal)
    function j:Flush(cb)self.flushes=(self.flushes or 0)+1;if cb then cb(true)end end
    function j:WritePlayer(p,cb)cb(true,{data={shadowvault_receipts2hm=deepcopy(p.shadowvault_receipts2hm)}})end
    v.journal=j;return j,v
end
local function delivery(v,name)
    local e=VA_TEST.box(true);local item=SpawnPrefab("goldnugget");item.data={amount=17}
    item.components.stackable={StackSize=function()return item.amount or 17 end}
    e.components.container:GiveItem(item,1)
    local row={userid="KU_Journal",page="2",state="delivery",escrow=e};v.rows[name]=row
    return row,item
end
local j,v=journal();local p=player();AllPlayers={p}
local row,item=delivery(v,"one")
p.components.inventory.capacity=0;j:Deliver("one",row,p)
check(row.state=="delivery" and not j.flushes,"full bag keeps custody without repeated writes")
p.components.inventory.capacity=99;j:Deliver("one",row,p)
check(not v.rows.one and p.components.inventory.itemslots[1]==item,"delivery moves the actual item")
check(p.shadowvault_receipts2hm.one and j.deliveries.one.state=="held","delivery has receipt and independent recovery payload")
j:Deliver("one",row,p)
check(p.components.inventory.itemslots[1]==item and not v.rows.one,"receipt prevents repeated delivery")
-- Native file truncation removes a delivery from the old player profile.
p.components.inventory:RemoveItem(item);item:Remove();local restored=player();AllPlayers={restored}
j:ReconcilePlayer(restored)
check(v.rows.one and v.rows.one.state=="delivery","only missing held delivery is reconstructed")
j:Deliver("one",v.rows.one,restored)
check(not v.rows.one and restored.components.inventory.itemslots[1].data.amount==17,"restored item data survives exactly")
j:ReconcilePlayer(restored)
check(not v.rows.one,"reconciliation cannot issue the same parcel twice")
-- A receipt with no item is possible after consumption, and never a refund.
j,v=journal();p=player();p.shadowvault_receipts2hm={used=true};AllPlayers={p}
j.deliveries.used={userid=p.userid,page="2",state="held",payload={items={},session=v.session,layout="1:false:true:false"}}
j:ReconcilePlayer(p)
check(not v.rows.used and j.deliveries.used.state=="spent","spent receipt is not guessed as item loss")
-- Any ownership change first revokes the recovery claim; growing mixed stacks
-- cannot incorporate older inventory into an automatic refund.
j,v=journal();p=player();AllPlayers={p};row,item=delivery(v,"mixed");j:Deliver("mixed",row,p)
item.amount=20;j:IssuedChanged("mixed",item)
check(j.deliveries.mixed.state=="spent" and not j.deliveries.mixed.payload,"change invalidates old refund immediately")
j:RefreshIssued()
check(j.deliveries.mixed.reason=="mixed_stack" and not j.deliveries.mixed.payload,"mixed stack cannot multiply pre-existing goods")
j,v=journal();p=player();AllPlayers={p};row,item=delivery(v,"partial");j:Deliver("partial",row,p)
item.amount=12;j:IssuedChanged("partial",item);j:RefreshIssued()
check(j.deliveries.partial.state=="held" and j.deliveries.partial.count==12,"remaining same-owner quantity can be tracked")
j:Departing(p.userid)
check(j.deliveries.partial.reason=="migrated" and not j.deliveries.partial.payload,"native departure revokes source refund without a remote reply")
-- Dedupe only tagged deposits; never rewind unrelated progress or inventory.
j,v=journal();p=player();AllPlayers={p}
local duplicate=SpawnPrefab("goldnugget");duplicate.components.shadowvaultticket2hm={id="deposit"}
local unrelated=SpawnPrefab("rocks");p.components.inventory:GiveItem(duplicate,1);p.components.inventory:GiveItem(unrelated,2)
j.deposits.deposit=p.userid;j:ReconcilePlayer(p)
check(not duplicate:IsValid() and p.components.inventory.itemslots[2]==unrelated,"remove only known deposited copy")
-- A mailbox ACK is released after the recipient's independent commit, and a
-- replay after consumption can only acknowledge the durable receipt.
j,v=journal();local sent=0;v.transport={Send=function()sent=sent+1 end}
local payload={items={[1]={prefab="goldnugget",data={amount=17}}},session=v.session,layout="1:false:true:false"}
local cb
function j:Flush(fn)self.busy=true;cb=fn end
j:AcceptParcel("parcel","KU_Journal","2",payload,"1")
check(sent==0 and v.rows.parcel,"mailbox has custody before ACK")
j:AcceptParcel("parcel","KU_Journal","2",payload,"1")
check(sent==0,"uncommitted receipt cannot acknowledge a duplicate")
j.busy=nil;cb(true);check(sent==1,"durable receipt releases one ACK")
v.rows.parcel.escrow:Remove();v.rows.parcel=nil
j:AcceptParcel("parcel","KU_Journal","2",payload,"1")
check(sent==2 and not v.rows.parcel,"late mail cannot resurrect consumed goods")
-- If replacing the native base fails after staging, all other original pages
-- must still be present, and temporary staged copies must be removed.
j,v=journal();v.master=true;v.id="1";v.pages={["1"]=v.base,["2"]=VA_TEST.box(false)}
local original=SpawnPrefab("goldnugget");original.data={amount=17}
v.pages["2"].components.container:GiveItem(original,1)
local own=Journal.Payload(v,v.base);local other=Journal.Payload(v,v.pages["2"])
local saved={schema=4,pages={["1"]=own,["2"]=other},rows={},registry={},protocol={mode="journal"}}
local adapter=require("shadowvaultitems2hm");local apply=adapter.Apply
adapter.Apply=function(proxy,name,payload)if proxy:Container(name)==v.base then return false,"injected_base_failure" end return apply(proxy,name,payload)end
local ok,why=j:Restore(saved);adapter.Apply=apply
check(not ok and why=="injected_base_failure","base replacement failure is explicit")
check(original:IsValid() and v.pages["2"].components.container.slots[1]==original,"failed restore preserves unrelated original page custody")
j,v=journal();v.master=false;v.id="2"
local snapshot=adapter.Snapshot
adapter.Snapshot=function(proxy,name)if proxy:Container(name)==v.base then error("obsolete base must not be re-serialized")end return snapshot(proxy,name)end
local ok=j:Restore({schema=4,imported=true,pages={},rows={},registry={},protocol={mode="journal"}})
adapter.Snapshot=snapshot
check(ok and v.imported,"imported secondary clears obsolete native base without serializing its old contents")

-- Native pocket-only items must fail before the tagged save or cursor removal.
j,v=journal();p=player()
local inv=p.components.inventory
local blocked=SpawnPrefab("rocks")
inv.active=blocked;blocked.components.inventoryitem.owner=p
function inv:GetActiveItem()return self.active end
local escrow=VA_TEST.box(true)
escrow.components.container.CanTakeItemInSlot=function()return false end
local notice
function v:Notify(_,why)notice=why end
function j:WritePlayer()error("unsupported item must not write a before-image")end
j:StageDeposit("blocked",{escrow=escrow,userid=p.userid},blocked,p)
check(inv.active==blocked and blocked:IsValid() and not blocked.components.shadowvaultticket2hm,"rejected item stays on the cursor")
check(not v.error and not escrow:IsValid() and notice=="unsupported","rejected item does not protect the shared spaces")

-- A hook can still refuse actual placement after the permission check.
escrow=VA_TEST.box(true)
escrow.components.container.GiveItem=function()return false end
function inv:RemoveItem(item)self.active=nil;item.components.inventoryitem.owner=nil;return item end
function inv:GiveActiveItem(item)self.active=item;item.components.inventoryitem.owner=p end
function j:WritePlayer(_,cb)cb(true,{data={shadowvaultticket2hm=blocked.components.shadowvaultticket2hm}})end
j:StageDeposit("late",{escrow=escrow,userid=p.userid},blocked,p)
check(inv.active==blocked and not blocked.components.shadowvaultticket2hm and not escrow:IsValid(),"late refusal restores the original item and removes its ticket")
check(not v.error and not next(v.rows),"recoverable placement failure leaves the journal usable")
-- Several transferable items can exceed one RPC message when the whole page
-- is saved to disk. This must not prevent committing the page.
j,v=journal()
v.pages["1"]=v.base
v.protocol={Save=function()return {mode="journal"}end}
for slot=1,6 do
    local bulky=SpawnPrefab("goldnugget")
    bulky.data={padding=string.rep("V",100000)}
    v.base.components.container:GiveItem(bulky,slot)
end
local message,reason=Journal.Payload(v,v.base)
check(not message and reason=="too_large","whole large pages still cannot fit in one transfer")
local saved=j:Capture()
check(saved and #saved.pages["1"].items==6 and #saved.pages["1"].items[6].data.padding==100000,
    "whole large pages can be committed to the local journal")
-- Broken bank references require proof before any old physical contents are
-- retired. Preserve the real entity when only native temperature time differs.
local function reconstruction(conflict)
    Ents={}
    local j,v=journal();v.id="1";v.master=true
    v.native_bases={shadow=v.base};v.pages={["1"]=v.base}
    v.GuardPage=function()end
    local source=VA_TEST.box(false)
    function source:GetPersistData()return {container={}}end
    local item=SpawnPrefab("goldnugget");item.data={edible={chill=.6},stackable={stack=7},custom={marker="keep"}}
    source.components.container:GiveItem(item,1)
    local payload=require("shadowvaultnative2hm").ExportPage(v,source)
    payload.items[1].data.edible.chill=.4
    if conflict then payload.items[1].data.stackable.stack=6 end
    local variants={banks={hosted={}},journal_recovery_sources={[source]="shadow",[v.base]="shadow"}}
    v.inst={components={exchangevariants2hm=variants},PocketDimensionContainers={shadow=v.base}}
    function v.inst:SetPocketDimensionContainer(f,e)self.PocketDimensionContainers[f]=e end
    v.saved_native_world={version=1,shared=true,owners={["1"]="1"},epochs={["1"]=0}}
    local saved={schema=4,pages={["1"]=payload},rows={},registry={["1"]={imported=true}},
        protocol={mode="journal"},native=deepcopy(v.saved_native_world)}
    return j,v,source,item,saved,variants
end
j,v,source,item,saved,variants=reconstruction(false)
local oldbase=v.base
local ok,why=j:Restore(saved)
check(ok,"complete journal can reconstruct a bank whose references are stale: "..tostring(why))
check(v.pages["1"]==source and source.components.container.slots[1]==item,"reconstruction keeps the unique actual item instead of replacing it with an older checkpoint")
check(item.data.edible.chill==.6 and item.data.custom.marker=="keep","native temperature and arbitrary item component data are preserved")
check(v.inst.PocketDimensionContainers.shadow==source and not oldbase:IsValid(),"empty constructor cannot override the journal goods")
check(variants.banks.hosted.shadow==source and not variants.journal_recovery_sources,"reconstructed references are current and recovery completes once")
j,v,source,item,saved=reconstruction(true)
local originalbase=v.base
ok,why=j:Restore(saved)
check(not ok and why=="migration_source_conflict","a stack-count difference is a protected conflict rather than a temperature update")
check(source:IsValid() and source.components.container.slots[1]==item and originalbase:IsValid(),"conflict preserves every original source and its real item")
j,v,source,item,saved=reconstruction(false)
for _,id in ipairs({"2","3"})do
    saved.pages[id]=deepcopy(saved.pages["1"]);saved.native.owners[id]="1";saved.native.epochs[id]=0
    saved.registry[id]={imported=true}
end
ok,why=j:Restore(saved)
check(not ok and why=="migration_source_conflict" and source:IsValid(),"three identical page candidates cannot prove where an updated real source belongs")
local absent={schema=4,pages={},rows={},registry={},protocol={mode="journal",active={name="missing"}}}
ok,why=j:Restore(absent)
check(not ok and why=="missing_transfer_record","missing durable transfer row remains protected after the journal has loaded")
local vault=require("components/shadowvault2hm")
v.pages={["1"]=VA_TEST.box(false)};v.reserved={}
check(vault.Reserve(v,"native_page",{op="N",page="1",state="active"}),"restored whole-page transfer needs no numeric item slot")
check(v.pages["1"].components.container.readonlycontainer and not next(v.reserved),"whole-page restoration locks the page without a nil slot reservation")
print("Independent vault journal custody: "..n.." checks passed")
