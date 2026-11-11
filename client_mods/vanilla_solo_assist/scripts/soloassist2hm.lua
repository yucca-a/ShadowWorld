local M = {}
local SPEED_MODES = {
    [0] = {name="关闭", attempts=0, host=1},
    {name="温和", attempts=3, host=1.8},
    {name="加速", attempts=4, host=3.5},
    {name="极速", attempts=8, host=5},
}

-- Match actual control states, not the broad busy tag (crafting is busy too).
local CONTROL_STATES = {
    frozen=true, thaw=true, knockout=true, yawn=true, hit=true, hit_souloverload=true,
    electrocute=true, knockback=true, knockbacklanded=true, knockback_pst=true,
    pinned_pre=true, pinned=true, pinned_hit=true,
}
local CONTROL_HASHES = {}
for name in pairs(CONTROL_STATES) do CONTROL_HASHES[hash(name)] = true end

function M.IsControlled(p)
    local classified = p.player_classified
    if not TheWorld.ismastersim and classified and classified.currentstate then
        local state = classified.currentstate:value()
        if state ~= 0 then return CONTROL_HASHES[state] == true end
    end
    local sg = p.sg
    if sg and sg.currentstate and CONTROL_STATES[sg.currentstate.name] then return true end
    -- With prediction disabled there may be no replicated state hash.
    -- Keep this fallback specific; a lingering frozen component alone is insufficient.
    return p:HasTag("busy") and p.AnimState ~= nil and
        (p.AnimState:IsCurrentAnimation("frozen") or p.AnimState:IsCurrentAnimation("frozen_loop_pst"))
end

local function Alive(p)
    return p and p:IsValid() and p == ThePlayer and not p:HasTag("playerghost")
end

-- Use the same camera-relative direction as the original player controller.
local function Direction()
    local x = TheInput:GetAnalogControlValue(CONTROL_MOVE_RIGHT) - TheInput:GetAnalogControlValue(CONTROL_MOVE_LEFT)
    local y = TheInput:GetAnalogControlValue(CONTROL_MOVE_UP) - TheInput:GetAnalogControlValue(CONTROL_MOVE_DOWN)
    if math.abs(x) < TUNING.CONTROLLER_DEADZONE_RADIUS and math.abs(y) < TUNING.CONTROLLER_DEADZONE_RADIUS then return end
    return (TheCamera:GetRightVec() * x - TheCamera:GetDownVec() * y):GetNormalized()
end

function M.Recover(p)
    if not Alive(p) then return false end
    local x, _, z = p.Transform:GetWorldPosition()
    if not p:CanSeePointOnMiniMap(x, 0, z) then return false end
    if TheWorld.ismastersim then
        local pc = p.components.playercontroller
        if not pc then return false end
        pc:OnMapAction(ACTIONS.MAPDELIVER_MAP.code, Vector3(x, 0, z), p)
    else
        SendRPCToServer(RPC.DoActionOnMap, ACTIONS.MAPDELIVER_MAP.code, x, z, p)
    end
    return true
end

function M.Attach(p, options)
    if not Alive(p) or p._soloassist2hm then return end
    options = options or {}
    local state = {mode=0, enabled=false, auto_recover=false, next_recover=0, level=0}
    p._soloassist2hm = state
    local pc = p.components.playercontroller
    local function ClearMouse(stop)
        local mouse = state.mouse
        if mouse and mouse.handle then TheWorld.Pathfinder:KillSearch(mouse.handle) end
        state.mouse = nil
        if mouse and stop then
            local loco = p.components.locomotor
            if loco and (not loco.bufferedaction or loco.bufferedaction.action == ACTIONS.WALKTO) then
                loco:Stop()
                loco:Clear()
            end
            -- The correction packets bypass the controller's cached remote_vector;
            -- send the native stop even when that cache already says 'stopped'.
            if not TheWorld.ismastersim then SendRPCToServer(RPC.StopWalking) end
        end
    end
    -- Observe the native action chosen by the controller, not raw screen clicks:
    -- HUD clicks, harvesting, attacks and item use must retain their own behavior.
    local DoAction = pc and pc.DoAction
    local OnControl = pc and pc.OnControl
    local action_hook, control_hook
    if DoAction then
        action_hook = function(self, act, ...)
            ClearMouse()
            state.x, state.z = nil, nil
            if state.enabled and Alive(p) and not self:IsBusy() and act and
                act.action == ACTIONS.WALKTO and act.target == nil and not p:GetCurrentPlatform() then
                local pt = act:GetActionPoint()
                if pt then state.mouse = {x=pt.x, z=pt.z} end
            end
            return DoAction(self, act, ...)
        end
        pc.DoAction = action_hook
    end
    if OnControl then
        control_hook = function(self, control, down, ...)
            if down and (control == CONTROL_SECONDARY or control == CONTROL_CANCEL or
                control == CONTROL_ACTION or control == CONTROL_ATTACK or control == CONTROL_INSPECT) then
                ClearMouse()
            end
            return OnControl(self, control, down, ...)
        end
        pc.OnControl = control_hook
    end
    local function MouseWaypoint(x, z)
        local mouse = state.mouse
        if not mouse then return end
        if pc.draggingonground then
            local pt = TheInput:GetWorldPosition()
            if (pt.x-mouse.x)^2+(pt.z-mouse.z)^2 > .25 then
                ClearMouse()
                mouse = {x=pt.x, z=pt.z}
                state.mouse = mouse
            end
            mouse.dragging = true
        elseif mouse.dragging then
            ClearMouse(true)
            return
        end
        if (mouse.x-x)^2+(mouse.z-z)^2 < .16 then ClearMouse(true); return end
        -- Reuse the game's pathfinder and its normal locomotor path capabilities.
        -- In particular, do not accelerate through a wall just because its tile is land.
        local finder = TheWorld.Pathfinder
        local loco = p.components.locomotor
        local caps = loco and loco.pathcaps or nil
        if finder:IsClear(x,0,z,mouse.x,0,mouse.z,caps) then
            if mouse.handle then finder:KillSearch(mouse.handle); mouse.handle=nil end
            mouse.steps = nil
            return mouse
        end
        if mouse.handle then
            local status = finder:GetSearchStatus(mouse.handle)
            if status == 0 then return end
            local path = status == 1 and finder:GetSearchResult(mouse.handle) or nil
            finder:KillSearch(mouse.handle)
            mouse.handle = nil
            if not path or not path.steps or #path.steps < 2 then ClearMouse(); return end
            mouse.steps, mouse.index = path.steps, 2
        end
        if mouse.steps then
            local point = mouse.steps[mouse.index]
            while point and (point.x-x)^2+(point.z-z)^2 < .36 do
                mouse.index = mouse.index + 1
                point = mouse.steps[mouse.index]
            end
            if point and finder:IsClear(x,0,z,point.x,0,point.z,caps) then return point end
            mouse.steps = nil
        end
        mouse.handle = finder:SubmitSearch(x,0,z,mouse.x,0,mouse.z,caps)
        if not mouse.handle then ClearMouse() end
    end
    local function ClearHostSpeed()
        if TheWorld and TheWorld.ismastersim and p.components.locomotor then
            p.components.locomotor:RemoveExternalSpeedMultiplier(p, "soloassist2hm")
        end
    end
    local function ReleasePrediction()
        if state.prediction_override then
            state.prediction_override = nil
            if TheWorld and not TheWorld.ismastersim and Alive(p) then
                -- Restore the protocol to the client's current native mode.
                -- Do not touch Profile, client.ini, or the local prediction component.
                SendRPCToServer(RPC.SetMovementPredictionEnabled, p.components.locomotor ~= nil)
            end
        end
    end
    local function EnsureServerPrediction()
        if p.components.locomotor then return true end
        if not state.prediction_override then
            state.prediction_override = true
            state.prediction_ready_after = GetTime() + 2 * FRAMES
            SendRPCToServer(RPC.SetMovementPredictionEnabled, true)
        end
        return GetTime() >= state.prediction_ready_after
    end
    local function StopPlan()
        state.x, state.z = nil, nil
        ClearHostSpeed()
        ReleasePrediction()
    end
    local notice, notice_task
    local function Notify(show_speed, show_recover)
        if not Alive(p) then return end
        if not notice or not notice:IsValid() then
            -- Native non-networked Label, like the game's local health-bar label.
            -- Never add a Network component or invoke talker/chat RPCs.
            notice = CreateEntity()
            notice.entity:AddTransform()
            notice.entity:AddLabel()
            notice.entity:SetParent(p.entity)
            notice.Transform:SetPosition(0, 0, 0)
            notice:AddTag("CLASSIFIED")
            notice:AddTag("NOCLICK")
            notice.persists = false
            notice.Label:SetFont(TALKINGFONT)
            notice.Label:SetFontSize(26)
            notice.Label:SetWorldOffset(0, 3, 0)
            notice.Label:SetColour(1, .9, .55)
        end
        local text = {}
        if show_speed then text[#text+1] = "快速移动：" .. SPEED_MODES[state.mode].name end
        if show_recover then text[#text+1] = "自动解控：" .. (state.auto_recover and "开启" or "关闭") end
        notice.Label:SetText(table.concat(text, "\n"))
        notice.Label:Enable(true)
        if notice_task then notice_task:Cancel() end
        notice_task = p:DoStaticTaskInTime(2, function()
            notice_task = nil
            if notice and notice:IsValid() then notice.Label:Enable(false) end
        end)
    end
    local function InputReady()
        return Alive(p) and p.HUD and not p.HUD:HasInputFocus() and TheFrontEnd:GetActiveScreen() == p.HUD
    end
    local function CycleSpeed()
        state.mode = (state.mode + 1) % 4
        state.enabled = state.mode ~= 0
        state.level = SPEED_MODES[state.mode].attempts
        if not state.enabled then ClearMouse() end
        StopPlan()
    end
    local function ToggleRecover()
        state.auto_recover = not state.auto_recover
        state.next_recover = 0
    end
    local bindings, handlers = {}, {}
    local function Bind(key, fn)
        bindings[key] = bindings[key] or {}
        table.insert(bindings[key], fn)
    end
    local speed_key = options.speed_key or KEY_F6
    local recover_key = options.recover_key or KEY_F7
    Bind(speed_key, CycleSpeed)
    Bind(recover_key, ToggleRecover)
    for key, callbacks in pairs(bindings) do
        local actions, held = callbacks, false
        local show_speed, show_recover = key == speed_key, key == recover_key
        handlers[#handlers+1] = TheInput:AddKeyDownHandler(key, function()
            if held then return end
            held = true
            if InputReady() then
                for _, fn in ipairs(actions) do fn() end
                Notify(show_speed, show_recover)
            end
        end)
        handlers[#handlers+1] = TheInput:AddKeyUpHandler(key, function() held = false end)
    end
    local task = p:DoPeriodicTask(FRAMES, function()
        if state.auto_recover and InputReady() and M.IsControlled(p) and GetTime() >= state.next_recover then
            -- Allow the native half-second action and its replication to complete.
            state.next_recover = GetTime() + .8
            M.Recover(p)
        end
        if not Alive(p) or not state.enabled or not p.HUD or p.HUD:HasInputFocus() or
            TheFrontEnd:GetActiveScreen() ~= p.HUD or p:HasTag("busy") or p:GetCurrentPlatform() then
            ClearMouse()
            StopPlan()
            return
        end
        local dir = options.direction and options.direction() or Direction()
        local x, _, z = p.Transform:GetWorldPosition()
        local waypoint
        if dir and dir:LengthSq() >= .01 then
            ClearMouse()
        else
            waypoint = MouseWaypoint(x,z)
            if not waypoint then StopPlan();return end
            local dx,dz = waypoint.x-x,waypoint.z-z
            local distance = math.sqrt(dx*dx+dz*dz)
            dir = Vector3(dx/distance,0,dz/distance)
        end
        local loco = p.components.locomotor
        if TheWorld.ismastersim then
            -- A single-player host already owns this entity: use the native speed API.
            if loco then loco:SetExternalSpeedMultiplier(p, "soloassist2hm", SPEED_MODES[state.mode].host) end
            return
        end
        if not state.x or (state.x-x)^2+(state.z-z)^2 > 4 then state.x,state.z=x,z end
        local step = math.min(.18, loco and loco:GetRunSpeed()*FRAMES*.85 or .15)
        for i=1,state.level do
            local dx,dz,amount = dir.x,dir.z,step
            if waypoint then
                dx,dz = waypoint.x-state.x,waypoint.z-state.z
                local remaining = math.sqrt(dx*dx+dz*dz)
                if remaining < .05 then return end
                dx,dz,amount = dx/remaining,dz/remaining,math.min(step,remaining)
            end
            local nx,nz=state.x+dx*amount,state.z+dz*amount
            if not TheWorld.Map:IsPassableAtPoint(nx,0,nz) or TheWorld.Map:IsOceanAtPoint(nx,0,nz) or TheWorld.Map:IsPointNearHole(Vector3(nx,0,nz)) then
                StopPlan();return
            end
            if waypoint and not TheWorld.Pathfinder:IsClear(state.x,0,state.z,nx,0,nz,
                loco and loco.pathcaps or nil) then
                StopPlan();return
            end
            if not EnsureServerPrediction() then
                state.x, state.z = nil, nil
                return
            end
            state.x,state.z=nx,nz
            SendRPCToServer(RPC.PredictWalking,nx,nz,true,true,nil,false,nil,false)
            SendRPCToServer(RPC.InspectButton,p)
        end
    end)
    p:ListenForEvent("onremove", function()
        task:Cancel()
        ClearMouse()
        StopPlan()
        if pc then
            if pc.DoAction == action_hook then pc.DoAction = DoAction end
            if pc.OnControl == control_hook then pc.OnControl = OnControl end
        end
        if notice_task then notice_task:Cancel() end
        if notice and notice:IsValid() then notice:Remove() end
        for _, handler in ipairs(handlers) do handler:Remove() end
    end)
end

return M
