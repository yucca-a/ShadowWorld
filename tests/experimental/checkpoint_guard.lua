-- Pure checkpoint safety model; deliberately has no production engine adapter.
-- save() must serialize frozen protocol + boxes + world + player snapshots.
-- pin() must retain every file required to restore that native snapshot.
local Guard = {}
Guard.__index = Guard

function Guard.new(io, loaded)
    return setmetatable({io = io, generation = loaded and loaded.generation,
        loaded = loaded, phase = "checking", dirty = false, peers = {}, history = {}}, Guard)
end

function Guard:Generation() return self.generation end
function Guard:IsReady() return self.phase == "ready" end
function Guard:IsFrozen() return self.phase ~= "ready" end
function Guard:CanExchange(peer) return self:IsReady() and self.peers[peer] ~= nil end
function Guard:Dirty() self.dirty = true end

function Guard:Connect(peer, info)
    self.peers[peer] = info
    local loaded = self.loaded
    if not loaded or not info.checkpoint or loaded.generation ~= info.checkpoint.generation then
        self.phase = "recovery_required"
        return false, "different_checkpoint"
    end
    local boots = self.live_boots or loaded.boots or {}
    local restarted = boots[self.io.id] ~= self.io.boot or boots[peer] ~= info.boot
    if restarted and (self.dirty or info.dirty) then
        self.phase = "recovery_required"
        return false, "peer_restarted_after_unsaved_exchange"
    end
    if not self.io.has_snapshot(loaded) then
        self.phase = "recovery_required"
        return false, "missing_checkpoint_files"
    end
    self.generation, self.phase = loaded.generation, "checking"
    self.vote = {generation = loaded.generation, local_boot = self.io.boot, peer_boot = info.boot, ready = true}
    return self.vote
end

function Guard:Activate(peer, vote)
    if self.phase ~= "checking" or not self.vote or not self.peers[peer] or
        not vote or vote.ready ~= true or vote.generation ~= self.generation or
        vote.local_boot ~= self.peers[peer].boot or vote.peer_boot ~= self.io.boot then return false end
    self.phase = "ready"
    self.live_boots = {[self.io.id] = self.io.boot, [peer] = self.peers[peer].boot}
    return true
end

function Guard:Disconnect(peer)
    self.peers[peer] = nil
    self.phase = "checking"
end

function Guard:Freeze(generation)
    if self.phase ~= "ready" or not self.io.idle() then return false end
    self.phase, self.pending = "frozen", {generation = generation}
    return true
end

function Guard:Saved(snapshot, players)
    if self.phase ~= "frozen" then return false end
    self.pending.snapshot, self.pending.players = snapshot, players
    self.pending.boots = self.live_boots
    if not self.io.pin(self.pending) then
        self.phase = "recovery_required"
        return false
    end
    self.phase = "saved"
    return true
end

function Guard:Seal(peer, other)
    if self.phase ~= "saved" or not self.peers[peer] or type(other) ~= "table" or
        other.generation ~= self.pending.generation then return false end
    local checkpoint = self.pending
    checkpoint.peer, checkpoint.other = peer, other
    -- persist_manifest must report verified successful storage before reopening.
    if not self.io.persist_manifest(checkpoint) then return false end
    self.loaded, self.generation, self.dirty = checkpoint, checkpoint.generation, false
    self.history[checkpoint.generation] = checkpoint
    self.pending, self.phase = nil, "checking"
    self.vote = {generation = self.generation, local_boot = self.io.boot,
        peer_boot = self.peers[peer].boot, ready = true}
    -- A local manifest write is not proof that the peer sealed its own cut.
    -- Require the peer's matching vote before reopening this side.
    return true
end

function Guard:Recover(checkpoint)
    self.phase = "recovery_required"
    if not self.io.has_snapshot(checkpoint) then return false, "missing_checkpoint_files" end
    -- Never restore only box contents. The adapter must restart from the whole
    -- native snapshot including user sessions, or refuse recovery.
    return self.io.restore_world_and_players(checkpoint)
end

return Guard
