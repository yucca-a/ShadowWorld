local lightmode = GetModConfigData("moonlight")
if not (lightmode and type(lightmode) == "number") then return end
lightmode = -lightmode

local modelightmoons = {
    {"new", "quarter", "half", "threequarter", "full"},
    {"quarter", "half", "threequarter", "full"},
    {"half", "threequarter", "full"},
    {"threequarter", "full"},
    {"full"},
    {}
}

local lightmoons = modelightmoons[lightmode] or modelightmoons[4]

-- 月亮风暴期间正常阴晴圆缺
AddComponentPostInit("clock", function(self)
    if TheWorld and TheWorld.event_listeners and TheWorld.event_listeners.ms_lockmoonphase then
        for k, value in pairs(TheWorld.event_listeners.ms_lockmoonphase) do
            for index, fn in pairs(value) do
                local newfn = function(_inst, data, ...)
                    if data and data.lock then data.lock = false end
                    fn(_inst, data, ...)
                end
                value[index] = newfn
            end
        end
    end
end)

-- 启迪时夜间是否有光照
local _moonphasestyle = "default"
local ambientlightingsource = "scripts/components/ambientlighting.lua"
local function process(data, _moonphasechanged2)
    if (TheWorld.state.isalterawake or _moonphasestyle == "alter_active" or _moonphasestyle == "glassed_alter_active") then
        _moonphasechanged2(TheWorld, {moonphase = table.contains(lightmoons, data and data.moonphase or TheWorld.state.moonphase) and "full" or "new"})
    end
end
AddComponentPostInit("ambientlighting", function(self)
    if self.inst:HasTag("cave") then return end
    local inst = self.inst
    local index = 1
    local _moonphasechanged2
    for i, func in ipairs(inst.event_listening["moonphasechanged2"][inst]) do
        if GLOBAL.debug.getinfo(func, "S").source == ambientlightingsource then
            index = i
            break
        end
    end
    _moonphasechanged2 = inst.event_listening["moonphasechanged2"][inst][index]
    if not TheWorld:HasTag("cave") and _moonphasechanged2 then
        inst:ListenForEvent("moonphasestylechanged", function(src, data)
            _moonphasestyle = data and data.style or "default"
            process(nil, _moonphasechanged2)
        end)
        inst:ListenForEvent("moonphasechanged2", function(src, data, ...) process(data, _moonphasechanged2) end)
        inst:DoTaskInTime(1.25, function() process(nil, _moonphasechanged2) end)
    end
end)

AddClassPostConstruct("widgets/uiclock", function(self)
    if TheWorld and TheWorld:HasTag("cave") then return end
    local OnMoonPhaseStyleChanged = self.OnMoonPhaseStyleChanged
    self.OnMoonPhaseStyleChanged = function(self, data, ...)
        if data and data.style ~= "alter_active" and data.style ~= "glassed_alter_active" then
            OnMoonPhaseStyleChanged(self, data, ...)
        elseif data and data.style then
            self._moonphasebuild = self._moon_builds.default
            if self._alteractive_states[data.style] then
                self._face:SetTexture("images/hud2.xml", "clock_alter.tex")
            else
                self._face:SetTexture("images/hud.xml", "clock_NIGHT.tex")
            end
            self._moonanim:GetAnimState():SetBank("moon_phases_clock")
            self._moonanim:GetAnimState():SetBuild("moon_phases_clock")
            self.trans_out_anim = nil
            if self._phase == "night" then
                self:ShowMoon()
                self.trans_out_anim = nil
            end
        end
    end
end)

-- -- 妥协修复月晷显示
-- if TUNING.DSTU then
--     local lightstates = {
--         new = {override = 0.10, enabled = true, radius = 0.10},
--         quarter = {override = 0.10, enabled = true, radius = 0.30},
--         half = {override = 0.10, enabled = true, radius = 0.70},
--         threequarter = {override = 0.10, enabled = true, radius = 1.50},
--         full = {override = 0.50, enabled = true, radius = 5.00}
--     }
--     local function onmoonphasechagned(inst)
--         if not (inst.hastear and TheWorld.state.isalterawake) then return end
--         if (TheWorld.state.iswaxingmoon and TheWorld.state.moonphase ~= "new") or TheWorld.state.moonphase == "full" then
--             inst.AnimState:ClearOverrideSymbol("reflection_quarter")
--             inst.AnimState:ClearOverrideSymbol("reflection_half")
--             inst.AnimState:ClearOverrideSymbol("reflection_threequarter")
--         else
--             inst.AnimState:OverrideSymbol("reflection_quarter", "moondial_waning_build", "reflection_quarter")
--             inst.AnimState:OverrideSymbol("reflection_half", "moondial_waning_build", "reflection_half")
--             inst.AnimState:OverrideSymbol("reflection_threequarter", "moondial_waning_build", "reflection_threequarter")
--         end
--         local lightstate = lightstates[TheWorld.state.moonphase]
--         inst.AnimState:SetLightOverride(lightstate.override)
--         inst.Light:Enable(lightstate.enabled)
--         inst.Light:SetRadius(lightstate.radius)
--         inst.sg:GoToState("glassed_pre")
--     end
--     local function CalcPhaseAnimName(anim) return anim .. "_" .. TheWorld.state.moonphase end
--     local function CalcTransitionAnimName()
--         if TheWorld.state.moonphase == "full" then
--             return "wax_to_full"
--         elseif TheWorld.state.moonphase == "new" then
--             return "wane_to_new"
--         end
--         return (TheWorld.state.iswaxingmoon and "wax" or "wane") .. "_to_" .. TheWorld.state.moonphase
--     end
--     local function onalterawake(inst, awake)
--         if not inst.hastear and TheWorld.state.isalterawake then
--             inst.AnimState:ClearOverrideSymbol("reflection_quarter")
--             inst.AnimState:ClearOverrideSymbol("reflection_half")
--             inst.AnimState:ClearOverrideSymbol("reflection_threequarter")
--             local lightstate = lightstates.full
--             inst.AnimState:SetLightOverride(lightstate.override)
--             inst.Light:Enable(lightstate.enabled)
--             inst.Light:SetRadius(lightstate.radius)
--         end
--         if inst.hastear and not TheWorld.state.isalterawake and not (POPULATING or not inst.entity:IsAwake()) then
--             inst.AnimState:PlayAnimation(CalcPhaseAnimName("hit"))
--         end
--     end
--     local function delayonmoonphasechagned(inst) inst:DoTaskInTime(0, onmoonphasechagned) end
--     local function delayonalterawake(inst) inst:DoTaskInTime(0, onalterawake) end
--     AddStategraphPostInit("moondial", function(sg)
--         local onenterpre = sg.states.glassed_pre.onenter
--         sg.states.glassed_pre.onenter = function(inst, ...)
--             if inst.hastear and TheWorld.state.isalterawake then
--                 inst.AnimState:PlayAnimation(CalcTransitionAnimName())
--                 return
--             end
--             onenterpre(inst, ...)
--         end
--         sg.states.glassed_pre.events.trade = EventHandler("trade", function(inst) inst.sg:GoToState("glassed_pre") end)
--         local onenteridle = sg.states.glassed_idle.onenter
--         sg.states.glassed_idle.onenter = function(inst, ...)
--             if inst.hastear and TheWorld.state.isalterawake then
--                 inst.AnimState:PlayAnimation(CalcPhaseAnimName("idle"), true)
--                 inst.SoundEmitter:PlaySound("dontstarve/common/together/moondial/full_LP", "loop")
--                 return
--             end
--             onenteridle(inst, ...)
--         end
--         sg.states.glassed_idle.events.trade = sg.states.glassed_pre.events.trade
--         local onenterpst = sg.states.glassed_pst.onenter
--         sg.states.glassed_pst.onenter = function(inst, ...)
--             if inst.hastear and TheWorld.state.isalterawake then
--                 inst.AnimState:PlayAnimation(CalcPhaseAnimName("hit"))
--                 return
--             end
--             onenterpst(inst, ...)
--         end
--         sg.states.glassed_pst.events.trade = EventHandler("trade", function(inst) inst.sg:GoToState("next") end)
--     end)
--     AddPrefabPostInit("moondial", function(inst)
--         if not TheWorld.ismastersim then return end
--         inst:WatchWorldState("moonphase", delayonmoonphasechagned)
--         inst:ListenForEvent("trade", delayonmoonphasechagned)
--         inst:WatchWorldState("isalterawake", delayonalterawake)
--         delayonalterawake(inst)
--         delayonmoonphasechagned(inst)
--     end)
-- end
