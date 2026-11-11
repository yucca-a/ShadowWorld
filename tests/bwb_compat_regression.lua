GLOBAL=_G
local checks,bugs=0,0
local function check(ok,why) checks=checks+1;assert(ok,why) end
local function near(a,b) return math.abs(a-b)<1e-8 end
math.clamp=function(v,lo,hi)return math.min(math.max(v,lo),hi)end
table.contains=function(t,v)for _,x in pairs(t)do if x==v then return true end end return false end
TUNING={MAXIMUM_HEALTH_PENALTY=.75,MAX_HEALING_NORMAL=-.25}
TheWorld={ismastersim=true}
FOODTYPE={MEAT="meat"}
RATE_SCALE={NEUTRAL=0,INCREASE_HIGH=3,INCREASE_MED=2,INCREASE_LOW=1,DECREASE_HIGH=-3,DECREASE_MED=-2,DECREASE_LOW=-1}
assert(loadstring(class_source))()
EntityScript={is_instance=function()return false end}
package.preload["util/sourcemodifierlist"]=function()return assert(loadstring(modifier_source))()end
local function anim()
    return {SetBank=function()end,SetBuild=function()end,PlayAnimation=function()end,AnimateWhilePaused=function()end,
        SetMultColour=function()end,SetPercent=function(self,_,v)self.percent=v end}
end
package.preload["widgets/uianim"]=function()return function()
    local a=anim();return {GetAnimState=function()return a end,SetScale=function()end,SetClickable=function()end}
end end
local Hunger=assert(loadstring(native_hunger))()
local tasks,components,players,widgets
local function flush()
    while #tasks>0 do local pending=tasks;tasks={};for _,fn in ipairs(pending)do fn()end end
end
function AddRecipePostInit()end
function AddPrefabPostInit()end
function AddComponentPostInit(name,fn)components[name]=components[name]or{};table.insert(components[name],fn)end
function AddPlayerPostInit(fn)table.insert(players,fn)end
function AddClassPostConstruct(name,fn)widgets[name]=widgets[name]or{};table.insert(widgets[name],fn)end
function ProfileStatsSet()end
local function net()
    local value=0;return {set=function(_,v)value=v end,value=function()return value end}
end
local function player()
    local inst={components={},replica={hunger={}},player_classified={hungerpenalty2hm=net(),hungerpenalty=net()},events={}}
    function inst:HasTag(tag)return tag=="player"end
    function inst:DoPeriodicTask()return {Cancel=function()end}end
    function inst:DoTaskInTime(_,fn)table.insert(tasks,function()fn(self)end)end
    function inst:ListenForEvent(event,fn)self.events[event]=self.events[event]or{};table.insert(self.events[event],fn)end
    function inst:PushEvent(event,data)for _,fn in ipairs(self.events[event]or{})do fn(self,data)end end
    inst.components.health={IsInvincible=function()return false end}
    inst.replica.hunger={SetMax=function()end,SetCurrent=function()end,SetRateScale=function()end}
    local h=Hunger(inst);inst.components.hunger=h;h:SetMax(150)
    for _,fn in ipairs(components.hunger)do fn(h)end
    for _,fn in ipairs(players)do fn(inst)end
    flush();return inst,h
end
local function setup(order)
    tasks,components,players,widgets={},{},{},{}
    env={AddComponentPostInit=AddComponentPostInit}
    package.loaded["components/hunger_replica"]={IsStarving=function()return false end}
    if order=="bwb-first"then assert(loadstring(bwb_hunger))()end
    assert(loadstring(sw_hunger))()
    if order~="bwb-first"then assert(loadstring(bwb_hunger))()end
end
for _,order in ipairs({"sw-first","bwb-first"})do
    setup(order)
    local inst,h=player()
    inst:PushEvent("death",{cause="audit"})
    if expect_bug then
        local old=h.penalty2hm;h:ReduceUnifiedPenalty(-.05)
        if near(h.penalty2hm,old)then bugs=bugs+1 end
    else
        check(near(h.penalty2hm,.15),order..": own death penalty")
        check(near(h.penalty,0),order..": BWB store unchanged by death")
        h:ReduceUnifiedPenalty(-.05)
        check(near(h.penalty2hm,.1),order..": unified recovery reaches SW once")
        h:SetPenalty(.2);h:ReduceUnifiedPenalty(-.05)
        check(near(h.penalty,.15)and near(h.penalty2hm,.05),order..": both stores recover once")
        TUNING.ISHAPPYPATCH_ENABLED=true
        h:ReduceUnifiedPenalty(-.01)
        check(near(h.penalty,.14)and near(h.penalty2hm,.04),order..": upstream compatibility flag does not double heal")
        TUNING.ISHAPPYPATCH_ENABLED=nil
        h:SetPenalty2hm(.3);h:SetCurrent(999)
        check(near(h.current,105),order..": direct current respects both caps")
        check(near(h:GetPenalizedMax(),105),order..": BWB effective max sees SW cap")
        local saved=h:OnSave();h:SetPenalty2hm(.6);h:OnLoad(saved)
        check(near(h.penalty2hm,.3)and near(h.current,105),order..": saved penalty restored after native hunger load")
        check(near(inst.player_classified.hungerpenalty2hm:value()/200,.3),order..": classified sync")
        h.disable_penalty=true;h:ReduceUnifiedPenalty(-.1)
        check(near(h.penalty2hm,.3),order..": penalty disable honored")
        h.disable_penalty=nil
        local originalclamp=math.clamp
        h:DoDelta(-1)
        check(math.clamp==originalclamp,order..": no global math patch")
        local _,migrated=player()
        h:TransferComponent(migrated.inst)
        check(near(migrated.penalty2hm,h.penalty2hm),order..": component transfer preserves penalty")
        check(near(migrated.inst.player_classified.hungerpenalty2hm:value()/200,.3),order..": transfer synchronizes client cap")
    end
end
local function text()
    return {str="",SetString=function(self,s)self.str=s end,GetString=function(self)return self.str end}
end
for _,order in ipairs({"sw-first","bwb-first"})do for _,combined in ipairs({false,true})do
    setup("sw-first")
    local swwidgets=widgets;widgets={}
    assert(loadstring(bwb_badge))()
    local bwbwidgets=widgets
    local owner={components={hunger={penalty2hm=.2,penalty=.1}},player_classified={hungerpenalty2hm=net(),hungerpenalty=net()}}
    local badge={owner=owner,num=text(),underNumber={AddChild=function(_,v)return v end}}
    if combined then
        badge.active=true;badge.maxnum=text()
        badge.CombinedStatusUpdateNumbers=function(self,max)self.maxnum:SetString(tostring(max))end
    end
    badge.SetPercent=function(self,pct,max)
        self.num:SetString(tostring(math.ceil(pct*max)))
        if self.CombinedStatusUpdateNumbers then self:CombinedStatusUpdateNumbers(max)end
    end
    local sw=swwidgets["widgets/hungerbadge"][1];local bw=bwbwidgets["widgets/hungerbadge"][1]
    if order=="sw-first"then sw(badge);bw(badge)else bw(badge);sw(badge)end
    local display={owner=owner,stomach=badge,SetHungerPercent=function(self,pct)self.stomach:SetPercent(pct,150)end}
    local swstatus=swwidgets["widgets/statusdisplays"][1]
    local bwstatus=assert(loadstring(bwb_status))()
    if order=="sw-first"then swstatus(display);bwstatus(display)else bwstatus(display);swstatus(display)end
    display:SetHungerPercent(.5)
    if expect_bug then
        if not badge.SetPercent2hm then bugs=bugs+1 end
    else
        check(badge.SetPercent2hm~=nil,order..": SW overlay installed with existing BWB overlay")
        check(near(badge.topperanim2hm:GetAnimState().percent,.8),order..": visible combined cap")
        check(badge.num.str==(combined and "75"or"75/120"),order..": one accurate numeric cap, no duplicate suffix")
        if combined then check(badge.maxnum.str=="Max:\n120",order..": Combined Status effective max")end
        owner.components.hunger.penalty2hm=0;owner.components.hunger.penalty=0
        display:SetHungerPercent(.5)
        check(near(badge.topperanim2hm:GetAnimState().percent,1),order..": recovered overlay cleared")
        check(badge.num.str=="75",order..": recovered number cleared")
        owner.components.hunger=nil
        owner.player_classified.hungerpenalty2hm:set(40);owner.player_classified.hungerpenalty:set(20)
        display:SetHungerPercent(.5)
        check(near(badge.penalty2hm,.2),order..": remote client uses classified values")
    end
end end
if not expect_bug then
    SEASONS={AUTUMN="autumn"}
    AllPlayers={}
    local function seasoncase(mode,bwb,phase,base,peer,single)
        local removed,sent,hook,handler,moon=0,0,nil,nil,{}
        TheWorld={ismastersim=true,ismastershard=true,state={season=phase},components={archivemanager={}}}
        local seasons={current_clock=bwb and "cave" or "default",clocks=bwb and {cave=true}or{}}
        function seasons:OnSave()return {season=base}end
        TheWorld.components.seasons=seasons
        function TheWorld:PushEvent(event,value)
            if event=="ms_setseason"then
                if value=="autumn"then base="autumn";if not bwb then self.state.season=value end
                elseif value=="tranquil"and bwb then self.state.season=value end
            elseif event:find("ms_setmoonphase",1,true)then moon[event]=value.moonphase end
        end
        GetModConfigData=function()return mode end
        AddShardModRPCHandler=function(_,_,fn)handler=fn end
        AddPrefabPostInit=function(name,fn)if name=="archive_switch"then hook=fn end end
        GetShardModRPC=function()return {}end
        SendModRPCToShard=function()sent=sent+1 end
        TheShard={GetShardId=function()return "1"end}
        ShardList={['2']={}}
        Shard_IsWorldAvailable=function()return peer end
        TUNING.DSA_ONE_PLAYER_MODE=single
        local sockets={}
        for i=1,3 do
            local inst={components={trader={onaccept=function(self)self.gem=true end},pickable={onpickedfn=function(self)self.gem=nil;removed=removed+1 end}},Transform={GetWorldPosition=function()return 0,0,0 end}}
            function inst:DoTaskInTime(_,fn)fn()end
            sockets[i]=inst
        end
        TheSim={FindEntities=function()local t={};for i,v in ipairs(sockets)do t[i]=v end;return t end}
        assert(loadstring(sw_autumn))()
        for _,inst in ipairs(sockets)do hook(inst);inst.components.trader.onaccept(inst)end
        return {removed=removed,sent=sent,base=base,phase=TheWorld.state.season,moon=moon,handler=handler}
    end
    for _,bwb in ipairs({false,true})do for _,mode in ipairs({-1,-2,-3})do
        local r=seasoncase(mode,bwb,bwb and "frost"or"winter","winter",true,false)
        check(r.removed==({[-1]=0,[-2]=1,[-3]=3})[mode],"unchanged gem cost mode "..mode)
        check(r.base=="autumn"and r.phase==(bwb and "tranquil"or"autumn"),"both season clocks updated")
        check(r.sent==1,"one shard broadcast per activation")
        check((r.moon.ms_setmoonphase=="full")== (mode==-3),"full moon only in three-gem mode")
        if bwb and mode==-3 then check(r.moon.ms_setmoonphase_cave=="full","BWB moon clock updated")end
    end end
    local stable=seasoncase(-3,true,"tranquil","autumn",true,false)
    check(stable.removed==0 and stable.sent==0,"corresponding autumn does not consume another set of gems")
    local mismatched=seasoncase(-3,true,"tranquil","summer",true,false)
    check(mismatched.base=="autumn"and mismatched.sent==1,"old mismatched surface clock repaired")
    local offline=seasoncase(-3,true,"frost","winter",false,false)
    check(offline.removed==0 and offline.sent==0,"no peer: no gem loss")
    local solo=seasoncase(-3,true,"frost","winter",true,true)
    check(solo.removed==0 and solo.sent==0,"standalone cave mode unchanged")
end
if expect_bug then check(bugs>=2,"old source must reproduce recovery/UI defects");print("BWB before-fix contrast:",bugs,"defects reproduced")
else print("BWB hunger/UI regressions:",checks,"checks passed")end
