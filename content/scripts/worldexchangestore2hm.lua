-- A verified, serial journal. The commit pointer is written last; a torn or
-- missing committed record is an error, never permission to guess an old state.
local Store = {}
Store.__index = Store
local copy = deepcopy
local function digest(data)
    local hash = 5381
    -- Four bytes remain exact in Lua's double (< 2^53), while avoiding a
    -- C string call and modulo for every byte of a multi-MB world snapshot.
    local last = #data - #data % 4
    for i = 1, last, 4 do
        local a, b, c, d = data:byte(i, i + 3)
        hash = ((((hash * 33 + a) * 33 + b) * 33 + c) * 33 + d) % 4294967296
    end
    for i = last + 1, #data do hash = (hash * 33 + data:byte(i)) % 4294967296 end
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
            if not parsed or type(state) ~= "table" or (state.version ~= 2 and state.version ~= 3) or state.revision ~= head.revision or
                type(state.cuts) ~= "table" or type(state.registry) ~= "table" then cb(nil, "invalid_journal"); return end
            self.state = state
            self:CompactPlayers(function(ok, reason)
                if ok then cb(self.state) else cb(nil, reason) end
            end)
        end)
    end)
end

-- One-time v2 migration. Verify each external body before committing its
-- reference; interruption leaves either the old inline cut or a complete new
-- cut. No world or player snapshot is discarded during the conversion.
function Store:CompactPlayers(cb)
    local ids = {}
    for id, cut in pairs(self.state.cuts) do
        if cut.playerfile == nil and type(cut.players) == "table" and next(cut.players) then ids[#ids + 1] = id end
    end
    local position = 0
    local function nextcut()
        position = position + 1
        local id = ids[position]
        if not id then cb(true); return end
        local cut = self.state.cuts[id]
        if type(cut.world) ~= "string" or cut.world:sub(1, #self.prefix + 7) ~= self.prefix .. "_world_" or
            not cut.world:match("^[%w_%-]+$") then cb(false, "invalid_player_checkpoint"); return end
        local key, body = cut.world .. "_players", self.io.encode(cut.players)
        local hash = digest(body)
        self:Write(key, body, function(ok)
            if not ok then cb(false, "player_checkpoint_write_failed"); return end
            self:Update(function(state)
                local current = state.cuts[id]
                current.players, current.playerfile, current.playerdigest = {}, key, hash
                state.version = 3
            end, function(saved, reason)
                if saved then nextcut() else cb(false, reason) end
            end)
        end)
    end
    nextcut()
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
    self.pending = (self.pending or 0) + 1
    local function finish(ok, reason)
        self.pending = self.pending - 1
        cb(ok, reason)
    end
    local record = copy(cut)
    record.world = self.prefix .. "_world_" .. tostring(cut.serial) .. "_" .. digest(cut.id):gsub(":", "_")
    record.digest = digest(world)
    -- Keep large player/map records on disk, just like the world record.
    -- The live journal contains only metadata and any late-join overlays.
    local included = {}
    for uid in pairs(record.players) do included[uid] = true end
    local playerdata = self.io.encode(record.players)
    record.players = {}
    record.playerfile = record.world .. "_players"
    record.playerdigest = digest(playerdata)
    self:Write(record.world, world, function(ok)
        if not ok then finish(false, "checkpoint_write_failed"); return end
        self:Write(record.playerfile, playerdata, function(saved)
            if not saved then finish(false, "player_checkpoint_write_failed"); return end
            self:Update(function(state)
                for uid, baseline in pairs(state.baselines or {}) do
                    if not included[uid] then
                        record.players[uid], record.owners[uid] = baseline.raw, baseline.owner
                    end
                end
                -- Old builds must fail closed instead of interpreting external
                -- player records as empty inventories when downgraded.
                state.version = 3
                state.cuts[record.id] = record
                for uid in pairs(record.owners) do state.registry[uid] = true end
                state.nextserial = math.max(state.nextserial or 0, record.serial)
            end, finish)
        end)
    end)
end

function Store:ReadCut(id, cb)
    local cut = self.state and self.state.cuts[id]
    if not cut or type(cut.world) ~= "string" or cut.world:sub(1, #self.prefix + 7) ~= self.prefix .. "_world_" or
        not cut.world:match("^[%w_%-]+$") or type(cut.players) ~= "table" then cb(nil, "missing_checkpoint"); return end
    self.io.read(cut.world, function(ok, raw)
        if not ok or type(raw) ~= "string" or digest(raw) ~= cut.digest then cb(nil, "corrupt_checkpoint"); return end
        if cut.playerfile == nil then cb(raw, nil, cut); return end -- Existing v2 cuts.
        if cut.playerfile ~= cut.world .. "_players" or type(cut.playerdigest) ~= "string" then
            cb(nil, "invalid_player_checkpoint"); return
        end
        self.io.read(cut.playerfile, function(found, body)
            if not found or type(body) ~= "string" or digest(body) ~= cut.playerdigest then
                cb(nil, "corrupt_player_checkpoint"); return
            end
            local parsed, players = self.io.decode(body)
            if not parsed or type(players) ~= "table" then cb(nil, "invalid_player_checkpoint"); return end
            local hydrated = copy(cut)
            for uid, value in pairs(cut.players) do players[uid] = value end
            hydrated.players = players
            cb(raw, nil, hydrated)
        end)
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
            state.redirects = state.redirects or {}
            for key, cut in pairs(state.cuts) do
                if cut.serial > serial then state.redirects[key] = id; state.cuts[key] = nil end
            end
        end
    end, cb)
end

-- A native rollback can cross the installation boundary of fast mode. Preserve
-- the old journal as an archive, then establish a new paired native timeline.
function Store:RebaseNative(rebase, cb)
    local raw = self.io.encode(self.state)
    local key = self.prefix .. "_archive_" .. self.state.revision .. "_" .. digest(rebase.token):gsub(":", "_")
    self:Write(key, raw, function(ok)
        if not ok then cb(false, "rollback_archive_failed"); return end
        self:Update(function(state)
            state.archives = state.archives or {}
            state.archives[key] = digest(raw)
            state.cuts, state.registry, state.baselines, state.redirects = {}, {}, {}, {}
            state.current, state.forced = nil, nil
            state.timeline, state.rebase = rebase.token, copy(rebase)
        end, cb)
    end)
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
            if key ~= id then
                local cut = state.cuts[key]
                table.insert(retired, cut.world)
                if cut.playerfile == cut.world .. "_players" then table.insert(retired, cut.playerfile) end
                state.cuts[key] = nil
            end
        end
    end, function(ok, reason)
        if ok and self.io.erase then for _, key in ipairs(retired) do self.io.erase(key) end end
        cb(ok, reason)
    end)
end

return Store
