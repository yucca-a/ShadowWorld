-- Shared native views. Only the master owns persistent page items; secondary
-- widgets contain disposable native render copies, never transferable inventory.
local Config=require("shadowvaultconfig2hm")
local Shared={};Shared.__index=Shared
local MASTER=tostring(SHARDID.MASTER)
local function valid(e)return e and e:IsValid()end
local function qty(e)return e.components.stackable and e.components.stackable:StackSize() or 1 end
-- Save records are freshly allocated tables; Lua's hash traversal order is not
-- stable across allocations. Comparing DataDumper strings rebuilds unchanged
-- entities and races the native classified's itemget/refresh events.
local function same(a,b)
    if type(a)~=type(b)then return false end
    if type(a)~="table"then return a==b end
    for k,value in pairs(a)do if not same(value,b[k])then return false end end
    for k in pairs(b)do if a[k]==nil then return false end end
    return true
end
local function removed(a,b)
    if type(a)~="table"then return false end
    if type(b)~="table"then return true end
    for k,value in pairs(a)do
        if b[k]==nil or removed(value,b[k])then return true end
    end
    return false
end
local function playerfor(uid)for _,p in ipairs(AllPlayers)do if p.userid==uid then return p end end end
local function freeze(e)
    e.persists=false;e.shadowvault_preview2hm=true
    e:AddTag("nocrafting")
    if e.components.perishable then e.components.perishable:StopPerishing() end
    if e.components.fueled then e.components.fueled:StopConsuming() end
    if e.components.container then
        e.components.container:EnableReadOnlyContainer(true)
        for _,child in pairs(e.components.container.slots)do freeze(child)end
    end
end
local function dispose(e)
    if not valid(e)then return end
    local c=e.components.container
    if c then
        c.worldexchange_internal2hm=true
        local slots={};for slot in pairs(c.slots)do slots[#slots+1]=slot end
        for _,slot in ipairs(slots)do dispose(c:RemoveItemBySlot(slot,true))end
    end
    e:Remove()
end
function Shared.new(native)
    return setmetatable({native=native,v=native.v,pending={},mirrors={},queue={},dirty={},openviews={},remote={}},Shared)
end
function Shared:GetLocal(uid,session)
    return self.openviews[uid]and self.openviews[uid][session]
end
function Shared:GetRemote(peer,uid,session)
    return self.remote[peer]and self.remote[peer][uid]and self.remote[peer][uid][session]
end
function Shared:ForContainer(player,entity)
    for _,view in pairs(self.openviews[player.userid]or{})do
        if valid(view.anchor)and view.anchor.components.container_proxy:GetMaster()==entity and
            self.native:CanAccess(player,view.anchor) and view.anchor.components.container_proxy:IsOpenedBy(player)then return view end
    end
end
function Shared:Closed(player,anchor)
    for uid,views in pairs(self.openviews)do
        if not player or uid==player.userid then
            for session,view in pairs(views)do if view.anchor==anchor then views[session]=nil end end
            if not self.v.views[uid]then for _,view in pairs(views)do self.v.views[uid]=view;break end end
        end
    end
end
function Shared:Changed(page)
    local v=self.v
    if v.retired then return end
    if not v.master or not self.native:Owns(page) or self.native:Changing(page) then return end
    self.native.state.epochs[page]=(self.native.state.epochs[page]or 0)+1
    self.dirty[page]=true
end
function Shared:Observe(page,entity)
    if entity.shadowvault_shared_observed2hm then return end
    entity.shadowvault_shared_observed2hm=true
    local c=entity.components.container
    local function changed()
        if not self.v.internal and not c.worldexchange_internal2hm then self:Changed(page)end
    end
    local function watch(_,data)
        if not data or not data.initial then changed()end
        local item=data and data.item
        if item and not item.shadowvault_stackwatch2hm then
            item.shadowvault_stackwatch2hm=true
            item:ListenForEvent("stacksizechange",function()
                if item.components.inventoryitem.owner==entity then changed()end
            end)
        end
    end
    entity:ListenForEvent("itemget",watch)
    entity:ListenForEvent("itemlose",changed)
    for _,item in pairs(c.slots)do watch(nil,{item=item,initial=true})end
end
function Shared:Open(player,anchor,page,say)
    if not self.native:CanAccess(player,anchor) then return false end
    local v=self.v
    v.view_sequence=v.view_sequence+1
    self.pending[player.userid]={anchor=anchor,page=page,say=say,session=v.catalog_epoch.."_shared_"..v.view_sequence,
        shared_sequence=v.view_sequence}
    return true
end
function Shared:Send(peer,uid,page,session)
    local v=self.v
    if not self.native:Owns(page) or self.native:Changing(page) then return end
    local catalog=v:Catalog(page)
    local entity=v.pages[page]
    if not catalog or not catalog.ready or not valid(entity) then return end
    local records,identities={},{}
    for slot,item in pairs(entity.components.container.slots)do
        local ok,record=pcall(item.GetSaveRecord,item)
        if not ok or not record then return end
        records[tostring(slot)]=record
        identities[tostring(slot)]=item.GUID
    end
    local ok,metadata=pcall(entity.GetPersistData,entity)
    if not ok then return end
    if metadata and metadata.container then metadata.container.items=nil end
    catalog.session=session
    local message={vault=7,kind="VIEW",op=session,userid=uid,catalog=catalog,records=records,identities=identities,metadata=metadata,item_session=v.session,
        epoch=self.native.state.epochs[page]or 0}
    local key=peer..":"..uid..":"..session
    self.sent=self.sent or {}
    local sent=self.sent[key]
    if not sent or not same(sent.message,message)or GetStaticTime()-sent.time>=1 then
        local body=DataDumper(message,nil,true)
        self.sent[key]={message=message,time=GetStaticTime()}
        v.transport:Send(peer,message,body)
    end
end
function Shared:Mirror(page)
    local entity=self.mirrors[page]
    if not valid(entity) then
        entity=Config.SpawnPage(page)
        if not entity then return end
        entity.persists=false
        entity.shadowvault_page2hm=page
        entity.shadowvault_mirror2hm=self
        entity.shadowvault_owner2hm=self.native
        entity.shadowvault_records2hm={}
        self.mirrors[page]=entity
    end
    return entity
end
function Shared:Apply(entity,message)
    local c=entity.components.container
    local signatures=entity.shadowvault_records2hm
    entity.shadowvault_identities2hm=entity.shadowvault_identities2hm or{}
    local identities=entity.shadowvault_identities2hm
    local staged,changed={},{}
    for slot=1,c.numslots do
        local record=message.records[tostring(slot)]
        local signature=record
        local identity=message.identities and message.identities[tostring(slot)]
        if not same(signatures[slot],signature)or identity~=identities[slot]then
            if record then
                local current=c.slots[slot]
                -- Timers, durability and wrapped perishables change save data
                -- without changing the item. Keep its replicated entity so the
                -- original ItemTile and pending native RPCs retain their target.
                local reuse=identity and identities[slot]==identity and valid(current) and
                    current.prefab==record.prefab and current.skinname==record.skinname and
                    not current.components.container and not removed(signatures[slot],record)
                local item=reuse and current or SpawnPrefab(record.prefab,record.skinname,record.skin_id,{sessionid=message.item_session})
                if not item then for _,e in pairs(staged)do dispose(e)end;return false end
                item.alt_skin_ids=record.alt_skin_ids
                local ok=pcall(item.SetPersistData,item,record.data)
                if not ok or not valid(item) then
                    dispose(item)
                    for _,e in pairs(staged)do dispose(e)end
                    return false
                end
                freeze(item);if not reuse then staged[slot]=item end
            end
            changed[slot]=signature or false
        end
    end
    c.worldexchange_internal2hm=true
    c:EnableReadOnlyContainer(false)
    local metadata=message.metadata
    if not same(metadata,entity.shadowvault_metadata2hm)then
        if message.metadata then entity:SetPersistData(message.metadata)end
        entity.shadowvault_metadata2hm=metadata
    end
    for slot,signature in pairs(changed)do
        if staged[slot]or not signature then
            local old=c:RemoveItemBySlot(slot,true)
            dispose(old)
            if staged[slot] then
                assert(c:GiveItem(staged[slot],slot,nil,false),"native shared view rejected its original item")
            end
        end
        signatures[slot]=signature or nil
        identities[slot]=message.identities and message.identities[tostring(slot)]or nil
    end
    c.worldexchange_internal2hm=nil
    return true
end
function Shared:Receive(peer,message)
    local v=self.v
    if v.master and message.kind=="OPEN" then
        if type(message.userid)~="string" or not Config.ValidStamp(message.session) or
            not v.registry[message.page] or not Config.Concurrent(message.page)then return end
        v.remoteviews=v.remoteviews or {};v.remoteviews[peer]=v.remoteviews[peer]or {}
        local view={shared=true,page=message.page,session=message.session,time=GetStaticTime(),
            shared_sequence=message.shared_sequence}
        v.remoteviews[peer][message.userid]=view
        self.remote[peer]=self.remote[peer]or{};self.remote[peer][message.userid]=self.remote[peer][message.userid]or{}
        self.remote[peer][message.userid][message.session]=view
        self:Send(peer,message.userid,message.page,message.session)
    elseif v.master and message.kind=="SORT"then
        local view=self:GetRemote(peer,message.userid,message.session)
        if view and view.shared and view.page==message.page and view.session==message.session and
            GetStaticTime()-view.time<4 then
            if v:SortPage(view.page)then self:Changed(view.page)end
        end
    elseif not v.master and peer==MASTER and message.kind=="VIEW" and type(message.catalog)=="table" and
        type(message.records)=="table" then
        local catalog=message.catalog
        local pending=self.pending[message.userid]
        if pending and pending.session~=catalog.session then pending=nil end
        local view=self:GetLocal(message.userid,catalog.session)
        local request=pending or view and view.shared and view
        local player=playerfor(message.userid)
        if not request or request.page~=catalog.page or request.session~=catalog.session or
            not self.native:CanAccess(player,request.anchor) then return end
        local entity=self:Mirror(catalog.page)
        if not entity or (entity.shadowvault_epoch2hm or -1)>(message.epoch or 0) then return end
        if not self:Apply(entity,message)then return end
        entity.shadowvault_epoch2hm=message.epoch or 0
        v.registry=catalog.registry
        if pending then
            if self.native:Display(player,pending.anchor,pending.page,pending.say,entity) then
                view=v.views[player.userid];view.session=pending.session;view.shared=true
                view.shared_sequence=pending.shared_sequence
                self.openviews[player.userid]=self.openviews[player.userid]or{}
                self.openviews[player.userid][view.session]=view
                self.pending[player.userid]=nil
            end
        end
        if view and view.shared then view.catalog=catalog end
    end
end
function Shared:Sort(player,entity)
    local view=player and self:ForContainer(player,entity)
    if view then
        self.v.transport:Send(MASTER,{vault=7,kind="SORT",userid=player.userid,page=view.page,session=view.session})
    end
end
function Shared:Enqueue(player,container,action,slot,item,mode,requested_count)
    local v=self.v;local view=self:ForContainer(player,container.inst)
    if not view then return end
    if #self.queue>=32 then return end
    local entry=view.catalog and view.catalog.items[tostring(slot)]
    self.queue[#self.queue+1]={uid=player.userid,session=view.session,page=view.page,action=action,slot=slot,
        item=item,count=item and qty(item),mode=mode,requested_count=requested_count,
        token=entry and entry.token or view.catalog and view.catalog.emptytoken}
end
function Shared:QuickStore(player,item,half,requested_count,entity)
    local view=entity and self:ForContainer(player,entity)or self.v.views[player.userid]
    if not view or not view.shared or not view.catalog then return false end
    local slot=Config.QuickStoreSlot(view.catalog,item.prefab,item.skinname)
    if not slot then return false end
    local c=view.anchor.components.container_proxy:GetMaster().components.container
    if c.itemtestfn and not c:itemtestfn(item,slot)then return false end
    self:Enqueue(player,c,half and "quickstorehalf"or"quickstore",slot,item,nil,requested_count)
    return true
end
function Shared:Update()
    local v=self.v;local now=GetStaticTime()
    if v.master then
        if next(self.dirty) and not v.journal.busy and not v.journal.staging then
            self.dirty={};v.journal:Flush()
        end
        if not self.nextsend or now>=self.nextsend then
            self.nextsend=now+.15
            for peer,users in pairs(self.remote)do
                for uid,views in pairs(users)do for session,view in pairs(views)do
                    if now-view.time<4 then self:Send(peer,uid,view.page,view.session)
                    else views[session]=nil;if self.sent then self.sent[peer..":"..uid..":"..session]=nil end end
                end
                end
            end
        end
        return
    end
    for uid,request in pairs(self.pending)do
        local p=playerfor(uid)
        if not self.native:CanAccess(p,request.anchor)then self.pending[uid]=nil
        elseif not request.nextsend or now>=request.nextsend then
            request.nextsend=now+.5
            v.transport:Send(MASTER,{vault=7,kind="OPEN",op=request.session,userid=uid,page=request.page,session=request.session,
                shared_sequence=request.shared_sequence})
        end
    end
    for uid,views in pairs(self.openviews)do for session,view in pairs(views)do
        local player=playerfor(uid)
        local proxy=valid(view.anchor)and view.anchor.components.container_proxy
        if not self.native:CanAccess(player,view.anchor)or not proxy or not proxy:IsOpenedBy(player)then
            views[session]=nil
        elseif (not self.pending[uid]or self.pending[uid].anchor~=view.anchor)and (not view.nextshared or now>=view.nextshared)then
            view.nextshared=now+.5
            v.transport:Send(MASTER,{vault=7,kind="OPEN",op=view.session,userid=uid,page=view.page,session=view.session,
                shared_sequence=view.shared_sequence})
        end
    end end
    for page,entity in pairs(self.mirrors)do
        local waiting=false
        for _,request in pairs(self.pending)do if request.page==page then waiting=true;break end end
        if not waiting and entity.components.container.opencount==0 then
            local base=v.native_bases[Config.Family(page)]
            for e in pairs(entity.shadowvault_anchors2hm or{})do
                local proxy=valid(e)and e.components.container_proxy
                if proxy and proxy:GetMaster()==entity then proxy:SetMaster(base)end
            end
            local c=entity.components.container;c.worldexchange_internal2hm=true
            for slot=1,c.numslots do dispose(c:RemoveItemBySlot(slot,true))end
            entity:Remove();self.mirrors[page]=nil
        end
    end
    if v.protocol.active or v.journal.busy or v.journal.staging or not self.queue[1]then return end
    local row=table.remove(self.queue,1)
    local player=playerfor(row.uid);local view=self:GetLocal(row.uid,row.session)
    if not player or player._despawning or not view or view.session~=row.session or not view.catalog then return end
    if v:PendingDelivery(row.uid)then table.insert(self.queue,1,row);return end
    local entry=view.catalog.items[tostring(row.slot)]
    local item=row.item
    if item and (not valid(item)or qty(item)~=row.count)then return end
    player._shadowvault_nextaction=nil
    v.views[row.uid]=view
    player._shadowvault_requested_count2hm=row.requested_count
    v:Action(player,row.action,row.page,row.slot,row.token,row.session,
        item,row.mode or row.count)
    player._shadowvault_requested_count2hm=nil
end
return Shared
