local checks = 0
local function check(value, reason) assert(value, reason); checks = checks + 1 end
local world, user = "session/ABC/0000000001", "session/ABC/USER/0000000001"
local function fixture()
    local disk, queue, writes = {[world] = "world-before", [user] = "inventory-before"}, {}, {}
    local state = {disk = disk, queue = queue, writes = writes}
    state.store = Store.new({
        read = function(path, cb) table.insert(queue, function() cb(disk[path] ~= nil, disk[path]) end) end,
        write = function(path, data, cb)
            table.insert(queue, function()
                table.insert(writes, path)
                if state.refuse == path then cb(false); return end
                if state.drop ~= path then disk[path] = state.corrupt == path and "corrupt" or data end
                cb()
            end)
        end,
        encode = function(data) return "manifest:" .. data.epoch .. ":" .. #data.files end,
    }, "test")
    function state:drain()
        while #queue > 0 do table.remove(queue, 1)() end
    end
    function state:pin()
        self.store:Capture("cut", {world, user}, function(manifest, reason)
            self.manifest, self.reason = manifest, reason
        end)
        self:drain()
        return self.manifest
    end
    function state:restore(manifest)
        self.store:Restore(manifest or self.manifest, function(ok, reason) self.ok, self.reason = ok, reason end)
        self:drain()
    end
    return state
end

local s = fixture()
check(s:pin(), "capture did not produce a manifest")
check(s.disk.test_cut_manifest ~= nil, "manifest missing")
s.disk[world], s.disk[user] = "world-after", "inventory-after"
s:restore()
check(s.ok and s.disk[world] == "world-before" and s.disk[user] == "inventory-before", "whole cut not restored")
s:restore()
check(s.ok and s.disk[user] == "inventory-before", "restore not idempotent")

s = fixture(); s.refuse = world
s.store:WriteVerified(world, "world-before", function(ok) s.ok = ok end); s:drain()
check(s.ok == false, "reported write failure cannot be hidden by matching existing bytes")

for _, failure in ipairs({"drop", "corrupt"}) do
    for _, path in ipairs({"test_cut_1", "test_cut_2", "test_cut_manifest"}) do
        s = fixture(); s[failure] = path
        check(not s:pin(), "capture accepted failed write: " .. path)
        check(s.disk[world] == "world-before" and s.disk[user] == "inventory-before", "capture modified live files")
    end
end

for _, path in ipairs({world, user}) do
    s = fixture(); s.disk[path] = nil
    check(not s:pin() and s.reason == "source_read_failed", "capture accepted missing native file")
end
for _, path in ipairs({"test_cut_1", "test_cut_2"}) do
    s = fixture(); s:pin(); s.disk[path] = "corrupt"
    s.disk[world], s.disk[user] = "world-after", "inventory-after"
    local before = #s.writes
    s:restore()
    check(not s.ok and s.reason == "corrupt_backup", "restore accepted corrupted file")
    check(#s.writes == before and s.disk[world] == "world-after" and s.disk[user] == "inventory-after", "partial restore before validation")
end

s = fixture(); s:pin(); s.disk[world], s.disk[user], s.drop = "world-after", "inventory-after", user
s:restore()
check(not s.ok and s.reason == "restore_write_failed", "partial restore reported success")
s.drop = nil; s:restore()
check(s.ok and s.disk[user] == "inventory-before", "interrupted restore could not be retried")

local badlists = {{}, {world, world}, {world, "session/../other"}, {[1] = world, [3] = user}}
for _, files in ipairs(badlists) do
    s = fixture()
    s.store:Capture("bad", files, function(m) s.manifest = m end); s:drain()
    check(not s.manifest and #s.writes == 0, "invalid file list caused writes")
end
for _, edit in ipairs({
    function(m) m.files[1].path = "session/../other" end,
    function(m) m.files[1].backup = "test_../other" end,
    function(m) m.files[2].path = m.files[1].path end,
    function(m) m.files[1] = "broken" end,
    function(m) m.epoch = "../other" end,
    function(m) m.files.extra = m.files[1] end,
}) do
    s = fixture(); s:pin(); edit(s.manifest)
    local before = #s.writes
    s:restore()
    check(not s.ok and s.reason == "invalid_manifest" and #s.writes == before, "invalid manifest caused writes")
end
print("Snapshot store checks: " .. checks)
