local benefits = require("combatbenefits2hm")
local UMGuard = require("umcompatguard2hm")

-- Weapon:OnAttack still dispatches events and consumes durability on a
-- protected hit. Only the bat bat's own drain callback is ineligible.
AddPrefabPostInit("batbat", function(inst)
    if not TheWorld.ismastersim then return end
    local onattack = inst.components.weapon.onattack
    inst.components.weapon:SetOnAttack(function(weapon, attacker, target)
        if not benefits.IsProtectedWeaponHit(attacker, target) then
            return onattack(weapon, attacker, target)
        end
    end)
end)

AddPrefabPostInit("shadow_battleaxe", function(inst)
    if not TheWorld.ismastersim then return end
    local DoLifeSteal = inst.DoLifeSteal
    inst.DoLifeSteal = function(self, attacker, target)
        if benefits.CanLifeSteal(attacker, target) then return DoLifeSteal(self, attacker, target) end
    end
end)

-- Cards have combat/health components for shuffling, but are explicitly
-- classified as non-lifeforms by the game. Retain each edition's song rules.
local wrappedfilters = setmetatable({}, {__mode = "k"})
local function FilterSong(inst)
    if not TheWorld.ismastersim then return end
    local slot = UMGuard.Find(inst.songdata.ONAPPLY, "CheckValidAttackData")
    local check = slot.value
    if wrappedfilters[check] then return end
    local function CheckLivingAttack(attacker, data)
        return data ~= nil and data.target ~= nil and IsLifeDrainable(data.target) and check(attacker, data)
    end
    wrappedfilters[CheckLivingAttack] = true
    debug.setupvalue(slot.owner, slot.index, CheckLivingAttack)
end
AddPrefabPostInit("battlesong_healthgain", FilterSong)
AddPrefabPostInit("battlesong_sanitygain", FilterSong)

-- UM awards adrenaline on the attack attempt, before beefalo protection can
-- reject damage. Filter that reward listener, leaving the combat event intact.
AddPrefabPostInit("wathom", function(inst)
    if not TheWorld.ismastersim then return end
    local listeners = {unpack(inst.event_listeners.onattackother[inst])}
    for _, fn in ipairs(listeners) do
        local source = debug.getinfo(fn, "S").source:gsub("\\", "/")
        if source:sub(-#"scripts/prefabs/wathom.lua") == "scripts/prefabs/wathom.lua" or fn == inst.OnAttackOther2hm then
            local function OnAttackOther(attacker, data)
                if data == nil or data.target == nil or not benefits.IsProtectedWeaponHit(attacker, data.target) then
                    return fn(attacker, data)
                end
            end
            inst:RemoveEventCallback("onattackother", fn)
            inst:ListenForEvent("onattackother", OnAttackOther)
            if fn == inst.OnAttackOther2hm then inst.OnAttackOther2hm = OnAttackOther end
        end
    end
end)
