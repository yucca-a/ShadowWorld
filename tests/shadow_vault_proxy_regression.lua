local Proxy=require("shadowvaultproxy2hm")
local Config=require("shadowvaultconfig2hm")
local checks=0
local function check(ok,why)checks=checks+1;assert(ok,why)end
local function entity()
    local e={components={container={}},replica={container={}},valid=true}
    function e:IsValid()return self.valid end
    function e:Remove()self.valid=false end
    e.replica.container.classified={IsValid=function()return true end}
    return e
end
local before=TheWorld
local canonical=entity()
TheWorld={PocketDimensionContainers={tacklestation2hm=canonical}}
function TheWorld:GetPocketDimensionContainer(family)return self.PocketDimensionContainers[family]end
local old=entity();old.shadowvault_page2hm="tackle_1";old.valid=false;old.replica.container.classified=nil
local anchor=entity();anchor.StopUpdatingComponent=function(self)self.stopped=true end
local p={inst=anchor,master=old,openlist={},opencount=0}
function p:SetMaster(e)self.master=e end
check(not Proxy.Ready(old),"removed native container cannot be opened")
check(Proxy.Ensure(p,{native_bases={tacklestation2hm=canonical}}) and p.master==canonical,"stale pointer binds to the existing native space")
check(Proxy.Ensure(p) and p.master==canonical,"valid master is left unchanged")
canonical.replica.container.classified=nil
check(not Proxy.Ensure(p) and p.master==canonical,"missing network data does not spawn or replace storage")
canonical.replica.container.classified={IsValid=function()return true end}
local player=entity();player.components.inventory={opencontainerproxies={[anchor]=true}}
local opener=entity();p.openlist[player]=opener;p.opencount=1;p.master=old
local closes=0;p.onclosefn=function()closes=closes+1 end
check(Proxy.Ensure(p),"stale opener can be safely detached")
check(not opener:IsValid() and p.opencount==0 and not next(p.openlist),"stale opener bookkeeping is released")
check(not player.components.inventory.opencontainerproxies[anchor] and anchor.stopped and closes==1,"native close cleanup runs once")
p.master=old;TheWorld.PocketDimensionContainers={}
check(not Proxy.Ensure(p) and p.master==nil,"missing replacement safely refuses opening")
check(p.shadowvault_family2hm=="tacklestation2hm","family survives deferred native initialization")
TheWorld.PocketDimensionContainers.tacklestation2hm=canonical
check(Proxy.Ensure(p) and p.master==canonical,"later native initialization restores the entrance")
canonical.userid="KU_Private"
check(not Proxy.Family(canonical),"private containers cannot be recovered as shared pockets")
TheWorld=before
-- Rollback replaces an already saved foreign page from its newer journal.
-- Its entrance must follow the replacement before the old entity is removed.
local v=VA_TEST.service("1")
local foreign=VA_TEST.box(false)
v.pages["2"]=foreign
local olditem=SpawnPrefab("goldnugget");foreign.components.container:GiveItem(olditem,1)
local entrance={master=foreign}
function entrance:GetMaster()return self.master end
function entrance:SetMaster(e)self.master=e end
local oldents=Ents
Ents={{components={container_proxy=entrance}}}
TheWorld={PocketDimensionContainers={shadow=v.base}}
function TheWorld:SetPocketDimensionContainer(family,e)self.PocketDimensionContainers[family]=e end
local journal=setmetatable({v=v,receipts={},deposits={}},require("shadowvaultjournal2hm"))
local payload={session=v.session,layout="12:false:true:false",items={[1]={prefab="goldnugget",data={testvalue=7}}}}
check(journal:Restore({schema=4,pages={["2"]=payload},rows={},registry={["2"]={imported=true}},
    protocol={mode="journal"},native={version=1,owners={["2"]="1"},epochs={["2"]=5}}}),"rollback restores the journal page")
check(not foreign:IsValid() and entrance.master==v.pages["2"] and entrance.master:IsValid(),"entrance follows replacement before old foreign page removal")
check(entrance.master.components.container.slots[1].data.testvalue==7 and not olditem:IsValid(),"replacement uses the journal item exactly once")
TheWorld,Ents=before,oldents
print("Stale native entrance recovery: "..checks.." checks passed")
