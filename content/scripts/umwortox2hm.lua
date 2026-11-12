local Guard = require("umcompatguard2hm")
local M = {COOLDOWN = 120, TIMER = "wortox_reviver_cooldown2hm"}

function M.Install(env)
    local G = env.GLOBAL
    local config = G.rawget(G, "UM_CONFIG")
    if not G.ModManager:GetMod("workshop-3193922031") or not config or not config.WORTOX then return end
    local installed = false
    env.AddPlayerPostInit(function(inst)
        if not G.TheWorld.ismastersim or installed then return end
        local health = inst.components.health
        local chooser = Guard.Find(health.SetVal, "HasPocketResurrection")
        local trigger = Guard.Find(health.SetVal, "TriggerPocketResurrection")
        if not chooser or not trigger or not Guard.Known(chooser.value, "wortox_pocket_choose") or
            not Guard.Known(trigger.value, "wortox_pocket_trigger") then
            print("[ShadowWorld UM] wortox reviver cooldown skipped: upstream pocket resurrection changed")
            return
        end
        local ChooseItem, TriggerItem = chooser.value, trigger.value
        Guard.Replace(chooser, function(self)
            local item = ChooseItem(self)
            if item and item.prefab == "wortox_reviver" and self.inst.components.timer:TimerExists(M.TIMER) then return end
            return item
        end)
        Guard.Replace(trigger, function(self, item)
            -- Start before the resurrection event: its listeners may deal damage.
            if item.prefab == "wortox_reviver" then self.inst.components.timer:StartTimer(M.TIMER, M.COOLDOWN) end
            return TriggerItem(self, item)
        end)
        installed = true
    end)
end

return M
