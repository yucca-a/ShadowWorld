-- Native snapshot pinning primitive, not a complete cluster recovery adapter.
-- The caller must supply the complete world/player file set and gate gameplay.
-- IO must decode/encode with the correct native format for each file type.
-- Read-back equality alone does not prove that the game can load a file.
local Store = {}
Store.__index = Store
local function nativepath(path)
    return type(path) == "string" and #path <= 512 and path:match("^session/[%w_%-/%.]+$") and
        not path:find("..", 1, true)
end
local function epochkey(epoch)
    return type(epoch) == "string" and #epoch > 0 and #epoch <= 80 and epoch:match("^[%w_%-]+$")
end
local function sequence(list)
    if type(list) ~= "table" or #list < 1 then return false end
    local count = 0
    for key in pairs(list) do
        if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > #list then return false end
        count = count + 1
    end
    return count == #list
end
local function digest(data)
    local hash = 5381
    for i = 1, #data do hash = (hash * 33 + data:byte(i)) % 4294967296 end
    return tostring(#data) .. ":" .. string.format("%08x", hash)
end
function Store.new(io, prefix)
    assert(prefix:match("^[%w_]+$"), "flat persistent key required")
    return setmetatable({io = io, prefix = prefix}, Store)
end
function Store:WriteVerified(path, data, callback)
    self.io.write(path, data, function(written)
        if written == false then callback(false); return end
        self.io.read(path, function(ok, actual)
            callback(ok and actual == data)
        end)
    end)
end
function Store:Capture(epoch, files, callback)
    assert(epochkey(epoch), "invalid checkpoint key")
    if not sequence(files) then callback(nil, "invalid_file_list"); return end
    local seen = {}
    for _, path in ipairs(files) do
        if not nativepath(path) or seen[path] then callback(nil, "invalid_native_path"); return end
        seen[path] = true
    end
    local manifest = {version = 1, epoch = epoch, files = {}}
    local function nextfile(index)
        local path = files[index]
        if not path then
            local key = self.prefix .. "_" .. epoch .. "_manifest"
            self:WriteVerified(key, self.io.encode(manifest), function(ok)
                callback(ok and manifest or nil, ok and nil or "manifest_write_failed")
            end)
            return
        end
        self.io.read(path, function(ok, data)
            if not ok or type(data) ~= "string" then callback(nil, "source_read_failed"); return end
            local backup = self.prefix .. "_" .. epoch .. "_" .. index
            self:WriteVerified(backup, data, function(written)
                if not written then callback(nil, "backup_write_failed"); return end
                table.insert(manifest.files, {path = path, backup = backup, digest = digest(data)})
                nextfile(index + 1)
            end)
        end)
    end
    nextfile(1)
end
function Store:Restore(manifest, callback)
    if type(manifest) ~= "table" or manifest.version ~= 1 or not epochkey(manifest.epoch) or
        not sequence(manifest.files) then callback(false, "invalid_manifest"); return end
    local seen = {}
    for index, record in ipairs(manifest.files) do
        if type(record) ~= "table" or not nativepath(record.path) or seen[record.path] or
            record.backup ~= self.prefix .. "_" .. manifest.epoch .. "_" .. index or
            type(record.digest) ~= "string" then callback(false, "invalid_manifest"); return end
        seen[record.path] = true
    end
    local payloads = {}
    local function writefile(index)
        local record = manifest.files[index]
        if not record then callback(true); return end
        self:WriteVerified(record.path, payloads[index], function(ok)
            if not ok then callback(false, "restore_write_failed"); return end
            writefile(index + 1)
        end)
    end
    local function validate(index)
        local record = manifest.files[index]
        if not record then writefile(1); return end
        self.io.read(record.backup, function(ok, data)
            if not ok or type(data) ~= "string" or digest(data) ~= record.digest then callback(false, "corrupt_backup"); return end
            payloads[index] = data
            validate(index + 1)
        end)
    end
    validate(1) -- Validate the whole backup before overwriting any native file.
end
return Store
