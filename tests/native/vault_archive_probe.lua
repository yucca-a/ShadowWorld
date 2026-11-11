local G=GLOBAL
G.setmetatable(env,{__index=function(_,key)return G.rawget(G,key)end})
local json=require("json")
local function emit(row)row.shard=tostring(TheShard:GetShardId());print("[VAUDIT] "..json.encode(row))end
local Native=require("shadowvaultnative2hm")
local display=Native.Display
function Native:Display(player,anchor,...)
    local ok=display(self,player,anchor,...)
    if player.userid and player.userid:find("VaultArchiveProbe",1,true)then
        emit({kind="display_trace",ok=ok,count=anchor.components.container_proxy.opencount})
    end
    return ok
end
local Adapter=require("shadowvaultitems2hm")
local snapshot=Adapter.Snapshot
local seen={}
local serialize=G.SerializeWorldSession
G.SerializeWorldSession=function(data,session,cb,metadata)
    return serialize(data,session,function(...)
        emit({kind="archive_saved"})
        if cb then cb(...)end
    end,metadata)
end
function Adapter:Snapshot(name,...)
    local data,why=snapshot(self,name,...)
    if not data then
        local entity=self:Container(name)
        if entity and not seen[entity]then
            seen[entity]=true
            local items={}
            for slot,item in pairs(entity.components.container.slots)do
                local ok,record,refs=pcall(item.GetSaveRecord,item)
                items[#items+1]={slot=slot,prefab=item.prefab,valid=item:IsValid(),persists=item.persists,
                    irreplaceable=item:HasTag("irreplaceable"),pet=item.components.migrationpetowner and item.components.migrationpetowner:GetPet()~=nil,
                    refs=ok and refs and #refs or 0,record=ok and record~=nil}
            end
            emit({kind="snapshot_rejected",reason=why,prefab=entity.prefab,items=items})
        end
    end
    return data,why
end
G.VaultArchiveProbe=function()
    local v=TheWorld.components.shadowvault2hm
    local t=v and v.protocol and v.protocol.active
    local rows,pages=0,{}
    if v then
        for _ in pairs(v.rows)do rows=rows+1 end
        for id,page in pairs(v.pages)do
            local count=0
            for _ in pairs(page.components.container.slots)do count=count+1 end
            pages[id]=count
        end
    end
    emit({kind="archive_state",error=v and v.error,journal_error=v and v.journal and v.journal.error,
        active=t and t.phase,transaction_error=t and t.error,rows=rows,pages=pages})
end
-- Separate rows keep large offline-player inventories below the log line limit.
G.VaultArchiveInventory=function()
    local v=TheWorld.components.shadowvault2hm
    for family,entity in pairs(TheWorld.PocketDimensionContainers)do
        if family:find("legacycontainer_KU_VaultArchiveProbe_",1,true)==1 then
            assert(not next(entity.components.container.slots),"test-only offline pockets must stay empty")
        elseif family:match("^legacycontainer_") or entity.prefab=="cloudpine_box_l4" then
            local items={}
            for slot,item in pairs(entity.components.container.slots)do
                local pet=item.components.migrationpetowner and item.components.migrationpetowner:GetPet()
                items[tostring(slot)]={prefab=item.prefab,count=item.components.stackable and item.components.stackable:StackSize()or 1,
                    pet=pet and pet.prefab or nil}
            end
            local id=require("shadowvaultconfig2hm").Page(v.id,family)
            emit({kind="archive_inventory",family=family,prefab=entity.prefab,items=items,
                managed=v.native.state.owners[id]~=nil,readonly=entity.components.container.readonlycontainer==true,
                retained=v.native.localonly and v.native.localonly[id] or nil})
        end
    end
    emit({kind="inventory_done"})
end
local opener,entrance,opening
G.VaultArchiveOpen=function(family,stale)
    assert(not entrance,"previous test entrance still open")
    opener=SpawnPrefab("wilson");opener.userid="KU_VaultArchiveProbe_"..TheShard:GetShardId()
    if not table.contains(AllPlayers,opener)then table.insert(AllPlayers,opener)end
    opener.Transform:SetPosition(0,0,0);opener.components.health:SetInvincible(true)
    opener.components.hunger:SetRate(0)
    -- Native containers close when the opener cannot see them in a dark cave.
    if not opener.Light then opener.entity:AddLight()end
    opener.Light:SetRadius(12);opener.Light:SetIntensity(.9);opener.Light:SetFalloff(.5)
    opener.Light:SetColour(1,1,1);opener.Light:Enable(true)
    if opener.components.playervision then opener.components.playervision:ForceNightVision(true)
    else opener:AddTag("canseeindark")end
    entrance=SpawnPrefab("treasurechest");entrance.Transform:SetPosition(0,0,0)
    entrance:RemoveComponent("container");entrance:AddComponent("container_proxy")
    entrance.components.container_proxy:SetMaster(TheWorld:GetPocketDimensionContainer(family))
    local proxy=entrance.components.container_proxy
    local close=proxy.Close
    function proxy:Close(player)
        local frames={}
        for level=2,10 do
            local info=debug.getinfo(level,"Sl")
            if not info then break end
            frames[#frames+1]=info.short_src..":"..info.currentline
        end
        emit({kind="close_trace",during_open=self.shadowvault_opening2hm==true,count=self.opencount,
            frames=frames})
        return close(self,player)
    end
    if stale then
        local cfg=require("shadowvaultconfig2hm")
        local old=cfg.SpawnPage(cfg.Page(tostring(TheShard:GetShardId()),family))
        entrance.components.container_proxy:SetMaster(old)
        old:Remove()
        assert(not old:IsValid() and old.replica.container.classified==nil,"same removed-master condition as crash log")
    end
    opening=family
    local accepted=entrance.components.container_proxy:Open(opener)
    emit({kind="archive_open_started",accepted=accepted})
end
G.VaultArchiveOpened=function(finish)
    local proxy=entrance.components.container_proxy
    local opened=proxy:IsOpenedBy(opener)
    local c=proxy:GetMaster().components.container
    local roundtrip=false
    if opened and opening=="cloudpine_l4" then
        for slot,item in pairs(c.slots)do
            if item.prefab=="refractedmoonlight" then
                assert(c:RemoveItemBySlot(slot)==item,"native removal preserves identity")
                assert(c:GiveItem(item,slot) and c.slots[slot]==item,"native insertion preserves identity")
                roundtrip=true;break
            end
        end
        assert(roundtrip,"expected retained protected item")
    end
    local v=TheWorld.components.shadowvault2hm
    local pending=v.native.shared.pending[opener.userid]
    emit({kind="archive_opened",family=opening,opened=opened,roundtrip=roundtrip,
        player_found=table.contains(AllPlayers,opener),distance=opener:GetDistanceSqToInst(entrance),
        access=v.native:CanAccess(opener,entrance),master_valid=proxy:GetMaster():IsValid(),
        cansee=CanEntitySeeTarget(opener,entrance),
        pending=pending and pending.page,view=v.views[opener.userid] and v.views[opener.userid].page,
        queue=#v.transport.outbox,ready=v.journal.ready,error=v.error})
    if not opened and not finish then return end
    proxy:Close(opener);entrance:Remove();table.removearrayvalue(AllPlayers,opener);opener:Remove()
    entrance,opener,opening=nil,nil,nil
end
AddPrefabPostInit("world",function(inst)
    inst:DoTaskInTime(5,function()emit({kind="ready"})end)
end)
