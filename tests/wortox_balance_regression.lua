GLOBAL=_G
local checks=0
local function check(ok,why)checks=checks+1;assert(ok,why)end
package.preload.umcompatguard2hm=function()return assert(loadstring(guard_source))()end
package.preload.umcompatprofiles2hm=function()return assert(loadstring(profiles_source))()end
local Guard=require('umcompatguard2hm')
local Patch=assert(loadstring(patch_source))()
local Timer=assert(loadstring(timer_source))()
TUNING={RESURRECT_HEALTH=50,TOTAL_DAY_TIME=480,MAXIMUM_HEALTH_PENALTY=.75}
EQUIPSLOTS={NECK='neck',BODY='body'}
TheWorld={ismastersim=true}
TheNet={GetPVPEnabled=function()return false end}
TheSim={FindEntities=function()return {}end}
local now,tasks=0,{}
GetTime=function()return now end
local function task(inst,delay,fn,...)
    local t={inst=inst,time=now+delay,fn=fn,args={...}}
    function t:Cancel()self.cancelled=true end
    tasks[#tasks+1]=t;return t
end
local function advance(dt)
    local target=now+dt
    while true do
        local nexttask
        for _,t in ipairs(tasks)do if not t.cancelled and t.time<=target and (not nexttask or t.time<nexttask.time)then nexttask=t end end
        if not nexttask then break end
        now=nexttask.time;nexttask.cancelled=true
        nexttask.fn(nexttask.inst,unpack(nexttask.args))
    end
    now=target
end
SpawnPrefab=function()
    return {entity={AddFollower=function()return {FollowSymbol=function()end}end},Setup=function()end,
        Transform={SetPosition=function()end}}
end
local function makeplayer()
    local p={prefab='wortox',components={},tags={player=true,souleater=true},inventory={},events={}}
    function p:HasTag(tag)return self.tags[tag]or false end
    function p:HasAllTags(...)for _,t in ipairs({...})do if not self:HasTag(t)then return false end end;return true end
    function p:DoTaskInTime(...)return task(self,...)end
    function p:PushEvent(name)
        self.events[name]=(self.events[name]or 0)+1
        if name=='PocketResurrection'and self.onrescue then self:onrescue()end
    end
    p.Transform={GetWorldPosition=function()return 0,0,0 end}
    p.components.combat={hiteffectsymbol='body'}
    p.components.inventory={
        GetEquippedItem=function(_,slot)return p[slot]end,
        FindItem=function(_,fn)for _,item in ipairs(p.inventory)do if not item.removed and fn(item)then return item end end end,
    }
    p.components.timer=Timer(p)
    local h={inst=p,currenthealth=100,minhealth=0,penalty=0}
    function h:SetVal(v)self.currenthealth=v end
    function h:SetCurrentHealth(v)self.currenthealth=v end
    function h:DeltaPenalty(v)self.penalty=self.penalty+v end
    function h:DoDelta()end
    function h:SetInvincible(v)self.invincible=v end
    p.components.health=h
    return p
end
local function heart(p,prefab)
    local item={prefab=prefab or 'wortox_reviver',components={}}
    function item:HasTag()return false end
    function item:DoTaskInTime(...)return task(self,...)end
    function item:Remove()self.removed=true end
    p.inventory[#p.inventory+1]=item;return item
end
local function setup(beta,overhaul,mastersim,source)
    now,tasks=0,{}
    UM_CONFIG={WORTOX=overhaul}
    local hooks,playerhook={}
    env={AddComponentPostInit=function(name,fn)hooks[name]=fn end,GetModConfigData=function()return false end}
    assert(loadstring(source or upstream_source,'@postinit/components/health.lua'))()
    TheWorld.ismastersim=mastersim~=false
    ModManager={GetMod=function(_,name)return beta and name=='workshop-3193922031'and {}or nil end}
    Patch.Install({GLOBAL=_G,AddPlayerPostInit=function(fn)playerhook=fn end})
    return function()
        local p=makeplayer();hooks.health(p.components.health)
        if playerhook then playerhook(p)end
        return p
    end,playerhook
end
for _,mode in ipairs({{true,true},{true,false},{false,true}})do
    local spawn,hook=setup(unpack(mode))
    check((hook~=nil)==(mode[1]and mode[2]),'only enabled beta installs the cooldown')
    local p=spawn();local h=p.components.health;local item=heart(p)
    h:SetVal(80)
    check(not p.components.timer:TimerExists(Patch.TIMER)and not item.removed,'nonlethal damage never starts cooldown')
    p.onrescue=function(self)self.timeratevent=self.components.timer:TimerExists(Patch.TIMER)end
    h:SetVal(-100)
    check(h.currenthealth==50,'first lethal hit uses actual UM rescue')
    check(p.components.timer:TimerExists(Patch.TIMER)==(mode[1]and mode[2]),'only enabled beta starts timer')
    advance(.3)
    check(item.removed,'rescue consumes the heart')
    if not(mode[1]and mode[2])then p.components.timer:StartTimer(Patch.TIMER,120)end
    local second=heart(p)
    h:SetVal(-100)
    local limited=mode[1]and mode[2]
    check((h.currenthealth==-100)==limited,'a different heart cannot bypass player cooldown')
    if not limited then check(h.currenthealth==50,'stored cooldown has no effect outside the active beta overhaul')end
    if limited then
        check(not second.removed and p.timeratevent,'blocked heart retained; timer already running at rescue event')
        check(math.abs(p.components.timer:GetTimeLeft(Patch.TIMER)-119.7)<.0001,'cooldown is 120 simulation seconds')
        local saved=p.components.timer:OnSave()
        local q=spawn();q.components.timer:OnLoad(saved);heart(q)
        q.components.health:SetVal(-100)
        check(q.components.health.currenthealth==-100,'save/load retains cooldown')
        local r=spawn();p.components.timer:TransferComponent(r);heart(r)
        r.components.health:SetVal(-100)
        check(r.components.health.currenthealth==-100,'player transfer retains cooldown')
        p.neck=heart(p,'amulet');h.currenthealth=100
        local remaining=p.components.timer:GetTimeLeft(Patch.TIMER)
        h:SetVal(-100)
        check(h.currenthealth==50,'amulet still works during heart cooldown')
        check(p.components.timer:GetTimeLeft(Patch.TIMER)==remaining,'amulet neither restarts nor removes heart cooldown')
        advance(119.69);p.neck=nil;h.currenthealth=100;h:SetVal(-100)
        check(h.currenthealth==-100,'heart is blocked just before expiry')
        advance(.02);h.currenthealth=100;h:SetVal(-100)
        check(h.currenthealth==50,'heart works again after expiry')
        check(p.components.timer:GetTimeLeft(Patch.TIMER)==120,'next successful rescue starts fresh cooldown')
    end
end
local _,hook=setup(true,true,false)
local client={}
hook(client)
check(client.components==nil,'client does not install health hooks')
local spawn=setup(true,true,true,upstream_source:gsub('local inventory = self.inst.components.inventory','local inventory = self.inst.components.inventory; local changed = true; if changed == false then return end',1))
local future=spawn();heart(future);future.components.health:SetVal(-100)
check(not future.components.timer:TimerExists(Patch.TIMER),'unreviewed upstream implementation is not patched')

for _,hard in ipairs({false,true})do
    TheWorld.ismastersim=true
    TUNING.hardmode2hm=hard;TUNING.SKILLS={WORTOX={}}
    local callbacks={}
    GetModConfigData=function(name)return name=='Wortox Auto Receive Soul'or name=='role_nerf'or name=='wortox'end
    AddPrefabPostInit=function(name,fn)callbacks[name]=fn end
    assert(loadstring(local_source))()
    local p=makeplayer();p.hp,p.san,p.food=1,1,1
    p.components.health.GetPercent=function()return p.hp end
    p.components.sanity={GetRealPercent=function()return p.san end,GetPercent=function()return 1 end}
    p.components.hunger={GetPercent=function()return p.food end}
    p.SoundEmitter={PlaySound=function()end};p.received=0;p.souls={}
    p.components.inventory.FindItems=function(_,fn)local r={}for _,i in ipairs(p.souls)do if fn(i)then r[#r+1]=i end end;return r end
    p.components.inventory.GiveItem=function()p.received=p.received+1 end
    p.DoPeriodicTask=function(_,period,fn)p.period=period;p.tick=fn end
    callbacks.wortox(p)
    check(p.period==(hard and 240 or 120),'original grant interval retained')
    local function tick(expected)
        local before=p.received;p.tick(p)
        check(p.received-before==expected,'passive soul threshold/cap/ghost rule')
    end
    tick(1)
    for _,stat in ipairs({'hp','san','food'})do p[stat]=.7499;tick(0);p[stat]=.75;tick(1);p[stat]=1 end
    p.hp,p.san,p.food=.75,.75,.75;tick(1)
    p.tags.playerghost=true;tick(0);p.tags.playerghost=nil
    local function soul(n)return {prefab='wortox_soul',IsValid=function()return true end,components={stackable={StackSize=function()return n end}}}end
    local jar={prefab='wortox_souljar',soulcount=5,IsValid=function()return true end}
    p.souls={soul(5),jar};tick(0)
    p.souls={soul(4),jar};tick(1)
    p.san=.1;tick(0) -- induced display values do not replace actual sanity.
    TheWorld.ismastersim=false
    callbacks.wortox({})
    check(true,'client never schedules the passive grant')
end
TheWorld.ismastersim=true
local disabled={}
GetModConfigData=function()return false end
AddPrefabPostInit=function(name,fn)disabled[name]=fn end
assert(loadstring(local_source))()
check(next(disabled)==nil,'disabled local auto-soul option installs no grant callback')
print('Wortox cooldown / healthy passive souls: '..checks..' checks passed')
