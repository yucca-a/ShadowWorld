local n=0
local function check(ok,message)n=n+1;assert(ok,message)end
local Mode=require("exchangemode2hm")
for _,old in ipairs({"off","classic","xianyu","hosted","coordinated","instant","fast",true,false,1,2,3})do
    check(Mode.Normalize(old)=="classic","legacy config must force original: "..tostring(old))
end
check(Mode.Normalize(nil)=="classic","missing setting defaults original")
for option,mode in pairs({original="classic",xianyu="xianyu",nexus="hosted",off="off"})do
    check(Mode.Normalize("exchange_v1_"..option)==mode,"explicit new choice retained")
end
check(Mode.Storage("hosted")=="hosted" and Mode.Storage("off")=="classic","runtime mode is not renormalized")
local tasks,queue,handlers={}, {},{}
TUNING={EXCHANGE_MODE2HM="classic",util2hm={},isCh2hm=true};FRAMES=1/30
TheNet={IsServerPaused=function()return false end}
Shard_IsWorldAvailable=function()return true end
local function box(item)
    local e={components={},tags={}}
    function e:IsValid()return true end
    function e:AddTag(t)self.tags[t]=true end
    function e:HasTag(t)return self.tags[t]end
    function e:RemoveTag(t)self.tags[t]=nil end
    local c={numslots=1,slots={[1]={prefab=item,IsValid=function()return true end,PushEvent=function()end}}};e.components.container=c
    function c:DestroyContents()self.slots={}end
    function c:OnSave()return {item=self.slots[1]and self.slots[1].prefab}end
    function c:OnLoad(data)check(type(data)=="table","native OnLoad needs decoded table");self.slots[1]=data.item and {prefab=data.item,IsValid=function()return true end,PushEvent=function()end}end
    function e:DoTaskInTime(delay,fn,...)
        local args={...};local t={fn=function()fn(self,unpack(args))end,delay=delay}
        function t:Cancel()self.cancelled=true end;tasks[#tasks+1]=t;return t
    end
    e.DoStaticTaskInTime=e.DoTaskInTime
    return e
end
local worlds={['1']={ismastersim=true,components={},box=box('goldnugget')},['2']={ismastersim=true,components={},box=box('cutstone')}}
local function selectworld(id)
    TheWorld=worlds[id];TheShard={GetShardId=function()return id end}
    ShardList={[id=='1'and'2'or'1']={}}
end
for _,w in pairs(worlds)do function w:GetPocketDimensionContainer(name)return self.PocketDimensionContainers[name]end;w.PocketDimensionContainers={shadow=w.box}end
AddShardModRPCHandler=function(_,name,fn)handlers[name]=fn end
GetShardModRPC=function(_,name)return name end
SendModRPCToShard=function(rpc,_,worldid,...)
    queue[#queue+1]={source=TheShard:GetShardId(),destination=worldid,rpc=rpc,args={worldid,...}}
end
assert(loadstring(classic_source))()
local player={components={talker={Say=function(_,s)player_speech=s end}},IsValid=function()return true end}
selectworld('1');TUNING.util2hm.ClassicExchange2hm(player,worlds['1'].box)
local function deliver()
    local m=table.remove(queue,1);selectworld(m.destination);handlers[m.rpc](m.source,unpack(m.args))
end
deliver()
selectworld('2');for _,t in ipairs(tasks)do if t.delay==FRAMES*1.5 and not t.cancelled then t:Cancel();t.fn()end end
deliver()
selectworld('1');for _,t in ipairs(tasks)do if t.delay==FRAMES*1.5 and not t.cancelled then t:Cancel();t.fn()end end
deliver()
check(worlds['1'].box.components.container.slots[1].prefab=='cutstone','original exchange receives cave item')
check(worlds['2'].box.components.container.slots[1].prefab=='goldnugget','original exchange receives surface item')
check(player_speech=='成功穿越世界2啦','original success speech')
selectworld('1');handlers.exchangeconfirmdata2hm('2','1','missing','bad')
check(true,'missing container callback does not crash')
-- Missing or incompatible messages must leave the local container untouched.
for _,mode in ipairs({'hosted','xianyu','off'})do
    TUNING.EXCHANGE_MODE2HM=mode;handlers.exchangesenddata2hm('2','1','shadow','return {time2hm=0}')
    check(worlds['1'].box.components.container.slots[1].prefab=='cutstone','inactive original RPC is inert')
end
TUNING.EXCHANGE_MODE2HM='classic'
for _,data in ipairs({'return true','return {}','return {time2hm="bad"}'})do
    handlers.exchangesenddata2hm('2','1','shadow',data)
    check(worlds['1'].box.components.container.slots[1].prefab=='cutstone','malformed original RPC is inert')
end
-- The migration must not release storage merely because the source journal
-- was flushed. Its ordinary native world save is the ownership boundary.
local Migration=require('exchangeoriginalmigration2hm')
local base=box('axe');base.GUID=9
function base.components.container:EnableReadOnlyContainer(on)self.readonlycontainer=on end
local inst={PocketDimensionContainers={shadow=base}}
function inst:SetPocketDimensionContainer(f,e)self.PocketDimensionContainers[f]=e end
local variants={inst=inst,banks={hosted={shadow=base}},migrating=true}
function variants:Freeze(e,on)e.components.container:EnableReadOnlyContainer(on)end
local m=Migration.new(variants)
local v={id='1',session='s',master=true,registry={['1']={}},rows={},pages={['1']=base},native_bases={shadow=base},protocol={},
    journal={ready=true,mail={},Flush=function(_,cb)cb(true)end},native={state={owners={['1']='1'}}},transport={peers={}}}
Ents={};SHARDID={MASTER='1'}
m:Prepare(v);check(m.phase=='prepared' and not variants.ready,'flush alone does not unlock')
m:Commit(v);check(m.phase=='committed' and variants.migrated and not variants.ready,'commit waits for world save')
check(inst.PocketDimensionContainers.shadow==base and base.components.container.slots[1].prefab=='axe','real item identity retained')
check(v.retired and v.journal_namespace=='sv4_s_exchange_v1','future Nexus cannot replay old journal')
m:Saved();check(variants.ready and not variants.migrating and not base.components.container.readonlycontainer,'save opens original storage')
v.journal.deliveries={old={state='held'}}
check(not m:Quiet(v),'offline held delivery is preserved, never silently retired')
check(Migration.HasReceipt({data={shadowvault_receipts2hm={old=true}}},'old'),'native player receipt proves prior delivery')
check(not Migration.HasReceipt({data={shadowvault_receipts2hm={different=true}}},'old'),'unrelated receipt never authorizes dropping a recovery claim')
GetStaticTime=function()return 0 end
v.journal.deliveries={old={state='held',userid='KU_old',payload={item='axe'}}};v.journal.issued={}
v.journal.Flush=function(_,cb)if cb then cb(true)end end
TheNet.GetUserSessionFile=function()return 'native_player_save' end
TheNet.DeserializeUserSession=function(_,file,cb)
    check(file=='native_player_save','migration reads native player session path')
    cb(true,DataDumper({data={shadowvault_receipts2hm={old=true}}},nil,true))
end
m:ResolveHeld(v)
check(v.journal.deliveries.old.state=='spent' and not v.journal.deliveries.old.payload,'already delivered offline goods need no login or duplicate refund')
v.journal.deliveries={};v.registry['2']={};v.transport.peers['2']={boot='current'}
v.native.state.owners['2']='2';m.phase='returning'
m.states['2']={phase='returning',quiet=true,home=true,boot='previous'}
check(not m:All(v,'returning'),'previous peer boot cannot confirm a new migration')
m.states['2'].boot='current'
check(m:All(v,'returning'),'all connected authoritative homes required')
v.native.state.owners['2']='1'
check(not m:All(v,'returning'),'foreign custody must return before original opens')
local Config=require('shadowvaultconfig2hm')
local Variants=require('components/exchangevariants2hm')
local serial=20
local function pocket(item)
    local e=box(item);serial=serial+1;e.GUID=serial
    function e.components.container:EnableReadOnlyContainer(on)self.readonlycontainer=on end
    return e
end
local function world(base)
    local w={PocketDimensionContainers={shadow=base},components={}}
    function w:GetPocketDimensionContainer(f)return self.PocketDimensionContainers[f]end
    function w:SetPocketDimensionContainer(f,e)self.PocketDimensionContainers[f]=e end
    function w:DoStaticPeriodicTask(_,fn)return {Cancel=function()end}end
    TheWorld=w;return w
end
Config.SpawnPage=function()return pocket(nil)end
local old=pocket('log');local w=world(old)
TUNING.EXCHANGE_MODE2HM='classic'
local service=Variants(w)
service:Restore({[old.GUID]={entity=old}},{shadowvault2hm={status='active',native_bases={shadow=old.GUID}}})
check(service.migrating and not service.ready,'legacy active Nexus must recover and auto-migrate')
local saved,refs=service:OnSave()
check(saved.migration_pending and saved.active=='hosted' and refs[1]==old.GUID,'ordinary save during migration retains source references')
local original=pocket('goldnugget');local nexus=pocket('cutstone');w=world(nexus)
local modern={active='hosted',banks={classic={shadow=original.GUID},hosted={shadow=nexus.GUID}}}
service=Variants(w);service:Restore({[original.GUID]={entity=original},[nexus.GUID]={entity=nexus}},{exchangevariants2hm=modern})
check(service.ready and not service.migrating and w.PocketDimensionContainers.shadow==original,'manual mode change never replaces established original inventory')
check(nexus.components.container.readonlycontainer and not original.components.container.readonlycontainer,'inactive bank frozen, original active')
saved=service:OnSave();TUNING.EXCHANGE_MODE2HM='hosted';w=world(original)
service=Variants(w);service:Restore({[original.GUID]={entity=original},[nexus.GUID]={entity=nexus}},{exchangevariants2hm=saved})
check(service.ready and w.PocketDimensionContainers.shadow==nexus and nexus.components.container.slots[1].prefab=='cutstone','returning to Nexus retains its distinct real inventory')
-- A pending migration must not trust IDs carried through a failed earlier boot.
TUNING.EXCHANGE_MODE2HM='off'
local function pending_world(journal,other)
    local base=pocket('log');base.prefab='shadow_container'
    local w=world(base)
    local s=Variants(w);s.probed=true;s.journal_legacy=journal
    local data={exchangevariants2hm={active='hosted',migration_pending=true,banks={hosted={shadow=999}}},
        shadowvault2hm={status='active',journal_version=4}}
    if other then data.exchangevariants2hm.banks.classic={shadow=998}end
    return s,w,base,data
end
service,w,base,saved=pending_world(true)
local tree={prefab='evergreen',components={},IsValid=function()return true end}
local private=pocket('rocks');private.prefab=base.prefab;private.userid='KU_offline'
service:Restore({[999]={entity=tree},[base.GUID]={entity=base},[private.GUID]={entity=private}},saved)
check(service.migrating and not service.ready and not service.error,'stale GUID can recover from the unfinished authoritative journal')
check(service.banks.hosted.shadow==base and service.journal_recovery_sources[base]=='shadow','real current source stays referenced and frozen until journal validation')
check(not service.journal_recovery_sources[tree] and not service.journal_recovery_sources[private],'ordinary entities and private offline storage are excluded')
check(base.components.container.readonlycontainer,'candidate contents cannot change while journal fingerprints are checked')
service,w,base,saved=pending_world(false)
service:Restore({},saved)
check(service.error=='missing_mechanism_container' and not service.ready,'missing journal never authorizes empty replacement or release')
service,w,base,saved=pending_world(true,true)
service:Restore({},saved)
check(service.error=='missing_mechanism_container' and not service.ready,'missing independent original bank is protected even when a Nexus journal exists')
service,w,base,saved=pending_world(true)
saved.exchangevariants2hm.migration_pending=nil
service:Restore({},saved)
check(service.error=='missing_mechanism_container' and not service.ready,'manual switches do not replay a historical journal')
service,w,base,saved=pending_world(true)
local wrong=pocket('cutstone');wrong.prefab='other_pocket'
service:Restore({[999]={entity=wrong},[base.GUID]={entity=base}},saved)
check(service.journal_recovery and service.banks.hosted.shadow==base,'reused GUID of another container family is rejected')
service,w,base,saved=pending_world(true)
base.GUID=4321
service:OnLoad(saved.exchangevariants2hm);service.probing=true
service:Restore({[999]={entity=base}},saved)
local persisted,refs=service:OnSave()
check(persisted.banks.hosted.shadow==4321 and refs[1]==4321,'save during asynchronous startup remaps the loaded GUID and returns its native reference')
check(service.saved.banks.hosted.shadow==999,'pending save does not mutate IDs needed by the unfinished load pass')
print('Three-mode regression: '..n..' checks passed')
