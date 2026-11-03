-- Whole-container exchange. Transport, clocks, containers and save checkpoints are
-- injected so the same state machine can be fault-tested without the game engine.
local Protocol = {}
Protocol.__index = Protocol
local VERSION = 1

local copy = deepcopy

function Protocol.new(io, saved)
    local self = setmetatable({io = io, sequence = 0, closed = {}, retry = 0, interval = 1}, Protocol)
    if saved then
        self.active = copy(saved.active)
        self.closed = copy(saved.closed or {})
        -- A phase loaded from the world snapshot is already durable with its items.
        self.durable = self.active ~= nil
        if self.active and self.active.phase == "offer" then self.started = io.now() end
    end
    return self
end

function Protocol:Save()
    return {version = VERSION, active = copy(self.active), closed = copy(self.closed)}
end

function Protocol:Marker()
    local t = self.active
    return t and {id = t.id, phase = t.phase} or nil
end

function Protocol:OnSaved(marker)
    local t = self.active
    if t and marker and t.id == marker.id and t.phase == marker.phase then
        self.durable = true
        self.retry = 0
    end
end

function Protocol:Send(kind, extra, peer, transaction)
    local t = transaction or self.active
    if not t then return end
    local message = {v = VERSION, kind = kind, id = t.id, epoch = t.epoch, seq = t.seq,
        coordinator = t.coordinator, name = t.name, coordinator_session = t.coordinator_session,
        participant_session = t.participant_session}
    for k, v in pairs(extra or {}) do message[k] = v end
    self.io.send(peer or t.peer, message)
end

function Protocol:SetPhase(phase)
    self.active.phase = phase
    self.durable = false
    self.retry, self.interval = 0, 1
    self.peer_durable, self.peer_phase = nil, nil
end

function Protocol:Notify(reason)
    if self.active then self.io.notify(self.active.requester, reason) end
end

function Protocol:Remember(t, outcome)
    local key = t.coordinator .. "/" .. t.epoch
    local old = self.closed[key]
    if not old or old.seq <= t.seq then self.closed[key] = {seq = t.seq, outcome = outcome} end
end

function Protocol:Closed(t)
    local receipt = self.closed[t.coordinator .. "/" .. t.epoch]
    if receipt and receipt.seq >= t.seq then
        return receipt.seq == t.seq and receipt.outcome or "stale"
    end
end

function Protocol:Finish(outcome)
    local t = self.active
    self:Remember(t, outcome)
    self.io.unlock(t.name)
    self:Notify(outcome == "done" and "done" or (t.reason or "cancelled"))
    self.active, self.durable = nil, nil
    self.peer_phase, self.peer_durable = nil, nil
end

function Protocol:Fail(reason)
    -- Never manufacture a rollback after an intent may have been committed.
    if self.active and self.active.error ~= reason then
        self.active.error = reason
        self:Notify(reason)
        self.io.log(reason, self.active.id)
    end
end

function Protocol:Cancel(reason, unsaved_intent)
    if self.active and self.active.coordinator == self.io.id and (self.active.phase == "offer" or
        (unsaved_intent and self.active.phase == "intent" and not self.durable)) then
        self.active.reason = reason
        self:SetPhase("aborting")
    end
end

function Protocol:Start(name, peer, requester)
    if self.active then return false, "busy" end
    local peer_session = self.io.peer_session(peer)
    if not peer_session then return false, "connecting" end
    local locked, why = self.io.lock(name)
    if not locked then return false, why end
    local payload, reason = self.io.snapshot(name)
    if not payload then self.io.unlock(name); return false, reason end
    self.sequence = self.sequence + 1
    local epoch = self.io.session .. ":" .. self.io.boot
    self.active = {id = self.io.id .. "/" .. epoch .. "/" .. self.sequence,
        epoch = epoch, seq = self.sequence, coordinator = self.io.id, peer = peer,
        name = name, phase = "offer", own = payload, requester = requester,
        coordinator_session = self.io.session, participant_session = peer_session}
    self.started = self.io.now()
    self.durable = false
    self.retry, self.interval = 0, 1
    self:Notify("preparing")
    return true
end

function Protocol:Receive(peer, m)
    if type(m) ~= "table" or m.v ~= VERSION or type(m.kind) ~= "string" or
        type(m.id) ~= "string" or type(m.epoch) ~= "string" or
        type(m.name) ~= "string" or type(m.coordinator) ~= "string" or
        type(m.seq) ~= "number" or m.seq < 1 or m.seq % 1 ~= 0 or
        m.id ~= m.coordinator .. "/" .. m.epoch .. "/" .. m.seq then return end
    local iscoord = m.coordinator == self.io.id
    if not iscoord and m.coordinator ~= peer then return end
    local local_session = iscoord and m.coordinator_session or m.participant_session
    local remote_session = iscoord and m.participant_session or m.coordinator_session
    if local_session ~= self.io.session or remote_session ~= self.io.peer_session(peer) then return end

    local receipt = self:Closed(m)
    if receipt then
        -- Closed messages are terminal replies, never answered with another reply.
        if m.kind ~= "CLOSED" then self:Send("CLOSED", {outcome = receipt}, peer, m) end
        return
    end
    local t = self.active
    if m.kind == "PREPARE" and not iscoord and (not t or t.id ~= m.id) then
        if t then
            -- Resolve simultaneous clicks deterministically before either side commits.
            if t.phase == "offer" and peer < self.io.id then
                self:Send("CANCEL")
                self:Remember(t, "aborted")
                self.io.unlock(t.name)
                self.active = nil
            else
                self:Send("REJECT", {reason = "busy"}, peer, m)
                return
            end
        end
        local ok, reason = self.io.lock(m.name)
        if not ok then self:Send("REJECT", {reason = reason}, peer, m); return end
        local own, why = self.io.snapshot(m.name)
        local compatible, error
        if own then compatible, error = self.io.validate(m.name, m.payload) end
        if not own or not compatible then
            self.io.unlock(m.name)
            self:Remember(m, "aborted")
            self:Send("REJECT", {reason = why or error or "invalid_items"}, peer, m)
            return
        end
        self.active = {id = m.id, epoch = m.epoch, seq = m.seq, coordinator = peer, peer = peer,
            name = m.name, phase = "prepared", own = own, incoming = copy(m.payload),
            coordinator_session = m.coordinator_session, participant_session = m.participant_session}
        self.durable, self.peer_phase, self.peer_durable = false, nil, nil
        self.retry, self.interval = 0, 1
        t = self.active
    end

    if not t or t.id ~= m.id then
        -- A peer resumed an exchange absent from our snapshot. Tell it to hold
        -- its transaction instead of replaying goods from another save generation.
        if m.kind ~= "CLOSED" and m.kind ~= "REJECT" and m.kind ~= "UNKNOWN" and m.kind ~= "CANCEL" then
            self:Send("UNKNOWN", nil, peer, m)
        end
        return
    end
    if t.peer ~= peer or t.name ~= m.name or t.epoch ~= m.epoch or t.seq ~= m.seq then return end
    if m.kind == "UNKNOWN" then
        if t.phase == "offer" then self:Cancel("connecting")
        elseif iscoord and t.phase == "intent" and not self.durable then
            -- No apply can have been issued before our own intent is durable.
            -- Persist cancellation if the peer lost its unsaved preparation.
            self:Cancel("cancelled", true)
        elseif not iscoord and (t.phase == "prepared" or (t.phase == "intent" and not self.durable)) then
            -- Our saved intent was never acknowledged, so the coordinator could
            -- not apply anything before losing this pre-commit transaction.
            self:Finish("aborted")
        else self:Fail("snapshot_mismatch") end
        return
    elseif m.kind == "CLOSED" then
        if m.outcome == "done" and (t.phase == "applied" or t.phase == "release") and self.durable then
            self:Finish("done")
        elseif m.outcome == "aborted" and (t.phase == "offer" or t.phase == "prepared" or t.phase == "aborting" or
            (not iscoord and t.phase == "intent")) then
            if iscoord then self:Cancel("cancelled") else self:Finish("aborted") end
        else
            self:Fail("snapshot_mismatch")
        end
        return
    elseif m.kind == "REJECT" and iscoord then
        self:Cancel(m.reason or "cancelled")
        return
    elseif m.kind == "CANCEL" and not iscoord and (t.phase == "prepared" or t.phase == "intent") then
        self:Finish("aborted")
        return
    end
    if t.error then return end
    if m.kind == "READY" and iscoord and t.phase == "offer" then
        local ok, reason = self.io.validate(t.name, m.payload)
        if not ok then self:Cancel(reason or "invalid_items"); return end
        t.incoming = copy(m.payload)
        self:SetPhase("intent")
    elseif m.kind == "INTENT" and not iscoord and t.phase == "prepared" then
        self:SetPhase("intent")
    elseif m.kind == "STATE" then
        local previous_phase, previous_durable = self.peer_phase, self.peer_durable
        if m.phase == "intent" or m.phase == "applied" then
            -- Old packets must not undo newer durable evidence. The transport
            -- clears this evidence when a peer disconnects or changes boot ID.
            if self.peer_phase ~= "applied" or m.phase == "applied" then
                self.peer_durable = m.durable == true or (self.peer_phase == m.phase and self.peer_durable == true)
                self.peer_phase = m.phase
            end
        end
        -- Event-driven wakeups must not turn identical STATE/INTENT replies into
        -- a ping-pong loop while storage is still pending.
        if self.peer_phase == previous_phase and self.peer_durable == previous_durable then return end
    elseif m.kind == "APPLY" and not iscoord and t.phase == "intent" and self.durable then
        local ok, reason = self.io.apply(t.name, t.incoming)
        if not ok then self:Fail(reason or "apply_failed"); return end
        self:SetPhase("applied")
    elseif m.kind == "RELEASE" and not iscoord and t.phase == "applied" and self.durable then
        self:Send("CLOSED", {outcome = "done"})
        self:Finish("done")
        return
    end
    self.retry = 0
end

function Protocol:Tick()
    local t = self.active
    if not t then return end
    local locked = self.io.lock(t.name)
    if not locked then return end -- Pocket containers may not have loaded yet.
    if t.error then return end
    local now = self.io.now()
    if t.phase == "offer" and self.started and now - self.started >= 20 then self:Cancel("timeout") end
    if now < self.retry then return end
    self.retry = now + self.interval
    self.interval = math.min(5, self.interval * 2)
    local iscoord = t.coordinator == self.io.id
    if t.phase == "offer" then
        self:Send("PREPARE", {payload = t.own})
    elseif t.phase == "prepared" then
        self:Send("READY", {payload = t.own})
    elseif t.phase == "aborting" then
        if self.durable then self:Send("CANCEL"); self:Finish("aborted")
        else self.io.checkpoint() end
    elseif t.phase == "intent" then
        if iscoord then
            self:Send("INTENT")
            if self.peer_phase == "intent" then
                if self.durable and self.peer_durable then
                    local ok, reason = self.io.apply(t.name, t.incoming)
                    if not ok then self:Fail(reason or "apply_failed"); return end
                    self:SetPhase("applied")
                    self:Send("APPLY")
                else self.io.checkpoint() end
            elseif self.peer_phase == "applied" and self.durable then
                -- Restart between the two checkpoints: our saved original items
                -- are still locked, while the peer already performed its apply.
                local ok, reason = self.io.apply(t.name, t.incoming)
                if not ok then self:Fail(reason or "apply_failed"); return end
                self:SetPhase("applied")
                self:Send("APPLY")
            end
        else self:Send("STATE", {phase = "intent", durable = self.durable == true}) end
    elseif t.phase == "applied" then
        if iscoord then
            self:Send("APPLY")
            if self.peer_phase == "applied" then
                if self.durable and self.peer_durable then
                    self:SetPhase("release")
                    -- The already-saved applied phase is sufficient to resume release.
                    self.durable = true
                    self:Send("RELEASE")
                    self:Notify("finishing")
                else self.io.checkpoint() end
            end
        else self:Send("STATE", {phase = "applied", durable = self.durable == true}) end
    elseif t.phase == "release" then
        self:Send("RELEASE")
    end
end

return Protocol
