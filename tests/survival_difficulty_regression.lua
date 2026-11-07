local count = 0
local function check(ok, message)
    count = count + 1
    assert(ok, message or ("check " .. count))
end
local function run(source, env)
    setmetatable(env, {__index = _G})
    setfenv(assert(loadstring(source)), env)()
    return env
end
local info = run(mod_sources["modinfo.lua"], {locale = "zh"})
local options, schema = info.configuration_options, {}
for _, option in ipairs(options) do if option.name ~= "" then schema[option.name] = option end end
local Rating = require("difficultyrating2hm")
local function evaluate(overrides, um)
    return Rating.Evaluate(function(name)
        if overrides and overrides[name] ~= nil then return overrides[name] end
        return schema[name] and schema[name].default
    end, options, {um = um})
end
for _, um in ipairs({true, false}) do
    local r = evaluate(nil, um)
    check(r.level == "default" and r.net == 0 and r.raised == 0 and r.lowered == 0, "All defaults must rate Default")
end
check(schema["贝爷求生"].default == false and schema["德爷生存"].default == false, "Both masters default off")
check(evaluate({["贝爷求生"] = 1}).raised == 1, "Bear core counts once")
check(evaluate({["德爷生存"] = 1}).raised == 2, "Ed enables the two default hard mechanics")
check(evaluate({["种地种树需要书"] = 1, ["护甲失效"] = 1}).net == 0, "Disabled survival masters mask suboptions")
local upgrades = {"temperature_change", "rain_change", "fooddata_change", "cooking_change", "rocks_change", "animal_change", "plant_change"}
local values = {-2, -2, -2, -2, 3, 9, 9}
local changed = {}
for i, name in ipairs(upgrades) do
    changed[name] = values[i]
    local r = evaluate(changed)
    check(r.raised == i and r.net == i, "Each upward setting counts once")
    check(r.level == (i >= 7 and "hell" or i >= 4 and "hard" or "default"), "Upper thresholds")
end
changed.rocks_change = 16
check(evaluate(changed).raised == 7, "Larger tier jumps still count once")
for i, name in ipairs(upgrades) do
    local down = {}
    for j = 1, i do down[upgrades[j]] = false end
    local r = evaluate(down)
    check(r.disabled == i and r.lowered == i and r.net == -i, "Disabled count")
    check(r.level == (i >= 5 and "easy" or "default"), "Lower threshold")
end
for _, master in ipairs({"role_nerf", "weather_change", "other_change", "food_change", "monster_change", "enable hard mode"}) do
    local r = evaluate({[master] = false})
    check(r.lowered >= 5 and r.level == "easy", "Master disables effective children: " .. master)
    for _, detail in ipairs(r.details) do check(detail.name ~= master, "Do not double count master") end
end
check(evaluate({extra_change = false, boss_health = 50}).net == 0, "Inactive extra options")
check(evaluate({extra_change = true, boss_health = 1, boss_speed = 1, notboss_range = false}).net == 0, "x1 upgrades have no effect")
check(evaluate({extra_change = true, boss_health = 2}).net == 1, "Enabled optional extra parent does not double count")
check(evaluate({extra_change = true, notboss_health = 2, notboss_range = false}).net == 2, "Non-boss scope has effect with an upgrade")
check(evaluate({leader = 8}).raised == 1 and evaluate({leader = 20}).lowered == 1, "Follower-cap direction")
check(evaluate({norunattack = false}).lowered == 1, "Zero attack-delay tier still has a mechanic to disable")
check(evaluate({extra_change = true, boss_damagetake2 = 0.5}).raised == 1, "Damage reduction direction")
check(evaluate({extra_change = true, boss_maxdamagetake = 1000}).raised == 1, "Damage cap enables difficulty")
check(evaluate({shengwuqishilu = 140}).raised == 1, "Apocalypse gates on hard mode, not extras")
check(evaluate({["enable hard mode"] = false, shengwuqishilu = 140}).raised == 0, "Apocalypse obeys master")
check(evaluate({combat = 1, epic_armor_5 = true}).net == 0, "Legacy defaults migrate")
check(evaluate({epic_ruin = 1}).net == 0, "Legacy ruin default migrates like the gameplay implementation")
check(evaluate({epic_ruin = "full"}).raised == 1, "Explicit new 100% ruin tier")
check(evaluate({container_live = -1}).raised == 1, "Animal food stealing ignores distance at harder tier")
check(evaluate({chess = true}).lowered == 1, "Clockwork alternative restores the shorter regrowth time")
check(evaluate({combat = "traditional_1", epic_armor_5 = 5}).net == 0, "Alternative mechanisms are not arbitrary increases")
check(evaluate({banicetiles = true}).lowered == 1, "Ice ban direction")
check(evaluate({["Container Sort"] = false, ["Language In Game"] = -2, ["enable easy mode"] = false}).net == 0, "Convenience/UI settings excluded")
check(evaluate({shadowthrall = false, shadow_rift = true}).raised == 0, "Inactive rift child")
check(evaluate({poor_armor = false, pig_boss = true}).raised == 0, "Inactive pig-boss child")
check(evaluate({["UM Widow"] = false}, false).net == 0, "UM-only options excluded without UM")
check(Rating.Evaluate(function() end, {}) == nil, "Missing schema does not invent a default rating")
-- Every legal choice must evaluate without throwing, including numeric zero,
-- inverse caps, legacy mechanisms, duplicate display labels and inactive groups.
for name, option in pairs(schema) do
    for _, choice in ipairs(option.options) do
        for _, um in ipairs({true, false}) do
            local ok, r = pcall(evaluate, {[name] = choice.data}, um)
            check(ok and r and r.net == r.raised - r.lowered, "Legal choice: " .. name .. "=" .. tostring(choice.data))
        end
    end
end
-- RPC/command integration: requester identity is the only routing target.
local sent, serverhandlers, clienthandlers, commands, consolehooks = {}, {}, {}, {}, {}
local now = 10
local env = {
    modname = "TestTempering", TheWorld = {ismastersim = true}, TUNING = {isCh2hm = true},
    TheNet = {IsDedicated = function() return false end}, COMMAND_PERMISSION = {USER = 1},
    GetModConfigData = function(name) return schema[name] and schema[name].default end,
    KnownModIndex = {GetModInfo = function() return info end}, GetTime = function() return now end,
    GetClientModRPC = function(_, key) return key end, GetModRPC = function(_, key) return key end,
    AddModRPCHandler = function(_, key, fn) serverhandlers[key] = fn end,
    AddClientModRPCHandler = function(_, key, fn) clienthandlers[key] = fn end,
    AddUserCommand = function(key, data) commands[key] = data end,
    AddClassPostConstruct = function(_, fn) consolehooks[#consolehooks + 1] = fn end,
    SendModRPCToClient = function(...) sent[#sent + 1] = {...} end,
    SendModRPCToServer = function(key) sent[#sent + 1] = {key} end,
    ChatHistory = {SendCommandResponse = function(_, message) sent[#sent + 1] = {message} end},
}
run(mod_sources["common/difficulty.lua"], env)
check(#sent == 0, "No startup/join/periodic announcement")
local alice = {userid = "Alice", IsValid = function() return true end}
local bob = {userid = "Bob", IsValid = function() return true end}
serverhandlers.difficulty_query(alice, "Bob")
check(#sent == 1 and sent[1][2] == "Alice" and sent[1][3] == "default", "Cannot query-broadcast to another player")
serverhandlers.difficulty_query(alice)
check(#sent == 1, "Repeated requests throttled per player")
commands.nd.serverfn({}, bob)
check(#sent == 2 and sent[2][2] == "Bob", "Ordinary user slash command is private")
serverhandlers.difficulty_query(nil)
check(#sent == 2, "Server console without player cannot broadcast")
clienthandlers.difficulty_result("hell", 7, 0, 0, 7)
check(sent[3][1]:find("地狱") and sent[3][1]:find("上调 7"), "Private translated result")
local normal = 0
local screen = {Run = function() normal = normal + 1 end, console_edit = {GetString = function() return " /ND " end}}
consolehooks[1](screen)
screen:Run()
check(sent[4][1] == "difficulty_query" and normal == 0, "Console intercept ignores local/remote execution mode")
screen.console_edit.GetString = function() return "/wiki" end
screen:Run()
check(normal == 1, "Other console commands preserved")
check(commands.nd.permission == 1 and commands.nd.slash and not commands.nd.vote, "No administrator or vote requirement")
-- The merged modes must not install any hooks at all under default settings.
local imports = {}
local entry = mod_sources["modmain.lua"]:match("(%-%- Optional upstream survival modes.*)")
run(entry, {GetModConfigData = function(name) return schema[name] and schema[name].default end,
    modimport = function(name) imports[#imports + 1] = name end})
check(#imports == 1 and imports[1] == "common/difficulty.lua", "Default entry loads neither optional mode")
-- Deferred craft callbacks must block unlocks even after long craft times,
-- while unrelated blueprints and failed callbacks retain normal behavior.
local hooks = {}
run(mod_sources["ray/beye_actions.lua"], {
    GLOBAL = _G, AllRecipes = {tech = {level = {SCIENCE = 1}}, basic = {level = {SCIENCE = 0}}},
    GetModConfigData = function() return false end,
    AddComponentPostInit = function(name, fn) hooks[name] = hooks[name] or {}; table.insert(hooks[name], fn) end,
    AddPrefabPostInit = function() end,
})
local learned, pending = {}, nil
local builder = {
    AddRecipe = function(_, name) learned[name] = true; return "learned" end,
    MakeRecipe = function(_, recipe, pt, rot, skin, success) pending = success; return true end,
    BufferBuild = function(self, name) self:AddRecipe(name); return true end,
}
for _, fn in ipairs(hooks.builder) do fn(builder) end
check(builder:MakeRecipe({name = "tech"}, nil, nil, nil, function() builder:AddRecipe("tech") end), "Queue technological craft")
check(not builder.ray_zhizao_zhengzai_jiesuo, "No timed guard between crafting and success")
check(builder:AddRecipe("tech") == "learned", "Blueprint while slow craft is pending")
learned.tech = nil
pending()
check(learned.tech == nil and not builder.ray_zhizao_zhengzai_jiesuo, "Deferred success does not unlock tech")
check(builder:BufferBuild("tech") and learned.tech == nil, "Buildings cannot permanently unlock through BufferBuild")
check(builder:BufferBuild("basic") and learned.basic, "Basic recipes still unlock")
builder:MakeRecipe({name = "tech"}, nil, nil, nil, function() error("recipe failure") end)
check(not pcall(pending) and not builder.ray_zhizao_zhengzai_jiesuo, "Failure clears only its own guard and propagates")
builder:AddRecipe("tech")
check(learned.tech, "Blueprints still work after failure")
-- Preserve old player save references and allow loading a player with no data.
local init
local bear_source = mod_sources["ray/beye.lua"]
run(bear_source:sub(1, assert(bear_source:find('modimport("ray/beye_actions.lua")', 1, true)) - 1), {
    TheWorld = {ismastersim = true},
    AddPlayerPostInit = function(fn) init = fn end,
})
local player = {components = {reader = {}, grue = {AddImmunity = function() end}},
    HasTag = function() return false end, AddTag = function() end, ListenForEvent = function() end,
    OnSave = function(_, data) data.original = true; return {42} end,
    OnLoad = function(_, data) check(data == nil, "Original load receives nil unchanged") end,
    ray_zhizao_manufactured_items = {axe = 9}}
init(player)
local data = {}
local refs = player:OnSave(data)
check(refs[1] == 42 and data.original and data.ray_zhizao_manufactured_items.axe == 9, "Original references survive merged save hook")
player:OnLoad(nil)
check(player.ray_zhizao_manufactured_items == nil, "No-data old player does not crash")
print("SURVIVAL_DIFFICULTY_PASS " .. count .. " checks")
