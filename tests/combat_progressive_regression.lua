local assertions = 0
local function near(a, b, label)
    assertions = assertions + 1
    assert(math.abs(a - b) < 1e-7, (label or "near") .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end
local function equal(a, b, label)
    assertions = assertions + 1
    assert(a == b, (label or "equal") .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end
FRAMES = 1 / 30
TUNING = {isCh2hm = false}
TheWorld = {ismastersim = true, components = {}, PushEvent = function() end}
EntityScript = {is_instance = function() return false end}
function math.clamp(v, lo, hi) return math.max(lo, math.min(v, hi)) end
function table.removearrayvalue(list, value)
    for i = #list, 1, -1 do if list[i] == value then table.remove(list, i) end end
end
function CanApplyPlayerDamageMod(target) return target:HasTag("player") end
function FunctionOrValue(v, ...) if type(v) == "function" then return v(...) end return v end
function IsRangedWeapon() return false end
function CanEntityBecomeCorpse() return false end
function NotifyPlayerProgress() end
function CanEntitySeeTarget() return true end
for name, source in pairs(native_sources) do
    local code = source
    package.preload[name] = function() return assert(loadstring(code))() end
end
for _, name in ipairs({"progressivecombat2hm", "combatdisplay2hm", "components/dynamicarmor2hm"}) do
    local code = mod_sources["scripts/" .. name .. ".lua"]
    package.preload[name] = function() return assert(loadstring(code))() end
end
local SML = require("util/sourcemodifierlist")
SpDamageUtil = require("components/spdamageutil")
local Weapon = require("components/weapon")
local Planar = require("components/planardamage")
local TypeBonus = require("components/damagetypebonus")
local Calculator = require("progressivecombat2hm")
local Armor = require("components/dynamicarmor2hm")
Combat = {}; Health = {}
assert(loadstring(native_calc_source))()
assert(loadstring(native_attacked_source))()
assert(loadstring(health_source))()
local hooks, prefabs, playerhooks, config, now, jobs
function GetTime() return now end
function GetModConfigData(key) return config[key] end
function AddComponentPostInit(name, fn)
    hooks[name] = hooks[name] or {}; table.insert(hooks[name], fn)
end
function AddPlayerPostInit(fn) table.insert(playerhooks, fn) end
function AddPrefabPostInit(name, fn) prefabs[name] = fn end
function AddPrefabPostInitAny(fn) prefabs.any = fn end
function modimport(name) assert(loadstring(mod_sources[name]))() end
local function hook(name, component)
    for _, fn in ipairs(hooks[name] or {}) do fn(component) end
end
local function advance(dt)
    local target = now + dt
    for _, j in ipairs(jobs) do
        if not j.cancelled and j.at <= target then j.cancelled = true; j.fn(j.inst) end
    end
    now = target
end
local function install(mode, dynamic)
    hooks = {}; prefabs = {}; playerhooks = {}; jobs = {}; now = 0
    config = {combat = mode, extra_change = false}
    TheWorld.ismastersim = true
    modimport("role/combat.lua")
    if dynamic then modimport("epic/dynamic_armor.lua") end
end
local function entity(prefab, tags)
    local inst = {prefab = prefab, components = {}, tags = tags or {}, events = {}, valid = true}
    inst.isplayer = inst.tags.player; inst.userid = inst.isplayer and "fixture" or nil
    function inst:HasTag(tag) return self.tags[tag] or false end
    function inst:IsValid() return self.valid end
    function inst:IsAsleep() return true end
    function inst:IsInLimbo() return false end
    function inst:PushEvent(event, data)
        self.events[event] = (self.events[event] or 0) + 1
        if event == "healthdelta" then self.lastdelta = data.amount end
    end
    function inst:DoTaskInTime(delay, fn)
        local j = {at = now + delay, fn = fn, inst = self, Cancel = function(j) j.cancelled = true end}
        jobs[#jobs + 1] = j; return j
    end
    function inst:DoPeriodicTask(delay, fn) return self:DoTaskInTime(delay, fn) end
    function inst:AddComponent(name)
        if name == "dynamicarmor2hm" then self.components[name] = Armor(self) else error(name) end
    end
    return inst
end
local function health(inst, maximum)
    local h = setmetatable({inst = inst, currenthealth = maximum, maxhealth = maximum, minhealth = 0,
        penalty = 0, nonlethal_pct = 0, absorb = 0, playerabsorb = 0, nofadeout = true,
        externalabsorbmodifiers = SML(inst, 0, SML.additive),
        externalreductionmodifiers = SML(inst, 0, SML.additive)}, {__index = Health})
    function h:GetPercent() return self.currenthealth / self.maxhealth end
    function h:IsInvincible() return self.invincible or false end
    function h:ForceUpdateHUD() end
    inst.components.health = h; hook("health", h); return h
end
local function combat(inst)
    local c = setmetatable({inst = inst, defaultdamage = 100, damagemultiplier = 1, damagebonus = 0,
        playerdamagepercent = 1, pvp_damagemod = 0.5, externaldamagemultipliers = SML(inst),
        externaldamagetakenmultipliers = SML(inst)}, {__index = Combat})
    function c:ShouldRecoil(_, _, damage) return false, damage end
    function c:GetImpactSound() end
    inst.components.combat = c; hook("combat", c); return c
end
local function player(prefab)
    local inst = entity(prefab or "wilson", {player = true})
    health(inst, 150); local c = combat(inst)
    inst.components.talker = {Say = function(_, message) inst.lastspeech = message end}
    inst.components.locomotor = {SetExternalSpeedMultiplier = function(_, _, _, value) inst.speed = value end,
        RemoveExternalSpeedMultiplier = function() inst.speed = nil end}
    for _, fn in ipairs(playerhooks) do fn(inst) end
    return inst, c
end
local function planar(inst, base, multiplier, bonus)
    local p = Planar(inst); inst.components.planardamage = p
    p:SetBaseDamage(base); p:AddMultiplier("test", multiplier or 1); p:AddBonus("test", bonus or 0)
    return p
end
local function tagbonus(inst, value)
    inst.components.damagetypebonus = TypeBonus(inst)
    inst.components.damagetypebonus:AddBonus("shadow", "test", value)
end
local function weapon(base, sp)
    local w = entity("fixtureweapon")
    w.components.weapon = setmetatable({inst = w, damage = base or 100}, {__index = Weapon})
    if sp then planar(w, sp) end
    return w
end
local target = entity("target", {shadow = true})
local function toggle(inst)
    local bag = entity("punchingbag")
    bag.components.inspectable = {inst = bag, GetDescription = function() return "bag", "filter", "author" end}
    prefabs.punchingbag(bag)
    local _, filter, author = bag.components.inspectable:GetDescription(inst)
    equal(filter, "filter"); equal(author, "author")
end

-- Config compatibility and defaults.
locale = "zh"; assert(loadstring(mod_sources["modinfo.lua"]))()
local opt
for _, entry in ipairs(configuration_options) do if entry.name == "combat" then opt = entry end end
equal(opt.default, 4)
local modes = {}; for _, entry in ipairs(opt.options) do modes[entry.data] = true end
equal(modes[false], true); for i = 1, 4 do equal(modes[i], true) end

install(4)
local p, c = player(); local w = weapon(100, 20)
for _, row in ipairs({{1, 1}, {2.5, 2.5}, {3, 2.75}, {4, 2.875}, {5, 2.9166666666667}, {10, 2.96875}}) do
    c.damagemultiplier = row[1]
    local d, sp = c:CalcDamage(target, w)
    near(d, row[2] * 100); near(sp.planar, 20, "ordinary does not leak to planar")
end
for _, row in ipairs({{"wolfgang", 3.5, 4}, {"wathom", 4, 4.5}}) do
    local character, cc = player(row[1]); cc.damagemultiplier = math.huge
    local d, sp = cc:CalcDamage(target, w)
    near(d, row[3] * 100, "finite extreme output"); near(sp.planar, 20)
end

-- Multipliers combine before compression; negatives and PVP remain effective.
c.damagemultiplier = 2; c.externaldamagemultipliers:SetModifier("buff", 2)
tagbonus(w, 1.5)
local d, sp = c:CalcDamage(target, w)
near(d, 293.75, "counter bonus inside pool"); near(sp.planar, 30)
c.externaldamagemultipliers:SetModifier("debuff", 0.8); c.damagebonus = 20
d = c:CalcDamage(target, w); near(d, 255, "negative after positive limit; flat bonus last")
w.components.damagetypebonus = nil
c.externaldamagemultipliers:RemoveModifier("debuff"); c.damagebonus = 50
local pvptarget = entity("wilson", {player = true})
d, sp = c:CalcDamage(pvptarget, w); near(d, 193.75); near(sp.planar, 10)

-- Planar local multipliers/bonuses and character-owned contributions stay distinct.
p, c = player(); w = weapon(100, 20)
planar(w, 20, 2, 5); planar(p, 10); tagbonus(w, 1.5)
d, sp = c:CalcDamage(target, w)
near(d, 150); near(sp.planar, 64.1666666666667, "source-local bonus scopes")
p.components.planardamage = nil; planar(w, 20, 1)
local customcalls, specialcalls, tagcalls, damagecalls = 0, 0, 0, 0
c.customdamagemultfn = function() customcalls = customcalls + 1; return 2 end
c.customspdamagemultfn = function() specialcalls = specialcalls + 1; return 2 end
w.components.damagetypebonus:AddBonusCallback(function() tagcalls = tagcalls + 1; return 1 end)
w.components.weapon.damage = function() damagecalls = damagecalls + 1; return 100 end
local before = c.CalcDamage
toggle(p); d, sp = c:CalcDamage(target, w)
near(d, 275); near(sp.planar, 46.6666666666667)
equal(c.CalcDamage, before, "display never changes calculator")
near(customcalls, 1); near(specialcalls, 1); near(tagcalls, 1); near(damagecalls, 1)
advance(0.1); equal(p.lastspeech ~= nil, true)
toggle(p); local d2, sp2 = c:CalcDamage(target, w)
near(d2, d); near(sp2.planar, sp.planar)
near(customcalls, 2); near(specialcalls, 2); near(damagecalls, 2)
w.components.planardamage = nil
c:CalcDamage(target, w); near(specialcalls, 2, "no special callback without special damage")
local blocked = entity("block", {alwaysblock = true})
near(c:CalcDamage(blocked, w), 0); near(customcalls, 3, "blocked does not run callbacks")

-- Opaque weapon callbacks are retained once; explicit adapter enables local factors.
p, c = player(); w = weapon(100); local calls = 0
w.components.weapon.GetDamage = function() calls = calls + 1; return 200, {planar = 30} end
tagbonus(w, 3)
d, sp = c:CalcDamage(target, w); near(d, 200); near(sp.planar, 30); near(calls, 1)
w.components.weapon.progressiveterms2hm = function()
    return {regular = {{amount = 100, factors = {2, 3}}}, special = {planar = {{amount = 10, factors = {3}}}}}
end
d, sp = c:CalcDamage(target, w); near(d, 293.75); near(sp.planar, 23.3333333333333); near(calls, 1)

-- Mounted source and saddle bonuses; rider ordinary multiplier must not leak.
p, c = player("wathom"); c.damagemultiplier = 100
local mount = entity("beefalo"); local mc = combat(mount); mc.damagemultiplier = 4
local saddle = entity("saddle"); saddle.components.saddler = {GetBonusDamage = function() return 20 end}
planar(mount, 10); planar(saddle, 5)
p.components.rider = {IsRiding = function() return true end, GetMount = function() return mount end, GetSaddle = function() return saddle end}
d, sp = c:CalcDamage(target); near(d, 345); near(sp.planar, 15)
near(mc:CalcDamage(target), 400, "NPCs retain native calculation")
-- Maxwell's followers must not inherit their owner's progressive calculation.
local maxwell, maxwellcombat = player("waxwell")
maxwellcombat.damagemultiplier = 100
local servants = 0
for i = 1, 3 do
    local servant = entity("shadowduelist", {shadowminion = true})
    servant.components.follower = {leader = maxwell}
    local sc = combat(servant)
    sc.defaultdamage = 20
    near(sc:CalcDamage(target), 20, "shadow servant retains its own native attack")
    servants = servants + sc:CalcDamage(target)
end
near(servants, 60, "three servants add three attacks, not the owner's multiplier")

-- Match native semantics when no source exceeds the thresholds.
for _, base in ipairs({0, 50, 100}) do
    for _, mult in ipairs({0.5, 1, 1.2}) do
        p, c = player(); c.damagemultiplier = mult; c.damagebonus = 7
        w = weapon(base, 20); planar(p, 5); tagbonus(w, 1.2); tagbonus(p, 1.1)
        d, sp = c:CalcDamage(target, w)
        local native, nativesp = Combat.CalcDamage(c, target, w)
        near(d, native, "below-threshold regular parity"); near(sp.planar, nativesp.planar, "below-threshold special parity")
    end
end

-- The mod's real Willow prefab wrapper must stay outside the new component hook.
install(4)
assert(loadstring(willow_flame_wrapper))()
p, c = player("willow"); c.damagemultiplier = 100
prefabs.willow(p); advance(2)
for _, name in ipairs({"willow_shadow_flame", "flamethrower_fx"}) do
    w = weapon(40, 20); w.prefab = name
    local count = 0
    w.components.weapon.GetDamage = function() count = count + 1; return 40, {planar = 20} end
    d, sp = c:CalcDamage(target, w)
    near(d, 40, "Willow flame keeps its own rules"); near(sp.planar, 20); near(count, 1)
end
w = weapon(100, 20)
d, sp = c:CalcDamage(target, w)
near(d, Calculator.SoftLimit(100, 2.5) * 100, "Willow ordinary weapon uses progressive mode")
near(sp.planar, 20)

-- Legacy mode1/mode3 retain results and show them without swapping algorithms.
for _, mode in ipairs({1, 3}) do
    install(mode); p, c = player(); w = weapon(100, 20); c.damagemultiplier = 4
    advance(1)
    local calc = c.CalcDamage; d, sp = c:CalcDamage(target, w)
    near(d, mode == 1 and 400 or 250); near(sp.planar, 20)
    toggle(p); d2, sp2 = c:CalcDamage(target, w)
    near(d2, d); near(sp2.planar, sp.planar); equal(c.CalcDamage, calc)
end

-- Installed native target combat + health pipeline + both new mechanics.
install(4, true)
p, c = player(); w = weapon(100, 20); tagbonus(w, 1.5)
c.damagemultiplier = 2; c.externaldamagemultipliers:SetModifier("buff", 2)
c.externaldamagemultipliers:SetModifier("penalty", 0.8); c.damagebonus = 20
planar(w, 20, 2)
local boss = entity("testboss", {epic = true, shadow = true})
local bh = health(boss, 10000); local bc = combat(boss); prefabs.any(boss)
boss.components.inventory = {ApplyDamage = function(_, amount, _, _, special) return amount * 0.5, special end}
boss.components.planardefense = {GetDefense = function() return 5 end}
bc.externaldamagetakenmultipliers:SetModifier("vulnerable", 1.2)
bh.absorb = 0.1; bh:SetMaxDamageTakenPerHit(150)
boss.components.dynamicarmor2hm:OnLoad({pressure = 0.15})
d, sp = c:CalcDamage(boss, w); near(d, 255); near(sp.planar, 46.6666666666667)
bc:GetAttacked_Internal(p, d, w, nil, sp)
near(10000 - bh.currenthealth, 69.6460117874711, "full defense order then continuous armor")
equal(boss.events.healthdelta, 1, "one health change for mixed damage")
near(boss.components.dynamicarmor2hm.pressure, 0.156964601178747)
-- Huge mixed hit is capped once, after summing both channels.
boss.components.inventory = nil; boss.components.planardefense = nil
bc.externaldamagetakenmultipliers:Reset(); bh.absorb = 0; bh.maxdamagetakenperhit = nil
bh:SetPercent(1); boss.components.dynamicarmor2hm:OnLoad(nil)
bc:GetAttacked_Internal(p, 10000, w, nil, {planar = 10000})
near(bh.currenthealth, 9000); near(boss.components.dynamicarmor2hm.pressure, 0.1)
print("PASS progressive combat: " .. assertions .. " assertions (native damage/components; simulated engine)")
