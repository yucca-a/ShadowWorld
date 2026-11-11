local G=GLOBAL
G.setmetatable(env,{__index=function(_,k)return G.rawget(G,k)end})
local json=require('json')
local function emit(row)row.shard=tostring(TheShard:GetShardId());print('[VAUDIT] '..json.encode(row))end
local serialize=G.SerializeWorldSession
G.SerializeWorldSession=function(data,session,cb,...)
 return serialize(data,session,function(...)emit({kind='archive_saved'});if cb then cb(...)end end,...)
end
local function contents(e)
 local items={}
 if e and e:IsValid() then
  for slot,item in pairs(e.components.container.slots)do
   items[tostring(slot)]={prefab=item.prefab,count=item.components.stackable and item.components.stackable:StackSize()or 1,
    uses=item.components.finiteuses and item.components.finiteuses:GetUses()}
  end
 end
 return items
end
G.XiInspect=function()
 local v=TheWorld.components.exchangevariants2hm;local b=TheWorld.components.shadowbank2hm
 local banks={}
 for mode,rows in pairs(v.banks)do
  banks[mode]={};for family,e in pairs(rows)do banks[mode][family]=contents(e)end
 end
 emit({kind='xi_state',ready=v.ready==true,error=v.error,mode=v.mode,banks=banks,
  shadow=contents(TheWorld:GetPocketDimensionContainer('shadow')),
  tackle=contents(TheWorld:GetPocketDimensionContainer('tacklestation2hm')),
  second=contents(v.second or TheWorld.shadowbanksecond2hm),tacklesecond=contents(v.tacklesecond or TheWorld.shadowbanktacklesecond2hm),
  pending=GetTableSize(b.transfer.pending),imports=#b.imports,mail=#b.mail,
  importrecords=b.imports,mailrecords=b.mail})
end
local function give(c,prefab,count,slot)
 local e=SpawnPrefab(prefab)
 if e.components.stackable then e.components.stackable:SetStackSize(count or 1)end
 if e.components.finiteuses then e.components.finiteuses:SetUses(count or 43)end
 assert(c:GiveItem(e,slot),'seed fits');return e
end
G.XiSeed=function()
 local b=TheWorld.components.shadowbank2hm;b:EnsureBanks()
 b.Update=function()end -- Keep deliberately full per-layer source inventories until the test save.
 local shadow=TheWorld:GetPocketDimensionContainer('shadow').components.container
 local tackle=TheWorld:GetPocketDimensionContainer('tacklestation2hm').components.container
 for slot=1,shadow.numslots do give(shadow,'axe',43,slot)end
 for slot=1,tackle.numslots do give(tackle,'seeds',7,slot)end
 if TheShard:IsMaster()then
  for slot=1,b:Bank(2).numslots do give(b:Bank(2),'spear',55,slot)end
  for slot=1,b:Bank(4).numslots do give(b:Bank(4),'pinecone',11,slot)end
 end
 local e=SpawnPrefab('tacklestation');e.Transform:SetPosition(0,0,0)
 -- Simulate an entrance saved while the extra tackle bank was selected.
 if TheShard:IsMaster()then e.components.container_proxy:SetMaster(TheWorld.shadowbanktacklesecond2hm)end
 emit({kind='seeded'})
end
G.XiOpen=function()
 local p=SpawnPrefab('wilson');p.userid='KU_XiClassicProbe'
 p.components.health:SetInvincible(true);p.components.hunger:SetRate(0)
 AllPlayers[#AllPlayers+1]=p
 local e
 for _,entity in pairs(Ents)do if entity.prefab=='tacklestation' then e=entity;break end end
 assert(e and e.components.container_proxy,'saved native tackle entrance exists')
 e.components.container_proxy:Open(p)
 assert(e.components.container_proxy:IsOpenedBy(p),'saved native tackle entrance opens')
 emit({kind='opened',canonical=e.components.container_proxy:GetMaster()==TheWorld:GetPocketDimensionContainer('tacklestation2hm')})
 e.components.container_proxy:Close(p);table.removearrayvalue(AllPlayers,p);p:Remove()
end
G.XiEmpty=function()
 local removed={}
 for _,family in ipairs({'shadow','tacklestation2hm'})do
  local c=TheWorld:GetPocketDimensionContainer(family).components.container
  for slot=1,c.numslots do local e=c:RemoveItemBySlot(slot,true);if e then
   removed[e.prefab]=(removed[e.prefab]or 0)+(e.components.stackable and e.components.stackable:StackSize()or 1);e:Remove()
  end end
 end
 emit({kind='emptied',removed=removed})
end
G.XiLoseAck=function()
 local send=TUNING.util2hm.ShadowBankSend
 TUNING.util2hm.ShadowBankSend=function(peer,data)if data.kind~='ack'then send(peer,data)end end
 emit({kind='faulted'})
end
G.XiPending=function()
 local b=TheWorld.components.shadowbank2hm
 local e=SpawnPrefab('goldnugget');e.components.stackable:SetStackSize(9)
 assert(b:SendItem(SHARDID.MASTER,e,'import',nil,2))
 emit({kind='queued'})
end
AddPrefabPostInit('world',function(inst)inst:DoTaskInTime(5,function()emit({kind='ready'})end)end)
