GLOBAL, env = _G, _G
local checks = 0
local function check(value, message) checks = checks + 1; assert(value, message) end
assert(loadstring(class_source))()
EntityScript = {is_instance = function() return false end}
local loaded = {}
function require(name)
    if name == "tools/um_upvaluehacker" then return {} end
    if not loaded[name] then
        local source = ({umcompatguard2hm = guard_source, umcompatprofiles2hm = profiles_source,
            ["util/sourcemodifierlist"] = modifier_source})[name]
        loaded[name] = assert(loadstring(source))()
    end
    return loaded[name]
end
local Work = assert(loadstring(work_source))()
local Efficient = assert(loadstring(efficient_source))()
local Repair = assert(loadstring(repair_source))()
local Builder = assert(loadstring(builder_source))()
ACTIONS = {}
for _, name in ipairs({"BUILD", "CHOP", "MINE", "HAMMER", "ROW", "DIG", "ATTACK", "PICK", "TILL", "REMOVELUNARBUILDUP"}) do ACTIONS[name] = {id = name} end
TheWorld = {ismastersim = true}
TUNING = {HUNGRY_THRESH = 0.2, UM_COMPAT_STATUS2HM = {}}
function GetValidRecipe(name) return name == "custom" and {sg_state = "dohungrybuild"} or nil end
local um_post, patch_post, local_post, sg
function AddPrefabPostInit(name, fn) um_post = fn end
local function Build(inst, action)
    return action.recipe == "custom" and "dohungrybuild" or inst:HasTag("hungrybuilder") and "dohungrybuild"
        or inst:HasTag("fastbuilder") and "domediumaction" or "dolongaction"
end
local function Fixture(source, config, patch, enhance, nohungry)
    UM_CONFIG = config or {WINONAWORKER = true}
    TUNING.UM_COMPAT_STATUS2HM = {}
    sg = {actionhandlers = {[ACTIONS.PICK] = {deststate = function() return "dolongaction" end}, [ACTIONS.BUILD] = {deststate = Build}}}
    assert(loadstring(source or worker_source, "@../mods/workshop-3193922031/init/init_character_changes/winona.lua"))()
    local_post, patch_post = nil, nil
    if enhance ~= false then
        Builder.Install({GLOBAL = _G, AddPrefabPostInit = function(_, fn) local_post = fn end,
            AddStategraphPostInit = function(name, fn)
                if name == "wilson" then fn(sg) else
                    local client = {actionhandlers = {[ACTIONS.BUILD] = {deststate = Build}}}
                    fn(client); sg.client = client
                end
            end}, nohungry ~= false)
    end
    if patch ~= false then Repair.Install({GLOBAL = _G, AddPrefabPostInit = function(_, fn) patch_post = fn end}) end
end
local function Spawn()
    local inst = {prefab = "winona", tags = {hungrybuilder = true, fastbuilder = true}, components = {}, event_listeners = {}, sg = {sg = sg}}
    function inst:AddTag(tag) self.tags[tag] = true end
    function inst:RemoveTag(tag) self.tags[tag] = nil end
    function inst:HasTag(tag) return self.tags[tag] == true end
    function inst:ListenForEvent(event, fn)
        self.event_listeners[event] = self.event_listeners[event] or {[self] = {}}
        table.insert(self.event_listeners[event][self], fn)
    end
    function inst:RemoveEventCallback(event, fn)
        local list = self.event_listeners[event] and self.event_listeners[event][self] or {}
        for i = #list, 1, -1 do if list[i] == fn then table.remove(list, i) end end
    end
    function inst:PushEvent(event, data)
        local copy = {}
        for i, fn in ipairs(self.event_listeners[event] and self.event_listeners[event][self] or {}) do copy[i] = fn end
        for _, fn in ipairs(copy) do fn(self, data) end
    end
    inst.components.workmultiplier, inst.components.efficientuser = Work(inst), Efficient(inst)
    inst.components.hunger = {percent = 1, GetPercent = function(self) return self.percent end}
    um_post(inst)
    local originalpick = sg.actionhandlers[ACTIONS.PICK].deststate
    if local_post then local_post(inst) end
    if patch_post then patch_post(inst) end
    check(sg.actionhandlers[ACTIONS.PICK].deststate == originalpick, "native UM picker is never replaced")
    return inst
end
Fixture()
local inst = Spawn()
check(inst.umworkerpatched2hm, "known upstream lifecycle repaired")
check(inst.components.workmultiplier:GetMultiplier(ACTIONS.CHOP) == 1.5, "local initialization restores work")
check(inst.components.efficientuser:GetMultiplier(ACTIONS.CHOP) == 0.5, "initial tool efficiency")
check(inst:HasTag("hungrybuilder") and sg.actionhandlers[ACTIONS.PICK].deststate(inst, {}) == "dohungrybuild", "native gathering tag preserved")
check(sg.actionhandlers[ACTIONS.BUILD].deststate(inst, {recipe = "axe"}) == "domediumaction", "only normal crafting ignores hunger")
check(sg.client.actionhandlers[ACTIONS.BUILD].deststate(inst, {recipe = "axe"}) == "domediumaction", "client crafting agrees")
check(sg.actionhandlers[ACTIONS.BUILD].deststate(inst, {recipe = "custom"}) == "dohungrybuild", "custom recipe state preserved")
inst.prefab = "wilson"
check(sg.actionhandlers[ACTIONS.BUILD].deststate(inst, {recipe = "axe"}) == "dohungrybuild", "other characters unchanged")
inst.prefab = "winona"
inst.components.workmultiplier:AddMultiplier(ACTIONS.CHOP, 2, "other_mod")
inst:PushEvent("ms_becameghost")
check(inst.components.workmultiplier:GetMultiplier(ACTIONS.CHOP) == 2, "death preserves unrelated modifiers")
for i = 1, 5 do
    inst:PushEvent("ms_respawnedfromghost")
    check(#inst.event_listeners.performaction[inst] == 1, "revive has one drain " .. i)
    check(inst.components.workmultiplier:GetMultiplier(ACTIONS.CHOP) == 3, "revive has one UM multiplier " .. i)
    inst:PushEvent("ms_becameghost")
end
Fixture(nil, nil, false)
local withoutpatch = Spawn()
check(not withoutpatch.umworkerpatched2hm and withoutpatch.winonaworkerinitialized2hm, "local fixes independent of um_patch")
check(withoutpatch.components.workmultiplier:GetMultiplier(ACTIONS.CHOP) == 1.5, "patch-off retains initialized work")
check(sg.actionhandlers[ACTIONS.PICK].deststate(withoutpatch, {}) == "dohungrybuild", "patch-off retains native gathering")
Fixture(nil, nil, true, false)
local withoutenhance = Spawn()
check(withoutenhance.components.workmultiplier:GetMultiplier(ACTIONS.CHOP) == 1, "upstream patch does not initialize local enhancement")
check(withoutenhance.umworkerpatched2hm and not withoutenhance.winonaworkerinitialized2hm, "upstream patch only owns lifecycle")
local changed = worker_source:gsub('AddMultiplier%(v, 1%.5, "ohungy"%)', 'AddMultiplier(v, 1.6, "ohungy")')
Fixture(changed)
local future = Spawn()
check(not future.umworkerpatched2hm and not future.winonaworkerinitialized2hm, "unknown future update is not called or replaced")
future.event_listeners.hungerdelta[future][1](future)
check(future.components.workmultiplier:GetMultiplier(ACTIONS.CHOP) == 1.6, "future balance preserved")
local fixed = worker_source:gsub('        local _PickActionOld', '        onhungerchange(inst, nil)\n        local _PickActionOld', 1)
fixed = fixed:gsub('local function onbecamehuman%(inst, data%)',
    'local function onbecamehuman(inst, data)\n        inst:RemoveEventCallback("performaction", ActionHungerDrain)\n        inst:RemoveEventCallback("hungerdelta", onhungerchange)', 1)
fixed = fixed:gsub('local function onbecameghost%(inst, data%)%s+inst:ListenForEvent%("performaction", ActionHungerDrain%)',
    'local function onbecameghost(inst, data)\n        inst:RemoveEventCallback("performaction", ActionHungerDrain)', 1)
Fixture(fixed)
local complete = Spawn()
check(not complete.umworkerpatched2hm and not complete.winonaworkerinitialized2hm, "upstream self-fix retires lifecycle and initialization")
check(complete.components.workmultiplier:GetMultiplier(ACTIONS.CHOP) == 1.5 and #complete.event_listeners.performaction[complete] == 1, "self-fixed upstream not duplicated")
Fixture(nil, {WINONAWORKER = false})
local disabled = Spawn()
check(disabled:HasTag("hungrybuilder") and not disabled.umworkerpatched2hm, "disabled worker retains native character tag")
check(sg.actionhandlers[ACTIONS.BUILD].deststate(disabled, {recipe = "axe"}) == "domediumaction", "crafting enhancement works without UM worker")
check(patch_post == nil, "disabled upstream worker does not install patch")
print("Winona builder/lifecycle separation:", checks, "checks passed")
