-- One-time ownership handoff from the old journal to ordinary world saves.
-- Uses the existing durable page transfer; never copies an unowned checkpoint.
local Config=require("shadowvaultconfig2hm")
local Migration={};Migration.__index=Migration
local function valid(e)return e and e:IsValid()end
local function empty(t)return not t or next(t)==nil end
function Migration.new(variants)
    return setmetatable({variants=variants,states={},phase="returning"},Migration)
end
function Migration:Members(v)
    local ids={[v.id]=true}
    for page in pairs(v.registry)do ids[Config.PageShard(page)]=true end
    for peer in pairs(v.transport.peers)do ids[peer]=true end
    return ids
end
function Migration:Quiet(v)
    for _,delivery in pairs(v.journal and v.journal.deliveries or {})do
        if type(delivery)=="table" and delivery.state=="held" then return false end
    end
    return v.journal and v.journal.ready and not v.journal.busy and not v.journal.staging and
        not v.protocol.active and empty(v.rows) and empty(v.journal.mail)
end
function Migration:Home(v)
    for page,owner in pairs(v.native.state.owners)do
        if owner~=Config.PageShard(page) then return false end
    end
    return true
end
function Migration.HasReceipt(data,name)
    return type(data)=="table" and type(data.data)=="table" and
        type(data.data.shadowvault_receipts2hm)=="table" and data.data.shadowvault_receipts2hm[name]==true
end
function Migration:ResolveHeld(v)
    if self.readingreceipt or GetStaticTime()<(self.nextreceipt or 0) or v.journal.busy then return end
    self.nextreceipt=GetStaticTime()+5
    for name,record in pairs(v.journal.deliveries or {})do
        if type(record)=="table" and record.state=="held" and not v.rows[name] and type(record.userid)=="string" then
            local file=TheNet:GetUserSessionFile(v.session,record.userid)
            if file then
                self.readingreceipt=true
                TheNet:DeserializeUserSession(file,function(ok,raw)
                    self.readingreceipt=nil
                    local parsed,data=false,nil
                    if ok and type(raw)=="string" then parsed,data=RunInSandboxSafe(raw)end
                    -- This receipt is already the journal's proof of delivery.
                    -- A player's native file now owns the issued item or its
                    -- subsequent use; never issue a second migration refund.
                    if parsed and Migration.HasReceipt(data,name) and record.state=="held" and not v.rows[name] then
                        record.state="spent";record.reason="original_migration";record.payload=nil
                        v.journal.issued[name]=nil
                        v.journal:Flush()
                        self.nextreceipt=0
                    end
                end)
                return
            end
        end
    end
end
function Migration:Send(v,peer,kind)
    v.transport:Send(peer,{vault=8,kind=kind,boot=v.transport.boot,
        phase=self.phase,quiet=self:Quiet(v),home=self:Home(v)})
end
function Migration:All(v,phase)
    if self.phase~=phase or not self:Quiet(v) or not self:Home(v) then return false end
    for peer in pairs(self:Members(v))do
        if peer~=v.id then
            local connection=v.transport.peers[peer]
            local state=self.states[peer]
            if not connection or not Shard_IsWorldAvailable(peer) or not state or state.boot~=connection.boot or
                state.phase~=phase or not state.quiet or not state.home then return false end
        end
    end
    return true
end
function Migration:Prepare(v)
    if self.phase~="returning" or not self:Quiet(v) or not self:Home(v) then return end
    self.phase="flushing"
    -- Keep the final old journal intact as recovery input for a pre-migration
    -- world image. Future Nexus sessions use a separate, saved namespace.
    v.journal:Flush(function(ok)
        if ok then self.phase="prepared" else self.phase="returning" end
    end)
end
function Migration:Commit(v)
    if self.phase~="prepared" or not self:Quiet(v) or not self:Home(v) then return end
    local variants=self.variants
    local active={}
    for family,base in pairs(v.native_bases)do
        local page=Config.Page(v.id,family)
        local owned=v.native.state.owners[page]
        local e=owned==v.id and v.pages[page] or not owned and base
        if not valid(e) then return end
        active[family]=e
    end
    for page,owner in pairs(v.native.state.owners)do
        if owner==v.id then
            local e=v.pages[page]
            if not valid(e) then return end
            active[Config.Family(page)]=e
        end
    end
    -- Validate the complete handoff before rebinding any live entrance.
    for page,e in pairs(v.pages)do
        if v.native.state.owners[page]~=v.id and valid(e) and next(e.components.container.slots) then
            print("[ExchangeMigration2hm] retained unexpected foreign contents",page)
            self.phase="blocked_foreign_contents";return
        end
    end
    -- Every live page is now on its original layer. Reuse its real entity and
    -- native capacity, preserving skins, mod data and linked local-only items.
    local replacements={}
    for family,e in pairs(active)do
        local old=v.native_bases[family]
        if old then replacements[old]=e end
        variants.inst:SetPocketDimensionContainer(family,e)
        e.shadowvault_owner2hm=nil;e.shadowvault_page2hm=nil;e.dcs2hm=nil
        e.exchange_inactive2hm=nil
    end
    for _,e in pairs(Ents)do
        local proxy=e.components.container_proxy
        if proxy and replacements[proxy:GetMaster()] then proxy:SetMaster(replacements[proxy:GetMaster()])end
    end
    -- Foreign pages are empty protocol shells after a successful handoff.
    for page,e in pairs(v.pages)do
        if v.native.state.owners[page]~=v.id and valid(e) then e:Remove()end
    end
    variants.banks.hosted=nil;variants.banks.classic=active
    variants.migrated=true
    v.retired=true
    v.journal_namespace="sv4_"..v.session.."_exchange_v1"
    self.phase="committed"
    print("[ExchangeMigration2hm] committed",v.id)
end
function Migration:Receive(v,peer,m)
    local connection=v.transport.peers[peer]
    if not connection or m.boot~=connection.boot then return end
    if m.kind=="STATE" and v.master then self.states[peer]=m
    elseif peer==tostring(SHARDID.MASTER) then
        if m.kind=="PREPARE" then self:Prepare(v)
        elseif m.kind=="COMMIT" then self:Commit(v) end
    end
end
function Migration:Tick(v)
    if not v.journal or not v.journal.ready or v.error then return end
    if self.phase=="returning" then
        v.native:Adopt()
        self:ResolveHeld(v)
        if self:Quiet(v) then
            for page,owner in pairs(v.native.state.owners)do
                local home=Config.PageShard(page)
                if owner==v.id and home~=v.id then
                    local destination=v.master and home or tostring(SHARDID.MASTER)
                    if v.transport.peers[destination] then v.native:Transfer(page,destination)end
                    break
                end
            end
        end
    end
    if GetStaticTime()<(self.nextsend or 0) then return end
    self.nextsend=GetStaticTime()+.5
    if v.master then
        for peer in pairs(v.transport.peers)do v.native:Broadcast(peer)end
        if self:All(v,"returning") then self:Prepare(v)end
        if self.phase=="prepared" then
            for peer in pairs(self:Members(v))do if peer~=v.id then self:Send(v,peer,"PREPARE")end end
            if self:All(v,"prepared") then self:Commit(v)end
        end
        if self.phase=="committed" then
            for peer in pairs(self:Members(v))do if peer~=v.id then self:Send(v,peer,"COMMIT")end end
            if self:All(v,"committed") and not self.saverequest then
                self.saverequest=true
                v.inst:PushEvent("ms_save")
            end
        end
    else self:Send(v,tostring(SHARDID.MASTER),"STATE")end
end
function Migration:Saved()
    if self.phase~="committed" then return end
    local variants=self.variants
    for _,e in pairs(variants.banks.classic)do variants:Freeze(e,false)end
    variants.ready=true;variants.migrating=nil;variants.saved=nil
    self.phase="done"
    print("[ExchangeMigration2hm] saved and opened",TheShard:GetShardId())
end
return Migration
