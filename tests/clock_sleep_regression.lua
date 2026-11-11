local checks = 0
local function check(value, message) checks = checks + 1; assert(value, message) end
TUNING = {AUTUMN_LENGTH = 20, TOTAL_DAY_TIME = 480, SLEEP_TICK_PERIOD = 1, SLEEP_HUNGER_PER_TICK = -1, SLEEP_HEALTH_PER_TICK = 1, SLEEP_SANITY_PER_TICK = 1}
EQUIPSLOTS = {HEAD = "head"}
local patch
AddComponentPostInit = function(name, fn) check(name == "sleepingbag", "only native sleepingbag interface patched"); patch = fn end
assert(loadstring(SleepPatch))()
local function entity()
    local inst = {components = {}, tags = {}, listeners = {}}
    function inst:HasTag(tag) return self.tags[tag] == true end
    function inst:AddTag(tag) self.tags[tag] = true end
    function inst:RemoveTag(tag) self.tags[tag] = nil end
    function inst:ListenForEvent(name, fn) self.listeners[name] = fn end
    function inst:PushEvent(name, data) if self.listeners[name] then self.listeners[name](self, data) end end
    function inst:WatchWorldState(name, fn) TheWorld.components.worldstate:AddWatcher(name, self, fn, self) end
    function inst:StopWatchingWorldState(name, fn) TheWorld.components.worldstate:RemoveWatcher(name, self, fn, self) end
    function inst:DoPeriodicTask(period, fn) return {fn = fn, Cancel = function(self) self.cancelled = true end} end
    return inst
end
TheWorld = entity()
TheWorld.components.worldstate = NativeWorldState(TheWorld)
TheWorld.state = TheWorld.components.worldstate.data
local function phase(value) TheWorld:PushEvent("phasechanged", value) end
local function sleeper(initial, kind, fixed)
    phase(initial)
    local player, bed = entity(), entity()
    player.wakes = 0
    player.sg = {HasStateTag = function() return false end, GoToState = function(_, name)
        check(name == "wakeup", "native wake state used")
        player.wakes = player.wakes + 1
    end}
    player.components.inventory = {GetEquippedItem = function() return nil end}
    player.components.sleepingbaguser = NativeSleepUser(player)
    bed.components.sleepingbag = NativeSleepingBag(bed)
    if kind == "siesta" then bed.components.sleepingbag:SetSleepPhase("day")
    elseif kind == "upgrade" then bed.components.sleepingbag.GetSleepPhase = function() return TheWorld.state.phase end end
    if fixed then patch(bed.components.sleepingbag) end
    bed.components.sleepingbag:DoSleep(player)
    return player, bed
end
do
    local player = sleeper("night", "tent", false)
    phase("dusk")
    check(player.wakes == 1, "unpatched native callback reproduces night-to-dusk wake")
end
for _, start in ipairs({"dusk", "night"}) do
    for _, target in ipairs({"dusk", "night"}) do
        local player, bed = sleeper(start, "tent", true)
        local task = player.components.sleepingbaguser.sleeptask
        phase(target)
        phase(target) -- duplicate phase events are suppressed by native worldstate
        check(player.wakes == 0 and player.sleepingbag == bed, "dusk and night remain compatible")
        check(player.components.sleepingbaguser.sleeptask == task and not task.cancelled, "sleep recovery task is uninterrupted")
        phase("day")
        check(player.wakes == 1 and player.sleepingbag == nil and task.cancelled, "day wakes and cancels native recovery")
        phase("night"); phase("dusk"); phase("day")
        check(player.wakes == 1, "native phase watcher removed after wake")
    end
end
for _, target in ipairs({"dusk", "night"}) do
    local player = sleeper("day", "siesta", true)
    phase(target)
    check(player.wakes == 1, "siesta keeps its daytime-only restriction")
end
do
    local player, bed = sleeper("day", "siesta", true)
    local proxy = entity()
    proxy.components.sleepingbag = NativeSleepingBag(proxy)
    patch(proxy.components.sleepingbag)
    CopySleepSettings(bed.components.sleepingbag, proxy)
    check(proxy.components.sleepingbag:GetSleepPhase() == "day", "shared siesta inherits native sleep phase")
    phase("dusk")
    check(proxy.components.sleepingbag:GetSleepPhase() == "day", "shared siesta remains daytime-only at dusk")
    phase("day")
    bed.components.sleepingbag:DoSleep(player)
    phase("day")
    check(player.sleepingbag == bed, "siesta stays asleep during day")
    bed.components.sleepingbag:DoWakeUp()
end
do
    local player, bed = sleeper("dusk", "upgrade", true)
    for _, value in ipairs({"night", "day", "dusk", "day", "night"}) do phase(value) end
    check(player.wakes == 0 and player.sleepingbag == bed, "existing all-phase upgrade preserved")
    bed.components.sleepingbag:DoWakeUp()
end
do
    local player, bed = sleeper("dusk", "tent", true)
    player.components.hunger = {DoDelta = function() end, IsStarving = function() return true end}
    player.components.sleepingbaguser:SleepTick()
    check(player.wakes == 1 and player.sleepingbag == nil, "starvation wake is unaffected")
end
do
    local player, bed = sleeper("night", "tent", true)
    bed.components.sleepingbag:DoWakeUp()
    phase("dusk")
    check(player.wakes == 1, "manual or building-triggered wake is unaffected")
end
print("Clock sleeping phases: " .. checks .. " checks passed")
