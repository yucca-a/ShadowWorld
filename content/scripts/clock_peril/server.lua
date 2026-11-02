-- 2025.2.24 YeFeng:时钟险境 - 服务端

local Schedule = require("clock_peril/schedule")

local Server = {}

Server.current_schedule = nil
Server._loaded_from_save = false

local _last_segs = nil
local _setting_segs = false

local _forcing_phase = false
local _applying_schedule = false
local _external_control_cycle = nil    -- 2026.3.5 YeFeng: 兼容永不妥协外部强制时钟时按天让权，避免整天锁相位
local _internal_setclocksegs_until = 0    -- 2026.3.6 YeFeng: 标记近期内部setclocksegs时间窗，避免误判为外部接管
local _last_known_cycles = -1

local _current_seg = 0
local _tick_task = nil
local TICK_INTERVAL = 0.5
local NUM_SEGS = 16

local PHASE_SHORT = { day = "D", dusk = "U", night = "N" }
local PHASE_INDEX = { day = 1, dusk = 2, night = 3 }

local function GetCurrentSegFromClock()
    if not TheWorld or not TheWorld.state then
        return 1
    end

    local time = TheWorld.state.time or 0
    local seg_index = math.floor(time * NUM_SEGS) + 1

    if seg_index < 1 then seg_index = 1 end
    if seg_index > NUM_SEGS then seg_index = NUM_SEGS end

    return seg_index
end

function Server.GenerateSchedule()
    local mode = CLOCK_PERIL and CLOCK_PERIL.MODE or "shuffle"
    if mode == "fragment" then
        return Schedule.GenerateFragment()
    else
        return Schedule.GenerateShuffle()
    end
end

local function LogScheduleDetails(schedule, source)
    local Log = CLOCK_PERIL and CLOCK_PERIL.Log
    if not Log then
        return
    end

    local mode = CLOCK_PERIL and CLOCK_PERIL.MODE or "shuffle"
    local day = TheWorld and TheWorld.state and TheWorld.state.cycles or 0
    local encoded = Schedule.Encode(schedule)

    local vis = {}
    for i = 1, 16 do
        vis[i] = PHASE_SHORT[schedule[i]] or "?"
    end
    local bar = "[" .. table.concat(vis, " ") .. "]"

    local counts = { day = 0, dusk = 0, night = 0 }
    for i = 1, 16 do
        local p = schedule[i]
        if counts[p] ~= nil then
            counts[p] = counts[p] + 1
        end
    end

    Log("=== Schedule (" .. source .. ") ===")
    Log("  Day:", tostring(day + 1), " Mode:", mode)
    Log("  Encoded:", encoded)
    Log("  Segs:   ", bar)
    Log("  Counts:  D=" .. tostring(counts.day),
        " U=" .. tostring(counts.dusk),
        " N=" .. tostring(counts.night))
    Log("===========================")
end

local function CountScheduleSegs(schedule)
    local counts = { day = 0, dusk = 0, night = 0 }
    for i = 1, 16 do
        local phase = schedule[i]
        if counts[phase] ~= nil then
            counts[phase] = counts[phase] + 1
        end
    end
    return counts
end

local function MarkInternalSetClockSegs()    -- 2026.3.6 YeFeng: 记录内部改时钟来源，避免clocksegschanged误判外部接管
    _internal_setclocksegs_until = (GetTime and GetTime() or 0) + 0.25
end

local function IsInternalSetClockSegs()    -- 2026.3.6 YeFeng: 内部时间窗内触发的clocksegschanged视为本模组行为
    return (GetTime and GetTime() or 0) <= _internal_setclocksegs_until
end

-- 同步segs
local function SyncClockSegsFromSchedule(schedule, callback)
    local segs = CountScheduleSegs(schedule)
    local Log = CLOCK_PERIL and CLOCK_PERIL.Log

    if Log then
        Log("Syncing clock segs (day:", tostring(segs.day),
            " dusk:", tostring(segs.dusk),
            " night:", tostring(segs.night), ")")
    end

    _setting_segs = true
    _last_segs = { day = segs.day, dusk = segs.dusk, night = segs.night }
    
    MarkInternalSetClockSegs()    -- 2026.3.6 YeFeng: 标记本次ms_setclocksegs来自时钟险境内部同步
    TheWorld:PushEvent("ms_setclocksegs", segs)
    
    _setting_segs = false

    if callback then
        callback(schedule)
    end
end

-- 切换相位
local function ForceSetPhase(target_phase)
    if _forcing_phase then
        return
    end
    _forcing_phase = true
    _setting_segs = true

    local time = TheWorld.state.time or 0
    local current_seg_0 = math.floor(time * NUM_SEGS)
    if current_seg_0 < 0 then current_seg_0 = 0 end
    if current_seg_0 >= NUM_SEGS then current_seg_0 = NUM_SEGS - 1 end

    local before_segs = current_seg_0
    local after_segs = NUM_SEGS - current_seg_0

    local target_idx = PHASE_INDEX[target_phase]
    local new_segs = { day = 0, dusk = 0, night = 0 }

    if target_idx == 1 then
        new_segs.day = NUM_SEGS
    elseif target_idx == 2 then
        new_segs.day = before_segs
        new_segs.dusk = after_segs
    elseif target_idx == 3 then
        new_segs.dusk = before_segs
        new_segs.night = after_segs
    end

    local sum = new_segs.day + new_segs.dusk + new_segs.night
    if sum ~= NUM_SEGS then
        _forcing_phase = false
        _setting_segs = false
        return
    end

    MarkInternalSetClockSegs()    -- 2026.3.6 YeFeng: 标记本次ms_setclocksegs来自时钟险境内部强制纠偏
    TheWorld:PushEvent("ms_setclocksegs", new_segs)
    _last_segs = { day = new_segs.day, dusk = new_segs.dusk, night = new_segs.night }

    _setting_segs = false
    _forcing_phase = false
end

-- 应用新日程
function Server.ApplyNewSchedule()
    if _applying_schedule then
        return
    end
    _applying_schedule = true

    local schedule = Server.GenerateSchedule()

    Server.current_schedule = schedule

    SyncClockSegsFromSchedule(schedule, function(final_schedule)
        local encoded = Schedule.Encode(final_schedule)
        
        local Network = CLOCK_PERIL and CLOCK_PERIL.Network
        if Network then
            Network.SetSchedule(encoded)
        end

        LogScheduleDetails(final_schedule, "generated")

        if CLOCK_PERIL and CLOCK_PERIL.BroadcastScheduleToShards then
            CLOCK_PERIL.BroadcastScheduleToShards(encoded)
        end
    end)

    _applying_schedule = false

    return schedule
end

-- 应用已有日程
function Server.ApplyExistingSchedule(encoded)
    if _applying_schedule then
        return false
    end
    _applying_schedule = true

    local schedule = Schedule.Decode(encoded)
    if not schedule then
        _applying_schedule = false
        return false
    end

    Server.current_schedule = schedule

    SyncClockSegsFromSchedule(schedule, function(final_schedule)
        local final_encoded = Schedule.Encode(final_schedule)
        
        local Network = CLOCK_PERIL and CLOCK_PERIL.Network
        if Network then
            Network.SetSchedule(final_encoded)
        end

        LogScheduleDetails(final_schedule, "restored")
    end)

    _applying_schedule = false
    return true
end

function Server.OnSave()
    if not Server.current_schedule then
        return nil
    end
    return {
        schedule = Schedule.Encode(Server.current_schedule),
        current_seg = _current_seg,
    }
end

function Server.OnLoad(data)
    if not data or type(data.schedule) ~= "string" then
        return false
    end

    local Log = CLOCK_PERIL and CLOCK_PERIL.Log

    local success = Server.ApplyExistingSchedule(data.schedule)
    if success then
        Server._loaded_from_save = true

        if type(data.current_seg) == "number" then
            _current_seg = data.current_seg
        end
        if Log then
            Log("Loaded save data (seg:", tostring(_current_seg), ") - _loaded_from_save = true")
        end
    else
        if Log then
            Log("Failed to restore schedule from save, generating new one")
        end
    end

    return success
end

local function ResetDayTimer()
    _current_seg = 0
end

function Server.GetTimeProgress()
    return _current_seg
end

function Server.SyncTimeProgress(seg)
    _current_seg = seg or 0
end

local function OnTick()
    if not Server.current_schedule then
        return
    end

    if _applying_schedule or _forcing_phase then
        return
    end

    if _external_control_cycle ~= nil and TheWorld and TheWorld.state and _external_control_cycle == TheWorld.state.cycles then    -- 2026.3.5 YeFeng: 外部模组接管当天暂停时钟险境强制纠偏
        return
    end

    local seg_index = GetCurrentSegFromClock()

    if seg_index == _current_seg then
        return
    end

    _current_seg = seg_index

    local target_phase = Server.current_schedule[seg_index]
    if not target_phase then
        return
    end

    local current_phase = TheWorld.state.phase
    if current_phase ~= target_phase then
        local Log = CLOCK_PERIL and CLOCK_PERIL.Log
        if Log then
            Log("Seg", tostring(seg_index), "- forcing phase:", target_phase,
                "(was:", tostring(current_phase), ")")
        end
        ForceSetPhase(target_phase)
    end
end

function Server.Init()
    if not TheWorld.ismastersim then
        return
    end

    local Log = CLOCK_PERIL and CLOCK_PERIL.Log
    if Log then
        Log("Server.Init - generating first day schedule")
    end

    _last_known_cycles = TheWorld.state.cycles or 0

    TheWorld:DoTaskInTime(0, function()
        if Server.current_schedule then
            if Log then
                Log("Server.Init (deferred) - schedule already restored from save, skipping generation")
            end
            local encoded = Schedule.Encode(Server.current_schedule)
            local Network = CLOCK_PERIL and CLOCK_PERIL.Network
            if Network then
                Network.SetSchedule(encoded)
            end
            if CLOCK_PERIL and CLOCK_PERIL.BroadcastScheduleToShards then
                CLOCK_PERIL.BroadcastScheduleToShards(encoded)
            end
        elseif (TheWorld.state.cycles or 0) >= 1 then
            if Log then
                Log("Server.Init (deferred) - day", tostring((TheWorld.state.cycles or 0) + 1), ", generating schedule")
            end
            Server.ApplyNewSchedule()
        else
            if Log then
                Log("Server.Init (deferred) - day 1, keeping vanilla schedule")
            end
        end
    end)

    ResetDayTimer()

    TheWorld:ListenForEvent("cycleschanged", function(_world, cycles)
        if _external_control_cycle ~= nil and cycles ~= nil and cycles > _external_control_cycle then    -- 2026.3.5 YeFeng: 跨天后释放外部接管并恢复时钟险境控制
            _external_control_cycle = nil
            if Log then
                Log("New day, external control released")
            end
        end

        if _applying_schedule or _forcing_phase then
            if Log then
                Log("Ignoring cycleschanged during schedule apply/phase force (cycle:", tostring(cycles), ")")
            end
            return
        end

        if Server._loaded_from_save then
            Server._loaded_from_save = false
            _last_known_cycles = cycles or _last_known_cycles
            if Log then
                Log("Ignoring first cycleschanged after save load (cycle:", tostring(cycles), ") - schedule preserved")
            end
            return
        end

        if cycles ~= nil and cycles <= _last_known_cycles then
            if Log then
                Log("Ignoring stale cycleschanged (got:", tostring(cycles),
                    " last_known:", tostring(_last_known_cycles), ")")
            end
            return
        end

        _last_known_cycles = cycles or (_last_known_cycles + 1)

        if (cycles or 0) < 1 then
            if Log then
                Log("Day 1 (cycle:", tostring(cycles), ") - keeping vanilla schedule")
            end
            ResetDayTimer()
            return
        end

        if Log then
            Log("New day started (cycle:", tostring(cycles), ") - regenerating schedule")
        end
        ResetDayTimer()
        Server.ApplyNewSchedule()
    end)

    TheWorld:ListenForEvent("clocksegschanged", function(_world, data)
        if _setting_segs then
            return
        end

        if _applying_schedule or _forcing_phase then
            return
        end

        if (TheWorld.state.cycles or 0) < 1 then
            return
        end

        -- 兼容永不妥协
        local day = data.day or 0
        local dusk = data.dusk or 0
        local night = data.night or 0
        if day + dusk + night == NUM_SEGS and (day == NUM_SEGS or dusk == NUM_SEGS or night == NUM_SEGS) then    -- 2026.3.5 YeFeng: 识别外部整相位强制事件（如永不妥协）
            if IsInternalSetClockSegs() then    -- 2026.3.6 YeFeng: 过滤本模组内部16段单相位纠偏，避免误判外部接管
                return
            end
            _external_control_cycle = TheWorld and TheWorld.state and TheWorld.state.cycles or nil    -- 2026.3.5 YeFeng: 检测到永不妥协整相位强制后标记当天让权

            if Log then
                Log("External forced segs detected, yielding control for cycle:", tostring(_external_control_cycle))    -- 2026.3.5 YeFeng: 记录当日让权日志便于排查兼容
            end
            return
        end

        local mode = CLOCK_PERIL and CLOCK_PERIL.MODE or "shuffle"    -- 2026.3.5 YeFeng: 让权逻辑不改变模式算法，仅保留原有shuffle/fragment分支
        if mode ~= "shuffle" then
            return
        end

        if _last_segs
            and _last_segs.day == data.day
            and _last_segs.dusk == data.dusk
            and _last_segs.night == data.night then
            return
        end

        _last_segs = { day = data.day, dusk = data.dusk, night = data.night }

        if Log then
            Log("Clock segs changed (day:", tostring(data.day),
                " dusk:", tostring(data.dusk),
                " night:", tostring(data.night),
                ") - regenerating shuffle schedule")
        end

        Server.ApplyNewSchedule()
    end)

    if _tick_task then
        _tick_task:Cancel()
    end
    _tick_task = TheWorld:DoPeriodicTask(TICK_INTERVAL, OnTick)

    if Log then
        Log("Periodic phase enforcement started (interval:", tostring(TICK_INTERVAL), "s)")
    end
end

-- 从分片
function Server.InitSlave()
    if not TheWorld.ismastersim then
        return
    end

    local Log = CLOCK_PERIL and CLOCK_PERIL.Log
    if Log then
        Log("Server.InitSlave - waiting for schedule from master shard")
    end

    _last_known_cycles = TheWorld.state.cycles or 0

    if Server.current_schedule then
        if Log then
            Log("Server.InitSlave - schedule restored from save, applying")
        end
        SyncClockSegsFromSchedule(Server.current_schedule, function(final_schedule)
        end)
    end

    ResetDayTimer()

    TheWorld:ListenForEvent("cycleschanged", function(_world, cycles)
        if _applying_schedule or _forcing_phase then
            return
        end
        if cycles ~= nil and cycles <= _last_known_cycles then
            return
        end
        _last_known_cycles = cycles or (_last_known_cycles + 1)

        if Log then
            Log("Slave: New day (cycle:", tostring(cycles), ") - resetting timer, waiting for master schedule")
        end
        ResetDayTimer()
    end)

    if _tick_task then
        _tick_task:Cancel()
    end
    _tick_task = TheWorld:DoPeriodicTask(TICK_INTERVAL, OnTick)

    if Log then
        Log("Slave: Periodic phase enforcement started")
    end
end

return Server
