local M = {}
local defaults = {combat = 4, epic_armor_5 = "dynamic"}

-- Numeric 1 is the historical default cached by the game. A fresh explicit
-- traditional-tier-1 selection has its own token, so it survives future loads.
function M.MigrateSaved(name, value)
    if defaults[name] ~= nil and (value == 1 or value == true) then return defaults[name] end
    return value
end

function M.Resolve(name, value)
    value = M.MigrateSaved(name, value)
    if defaults[name] ~= nil and value == "traditional_1" then return 1 end
    return value
end

function M.Wrap(get)
    return function(name, ...)
        return M.Resolve(name, get(name, ...))
    end
end

return M
