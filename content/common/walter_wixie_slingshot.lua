-- UM removes Walter's native permissions even when Wixie's weapons are disabled.
-- Restore his own equipment independently of every optional character upgrade.
if not (TUNING.DSTU and TUNING.WIXIE_HEALTH) then return end
local wixieWeapons = GetModConfigData("Walter Use Wixie Slingshot")
local nativeSlingshots = {slingshot = true, slingshotex = true, slingshot2 = true, slingshot2ex = true}

AddPrefabPostInit("walter", function(inst)
    inst:AddTag("pebblemaker")
    inst:AddTag("slingshot_sharpshooter")
    inst:AddTag("allow_special_point_action_on_impassable")
    if wixieWeapons then inst:AddTag("troublemaker") end
end)

AddPrefabPostInit("slingshot", function(inst)
    if not TheWorld.ismastersim then return end
    local equip, weapon = inst.components.equippable, inst.components.weapon
    if equip == nil then return end
    -- The base slingshot is also tagged wixie_weapon by UM. It is still Walter's
    -- native weapon; leave linked-item ownership checks in the engine intact.
    equip.restrictedtag = "slingshot_sharpshooter"
    if weapon == nil then return end
    local onequip, onunequip = equip.onequipfn, equip.onunequipfn
    local original
    equip:SetOnEquip(function(inst, owner, ...)
        if owner.prefab == "walter" and original == nil then
            original = {weapon.damage, weapon.attackrange, weapon.hitrange}
            weapon:SetDamage(0)
            weapon:SetRange(TUNING.SLINGSHOT_DISTANCE, TUNING.SLINGSHOT_DISTANCE_MAX)
        end
        if onequip then return onequip(inst, owner, ...) end
    end)
    equip:SetOnUnequip(function(inst, owner, ...)
        if original ~= nil then
            weapon:SetDamage(original[1])
            weapon:SetRange(original[2], original[3])
            original = nil
        end
        if onunequip then return onunequip(inst, owner, ...) end
    end)
end)

AddPrefabPostInit("slingshotammo_container", function(inst)
    if TheWorld.ismastersim and inst.components.container then
        inst.components.container.restrictedtag = "slingshot_sharpshooter"
    end
end)

-- With the extra permission enabled, UM turns every slingshot ATTACK into a
-- shove. Keep Walter's four native variants on the normal shooting state.
local function RestoreNativeAttack(sg)
    local attack = sg.actionhandlers[ACTIONS.ATTACK]
    if attack == nil then return end
    local deststate = attack.deststate
    attack.deststate = function(inst, action, ...)
        local combat = inst.components.combat or inst.replica.combat
        local weapon = combat and combat:GetWeapon()
        if inst.prefab == "walter" and weapon and nativeSlingshots[weapon.prefab] and inst:HasTag("troublemaker") then
            local controller = inst.components.playercontroller
            local tag = controller and controller.remote_authority and controller.remote_predicting and "abouttoattack" or "attack"
            if not (inst.sg:HasStateTag(tag) and action.target == inst.sg.statemem.attacktarget or IsEntityDead(inst)) then
                inst.sg.mem.localchainattack = true
                return "slingshot_shoot"
            end
            return
        end
        return deststate(inst, action, ...)
    end
end
AddStategraphPostInit("wilson", RestoreNativeAttack)
AddStategraphPostInit("wilson_client", RestoreNativeAttack)

if not wixieWeapons then return end

-- UM routes troublemakers to Wixie's wardrobe on a fresh spawn. Walter should
-- retain his own spawn path even when he is allowed to use Wixie's weapons.
AddComponentPostInit("playerspawner", function(self)
    local SpawnAtLocation = self.SpawnAtLocation
    self.SpawnAtLocation = function(self, inst, player, ...)
        local restore = player ~= nil and player:IsValid() and player.prefab == "walter" and player:HasTag("troublemaker")
        if restore then player:RemoveTag("troublemaker") end
        local result = SpawnAtLocation(self, inst, player, ...)
        if restore then player:AddTag("troublemaker") end
        return result
    end
end)
