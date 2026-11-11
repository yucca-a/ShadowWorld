-- Disposable native clusters only; both submitted implementations stay unchanged.
local G=GLOBAL
G.setmetatable(env,{__index=function(_,key)return G.rawget(G,key)end})
local json=require("json")
local variant=GetModConfigData("variant")
local A={players={},anchors={},fault="none",sent=0,dropped=0,duplicated=0,saves=0,ready=false}
G.VaultAudit=A
local function emit(data)
    data.shard=tostring(TheShard:GetShardId());data.time=GetStaticTime()
    print("[VAUDIT] "..json.encode(data))
end
local function valid(e)return e and e:IsValid()end
local function qty(e)return e.components.stackable and e.components.stackable:StackSize() or 1 end
local function service()return TheWorld.components[variant=="xianyu" and "shadowbank2hm" or "shadowvault2hm"]end
local function record(item)
    local c=item.components
    return {prefab=item.prefab,count=qty(item),uses=c.finiteuses and c.finiteuses:GetUses() or nil,
        percent=c.armor and c.armor:GetPercent() or nil,skin=item.skinname,
        padding=c.vaultauditmark and c.vaultauditmark.padding and #c.vaultauditmark.padding or nil,
        nested=c.unwrappable and c.unwrappable.itemdata or nil}
end
local wire=G.SendModRPCToShard
G.SendModRPCToShard=function(rpc,peer,...)
    local channel=GetShardModRPC("MOD_HARDMODE",variant=="xianyu" and "shadowbank2hm" or "shadowvault_v1")
    if A.wirefault and rpc.namespace==channel.namespace and rpc.id==channel.id then
        A.wires=(A.wires or 0)+1
        if A.wires%13==0 then A.wiredrops=(A.wiredrops or 0)+1;return end
    end
    return wire(rpc,peer,...)
end
function A.wireloss(on)A.wirefault=on;emit({kind="wirefault"})end
AddPrefabPostInitAny(function(inst)
    if TheWorld.ismastersim and inst.components.inventoryitem then inst:AddComponent("vaultauditmark")end
end)
local serializeworld=G.SerializeWorldSession
G.SerializeWorldSession=function(data,session,cb,metadata)
    return serializeworld(data,session,function(...)
        A.saves=A.saves+1;emit({kind="saved",snapshot=TheNet:GetCurrentSnapshot()})
        if cb then cb(...)end
    end,metadata)
end
function A.bank(number)
    local v=service()
    if not TheWorld.ismastershard then return end
    if variant=="xianyu" then return v:Bank(number or 2)end
    local page=v.pages[tostring(number or 2)]
    return page and page.components.container
end
local function busy()
    local v=service();local n=0
    if variant=="xianyu" then
        for _ in pairs(v.transfer.pending)do n=n+1 end
        return n+#v.mail+#v.imports
    end
    for _ in pairs(v.rows)do n=n+1 end
    for _ in pairs(v.journal and v.journal.mail or {})do n=n+1 end
    if v.journal and (v.journal.busy or v.journal.staging) then n=n+1 end
    return n
end
function A.inspect(label)
    local v=service();local goods,locations,details={}, {},{}
    for _,e in pairs(Ents)do
        local mark=e.components.vaultauditmark
        if mark and mark.token and valid(e) and not e.shadowvault_preview2hm then
            goods[mark.token]=(goods[mark.token] or 0)+qty(e)
            details[#details+1]={token=mark.token,data=record(e)}
            local owner=e.components.inventoryitem.owner
            local where=owner and (owner.userid or owner.prefab) or "ground"
            locations[where]=(locations[where] or 0)+qty(e)
        end
    end
    local banks={}
    if TheWorld.ismastershard then
        if variant=="hosted" then
            for id,page in pairs(v.pages or {})do
                banks[id]={}
                for slot,item in pairs(page.components.container.slots)do banks[id][tostring(slot)]=record(item)end
            end
        else
            for i=1,2 do banks[tostring(i)]={};local c=A.bank(i)
                if c then for slot,item in pairs(c.slots)do banks[tostring(i)][tostring(slot)]=record(item)end end
            end
        end
    end
    emit({kind="state",label=label,goods=goods,locations=locations,details=details,banks=banks,
        pending=busy(),phase=v.protocol and v.protocol.active and v.protocol.active.phase,
        journalrevision=v.journal and v.journal.store.state and v.journal.store.state.revision,
        journalbusy=v.journal and v.journal.busy,
        snapshotphase=v.snapshot and v.snapshot.core.phase,
        runtimeboot=v.transport and v.transport.boot,
        snapshotcut=v.snapshot and v.snapshot.core.loaded,
        error=v.error or v.protocol and v.protocol.active and v.protocol.active.error,
        saves=A.saves,snapshot=TheNet:GetCurrentSnapshot(),sent=A.sent,dropped=A.dropped,duplicated=A.duplicated,
        wires=A.wires,wiredrops=A.wiredrops})
end
function A.player(index)
    local p=A.players[index]
    if valid(p)then return p end
    p=SpawnPrefab("wilson");p.userid="KU_VA_"..TheShard:GetShardId().."_"..index
    p.Transform:SetPosition(0,0,0)
    p.components.health:SetInvincible(true)
    p.components.hunger:SetRate(0)
    A.players[index]=p
    return p
end
function A.open(index,number)
    local p=A.player(index);local v=service()
    if variant=="xianyu" then
        p.shadowbanknumber2hm=number or 2
        if not p.components.magician then p:AddComponent("magician")end
        if not p.components.magician.item then
            local hat=SpawnPrefab("tophat")
            hat:ConvertToMagician()
            assert(p.components.magician:StartUsingTool(hat),"audit hat opens")
        end
        if not TheWorld.ismastershard then v:RemoteOpen(p,number or 2)end
    else
        if not valid(A.anchors[index])then A.anchors[index]=SpawnPrefab("treasurechest");A.anchors[index].Transform:SetPosition(0,0,0)end
        v:Open(p,A.anchors[index],tostring(number or 2))
    end
    local c=TheWorld.ismastershard and A.bank(number or 2)
    emit({kind="opened",index=index,physical_open=c and c:IsOpenedBy(p) or nil})
end
function A.localroundtrip(index,number,slot)
    local p=A.player(index);local c=A.bank(number)
    assert(c and c:IsOpenedBy(p),"real page opened while secondary offline")
    local item=c:RemoveItemBySlot(slot)
    assert(item,"offline page item exists")
    local original=qty(item)
    -- Native GiveItem without a destination may return a removed item to its
    -- still-open previous container. Model the explicit player-slot move.
    item.prevcontainer=nil;item.prevslot=nil
    assert(p.components.inventory:GiveItem(item,1),"offline withdraw")
    assert(item.components.inventoryitem.owner==p and qty(item)==original,"offline actual player custody")
    item=p.components.inventory:RemoveItem(item,true)
    assert(c:GiveItem(item,slot),"offline deposit")
    assert(c.slots[slot]==item and qty(item)==original,"offline exact return")
    emit({kind="local_roundtrip"})
end
function A.unfill(index)
    local inv=A.player(index).components.inventory
    for _,item in pairs(inv.itemslots)do
        if not item.components.vaultauditmark.token then item:Remove()end
    end
    local active=inv:GetActiveItem()
    if active and not active.components.vaultauditmark.token then active:Remove()end
    emit({kind="unfilled"})
end
function A.seed(where,index,prefab,amount,token,slot)
    local e=SpawnPrefab(prefab)
    assert(e and e.components.vaultauditmark,"audit item component exists")
    e.components.vaultauditmark.token=token
    if e.components.stackable then e.components.stackable:SetStackSize(amount)end
    if e.components.finiteuses then e.components.finiteuses:SetUses(amount)end
    if where=="bank" then
        local c=A.bank(index);local readonly=c.readonlycontainer;c:EnableReadOnlyContainer(false)
        assert(c:GiveItem(e,slot),"audit bank seed");c:EnableReadOnlyContainer(readonly)
        if service().journal then service().journal:Flush() end
    else assert(A.player(index).components.inventory:GiveItem(e),"audit player seed")end
    emit({kind="seeded",token=token})
end
function A.richseed()
    local bundle=SpawnPrefab("bundle");bundle.components.vaultauditmark.token="bundle"
    bundle.components.vaultauditmark.padding=string.rep("V",100000)
    local gold=SpawnPrefab("goldnugget");gold.components.stackable:SetStackSize(23)
    local axe=SpawnPrefab("axe");axe.components.finiteuses:SetUses(31)
    bundle.components.unwrappable:WrapItems({gold,axe});gold:Remove();axe:Remove()
    assert(A.bank(2):GiveItem(bundle,4))
    local armor=SpawnPrefab("armorwood");armor.components.vaultauditmark.token="armor"
    armor.components.armor:SetPercent(.37);assert(A.bank(2):GiveItem(armor,5))
    emit({kind="rich_seeded"})
end
function A.cache(index,slot)
    local v=service();local p=A.player(index)
    local view=variant=="xianyu" and v.viewers[p.userid] or v.views[p.userid]
    if variant=="xianyu" then A.cached=view and view.snapshot and view.snapshot.items[slot] and view.snapshot.items[slot].token
    else A.cached=view and view.catalog and view.catalog.items[tostring(slot)] and view.catalog.items[tostring(slot)].token end
    A.cachedsession=view and view.session
    emit({kind="cached"})
end
function A.swap()
    local c=A.bank(2);local a=c:RemoveItemBySlot(1);local b=c:RemoveItemBySlot(2)
    assert(c:GiveItem(b,1));assert(c:GiveItem(a,2));emit({kind="swapped"})
end
function A.cachedaction(index,slot)
    local v=service();local p=A.player(index)
    if variant=="xianyu" then local view=v.viewers[p.userid];v:Action(p,"take",slot,A.cached,"inventory",view.session)
    else v:Action(p,"withdraw","2",slot,A.cached,A.cachedsession)end
    emit({kind="cached_action"})
end
function A.action(index,op,slot,mode)
    local p=A.player(index);local v=service()
    if op=="deposit"then
        local inv=p.components.inventory
        if not inv:GetActiveItem()then
            for _,e in pairs(inv.itemslots)do
                if e.components.vaultauditmark and e.components.vaultauditmark.token then
                    local item=inv:RemoveItem(e,true);inv:GiveActiveItem(item);break
                end
            end
        end
    end
    if variant=="xianyu"then
        local view=v.viewers[p.userid]
        local entry=view and view.snapshot and view.snapshot.items[slot]
        v:Action(p,op=="withdraw" and "take" or op,slot,entry and entry.token or "",mode or "inventory",view and view.session)
    else
        local view=v.views[p.userid]
        local cat=view and view.catalog
        local item=cat and cat.items[tostring(slot)]
        local held=p.components.inventory:GetActiveItem()
        v:Action(p,op,view and view.page,slot,item and item.token or cat and cat.emptytoken,view and view.session,held,held and qty(held))
    end
    emit({kind="action",index=index,op=op,slot=slot,pending=busy()})
end
function A.setfault(kind)
    A.fault=kind;A.sent=0;emit({kind="fault",mode=kind})
end
local function inject(send,peer,message)
    A.sent=A.sent+1
    local n=A.sent
    if A.fault=="blackhole" or (A.fault=="loss" and n%5==0) or
        (A.fault=="exchange_blackhole" and (message.v==2 or message.v==4)) or
        (A.fault=="snapshot_capture" and message.kind=="SNAPSHOT" and message.op=="CAPTURE") or
        (A.fault=="snapshot_commit" and message.kind=="SNAPSHOT" and message.op=="COMMIT") or
        (A.fault=="ackloss" and (message.kind=="ack" or message.kind=="CLOSED"))then A.dropped=A.dropped+1;return end
    if A.fault=="reorder"then
        local frozen=deepcopy(message)
        TheWorld:DoStaticTaskInTime(n%3==0 and .7 or .04,function()send(peer,frozen)end)
    else send(peer,message)end
    if A.fault=="duplicate" or (A.fault=="loss" and n%7==0)then
        A.duplicated=A.duplicated+1
        TheWorld:DoStaticTaskInTime(.12,function()send(peer,deepcopy(message))end)
    end
end
function A.save()
    SaveGame(false,function()emit({kind="explicit_saved"})end)
end
function A.cluster_save()TheWorld:PushEvent("ms_save")end
function A.rollback()WorldRollbackFromSim(1)end
function A.restore(index)
    local uid="KU_VA_"..TheShard:GetShardId().."_"..index
    local path=TheNet:GetUserSessionFile(TheWorld.meta.session_identifier,uid)
    if not path then A.player(index);emit({kind="restored",index=index,found=false});return end
    TheNet:DeserializeUserSession(path,function(ok,raw)
        assert(ok and raw,"audit saved player readable")
        local parsed,data=RunInSandboxSafe(raw);assert(parsed and data.data,"audit saved player parses")
        local p=A.player(index)
        p:SetPersistData(data.data)
        p.components.health:SetInvincible(true);p.components.hunger:SetRate(0)
        emit({kind="restored",index=index,found=true})
    end)
end
function A.fill(index)
    local p=A.player(index)
    for i=1,p.components.inventory.maxslots do
        if not p.components.inventory.itemslots[i]then p.components.inventory:GiveItem(SpawnPrefab("axe"),i)end
    end
    if not p.components.inventory:GetActiveItem()then p.components.inventory:GiveActiveItem(SpawnPrefab("axe"))end
    emit({kind="filled"})
end
function A.disconnect(index)
    local p=A.players[index]
    if valid(p)then p:OnDespawn();SerializeUserSession(p);p:Remove();A.players[index]=nil end
    emit({kind="player_disconnected",index=index})
end
AddShardModRPCHandler("VaultAudit","migrant",function(peer,raw)
    local ok,envelope=RunInSandboxSafe(raw);assert(ok,"migrant fixture parses")
    local p=SpawnPrefab(envelope.record.prefab);p.userid=envelope.uid;p:AddComponent("playercontroller")
    A.players[envelope.index]=p
    ResumeExistingUserSession(envelope.record,p.GUID)
    p.components.health:SetInvincible(true);p.components.hunger:SetRate(0)
    SerializeUserSession(p)
    emit({kind="migrant_arrived",userid=p.userid,index=envelope.index})
end)
require("worldexchangerpc2hm").Install(G,GetShardModRPC("VaultAudit","migrant"),GetShardModRPCHandler("VaultAudit","migrant"))
local serializeuser=G.SerializeUserSession
G.SerializeUserSession=function(p,isnew)
    local result=serializeuser(p,isnew)
    local target=A.bridging and A.bridging[p.userid]
    if target and p.migration then
        local uid=p.userid;A.bridging[uid]=nil
        TheWorld:DoStaticTaskInTime(.1,function()
            local path=TheNet:GetUserSessionFile(TheWorld.meta.session_identifier,uid)
            TheNet:DeserializeUserSession(path,function(ok,raw)
                local valid,data=RunInSandboxSafe(raw);assert(ok and valid and (not service().snapshot or data.data.shadowvault_travel2hm),"native migration contains vault fence token")
                SendModRPCToShard(GetShardModRPC("VaultAudit","migrant"),target.world,
                    DataDumper({uid=uid,record=data,index=target.index},nil,true))
                emit({kind="migrant_departed",userid=uid})
            end)
        end)
    end
    return result
end
function A.migrate(index,world,targetindex)
    local p=A.player(index)
    if not p.components.playercontroller then p:AddComponent("playercontroller") end
    A.bridging=A.bridging or {};A.bridging[p.userid]={world=tostring(world),index=targetindex}
    TheWorld:PushEvent("ms_playerdespawnandmigrate",{player=p,worldid=tostring(world),x=0,y=0,z=0})
    emit({kind="migrate_requested",userid=p.userid})
end
function A.spawnpoint()
    local x,y,z=TheWorld.components.playerspawner:GetAnySpawnPoint()
    emit({kind="spawnpoint",x=x,y=y,z=z})
end
function A.history()
    local s=service().snapshot
    local committed,prepared=0,0
    for _,cut in pairs(s.store.state.cuts) do
        if cut.committed then committed=committed+1 else prepared=prepared+1 end
    end
    emit({kind="history",committed=committed,prepared=prepared,limit=s:RetentionLimit()})
end
function A.restoreuid(uid,index)
    local path=TheNet:GetUserSessionFile(TheWorld.meta.session_identifier,uid)
    if not path then emit({kind="profile",userid=uid,found=false});return end
    TheNet:DeserializeUserSession(path,function(ok,raw)
        local parsed,data=false,nil
        if ok and raw then parsed,data=RunInSandboxSafe(raw) end
        if not parsed or type(data)~="table" or not data.prefab then emit({kind="profile",userid=uid,found=false});return end
        local p=SpawnPrefab(data.prefab);p.userid=uid;A.players[index]=p;p:SetPersistData(data.data)
        p.components.health:SetInvincible(true);p.components.hunger:SetRate(0)
        emit({kind="profile",userid=uid,found=true})
    end)
end
function A.control(index,expectwait)
    local p=A.player(index)
    -- Scripted players have no client to keep their simulation island awake.
    p.entity:SetCanSleep(false)
    if not p.components.playercontroller then p:AddComponent("playercontroller") end
    p.components.playercontroller:Enable(true)
    local x,y,z=TheWorld.components.playerspawner:GetAnySpawnPoint()
    p.Physics:Teleport(x,y,z)
    local portal=SpawnPrefab("cave_exit");portal.Transform:SetPosition(x+1,y,z)
    portal.components.worldmigrator.linkedWorld="1"
    p.sg:GoToState("idle")
    p.bufferedaction=BufferedAction(p,portal,ACTIONS.MIGRATE)
    local failed=false
    p.bufferedaction:AddFailAction(function()failed=true end)
    p.sg:GoToState("migrate")
    TheWorld:DoStaticTaskInTime(2,function()
        emit({kind="control_state",state=p.sg.currentstate.name,asleep=p:IsAsleep(),animdone=p.AnimState:AnimDone(),
            waiting=p._shadowvault_departing==true,despawning=p._despawning==true})
        assert(p:IsValid() and not p._despawning,"failed migration must keep player present")
        assert(p.sg.currentstate.name~="migrate" and not p.sg:HasStateTag("busy"),"migration failure releases native busy state")
        assert(p.components.playercontroller:IsEnabled(),"player controls remain enabled")
        assert(not failed,"mod acknowledgement delay must not report a failed native portal action")
        assert((p._shadowvault_departing==true)==(expectwait==true),"exercise the intended pending or refused migration branch")
        local pos=p:GetPosition()
        local offset=FindWalkableOffset(pos,0,4,12,true,true)
        assert(offset,"movement fixture has a reachable ground point")
        p.components.locomotor:GoToPoint(pos+offset)
        TheWorld:DoStaticTaskInTime(2,function()
            local distance=p:GetDistanceSqToPoint(pos)
            assert(distance>1,"native locomotor moves after denied or pending migration")
            emit({kind="control_pass",state=p.sg.currentstate.name,moved_sq=distance,waiting=p._shadowvault_departing==true})
            portal:Remove()
        end)
    end)
end
AddSimPostInit(function()
    TheWorld:DoStaticPeriodicTask(5,function()
        if A.ready then return end
        local v=service()
        local boot=v and v.snapshot and v.snapshot.boot
        if variant=="hosted" then emit({kind="startup",status=v and v.status,error=v and v.error,
            protocol=v and v.protocol~=nil,loaded=boot and boot.loaded,bootready=boot and boot.ready,
            phase=v and v.snapshot and v.snapshot.core.phase,imported=v and v.imported}) end
    end)
    TheWorld:DoStaticPeriodicTask(.25,function()
        if A.ready then return end
        local v=service();if not v then return end
        if variant=="hosted"then
            v:Initialize();if not v.protocol then return end
            if not A.instrumented then
                A.instrumented=true
                local send=v.transport.Send
                v.transport.Send=function(self,peer,message)
                    inject(function(to,m)send(self,to,m)end,peer,message)
                end
            end
            if v.snapshot and (not v.snapshot.boot.ready or v.snapshot.core.phase~="ready") then return end
            if v.journal and (not v.journal.ready or v.journal.busy or v.journal.error) then return end
            if not TheWorld.ismastershard and (not v.imported or not v.native_ready or v.protocol.active)then return end
        else
            v:EnsureBanks()
            if not A.instrumented then
                A.instrumented=true
                local send=TUNING.util2hm.ShadowBankSend
                TUNING.util2hm.ShadowBankSend=function(peer,message)inject(send,peer,message)end
            end
        end
        A.ready=true;emit({kind="ready",variant=variant})
    end)
end)
