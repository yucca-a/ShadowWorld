local wortox_soul_common = require("prefabs/wortox_soul_common")

-- 沃拓克斯能力削弱，灵魂携带上限为10，灵魂的生命回复数额降低到10点，受到回复的角色会损失饥饿值，非怪物角色还会降低理智值

-- if TUNING.WORTOX_MAX_SOULS > 10 then
--     TUNING.WORTOX_MAX_SOULS = 10
-- end
-- if TUNING.HEALING_MED > 10 then
--     TUNING.HEALING_MED = 10
-- end

local woodiet = GetModConfigData("role_easy") and GetModConfigData("Woodie Hunger Wereness")

local function DoHealFx(inst)
    local healtargets = {}
    local healtargetscount = 0
    local x, y, z = inst.Transform:GetWorldPosition()
    for i, v in ipairs(AllPlayers) do
        if not (v.components.health:IsDead() or v:HasTag("playerghost")) and v.entity:IsVisible() and v:GetDistanceSqToPoint(x, y, z) <
            TUNING.WORTOX_SOULHEAL_RANGE * TUNING.WORTOX_SOULHEAL_RANGE then
            if v.components.health:IsHurt() and not v:HasTag("health_as_oldage") then -- Wanda tag.
                table.insert(healtargets, v)
                healtargetscount = healtargetscount + 1
            end
        end
    end
    if healtargetscount > 0 then
        local amt = math.max(TUNING.WORTOX_SOULHEAL_MINIMUM_HEAL, TUNING.HEALING_MED - TUNING.WORTOX_SOULHEAL_LOSS_PER_PLAYER * (healtargetscount - 1)) / 2
        for i = 1, healtargetscount do
            local v = healtargets[i]
            if v.components.hunger then v.components.hunger:DoDelta(-amt) end
            if v.prefab == "woodie" and woodiet and v.weremode and v.weremode:value() ~= 0 and v.components.wereness then
                v.components.wereness:DoDelta(-amt)
            end
            -- if not v:HasTag("monster") and v.components.sanity then
            --     v.components.sanity:DoDelta(-amt)
            -- end
            -- 2025.7.25 melon:魂回1%血上限
            if v.components.health ~= nil then
                v.components.health:DeltaPenalty(-0.01)
            end
        end
    end
end

local oldDoHeal = wortox_soul_common.DoHeal

wortox_soul_common.DoHeal = function(...)
    DoHealFx(...)
    oldDoHeal(...)
end

-- 2025.9.3 melon:蜜蜂33%掉余烬
local _SpawnSoulsAt = wortox_soul_common.SpawnSoulsAt
wortox_soul_common.SpawnSoulsAt = function(victim, numsouls)
    if victim.prefab == "bee" and math.random() < 0.67 then return end
    return _SpawnSoulsAt(victim, numsouls)
end


-- local function BlinkMapAbleFix(act)
--     return false
-- end

-- local oldBlinkMapAble = ACTIONS.BLINK_MAP.fn

-- ACTIONS.BLINK_MAP.fn = function(...)
--     if BlinkMapAbleFix(...) then
--         return oldBlinkMapAble(...)
--     end
--     return false
-- end
