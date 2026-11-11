local checks=0
local function check(ok,why) checks=checks+1;assert(ok,why) end
GLOBAL=_G
TheWorld={ismastersim=true}
local nearbag=false
TheSim={FindEntities=function() return nearbag and {{}} or {} end}
TUNING={DSTU={BATTLESONG_LUNAR_REGEN_PERIOD=1,BATTLESONG_LUNAR_HEALTHGAIN_MULT_SINGER=1.25,
    BATTLESONG_LUNAR_SANITYGAIN_MULT_SINGER=1.5},BATTLESONG_HEALTHGAIN_DELTA=2,
    BATTLESONG_HEALTHGAIN_DELTA_SINGER=4,BATTLESONG_SANITYGAIN_DELTA=1}
package.preload.umcompatprofiles2hm=assert(loadstring(profiles_source))
UMGuard=assert(loadstring(guard_source))()
local function victim(damage,tags)
    local t={components={health={},combat={defaultdamage=damage or 50}},tags=tags or {hostile=true}}
    function t:HasTag(tag) return self.tags[tag] or false end
    function t:IsValid() return not self.invalid end
    return t
end
local function fixture(source,name)
    nearbag=false
    local originalhooks,hooks={},{}
    env={AddPrefabPostInit=function(prefab,fn) originalhooks[prefab]=fn end}
    assert(loadstring(source,name or "@../mods/workshop-3193922031/postinit/prefabs/battlesongs.lua"))()
    AddPrefabPostInit=function(prefab,fn) hooks[prefab]=fn end
    assert(loadstring(repair_source))()
    local items={}
    for _,prefab in ipairs({"battlesong_healthgain","battlesong_sanitygain"}) do
        local inst={songdata={}}
        originalhooks[prefab](inst)
        inst.originalfilter=UMGuard.Find(inst.songdata.ONAPPLY,"CheckValidAttackData").value
        hooks[prefab](inst)
        inst.filter=UMGuard.Find(inst.songdata.ONAPPLY,"CheckValidAttackData").value
        items[#items+1]=inst
    end
    return items
end
local function actor(items)
    local p={components={combat={}},hp=0,sanity=0,callbacks={}}
    function p:HasTag(tag) return tag=="battlesinger" or tag=="lunarmelodist" or tag=="lunar_improved_songs" end
    p.Transform={GetWorldPosition=function() return 0,0,0 end}
    p.components.health={DoDelta=function(_,amount) p.hp=p.hp+amount end}
    p.components.sanity={DoDelta=function(_,amount) p.sanity=p.sanity+amount end}
    for _,item in ipairs(items) do
        item.ListenForEvent=function(_,event,fn,owner)
            check(event=="onattackother" and owner==p,"native song listener retained")
            p.callbacks[#p.callbacks+1]=fn
        end
        item.DoPeriodicTask=function(self)
            self.regen=true
            return {Cancel=function() end}
        end
        item.DoTaskInTime=function() end
        item.songdata.ONAPPLY(item,p)
    end
    return p
end
local items=fixture(beta_source)
check(items[1].filter~=items[1].originalfilter,"reviewed beta filter replaced")
local p=actor(items)
check(items[1].regen and items[2].regen,"upstream lunar periodic regeneration retained")
local function hit(target,stored,weapon,projectile)
    p.hp,p.sanity=0,0;p.components.combat.target=stored
    local data={target=target,weapon=weapon,projectile=projectile}
    for _,fn in ipairs(p.callbacks) do fn(p,data) end
    return p.hp,p.sanity
end
local weapon={components={inventoryitem={},weapon={attackrange=2}}}
for _,tags in ipairs({{epic=true},{hostile=true},{epic=true,hostile=true}}) do
    for _,stored in ipairs({"same","absent","passive"}) do
        local enemy=victim(0,tags)
        local cached=stored=="same" and enemy or stored=="passive" and victim(0,{prey=true}) or nil
        nearbag=true
        local hp,san=hit(enemy,cached,weapon)
        check(hp==2 and san==1,"actual zero-damage enemy heals once regardless of stored target or nearby dummy")
    end
end
for _,tags in ipairs({{structure=true},{wall=true},{veggie=true},{balloon=true},{groundspike=true},
    {smashable=true},{companion=true},{prey=true},{eyeturret=true}}) do
    local hp,san=hit(victim(50,tags),victim(100),weapon)
    check(hp==0 and san==0,"actual excluded victim cannot heal")
end
local hp,san=hit(victim(0,{}),victim(100),weapon)
check(hp==0 and san==0,"passive zero-damage creature excluded")
hp,san=hit(victim(50),nil,{components={weapon={}}})
check(hp==0 and san==0,"detached/fake AOE weapon remains excluded")
hp,san=hit(victim(50),nil,weapon,{components={projectile={IsBounced=function() return true end}}})
check(hp==0 and san==0,"bounced projectile remains excluded")
hp,san=hit(victim(50),nil,nil)
check(hp==2 and san==1,"valid unarmed/mounted attack still heals")
local invalid=victim(50);invalid.invalid=true
hp,san=hit(invalid,nil,weapon)
check(hp==0 and san==0,"invalid target rejected")
hp,san=hit(nil,nil,weapon)
check(hp==0 and san==0,"missing target rejected")
local missing=victim(50);missing.components.health=nil
hp,san=hit(missing,nil,weapon)
check(hp==0 and san==0,"health-less target rejected")
items=fixture(stable_source,"@../mods/workshop-2039181790/postinit/prefabs/battlesongs.lua")
check(items[1].filter==items[1].originalfilter and items[2].filter==items[2].originalfilter,"stable callbacks untouched")
p=actor(items)
nearbag=true
hp,san=hit(victim(0,{epic=true}),victim(0,{prey=true}),weapon)
check(hp==5 and san==1.5,"stable lunar hit healing amounts retained")
items=fixture(beta_source:gsub("local searchradius = 3","local searchradius = 4",1))
check(items[1].filter==items[1].originalfilter,"changed upstream implementation is not overwritten")
items=fixture(beta_source,"@../mods/other/postinit/prefabs/other_songs.lua")
check(items[1].filter==items[1].originalfilter,"unrelated source path is not overwritten")
print("Wigfrid actual-hit song recovery: "..checks.." checks passed")
