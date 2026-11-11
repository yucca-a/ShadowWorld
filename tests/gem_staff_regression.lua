local count = 0
local function check(ok, msg) count=count+1; assert(ok, msg) end
local compat = assert(loadstring(compat_source))()
local sentinel = {}
UpvalueHacker = sentinel
local helper = assert(loadstring(new_helper))()
check(UpvalueHacker == sentinel, "private helper must not overwrite Gem Core")
local old = assert(loadstring(old_helper))()
check(UpvalueHacker == old, "baseline global pollution reproduced")
UpvalueHacker = sentinel

local function setup(mode)
    local staff = assert(loadstring(staff_source))()
    local originalgreen = staff.fns.green
    if mode == "wrapped" or mode == "multi" then
        local oldgreen = originalgreen
        staff.fns.green = function(...) return oldgreen(...) end
        if mode == "multi" then
            local inner = staff.fns.green
            staff.fns.green = function(...) return inner(...) end
        end
    elseif mode == "opaque" then
        local holder = {originalgreen}
        staff.fns.green = function(...) return holder[1](...) end
    elseif mode == "ambiguous" then
        local other = assert(loadstring(staff_source))()
        local first, second = originalgreen, other.fns.green
        staff.fns.green = function(inst, alternate) return (alternate and second or first)(inst) end
    elseif mode == "cycle" then
        local loop
        loop = function(...) return loop(...) end
        staff.fns.green = loop
    end
    local callback
    local e = setmetatable({UpvalueHacker=helper}, {__index=_G})
    e._G=e
    e.require = function(name) assert(name=="prefabs/staff_common");return staff end
    e.GEMENV={AddSimPostInit=function(fn) callback=fn end}
    e.gemrun=function() end
    assert(setfenv(assert(loadstring(gem_source, "@../mods/workshop-1378549454/gemscripts/gemdictionary/loot.lua")),e))()
    return staff, callback, e, originalgreen
end

do
    local _, callback, env = setup("wrapped")
    env.UpvalueHacker = old
    local ok, err = pcall(callback)
    check(not ok and tostring(err):find("SpawnLootPrefab", 1, true), "reported missing-upvalue failure reproduced")
end

for _,mode in ipairs({"normal", "wrapped", "multi", "opaque", "ambiguous", "cycle"}) do
    local staff, callback, env, originalgreen = setup(mode)
    local green = staff.fns.green
    local before = helper.GetUpvalue(originalgreen, "destroystructure")
    local warnings = 0
    local wrapped = compat.Wrap(callback, function() return staff end, function() warnings=warnings+1 end)
    wrapped()
    local after = helper.GetUpvalue(originalgreen, "destroystructure")
    local supported = mode=="normal" or mode=="wrapped" or mode=="multi"
    check((after~=before)==supported, mode.." only supported recipe loops are patched")
    check(warnings==(supported and 0 or 1), mode.." diagnostic")
    check(staff.fns.green==green, mode.." preserves constructor wrapper")
    check(env.UpvalueHacker==helper and UpvalueHacker==sentinel, mode.." keeps shared APIs intact")
    if supported then
        check(helper.GetUpvalue(originalgreen,"onhauntgreen","destroystructure")==after, mode.." haunting and casting use same patch")
    end
end

do
    local staff, callback = setup("wrapped")
    local unrelated=function() error("unrelated failure") end
    local gem={postinitfns={SimPostInit={callback,unrelated}}}
    local manager={GetMod=function(_,id) assert(id=="workshop-1378549454");return gem end}
    compat.Install(manager)
    local installed=gem.postinitfns.SimPostInit[1]
    check(installed~=callback,"recognizes actual Gem Core callback source and closure")
    check(gem.postinitfns.SimPostInit[2]==unrelated,"unrelated callbacks unchanged")
    compat.Install(manager)
    check(gem.postinitfns.SimPostInit[1]==installed,"install idempotent")
    -- Installation loads the game module only when SimPostInit executes.
    local oldrequire=require
    require=function(name) if name=="prefabs/staff_common" then return staff end;return oldrequire(name) end
    installed()
    require=oldrequire
end
print("Gem staff regression passed: "..count.." checks")
