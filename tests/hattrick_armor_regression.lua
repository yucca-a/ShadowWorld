local count = 0
local function check(ok, message)
    count = count + 1
    assert(ok, message)
end
local function load(source) return assert(loadstring(source))() end
math.clamp = function(value, low, high) return math.max(low, math.min(value, high)) end
package.preload["util/sourcemodifierlist"] = function() return load(modifiers_source) end
local Armor = load(armor_source)
local Hat = load(component_source)
EQUIPSLOTS = {HEAD = "head"}
GLOBAL = _G
TUNING = {NoFreezePercent = .8, NoFireAndScarePercent = .9, HatReduceRate = {armor = .1}, HatTrickDropRate = .05}

local function entity()
    local inst = {components = {}, events = {}, tags = {}, tasks = {}}
    function inst:IsValid() return not self.removed end
    function inst:AddTag(tag) self.tags[tag] = true end
    function inst:RemoveTag(tag) self.tags[tag] = nil end
    function inst:ListenForEvent(event, fn, source)
        source = source or self
        source.events[event] = source.events[event] or {}
        table.insert(source.events[event], {listener = self, fn = fn})
    end
    function inst:RemoveEventCallback(event, fn, source)
        local callbacks = (source or self).events[event] or {}
        for i = #callbacks, 1, -1 do
            if callbacks[i].listener == self and callbacks[i].fn == fn then table.remove(callbacks, i) end
        end
    end
    function inst:PushEvent(event, data)
        for _, callback in ipairs(self.events[event] or {}) do callback.fn(callback.listener, data) end
    end
    function inst:DoTaskInTime(_, fn) table.insert(self.tasks, fn) end
    function inst:DoPeriodicTask(_, fn) self.periodic = fn end
    function inst:RunTasks()
        local tasks = self.tasks
        self.tasks = {}
        for _, fn in ipairs(tasks) do fn(self) end
    end
    function inst:Remove() self:PushEvent("onremove"); self.removed = true end
    return inst
end

local armorhook, prefabhook
env = {
    AddComponentPostInit = function(name, fn) assert(name == "armor"); armorhook = fn end,
    AddPrefabPostInitAny = function(fn) prefabhook = fn end,
}
load(rework_source)

local function hat(prefab, absorption, rework)
    local inst = entity()
    local armor = Armor(inst)
    inst.components.armor = armor
    if rework then armorhook(armor) end
    -- Native SpawnPrefab assigns prefab after construction, before post-init-any.
    armor:InitCondition(100, absorption)
    inst.prefab = prefab
    if rework then prefabhook(inst) end
    return inst
end

local function follower()
    local inst = entity()
    inst.components.inventory = {GetEquippedItem = function() return inst.head end}
    for _, spec in ipairs({{"freezable", "Freeze"}, {"sleeper", "GoToSleep"}, {"health", "DoFireDamage"}}) do
        inst.components[spec[1]] = {inst = inst, calls = 0, [spec[2]] = function(self, ...)
            self.calls = self.calls + 1
            self.args = {...}
            return "original"
        end}
    end
    return inst
end

local function effects(inst, freeze, fire, label)
    for _, spec in ipairs({{"freezable", "Freeze", freeze}, {"sleeper", "GoToSleep", freeze}, {"health", "DoFireDamage", fire}}) do
        local component = inst.components[spec[1]]
        local before = component.calls
        local result = component[spec[2]](component, 7, "source", true)
        check(component.calls == before + (spec[3] and 0 or 1), label .. ": " .. spec[2])
        if not spec[3] then
            check(result == "original" and component.args[1] == 7, label .. ": forwards original method")
        end
    end
    check((inst.tags.noscare2hm == true) == fire, label .. ": scare immunity")
end

local function equip(inst, prefab, absorption, rework)
    local original = hat(prefab, absorption, rework)
    local copy = hat(prefab, absorption, rework)
    inst.head = copy
    local component = Hat(copy)
    copy.components.removeleaveinventory2hm = component
    local parent = entity()
    component:SetOwner(inst, parent, original)
    check(copy.components.armor.absorb_percent == original.components.armor.absorb_percent, "immunity does not change armor absorption")
    return copy, original
end

for _, mode in ipairs({"solo", "stable", "beta-off", "beta-on"}) do
    TUNING.DSTU = mode ~= "solo" and {} or nil
    local rework = mode == "beta-on"
    for _, case in ipairs({
        {"footballhat", .8, .65, true, false},
        {"ruinshat", .9, .75, true, true},
        {"customhat", .7, .6, false, false},
        {"customhat", .85, .7, true, false},
        {"customhat", .95, .8, true, true},
        {"wathgrithrhat", .8, .65, true, false},
        {"cookiecutterhat", .8, .7, true, false},
    }) do
        local inst = follower()
        local copy, original = equip(inst, case[1], case[2], rework)
        local expected = rework and case[3] or case[2]
        check(copy.components.armor.absorb_percent == expected, mode .. ": actual upstream armor value")
        local freeze = rework and case[4] or case[2] >= .8
        local fire = rework and case[5] or (not rework and case[2] >= .9)
        effects(inst, freeze, fire, mode .. ": " .. case[1])
        copy.components.armor:TakeDamage(10)
        copy.periodic(copy)
        check(original.components.armor.condition == 99 and copy.components.armor.condition == 100, "shared armor wear stays at 10%")
        inst.head = nil
        inst:PushEvent("unequip", {eslot = EQUIPSLOTS.HEAD})
        copy:RunTasks()
        check(copy.removed, "unequipping removes the copied hat")
        effects(inst, false, false, mode .. ": removed hat")
        -- The same follower can receive a weaker replacement without old immunity leaking.
        local replacement = equip(inst, "customhat", .6, rework)
        effects(inst, false, false, mode .. ": weaker replacement")
        replacement:Remove()
    end
end

for _, case in ipairs({{.64999, false, false}, {.65, true, false}, {.74999, true, false}, {.75, true, true}}) do
    local inst = follower()
    local original, copy = hat("customhat", .8, true), hat("customhat", .8, true)
    original.components.armor:UMOverrideAbsorption(case[1])
    copy.components.armor:UMOverrideAbsorption(case[1])
    inst.head = copy
    Hat(copy):SetOwner(inst, entity(), original)
    effects(inst, case[2], case[3], "reworked boundary " .. case[1])
    check(copy.components.armor.absorb_percent == case[1], "boundary checks never modify absorption")
    copy:Remove()
    effects(inst, false, false, "boundary removal")
end

-- A similarly named field alone must not activate the compatibility branch.
for _, marker in ipairs({"umabsorbremap", "UMOverrideAbsorption"}) do
    local inst = follower()
    local original, copy = hat("customhat", .75, false), hat("customhat", .75, false)
    copy.components.armor[marker] = marker == "umabsorbremap" and .75 or function() end
    inst.head = copy
    Hat(copy):SetOwner(inst, entity(), original)
    effects(inst, false, false, "partial marker")
end
check(TUNING.NoFreezePercent == .8 and TUNING.NoFireAndScarePercent == .9, "global thresholds remain unchanged")
print("Hat trick / native armor + UM beta rework: " .. count .. " checks passed")
