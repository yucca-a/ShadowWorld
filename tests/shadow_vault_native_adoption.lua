local Native=require("shadowvaultnative2hm")
local Config=require("shadowvaultconfig2hm")
local checks=0
local function check(ok,why)checks=checks+1;assert(ok,why)end
local clock=GetStaticTime
local now=100
GetStaticTime=function()return now end
local function box()
    local e=VA_TEST.box(false)
    function e:GetPersistData()return {container=self.components.container:OnSave()}end
    return e
end
check(not Config.Manageable("legacycontainer_KU_Test",box()),"offline private pockets are excluded")
local private=box();private.userid="KU_Test"
check(not Config.Manageable("other_private_mod",private),"mod private pockets carrying a userid are excluded")
check(Config.Manageable("cloudpine_l4",box()),"public mod pockets remain eligible")
local v=VA_TEST.service("1")
v.pages["1"].GetPersistData=function()return {}end
local good,bad=box(),box()
local linked=SpawnPrefab("goldnugget")
linked.HasTag=function(_,tag)return tag=="irreplaceable"end
bad.components.container:GiveItem(linked,4)
v.native_bases={shadow=v.base,cloudpine_l4=bad,skull=good,legacycontainer_KU_Test=private}
local journal=setmetatable({v=v,receipts={},deposits={}},require("shadowvaultjournal2hm"))
check(journal:Restore({schema=4,pages={},rows={},registry={["1"]={imported=true}},protocol={mode="journal"}}),"old journal restores before adopting new pockets")
check(v.pages[Config.Page("1","cloudpine_l4")]==nil and bad:IsValid() and bad.components.container.slots[4]==linked,
    "journal restore cannot silently enlist unrecorded native pockets")
local n=Native.new(v);n.shared=nil;v.native=n
local badid=Config.Page("1","cloudpine_l4")
local goodid=Config.Page("1","skull")
n:Adopt()
check(n:Owns("1") and n:Owns(goodid),"one unsupported page does not stop healthy pages")
check(not v.registry[badid] and not v.pages[badid] and not n.checkpoints[badid],"failed preflight cannot install empty checkpoints")
check(n.localonly[badid]=="linked_items" and not v.error,"unsupported page is local-only without global error")
check(bad.components.container.slots[4]==linked and linked:IsValid(),"retention keeps original item entity and slot")
check(not bad.components.container.readonlycontainer,"native local storage stays usable")
check(not n.state.owners[Config.Page("1","legacycontainer_KU_Test")],"private storage is never adopted")
local saved=bad.components.container:RemoveItemBySlot(4)
n:Adopt()
check(not n:Owns(badid),"adoption retries are throttled")
now=106;bad.components.container.opencount=1;n:Adopt()
check(not n:Owns(badid) and n.localonly[badid]=="busy","an open local box cannot be adopted")
now=112;bad.components.container.opencount=0;n:Adopt()
check(n:Owns(badid) and v.pages[badid]==bad and not n.localonly[badid],"closing a now-safe box automatically adopts the same container")
check(saved==linked and saved:IsValid(),"retry does not destroy the removed protected item")
-- An owned/transactional page must never be guessed back into local-only mode.
bad.components.container.slots[4]=linked;now=118;n:Adopt()
check(n:Owns(badid) and v.pages[badid]==bad,"existing custody cannot be silently detached")
local secondary=VA_TEST.service("2")
secondary.native_ready=true;secondary.transport.peers["1"]={session="session1"}
secondary.base.GetPersistData=function()return {}end
secondary.base.components.container.slots[1]=linked
secondary.native=Native.new(secondary);secondary.native.shared=nil
secondary.protocol.Start=function()error("unsafe import reached transaction creation")end
secondary:StartImport("2")
check(not next(secondary.rows) and not secondary.error,"unsafe secondary import never creates a journal row")
check(secondary.native.localonly["2"]=="linked_items" and not secondary.base.components.container.readonlycontainer,"secondary native contents remain locally accessible")
-- A page registered by Initialize but not owned yet is safely removed from capture.
local unowned=VA_TEST.service("1");unowned.base.components.container.slots[1]=linked
unowned.native_bases={shadow=unowned.base};unowned.native=Native.new(unowned);unowned.native.shared=nil
unowned.native:Adopt()
check(not unowned.pages["1"] and not unowned.registry["1"] and unowned.native.localonly["1"],"unowned local base cannot poison the global journal")
GetStaticTime=clock
print("Native page adoption: "..checks.." checks passed")
