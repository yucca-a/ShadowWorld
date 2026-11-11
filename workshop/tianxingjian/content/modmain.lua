local Assist = require("soloassist2hm")
local G = GLOBAL
local function Attach(owner)
    if owner and owner:IsValid() then
        Assist.Attach(owner, {
            speed_key = G[GetModConfigData("speed_key") or "KEY_F6"] or G.KEY_F6,
            recover_key = G[GetModConfigData("recover_key") or "KEY_F7"] or G.KEY_F7,
        })
    end
end
AddClassPostConstruct("screens/playerhud", function(self)
    -- PlayerHud() has no owner yet; the game assigns it in SetMainCharacter.
    local SetMainCharacter = self.SetMainCharacter
    self.SetMainCharacter = function(hud, owner, ...)
        local result = SetMainCharacter(hud, owner, ...)
        if owner and owner:IsValid() then
            owner:DoTaskInTime(0, function() Attach(owner) end)
        end
        return result
    end
end)
