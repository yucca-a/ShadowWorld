-- A verified, serial journal. The commit pointer is written last; a torn or
-- missing committed record is an error, never permission to guess an old state.
local Store = {}
Store.__index = Store
local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}; for k, v in pairs(value) do out[k] = copy(v) end; return out
end
local function digest(data)
    local hash = 5381
    for i = 1, #data do hash = (hash * 33 + data:byte(i)) % 4294967296 end
    return tostring(#data) .. ":" .. string.format("%08x", hash)
end
Store.Copy, Store.Digest = copy, digest

function Store.new(io, session)
    assert(type(session) == "string" and session:match("^[%w_%-]+$"), "invalid session")
    return setmetatable({io = io, prefix = "swx2_" .. session, session = session, queue = {}}, Store)
end

function Store:Write(key, raw, cb)
    self.io.write(key, raw, function(ok)
        if ok == false then cb(false); return end
        self.io.read(key, function(found, actual) cb(found and actual == raw) end)
    end)
end

function Store:Load(cb)
    self.io.read(self.prefix .. "_head", function(found, raw)
        if not found then
            self.io.read(self.prefix .. "_bank0", function(a)
                self.io.read(self.prefix .. "_bank1", function(b)
                    if a or b then cb(nil, "missing_commit_pointer"); return end
                    self.state = {version = 2, revision = 0, registry = {}, baselines = {}, cuts = {}, nextserial = 0}
                    cb(self.state)
                end)
            end)
            return
        end
        local ok, head = self.io.decode(raw)
        if not ok or type(head) ~= "table" or type(head.revision) ~= "number" or
            head.revision < 1 or head.revision % 1 ~= 0 or type(head.digest) ~= "string" then
            cb(nil, "invalid_commit_pointer"); return
        end
        self.io.read(self.prefix .. "_bank" .. (head.revision % 2), function(exists, body)
            if not exists or type(body) ~= "string" or digest(body) ~= head.digest then cb(nil, "corrupt_committed_journal"); return end
            local parsed, state = self.io.decode(body)
            if not parsed or type(state) ~= "table" or state.version ~= 2 or state.revision ~= head.revision or
                type(state.cuts) ~= "table" or type(state.registry) ~= "table" then cb(nil, "invalid_journal"); return end
            self.state = state
            cb(state)
        end)
    end)
end

function Store:Update(change, callback)
    table.insert(self.queue, {change = change, callback = callback})
    self:Drain()
end

function Store:Drain()
    if self.busy or #self.queue == 0 then return end
    local job = table.remove(self.queue, 1)
    if self.error then if job.callback then job.callback(false, self.error) end; self:Drain(); return end
    self.busy = true
    local state = copy(self.state)
    local ok, reason = pcall(job.change, state)
    if not ok then self.busy = false; self.error = tostring(reason); if job.callback then job.callback(false, self.error) end; self:Drain(); return end
    state.revision = state.revision + 1
    local raw = self.io.encode(state)
    local function finish(written)
        if written then self.state = state else self.error = "journal_write_failed" end
        self.busy = false
        if job.callback then job.callback(written, self.error) end
        self:Drain()
    end
    self:Write(self.prefix .. "_bank" .. (state.revision % 2), raw, function(written)
        if not written then finish(false); return end
        self:Write(self.prefix .. "_head", self.io.encode({revision = state.revision, digest = digest(raw)}), finish)
    end)
end

function Store:PutCut(cut, world, cb)
    local record = copy(cut)
    record.world = self.prefix .. "_world_" .. tostring(cut.serial) .. "_" .. digest(cut.id):gsub(":", "_")
    record.digest = digest(world)
    self:Write(record.world, world, function(ok)
        if not ok then cb(false, "checkpoint_write_failed"); return end
        self:Update(function(state)
            for uid, baseline in pairs(state.baselines or {}) do
                if record.players[uid] == nil then
                    record.players[uid], record.owners[uid] = baseline.raw, baseline.owner
                end
            end
            state.cuts[record.id] = record
            for uid in pairs(record.owners) do state.registry[uid] = true end
            state.nextserial = math.max(state.nextserial or 0, record.serial)
        end, cb)
    end)
end

function Store:ReadCut(id, cb)
    local cut = self.state and self.state.cuts[id]
    if not cut or type(cut.world) ~= "string" or cut.world:sub(1, #self.prefix + 7) ~= self.prefix .. "_world_" or
        not cut.world:match("^[%w_%-]+$") or type(cut.players) ~= "table" then cb(nil, "missing_checkpoint"); return end
    self.io.read(cut.world, function(ok, raw)
        if not ok or type(raw) ~= "string" or digest(raw) ~= cut.digest then cb(nil, "corrupt_checkpoint"); return end
        cb(raw, nil, cut)
    end)
end

function Store:Register(uid, owner, raw, cb)
    self:Update(function(state)
        state.registry[uid] = true
        state.baselines = state.baselines or {}
        if not state.baselines[uid] then state.baselines[uid] = {owner = owner, raw = raw or false} end
        for _, cut in pairs(state.cuts) do
            if cut.players[uid] == nil then
                cut.players[uid] = raw or false
                cut.owners[uid] = owner
            end
        end
    end, cb)
end

function Store:Select(id, manual, cb)
    self:Update(function(state)
        assert(state.cuts[id], "missing selected checkpoint")
        state.current, state.forced = id, id
        if manual then
            local serial = state.cuts[id].serial
            for key, cut in pairs(state.cuts) do if cut.serial > serial then state.cuts[key] = nil end end
        end
    end, cb)
end

function Store:Seal(id, cb)
    local retired = {}
    self:Update(function(state)
        assert(state.cuts[id], "missing sealed checkpoint")
        state.current, state.forced = id, nil
        local ordered = {}
        for key, cut in pairs(state.cuts) do table.insert(ordered, {key = key, serial = cut.serial}) end
        table.sort(ordered, function(a, b) return a.serial > b.serial end)
        for n = 9, #ordered do
            local key = ordered[n].key
            if key ~= id then table.insert(retired, state.cuts[key].world); state.cuts[key] = nil end
        end
    end, function(ok, reason)
        if ok and self.io.erase then for _, key in ipairs(retired) do self.io.erase(key) end end
        cb(ok, reason)
    end)
end

return Store
