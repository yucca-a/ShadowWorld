-- UM removes Walter's native permissions even when Wixie's weapons are disabled.
-- Restore his own equipment independently of every optional character upgrade.
if not (TUNING.DSTU and TUNING.WIXIE_HEALTH) then return end
local wixieWeapons = GetModConfigData("Walter Use Wixie Slingshot")
local nativeSlingshots = {slingshot = true, slingshotex = true, slingshot999ex = true, slingshot2 = true, slingshot2ex = true}

-- UM replaces slingshot_charge on both graphs. Save the engine's State before
-- post-inits run so its charging owner, release events and prediction survive.
local nativeChargeName = "slingshot_charge_native2hm"
local function PreserveNativeCharge(sg)
    local state = sg.states.slingshot_charge
    if state == nil or not state.tags.aoecharging then return end
    local saved = {}
    for key, value in pairs(state) do saved[key] = value end
    setmetatable(saved, getmetatable(state))
    saved.name = nativeChargeName
    if state.server_states then saved.server_states = {[hash(nativeChargeName)] = true} end
    sg.states[nativeChargeName] = saved
end
local GetPostInitFns = ModManager.GetPostInitFns
ModManager.GetPostInitFns = function(self, kind, name, ...)
    local fns = GetPostInitFns(self, kind, name, ...)
    if kind == "StategraphPostInit" and (name == "wilson" or name == "wilson_client") then
        table.insert(fns, 1, PreserveNativeCharge)
    end
    return fns
end

local function RestoreNativeCharge(sg)
    local state = sg.states and sg.states.slingshot_charge
    if state == nil or state.tags.aoecharging or sg.states[nativeChargeName] == nil then return end
    local onenter, onexit = state.onenter, state.onexit
    state.onenter = function(inst, ...)
        local inventory = inst.components.inventory or inst.replica.inventory
        local weapon = inventory and inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        if weapon and nativeSlingshots[weapon.prefab] and weapon.components.aoecharging then
            inst.sg.statemem.nativecharge_redirect2hm = true
            return inst.sg:GoToState(nativeChargeName, ...)
        end
        if onenter then return onenter(inst, ...) end
    end
    state.onexit = function(inst, ...)
        if not inst.sg.statemem.nativecharge_redirect2hm and onexit then return onexit(inst, ...) end
    end
end

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
-- shove. Keep Walter's native variants on the normal shooting state.
local function RestoreNativeAttack(sg)
    RestoreNativeCharge(sg)
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
