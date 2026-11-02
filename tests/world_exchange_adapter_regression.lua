local assertions, now, wire = 0, 100, {}
local function check(ok, message) assertions = assertions + 1; assert(ok, message) end
GetStaticTime = function() return now end
GetTimeReal = function() return now * 1000 end
AllPlayers, TUNING, ShardList = {}, {}, {}
TheShard = {GetShardId = function() return "1" end}
Shard_IsWorldAvailable = function() return true end
GetShardModRPC = function() return "rpc" end
SendModRPCToShard = function(_, peer, ...) table.insert(wire, {peer = peer, args = {...}}) end
local function world()
    return {meta = {session_identifier = "session-1"}, components = {}, saves = 0,
        DoStaticPeriodicTask = function() return {Cancel = function() end} end,
        PushEvent = function(self, event) check(event == "ms_save", "native coordinated save event"); self.saves = self.saves + 1 end,
        GetPocketDimensionContainer = function(self) return self.box end,
        IsValid = function() return true end}
end
local inst = world()
local service = WorldExchange(inst)
service:Initialize()
local protocol = service.protocol

-- A peer identity is accepted only after answering our current challenge.
local hello = DataDumper({v = 1, session = "session-2"}, nil, true)
service:Packet("2", "HELLO", "boot-B", "", "foreign", 0, 0, hello)
check(service.peers["2"] == nil, "unsolicited hello cannot establish a trusted peer boot")
service:Hello("2")
local challenge = wire[#wire].args[4]
service:Packet("2", "HELLO_ACK", "boot-B", "wrong-target", challenge, 0, 0, hello)
check(service.peers["2"] == nil, "ack for another local boot rejected")
service:Packet("2", "HELLO_ACK", "boot-B", service.boot, challenge, 0, 0, hello)
check(service.peers["2"].boot == "boot-B", "current handshake establishes peer")
service:Packet("2", "HELLO_ACK", "old-boot", service.boot, challenge, 0, 0, hello)
check(service.peers["2"].boot == "boot-B", "replayed handshake cannot replace peer boot")

-- Real serializer and adapter: reordered/duplicated fragments, bounded buffers.
local received = {}
protocol.Receive = function(_, peer, msg) table.insert(received, {peer = peer, message = msg}) end
local payload = DataDumper({kind = "TEST", content = string.rep("fragmented-content", 2200)}, nil, true)
local count = math.ceil(#payload / 8192)
local function chunk(id, index, count_override, boot, target)
    service:Packet("2", "DATA", boot or "boot-B", target or service.boot, id, index, count_override or count,
        payload:sub((index - 1) * 8192 + 1, index * 8192))
end
for index = count, 2, -1 do chunk("message-1", index); chunk("message-1", index) end
check(#received == 0, "partial/repeated chunks never deliver a partial payload")
chunk("message-1", 1)
check(#received == 1 and received[1].message.content == string.rep("fragmented-content", 2200), "reordered chunks restore exact contents once")
chunk("bad-count", 1, 65)
chunk("bad-index", 0)
chunk("old-boot", 1, nil, "old-boot")
chunk("old-target", 1, nil, nil, "old-target")
check(next(service.inbox["2"]) == nil, "malformed and stale packets do not allocate buffers")
for n = 1, 9 do chunk("partial-" .. n, 1) end
local buffers = 0; for _ in pairs(service.inbox["2"]) do buffers = buffers + 1 end
check(buffers == 8, "incomplete messages bounded per peer")
now = now + 31; service:Update()
check(next(service.inbox["2"]) == nil, "incomplete buffers expire")

wire = {}
service:Send("2", {id = "large", kind = "PREPARE", content = string.rep("x", 50000)})
service:Send("2", {id = "large", kind = "PREPARE", content = "retry"})
check(#service.outbox == 1, "queued retransmits coalesce")
service:Update()
check(#wire == 4 and #service.outbox == 1, "outgoing chunks rate limited to four per tick")
service:Update()
check(#wire == 7 and #service.outbox == 0, "remaining fragments drain on next tick")
for _, packet in ipairs(wire) do check(#packet.args[7] <= 8192, "RPC body respects chunk size") end
protocol.peer_phase, protocol.peer_durable = "applied", true
protocol.active = {peer = "2"}
service:Disconnected("2")
check(service.peers["2"] == nil and protocol.peer_phase == nil and protocol.peer_durable == nil, "disconnect discards stale peer evidence")
protocol.active = nil

-- Save completion must match the exact phase that was serialized, even if
-- network events advanced the transaction while storage was asynchronous.
protocol.active = {id = "transaction", phase = "intent"}
protocol.durable = false
local capture = {}; service.savecapture = capture
service:OnSave(); service.savecapture = nil
protocol:SetPhase("applied")
service:OnSaved(capture)
check(not protocol.durable, "old save callback cannot make a later phase durable")
local capture2 = {}; service.savecapture = capture2
service:OnSave(); service.savecapture = nil; service:OnSaved(capture2)
check(protocol.durable, "matching saved phase becomes durable")
service:Checkpoint(); service:OnSaved(capture2); service:Checkpoint()
check(inst.saves == 1, "save completion does not disable same-phase retry throttle")
now = now + 10; service:Checkpoint()
check(inst.saves == 2, "failed peer save can be retried after throttle")
protocol:SetPhase("intent"); service:Checkpoint()
check(inst.saves == 3, "new phase can request its own checkpoint immediately")
protocol.active = nil

-- Exercise actual container adapter operations with entity/slot stubs. Native
-- counterparts, saves and RPCs are separately checked by isolated game servers.
Prefabs = {goldnugget = true, spear = true, berries = true, bundle = true}
local spawned, fail_spawn, fail_data, fail_slot = {}, false, false, nil
local function item(prefab, data)
    local obj = {prefab = prefab, persists = true, valid = true, components = {inventoryitem = {}}, data = data or {}}
    function obj:IsValid() return self.valid end
    function obj:HasTag(tag) return self.tag == tag end
    function obj:GetSaveRecord() return {prefab = self.prefab, data = self.data}, self.references end
    function obj:SetPersistData(data) if fail_data then error("injected restore failure") end; self.data = data end
    function obj:Remove() self.valid = false end
    function obj:PushEvent() end
    return obj
end
SpawnPrefab = function(prefab, skinname, skinid, creator)
    if fail_spawn then return nil end
    local obj = item(prefab); obj.skinname, obj.skinid, obj.creator = skinname, skinid, creator
    table.insert(spawned, obj); return obj
end
local function preserver()
    return {perish_rate_multiplier = .5, temperature_rate_multiplier = .25,
        SetPerishRateMultiplier = function(self, value) self.perish_rate_multiplier = value end,
        SetTemperatureRateMultiplier = function(self, value) self.temperature_rate_multiplier = value end}
end
local box = {components = {preserver = preserver()}, tags = {}, valid = true}
function box:IsValid() return self.valid end
function box:AddTag(tag) self.tags[tag] = true end
function box:RemoveTag(tag) self.tags[tag] = nil end
function box:HasTag(tag) return self.tags[tag] == true end
local container = {inst = box, numslots = 4, acceptsstacks = true, slots = {}}
box.components.container = container
function container:EnableReadOnlyContainer(value) self.readonlycontainer = value end
function container:OnSave()
    local items, refs = {}, {}
    for slot, obj in pairs(self.slots) do
        items[slot] = obj:GetSaveRecord()
        for _, ref in ipairs(obj.references or {}) do table.insert(refs, ref) end
    end
    return {items = items}, refs
end
function container:CanTakeItemInSlot(_, slot) return slot <= self.numslots and not self.readonlycontainer end
function container:RemoveItemBySlot(slot) local obj = self.slots[slot]; self.slots[slot] = nil; return obj end
function container:GiveItem(obj, slot)
    if fail_slot == slot and obj.prefab == "spear" then return false end
    if self.slots[slot] then return false end
    self.slots[slot] = obj; return true
end
inst.box = box
local original = item("goldnugget", {count = 17, nested = {durability = .42}})
container.slots[1] = original
check(service:Lock("shadow"), "container lock acquired")
check(container.readonlycontainer and box:HasTag("exchangeloading2hm") and box.dcs2hm, "read-only and sort guard enabled")
check(box.components.preserver.perish_rate_multiplier == 0 and box.components.preserver.temperature_rate_multiplier == 0, "locked contents frozen")
local snapshot = service:Snapshot("shadow")
check(snapshot and snapshot.items[1].data.count == 17, "native serializer snapshots item data")
original.data.count = 99
check(snapshot.items[1].data.count == 17, "journal snapshots do not alias mutable live data")
service:Unlock("shadow")
check(not container.readonlycontainer and not box.dcs2hm, "unlock restores normal container behavior")
check(box.components.preserver.perish_rate_multiplier == .5 and box.components.preserver.temperature_rate_multiplier == .25, "unlock restores prior preservers")
original.persists = false
check(service:Snapshot("shadow") == nil, "nonpersistent items cannot silently disappear in transfer")
original.persists = true; original.references = {123}
check(service:Snapshot("shadow") == nil, "external entity references rejected")
original.references = nil; original.tag = "irreplaceable"
check(service:Snapshot("shadow") == nil, "irreplaceable items rejected")
original.tag = nil
original.data.nested = {prefab = "missing_mod_prefab"}
check(service:Snapshot("shadow") == nil, "unknown nested prefabs rejected before exchange")
original.data.nested = nil
local incoming = {layout = snapshot.layout, session = "session-2", items = {[3] = {prefab = "spear", skinname = "testskin", skin_id = 123, data = {durability = .42}}}}
check(service:Validate("shadow", incoming), "compatible sparse record accepted")
incoming.layout = "mismatch"
check(not service:Validate("shadow", incoming), "incompatible capacity rejected")
incoming.layout = snapshot.layout
service:Lock("shadow")
for _, fault in ipairs({"spawn", "data", "slot"}) do
    fail_spawn, fail_data, fail_slot = fault == "spawn", fault == "data", fault == "slot" and 3 or nil
    check(not service:Apply("shadow", incoming), "apply fails safely on " .. fault)
    check(container.slots[1] == original and original:IsValid() and container.slots[3] == nil, "original items remain intact on " .. fault)
    check(container.readonlycontainer and not container.worldexchange_internal2hm, "read-only restored on " .. fault)
end
fail_spawn, fail_data, fail_slot = false, false, nil
check(service:Apply("shadow", incoming), "compatible item applies")
check(not original:IsValid() and container.slots[1] == nil, "original removed only after all incoming items placed")
local restored = container.slots[3]
check(restored.data.durability == .42 and restored.skinname == "testskin" and restored.skinid == 123, "restored item preserves data and skin")
check(restored.creator.sessionid == "session-2", "skin creator uses source session")
check(container.readonlycontainer and not container.worldexchange_internal2hm, "applied items remain locked until commit")
service:Unlock("shadow")

-- Execute installed hooks: readonly server mutation guards + SaveGame capture.
local container_hook
GLOBAL = _G
AddPrefabPostInit = function() end
AddShardModRPCHandler = function() end
AddComponentPostInit = function(name, callback) if name == "container" then container_hook = callback end end
local saved_callback
TheWorld = inst
inst.components.worldexchange2hm = service
SaveGame = function(_, callback) service:OnSave(); saved_callback = callback end
Shard_UpdateWorldState = function() end
assert(loadstring(integration_source))()
local called = 0
local guarded = {worldexchange_locked2hm = true}
for _, method in ipairs({"GiveItem", "RemoveItem_Internal", "DestroyContents", "DestroyContentsConditionally", "DropEverything"}) do
    guarded[method] = function() called = called + 1; return true end
end
container_hook(guarded)
for _, method in ipairs({"GiveItem", "RemoveItem_Internal", "DestroyContents", "DestroyContentsConditionally", "DropEverything"}) do guarded[method](guarded) end
check(called == 0, "locked container rejects external server mutations")
guarded.worldexchange_internal2hm = true; guarded:GiveItem()
check(called == 1, "internal commit can mutate locked container")
protocol.active = {id = "captured", phase = "intent"}; protocol.durable = false
local caller_completed = false
SaveGame(false, function() caller_completed = true end)
check(not protocol.durable and service.savecapture == nil, "SaveGame waits for native callback and clears temporary capture")
saved_callback()
check(protocol.durable and caller_completed, "native completion marks captured phase durable and forwards callback")
print("World exchange adapter: " .. assertions .. " assertions passed")
