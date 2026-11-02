local assertions = 0
local function equal(actual, expected, message)
    assertions = assertions + 1
    assert(actual == expected, (message or "mismatch") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
GLOBAL = _G
TheWorld = {ismastersim = true}
TUNING = {WEIGHABLE_HEAVY_WEIGHT_PERCENT = 0.75}
SPECIAL_EVENTS = {WINTERS_FEAST = "winter"}
function IsSpecialEventActive() return false end
local launched = {}
function SpawnPrefab(prefab) return {prefab = prefab} end
function LaunchAt(item) launched[#launched + 1] = item.prefab end
function math.clamp(n, lo, hi) return math.max(lo, math.min(hi, n)) end
local original = assert(loadstring(original_source))()
local enhance = assert(loadstring(enhanced_source))()
local hook, configured
function GetModConfigData() return configured end
function AddPrefabPostInit(prefab, fn) equal(prefab, "sharkboi", "hook target"); hook = fn end
local function install(multiplier)
    configured = multiplier
    assert(loadstring(patch_source))()
end
local function make(enhanced)
    local inst = {
        components = {health = {currenthealth = 100, minhealth = 1}},
        MakeTrader = original.MakeTrader, GiveReward = original.GiveReward,
        OnSave = original.OnSave, OnLoad = original.OnLoad,
        OnEntitySleep = original.OnEntitySleep, OnEntityWake = original.OnEntityWake,
        SoundEmitter = {PlaySound = function() end}, tags = {},
    }
    function inst:AddComponent(name)
        equal(name, "trader", "only add trader")
        self.components[name] = {SetAcceptTest = function(self, fn) self.test = fn end}
    end
    function inst:AddTag(tag) self.tags[tag] = true end
    function inst:HasTag(tag) return self.tags[tag] == true end
    function inst:IsAsleep() return self.asleep or false end
    function inst:DoTaskInTime(delay, fn)
        self.delay, self.sleepfn = delay, fn
        return {Cancel = function() self.cancelled = true end}
    end
    function inst:PushEvent() end
    function inst:Remove() self.removed = true end
    function inst:StartAggro() self.tags.hostile = true end
    inst.sg = {HasAnyStateTag = function() return true end, GoToState = function() end}
    if enhanced then enhance(inst) end
    hook(inst)
    return inst
end
local function save(inst)
    local data = {}
    inst:OnSave(data)
    return data
end
local function load(data, enhanced, defeated)
    local inst = make(enhanced)
    if defeated ~= false then inst.components.health.currenthealth = 1 end
    inst:OnLoad(data)
    return inst
end
local function fish(weight, percent)
    return {
        HasTag = function(_, tag) return tag == "oceanfish" end,
        components = {weighable = {GetWeight = function() return weight end,
            GetWeightPercent = function() return percent end}},
    }
end
local function trade(inst, percent)
    local item = fish(200, percent)
    assert(inst.components.trader.test(inst, item))
    inst.components.trader.onaccept(inst, nil, item)
    inst:GiveReward(nil)
end

for _, enhanced in ipairs({false, true}) do
    for _, case in ipairs({{1, 5}, {1.1, 5}, {1.2, 5}, {1.4, 6}, {1.5, 6}, {2, 7}, {3, 10}, {5, 15}, {100, 252},
        {false, 5}, {nil, 5}, {true, 5}, {"2", 5}, {0, 5}, {101, 252}, {math.huge, 5}, {-math.huge, 5}, {0/0, 5}}) do
        install(case[1])
        local inst = make(enhanced)
        equal(inst.stock, nil, "not a trader before defeat")
        inst:MakeTrader()
        equal(inst.stock, case[2], "initial capacity")
        inst.stock = inst.stock - 1
        inst.stock_ = 4 -- Existing enhancement can otherwise reinsert this old value.
        local remaining = inst.stock
        inst:MakeTrader()
        equal(inst.stock, remaining, "repeat does not refill or replay stock_")
        inst:OnEntitySleep()
        equal(inst.stock, remaining, "sleep does not refill")
        equal(inst.delay, 60, "original offscreen despawn time")
        inst:OnEntityWake()
        equal(inst.cancelled, true, "wake cancels offscreen removal")
    end

    install(3)
    local asleep = make(enhanced)
    asleep.components.health.currenthealth = 1
    asleep:OnEntitySleep() -- Real callback invokes local MakeTrader, not inst.MakeTrader.
    equal(asleep.stock, 10, "first trader via local sleep path")
    asleep.stock = 7
    asleep:OnEntitySleep()
    equal(asleep.stock, 7, "repeated sleep keeps local-path remaining stock")
    for _, remaining in ipairs({500, 10, 9, 6, 5, 4, 0}) do
        local inst = make(enhanced)
        inst:MakeTrader()
        inst.stock = remaining
        local data = save(inst)
        equal(data.frostjawstock2hm, remaining, "save every remaining balance")
        if remaining >= 5 then equal(data.stock, nil, "real vanilla omits stock >=5") end
        for _, smaller in ipairs({1, false}) do
            install(smaller)
            local restored = load(data, enhanced)
            equal(restored.stock, remaining, "restore earned balance (including legacy500) after config shrinks/disables")
            restored:MakeTrader()
            equal(restored.stock, remaining, "loaded stock survives repeat MakeTrader")
            equal(save(restored).frostjawstock2hm, remaining, "second save preserves balance")
        end
        install(3)
    end

    for _, remaining in ipairs({5, 4, 0}) do
        local data = remaining < 5 and {stock = remaining, stock_ = remaining} or {}
        local legacy = load(data, enhanced)
        equal(legacy.stock, remaining, "legacy defeated save receives no new allocation")
        legacy:MakeTrader()
        equal(legacy.stock, remaining, "legacy repeat does not refill")
    end
    local fighting = load({aggro = true}, enhanced, false)
    equal(fighting.stock, nil, "fighting save has no trader")
    equal(fighting:HasTag("hostile"), true, "original combat reload retained")
    fighting:MakeTrader()
    equal(fighting.stock, 10, "new defeat after combat reload uses current capacity")

    local combat = make(enhanced)
    local combatdata = save(combat)
    equal(combatdata.frostjawstock2hm, nil, "alive combat save has not earned a balance")
    local resumed = load(combatdata, enhanced, false)
    resumed.components.health.currenthealth = 1
    resumed:OnEntitySleep()
    equal(resumed.stock, 10, "combat save later defeats through local sleep entrance")
    local transition = make(enhanced)
    transition.components.health.currenthealth = 1
    equal(transition.components.trader, nil, "defeat animation has not built trader")
    local transitiondata = save(transition)
    equal(transitiondata.frostjawstock2hm, 10, "defeat transition saves earned capacity")
    install(false)
    local loadedtransition = load(transitiondata, enhanced)
    equal(loadedtransition.stock, 10, "defeat transition keeps earned balance after config disables")
    loadedtransition:MakeTrader()
    equal(loadedtransition.stock, 10, "defeat transition repeat does not refill")
    install(3)

    for _, malformed in ipairs({math.huge, -math.huge, 0/0, "9", true}) do
        local restored = load({frostjawstock2hm = malformed, stock = 3}, enhanced)
        equal(restored.stock, 3, "invalid saved custom balance preserves vanilla balance")
    end
    equal(load({frostjawstock2hm = 501}, enhanced).stock, 500, "saved balance upper bound")
    equal(load({frostjawstock2hm = -1}, enhanced).stock, 0, "saved balance lower bound")

    -- Real accept/reward functions: capacity does not change fish weights or payouts.
    local inst = make(enhanced)
    inst:MakeTrader()
    equal(inst.components.trader.test(inst, fish(149, 1)), false, "too-small fish refused")
    launched = {}
    trade(inst, 0.5)
    equal(inst.stock, 9, "ordinary trade consumes one")
    equal(#launched, 1, "ordinary fish yields one reward")
    equal(launched[1], enhanced and "bootleg2hm" or "bootleg", "original/enhanced reward prefab")
    launched = {}
    trade(inst, 1)
    equal(inst.stock, 8, "heavy trade consumes one")
    equal(#launched, 3, "heavy fish yields two rewards plus initial sketch")
    equal(launched[1], "chesspiece_sharkboi_sketch", "sketch retained")
    launched = {}
    trade(inst, 1)
    equal(#launched, 2, "sketch only once")
    inst.stock = 0
    equal(inst.components.trader.test(inst, fish(200, 1)), false, "empty stock refuses fish")
    inst.stock = 2; inst.pendingreward = 2
    local pending = load(save(inst), enhanced)
    equal(pending.pendingreward, 2, "pending payout preserved by real OnLoad")
    pending:GiveReward(nil)
    equal(pending.stock, 1, "pending payout decrements once after reload")
end

-- Only authoritative worlds register instance behavior.
install(3)
TheWorld.ismastersim = false
local client = {components = {}}
hook(client)
equal(client.MakeTrader, nil, "client untouched")
print("PASS: " .. assertions .. " assertions (Lua 5.1; installed Frostjaw trade/save/load/sleep and real enhancement wrappers).")
