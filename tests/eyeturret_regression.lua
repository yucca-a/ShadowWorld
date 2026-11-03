local checks, guid, clock = 0, 0, 0
local function check(ok, why) checks = checks + 1; assert(ok, why) end
local function near(a,b,why) check(math.abs(a-b)<0.00001,why..': '..tostring(a)..' vs '..tostring(b)) end
GLOBAL=_G; TUNING={isCh2hm=true,ELECTRIC_DAMAGE_MULT=1.5,ELECTRIC_WET_DAMAGE_MULT=1,MAX_FIRE_DAMAGE_PER_SECOND=120}
TheWorld={ismastersim=true,PushEvent=function()end};TheNet={GetIsServer=function()return true end}
GetTime=function()return clock end
CanEntityBecomeCorpse=function()return false end;NotifyPlayerProgress=function()end;ProfileStatsAdd=function()end
local hooks,recipes,entities,tasks,componenthooks={},{},{},{},{}
AddPrefabPostInit=function(n,f)hooks[n]=hooks[n]or{};table.insert(hooks[n],f)end
AddComponentPostInit=function(n,f)componenthooks[n]=f end
AddRecipePostInit=function(n,f)recipes[n]=f end
Ingredient=function(n,a)return {type=n,amount=a}end
SetOnSave=function(i,f)i.OnSave=f end;SetOnLoad=function(i,f)i.OnLoad=f end
IsEntityElectricImmune=function(t)return t:HasTag('electricdamageimmune')end
IsRangedWeapon=function()return true end
StopTrackingDelayOwner=function()end
local function tick(seconds)
    local untiltime=clock+seconds
    while true do
        local first
        for _,t in ipairs(tasks)do
            if not t.cancelled and t.at<=untiltime and (first==nil or t.at<first.at)then first=t end
        end
        if not first then break end
        clock=first.at;first.cancelled=true
        if first.inst:IsValid()then
            first.fn(first.inst)
            if first.period and first.inst:IsValid()then first.at=clock+first.period;first.cancelled=false end
        end
    end
    clock=untiltime
end
local function entity(name,x)
    guid=guid+1
    local i={GUID=guid,prefab=name,components={},events={},tags={},x=x or 0,persists=true}
    i.entity={SetParent=function()end,AddTransform=function()end,AddAnimState=function()end,AddNetwork=function()end,
        SetPristine=function()end,IsVisible=function()return true end,IsValid=function()return i:IsValid()end}
    i.Transform={GetWorldPosition=function()return i.x,0,0 end,SetPosition=function()end,SetScale=function()end}
    i.AnimState={SetBank=function()end,SetBuild=function()end,PlayAnimation=function()end,SetBloomEffectHandle=function()end,SetFinalOffset=function()end}
    i.Physics={Stop=function()end}
    function i:IsValid()return not self.removed end
    function i:IsInLimbo()return self:HasTag('INLIMBO')end
    function i:AddTag(t)self.tags[t]=true end
    function i:HasTag(t)return self.tags[t]or false end
    function i:HasOneOfTags(tags)for _,t in ipairs(tags)do if self:HasTag(t)then return true end end;return false end
    function i:HasAnyTag(...)return self:HasOneOfTags({...})end
    function i:GetPhysicsRadius(d)return d end
    function i:GetDistanceSqToInst(o)return (self.x-o.x)^2 end
    function i:GetWetMultiplier()return self.wet or 0 end
    function i:ListenForEvent(n,f,source)
        source=source or self;source.events[n]=source.events[n]or{}
        table.insert(source.events[n],{inst=self,fn=f})
    end
    function i:PushEvent(n,d)for _,h in ipairs(self.events[n]or{})do if h.inst:IsValid()then h.fn(h.inst,d)end end end
    function i:Remove()if self.removed then return end;self:PushEvent('onremove');self.removed=true end
    function i:DoTaskInTime(dt,f)
        local t={at=clock+dt,fn=f,inst=self,Cancel=function(t)t.cancelled=true end};table.insert(tasks,t);return t
    end
    function i:DoPeriodicTask(p,f)local t=self:DoTaskInTime(p,f);t.period=p;return t end
    function i:StartUpdatingComponent()end
    function i:AddComponent(n)
        check(n=='trader','only trader component added')
        self.components[n]={inst=self,enabled=true,deleteitemonaccept=true,
            SetAcceptTest=function(t,f)t.test=f end,SetOnAccept=function(t,f)t.onaccept=f end,
            AbleToAccept=Trader.AbleToAccept,WantsToAccept=Trader.WantsToAccept,AcceptGift=Trader.AcceptGift}
    end
    entities[#entities+1]=i;return i
end
Combat={};Projectile={};Health={};Trader={}
for _,code in pairs(native)do assert(loadstring(code))()end
local function health(i,hp)
    local h={inst=i,currenthealth=hp,maxhealth=hp,minhealth=0,fire_timestart=0,firedamageinlastsecond=0,firedamagecaptimer=0}
    h.IsDead=function(s)return s.currenthealth<=0 end
    h.IsInvincible=function(s)return s.invincible end
    h.GetPercent=function(s)return s.currenthealth/s.maxhealth end
    h.GetMaxWithPenalty=function(s)return s.maxhealth end
    h.CanFadeOut=function()return false end
    h.SetVal=Health.SetVal
    h.SetMaxHealth=function(s,v)s.currenthealth=v;s.maxhealth=v end
    h.StartRegen=function(s,a,p)s.regen={amount=a,period=p}end
    h.GetFireDamageScale=function(s)return s.firemult or 1 end
    h.DoFireDamage=Health.DoFireDamage
    h.DoDelta=function(s,v,_,cause,ignore,attacker)
        if s.invincible and not ignore then return 0 end
        s:SetVal(s.currenthealth+v,cause,attacker);return v
    end
    i.components.health=h;return h
end
local function combat(i)
    local c={inst=i,ignorehitrange=false,defaultdamage=65}
    c.GetWeapon=function(s)return s.weapon end
    c.SetDefaultDamage=function(s,v)s.defaultdamage=v end
    c.IsAlly=function(_,t)return t.ally end
    c.CanTarget=function(_,t)return not t.untargetable end
    c.CanHitTarget=function(_,t)return t~=nil and t:IsValid()end
    c.ClearAttackTemps=function()end
    c.ShouldRecoil=function()return false end
    c.DoAttack=Combat.DoAttack
    c.CalcReflectedDamage=function()return 0 end
    c.CalcDamage=function(s,t,w,mult)return (w and w.components.weapon.damage or s.defaultdamage)*mult,nil end
    c.GetAttacked_Internal=function(s,a,d,w,stimuli)
        s.lastdamage=d;s.laststimuli=stimuli;s.lastattacker=a;s.hits=(s.hits or 0)+1
        if not s.blocked then s.inst.components.health:DoDelta(-d*(s.absorbmult or 1),false,'combat',nil,a)end
    end
    i.components.combat=c;return c
end
local fireprefab
Asset=function()return {}end
Prefab=function(n,f)return {name=n,fn=f}end
CreateEntity=function()return entity('eyeturret_safefire2hm')end
fireprefab=assert(loadstring(fire_source))()
SpawnPrefab=function(n)
    if n=='eyeturret_safefire2hm'then return fireprefab.fn()end
    local fx=entity(n);fx.AlignToTarget=function()end;return fx
end
TheSim={FindEntities=function(_,x,y,z,r,must,cant)
    local found={}
    for _,i in ipairs(entities)do
        if i:IsValid() and i.components.combat and math.abs(i.x-x)<=r and not i:HasOneOfTags(cant or{})then found[#found+1]=i end
    end
    return found
end}
assert(loadstring(turret_source))()
local function apply(n,i)for _,f in ipairs(hooks[n]or{})do f(i)end;return i end
local function tower(x)
    local i=entity('eyeturret',x);i:AddTag('eyeturret');health(i,1000);combat(i)
    i.components.lootdropper={AddChanceLoot=function(_,n,p)i.loot=n;i.lootchance=p end}
    apply('eyeturret',i)
    local w=entity('weapon');w.components.weapon={damage=65,SetDamage=function(s,d)s.damage=d end,
        SetElectric=function(s)s.stimuli='electric'end,CanRangedAttack=function()return true end,OnAttack=function()end}
    i.components.combat.weapon=w
    i:PushEvent('equip',{item=w});return i
end
local function victim(name,x,tags)
    local i=entity(name or 'hound',x);health(i,10000);combat(i)
    i.components.burnable={inst=i,Ignite=function(s)s.nativelit=true end}
    componenthooks.burnable(i.components.burnable)
    for _,tag in ipairs(tags or {'hostile'})do i:AddTag(tag)end;return i
end
local function hit(i,target)
    local p=entity('eye_charge');p.components.projectile={inst=p,owner=i.components.combat:GetWeapon(),
        Stop=function()end,SetOnPreHitFn=function(s,f)s.onprehit=f end,SetOnHitFn=function(s,f)s.onhit=f end,
        onhit=function(p)p:Remove()end}
    p.components.projectile.owner.components.inventoryitem={owner=i}
    apply('eye_charge',p);Projectile.Hit(p.components.projectile,target);return p
end

-- Configuration is a real modinfo evaluation, rather than a string assertion.
locale='zh';folder_name='ShadowWorldLocalTest';assert(loadstring(config_source))()
local config
for _,c in ipairs(configuration_options)do if c.name=='eyeturret'then config=c end end
check(config and config.default==true,'existing option enabled by default')
check(config.options[1].data==false,'option can be disabled')
for _,name in ipairs({'eyeturret_item','eyeturret','wathom_eyeturret_item'})do
    local r={ingredients={Ingredient('thulecite',5)}};recipes[name](r)
    check(#r.ingredients==2 and r.ingredients[2].type=='lightninggoathorn' and r.ingredients[2].amount==2,'recipe adds two goat horns')
    r={ingredients={Ingredient('lightninggoathorn',3)}};recipes[name](r)
    check(#r.ingredients==1 and r.ingredients[1].amount==5,'existing horn ingredient is increased')
end
local t=tower(0)
near(t.components.health.maxhealth,2000,'maximum health');near(t.components.health.currenthealth,2000,'placement health')
near(t.components.health.regen.amount,50,'regeneration');near(t.components.health.regen.period,1,'regen interval')
near(t.components.combat.defaultdamage,200,'panel base damage');near(t.components.combat.weapon.components.weapon.damage,200,'projectile weapon base')
check(t.components.combat.weapon.components.weapon.stimuli=='electric','weapon is electric as soon as equipped')
check(t.loot==nil,'native death loot is not changed')
local enemies={}
for n=1,6 do enemies[n]=victim('hound',10+(n-1)*5)end
local neutral=victim('pigman',10.2,{})
local friend=victim('spider',10.1);friend.components.follower={leader=entity('wilson')};friend.components.follower.leader:AddTag('player')
local building=victim('wall_wood',10.3,{'wall'})
local player=victim('wilson',10.4,{'player'})
local ally=victim('hound',10.5);ally.ally=true
enemies[2].wet=1;enemies[3]:AddTag('electricdamageimmune');enemies[4].components.combat.absorbmult=.5
hit(t,enemies[1])
for n=1,5 do
    local mult=n==2 and 2.5 or n==3 and 1 or 1.5
    near(enemies[n].components.combat.lastdamage,200*.8^(n-1)*mult,'native electric hit '..n)
    near(10000-enemies[n].components.health.currenthealth,200*.8^(n-1)*mult*(n==4 and .5 or 1),'individual defence '..n)
    check(enemies[n].components.combat.hits==1,'each target hit once '..n)
end
check(enemies[6].components.combat.hits==nil,'no fifth extra jump')
for _,i in ipairs({neutral,friend,building,player,ally})do check(i.components.health.currenthealth==10000,'safe chain exclusions '..i.prefab)end
check(t.components.combat.ignorehitrange==false,'temporary range override restored')
for _,i in ipairs(enemies)do i:Remove()end
for _,i in ipairs({neutral,friend,building,player,ally})do i:Remove()end

local function gift(name)
    local i=entity(name);i.components.inventoryitem={RemoveFromOwner=function()end};return i
end
local collectgive=assert(loadstring(give_action_source))()
ACTIONS={GIVE={}}
local actiongiver=entity('wilson');actiongiver.replica={}
t.replica={}
for _,name in ipairs({'dragon_scales','shroom_skin'})do
    local material=gift(name);material.replica={}
    local actions={};collectgive(material,actiongiver,t,actions,false)
    check(actions[1]==ACTIONS.GIVE,'native material action exposes GIVE for '..name)
end
check(t.components.trader.acceptnontradable==true,'server accepts these non-tradable materials')
local scales=gift('dragon_scales');check(t.components.trader:AcceptGift(nil,scales),'dragon scale accepted')
check(scales.removed and t.eyeturretfire2hm,'one scale consumed for upgrade')
local duplicate=gift('dragon_scales');check(not t.components.trader:AcceptGift(nil,duplicate)and not duplicate.removed,'duplicate scale is not consumed')
local skin=gift('shroom_skin');check(t.components.trader:AcceptGift(nil,skin)and skin.removed,'skin accepted and consumed')
check(t:HasTag('eyeturretsporeproof2hm'),'targeted immunity tag')
local skin2=gift('shroom_skin');check(not t.components.trader:AcceptGift(nil,skin2)and not skin2.removed,'duplicate skin rejected')
check(not t.components.trader:AcceptGift(nil,gift('rocks')),'unrelated gifts rejected')
local saved={};t:OnSave(saved);local restored=tower(100);restored:OnLoad(saved)
check(restored.eyeturretfire2hm and restored.eyeturretspore2hm and restored:HasTag('eyeturretsporeproof2hm'),'both upgrades restored')
local legacy=tower(200);legacy:OnLoad({hasplaced2hm=true});check(not legacy.eyeturretfire2hm and not legacy.eyeturretspore2hm,'legacy save loads without upgrades')
local incomplete=tower(300);check(not incomplete.components.trader:AcceptGift(nil,gift('dragon_scales'),20),'bulk gift does not waste a stack')

local cloudtags={'noauradamage'}
for _,name in ipairs({'sporecloud','sporecloud_toad'})do
    local cloud=entity(name);cloud.components.aura={auraexcludetags=cloudtags};apply(name,cloud)
    check(#cloud.components.aura.auraexcludetags==2 and cloud.components.aura.auraexcludetags[2]=='eyeturretsporeproof2hm','cloud excludes upgraded turret '..name)
end
check(#cloudtags==1,'shared native exclusion table not mutated')
check(not t:HasTag('noauradamage'),'other damage auras not disabled')

local burn=victim('beefalo',15)
local chest=victim('treasurechest',15,{'structure'})
hit(t,burn);local fire=burn.eyeturretsafefire2hm
check(fire and fire:IsValid(),'scale upgrade creates visible target-only flame')
check(not fire.components.propagator and not fire.components.heater and not fire:HasTag('fire'),'flame cannot spread heat')
local aftershot=burn.components.health.currenthealth;tick(1)
near(aftershot-burn.components.health.currenthealth,5,'native fire damage five per second')
near(chest.components.health.currenthealth,10000,'adjacent building takes no damage')
fire:Refresh(t);tick(7.6);check(fire:IsValid(),'refresh extends duration without another flame')
tick(.5);check(not fire:IsValid()and burn.eyeturretsafefire2hm==nil,'fire expires and releases target reference')
burn:Remove();chest:Remove()
local plant=victim('grassgekko',10)
plant.components.burnable:Ignite(nil,t.components.combat:GetWeapon(),t)
check(not plant.components.burnable.nativelit and plant.eyeturretsafefire2hm~=nil,'native electrocute ignition becomes isolated flame')
local pf=plant.eyeturretsafefire2hm;plant.components.burnable:Ignite(nil,t.components.combat:GetWeapon(),t)
check(plant.eyeturretsafefire2hm==pf,'delayed electrocute ignition only refreshes isolated flame')
plant:Remove()
local unupgraded=victim('grassgekko',10)
unupgraded.components.burnable:Ignite(nil,legacy.components.combat:GetWeapon(),legacy)
check(not unupgraded.components.burnable.nativelit and unupgraded.eyeturretsafefire2hm==nil,'electric attack without dragon scale does not ignite plants')
unupgraded.components.burnable:Ignite(nil,entity('firestaff'),entity('wilson'))
check(unupgraded.components.burnable.nativelit,'unrelated fire sources preserve native ignition');unupgraded:Remove()
local immune=victim('dragonfly',10,{'hostile','fireimmune'});hit(t,immune)
check(immune.eyeturretsafefire2hm==nil,'fire immunity respected');immune:Remove()
local killed=victim('hound',10);hit(t,killed);local f=killed.eyeturretsafefire2hm;killed.components.health:SetVal(0,'test')
check(not f:IsValid(),'dead target removes flame immediately');killed:Remove()

local shielded=victim('glacialhound',10)
local deaths=0;shielded:ListenForEvent('death',function()deaths=deaths+1 end)
shielded.components.health.redirect=function()error('shield redirect must be bypassed')end
shielded.components.health.invincible=true;shielded.components.combat.blocked=true
hit(t,shielded)
check(shielded.components.health:IsDead()and deaths==1,'shielded invincible glacial hound dies through native SetVal')
check(shielded.components.health.causeofdeath==t,'kill credited to turret')
hit(t,shielded);check(deaths==1,'repeated projectile cannot duplicate death loot');shielded:Remove()
local first=victim('hound',10);local second=victim('glacialhound',15)
second.components.health.invincible=true;hit(t,first)
check(second.components.health:IsDead(),'secondary chain hit also executes glacial hound');first:Remove();second:Remove()
local ordinary=victim('icehound',10);ordinary.components.health.invincible=true;hit(t,ordinary)
check(not ordinary.components.health:IsDead(),'ordinary ice hound does not inherit execution');ordinary:Remove()

local armor=tower(500)
armor.components.health.currenthealth=1200;armor:PushEvent('healthdelta',{oldpercent=1,newpercent=.6})
check(armor.allmiss2hm and armor.poor_66cdtask2hm,'upper shield retained')
tick(10.01);check(not armor.allmiss2hm,'shield expires after ten seconds')
armor.components.health.currenthealth=600;armor:PushEvent('healthdelta',{oldpercent=.6,newpercent=.3})
check(armor.allmiss2hm and armor.poor_33cdtask2hm,'lower shield has independent cooldown')
local old=armor.poor_33cdtask2hm;armor:PushEvent('healthdelta',{oldpercent=.3,newpercent=.2})
check(armor.poor_33cdtask2hm==old,'shield cooldown does not restart on every hit')
armor:PushEvent('healthdelta',{oldpercent=.3,newpercent=.5});check(armor.poor_33cdtask2hm==old,'regeneration cannot trigger armor')

TheWorld.ismastersim=false
local preview=entity('eyeturret');apply('eyeturret',preview)
check(preview:HasTag('trader')and not preview.eyeturretenhanced2hm,'client receives action tag without server components')
check(preview:HasTag('alltrader'),'client offers material GIVE action')
local pc=entity('eye_charge');apply('eye_charge',pc);check(pc.components.projectile==nil,'client projectile is safe')
print('EYETURRET_CHECKS_PASS '..checks)
