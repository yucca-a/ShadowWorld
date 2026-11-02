if CONFIGS_LEGION then
    local function endtask(inst)
        inst.mod_hmlm_dmgmult = nil
        inst.components.combat.externaldamagetakenmultipliers:RemoveModifier(inst, "mod_hmlm_stask")
    end
    AddComponentPostInit("shieldlegion", function(self)
        self.Counterattack = function(self, doer, attacker, data, radius, dmgmult)
            if attacker == nil or not attacker:IsValid() or attacker.components.combat == nil or attacker.components.health == nil or
                attacker.components.health:IsDead() or doer:GetDistanceSqToPoint(attacker.Transform:GetWorldPosition()) > radius * radius then
                return false
            end
            local inst = doer
            if inst and inst.components.combat and dmgmult and dmgmult > (inst.mod_hmlm_dmgmult or 1) then
                inst.mod_hmlm_dmgmult = dmgmult
                inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, 1 / dmgmult, "mod_hmlm_stask")
                if inst.mod_hmlm_stask ~= nil then inst.mod_hmlm_stask:Cancel() end
                inst.mod_hmlm_stask = inst:DoTaskInTime(2, endtask)
            end
            return true
        end
    end)
end
