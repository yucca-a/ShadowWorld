-- 岛屿冒险兼容
local SW, HAM
for i,mod in ipairs(ModManager.mods) do
    local modinfo = KnownModIndex:GetModInfo(mod.modname)
    if modinfo.ia_shipwrecked then
        SW = true
    elseif modinfo.ia_hamlet then
        HAM = true
    end
    if SW and HAM then break end
end
if HAM then return end
local random_seasons = GetModConfigData("random_seasons")
-- 混乱季节
-- 1 默认状态,原版季节顺序和长度
-- 2 随机状态,需要记录前后季节,不会连续相同三个季节,需要处理日照时长和温度变化问题
-- 3 恶劣随机状态,在随机状态基础上,季节更少秋天,且可以连续相同三个季节
-- 4 锁定季节状态
-- 5 超级恶劣随机状态(尚未加入),在恶劣随机基础上,同时随机设置季节长度
local WorldSettings_Overrides = require("worldsettings_overrides")
local easing = require("easing")
local seasons = {"autumn", "winter", "spring", "summer"}
if SW then seasons = {"mild", "wet", "green", "dry"} end
local badseasons = {seasons[1], seasons[2], seasons[3], seasons[4], seasons[2], seasons[3], seasons[4], seasons[2], seasons[3], seasons[4]}
local seasonsindex = {}
for i, season in pairs(seasons) do
    seasonsindex[season] = i
end
local NUM_CLOCK_SEGS = 16
local DEFAULT_CLOCK_SEGS = {
    autumn = {day = 8, dusk = 6, night = 2},
    winter = {day = 5, dusk = 5, night = 6},
    spring = {day = 5, dusk = 8, night = 3},
    summer = {day = 11, dusk = 1, night = 4}
}
if SW then
    DEFAULT_CLOCK_SEGS = {
        mild = {day = 12, dusk = 2, night = 2},
        wet = {day = 5, dusk = 5, night = 6},
        green = {day = 7, dusk = 6, night = 3},
        dry = {day = 10, dusk = 4, night = 2},
    }
end
local segmod = {day = 1, dusk = 1, night = 1}
local function OnSetSeasonSegModifier(inst, mod) segmod = mod end
-- 读取季节时长数据
local function getseasonsdata()
    if TheWorld and TheWorld.net and TheWorld.net.components and TheWorld.net.components.seasons and TheWorld.net.components.seasons.OnSave then
        return TheWorld.net.components.seasons:OnSave()
    end
end
-- 更新季节已存在的时长,剩余时长
local function setseasoncycles(length, elapsed, remaining, random)
    if TheWorld and TheWorld.net and TheWorld.net.components and TheWorld.net.components.seasons and TheWorld.net.components.seasons.OnSave and
        TheWorld.net.components.seasons.OnLoad then
        local data = TheWorld.net.components.seasons:OnSave()
        data.totaldaysinseason = length + (random and 1 or 0)
        data.elapseddaysinseason = elapsed
        data.remainingdaysinseason = remaining + (random and 1 or 0)
        TheWorld.net.components.seasons:OnLoad(data)
    end
end
-- 世界温度
local MIN_TEMPERATURE = -25
local MAX_TEMPERATURE = 95
local WINTER_CROSSOVER_TEMPERATURE = 5
local SUMMER_CROSSOVER_TEMPERATURE = 55
local SIMPLE_CROSSOVER_TEMPERATURE = 30
-- 计算正常季节状态下某季节特定日期的世界温度
local function CalculateSeasonTemperature(season, progress)
    return (season == seasons[2] and math.sin(PI * progress) * (MIN_TEMPERATURE - WINTER_CROSSOVER_TEMPERATURE) + WINTER_CROSSOVER_TEMPERATURE) or
               (season == seasons[3] and Lerp(WINTER_CROSSOVER_TEMPERATURE, SUMMER_CROSSOVER_TEMPERATURE, progress)) or
               (season == seasons[4] and math.sin(PI * progress) * (MAX_TEMPERATURE - SUMMER_CROSSOVER_TEMPERATURE) + SUMMER_CROSSOVER_TEMPERATURE) or
               Lerp(SUMMER_CROSSOVER_TEMPERATURE, WINTER_CROSSOVER_TEMPERATURE, progress)
end
local normalseasons = {seasons[1], seasons[3]}
-- 计算随机季节状态下世界温度
local function CalculateRandomSeasonTemperature(season, progress, prevseason, nextseason)
    if not table.contains(normalseasons, season) then
        -- 冬夏季
        if table.contains(normalseasons, prevseason) and table.contains(normalseasons, nextseason) then
            -- 前后季节都是春秋季
            return CalculateSeasonTemperature(season, progress)
        elseif prevseason == season and nextseason == season then
            -- 前后季节都是相同季节,使用正弦
            return season == seasons[2] and ((math.sin(PI * progress) + 2) * (MIN_TEMPERATURE - WINTER_CROSSOVER_TEMPERATURE) + WINTER_CROSSOVER_TEMPERATURE) or
                       ((math.sin(PI * progress) + 2) * (MAX_TEMPERATURE - SUMMER_CROSSOVER_TEMPERATURE) + SUMMER_CROSSOVER_TEMPERATURE)
        elseif progress < 0.5 then
            -- 前季节是春秋季,使用正弦
            if table.contains(normalseasons, prevseason) then
                return CalculateSeasonTemperature(season, progress)
            elseif prevseason == season then
                -- 前季节是同季节,使用直线
                return season == seasons[2] and
                           Lerp((MIN_TEMPERATURE - WINTER_CROSSOVER_TEMPERATURE) * 2 + WINTER_CROSSOVER_TEMPERATURE, MIN_TEMPERATURE, progress * 2) or
                           Lerp((MAX_TEMPERATURE - SUMMER_CROSSOVER_TEMPERATURE) * 2 + SUMMER_CROSSOVER_TEMPERATURE, MAX_TEMPERATURE, progress * 2)
            else
                -- 前季节是反季节,使用直线
                return season == seasons[2] and Lerp(SIMPLE_CROSSOVER_TEMPERATURE, MIN_TEMPERATURE, progress * 2) or
                           Lerp(SIMPLE_CROSSOVER_TEMPERATURE, MAX_TEMPERATURE, progress * 2)
            end
        else
            -- 后季节是春秋季,使用正弦
            if table.contains(normalseasons, nextseason) then
                return CalculateSeasonTemperature(season, progress)
            elseif nextseason == season then
                -- 后季节是同季节,使用直线
                return season == seasons[2] and
                           Lerp(MIN_TEMPERATURE, (MIN_TEMPERATURE - WINTER_CROSSOVER_TEMPERATURE) * 2 + WINTER_CROSSOVER_TEMPERATURE, (progress - 0.5) * 2) or
                           Lerp(MAX_TEMPERATURE, (MAX_TEMPERATURE - SUMMER_CROSSOVER_TEMPERATURE) * 2 + SUMMER_CROSSOVER_TEMPERATURE, (progress - 0.5) * 2)
            else
                -- 后季节是反季节,使用直线
                return season == seasons[2] and Lerp(MIN_TEMPERATURE, SIMPLE_CROSSOVER_TEMPERATURE, (progress - 0.5) * 2) or
                           Lerp(MAX_TEMPERATURE, SIMPLE_CROSSOVER_TEMPERATURE, (progress - 0.5) * 2)
            end
        end
    elseif progress < 0.5 then
        -- 春秋季,前半段
        if table.contains(normalseasons, prevseason) then
            return SIMPLE_CROSSOVER_TEMPERATURE
        else
            return prevseason == seasons[2] and Lerp(WINTER_CROSSOVER_TEMPERATURE, SIMPLE_CROSSOVER_TEMPERATURE, progress * 2) or
                       Lerp(SUMMER_CROSSOVER_TEMPERATURE, SIMPLE_CROSSOVER_TEMPERATURE, progress * 2)
        end
    else
        -- 春秋季,后半段
        if table.contains(normalseasons, nextseason) then
            return SIMPLE_CROSSOVER_TEMPERATURE
        else
            return nextseason == seasons[2] and Lerp(SIMPLE_CROSSOVER_TEMPERATURE, WINTER_CROSSOVER_TEMPERATURE, (progress - 0.5) * 2) or
                       Lerp(SIMPLE_CROSSOVER_TEMPERATURE, SUMMER_CROSSOVER_TEMPERATURE, (progress - 0.5) * 2)
        end
    end
end
-- 锁定季节和随机季节状态下世界温度计算方式有所变化
local function setseasonworldtemperature(inst, instdata)
    if inst.net and inst.net.components and inst.net.components.worldtemperature and inst.net.components.worldtemperature.OnSave and
        inst.net.components.worldtemperature.OnLoad then
        local data = inst.net.components.worldtemperature:OnSave()
        if instdata.lockseason then
            data.seasontemperature = CalculateSeasonTemperature(inst.state.season, 0.5)
        elseif instdata.randomseason and instdata.prevseason and instdata.nextseason and instdata.progress then
            data.seasontemperature = CalculateRandomSeasonTemperature(inst.state.season, instdata.progress, instdata.prevseason, instdata.nextseason) or
                                         data.seasontemperature
        end
        inst.net.components.worldtemperature:OnLoad(data)
    end
end
-- 默认状态,不需要处理日照时长和温度变化问题
local function resetseasonslength(inst)
    if inst.ismastersim and inst.topology and inst.topology.overrides and GetTableSize(inst.topology.overrides) > 0 and WorldSettings_Overrides and
        WorldSettings_Overrides.Post then
        for _, season in ipairs(seasons) do
            if WorldSettings_Overrides.Post[season] then
                local override = WorldSettings_Overrides.Post[season]
                local defaultdifficulty = inst.topology.overrides[season] or "default"
                override(defaultdifficulty)
            end
        end
    end
end
-- 锁定季节状态,不需要处理日照时长和温度变化问题
local function setseasonalways(inst)
    if inst.ismastersim and inst.topology and inst.topology.overrides and GetTableSize(inst.topology.overrides) > 0 and WorldSettings_Overrides and
        WorldSettings_Overrides.Post then
        for _, season in ipairs(seasons) do
            if WorldSettings_Overrides.Post[season] then
                local override = WorldSettings_Overrides.Post[season]
                local defaultdifficulty = inst.topology.overrides[season] or "default"
                if defaultdifficulty == "noseason" then defaultdifficulty = "veryshortseason" end
                local difficulty = season == inst.state.season and defaultdifficulty or "noseason"
                override(difficulty)
            end
        end
    end
end
-- 随机状态,需要处理日照时长和温度变化问题
local function setrandomseasonslength(inst)
    if inst.ismastersim and inst.topology and inst.topology.overrides and GetTableSize(inst.topology.overrides) > 0 and WorldSettings_Overrides and
        WorldSettings_Overrides.Post then
        local _season = inst.state.season
        local index = seasonsindex[_season]
        local prevseason = seasons[index > 1 and (index - 1) or #seasons]
        for _, season in ipairs(seasons) do
            if WorldSettings_Overrides.Post[season] then
                local override = WorldSettings_Overrides.Post[season]
                local defaultdifficulty = inst.topology.overrides[season] or "default"
                if defaultdifficulty == "noseason" then defaultdifficulty = "veryshortseason" end
                local difficulty = season == prevseason and defaultdifficulty or "noseason"
                override(difficulty)
            end
        end
    end
end
-- 洞穴通过此接口同步地表季节数据
local function syncseasondata(inst, randomseasondata)
    if inst.ismastershard then SendModRPCToShard(GetShardModRPC("MOD_HARDMODE", "syncseason2hm"), nil, DataDumper(randomseasondata, nil, true)) end
end
-- 更改主世界和其他世界的季节
local function SetWorldSeason(inst, season)
    if inst.delayrefreshseason2hmtask then inst.delayrefreshseason2hmtask = nil end
    inst:PushEvent("ms_setseason", season)
    SendModRPCToShard(GetShardModRPC("MOD_HARDMODE", "ms_setseason_update"), nil, season)
end
-- 读取月亮风暴开启状态
local function enablemoonstorm(inst)
    if inst.components.moonstormmanager then
        if inst.components.moonstormmanager.moonstorm_spark_task or inst.components.moonstormmanager.startstormtask then return true end
        local data = inst.components.moonstormmanager:OnSave()
        if data and (data.startstormtask or data.currentbasenodeindex ~= nil) then return true end
    end
end
-- 地表世界动态更新季节状态
local seasonsinit -- 游戏重新开始时,季节长度都会恢复原状,因此此时需要额外补充更新
local function refreshseason(inst)
    if inst.delayrefreshseason2hmtask then inst.delayrefreshseason2hmtask = nil end
    if not (inst.components.persistent2hm and inst.components.persistent2hm.data) then return end
    if not inst.components.persistent2hm.data.randomseason then inst.components.persistent2hm.data.randomseason = {} end
    local instdata = inst.components.persistent2hm.data.randomseason
    -- 仅一次,读取各个季节的时长,此时游戏数据应该未受到任何影响
    local seasonsdata = getseasonsdata()
    if not instdata.lengthdata and seasonsdata and seasonsdata.lengths and seasonsdata.lengths then instdata.lengthdata = seasonsdata.lengths end
    -- 监听季节变化,初始化季节起始时间
    local season = inst.state.season
    if not instdata.season then instdata.season = season end
    if not instdata.seasoncycles then
        instdata.seasoncycles = math.clamp(inst.state.cycles - (seasonsdata and seasonsdata.elapseddaysinseason or 0), 0, inst.state.cycles)
    end
    if not instdata.prevseason then
        local index = seasonsindex[season]
        instdata.prevseason = seasons[index > 1 and (index - 1) or #seasons]
    end
    local lastseason = instdata.season
    if lastseason ~= season then
        instdata.prevseason = lastseason
        instdata.season = season
        instdata.seasoncycles = inst.state.cycles
    end
    -- 计算当前世界应该变成的状态
    local lockseason = TUNING.alterguardianseason2hm and TUNING.alterguardianseason2hm ~= 0
    local hasmoonstorm = enablemoonstorm(inst)
    local randomseason = not lockseason and random_seasons and
                             (random_seasons == -5 or random_seasons == -4 or ((random_seasons == -3 or random_seasons == -2) and hasmoonstorm) or
                                 (random_seasons == -1 and not hasmoonstorm))
    local badrandomseason = not lockseason and random_seasons and (random_seasons == -5 or ((random_seasons == -4 or random_seasons == -4) and hasmoonstorm))
    -- 根据
    if lockseason then
        local haschange = not instdata.lockseason
        if not instdata.lockseason then instdata.lockseason = true end
        if instdata.progress then instdata.progress = nil end
        if instdata.nextseason then instdata.nextseason = nil end
        if instdata.randomseason then instdata.randomseason = nil end
        if instdata.badrandomseason then instdata.badrandomseason = nil end
        if haschange or not seasonsinit or lastseason ~= season or not instdata.length then
            setseasonalways(inst)
            instdata.length = 10000
        elseif not inst.delayrefreshseason2hmtask then
            inst.delayrefreshseason2hmtask = true
        end
        instdata.elapsed = (inst.state.cycles - instdata.seasoncycles) % 10000
        instdata.remaining = 10000 - instdata.elapsed
        setseasoncycles(10000, instdata.elapsed, instdata.remaining)
        if inst.delayrefreshseason2hmtask == true then inst.delayrefreshseason2hmtask = nil end
        setseasonworldtemperature(inst, instdata)
    elseif randomseason then
        local haschange = not instdata.randomseason
        if not instdata.randomseason then instdata.randomseason = true end
        if instdata.lockseason then instdata.lockseason = nil end
        if instdata.badrandomseason ~= badrandomseason then instdata.badrandomseason = badrandomseason end
        if not instdata.prevseason then
            local index = seasonsindex[season]
            instdata.prevseason = seasons[index > 1 and (index - 1) or #seasons]
        end
        if haschange or not instdata.nextseason or lastseason ~= season then
            if badrandomseason then
                instdata.nextseason = badseasons[math.random(#badseasons)]
            else
                while true do
                    local nextseason = seasons[math.random(#seasons)]
                    if nextseason ~= season then
                        instdata.nextseason = nextseason
                        break
                    end
                end
            end
        end
        if haschange or not seasonsinit or lastseason ~= season or not instdata.length then
            instdata.length = math.max(seasonsdata and seasonsdata.lengths and seasonsdata.lengths[season] or 5,
                                       instdata.lengthdata and instdata.lengthdata[season] or 5, 5)
            setrandomseasonslength(inst)
        elseif not inst.delayrefreshseason2hmtask then
            inst.delayrefreshseason2hmtask = true
        end
        instdata.progress = math.clamp((inst.state.cycles - instdata.seasoncycles) / instdata.length, 0, 1)
        instdata.elapsed = math.clamp(inst.state.cycles - instdata.seasoncycles, 0, instdata.length)
        instdata.remaining = math.clamp(instdata.length - instdata.elapsed, 0, instdata.length)
        setseasoncycles(instdata.length, instdata.elapsed, instdata.remaining, true)
        if inst.delayrefreshseason2hmtask == true then inst.delayrefreshseason2hmtask = nil end
        if instdata.progress >= 1 then
            if inst.delayrefreshseason2hmtask and inst.delayrefreshseason2hmtask ~= true then inst.delayrefreshseason2hmtask:Cancel() end
            inst.delayrefreshseason2hmtask = inst:DoTaskInTime(0, SetWorldSeason, instdata.nextseason)
        end
        setseasonworldtemperature(inst, instdata)
    else
        local haschange = instdata.lockseason or instdata.randomseason
        if instdata.lockseason then instdata.lockseason = nil end
        if instdata.randomseason then instdata.randomseason = nil end
        if haschange or not instdata.nextseason or lastseason ~= season then
            local index = seasonsindex[season]
            instdata.nextseason = seasons[index < 4 and (index + 1) or 1]
        end
        if instdata.badrandomseason then instdata.badrandomseason = nil end
        if instdata.length then instdata.length = nil end
        if instdata.progress then instdata.progress = nil end
        if haschange then
            if seasonsinit then resetseasonslength(inst) end
            local length = math.max(seasonsdata and seasonsdata.lengths and seasonsdata.lengths[season] or 5,
                                    instdata.lengthdata and instdata.lengthdata[season] or 5, 5)
            if (inst.state.cycles - instdata.seasoncycles) >= length then
                local index = seasonsindex[season]
                local nextseason = seasons[index < 4 and (index + 1) or 1]
                if inst.delayrefreshseason2hmtask and inst.delayrefreshseason2hmtask ~= true then inst.delayrefreshseason2hmtask:Cancel() end
                inst.delayrefreshseason2hmtask = inst:DoTaskInTime(0, SetWorldSeason, nextseason)
            else
                local elapsed = math.clamp(inst.state.cycles - instdata.seasoncycles, 0, length)
                local remaining = math.clamp(length - elapsed, 0, length)
                setseasoncycles(length, elapsed, remaining)
            end
        end
    end
    -- instdata.actionindex = math.random(100)
    syncseasondata(inst, instdata)
    if not seasonsinit then seasonsinit = true end
end
local function delayrefreshseason(inst) if not inst.delayrefreshseason2hmtask then inst.delayrefreshseason2hmtask = inst:DoTaskInTime(0, refreshseason) end end
AddPrefabPostInit("world", function(inst)
    if not inst.ismastersim then return end
    if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
    inst:ListenForEvent("ms_setseasonsegmodifier", OnSetSeasonSegModifier)
    if not inst.ismastershard then return inst end
    delayrefreshseason(inst)
    inst:ListenForEvent("seasontick", delayrefreshseason)
    inst:ListenForEvent("ms_startthemoonstorms", delayrefreshseason)
    inst:ListenForEvent("ms_stopthemoonstorms", delayrefreshseason)
    inst:ListenForEvent("delayrefreshseason2hm", delayrefreshseason)
end)

-- 洞穴同步地表状态
AddShardModRPCHandler("MOD_HARDMODE", "syncseason2hm", function(shard_id, _data)
    if _data and TheWorld and not TheWorld.ismastershard and TheWorld.components and TheWorld.components.persistent2hm and
        TheWorld.components.persistent2hm.data then
        local success, instdata = RunInSandboxSafe(_data)
        if not success then return end
        local olddata = TheWorld.components.persistent2hm.data.randomseason or {}
        TheWorld.components.persistent2hm.data.randomseason = instdata
        if instdata.lockseason then
            if not olddata.lockseason or not seasonsinit or olddata.season ~= TheWorld.state.season then setseasonalways(TheWorld) end
            setseasoncycles(10000, instdata.elapsed, instdata.remaining)
            setseasonworldtemperature(TheWorld, instdata)
        elseif instdata.randomseason then
            if not olddata.randomseason or not seasonsinit or olddata.season ~= TheWorld.state.season then setrandomseasonslength(TheWorld) end
            setseasoncycles(instdata.length, instdata.elapsed, instdata.remaining, true)
            setseasonworldtemperature(TheWorld, instdata)
        elseif olddata.lockseason or olddata.randomseason then
            if seasonsinit then resetseasonslength(TheWorld) end
            local seasonsdata = getseasonsdata()
            local length = math.max(seasonsdata and seasonsdata.lengths and seasonsdata.lengths[TheWorld.state.season] or 5,
                                    instdata.lengthdata and instdata.lengthdata[TheWorld.state.season] or 5, 5)
            if (TheWorld.state.cycles - instdata.seasoncycles) < length then
                local elapsed = math.clamp(TheWorld.state.cycles - instdata.seasoncycles, 0, length)
                local remaining = math.clamp(length - elapsed, 0, length)
                setseasoncycles(length, elapsed, remaining)
            end
        end
        if not seasonsinit then seasonsinit = true end
    end
end)

-- 混乱季节时日照时长处理
local dusk_mode = GetModConfigData("dusk_change")
local function GetModifiedSegs(retsegs, mod)
    local importance = {"day", "dusk", "night"}
    if mod then
        table.sort(importance, function(a, b) return mod[a] < mod[b] end)
        for _, k in ipairs(importance) do retsegs[k] = math.ceil(math.clamp(retsegs[k] * mod[k], 0, 16)) end
    end
    retsegs.day = math.max(0, retsegs.day or 0)
    retsegs.dusk = math.max(0, retsegs.dusk or 0)
    retsegs.night = math.max(0, retsegs.night or 0)
    local total = retsegs.day + retsegs.dusk + retsegs.night
    if total <= 0 then
        -- 与 common/patch.lua 的 uiclock 保护一致：全 0 时原循环会卡死。
        retsegs.day, retsegs.dusk, retsegs.night = 10, 3, 3
        return retsegs
    end
    local guard = 0
    while total ~= 16 and guard < 64 do
        guard = guard + 1
        for _, k in ipairs(importance) do
            if total >= 16 and retsegs[k] > 1 then
                retsegs[k] = retsegs[k] - 1
            elseif total < 16 and retsegs[k] > 0 then
                retsegs[k] = retsegs[k] + 1
            end
            total = retsegs.day + retsegs.dusk + retsegs.night
            if total == 16 then break end
        end
    end
    if total ~= 16 then
        local diff = 16 - total
        if diff > 0 then
            retsegs.day = retsegs.day + diff
        else
            for _, k in ipairs(importance) do
                local take = math.min(retsegs[k], -diff)
                retsegs[k] = retsegs[k] - take
                diff = diff + take
                if diff == 0 then break end
            end
        end
    end
    return retsegs
end
local mindusks = {autumn = 2, winter = 1, spring = 3, summer = nil}
if SW then mindusks = {mild = 2, wet = 1, green = 3, dry = nil} end
local function processseasonclocksegs(data)
    local instdata = TheWorld and TheWorld.components and TheWorld.components.persistent2hm and TheWorld.components.persistent2hm.data and
                         TheWorld.components.persistent2hm.data.randomseason
    if instdata and instdata.randomseason and instdata.season and instdata.length and instdata.nextseason and instdata.prevseason and instdata.progress then
        local seasonsdata = getseasonsdata()
        if seasonsdata and seasonsdata.segs then
            local segs = seasonsdata.segs
            local resultsegs = {day = data.day, dusk = data.dusk, night = data.night}
            local season = instdata.season
            local toseason = instdata.progress < .5 and instdata.prevseason or instdata.nextseason
            if season ~= toseason then
                -- 随机季节下,连续不同季节重新计算昼夜时长
                local fromsegs = segs[season] or DEFAULT_CLOCK_SEGS[season]
                local tosegs = segs[toseason] or DEFAULT_CLOCK_SEGS[toseason]
                local p = .5 - math.sin(PI * instdata.progress) * .5
                resultsegs = {
                    day = math.floor(easing.linear(p, fromsegs.day, tosegs.day - fromsegs.day, 1) + .5),
                    night = math.floor(easing.linear(p, fromsegs.night, tosegs.night - fromsegs.night, 1) + .5)
                }
                resultsegs.dusk = NUM_CLOCK_SEGS - resultsegs.day - resultsegs.night
                resultsegs = GetModifiedSegs(resultsegs, segmod)
            elseif not table.contains(normalseasons, season) then
                -- 随机季节下遇到连续相同冬夏时在原来基础上调整昼夜时长
                if instdata.prevseason == season and instdata.nextseason == season then
                    if season == seasons[2] and resultsegs.day > 1 then
                        local reduce = resultsegs.day - 1
                        resultsegs.day = 1
                        resultsegs.night = resultsegs.night + reduce
                    elseif season == seasons[4] and (resultsegs.night + resultsegs.dusk) > 2 then
                        local reduce = resultsegs.night + resultsegs.dusk - 2
                        resultsegs.night = 1
                        resultsegs.dusk = 1
                        resultsegs.day = resultsegs.day + reduce
                    end
                elseif season == toseason then
                    local p = math.sin(PI * instdata.progress)
                    if season == seasons[2] and resultsegs.day > 2 then
                        local newday = math.ceil(math.clamp(resultsegs.day * p, 2, resultsegs.day))
                        local reduce = resultsegs.day - newday
                        resultsegs.day = newday
                        resultsegs.night = resultsegs.night + reduce
                    elseif season == seasons[4] and (resultsegs.night + resultsegs.dusk) > 3 and resultsegs.dusk >= 2 and resultsegs.night >= 1 then
                        local newnight = math.ceil(math.clamp(resultsegs.night * p, 1, resultsegs.night))
                        local newdusk = math.ceil(math.clamp(resultsegs.dusk * p, 2, resultsegs.dusk))
                        local reduce = resultsegs.night + resultsegs.dusk - newnight - newdusk
                        resultsegs.night = newnight
                        resultsegs.dusk = newdusk
                        resultsegs.day = resultsegs.day + reduce
                    end
                end
            end
            data.day = resultsegs.day
            data.dusk = resultsegs.dusk
            data.night = resultsegs.night
            if dusk_mode == true then
                local dusklength = mindusks[TheWorld.state.season or "autumn"]
                if dusklength and data.dusk >= dusklength and data.night then
                    data.night = data.night + data.dusk - dusklength
                    data.dusk = dusklength
                end
            end
            data = GetModifiedSegs(data)
        end
    end
end
AddComponentPostInit("clock", function(self)
    if TheWorld and TheWorld.ismastersim and TheWorld.event_listeners and TheWorld.event_listeners.ms_setclocksegs then
        for k, value in pairs(TheWorld.event_listeners.ms_setclocksegs) do
            for index, fn in pairs(value) do
                local newfn = function(inst, data, ...)
                    if data and data.day and data.dusk and data.night and data.day > 0 and data.dusk > 0 and data.night > 0 then
                        processseasonclocksegs(data)
                    end
                    fn(inst, data, ...)
                end
                value[index] = newfn
            end
        end
    end
end)

local seasonstext = {autumn = "秋天", winter = "冬天", spring = "春天", summer = "夏天"}
if SW then seasonstext = {mild = "温和季", wet = "飓风季", green = "雨季", dry = "干旱季"} end
local function AnnounceSeason()
    if TheWorld.state.temperature and TheWorld.net and TheWorld.net.components and TheWorld.net.components.worldtemperature and
        TheWorld.net.components.worldtemperature.OnSave then
        local data = TheWorld.net.components.worldtemperature:OnSave()
        if data and data.season and data.seasontemperature and data.phasetemperature then
            TheNet:Announce(STRINGS.NAMES.WINTEROMETER .. ":" .. (TUNING.isCh2hm and
                                ((TheWorld:HasTag("cave") and "洞穴" or "地表") .. (seasonstext[data.season] or "秋天") .. "温度" ..
                                    string.format("%.2f", TheWorld.state.temperature) .. ",季节影响" .. string.format("%.2f", data.seasontemperature) ..
                                    ",日照影响" .. string.format("%.2f", data.phasetemperature)) or
                                ((TheWorld:HasTag("cave") and "Cave " or "Forest ") .. (seasonstext[data.season] or "autumn ") .. "temperature" ..
                                    string.format("%.2f", TheWorld.state.temperature) .. ",From Season " .. string.format("%.2f", data.seasontemperature) ..
                                    ",From Phase " .. string.format("%.2f", data.phasetemperature))))
        end
    end
end
AddPrefabPostInit("winterometer", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.inspectable then
        local GetDescription = inst.components.inspectable.GetDescription
        inst.components.inspectable.GetDescription = function(self, ...)
            AnnounceSeason()
            return GetDescription(self, ...)
        end
    end
end)

-- 克劳斯兼容
local function resetsacktime(inst) TUNING.KLAUSSACK_MAX_SPAWNS = 10000 end
AddComponentPostInit("klaussackspawner", function(self) self.inst:DoTaskInTime(0, resetsacktime) end)

-- 火炉保护
local campfires = {"chiminea", "sea_chiminea", "cotl_tabernacle_level3", "cotl_tabernacle_level2", "cotl_tabernacle_level1"}
local function protectcampfire(inst) inst:AddTag("campfire2hm") end
for _, campfire in ipairs(campfires) do AddPrefabPostInit(campfire, protectcampfire) end
local function protectcampfire2(inst) inst:AddTag("nightlight2hm") end
AddPrefabPostInit("nightlight", protectcampfire2)

-- local precipmodes = {dynamic = "", always = "无限降水", never = "终止降水"}
-- local function AnnounceWeather()
--     if TheWorld.net and TheWorld.net.components and TheWorld.net.components.weather and TheWorld.net.components.weather.OnSave and
--         TheWorld.net.components.weather.OnLoad then
--         local data = TheWorld.net.components.weather:OnSave()
--         TheNet:Announce(TUNING.isCh2hm and
--                             ((TheWorld:HasTag("cave") and "洞穴" or "地表") .. (seasonstext[data.season or "autumn"] or "秋天") .. "温度" ..
--                                 (TheWorld.state.temperature or "x") .. ",季节温度" .. (data.seasontemperature or "x") .. ",日照温度" ..
--                                 (data.phasetemperature or "x")) or
--                             ((TheWorld:HasTag("cave") and "Cave " or "Forest ") .. (seasonstext[data.season or "autumn"] or "autumn ") .. "temperature" ..
--                                 (TheWorld.state.temperature or "x") .. ",From Season " .. (data.seasontemperature or "x") .. ",From Phase " ..
--                                 (data.phasetemperature or "x")))
--     end
-- end
-- AddPrefabPostInit("rainometer", function(inst)
--     if not TheWorld.ismastersim then return end
--     if inst.components.inspectable then
--         local GetDescription = inst.components.inspectable.GetDescription
--         inst.components.inspectable.GetDescription = function(self, ...)
--             GetDescription(self, ...)
--             AnnounceWeather()
--         end
--     end
-- end)
