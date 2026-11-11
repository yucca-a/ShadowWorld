local n=0
local function check(ok,msg)n=n+1;assert(ok,msg)end
local function run(src,env)
    return setfenv(assert(loadstring(src)),setmetatable(env or {},{__index=_G}))()
end
local H=run(helper_source)
local leaf=4
local function inner()return leaf end
local function root()return inner()end
check(H.GetUpvalue(root,"inner","leaf")==4,"nested lookup")
check(H.GetUpvalue(root,"absent","leaf")==nil,"missing intermediate does not assert")
check(H.GetUpvalue(nil,"x")==nil,"nonfunction lookup")
check(H.SetUpvalue(root,7,"inner","leaf") and root()==7,"nested replacement")
check(not H.SetUpvalue(root,99,"missing") and root()==7,"missing write changes nothing")
local empty
local function nilslot()return empty end
check(H.SetUpvalue(nilslot,12,"empty") and nilslot()==12,"valid nil upvalue can be changed")
local flag=false
local function flagslot()return flag end
check(H.GetUpvalue(flagslot,"flag")==false,"false value preserved")

Ents={}
local guid=0
local function entity(prefab)
    guid=guid+1
    local inst={GUID=guid,prefab=prefab,components={},valid=true}
    function inst:IsValid()return self.valid end
    function inst:HasTag()return false end
    function inst:Remove()self.valid=false;Ents[self.GUID]=nil end
    Ents[guid]=inst
    return inst
end
RunInSandboxSafe=function(s)
    local f=loadstring(s)
    if not f then return false end
    return pcall(setfenv(f,{}))
end
local G=run(guard_source)
for _,v in ipairs({false,true,1,"cutstone",{}, {prefab="dragonflyfurnace"}})do
    check(not G.IsEntity(v),"bad entity rejected")
    check(not G.CanUseFurnace(v,v),"bad furnace RPC rejected")
end
check(not G.IsEntity(nil),"nil entity")
local player=entity("wilson")
player.sg={HasStateTag=function()return false end}
player.components.inventory={isvisible=true}
player.components.playercontroller={IsEnabled=function()return true end}
local furnace=entity("dragonflyfurnace")
furnace.IsNear=function()return true end
local opened=true
local container={IsOpenedBy=function()return opened end,IsEmpty=function()return false end,slots={}}
function container:GiveItem(item,slot)self.slots[slot]=item end
furnace.components.container=container
furnace.components.stewer={IsCooking=function()return false end}
furnace.AnimState={PlayAnimation=function()end}
furnace.SoundEmitter={PlaySound=function()end}
check(G.CanUseFurnace(player,furnace),"valid open furnace accepted")
opened=false;check(not G.CanUseFurnace(player,furnace),"closed furnace rejected");opened=true
check(G.IsFinite(0) and not G.IsFinite(0/0) and not G.IsFinite(math.huge),"finite coordinates")
check(G.DecodeTable('return {a=1}').a==1,"valid shard table")
for _,s in ipairs({'return 7','return true','return nil','!!!',false,{}})do
    check(G.DecodeTable(s)==nil,"invalid shard payload")
end

local filter
local search=run(search_source,{RPCGuard=G,collectrecipefn=function(_,_,_,_,_,fn)filter=fn end})
search(player,"[",true)
check(filter({name="a[b",prefab="box"}),"literal bracket search")
search(player,"%",true)
check(filter({name="50%",prefab="box"}),"literal percent search")
check(not filter({name={},prefab=false}),"unnamed mod item search")
search(player,{},true);search(nil,"x",true)
check(true,"wrong search payload ignored")

local cook=run(cook_source,{RPCGuard=G,SpawnPrefab=function(prefab)
    local out=entity(prefab);out.components.stackable={};return out
end})
for _,v in ipairs({"cutstone",{},false,1})do cook(player,v)end
cook(player,nil)
local food=entity("mod_food")
food.components.cookable={Cook=function()return nil end}
container.slots[2]=food
cook(player,furnace)
check(food:IsValid() and container.slots[2]==food,"failed mod cook preserves ingredient")
local boards=entity("boards");boards.components.stackable={stacksize=5};container.slots[2]=boards
cook(player,furnace)
check(not boards:IsValid() and container.slots[2].prefab=="charcoal" and container.slots[2].components.stackable.stacksize==5,"existing charcoal conversion preserved")

local action
run(dodge_source,{GetModConfigData=function()return true end,TUNING={hardmode2hm=true},
    AddAction=function(_,_,fn)action=fn end})
local function dodger()
    local p=entity("wilson")
    p.components.rider={IsRiding=function()return true end}
    p.sg={GoToState=function()end};p.listeners={}
    function p:DoTaskInTime(_,fn)
        local task={fn=fn};function task:Cancel()self.cancelled=true end;return task
    end
    function p:ListenForEvent(event,fn)self.listeners[event]=self.listeners[event] or {};table.insert(self.listeners[event],fn)end
    function p:PushEvent(event)for _,fn in ipairs(self.listeners[event] or {})do fn(self)end end
    return p
end
local a,b=dodger(),dodger()
action({doer=a,pos={}});local first=a.dodgetiredtask2hm
action({doer=b,pos={}})
check(not first.cancelled,"players do not cancel each other's fatigue timers")
action({doer=a,pos={}})
check(first.cancelled and #a.listeners.death==1 and #a.listeners.bucked==1,"repeat dodge replaces timer without duplicate listeners")
a.dodgetiredtask2hm.fn(a)
check(a.pettiredPG==0 and a.dodgetiredtask2hm==nil and b.pettiredPG==1,"per-player timeout, missing grogginess safe")
b:PushEvent("bucked")
check(b.pettiredPG==0 and b.dodgetiredtask2hm==nil,"bucked cleanup")

local self={_moonstorm_nodes={set=function()end}}
local active,markers={},{}
local env={self=self,_active_moonstorm_nodes=active,_mapmarkers=markers,
    TheWorld={topology={nodes={[1]={cent={10,20}}}},PushEvent=function()end},
    STORM_TYPES={MOONSTORM=1},convertlist=function(t)return t end,
    SpawnPrefab=function()return {Transform={SetPosition=function()end}}end}
run(moon_source,env)
self:AddMoonstormNodes(1);self:AddMoonstormNodes(1);self:AddMoonstormNodes(nil);self:AddMoonstormNodes({99})
check(active[1] and #markers==1,"scalar node accepted; missing/duplicate nodes safe")

local calls={}
local shared={onsleep=function()end,onwake=function()end}
local function shark(id)
    local s={OnEntitySleep=function()calls[#calls+1]="sleep"..id end,OnEntityWake=function()calls[#calls+1]="wake"..id end}
    shared.inst=s;run(shark_source,shared);return s
end
local s1,s2=shark(1),shark(2)
s1:OnEntitySleep();s2:OnEntitySleep();s1:OnEntityWake();s2:OnEntityWake()
check(table.concat(calls,",")=="sleep1,sleep2,wake1,wake2","each boss retains its own callbacks")
local icecalls=0
local ice=run(ice_source,{TheWorld={components={oceanicemanager={QueueDestroyForIceAtPoint=function()icecalls=icecalls+1 end}}}})
local attacker=entity("wilson")
attacker.HasTag=function()return true end
function attacker:GetPosition()assert(self:IsValid());return {x=0,z=0}end
local boss={DoTaskInTime=function(self,_,fn,arg)self.callback=function()fn(self,arg)end;return {}end}
ice(boss,{attacker=attacker});attacker:Remove();boss.callback()
check(icecalls==0 and boss.shouldremoveice2hm==nil,"removed attacker safely releases delayed ice task")
print("Crash audit regression passed: "..n.." checks")
