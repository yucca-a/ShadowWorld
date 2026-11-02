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

if success and not ModConfigurationScreen._happypatch2hm then
    ModConfigurationScreen._happypatch2hm = true

    -- HappyPatch2hm.Branch(ModConfigurationScreen, "_ctor", function(ctor, self, _modname, client_config, ...)
    --     if _modname == modname then
    --         self._happypatch2hm = true
    --         if 
    --      end
    --     return ctor(self, _modname, client_config, ...)
    -- end)

    -- 模组更新会把一些值为false/true的选项的值改成false/-1/-2,因此兼容(已废弃)
    HappyPatch2hm.Branch(ModConfigurationScreen, "CollectSettings", function(CollectSettings, self, ...)
        local settings = CollectSettings(self, ...)
        if self.modname == modname and self.dialog then
            --     for index, setdata in ipairs(settings) do
            --         if setdata.saved == true and setdata.default and type(setdata.default) == "number" and setdata.default < 0 then
            --             setdata.saved = setdata.default
            --         end
            --     end
        end
        return settings
    end)

    -- HappyPatch2hm.Parallel(ModConfigurationScreen, "Apply", function(self)
    -- 	if self._happypatch2hm then
    -- 		KnownModIndex:SaveConfigurationOptions(HappyPatch2hm.Dummy, self.modname, self:CollectSettings(), false)
    -- 	end
    -- end)
end
