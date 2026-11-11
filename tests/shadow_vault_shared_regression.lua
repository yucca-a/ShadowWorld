-- Regression for unchanged native entity identity and queued click intent.
local Shared=require("shadowvaultshared2hm")
local Config=require("shadowvaultconfig2hm")
local checks=0
local function check(ok,why)checks=checks+1;assert(ok,why)end
local original=SpawnPrefab
local created=0
SpawnPrefab=function(prefab)
    created=created+1
    local e={prefab=prefab,components={inventoryitem={}},valid=true,tags={}}
    function e:IsValid()return self.valid end
    function e:AddTag(tag)self.tags[tag]=true end
    function e:SetPersistData(data)self.data=deepcopy(data)end
    function e:Remove()self.valid=false end
    return e
end
local entity={components={},shadowvault_records2hm={}}
local c={slots={},numslots=2};entity.components.container=c
function c:EnableReadOnlyContainer(value)self.readonlycontainer=value end
function c:RemoveItemBySlot(slot)local item=self.slots[slot];self.slots[slot]=nil;return item end
function c:GiveItem(item,slot)self.slots[slot]=item;return true end
function entity:SetPersistData(data)self.metadata=data;self.loads=(self.loads or 0)+1 end
local v={};local native={v=v};local shared=Shared.new(native)
local record={prefab="gift",data={unwrappable={items={{prefab="axe",data={finiteuses={uses=31}}}}},x=1,y=2}}
local message={records={["1"]=record},metadata={preserver={upgrade=2}},item_session="session"}
check(shared:Apply(entity,message),"first native view loads")
local item=c.slots[1]
check(created==1 and item.tags.nocrafting and not item.persists,"view items cannot become independent persistent goods")
-- Different insertion order must not replace the native GUID or reload metadata.
local reordered={prefab="gift",data={y=2,x=1,unwrappable={items={{data={finiteuses={uses=31}},prefab="axe"}}}}}
for i=1,20 do
    check(shared:Apply(entity,{records={["1"]=deepcopy(reordered)},metadata=deepcopy(message.metadata)}),"repeat native view applies")
end
check(created==1 and c.slots[1]==item and entity.loads==1,"unchanged save records retain original native entity and metadata")
reordered.data.unwrappable.items[1].data.finiteuses.uses=30
check(shared:Apply(entity,{records={["1"]=reordered},metadata=message.metadata}),"changed nested item applies")
check(created==2 and not item.valid and c.slots[1]~=item,"nested contents are synchronized without losing changes")
check(shared:Apply(entity,{records={},metadata=message.metadata})and not c.slots[1],"authoritative removal clears render copy")
message.identities={["1"]=111}
check(shared:Apply(entity,message),"source identity is synchronized")
item=c.slots[1]
local ticking=deepcopy(message)
ticking.records["1"].data.unwrappable.items[1].data.finiteuses.uses=29
ticking.records["1"].alt_skin_ids={tool="skin_id"}
check(shared:Apply(entity,ticking)and c.slots[1]==item and item.valid,"changing saved item data retains the same native network entity")
check(item.data.unwrappable.items[1].data.finiteuses.uses==29,"same-entity updates still carry nested data changes")
check(item.alt_skin_ids.tool=="skin_id","alternate native skin ownership metadata is retained")
local defaults=deepcopy(ticking)
defaults.records["1"].data.unwrappable=nil
check(shared:Apply(entity,defaults)and not item.valid,"omitted save fields restore prefab defaults instead of retaining stale component data")
item=c.slots[1]
ticking=deepcopy(ticking)
ticking.identities["1"]=222
check(shared:Apply(entity,ticking)and c.slots[1]~=item and not item.valid,"a different source item gets its own native entity")
SpawnPrefab=original

local player={userid="shared_test"}
local view={page="2",session="open1",catalog={items={["1"]={token="clicked"}},emptytoken="empty"}}
shared.ForContainer=function()return view end
shared:Enqueue(player,c,"quicktake",1,nil,"cursor",3)
view.catalog.items["1"].token="changed"
check(shared.queue[1].token=="clicked" and shared.queue[1].requested_count==3,"queued click keeps the clicked slot token and exact count")
shared:Enqueue(player,c,"deposit",2)
check(shared.queue[2].token=="empty","empty-slot intent remains an empty-slot intent")
for i=1,50 do shared:Enqueue(player,c,"quicktake",1)end
check(#shared.queue==32,"click queue is bounded")
shared.openviews[player.userid]={one={page="1"},two={page="tackle_1"}}
check(shared:GetLocal(player.userid,"one").page=="1"and shared:GetLocal(player.userid,"two").page=="tackle_1","different native containers keep independent sessions")
shared.remote["2"]={[player.userid]={one=view,two={page="tackle_2"}}}
check(shared:GetRemote("2",player.userid,"one")==view and shared:GetRemote("3",player.userid,"one")==nil,"remote authorization includes shard, user, and exact open session")
check(Config.Parse("W:2:1:KU_Test:click_n3:token:session").requested_count==3,"native counted gesture survives protocol encoding")
check(not Config.Parse("W:2:1:KU_Test:click_n0:token:session"),"zero-count transfer is rejected")
check(not Config.Parse("W:2:1:KU_Test:click_n1000000001:token:session"),"unbounded transfer count is rejected")
check(Config.Parse("S:2:1:KU_Test:click_s1:token:session").paired,"swap-one retains both outgoing stacks")
check(Config.Concurrent("2")and Config.Concurrent("tackle_2"),"shadow and tackle pages support concurrent access")
check(not Config.Concurrent(Config.Page("2","cloudpine_l4")),"dynamic special containers retain their native manager")

local before_time=GetStaticTime
local now,sends=10,0
GetStaticTime=function()return now end
v={session="world",pages={page=entity},transport={Send=function()sends=sends+1 end}}
c.slots={}
function entity:IsValid()return true end
function v:Catalog()return {ready=true,items={}}end
function entity:GetPersistData()return {container={items={}},preserver={upgrade=2}}end
native={v=v,state={epochs={page=1}},Owns=function()return true end,Changing=function()return false end}
shared=Shared.new(native)
shared:Send("2","KU_Test","page","open1")
shared:Send("2","KU_Test","page","open1")
check(sends==1,"unchanged snapshots are not resent every update")
now=11.1;shared:Send("2","KU_Test","page","open1")
check(sends==2,"unchanged view is periodically resent to recover missing packets")
native.state.epochs.page=2;shared:Send("2","KU_Test","page","open1")
check(sends==3,"changed page epochs are sent immediately")
GetStaticTime=before_time
print("Shared native views: "..checks.." checks passed")
