local Config=require("shadowvaultconfig2hm")
local Native=require("shadowvaultnative2hm")
local checks=0
local function check(ok,reason) checks=checks+1;assert(ok,reason) end

for _,family in ipairs({"shadow","tacklestation2hm","skull","cloudpine_l1","cloudpine_l4","custom_world_box"}) do
    local page=Config.Page("layer_2",family)
    check(Config.Family(page)==family,"space family survives encoding")
    check(Config.PageShard(page)=="layer_2","shard survives encoding")
    check(Config.SameSpace(page,Config.Page("1",family)),"only the same family can be selected")
end
check(not Config.SameSpace(Config.Page("1","skull"),Config.Page("2","shadow")),"skull storage stays separate")
check(not Config.SameSpace(Config.Page("1","cloudpine_l1"),Config.Page("2","cloudpine_l4")),"cloud pine capacities stay separate")

local v={id="2",protocol={}}
local n=Native.new(v,{version=1,owners={page="1"},epochs={page=5}})
n:Receive("1",{kind="REGISTRY",registry={},owners={page="2"},epochs={page=4}})
check(n.state.owners.page=="1" and n.state.epochs.page==5,"an old registry cannot revive a returned page")
n.state.owners.page="2"
n:Receive("1",{kind="REGISTRY",registry={},owners={page="1"},epochs={page=6}})
check(n:Owns("page"),"an editable local page cannot be reassigned by a registry announcement")

local before_world,before_spawn=TheWorld,SpawnPrefab
local original={prefab="custom_box",components={container={}},IsValid=function()return true end}
local world={PocketDimensionContainers={custom_world_box=original}}
function world:SetPocketDimensionContainer(name,entity)self.PocketDimensionContainers[name]=entity end
local setter=world.SetPocketDimensionContainer
TheWorld=world
local created
SpawnPrefab=function(prefab)
    check(prefab=="custom_box","additional pages use the registered original prefab")
    created={prefab=prefab}
    -- Include both common registration forms used by third-party prefabs.
    world:SetPocketDimensionContainer("custom_world_box",created)
    world.PocketDimensionContainers.custom_world_box=created
    return created
end
local clone=Config.SpawnPage(Config.Page("3","custom_world_box"))
check(clone==created and clone~=original,"a separate real entity is created")
check(world.PocketDimensionContainers.custom_world_box==original,"cloning preserves the native singleton")
check(world.SetPocketDimensionContainer==setter,"the registration method is restored")
TheWorld,SpawnPrefab=before_world,before_spawn

local stopped=0
local proxy={opened=true,onclosefn=function()stopped=stopped+1 end}
function proxy:IsOpenedBy()return self.opened end
function proxy:Close()self.opened=false;if self.onclosefn then self.onclosefn()end end
local hat={prefab="tophat_container",components={container_proxy=proxy},IsValid=function()return true end}
local player={userid="native_player"}
v.views={[player.userid]={native=true,anchor=hat,page="1"}}
n:Close(player,true)
check(not proxy.opened and stopped==0 and proxy.onclosefn~=nil,"private handoff releases the opener while retaining the hat tool")
proxy.opened=true
v.views[player.userid]={native=true,anchor=hat,page="1"}
n:Close(player)
check(stopped==1,"a normal close still runs the original tool callback")
local oldents=Ents
local base,extra,unmanaged={},{},{}
Ents={base,extra,unmanaged}
local cleanup=assert(loadstring([[local count_skull=0
return function() for _,e in pairs(Ents)do count_skull=count_skull+1 end;return count_skull end
]],"@../mods/workshop-3193922031/postinit/prefabs/world.lua"))()
local task={fn=cleanup}
local cleanupworld={pendingtasks={[task]=true},components={shadowvault2hm={status="active",
    pages={localpage=base,otherpage=extra},rows={},native_bases={skull=base}}}}
Native.ProtectUniqueCleanup(cleanupworld)
check(cleanup()==2,"UM cleanup sees its canonical base and unmanaged duplicates, excluding intentional pages")
check(Ents[2]==extra,"the global entity registry is never changed")
Ents=oldents
local p={GetPerishRateMultiplier=function()return .5 end,GetTemperatureRateMultiplier=function()return .25 end}
local c={readonlycontainer=false}
local e={components={preserver=p,container=c}}
Config.ProtectPreserver(e)
check(p:GetPerishRateMultiplier()==.5 and p:GetTemperatureRateMultiplier()==.25,"native mod preservation remains unchanged during normal use")
c.readonlycontainer=true
check(p:GetPerishRateMultiplier()==0 and p:GetTemperatureRateMultiplier()==0,"page handoff freezes items even with an existing native preserver")
c.readonlycontainer=false
check(p:GetPerishRateMultiplier()==.5,"normal preservation resumes after handoff")
print("Native space behavior: "..checks.." checks passed")
