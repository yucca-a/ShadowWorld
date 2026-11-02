local assertions = 0
local function check(condition, description)
    assertions = assertions + 1
    assert(condition, description)
end
local function copy(v)
    if type(v) ~= "table" then return v end
    local out = {}; for k, child in pairs(v) do out[k] = copy(child) end; return out
end
local function equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not equal(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local initial = {
    ["1"] = {layout = "4", items = {[1] = {prefab = "spear", skin = "red", durability = .42},
        [4] = {prefab = "bundle", items = {{prefab = "berries", stack = 17, perish = .67}}}}},
    ["2"] = {layout = "4", items = {[2] = {prefab = "goldnugget", stack = 40}, [3] = {prefab = "rocks", stack = 12}}},
}

local function simulation(options)
    options = options or {}
    local sim = {time = 0, events = {}, worlds = {}, sent = {}, notices = {}, saves = 0, dropped = {}, boots = 0}
    local function event(delay, fn)
        table.insert(sim.events, {at = sim.time + delay, fn = fn})
    end
    function sim:save()
        if self.saving or not self.worlds["1"].online then return end
        self.saving = true
        event(.35, function()
            self.saves = self.saves + 1
            for _, world in pairs(self.worlds) do
                if world.online then
                    local instance = world.protocol
                    local marker = instance:Marker()
                    local snapshot = {protocol = instance:Save(), goods = copy(world.goods)}
                    event(.1, function()
                        if world.protocol == instance and world.online then
                            world.disk = snapshot
                            instance:OnSaved(marker)
                        end
                    end)
                end
            end
            event(.11, function() self.saving = false end)
        end)
    end
    local function build(world, saved)
        sim.boots = sim.boots + 1
        local io = {
            id = world.id, boot = tostring(sim.boots), session = "session-" .. world.id,
            now = function() return sim.time end,
            peer_session = function(peer) return sim.worlds[peer].online and "session-" .. peer or nil end,
            lock = function() world.locked = true; return true end,
            unlock = function() world.locked = false end,
            snapshot = function() return copy(world.goods) end,
            validate = function(_, payload)
                return type(payload) == "table" and type(payload.items) == "table" and payload.layout == world.goods.layout, "incompatible"
            end,
            apply = function(_, payload)
                if world.failapply then return false, "apply_failed" end
                check(world.locked, "apply must hold container lock")
                world.goods = copy(payload)
                world.applies = world.applies + 1
                return true
            end,
            checkpoint = function() sim:save() end,
            notify = function(_, code) table.insert(sim.notices, {world = world.id, code = code}) end,
            log = function() end,
        }
        io.send = function(peer, message)
            table.insert(sim.sent, {from = world.id, peer = peer, message = copy(message)})
            if not sim.worlds[peer].online or not world.online then return end
            if options.drop and options.drop(message, world.id, sim) then return end
            local delay = options.delay or .05
            if options.jitter then delay = delay + math.random() * options.jitter end
            local data = copy(message)
            event(delay, function()
                if sim.worlds[peer].online then sim.worlds[peer].protocol:Receive(world.id, copy(data)) end
            end)
            if options.duplicate then
                event(delay + .3 + math.random() * 2, function()
                    if sim.worlds[peer].online then sim.worlds[peer].protocol:Receive(world.id, copy(data)) end
                end)
            end
        end
        world.protocol = Protocol.new(io, saved)
    end
    for _, id in ipairs({"1", "2"}) do
        sim.worlds[id] = {id = id, online = true, locked = false, goods = copy(initial[id]), applies = 0,
            disk = {goods = copy(initial[id])}}
    end
    for _, world in pairs(sim.worlds) do build(world) end
    function sim:start(id)
        local peer = id == "1" and "2" or "1"
        return self.worlds[id].protocol:Start("shadow", peer, "player-" .. id)
    end
    function sim:step()
        self.time = self.time + .05
        local pending = self.events; self.events = {}
        for _, e in ipairs(pending) do
            if e.at <= self.time then e.fn() else table.insert(self.events, e) end
        end
        for _, world in pairs(self.worlds) do if world.online then world.protocol:Tick() end end
    end
    function sim:run(seconds, predicate)
        local deadline = self.time + (seconds or 120)
        while self.time < deadline do
            self:step()
            if predicate and predicate(self) then return true end
        end
        return false
    end
    function sim:restart(id)
        local world = self.worlds[id]
        world.goods = copy(world.disk.goods)
        world.locked = false
        build(world, world.disk.protocol)
    end
    function sim:finished()
        return not self.worlds["1"].protocol.active and not self.worlds["2"].protocol.active
    end
    function sim:swapped()
        check(self:finished(), "both sides must finish")
        check(equal(self.worlds["1"].goods, initial["2"]), "A receives exact B slots/properties")
        check(equal(self.worlds["2"].goods, initial["1"]), "B receives exact A slots/properties")
        check(not self.worlds["1"].locked and not self.worlds["2"].locked, "both containers unlocked")
        check(equal(self.worlds["1"].disk.goods, initial["2"]), "A items durable before unlock")
        check(equal(self.worlds["2"].disk.goods, initial["1"]), "B items durable before unlock")
    end
    return sim
end

local sim = simulation()
check(sim:start("1"), "start accepted")
sim:run(120, function(s) return s:finished() end)
sim:swapped()
check(sim.saves == 2, "healthy exchange uses exactly two coordinated checkpoints")
check(sim.worlds["1"].applies == 1 and sim.worlds["2"].applies == 1, "one apply per side")

for _, delay in ipairs({.8, 2, 4}) do
    sim = simulation({delay = delay})
    sim:start("1"); sim:run(200, function(s) return s:finished() end); sim:swapped()
end

-- Drop each protocol message once, including the formerly destructive final ACK.
for _, kind in ipairs({"PREPARE", "READY", "INTENT", "STATE", "APPLY", "RELEASE", "CLOSED"}) do
    sim = simulation({drop = function(message, _, s)
        if message.kind == kind and not s.dropped[kind] then s.dropped[kind] = true; return true end
    end})
    sim:start("1"); sim:run(180, function(s) return s:finished() end); sim:swapped()
    check(sim.dropped[kind], "fault was injected: " .. kind)
    check(sim.worlds["1"].applies == 1 and sim.worlds["2"].applies == 1, "retry never reapplies items: " .. kind)
end

-- Duplicate and reorder all phases, then replay old packets after items are used.
math.randomseed(88171)
for iteration = 1, 30 do
    sim = simulation({delay = .05, jitter = 1.5, duplicate = true})
    sim:start(iteration % 2 == 0 and "1" or "2")
    sim:run(180, function(s) return s:finished() end)
    sim:swapped()
    sim.worlds["1"].goods.items = {}
    sim.worlds["2"].goods.items = {}
    local packets = copy(sim.sent)
    for _, packet in ipairs(packets) do sim.worlds[packet.peer].protocol:Receive(packet.from, packet.message) end
    sim:run(10)
    check(next(sim.worlds["1"].goods.items) == nil and next(sim.worlds["2"].goods.items) == nil, "late packets cannot recreate consumed goods")
    check(sim:finished(), "old packets cannot start another exchange")
end

sim = simulation({duplicate = true, jitter = .3})
sim:start("1"); sim:start("2")
sim:run(180, function(s) return s:finished() end); sim:swapped()
check(sim.worlds["1"].applies == 1 and sim.worlds["2"].applies == 1, "simultaneous clicks coalesce into one swap")

-- Disconnect after both irrevocable intents exist, then reconnect.
sim = simulation()
sim:start("1")
check(sim:run(30, function(s)
    local a, b = s.worlds["1"].protocol.active, s.worlds["2"].protocol.active
    return a and b and a.phase == "intent" and b.phase == "intent"
end), "reached commit intent")
sim.worlds["2"].online = false
sim:run(40)
check(sim.worlds["1"].locked and sim.worlds["2"].locked, "disconnect keeps uncertain items locked")
sim.worlds["2"].online = true
sim:run(180, function(s) return s:finished() end); sim:swapped()

-- Restart either side after a durable intent, and after durable applied state.
for _, phase in ipairs({"intent", "applied"}) do
    for _, restartid in ipairs({"1", "2", "both"}) do
        sim = simulation({delay = .2})
        sim:start("1")
        check(sim:run(60, function(s)
            for _, world in pairs(s.worlds) do
                if not world.disk.protocol or not world.disk.protocol.active or world.disk.protocol.active.phase ~= phase then return false end
            end
            return true
        end), "both snapshots reached " .. phase)
        if restartid == "both" then sim:restart("1"); sim:restart("2") else sim:restart(restartid) end
        sim:run(180, function(s) return s:finished() end); sim:swapped()
    end
end

-- Crash after an unsaved apply: reload original items + intent, not two copies.
sim = simulation({delay = .3})
sim:start("1")
check(sim:run(60, function(s)
    local a = s.worlds["1"]
    return a.protocol.active and a.protocol.active.phase == "applied" and a.disk.protocol.active.phase == "intent"
end), "crash point between apply and checkpoint")
sim:restart("1")
sim:run(180, function(s) return s:finished() end); sim:swapped()

-- No response/old protocol: cancel without destroying local contents.
sim = simulation({drop = function(m) return m.kind == "PREPARE" end})
sim:start("1"); sim:run(60)
check(sim:finished(), "unresponsive peer eventually cancels before intent")
check(equal(sim.worlds["1"].goods, initial["1"]) and equal(sim.worlds["2"].goods, initial["2"]), "cancel preserves originals")

sim = simulation()
sim.worlds["2"].goods.layout = "different"
sim:start("1"); sim:run(60)
check(sim:finished() and sim.worlds["1"].applies == 0 and sim.worlds["2"].applies == 0, "incompatible layouts reject without apply")

sim = simulation()
sim.worlds["2"].failapply = true
sim:start("1"); sim:run(60)
check(sim.worlds["2"].protocol.active.error == "apply_failed", "restore failure is recorded")
check(sim.worlds["1"].locked and sim.worlds["2"].locked, "restore failure never unlocks or blindly rolls back")
check(equal(sim.worlds["2"].goods, initial["2"]), "restore failure preserves original B items")

-- A saved, never-accepted offer still has a timeout after process restart.
sim = simulation({drop = function(m) return m.kind == "PREPARE" end})
sim:start("1"); sim:save(); sim:run(1); sim:restart("1"); sim:run(60)
check(sim:finished() and not sim.worlds["1"].locked, "loaded offer can cancel instead of locking forever")
check(equal(sim.worlds["1"].goods, initial["1"]), "loaded offer timeout preserves originals")

-- After the participant unlocks, later autosaves may contain consumed items.
-- A coordinator retry/restart must finish from the receipt, never replay them.
sim = simulation({drop = function(m, _, s) return m.kind == "CLOSED" and not s.allowclosed end})
sim:start("1")
check(sim:run(60, function(s)
    return s.worlds["1"].protocol.active and s.worlds["1"].protocol.active.phase == "release" and not s.worlds["2"].protocol.active
end), "reached lost final confirmation")
sim.worlds["2"].goods.items = {}
sim:save(); sim:run(1); sim:restart("1"); sim:restart("2")
sim.allowclosed = true; sim:run(60, function(s) return s:finished() end)
check(sim:finished(), "saved receipt completes restarted coordinator")
check(next(sim.worlds["2"].goods.items) == nil, "consumed committed items are never recreated after restart")
check(equal(sim.worlds["1"].goods, initial["2"]), "other side retains exact committed items")

-- A peer loses its pre-checkpoint preparation during a restart. It must not
-- reconstruct an exchange by blindly importing an old incoming payload.
sim = simulation()
sim:start("1")
check(sim:run(10, function(s) return s.worlds["1"].protocol.active and s.worlds["1"].protocol.active.phase == "intent" end), "reached unsaved intent")
sim:restart("2"); sim:run(30)
check(sim:finished(), "lost unsaved preparation cancels automatically")
check(equal(sim.worlds["1"].goods, initial["1"]) and equal(sim.worlds["2"].goods, initial["2"]), "pre-commit restart preserves both originals")
check(sim.worlds["1"].applies == 0 and sim.worlds["2"].applies == 0, "missing journal cannot apply stale goods")

-- In contrast, an independently rolled-back peer may have forgotten a durable
-- decision and consumed items: hold for a coordinated save repair.
sim = simulation()
sim:start("1")
check(sim:run(10, function(s)
    return s.worlds["1"].protocol.active and s.worlds["1"].protocol.active.phase == "intent" and s.worlds["1"].protocol.durable
end), "reached durable intent")
sim.worlds["2"].disk = {goods = copy(initial["2"])}
sim:restart("2"); sim:run(30)
check(sim.worlds["1"].protocol.active.error == "snapshot_mismatch", "independent old rollback detected")
check(sim.worlds["1"].locked, "uncertain coordinator keeps original items protected")

sim = simulation({delay = .3})
sim:start("1")
check(sim:run(10, function(s)
    return s.worlds["2"].protocol.active and s.worlds["2"].protocol.active.phase == "prepared" and
        s.worlds["1"].protocol.active.phase == "offer"
end), "reached participant preparation before coordinator decision")
sim:restart("1"); sim:run(30)
check(sim:finished(), "lost initiator preparation cancels automatically")
check(not sim.worlds["2"].locked, "participant is not stranded by pre-commit initiator crash")
check(equal(sim.worlds["1"].goods, initial["1"]) and equal(sim.worlds["2"].goods, initial["2"]), "pre-commit initiator crash preserves both originals")

-- Identical confirmations should not continually wake the coordinator while a
-- save is pending. Only new phase/durability evidence can bypass its retry timer.
sim = simulation()
sim:start("1")
check(sim:run(10, function(s)
    local p = s.worlds["1"].protocol
    return p.active and p.active.phase == "intent" and p.peer_phase == "intent" and not p.peer_durable
end), "reached waiting-for-save acknowledgement")
local confirmation
for _, packet in ipairs(sim.sent) do
    if packet.from == "2" and packet.message.kind == "STATE" then confirmation = copy(packet.message) end
end
local coordinator = sim.worlds["1"].protocol
coordinator.retry = sim.time + 3
coordinator:Receive("2", confirmation)
check(coordinator.retry == sim.time + 3, "unchanged STATE preserves retry deadline")
confirmation.durable = true
coordinator:Receive("2", confirmation)
check(coordinator.retry == 0 and coordinator.peer_durable, "new durable evidence advances immediately")

print("World exchange protocol: " .. assertions .. " assertions passed")
