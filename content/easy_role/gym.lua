if GetModConfigData("Role Gym") == -1 then AddRecipePostInit("mighty_gym", function(inst) inst.builder_tag = nil end) end
-- 全角色健身
local function OnHitOther(inst) inst.components.mightiness:DelayDrain(10) end
local function GetMightiness(inst)
    if inst.components.mightiness ~= nil then
        return inst.components.mightiness:GetPercent()
    elseif inst.player_classified ~= nil then
        return inst.player_classified.currentmightiness:value() / TUNING.MIGHTINESS_MAX
    else
        return 0
    end
end
local function GetMightinessRateScale(inst)
    if inst.components.mightiness ~= nil then
        return inst.components.mightiness:GetRateScale()
    elseif inst.player_classified ~= nil then
        return inst.player_classified.mightinessratescale:value()
    else
        return RATE_SCALE.NEUTRAL
    end
end
local function GetCurrentMightinessState(inst)
    if inst.components.mightiness ~= nil then
        return inst.components.mightiness:GetState()
    elseif inst.player_classified ~= nil then
        local value = inst.player_classified.currentmightiness:value()
        if value >= TUNING.MIGHTY_THRESHOLD then
            return "mighty"
        elseif value >= TUNING.WIMPY_THRESHOLD then
            return "normal"
        else
            return "normal"
            -- return "wimpy"
        end
    else
        return "normal"
        -- return "wimpy"
    end
end
-- 增加健身难度
AddComponentPostInit("mightygym", function(self)
    local StartWorkout = self.StartWorkout
    self.StartWorkout = function(self, doer, ...)
        StartWorkout(self, doer, ...)
        if self.strongman and self.strongman:IsValid() then self:SetLevelArt(math.clamp(math.floor(self:CalcWeight() / 2), 2, 4), self.strongman) end
    end
    local StopWorkout = self.StopWorkout
    self.StopWorkout = function(self, ...)
        StopWorkout(self, ...)
        self:SetLevelArt(self:CalcWeight())
    end
end)
local function CalcLiftAction(inst)
    local busy = inst:HasTag("busy")
    local percent = inst.bell_percent
    -- local level = inst.player_classified.inmightygym:value()
    local level = math.clamp(math.floor(inst.player_classified.inmightygym:value() / 2 + 0.5), 2, 4)
    if inst.player_classified and inst.player_classified.currentmightiness then
        local value = inst.player_classified.currentmightiness:value()
        inst.bell_speed = value >= 50 and 0.9 or 1.8
    end
    local success_min = TUNING["BELL_SUCCESS_MIN_" .. level]
    local success_max = TUNING["BELL_SUCCESS_MAX_" .. level]
    local success_mid_min = TUNING["BELL_MID_SUCCESS_MIN_" .. level]
    local success_mid_max = TUNING["BELL_MID_SUCCESS_MAX_" .. level]
    if not busy and success_min and percent >= success_min and percent <= success_max then
        return ACTIONS.LIFT_GYM_SUCCEED_PERFECT
    elseif not busy and percent >= success_mid_min and percent <= success_mid_max then
        return ACTIONS.LIFT_GYM_SUCCEED
    else
        return ACTIONS.LIFT_GYM_FAIL
    end
end
local function bell_SetPercent(inst, val)
    val = val or inst.bell_percent
    if inst.bell ~= nil then inst.bell.AnimState:SetPercent("meter_move", val) end
    inst.bell_percent = val
end
local function updatebell(inst, dt)
    if inst.components.skilltreeupdater and inst.components.skilltreeupdater:IsActivated("wolfgang_autogym") then -- NOTES(JBK): This must be before the bell_percent gets updated.
        local liftaction = CalcLiftAction(inst)
        local level = inst.player_classified.inmightygym:value() + 1
        if level < TUNING.BELL_PERFECT_LEVEL_STARTING and liftaction == ACTIONS.LIFT_GYM_SUCCEED or liftaction == ACTIONS.LIFT_GYM_SUCCEED_PERFECT then
            if inst.components.playercontroller ~= nil then
                local x, y, z = inst.Transform:GetWorldPosition()
                local act = BufferedAction(inst, nil, liftaction, nil, Vector3(x, y, z))
                if not TheWorld.ismastersim then SendRPCToServer(RPC.LeftClick, act.action.code, x, z) end
                inst.components.playercontroller:DoAction(act)
            end
        end
    end
    if inst.bell_forward and inst.bell_percent and inst.bell_percent >= 1 then
        inst.bell_forward = false
    elseif not inst.bell_forward and inst.bell_percent and inst.bell_percent <= 0 then
        inst.bell_forward = true
    end
    local playsound = nil
    local oldpercent = inst.bell_percent
    if inst.bell_forward then
        inst.bell_SetPercent(inst, inst.bell_percent + (dt * inst.bell_speed))
        if (oldpercent < 1 and inst.bell_percent >= 1) then playsound = true end
    else
        inst.bell_SetPercent(inst, inst.bell_percent - (dt * inst.bell_speed))
        if (oldpercent > 0 and inst.bell_percent <= 0) then playsound = true end
    end
    if playsound then inst.SoundEmitter:PlaySound("wolfgang2/common/gym/rhythm") end
end
local function Startbell(inst)
    if inst == ThePlayer then
        if not inst.updateset then
            inst.bell_speed = 1.8
            inst.components.updatelooper:AddOnUpdateFn(updatebell)
            inst.updateset = true
        end
    end
end
local function ResetBell(inst)
    inst.bell_forward = true
    inst.bell_SetPercent(inst, 0)
end
local function Stopbell(inst)
    inst.components.updatelooper:RemoveOnUpdateFn(updatebell)
    inst.updateset = nil
    inst:ResetBell()
end
local function Pausebell(inst)
    inst.components.updatelooper:RemoveOnUpdateFn(updatebell)
    inst.updateset = nil
end
local function onliftgym(inst, data) if data.result == "fail" then inst:Pausebell() end end
local function LeftClickPicker(inst, target, position)
    if inst:HasTag("ingym") then
        if inst ~= ThePlayer then
            if CLIENT_REQUESTED_ACTION == ACTIONS.LIFT_GYM_SUCCEED_PERFECT or CLIENT_REQUESTED_ACTION == ACTIONS.LIFT_GYM_SUCCEED or CLIENT_REQUESTED_ACTION ==
                ACTIONS.LIFT_GYM_FAIL then return inst.components.playeractionpicker:SortActionList({CLIENT_REQUESTED_ACTION}) end
        elseif inst.components.skilltreeupdater and not inst.components.skilltreeupdater:IsActivated("wolfgang_autogym") then
            return inst.components.playeractionpicker:SortActionList({CalcLiftAction(inst)}, position)
        end
    end
    return {}
end
local function RightClickPicker(inst, target, position)
    if inst:HasTag("ingym") and not inst:HasTag("busy") then
        return inst.components.playeractionpicker:SortActionList({ACTIONS.LEAVE_GYM}, inst:GetPosition())
    end
    return {}
end
local function PointSpecialActions(inst, pos, useitem, right)
    if inst.components.playercontroller:IsEnabled() then
        if right then
            return {ACTIONS.LEAVE_GYM}
        else
            if inst ~= ThePlayer then
                if CLIENT_REQUESTED_ACTION == ACTIONS.LIFT_GYM_SUCCEED_PERFECT or CLIENT_REQUESTED_ACTION == ACTIONS.LIFT_GYM_SUCCEED or CLIENT_REQUESTED_ACTION ==
                    ACTIONS.LIFT_GYM_FAIL then return {CLIENT_REQUESTED_ACTION} end
            elseif inst.components.skilltreeupdater and not inst.components.skilltreeupdater:IsActivated("wolfgang_autogym") then
                return {CalcLiftAction(inst)}
            end
        end
    end
    return {}
end
local function actionbuttonoverride(inst, force_target)
    if inst ~= ThePlayer then
        if CLIENT_REQUESTED_ACTION == ACTIONS.LIFT_GYM_SUCCEED_PERFECT or CLIENT_REQUESTED_ACTION == ACTIONS.LIFT_GYM_SUCCEED or CLIENT_REQUESTED_ACTION ==
            ACTIONS.LIFT_GYM_FAIL then return BufferedAction(inst, nil, CLIENT_REQUESTED_ACTION, nil, inst:GetPosition()) end
    elseif inst.components.skilltreeupdater and not inst.components.skilltreeupdater:IsActivated("wolfgang_autogym") then
        return BufferedAction(inst, nil, CalcLiftAction(inst), nil, inst:GetPosition())
    end
end
local function CreateDing()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    --[[Non-networked entity]]
    inst:AddTag("NOCLICK")
    inst:AddTag("FX")
    inst.AnimState:SetBank("mighty_gym")
    inst.AnimState:SetBuild("mighty_gym")
    local player = ThePlayer
    if player and player.gym_skin and player.gym_skin ~= "" then inst.AnimState:SetSkin(player.gym_skin, "mighty_gym") end
    inst.AnimState:PlayAnimation("gym_bell_fx")
    inst.AnimState:SetFinalOffset(1)
    inst.persists = false
    inst:ListenForEvent("onremove", inst.Remove)
    return inst
end
local function ding(inst, success)
    local fx = CreateDing()
    fx.Transform:SetPosition(inst.AnimState:GetSymbolPosition("meter", 0, 0, 0))
    if success == "fail" then
        fx.AnimState:SetMultColour(1, 0, 0, 1)
    elseif success == "succeed" then
        fx.AnimState:SetMultColour(1, 1, 0, 1)
    end
end
local function CreateMightyGymBell(player)
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    --[[Non-networked entity]]
    inst:AddTag("CLASSIFIED")
    inst:AddTag("NOCLICK")
    inst:AddTag("FX")
    inst.AnimState:SetBank("mighty_gym")
    inst.AnimState:SetBuild("mighty_gym")
    if player.gym_skin and player.gym_skin ~= "" then inst.AnimState:SetSkin(player.gym_skin, "mighty_gym") end
    inst.AnimState:PlayAnimation("meter_move")
    inst.AnimState:SetPercent("meter_move", 0)
    inst.AnimState:SetFinalOffset(2)
    inst.persists = false
    inst.ding = ding
    return inst
end
local function mightybadgecheck(inst, forceshow)
    if inst == ThePlayer and inst.strongman2hm and inst.HUD and inst.HUD.controls and inst.HUD.controls.status then
        local self = inst.HUD.controls.status
        local percent = inst.player_classified.currentmightiness
        local state = GetCurrentMightinessState(inst)
        if self.mightybadge == nil and (forceshow or state == "mighty") then
            self:AddMightiness()
            if self.mightybadge and self.owner and self.onmightinessdelta == nil then
                self.onmightinessdelta = function(owner, data)
                    self:MightinessDelta(data)
                    if not inst.ingym2hm then mightybadgecheck(inst) end
                end
                self.inst:ListenForEvent("mightinessdelta", self.onmightinessdelta, self.owner)
                self:SetMightiness(self.owner:GetMightiness())
            end
        elseif self.mightybadge ~= nil and not forceshow and state ~= "mighty" then
            if self.owner and self.onmightinessdelta then
                self.inst:RemoveEventCallback("mightinessdelta", self.onmightinessdelta, self.owner)
                self.onmightinessdelta = nil
            end
            self.mightybadge:Kill()
            self.mightybadge = nil
        end
    end
end
local function OnGymCheck(inst, data)
    local self = inst and inst.HUD and inst.HUD.controls and inst.HUD.controls.status
    if data.ingym > 1 and not inst.ingym2hm then
        if inst == ThePlayer and inst.bell == nil then
            inst.bell = CreateMightyGymBell(inst)
            inst.bell.entity:SetParent(inst.entity)
        end
        mightybadgecheck(inst, true)
        inst.gymleftclickoverride2hm = inst.components.playeractionpicker.leftclickoverride
        inst.components.playeractionpicker.leftclickoverride = LeftClickPicker
        inst.gymRightClickPicker2hm = inst.components.playeractionpicker.rightclickoverride
        inst.components.playeractionpicker.rightclickoverride = RightClickPicker
        inst.gymPointSpecialActions2hm = inst.components.playeractionpicker.pointspecialactionsfn
        inst.components.playeractionpicker.pointspecialactionsfn = PointSpecialActions
        inst.gymactionbuttonoverride2hm = inst.components.playercontroller.actionbuttonoverride
        inst.components.playercontroller.actionbuttonoverride = actionbuttonoverride
        inst.ingym2hm = true
    elseif inst.ingym2hm then
        inst.ingym2hm = nil
        inst:Stopbell()
        if inst.bell ~= nil then
            inst.bell:Remove()
            inst.bell = nil
        end
        mightybadgecheck(inst)
        if inst.components.playeractionpicker.leftclickoverride == LeftClickPicker then
            inst.components.playeractionpicker.leftclickoverride = inst.gymleftclickoverride2hm
        end
        inst.gymleftclickoverride2hm = nil
        if inst.components.playeractionpicker.rightclickoverride == RightClickPicker then
            inst.components.playeractionpicker.rightclickoverride = inst.gymRightClickPicker2hm
        end
        inst.gymRightClickPicker2hm = nil
        if inst.components.playeractionpicker.pointspecialactionsfn == PointSpecialActions then
            inst.components.playeractionpicker.pointspecialactionsfn = inst.gymPointSpecialActions2hm
        end
        inst.gymPointSpecialActions2hm = nil
        if inst.components.playercontroller.actionbuttonoverride == actionbuttonoverride then
            inst.components.playercontroller.actionbuttonoverride = inst.gymactionbuttonoverride2hm
        end
        inst.gymactionbuttonoverride2hm = nil
    end
end
local rolesstrongdamage = {
    wilson = 1.75,
    willow = 1.5,
    -- "wolfgang",
    wendy = 1.5,
    wx78 = 1.5,
    wickerbottom = 1.75,
    woodie = 1.5,
    wes = 1.75,
    waxwell = 1.5,
    wathgrithr = 1.5,
    webber = 1.5,
    winona = 1.5,
    warly = 1.5,
    walter = 1.5,
    wortox = 1.5,
    wormwood = 1.75,
    wurt = 1.5,
    wanda = 1.5,
    wathom = 1.35,
    wonkey = 1.75,
    wixie = 1.5,
    winky = 1.75
}
local function externaldamagemultiplier(prefab) return rolesstrongdamage[prefab] end
local STATE_DATA = {
    wimpy = {skin_data = {skin_mode = "wimpy_skin"}, event = "powerdown", scale = 0.9},
    normal = {skin_data = {skin_mode = "normal_skin"}, event = {wimpy = "powerup", mighty = "powerdown"}, scale = 1},
    mighty = {skin_data = {skin_mode = "mighty_skin"}, event = "powerup", scale = 1.2, hunger_mult = 1.75, externaldamagemultiplier = externaldamagemultiplier}
}
local function BecomeState(self, state, silent, delay_skin, forcesound)
    if state == "wimpy" then state = "normal" end
    if not self:CanTransform(state) then return end
    silent = silent or self.inst.sg:HasStateTag("silentmorph") or not self.inst.entity:IsVisible()
    local state_data = STATE_DATA[state]
    local gym = self.inst.components.strongman.gym
    if gym then gym.components.mightygym:SetSkinModeOnGym(self.inst, state_data.skin_data.skin_mode) end
    if not silent then self.inst.sg:PushEvent(state == "normal" and state_data.event[self.state] or state_data.event) end
    if self.inst.components.combat then
        if state_data.externaldamagemultiplier then
            self.inst.components.combat.externaldamagemultipliers:SetModifier(self.inst, state_data.externaldamagemultiplier(self.inst.prefab) or 1,
                                                                              "mightiness2hm")
        else
            self.inst.components.combat.externaldamagemultipliers:RemoveModifier(self.inst, "mightiness2hm")
        end
    end
    if self.inst.components.hunger then
        if state_data.hunger_mult then
            self.inst.components.hunger.burnratemodifiers:SetModifier(self.inst, state_data.hunger_mult, "mightiness2hm")
        else
            self.inst.components.hunger.burnratemodifiers:RemoveModifier(self.inst, "mightiness2hm")
        end
    end
    -- self.inst.components.hunger.burnrate = rate or 1.4
    if not self.inst:HasTag("ingym") and not self.inst.components.rider:IsRiding() then self.inst:ApplyAnimScale("mightiness", state_data.scale) end
    local previous_state = self.state
    self.state = state
    self.inst:PushEvent("mightiness_statechange", {previous_state = previous_state, state = state})
end
local function initrole(inst)
    if inst:HasTag("strongman") or inst.GetMightiness or inst.Startbell or inst:HasTag("mightiness_normal") then return end
    inst.strongman2hm = true
    inst.GetMightiness = GetMightiness
    inst.GetMightinessRateScale = GetMightinessRateScale
    inst.GetCurrentMightinessState = GetCurrentMightinessState
    inst.bell_percent = 0
    inst.bell_forward = true
    inst.bell_speed = 1.8
    if not inst.components.updatelooper then inst:AddComponent("updatelooper") end
    inst.bell_SetPercent = bell_SetPercent
    inst.updatebell = updatebell
    inst.Startbell = Startbell
    inst.Stopbell = Stopbell
    inst.Pausebell = Pausebell
    inst.ResetBell = ResetBell
    if not TheNet:IsDedicated() then
        inst:DoTaskInTime(3, mightybadgecheck)
        inst:ListenForEvent("lift_gym", onliftgym)
    end
    inst:ListenForEvent("inmightygym", OnGymCheck)
    if not TheWorld.ismastersim then return end
    if inst.components.mightiness or inst.components.strongman or inst.components.dumbbelllifter then return end
    inst:AddComponent("strongman")
    inst:AddComponent("dumbbelllifter")
    local GetPostInitFns
    if ModManager then
        GetPostInitFns = ModManager.GetPostInitFns
        ModManager.GetPostInitFns = emptytablefn
    end
    inst:AddComponent("mightiness")
    if GetPostInitFns then ModManager.GetPostInitFns = GetPostInitFns end
    local self = inst.components.mightiness
    self:DelayDrain(10)
    self.UpdateSkinMode = nilfn
    self.BecomeState = BecomeState
    local DoDelta = self.DoDelta
    self.DoDelta = function(self, dt, force, ...)
        local v = TUNING.WIMPY_THRESHOLD
        TUNING.WIMPY_THRESHOLD = 0
        DoDelta(self, dt, force, ...)
        TUNING.WIMPY_THRESHOLD = v
    end
    inst:ListenForEvent("onhitother", OnHitOther)
end
for role, _ in pairs(rolesstrongdamage) do AddPrefabPostInit(role, initrole) end
AddComponentAction("SCENE", "mightygym", function(inst, doer, actions, right)
    if doer:HasTag("player") and doer.strongman2hm and not inst:HasTag("hasstrongman") then
        table.insert(actions, right and inst:HasTag("loaded") and ACTIONS.UNLOAD_GYM or ACTIONS.ENTER_GYM)
    end
end)
AddComponentPostInit("mightygym", function(self)
    local CanWorkout = self.CanWorkout
    self.CanWorkout = function(self, doer, ...)
        if doer and doer.strongman2hm and not doer:HasTag("strongman") then
            doer:AddTag("strongman")
            local result = CanWorkout(self, doer, ...)
            doer:RemoveTag("strongman")
            return result
        end
        return CanWorkout(self, doer, ...)
    end
end)
AddComponentAction("INVENTORY", "mightydumbbell", function(inst, doer, actions, right)
    if doer.strongman2hm and (inst.replica.equippable ~= nil and inst.replica.equippable:IsEquipped()) then
        table.insert(actions, inst:HasTag("lifting") and ACTIONS.STOP_LIFT_DUMBBELL or ACTIONS.LIFT_DUMBBELL)
    end
end)
