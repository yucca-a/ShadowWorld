-- local SetPrefabName = EntityScript.SetPrefabName
-- EntityScript.SetPrefabName = function(inst, ...)
--     SetPrefabName(inst, ...)
--     if inst:HasTag("flying") then inst.isflying2hm = true end
-- end
local function cancelflyingdamagetask2hm(inst) inst.flyingdamagetask2hm = nil end
local oldequipslots
AddComponentPostInit("inventory", function(self)
    if not self.inst:HasTag("player") then return end
    local ApplyDamage = self.ApplyDamage
    self.ApplyDamage = function(self, damage, attacker, weapon, spdamage, ...)
        if damage and damage > 0 and attacker and attacker:IsValid() and attacker:HasTag("flying") and not attacker:HasTag("antlion") and
            (weapon == nil or (weapon.components.projectile == nil and (weapon.components.weapon == nil or weapon.components.weapon.projectile == nil))) and
            self.inst:IsNear(attacker, attacker:GetPhysicsRadius(0) + (attacker.components.combat and attacker.components.combat:GetHitRange() or 3)) then
            oldequipslots = self.equipslots
            self.equipslots = {}
            self.equipslots[EQUIPSLOTS.HEAD] = oldequipslots[EQUIPSLOTS.HEAD]
            self.equipslots[EQUIPSLOTS.HANDS] = oldequipslots[EQUIPSLOTS.HANDS]
            if oldequipslots[EQUIPSLOTS.BODY] and oldequipslots[EQUIPSLOTS.BODY].components.armor and
                not (oldequipslots[EQUIPSLOTS.HEAD] and oldequipslots[EQUIPSLOTS.HEAD].components.armor) and self.inst.components.talker and
                not self.inst.flyingdamagetask2hm then
                self.inst.flyingdamagetask2hm = self.inst:DoTaskInTime(10, cancelflyingdamagetask2hm)
                self.inst.components.talker:Say(TUNING.isCh2hm and "被攻击到头部了,好疼" or "My head is attacked,it hurts so much")
            end
        end
        local results = {ApplyDamage(self, damage, attacker, weapon, spdamage, ...)}
        if oldequipslots then
            oldequipslots[EQUIPSLOTS.HEAD] = self.equipslots[EQUIPSLOTS.HEAD]
            oldequipslots[EQUIPSLOTS.HANDS] = self.equipslots[EQUIPSLOTS.HANDS]
            self.equipslots = oldequipslots
            oldequipslots = nil
        end
        return unpack(results)
    end
end)
