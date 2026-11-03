-- Recovery control traffic must run during WallUpdate, including while the
-- simulation is paused. Vanilla's shared shard RPC timeline can retain packets
-- behind a different simulation tick after rollback/pause. Keep native decoding
-- and all other RPC queues; only this already boot-checked channel is immediate.
local RPC = {}
function RPC.Install(globals, id, handler)
    local previous = globals.HandleShardModRPC
    local channel = string.lower(id.namespace)
    globals.HandleShardModRPC = function(sender, tick, namespace, code, data)
        if type(namespace) == "string" and string.lower(namespace) == channel and code == id.id then
            if globals.Shard_IsWorldAvailable(tostring(sender)) then
                globals.TheNet:CallShardRPC(handler, sender, data)
            end
            return
        end
        return previous(sender, tick, namespace, code, data)
    end
end
return RPC
