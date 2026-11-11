-- Disposable cluster only. Populates native shadow containers and uses real items.
local G=GLOBAL
G.setmetatable(env,{__index=function(_,key) return G.rawget(G,key) end})
local function log(...) print("[VAULT_NATIVE]",...) end
local function check(ok,why) assert(ok,"VAULT: "..why) end
local player,anchor,stage,started,seeded
local saves=0
local function goods(c)
    local result={}
    for slot,item in pairs(c.slots) do
        local components=item.components
        local nested=components.unwrappable and components.unwrappable.itemdata and components.unwrappable.itemdata[1]
        local stack=nested and nested.data and nested.data.stackable
        result[#result+1]=slot..":"..item.prefab..":"..(components.stackable and components.stackable:StackSize() or 1)
            ..":"..(components.finiteuses and components.finiteuses:GetUses() or "")
            ..":"..(nested and nested.prefab..":"..(stack and stack.stack or 1) or "")
    end
    table.sort(result);return table.concat(result,"|")
end
local serialize=G.SerializeWorldSession
G.SerializeWorldSession=function(...) saves=saves+1;return serialize(...) end
AddSimPostInit(function()
    local world=G.TheWorld
    if not world.ismastersim then return end
    if VAULT_SCENARIO=="migrate_cut" then
        VAULT_SCENARIO="migrate"
        if world.ismastershard then
            local v=world.components.shadowvault2hm
            local retire=v.RetireLegacy
            v.RetireLegacy=function(self)
                local old=world.components.worldexchange2hm
                local core=old and old.engine and old.engine.core
                if core and core.generation then
                    local all=true
                    for peer in pairs(core.members) do if peer~="1" and self.migrated_peers[peer]~=core.generation then all=false end end
                    if all then log("MIGRATION_CUT_READY");return false end
                end
                return retire(self)
            end
        end
    end
    local box=world:GetPocketDimensionContainer("shadow")
    check(box~=nil,"native shadow container exists")
    if VAULT_SCENARIO=="migrate" then log("BASELINE",G.TheShard:GetShardId(),goods(box.components.container)) end
    if (VAULT_SCENARIO=="transfer" or VAULT_SCENARIO=="cut") and not next(box.components.container.slots) then
        local item=G.SpawnPrefab(world.ismastershard and "goldnugget" or "rocks")
        item.components.stackable:SetStackSize(world.ismastershard and 17 or 29+tonumber(G.TheShard:GetShardId()))
        check(box.components.container:GiveItem(item,1),"seed native items")
    end
    seeded=true
    stage="import"
    local deadline=G.GetStaticTime()+220
    world:DoStaticPeriodicTask(.2,function()
        check(G.GetStaticTime()<deadline,"test timeout stage="..tostring(stage))
        local v=world.components.shadowvault2hm
        if VAULT_SCENARIO=="migrate" and v and not v.protocol and (not started or G.GetStaticTime()-started>10) then
            started=G.GetStaticTime()
            local old=world.components.worldexchange2hm
            log("MIGRATE_WAIT",old and old.engine and old.engine.core.phase,v.status)
        end
        if not v or not v.protocol then return end
        check(not v.error,"vault not in protected error: "..tostring(v.error))
        if v.protocol.active then check(not v.protocol.active.error,"transaction has no error: "..tostring(v.protocol.active.error)) end
        if VAULT_SCENARIO=="migrate" then
            if not started or G.GetStaticTime()-started>10 then
                started=G.GetStaticTime();log("MIGRATE_ACTIVE",v.id,v.cutover_durable,v.native_ready,v.migration_generation,G.TheNet:GetCurrentSnapshot())
            end
            if world.ismastershard and stage~="done" then
                for id=2,VAULT_SHARDS do if not v.registry[tostring(id)] or not v.registry[tostring(id)].imported then return end end
                for id=1,VAULT_SHARDS do log("MIGRATE_PAGE",tostring(id),goods(v.pages[tostring(id)].components.container)) end
                stage="done";G.SaveGame(false,function()log("PASS")end)
            elseif not world.ismastershard and v.imported and not v.protocol.active and stage~="done" then
                check(not next(box.components.container.slots),"legacy source emptied only after import")
                stage="done";log("MIGRATE_SOURCE_PASS")
            end
            return
        end
        if VAULT_SCENARIO=="recover" then
            if not v.protocol.active and stage~="done" then
                check(not next(v.rows),"recovered transfer has no unresolved escrow")
                if world.ismastershard then
                    local c=v.pages["2"].components.container
                    check(not c.slots[1] and c.slots[4] and c.slots[4].components.stackable:StackSize()==5,"interrupted deposit recovered once")
                    log("RECOVER_MASTER_PASS")
                else
                    check(v.imported and not next(v.base.components.container.slots),"recovered source has no second copy")
                    local file=G.TheNet:GetUserSessionFile(v.session,"KU_VaultProbe")
                    check(file~=nil,"native player profile retained")
                    G.TheNet:DeserializeUserSession(file,function(ok,raw)
                        check(ok and raw,"native profile readable")
                        local parsed,data=G.RunInSandboxSafe(raw)
                        check(parsed and data.data and data.data.inventory,"native profile parses")
                        local rocks,gold=0,0
                        for _,item in pairs(data.data.inventory.items or {}) do
                            if item.prefab=="rocks" then rocks=rocks+(item.data.stackable and item.data.stackable.stack or 1) end
                            if item.prefab=="goldnugget" then gold=gold+(item.data.stackable and item.data.stackable.stack or 1) end
                        end
                        check(rocks==31 and gold==0 and data.data.inventory.activeitem==nil,"player profile retains withdrawn stack and excludes deposited stack")
                        log("RECOVER_SECONDARY_PASS")
                    end)
                end
                stage="done"
            end
            return
        end
        if VAULT_SCENARIO=="reload" then
            if world.ismastershard then
                check(v.pages["2"] and v.registry["2"].imported,"persisted cave page restored")
                local c=v.pages["2"].components.container
                check(not c.slots[1] and c.slots[4] and c.slots[4].prefab=="goldnugget" and c.slots[4].components.stackable:StackSize()==5,"persisted goods restored once")
                if stage~="done" then
                    v:Register("3");v:Register("4")
                    check(v.pages["3"]~=v.pages["4"] and v.pages["3"]~=v.pages["2"],"four independent pages")
                    local p=G.SpawnPrefab("wilson");p.userid="KU_VaultGround"
                    local a=G.SpawnPrefab("treasurechest")
                    p.Transform:SetPosition(0,0,0);a.Transform:SetPosition(0,0,0)
                    check(v:Open(p,a,"2"),"native proxy opens cave page")
                    check(c:IsOpenedBy(p),"real container open recorded")
                    v:Close(p.userid)
                    check(not c:IsOpenedBy(p),"native proxy closes cleanly")
                    stage="done";log("RELOAD_MASTER_PASS")
                end
            elseif not v.protocol.active then
                check(v.imported and not next(v.base.components.container.slots) and not next(v.rows),"source resumes saved receipt without duplicating goods")
                if stage~="done" then stage="done";log("RELOAD_SECONDARY_PASS") end
            end
            return
        elseif VAULT_SCENARIO=="rollback" then
            check(world.ismastershard and not G.Shard_IsWorldAvailable("2"),"rollback runs with cave offline")
            local own=v.pages["1"].components.container.slots[1]
            local c=v.pages["2"].components.container
            check(c.slots[4] and c.slots[4].components.stackable:StackSize()==5,"offline cave page survives rollback")
            if stage=="import" then
                if own.components.stackable:StackSize()==18 then
                    log("ROLLBACK_PASS");stage="done";log("PASS")
                else
                    check(own.components.stackable:StackSize()==17,"initial rollback fixture")
                    stage="saving"
                    own.components.stackable:SetStackSize(18)
                    G.SaveGame(false,function()
                        own.components.stackable:SetStackSize(19)
                        G.SaveGame(false,function() log("ROLLBACK_REQUEST");G.WorldRollbackFromSim(1) end)
                    end)
                end
            end
            return
        end
        if not v.native_test_instrumented then
            v.native_test_instrumented=true
            if VAULT_SCENARIO=="cut" and not world.ismastershard then
                local send=v.protocol.Send
                v.protocol.Send=function(self,kind,...)
                    if kind=="RELEASE" and self.active.name:sub(1,1)=="D" then log("CUT_READY");return end
                    return send(self,kind,...)
                end
            end
            local notify=v.Notify
            v.Notify=function(self,uid,why) log("NOTIFY",self.id,why);return notify(self,uid,why) end
            local checkpoint=v.Checkpoint
            v.Checkpoint=function(self) log("CHECKPOINT",self.id,self.protocol.active and self.protocol.active.phase);return checkpoint(self) end
            local saved=v.OnSaved
            v.OnSaved=function(self,marker,...) log("SAVED",self.id,marker and marker.phase);return saved(self,marker,...) end
            if world.ismastershard then
                local send=v.transport.Send
                v.transport.Send=function(self,peer,m,...)
                    if m.kind=="CLOSED" and m.outcome=="done" and not self.dropped_test_ack then
                        self.dropped_test_ack=true;log("DROPPED_ACK");return
                    end
                    return send(self,peer,m,...)
                end
            end
        end
        if world.ismastershard then
            local allimported,alloffline=true,true
            for id=2,VAULT_SHARDS do
                if not v.registry[tostring(id)] or not v.registry[tostring(id)].imported then allimported=false end
                if G.Shard_IsWorldAvailable(tostring(id)) then alloffline=false end
            end
            if stage=="import" and allimported then
                local a,b=v.pages["1"].components.container,v.pages["2"].components.container
                check(a.slots[1] and a.slots[1].prefab=="goldnugget" and a.slots[1].components.stackable:StackSize()==17,"master native goods retained")
                check(b.slots[1] and b.slots[1].prefab=="rocks" and b.slots[1].components.stackable:StackSize()==31,"caves goods imported once")
                for id=3,VAULT_SHARDS do
                    local page=v.pages[tostring(id)]
                    check(page~=v.pages["2"] and page.components.container.slots[1].components.stackable:StackSize()==29+id,"independent additional shard goods")
                end
                log("IMPORT_PASS",saves)
                stage="transfer"
            elseif stage=="transfer" then
                local c=v.pages["2"].components.container
                if not c.slots[1] and c.slots[4] and not v.protocol.active then
                    check(c.slots[4].prefab=="goldnugget" and c.slots[4].components.stackable:StackSize()==5,"deposit exactly once")
                    stage="offline";log("READY_FOR_OFFLINE",saves)
                end
            elseif stage=="offline" and alloffline then
                local c=v.pages["2"].components.container
                check(not c.readonlycontainer and c.slots[4],"offline caves page remains accessible")
                local before=saves
                local item=c:RemoveItemBySlot(4,true)
                check(item and item.components.stackable:StackSize()==5,"offline page contains real original stack")
                check(c:GiveItem(item,4),"offline local deposit succeeds")
                check(saves==before,"offline local access does not request world save")
                for id=3,VAULT_SHARDS do
                    local page=v.pages[tostring(id)].components.container
                    check(not page.readonlycontainer,"additional offline page remains writable")
                    local item=page:RemoveItemBySlot(1,true)
                    check(item.components.stackable:StackSize()==29+id and page:GiveItem(item,1),"additional offline page retains its exact goods")
                end
                log("OFFLINE_PASS",saves)
                stage="done"
                G.SaveGame(false,function() log("PASS") end)
            end
        else
            if stage=="import" and v.imported and not v.protocol.active then
                check(not next(v.base.components.container.slots),"secondary old chest empty after import")
                if v.id~="2" then stage="done";log("EXTRA_SHARD_IMPORT_PASS",v.id);return end
                player=G.SpawnPrefab("wilson");player.userid="KU_VaultProbe"
                anchor=G.SpawnPrefab("treasurechest")
                player.Transform:SetPosition(0,0,0);anchor.Transform:SetPosition(0,0,0)
                v.views[player.userid]={anchor=anchor,page="2"}
                v:Refresh(player.userid)
                stage="catalog"
            elseif stage=="catalog" and v.registry["2"] then
                for id=3,VAULT_SHARDS do if not v.registry[tostring(id)] or not v.registry[tostring(id)].imported then return end end
                v:Action(player,"withdraw","2",1)
                check(v.protocol.active,"withdraw starts transaction")
                stage="withdraw"
            elseif stage=="withdraw" and not v.protocol.active and not next(v.rows) then
                local n=0
                for _,item in pairs(player.components.inventory.itemslots) do if item.prefab=="rocks" then n=n+item.components.stackable:StackSize() end end
                check(n==31,"withdraw delivers exactly one stack")
                local gold=G.SpawnPrefab("goldnugget");gold.components.stackable:SetStackSize(5)
                player.components.inventory:GiveActiveItem(gold)
                v:Action(player,"deposit","2",4)
                check(v.protocol.active,"deposit starts transaction")
                stage="deposit"
            elseif stage=="deposit" and not v.protocol.active and not next(v.rows) then
                check(not player.components.inventory:GetActiveItem(),"deposit removed source stack")
                log("TRANSFER_PASS",saves)
                stage="done"
            end
        end
    end)
end)
