local boss = {IsValid = function() return true end, HasTag = function(_, tag) return tag == "epic" end}
local player = {IsValid = function() return true end, HasTag = function(_, tag) return tag == "player" end}

local function spawn(saved)
    local inst = setmetatable({components = {}, IsValid = function() return true end,
        HasTag = function() return false end}, {__index = EntityScript})
    local health = {currenthealth = 100, maxhealth = 100}
    function health:SetVal(value) self.currenthealth = math.max(0, value) end
    function health:OnSave() return {health = self.currenthealth} end
    function health:OnLoad(data) self:SetVal(data.health) end
    inst.components.health = health
    inst.components.lootdropper = {GenerateLoot = function()
        local loot = {}
        for i = 1, 10 do loot[i] = "rocks" end
        return loot
    end}
    function inst:AddComponent(name) self.components[name] = Persistent(self) end
    function inst:DoTaskInTime(_, fn) self.initialize = fn end
    function inst:WatchWorldState(_, fn)
        assert(not self.onDay, "only one daily listener per creature")
        self.onDay = fn
        self.registrations = (self.registrations or 0) + 1
    end
    function inst:StopWatchingWorldState(_, fn)
        assert(self.onDay == fn, "remove the registered callback")
        self.onDay = nil
    end
    -- Native order is prefab post-init, saved data, then scheduled tasks.
    inst.OnPreLoad = function(self) self.preloaded = true end
    Initialize(inst)
    inst:SetPersistData(saved)
    inst.initialize()
    assert(inst.preloaded, "the prefab's existing OnPreLoad still runs")
    return inst
end

local function snapshot(inst)
    return assert(loadstring(DataDumper(inst:GetPersistData(), nil, true)))()
end

local function lootAfterFinish(inst)
    inst.components.health:SetVal(0, "player", player)
    return #inst.components.lootdropper:GenerateLoot()
end

for _, damage in ipairs({90, 99}) do
    local victim = spawn()
    local beforeHit = snapshot(victim)
    victim.components.health:SetVal(100 - damage, "epic", boss)
    local afterHit = snapshot(victim)
    local restored = spawn(afterHit)
    assert(restored.components.health.currenthealth == 100 - damage, "saved health is restored")
    assert(lootAfterFinish(restored) == ExpectedRemaining, "reloading a wounded target must retain boss damage")
    assert(lootAfterFinish(spawn(afterHit)) == ExpectedRemaining, "repeated rollback to the same wounded snapshot must retain the reduction")
    assert(lootAfterFinish(spawn(beforeHit)) == 10, "rollback to before the hit restores full loot")
end

local victim = spawn()
victim.components.health:SetVal(10, "epic", boss)
local saved = snapshot(victim)
TheWorld.state.cycles = 11
assert(lootAfterFinish(spawn(saved)) == ExpectedAfterOneDay, "one in-game day still decays boss damage by 20% max health")

local untouched = spawn()
assert(not untouched.onDay, "untouched creatures have no daily listener")
assert(not untouched.components.persistent2hm, "daily decay must not allocate a record for an untouched creature")

local rested = spawn(saved)
TheWorld.state.cycles = 15
assert(rested.onDay, "positive saved records restore daily decay")
rested.onDay(rested)
assert(not rested.onDay, "zero damage removes the daily listener")
TheWorld.state.cycles = 16
rested.components.health:SetVal(100, "heal")
rested.components.health:SetVal(10, "epic", boss)
assert(rested.onDay and rested.registrations == 2, "a later boss hit starts daily decay again")
assert(lootAfterFinish(rested) == ExpectedRemaining, "expired damage must not decay a new boss hit")
local ordinary = spawn()
ordinary.components.health:SetVal(90, "player", player)
assert(not ordinary.onDay and not ordinary.components.persistent2hm, "ordinary damage does not start tracking")
ordinary.components.health:SetVal(80, "epic", boss)
ordinary.components.health:SetVal(70, "epic", boss)
assert(ordinary.registrations == 1, "repeated hits reuse the daily listener")
local empty = snapshot(spawn())
assert(not spawn(empty).onDay, "unwounded save reload stays unregistered")
print("Epic Ruin save, reload and rollback checks passed")
