local checks=0
local function check(ok,why) checks=checks+1;assert(ok,why) end
AllRecipes={}
TUNING={}
SPECIAL_EVENTS={WINTERS_FEAST=1}
function IsSpecialEventActive() return false end
TheWorld={PushEvent=function() end}
function AddSimPostInit() end
local size=assert(loadstring(size_source))()
local function clone(t) local out={} for i,v in ipairs(t) do out[i]=v end return out end
local function count(list,key)
    local n=0 for _,v in ipairs(list) do if v==key then n=n+1 end end return n
end
local function make(scale,loots,tags)
    local p={prefab="beefalo",components={},ray_suijidaxiao=1,tags=tags or {_health=true}}
    function p:HasTag(tag) return self.tags[tag] or false end
    function p:AddTag(tag) self.tags[tag]=true end
    p.Transform={GetScale=function() return 1,1,1 end,SetScale=function() end}
    local ld=LootDropper(p);p.components.lootdropper=ld
    ld.GetLuckyUser=function() end
    if loots then ld:SetLoot(loots) else ld:SetChanceLootTable("beefalo") end
    local generated=ld.GenerateLoot
    ld.GenerateLoot=function(self,...) self.rolls=(self.rolls or 0)+1;return generated(self,...) end
    ld.SpawnLootPrefab=function(self,prefab) self.spawned[#self.spawned+1]=prefab end
    if scale then size.Apply(p,scale,true) end
    return p,ld
end
local function drop(ld,roll)
    local original=math.random
    local calls=0
    math.random=function() calls=calls+1;return roll or .1 end
    ld.spawned={};ld:DropLoot()
    math.random=original
    return ld.spawned,calls
end
for _,case in ipairs({{.75,2},{.80,2},{.81,3},{.85,3},{.89,3},{.90,4},{.95,4},{1,4},{1.35,4},{1.36,8},{2,8}}) do
    for _,roll in ipairs({.1,.9}) do
        local p,ld=make(case[1])
        local loots,rng=drop(ld,roll)
        local multiple=case[1]>1.35 and 2 or 1
        check(count(loots,"meat")==case[2],"beefalo meat threshold "..case[1])
        check(count(loots,"beefalowool")==3*multiple,"wool unchanged by small-size rule")
        check(count(loots,"horn")== (roll<.33 and multiple or 0),"horn chance unchanged")
        check(rng==multiple,"meat filter does not add random rolls")
        size.Apply(p,.75,true)
        check(count(drop(ld,roll),"meat")==case[2],"repeated size application does not stack loot hooks")
    end
end
for _,loots in ipairs({elephant_summer,elephant_winter,elephant_fire}) do
    for _,case in ipairs({{.75,6},{.80,6},{.85,7},{.89,7},{.90,8},{1,8}}) do
        local _,ld=make(case[1],loots)
        local actual=drop(ld)
        check(count(actual,"meat")==case[2],"elephant multiple meat reduced")
        check(count(actual,loots[9])==1,"elephant trunk always preserved")
        check(#loots==9,"original shared loot table not mutated")
    end
end
for _,prefab in ipairs({"smallmeat","froglegs","monstermeat","drumstick","meat","fishmeat_small","batwing"}) do
    local _,ld=make(.75,{prefab})
    check(count(drop(ld),prefab)==1,"single portion preserved: "..prefab)
    _,ld=make(.75,{prefab,prefab})
    check(count(drop(ld),prefab)==1,"two portions retain one: "..prefab)
end
do
    local original={"meat","horn","meat","smallmeat","trunk_summer","meat","meat","smallmeat","pigskin","pigskin"}
    local _,ld=make(.75,original)
    local actual=drop(ld)
    check(count(actual,"meat")==2 and count(actual,"smallmeat")==1,"separate meat types each keep a minimum")
    check(count(actual,"horn")==1 and count(actual,"trunk_summer")==1 and count(actual,"pigskin")==2,"all non-meat products retained")
    check(#original==10,"caller-provided base loot table not mutated")
    ld:SetLoot({"cookedmeat","cookedmeat","cookedmeat","cookedmeat"})
    check(count(drop(ld),"cookedmeat")==2,"loot tables that change later remain supported")
    ld:SetLoot({})
    check(#drop(ld)==0,"empty native loot stays empty")
end
for _,tags in ipairs({{boulder=true},{_health=true,structure=true},{_health=true,swc2hm=true}}) do
    local _,ld=make(.75,{"meat","meat","meat","meat","rocks","rocks"},tags)
    check(count(drop(ld),"meat")==4,"excluded entity not reduced")
end
do
    local p,ld=make(nil,{"meat","meat","meat","meat"})
    p.ray_suijidaxiao=0;size.Apply(p,.75,true)
    check(count(drop(ld),"meat")==4,"non-random individual not reduced")
    p,ld=make(nil,{"meat","meat","meat","meat"})
    size.Apply(p,.75,false)
    check(count(drop(ld),"meat")==4,"loot flag disabled preserves normal result")
end
do
    local p,ld=make(.75)
    size.Save(p)
    local saved={};p:OnSave(saved)
    local restored,nextld=make(nil)
    size.Save(restored);restored:OnLoad(saved);size.Apply(restored,1,true)
    check(restored.myscale==.75 and count(drop(nextld),"meat")==2,"saved random size reapplies the same reduction once")
end
print("Random-size meat loot: "..checks.." checks passed")
