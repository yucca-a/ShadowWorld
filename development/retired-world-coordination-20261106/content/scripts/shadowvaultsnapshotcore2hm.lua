-- Runtime transfers never request a save. This controller only handles an
-- existing native save request and the selection of its recovery images.
-- The master's committed vector is authoritative; absent shards rejoin lazily.
local Core = {}
Core.__index = Core
local copy = deepcopy
local Movement=require("shadowvaultmovement2hm")

function Core.new(io, store, loaded)
    local cut = assert(store.state.cuts[loaded], "missing vault baseline")
    return setmetatable({io=io,store=store,loaded=loaded,generation=loaded,
        refs=copy(cut.refs or {[io.id]={session=io.session,id=loaded}}),
        movement_refs=copy(cut.movement_refs or {[io.id]=cut.movements or Movement.Empty()}),
        phase=io.master and "ready" or "joining",peers={},dirty={},callbacks={},aborted={},discarded={},abortout={},lastsend=-100},Core)
end
function Core:Fail(reason)
    self.error,self.phase=reason,"error"
    self.io.fail(reason)
end
function Core:Send(peer,op,data)
    local m=copy(data or {});m.vault=3;m.kind="SNAPSHOT";m.op=op
    self.io.send(peer,m)
end
function Core:Connected(peer,info)
    if not self.io.master and peer~=self.io.masterid then return end
    local old=self.peers[peer]
    if old and old.boot==info.boot then return end
    -- A boot explicitly restored under this master's decision is already
    -- aligned. Its one-boot proof prevents a cascading recovery restart.
    local expected=self.refs[peer]
    local aligned=self.io.master and expected and info.recovery_parent==self.io.boot and
        info.recovery_cut==expected.id and info.session==expected.session
    if old and not aligned then
        -- Native travel can happen while every mod packet is lost. Absence of
        -- a mod-side Dirty notification cannot prove a restarted peer is clean.
        self.phase="recovering";self.io.restart(self.loaded,not self.io.master and info.boot or nil);return
    end
    self.peers[peer]={boot=info.boot,session=info.session}
    if not self.io.master then self.phase="joining" end
    self.lastsend=-100
end
function Core:Disconnected(peer)
    if not self.io.master and peer~=self.io.masterid then return end
    if self.io.master and self.pending and self.pending.participants[peer] and self.phase~="committing" then
        -- A native disconnect can be reported just after capture participants
        -- were selected. Abandon that attempt; a retry may omit a clean absent
        -- peer, with movement validation still protecting its older reference.
        self:YieldForTravel()
    end
    -- Connectivity is checked separately by io.connected. Preserve readiness,
    -- pending save phase and boot evidence across a temporary wire outage;
    -- otherwise a draining peer could never finish the original handshake.
end
function Core:Generation() return self.generation end
function Core:IsFrozen()
    return self.error~=nil or (self.phase~="ready" and self.phase~="draining")
end
function Core:CanExchange(peer)
    local p=self.peers[peer]
    return self.phase=="ready" and p and p.ready and self.io.connected(peer,p.boot) and not self.want
end
function Core:CanReceive(peer)
    local p=self.peers[peer]
    return not self:IsFrozen() and p and p.ready and self.io.connected(peer,p.boot)
end
function Core:Dirty(peer)
    self.runtime_dirty=true
    if peer then self.dirty[peer]=true end
end
function Core:Request(callback,shutdown)
    if callback then self.callbacks[#self.callbacks+1]=callback end
    self.want=true;self.shutdown=self.shutdown or shutdown
    self.lastsend=-100
end
function Core:YieldLocal(id)
    if type(id)~="string" or #id>250 then return false end
    local known=self.store.state.cuts[id]
    if known and known.committed or self.pending and self.pending.id==id and self.phase=="committing" then return false end
    self.aborted[id]=true
    self.discarded[id]=true
    if self.pending and self.pending.id==id then
        self.pending=nil;self.phase="ready";self.lastsend=-100
    end
    return true
end
function Core:YieldForTravel()
    if self.phase=="ready" then return true end
    if not self.io.master or not self.pending or self.phase=="committing" then return false end
    local pending=self.pending
    if not self:YieldLocal(pending.id) then return false end
    self.lastyield=pending.id
    local waiting={}
    for peer in pairs(pending.participants) do
        if peer~=self.io.id then waiting[peer]=true;self:Send(peer,"YIELD",{id=pending.id}) end
    end
    if next(waiting) then self.abortout[pending.id]=waiting end
    return true
end
function Core:Begin()
    if self.retryat and self.io.now()<self.retryat then return end
    if self.retry_revisions then
        local changed=false
        for peer,revision in pairs(self.retry_revisions) do
            local live=peer==self.io.id and (self.io.movement_revision and self.io.movement_revision() or 0) or
                self.peers[peer] and self.peers[peer].live_revision
            if live~=nil and live~=revision then changed=true;break end
        end
        -- An unfinished native trip must not cause repeated whole-world writes.
        -- Retry only when a participant reports new native movement evidence.
        if not changed then return end
        self.retry_revisions=nil
    end
    if self.io.travelidle and not self.io.travelidle() then return end
    -- A natively connected shard can already receive a migrating player even
    -- before the mod handshake. It must join the recovery vector before saving.
    for peer in pairs(self.io.nativepeers and self.io.nativepeers() or {}) do
        if peer~=self.io.id and (not self.peers[peer] or not self.peers[peer].ready) then return end
    end
    for _,waiting in pairs(self.abortout) do
        for peer in pairs(waiting) do
            local p=self.peers[peer]
            if p and self.io.connected(peer,p.boot) then return end
        end
    end
    local participants={[self.io.id]=true}
    for peer in pairs(self.dirty) do
        local p=self.peers[peer]
        if not p or not p.ready or not self.io.connected(peer,p.boot) then return end
    end
    for peer,p in pairs(self.peers) do
        if p.ready and self.io.connected(peer,p.boot) then participants[peer]=true end
    end
    local serial=math.max(self.serial or 0,self.store.state.nextserial or 0)+1
    self.serial=serial
    self.pending={id=self.io.id.."_"..self.io.boot.."_"..serial,serial=serial,
        generation=self.generation,participants=participants,parent=self.loaded,refs=copy(self.refs),historylimit=self.io.historylimit and self.io.historylimit()}
    self.drained,self.prepared={},{}
    self.phase="draining";self.lastsend=-100
end
function Core:Capture()
    self.phase="capturing"
    local pending=self.pending
    self.io.capture(pending,function(ok,reason)
        if self.pending~=pending then return end
        if not ok then self:Fail(reason or "snapshot_capture_failed");return end
        self.phase="prepared"
        self.prepared[self.io.id]=copy(self.store.state.cuts[pending.id].movements or Movement.Empty())
        self.lastsend=-100
    end)
end
function Core:All(map)
    for peer in pairs(self.pending.participants) do if not map[peer] then return false end end
    return true
end
function Core:Commit()
    local pending=self.pending
    local movements=copy(self.movement_refs)
    for peer in pairs(pending.participants) do movements[peer]=copy(self.prepared[peer]) end
    if not Movement.Coherent(movements) then
        -- Crossing continued natively between two captures. These images may
        -- not be committed together. Retry the existing save in the background.
        self.retry_revisions={}
        for peer in pairs(pending.participants) do self.retry_revisions[peer]=self.prepared[peer].revision or 0 end
        self:YieldForTravel();self.retryat=self.io.now()+2
        return
    end
    self.phase="committing"
    local refs=copy(pending.refs)
    for peer in pairs(pending.participants) do
        refs[peer]={session=peer==self.io.id and self.io.session or self.peers[peer].session,id=pending.id}
    end
    self.store:Update(function(state)
        local cut=assert(state.cuts[pending.id],"missing prepared image")
        cut.committed,cut.refs=true,copy(refs)
        cut.movement_refs=copy(movements)
        state.current=pending.id;state.forced=nil
    end,function(ok,reason)
        if not ok then self:Fail(reason or "snapshot_commit_failed");return end
        self.refs=refs;self.movement_refs=movements;self.loaded=pending.id;self.generation=pending.id
        self.dirty={};self.runtime_dirty=nil;self.committed=pending;self.pending=nil
        self.phase="ready";self.want=nil;self.lastsend=-100
        self.aborted={};self.shutdown=nil
        for peer in pairs(pending.participants) do
            if peer~=self.io.id then self.peers[peer].ready=nil end
        end
        local callbacks=self.callbacks;self.callbacks={}
        for _,cb in ipairs(callbacks) do cb() end
    end)
end
function Core:Receive(peer,m)
    local p=self.peers[peer]
    if not p or type(m)~="table" or m.vault~=3 or m.kind~="SNAPSHOT" or self.error then return end
    local op=m.op
    if self.io.master and op=="INFO" and type(m.loaded)=="string" and #m.loaded<=250 then
        p.live_revision=m.live_revision
        local ref=self.refs[peer]
        if not ref then
            if self.phase~="ready" or p.registering then return end
            p.registering=true
            local added={session=p.session,id=m.loaded}
            self.store:Update(function(state)
                local cut=assert(state.cuts[self.loaded])
                cut.refs=cut.refs or copy(self.refs);cut.refs[peer]=copy(added)
                cut.movement_refs=cut.movement_refs or copy(self.movement_refs)
                cut.movement_refs[peer]=copy(m.movements or Movement.Empty())
            end,function(ok,why)
                p.registering=nil
                if not ok then self:Fail(why);return end
                self.refs[peer]=added;self.movement_refs[peer]=copy(m.movements or Movement.Empty());self.lastsend=-100
            end)
            return
        end
        if ref.session~=p.session then self:Fail("shard_session_changed");return end
        if ref.id~=m.loaded then self:Send(peer,"ALIGN",{id=ref.id});return end
        if self.phase=="ready" then self:Send(peer,"OPEN",{id=self.generation,loaded=ref.id}) end
    elseif not self.io.master and peer==self.io.masterid and op=="ALIGN" and type(m.id)=="string" then
        if m.id~=self.loaded then
            if not self.store.state.cuts[m.id] then self:Fail("required_shard_snapshot_missing");return end
            self.phase="recovering";self.io.restart(m.id,p.boot)
        end
    elseif not self.io.master and peer==self.io.masterid and op=="OPEN" and m.loaded==self.loaded and type(m.id)=="string" then
        if self.phase=="joining" or self.phase=="ready" then
            self.generation=m.id;self.phase="ready";p.ready=true
            self:Send(peer,"OPENED",{id=m.id,loaded=self.loaded})
        end
    elseif self.io.master and op=="OPENED" and m.id==self.generation and self.refs[peer] and m.loaded==self.refs[peer].id then
        p.ready=true
    elseif self.io.master and op=="REQUEST" then self:Request()
    elseif not self.io.master and peer==self.io.masterid and op=="YIELD" then
        if self:YieldLocal(m.id) then self:Send(peer,"YIELDED",{id=m.id}) end
    elseif self.io.master and op=="YIELDED" and self.abortout[m.id] then
        self.abortout[m.id][peer]=nil
        if not next(self.abortout[m.id]) then self.abortout[m.id]=nil end
    elseif not self.io.master and peer==self.io.masterid and op=="FREEZE" and type(m.id)=="string" and type(m.serial)=="number" then
        local known=self.store.state.cuts[m.id]
        if self.phase=="ready" and m.generation==self.generation and not self.aborted[m.id] and not (known and known.committed) then
            self.pending={id=m.id,serial=m.serial,parent=self.loaded,participants=m.participants,refs=m.refs,historylimit=m.historylimit}
            self.phase="draining";self.prepared={};self.lastsend=-100
        end
    elseif self.io.master and op=="DRAINED" and self.pending and m.id==self.pending.id and self.pending.participants[peer] then
        self.drained[peer]=true
    elseif not self.io.master and peer==self.io.masterid and op=="CAPTURE" and self.pending and m.id==self.pending.id and self.phase=="frozen" then
        self:Capture()
    elseif self.io.master and op=="PREPARED" and self.pending and m.id==self.pending.id and self.pending.participants[peer] then
        if type(m.movements)=="table" then self.prepared[peer]=copy(m.movements) end
    elseif not self.io.master and peer==self.io.masterid and op=="COMMIT" and self.pending and m.id==self.pending.id and self.phase=="prepared" then
        self.phase="committing"
        self.store:Update(function(state)
            local cut=assert(state.cuts[m.id]);cut.committed=true;cut.refs=copy(m.refs)
            state.current=m.id;state.forced=nil
        end,function(ok,why)
            if not ok then self:Fail(why);return end
            self.loaded,self.generation=m.id,m.id;self.refs=copy(m.refs)
            self.runtime_dirty=nil
            self.pending=nil;self.phase="ready";self.want=nil;p.ready=true
            self.aborted={};self.shutdown=nil
            self:Send(peer,"OPENED",{id=m.id,loaded=m.id})
            local callbacks=self.callbacks;self.callbacks={}
            for _,cb in ipairs(callbacks) do cb() end
        end)
    end
end
function Core:Tick()
    if self.error or self.phase=="recovering" then return end
    if self.io.master and self.phase=="ready" and self.want then self:Begin() end
    if self.phase=="draining" and self.io.idle() then
        self.phase="frozen";self.lastsend=-100
        if self.io.master then self.drained[self.io.id]=true end
    end
    if self.io.master and self.phase=="frozen" and self:All(self.drained) then self:Capture() end
    if self.io.master and self.phase=="prepared" and self:All(self.prepared) then self:Commit() end
    local now=self.io.now()
    if now-self.lastsend<.5 then return end
    self.lastsend=now
    for id,waiting in pairs(self.abortout) do
        for peer in pairs(waiting) do self:Send(peer,"YIELD",{id=id}) end
    end
    if not self.io.master then
        local peer=self.io.masterid
        if self.phase=="joining" or self.phase=="ready" then
            self:Send(peer,"INFO",{loaded=self.loaded,movements=self.store.state.cuts[self.loaded].movements or Movement.Empty(),
                live_revision=self.io.movement_revision and self.io.movement_revision() or 0})
            if self.want then self:Send(peer,"REQUEST") end
        elseif self.phase=="frozen" then self:Send(peer,"DRAINED",{id=self.pending.id})
        elseif self.phase=="prepared" then self:Send(peer,"PREPARED",{id=self.pending.id,movements=self.prepared[self.io.id]}) end
    elseif self.pending then
        for peer in pairs(self.pending.participants) do
            if peer~=self.io.id then
                if not self.drained[peer] then self:Send(peer,"FREEZE",self.pending)
                elseif self.phase=="prepared" and not self.prepared[peer] then self:Send(peer,"CAPTURE",{id=self.pending.id}) end
            end
        end
    elseif self.committed then
        for peer in pairs(self.committed.participants) do
            if peer~=self.io.id and not self.peers[peer].ready then
                self:Send(peer,"COMMIT",{id=self.committed.id,refs=self.refs})
            end
        end
    end
end
return Core
