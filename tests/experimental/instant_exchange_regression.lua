local assertions = 0
local function check(ok, description) assertions = assertions + 1; assert(ok, description) end
-- Network tests use a known common cut. Engine checkpoint creation/restoration
-- is explicitly outside this test and is never assumed to be implemented.
Protocol = {new = function(io, saved)
    local guard = {ready = true, generation = "cut-1"}
    function guard:Generation() return self.generation end
    function guard:IsReady() return self.ready end
    function guard:IsFrozen() return not self.ready end
    function guard:CanExchange() return self.ready end
    function guard:Dirty() self.dirty = true end
    return Instant.new(io, saved, guard)
end}

local function swapped(sim)
    check(sim:finished(), "both sides finish")
    check(equal(sim.worlds["1"].goods, initial["2"]) and equal(sim.worlds["2"].goods, initial["1"]), "exact item data conserved")
    check(sim.worlds["1"].applies == 1 and sim.worlds["2"].applies == 1, "one apply per side")
    check(not sim.worlds["1"].locked and not sim.worlds["2"].locked, "unlocked after mutual confirmation")
    check(sim.saves == 0, "exchange did not force a world save")
end
local sim = simulation()
sim:start("1"); sim:run(30, function(s) return s:finished() end); swapped(sim)
check(sim.time < 1, "healthy simulated exchange takes less than one second")
local record = sim.worlds["1"].protocol:Save()
check(record.version == 2 and record.mode == "instant" and record.checkpoint == "cut-1", "fast snapshot explicitly identifies its durability model")
local generation = {Generation = function() return "cut-1" end}
check(not pcall(Instant.new, {}, {version = 1, active = {}}, generation), "unfinished durable transaction cannot be converted to fast mode")
check(not pcall(Instant.new, {}, {version = 2, mode = "instant", checkpoint = "old", active = {}}, generation), "active state from another cut cannot be resumed")
for _, kind in ipairs({"PREPARE", "READY", "INTENT", "STATE", "APPLY", "RELEASE", "CLOSED"}) do
    sim = simulation({drop = function(m, _, s)
        if m.kind == kind and not s.dropped[kind] then s.dropped[kind] = true; return true end
    end})
    sim:start("1"); sim:run(120, function(s) return s:finished() end); swapped(sim)
    check(sim.dropped[kind], "injected " .. kind .. " loss")
end
math.randomseed(815179)
for i = 1, 30 do
    sim = simulation({duplicate = true, jitter = 1.5})
    sim:start(i % 2 == 0 and "1" or "2")
    sim:run(180, function(s) return s:finished() end); swapped(sim)
    sim.worlds["1"].goods.items, sim.worlds["2"].goods.items = {}, {}
    for _, packet in ipairs(sim.sent) do
        -- Replaying terminal replies can append to sim.sent. Filter out all
        -- replies so this loop is bounded and still exercises original commands.
        if packet.message.kind ~= "CLOSED" then sim.worlds[packet.peer].protocol:Receive(packet.from, packet.message) end
    end
    sim:run(5)
    check(next(sim.worlds["1"].goods.items) == nil and next(sim.worlds["2"].goods.items) == nil, "duplicate messages do not recreate consumed items")
end
sim = simulation({duplicate = true, jitter = .3})
sim:start("1"); sim:start("2"); sim:run(120, function(s) return s:finished() end); swapped(sim)

sim = simulation({drop = function(m) return m.kind == "PREPARE" end})
sim:start("1"); sim:run(40)
check(sim:finished() and equal(sim.worlds["1"].goods, initial["1"]), "preparation timeout preserves originals")
check(sim.saves == 0, "cancellation is also part of unsaved gameplay")

-- Explicitly demonstrate why restarting only one shard is unsafe without the
-- real guard: the resumed shard has no journal for exchanges after its last cut.
sim = simulation()
sim:start("1"); sim:run(30, function(s) return s:finished() end); swapped(sim)
sim:restart("1")
check(equal(sim.worlds["1"].goods, initial["1"]) and equal(sim.worlds["2"].goods, initial["1"]), "negative control reproduces duplicate A / missing B after isolated restart")
sim:restart("2")
check(equal(sim.worlds["1"].goods, initial["1"]) and equal(sim.worlds["2"].goods, initial["2"]), "paired rollback restores the original complete cut")

-- Guard model tests. Restoring a box alone is never accepted as recovery.
local pinned = true
local restored_world_and_players, manifest_ok = false, true
local io = {id = "1", boot = "boot-1", idle = function() return true end,
    has_snapshot = function() return pinned end,
    pin = function() return pinned end,
    persist_manifest = function() return manifest_ok end,
    restore_world_and_players = function() restored_world_and_players = true; return true end}
local cut = {generation = "cut-1", snapshot = 10, players = {"player-1"}, boots = {["1"] = "boot-1", ["2"] = "boot-2"}}
local guard = Guard.new(io, cut)
local vote = guard:Connect("2", {boot = "boot-2", checkpoint = cut})
check(vote and not guard:CanExchange("2"), "one-sided readiness cannot unlock exchange")
check(not guard:Activate("2", {generation = "cut-1", ready = true, local_boot = "stale", peer_boot = "boot-1"}), "old-boot votes rejected")
check(guard:Activate("2", {generation = "cut-1", ready = true, local_boot = "boot-2", peer_boot = "boot-1"}), "matching mutual readiness accepted")
guard:Dirty(); guard:Disconnect("2")
check(not guard:CanExchange("2"), "disconnect blocks new trades")
check(not guard:Connect("2", {boot = "restarted-2", checkpoint = cut}), "dirty live shard detects restarted peer")
check(guard.phase == "recovery_required", "asymmetric restart requires recovery")
pinned = false
check(not guard:Recover(cut) and not restored_world_and_players, "missing checkpoint never triggers partial recovery")
pinned = true
check(guard:Recover(cut) and restored_world_and_players, "recovery delegates the whole world and player cut")

io.boot = "restarted-1"
guard = Guard.new(io, cut)
check(not guard:Connect("2", {boot = "boot-2", checkpoint = cut, dirty = true}), "restarted side also refuses a dirty live peer")
io.boot = "boot-1"
guard = Guard.new(io, cut)
guard:Connect("2", {boot = "boot-2", checkpoint = cut})
guard:Activate("2", {generation = "cut-1", ready = true, local_boot = "boot-2", peer_boot = "boot-1"})
check(guard:Freeze("cut-2") and not guard:CanExchange("2"), "checkpoint freeze prevents new exchanges")
check(guard:Saved(11, {"player-1"}), "checkpoint stores world and player set")
manifest_ok = false
check(not guard:Seal("2", {generation = "cut-2", snapshot = 11}) and not guard:IsReady(), "failed manifest does not reopen exchanges")
manifest_ok = true
check(guard:Seal("2", {generation = "cut-2", snapshot = 11}) and guard:Generation() == "cut-2" and
    not guard:IsReady(), "local seal still waits for peer activation")
check(not guard:Activate("2", {generation = "cut-1", ready = true, local_boot = "boot-2", peer_boot = "boot-1"}), "old cut activation rejected")
check(guard:Activate("2", {generation = "cut-2", ready = true, local_boot = "boot-2", peer_boot = "boot-1"}), "matching sealed cut activated")
print("Instant exchange research: " .. assertions .. " assertions passed")
