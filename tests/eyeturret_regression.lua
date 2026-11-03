local checks, guid, clock = 0, 0, 0
local function check(ok, why) checks = checks + 1; assert(ok, why) end
local function near(a,b,why) check(math.abs(a-b)<0.00001,why..': '..tostring(a)..' vs '..tostring(b)) end
GLOBAL=_G; TUNING={TOTAL_DAY_TIME=480,isCh2hm=true,ELECTRIC_DAMAGE_MULT=1.5,ELECTRIC_WET_DAMAGE_MULT=1,MAX_FIRE_DAMAGE_PER_SECOND=120}
FRAMES=1/30
TheWorld={ismastersim=true,PushEvent=function()end};TheNet={GetIsServer=function()return true end}
GetTime=function()return clock end
CanEntityBecomeCorpse=function()return false end;NotifyPlayerProgress=function()end;ProfileStatsAdd=function()end
local hooks,recipes,entities,tasks,componenthooks,componentactions={},{},{},{},{},{}
AddPrefabPostInit=function(n,f)hooks[n]=hooks[n]or{};table.insert(hooks[n],f)end
AddComponentPostInit=function(n,f)componenthooks[n]=f end
AddComponentAction=function(t,n,f)
    local key=t..':'..n;check(not componentactions[key],'shared action registered only once: '..key);componentactions[key]=f
end
ACTIONS={};Action=function(t)return t end;AddAction=function(a)ACTIONS[a.id]=a end
assert(loadstring(common_actions_source))()
AddRecipePostInit=function(n,f)recipes[n]=f end
Ingredient=function(n,a)return {type=n,amount=a}end
local function wrap(i,key,f)local old=i[key];i[key]=function(...)if old then old(...)end;return f(...)end end
SetOnSave=function(i,f)wrap(i,'OnSave',f)end;SetOnLoad=function(i,f)wrap(i,'OnLoad',f)end
SetOnPreLoad=function(i,f)wrap(i,'OnPreLoad',f)end
State=function(t)return t end;EventHandler=function(n,f)return {name=n,fn=f}end
local graph={states={death={onenter=function(i)i.deathloot=true;i.physicsremoved=true end}}}
AddStategraphState=function(n,s)check(n=='eyeturret','only turret stategraph extended');graph.states[s.name]=s end
AddStategraphPostInit=function(n,f)check(n=='eyeturret','only turret death state wrapped');f(graph)end
Class=function(ctor)local c={};c.__index=c;return setmetatable(c,{__call=function(_,...)local s=setmetatable({},c);ctor(s,...);return s end})end
local Timer=assert(loadstring(timer_source))()
local Repairable=assert(loadstring(repair_source))()
FunctionOrValue=function(v,...)if type(v)=='function'then return v(...)else return v end end
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
    i.colour={1,1,1,1}
    i.AnimState={SetBank=function()end,SetBuild=function()end,PlayAnimation=function()end,SetBloomEffectHandle=function()end,SetFinalOffset=function()end,
        GetMultColour=function()return unpack(i.colour)end,SetMultColour=function(_,...)i.colour={...}end}
    i.Physics={Stop=function()end}
    function i:IsValid()return not self.removed end
    function i:IsInLimbo()return self:HasTag('INLIMBO')end
    function i:AddTag(t)self.tags[t]=true end
    function i:RemoveTag(t)self.tags[t]=nil end
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
    function i:PushEvent(n,d)for _,h in ipairs(self.events[n]or{})do if h.inst:IsValid()then h.fn(self,d)end end end
    function i:Remove()if self.removed then return end;self:PushEvent('onremove');self.removed=true end
    function i:DoTaskInTime(dt,f,...)
        local args={...}
        local t={at=clock+dt,fn=function(inst)return f(inst,unpack(args))end,inst=self,Cancel=function(t)t.cancelled=true end};table.insert(tasks,t);return t
    end
    function i:DoPeriodicTask(p,f)local t=self:DoTaskInTime(p,f);t.period=p;return t end
    function i:StartUpdatingComponent()end
    function i:StopBrain(reason)self.brainstopped=reason end
    function i:RestartBrain(reason)if self.brainstopped==reason then self.brainstopped=nil end end
    function i:AddComponent(n)
        if n=='timer'then self.components.timer=Timer(self);return end
        check(n=='repairable2hm','reuse upstream repair component')
        self.components[n]=Repairable(self)
    end
    entities[#entities+1]=i;return i
end
Combat={};Projectile={};Health={};SpellCaster={}
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
    h.StopRegen=function(s)s.regen=nil end
    h.SetPercent=function(s,p)s:SetVal(p*s.maxhealth)end
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
    c.DropTarget=function(s)s.target=nil end
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
    local i=entity('eyeturret',x);i:AddTag('eyeturret');i:AddTag('companion');health(i,1000);combat(i)
    i.components.lootdropper={AddChanceLoot=function(_,n,p)i.loot=n;i.lootchance=p end,
        SpawnLootPrefab=function(_,n)i.refunds=i.refunds or {};i.refunds[n]=(i.refunds[n]or 0)+1;return entity(n)end}
    i.components.inventory={DisableDropOnDeath=function(s)s.dropondeath=false end}
    i.components.inspectable={}
    i.base={}
    i.Light={Enable=function(_,v)i.lightenabled=v end,SetRadius=function(_,v)i.lightradius=v end}
    i._lightframe={set=function(_,v)i.lightframe=v end}
    i.syncanim=function(s,n)s.animation=n end
    i.sg={GoToState=function(s,n)s.currentstate={name=n};if graph.states[n]then graph.states[n].onenter(i)end end,
        HasStateTag=function(s,t)return s.currentstate and s.currentstate.name=='eyeturret_recover2hm'and t=='busy'end}
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
check(t.loot==nil,'native loot table is not replaced')
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
local collectrepair=componentactions['USEITEM:inventoryitem']
local actiongiver=entity('wilson');actiongiver.replica={}
t.replica={}
for _,name in ipairs({'dragon_scales','shroom_skin'})do
    local material=gift(name);material.replica={}
    local actions={};collectrepair(material,actiongiver,t,actions,false)
    check(actions[1]==ACTIONS.REPAIR2HM,'shared material action exposes REPAIR2HM for '..name)
end
check(t.components.trader==nil and t.components.repairable2hm,'no separate trader path needed')
local scales=gift('dragon_scales');check(t.components.repairable2hm:Repair(nil,scales),'dragon scale accepted')
check(scales.removed and t.eyeturretfire2hm,'one scale consumed for upgrade')
local duplicate=gift('dragon_scales');check(not t.components.repairable2hm:Repair(nil,duplicate)and not duplicate.removed,'duplicate scale is not consumed')
local skin=gift('shroom_skin');check(t.components.repairable2hm:Repair(nil,skin)and skin.removed,'skin accepted and consumed')
check(t:HasTag('eyeturretsporeproof2hm'),'targeted immunity tag')
local skin2=gift('shroom_skin');check(not t.components.repairable2hm:Repair(nil,skin2)and not skin2.removed,'duplicate skin rejected')
check(not t.components.repairable2hm:Repair(nil,gift('rocks')),'unrelated gifts rejected')
local saved={};t:OnSave(saved);local restored=tower(100);restored:OnLoad(saved)
check(restored.eyeturretfire2hm and restored.eyeturretspore2hm and restored:HasTag('eyeturretsporeproof2hm'),'both upgrades restored')
local legacy=tower(200);legacy:OnLoad({hasplaced2hm=true});check(not legacy.eyeturretfire2hm and not legacy.eyeturretspore2hm,'legacy save loads without upgrades')
local incomplete=tower(300);local stack=gift('dragon_scales');local remaining=20
stack.components.stackable={Get=function(_,n)check(n==1,'upgrade requests exactly one material');remaining=remaining-n;return gift('dragon_scales')end}
check(incomplete.components.repairable2hm:Repair(nil,stack) and remaining==19 and stack:IsValid(),'stack upgrade consumes one and retains remainder')

local function portable(ondeploy)
    local i=entity('eyeturret_item')
    i.components.inventoryitem={owner=actiongiver}
    i.components.deployable={ondeploy=ondeploy or function(item,pt,deployer)
        local placed=tower(pt.x);item:Remove();return placed,nil,'native-return'
    end}
    return apply('eyeturret_item',i)
end
local existing=entity('eyeturret_item')
existing.repairmaterials2hm={rocks=1}
existing.components.deployable={ondeploy=function()end}
existing:AddComponent('repairable2hm')
existing.components.repairable2hm.customrepair=function()return false end
apply('eyeturret_item',existing)
local denied=gift('rocks')
check(existing.repairmaterials2hm.rocks==1,'existing material registry is retained')
check(existing.components.repairable2hm:Repair(nil,denied)==false and denied:IsValid(),'existing repair rejection is not converted to success')
check(existing.components.repairable2hm:Repair(nil,gift('dragon_scales')),'new upgrade coexists with existing repair callback')
local item=portable();item.replica={}
check(item.components.health==nil and item.components.repairable2hm~=nil,'portable item gets upgrades without combat components')
for _,name in ipairs({'dragon_scales','shroom_skin'})do
    local material=gift(name);material.replica={}
    local actions={};collectrepair(material,actiongiver,item,actions,true)
    check(actions[1]==ACTIONS.REPAIR2HM,'inventory tile right-click offers REPAIR2HM for '..name)
    check(#actions==1,'shared inventory upgrade action is not duplicated')
    check(item.components.repairable2hm:Repair(actiongiver,material)and material.removed,'inventory item accepts and consumes '..name)
    local extra=gift(name);check(not item.components.repairable2hm:Repair(actiongiver,extra)and not extra.removed,'portable duplicate rejected '..name)
end
local stored={};item:OnSave(stored);item:Remove()
item=portable();item:OnLoad(stored)
check(item.eyeturretfire2hm and item.eyeturretspore2hm,'portable upgrades survive save/load')
local placed,middle,tail=item.components.deployable.ondeploy(item,{x=700},actiongiver)
check(item.removed and placed.eyeturretfire2hm and placed.eyeturretspore2hm,'native deployment inherits both item upgrades')
check(middle==nil and tail=='native-return','deployment wrapper preserves all native return values')
local fresh=tower(800);check(not fresh.eyeturretfire2hm and not fresh.eyeturretspore2hm,'later unrelated turrets inherit no deployment flags')
local partial=portable();partial.components.repairable2hm:Repair(nil,gift('dragon_scales'))
local converted=partial.components.deployable.ondeploy(partial,{x=900},actiongiver)
check(converted.eyeturretfire2hm and not converted.eyeturretspore2hm,'single material upgrade transfers independently')
check(converted.components.repairable2hm:Repair(nil,gift('shroom_skin'))and converted.eyeturretspore2hm,'remaining upgrade can be given after placing')
local failed=portable(function()error('injected deployment failure')end)
failed.components.repairable2hm:Repair(nil,gift('dragon_scales'))
check(not pcall(failed.components.deployable.ondeploy,failed,{x=1000},actiongiver),'deployment failure remains visible')
check(failed:IsValid()and failed.eyeturretfire2hm,'failed deployment keeps upgraded item')
local afterfailed=tower(1100);check(not afterfailed.eyeturretfire2hm,'failed deployment cannot leak upgrade context')
local wrong={};collectrepair(gift('rocks'),actiongiver,item,wrong,true)
check(#wrong==0,'new inventory action excludes other materials')
wrong={};collectrepair(gift('dragon_scales'),actiongiver,t,wrong,true)
check(#wrong==0,'upgraded turret no longer offers the same upgrade')

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
local extinguished=victim('hound',10);hit(t,extinguished);local ef=extinguished.eyeturretsafefire2hm
extinguished:PushEvent('onextinguish')
check(extinguished:IsValid()and not ef:IsValid()and not extinguished.eyeturretsafefire2hm,'extinguishing removes only the flame, not its event source')
hit(t,extinguished);ef=extinguished.eyeturretsafefire2hm;extinguished:Remove()
check(not ef:IsValid(),'removing a burning target clears flame without recursive target removal')

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

-- NewConstant enemies share eye_charge but are not player turrets. Exercise
-- strict eligibility even when a foreign hook routes them through our callback
-- or a stale/copying mod leaves enhancement flags on an enemy.
local function enemy_tower(name,tags)
    local i=entity(name,2000);health(i,1500);combat(i)
    i.components.combat.defaultdamage=75
    i.components.health.regen={amount=12,period=1}
    for _,tag in ipairs(tags)do i:AddTag(tag)end
    local save=function()end;local load=function()end;i.OnSave=save;i.OnLoad=load
    apply('eyeturret',i)
    local w=entity('enemyweapon');w.components.weapon={damage=75,SetDamage=function(s,d)s.damage=d end,
        SetElectric=function(s)s.stimuli='electric'end,CanRangedAttack=function()return true end,OnAttack=function()end}
    i.components.combat.weapon=w;i:PushEvent('equip',{item=w});tick(0)
    near(i.components.health.maxhealth,1500,'enemy health untouched '..name)
    near(i.components.health.regen.amount,12,'enemy regeneration untouched '..name)
    near(i.components.combat.defaultdamage,75,'enemy combat damage untouched '..name)
    check(not i.eyeturretenhanced2hm and not i.components.repairable2hm and not i:HasTag('repairable2hm'),'enemy gets no enhancement or upgrade action '..name)
    check(w.components.weapon.damage==75 and w.components.weapon.stimuli==nil,'enemy weapon retains its own damage/type')
    check(i.OnSave==save and i.OnLoad==load,'enemy save/load callbacks remain untouched')
    i:PushEvent('healthdelta',{oldpercent=1,newpercent=.3})
    check(not i.allmiss2hm and not i.poor_33cdtask2hm,'enemy never gets our shield')
    return i
end
for _,spec in ipairs({
    {'shadoweyeturret',{'hostile','shadoweyeturret','shadow_aligned'}},
    {'shadoweyeturret2',{'hostile','shadoweyeturret','shadow_aligned'}},
    {'eyeturret',{'companion','hostile'}},
    {'eyeturret',{'companion','shadoweyeturret'}},
    {'eyeturret',{}},
    {'shadoweyeturret',{'companion'}},
})do
    local enemy=enemy_tower(spec[1],spec[2])
    -- A legacy marker alone must never turn a hostile projectile electric.
    enemy.eyeturretenhanced2hm=true;enemy.eyeturretfire2hm=true
    local victim1=victim('hound',2010);local victim2=victim('hound',2015)
    hit(enemy,victim1)
    near(10000-victim1.components.health.currenthealth,75,'enemy projectile has original physical damage')
    near(victim2.components.health.currenthealth,10000,'enemy projectile cannot chain')
    check(victim1.eyeturretsafefire2hm==nil,'enemy cannot acquire our isolated flame')
    victim1.components.burnable:Ignite(true,enemy,enemy)
    check(victim1.components.burnable.nativelit,'enemy native gem fire is not intercepted')
    local glacial=victim('glacialhound',2010);hit(enemy,glacial)
    check(not glacial.components.health:IsDead(),'enemy cannot acquire glacial execution')
    enemy.components.health:SetVal(0,'test');graph.states.death.onenter(enemy)
    check(enemy.deathloot and enemy.physicsremoved and not enemy.eyeturretrecovering2hm and not enemy.components.timer,
        'enemy retains native death, loot and collider removal')
    enemy:Remove();victim1:Remove();victim2:Remove();glacial:Remove()
end
local retaliating=tower(2200)
retaliating.components.combat.target=entity('wilson');retaliating.components.combat.target:AddTag('player')
retaliating:PushEvent('healthdelta',{oldpercent=1,newpercent=.6})
check(retaliating.eyeturretenhanced2hm and retaliating.allmiss2hm,'friendly turret retaliation does not revoke its identity')
retaliating:Remove()

-- Native Health:SetVal and the full native Timer drive the recovery lifecycle.
local resting=tower(2400)
resting.components.repairable2hm:Repair(nil,gift('dragon_scales'))
resting.components.repairable2hm:Repair(nil,gift('shroom_skin'))
local deathcount=0;resting:ListenForEvent('death',function()deathcount=deathcount+1 end)
resting:PushEvent('healthdelta',{oldpercent=1,newpercent=.3})
resting.components.health:SetVal(0,'combat')
check(resting.components.health:IsDead()and resting.eyeturretrecovering2hm,'zero health starts recovery')
check(resting.persists and resting.components.health.nofadeout and not resting:HasTag('NOCLICK'),'dead tower persists and remains clickable')
check(not resting.components.inventory.dropondeath and resting.components.combat:GetWeapon(),'death retains its equipped weapon')
check(not resting.components.health.regen and resting.brainstopped and not resting.allmiss2hm,'recovery stops regeneration brain and shield')
check(not resting.poor_armor2hm_fx and not resting.poor_33cdtask2hm,'recovery removes shield effects and cooldown')
check(resting.colour[4]==1 and resting.eyeturretfadetask2hm and resting.animation=='idle_loop'and not resting.lightenabled,'eye starts fading from current opacity with inactive light')
graph.states.death.onenter(resting)
check(not resting.deathloot and not resting.physicsremoved,'friendly death state neither drops loot nor removes obstacle')
near(resting.components.timer:GetTimeLeft('eyeturret_recovery2hm'),2400,'five standard days are forty minutes')
resting.components.health:SetVal(1500,'healing');resting.components.health:DoDelta(50,true,'regen')
check(resting.components.health.currenthealth==0 and deathcount==1,'healing cannot bypass recovery or replay death')
check(not resting.components.repairable2hm:Repair(nil,gift('dragon_scales')),'resting tower rejects upgrades')
check(resting.components.inspectable.descriptionfn(resting):find('5.0',1,true),'inspect reports remaining days')
tick(479)
check(resting.colour[4]==0 and not resting.eyeturretfadetask2hm,'fade-out finishes and releases its task')
local data={};resting:OnSave(data);data.timer=resting.components.timer:OnSave()
near(data.timer.timers.eyeturret_recovery2hm.timeleft,1921,'save retains exact remaining time')
for _,healthfirst in ipairs({true,false})do
    local reload=tower(2500)
    local replayed=0;reload:ListenForEvent('death',function()replayed=replayed+1 end)
    reload:OnPreLoad(data)
    if healthfirst then reload.components.health:SetVal(0,'file_load')end
    reload.components.timer:OnLoad(data.timer)
    if not healthfirst then reload.components.health:SetVal(0,'file_load')end
    reload:OnLoad(data)
    check(replayed==0 and reload.eyeturretrecovering2hm and reload.colour[4]==0,'reload avoids duplicate death in either component order')
    check(reload.eyeturretfire2hm and reload.eyeturretspore2hm,'resting save retains both upgrades')
    near(reload.components.timer:GetTimeLeft('eyeturret_recovery2hm'),1921,'reload does not restart five-day countdown')
    reload.components.timer:LongUpdate(1920);tick(0)
    check(reload.eyeturretrecovering2hm and reload.components.health:IsDead(),'long update does not recover early')
    reload.components.timer:LongUpdate(1);tick(0)
    check(not reload.eyeturretrecovering2hm and reload.components.health.currenthealth==2000,'full elapsed simulation time restores full health')
    check(reload.colour[4]==0 and reload.eyeturretfadetask2hm and not reload.brainstopped and reload.sg.currentstate.name=='idle','recovery starts eye fade-in and immediately restores brain')
    check(reload.components.health.regen.amount==50 and reload.components.combat.weapon.components.weapon.stimuli=='electric','recovery restores regeneration and electric attack')
    reload.components.health:SetVal(0,'second defeat')
    near(reload.components.timer:GetTimeLeft('eyeturret_recovery2hm'),2400,'second defeat begins a fresh recovery')
    reload:Remove()
end
tick(1920)
check(resting.eyeturretrecovering2hm,'not restored one second before deadline')
tick(1)
check(not resting.eyeturretrecovering2hm and resting.components.health.currenthealth==2000,'normal timer recovers at exactly five days')

AllRecipes={eyeturret={ingredients={},numtogive=1},eyeturret_item={ingredients={},numtogive=1}}
local staff=entity('greenstaff')
staff.components.spellcaster={spell=function()end,canuseontargets=true,canonlyuseonrecipes=true,canuseondead=false,CanCast=SpellCaster.CanCast}
apply('greenstaff',staff)
check(staff.components.spellcaster:CanCast(actiongiver,resting),'green staff can deconstruct active friendly tower')
resting.components.health:SetVal(0,'test')
check(staff.components.spellcaster:CanCast(actiongiver,resting),'green staff can deconstruct zero-health resting tower')
check(not staff.components.spellcaster.canuseondead,'staff death exception remains scoped to a single call')
local otherdead=victim('eyeturret',2600,{'companion','hostile'});otherdead.components.health:SetVal(0,'test')
check(not staff.components.spellcaster:CanCast(actiongiver,otherdead),'staff still rejects other dead targets')
resting:AddTag('INLIMBO');check(not staff.components.spellcaster:CanCast(actiongiver,resting),'staff retains native visibility/limbo restrictions');resting:RemoveTag('INLIMBO')
for _,target in ipairs({resting,tower(2700)})do
    if target~=resting then target.components.repairable2hm:Repair(nil,gift('dragon_scales'))end
    target:PushEvent('ondeconstructstructure')
    check(target.refunds.dragon_scales==1,'deconstruction returns exactly one installed scale')
    check(target.refunds.shroom_skin==(target==resting and 1 or nil),'deconstruction returns only installed mushroom skin')
    target:PushEvent('ondeconstructstructure')
    check(target.refunds.dragon_scales==1 and not target.eyeturretfire2hm and not target:HasTag('eyeturretsporeproof2hm'),'repeat event cannot duplicate refund')
    target:Remove()
end
local unmodified=tower(2800);unmodified:PushEvent('ondeconstructstructure');check(not unmodified.refunds,'no free upgrade materials without upgrades')
local packed=portable();packed.components.repairable2hm:Repair(nil,gift('shroom_skin'))
local before=#entities;packed:PushEvent('ondeconstructstructure')
check(#entities==before+1 and entities[#entities].prefab=='shroom_skin','upgraded portable item also refunds its material')
local failingstaff=entity('greenstaff');failingstaff.components.spellcaster={canuseondead=false,CanCast=function()error('injected cast error')end}
apply('greenstaff',failingstaff)
unmodified.components.health:SetVal(0,'test')
check(not pcall(failingstaff.components.spellcaster.CanCast,failingstaff.components.spellcaster,actiongiver,unmodified),'native casting error remains visible')
check(not failingstaff.components.spellcaster.canuseondead,'casting error restores staff flags')
unmodified:Remove();packed:Remove();otherdead:Remove()

-- Cosmetic transitions preserve tint and do not restart on duplicate death,
-- replay on load, or leave a stale fade-in running after another defeat.
local fading=tower(2900);fading.AnimState:SetMultColour(.8,.7,.6,.9)
fading.components.health:SetVal(0,'test')
near(fading.colour[4],.9,'fade-out starts at original alpha')
tick(.25)
local partial=fading.colour[4]
check(partial>0 and partial<.9,'fade-out has an intermediate opacity')
graph.states.death.onenter(fading)
near(fading.colour[4],partial,'duplicate death does not snap or restart fade')
local fadeSave={};fading:OnSave(fadeSave);fadeSave.timer=fading.components.timer:OnSave()
local midload=tower(3000);midload:OnPreLoad(fadeSave);midload.components.timer:OnLoad(fadeSave.timer);midload:OnLoad(fadeSave)
check(midload.colour[4]==0 and not midload.eyeturretfadetask2hm,'loading during fade-out shows resting state without a flash')
midload:Remove();tick(.4)
near(fading.colour[4],0,'fade-out reaches zero')
near(fading.colour[1],.8,'fade preserves original colour channels')
fading.components.timer:LongUpdate(fading.components.timer:GetTimeLeft('eyeturret_recovery2hm'));tick(0)
tick(.35)
partial=fading.colour[4]
check(partial>0 and partial<.9 and fading.components.health.currenthealth==2000,'fade-in progresses while gameplay has recovered')
local awakeSave={};fading:OnSave(awakeSave)
local awakeLoad=tower(3100);awakeLoad:OnPreLoad(awakeSave);awakeLoad:OnLoad(awakeSave)
check(not awakeLoad.eyeturretrecovering2hm and awakeLoad.colour[4]==1 and not awakeLoad.eyeturretfadetask2hm,'loading during fade-in shows normal live state')
awakeLoad:Remove()
local oldfade=fading.eyeturretfadetask2hm
fading.components.health:SetVal(0,'defeated during fade-in')
check(oldfade.cancelled,'new defeat cancels the previous fade-in task')
near(fading.colour[4],partial,'new defeat fades from current partial opacity')
tick(.65);near(fading.colour[4],0,'interrupted fade-in cannot make resting eye reappear')
fading.components.timer:LongUpdate(fading.components.timer:GetTimeLeft('eyeturret_recovery2hm'));tick(0);tick(.85)
near(fading.colour[4],.9,'fade-in restores original target alpha')
check(not fading.eyeturretfadetask2hm and not fading.eyeturretcolour2hm,'completed fade-in releases transition state')
fading.components.health:SetVal(0,'test');local pending=fading.eyeturretfadetask2hm
fading:PushEvent('ondeconstructstructure');fading:Remove()
check(pending.cancelled and not fading.eyeturretfadetask2hm,'removal during transition cancels the fade task')

TheWorld.ismastersim=false
local preview=entity('eyeturret');preview:AddTag('companion');apply('eyeturret',preview)
check(preview:HasTag('repairable2hm')and not preview.eyeturretenhanced2hm,'client receives action tag without server components')
check(not preview:HasTag('alltrader') and preview.repairmaterials2hm.dragon_scales==1,'client uses common material action')
local basepreview=entity('eyeturret_base');local replicationcalled=false
basepreview.entity.GetParent=function()return preview end
basepreview.OnEntityReplicated=function()replicationcalled=true end
apply('eyeturret_base',basepreview);basepreview:OnEntityReplicated()
check(replicationcalled and basepreview.client_forward_target==preview,'client base preserves replication callback and forwards clicks to friendly tower')
for _,spec in ipairs({{'eyeturret',{'hostile','companion'}},{'shadoweyeturret',{'shadoweyeturret','hostile'}}})do
    local enemy=entity(spec[1]);for _,tag in ipairs(spec[2])do enemy:AddTag(tag)end
    apply('eyeturret',enemy)
    check(not enemy:HasTag('repairable2hm')and not enemy.repairmaterials2hm,'enemy client has no fake upgrade action')
end
local itempreview=entity('eyeturret_item');apply('eyeturret_item',itempreview)
check(itempreview:HasTag('repairable2hm')and itempreview.components.repairable2hm==nil,'client portable preview only adds native action tags')
local pc=entity('eye_charge');apply('eye_charge',pc);check(pc.components.projectile==nil,'client projectile is safe')
print('EYETURRET_CHECKS_PASS '..checks)
