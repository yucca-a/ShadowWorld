-- Shard checkpoint coordinator. Exchanges never call SaveGame. Normal
-- saves/exit requests drain work in flight before capturing a shared cut.
-- Travel can resume once all native snapshots are captured.
local Store = require("worldexchangestore2hm")
local Checkpoint = {}
Checkpoint.__index = Checkpoint

function Checkpoint.new(io, store, loaded, requested)
    local cut = loaded and store.state.cuts[loaded]
    local owners = Store.Copy(cut and cut.owners or {})
    local members = Store.Copy(store.state.members or {})
    for id in pairs(cut and cut.members or {}) do members[id] = true end
    members[io.id] = true
    if not cut then
        for uid, baseline in pairs(store.state.baselines or {}) do owners[uid] = baseline.owner end
    end
    return setmetatable({io = io, store = store, loaded = loaded, generation = loaded,
        requested = requested, phase = "joining", peers = {}, offline = {}, reports = {}, owners = owners,
        members = members, discovered = io.now(),
        peerloaded = {}, peerdrained = {}, peercaptured = {}, peerprepared = {}, peersealed = {}, peeractive = {},
        registrations = {}, outbound = {}, inbound = {}, arrived = {}, arrivalacks = {},
        departures = 0, callbacks = {}, lastsend = -100,
        lastcut = io.now()}, Checkpoint)
end

function Checkpoint:Generation() return self.generation end
function Checkpoint:Discover(peer)
    if self.members[peer] then return end
    self.members[peer], self.membersdirty, self.discovered = true, true, self.io.now()
    if self.phase ~= "joining" and self.phase ~= "error" then
        self.phase, self.selection, self.pending, self.travelcut = "joining", nil, nil, nil
    end
    self.lastsend = -100
end

function Checkpoint:AllPeers(predicate)
    local hasPeer = false
    for peer in pairs(self.members) do
        if peer ~= self.io.id then
            local boot = self.peers[peer]
            if not boot or not predicate(peer, boot) then return false end
            hasPeer = true
        end
    end
    return hasPeer
end

function Checkpoint:HasPeer(peer)
    return self.peers[peer] ~= nil
end

function Checkpoint:IsReady()
    return self.phase == "ready" and not self.exiting and not self.exitready and not self.suspended and self.io.bootready()
        and self:AllPeers(self.io.connected)
end
function Checkpoint:IsFrozen()
    return not self.io.bootready() or self.suspended or not self:AllPeers(self.io.connected) or
        (self.phase ~= "ready" and self.phase ~= "draining" and self.phase ~= "frozen" and self.phase ~= "capture_wait")
end
function Checkpoint:CanExchange(peer) return self:IsReady() and self.generation ~= nil and self:HasPeer(peer) and not self.regbusy end
function Checkpoint:CanReceive(peer) return not self:IsFrozen() and self:HasPeer(peer) end
function Checkpoint:Dirty() self.dirty = true end
function Checkpoint:Fail(reason)
    if self.phase == "error" then return end
    self.phase, self.error = "error", reason
    self.io.log("checkpoint protection: " .. tostring(reason))
end
function Checkpoint:Send(kind, extra, target)
    local m = {v = 3, kind = "CHECKPOINT", op = kind, exiting = self.exiting or self.peerexitrequested or nil}
    for k, v in pairs(extra or {}) do m[k] = v end
    if target then self.io.send(target, m)
    else
        local encoded = self.io.encode and self.io.encode(m)
        for peer in pairs(self.peers) do self.io.send(peer, m, encoded) end
    end
end
function Checkpoint:Info()
    local cuts = {}
    for id, cut in pairs(self.store.state.cuts) do cuts[id] = cut.serial end
    return {cuts = cuts, loaded = self.loaded, current = self.store.state.current,
        members = self.members,
        requested = self.requested, phase = self.phase, boot = self.io.boot,
        ready = self.io.bootready(), generation = self.generation}
end
function Checkpoint:Connected(peer, boot)
    if self.phase == "error" then return end
    self:Discover(peer)
    local previous = self.peers[peer]
    local changed = previous ~= boot
    if previous and changed then
        self.phase, self.selection, self.travelcut = "joining", nil, nil
        self.reports = {}
        self.peerexitrequested = nil
    end
    self.offline[peer] = nil
    self.suspended = next(self.offline) ~= nil
    self.peers[peer] = boot
    -- Keep the coordinator address for secondary requests.
    if not self.peer or peer == (self.io.masterid or "1") then self.peer = peer end
    self.peerboot = self.peers[self.peer]
    if changed then
        self.lastsend = -100
        self:Send("INFO", self:Info(), peer)
        if self.io.wake then self.io.wake() end
    end
end
function Checkpoint:Disconnected(peer)
    if not self:HasPeer(peer) or self.phase == "error" then return end
    self.offline[peer], self.suspended, self.reports[peer] = true, true, nil
    if self:AwaitingExitActivation() then self:FinishActivation() end
end

function Checkpoint:AwaitingExitActivation()
    return self.io.master and self.exiting and self.phase == "activating" and
        self:AllPeers(function(peer) return self.peerloaded[peer] == self.generation end)
end

function Checkpoint:FinishActivation()
    if self:AllPeers(function(peer)
        return self.peeractive[peer] == self.generation or (self.exiting and self.offline[peer])
    end) then
        self:Send("OPEN", {id = self.generation})
        self:Open()
    end
end

function Checkpoint:Request(callback, exiting)
    if callback then table.insert(self.callbacks, callback) end
    self.want = true
    if exiting then self.exiting = true end
    self.lastsend = -100
    if self.io.wake then self.io.wake() end
end

function Checkpoint:Register(uid, owner, raw, callback)
    local pending = self.registrations[uid]
    if pending then
        if callback then
            if pending.localdone then callback(true)
            else table.insert(pending.callbacks, callback) end
        end
        return
    end
    if self.store.state.registry[uid] then if callback then callback(true) end; return end
    local reg = {owner = owner, callbacks = {}, acknowledged = {}}
    if callback then table.insert(reg.callbacks, callback) end
    self.registrations[uid], self.regbusy = reg, true
    self.owners[uid] = owner
    self.store:Register(uid, owner, raw, function(ok, reason)
        if not ok then self:Fail(reason); return end
        self:RegistrationWritten(reg)
        self.lastsend = -100
    end)
end

function Checkpoint:RegistrationWritten(reg)
    -- A player can spawn and save locally after the before-image is durable.
    -- Keep the registration pending for cross-shard operations until ACK.
    reg.localdone = true
    local callbacks = reg.callbacks
    reg.callbacks = nil
    for _, callback in ipairs(callbacks) do callback(true) end
end

function Checkpoint:CompleteRegistration(uid)
    self.registrations[uid] = nil
    self.regbusy = next(self.registrations) ~= nil
end

function Checkpoint:CanMigrate(uid, destination)
    -- A shard in the drain phase has not reported its final owner map yet.
    -- Depart records the migration before that shard can freeze or capture.
    local phase = self.phase
    local captured = self.pending and self.travelcut == self.pending.id and
        (phase == "saving" or phase == "prepared" or phase == "sealing" or phase == "sealed" or phase == "activating")
    if (phase ~= "ready" and phase ~= "draining" and not captured) or self.exiting or self.exitready or
        self.peerexitrequested or not self.io.bootready() or self.registrations[uid] or self.outbound[uid] or
        self.inbound[uid] or self.store.state.registry[uid] ~= true then return false end
    if not self.suspended and self:AllPeers(self.io.connected) then return true end
    -- An unrelated offline shard must not veto travel between live shards
    -- on the same committed cut. Arrival still converges on every member
    -- before this player can move again or a new checkpoint can be taken.
    local boot = destination and self.peers[destination]
    return self.phase == "ready" and self.generation ~= nil and boot ~= nil and
        not self.offline[destination] and self.io.connected(destination, boot) and
        self.io.migrationready and self.io.migrationready(destination, self.generation)
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
    self.arrivalacks[uid] = {}
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
    self.captured, self.travelcut = nil, nil
    self.peerdrained, self.peercaptured, self.peerprepared, self.peersealed, self.peeractive = {}, {}, {}, {}, {}
    self.phase, self.want, self.lastsend = "draining", nil, -100
end

function Checkpoint:Choose()
    if self.store.busy or not self.io.bootready() or not self:AllPeers(function(peer, boot)
        local report = self.reports[peer]
        if not (self.io.connected(peer, boot) and report and report.ready) then return false end
        if not report.members then return false end
        for id in pairs(self.members) do if not report.members[id] then return false end end
        return true
    end) then return end
    local chosen, serial
    local cap
    local requests = {self.requested or false}
    local hasCuts = next(self.store.state.cuts) ~= nil
    for _, report in pairs(self.reports) do
        requests[#requests + 1] = report.requested or false
        hasCuts = hasCuts or next(report.cuts) ~= nil
    end
    local function shared(id, cut)
        return self:AllPeers(function(peer) return self.reports[peer].cuts[id] == cut.serial end)
    end
    for _, requested in ipairs(requests) do
        if requested then
            local own = self.store.state.cuts[requested]
            if not own or not shared(requested, own) then self:Fail("manual_checkpoint_missing"); return end
            cap = math.min(cap or own.serial, own.serial)
        end
    end
    for id, cut in pairs(self.store.state.cuts) do
        if shared(id, cut) and (not cap or cut.serial <= cap) and (not serial or cut.serial > serial) then
            chosen, serial = id, cut.serial
        end
    end
    if not chosen then
        if hasCuts then self:Fail("no_common_checkpoint"); return end
        if not self.io.idle() or self.io.now() - self.discovered < 2 then return end
        -- New worlds already have a native save. Establish the first shared
        -- cut on a real save/exchange request, not during world entry.
        self.phase, self.generation = "ready", nil
        self:Send("INFO", self:Info())
        if self.want then self:Begin() end
        return
    end
    self.selection = {id = chosen, manual = cap ~= nil}
    self.peerloaded, self.peeractive = {}, {}
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
            if not self.io.master then self:Send("LOADED", {id = id}, self.io.masterid or "1") end
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
        self.store:Select(id, manual, function(ok, reason)
            if not ok then self:Fail(reason); return end
            self.io.restart()
        end)
    end
end

local coordinatorMessage = {
    ROLLBACK_HINT = true, SELECT = true, ACTIVATE = true, OPEN = true, FREEZE = true, CAPTURE = true, SEAL = true,
    TRAVEL_OPEN = true,
}

function Checkpoint:Receive(peer, m)
    if not self:HasPeer(peer) or m.v ~= 3 or m.kind ~= "CHECKPOINT" or self.phase == "error" then return end
    local before = self.phase
    local op = m.op
    if coordinatorMessage[op] and (self.io.master or peer ~= (self.io.masterid or "1")) then return end
    if m.exiting == true then self.peerexitrequested = true end
    if op == "ROLLBACK_HINT" and not self.io.master then
        local cut = self.store.state.cuts[m.id]
        if not cut or cut.serial ~= m.serial then return end
        if self.selecting or (not self.opened and self.loaded == m.id) then return end
        -- Advisory from the authenticated master after native truncation. Start
        -- loading the verified target in parallel with the master's restart.
        -- A lost hint is harmless: the regular INFO/SELECT recovery still runs.
        self.requested, self.phase = m.id, "joining"
        self.io.log("preloading rollback checkpoint " .. m.id)
        self:Select(m.id, true)
    elseif op == "INFO" then
        if type(m.cuts) ~= "table" or type(m.boot) ~= "string" or m.boot ~= self.peers[peer] then return end
        if type(m.members) ~= "table" then return end
        for id, known in pairs(m.members) do
            if type(id) == "string" and #id <= 40 and known == true then self:Discover(id) end
        end
        self.reports[peer] = m
        if self.io.master and self.phase == "joining" then self:Choose() end
        if self.phase == "ready" and m.phase == "joining" then self:Send("INFO", self:Info(), peer) end
        if not self.io.master and peer == (self.io.masterid or "1") and self.phase == "joining" and
            m.ready and self.io.bootready() and self:AllPeers(self.io.connected) and
            m.phase == "ready" and
            not next(self.store.state.cuts) and not next(m.cuts) then
            self.phase, self.lastsend = "ready", -100
        end
    elseif op == "SELECT" and not self.io.master and type(m.id) == "string" then
        self:Select(m.id, m.manual == true)
    elseif op == "LOADED" and self.io.master and self.selection and m.id == self.selection.id then
        self.peerloaded[peer] = m.id
        self.lastsend = -100
    elseif op == "ACTIVATE" and m.id == self.generation and self.phase == "activating" then
        self.activation = true
        self:Send("ACTIVE", {id = m.id}, peer)
        -- ACTIVATE is sent only after all participants have committed the cut.
        -- A shard already shutting down can finish without waiting for OPEN.
        if self.exiting then self:Open() end
    elseif op == "ACTIVATE" and self.exiting and m.id == self.opened_generation and self.phase == "ready" then
        self:Send("ACTIVE", {id = m.id}, peer)
    elseif op == "ACTIVE" and self.io.master and m.id == self.generation and self.phase == "activating" then
        self.peeractive[peer] = m.id
        self:FinishActivation()
    elseif op == "ACTIVE" and self.io.master and self.opened_generation and m.id == self.opened_generation and
        m.id == self.generation and self.phase ~= "joining" and self.phase ~= "loading" then
        -- A secondary retries ACTIVE until it receives OPEN. Reply only to
        -- that shard, even if the next checkpoint is already draining.
        self:Send("OPEN", {id = m.id}, peer)
    elseif op == "OPEN" and not self.io.master and self.activation and m.id == self.generation and self.phase == "activating" then
        self:Open()
    elseif op == "REQUEST" and self.io.master then self.want = true
    elseif op == "FREEZE" and not self.io.master and type(m.id) == "string" and type(m.serial) == "number" then
        if self.phase == "ready" or (self.phase == "joining" and not next(self.store.state.cuts) and self.io.bootready()) then
            self.pending = {id = m.id, serial = m.serial}
            self.phase, self.lastsend = "draining", -100
        elseif not self.pending or self.pending.id ~= m.id then return end
    elseif op == "DRAINED" and self.io.master and self.pending and m.id == self.pending.id and type(m.owners) == "table" then
        self.peerdrained[peer] = m.owners
    elseif op == "CAPTURE" and not self.io.master and self.pending and self.pending.id == m.id and self.phase == "frozen" and type(m.owners) == "table" then
        self.phase, self.owners = "capture_wait", Store.Copy(m.owners)
    elseif op == "TRAVEL_OPEN" and self.pending and self.pending.id == m.id and self.captured == m.id then
        self.travelcut = m.id
    elseif (op == "CAPTURED" or op == "PREPARED") and self.io.master and self.pending and self.pending.id == m.id then
        if not self.peercaptured[peer] then self.peercaptured[peer], self.lastsend = true, -100 end
        if op == "PREPARED" and self.peerprepared[peer] ~= m.id then self.peerprepared[peer], self.lastsend = m.id, -100 end
    elseif op == "SEAL" and not self.io.master and self.pending and self.pending.id == m.id and self.phase == "prepared" and self:Idle() then
        self:Seal()
    elseif op == "SEALED" and self.io.master and self.pending and self.pending.id == m.id then self.peersealed[peer] = m.id
    elseif op == "REGISTER" and type(m.uid) == "string" and #m.uid <= 100 and type(m.owner) == "string" then
        if self.store.state.registry[m.uid] then self:Send("REGISTERED", {uid = m.uid}, peer); return end
        if self.registrations[m.uid] then return end
        local reg = {owner = m.owner, callbacks = {}}
        self.registrations[m.uid], self.regbusy = reg, true
        self.owners[m.uid] = m.owner
        self.store:Register(m.uid, m.owner, false, function(ok, reason)
            if not ok then self:Fail(reason); return end
            self:RegistrationWritten(reg)
            self:CompleteRegistration(m.uid)
            self:Send("REGISTERED", {uid = m.uid}, peer)
        end)
    elseif op == "REGISTERED" and self.registrations[m.uid] and self.registrations[m.uid].localdone then
        local reg = self.registrations[m.uid]
        reg.acknowledged[peer] = self.peers[peer]
        if self:AllPeers(function(id, boot) return reg.acknowledged[id] == boot end) then self:CompleteRegistration(m.uid) end
    elseif op == "ARRIVED" and type(m.uid) == "string" and type(m.token) == "string" and self.store.state.registry[m.uid] then
        local origin, boot, sequence = m.token:match("^([^/]+)/([^/]+)/(%d+)$")
        local originboot = origin == self.io.id and self.io.boot or self.peers[origin]
        if not sequence or boot ~= originboot or origin == peer then return end
        sequence = tonumber(sequence)
        local seen = self.arrived[m.uid] or {}
        self.arrived[m.uid] = seen
        local previous = seen[origin]
        if previous and previous.boot == boot and previous.sequence > sequence then return end
        if not previous or previous.boot ~= boot or previous.sequence < sequence then
            if origin == self.io.id and self.outbound[m.uid] ~= m.token then return end
            if origin == self.io.id then self.outbound[m.uid] = nil end
            self.owners[m.uid] = peer
            seen[origin] = {boot = boot, sequence = sequence, destination = peer}
        end
        if seen[origin].destination == peer then self:Send("ARRIVED_ACK", {uid = m.uid, token = m.token}, peer) end
    elseif op == "ARRIVED_ACK" and self.inbound[m.uid] == m.token then
        local acks = self.arrivalacks[m.uid]
        acks[peer] = self.peers[peer]
        if self:AllPeers(function(id, boot) return acks[id] == boot end) then
            self.inbound[m.uid], self.arrivalacks[m.uid] = nil, nil
        end
    end
    if self.phase ~= before then self.lastsend = -100 end
    if self.io.wake then self.io.wake() end
end

function Checkpoint:Saved(cut, world)
    if self.phase ~= "saving" or not self.pending or self.pending.id ~= cut.id then return end
    self.captured, self.lastsend = cut.id, -100
    if self.io.wake then self.io.wake() end
    cut.members = {[self.io.id] = true}
    for peer in pairs(self.peers) do cut.members[peer] = true end
    self.store:PutCut(cut, world, function(ok, reason)
        if not ok then self:Fail(reason); return end
        if self.phase ~= "saving" or not self.pending or self.pending.id ~= cut.id then return end
        self.phase, self.lastsend = "prepared", -100
        if self.io.wake then self.io.wake() end
    end)
end
function Checkpoint:Seal()
    if self.phase ~= "prepared" then return end
    self.phase = "sealing"
    local id = self.pending.id
    self.store:Seal(id, function(ok, reason)
        if not ok then self:Fail(reason); return end
        if self.phase ~= "sealing" or not self.pending or self.pending.id ~= id then return end
        self.generation, self.loaded = id, id
        self.phase, self.lastsend = "sealed", -100
        if self.io.wake then self.io.wake() end
    end)
end
function Checkpoint:Open()
    local cut = self.store.state.cuts[self.generation]
    if cut and cut.members then for peer in pairs(cut.members) do self:Discover(peer) end end
    self.exitready = self.exiting or self.peerexitrequested or nil
    self.phase, self.dirty, self.requested = "ready", false, nil
    self.opened, self.activation, self.want = true, nil, nil
    self.opened_generation = self.generation
    self.pending, self.selection, self.captured, self.travelcut, self.peerloaded = nil, nil, nil, nil, {}
    self.peerdrained, self.peercaptured, self.peerprepared, self.peersealed, self.peeractive = {}, {}, {}, {}, {}
    self.lastcut = self.io.now()
    local callbacks = self.callbacks; self.callbacks = {}
    for _, callback in ipairs(callbacks) do callback() end
end

function Checkpoint:Tick()
    if self.membersdirty and not self.store.busy then
        self.membersdirty = nil
        local members = Store.Copy(self.members)
        self.store:Update(function(state) state.members = members end, function(ok, reason)
            if not ok then self:Fail(reason) end
        end)
    end
    if self.phase == "error" or self.selecting then return end
    for peer, boot in pairs(self.peers) do
        if not self.offline[peer] and not self.io.connected(peer, boot) then self:Disconnected(peer) end
    end
    if (self.suspended or not self:AllPeers(self.io.connected)) and not self:AwaitingExitActivation() then
        local now = self.io.now()
        if next(self.inbound) and now - self.lastsend >= .5 then
            self.lastsend = now
            for uid, token in pairs(self.inbound) do self:Send("ARRIVED", {uid = uid, token = token}) end
        end
        return
    end
    local master = self.io.masterid or "1"
    local capturePeer
    if self.io.master and self.phase == "ready" and self.want and not self.exitready then self:Begin() end
    if self.phase == "draining" and self:Idle() then
        self.phase, self.lastsend = "frozen", -100
    end
    if self.io.master and self.phase == "frozen" and self:AllPeers(function(peer) return self.peerdrained[peer] end) then
        local matching = true
        local owners = Store.Copy(self.owners)
        for _, peerowners in pairs(self.peerdrained) do
            for uid, owner in pairs(peerowners) do
                -- A migration can finish after a shard sent DRAINED.
                if owners[uid] and owners[uid] ~= owner then matching = false end
                owners[uid] = owner
            end
        end
        if matching then
            self.owners = owners
            self.phase = "capture_wait"
        end
        -- A stale DRAINED map must not stop REGISTER/ARRIVED retries below.
    end
    if self.phase == "capture_wait" and self:Idle() then
        self.phase = "saving"
        self.io.save(self.pending, self.owners)
    end
    if self.io.master and (self.phase == "prepared" or
        (self.phase == "saving" and self.captured == self.pending.id)) then
        -- The native callbacks sealed the player/world images in memory.
        -- Backup writes can continue while arrivals update the live owner map.
        if not self.travelcut and self:AllPeers(function(peer) return self.peercaptured[peer] end) then
            self.travelcut, self.lastsend = self.pending.id, -100
        end
        -- Start only one native capture at a time. Allow up to two backups to
        -- verify concurrently, and still require every PREPARED before sealing.
        local verifying = self.phase == "saving" and 1 or 0
        for peer in pairs(self.peers) do
            if self.peerprepared[peer] ~= self.pending.id then
                if self.peercaptured[peer] then verifying = verifying + 1
                elseif not capturePeer or peer < capturePeer then capturePeer = peer end
            end
        end
        if not capturePeer and verifying == 0 and self:Idle() then
            self:Send("SEAL", {id = self.pending.id})
            self:Seal()
        end
        if verifying >= 2 then capturePeer = nil end
    end
    if self.io.master and self.phase == "sealed" and self:AllPeers(function(peer)
        return self.peersealed[peer] == self.pending.id
    end) then
        self.phase, self.peerloaded = "activating", self.peersealed
        self.selection = {id = self.pending.id}
        self:Send("ACTIVATE", {id = self.generation})
    end
    local now = self.io.now()
    if now - self.lastsend < .5 then return end
    self.lastsend = now
    if self.io.master and self.pending and self.travelcut == self.pending.id then
        self:Send("TRAVEL_OPEN", {id = self.travelcut})
    end
    if capturePeer then
        self:Send("CAPTURE", {id = self.pending.id, owners = self.owners}, capturePeer)
    elseif self.phase == "joining" then
        if self.io.master then self:Choose() end
        if self.phase == "joining" then self:Send("INFO", self:Info()) end
    elseif self.phase == "ready" then
        if self.want and not self.io.master then self:Send("REQUEST", nil, master) end
    elseif self.phase == "draining" or self.phase == "frozen" then
        if self.io.master then self:Send("FREEZE", self.pending)
        elseif self.phase == "frozen" then self:Send("DRAINED", {id = self.pending.id, owners = self.owners}, master) end
    elseif not self.io.master and self.phase == "saving" and self.captured == self.pending.id then
        self:Send("CAPTURED", {id = self.pending.id}, master)
    elseif not self.io.master and self.phase == "prepared" and self:Idle() then
        self:Send("PREPARED", {id = self.pending.id}, master)
    elseif self.phase == "sealed" then
        if self.io.master then self:Send("SEAL", {id = self.pending.id})
        else self:Send("SEALED", {id = self.pending.id}, master); self.phase = "activating" end
    elseif self.phase == "activating" then
        if self.io.master then
            if self:AllPeers(function(peer) return self.peerloaded[peer] == self.generation end) then self:Send("ACTIVATE", {id = self.generation})
            elseif self.selection then self:Send("SELECT", self.selection) end
        elseif self.activation then self:Send("ACTIVE", {id = self.generation}, master)
        else
            self:Send("LOADED", {id = self.generation}, master)
            if self.pending then self:Send("SEALED", {id = self.generation}, master) end
        end
    end
    for uid, reg in pairs(self.registrations) do
        if reg.localdone then self:Send("REGISTER", {uid = uid, owner = reg.owner}) end
    end
    for uid, token in pairs(self.inbound) do self:Send("ARRIVED", {uid = uid, token = token}) end
end

return Checkpoint
