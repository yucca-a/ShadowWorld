-- Fast exchanges rely on the verified common world/player checkpoint. The
-- checkpoint controller owns crash recovery; no exchange requests a world save.
local Base = require("worldexchangeprotocol2hm")
local Instant = {}

function Instant.new(io, saved, checkpoint)
    assert(checkpoint, "a checkpoint guard is mandatory")
    assert(not saved or not saved.active or (saved.version == 2 and saved.mode == "instant" and
        saved.checkpoint == checkpoint:Generation()), "cannot resume an unverified or legacy transaction")
    local wrapped = {}
    for key, value in pairs(io) do wrapped[key] = value end
    wrapped.send = function(peer, message)
        message.v = 2 -- Legacy services must not interpret this as a durable v1 transaction.
        message.checkpoint = checkpoint:Generation()
        io.send(peer, message)
    end
    wrapped.checkpoint = function() error("instant transactions must not request world saves") end
    local self = Base.new(wrapped, saved)
    self.checkpoint, self.inbound = checkpoint, {}
    local base_start, base_receive, base_tick = self.Start, self.Receive, self.Tick
    local base_phase, base_save = self.SetPhase, self.Save

    function self:Save()
        local data = base_save(self)
        data.version, data.mode, data.checkpoint = 2, "instant", checkpoint:Generation()
        return data
    end

    function self:SetPhase(phase)
        base_phase(self, phase)
        -- In v2 this means in-process readiness only. Disk durability belongs to
        -- the external coordinated checkpoint and must never be inferred here.
        self.durable = true
    end

    function self:Start(name, peer, requester)
        if not checkpoint:CanExchange(peer) then return false, "checkpoint_pending" end
        local ok, reason = base_start(self, name, peer, requester)
        if ok then
            self.active.fast_checkpoint = checkpoint:Generation()
            self.durable = true
            checkpoint:Dirty()
        end
        return ok, reason
    end

    function self:Receive(peer, message)
        if type(message) ~= "table" or message.v ~= 2 or checkpoint:Generation() == nil or
            message.checkpoint ~= checkpoint:Generation() then return end
        if checkpoint:IsFrozen() then
            -- A frozen participant may already have finalized this transfer.
            -- Answer its terminal receipt so the other participant can drain;
            -- starting or applying a new transfer remains forbidden here.
            if type(message.coordinator)=="string" and type(message.epoch)=="string" and type(message.seq)=="number" and
                self:Closed(message) then
                local decoded={};for key,value in pairs(message) do decoded[key]=value end
                decoded.v=1;base_receive(self,peer,decoded);return
            end
            if #self.inbound < 64 then table.insert(self.inbound, {peer, message}) end
            return
        end
        if checkpoint.CanReceive then
            if not checkpoint:CanReceive(peer) then return end
        elseif not checkpoint:CanExchange(peer) then return end
        local decoded = {}
        for key, value in pairs(message) do decoded[key] = value end
        decoded.v = 1
        base_receive(self, peer, decoded)
        if self.active then
            self.active.fast_checkpoint = checkpoint:Generation()
            self.durable = true
            checkpoint:Dirty()
        end
    end

    function self:Tick()
        if checkpoint:IsFrozen() then return end
        local queued = self.inbound
        self.inbound = {}
        for _, packet in ipairs(queued) do self:Receive(packet[1], packet[2]) end
        base_tick(self)
    end

    -- Loaded fast state cannot be resumed just because a local snapshot exists.
    -- The checkpoint controller must first prove that both worlds loaded the
    -- same sealed cut (or complete a coordinated native rollback).
    return self
end

return Instant
