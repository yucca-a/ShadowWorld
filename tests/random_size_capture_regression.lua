-- Lifecycle edge cases with headless entities; native LootDropper and MURDER.
local n=0
local function check(ok,why) n=n+1;assert(ok,why) end
local size=assert(loadstring(size_source))()
ACTIONS={MURDER={}}
assert(loadstring(murder_source))()
function Vector3(x,y,z) return {x=x,y=y,z=z} end
local products={}
function SpawnPrefab(prefab) return {prefab=prefab} end
local doer={Transform={GetWorldPosition=function() return 0,0,0 end},components={inventory={
    GiveItem=function(_,loot) products[#products+1]=loot.prefab end}},PushEvent=function() end}
local function make(scale,stack,original)
    local p={prefab="rabbit",components={},tasks={},tags={_health=true},valid=true}
    function p:HasTag(tag) return self.tags[tag] or false end
    function p:AddTag(tag) self.tags[tag]=true end
    function p:IsValid() return self.valid end
    function p:Remove() self.valid=false end
    function p:DoTaskInTime(_,fn)
        local t={fn=fn,Cancel=function(self) self.cancelled=true end}
        self.tasks[#self.tasks+1]=t;return t
    end
    function p:Flush()
        local tasks=self.tasks;self.tasks={}
        for _,t in ipairs(tasks) do if not t.cancelled then t.fn(self) end end
    end
    p.Transform={GetScale=function() return 1,1,1 end,SetScale=function(_,x) p.display=x end,SetPosition=function() end}
    local h={currenthealth=100,maxhealth=100,penalty=0}
    function h:GetPercent() return self.currenthealth/self.maxhealth end
    function h:SetPercent(v) self.currenthealth=self.maxhealth*v end
    function h:SetMaxHealth(v) self.maxhealth=v;self.currenthealth=v end
    function h:SetPenalty(v) self.penalty=v end
    function h:SetCurrentHealth(v) self.currenthealth=v end
    function h:ForceUpdateHUD() self.currenthealth=math.min(self.currenthealth,self.maxhealth*(1-self.penalty)) end
    function h:IsDead() return self.currenthealth<=0 end
    p.components.health=h
    p.components.inventoryitem={trappable=true,RemoveFromOwner=function() return p end}
    if stack then p.components.stackable={StackSize=function() return 1 end} end
    local ld=LootDropper(p);ld:SetLoot({"smallmeat"});ld.GetLuckyUser=function() end
    p.components.lootdropper=ld
    if original then
        p.settrapdata=function() return original.payload end
        p.restoredatafromtrap=function(_,data)
            p.originalrestored=data;original.calls=(original.calls or 0)+1
            if original.defer then
                p:DoTaskInTime(0,function() h:SetMaxHealth(999) end)
            end
            return false
        end
    end
    size.Install(p)
    if scale then p.ray_suijidaxiao=1;size.Apply(p,scale,true) end
    return p,h,ld
end
for _,scale in ipairs({.75,1,1.35,1.5}) do
    local original={payload={beardlingtime=42,persistent2hm={super="red"}}}
    local p,h=make(scale,false,original)
    h:SetCurrentHealth(h.maxhealth*.6)
    local data=p:settrapdata()
    check(original.payload.randomsizecapture2hm==nil,"original callback table not mutated")
    check(data.beardlingtime==42 and data.persistent2hm.super=="red","existing trap data retained")
    local restored,rh=make(nil,false,{payload=original.payload,defer=true})
    check(restored:restoredatafromtrap(data)==false,"old restoration return value retained")
    check(restored.myscale==scale and rh.maxhealth==h.maxhealth and rh.currenthealth==h.currenthealth,"immediate exact identity restored")
    restored:Flush()
    check(rh.maxhealth==h.maxhealth and rh.currenthealth==h.currenthealth,"late prefab initialization cannot reset captured HP")
    check(rh.save_maxhealth,"native health saves exact maximum after capture")
    size.Apply(restored,1,true)
    check(rh.maxhealth==h.maxhealth,"queued random initialization cannot apply scale twice")
    products={}
    check(ACTIONS.MURDER.fn({invobject=restored,doer=doer}),"native inventory murder succeeds")
    check(#products==(scale>1.35 and 2 or 1),"native murder uses large bonus and small single-portion minimum")
end
do
    local p=make(1.5,true,{payload={beardlingtime=15}})
    local data=p:settrapdata()
    check(data.randomsizecapture2hm==nil and data.beardlingtime==15,"stackable source returns existing trap data only")
    local p2,h2=make(nil,true)
    p2:restoredatafromtrap(data);p2:Flush()
    check(h2.maxhealth==100 and h2.currenthealth==100 and p2.myscale==nil,"stackable live source keeps baseline")
    local source=make(1.5,false)
    local p3,h3=make(nil,true)
    p3:restoredatafromtrap(source:settrapdata());p3:Flush()
    check(h3.maxhealth==100 and h3.currenthealth==100 and p3.myscale==nil,"newly enabled stackability also ignores old individual metadata")
    local late=make(1.5,false)
    late.components.stackable={}
    check(late:settrapdata()==nil,"stackability added after hooks is checked dynamically")
end
for _,payload in ipairs({false,"custom-scalar",27}) do
    local source=make(1.5,false,{payload=payload})
    local restored=make(nil,false,{payload=payload})
    restored:restoredatafromtrap(source:settrapdata())
    check(restored.originalrestored==payload,"non-table existing trap data preserved")
end
do
    local source=make(1.5,false)
    local restored=make(nil,false)
    restored:restoredatafromtrap(source:settrapdata())
    check(restored.originalrestored==nil,"nil original trap payload supported")
    local old,h=make(nil,false)
    old:restoredatafromtrap({beardlingtime=12});old:Flush()
    check(h.maxhealth==100 and h.currenthealth==100,"old traps without new metadata remain loadable")
    old:restoredatafromtrap({randomsizecapture2hm=5})
    check(h.maxhealth==100,"unrecognized metadata does not break existing trap restoration")
end
print("Random-size live capture/murder: "..n.." checks passed")
