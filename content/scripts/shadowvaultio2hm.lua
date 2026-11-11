-- Native persistence API for the independent vault journal.
local IO={}
function IO.New(index)
    local clustered = not TheNet:IsDedicated() and index:GetSlot() ~= nil and
        not index:GetServerData().use_legacy_session_path
    local slot, shard = index:GetSlot(), index:GetShard() or "Master"
    return {
        read = function(key, cb)
            if clustered then TheSim:GetPersistentStringInClusterSlot(slot, shard, key, cb)
            else TheSim:GetPersistentString(key, cb) end
        end,
        write = function(key, data, cb)
            if clustered then TheSim:SetPersistentStringInClusterSlot(slot, shard, key, data, false, cb)
            else TheSim:SetPersistentString(key, data, false, cb) end
        end,
        erase = function(key)
            if clustered then TheSim:SetPersistentStringInClusterSlot(slot, shard, key, "", false)
            else TheSim:ErasePersistentString(key) end
        end,
        encode = function(data) return DataDumper(data, nil, true) end,
        decode = RunInSandboxSafe,
    }
end

return IO
