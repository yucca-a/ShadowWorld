local checks = 0
local function eq(a,b,label)
    checks=checks+1
    assert(a==b,(label or "equal")..": "..tostring(a).." ~= "..tostring(b))
end
function math.clamp(v,lo,hi)return math.max(lo,math.min(v,hi))end
STRINGS={NAMES={WETGOOP="Wet Goop",RABBITHOLE="Rabbit Hole"},NAME_DETAIL_EXTENTION={},
    SMOLDERINGITEM="Smoldering",WITHEREDITEM="Withered",DISEASEDITEM="Diseased",WAXEDPLANT="Waxed",
    BROKENITEM="Broken",DEADCREATURE="Dead",UI={HUD={SPOILED="Spoiled"}},
    WET_PREFIX={FOOD="Soggy",CLOTHING="Damp",TOOL="Slippery",FUEL="Wet",GENERIC="Wet",WETGOOP="Watery",RABBITHOLE="Collapsed"}}
FOODTYPE={};FUELTYPE={};EQUIPSLOTS={HANDS="hands",HEAD="head",BODY="body"}
assert(loadstring(adjective_source,"@scripts/dlcsupport_strings.lua"))()
EntityScript={};assert(loadstring(naming_source,"@scripts/entityscript.lua"))()
Health={};assert(loadstring(health_source,"@scripts/components/health.lua"))()
function NotifyPlayerProgress()end
function CanEntityBecomeCorpse()return false end
TheWorld={PushEvent=function()end}
local hook
function AddComponentPostInit(name,fn)if name=="health"then hook=fn end end
function AddSimPostInit()end
function AddPrefabPostInit()end
function AddStategraphPostInit()end
local function health(source)
    hook=nil;assert(loadstring(source,"@common/bugfix.lua"))()
    local inst={events={}}
    function inst:PushEvent(event,data)self.events[event]=data end
    local h=setmetatable({inst=inst,maxhealth=100,currenthealth=100,minhealth=0,penalty=0,
        nonlethal_pct=0,absorb=0,playerabsorb=0,nofadeout=true,
        externalabsorbmodifiers={Get=function()return 0 end}}, {__index=Health})
    function h:GetPercent()return self.currenthealth/self.maxhealth end
    function h:IsInvincible()return false end
    function h:ForceUpdateHUD()end
    hook(h);return h,inst
end
local function entity(prefab,name,tags)
    local e=setmetatable({prefab=prefab,name=name,tags=tags or {},replica={}}, {__index=EntityScript})
    function e:HasTag(tag)return self.tags[tag]or false end
    function e:GetIsWet()return self.wet or false end
    return e
end
local calls={
    DoDelta=function(h,c)h:DoDelta(-25,false,c)end,
    SetPercent=function(h,c)h:SetPercent(.75,false,c)end,
    SetVal=function(h,c)h:SetVal(75,c)end,
}
local missing=entity("unnamed_mod_entity",nil);missing.wet=true
local ok,err=pcall(missing.GetDisplayName,missing)
eq(ok,false,"native naming reproduces missing-name crash")
eq(tostring(err):find("concatenate")~=nil,true,"native concatenation fails before fallback")
for _,source in ipairs({published_source,upstream_source,fixed_source})do
    for method,call in pairs(calls)do
        local h,inst=health(source)
        local pass=pcall(call,h,missing)
        eq(pass,source~=published_source,method.." published fails, upstream/fixed survive")
        if pass then eq(h.currenthealth,75,method.." damage still applied")end
    end
end
local wet=entity("log","Log");wet.wet=true
local cases={
    {cause="cold",expected="cold"}, {cause=false,expected=false}, {expected=nil},
    {cause=wet,expected="Wet Log"}, {cause=entity("unnamed_mod_entity",nil),expected="unnamed_mod_entity"},
    {cause=missing,expected="unnamed_mod_entity"},
    {cause=entity("unnamed_smolder",nil,{smolder=true}),expected="unnamed_smolder"},
    {cause={prefab="throws",GetDisplayName=function()error("bad mod display name")end},expected="throws"},
    {cause={prefab="empty",GetDisplayName=function()return ""end},expected="empty"},
    {cause={prefab="bad_name",GetDisplayName=function()return {}end},expected="bad_name"},
    {cause={prefab="no_method"},expected="no_method"},
    {cause={prefab="not_callable",GetDisplayName=true},expected="not_callable"},
    {cause={GetDisplayName=function()return "Custom Name"end},expected="Custom Name"},
    {cause={},expected="unknown"}, {cause={prefab={}},expected="unknown"},
    {cause=42,expected="unknown"}, {cause=true,expected="unknown"},
}
for method,call in pairs(calls)do
    for _,case in ipairs(cases)do
        local h,inst=health(fixed_source);call(h,case.cause)
        eq(h.currenthealth,75,method.." preserves health result")
        if method~="SetVal"then eq(inst.events.healthdelta.cause,case.expected,method.." normalizes event cause")end
    end
end
for method,call in pairs(calls)do
    local h,inst=health(fixed_source)
    if method=="DoDelta"then h:DoDelta(-200,false,missing)
    elseif method=="SetPercent"then h:SetPercent(0,false,missing)
    else h:SetVal(0,missing)end
    eq(h.currenthealth,0,"lethal damage still kills")
    eq(inst.events.death.cause,"unnamed_mod_entity","death gets safe prefab cause")
end
print("PASS health cause: "..checks.." assertions; native nameless-source crash reproduced in published 2.8.15.0.7")
