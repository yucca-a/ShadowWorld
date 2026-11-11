-- Configuration rating, not a measurement of a player's skill or world progress.
local M = {}
local Resolve = require("combatconfig2hm").Resolve
local groups = {role_nerf = true, weather_change = true, other_change = true,
    food_change = true, monster_change = true, extra_change = true}
local bear = { ["种地种树需要书"] = true, ["做饭需要书"] = true,
    ["材料制造翻倍"] = true, ["低san采集失败"] = true, ["捡东西变慢"] = true }
local ed = { ["料理禁止堆叠"] = true, ["护甲失效"] = true,
    ["难以冻结"] = true, ["下雨禁火"] = true }
-- Alternative mechanics with no defensible harder/easier ordering are neutral.
local neutral = {clockwork_guard = true, old_alterguardian = true, warly = true}
local full = {death_curse = true, wickerbottom = true, moonisland = true,
    winter_change = true, moonrockidol = true, oceanlife = true, cave_entrance = true,
    ancient_altar = true, oceanfish_change = true, wall_destroy = true,
    deerclops = true, shadowchesspieces = true}
local extra_parents = {shadow_rift = "shadowthrall", pig_boss = "poor_armor",
    banicetiles = "alterguardian", old_alterguardian = "alterguardian"}
local um_only = {wixie = true, ["UM Widow"] = true}
local multipliers = {boss_health = true, boss_speed = true, boss_attackanim = true,
    boss_attackspeed = true, boss_attackrange = true, boss_damage = true,
    notboss_health = true, notboss_speed = true, notboss_attackanim = true,
    notboss_attackspeed = true, notboss_attackrange = true, notboss_damage = true,
    ["Monster Harder Level"] = true}

local function enabled(v) return v ~= nil and v ~= false end

local function rank(name, value)
    value = Resolve(name, value)
    if not enabled(value) then return 0 end
    if name == "banicetiles" then return -1 end -- Removes a boss attack.
    if name == "norunattack" then return 1 + value end -- Zero still enables animation-matched attacks.
    -- Mechanism switches aren't numeric tiers relative to the new defaults.
    if name == "combat" or name == "epic_armor_5" then return 1 end
    if name == "minotaur" then return value == true and 2 or value end
    if name == "epic_ruin" then return value == "full" and 1 or value == 1 and 0.8 or value end
    if multipliers[name] then return value - 1 end -- x1 does not add difficulty.
    if name == "leader" then return 1 / value end -- Smaller follower cap is harder.
    if name == "boss_maxdamagetake" or name == "notboss_maxdamagetake" then return 1 / value end
    if name == "shengwuqishilu" or name == "shengwuqishilu2" or name == "shengwuqishilu3" then
        return 1 / value -- Shorter growth period is harder.
    end
    if name == "notboss_range" then return value == true and 0 or 1 end
    if name == "nutrient" then return value == true and 3 or -value end
    if name == "container_live" or name == "chess" then return value == true and 1 or 2 end
    if name == "dusk_change" then return value == -1 and 3 or (value == true and 2 or 1) end
    if name == "random_seasons" then return ({[-1] = 2, [-2] = 1, [-3] = 3, [-4] = 4, [-5] = 5})[value] end
    if name == "alterguardian" then return ({[-1] = 1, [-2] = 2, [-3] = 3, [-5] = 5, [-4] = 4})[value] end
    if name == "atriumstalker" then return ({[true] = 2, [-1] = 3, [-2] = 1})[value] end
    if name == "recipe_add_material" then return value == 1 and 2 or 1 end
    if name == "worldgen" then return value == true and 3 or -value end
    if full[name] then return value == true and 2 or 1 end
    if value == true then return 1 end
    if type(value) == "number" then return math.abs(value) end
end

function M.Evaluate(get, options, context)
    if type(options) ~= "table" or #options == 0 then return nil end
    context = context or {}
    local schema, state = {}, {}
    for _, option in ipairs(options) do
        if option.name and option.name ~= "" then
            schema[option.name] = option
            local v = get(option.name)
            if v == nil then v = option.default end
            state[option.name] = Resolve(option.name, v)
        end
    end
    if schema["enable hard mode"] == nil then return nil end
    local function active(name, defaults)
        local option = schema[name]
        if not option then return false end
        local value = defaults and option.default
        if not defaults then value = state[name] end
        return enabled(value) and not (name == "minotaur" and value == 0)
    end
    local function effective(name, parent, defaults)
        if um_only[name] and not context.um then return 0 end
        if parent then
            if not active(parent, defaults) then return 0 end
            if groups[parent] and not active("enable hard mode", defaults) then return 0 end
        end
        local dependency = extra_parents[name]
        if dependency and not active(dependency, defaults) then return 0 end
        local value = defaults and schema[name].default
        if not defaults then value = state[name] end
        -- Non-BOSS scope only matters if at least one of its upgrades is effective.
        if name == "notboss_range" then
            local hasupgrade = false
            for key in pairs(schema) do
                if key ~= name and key:match("^notboss_") and active(key, defaults) then
                    local v = defaults and schema[key].default
                    if not defaults then v = state[key] end
                    if (rank(key, v) or 0) > 0 then hasupgrade = true break end
                end
            end
            if not hasupgrade then return 0 end
            return value == false and 1 or 0
        end
        return rank(name, value)
    end
    local result = {raised = 0, lowered = 0, disabled = 0, net = 0, details = {}}
    local parent
    for _, option in ipairs(options) do
        local name = option.name
        if groups[name] then parent = name end
        local owner = parent
        local include = parent ~= nil and name ~= "" and not groups[name] and not neutral[name]
        if name == "贝爷求生" then include, owner = true, nil end -- bundled core mechanics count once.
        if bear[name] then include, owner = true, "贝爷求生" end
        if ed[name] then include, owner = true, "德爷生存" end
        if name == "shengwuqishilu" or name == "shengwuqishilu2" or name == "shengwuqishilu3" then
            owner = "enable hard mode"
        end
        if include then
            local baseline = effective(name, owner, true)
            local current = effective(name, owner, false)
            if baseline and current and math.abs(current - baseline) > 0.000001 then
                local direction = current > baseline and 1 or -1
                if direction > 0 then result.raised = result.raised + 1
                else result.lowered = result.lowered + 1 end
                if baseline > 0 and current == 0 then result.disabled = result.disabled + 1 end
                result.net = result.net + direction
                result.details[#result.details + 1] = {name = name, direction = direction}
            end
        end
    end
    result.level = result.net >= 7 and "hell" or result.net >= 4 and "hard"
        or result.net <= -5 and "easy" or "default"
    return result
end

function M.Format(result, chinese)
    if not result then
        return chinese and "[淬炼] 暂时无法读取难度设置，请稍后用 /nd 重试。"
            or "[Tempering] Difficulty settings unavailable. Retry /nd shortly."
    end
    if chinese then
        local names = {easy = "简单", default = "默认", hard = "困难", hell = "地狱"}
        return string.format("[淬炼] 难度：%s｜上调 %d 项，下调 %d 项（含关闭 %d 项），净变化 %+d。\n相对本模组默认设置；同一项只计一次。", 
            names[result.level], result.raised, result.lowered, result.disabled, result.net)
    end
    local names = {easy = "Easy", default = "Default", hard = "Hard", hell = "Hell"}
    return string.format("[Tempering] Difficulty: %s | Raised %d, lowered %d (disabled %d), net %+d.\nRelative to mod defaults; each setting counts once.",
        names[result.level], result.raised, result.lowered, result.disabled, result.net)
end

function M.InstallConsole(screen, request)
    local Run = screen.Run
    function screen:Run(...)
        if self.console_edit:GetString():lower():match("^%s*/nd%s*$") then return request() end
        return Run(self, ...)
    end
end

return M
