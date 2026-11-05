local M = {}
local umOptions = {
    wixie = true,
    ["Wixie No Claustrophobia"] = true,
    ["Walter Use Wixie Slingshot"] = true,
    ["wathom nightvision"] = true,
}
local ids = {["workshop-2039181790"] = true, ["workshop-3193922031"] = true,
             ["2039181790"] = true, ["3193922031"] = true}

function M.IsUMEnabled(index)
    if index == nil or index.GetModsToLoad == nil then return false end
    for _, name in ipairs(index:GetModsToLoad() or {}) do
        if ids[name] then return true end
        local info = index.GetModInfo ~= nil and index:GetModInfo(name) or nil
        local title = info ~= nil and info.name or ""
        title = title:gsub("󰀕 ", ""):gsub("%[LOCAL%] %- ", "")
        if title == "Uncompromising Mode" or title == "Uncompromising Mode: Public Beta" then return true end
    end
    return false
end

function M.Install(G, modname)
    if G.TheNet ~= nil and G.TheNet:IsDedicated() then return end
    local class = G.require("screens/redux/modconfigurationscreen")
    if class.wixieconfigmods2hm ~= nil then
        class.wixieconfigmods2hm[modname] = true
        return
    end
    class.wixieconfigmods2hm = {[modname] = true}
    local constructor = class._ctor
    class._ctor = function(self, name, ...)
        local index = G.KnownModIndex
        if not class.wixieconfigmods2hm[name] or index == nil then
            return constructor(self, name, ...)
        end
        local hideUMOptions = not M.IsUMEnabled(index)
        -- Keep the runtime configuration intact while translating the displayed settings.
        local load = index.LoadModConfigurationOptions
        local hidden = {}
        index.LoadModConfigurationOptions = function(index, target, ...)
            local config = load(index, target, ...)
            if target ~= name or type(config) ~= "table" then return config end
            local visible = {}
            for _, option in ipairs(config) do
                if option.name == "um_patch" and (option.saved == 1 or option.saved == 2 or option.saved == 3) then
                    local migrated = {}
                    for key, value in pairs(option) do migrated[key] = value end
                    migrated.saved = true
                    table.insert(visible, migrated)
                elseif hideUMOptions and umOptions[option.name] then
                    local value = option.saved
                    if value == nil then value = option.default end
                    table.insert(hidden, {name = option.name, label = option.label, options = option.options,
                        default = option.default, saved = value})
                else
                    table.insert(visible, option)
                end
            end
            return visible
        end
        local function finish(ok, ...)
            index.LoadModConfigurationOptions = load
            if not ok then error((...), 0) end
            if #hidden == 0 then return ... end
            -- Saving another visible option must not erase hidden preferences.
            local collect = self.CollectSettings
            self.CollectSettings = function(screen, ...)
                local settings = collect(screen, ...) or {}
                for _, option in ipairs(hidden) do table.insert(settings, option) end
                return settings
            end
            return ...
        end
        return finish(pcall(constructor, self, name, ...))
    end
end

return M
