-- Engine services and rendering are stubbed; data, updater, tree definitions,
-- toast behaviour and checkbox implementation come from the installed game.
local assertions = 0
local function equal(actual, expected, message)
    assertions = assertions + 1
    assert(actual == expected, (message or "mismatch") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function namespace()
    return setmetatable({}, {__index = function(t, k) local v = namespace(); rawset(t, k, v); return v end})
end
function table.count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end
function table.contains(t, v) for _, item in pairs(t) do if item == v then return true end end; return false end
function table.keysareidentical(a, b)
    for k in pairs(a) do if b[k] == nil then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
function deepcopy(t)
    if type(t) ~= "table" then return t end
    local result = {}; for k, v in pairs(t) do result[k] = deepcopy(v) end; return result
end
function orderedPairs(t) return pairs(t) end
function GetTableSize(t) return table.count(t) end
function math.clamp(v, lo, hi) return math.max(lo, math.min(v, hi)) end
STRINGS = namespace()
STRINGS.UI.HUD.INSPECT_SELF = "Inspect self"
UPGRADETYPES = setmetatable({}, {__index = function(_, key) return key end})
SPELLTYPES = UPGRADETYPES
TUNING = {SKILLS = namespace(), TEMP2HM = {}, isCh2hm = true, FIXME_DO_NOT_USE_FOR_MODS_OLD_MAX_XP_VALUE = 160}
package.preload["prefabs/wx78_common"] = function() return {} end
BRANCH = "release"
TheNet = {IsDedicated = function() return false end}
TheWorld = {state = {cycles = 1000}, ismastersim = true}
local defs = require("prefabs/skilltree_defs")
local SkillTreeData = require("skilltreedata")
local hooks = {}
local config
function GetModConfigData(name) return config[name] end
function AddClassPostConstruct(name, fn) hooks[name] = fn end
function SaveTemp2hm() saved_preferences = deepcopy(TUNING.TEMP2HM) end
local function install(option, hardmode)
    hooks = {}
    config = {["More Skill Points"] = option, role_nerf = true}
    TUNING.hardmode2hm = hardmode
    assert(loadstring(patch_source))()
end
local function data()
    local d = SkillTreeData()
    hooks.skilltreedata(d)
    return d
end
local function allskills(prefab)
    local skills = {}
    for name, skill in pairs(defs.SKILLTREE_DEFS[prefab]) do if skill.rpc_id ~= nil then skills[name] = true end end
    return skills
end
local function maximumxp(n)
    local xp = 0; for i = 1, n do xp = xp + TUNING.SKILL_THRESHOLDS[i] end; return xp
end

-- Every current character, including WX-78: fully spent trees stay at zero,
-- old overflow does not erase skills/XP, and respec refunds exactly the tree size.
install(true, true)
local counts = {}
for prefab, meta in pairs(defs.SKILLTREE_METAINFO) do
    local d = data()
    local count = meta.TOTAL_SKILLS_COUNT
    counts[#counts + 1] = prefab .. "=" .. count
    d.skillxp[prefab] = 160
    d.activatedskills[prefab] = allskills(prefab)
    equal(d:GetAvailableSkillPoints(prefab), 0, prefab .. " full tree")
    local updated = d:AddSkillXP(100, prefab)
    equal(updated, false, prefab .. " stops gaining XP")
    equal(d.skillxp[prefab], 160, prefab .. " preserves historical XP")
    equal(table.count(d.activatedskills[prefab]), count, prefab .. " preserves skills")
    d:RespecSkills(prefab)
    equal(d:GetAvailableSkillPoints(prefab), count, prefab .. " respec")
    d.skillxp[prefab] = maximumxp(count) - 1
    equal(d:GetAvailableSkillPoints(prefab), count - 1, prefab .. " last point boundary")
    d:AddSkillXP(100, prefab)
    equal(d:GetAvailableSkillPoints(prefab), count, prefab .. " last point awarded")
    equal(d.skillxp[prefab], maximumxp(count), prefab .. " new XP capped")
end
table.sort(counts)
print("Current game skill counts: " .. table.concat(counts, ", "))

-- Regression for stale prefab context breaking a different character's load.
local d = data()
d:GetAvailableSkillPoints("wathgrithr")
local roots = {}
for name, skill in pairs(allskills("woodie")) do roots[name] = true end
-- Validate allocation count using real validation with dependency checks omitted
-- only for this fixture (alignment locks intentionally restrict some combinations).
local saveddefs = defs.SKILLTREE_DEFS.woodie
rawset(defs.SKILLTREE_DEFS, "woodie", {})
for name in pairs(roots) do defs.SKILLTREE_DEFS.woodie[name] = {} end
equal(d:ValidateCharacterData("woodie", roots, 160), true, "cross-character validation")
rawset(defs.SKILLTREE_DEFS, "woodie", saveddefs)
equal(d:GetAvailableSkillPoints("wes"), 0, "no tree has no points")
d:AddSkillXP(1, "wes")
equal(d:GetSkillXP("wes"), 0, "no tree does not earn XP")

-- Starting points, world-day growth, no-points option, and inactive feature.
for _, option in ipairs({-6, -16}) do
    install(option, true)
    local limited = data()
    limited.skillxp.wx78 = 160
    local start = -option - 1
    TheWorld.state.cycles = 0
    equal(limited:GetAvailableSkillPoints("wx78"), start, "starting points")
    TheWorld.state.cycles = TUNING.SKILL_THRESHOLDS[start + 1]
    equal(limited:GetAvailableSkillPoints("wx78"), start + 1, "day unlock")
    TheWorld.state.cycles = 1000
    limited.activatedskills.wx78 = allskills("wx78")
    equal(limited:GetAvailableSkillPoints("wx78"), 0, "full tree after 1000 days")
    equal(limited:AddSkillXP(1, "wx78"), false, "no forced XP event after cap")
end
install(-1, true)
d = data(); d.skillxp.wx78 = 160
equal(d:GetAvailableSkillPoints("wx78"), 0, "zero-point config")
install(false, true)
equal(hooks.skilltreedata, nil, "disabled feature")
install(false, false)
equal(hooks.skilltreedata, nil, "disabled feature also respected without hard mode")
install(true, false)
d = data(); d.skillxp.wx78 = 160; TheWorld.state.cycles = 0
equal(d:GetAvailableSkillPoints("wx78"), 15, "easy mode starts with 15")
TheWorld.state.cycles = 1000

-- Minimal widget and event simulation for real toast and checkbox code.
local function entity()
    return {
        listeners = {},
        ListenForEvent = function(self, event, fn, source)
            source = source or self
            source.listeners[event] = source.listeners[event] or {}
            table.insert(source.listeners[event], fn)
        end,
        PushEvent = function(self, event, arg)
            for _, fn in ipairs(self.listeners[event] or {}) do fn(self, arg) end
        end,
    }
end
TheWorld.listeners = {}
function Vector3(x, y, z) return {x = x or 0, y = y or 0, z = z or 0} end
local Widget = Class(function(self) self.inst = entity(); self.shown = true; self.pos = Vector3(); self.dirs = {} end)
function Widget:AddChild(child) child.parent = self; return child end
function Widget:Show() self.shown = true end
function Widget:Hide() self.shown = false end
function Widget:IsVisible() return self.shown end
function Widget:SetPosition(x, y, z) self.pos = type(x) == "table" and x or Vector3(x, y, z) end
function Widget:GetPosition() return self.pos end
function Widget:MoveTo(from, to, duration, fn) self.pos = to; fn() end
function Widget:SetOnClick(fn) self.onclick = fn end
function Widget:SetFocusChangeDir(dir, target) self.dirs[dir] = target end
function Widget:SetString(s) self.value = s end
function Widget:GetRegionSize() return 200, 25 end
function Widget:StartUpdating() self.updating = true end
function Widget:StopUpdating() self.updating = false end
function Widget:Kill() self.killed = true end
for _, name in ipairs({"SetScale", "SetTextColour", "SetTooltip", "SetTooltipPos", "Disable", "Enable", "SetLoop", "SetOnFocus", "SetTextFocusColour", "SetFont", "SetDisabledFont", "SetTextDisabledColour", "SetText", "SetTextSize", "SetHAlign", "SetTextures"}) do
    Widget[name] = function() end
end
local function button()
    local w = Widget(); w.text = Widget()
    w.animstate = {IsCurrentAnimation = function() return false end, PlayAnimation = function() end}
    return w
end
package.preload["widgets/widget"] = function() return Widget end
for _, module in ipairs({"imagebutton", "text", "uianim", "uianimbutton"}) do
    package.preload["widgets/" .. module] = function() return button end
end
TEMPLATES = {}; ImageButton = button
UICOLOURS = {GOLD = {}, BLACK = {}, HIGHLIGHT_GOLD = {}}
MOVE_UP = "up"; MOVE_DOWN = "down"; MOVE_RIGHT = "right"
assert(loadstring(checkbox_source))()
package.loaded["widgets/redux/templates"] = TEMPLATES
local controller = false
TheInput = {ControllerAttached = function() return controller end, GetControllerID = function() return 0 end, GetLocalizedControl = function() return "inspect" end}
local hud_enabled = true
Profile = {GetScrapbookHudDisplay = function() return hud_enabled end}
local sounds = 0
TheFrontEnd = {GetSound = function() return {PlaySound = function() sounds = sounds + 1 end} end}
ThePlayer = entity(); ThePlayer.prefab = "wx78"; ThePlayer.player_classified = {}; ThePlayer.HUD = {focus = true}
ThePlayer.components = {}
install(-6, true)
TheSkillTree = data(); TheSkillTree.skillxp.wx78 = 160
local SkillTreeUpdater = require("components/skilltreeupdater")
local updater = SkillTreeUpdater(ThePlayer); updater.skilltree = TheSkillTree
ThePlayer.components.skilltreeupdater = updater
local SkillTreeToast = require("widgets/skilltreetoast")
local toast = SkillTreeToast(ThePlayer, {ManageToast = function() end})
hooks["widgets/skilltreetoast"](toast)
local function builder(prefab, readonly)
    local b = {root = Widget(), buttongrid = {}, SetFocusChangeDirs = function() end, buildbuttons = function() end}
    b.CreateTree = function(self, target, targetdata, read) self.target = target; self.readonly = read end
    hooks["widgets/redux/skilltreebuilder"](b)
    b:CreateTree(prefab, {}, readonly)
    return b
end
local b = builder("wx78", false)
equal(b.muteskilltoast2hm.checked, false, "mute defaults off")
updater:AddSkillXP(1)
equal(toast.opened, true, "normal unused-point alert")
local before = TheSkillTree:GetAvailableSkillPoints("wx78")
b.muteskilltoast2hm.onclick()
equal(toast.opened, false, "mute immediately closes alert")
equal(toast.tab_gift:IsVisible(), false, "mute hides tab")
local quietsounds = sounds
updater:AddSkillXP(1)
equal(toast.opened, false, "daily event stays muted")
equal(sounds, quietsounds, "muted daily event makes no sound")
equal(TheSkillTree:GetAvailableSkillPoints("wx78"), before, "mute preserves available points")
equal(saved_preferences.mutedskilltoasts.wx78, true, "preference saved")
TUNING.TEMP2HM = deepcopy(saved_preferences)
equal(builder("wx78", false).muteskilltoast2hm.checked, true, "reopening restores preference")
equal(builder("willow", false).muteskilltoast2hm.checked, false, "preference is per character")
equal(builder("wx78", true).muteskilltoast2hm, nil, "other player has no toggle")
b.muteskilltoast2hm.onclick()
equal(toast.opened, true, "unmute restores alert")
hud_enabled = false; toast:UpdateElements()
equal(toast.opened, false, "existing global HUD preference respected")
hud_enabled = true; toast:UpdateElements()
TheSkillTree.activatedskills.wx78 = allskills("wx78")
ThePlayer:PushEvent("onactivateskill_client")
equal(toast.opened, false, "learning final skill dismisses stale alert")
updater:AddSkillXP(1)
equal(toast.opened, false, "full tree never reopens alert")
local top = button(); b.buttongrid = {{x = 0, y = 100, button = top}}
b:SetFocusChangeDirs()
equal(top.dirs.up, b.muteskilltoast2hm, "controller reaches toggle")
equal(b.muteskilltoast2hm.dirs.down, top, "controller returns to tree")

TheSkillTree.activatedskills.wx78 = nil
controller = true
toast:UpdateElements()
equal(toast.opened, true, "controller alert opens")
equal(toast.updating, true, "controller help starts updating")
b.muteskilltoast2hm.onclick()
equal(toast.opened, false, "controller alert closes on mute")
equal(toast.controller_help:IsVisible(), false, "controller help hides on mute")
equal(toast.updating, false, "controller help stops updating on mute")
toast:OnUpdate()
TheSkillTree.skillxp.wx78 = 0
updater:AddSkillXP(TUNING.SKILL_THRESHOLDS[1])
equal(TheSkillTree:GetAvailableSkillPoints("wx78"), 1, "muted character still earns points")
equal(toast.opened, false, "earned point remains silent")
TheSkillTree.skillxp.wx78 = 160
controller = false

-- The real backup handshake nests AddSkillXP: its raw-XP bypass must survive.
TheSkillTree.activatedskills = {}
TheWorld.state.cycles = 0
TheSkillTree:OPAH_DoBackup()
equal(TheSkillTree.ignorexp, true, "backup handshake enters ignore-XP mode")
equal(TheSkillTree.disablehardxp2hm, nil, "nested backup restores bypass flag")
equal(TheSkillTree.skillxp.wx78, 160, "backup preserves historical XP")
equal(TheSkillTree:GetAvailableSkillPoints("wx78"), 5, "backup restores day restriction")
print("PASS: " .. assertions .. " assertions (Lua 5.1; real game data/updater/toast; stubbed engine/rendering).")
