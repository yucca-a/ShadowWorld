local oldGetPVPEnabled = getmetatable(TheNet).__index["GetPVPEnabled"]
getmetatable(TheNet).__index["GetPVPEnabled"] = function(...)
    if TUNING.oldPVP2hm then
        return oldGetPVPEnabled(...)
    else
        return true
    end
end
-- AddComponentPostInit("health", function(self)
--     local oldDoDelta = self.DoDelta
--     self.DoDelta = function(self, amount, overtime, cause, ...)
--         return oldDoDelta(self, amount, overtime, cause and (type(cause) == "string" and cause or cause.prefab), ...)
--     end
-- end)
AddComponentPostInit("singinginspiration", function(self)
    local InstantInspire = self.InstantInspire
    self.InstantInspire = function(self, ...)
        local oldPVP2hm = TUNING.oldPVP2hm
        TUNING.oldPVP2hm = true
        InstantInspire(self, ...)
        TUNING.oldPVP2hm = oldPVP2hm
    end
    local Inspire = self.Inspire
    self.Inspire = function(self, ...)
        local oldPVP2hm = TUNING.oldPVP2hm
        TUNING.oldPVP2hm = true
        Inspire(self, ...)
        TUNING.oldPVP2hm = oldPVP2hm
    end
end)
local Combat = require("components/combat_replica") -- postinits do not seem to work.
local oldIsValidTarget = Combat.IsValidTarget
function Combat:IsValidTarget(...)
    local oldPVP2hm = TUNING.oldPVP2hm
    TUNING.oldPVP2hm = true
    local res = oldIsValidTarget(self, ...)
    TUNING.oldPVP2hm = oldPVP2hm
    return res
end
local oldCanTarget = Combat.CanTarget
function Combat:CanTarget(...)
    local oldPVP2hm = TUNING.oldPVP2hm
    TUNING.oldPVP2hm = true
    local res = oldCanTarget(self, ...)
    TUNING.oldPVP2hm = oldPVP2hm
    return res
end
local oldCanBeAttacked = Combat.CanBeAttacked
function Combat:CanBeAttacked(...)
    local oldPVP2hm = TUNING.oldPVP2hm
    TUNING.oldPVP2hm = true
    local res = oldCanBeAttacked(self, ...)
    TUNING.oldPVP2hm = oldPVP2hm
    return res
end
