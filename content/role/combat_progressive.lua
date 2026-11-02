local Calculator = require("progressivecombat2hm")
local Report = require("combatdisplay2hm")

-- Install at component creation so later prefab-specific CalcDamage wrappers
-- (e.g. Willow's special flames) remain outside this normal-attack calculator.
AddComponentPostInit("combat", function(combat)
    if not TheWorld.ismastersim then return end
    local previous = combat.CalcDamage
    combat.CalcDamage = function(self, target, weapon, multiplier, ...)
        if not self.inst:HasTag("player") then return previous(self, target, weapon, multiplier, ...) end
        local damage, special, report = Calculator.CalcDamage(self, target, weapon, multiplier)
        Report(self.inst, damage, special, report)
        return damage, special
    end
end)

local function InspectBag(inst)
    if not TheWorld.ismastersim or not inst.components.inspectable then return end
    local previous = inst.components.inspectable.GetDescription
    inst.components.inspectable.GetDescription = function(self, viewer, ...)
        local description, filter, author = previous(self, viewer, ...)
        if viewer and viewer:IsValid() and viewer.userid and viewer.components.combat then
            local combat = viewer.components.combat
            combat.inspectstatus2hm = not combat.inspectstatus2hm
            local enabled = combat.inspectstatus2hm
            description = (description or "") .. (TUNING.isCh2hm
                and (enabled and "\n[战斗险境]伤害显示已开启" or "\n[战斗险境]伤害显示已关闭")
                or (enabled and "\n[Combat] Damage display enabled" or "\n[Combat] Damage display disabled"))
        end
        return description, filter, author
    end
end
for _, prefab in ipairs({"punchingbag", "punchingbag_lunar", "punchingbag_shadow", "punchingbag_chaos"}) do
    AddPrefabPostInit(prefab, InspectBag)
end
