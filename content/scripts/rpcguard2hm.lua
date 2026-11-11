local Guard = {}

function Guard.IsEntity(value)
    return type(value) == "table" and type(value.GUID) == "number" and Ents[value.GUID] == value
        and type(value.IsValid) == "function" and value:IsValid()
end

function Guard.IsFinite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function Guard.DecodeTable(payload)
    if type(payload) ~= "string" or payload == "" then return end
    local ok, data = RunInSandboxSafe(payload)
    if ok and type(data) == "table" then return data end
end

function Guard.CanUseFurnace(player, inst)
    if not Guard.IsEntity(player) or not Guard.IsEntity(inst) or inst.prefab ~= "dragonflyfurnace" then return false end
    local container = inst.components and inst.components.container
    local controller = player.components and player.components.playercontroller
    return container and container:IsOpenedBy(player) and inst:IsNear(player, 4)
        and controller and controller:IsEnabled() and player.sg and not player.sg:HasStateTag("busy") or false
end

return Guard
