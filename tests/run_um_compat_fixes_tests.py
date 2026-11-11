"""Actual UM attack closures and production compatibility callbacks in Lua 5.1."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
g = lua.globals()
common = (ROOT / "content/common/common.lua").read_text(encoding="utf-8-sig")
g.speech_source = common[common.index('AddComponentPostInit("talker"'):common.index('-- 时间接口')]
g.compat_source = (ROOT / "content/common/um_compat_fixes.lua").read_text(encoding="utf-8-sig")
g.packing_source = (ROOT / "content/common/beef_bell_pack.lua").read_text(encoding="utf-8-sig")
for version, uid in [("stable", "2039181790"), ("beta", "3193922031")]:
    source = Path(f"D:/SteamLibrary/steamapps/workshop/content/322330/{uid}/init/init_wathom.lua").read_text(encoding="utf-8-sig")
    for name in ["Attack_New", "AttackClient_New"]:
        start = source.index("local function " + name + "(")
        end = source.index("\nend", start) + 4
        g[version + "_" + name] = (
            'local special_staff = {"staff_lunarplant", "icestaff", "firestaff"}\n'
            'local Attack_Old = function() return "normal" end\n'
            'local ClientAttack_Old = Attack_Old\n' + source[start:end] + "\nreturn " + name
        )
lua.execute(r'''
local checks = 0
local function check(ok, msg) checks = checks + 1; assert(ok, msg) end
GLOBAL = _G
local speech
function AddComponentPostInit(name, fn) speech = fn end
assert(loadstring(speech_source))()
local talker = {Say = function(self, text, ...) return text, ... end}
speech(talker)
for _, pair in ipairs({
    {"only_used_by_waxwell", ""},
    {"原台词only_used_by_waxwell\n魔光生效: 开", "原台词\n魔光生效: 开"},
    {"原台词only_used_by_waxwell\n本季节养分", "原台词\n本季节养分"},
    {"only_used_by_waxwell 原台词 only_used_by_wurt", " 原台词 "},
    {"正常台词 TEST", "正常台词 TEST"},
}) do
    local text, arg = talker:Say(pair[1], 20)
    check(text == pair[2] and arg == 20, "preserve text and arguments")
end
local lines = {{message = "table speech"}}
check(talker:Say(lines) == lines and talker:Say(nil) == nil, "native table/nil contracts")
local prefabs, sim, sgpatch = {}, nil, nil
function AddPrefabPostInit(name, fn) prefabs[name] = fn end
function AddSimPostInit(fn) sim = fn end
function AddStategraphPostInit(name, fn) sgpatch = fn end
EQUIPSLOTS = {HANDS = "hands"}
ACTIONS = {ATTACK = {}}
TheWorld = {ismastersim = true}
function GetString() return "cannot wrap" end
local button = {validfn = function() return "native valid", 7 end}
local containers = {widgetsetup = function(container) container.widget = {buttoninfo = button}; return 42 end}
function require() return containers end
function modimport() end
assert(loadstring(compat_source))()
local dummy = {inst = {prefab = "silksack"}}
check(containers.widgetsetup(dummy) == 42, "native widgetsetup return value")
containers.widgetsetup(dummy)
local slots, calls = {}, 0
local c = {GetItemInSlot = function(self, slot) return slots[slot] end}
local bag = {components = {container = c}, replica = {}, WrapStuff = function() calls = calls + 1; return true, 7 end}
prefabs.silksack(bag)
for slot = 1, 6 do
    slots[slot] = {HasTag = function(self, tag) return tag == "nobundling" end}
    check(button.validfn(bag) == false and bag:WrapStuff() == false and calls == 0, "server/widget protected slot " .. slot)
    slots[slot] = nil
end
local result, extra = bag:WrapStuff()
check(result == true and extra == 7 and calls == 1, "native wrapping return values")
result, extra = button.validfn(bag)
check(result == "native valid" and extra == 7, "native widget return values")
local client = {replica = {container = c}, components = {}}
slots[1] = {HasTag = function() return true end}
check(button.validfn(client) == false, "client replica validation")
slots[1] = nil
local clientbag = {WrapStuff = function() return 42 end}
TheWorld.ismastersim = false
prefabs.silksack(clientbag)
check(clientbag:WrapStuff() == 42, "client never gets server wrapper")
slots[1] = {prefab = "beef_bell", HasTag = function() return true end}
check(button.validfn(client) == "native valid", "bound bell is allowed")
check(bag:WrapStuff(), "bound bell reaches native packing")
slots[1] = nil
function HasSkill() return false end
function table.contains(t, wanted) for _, v in ipairs(t) do if v == wanted then return true end end return false end
for _, version in ipairs({"stable", "beta"}) do
    local server = assert(loadstring(_G[version .. "_Attack_New"]))()
    local clientattack = assert(loadstring(_G[version .. "_AttackClient_New"]))()
    local graph = {states = {wathomleap = {}}, actionhandlers = {[ACTIONS.ATTACK] = {deststate = server}}}
    sgpatch(graph)
    for _, name in ipairs({"icestaff", "icestaff2", "icestaff3", "firestaff", "blowdart_pipe", "boomerang"}) do
        for _, context in ipairs({"normal", "riding", "attacking", "wilson"}) do
            local weapon = {prefab = name, HasTag = function(_, tag)
                return tag == "rangedweapon" or tag == "blowdart" and name == "blowdart_pipe" or tag == "thrown" and name == "boomerang"
            end}
            local inventory = {GetEquippedItem = function() return weapon end}
            local rider = {IsRiding = function() return context == "riding" end}
            local inst = {components = {inventory = inventory, rider = rider}, replica = {inventory = inventory, rider = rider},
                HasTag = function() return context ~= "wilson" end,
                sg = {mem = {}, HasStateTag = function() return context == "attacking" end}}
            local want = context == "normal" and name ~= "blowdart_pipe" and name ~= "boomerang"
            check((graph.actionhandlers[ACTIONS.ATTACK].deststate(inst, {}) == "wathomleap") == want, version .. " server " .. name .. " " .. context)
            check((clientattack(inst, {}) == "wathomleap_pre") == want, version .. " client " .. name .. " " .. context)
        end
    end
end
print("UM compatibility regressions: " .. checks .. " checks passed")
''')
lua.execute(r'''
local checks, spawned = 0, 0
local function check(ok, msg) checks = checks + 1; assert(ok, msg) end
function shallowcopy(t) local c = {}; for k, v in pairs(t) do c[k] = v end; return c end
local prefabs, component = {}, nil
function AddPrefabPostInit(name, fn) prefabs[name] = fn end
function AddComponentPostInit(name, fn) component = fn end
TheWorld.ismastersim = true
assert(loadstring(packing_source))()
local function bell()
    local cow = {valid = true, components = {follower = {SetLeader = function() end}},
        IsValid = function(self) return self.valid end, Remove = function(self) self.valid = false end}
    local callback = function() error("must not trigger death/revival") end
    local leader = {onremovefollower = callback, RemoveFollower = function(self, target, invalid)
        check(self.onremovefollower == nil and target == cow and invalid, "transfer removes follower without death callback")
    end}
    local e = {prefab = "beef_bell", valid = true, components = {leader = leader, inventoryitem = {ChangeImageName = function() end}},
        GetSkinName = function() end, AnimState = {PlayAnimation = function() end},
        GetBeefalo = function() return cow end, Remove = function(self) self.valid = false; return "removed" end,
        OnLoad = function(self, data) if data.beef_record then spawned = spawned + 1 end end,
        OnSave = function() return "saved" end}
    prefabs.beef_bell(e)
    return e, cow, callback
end
local function bundle()
    local e = {valid = true, IsValid = function(self) return self.valid end}
    local c = {inst = e, WrapItems = function(self, items)
        self.origin = "new"
        self.itemdata = {{prefab = items[1].prefab, data = {beef_record = {}}}}
        if self.failwrap then error("callback failure") end
        return "wrapped"
    end, PeekInContainer = function(self)
        check(self.itemdata[1].data.beefbellpreview2hm, "only temporary preview data is marked")
        if self.failpeek then error("preview failure") end
        return "peeked"
    end}
    component(c)
    return c
end
local source, cow = bell()
source:Remove()
check(cow.valid, "unrelated bell removal keeps original behavior")
source, cow = bell()
local c = bundle()
check(c:WrapItems({source}) == "wrapped" and cow.valid, "serialization alone does not consume cow")
check(source:Remove() == "removed" and not cow.valid, "source consumption commits cow transfer")
source, cow = bell()
c = bundle(); c:WrapItems({source}); c.inst.valid = false
source:Remove()
check(cow.valid, "discarded bundle cannot consume source cow")
source, cow = bell()
c = bundle(); c:WrapItems({source}); c.itemdata = {}
source:Remove()
check(cow.valid, "replaced payload cannot consume source cow")
source, cow = bell()
c = bundle(); c.itemdata = {"old"}; local previous = c.itemdata; c.origin = "old"; c.failwrap = true
check(not pcall(c.WrapItems, c, {source}), "serialization callback failure propagates")
check(c.itemdata == previous and c.origin == "old", "failed serialization rolls back payload and origin")
check(cow.valid and source.beefbelltransfer2hm == nil, "failed serialization never transfers cow")
source, cow = bell()
c = bundle(); c:WrapItems({source}); local actual = c.itemdata
check(c:PeekInContainer() == "peeked", "native peek return preserved")
check(c.itemdata == actual and not actual[1].data.beefbellpreview2hm, "successful peek leaves original record intact")
c.failpeek = true
check(not pcall(c.PeekInContainer, c), "native peek exception propagates")
check(c.itemdata == actual and not actual[1].data.beefbellpreview2hm, "failed peek restores original record")
local preview = bell()
preview:OnPreLoad({beefbellpreview2hm = true})
preview:OnLoad({beef_record = {}, beefbellpreview2hm = true})
check(spawned == 0, "preview load never runs native cow restoration")
source = bell()
source:OnPreLoad({beef_record = {}}); source:OnLoad({beef_record = {}})
check(spawned == 1, "real load still restores native cow")
function GetTime() return 100 end
source.relivetask2hm = {NextTime = function() return 137 end}
local data = {}
check(source:OnSave(data) == "saved" and data.beefbellrevivetime2hm == 37, "revival timer and native save result preserved")
print("Bell ownership regressions: " .. checks .. " checks passed")
''')
for name in ["common/common.lua", "common/um_compat_fixes.lua", "common/beef_bell_pack.lua", "modmain.lua", "easy_role/wathom_easy.lua", "easy_other/easy_items.lua", "easy_other/lunar_shadow_items.lua"]:
    lua.execute("assert(loadstring(...))", (ROOT / "content" / name).read_text(encoding="utf-8-sig"))
print("Changed production files compile in Lua 5.1")
