-- A page has one physical owner. Players interact with native containers only.
local Config = require("shadowvaultconfig2hm")
local Adapter = require("shadowvaultitems2hm")
local Native = {}
Native.__index = Native
local MASTER = tostring(SHARDID.MASTER)
local MAX_PAGE_BYTES = 16 * 1024 * 1024

local function valid(inst) return inst and inst:IsValid() end
local function playerfor(uid)
    for _, player in ipairs(AllPlayers) do if player.userid == uid then return player end end
end
function Native.ProtectUniqueCleanup(world)
    -- UM's startup repair removes every extra skull/winky singleton. Managed
    -- pages are intentional real containers; keep them outside that one scan.
    -- Only change that callback's environment, never the global entity table.
    for task in pairs(world.pendingtasks or {}) do
        local fn=task.fn
        local info=type(fn)=="function" and debug.getinfo(fn,"S")
        if info and info.source:find("postinit/prefabs/world.lua",1,true) then
            local cleanup=false
            for i=1,100 do
                local name=debug.getupvalue(fn,i)
                if not name then break end
                if name=="count_skull" then cleanup=true;break end
            end
            if cleanup then
                local original=getfenv(fn)
                setfenv(fn,setmetatable({pairs=function(value)
                    if value~=Ents then return pairs(value) end
                    local v=world.components.shadowvault2hm
                    local variants=world.components.exchangevariants2hm
                    if not v and not variants then return pairs(value) end
                    local extras={}
                    for _,entity in pairs(v and v.pages or {}) do extras[entity]=true end
                    for _,row in pairs(v and v.rows or {}) do if row.escrow then extras[row.escrow]=true end end
                    for _,banks in pairs(variants and variants.banks or {})do
                        for _,entity in pairs(banks)do extras[entity]=true end
                    end
                    for _,entity in pairs(world.PocketDimensionContainers or v and v.native_bases or {}) do extras[entity]=nil end
                    local visible={}
                    for id,entity in pairs(value) do
                        if not extras[entity] then visible[id]=entity end
                    end
                    return pairs(visible)
                end},{__index=original}))
            end
        end
    end
end
local function parse(name)
    if type(name) ~= "string" then return end
    local page, source, destination, epoch, nonce = name:match("^N:([%w_%-]+):([%w_%-]+):([%w_%-]+):(%d+):([%w_%-]+)$")
    epoch = tonumber(epoch)
    if page and epoch and epoch > 0 then
        return {op="N",page=page,source=source,destination=destination,epoch=epoch,nonce=nonce}
    end
end
local function payload(v, page)
    local snapshot,why=Adapter.Snapshot({session=v.session,Container=function() return page end,Validate=Adapter.Validate}, "native", true)
    if not snapshot then return nil,why end
    local ok,data=pcall(page.GetPersistData,page)
    if not ok then return nil,"invalid_items" end
    if data and data.container then data.container.items=nil end
    snapshot.metadata=data
    return snapshot
end
Native.ExportPage=payload
function Native.RestoreMetadata(entity,data)
    if not data.metadata then return true end
    return pcall(entity.SetPersistData,entity,data.metadata)
end
local function clearpayload(v, page)
    local c=page.components.container
    return {items={},session=v.session,layout=tostring(c.numslots)..":"..tostring(c.infinitestacksize==true)..":"..
        tostring(c.acceptsstacks==true)..":"..tostring(c.usespecificslotsforitems==true)}
end

function Native.new(v, saved, checkpoints)
    local self=setmetatable({v=v,pending={},checkpoints=checkpoints or {},checkpoint_epochs={},sequence=0,localonly={},adoptafter={}},Native)
    self.state=deepcopy(saved or {version=1,owners={},epochs={}})
    self.state.owners=self.state.owners or {}
    self.state.epochs=self.state.epochs or {}
    local world=v.saved_native_world
    if saved and saved.shared and world and world.shared then
        for page,owner in pairs(self.state.owners)do
            if owner==v.id and world.owners[page]==v.id then
                self.state.epochs[page]=math.max(self.state.epochs[page]or 0,world.epochs[page]or 0)
            end
        end
    end
    self.shared=require("shadowvaultshared2hm").new(self)
    self.state.shared=true
    return self
end
function Native:Save() return deepcopy(self.state) end
function Native:IsTransfer(name) return parse(name) ~= nil end
function Native:Owns(page) return self.state.owners[page]==self.v.id end
function Native:Changing(page)
    local t=self.v.protocol.active
    local row=t and parse(t.name)
    return row and row.page==page
end
function Native:Say(uid, zh, en) self.v:Say(uid,zh,en) end
function Native:Page(page)
    local v=self.v
    if not valid(v.pages[page]) then
        local family=Config.Family(page)
        local entity=page==Config.Page(v.id,family) and v.native_bases[family] or Config.SpawnPage(page)
        if not valid(entity) then return end
        v.pages[page]=entity
        v:GuardPage(page,entity)
    end
    local entity=v.pages[page]
    self.checkpoints[page]=self.checkpoints[page] or clearpayload(v,entity)
    entity.shadowvault_page2hm=page
    entity.shadowvault_owner2hm=self
    entity.components.container.skipautoclose=true
    if self.shared then self.shared:Observe(page,entity) end
    return entity
end
function Native:PrepareAdoption(page, entity)
    self.localonly=self.localonly or {}
    self.adoptafter=self.adoptafter or {}
    local now=GetStaticTime()
    if now<(self.adoptafter[page] or 0) then return end
    local data,why
    if entity.components.container.opencount>0 then why="busy"
    else data,why=payload(self.v,entity) end
    if not data then
        why=why or "invalid_items"
        if self.localonly[page]~=why then
            print("[ShadowVault2hm] native_page_retained",entity.prefab,why)
        end
        self.localonly[page]=why
        self.adoptafter[page]=now+5
        -- No custody transfer has started. Keep the same native entity, slots,
        -- pet links and original container UI; never drop or reconstruct items.
        entity.components.container:EnableReadOnlyContainer(false)
        entity.dcs2hm=nil
        return
    end
    self.localonly[page]=nil;self.adoptafter[page]=nil
    return data
end
function Native:Adopt()
    local v=self.v
    local active=v.protocol.active
    if active and not self:IsTransfer(active.name) then return end
    if v.master then
        for family,base in pairs(v.native_bases or {}) do
            local page=Config.Page(v.id,family)
            if valid(base) and Config.Manageable(family,base) and not v.registry[page] and self:PrepareAdoption(page,base) then
                v.registry[page]={name=v.registry[v.id] and v.registry[v.id].name or "Master",imported=true}
                v.pages[page]=base
                v:GuardPage(page,base)
            end
        end
        for page,info in pairs(v.registry) do
            if info.imported and not self.state.owners[page] and valid(v.pages[page]) then
                local data=self:PrepareAdoption(page,v.pages[page])
                if data then
                    self.state.owners[page]=v.id
                    self.state.epochs[page]=0
                    self.checkpoints[page]=data
                elseif v:LocalBase(page)==v.pages[page] then
                    -- Only detach an unowned local base. Existing transactions
                    -- and remotely owned pages retain their protection.
                    v.pages[page]=nil;v.registry[page]=nil
                end
            end
        end
    end
    for page in pairs(self.state.owners) do
        local entity=v.pages[page]
        if valid(entity) then
            self:Page(page)
            local c=entity.components.container
            c:EnableReadOnlyContainer(not self:Owns(page) or self:Changing(page))
            entity.dcs2hm=not self:Owns(page) or self:Changing(page) or nil
        end
    end
end
function Native:Snapshot(name)
    local row=self.v.rows[name]
    if not row then return nil,"container_missing" end
    local data,why=payload(self.v,row.escrow)
    if not data then return nil,why end
    if #DataDumper(data,nil,true)>MAX_PAGE_BYTES-65536 then return nil,"too_large" end
    return data
end
function Native:Lock(name, incoming)
    local v=self.v
    local row=v.rows[name]
    if row then return valid(row.escrow) end
    row=parse(name)
    local peer=v.receiving_peer
    if not row or peer~=row.source or row.destination~=v.id or
        row.source~=MASTER and row.destination~=MASTER then return false,"invalid_items" end
    if v.master then
        if self.state.owners[row.page]~=peer or row.epoch~=(self.state.epochs[row.page] or 0)+1 then return false,"stale" end
    elseif peer~=MASTER or row.epoch<=(self.state.epochs[row.page] or -1) then return false,"stale" end
    local entity=self:Page(row.page)
    if not entity or entity.components.container.opencount>0 or next(entity.components.container.slots) then return false,"busy" end
    if not Native.RestoreMetadata(entity,incoming) or
        not Adapter.Validate({Container=function()return entity end},name,incoming) then return false,"invalid_items" end
    row.escrow,row.state=entity,"active"
    v.rows[name]=row
    entity.components.container:EnableReadOnlyContainer(true)
    entity.dcs2hm=true
    return true
end
function Native:Validate(name, incoming)
    local v=self.v
    local row=v.rows[name]
    local ok,why=Adapter.Validate(v,name,incoming)
    if not ok then return false,why end
    if not row then return false,"invalid_items" end
    if row.source==v.id and next(incoming.items) then return false,"destination_changed" end
    return true
end
function Native:Finalize(name, success)
    local v=self.v
    local row=v.rows[name]
    if not row then return false,"missing_transfer_record" end
    if success then
        local t=v.protocol.active
        self.state.owners[row.page]=row.destination
        self.state.epochs[row.page]=row.epoch
        self.checkpoints[row.page]=deepcopy(t and t.incoming or clearpayload(v,row.escrow))
        if not v.registry[row.page] then v.registry[row.page]={name=Config.PageShard(row.page),imported=true} end
    end
    row.escrow.components.container:EnableReadOnlyContainer(true)
    row.escrow.dcs2hm=true
    v.rows[name]=nil
    self.nextannounce=0
    return true
end
function Native:Transfer(page, destination, uid)
    local v=self.v
    local entity=self:Page(page)
    if not self:Owns(page) or not entity or entity.components.container.opencount>0 or
        v.protocol.active or v.journal.busy or v.journal.staging then return false,"busy" end
    local data,why=payload(v,entity)
    if not data then return false,why end
    if #DataDumper(data,nil,true)>MAX_PAGE_BYTES-65536 then return false,"too_large" end
    self.sequence=self.sequence+1
    local epoch=(self.state.epochs[page] or 0)+1
    local nonce=v.transport.boot:gsub("[^%w_%-]","_").."_"..self.sequence
    local name="N:"..page..":"..v.id..":"..destination..":"..epoch..":"..nonce
    v.rows[name]={op="N",page=page,source=v.id,destination=destination,epoch=epoch,escrow=entity,state="active"}
    entity.components.container:EnableReadOnlyContainer(true)
    entity.dcs2hm=true
    local ok,reason=v.protocol:Start(name,destination,uid)
    if not ok then
        v.rows[name]=nil
        entity.components.container:EnableReadOnlyContainer(false)
        entity.dcs2hm=nil
    end
    return ok,reason
end
function Native:Broadcast(peer)
    self.v.transport:Send(peer,{vault=6,kind="REGISTRY",registry=self.v.registry,owners=self.state.owners,epochs=self.state.epochs})
end
function Native:Receive(peer, message)
    local v=self.v
    if message.kind=="REGISTRY" and not v.master and peer==MASTER and type(message.registry)=="table" then
        v.registry=deepcopy(message.registry)
        for page,owner in pairs(message.owners or {}) do
            local epoch=(message.epochs or {})[page] or 0
            if not self:Owns(page) and not self:Changing(page) and epoch>=(self.state.epochs[page] or -1) then
                self.state.owners[page]=owner
                self.state.epochs[page]=epoch
            end
        end
    elseif message.kind=="REQUEST" and v.master and type(message.page)=="string" and type(message.userid)=="string" then
        local page=message.page
        if not v.registry[page] or not v.registry[page].imported then return end
        if self.state.owners[page]==peer then
            self:Broadcast(peer)
        elseif self:Owns(page) then
            local ok,why=self:Transfer(page,peer,message.userid)
            if not ok then v.transport:Send(peer,{vault=6,kind="WAIT",userid=message.userid,page=page,reason=why}) end
        else
            v.transport:Send(peer,{vault=6,kind="WAIT",userid=message.userid,page=page,reason="occupied"})
        end
    elseif message.kind=="WAIT" and peer==MASTER then
        local pending=self.pending[message.userid]
        if pending and pending.page==message.page and message.reason~="busy" then
            self.pending[message.userid]=nil
            self:Say(message.userid,"这个空间正在另一世界使用，关闭后可再次穿越。",
                "This space is open on another shard. Retry after it closes.")
        end
    end
end
function Native:CanAccess(player, anchor)
    if not valid(player) or player._despawning or not valid(anchor) then return false end
    if anchor.prefab=="tophat_container" then
        local magician=player.components.magician
        return magician and valid(anchor.tophat) and magician.item==anchor.tophat
    end
    local owner=anchor.components.inventoryitem and anchor.components.inventoryitem:GetGrandOwner()
    return owner==player or anchor.Transform and player:GetDistanceSqToInst(anchor)<=25
end
function Native:Close(player, keep_hat, anchor)
    local v=self.v
    local current=v.views[player.userid]
    local view=anchor and {anchor=anchor} or current
    if not anchor or current and current.anchor==anchor then v.views[player.userid]=nil end
    local pending=self.pending[player.userid]
    if not anchor or pending and pending.anchor==anchor then self.pending[player.userid]=nil end
    local sharedpending=self.shared and self.shared.pending[player.userid]
    if sharedpending and (not anchor or sharedpending.anchor==anchor)then self.shared.pending[player.userid]=nil end
    if not view or not valid(view.anchor) then return end
    local proxy=view.anchor.components.container_proxy
    if proxy and proxy:IsOpenedBy(player) then
        local onclose=proxy.onclosefn
        local preserve=keep_hat and view.anchor.prefab=="tophat_container"
        if preserve then proxy.onclosefn=nil end
        proxy:Close(player)
        if preserve and valid(view.anchor) then proxy.onclosefn=onclose end
    end
end
function Native:Display(player, anchor, page, say, mirror)
    local v=self.v
    if not mirror and (not self:Owns(page) or self:Changing(page)) or not self:CanAccess(player,anchor) then return false end
    local entity=mirror or self:Page(page)
    local proxy=anchor.components.container_proxy
    if not entity or not proxy then return false end
    if proxy.opencount>0 and proxy.master~=entity and
        (proxy.opencount>1 or not proxy:IsOpenedBy(player)) then
        self:Say(player.userid,"这个入口正被其他玩家使用，请使用另一个入口。",
            "Another player is using this entrance. Use a different entrance.")
        return false
    end
    local switching=proxy:IsOpenedBy(player) and proxy.master~=entity
    local onopen,onclose=proxy.onopenfn,proxy.onclosefn
    if switching then
        -- Switching the space keeps its physical entrance open. In particular,
        -- a skull chest must not apply its opening penalty a second time.
        proxy.onopenfn,proxy.onclosefn=nil,nil
    end
    if proxy:IsOpenedBy(player) then proxy:Close(player) end
    self.pending[player.userid]=nil
    if not valid(anchor) then return false end
    proxy:SetMaster(entity)
    if mirror then
        entity.shadowvault_anchors2hm=entity.shadowvault_anchors2hm or setmetatable({},{__mode="k"})
        entity.shadowvault_anchors2hm[anchor]=true
    end
    entity.components.container:EnableReadOnlyContainer(false)
    entity.dcs2hm=nil
    v.view_sequence=v.view_sequence+1
    local view={native=true,anchor=anchor,page=page,session=v.catalog_epoch.."_"..v.view_sequence}
    v.views[player.userid]=view
    proxy.shadowvault_opening2hm=true
    proxy:Open(player)
    proxy.shadowvault_opening2hm=nil
    if switching then proxy.onopenfn,proxy.onclosefn=onopen,onclose end
    if not proxy:IsOpenedBy(player) then v.views[player.userid]=nil;return false end
    if say then v:SayTravel(player.userid,page) end
    return true
end
function Native:Open(player, anchor, page, say)
    local v=self.v
    if not v.journal.ready or v.error or not self:CanAccess(player,anchor) then return false end
    page=page or v.id
    if not v.master and self.shared and Config.Concurrent(page)then
        return self.shared:Open(player,anchor,page,say)
    end
    if self:Owns(page) and not self:Changing(page) then return self:Display(player,anchor,page,say) end
    self.pending[player.userid]={anchor=anchor,page=page,say=say,time=GetStaticTime()}
    self:Say(player.userid,"正在交接空间，请稍候。","Moving the space to this shard. Please wait.")
    return true
end
function Native:Request(player, inst)
    local v=self.v
    for family,base in pairs(v.native_bases or {}) do
        local page=Config.Page(v.id,family)
        if base==inst and self.localonly and self.localonly[page] then
            self:Say(player.userid,"箱内有暂不支持跨界的物品，原箱仍可正常使用。取出这些物品并关箱后会自动重试。",
                "Some items cannot cross shards. This local container still works; remove those items and close it to retry automatically.")
            return false
        end
    end
    local view=v.views[player.userid]
    if not view or not view.native or view.anchor.components.container_proxy:GetMaster()~=inst then
        view=nil
        for anchor in pairs(player.components.inventory.opencontainerproxies) do
            local proxy=anchor.components.container_proxy
            if proxy and proxy:IsOpenedBy(player) and proxy:GetMaster()==inst and inst.shadowvault_page2hm then
                view={native=true,anchor=anchor,page=inst.shadowvault_page2hm}
                v.views[player.userid]=view
                break
            end
        end
    end
    if not view then return end
    local ids=Config.Order(self.v.registry,view.page)
    for index,page in ipairs(ids) do
        if page==view.page and #ids>1 then
            return self:Open(player,view.anchor,ids[index%#ids+1],true)
        end
    end
end
function Native:Update()
    local v=self.v
    if not v.journal.ready or v.error then return end
    self:Adopt()
    for uid,view in pairs(v.views) do
        if view.native then
            local player=playerfor(uid)
            local proxy=valid(view.anchor) and view.anchor.components.container_proxy
            if not self:CanAccess(player,view.anchor) or not proxy or not proxy:IsOpenedBy(player) then
                if player then self:Close(player) else v.views[uid]=nil end
            end
        end
    end
    for uid,pending in pairs(self.pending) do
        local player=playerfor(uid)
        if not self:CanAccess(player,pending.anchor) then self.pending[uid]=nil
        elseif self:Owns(pending.page) and not self:Changing(pending.page) then
            self.pending[uid]=nil
            self:Display(player,pending.anchor,pending.page,pending.say)
        elseif GetStaticTime()-pending.time>30 then
            self.pending[uid]=nil
            self:Say(uid,"空间交接尚未完成，请稍后再试。","The space is still moving. Please retry shortly.")
        elseif not pending.nextrequest or GetStaticTime()>=pending.nextrequest then
            pending.nextrequest=GetStaticTime()+1
            if v.master then
                local owner=self.state.owners[pending.page]
                -- Older saves may still be returning a borrowed real page.
                -- Keep the native request pending while that handoff finishes.
            else
                v.transport:Send(MASTER,{vault=6,kind="REQUEST",page=pending.page,userid=uid})
            end
        end
    end
    if not v.master and not v.protocol.active and not v.journal.busy and not v.journal.staging then
        for page in pairs(self.state.owners) do
            local entity=v.pages[page]
            local waiting=false
            for _,request in pairs(self.pending) do if request.page==page then waiting=true;break end end
            if self:Owns(page) and valid(entity) and entity.components.container.opencount==0 and not waiting then
                self.idle=self.idle or {}
                self.idle[page]=self.idle[page] or GetStaticTime()+1
                if GetStaticTime()>=self.idle[page] then
                    self:Transfer(page,MASTER)
                    self.idle[page]=GetStaticTime()+2
                    break
                end
            elseif self.idle then self.idle[page]=nil end
        end
    end
    if v.master and (not self.nextannounce or GetStaticTime()>=self.nextannounce) then
        self.nextannounce=GetStaticTime()+1
        for peer in pairs(v.transport.peers) do self:Broadcast(peer) end
    end
    if self.shared then self.shared:Update() end
end

return Native
