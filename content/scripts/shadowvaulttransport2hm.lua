-- Bounded, session-bound shard transport. Adapted from the validated exchange transport.
local Transport = {}
Transport.__index = Transport
local CHUNK, MAX_CHUNKS = 8192, 4096
local LIMIT = CHUNK * MAX_CHUNKS
function Transport.new(inst, callbacks)
    local self = setmetatable({inst=inst, callbacks=callbacks, id=tostring(TheShard:GetShardId()),
        session=inst.meta.session_identifier, peers={}, inbox={}, outbox={}, challenges={}, accepted_hello={},
        hello_sequence=0, message_sequence=0, boot=tostring(os.time())..":"..tostring(GetTimeReal())..":"..tostring(math.random(1,1073741823))}, Transport)
    self.protocol = {Tick=function() end, Fail=function(_, why) callbacks.fail(why) end,
        Receive=function(_, peer, message) callbacks.receive(peer, message) end}
    return self
end
function Transport:Initialize() end
function Transport:Now() return GetStaticTime() end
function Transport:Wake()
    if self.waketask then return end
    self.waketask = self.inst:DoStaticTaskInTime(0,function() self.waketask=nil; self:Flush() end)
end
function Transport:Close()
    if self.waketask then self.waketask:Cancel();self.waketask=nil end
end
function Transport:Hello(peer, reply, target, challenge)
    if not reply then
        self.hello_sequence = self.hello_sequence + 1
        challenge = tostring(self.hello_sequence)
        self.challenges[peer] = self.challenges[peer] or {}
        self.challenges[peer][challenge] = self:Now() + 60
    end
    local info = {v = 1, vault = 1, session = self.session}
    info.storage=4
    SendModRPCToShard(GetShardModRPC("MOD_HARDMODE", "shadowvault_v1"), peer,
        reply and "HELLO_ACK" or "HELLO", self.boot, target or "", challenge, 0, 0,
        DataDumper(info, nil, true))
end

function Transport:Send(peer, message, encoded)
    local connection = self.peers[peer]
    if not connection or not Shard_IsWorldAvailable(peer) then return end
    -- Replace unsent retries of the same phase instead of accumulating a backlog.
    for _, pending in ipairs(self.outbox) do
        if pending.peer == peer and pending.txid == message.id and pending.kind == message.kind and
            pending.op == message.op and pending.uid == message.userid then
            if pending.index == 1 then
                encoded = encoded or DataDumper(message, nil, true)
                if #encoded > LIMIT then self.protocol:Fail("too_large"); return end
                pending.data = encoded
                pending.count = math.max(1, math.ceil(#encoded / CHUNK))
            end
            return
        end
    end
    if #self.outbox >= 32 then return end
    encoded = encoded or DataDumper(message, nil, true)
    if #encoded > LIMIT then self.protocol:Fail("too_large"); return end
    self.message_sequence = self.message_sequence + 1
    table.insert(self.outbox, {peer = peer, target = connection.boot, id = tostring(self.message_sequence),
        txid = message.id, kind = message.kind, op = message.op, uid = message.userid,
        data = encoded, index = 1, count = math.max(1, math.ceil(#encoded / CHUNK))})
    self:Wake()
end

function Transport:Packet(peer, kind, boot, target, id, index, count, data)
    if not self.protocol or peer == self.id or not Shard_IsWorldAvailable(peer) or
        type(data) ~= "string" or type(boot) ~= "string" or #boot > 200 then return end
    if kind == "HELLO" or kind == "HELLO_ACK" then
        if #data > 1024 or (kind == "HELLO_ACK" and target ~= self.boot) then return end
        local ok, info = RunInSandboxSafe(data)
        if not ok or type(info) ~= "table" or info.v ~= 1 or info.vault ~= 1 or type(info.session) ~= "string" then return end
        if kind == "HELLO" then
            if type(id) == "string" and #id <= 40 then self:Hello(peer, true, boot, id) end
            return
        end
        local pending = self.challenges[peer]
        local serial = tonumber(id)
        if not pending or not pending[id] or pending[id] < self:Now() or not serial or
            serial <= (self.accepted_hello[peer] or 0) then return end
        pending[id] = nil
        self.accepted_hello[peer] = serial
        local previous = self.peers[peer]
        if not previous or previous.boot ~= boot then
            self.protocol.peer_phase, self.protocol.peer_durable = nil, nil
            self.protocol.retry = 0
            self.inbox[peer] = nil
        end
        info.boot, info.lastseen = boot, self:Now()
        self.peers[peer] = info
        if self.callbacks.hello then self.callbacks.hello(peer, info, previous) end
        return
    end
    local connection = self.peers[peer]
    if kind ~= "DATA" or target ~= self.boot or not connection or connection.boot ~= boot or
        type(id) ~= "string" or #id > 40 or type(index) ~= "number" or type(count) ~= "number" or
        index % 1 ~= 0 or count % 1 ~= 0 or index < 1 or count < 1 or count > MAX_CHUNKS or index > count or #data > CHUNK then return end
    connection.lastseen = self:Now()
    self.inbox[peer] = self.inbox[peer] or {}
    local inbox = self.inbox[peer]
    local part = inbox[id]
    if not part then
        local total = 0
        for _ in pairs(inbox) do total = total + 1 end
        if total >= 8 then return end
        part = {count = count, chunks = {}, received = 0, expires = self:Now() + 30}
        inbox[id] = part
    end
    if part.count ~= count then return end
    if not part.chunks[index] then part.chunks[index] = data; part.received = part.received + 1 end
    if part.received == count then
        inbox[id] = nil
        local ok, message = RunInSandboxSafe(table.concat(part.chunks))
        if ok and type(message) == "table" then
            self.protocol:Receive(peer, message)
            self:Wake()
        end
    end
end

function Transport:Disconnected(peer)
    peer = tostring(peer)
    self.peers[peer], self.inbox[peer], self.challenges[peer] = nil, nil, nil
    self.nexthello = 0
    if self.callbacks.disconnected then self.callbacks.disconnected(peer) end
    if self.protocol and self.protocol.active and self.protocol.active.peer == peer then
        self.protocol.peer_phase, self.protocol.peer_durable = nil, nil
        self.protocol.retry = 0
    end
end

function Transport:Update()
    self:Initialize()
    if not self.protocol then return end
    local now = self:Now()
    if not self.nexthello or now >= self.nexthello then
        local recovering = not next(self.peers)
        self.nexthello = now + (recovering and .25 or 5)
        for peer in pairs(ShardList or {}) do
            peer = tostring(peer)
            if peer ~= self.id and Shard_IsWorldAvailable(peer) then self:Hello(peer) end
        end
    end
    for peer, inbox in pairs(self.inbox) do
        for id, part in pairs(inbox) do if now >= part.expires then inbox[id] = nil end end
    end
    for _, pending in pairs(self.challenges) do
        for id, expires in pairs(pending) do if now >= expires then pending[id] = nil end end
    end
    self:Flush()
end

function Transport:Flush()
    local now = self:Now()
    if not self.sendwindow or now - self.sendwindow >= 0.1 - 0.000001 then
        self.sendwindow, self.sendbudget = now, 4
    end
    while self.sendbudget > 0 do
        -- Final acknowledgements and save-state messages should not wait behind
        -- another large retry payload. All traffic shares the same burst budget.
        local index = 1
        for n, candidate in ipairs(self.outbox) do
            if candidate.kind ~= "PREPARE" and candidate.kind ~= "READY" then index = n; break end
        end
        local packet = self.outbox[index]
        if not packet then break end
        local peer = self.peers[packet.peer]
        if peer and peer.boot == packet.target and Shard_IsWorldAvailable(packet.peer) then
            SendModRPCToShard(GetShardModRPC("MOD_HARDMODE", "shadowvault_v1"), packet.peer,
                "DATA", self.boot, packet.target, packet.id, packet.index, packet.count,
                packet.data:sub((packet.index - 1) * CHUNK + 1, packet.index * CHUNK))
            packet.index = packet.index + 1
            self.sendbudget = self.sendbudget - 1
            if packet.index > packet.count then table.remove(self.outbox, index) end
        else table.remove(self.outbox, index) end
    end
end


return Transport
