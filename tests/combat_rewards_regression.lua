local checks=0
local function check(ok,why)checks=checks+1;assert(ok,why)end
local function load(s)return assert(loadstring(s))()end
TUNING={BATBAT_DRAIN=6.8,BATBAT_SANITY_DRAIN_MULT=.5,SHADOW_BATTLEAXE={LIFE_STEAL_SANITY_LOSS_SCALE=.5}}
EQUIPSLOTS={HEAD='head'};ACTIONS={ATTACK={}}
SKIN_FX_PREFAB={}
load(tags_source);load(life_source)
local benefits=load(benefits_source)
package.preload.combatbenefits2hm=function()return benefits end
package.preload.umcompatguard2hm=function()return load(guard_source)end
TheWorld={ismastersim=true}
local hooks={}
AddPrefabPostInit=function(name,fn)hooks[name]=fn end
load(patch_source)
Weapon={};load(weapon_source)
local function entity(prefab,tags)
    local inst={prefab=prefab,tags=tags or {},components={}}
    function inst:HasTag(t)return self.tags[t]or false end
    function inst:HasAnyTag(tags)for _,t in ipairs(tags)do if self:HasTag(t)then return true end end;return false end
    inst.HasOneOfTags=inst.HasAnyTag
    function inst:IsValid()return true end
    function inst:ListenForEvent(name,fn)
        self.event_listeners=self.event_listeners or {}
        self.event_listeners[name]=self.event_listeners[name]or {[self]={}}
        local list=self.event_listeners[name][self]
        list[#list+1]=fn
    end
    function inst:RemoveEventCallback(name,fn)
        local list=self.event_listeners[name][self]
        for i=#list,1,-1 do if list[i]==fn then table.remove(list,i)end end
    end
    function inst:PushEvent(name)self.event=name end
    return inst
end
local function cow(bound,shadow)
    local inst=entity('beefalo',shadow and {swc2hm=true}or {})
    inst.components.follower={GetLeader=function()return bound and {}or nil end}
    if shadow then inst.swp2hm=cow(bound,false);inst.components.follower.GetLeader=function()end end
    return inst
end
local function player()
    local p=entity('wathom',{player=true})
    p.hp=40;p.san=50
    p.components.health={IsHurt=function()return p.hp<100 end,DoDelta=function(_,d)p.hp=p.hp+d end}
    p.components.sanity={DoDelta=function(_,d)p.san=p.san+d end}
    p.components.inventory={GetEquippedItem=function()end}
    return p
end
local nativebat,nativeaxe=load(bat_source),load(axe_source)
local function weapon(prefab)
    local inst=entity(prefab)
    inst.GetSkinName=function()end
    local cmp={inst=inst,onattack=nativebat,attackwearmultipliers={Get=function()return 1 end}}
    function cmp:SetOnAttack(fn)self.onattack=fn end
    inst.components.weapon=cmp
    inst.components.finiteuses={used=0,IgnoresCombatDurabilityLoss=function()return false end,Use=function(self,n)self.used=self.used+n end}
    inst.DoLifeSteal=nativeaxe;inst._lifesteal=3
    hooks[prefab](inst)
    return inst
end
for _,enabled in ipairs({false,true})do
    benefits.beefaloprotection=enabled
    for _,shadow in ipairs({false,true})do
        for _,bound in ipairs({false,true})do
            local target=cow(bound,shadow)
            local p=player()
            local bat=weapon('batbat')
            Weapon.OnAttack(bat.components.weapon,p,target)
            check((p.hp==40)==(enabled and bound),'bat drain follows actual protection setting and bell binding')
            check((p.san==50)==(enabled and bound),'blocked bat drain spends no sanity')
            check(bat.components.finiteuses.used==1 and bat.event=='weapononattack','normal attack event and durability remain')
            local axe=weapon('shadow_battleaxe');p.hp=40
            axe:DoLifeSteal(p,target)
            check((p.hp==40)==(enabled and bound),'axe native drain matches protection')
        end
    end
end
benefits.beefaloprotection=true
local bat=weapon('batbat');local npc=player();npc.tags.player=nil
Weapon.OnAttack(bat.components.weapon,npc,cow(true,false))
check(npc.hp>40,'NPC drain is not suppressed by player weapon protection')
local valid=load(victim_source)
for _,tag in ipairs({'deck_of_cards','structure','wall','balloon'})do
    local target=entity('test',{[tag]=true})
    target.components.health={IsDead=function()return false end};target.components.combat={}
    check(not valid(target),'shield cannot bite non-lifeform '..tag)
end
local target=entity('pigman');target.components.health={IsDead=function()return false end};target.components.combat={}
check(valid(target),'shield still bites living enemies')
local CombatBenefits=benefits
local extra=assert(loadstring('local CombatBenefits=...;local function SBADoHit()dotcalls=dotcalls+1 end;local function SBAClear()end;\n'..extra_source))(benefits)
for _,bound in ipairs({false,true})do
    local target=cow(bound,false)
    target._sba_buff2hm=true;target.components.combat={};target.components.health={IsDead=function()return false end}
    local p=player();local axe=weapon('shadow_battleaxe')
    dotcalls=0
    extra(axe,p,target)
    check(dotcalls==(bound and 0 or 1),'protected cow receives no enhanced axe damage-over-time')
    check((p.hp==40)==bound,'enhanced axe bonus drain uses the same protection')
end
local calls=0
local function CheckValidAttackData()calls=calls+1;return true end
local song={songdata={ONAPPLY=function()return CheckValidAttackData end}}
hooks.battlesong_healthgain(song);hooks.battlesong_sanitygain(song)
local guard=require('umcompatguard2hm')
local filter=guard.Find(song.songdata.ONAPPLY,'CheckValidAttackData').value
check(not filter(nil,{target=entity('deck_of_cards',{deck_of_cards=true})}),'songs reject deck even if old filter would accept it')
check(calls==0,'non-lifeform hit never reaches old benefit callback')
check(filter(nil,{target=entity('pigman')}),'living target retains old song rule')
check(calls==1,'shared song filter wraps once')
for _,source in ipairs(wathom_sources)do
    local native=assert(loadstring(source,'@scripts/prefabs/wathom.lua'))()
    for _,enabled in ipairs({false,true})do
        benefits.beefaloprotection=enabled
        for _,bound in ipairs({false,true})do
            local p=player()
            local target=cow(bound,false)
            target.components.combat={defaultdamage=34}
            p.amp=30
            p.components.adrenaline={GetPercent=function()return p.amp/100 end,DoDelta=function(_,d)p.amp=p.amp+d end}
            p.DoTaskInTime=function()return {Cancel=function()end}end
            local other=0
            p.OnAttackOther2hm=function()p.customtimer=true end
            p.event_listeners={onattackother={[p]={native,p.OnAttackOther2hm,function()other=other+1 end}}}
            hooks.wathom(p)
            local data={target=target,weapon={}}
            for _,fn in ipairs(p.event_listeners.onattackother[p])do fn(p,data)end
            check((p.amp==30)==(enabled and bound),'both UM editions reject protected cow adrenaline only')
            check((p.adrenalpause==nil)==(enabled and bound),'protected attacks do not refresh native combat timer')
            check((p.customtimer==nil)==(enabled and bound),'protected attacks do not refresh extended combat timer')
            check(other==1,'other attack listeners remain active')
        end
    end
end
print('Combat reward eligibility / native weapon drain: '..checks..' checks passed')
