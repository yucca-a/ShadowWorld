-- 2025.2.24 YeFeng:时钟险境 - 日程算法

local Schedule = {}

local PHASE_NAMES = { "day", "dusk", "night" }

local ENCODE_MAP = { day = "d", dusk = "u", night = "n" }
local DECODE_MAP = { d = "day", u = "dusk", n = "night" }

local DEFAULT_CLOCK_SEGS = {
    autumn = { day = 8, dusk = 6, night = 2 },
    winter = { day = 5, dusk = 5, night = 6 },
    spring = { day = 5, dusk = 8, night = 3 },
    summer = { day = 11, dusk = 1, night = 4 },
}

local NUM_SEGS = 16

-- 2026.2.27 YeFeng:漫漫长夜兼容
local function ApplyDuskChange(segs)
    local dusk_mode = CLOCK_PERIL and CLOCK_PERIL.DUSK_CHANGE
    if dusk_mode == true then
        local mindusks = {autumn = 2, winter = 1, spring = 3, summer = nil}
        if segs.day and segs.dusk and segs.night and segs.day > 0 and segs.night > 0 then
            local season = TheWorld and TheWorld.state and TheWorld.state.season or "autumn"
            local dusklength = mindusks[season]
            if dusklength and segs.dusk >= dusklength then
                segs.night = segs.night + segs.dusk - dusklength
                segs.dusk = dusklength
            end
        end
    end
    return segs
end

function Schedule.GetCurrentSegs()
    local segs
    if TheWorld and TheWorld.state then
        segs = {
            day   = TheWorld.state.clocksegs and TheWorld.state.clocksegs.day or nil,
            dusk  = TheWorld.state.clocksegs and TheWorld.state.clocksegs.dusk or nil,
            night = TheWorld.state.clocksegs and TheWorld.state.clocksegs.night or nil,
        }
        if segs.day and segs.dusk and segs.night
            and (segs.day + segs.dusk + segs.night) == NUM_SEGS then
            return ApplyDuskChange(segs)
        end

        local season = TheWorld.state.season or "autumn"
        if DEFAULT_CLOCK_SEGS[season] then
            segs = {
                day = DEFAULT_CLOCK_SEGS[season].day,
                dusk = DEFAULT_CLOCK_SEGS[season].dusk,
                night = DEFAULT_CLOCK_SEGS[season].night,
            }
            return ApplyDuskChange(segs)
        end
    end
    segs = {
        day = DEFAULT_CLOCK_SEGS.autumn.day,
        dusk = DEFAULT_CLOCK_SEGS.autumn.dusk,
        night = DEFAULT_CLOCK_SEGS.autumn.night,
    }
    return ApplyDuskChange(segs)
end

local function ShuffleArray(arr)
    for i = #arr, 2, -1 do
        local j = math.random(1, i)
        arr[i], arr[j] = arr[j], arr[i]
    end
    return arr
end

function Schedule.GenerateShuffle(segs)
    segs = segs or Schedule.GetCurrentSegs()

    local blocks = {}
    for _, phase in ipairs(PHASE_NAMES) do
        local count = segs[phase] or 0
        if count > 0 then
            table.insert(blocks, { phase = phase, count = count })
        end
    end

    ShuffleArray(blocks)

    local result = {}
    for _, block in ipairs(blocks) do
        for _ = 1, block.count do
            table.insert(result, block.phase)
        end
    end

    return result
end

function Schedule.GenerateFragment()
    local result = {}

    local reserved = {}
    for i = 1, NUM_SEGS do
        reserved[i] = false
    end

    local positions = {}
    for i = 1, NUM_SEGS do
        table.insert(positions, i)
    end
    ShuffleArray(positions)

    for i, phase in ipairs(PHASE_NAMES) do
        local pos = positions[i]
        result[pos] = phase
        reserved[pos] = true
    end

    for i = 1, NUM_SEGS do
        if not reserved[i] then
            result[i] = PHASE_NAMES[math.random(1, #PHASE_NAMES)]
        end
    end

    return result
end

function Schedule.Encode(schedule)
    local chars = {}
    for i = 1, NUM_SEGS do
        local phase = schedule[i]
        chars[i] = ENCODE_MAP[phase] or "d"
    end
    return table.concat(chars)
end

function Schedule.Decode(str)
    if type(str) ~= "string" or #str ~= NUM_SEGS then
        return nil
    end

    local result = {}
    for i = 1, NUM_SEGS do
        local ch = str:sub(i, i)
        local phase = DECODE_MAP[ch]
        if not phase then
            return nil
        end
        result[i] = phase
    end
    return result
end

return Schedule
