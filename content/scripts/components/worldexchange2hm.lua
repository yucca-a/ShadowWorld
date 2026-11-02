local Protocol = require("worldexchangeprotocol2hm")
local CHUNK, MAX_CHUNKS = 8192, 64
local LIMIT = CHUNK * MAX_CHUNKS
local TEXT = {
    preparing = {"正在连接另一世界并准备交换……", "Preparing the world exchange..."},
    finishing = {"物品已保存，正在完成双方确认……", "Items saved; waiting for final confirmation..."},
    done = {"穿越完成，双方物品已交换并保存。", "World exchange completed and saved."},
    busy = {"此世界已有交换正在处理，请稍后再试。", "An exchange is already in progress."},
    connecting = {"正在连接另一世界，请稍后重试；两层都需要安装新版模组。", "Connecting; both shards need the updated mod."},
    timeout = {"对方尚未准备好，交换已取消，原物品保留。", "The peer was not ready; original items were kept."},
    cancelled = {"交换已取消，原物品保留。", "Exchange cancelled; original items were kept."},
    unavailable = {"找不到已连接的另一世界。", "No other connected world was found."},
    container_missing = {"对方尚未准备好对应的容器。", "The matching container is not ready."},
    readonly = {"容器当前不可交换。", "This container is not available for exchange."},
    incompatible = {"两边容器容量或类型不同，未交换物品。", "Container layouts differ; no items were exchanged."},
    linked_items = {"箱内有不可跨世界或关联其他实体的物品，请先取出。", "Remove items linked to other world entities first."},
    invalid_items = {"物品数据不兼容，未交换物品。", "Incompatible item data; no items were exchanged."},
    too_large = {"物品数据过大，请减少嵌套容器后重试。", "Item data is too large; reduce nested containers."},
    apply_failed = {"物品恢复失败，交换已锁定保护，请保留存档并检查日志。", "Item restore failed; exchange locked for recovery."},
    snapshot_mismatch = {"两层交换记录不一致，已锁定保护；请恢复同一时间的双层存档。", "Shard save histories differ; restore a coordinated backup."},
    waiting = {"交换仍在同步，将自动重试；请勿单独回档其中一层。", "Exchange pending; it will retry automatically."},
    idle = {"当前没有待处理的穿越。", "No exchange is pending."},
    saving = {"正在等待双层同步存档完成……", "Waiting for the coordinated world save..."},
}

local WorldExchange = Class(function(self, inst)
    self.inst = inst
    self.peers, self.inbox, self.outbox, self.locks = {}, {}, {}, {}
    self.challenges, self.accepted_hello, self.hello_sequence = {}, {}, 0
    self.message_sequence = 0
    self.boot = tostring(os.time()) .. ":" .. tostring(GetTimeReal()) .. ":" .. tostring(math.random(1, 1073741823))
    self.task = inst:DoStaticPeriodicTask(0.1, function() self:Update() end)
end)

function WorldExchange:Now() return GetStaticTime() end

function WorldExchange:Notify(userid, code)
    local texts = TEXT[code] or TEXT.waiting
    if userid then
        for _, player in ipairs(AllPlayers) do
            if player.userid == userid and player.components.talker then
                player.components.talker:Say(texts[TUNING.isCh2hm and 1 or 2])
                return
            end
        end
    end
end

function WorldExchange:Initialize()
    if self.protocol or not self.inst.meta or not self.inst.meta.session_identifier then return end
    self.id = tostring(TheShard:GetShardId())
    self.session = self.inst.meta.session_identifier
    self.protocol = Protocol.new({
        id = self.id, session = self.session, boot = self.boot,
        now = function() return self:Now() end,
        peer_session = function(peer) return self.peers[peer] and self.peers[peer].session end,
        send = function(peer, message) self:Send(peer, message) end,
        lock = function(name) return self:Lock(name) end,
        unlock = function(name) self:Unlock(name) end,
        snapshot = function(name) return self:Snapshot(name) end,
        validate = function(name, payload) return self:Validate(name, payload) end,
        apply = function(name, payload) return self:Apply(name, payload) end,
        checkpoint = function() self:Checkpoint() end,
        notify = function(userid, code) self:Notify(userid, code) end,
        log = function(reason, id) print("[WorldExchange2hm]", reason, id) end,
    }, self.saved)
    self.saved = nil
    if self.protocol.active then self:Lock(self.protocol.active.name) end
end

function WorldExchange:Container(name)
    local inst = self.inst:GetPocketDimensionContainer(name)
    if inst and inst:IsValid() and inst.components.container and inst.virtchest == nil then return inst end
end

function WorldExchange:Lock(name)
    local inst = self:Container(name)
    if not inst then return false, "container_missing" end
    if self.locks[name] then return true end
    local container = inst.components.container
    if container.readonlycontainer then return false, "readonly" end
    local preserver = inst.components.preserver
    self.locks[name] = {inst = inst, dcs = inst.dcs2hm, preserver = preserver,
        perish = preserver and preserver.perish_rate_multiplier,
        temperature = preserver and preserver.temperature_rate_multiplier}
    inst.dcs2hm = true
    inst:AddTag("exchangeloading2hm")
    container.worldexchange_locked2hm = true
    container:EnableReadOnlyContainer(true)
    if inst.components.preserver then
        inst.components.preserver:SetPerishRateMultiplier(0)
        inst.components.preserver:SetTemperatureRateMultiplier(0)
    end
    return true
end

function WorldExchange:Unlock(name)
    local lock = self.locks[name]
    if not lock then return end
    local inst = lock.inst
    if inst:IsValid() then
        inst.components.container.worldexchange_locked2hm = nil
        inst.components.container:EnableReadOnlyContainer(false)
        inst.dcs2hm = lock.dcs
        inst:RemoveTag("exchangeloading2hm")
        if lock.preserver and inst.components.preserver == lock.preserver then
            lock.preserver:SetPerishRateMultiplier(lock.perish)
            lock.preserver:SetTemperatureRateMultiplier(lock.temperature)
        end
    end
    self.locks[name] = nil
end

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

function WorldExchange:Snapshot(name)
    local inst = self:Container(name)
    if not inst then return nil, "container_missing" end
    local container = inst.components.container
    for _, item in pairs(container.slots) do
        if not movable(item, {}) then return nil, "linked_items" end
    end
    local success, data, references = pcall(container.OnSave, container)
    if not success or type(data) ~= "table" then return nil, "invalid_items" end
    if references and next(references) then return nil, "linked_items" end
    if type(data.items) ~= "table" then return nil, "invalid_items" end
    for slot in pairs(container.slots) do
        if not data.items[slot] then return nil, "invalid_items" end
    end
    local payload = {items = data.items, layout = layout(container), session = self.session}
    local ok, encoded = pcall(DataDumper, payload, nil, true)
    if not ok then return nil, "invalid_items" end
    if #encoded > LIMIT - 4096 then return nil, "too_large" end
    local decoded, frozen = RunInSandboxSafe(encoded)
    if not decoded or type(frozen) ~= "table" then return nil, "invalid_items" end
    local valid, reason = self:Validate(name, frozen)
    if not valid then return nil, reason end
    return frozen
end

local function validrecords(value, depth)
    if depth > 64 then return false end
    if type(value) ~= "table" then return type(value) ~= "function" and type(value) ~= "userdata" end
    if value.prefab ~= nil and (type(value.prefab) ~= "string" or Prefabs[value.prefab] == nil) then return false end
    for _, child in pairs(value) do if not validrecords(child, depth + 1) then return false end end
    return true
end

function WorldExchange:Validate(name, payload)
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

function WorldExchange:Apply(name, payload)
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

function WorldExchange:Checkpoint()
    local t = self.protocol and self.protocol.active
    if not t then return end
    local key = t.id .. "/" .. t.phase
    if self.checkpointkey == key and self.lastcheckpoint and self:Now() - self.lastcheckpoint < 10 then return end
    self.checkpointkey = key
    self.lastcheckpoint = self:Now()
    -- Use the native coordinated autosaver. Saving a shard independently changes
    -- its snapshot number and can make the native autosaver roll that shard back.
    self.inst:PushEvent("ms_save")
end

function WorldExchange:OnSave()
    if self.protocol then
        if self.savecapture then self.savecapture.marker = self.protocol:Marker() end
        return self.protocol:Save()
    end
    return self.saved
end

function WorldExchange:OnLoad(data) self.saved = data end

function WorldExchange:LoadPostPass()
    self:Initialize()
    if self.protocol and self.protocol.active then self:Lock(self.protocol.active.name) end
end

function WorldExchange:OnSaved(capture)
    if self.protocol then self.protocol:OnSaved(capture.marker) end
end

function WorldExchange:Hello(peer, reply, target, challenge)
    if not reply then
        self.hello_sequence = self.hello_sequence + 1
        challenge = tostring(self.hello_sequence)
        self.challenges[peer] = self.challenges[peer] or {}
        self.challenges[peer][challenge] = self:Now() + 60
    end
    SendModRPCToShard(GetShardModRPC("MOD_HARDMODE", "worldexchange_v1"), peer,
        reply and "HELLO_ACK" or "HELLO", self.boot, target or "", challenge, 0, 0,
        DataDumper({v = 1, session = self.session}, nil, true))
end

function WorldExchange:Send(peer, message)
    local connection = self.peers[peer]
    if not connection or not Shard_IsWorldAvailable(peer) then return end
    local encoded = DataDumper(message, nil, true)
    if #encoded > LIMIT then self.protocol:Fail("too_large"); return end
    -- Replace unsent retries of the same phase instead of accumulating a backlog.
    for _, pending in ipairs(self.outbox) do
        if pending.peer == peer and pending.txid == message.id and pending.kind == message.kind then return end
    end
    if #self.outbox >= 32 then return end
    self.message_sequence = self.message_sequence + 1
    table.insert(self.outbox, {peer = peer, target = connection.boot, id = tostring(self.message_sequence),
        txid = message.id, kind = message.kind, data = encoded, index = 1, count = math.max(1, math.ceil(#encoded / CHUNK))})
end

function WorldExchange:Packet(peer, kind, boot, target, id, index, count, data)
    if not self.protocol or peer == self.id or not Shard_IsWorldAvailable(peer) or
        type(data) ~= "string" or type(boot) ~= "string" or #boot > 200 then return end
    if kind == "HELLO" or kind == "HELLO_ACK" then
        if #data > 1024 or (kind == "HELLO_ACK" and target ~= self.boot) then return end
        local ok, info = RunInSandboxSafe(data)
        if not ok or type(info) ~= "table" or info.v ~= 1 or type(info.session) ~= "string" then return end
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
        self.peers[peer] = {boot = boot, session = info.session}
        local t = self.protocol.active
        if t and t.peer == peer then
            local expected = t.coordinator == self.id and t.participant_session or t.coordinator_session
            if expected ~= info.session then self.protocol:Fail("snapshot_mismatch") end
        end
        return
    end
    local connection = self.peers[peer]
    if kind ~= "DATA" or target ~= self.boot or not connection or connection.boot ~= boot or
        type(id) ~= "string" or #id > 40 or type(index) ~= "number" or type(count) ~= "number" or
        index % 1 ~= 0 or count % 1 ~= 0 or index < 1 or count < 1 or count > MAX_CHUNKS or index > count or #data > CHUNK then return end
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
        if ok and type(message) == "table" then self.protocol:Receive(peer, message) end
    end
end

function WorldExchange:Disconnected(peer)
    peer = tostring(peer)
    self.peers[peer], self.inbox[peer], self.challenges[peer] = nil, nil, nil
    if self.protocol and self.protocol.active and self.protocol.active.peer == peer then
        self.protocol.peer_phase, self.protocol.peer_durable = nil, nil
        self.protocol.retry = 0
    end
end

function WorldExchange:Update()
    self:Initialize()
    if not self.protocol then return end
    local now = self:Now()
    if not self.nexthello or now >= self.nexthello then
        self.nexthello = now + 5
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
    if not self.nexttick or now >= self.nexttick then
        self.nexttick = now + 0.5
        self.protocol:Tick()
    end
    for _ = 1, 4 do
        local packet = self.outbox[1]
        if not packet then break end
        local peer = self.peers[packet.peer]
        if peer and peer.boot == packet.target and Shard_IsWorldAvailable(packet.peer) then
            SendModRPCToShard(GetShardModRPC("MOD_HARDMODE", "worldexchange_v1"), packet.peer,
                "DATA", self.boot, packet.target, packet.id, packet.index, packet.count,
                packet.data:sub((packet.index - 1) * CHUNK + 1, packet.index * CHUNK))
            packet.index = packet.index + 1
            if packet.index > packet.count then table.remove(self.outbox, 1) end
        else table.remove(self.outbox, 1) end
    end
end

function WorldExchange:Request(player, inst)
    if not self.protocol then return self:Notify(player.userid, "connecting") end
    local name
    for key, container in pairs(self.inst.PocketDimensionContainers) do if container == inst then name = key; break end end
    if not name then return end
    local choices = {}
    for peer in pairs(ShardList or {}) do
        peer = tostring(peer)
        if peer ~= self.id and Shard_IsWorldAvailable(peer) then table.insert(choices, peer) end
    end
    table.sort(choices)
    if #choices == 0 then return self:Notify(player.userid, "unavailable") end
    local index = ((self.lastchoice or 0) % #choices) + 1
    local ok, reason = self.protocol:Start(name, choices[index], player.userid)
    if ok then self.lastchoice = index else self:Notify(player.userid, reason) end
end

function WorldExchange:Status(player)
    local t = self.protocol and self.protocol.active
    self:Notify(player.userid, not t and "idle" or t.error or
        ((t.phase == "intent" or t.phase == "applied" or t.phase == "aborting") and "saving" or "waiting"))
    if self.protocol then self.protocol.retry = 0 end
end

function WorldExchange:OnRemoveFromEntity() if self.task then self.task:Cancel() end end
WorldExchange.OnRemoveEntity = WorldExchange.OnRemoveFromEntity
return WorldExchange
