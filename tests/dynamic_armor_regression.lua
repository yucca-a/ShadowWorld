local assertions = 0
local function equal(actual, expected, label)
    assertions = assertions + 1
    assert(actual == expected, (label or "equal") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function near(actual, expected, label, epsilon)
    assertions = assertions + 1
    assert(math.abs(actual - expected) <= (epsilon or 1e-7),
        (label or "near") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
function math.clamp(v, lo, hi) return math.max(lo, math.min(v, hi)) end
FRAMES = 1 / 30
TWOPI = 2 * math.pi
Health = {}
assert(loadstring(health_source))()
TUNING = {isCh2hm = true, EXPLOSIVE_MAX_RESIST_DAMAGE = 8000, EXPLOSIVE_RESIST_DECAY_TIME = 8,
    EXPLOSIVE_RESIST_DECAY_DELAY = 2, EXPLOSIVE_MAX_WORKABLE_INVENTORYITEMS = 100}
package.preload["components/spdamageutil"] = function() return {CollectSpDamage = function() return nil end} end
local Explosive = assert(loadstring(explosive_source))()
local ExplosiveResist = assert(loadstring(explosiveresist_source))()
local DynamicArmor = assert(loadstring(component_source))()
local phase1 = assert(loadstring(phase1_source))()
local phase2 = assert(loadstring(phase2_source))()
AllPlayers = {}
CanEntityBecomeCorpse = function() return false end
NotifyPlayerProgress = function() end
CanEntitySeeTarget = function(viewer) return not viewer.blind end
TheSim = {FindEntities = function() return {} end}
TheWorld = {ismastersim = true, components = {}, PushEvent = function() end}
local clock, jobs, hooks, config, prefabhooks, entities
function GetTime() return clock end
local ModeConfig=assert(loadstring(modeconfig_source))()
GetModConfigData=ModeConfig.Wrap(function(name) return config[name] end)
function AddComponentPostInit(name, fn) hooks[name] = fn end
function AddPrefabPostInitAny(fn) hooks.any = fn end
function AddPrefabPostInit(name, fn) prefabhooks[name] = fn end
local function advance(seconds)
    local target = clock + seconds
    while true do
        local nextjob
        for _, job in ipairs(jobs) do
            if not job.cancelled and job.at <= target + 1e-10 and (nextjob == nil or job.at < nextjob.at) then nextjob = job end
        end
        if nextjob == nil then break end
        clock = nextjob.at
        if nextjob.period then nextjob.at = nextjob.at + nextjob.period else nextjob.cancelled = true end
        if nextjob.inst:IsValid() then nextjob.fn(nextjob.inst) end
    end
    clock = target
end
local function install(mult, extra)
    clock = 0; jobs = {}; hooks = {}; prefabhooks = {}; entities = {}
    config = {boss_health = mult, extra_change = extra ~= false, epic_armor_5 = "dynamic"}
    PrefabFiles={}
    TheWorld.ismastersim = true
    assert(loadstring(integration_source))()
end
local function entity(prefab, tags)
    local inst = {prefab = prefab, tags = tags or {}, components = {}, events = {}, valid = true, entity = {SetParent = function() end}}
    function inst:HasTag(tag) return self.tags[tag] or false end
    function inst:HasAnyTag(tags) for _, tag in ipairs(tags) do if self:HasTag(tag) then return true end end return false end
    function inst:AddTag(tag) self.tags[tag] = true end
    function inst:IsValid() return self.valid end
    function inst:IsInLimbo() return false end
    function inst:IsAsleep() return self.asleep or false end
    function inst:GetPhysicsRadius() return 1 end
    function inst:GetPosition() return {x = 0, y = 0, z = 0} end
    function inst:StartUpdatingComponent() end
    function inst:StopUpdatingComponent() end
    function inst:Remove()
        self.valid = false
        for _, component in pairs(self.components) do
            if component.OnRemoveEntity then component:OnRemoveEntity() end
        end
    end
    function inst:ListenForEvent(name, fn)
        self.events[name] = self.events[name] or {}
        table.insert(self.events[name], fn)
    end
    function inst:PushEvent(name, data)
        if name == "healthdelta" then self.lastdelta = data.amount end
        for _, fn in ipairs(self.events[name] or {}) do fn(self, data) end
    end
    function inst:DoTaskInTime(delay, fn)
        local job = {at = clock + delay, inst = self, fn = fn, Cancel = function(self) self.cancelled = true end}
        table.insert(jobs, job)
        return job
    end
    function inst:DoPeriodicTask(period, fn)
        local job = self:DoTaskInTime(period, fn); job.period = period; return job
    end
    function inst:AddComponent(name)
        if name == "dynamicarmor2hm" then self.components[name] = DynamicArmor(self)
        else error("unsupported component " .. name) end
    end
    inst.Transform = {GetWorldPosition = function() return 0, 0, 0 end, GetRotation = function() return 0 end,
        SetPosition = function() end, SetRotation = function() end, SetScale = function() end}
    inst.AnimState = {MakeFacingDirty = function() end, SetMultColour = function(_, r, g, b, a) inst.alpha = a end}
    inst.SoundEmitter = {KillSound = function() end, PlaySound = function() end}
    inst.sg = {GoToState = function() end}
    return inst
end
local function boss(prefab, maximum, tags)
    local inst = entity(prefab or "testboss", tags or {epic = true})
    local h = setmetatable({inst = inst, maxhealth = maximum or 10000, currenthealth = maximum or 10000,
        minhealth = 0, penalty = 0, nonlethal_pct = 0, playerabsorb = 0, absorb = 0, nofadeout = true,
        externalabsorbmodifiers = {Get = function() return 0 end},
        externalreductionmodifiers = {Get = function() return 0 end}}, {__index = Health})
    function h:GetPercent() return self.currenthealth / self.maxhealth end
    function h:IsInvincible() return self.invincible or false end
    function h:ForceUpdateHUD() end
    inst.components.health = h
    if hooks.health then hooks.health(h) end
    inst.components.combat = {SuggestTarget = function() end, CanBeAttacked = function() return true end,
        GetAttacked = function(_, attacker, damage) return h:DoDelta(-damage, false, "attack", false, attacker) end,
        GetAttacked_Internal = function(_, attacker, damage) return h:DoDelta(-damage, false, "attack", false, attacker) end}
    local timer = {values = {}}
    function timer:TimerExists(name) return self.values[name] ~= nil end
    function timer:StopTimer(name) self.values[name] = nil end
    function timer:StartTimer(name, time)
        self.values[name] = time
        inst:DoTaskInTime(time, function() self.values[name] = nil; inst:PushEvent("timerdone", {name = name}) end)
    end
    inst.components.timer = timer
    local inspectable = {inst = inst, GetDescription = function() return "boss", "filter", "author" end}
    inst.components.inspectable = inspectable
    if hooks.inspectable then hooks.inspectable(inspectable) end
    if prefab == "alterguardian_phase1" then inst:ListenForEvent("phasetransition", phase1)
    elseif prefab == "alterguardian_phase2" then inst:ListenForEvent("phasetransition", phase2) end
    if prefabhooks[inst.prefab] then prefabhooks[inst.prefab](inst) end
    if hooks.any then hooks.any(inst) end
    table.insert(entities, inst)
    return inst, h, inst.components.dynamicarmor2hm
end
function SpawnPrefab(prefab)
    if prefab == "forcefieldfx" then return entity(prefab) end
    if prefab == "dynamicarmor_indicator2hm" then
        local fx=entity(prefab)
        function fx:SetTarget(target)self.target=target end
        function fx:SetResistance(value)self.resistance=value end
        return fx
    end
    return boss(prefab, prefab == "alterguardian_phase2" and 20000 or 30000)
end
local player = entity("wilson", {player = true})
local function hit(h, damage, source) return h:DoDelta(-damage, false, "test", false, source) end

-- Configuration keeps saved false/numeric values and routes dynamic separately.
locale = "zh"
assert(loadstring(config_source))()
local option
for _, opt in ipairs(configuration_options) do if opt.name == "epic_armor_5" then option = opt end end
equal(option.default, "dynamic", "dynamic default")
local values = {}
for _, opt in ipairs(option.options) do values[opt.data] = true end
equal(values[false], true)
equal(values.traditional_1,true)
for i = 2, 5 do equal(values[i], true) end
equal(values.dynamic, true)
for _, mode in ipairs({false, 1, "traditional_1", 2, 3, 4, 5, "dynamic"}) do
    install(1)
    config.epic_armor_5 = mode
    local imported
    modimport = function(path) imported = path end
    assert(loadstring(routing_source))()
    equal(imported, (mode == "dynamic"or mode==1) and "epic/dynamic_armor.lua" or mode and "epic/epic_armor.lua" or nil, "exclusive routing")
end

-- Native gunpowder stack -> native explosion resistance -> native health pipeline.
for _, row in ipairs({{1, 200}, {5, 1000}, {10, 1000}, {20, 1000}, {40, 1000}}) do
    install(1)
    local inst, h, armor = boss()
    inst.components.explosiveresist = ExplosiveResist(inst)
    local powder = entity("gunpowder", {explosive = true})
    powder.components.stackable = {StackSize = function() return row[1] end}
    local explosive = Explosive(powder)
    explosive:OnBurnt(inst)
    near(10000 - h.currenthealth, row[2], "gunpowder " .. row[1])
    near(armor.pressure * 10000, row[2], "actual pressure")
    near(inst.lastdelta, -row[2], "event reports actual damage")
    near(inst.components.explosiveresist:GetResistance(), math.min(1, row[1] * 200 / 8000), "native resistance retained")
    equal(powder:IsValid(), false)
end

-- Partition invariance below the new per-hit cap. Splitting above it intentionally changes input.
for _, damage in ipairs({0.001, 200, 500, 1000}) do
    install(1)
    local a, ha, aa = boss(); local b, hb, ab = boss()
    hit(ha, damage, player)
    for i = 1, 100 do hit(hb, damage / 100, player) end
    near(ha.currenthealth, hb.currenthealth, "split invariant", 1e-6)
    near(aa.pressure, ab.pressure, "split pressure", 1e-9)
end

install(1)
local inst, h, armor = boss()
for i = 1, 8 do hit(h, 8000) end
near(armor.pressure, 0.29975212478233, "source-free damage counted")
near(h.currenthealth, 7002.4787521767)
equal(armor.fx.persists, false, "feedback FX never saved separately")
equal(armor.fx.prefab,"dynamicarmor_indicator2hm","dynamic mode no longer spawns a shield")
equal(armor.fx.target,inst,"subtle effect follows the actual boss")
local feedback=armor.fx
armor:UpdateFX()
equal(armor.fx,feedback,"continued hits reuse a single indicator")
local before = armor.pressure
h:DoDelta(1000)
near(armor.pressure, before, "healing does not erase pressure")
advance(3)
near(armor:Decay(), before - 0.10, "proportional cooling continues before the minimum starts")
advance(30)
near(armor.pressure, 0)
equal(armor.task, nil, "idle task stops")
equal(armor.fx, nil)

for _, row in ipairs({{1, true, 0.12}, {2, true, 0.1+.02/math.sqrt(2)}, {4, true, 0.11}, {8, true, 0.1+.02/math.sqrt(8)}, {4, false, 0.12}}) do
    install(row[1], row[2])
    inst, h, armor = boss(nil, 4000)
    for i = 1, 40 do hit(h, 1e6) end; advance(2)
    near(armor:Decay(), 0.3 - row[3], "configured decay floor")
end

-- Exercise both cooling branches, rather than only small bosses where the floor wins.
for _, row in ipairs({
    {10000,1,1,true,400}, {20000,1,1,true,400},
    {100000,1,1,true,2000}, {100000,4,1,true,1000},
    {100000,4,4,true,500}, {100000,1000000,1,true,400},
    {4000,4,1,true,400}, {100000,4,1,false,2000},
})do
    install(row[2],row[4])
    inst,h,armor=boss(nil,row[1])
    armor:SetExternalHealthMultiplier(row[3])
    armor:OnLoad({pressure=.3,externalhealthmult=row[3]})
    near(armor:GetDecayRate()*row[1],row[5],"cooling HP/sec follows max-health floor and multiplier")
    advance(1)
    near(armor:Decay(),.3-row[5]/row[1],"one second of native update cooling")
    local savedrate=armor:OnSave()
    armor:LongUpdate(1000)
    near(armor.pressure,0,"long update clamps pressure at zero")
    armor:OnLoad(savedrate)
    near(armor.pressure,savedrate.pressure,"save/load retains the new pressure without offline cooling")
end

install(1)
inst,h,armor=boss()
for _, row in ipairs({{.1,0},{.199,0},{.2,0},{.21,.1},{.25,.5},{.3,1},{.8,1}})do
    armor:OnLoad({pressure=row[1]})
    near(armor:GetResistance(),row[2],"new resistance threshold and limit")
end
armor:OnLoad({pressure=.199})
hit(h,10)
near(h.currenthealth,9990,"damage up to twenty percent pressure is unreduced")
near(armor:GetResistance(),0,"exact threshold remains unarmored")
hit(h,100)
near(9990-h.currenthealth,95.16258196404,"mitigation begins continuously above twenty percent")
-- Splitting a packet across the threshold or inside the resistance band must
-- not evade mitigation. No time advances between these native damage calls.
for _, pressure in ipairs({.195,.225})do
    for _, damage in ipairs({.001,200,1000})do
        install(1)
        local a,ha,aa=boss();local b,hb,ab=boss()
        aa:OnLoad({pressure=pressure});ab:OnLoad({pressure=pressure})
        hit(ha,damage)
        for i=1,100 do hit(hb,damage/100)end
        near(ha.currenthealth,hb.currenthealth,"split invariant across new resistance band",1e-6)
        near(aa.pressure,ab.pressure,"split pressure above new threshold",1e-9)
    end
end

install(4)
inst, h, armor = boss()
hit(h, 2000)
local saved = armor:OnSave()
local p = saved.pressure
advance(40)
local loaded, hl, al = boss()
al:OnLoad(saved); hl:OnLoad({health = 1000})
near(al.pressure, p, "load preserves pressure, no wall-clock decay")
near(hl.currenthealth, 1000, "load HP unarmored")
hl:SetMaxHealth(40000); hl:SetPercent(0.25)
near(al.pressure, p, "rescale keeps pressure ratio")
near(hl.currenthealth, 10000, "SetPercent is structural")
al:SetExternalHealthMultiplier(4)
near(al:GetHealthMultiplier(), 16)
advance(2); near(al:Decay(), p - 0.015)
local savedexternal = al:OnSave()
local _, _, copy = boss(nil,40000); copy:OnLoad(savedexternal)
near(copy:GetHealthMultiplier(), 16, "external multiplier saved")
local pre_skip = copy:Decay()
copy:LongUpdate(2)
near(copy.pressure, pre_skip - 0.02, "time skip cools once")
near(copy:Decay(), pre_skip - 0.02, "time skip not double counted")
copy:SetExternalHealthMultiplier(0 / 0); near(copy:GetHealthMultiplier(), 4, "invalid multiplier")
copy:OnLoad({pressure = math.huge, externalhealthmult = math.huge}); near(copy.pressure, 0)

-- Normal melee cadence must accumulate pressure rather than having each hit
-- erased by the 400 HP/sec floor before the next one arrives.
install(1)
inst,h,armor=boss(nil,6000)
for i=1,12 do hit(h,200);advance(.5)end
equal(armor:GetResistance()>0,true,"200 damage every half second triggers resistance")
equal(h.currenthealth>3600,true,"sustained melee receives actual mitigation")
local retained=armor.pressure
advance(.49)
near(armor:Decay(),retained-.49*.02,"proportional cooling remains active during the grace interval")
advance(.51)
near(armor:Decay(),retained-.5*.02-200/6000,"minimum cooling starts after grace")
armor:OnLoad({pressure=.25,cooling=.7})
local grace=armor:OnSave()
near(grace.cooling,.7,"remaining grace is saved")
local _,_,restored=boss(nil,6000);restored:OnLoad(grace)
restored:LongUpdate(.3)
near(restored.pressure,.244,"partial long update applies only proportional cooling")
near(restored:OnSave().cooling,.4,"long update preserves remaining grace")
restored:LongUpdate(.5)
near(restored.pressure,.244-.4*.02-40/6000,"only the post-grace portion uses the minimum")
local remaining=restored.pressure
near(restored:Decay(),remaining,"long update cooling is not counted twice")
restored:OnLoad({pressure=.25,cooling=-1});near(restored:OnSave().cooling,0,"negative grace rejected")
restored:OnLoad({pressure=.25,cooling=math.huge});near(restored:OnSave().cooling,0,"non-finite grace rejected")
restored:OnLoad({pressure=.25,cooling=20});near(restored:OnSave().cooling,1,"saved grace bounded to one second")
local stamp=restored.coolinguntil
restored:RecordDamage(0);near(restored.coolinguntil,stamp,"blocked zero-damage hits cannot extend grace")

-- Real health defenses run first, ignore_invincible does NOT bypass dynamic armor.
install(1)
inst, h, armor = boss(); h:SetMaxDamageTakenPerHit(100)
hit(h, 8000); near(h.currenthealth, 9900); near(armor.pressure, 0.01)
inst, h, armor = boss(); h.absorb = 0.5
hit(h, 4000); near(10000 - h.currenthealth, 1000, "defenses before ten-percent cap")
inst, h, armor = boss(); h.invincible = true
near(hit(h, 8000), 0); near(armor.pressure, 0)
h:DoDelta(-8000, nil, "percent_skill", true, nil, true)
near(10000 - h.currenthealth, 1000)
h.invincible = false
h:ForceKill(); near(h.currenthealth, 0, "admin kill bypass")
inst, h, armor = boss(); h.minhealth = 9500
near(hit(h, 8000), -500, "minhealth clamp")
near(armor.pressure, 0.05, "count actual clamped loss")
near(inst.lastdelta, -500)
inst, h, armor = boss(); h:SetPercent(0.05)
hit(h, 2000); near(h.currenthealth, 0, "low health finishing blow")

-- Minhealth phase writes nested inside a damage call must not be treated as attacks.
inst, h, armor = boss(); h.minhealth = 9500
inst:ListenForEvent("minhealth", function() h:SetPercent(1) end)
hit(h, 8000); near(armor.pressure, 0.05, "phase refill does not remove spent pressure")
near(h.currenthealth, 10000)

-- Shared boss pool includes multiple sources equally; newly spawned shadows opt out.
install(1)
inst, h, armor = boss()
for _, source in ipairs({player, entity("pigman"), entity("bearger", {epic = true})}) do hit(h, 500, source) end
near(10000 - h.currenthealth, 1500, "all sources share pressure below the new threshold")
for _, prefab in ipairs({"lordfruitfly", "antlion"}) do
    local excluded, he = boss(prefab); equal(excluded.components.dynamicarmor2hm, nil)
    hit(he, 2000); near(he.currenthealth, 8000)
end
local shadow, hs, ashadow = boss(); shadow:AddTag("swc2hm")
hit(hs, 8000); near(hs.currenthealth, 2000); near(ashadow.pressure, 0)
local character, hc = boss("wilson", 10000, {player = true, epic = true})
equal(character.components.dynamicarmor2hm, nil)
TheWorld.ismastersim = false
local client = boss(); equal(client.components.dynamicarmor2hm, nil)
TheWorld.ismastersim = true

-- Native synchronous phase transition: old removed before new spawned.
install(1)
inst, h, armor = boss("alterguardian_phase1")
hit(h, 2000); hit(h, 2000); hit(h,2000); local inherited = armor.pressure
inst:PushEvent("phasetransition")
local second = entities[#entities]
equal(second.prefab, "alterguardian_phase2")
near(second.components.dynamicarmor2hm.pressure, inherited)
second:PushEvent("phasetransition")
local third = entities[#entities]
equal(third.prefab, "alterguardian_phase3")
near(third.components.dynamicarmor2hm.pressure, inherited)
local unrelated = boss("alterguardian_phase3")
near(unrelated.components.dynamicarmor2hm.pressure, 0, "no cross-boss inheritance")

-- Health TransferComponent and in-place phases preserve pressure, FX cleans up.
local replacement = boss(); third.components.health:TransferComponent(replacement)
near(replacement.components.dynamicarmor2hm.pressure, inherited)
local viewer = entity("wilson", {player = true})
local description, filter, author = replacement.components.inspectable:GetDescription(viewer)
equal(description:find("63%%") ~= nil, true, "inspect resistance")
equal(filter, "filter"); equal(author, "author")
viewer.blind = true
equal(replacement.components.inspectable:GetDescription(viewer), "boss", "respect visibility")
replacement:Remove()
equal(replacement.components.dynamicarmor2hm.fx, nil)
equal(replacement.components.dynamicarmor2hm.task, nil)

install(1)
inst, h, armor = boss("crabking", 10000, {})
inst.components.timer.values.invincible2hm = 60
inst.epic_armor2hm = true
advance(0)
equal(inst.components.timer:TimerExists("invincible2hm"), false, "old shield removed on mode switch")
hit(h, 2000); near(10000 - h.currenthealth, 1000, "crab uses ten-percent cap")
equal(inst.components.timer:TimerExists("invincible2hm"), false)

-- Per-hit ceiling uses maximum HP, follows max-health changes and shares pressure.
install(1)
inst, h, armor = boss()
hit(h, 1e9); near(h.currenthealth, 9000, "huge first hit limited to ten percent")
hit(h, 1e9); near(h.currenthealth, 8000, "second ten-percent hit reaches the new threshold")
hit(h, 1e9); near(h.currenthealth, 7367.8794411714, "followup above twenty percent continuously reduced")
for i = 1, 20 do hit(h, 1e9) end
equal(h.currenthealth >= 7000 - 1e-7, true, "many same-tick packets cannot kill")
advance(30)
hit(h, 8000); near(armor.pressure, 0.1, "cooldown does not bypass per-hit cap")
inst, h, armor = boss(nil, 40000)
hit(h, 8000); near(h.currenthealth, 36000, "cap follows multiplied maximum")
h:SetPercent(0.05); armor:OnLoad(nil)
hit(h, 8000); near(h.currenthealth, 0, "cap is not ten percent of remaining HP")

-- Existing traditional tier1 behavior is still loaded unchanged.
install(1); hooks = {}; prefabhooks = {}; config.epic_armor_5 = "traditional_1"
assert(loadstring(legacy_source))()
inst, h = boss(); advance(0)
hit(h, 8000, player); near(h.currenthealth, 6000, "legacy tier1 clamp")
advance(1); equal(inst.components.timer:TimerExists("invincible2hm"), true)
advance(10); equal(inst.components.timer:TimerExists("invincible2hm"), false)
print("PASS dynamic armor regression: " .. assertions .. " assertions (native health/explosion/resistance; simulated engine)")
