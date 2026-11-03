-- 下列代码来自于BOSS血条
for i, v in ipairs({"_G", "setmetatable", "rawget"}) do env[v] = GLOBAL[v] end

setmetatable(env, {__index = function(table, key) return rawget(_G, key) end})

modpath = package.path:match("([^;]+)")
package.path = package.path:sub(#modpath + 2) .. ";" .. modpath

-- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\

local mem = setmetatable({}, {__mode = "v"})
local function argtohash(...)
    local str = "";
    for i, v in ipairs(arg) do str = str .. tostring(v) end
    return hash(str)
end
local function memget(...) return mem[argtohash(...)] end
local function memset(value, ...) mem[argtohash(...)] = value end

local HappyPatch2hm = {
    Dummy = function() end,

    Parallel = function(root, key, fn, lowprio)
        if type(root) == "table" then
            local oldfn = root[key]
            local newfn = oldfn and memget("PARALLEL", oldfn, fn)
            if not oldfn or newfn then
                root[key] = newfn or fn
            else
                if lowprio then
                    root[key] = function(...)
                        oldfn(...)
                        return fn(...)
                    end
                else
                    root[key] = function(...)
                        fn(...)
                        return oldfn(...)
                    end
                end
                memset(root[key], "PARALLEL", oldfn, fn)
            end
        end
    end,

    Branch = function(root, key, fn)
        if type(root) == "table" then
            local oldfn = root[key]
            if oldfn then
                local newfn = memget("BRANCH", oldfn, fn)
                if newfn then
                    root[key] = newfn
                else
                    root[key] = function(...) return fn(oldfn, ...) end
                    memset(root[key], "BRANCH", oldfn, fn)
                end
            end
        end
    end
}

-- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\

-- local locale = LanguageTranslator ~= nil and LanguageTranslator.defaultlang or TheNet:GetLanguageCode()
-- if type(locale) == "string" then modinfo.SetLocale(locale, modinfo) end

local success, ModConfigurationScreen = pcall(require, "screens/redux/modconfigurationscreen")
local success2, ImageButton = pcall(require, "widgets/imagebutton")
if success and success2 and not ModConfigurationScreen._happypatch2hm then
    ModConfigurationScreen._happypatch2hm = true
    HappyPatch2hm.Branch(ModConfigurationScreen, "_ctor", function(ctor, self, _modname, client_config, ...)
        local result = ctor(self, _modname, client_config, ...)
        local total = self.optionwidgets and #self.optionwidgets
        if self.options_scroll_list and total and total >= 40 then
            local headeritems = {}
            for i, data in ipairs(self.optionwidgets) do
                if data and data.is_header and data.option then
                    table.insert(headeritems, {i = i, option = data.option.label or data.option.name or ""})
                end
            end
            local lastoption
            local laststep
            local lastdata
            local stepoptions = {}
            for _, data in ipairs(headeritems) do
                local key = data.i
                if lastoption == nil then
                    lastoption = key
                    laststep = key
                    lastdata = data
                    table.insert(stepoptions, data)
                else
                    if key ~= lastoption + 1 then
                        if key - laststep >= 2 then
                            -- 首个header选项
                            laststep = key
                            lastdata = data
                            table.insert(stepoptions, data)
                        end
                    elseif lastdata and lastdata.option == "" then
                        -- 连续header选项，排除其中的空白
                        if data.option ~= "" then
                            lastdata.i = key
                            lastdata.option = data.option
                        end
                    end
                    lastoption = key
                end
            end
            local start = self.options_scroll_list:GetSlideStart()
            local range = self.options_scroll_list:GetSlideRange()
            for _, data in ipairs(stepoptions) do
                local key = data.i
                local btn = self.options_scroll_list.scroll_bar_container:AddChild(ImageButton("images/global_redux.xml", "scrollbar_handle.tex"))
                btn.show_stuff = true
                self["stepbtn2hm" .. key] = btn
                btn:SetScale(0.15, 0.15, 1)
                local height = start - range * key / total
                btn:SetPosition(0, height)
                local txt = data.option
                if txt == "" then txt = STRINGS.UI.MODSSCREEN.UNKNOWN_MOD_CONFIG_SETTING end
                btn:SetHoverText(txt)
                -- 强行跳转到对应位置
                btn:SetOnDown(function()
                    self.options_scroll_list:ScrollToDataIndex(data.i)
                    local currentindex = data.i - self.options_scroll_list.displayed_start_index
                    if currentindex > 3 then for i = 1, currentindex - 3 do self.options_scroll_list:GetNextWidget(2) end end
                end)
            end
            self.options_scroll_list.position_marker:MoveToFront()
        end
        return result
    end)

    -- -- 模组更新会把一些值为false/true的选项的值改成false/-1/-2,因此兼容(已废弃)
    -- HappyPatch2hm.Branch(ModConfigurationScreen, "CollectSettings", function(CollectSettings, self, ...)
    --     local settings = CollectSettings(self, ...)
    --     if self.modname == modname and self.dialog then
    --         --     for index, setdata in ipairs(settings) do
    --         --         if setdata.saved == true and setdata.default and type(setdata.default) == "number" and setdata.default < 0 then
    --         --             setdata.saved = setdata.default
    --         --         end
    --         --     end
    --     end
    --     return settings
    -- end)

    -- HappyPatch2hm.Parallel(ModConfigurationScreen, "Apply", function(self)
    -- 	if self._happypatch2hm then
    -- 		KnownModIndex:SaveConfigurationOptions(HappyPatch2hm.Dummy, self.modname, self:CollectSettings(), false)
    -- 	end
    -- end)
end

-- Keep Wixie-only options conditional on the enabled server mods.
GLOBAL.require("wixieconfig2hm").Install(GLOBAL, modname)
