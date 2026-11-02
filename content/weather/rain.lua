local rain_change = GetModConfigData("rain_change")
local rainrate = rain_change == -1 and 32 or 64
local moisturerate = rain_change == -1 and 3 or 6
TUNING.moisturerate2hm = moisturerate
-- local drymoisturerate = rain_change == -1 and 0.8 or 0.65
local drymoisturerate = 1
local difficultyrate = {never = 0, rare = 0.5, default = 1, often = 2, squall = 30, always = 100}

-- 增加雨水
local function SetRainScale(inst)
    if inst.delayrefreshrain2hmtask then inst.delayrefreshrain2hmtask = nil end
    local difficult = inst.topology and inst.topology.overrides and inst.topology.overrides.weather
    if not difficult then return end
    local defaultrate = difficultyrate[difficult] or 1
    if defaultrate >= 100 or defaultrate <= 0 then return end
    local instdata = inst.components and inst.components.persistent2hm and inst.components.persistent2hm.data and
                         inst.components.persistent2hm.data.randomseason
    if instdata and instdata.randomseason and instdata.length and instdata.nextseason and instdata.prevseason and instdata.seasoncycles and instdata.progress then
        local toseason = instdata.progress < .5 and instdata.prevseason or instdata.nextseason
        local p = 1 - math.sin(PI * instdata.progress)
        if toseason == "spring" then
            if season == "spring" then
                inst:PushEvent("ms_setprecipitationmode", "always")
                inst:PushEvent("ms_setmoisturescale", 10000)
                return
            end
            defaultrate = defaultrate * (1 + p)
        elseif toseason == "summer" then
            if season == "summer" and not inst:HasTag("cave") then
                inst:PushEvent("ms_setprecipitationmode", "never")
                inst:PushEvent("ms_setmoisturescale", 0)
                return
            end
            defaultrate = defaultrate * (1 - 0.5 * p)
        elseif toseason == "winter" then
            defaultrate = defaultrate * (1 + 0.5 * p)
        end
    end
    inst:PushEvent("ms_setprecipitationmode", "dynamic")
    if inst.state.season == "summer" then
        inst:PushEvent("ms_setmoisturescale", (inst:HasTag("cave") and rainrate / 16 or rainrate / 64) * defaultrate)
    elseif inst.state.season == "spring" or inst.state.season == "winter" then
        inst:PushEvent("ms_setmoisturescale", (inst:HasTag("cave") and rainrate or rainrate / 4) * defaultrate)
    else
        inst:PushEvent("ms_setmoisturescale", (inst:HasTag("cave") and rainrate / 8 or rainrate / 32) * defaultrate)
    end
end

local function delayrefreshrain(inst) if not inst.delayrefreshrain2hmtask then inst.delayrefreshrain2hmtask = inst:DoTaskInTime(FRAMES, SetRainScale) end end
AddPrefabPostInit("world", function(inst)
    if not inst.ismastersim then return inst end
    if not inst.components.waterstreakrain2hm then inst:AddComponent("waterstreakrain2hm") end
    inst.components.waterstreakrain2hm.enablerain = true
    delayrefreshrain(inst)
    inst:ListenForEvent("seasontick", delayrefreshrain)
    inst:ListenForEvent("ms_startthemoonstorms", delayrefreshrain)
    inst:ListenForEvent("ms_stopthemoonstorms", delayrefreshrain)
    inst:ListenForEvent("delayrefreshseason2hm", delayrefreshrain)
end)

AddComponentPostInit("moisture", function(self)
    if not self.inst:HasTag("player") then return end
    local OnUpdate = self.OnUpdate
    self.OnUpdate = function(self, ...)
        self.updating2hm = true
        OnUpdate(self, ...)
        self.updating2hm = nil
    end
    local DoDelta = self.DoDelta
    self.DoDelta = function(self, amount, ...) return DoDelta(self, amount and self.updating2hm and amount > 0 and amount * moisturerate or amount, ...) end
end)

local function checkDynamicShadow(inst) if inst.DynamicShadow then inst.DynamicShadow:Enable(inst:HasTag("DynamicShadow2hm")) end end
AddPrefabPostInit("waterstreak_projectile", function(inst)
    if not inst.DynamicShadow then
        inst.entity:AddDynamicShadow()
        inst.DynamicShadow:SetSize(2.5, 1.5)
        inst:DoTaskInTime(0, checkDynamicShadow)
        inst.DynamicShadow:Enable(false)
    end
end)

-- 青蛙雨BUG修复,且持续时长优化
local frograinindex = 0
local function OnFrogRainPhase(inst)
    if inst.state.israining and inst.state.isspring and inst.components.frograin and inst.components.frograin.OnSave then
        local data = inst.components.frograin:OnSave()
        if data and data.frogcap then
            if data.frogcap <= 0 then
                -- 春天累计下雨20天后0.08概率下青蛙雨
                frograinindex = math.clamp(-160, frograinindex - 1, 0)
                if math.random() < math.clamp(0, -frograinindex * TUNING.FROG_RAIN_CHANCE / 160, 1) then
                    data.frogcap = math.random(TUNING.FROG_RAIN_LOCAL_MIN, TUNING.FROG_RAIN_LOCAL_MAX)
                    inst.components.frograin:OnLoad(data)
                end
            else
                -- 青蛙雨时,1天内大概率停止青蛙雨
                frograinindex = math.clamp(0, frograinindex + 1, 4)
                if math.random() > math.clamp(0, 1 - frograinindex * (1 - TUNING.FROG_RAIN_CHANCE) / 4, 1) then
                    data.frogcap = 0
                    inst.components.frograin:OnLoad(data)
                end
            end
        end
    end
end
local frograinsource = "scripts/components/frograin.lua"
AddComponentPostInit("frograin", function(self)
    self.inst:WatchWorldState("cycles", OnFrogRainPhase)
    self.inst:WatchWorldState("phase", OnFrogRainPhase)
    local inst = self.inst
    local _precipitationrate
    local index = 1
    for i, func in ipairs(inst.worldstatewatching["precipitationrate"]) do
        if GLOBAL.debug.getinfo(func, "S").source == frograinsource then
            index = i
            break
        end
    end
    _precipitationrate = inst.worldstatewatching["precipitationrate"][index]
    if _precipitationrate then
        inst:StopWatchingWorldState("precipitationrate", _precipitationrate)
        inst:WatchWorldState("precipitationrate", function(...) _precipitationrate(...) end)
    end
end)

-- 潮湿需要多次点燃
local function talkerror(inst)
    if inst.components.talker then inst.components.talker:Say(TUNING.isCh2hm and "太潮湿了,我要再试一次" or "too wet and need retry") end
end
local lightfn = ACTIONS.LIGHT.fn
ACTIONS.LIGHT.fn = function(act, ...)
    if act.doer and act.target and act.target:IsValid() and act.doer.prefab ~= "willow" and act.target:GetIsWet() and math.random() > 0.35 then
        act.doer:DoTaskInTime(0, talkerror)
        return false
    end
    return lightfn(act, ...)
end
