local n=0
local function check(ok,message)n=n+1;assert(ok,message)end
TUNING={EXCHANGE_MODE2HM='classic',util2hm={ShadowBankSend=function()end}}
AllPlayers={};Ents={};GetTime=function()return 1 end
TheNet={GetSessionIdentifier=function()return 'test' end}
TheShard={IsMaster=function()return true end,GetShardId=function()return '1'end}
Shard_IsWorldAvailable=function()return true end
local serial=0
local function item(prefab,count)
 serial=serial+1
 local e={GUID=serial,prefab=prefab,components={inventoryitem={}},skinname='test_skin',health=73,nested={token='nested-reference'}}
 function e:IsValid()return not self.removed end
 function e:Remove()self.removed=true end
 if count then e.components.stackable={StackSize=function()return count end}end
 return e
end
local function box(size)
 serial=serial+1
 local e={GUID=serial,components={}}
 function e:IsValid()return true end
 function e:HasTag(tag)return self[tag]==true end
 local c={inst=e,numslots=size or 2,slots={},acceptsstacks=true}
 e.components.container=c
 function c:EnableReadOnlyContainer(on)self.readonlycontainer=on end
 function c:CanTakeItemInSlot(e,slot)return not self.reject and not self.readonlycontainer and slot<=self.numslots end
 function c:GiveItem(e,slot,_,drop)
  assert(drop==false,'migration never drops overflow')
  if self.fail or not self:CanTakeItemInSlot(e,slot)or self.slots[slot]then return false end
  self.slots[slot]=e;e.components.inventoryitem.owner=self.inst;return true
 end
 function c:RemoveItemBySlot(slot,keep)
  assert(not self.readonlycontainer and keep,'read-only source unlocked, whole stack retained')
  local e=self.slots[slot];self.slots[slot]=nil
  if e then e.components.inventoryitem.owner=nil end
  return e
 end
 return e
end
local function seed(c,e,slot)c.slots[slot or 1]=e;e.components.inventoryitem.owner=c.inst;return e end
local Recovery=require('exchangexianyurecovery2hm')
local source,target=box(),box();local a=seed(source.components.container,item('axe'),1)
source.components.container:EnableReadOnlyContainer(true)
local nested=a.nested
Recovery.Move(source,target)
check(target.components.container.slots[1]==a and a.nested==nested and a.skinname=='test_skin' and a.health==73,'entire individual entity preserved')
check(not next(source.components.container.slots) and source.components.container.readonlycontainer,'source emptied and frozen again')
Recovery.Move(source,target);check(target.components.container.slots[1]==a,'retries never copy entities')
local b=seed(source.components.container,item('spear'),1)
seed(target.components.container,item('axe'),2)
Recovery.Move(source,target);check(source.components.container.slots[1]==b,'full destination preserves overflow')
target.components.container.slots[2]=nil
for _,busy in ipairs({'exchangeloading2hm','containersendtask2hm','containerreceivetask2hm','exchangeconfirmtask2hm','dcs2hm'})do
 target[busy]=true;Recovery.Move(source,target);check(source.components.container.slots[1]==b,'original exchange in progress cannot absorb overflow: '..busy);target[busy]=nil
end
target.components.container.reject=true;Recovery.Move(source,target);check(source.components.container.slots[1]==b,'native item acceptance respected')
target.components.container.reject=nil;target.components.container.fail=true
Recovery.Move(source,target);check(source.components.container.slots[1]==b and b.components.inventoryitem.owner==source,'failed insertion restores original ownership')
check(source.components.container.readonlycontainer and not target.components.container.worldexchange_internal2hm,'failed insertion restores container flags')
target.components.container.fail=nil;Recovery.Move(source,target)
check(target.components.container.slots[2]==b,'capacity becoming available resumes restoration')
local stack=seed(source.components.container,item('seeds',120),1)
local seeds=box();seeds.components.container.acceptsstacks=false
Recovery.Move(source,seeds);check(source.components.container.slots[1]==stack,'non-stacking target never splits a saved stack')
seeds.components.container.acceptsstacks=true;Recovery.Move(source,seeds)
check(seeds.components.container.slots[1]==stack and stack.components.stackable:StackSize()==120,'overstacked item retains identity and full amount')
local world={components={},PocketDimensionContainers={shadow=target,tacklestation2hm=seeds}}
function world:GetPocketDimensionContainer(f)return self.PocketDimensionContainers[f]end
function world:SetPocketDimensionContainer(f,e)self.PocketDimensionContainers[f]=e end
function world:DoPeriodicTask(_,fn)return {Cancel=function()end,fn=fn}end
world.DoStaticPeriodicTask=world.DoPeriodicTask
TheWorld=world
local created={}
SpawnSaveRecord=function(record)
 if record.invalid then return end
 local e=item(record.prefab,record.count);created[#created+1]=e;return e
end
local Bank=require('components/shadowbank2hm')
local service=Bank(world);world.components.shadowbank2hm=service
service:OnLoad({version=1,imports={{bank=2,record={prefab='goldnugget',count=17}},{bank=4,record={prefab='pinecone',count=11}}}})
check(service:Recovering(),'disabled Xianyu service recovers its saved transfers in original mode')
Recovery.Imports(service);check(#service.imports==1 and seeds.components.container.slots[2].prefab=='pinecone','families recover independently; full shadow import retained')
target.components.container.slots[1]=nil;Recovery.Imports(service)
check(#service.imports==0 and target.components.container.slots[1].components.stackable:StackSize()==17,'record import delivered once room exists')
local sent={};service.transfer.io.send=function(peer,data)sent[#sent+1]=data end
world.components.exchangevariants2hm={ready=true}
local incoming={kind='transfer',stream='old-saved-stream',sequence=1,payload={kind='item',purpose='deposit',bank=2,record={prefab='goldnugget',count=9}}}
service:Packet('2',incoming);service:Packet('2',incoming)
check(#service.imports==1 and #sent==2,'lost acknowledgement replay acknowledges twice but imports once')
local persisted=service:OnSave();service=Bank(world);service:OnLoad(persisted)
service.transfer.io.send=function()end;service:Packet('2',incoming)
check(#service.imports==1,'native snapshot preserves deduplication receipts across restart')
service:Packet('2',{kind='transfer',stream='old-saved-stream',sequence=2,payload={kind='take',bank=2,uid='KU_offline'}})
check(service.transfer.received['2/old-saved-stream'].through==2 and #service.imports==1,'stale take acknowledged without new withdrawal')
local mail={kind='transfer',stream='old-saved-stream',sequence=3,payload={kind='item',purpose='withdraw',uid='KU_offline',record={prefab='axe'}}}
service:Packet('2',mail);service:Packet('2',mail);service:DeliverMail()
check(#service.mail==1 and service.mail[1].uid=='KU_offline','offline player return retained exactly once')
service:Packet('2',{kind='view',uid='KU_offline',session='stale',bank=2})
check(not next(service.remote),'recovery never re-enables old Xianyu UI')
local key=service.transfer:Queue('2',{kind='item',purpose='withdraw',uid='KU_offline',record={prefab='axe'}})
local message=service.transfer.pending[key]
service:Packet('2',{kind='ack',stream=message.stream,sequence=message.sequence})
check(not service.transfer.pending[key],'old outgoing transfer completes by acknowledgement without local reconstruction')
-- Legacy first/extra tackle refs, existing-original inventories and a world
-- already switched before this patch must all enter the same recovery path.
local Config=require('shadowvaultconfig2hm');Config.SpawnPage=function()return box()end
local Variants=require('components/exchangevariants2hm')
local function restore(previous,hasclassic,legacy)
 local first,second,tackle,extra=box(),box(),box(),box()
 local gold=seed(first.components.container,item('goldnugget',5));seed(second.components.container,item('axe'))
 seed(tackle.components.container,item('seeds',7));seed(extra.components.container,item('pinecone',11))
 local original=hasclassic and box()or nil
 if original then seed(original.components.container,item('log',3))end
 local all={};for _,e in ipairs({first,second,tackle,extra})do all[e.GUID]={entity=e}end
 if original then all[original.GUID]={entity=original}end
 world.PocketDimensionContainers={shadow=original or first,tacklestation2hm=tackle}
 world.shadowbanksecond2hm=second;world.shadowbanktacklesecond2hm=extra
 local saved={active=previous,banks={xianyu={shadow=first.GUID,tacklestation2hm=tackle.GUID}},second=second.GUID,tacklesecond=extra.GUID}
 if original then saved.banks.classic={shadow=original.GUID}end
 local v=Variants(world)
 v:Restore(all,legacy and {shadowbank2hm={version=1}}or {exchangevariants2hm=saved})
 check(v.ready and v.xianyu_restore,'Xianyu recovery ready: '..previous..'/'..tostring(legacy))
 check(v.tacklesecond==extra,'extra tackle container retained for legacy and modern saves')
 check(world.PocketDimensionContainers.shadow== (original or first),'existing original bank preserved, otherwise first real source reused')
 if original then check(original.components.container.slots[1].prefab=='log' and original.components.container.slots[2]==gold,'existing original contents never overwritten')end
 local data,refs=v:OnSave()
 check(data.xianyu_restore==true and data.second==second.GUID and data.tacklesecond==extra.GUID and #refs>=4,'overflow refs and boolean recovery marker persisted')
 return v
end
restore('xianyu',false,false);restore('xianyu',true,false);restore('classic',true,false);restore('xianyu',false,true)
local empty=box();world.PocketDimensionContainers={shadow=empty};world.shadowbanksecond2hm=nil;world.shadowbanktacklesecond2hm=nil
local proxy={SetMaster=function()error('unbound unrelated entrance must not be rebound to shadow')end,GetMaster=function()return nil end}
Ents={{components={container_proxy=proxy}}}
local v=Variants(world);v:Restore({[empty.GUID]={entity=empty}},{exchangevariants2hm={active='xianyu',banks={xianyu={shadow=empty.GUID}}}})
check(v.ready,'shard without extra banks leaves unbound unrelated entrances alone')
print('Xianyu -> original recovery: '..n..' checks passed')
