GLOBAL = _G
TUNING = { SPRING_FIRE_RANGE_MOD = 1.5, DSTU = { WINTER_FIRE_MOD = .5 } }
TheWorld = { state = {} }
UMSimTempOverride = {}
local searches, cancelled, warmed, melted = 0, 0, 0, 0
local target = {
    Transform = { GetWorldPosition = function() return 11, 0, 20 end },
    components = { propagator = {
        AcceptsHeat = function() return true end,
        AddHeat = function() warmed = warmed + 1 end,
    } },
    IsValid = function() return true end,
    GetDistanceSqToPoint = function() return 1 end,
    HasAnyTag = function() return true end,
    AddTag = function() end,
    RemoveTag = function() end,
    PushEvent = function() melted = melted + 1 end,
}
TheSim = { FindEntities = function(_, x, y, z)
    assert(type(x) == "number" and type(y) == "number" and type(z) == "number", "invalid search coordinates")
    searches = searches + 1
    return { target }
end }
function VecUtil_LengthSq(x, z) return x*x + z*z end
local hook
function AddComponentPostInit(name, fn) assert(name == "propagator"); hook = fn end
env = { AddComponentPostInit = AddComponentPostInit }
local Propagator = assert(loadstring(native_propagator))()
local function make()
    local inst = { valid = true, components = {} }
    function inst:IsValid() return self.valid end
    inst.Transform = { GetWorldPosition = function()
        if inst.valid and not inst.no_position then return 10, 0, 20 end
    end }
    local p = Propagator(inst)
    p.task = { Cancel = function() cancelled = cancelled + 1 end }
    p.delay = { Cancel = function() cancelled = cancelled + 1 end }
    return p
end
local total = 0
for _, source in ipairs({ false, stable, beta }) do
    local umhook
    if source then assert(loadstring(source))(); umhook = hook end
    local old = make()
    if umhook then umhook(old) end
    old.inst.valid = false
    assert(not pcall(old.OnRemoveFromEntity, old), "unpatched cleanup reproduces crash")
    assert(loadstring(patch))()
    local repair = hook
    for _, invalid in ipairs({ "removed", "missing_position" }) do
        local p = make()
        if umhook then umhook(p) end
        repair(p)
        p.inst.valid = invalid ~= "removed"
        p.inst.no_position = invalid == "missing_position"
        local before, calls = cancelled, searches
        p:OnRemoveFromEntity()
        assert(searches == calls, "invalid entity never reaches FindEntities")
        assert(cancelled == before + 2 and p.task == nil and p.delay == nil, "both tasks cleaned")
        p:OnRemoveEntity()
        p:OnUpdate(0)
        assert(searches == calls, "repeat cleanup is safe")
        total = total + 1
    end
    for _, winter in ipairs({ false, true }) do
        TheWorld.state.iswinter = winter
        local p = make()
        if umhook then umhook(p) end
        repair(p)
        local calls, oldwarmed, oldmelted = searches, warmed, melted
        p.spreading = true
        p:OnUpdate(.5)
        assert(searches == calls + 1 and warmed > oldwarmed and melted > oldmelted, "valid fire still spreads heat")
        assert(p.propagaterange == 3 and p.damagerange == 3, "UM restores winter ranges")
        p:OnRemoveFromEntity()
        assert(searches == calls + 2 and p.task == nil and p.delay == nil, "valid cleanup still notifies nearby entities")
        total = total + 1
    end
end
print("Propagator: old crash reproduced in vanilla/stable/beta; " .. total .. " patched lifecycle cases passed")
