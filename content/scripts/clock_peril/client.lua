-- 2025.2.24 YeFeng:时钟险境 - 客户端

local Schedule = require("clock_peril/schedule")

local Client = {}

local NUM_SEGS = 16
local DAY_COLOUR   = Vector3(254 / 255, 212 / 255, 86 / 255)
local DUSK_COLOUR  = Vector3(165 / 255, 91 / 255, 82 / 255)
local NIGHT_COLOUR = Vector3(73 / 255, 73 / 255, 122 / 255)
local CAVE_DAY_COLOUR  = Vector3(174 / 255, 195 / 255, 108 / 255)
local CAVE_DUSK_COLOUR = Vector3(113 / 255, 127 / 255, 108 / 255)
local CAVE_NIGHT_COLOUR = Vector3(60 / 255, 60 / 255, 80 / 255)
local DARKEN_PERCENT = .75

local function GetPhaseColour(phase, is_cave)
    if phase == "day" then
        return is_cave and CAVE_DAY_COLOUR or DAY_COLOUR
    elseif phase == "dusk" then
        return is_cave and CAVE_DUSK_COLOUR or DUSK_COLOUR
    else
        return is_cave and CAVE_NIGHT_COLOUR or NIGHT_COLOUR
    end
end

local function RecolorSegs(clock)
    if not clock._cp_schedule or not clock._segs then
        return
    end

    local is_cave = clock._cave
    for i = 1, NUM_SEGS do
        local seg = clock._segs[i]
        if seg then
            local phase = clock._cp_schedule[i]
            if phase then
                seg:Show()
                local color = GetPhaseColour(phase, is_cave)
                local dark = (i % 2 == 1)
                if dark then
                    color = color * DARKEN_PERCENT
                end
                seg:SetTint(color.x, color.y, color.z, 1)
            end
        end
    end
end

local function OnScheduleUpdated(clock, encoded)
    if type(encoded) ~= "string" or #encoded == 0 then
        return
    end

    local decoded = Schedule.Decode(encoded)
    if not decoded then
        return
    end

    clock._cp_schedule = decoded
    RecolorSegs(clock)
end

function Client.HookUIClock(clock)
    clock._cp_schedule = nil
    clock._cp_pending_recolor = false

    local _orig_OnClockSegsChanged = clock.OnClockSegsChanged
    clock.OnClockSegsChanged = function(self, data)
        if self._cp_schedule then
            self._daysegs = data.day or 0
            RecolorSegs(self)
        else
            _orig_OnClockSegsChanged(self, data)
            self._cp_pending_recolor = true
        end
    end

    local _orig_OnClockTick = clock.OnClockTick
    clock.OnClockTick = function(self, data)
        _orig_OnClockTick(self, data)
        if self._cp_pending_recolor then
            local Network = CLOCK_PERIL and CLOCK_PERIL.Network
            if Network then
                local current = Network.GetSchedule()
                if current and #current > 0 then
                    OnScheduleUpdated(self, current)
                    self._cp_pending_recolor = false
                end
            end
        end
    end

    local Network = CLOCK_PERIL and CLOCK_PERIL.Network
    if Network then
        local current = Network.GetSchedule()
        if current and #current > 0 then
            OnScheduleUpdated(clock, current)
        end
    end

    clock._cp_listener = function(_world, encoded)
        OnScheduleUpdated(clock, encoded)
        clock._cp_pending_recolor = false
    end
    clock.inst:ListenForEvent("clock_peril_schedule_updated", clock._cp_listener, TheWorld)
end

return Client
