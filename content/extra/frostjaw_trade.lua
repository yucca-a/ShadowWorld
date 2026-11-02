-- Frostjaw trades are its boss reward: scale capacity, not each fish's reward.
-- Keep this hook active even when the multiplier is disabled so saved balances survive.
local multiplier = GetModConfigData("boss_health")
local capacity = 5
if type(multiplier) == "number" and multiplier == multiplier and math.abs(multiplier) < math.huge then
    local healthmult = math.max(1, math.min(100, multiplier))
    -- Match the generic boss-loot multiplier: 3x health yields 2x rewards.
    capacity = math.floor(5 * (1 + healthmult) / 2 + 1e-7)
end

local function ValidStock(stock)
    -- New grants stop at 252; retain legacy earned balances up to 500 on reload.
    return type(stock) == "number" and stock == stock and math.abs(stock) < math.huge
        and math.max(0, math.min(500, math.floor(stock + 1e-7))) or nil
end

AddPrefabPostInit("sharkboi", function(inst)
    if not TheWorld.ismastersim then return end
    local loading = false
    local function RestoreStock(inst, wastrader, remaining)
        if inst.components.trader ~= nil then
            if remaining ~= nil then
                -- The separate Frostjaw enhancement can restore stale stock_ here.
                inst.stock = remaining
            elseif not wastrader and not loading then
                inst.stock = capacity
            end
        end
    end
    local MakeTrader = inst.MakeTrader
    inst.MakeTrader = function(inst, ...)
        local wastrader = inst.components.trader ~= nil
        local remaining = wastrader and ValidStock(inst.stock) or nil
        local result = MakeTrader(inst, ...)
        RestoreStock(inst, wastrader, remaining)
        return result
    end

    -- The vanilla sleep callback calls a local MakeTrader, bypassing the method.
    local OnEntitySleep = inst.OnEntitySleep
    if OnEntitySleep then
        inst.OnEntitySleep = function(inst, ...)
            local wastrader = inst.components.trader ~= nil
            local remaining = wastrader and ValidStock(inst.stock) or nil
            local result = OnEntitySleep(inst, ...)
            RestoreStock(inst, wastrader, remaining)
            return result
        end
    end

    local OnSave = inst.OnSave
    inst.OnSave = function(inst, data, ...)
        local result = OnSave and OnSave(inst, data, ...)
        if inst.components.trader ~= nil then
            -- Vanilla only serializes stock below five. Include zero and larger balances.
            data.frostjawstock2hm = ValidStock(inst.stock)
        elseif inst.components.health.currenthealth <= inst.components.health.minhealth then
            -- Defeat animations can be saved before MakeTrader. This fight has
            -- already earned its capacity; vanilla OnLoad creates the trader locally.
            data.frostjawstock2hm = capacity
        end
        return result
    end

    local OnLoad = inst.OnLoad
    inst.OnLoad = function(inst, data, ...)
        loading = true
        local result = OnLoad and OnLoad(inst, data, ...)
        loading = false
        if inst.components.trader ~= nil then
            local remaining = data and ValidStock(data.frostjawstock2hm)
            if remaining ~= nil then
                -- A configuration change applies to the next fight, not this balance.
                inst.stock = remaining
            end
            -- Unmarked old saves keep vanilla's remaining stock, without a refill.
        end
        return result
    end
end)
