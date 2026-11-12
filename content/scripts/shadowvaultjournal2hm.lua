-- Independent warehouse journal. No world/player image restore, save request,
-- shutdown gate, or cross-shard recovery epoch exists in this module.
local Store=require("worldexchangestore2hm")
local Adapter=require("shadowvaultitems2hm")
local Config=require("shadowvaultconfig2hm")
local Journal={};Journal.__index=Journal
local function valid(e) return e and e:IsValid() end
local function proxy(v,entity)
    return {session=v.session,Container=function()return entity end,Validate=Adapter.Validate}
end
function Journal.Payload(v,entity,local_page) return Adapter.Snapshot(proxy(v,entity),"journal",local_page) end
local function clear(entity)
    if not valid(entity) then return end
    for _,item in pairs(entity.components.container.slots) do if valid(item) then item:Remove() end end
    entity:Remove()
end
local function inside(item,owner)
    local seen={}
    while item and not seen[item] do
        if item==owner then return true end
        seen[item]=true;item=item.components.inventoryitem and item.components.inventoryitem.owner
    end
    return false
end
local function ticketIn(record,id)
    if type(record)~="table" then return false end
    if record.shadowvaultticket2hm and record.shadowvaultticket2hm.id==id then return true end
    for _,value in pairs(record) do if type(value)=="table" and ticketIn(value,id) then return true end end
    return false
end
function Journal:Capture()
    local v=self.v
    local state={schema=4,registry=deepcopy(v.registry),imported=v.imported,tackle_imported=v.tackle_imported,extra_imported=deepcopy(v.extra_imported),pages={},rows={},
        native=v.native and v.native:Save() or nil,protocol=v.protocol:Save(),deposits=deepcopy(self.deposits),receipts=deepcopy(self.receipts),
        deliveries=deepcopy(self.deliveries),routes=deepcopy(v.delivery_routes or {}),mail=deepcopy(self.mail),mailsequence=self.mailsequence}
    for id,page in pairs(v.pages) do
        local payload,why
        if v.native and v.native.shared and v.master and v.native:Owns(id) and not v.native:Changing(id) then
            local active=v.protocol.active
            local row=active and v.rows[active.name]
            local epoch=v.native.state.epochs[id]or 0
            if v.native.checkpoint_epochs[id]~=epoch or row and row.page==id then
                payload,why=require("shadowvaultnative2hm").ExportPage(v,page)
                if payload then v.native.checkpoints[id]=payload;v.native.checkpoint_epochs[id]=epoch end
            else payload=v.native.checkpoints[id]end
        elseif v.native and v.native.state.owners[id] then payload=v.native.checkpoints[id]
        else payload,why=Journal.Payload(v,page,true) end
        if not payload then return nil,why or "missing_native_page_checkpoint" end
        state.pages[id]=payload
    end
    for name,row in pairs(v.rows) do
        local saved={}
        for key,value in pairs(row) do if key~="escrow" and key~="checking" then saved[key]=deepcopy(value) end end
        saved.prefab=row.escrow.prefab
        local payload,why
        if v.native and (row.op=="N" or row.op=="I") then payload,why=v.native:Snapshot(name)
        else payload,why=Journal.Payload(v,row.escrow) end
        if not payload then return nil,why end
        saved.payload=payload;state.rows[name]=saved
    end
    return state
end
function Journal:Flush(callback)
    callback=callback or function()end
    -- The migration preserves this journal as a pre-handoff recovery image.
    -- Old item observers must not rewrite it after native world ownership wins.
    if self.v.retired then callback(false);return end
    if self.error then callback(false);return end
    if self.busy then self.waiters[#self.waiters+1]=callback;self.again=true;return end
    if not self.ready then self.waiters[#self.waiters+1]=callback;return end
    local snapshot,why=self:Capture()
    if not snapshot then self.capture_error=why;self.error=why;self.v:Fail(why);callback(false);return end
    local raw=DataDumper(snapshot,nil,true)
    if raw==self.lastbody then callback(true);return end
    self.busy=true
    self.store:Update(function(state) state.vault=snapshot end,function(ok,reason)
        self.busy=nil
        if ok then self.lastbody=raw else self.error=reason;self.v:Fail(reason) end
        callback(ok)
        local waiting=self.waiters;self.waiters={}
        if self.again or #waiting>0 then
            self.again=nil
            self:Flush(function(saved)for _,fn in ipairs(waiting) do fn(saved) end end)
        end
    end)
end
-- Retry only a failed capture of the current live custody. Never load an older
-- bank, create missing items, or bypass a disk/checksum/ownership failure here.
function Journal:TryRecover()
    local why=self.capture_error
    local v=self.v
    if not why or self.error~=why or v.error~=why or not self.ready or
        self.busy or self.staging or self.recovering then return false end
    local now=GetStaticTime()
    if now<(self.nextrecovery or 0) then return false end
    self.nextrecovery=now+10
    local core=v.protocol
    local t=core and core.active
    if t and (t.error and t.error~="journal_write_failed" or not v.rows[t.name]) then return false end
    local snapshot=self:Capture()
    if not snapshot then return false end
    local previous=t and t.error
    if t then t.error=nil end
    local marker=core and core:Marker()
    self.error=nil;self.recovering=true
    self:Flush(function(ok)
        self.recovering=nil
        if not ok then
            if t then t.error=previous end
            return
        end
        self.capture_error=nil
        if v.error==why then v.error=nil end
        if core then core:OnSaved(marker);core.retry=0 end
        print("[ShadowVault2hm] recovered",v.id,why)
    end)
    return true
end
function Journal:Restore(saved)
    local v=self.v
    local variants=v.inst and v.inst.components and v.inst.components.exchangevariants2hm
    local recovery=variants and variants.journal_recovery_sources
    if saved.schema~=4 or type(saved.pages)~="table" or type(saved.rows)~="table" or
        type(saved.registry)~="table" or type(saved.protocol)~="table" or saved.protocol.mode~="journal" then
        return false,"invalid_vault_journal"
    end
    if saved.native and (saved.native.version~=1 or type(saved.native.owners)~="table" or type(saved.native.epochs)~="table") then
        return false,"invalid_native_page_directory"
    end
    if saved.protocol.active and not saved.rows[saved.protocol.active.name] then
        return false,"missing_transfer_record"
    end
    -- Materialize every replacement before removing any saved container. A
    -- missing prefab protects the vault instead of converting it into emptiness.
    local staged_pages,staged_rows={},{}
    local retained={}
    local function is_native(e) return e==v.base or e==v.tackle or retained[e] end
    local function discard()
        for _,p in pairs(staged_pages)do if not is_native(p) then clear(p)end end
        for _,r in pairs(staged_rows)do if not is_native(r.escrow) then clear(r.escrow)end end
    end
    local function spawn(prefab,payload,pageid)
        local e=pageid and Config.SpawnPage(pageid) or SpawnPrefab(prefab)
        if not e then return end
        local ok=require("shadowvaultnative2hm").RestoreMetadata(e,payload)
        if ok then ok=Adapter.Apply(proxy(v,e),"journal",payload) end
        if not ok then clear(e);return end
        return e
    end
    for id,payload in pairs(saved.pages or {}) do
        local native=saved.native
        local world=v.saved_native_world
        local active=saved.protocol.active
        local transfer=active and active.name and active.name:match("^N:"..id..":")
        local existing=v.pages[id]
        if not recovery and native and world and native.owners[id]==v.id and world.owners[id]==v.id and
            (native.epochs[id]==world.epochs[id] or native.shared and world.shared and
                (world.epochs[id]or 0)>(native.epochs[id]or 0)) and not transfer and valid(existing) then
            staged_pages[id]=existing
            retained[existing]=true
        else
            staged_pages[id]=spawn(Config.PagePrefab(id),payload,id)
        end
        if not staged_pages[id] then
            discard()
            return false,"journal_page_restore_failed"
        end
    end
    for name,row in pairs(saved.rows or {}) do
        local e
        if row.op=="N" then
            e=staged_pages[row.page]
            if not e then discard();return false,"native_transfer_page_missing" end
            local ok=Adapter.Apply(proxy(v,e),"journal",row.payload)
            if not ok then discard();return false,"native_transfer_restore_failed" end
        else
            e=spawn(row.op=="I" and Config.PagePrefab(row.page) or row.prefab or "shadowvaulttransfer2hm",row.payload,row.op=="I" and row.page or nil)
        end
        if not e then
            discard()
            return false,"journal_transfer_restore_failed"
        end
        local r=deepcopy(row);r.payload=nil;r.prefab=nil;r.escrow=e
        staged_rows[name]=r
    end
    if recovery then
        -- Missing GUIDs make native singleton registration ambiguous. An empty
        -- constructor must not override a nonempty authoritative journal page.
        -- Check every old real container before deleting any of them, including
        -- duplicates no longer referenced by the failed world's component data.
        local function fingerprint(payload,temperature)
            local items=payload.items
            if temperature then
                items=deepcopy(items)
                for _,record in pairs(items)do
                    local edible=record.data and record.data.edible
                    if edible and type(edible.chill)=="number" then edible.chill=nil end
                end
            end
            return DataDumper({items=items,layout=payload.layout,metadata=payload.metadata},nil,false)
        end
        local known,candidates,changing,claimed={},{},{},{}
        for _,row in pairs(saved.rows)do if row.page then changing[row.page]=true end end
        for id,payload in pairs(saved.pages)do
            local family=Config.Family(id);known[family]=known[family] or {}
            known[family][fingerprint(payload)]=true
            if saved.native and saved.native.owners[id]==v.id and not changing[id] then
                local key=family..":"..fingerprint(payload,true)
                -- Multiple identical pages cannot identify a particular source.
                if candidates[key]~=nil then candidates[key]=false else candidates[key]=id end
            end
        end
        for _,row in pairs(saved.rows)do
            local family=Config.Family(row.page or "")
            if row.payload then
                known[family]=known[family] or {};known[family][fingerprint(row.payload)]=true
            end
        end
        for entity,family in pairs(recovery)do
            if valid(entity) and next(entity.components.container.slots) then
                local payload=require("shadowvaultnative2hm").ExportPage(v,entity)
                local page=payload and candidates[family..":"..fingerprint(payload,true)]
                if page and not claimed[page] then
                    -- Native edible temperature can differ from the last journal
                    -- checkpoint. Keep the actual source and all its current data;
                    -- never erase that difference or manufacture another item.
                    local staged=staged_pages[page]
                    if staged~=entity and not is_native(staged) then clear(staged)end
                    staged_pages[page]=entity;retained[entity]=true;claimed[page]=true
                elseif not payload or not (known[family] and known[family][fingerprint(payload)]) then
                    discard();return false,"migration_source_conflict"
                end
            end
        end
    end
    local tacklepage=Config.TacklePage(v.id)
    local localpages={}
    for family in pairs(v.native_bases or {}) do localpages[#localpages+1]=Config.Page(v.id,family) end
    if #localpages==0 then localpages={v.id,tacklepage} end
    for _,id in ipairs(localpages) do
        local base=v:LocalBase(id)
        local payload=saved.pages[id]
        if saved.native and saved.native.owners[id] then
            local replacement=staged_pages[id]
            if valid(base) and valid(replacement) and base~=replacement then
                local family=Config.Family(id)
                v.native_bases[family]=replacement
                v.inst:SetPocketDimensionContainer(family,replacement)
                if family=="shadow" then v.base=replacement end
                if family=="tacklestation2hm" then v.tackle=replacement end
                for _,entity in pairs(Ents) do
                    local proxy=entity.components.container_proxy
                    if proxy and proxy:GetMaster()==base then proxy:SetMaster(replacement) end
                end
                if not retained[base] then clear(base)end
            end
        elseif v.master and valid(base) and (payload or id==v.id or id==tacklepage) then
            -- Unrecorded extra pockets have not entered journal custody yet.
            -- Native:Adopt must validate them before adding them to v.pages.
            local ok,why=true
            if payload then ok,why=Adapter.Apply(proxy(v,base),"journal",payload) end
            if not ok then
                discard()
                return false,why
            end
            clear(staged_pages[id]);staged_pages[id]=base
        elseif not v.master and valid(base) and ((id==v.id and saved.imported) or (id==tacklepage and saved.tackle_imported) or
            saved.extra_imported and saved.extra_imported[Config.Family(id)]) then
            local c=base.components.container
            local layout=tostring(c.numslots)..":"..tostring(c.infinitestacksize==true)..":"..
                tostring(c.acceptsstacks==true)..":"..tostring(c.usespecificslotsforitems==true)
            local ok,why=Adapter.Apply(proxy(v,base),"journal",{items={},layout=layout,session=v.session})
            if not ok then discard();return false,why end
        end
    end
    if not v.master then
        for name,row in pairs(staged_rows) do
            if row.op=="I" then
                local base=v:LocalBase(row.page)
                if not valid(base) then discard();return false,"import_container_missing" end
                local ok,why=Adapter.Apply(proxy(v,base),"journal",saved.rows[name].payload)
                if not ok then discard();return false,why end
                clear(row.escrow);row.escrow=base
            end
        end
    end
    -- Native saves may contain a newer, unacknowledged deposit. Preserve it as
    -- reviewable custody instead of destroying an item absent from the journal.
    for name,row in pairs(v.rows) do
        if not (saved.rows or {})[name] and not self.receipts[name] and not self.deposits[name] and
            (row.op=="D" or row.op=="P" or row.op=="S" or row.op=="Q" or row.op=="K") and
            next(row.escrow.components.container.slots) then
            row.state="uncertain";staged_rows[name]=row
        elseif not is_native(row.escrow) and row.op~="N" then clear(row.escrow) end
    end
    for id,page in pairs(v.pages) do
        local replacement=staged_pages[id]
        if page~=replacement and not is_native(page) then
            -- Non-canonical pages can also have native entrances. Repoint
            -- them before retiring the old entity during rollback recovery.
            if valid(replacement) then
                for _,entity in pairs(Ents)do
                    local proxy=entity.components.container_proxy
                    if proxy and proxy:GetMaster()==page then proxy:SetMaster(replacement) end
                end
            end
            clear(page)
        end
    end
    v.unresolved_pages,v.unresolved_rows={},{}
    v.pages,v.rows=staged_pages,staged_rows
    v.registry,v.imported=deepcopy(saved.registry or {}),saved.imported
    v.tackle_imported=saved.tackle_imported
    v.extra_imported=deepcopy(saved.extra_imported or {})
    if v.master and valid(v.tackle) and not v.registry[tacklepage] then
        v.registry[tacklepage]={name=v.registry[v.id] and v.registry[v.id].name or "Master",imported=true}
    end
    v.delivery_routes=deepcopy(saved.routes or {})
    v.reserved={}
    for name,row in pairs(v.rows) do if v.master and row.state=="active" then v:Reserve(name,row) end end
    for id,page in pairs(v.pages) do v:GuardPage(id,page);page.components.container:EnableReadOnlyContainer(true) end
    if recovery then
        for entity,family in pairs(recovery)do
            local replacement=v.native_bases[family]
            if valid(entity) and entity~=replacement and not retained[entity] then
                for _,entrance in pairs(Ents)do
                    local p=entrance.components.container_proxy
                    if p and p:GetMaster()==entity then p:SetMaster(replacement)end
                end
                clear(entity)
            end
        end
        variants.banks.hosted={}
        for family,entity in pairs(v.native_bases)do variants.banks.hosted[family]=entity end
        variants.journal_recovery_sources=nil
    end
    return true
end
function Journal.Attach(v)
    if v.journal then return v.journal end
    local IO=require("shadowvaultio2hm")
    if not ShardGameIndex then return end
    local self=setmetatable({v=v,waiters={},deposits={},receipts={},deliveries={},mail={},issued={}},Journal)
    v.journal=self
    for _,page in pairs(v.pages) do page.components.container:EnableReadOnlyContainer(true) end
    local store=Store.new(IO.New(ShardGameIndex),v.session);store.prefix=v.journal_namespace or "sv4_"..v.session
    self.store=store
    store:Load(function(state,why)
        if not state then self.error=why;v:Fail(why);return end
        local saved=state.vault
        if saved then
            self.deposits,self.receipts,self.deliveries,self.mail=deepcopy(saved.deposits or {}),deepcopy(saved.receipts or {}),deepcopy(saved.deliveries or {}),deepcopy(saved.mail or {})
            local ok,reason=self:Restore(saved)
            if not ok then self.error=reason;v:Fail(reason);return end
            self.mailsequence=saved.mailsequence or 0
        elseif v.journal_version==4 then
            self.error="missing_vault_journal";v:Fail(self.error);return
        elseif v.protocol.active then
            -- Unpublished older prototypes lack independent durability proof.
            -- Keep their items visible as held custody; do not guess an outcome.
            for _,row in pairs(v.rows) do row.state="uncertain" end
        end
        local io=v.protocol.io
        v.protocol=require("shadowvaultdurable2hm").new(io,saved and saved.protocol,self)
        v:BindFinalization();v.saved_protocol=nil;v.native_ready=true
        v.native=require("shadowvaultnative2hm").new(v,saved and saved.native,saved and saved.pages)
        v.native:Adopt()
        for _,page in pairs(v.pages) do page.components.container:EnableReadOnlyContainer(true) end
        self.ready=true;self:Flush()
    end)
    return self
end
function Journal:WritePlayer(player,callback)
    if not valid(player) then callback(false);return end
    if not pcall(SerializeUserSession,player) then callback(false);return end
    local file=TheNet:GetUserSessionFile(self.v.session,player.userid)
    if not file then callback(false);return end
    TheNet:DeserializeUserSession(file,function(ok,raw)
        local parsed,data=false,nil
        if ok and raw then parsed,data=RunInSandboxSafe(raw) end
        callback(parsed and type(data)=="table",data)
    end)
end
function Journal:ReconcilePlayer(player)
    if not self.ready or not valid(player) or not player.components.inventory then return end
    local changed=false;local remove={};local found={}
    player.components.inventory:ForEachItem(function(item)
        local tag=item.components.shadowvaultticket2hm
        local issued=item.components.shadowvaultissued2hm
        local delivery=issued and self.deliveries[issued.id]
        if (tag and self.deposits[tag.id]) or (type(delivery)=="table" and delivery.reason=="deposited") then
            remove[#remove+1]=item
        elseif issued then
            found[issued.id]=item
            if type(delivery)=="table" and delivery.state=="held" then self.issued[issued.id]=item end
        end
    end)
    for _,item in ipairs(remove) do
        local owner=item.components.inventoryitem and item.components.inventoryitem.owner
        local inv=owner and (owner.components.inventory or owner.components.container)
        local removed=inv and inv:RemoveItem(item,true)
        if removed then removed:Remove();changed=true end
    end
    if changed then self:WritePlayer(player,function()end) end
    local receipts=player.shadowvault_receipts2hm or {};player.shadowvault_receipts2hm=receipts
    for name,record in pairs(self.deliveries) do
        if type(record)=="table" and record.userid==player.userid and record.state=="held" and not self.v.rows[name] then
            if found[name] then receipts[name]=true
            elseif receipts[name] then
                record.state="spent";record.payload=nil
            elseif record.payload then
                -- Native startup truncates player files newer than the world.
                -- Restore only this still-held delivery, never a whole profile.
                local escrow=SpawnPrefab("shadowvaulttransfer2hm")
                if escrow then
                    local ok=Adapter.Apply(proxy(self.v,escrow),"journal",record.payload)
                    self.v.rows[name]={userid=record.userid,page=record.page,escrow=escrow,
                        state=ok and "delivery" or "uncertain",retained_payload=not ok and record.payload or nil}
                    record.state="recovering"
                end
            end
        end
    end
    self:Flush()
end
function Journal:Departing(uid)
    for name,record in pairs(self.deliveries) do
        if type(record)=="table" and record.userid==uid and record.state=="held" then
            record.state="spent";record.reason="migrated";record.payload=nil;self.issued[name]=nil
        end
    end
end
function Journal:IssuedChanged(name,item)
    local record=name and self.deliveries[name]
    if not self.ready or self.issued[name]~=item or type(record)~="table" or record.state~="held" then return end
    -- A stale before-image cannot authorize a refund after use or transfer.
    record.state="spent";record.payload=nil;self.issued[name]=nil
    self:Flush()
    if not self.refreshissued then self.refreshissued={} end
    self.refreshissued[name]=item
end
function Journal:RefreshIssued()
    if self.busy or self.staging or not self.ready or self.error then return end
    local pending=self.refreshissued or {};self.refreshissued={}
    local changed=false
    for name,item in pairs(pending) do
        local record=self.deliveries[name]
        if valid(item) and record and not record.reason then
            for _,player in ipairs(AllPlayers) do
                if player.userid==record.userid and not player._despawning and inside(item,player) then
                    local count=item.components.stackable and item.components.stackable:StackSize() or 1
                    if record.count and count>record.count then
                        -- A merge may include pre-existing inventory. Refunding
                        -- the combined stack would recreate those older goods.
                        record.reason="mixed_stack";changed=true;break
                    end
                    local preview=setmetatable({slots={[1]=item}},{__index=self.v.base.components.container})
                    preview.numslots=1;preview.infinitestacksize=false
                    local payload=Journal.Payload(self.v,{components={container=preview}})
                    if payload then record.payload=payload;record.count=count;record.state="held";self.issued[name]=item;changed=true end
                    break
                end
            end
        end
    end
    if changed then self:Flush() end
end
function Journal.CanStageDeposit(container,item)
    local readonly=container.readonlycontainer
    container:EnableReadOnlyContainer(false)
    local ok,allowed=pcall(container.CanTakeItemInSlot,container,item,1)
    container:EnableReadOnlyContainer(readonly)
    return ok and allowed
end
function Journal:StageDeposit(name,row,item,player,source,source_slot)
    local c=row.escrow.components.container
    if not Journal.CanStageDeposit(c,item) then
        clear(row.escrow);self.v:Notify(row.userid,"unsupported");return
    end
    local preview=setmetatable({slots={[1]=item}},{__index=row.escrow.components.container})
    local payload=Journal.Payload(self.v,{components={container=preview}})
    if not payload then clear(row.escrow);self.v:Notify(row.userid,"unsupported");return end
    self.staging=true
    local amount=item.components.stackable and item.components.stackable:StackSize() or 1
    item:AddComponent("shadowvaultticket2hm");item.components.shadowvaultticket2hm.id=name
    -- Persist a tagged before-image while the original is still in the player's
    -- custody. After a crash, only this deposited copy can be reconciled away.
    self:WritePlayer(player,function(ok,data)
        self.staging=nil
        local inventory=valid(player) and player.components.inventory
        local original
        if inventory then
            if not source then original=inventory:GetActiveItem()
            elseif source==inventory or source==inventory:GetOverflowContainer() then original=source:GetItemInSlot(source_slot) end
        end
        if not ok or not ticketIn(data,name) or not valid(player) or player._despawning or not valid(item) or
            original~=item or
            source and (source.readonlycontainer or item.components.inventoryitem.islockedinslot or
                item.components.stackable and item.components.stackable:IsOverStacked()) or
            (item.components.stackable and item.components.stackable:StackSize() or 1)~=amount then
            if valid(item) and item.components.shadowvaultticket2hm then item:RemoveComponent("shadowvaultticket2hm") end
            clear(row.escrow);self.v:Notify(row.userid,"cancelled");return
        end
        if not Journal.CanStageDeposit(c,item) then
            item:RemoveComponent("shadowvaultticket2hm")
            clear(row.escrow);self.v:Notify(row.userid,"unsupported");return
        end
        local removed=(source or inventory):RemoveItem(item,true,nil,true)
        c:EnableReadOnlyContainer(false)
        if valid(removed) then pcall(c.GiveItem,c,removed,1,nil,false) end
        c:EnableReadOnlyContainer(true)
        if not valid(removed) or c.slots[1]~=removed then
            if valid(item) then item:RemoveComponent("shadowvaultticket2hm") end
            if valid(removed) and not inside(removed,player) then
                if not source and not inventory:GetActiveItem() then inventory:GiveActiveItem(removed)
                else inventory:GiveItem(removed,source==inventory and source_slot or nil) end
            end
            if valid(item) and inside(item,player) and (not removed or valid(removed) and inside(removed,player)) and
                not next(c.slots) then
                clear(row.escrow)
                self:WritePlayer(player,function()end)
                self.v:Notify(row.userid,"unsupported")
            else
                -- An inventory hook changed custody unexpectedly. Keep the
                -- saved player before-image available for recovery.
                self.v:Fail("deposit_reservation_failed")
            end
            return
        end
        row.state="staged";row.forward=self.v.delivery_routes and self.v.delivery_routes[row.userid]
        local issued=removed.components.shadowvaultissued2hm
        local previous=issued and self.deliveries[issued.id]
        if type(previous)=="table" then
            previous.state="spent";previous.reason="deposited";previous.payload=nil;self.issued[issued.id]=nil
        end
        self.v.rows[name]=row;self.deposits[name]=row.userid
        self:Flush(function(saved)
            if saved and valid(player) and not player._despawning then self:WritePlayer(player,function()end) end
        end)
    end)
end
function Journal:ResumeDeposits()
    if self.busy or self.staging or not self.ready or self.error or self.v.protocol.active then return end
    local v=self.v
    for name,row in pairs(v.rows) do
        if row.state=="staged" then
            if row.localonly then
                local page=v.pages[row.page]
                local target=valid(page) and page.components.container
                if not target or row.op=="D" and target.slots[row.slot] or
                    row.token and row.token~=v:SlotToken(row.page,row.slot) then
                    row.state="delivery";self:Flush();return
                end
                if row.op=="P" or row.op=="S" or row.op=="Q" or row.op=="K" then
                    local ok,why=v:PlanSlot(row,target,row.escrow.components.container.slots[1])
                    if not ok then
                        row.state="delivery";self:Flush();v:Notify(row.userid,why);return
                    end
                end
                row.state="active";v:Reserve(name,row)
                local ok,why=v:Finalize(name,true)
                if not ok then v:Fail(why);return end
                self:Flush();v:Notify(row.userid,"done");v:Refresh(row.userid)
            elseif v.transport.peers[tostring(SHARDID.MASTER)] then
                row.state="active"
                local ok,why=v.protocol:Start(name,tostring(SHARDID.MASTER),row.userid)
                if not ok then v:Unlock(name);self:Flush();v:Notify(row.userid,why) end
            end
            return
        end
    end
end
function Journal:AcceptParcel(id,uid,page,payload,peer)
    if self.busy or not self.ready or self.error then return end
    local function acknowledge()
        if peer then self.v.transport:Send(peer,{vault=4,kind="PARCEL_ACK",id=id}) end
    end
    if self.receipts[id] then acknowledge();return end
    local escrow=SpawnPrefab("shadowvaulttransfer2hm")
    if not escrow then return end
    local ok=Adapter.Apply(proxy(self.v,escrow),"journal",payload)
    local row={userid=uid,page=page,escrow=escrow,state=ok and "delivery" or "uncertain",
        forward=self.v.delivery_routes and self.v.delivery_routes[uid]}
    if not ok then row.retained_payload=deepcopy(payload) end
    self.v.rows[id]=row;self.receipts[id]=true
    self:Flush(function(saved)if saved then acknowledge() end end)
end
function Journal:Receive(peer,m)
    if self.busy or not self.ready or self.error or type(m.id)~="string" or #m.id>1500 then return end
    if m.kind=="PARCEL_ACK" then
        local mail=self.mail[m.id]
        if mail and mail.to==peer then self.mail[m.id]=nil;self:Flush() end
    elseif m.kind=="PARCEL" and type(m.userid)=="string" and type(m.page)=="string" and type(m.payload)=="table" then
        self:AcceptParcel(m.id,m.userid,m.page,m.payload,peer)
    end
end
function Journal:Forward()
    if self.busy or not self.ready or self.error then return end
    local v=self.v
    for name,row in pairs(v.rows) do
        if row.state=="delivery" and row.forward and Shard_IsWorldAvailable(row.forward) then
            local present=false
            for _,p in ipairs(AllPlayers) do if p.userid==row.userid then present=true;break end end
            if not present then
                local payload,why=Journal.Payload(v,row.escrow)
                if not payload then v:Fail(why);return end
                self.mailsequence=(self.mailsequence or 0)+1
                local id="parcel/"..v.id.."/"..v.session.."/"..v.transport.boot.."/"..self.mailsequence
                self.mail[id]={to=row.forward,userid=row.userid,page=row.page,payload=payload}
                clear(row.escrow);v.rows[name]=nil
                self:Flush();return
            end
        end
    end
    if GetStaticTime()<(self.nextmail or 0) then return end
    self.nextmail=GetStaticTime()+.5
    for id,mail in pairs(self.mail) do
        v.transport:Send(mail.to,{vault=4,kind="PARCEL",id=id,userid=mail.userid,page=mail.page,payload=mail.payload})
    end
end
function Journal:Deliver(name,row,player)
    if self.busy or not self.ready or self.error or row.checking then return end
    player.shadowvault_receipts2hm=player.shadowvault_receipts2hm or {}
    local receipts=player.shadowvault_receipts2hm
    local function complete()
        clear(row.escrow);self.v.rows[name]=nil
        self:Flush();self.v:Notify(row.userid,"done");self.v:Refresh(row.userid)
    end
    if receipts[name] then complete();return end
    if row.state=="issuing" or row.state=="uncertain" then
        -- No evidence is not evidence of non-delivery: it may have been used.
        -- Retain the original record, and never automatically create a refund.
        return
    end
    if row.state~="delivery" then return end
    local pending=row.escrow.components.container.slots[1]
    if not valid(pending) then row.state="uncertain";self:Flush();return end
    local inventory=player.components.inventory
    local function CanUseCursor()
        local view=row.cursor_session and self.v.views[row.userid]
        if row.cursor_session and self.v.native and self.v.native.shared then
            view=self.v.native.shared:GetLocal(row.userid,row.cursor_session)or view
        end
        return view and view.session==row.cursor_session and view.page==row.page and not inventory:GetActiveItem()
    end
    local pendingcount=pending.components.stackable and pending.components.stackable:StackSize() or 1
    if not CanUseCursor() and inventory:CanAcceptCount(pending,pendingcount)<pendingcount then return end
    row.state="issuing"
    self:Flush(function(ok)
        if not ok then return end
        if not valid(player) or player._despawning then row.state="delivery";self:Flush();return end
        local c=row.escrow.components.container;local item=c.slots[1]
        if not valid(item) then row.state="uncertain";self:Flush();return end
        local amount=item.components.stackable and item.components.stackable:StackSize() or 1
        local cursor=CanUseCursor()
        if not cursor and inventory:CanAcceptCount(item,amount)<amount then row.state="delivery";self:Flush();return end
        if not item.components.shadowvaultissued2hm then item:AddComponent("shadowvaultissued2hm") end
        item.components.shadowvaultissued2hm.id=name
        local payload=Journal.Payload(self.v,row.escrow)
        c:EnableReadOnlyContainer(false);item=c:RemoveItemBySlot(1,true);c:EnableReadOnlyContainer(true)
        item.prevcontainer=nil;item.prevslot=nil
        if item.components.shadowvaultticket2hm then item:RemoveComponent("shadowvaultticket2hm") end
        if cursor then
            inventory:GiveActiveItem(item)
        else
            local freeslot
            for slot=1,inventory.maxslots do
                if not inventory:GetItemInSlot(slot) and inventory:CanTakeItemInSlot(item,slot) then freeslot=slot;break end
            end
            inventory:GiveItem(item,freeslot)
        end
        if valid(item) and not inside(item,player) then
            c:EnableReadOnlyContainer(false);c:GiveItem(item,1,nil,false);c:EnableReadOnlyContainer(true)
            row.state="delivery";self:Flush();return
        end
        receipts[name]=true;row.retained_payload=payload
        row.checking=true
        self:WritePlayer(player,function(saved,data)
            row.checking=nil
            if saved and data.data and data.data.shadowvault_receipts2hm and data.data.shadowvault_receipts2hm[name] then
                local held=valid(item) and inside(item,player) and not player._despawning
                self.deliveries[name]={userid=row.userid,page=row.page,count=amount,state=held and "held" or "spent",payload=held and payload or nil}
                if held then self.issued[name]=item end
                complete()
                local view=row.delivery_session and self.v.views[row.userid]
                if held and view and view.session==row.delivery_session and view.page==row.page and valid(item) then
                    if row.after_delivery=="use" then
                        local active=inventory:GetActiveItem()
                        if (active and active.GUID)==row.active_guid then
                            -- A native Store action from this use must not target the slot it came from.
                            item._shadowvault_use_until2hm=GetStaticTime()+1
                            inventory:UseItemFromInvTile(item)
                        end
                    elseif row.after_delivery=="drop" or row.after_delivery=="dropone" then
                        inventory:DropItemFromInvTile(item,false)
                    end
                end
            else row.state="uncertain";self:Flush() end
        end)
    end)
end
return Journal
