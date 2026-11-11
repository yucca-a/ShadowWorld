-- UM removes Walter's native permissions even when Wixie's weapons are disabled.
-- Restore his own equipment independently of every optional character upgrade.
if not (TUNING.DSTU and TUNING.WIXIE_HEALTH) then return end
local wixieWeapons = GetModConfigData("Walter Use Wixie Slingshot")
-- UM replaces the vanilla recipe as well as its item. Restore a distinct
-- Walter round independently of the permission to use Wixie's weapons.
local walterGlass = "slingshotammo_moonglass_walter2hm"
local walterGlassTag = "walter_moonglass2hm"
STRINGS.NAMES.SLINGSHOTAMMO_MOONGLASS_WALTER2HM = TUNING.isCh2hm and "玻璃弹（沃尔特）" or "Moonglass Rounds (Walter)"
STRINGS.RECIPE_DESC.SLINGSHOTAMMO_MOONGLASS_WALTER2HM = TUNING.isCh2hm and "沃尔特的圆形玻璃弹。" or "Walter's round moonglass ammunition."
local function GlassCraftState(recipe, doer)
    return doer.components.skilltreeupdater and doer.components.skilltreeupdater:IsActivated("walter_ammo_efficiency") and
        "domediumaction" or nil
end
local function GlassCraftCount(recipe, doer)
    return doer.components.skilltreeupdater and doer.components.skilltreeupdater:IsActivated("walter_ammo_efficiency") and
        recipe.numtogive * 1.5 or nil
end
AddRecipe2(walterGlass, {Ingredient("moonglass", 1)}, TECH.CELESTIAL_THREE, {
    builder_tag = walterGlassTag,
    builder_skill = "walter_ammo_shattershots",
    sg_state = GlassCraftState,
    numtogive = 20,
    override_numtogive_fn = GlassCraftCount,
    no_deconstruction = true,
    allowautopick = true,
    force_hint = true,
    station_tag = "celestial_station",
    atlas = "images/inventoryimages3.xml",
    image = "slingshotammo_moonglass.tex",
}, {"CHARACTER", "WEAPONS", "CRAFTING_STATION"})
local nativeSlingshots = {slingshot = true, slingshotex = true, slingshot999ex = true, slingshot2 = true, slingshot2ex = true}
local wixieSlingshots = {slingshot_gnasher = true, slingshot_matilda = true, slingshot_claire = true, slingshot_jessie = true, slingshot_sling = true}
-- UM replaces the honey and moonglass ammo prefabs as well as adding new ones.
local wixieAmmo = {
    firecrackers_slingshot = true,
    slingshotammo_firecrackers = true,
    slingshotammo_flare = true,
    slingshotammo_goop = true,
    slingshotammo_honey = true,
    slingshotammo_insanity = true,
    slingshotammo_lazy = true,
    slingshotammo_limestone = true,
    slingshotammo_lunarvine = true,
    slingshotammo_moonglass = true,
    slingshotammo_moonrock = true,
    slingshotammo_obsidian = true,
    slingshotammo_rubber = true,
    slingshotammo_salt = true,
    slingshotammo_shadow = true,
    slingshotammo_slime = true,
    slingshotammo_tar = true,
    slingshotammo_tremor = true,
    um_smolder_spore = true,
}
local walterAmmoRestriction = "walter_wixie_ammo_restricted2hm"
for _, recipe in pairs(AllRecipes) do
    if wixieAmmo[recipe.product] then recipe.no_builder_tag = walterAmmoRestriction end
end

local function IsWixieAmmo(item)
    -- UM also lets some worlds use an ordinary coconut as ammo.
    return wixieAmmo[item.prefab] or (item.prefab == "coconut" and item:HasTag("slingshotammo"))
end

-- Keep each weapon's slot rules on the server and the predicting client.
local containers = require("containers")
local widgetsetup = containers.widgetsetup
function containers.widgetsetup(container, prefab, data, ...)
    widgetsetup(container, prefab, data, ...)
    local widget = prefab or container.inst.prefab
    if not (nativeSlingshots[widget] or widget == "matilda" or widget == "jessie") then return end
    local itemtestfn = container.itemtestfn
    container.itemtestfn = function(self, item, slot)
        if IsWixieAmmo(item) then
            local inventoryitem = self.inst.components.inventoryitem
            local owner = inventoryitem and inventoryitem:GetGrandOwner() or (not TheWorld.ismastersim and
                ThePlayer and self:IsOpenedBy(ThePlayer) and ThePlayer)
            if owner and owner.prefab == "walter" then return false end
        end
        return itemtestfn == nil or itemtestfn(self, item, slot)
    end
end

-- Old saves and other players can hand Walter an already loaded weapon.
local function UnloadWixieAmmoOnEquip(inst)
    if not TheWorld.ismastersim then return end
    local container, equip = inst.components.container, inst.components.equippable
    if container == nil or equip == nil then return end
    local onequip = equip.onequipfn
    equip:SetOnEquip(function(inst, owner, ...)
        if owner.prefab == "walter" then
            for slot = 1, container:GetNumSlots() do
                local ammo = container:GetItemInSlot(slot)
                if ammo and IsWixieAmmo(ammo) then container:DropItemBySlot(slot, owner:GetPosition(), true) end
            end
        end
        if onequip then return onequip(inst, owner, ...) end
    end)
end
for prefab in pairs(nativeSlingshots) do AddPrefabPostInit(prefab, UnloadWixieAmmoOnEquip) end
for prefab in pairs(wixieSlingshots) do AddPrefabPostInit(prefab, UnloadWixieAmmoOnEquip) end

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
    inst:AddTag(walterGlassTag)
    inst:AddTag("pebblemaker")
    inst:AddTag("slingshot_sharpshooter")
    inst:AddTag("allow_special_point_action_on_impassable")
    inst:AddTag(walterAmmoRestriction)
    if wixieWeapons then inst:AddTag("troublemaker") end
    local builder = inst.components.builder
    if builder then
        local DoBuild = builder.DoBuild
        builder.DoBuild = function(self, name, ...)
            local recipe = GetValidRecipe(name)
            if recipe and wixieAmmo[recipe.product] then return false end
            return DoBuild(self, name, ...)
        end
    end
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
