local Transfer = {}
Transfer.__index = Transfer

function Transfer.new(io, saved)
    return setmetatable({io = io, stream = io.boot, sequence = saved and saved.stream == io.boot and saved.sequence or {}, pending = saved and saved.pending or {},
        received = saved and saved.received or {}, retry = {}}, Transfer)
end

function Transfer:CanQueue(required)
    local count = 0
    for _ in pairs(self.pending) do count = count + 1 end
    return count + (required or 1) <= 32
end

function Transfer:Queue(peer, payload)
    if not self:CanQueue() then return false end
    peer = tostring(peer)
    self.sequence[peer] = (self.sequence[peer] or 0) + 1
    local sequence = self.sequence[peer]
    local key = peer .. "/" .. self.stream .. "/" .. sequence
    self.pending[key] = {peer = peer, kind = "transfer", stream = self.stream, sequence = sequence, payload = payload}
    return key
end

function Transfer:Cancel(key)
    if self.pending[key] then self.pending[key].payload = {kind = "cancel"} end
end

function Transfer:Receive(peer, message)
    peer = tostring(peer)
    if type(message.stream) ~= "string" or #message.stream > 200 or type(message.sequence) ~= "number" or
        message.sequence < 1 or message.sequence % 1 ~= 0 then return end
    if message.kind == "ack" then
        local key = peer .. "/" .. message.stream .. "/" .. message.sequence
        self.pending[key], self.retry[key] = nil, nil
        return
    end
    if message.kind ~= "transfer" or type(message.payload) ~= "table" then return end
    local key = peer .. "/" .. message.stream
    local receipt = self.received[key] or {through = 0, gaps = {}}
    local sequence = message.sequence
    if sequence > receipt.through and not receipt.gaps[sequence] then
        if message.payload.kind ~= "cancel" and not self.io.apply(peer, message.payload) then return end
        receipt.gaps[sequence] = true
        while receipt.gaps[receipt.through + 1] do
            receipt.through = receipt.through + 1
            receipt.gaps[receipt.through] = nil
        end
        self.received[key] = receipt
    end
    self.io.send(peer, {kind = "ack", stream = message.stream, sequence = sequence})
end

function Transfer:Tick(now)
    local budget = 2
    for key, message in pairs(self.pending) do
        if self.io.available(message.peer) and (not self.retry[key] or now >= self.retry[key]) then
            self.retry[key] = now + 2
            self.io.send(message.peer, message)
            budget = budget - 1
            if budget == 0 then break end
        end
    end
end

function Transfer:Save()
    return {pending = self.pending, received = self.received, stream = self.stream, sequence = self.sequence}
end

return Transfer
