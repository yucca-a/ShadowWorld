-- Two-shard checkpoint coordinator. Exchanges never call SaveGame. Normal
-- saves/exit requests freeze new exchanges and migrations, drain work already
-- in flight, then save and seal one common world/player cut before reopening.
local Store = require("worldexchangestore2hm")
local Checkpoint = {}
Checkpoint.__index = Checkpoint

function Checkpoint.new(io, store, loaded, requested)
    local cut = loaded and store.state.cuts[loaded]
    local owners = Store.Copy(cut and cut.owners or {})
    if not cut then
        for uid, baseline in pairs(store.state.baselines or {}) do owners[uid] = baseline.owner end
    end
    return setmetatable({io = io, store = store, loaded = loaded, generation = loaded,
        requested = requested, phase = "joining", peers = {}, owners = owners,
        registrations = {}, outbound = {}, inbound = {}, arrived = {}, departures = 0, callbacks = {}, lastsend = -100,
        lastcut = io.now(), lastpeer = io.now()}, Checkpoint)
end

function Checkpoint:Generation() return self.generation end
function Checkpoint:IsReady() return self.phase == "ready" and not self.exiting and not self.exitready and not self.suspended end
function Checkpoint:IsFrozen()
    return self.suspended or (self.phase ~= "ready" and self.phase ~= "draining" and self.phase ~= "frozen" and self.phase ~= "capture_wait")
end
function Checkpoint:CanExchange(peer) return self:IsReady() and self.generation ~= nil and self.peer == peer and not self.regbusy end
function Checkpoint:CanReceive(peer) return not self:IsFrozen() and self.peer == peer end
function Checkpoint:Dirty() self.dirty = true end
function Checkpoint:Fail(reason)
    if self.phase == "error" then return end
    self.phase, self.error = "error", reason
    self.io.hold(true)
    self.io.log("checkpoint protection: " .. tostring(reason))
end
function Checkpoint:Send(kind, extra)
    if not self.peer then return end
    local m = {v = 3, kind = "CHECKPOINT", op = kind, exiting = self.exiting or self.peerexitrequested or nil}
    for k, v in pairs(extra or {}) do m[k] = v end
    self.io.send(self.peer, m)
end
function Checkpoint:Info()
    local cuts = {}
    for id, cut in pairs(self.store.state.cuts) do cuts[id] = cut.serial end
    return {cuts = cuts, loaded = self.loaded, current = self.store.state.current,
        requested = self.requested, phase = self.phase, boot = self.io.boot,
        ready = self.io.bootready(), generation = self.generation}
end
function Checkpoint:Connected(peer, boot)
    if self.phase == "error" then return end
    local changed = self.peer ~= peer or self.peerboot ~= boot
    if self.peer and self.peer ~= peer then self:Fail("only_two_shards_supported"); return end
    if self.peerboot and self.peerboot ~= boot then
        self.phase, self.remote = "joining", nil
        self.io.hold(self.generation ~= nil or next(self.store.state.cuts) ~= nil)
    elseif self.suspended then self.io.hold(false)
    end
    self.suspended = nil
    self.peer, self.peerboot, self.lastpeer = peer, boot, self.io.now()
    if changed then
        self.lastsend = -100
        self:Send("INFO", self:Info())
        if self.io.wake then self.io.wake() end
    end
end
function Checkpoint:Disconnected(peer)
    if peer ~= self.peer or self.phase == "error" then return end
    self.suspended, self.remote = true, nil
    -- A pristine/newly regenerated world has no exchange history to restore.
    -- Only cross-world operations need to wait for its peer, not movement.
    self.io.hold(self.generation ~= nil or next(self.store.state.cuts) ~= nil)
    -- Either side may close immediately after the shared cut is sealed. An
    -- exit already waiting on that proven cut must not wait forever for OPEN.
    if self.exiting and self.phase == "activating" and
        (self.activation or (self.io.master and self.peerloaded == self.generation)) then self:Open() end
end

function Checkpoint:Request(callback, exiting)
    if callback then table.insert(self.callbacks, callback) end
    self.want = true
    if exiting then self.exiting = true end
    self.lastsend = -100
    if self.io.wake then self.io.wake() end
end

function Checkpoint:Register(uid, owner, raw, callback)
    if self.registrations[uid] then
        if callback then table.insert(self.registrations[uid].callbacks, callback) end
        return
    end
    if self.store.state.registry[uid] then if callback then callback(true) end; return end
    local reg = {owner = owner, raw = raw, callbacks = {}, localdone = false}
    if callback then table.insert(reg.callbacks, callback) end
    self.registrations[uid], self.regbusy = reg, true
    self.owners[uid] = owner
    self.store:Register(uid, owner, raw, function(ok, reason)
        if not ok then self:Fail(reason); return end
        reg.localdone = true
        self.lastsend = -100
        if not self.generation then self:CompleteRegistration(uid) end
    end)
end

function Checkpoint:CompleteRegistration(uid)
    local reg = self.registrations[uid]
    if not reg then return end
    self.registrations[uid] = nil
    self.regbusy = next(self.registrations) ~= nil
    for _, callback in ipairs(reg.callbacks) do callback(true) end
end

function Checkpoint:CanMigrate(uid)
    return self:IsReady() and not self.registrations[uid] and not self.outbound[uid] and not self.inbound[uid]
        and self.store.state.registry[uid] == true
end
function Checkpoint:Depart(uid)
    self.departures = self.departures + 1
    local token = self.io.id .. "/" .. self.io.boot .. "/" .. self.departures
    self.outbound[uid] = token
    return token
end
function Checkpoint:Arrived(uid, token, origin)
    self.owners[uid] = self.io.id
    if not token then return end -- A login on the current owner is not a migration.
    if origin == self.io.id then
        if self.outbound[uid] == token then self.outbound[uid] = nil end
        return -- Native failed-migration return to the source.
    end
    self.inbound[uid] = token
    self.lastsend = -100
    if self.io.wake then self.io.wake() end
end
function Checkpoint:Idle()
    return self.io.idle() and not self.regbusy and not next(self.outbound) and not next(self.inbound) and not self.store.busy
end

function Checkpoint:Begin()
    if self.phase ~= "ready" or not self.io.master then return end
    local serial = (self.store.state.nextserial or 0) + 1
    self.pending = {id = self.io.id .. "/" .. self.io.boot .. "/" .. serial, serial = serial}
    self.phase, self.want, self.lastsend = "draining", nil, -100
end

function Checkpoint:Choose()
    local remote = self.remote
    if not remote or not remote.ready or not self.io.bootready() then return end
    local chosen, serial
    local cap
    for _, requested in ipairs({self.requested or false, remote.requested or false}) do
        if requested then
            local own, other = self.store.state.cuts[requested], remote.cuts[requested]
            if not own or not other then self:Fail("manual_checkpoint_missing"); return end
            cap = math.min(cap or own.serial, own.serial)
        end
    end
    for id, cut in pairs(self.store.state.cuts) do
        if remote.cuts[id] == cut.serial and (not cap or cut.serial <= cap) and (not serial or cut.serial > serial) then
            chosen, serial = id, cut.serial
        end
    end
    if not chosen then
        if next(self.store.state.cuts) or next(remote.cuts) then self:Fail("no_common_checkpoint"); return end
        if not self.io.idle() then return end
        -- New worlds already have a native save. Establish the first shared
        -- cut on a real save/exchange request, not during world entry.
        self.phase, self.generation = "ready", nil
        self.io.hold(false)
        if self.want then self:Begin() end
        return
    end
    self.selection = {id = chosen, manual = cap ~= nil}
    self:Send("SELECT", self.selection)
    self:Select(chosen, cap ~= nil)
end

function Checkpoint:Select(id, manual)
    if self.selecting or self.phase == "error" then return end
    local cut = self.store.state.cuts[id]
    if not cut then self:Fail("selected_checkpoint_missing"); return end
    if self.loaded == id and not self.opened and self.io.idle() and self.phase == "joining" then
        self.phase = "loading"
        local function sealed(ok, reason)
            if not ok then self:Fail(reason); return end
            self.generation, self.phase, self.activation = id, "activating", nil
            self.lastsend = -100
            self:Send("LOADED", {id = id})
            if self.io.wake then self.io.wake() end
        end
        if manual then
            self.store:Select(id, true, function(ok, reason)
                if not ok then self:Fail(reason); return end
                self.store:Seal(id, sealed)
            end)
        elseif self.store.state.current == id and not self.store.state.forced then
            -- Load already verified this committed journal and world body.
            -- Rewriting the same journal adds disk latency to every login.
            sealed(true)
        else self.store:Seal(id, sealed) end
        return
    end
    if self.phase == "joining" then
        self.selecting = true
        self.io.hold(true)
        self.store:Select(id, manual, function(ok, reason)
            if not ok then self:Fail(reason); return end
            self.io.restart()
        end)
    end
end

function Checkpoint:Receive(peer, m)
    if peer ~= self.peer or m.v ~= 3 or m.kind ~= "CHECKPOINT" or self.phase == "error" then return end
    local before = self.phase
    local op = m.op
    if m.exiting == true then self.peerexitrequested = true end
    if op == "ROLLBACK_HINT" and not self.io.master then
        local cut = self.store.state.cuts[m.id]
        if not cut or cut.serial ~= m.serial then return end
        if self.selecting or (not self.opened and self.loaded == m.id) then return end
        -- Advisory from the authenticated master after native truncation. Start
        -- loading the verified target in parallel with the master's restart.
        -- A lost hint is harmless: the regular INFO/SELECT recovery still runs.
        self.requested, self.phase = m.id, "joining"
        self.io.hold(true)
        self.io.log("preloading rollback checkpoint " .. m.id)
        self:Select(m.id, true)
    elseif op == "INFO" then
        if type(m.cuts) ~= "table" or type(m.boot) ~= "string" or m.boot ~= self.peerboot then return end
        self.remote = m
        if self.io.master and self.phase == "joining" then self:Choose() end
        if not self.io.master and self.phase == "joining" and m.ready and self.io.bootready() and
            not next(self.store.state.cuts) and not next(m.cuts) then
            self.phase, self.lastsend = "ready", -100
            self.io.hold(false)
        end
    elseif op == "SELECT" and not self.io.master and type(m.id) == "string" then
        self:Select(m.id, m.manual == true)
    elseif op == "LOADED" and self.io.master and self.selection and m.id == self.selection.id then
        self.peerloaded = m.id
        self.lastsend = -100
    elseif op == "ACTIVATE" and m.id == self.generation and self.phase == "activating" then
        self.activation = true
        self:Send("ACTIVE", {id = m.id})
    elseif op == "ACTIVE" and self.io.master and m.id == self.generation and self.phase == "activating" then
        self:Send("OPEN", {id = m.id})
        self:Open()
    elseif op == "OPEN" and not self.io.master and self.activation and m.id == self.generation and self.phase == "activating" then
        self:Open()
    elseif op == "REQUEST" and self.io.master then self.want = true
    elseif op == "FREEZE" and not self.io.master and type(m.id) == "string" and type(m.serial) == "number" then
        if self.phase == "ready" or (self.phase == "joining" and not next(self.store.state.cuts) and self.io.bootready()) then
            self.pending = {id = m.id, serial = m.serial}
            self.phase, self.lastsend = "draining", -100
        elseif not self.pending or self.pending.id ~= m.id then return end
    elseif op == "DRAINED" and self.io.master and self.pending and m.id == self.pending.id and type(m.owners) == "table" then
        self.peerdrained, self.peerowners = m.id, m.owners
    elseif op == "CAPTURE" and not self.io.master and self.pending and self.pending.id == m.id and self.phase == "frozen" and type(m.owners) == "table" then
        self.phase, self.owners = "capture_wait", Store.Copy(m.owners)
    elseif op == "PREPARED" and self.io.master and self.pending and self.pending.id == m.id then
        self.peerprepared = m.id
    elseif op == "SEAL" and not self.io.master and self.pending and self.pending.id == m.id and self.phase == "prepared" and self:Idle() then
        self:Seal()
    elseif op == "SEALED" and self.io.master and self.pending and self.pending.id == m.id then self.peersealed = m.id
    elseif op == "REGISTER" and type(m.uid) == "string" and #m.uid <= 100 and type(m.owner) == "string" then
        if self.store.state.registry[m.uid] then self:Send("REGISTERED", {uid = m.uid}); return end
        if self.registrations[m.uid] then return end
        self.registrations[m.uid], self.regbusy = {owner = m.owner, callbacks = {}, remote = true}, true
        self.owners[m.uid] = m.owner
        self.store:Register(m.uid, m.owner, false, function(ok, reason)
            if not ok then self:Fail(reason); return end
            self:CompleteRegistration(m.uid)
            self:Send("REGISTERED", {uid = m.uid})
        end)
    elseif op == "REGISTERED" and self.registrations[m.uid] and self.registrations[m.uid].localdone then
        self:CompleteRegistration(m.uid)
    elseif op == "ARRIVED" and type(m.uid) == "string" and type(m.token) == "string" and self.store.state.registry[m.uid] then
        if self.outbound[m.uid] == m.token then
            self.owners[m.uid], self.outbound[m.uid], self.arrived[m.uid] = peer, nil, m.token
        end
        if self.arrived[m.uid] == m.token then self:Send("ARRIVED_ACK", {uid = m.uid, token = m.token}) end
    elseif op == "ARRIVED_ACK" and self.inbound[m.uid] == m.token then self.inbound[m.uid] = nil end
    if self.phase ~= before then self.lastsend = -100 end
    if self.io.wake then self.io.wake() end
end

function Checkpoint:Saved(cut, world)
    if self.phase ~= "saving" or not self.pending or self.pending.id ~= cut.id then return end
    self.store:PutCut(cut, world, function(ok, reason)
        if not ok then self:Fail(reason); return end
        self.phase, self.lastsend = "prepared", -100
        if self.io.wake then self.io.wake() end
    end)
end
function Checkpoint:Seal()
    if self.phase ~= "prepared" then return end
    self.phase = "sealing"
    self.store:Seal(self.pending.id, function(ok, reason)
        if not ok then self:Fail(reason); return end
        self.generation, self.loaded = self.pending.id, self.pending.id
        self.phase, self.lastsend = "sealed", -100
        if self.io.wake then self.io.wake() end
    end)
end
function Checkpoint:Open()
    self.exitready = self.exiting or self.peerexitrequested or nil
    self.phase, self.dirty, self.requested = "ready", false, nil
    self.opened, self.activation, self.want = true, nil, nil
    self.pending, self.selection, self.peerloaded = nil, nil, nil
    self.peerdrained, self.peerprepared, self.peersealed = nil, nil, nil
    self.lastcut = self.io.now()
    self.io.hold(false)
    local callbacks = self.callbacks; self.callbacks = {}
    for _, callback in ipairs(callbacks) do callback() end
end

function Checkpoint:Tick()
    if self.phase == "error" or self.selecting then return end
    if not self.peer then return end
    if not self.io.connected(self.peer, self.peerboot) then
        if not self.suspended then self:Disconnected(self.peer) end
        return
    end
    if self.suspended then return end
    if self.io.master and self.phase == "ready" and self.want and not self.exitready then self:Begin() end
    if self.phase == "draining" and self:Idle() then
        self.phase, self.lastsend = "frozen", -100
    end
    if self.io.master and self.phase == "frozen" and self.peerdrained == self.pending.id then
        local matching = true
        for uid, owner in pairs(self.peerowners) do
            -- A migration can finish after the peer sent DRAINED. Wait for its
            -- refreshed owner map instead of accepting the stale one.
            if self.owners[uid] and self.owners[uid] ~= owner then matching = false end
        end
        if matching then
            for uid, owner in pairs(self.peerowners) do self.owners[uid] = owner end
            self.phase = "capture_wait"
            self:Send("CAPTURE", {id = self.pending.id, owners = self.owners})
        end
        -- A stale DRAINED map must not stop REGISTER/ARRIVED retries below.
    end
    if self.phase == "capture_wait" and self:Idle() then
        self.phase = "saving"
        self.io.save(self.pending, self.owners)
    end
    if self.io.master and self.phase == "prepared" and self.peerprepared == self.pending.id and self:Idle() then
        self:Send("SEAL", {id = self.pending.id}); self:Seal()
    end
    if self.io.master and self.phase == "sealed" and self.peersealed == self.pending.id then
        self.phase, self.peerloaded = "activating", self.pending.id
        self.selection = {id = self.pending.id}
        self:Send("ACTIVATE", {id = self.generation})
    end
    local now = self.io.now()
    if now - self.lastsend < .5 then return end
    self.lastsend = now
    if self.phase == "joining" then self:Send("INFO", self:Info())
    elseif self.phase == "ready" then
        if self.want then self:Send("REQUEST") end
        if self.generation then self:Send("OPEN", {id = self.generation})
        else self:Send("INFO", self:Info()) end
    elseif self.phase == "draining" or self.phase == "frozen" then
        if self.io.master then self:Send("FREEZE", self.pending)
        elseif self.phase == "frozen" then self:Send("DRAINED", {id = self.pending.id, owners = self.owners}) end
    elseif self.phase == "saving" then
        if self.io.master then self:Send("CAPTURE", {id = self.pending.id, owners = self.owners}) end
    elseif self.phase == "prepared" then
        if self.io.master then self:Send("CAPTURE", {id = self.pending.id, owners = self.owners})
        elseif self:Idle() then self:Send("PREPARED", {id = self.pending.id}) end
    elseif self.phase == "sealed" then
        if self.io.master then self:Send("SEAL", {id = self.pending.id})
        else self:Send("SEALED", {id = self.pending.id}); self.phase = "activating" end
    elseif self.phase == "activating" then
        if self.io.master then
            if self.peerloaded == self.generation then self:Send("ACTIVATE", {id = self.generation})
            elseif self.selection then self:Send("SELECT", self.selection) end
        elseif self.activation then self:Send("ACTIVE", {id = self.generation})
        else self:Send("LOADED", {id = self.generation}); if self.pending then self:Send("SEALED", {id = self.generation}) end end
    end
    for uid, reg in pairs(self.registrations) do
        if reg.localdone then self:Send("REGISTER", {uid = uid, owner = reg.owner}) end
    end
    for uid, token in pairs(self.inbound) do self:Send("ARRIVED", {uid = uid, token = token}) end
end

return Checkpoint
