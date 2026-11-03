-- Actual native gameplay functions; entity rendering, events and search are simulated.
local checks, live, spawned, stats = 0, {}, {}, {}
local function check(value, why) checks = checks + 1; assert(value, why) end
local noop = function() end
TUNING = {TOTAL_DAY_TIME = 480, TRAP_USES = 8, isCh2hm = true}
FOODTYPE = {VEGGIE = "VEGGIE"}
STRINGS = {ACTIONS = {ACTION2HM = {}}}
TheWorld = {ismastersim = true, PushEvent = noop}
TheNet = {GetServerGameMode = function() return "survival" end}
GetTime = function() return 0 end
ModManager = {GetPostInitData = function() return {} end, GetPostInitFns = function() return {} end}
package.preload["prefabs/wortox_soul_common"] = function()
    return {HasSoul = function(inst) return inst.soul end, GetNumSouls = function(inst) return inst.souls or 1 end}
end
local Trap = assert(loadstring(native_trap))()
local FiniteUses = assert(loadstring(native_uses))()
local graph, prefabhook, graphhook, shadowhook
function AddStategraphPostInit(name, fn) check(name == "trap", "only native trap graph modified"); graphhook = fn end
function AddPrefabPostInit(name, fn) check(name == "trap", "only ordinary trap prefab modified"); prefabhook = fn end
function AddComponentPostInit(name, fn) check(name == "trap", "upstream shadow hook"); shadowhook = fn end
function ProfileStatsAdd(key) stats[key] = (stats[key] or 0) + 1 end

local function entity(prefab)
    local inst = {prefab = prefab, valid = true, awake = true, tags = {}, components = {}, replica = {}, listeners = {}, events = {}, tasks = {}, x = 0, z = 0}
    function inst:IsValid() return self.valid end
    function inst:IsInLimbo() return self:HasTag("INLIMBO") end
    function inst:AddTag(tag) self.tags[tag] = true end
    function inst:RemoveTag(tag) self.tags[tag] = nil end
    function inst:HasTag(tag) return self.tags[tag] == true end
    function inst:Remove() self.valid = false; self.removed = (self.removed or 0) + 1 end
    function inst:ListenForEvent(name, fn)
        self.event_listeners = self.event_listeners or {}
        self.event_listeners[name] = self.event_listeners[name] or {[self] = {}}
        table.insert(self.event_listeners[name][self], fn)
    end
    function inst:RemoveEventCallback() end
    function inst:PushEvent(name, data)
        self.events[name] = (self.events[name] or 0) + 1
        return EntityScript.PushEvent(self, name, data)
    end
    inst.PushEvent_Internal = EntityScript.PushEvent_Internal
    function inst:DoPeriodicTask(period, fn, delay, ...)
        local task = {period = period, delay = delay, args = {...}, fn = fn, Cancel = function(self) self.cancelled = true end}
        self.tasks[#self.tasks + 1] = task; return task
    end
    function inst:GetPosition() return {Get = function() return self.x, 0, self.z end} end
    inst.entity = setmetatable({IsAwake = function() return inst.awake end, IsVisible = function() return true end}, {__index = function() return noop end})
    inst.Transform = {GetWorldPosition = function() return inst.x, 0, inst.z end,
        SetPosition = function(_, x, _, z) inst.x, inst.z = x, z end}
    inst.AnimState = setmetatable({PlayAnimation = function(_, name) inst.animation = name end}, {__index = function() return noop end})
    inst.SoundEmitter = {PlaySound = function(_, sound) inst.lastsound = sound end}
    inst.MiniMapEntity = {SetIcon = noop}
    function inst:AddComponent(name)
        if name == "trap" then
            self.components.trap = Trap(self)
            if shadowhook then shadowhook(self.components.trap) end
        elseif name == "finiteuses" then self.components.finiteuses = FiniteUses(self)
        elseif name == "timer" then
            self.components.timer = {timers = {}, StartTimer = function(t, key, time) t.timers[key] = time end,
                StopTimer = function(t, key) t.timers[key] = nil end, GetTimeElapsed = function(t) return t.elapsed or 0 end}
        else self.components[name] = {canbepickedup = true, RemoveFromOwner = noop} end
    end
    function inst:SetStateGraph(name)
        check(name == "SGtrap", "real native prefab selects shared graph")
        self.sg = StateGraphInstance(graph, self)
        SGManager:SendToList(self.sg, SGManager.updaters)
        self.sg:GoToState(graph.defaultstate)
    end
    return inst
end
function CreateEntity() return entity("trap") end
Asset, MakeInventoryPhysics, MakeInventoryFloatable, MakeHauntableLaunch = noop, noop, noop, noop
function Prefab(_, fn) return fn end
local nativefactory = assert(loadstring(native_prefab))()
function SpawnPrefab(name)
    local loot = entity(name)
    loot.restoredatafromtrap = function(self, data) self.restored = data end
    loot.components.perishable = {LongUpdate = function(_, dt) loot.aged = dt end}
    spawned[#spawned + 1] = loot; return loot
end
TheSim = {FindEntities = function(_, x, y, z, radius, must, cant, oneof)
    local found = {}
    for _, ent in ipairs(live) do
        local match = ent.valid and (ent.x - x)^2 + (ent.z - z)^2 <= radius^2
        for _, tag in ipairs(must or {}) do match = match and ent:HasTag(tag) end
        for _, tag in ipairs(cant or {}) do match = match and not ent:HasTag(tag) end
        if oneof then local any = false; for _, tag in ipairs(oneof) do any = any or ent:HasTag(tag) end; match = match and any end
        if match then found[#found + 1] = ent end
    end
    return found
end}
local function install(enabled, shadow)
    live, spawned, stats = {}, {}, {}
    graphhook, prefabhook, shadowhook = nil, nil, nil
    GetModConfigData = function() return enabled end
    graph = assert(loadstring(native_graph))()
    assert(loadstring(patch_source))()
    if graphhook then graphhook(graph) end
    if shadow then assert(loadstring(shadow_source))() end
end
local function trap(awake, kind)
    local inst = nativefactory()
    inst.prefab, inst.awake = kind or "trap", awake ~= false
    if inst.prefab == "trap" then prefabhook(inst) end
    if TheWorld.ismastersim then inst:PushEvent("ondropped"); inst.sg:HandleEvents() end
    return inst, inst.components.trap
end
local function animal(name, inventory, trappable)
    local inst = entity(name)
    inst:AddTag("canbetrapped"); inst.soul = true
    inst.components.health = {IsDead = function() return inst.dead == true end}
    inst.components.lootdropper = {trappable = trappable ~= false, GenerateLoot = function() return {name .. "_loot"} end}
    if inventory then inst.components.inventoryitem = {trappable = trappable ~= false} end
    inst.settrapdata = function() return {beardling = true, marker = 42} end
    live[#live + 1] = inst; return inst
end
local function close(inst) inst:PushEvent("animover"); inst.sg:HandleEvents() end
local function trigger(component, target) component:DoTriggerOn(target); component.inst.sg:HandleEvents() end
local function harvest(component) component:Harvest(); component.inst.sg:HandleEvents() end

-- Native baseline: delay is real; simply leaving the radius does NOT cause a miss.
install(false)
local box, component = trap()
local rabbit = animal("rabbit", true)
component:OnUpdate(.75)
box.sg:HandleEvents()
check(rabbit.valid and not component:HasLoot() and box.animation == "trap_pre", "native capture waits for closing animation")
rabbit.x = 100; close(box)
check(not rabbit.valid and component.lootprefabs[1] == "rabbit", "native target remains catchable outside radius")
box, component = trap(); rabbit = animal("rabbit", true); trigger(component, rabbit); rabbit.dead = true; close(box)
check(not component:HasLoot(), "native delay permits target death and an empty trap")

for _, shadow in ipairs({false, true}) do
    for _, awake in ipairs({false, true}) do
        for _, species in ipairs({"rabbit", "frog", "spider"}) do
            install(true, shadow)
            box, component = trap(awake)
            local target = animal(species, species == "rabbit")
            component:OnUpdate(.75)
            box.sg:HandleEvents()
            check(not target.valid and target.removed == 1, "target captured at trigger time: " .. species)
            check(component.lootprefabs[1] == (species == "rabbit" and species or species .. "_loot"), "native live-item/loot selection")
            check(target.events.trapped == 1 and target.events.ontrapped == 1, "native catch events delivered once")
            check(stats["trapped_" .. species] == 1, "native statistics once")
            check(component.range == 1.5 and component.checkperiod == .75, "range and polling unchanged")
            check(box.components.finiteuses:GetUses() == 8, "capture does not prematurely consume durability")
            check(box.components.timer.timers.foodspoil == 960, "native starvation starts")
            check(species == "rabbit" and component.starvednumsouls == 1 or species ~= "rabbit" and component.numsouls == 1,
                "native soul accounting retained")
            if awake then check(box.animation == "trap_pre" and not box.components.inventoryitem.canbepickedup, "closing animation retained") end
            close(box); component:DoSpring()
            check(component:HasLoot() and target.removed == 1, "animation and repeated spring cannot erase or duplicate catch")
            check(box.sg.currentstate.name == "full" and box.components.inventoryitem.canbepickedup, "native full state unlocks pickup")
            harvest(component)
            check(#spawned == 1 and spawned[1].prefab == (species == "rabbit" and species or species .. "_loot"), "native harvest emits one reward")
            if species == "rabbit" then check(spawned[1].restored.marker == 42, "native special rabbit save data retained") end
            check(box.components.finiteuses:GetUses() == 7 and component.isset and box.sg.currentstate.name == "idle", "native harvest consumes one use and rearms")
        end
    end
end

install(true)
box, component = trap(); rabbit = animal("rabbit", true); trigger(component, rabbit)
harvest(component) -- auto-collection while trap_pre is still playing
check(#spawned == 1 and component.isset and box.sg.currentstate.name == "idle", "early harvest finishes close before rearming")
close(box); check(component.isset and not component.issprung, "stale animation completion cannot spring the rearmed trap")
local frog = animal("frog", false); trigger(component, frog); close(box); harvest(component)
check(#spawned == 2 and box.components.finiteuses:GetUses() == 6, "next catch after early harvest works")

install(true)
local first, c1 = trap(); local second, c2 = trap(); rabbit = animal("rabbit", true)
c1:DoTriggerOn(rabbit); c2:DoTriggerOn(rabbit)
first.sg:HandleEvents(); second.sg:HandleEvents()
check(c1:HasLoot() and not c2:HasLoot() and rabbit.removed == 1, "same-frame traps cannot duplicate an animal")
check(c1.DoTriggerOn == Trap.DoTriggerOn, "native trigger selection and event delivery are unchanged")
local data = c1:OnSave() -- saved before the close animation has ended
local restored, rc = trap(); rc:OnLoad(data); restored.sg:HandleEvents()
check(rc.lootprefabs[1] == "rabbit" and restored.sg.currentstate.name == "full", "native save/load keeps early-captured loot")
harvest(rc); check(#spawned == 1, "restored capture harvests normally")

install(true)
box, component = trap(); rabbit = animal("rabbit", true)
local bait = entity("carrot"); bait.components.bait = {}; component:SetBait(bait)
component:BaitTaken(rabbit); box.sg:HandleEvents(); close(box)
check(bait.removed == 1 and component.bait == nil and component:HasLoot(), "native bait path consumes bait once")
component:OnTrappedStarve()
check(not component:HasLoot() and box.sg.currentstate.name == "empty" and spawned[1].prefab == "rabbit_loot", "native starvation and drops preserved")

install(true)
box, component = trap(); rabbit = animal("rabbit", true)
rabbit.components.perishable = {perishremainingtime = 123}
component:DoTriggerOn(rabbit)
check(rabbit.valid and #box.sg.bufferedevents > 0, "test uses native queued events, not synchronous fake dispatch")
box.sg:HandleEvents()
check(not rabbit.valid and box.components.timer.timers.foodspoil == 123, "capture at close-state entry retains remaining freshness")
component:Harvest(); component:Harvest(); box.sg:HandleEvents()
check(#spawned == 1 and box.components.finiteuses:GetUses() == 7, "two collectors in one tick only receive one reward")
for i = 2, 8 do
    trigger(component, animal("rabbit", true)); close(box); harvest(component)
end
check(#spawned == 8 and not box.valid and box.components.finiteuses:GetUses() == 0, "all eight native uses and final-use destruction preserved")

install(false)
box, component = trap()
check(component.DoSpring == Trap.DoSpring and component.Harvest == Trap.Harvest and not box.trapguaranteed2hm,
    "disabled option leaves native methods untouched")
component:OnLoad(data); box.sg:HandleEvents()
check(component.lootprefabs[1] == "rabbit" and box.sg.currentstate.name == "full", "captured save remains usable after feature is disabled")

install(true, true)
box, component = trap(); local clone = animal("spider", false); clone:AddTag("swc2hm")
trigger(component, clone); close(box)
check(clone.valid and not component:HasLoot(), "existing shadow-clone immunity remains authoritative")
install(true)
box, component = trap(); local mole = animal("mole", true, false)
trigger(component, mole); close(box)
check(mole.valid and not component:HasLoot() and mole.events.safelydisarmedtrap == 1, "native nontrappable mole is not forcibly captured")

for _, kind in ipairs({"dead", "INLIMBO", "untrappable", "outside", "wrongtag"}) do
    install(true); box, component = trap(); rabbit = animal("rabbit", true)
    if kind == "dead" then rabbit.dead = true elseif kind == "outside" then rabbit.x = 2
    elseif kind == "wrongtag" then rabbit:RemoveTag("canbetrapped") else rabbit:AddTag(kind) end
    component:OnUpdate(.75)
    check(rabbit.valid and component.isset and not component:HasLoot(), "native eligibility preserved: " .. kind)
end
install(true)
box, component = trap(); component:Reset(); rabbit = animal("rabbit", true); component:OnUpdate(.75)
check(rabbit.valid and not component:HasLoot(), "carried or reset trap cannot capture")
box, component = trap(true, "birdtrap"); rabbit = animal("bird", true); trigger(component, rabbit)
check(rabbit.valid and component.DoSpring == Trap.DoSpring, "shared graph leaves bird traps unchanged")
close(box); check(not rabbit.valid, "bird trap retains native animation-timed capture")

install(true); TheWorld.ismastersim = false
box, component = trap()
check(component == nil and not box.trapguaranteed2hm, "clients do not run capture authority")
TheWorld.ismastersim = true
for _, localevalue in ipairs({"zh", "en"}) do
    local env = setmetatable({locale = localevalue}, {__index = _G})
    local fn = assert(loadstring(info_source)); setfenv(fn, env); fn()
    local found
    for _, option in ipairs(env.configuration_options) do if option.name == "Trap Guaranteed Catch" then found = option end end
    check(found and found.default == true, "new gameplay option defaults on")
    local off = false; for _, option in ipairs(found.options) do off = off or option.data == false end
    check(off, "new gameplay option can be disabled")
end
print("Trap catch: " .. checks .. " assertions passed (real DST trap/prefab/stategraph/finite uses; simulated entities)")
