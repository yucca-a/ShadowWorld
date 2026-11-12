local M = {}
local combatconfig = require("combatconfig2hm")
local umOptions = {
    um_weather_particles2hm = true,
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
                local saved = combatconfig.MigrateSaved(option.name, option.saved)
                if option.name == "epic_ruin" and saved == 1 then
                    saved = option.default
                elseif option.name == "World Exchange" and (saved == "traditional" or saved == false) then
                    saved = option.default
                elseif option.name == "um_patch" and (saved == 1 or saved == 2 or saved == 3) then
                    saved = true
                elseif option.name == "dragonfly furnace stewer" and saved == -1 then
                    saved = true
                end
                if saved ~= option.saved then
                    local migrated = {}
                    for key, value in pairs(option) do migrated[key] = value end
                    migrated.saved = saved
                    table.insert(visible, migrated)
                elseif option.name == "wx78_easy" or option.name == "wx-78" or (hideUMOptions and umOptions[option.name]) then
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
            -- 原生标题隐藏 Spinner 后仍沿用左列右对齐；只调整本模组，滚动复用时恢复普通行。
            local scroll = self.options_scroll_list
            if scroll and scroll.update_fn and scroll.GetScrollRegionSize then
                local update = scroll.update_fn
                local layouts = {}
                scroll.update_fn = function(context, widget, data, ...)
                    local label = widget.opt.label
                    local layout = layouts[label]
                    if not layout then
                        local width, height = label:GetRegionSize()
                        layout = {position = label:GetPosition(), width = width, height = height}
                        layouts[label] = layout
                    end
                    label:SetPosition(layout.position)
                    label:SetRegionSize(layout.width, layout.height)
                    label:SetHAlign(G.ANCHOR_RIGHT)
                    local result = update(context, widget, data, ...)
                    if data and data.is_header then
                        label:SetPosition(0, layout.position.y, layout.position.z)
                        label:SetRegionSize(scroll:GetScrollRegionSize(), layout.height)
                        label:SetHAlign(G.ANCHOR_MIDDLE)
                    end
                    return result
                end
                scroll:RefreshView()
            end
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
