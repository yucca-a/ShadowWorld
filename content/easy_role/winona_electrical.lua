local enabled = TUNING.easymode2hm and GetModConfigData("role_easy") and GetModConfigData("winona_easy") and
    GetModConfigData("Winona Electrical Upgrades")
local ground = TUNING.easymode2hm and GetModConfigData("role_easy") and GetModConfigData("winona_easy") and
    GetModConfigData("Winona Generator Ground Charging")
local electrical = require("winonaelectrical2hm")
local has_um = TUNING.DSTU ~= nil
local legacy = has_um and rawget(GLOBAL, "UM_CONFIG") == nil
FUELTYPE.BATTERYPOWER = FUELTYPE.BATTERYPOWER or "BATTERYPOWER"
UPGRADETYPES.ELECTRICAL = UPGRADETYPES.ELECTRICAL or "ELECTRICAL"

if not has_um then
    -- Keep the prefab registered when disabled so existing kits survive configuration changes.
    table.insert(PrefabFiles, "winona_electrical2hm")
    STRINGS.NAMES.WINONA_UPGRADEKIT_ELECTRICAL = TUNING.isCh2hm and "电能转换套件" or "Electrical Upgrade Kit"
    STRINGS.RECIPE_DESC.WINONA_UPGRADEKIT_ELECTRICAL = TUNING.isCh2hm and "让照明设备接上电力。" or "Bring your lights into the electrical age."
end
-- UM stable predates electrical moggles and has no name for them.
for prefab, cn in pairs({lantern = "电提灯", minerhat = "电矿工帽", molehat = "电鼹鼠帽"}) do
    local key = string.upper(prefab) .. "_ELECTRICAL"
    STRINGS.NAMES[key] = STRINGS.NAMES[key] or (TUNING.isCh2hm and cn or ("Electrical " .. STRINGS.NAMES[string.upper(prefab)]))
end
if enabled and not AllRecipes.winona_upgradekit_electrical then
    AddRecipe2("winona_upgradekit_electrical", {Ingredient("goldnugget", 6), Ingredient("sewing_tape", 2), Ingredient("wagpunk_bits", 4)},
        TECH.SCIENCE_TWO, {builder_tag = "handyperson",
            atlas = has_um and "images/inventoryimages/winona_upgradekit_electrical.xml" or nil,
            image = has_um and "winona_upgradekit_electrical.tex" or "transistor.tex"}, {"CHARACTER", "LIGHT"})
end

AddPrefabPostInit("winona", function(inst) inst:AddTag(UPGRADETYPES.ELECTRICAL .. "_upgradeuser") end)

local function SetupLamp(inst)
    if not TheWorld.ismastersim then return end
    inst.electricalovercharge2hm = enabled
    inst.electricallegacy2hm = legacy
    electrical.InstallStorage(inst)
    if not inst.components.upgradeable then inst:AddComponent("upgradeable") end
    -- With UM enabled, its existing kit remains usable even if our enhancement is off.
    if enabled or has_um then inst.components.upgradeable.upgradetype = UPGRADETYPES.ELECTRICAL end
    inst.components.upgradeable:SetOnUpgradeFn(function(inst)
        electrical.Convert(inst)
        electrical.InstallGround(inst, ground)
    end)
    local OnSave, OnLoad = inst.OnSave, inst.OnLoad
    local OnPreLoad = inst.OnPreLoad
    inst.OnPreLoad = function(inst, data, ...)
        if OnPreLoad then OnPreLoad(inst, data, ...) end
        -- Identify converted saves before native components load their fuel amounts.
        inst.electricalconverted2hm = data and (data.upgraded or data.electrical2hm) or nil
    end
    inst.OnSave = function(inst, data, ...)
        if OnSave then OnSave(inst, data, ...) end
        if inst.electricalconverted2hm then
            data.upgraded = true
            data.electrical2hm = true
            data.electricalfuel2hm = inst.components.fueled.currentfuel
            data.electricalunlocked2hm = inst.electricalunlocked2hm or nil
            -- Retire the old percent-based restores and their delayed callbacks.
            data.saved_fuel_value = nil
        end
    end
    inst.OnLoad = function(inst, data, ...)
        local upgraded = data and (data.upgraded or data.electrical2hm)
        local clean = data
        if upgraded then
            clean = {}
            for k, v in pairs(data) do clean[k] = v end
            clean.upgraded, clean.saved_fuel_value = nil, nil
        end
        if OnLoad then OnLoad(inst, clean, ...) end
        if upgraded then
            local fueled = inst.components.fueled
            inst.electricalunlocked2hm = data.electricalunlocked2hm or nil
            electrical.Convert(inst)
            if data.electricalfuel2hm ~= nil then
                fueled.currentfuel = math.clamp(data.electricalfuel2hm, 0, fueled.maxfuel * (enabled and 2 or 1))
            elseif data.saved_fuel_value ~= nil then
                -- UM stable doubled base capacity on conversion; preserve actual energy.
                fueled.currentfuel = math.clamp(data.saved_fuel_value * fueled.maxfuel * (legacy and 2 or 1), 0,
                    fueled.maxfuel * (enabled and 2 or 1))
            end
            electrical.InstallGround(inst, ground)
            fueled:DoDelta(0)
        end
    end
    inst:ListenForEvent("equipped", electrical.Refresh)
end

for _, name in ipairs({"lantern", "minerhat", "molehat"}) do AddPrefabPostInit(name, SetupLamp) end

local function NightstickBonus(inst, attacker, target)
    if not inst.overcharged or not target or not target:IsValid() then return end
    if not target.components.debuffable then target:AddComponent("debuffable") end
    if not target:HasTag("epic") and not target:HasTag("shadow") or target:HasTag("chess") or target:HasTag("uncompromising_pawn") then
        target.components.debuffable:AddDebuff("shockstundebuff", "shockstundebuff")
    end
    if (target:HasTag("chess") or target:HasTag("uncompromising_pawn") or target:HasTag("twinofterror") and not target:HasTag("fleshyeye"))
        and target.components.health and not target.components.health:IsDead() and target.sg and not target.sg:HasStateTag("noattack") then
        target.components.health:DoDelta(-17, false, attacker, false, attacker)
    end
end

local function SetupWeapon(inst)
    if enabled then inst:AddTag("electricalovercharge2hm") end
    if not TheWorld.ismastersim then return end
    if not electrical.Storage(inst) then return end
    inst.electricalweapon2hm, inst.electricalovercharge2hm, inst.electricallegacy2hm = true, enabled, legacy
    if inst.prefab == "spear_wathgrithr_lightning_charged" then
        inst.electricalunlocked2hm = electrical.transferspear2hm or nil
    elseif inst.prefab == "spear_wathgrithr_lightning" and inst.components.upgradeable then
        -- The native permanent spear upgrade creates a new entity synchronously.
        -- Carry the per-item unlock through that replacement without changing the upgrade.
        local OnUpgrade = inst.components.upgradeable.onupgradefn
        inst.components.upgradeable:SetOnUpgradeFn(function(inst, ...)
            local previous = electrical.transferspear2hm
            electrical.transferspear2hm = inst.electricalunlocked2hm
            local ok, result = pcall(OnUpgrade, inst, ...)
            electrical.transferspear2hm = previous
            if not ok then error(result) end
            return result
        end)
    end
    inst:AddTag("electricaltool")
    electrical.InstallStorage(inst)
    if enabled then electrical.InstallBatteryUser(inst) end
    if enabled and inst.components.fueled then
        inst.components.fueled.rate_modifiers:SetModifier(inst, 0.75, "electricalefficiency")
    end
    -- Only take over legacy UM circuits; native gadgets keep their own circuitry.
    electrical.InstallGround(inst, ground)
    local weapon = inst.components.weapon
    local legacy_bonus = legacy and inst:HasTag("overchargeable")
    if enabled and inst.prefab == "nightstick" and not legacy_bonus then
        local OnAttack = weapon.onattack
        weapon:SetOnAttack(function(inst, attacker, target, ...)
            if OnAttack then OnAttack(inst, attacker, target, ...) end
            NightstickBonus(inst, attacker, target)
        end)
    elseif enabled and inst.prefab == "bugzapper" and not legacy_bonus then
        local OnAttack = weapon.onattack
        weapon:SetOnAttack(function(inst, attacker, target, ...)
            if OnAttack then OnAttack(inst, attacker, target, ...) end
            if inst.overcharged and target and target:IsValid() and target:HasAnyTag("insect", "spider", "hoodedwidow") then
                local x, y, z = target.Transform:GetWorldPosition()
                -- UM beta already deals 5 chain damage; add the missing 20, once.
                for _, v in ipairs(TheSim:FindEntities(x, y, z, 3.5, {"_combat"}, {"INLIMBO", "player", "notarget", "noattack"}, {"insect", "spider", "hoodedwidow"})) do
                    if v ~= inst and v ~= target and v:IsValid() and not (v.components.health and v.components.health:IsDead())
                        and attacker.components.combat:CanTarget(v) and not attacker.components.combat:IsAlly(v) then
                        v.components.combat:GetAttacked(attacker, 20, nil)
                    end
                end
            end
        end)
    end
    local OnLoad = inst.OnLoad
    local OnSave = inst.OnSave
    inst.OnSave = function(inst, data, ...)
        if OnSave then OnSave(inst, data, ...) end
        data.electricalunlocked2hm = inst.electricalunlocked2hm or nil
    end
    inst.OnLoad = function(inst, data, ...)
        inst.electricalunlocked2hm = data and data.electricalunlocked2hm or nil
        local clean = data
        if data and data.actual_fuel ~= nil then
            clean = {}
            for k, v in pairs(data) do clean[k] = v end
            clean.actual_fuel = nil
        end
        if OnLoad then OnLoad(inst, clean, ...) end
        electrical.Refresh(inst)
    end
    inst:ListenForEvent("equipped", electrical.Refresh)
end
for _, name in ipairs({"nightstick", "bugzapper", "spear_wathgrithr_lightning", "spear_wathgrithr_lightning_charged"}) do
    AddPrefabPostInit(name, SetupWeapon)
end

if enabled then
    if not legacy then table.insert(PrefabFiles, "electrical_shock2hm") end
    AddPrefabPostInit("inventoryitem_classified", function(inst)
        if not TheWorld.ismastersim then return end
        local Serialize = inst.SerializePercentUsed
        inst.SerializePercentUsed = function(inst, percent)
            local parent = inst.electricalowner2hm or inst._parent
            if parent and parent:HasTag("electricalovercharge2hm") and percent ~= nil then
                inst.percentused:set(percent <= 0 and 0 or math.clamp(math.floor(percent * 100 + 0.5), 1, 200))
            else
                Serialize(inst, percent)
            end
        end
    end)
    local ChargeFrom = ACTIONS.CHARGE_FROM.fn
    ACTIONS.CHARGE_FROM.fn = function(act)
        local item = act.invobject
        if not item and act.doer and act.doer.components.inventory then
            for _, equipped in pairs(act.doer.components.inventory.equipslots) do
                if (equipped.electricalconverted2hm or equipped.electricalweapon2hm) and
                    (not item or electrical.Storage(equipped):GetPercent() < electrical.Storage(item):GetPercent()) then item = equipped end
            end
        end
        if item and (item.electricalconverted2hm or item.electricalweapon2hm) and act.target and act.target.components.battery then
            item._electricaldoer2hm = act.doer
            local ok, result, reason = pcall(item.components.batteryuser.ChargeFrom, item.components.batteryuser, act.target)
            item._electricaldoer2hm = nil
            if not ok then error(result) end
            return result, reason
        end
        return ChargeFrom(act)
    end
end

if ground then
    AddPrefabPostInitAny(function(inst)
        if not TheWorld.ismastersim or not inst.components.inventoryitem or inst.AddBatteryPower then return end
        local fueled, batteryuser = inst.components.fueled, inst.components.batteryuser
        if fueled and fueled.fueltype == FUELTYPE.BATTERYPOWER or
            batteryuser and batteryuser.allowpartialcharge and electrical.Storage(inst) then
            electrical.InstallGround(inst, true)
        end
    end)
end
