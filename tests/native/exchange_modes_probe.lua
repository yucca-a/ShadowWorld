local G=GLOBAL
G.setmetatable(env,{__index=function(_,key)return G.rawget(G,key)end})
local json=require("json")
local function emit(row)row.shard=tostring(TheShard:GetShardId());print("[VAUDIT] "..json.encode(row))end
local serialize=G.SerializeWorldSession
G.SerializeWorldSession=function(data,session,cb,...)
    return serialize(data,session,function(...)
        emit({kind="archive_saved"});if cb then cb(...)end
    end,...)
end
local function record(c)
    local items={}
    for slot,e in pairs(c.slots)do
        items[tostring(slot)]={prefab=e.prefab,count=e.components.stackable and e.components.stackable:StackSize()or 1,
            skin=e.skinname,pet=e.components.migrationpetowner and e.components.migrationpetowner:GetPet()and e.components.migrationpetowner:GetPet().prefab}
    end
    return items
end
G.ExchangeModeProbe=function()
    local variants=TheWorld.components.exchangevariants2hm
    local v=TheWorld.components.shadowvault2hm
    local banks={}
    for family,e in pairs(TheWorld.PocketDimensionContainers)do
        if family:find("legacycontainer_KU_ExchangeModeProbe",1,true)==1 then
            assert(not next(e.components.container.slots),"test-only offline inventory is empty")
        else
        local row={kind="mode_bank",family=family,prefab=e.prefab,items=record(e.components.container),readonly=e.components.container.readonlycontainer==true}
        emit(row)
        banks[family]={prefab=e.prefab,slots=GetTableSize(e.components.container.slots),readonly=row.readonly}
        end
    end
    local owners=v.native and v.native.state.owners
    emit({kind="mode_state",mode=TUNING.EXCHANGE_MODE2HM,ready=variants.ready==true,migrated=variants.migrated,
        phase=variants.migration and variants.migration.phase,error=v.error or variants.error,owners=owners,banks=banks,
        protocol=v.protocol and v.protocol.active and v.protocol.active.phase,
        rows=v.rows and GetTableSize(v.rows),journal=v.journal and {ready=v.journal.ready,busy=v.journal.busy,error=v.journal.error},
        peers=v.transport and GetTableSize(v.transport.peers),states=variants.migration and variants.migration.states,
        retired=v.retired,namespace=v.journal_namespace})
end
G.ExchangeModeOpen=function(family,exchange)
    local p=SpawnPrefab("wilson");p.userid="KU_ExchangeModeProbe"..TheShard:GetShardId()
    p.Transform:SetPosition(0,0,0);p.components.health:SetInvincible(true);p.components.hunger:SetRate(0)
    if p.components.playervision then p.components.playervision:ForceNightVision(true)else p:AddTag("canseeindark")end
    AllPlayers[#AllPlayers+1]=p
    local e=SpawnPrefab("treasurechest");e.Transform:SetPosition(0,0,0)
    e:RemoveComponent("container");e:AddComponent("container_proxy")
    local base=TheWorld:GetPocketDimensionContainer(family)
    e.components.container_proxy:SetMaster(base);e.components.container_proxy:Open(p)
    assert(e.components.container_proxy:IsOpenedBy(p),"original native entrance opens")
    if not exchange then
        for slot,item in pairs(base.components.container.slots)do
            local c=base.components.container
            assert(c:RemoveItemBySlot(slot,true)==item,"native removal retains item identity")
            assert(c:GiveItem(item,slot)and c.slots[slot]==item,"native reinsertion retains item identity")
            break
        end
    end
    if exchange then TUNING.util2hm.ClassicExchange2hm(p,base)end
    TheWorld:DoTaskInTime(2,function()
        emit({kind="mode_opened",family=family,opened=e.components.container_proxy:IsOpenedBy(p),items=record(base.components.container)})
        e.components.container_proxy:Close(p);e:Remove();table.removearrayvalue(AllPlayers,p);p:Remove()
    end)
end
AddPrefabPostInit("world",function(inst)
    inst:DoTaskInTime(5,function()emit({kind="ready"})end)
end)
