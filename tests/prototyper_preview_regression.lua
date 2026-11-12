local checks, sent, nextguid = 0, 0, 100
local function check(ok, why)checks=checks+1;assert(ok,why)end
local hooks={}
local enabled={['Science Machine Refine Materials']=true,['Alchemy Engine Redeem Gold Nugget']=true,
    ['Shadow Manipulator Break Down Objects']=true,['Prestihatitator Redeem shadowmagic Tag']=true}
GetModConfigData=function(k)return enabled[k] or false end
TUNING={hardmode2hm=false};STRINGS={};GLOBAL=_G
AddPrefabPostInit=function(name,fn)hooks[name]=hooks[name]or{};table.insert(hooks[name],fn)end
AddPlayerPostInit=function()end;AddComponentPostInit=function()end
AddComponentAction=function()end
net_byte=function()local value=0;return {set=function(_,v)value=v end,value=function()return value end}end
SetOnSave2hm=function(i,fn)i.onsave2hm=fn end
SetOnLoad2hm=function(i,fn)i.onload2hm=fn end
TheShard={GetShardId=function()return '1'end}
TheNet={GetIsServer=function()return false end}
TheWorld=setmetatable({ismastersim=false,components={}},{})
SendModRPCToShard=function()sent=sent+1 end
GetShardModRPC=function()return {}end
assert(loadstring(structure_source))()
local function station(prefab)
    nextguid=nextguid+1
    local inst={GUID=nextguid,prefab=prefab,components={},events={},persists=true,name=prefab}
    function inst:AddComponent(name)
        self.components[name]=name=='persistent2hm'and{data={}}or{SetAcceptTest=function()end,AcceptGift=function()end}
    end
    function inst:RemoveComponent(name)self.components[name]=nil end
    function inst:ListenForEvent(name,fn)self.events[name]=fn end
    function inst:Remove()self.events.onremove()end
    function inst:GetDebugString()return 'Tags: preview\n'end
    for _,fn in ipairs(hooks[prefab]or{})do fn(inst)end
    return inst
end
EntUtil={NullName='preview',GetTags=function()return{}end,GetPrefabName=function(_,name)return name end}
local templates={'researchlab4','researchlab3','researchlab','researchlab2'}
Prefabs={};for _,name in ipairs(templates)do Prefabs[name]=true end
Mod_ShroomMilk={PrefabCopy={}};PrefabImage={};PrefabsBug={};SpawnPrefab=station
t_util={Pairs=function(_,t,fn)for k,v in pairs(t)do fn(k,v)end end}
assert(loadstring(clone_source))()
for _,name in ipairs(templates)do
    TheWorld.ismastersim=false;TheWorld.components={};TheNet.GetIsServer=function()return false end
    local ok,why=pcall(EntUtil.ClonePrefab,EntUtil,name)
    check(ok,'client recipe preview removal must not crash: '..name)
    check(not TheWorld.ismastersim and not MOD_SRM_LOCK,'foreign preview restores client mode after removal')
    check(sent==0,'preview never sends server station updates')
    -- Even a spoofed client with a table cannot remove real-looking entries.
    TheWorld.ismastersim=true
    local preview=station(name)
    local index={['1']={[tostring(preview.GUID)]='keep'}}
    TheWorld.components={persistent2hm={data={reskinprototyper2hm=index}}}
    preview.events.onburnt();preview:Remove()
    check(index['1'][tostring(preview.GUID)]=='keep'and sent==0,'client cleanup has no authority to mutate station index')
    TheNet.GetIsServer=function()return true end
    local real=station(name);local id=tostring(real.GUID)
    local entries={[id]='real',other='keep'}
    TheWorld.components={persistent2hm={data={reskinprototyper2hm={['1']=entries,['2']={other='peer'}}}}}
    local before=sent;real.events.onburnt();real:Remove()
    check(entries[id]==nil and entries.other=='keep','real removal clears only its own station entry')
    check(sent==before+1,'burn then remove broadcasts exactly once')
    TheWorld.components={};check(pcall(real.Remove,real),'server world without persistent data is safe')
    TheWorld.components={persistent2hm={}};check(pcall(real.Remove,real),'missing persistent data table is safe')
    TheWorld.components={persistent2hm={data={}}};real:Remove()
    check(TheWorld.components.persistent2hm.data.reskinprototyper2hm==nil,'unregistered preview does not create an empty index')
    TheWorld.components={persistent2hm={data={reskinprototyper2hm={['1']={[id]='keep'}}}}}
    real.persists=false;real:Remove()
    check(TheWorld.components.persistent2hm.data.reskinprototyper2hm['1'][id]=='keep','nonpersistent server preview is ignored')
    sent=0
end
print('Prototyper preview compatibility checks:',checks)
