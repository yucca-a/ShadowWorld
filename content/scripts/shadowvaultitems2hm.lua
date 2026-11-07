-- Item serialization and placement shared by Shadow Nexus transfers.
local Adapter={}
local LIMIT=8192*64
local function movable(item, visited)
    if visited[item] then return false end
    visited[item] = true
    if not item:IsValid() or not item.persists or item:HasTag("irreplaceable") or
        (item.components.migrationpetowner and item.components.migrationpetowner:GetPet()) then return false end
    local container = item.components.container
    if container then
        for _, child in pairs(container.slots) do if not movable(child, visited) then return false end end
    end
    return true
end

local function layout(container)
    return tostring(container.numslots) .. ":" .. tostring(container.infinitestacksize == true) .. ":" ..
        tostring(container.acceptsstacks == true) .. ":" .. tostring(container.usespecificslotsforitems == true)
end

function Adapter:Snapshot(name, local_page)
    local inst = self:Container(name)
    if not inst then return nil, "container_missing" end
    local container = inst.components.container
    for _, item in pairs(container.slots) do
        local ok,allowed=pcall(movable,item,{})
        if not ok or not allowed then
            if inst.shadowvault_snapshot_error2hm~=item then
                inst.shadowvault_snapshot_error2hm=item
                local bad=type(item)=="table"and item or {}
                print("[ShadowVault2hm] item_capture_blocked",inst.prefab,bad.prefab,
                    "movable",ok and allowed,"persistent",bad.persists)
            end
            return nil, "linked_items"
        end
    end
    local success, data, references = pcall(container.OnSave, container)
    if not success or type(data) ~= "table" then return nil, "invalid_items" end
    if references and (type(references)~="table" or next(references)) then return nil, "linked_items" end
    if type(data.items) ~= "table" then return nil, "invalid_items" end
    for slot in pairs(container.slots) do
        if not data.items[slot] then return nil, "invalid_items" end
    end
    local payload = {items = data.items, layout = layout(container), session = self.session}
    local ok, encoded = pcall(DataDumper, payload, nil, true)
    if not ok then return nil, "invalid_items" end
    -- Whole local pages go to disk. Only payloads that may cross shards use the RPC limit.
    if not local_page and #encoded > LIMIT - 4096 then return nil, "too_large" end
    local decoded, frozen = RunInSandboxSafe(encoded)
    if not decoded or type(frozen) ~= "table" then return nil, "invalid_items" end
    local valid, reason = self:Validate(name, frozen)
    if not valid then return nil, reason end
    inst.shadowvault_snapshot_error2hm=nil
    return frozen
end

local function validrecords(value, depth)
    if depth > 64 then return false end
    if type(value) ~= "table" then return type(value) ~= "function" and type(value) ~= "userdata" end
    if value.prefab ~= nil and (type(value.prefab) ~= "string" or Prefabs[value.prefab] == nil) then return false end
    for _, child in pairs(value) do if not validrecords(child, depth + 1) then return false end end
    return true
end

-- Check the actual mod-provided save contract before native UI moves an item.
-- No prefab allowlist: nested data/skins/components use the same serializer as
-- transfers. Linked entities cannot be reconstructed from an inventory record.
function Adapter.CheckItem(item)
    local ok,allowed=pcall(movable,item,{})
    if not ok or not allowed then return false,"linked_items" end
    local success,record,refs=pcall(item.GetSaveRecord,item)
    if not success or type(record)~="table" or type(record.prefab)~="string" then return false,"invalid_items" end
    if refs and (type(refs)~="table" or next(refs)) then return false,"linked_items" end
    if not validrecords(record,0) then return false,"invalid_items" end
    local encoded,body=pcall(DataDumper,record,nil,true)
    if not encoded then return false,"invalid_items" end
    local decoded,frozen=RunInSandboxSafe(body)
    if not decoded or type(frozen)~="table" or not validrecords(frozen,0) then return false,"invalid_items" end
    return true
end

function Adapter:Validate(name, payload)
    local inst = self:Container(name)
    if not inst then return false, "container_missing" end
    if type(payload) ~= "table" or type(payload.items) ~= "table" or type(payload.session) ~= "string" then return false, "invalid_items" end
    local container = inst.components.container
    if payload.layout ~= layout(container) then return false, "incompatible" end
    for slot, record in pairs(payload.items) do
        if type(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > container.numslots or
            type(record) ~= "table" or type(record.prefab) ~= "string" or not validrecords(record, 0) then return false, "invalid_items" end
    end
    return true
end

function Adapter:Apply(name, payload)
    local ok, why = self:Validate(name, payload)
    if not ok then return false, why end
    local inst = self:Container(name)
    local container, spawned, originals = inst.components.container, {}, {}
    -- Restore all records before removing any original item. This is synchronous:
    -- a save cannot observe half of an exchange between these Lua statements.
    local success, err = pcall(function()
        for slot, record in pairs(payload.items) do
            local item = SpawnPrefab(record.prefab, record.skinname, record.skin_id, {sessionid = payload.session})
            assert(item, "missing prefab " .. record.prefab)
            spawned[slot] = item
            if record.alt_skin_ids then item.alt_skin_ids = record.alt_skin_ids end
            if record.scenario or (record.data and record.data.scenariorunner) then
                if not item.components.scenariorunner then item:AddComponent("scenariorunner") end
                if record.scenario then item.components.scenariorunner:SetScript(record.scenario) end
            end
            item:SetPersistData(record.data)
            assert(item:IsValid() and item.components.inventoryitem, "invalid restored item")
        end
    end)
    if not success then
        for _, item in pairs(spawned) do if item:IsValid() then item:Remove() end end
        print("[WorldExchange2hm] restore error", tostring(err))
        return false, "apply_failed"
    end
    container.worldexchange_internal2hm = true
    container:EnableReadOnlyContainer(false)
    local ignoreoverstacked = container.ignoreoverstacked
    container.ignoreoverstacked = true
    success, err = pcall(function()
        for slot, item in pairs(spawned) do assert(container:CanTakeItemInSlot(item, slot), "item rejected by slot") end
        for slot = 1, container.numslots do originals[slot] = container:RemoveItemBySlot(slot, true) end
        for slot, item in pairs(spawned) do
            assert(container:GiveItem(item, slot, nil, false) and container.slots[slot] == item, "item placement failed")
        end
    end)
    local cleaned, cleanup_error = pcall(function()
        if not success then
            for slot, item in pairs(spawned) do
                if container.slots[slot] == item then container:RemoveItemBySlot(slot, true) end
                if item:IsValid() then item:Remove() end
            end
            for slot, item in pairs(originals) do
                assert(container:GiveItem(item, slot, nil, false) and container.slots[slot] == item, "original item restore failed")
            end
        else
            for _, item in pairs(originals) do item:PushEvent("player_despawn"); item:Remove() end
        end
    end)
    container.ignoreoverstacked = ignoreoverstacked
    container:EnableReadOnlyContainer(true)
    container.worldexchange_internal2hm = nil
    if not success or not cleaned then
        print("[WorldExchange2hm] placement error", tostring(err), tostring(cleanup_error))
        return false, "apply_failed"
    end
    return true
end

return Adapter
