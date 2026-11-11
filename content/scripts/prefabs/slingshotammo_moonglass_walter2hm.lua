-- UM owns slingshotammo_moonglass (spiked ammo). Keep its saved items intact
-- and give Walter a separate name backed by the current native constructors.
local loadnative = assert(kleiloadlua("scripts/prefabs/slingshotammo.lua"))
local item, projectile
for _, prefab in ipairs({loadnative()}) do
    if prefab.name == "slingshotammo_moonglass" then item = prefab
    elseif prefab.name == "slingshotammo_moonglass_proj" then projectile = prefab end
end
assert(item and projectile, "Native Walter moonglass ammo constructors unavailable")
-- Keep existing stacks readable if UM is later disabled in this world.
STRINGS.NAMES.SLINGSHOTAMMO_MOONGLASS_WALTER2HM = STRINGS.NAMES.SLINGSHOTAMMO_MOONGLASS_WALTER2HM or
    STRINGS.NAMES.SLINGSHOTAMMO_MOONGLASS

local assets = {}
for _, asset in ipairs(item.assets or {}) do assets[#assets + 1] = asset end
assets[#assets + 1] = Asset("ATLAS", "images/inventoryimages3.xml")

local function fn()
    local inst = item.fn()
    if TheWorld.ismastersim then
        -- An explicit native atlas prevents UM's same-name inventory icon
        -- registration from displaying its pointed shard on Walter's round.
        inst.components.inventoryitem.atlasname = "images/inventoryimages3.xml"
        inst.components.inventoryitem:ChangeImageName("slingshotammo_moonglass")
        inst.components.inspectable.nameoverride = "slingshotammo_moonglass"
    end
    return inst
end

local function secondaryfn()
    local inst = projectile.fn()
    if TheWorld.ismastersim then
        -- Wixie's launchers append _secondary and supply their own power level.
        -- Preserve the native glass hit/skill effects with UM's damage scaling.
        local base = inst.components.weapon.damage
        local thrown = inst.components.projectile.onthrown
        inst.components.projectile:SetOnThrownFn(function(inst, ...)
            local power = inst.powerlevel or 1
            if type(base) == "number" and type(power) == "number" then inst.components.weapon:SetDamage(base * power) end
            if thrown then return thrown(inst, ...) end
        end)
    end
    return inst
end

return Prefab("slingshotammo_moonglass_walter2hm", fn, assets,
        {"slingshotammo_moonglass_walter2hm_proj", "slingshotammo_moonglass_walter2hm_proj_secondary"}),
    Prefab("slingshotammo_moonglass_walter2hm_proj", projectile.fn, projectile.assets, projectile.prefabs),
    Prefab("slingshotammo_moonglass_walter2hm_proj_secondary", secondaryfn, projectile.assets, projectile.prefabs)
