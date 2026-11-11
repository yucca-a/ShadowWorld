local Vault=require("components/shadowvault2hm")
local Config=require("shadowvaultconfig2hm")
local Transport=require("shadowvaulttransport2hm")
local checks,serial=0,0
local function check(ok,why)checks=checks+1;assert(ok,why)end
local function entity(prefab)
    serial=serial+1
    local e={GUID=serial,prefab=prefab,persists=true,valid=true,components={}}
    function e:IsValid()return self.valid end
    function e:HasTag()return false end
    function e:Remove()self.valid=false end
    function e:PushEvent()end
    function e:GetBasicDisplayName()return self.prefab end
    function e:SetPersistData(data)self.data=deepcopy(data)end
    function e:GetSaveRecord()return {prefab=self.prefab,data=self.data or {}} end
    return e
end
local function box(single)
    local e=entity(single and "shadowvaulttransfer2hm" or "shadowvaultpage2hm")
    local c={inst=e,numslots=single and 1 or 12,slots={},acceptsstacks=true,opencount=0}
    e.components.container=c
    function c:EnableReadOnlyContainer(v)self.readonlycontainer=v end
    function c:CanTakeItemInSlot(_,slot)return not self.readonlycontainer and (not slot or slot<=self.numslots)end
    function c:GiveItem(item,slot)
        if self.slots[slot] or not self:CanTakeItemInSlot(item,slot) then return false end
        self.slots[slot]=item;item.components.inventoryitem.owner=e;return true
    end
    function c:RemoveItemBySlot(slot)
        local item=self.slots[slot];self.slots[slot]=nil
        if item then item.components.inventoryitem.owner=nil end
        return item
    end
    function c:OnSave()
        local items={};for slot,item in pairs(self.slots)do items[slot]=item:GetSaveRecord()end
        return {items=items}
    end
    return e
end
SpawnPrefab=function(prefab)
    if prefab=="shadowvaultpage2hm" or prefab=="shadowvaulttransfer2hm" then return box(prefab=="shadowvaulttransfer2hm") end
    local e=entity(prefab);e.components.inventoryitem={};return e
end
AllPlayers={};TUNING={SHADOWVAULT_ENABLED2HM=true};SHARDID={MASTER="1"}
Prefabs={goldnugget=true,rocks=true}
local connected=true
Shard_IsWorldAvailable=function()return connected end
GetClientModRPC=function()return {}end
SendModRPCToClient=function()end
local function service(id)
    TheShard={GetShardId=function()return id end}
    local w={ismastershard=id=="1",meta={session_identifier="session"..id},components={},base=box(false),
        ListenForEvent=function()end,IsValid=function()return true end,
        DoStaticPeriodicTask=function()return {Cancel=function()end}end,
        DoStaticTaskInTime=function()return {Cancel=function()end}end,
        PushEvent=function()end,GetPocketDimensionContainer=function(self,name)return name=="shadow" and self.base or nil end}
    local v=Vault(w);w.components.shadowvault2hm=v;v:Initialize();return v
end
local main=service("1")
main:Register("2");main:Register("3");main:Register("4")
local first=main.pages["2"];main:Register("2")
check(main.pages["2"]==first,"repeat registration never replaces stored page")
check(main.pages["3"]~=main.pages["4"],"independent shard spaces")
check(table.concat(Config.Order(main.registry),",")=="1,2,3,4","stable numeric page order")
main.registry["2"].imported=true
local c=first.components.container;c:EnableReadOnlyContainer(false)
local gold=SpawnPrefab("goldnugget");gold.data={count=17};c:GiveItem(gold,4)
main.receiving_peer="2"
main.remoteviews={["2"]={KU_Test={page="2",session="view1",time=GetStaticTime()}}}
local name="W:2:4:KU_Test:one:"..main:SlotToken("2",4)..":view1"
check(main:Lock(name),"withdraw reserves an existing stack")
check(c.slots[4]==nil and main.rows[name].escrow.components.container.slots[1]==gold,"one real owner during withdrawal")
check(not c:CanTakeItemInSlot(SpawnPrefab("rocks"),4),"reserved slot rejects concurrent deposit")
local snap=WorldExchange.Snapshot(main,name)
check(snap and snap.items[1].data.count==17,"own withdrawal snapshot may contain an item")
local empty={layout=snap.layout,session="session2",items={}}
check(main:ValidateIncoming(name,empty),"withdraw accepts an empty incoming escrow")
check(not main:ValidateIncoming(name,snap),"withdraw rejects a second incoming item")
check(main:Finalize(name,false),"precommit abort returns reservation")
check(c.slots[4]==gold and next(main.rows)==nil,"abort restores original identity exactly once")
check(not main:Finalize(name,false),"repeated finalization cannot manufacture goods")
local d="D:2:5:KU_Test:two:"..main:SlotToken("2",5)..":view1"
check(main:Lock(d),"empty slot reserved for deposit")
check(WorldExchange.Snapshot(main,d).items[1]==nil,"own deposit snapshot remains empty")
check(main:ValidateIncoming(d,snap),"deposit accepts one incoming item")
local double=deepcopy(snap);double.items[2]=deepcopy(snap.items[1])
check(not main:ValidateIncoming(d,double),"single-stack transfer rejects extra item slots")
check(WorldExchange.Apply(main,d,snap),"apply incoming record into hidden escrow")
check(main:Finalize(d,true),"commit deposit")
check(c.slots[5] and c.slots[5].data.count==17,"deposited item is now master-owned")
check(not c.readonlycontainer and not first.dcs2hm,"completed reservation restores page access")
connected=false
check(main:Catalog("2").items["5"]~=nil,"offline page reads use local items")
local icon=c.slots[5].components.inventoryitem
icon.imagename="gift_medium2"
check(main:Catalog("2").items["5"].image=="gift_medium2.tex","dynamic inventory images use the native atlas region")
icon.imagename="gift_medium2.tex"
check(main:Catalog("2").items["5"].image=="gift_medium2.tex","complete inventory image names are preserved")
icon.imagename=nil
local removed=c:RemoveItemBySlot(5)
check(removed and c:GiveItem(removed,5),"offline target accepts local take and put")
local saved,refs=main:OnSave()
check(#refs==4 and saved.pages["2"]==first.GUID,"all spaces referenced in native world snapshot")
local restored=service("1")
restored:OnLoad(saved)
local entities={};for _,page in pairs(main.pages)do entities[page.GUID]={entity=page}end
restored:LoadPostPass(entities,saved)
check(restored.pages["2"]==first,"postpass restores the recorded page, not an empty replacement")
local damaged=service("1");damaged:OnLoad(saved)
local missing=deepcopy(entities);missing[first.GUID]=nil
damaged:LoadPostPass(missing,saved)
local protected=damaged:OnSave()
check(damaged.error and protected.pages["2"]==first.GUID and protected.pages["3"],"missing page stays marked for recovery without discarding readable pages")
connected=true
local source=service("2");source.native_ready=true;source.imported=true
local player=entity("wilson");player.userid="KU_Test";player.components.inventory={GetActiveItem=function()error("must not read inventory while offline")end}
AllPlayers={player};source.AccessAllowed=function()return true end
source.views[player.userid]={page="2",session="source_view"};source.registry["2"]={imported=true}
source.transport.peers["1"]={session="session1",boot="peer"}
connected=false
source:Action(player,"deposit","2",1,"empty","source_view")
check(next(source.rows)==nil and not source.protocol.active,"disconnected requests cannot take player items")
source.native_ready=false
local called=false;source.protocol.Receive=function()called=true end
source:Receive("1",{v=1})
check(not called,"secondary blocks saved receipts until native alignment")
connected=true
local tr=Transport.new(main.inst,{fail=function()error("unexpected transport failure")end})
tr.peers["2"]={boot="peer"}
tr:Send("2",{kind="CATALOG",userid="A"});tr:Send("2",{kind="CATALOG",userid="B"})
check(#tr.outbox==2,"different players never overwrite each other's catalog response")
tr:Send("2",{kind="CATALOG",userid="A"})
check(#tr.outbox==2,"same player refresh coalesces")
check(Config.ActiveSave({map={persistdata={shadowvault2hm=saved}}}),"vault save bypasses obsolete independent checkpoint journal")
check(not Config.Parse("D:2:1001:KU_Test:bad") and not Config.Parse("D:2:1:KU_Test:bad:extra"),"malformed transaction targets rejected")
local fresh=service("1");fresh.status="initializing"
check(fresh:Activate(),"activation no longer waits for a shared checkpoint or other shards")
local legacydata={active={name="shadow",phase="intent",own={items={}}}}
local guarded=service("1");guarded.protocol=nil;guarded.inst.components.worldexchange2hm={saved=legacydata}
guarded:Initialize()
check(guarded.error=="legacy_exchange_pending" and not guarded.protocol,"unfinished old exchange is preserved without starting its coordinator")
check(guarded.base.components.container.readonlycontainer,"unfinished legacy custody remains protected")
check(guarded.inst.components.worldexchange2hm.saved==legacydata,"old transaction record is not erased")

-- A stale view must fail before the master removes a different item. Existing
-- journals use their saved escrow and must not be revalidated against a new boot.
local stamp=main:SlotToken("2",4)
local original=c:RemoveItemBySlot(4)
local replacement=SpawnPrefab("rocks");c:GiveItem(replacement,4)
local stale="W:2:4:KU_Test:stale:"..stamp..":view1"
local ok,why=main:Lock(stale)
check(not ok and why=="stale" and c.slots[4]==replacement and not main.rows[stale],"master rejects replaced item without taking it")
c:RemoveItemBySlot(4);c:GiveItem(original,4)
original.components.stackable={StackSize=function()return 2 end}
check(not main:Lock(stale),"same entity with changed stack count invalidates the view")
original.components.stackable=nil
main.remoteviews["2"].KU_Test.session="view2"
check(not main:Lock(stale),"closed and reopened view cannot replay old clicks")
main.remoteviews["2"].KU_Test.session="view1"
check(not main:Lock("W:2:4:KU_Test:unsigned"),"new requests without item stamp are rejected")
local old="W:2:4:KU_Test:legacy"
local held=box(true);held.components.container:GiveItem(c:RemoveItemBySlot(4),1)
main.rows[old]={op="W",page="2",slot=4,userid="KU_Test",state="active",escrow=held}
check(main:Lock(old),"saved pre-upgrade escrow can resume without new view metadata")
check(main:Finalize(old,false) and c.slots[4]==original,"saved pre-upgrade abort returns exactly its held item")
local parsed=Config.Parse("D:2:1:KU_Test:n:boot_empty:view")
check(parsed and parsed.token=="boot_empty" and parsed.session=="view","versioned request fields survive protocol serialization")
check(not Config.Parse("D:2:1:KU_Test:n:"..string.rep("a",121)..":view"),"oversized identity stamp rejected")

local priorclock=GetStaticTime;local now=100
GetStaticTime=function()return now end
source.native_ready=true;source.error=nil;source.protocol.active=nil
local view=source.views[player.userid];view.catalog={page="2",items={},emptytoken="empty"}
player._shadowvault_nextaction=nil
local delivery=box(true);delivery.components.container:GiveItem(SpawnPrefab("rocks"),1)
source.rows.waiting={userid=player.userid,page="2",state="delivery",escrow=delivery}
source:Action(player,"deposit","2",1,"empty",view.session)
check(source.rows.waiting and not source.protocol.active,"pending delivery blocks extra custody before reading active item")
local state=source:ClientState(player.userid)
check(state.mode=="delivery" and state.page=="2" and state.name=="rocks" and state.count==1,"waiting status names the held item and its page")
check(Config.StatusText(state,true):find("暂存")~=nil,"waiting status explains inventory-space recovery")
local retained=source.rows.waiting.escrow.components.container.slots[1]
source:OnSave()
check(source.rows.waiting.escrow.components.container.slots[1]==retained,"status and saving never move or duplicate held items")
source.rows={}
for i=1,32 do source.rows[tostring(i)]={userid="another"..i,state="delivery"}end
now=101;source:Action(player,"deposit","2",1,"empty",view.session)
check(not source.protocol.active,"world pending limit rejects before touching player inventory")
source.rows={};now=102
local refreshes=0;source.Refresh=function()refreshes=refreshes+1 end
for i=1,100 do source:Action(player,"withdraw","2",1,"old","wrong_view")end
check(refreshes==1 and not source.protocol.active,"burst of invalid old clicks is rate limited")

-- Delayed catalogs from an earlier opening cannot update the new panel/session.
local current={page="2",items={},emptytoken="new_empty",session=view.session,registry={}}
source:Receive("1",{vault=1,kind="CATALOG",userid=player.userid,catalog=current})
local cached=view.catalog
local oldcatalog=deepcopy(current);oldcatalog.session="old_view"
source:Receive("1",{vault=1,kind="CATALOG",userid=player.userid,catalog=oldcatalog})
check(view.catalog==cached,"out-of-order catalog from closed opening is ignored")

view.catalog={page="2",items={},emptytoken="empty"}
source.registry["2"]={imported=true}
local helditem=SpawnPrefab("rocks");local olditem=SpawnPrefab("goldnugget")
player.components.inventory.GetActiveItem=function()return helditem end
now=110;source:Action(player,"deposit","2",1,"empty",view.session,olditem,1)
check(not next(source.rows) and view.notice=="cursor","delayed deposit cannot take a replacement cursor item")
helditem.components.stackable={StackSize=function()return 17 end}
now=111;source:Action(player,"deposit","2",1,"empty",view.session,helditem,18)
check(not next(source.rows) and view.notice=="cursor","changed cursor stack amount also requires a fresh click")

-- Pre-upgrade checkpoint requests and stale save packets must not trigger a
-- world save. New transfers are verified by the snapshot/instant protocol tests.
local saves=0;main.inst.PushEvent=function(_,event)if event=="ms_save" then saves=saves+1 end end
main.protocol.active={id="old",phase="intent"}
main:Checkpoint()
check(saves==0,"legacy transfer waits for a normal save without requesting one")
main.protocol.active=nil
main:Receive("2",{vault=1,kind="CHECKPOINT",id="2/s/b/1",phase="aborting"})
check(saves==0,"old checkpoint packets cannot force native saves")
local Courier=require("shadowvaultcourier2hm")
local overflow=box(true);local parcel=SpawnPrefab("goldnugget");parcel.data={count=17}
overflow.components.container:GiveItem(parcel,1)
source.rows={overflow={userid=player.userid,page="2",state="delivery",escrow=overflow}}
local luggage={["legacy:2/boot/1"]={page="2",payload=WorldExchange.Snapshot(source,"overflow")}}
Courier.Departing(source,player.userid,"1")
check(source.rows.overflow.forward=="1" and parcel:IsValid(),"departure leaves overflow in its original escrow for background transfer")
Courier.Here(source,player.userid)
check(source.rows.overflow.forward==nil and parcel:IsValid(),"return before background transfer keeps the original custody")
Courier.Accept(main,player.userid,luggage)
local parcelid=next(luggage);local arrived=main.rows[parcelid].escrow.components.container.slots[1]
check(arrived.data.count==17 and main.rows[parcelid].state=="delivery","legacy carried parcel can still be restored after upgrade")
Courier.Accept(main,player.userid,luggage)
check(main.rows[parcelid].escrow.components.container.slots[1]==arrived,"duplicate player payload does not recreate parcel")
main.rows[parcelid].escrow:Remove();main.rows[parcelid]=nil
Courier.Accept(main,player.userid,luggage)
check(main.rows[parcelid]==nil,"receipt prevents replay after parcel was already delivered")
local mail={later={page="2",payload=deepcopy(luggage[parcelid].payload)}}
Courier.Departing(main,player.userid,"3");Courier.Accept(main,player.userid,mail)
check(main.rows.later.forward=="3","late transaction result follows a player who has moved on")
Courier.Here(main,player.userid)
check(main.rows.later.forward==nil and main.delivery_routes[player.userid]==nil,"returning player cancels stale forwarding route")
local nativeSpawn=SpawnPrefab
SpawnPrefab=function(prefab)if prefab=="goldnugget" then return nil end;return nativeSpawn(prefab)end
Courier.Accept(main,player.userid,{failed={page="2",payload=deepcopy(luggage[parcelid].payload)}})
check(main.travel_inbox.failed and not main.travel_receipts.failed,"restoration failure retains serialized custody without marking delivery complete")
SpawnPrefab=nativeSpawn;now=now+3;Courier.Receive(main)
check(main.rows.failed and not main.travel_inbox.failed,"retained parcel can recover without another transfer")
local gone=main.rows.failed.escrow.components.container.slots[1];gone:Remove()
main.rows.failed.forward="3"
Courier.Forward(main)
check(not main.rows.failed,"native item migration clears an invalid item reference left in a readonly escrow")
local notices={}
function main:Say(_,zh) notices[#notices+1]=zh end
local destination={page="2",registry={["2"]={name="洞穴"}},ready=false}
local traveling={page="2",travel_to="2"}
main:ShowCatalog(player.userid,traveling,destination)
check(#notices==0,"travel confirmation waits for the destination")
destination.ready=true
main:ShowCatalog(player.userid,traveling,destination)
main:ShowCatalog(player.userid,traveling,destination)
check(#notices==1 and notices[1]=="成功穿越世界2啦","catalog refreshes use the original travel line only once")
local hat=entity("tophat")
local hat_opener=entity("tophat_container")
hat.container,hat_opener.tophat=hat_opener,hat
main.views[player.userid]={anchor=hat_opener}
player.components.magician={item=hat}
check(main:AccessAllowed(player.userid),"the native hat opener needs no Transform")
player.components.magician.item=nil
check(not main:AccessAllowed(player.userid),"a hat opener cannot be used after the owner stops using the hat")
GetStaticTime=priorclock
print("Shadow vault checks: "..checks.." (native Lua serializer; custody and transport)")
