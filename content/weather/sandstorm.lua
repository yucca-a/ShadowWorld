AddComponentPostInit("sandstorms", function(self)
    local inst = self.inst
    if inst:HasTag("cave") then return end
    -- Private
    local _sandstormactive = false
    local _issandstormseason = false
    local _iswet = false
    --[[ Private member functions ]]
    local function ShouldActivateSandstorm() return _issandstormseason and not _iswet end
    local function ToggleSandstorm(inst)
        if _sandstormactive ~= ShouldActivateSandstorm() then
            _sandstormactive = not _sandstormactive
            inst:PushEvent("ms_stormchanged", {stormtype = STORM_TYPES.SANDSTORM, setting = _sandstormactive})
        end
    end
    --[[ Private event handlers ]]
    local function OnSeasonTick(inst, data)
        _issandstormseason = data.season ~= SEASONS.WINTER
        inst:DoTaskInTime(0.1, ToggleSandstorm)
    end
    local function OnWeatherTick(inst, data)
        _iswet = data.wetness > 0 or data.snowlevel > 0
        inst:DoTaskInTime(0.1, ToggleSandstorm)
    end
    -- Register events
    inst:ListenForEvent("weathertick", OnWeatherTick)
    inst:ListenForEvent("seasontick", OnSeasonTick)
    -- Component Functions
    local function IsInSandstorm(self, ent)
        return _sandstormactive and ent.components.areaaware ~= nil and ent.components.areaaware:CurrentlyInTag("sandstorm")
    end
    local oldIsInSandstorm = self.IsInSandstorm
    self.IsInSandstorm = function(...) return oldIsInSandstorm(...) or IsInSandstorm(...) end
    local function GetSandstormLevel(self, ent)
        if IsInSandstorm(self, ent) then
            local oasislevel = self:CalcOasisLevel(ent)
            return oasislevel < 1 and math.clamp(self:CalcSandstormLevel(ent) - oasislevel, 0, 1) or 0
        end
        return 0
    end
    local oldGetSandstormLevel = self.GetSandstormLevel
    self.GetSandstormLevel = function(...)
        local level = oldGetSandstormLevel(...)
        if level == 0 then return GetSandstormLevel(...) end
        return level
    end
    local oldIsSandstormActive = self.IsSandstormActive
    self.IsSandstormActive = function(...) return oldIsSandstormActive(...) or _sandstormactive end
end)

-- AddPrefabPostInit(
--     "antlion",
--     function(inst)
--         if not TheWorld.ismastersim then
--             return inst
--         end
--         if inst.components.trader then
--             local oldaccept = inst.components.trader.onaccept
--             inst.components.trader.onaccept = function(inst, giver, item, ...)
--                 if
--                     TheWorld.state.season ~= SEASONS.SUMMER and item.prefab == "heatrock" and
--                         item.currentTempRange ~= nil
--                  then
--                     item.currentTempRange = 3
--                 end
--                 oldaccept(inst, giver, item, ...)
--             end
--         end
--     end
-- )
