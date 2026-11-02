-- Native configuration selection + real mod hooks; rendering/network are simulated.
local count = 0
local function check(value, message)
    count = count + 1
    assert(value, message)
end
local function equal(actual, expected, message) check(actual == expected, message) end
local native_getconfig = GetModConfigData
function deepcopy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for k, v in pairs(value) do copy[k] = deepcopy(v) end
    return copy
end
function IsTableEmpty(value) return next(value) == nil end
GLOBAL = {GetModConfigData = native_getconfig}
CONTROL_PRIMARY, CONTROL_SECONDARY, CONTROL_CANCEL, CONTROL_MAP = 1, 2, 3, 4

local function setup(settings)
    settings = settings or {}
    local state = {screens = {}, hooks = {}, saves = 0, imports = {}}
    TUNING = {TEMP2HM = {}, isCh2hm = true}
    TUNING.TEMP2HM.openmods = settings.openmods
    STRINGS = {UI = {MODSSCREEN = {SERVERMODS = "Server Mods", CONFIGSCREENTITLESUFFIX = "Configure", RESETDEFAULT = "Reset"}, HELP = {BACK = "Back"}}}
    TheNet = setmetatable({}, {__index = {
        IsDedicated = function() return settings.dedicated == true end,
        GetIsServer = function() return not settings.client end,
        GetIsClient = function() return settings.client == true end,
        GetServerIsClientHosted = function() return false end,
        GetIsServerAdmin = function() return false end,
        GetServerListing = function() return state.listing end,
        Say = function(_, message) state.last_chat = message end,
    }})
    TheSim = {
        GetScreenSize = function() return 1920, 1080 end,
        GetPersistentString = function(_, _, callback) callback(false, "") end,
        SetPersistentString = function() state.saves = state.saves + 1 end,
    }
    TheInput = {
        GetControllerID = function() return 0 end,
        GetLocalizedControl = function() return "Mouse" end,
        ControllerAttached = function() return false end,
    }
    TheFrontEnd = {
        PushScreen = function(_, screen) table.insert(state.screens, screen) end,
        PopScreen = function() table.remove(state.screens) end,
    }
    GetInventoryItemAtlas = function() return "images/inventoryimages.xml" end
    RunInSandboxSafe = function(text)
        local fn = loadstring(text)
        if not fn then return false end
        return pcall(setfenv(fn, {}))
    end
    DataDumper = function() return "return {}" end
    GetModConfigData = function(name)
        if name == "Show Mod Icon In Game" then return settings.enabled ~= false end
    end
    AddClassPostConstruct = function(name, fn) state.hooks[name] = fn end
    modimport = function(path) table.insert(state.imports, path) end

    local default_options = {
        {name = "enabled", default = true, saved = true, options = {{data = false}, {data = true}}},
        {name = "amount", default = 1, saved = 99, options = {{data = 0}, {data = 7}, {data = 99}}},
        {name = "mode", default = "default", options = {{data = "world"}, {data = "network"}}},
    }
    local function known(name, client_only, require_all)
        return {modinfo = {name = name, client_only_mod = client_only, all_clients_require_mod = require_all,
            configuration_options = deepcopy(default_options)}, temp_config_options = {
            {name = "enabled", default = true, saved_server = false},
            {name = "amount", default = 1, saved_server = 0, saved_client = 99},
            {name = "mode", default = "default", saved = "world"},
        }}
    end
    KnownModIndex = setmetatable({savedata = {known_mods = {
        worldmod = known("World Mod", false, true),
        servermod = known("Server Mod", false, false),
        clientmod = known("Client Mod", true, false),
        disabledmod = known("Disabled Mod", false, true),
    }}}, {__index = ModIndex})
    KnownModIndex.LoadModConfigurationOptions = function(self, name)
        local info = self:GetModInfo(name)
        return info and info.configuration_options
    end
    state.original_loader = KnownModIndex.LoadModConfigurationOptions
    ModManager = setmetatable({worldgen = false, mods = {{modname = "worldmod"}, {modname = "servermod"}, {modname = "clientmod"}}}, {__index = ModWrangler})

    local Screen = Class(nil, function(self, modname, client_config)
        native_screen_options(self, modname, client_config)
        self.optionwidgets = {}
        for i in ipairs(self.options) do self.optionwidgets[i] = {} end
        self.options_scroll_list = {RefreshView = function() end}
        self.dialog = {actions = {items = {{Hide = function() self.apply_hidden = true end}}}}
    end)
    Screen._base = {OnControl = function() return false end}
    package.loaded["screens/redux/modconfigurationscreen"] = Screen
    package.loaded["screens/redux/textlistpopup"] = function(items, title) return {items = items, title = title} end
    package.loaded["widgets/imagebutton"] = function()
        return {
            OnControl = function() return false end,
            SetTextures = function() end,
            SetTooltip = function(self, text) self.tooltip = text end,
            SetPosition = function(self, x, y, z) self.position = {x = x, y = y, z = z} end,
            SetOnDown = function(self, fn) self.ondown = fn end,
            SetOnClick = function(self, fn) self.onclick = fn end,
        }
    end
    state.host = function(name)
        local host = {AddChild = function(_, child) return child end}
        state.hooks[name or "widgets/controls"](host)
        return host
    end
    state.load = function()
        assert(loadstring(ui_import_source))()
        for _, path in ipairs(state.imports) do
            equal(path, "easy_other/ui.lua", "correct UI imported")
            assert(loadstring(ui_source))()
        end
    end
    return state
end

local function open_mod(state, host, text)
    host.btn2hm.onclick()
    local list = state.screens[#state.screens]
    for _, item in ipairs(list.items) do
        if item.text:find(text, 1, true) then
            check(item.onclick ~= nil, "configuration can be opened: " .. text)
            item.onclick()
            return state.screens[#state.screens], list
        end
    end
    error("mod missing from list: " .. text)
end
local function value(screen, name)
    for _, option in ipairs(screen.options) do if option.name == name then return option.value end end
end

-- Exact reported failure: offline host, no online role flags and no server listing.
local state = setup()
state.load()
check(state.hooks["widgets/controls"] ~= nil, "offline host must load the mod viewer")
local host = state.host()
check(host.btn2hm ~= nil, "offline HUD must display the icon without a server listing")
check(host.btn2hm.tooltip:find("显示模组", 1, true), "button tooltip is available")
local screen, list = open_mod(state, host, "World Mod")
equal(#list.items, 2, "only loaded world mods shown, excluding disabled/client-only mods")
equal(value(screen, "enabled"), false, "saved false must survive")
equal(value(screen, "amount"), 0, "saved zero must survive instead of local saved 99")
equal(value(screen, "mode"), "world", "world configuration is displayed")
check(screen.apply_hidden, "viewer is read-only")
equal(KnownModIndex.LoadModConfigurationOptions, state.original_loader, "configuration loader restored")
equal(STRINGS.UI.MODSSCREEN.CONFIGSCREENTITLESUFFIX, "Configure", "screen title restored")
equal(KnownModIndex:GetModInfo("worldmod").configuration_options[1].default, true, "original default unchanged")
equal(state.saves, 0, "opening configuration never writes a save")
screen:Cancel()
equal(state.screens[#state.screens], list, "back returns to mod list")

-- Lobby and partial listing: creation does not depend on listing readiness.
state = setup()
state.listing = {mods_description = {}}
state.load()
host = state.host("screens/redux/lobbyscreen")
check(host.btn2hm ~= nil, "offline lobby also displays the button")
screen = open_mod(state, host, "Server Mod")
equal(value(screen, "amount"), 0, "server-only local mod uses world settings")
equal(next(state.listing.mods_description), nil, "fallback does not mutate shared server listing")
equal(state.listing._processed_mods_config_data, nil, "fallback does not add a shared cache")

-- Online advertised settings win over local/runtime settings.
state = setup({client = true})
state.listing = {mods_description = {{mod_name = "worldmod", modinfo_name = "Advertised Mod"}},
    mods_config_data = 'return {worldmod = {enabled = false, amount = 7, mode = "network"}}'}
state.load()
host = state.host()
screen, list = open_mod(state, host, "Advertised Mod")
equal(#list.items, 1, "online advertised mod list is preserved")
equal(value(screen, "enabled"), false, "network false is preserved")
equal(value(screen, "amount"), 7, "online settings win over locally saved settings")
equal(value(screen, "mode"), "network", "advertised configuration displayed")
state.listing._processed_mods_config_data = {worldmod = {enabled = true, amount = 0, mode = "cached"}}
screen = open_mod(state, host, "Advertised Mod")
equal(value(screen, "mode"), "cached", "existing parsed cache has priority")
equal(value(screen, "amount"), 0, "cached zero preserved")

-- Late/changed server metadata is refreshed on each click.
state.listing = {mods_description = {{mod_name = "servermod", modinfo_name = "Updated Mod"}},
    mods_config_data = 'return {servermod = {mode = "updated"}}'}
screen = open_mod(state, host, "Updated Mod")
equal(value(screen, "mode"), "updated", "viewer does not retain the constructor's stale listing")

-- Missing, malformed and non-table config payloads must not crash the list.
for _, payload in ipairs({false, "invalid lua", "return 42", "error('bad data')"}) do
    state = setup()
    state.listing = {mods_description = {{mod_name = "worldmod", modinfo_name = "World Mod"}}, mods_config_data = payload}
    state.load()
    host = state.host()
    screen = open_mod(state, host, "World Mod")
    equal(value(screen, "amount"), 0, "missing/invalid network config falls back to actual world config")
end
state = setup({client = true})
KnownModIndex.savedata.known_mods.worldmod.temp_enabled = true
KnownModIndex.savedata.known_mods.worldmod.temp_config_options = {enabled = false, amount = 7, mode = "temporary"}
state.load()
screen = open_mod(state, state.host(), "World Mod")
equal(value(screen, "mode"), "temporary", "native client temp-config dictionary is supported")
equal(value(screen, "enabled"), false, "client temp false preserved")

-- Respect disabled/show/hide preferences and never load widgets on a dedicated server.
for _, settings in ipairs({{enabled = false}, {openmods = false}, {dedicated = true}}) do
    state = setup(settings)
    state.load()
    equal(#state.imports, 0, "disabled/dedicated environments must not import the viewer")
end
state = setup({enabled = false, openmods = true})
state.load()
check(state.host().btn2hm ~= nil, "explicit show preference overrides disabled default")

-- Offline chat commands still persist preferences for the next entry.
state = setup()
assert(loadstring(temp_source))()
TheNet:Say("显示模组")
equal(TUNING.TEMP2HM.openmods, true, "offline show command persists")
TheNet:Say("隐藏模组")
equal(TUNING.TEMP2HM.openmods, false, "offline hide command persists")
TheNet:Say("默认模组")
equal(TUNING.TEMP2HM.openmods, nil, "offline default command clears override")
equal(state.saves, 3, "each command saved once")
state = setup({dedicated = true})
assert(loadstring(temp_source))()
TheNet:Say("显示模组")
equal(state.saves, 0, "dedicated server does not intercept client UI commands")

print("Mod viewer regression: " .. count .. " assertions passed")
