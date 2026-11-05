-- Cosmetic client effects. Reuse the game's endothermic flame animation without
-- spawning its heater/firefx components. The server owns only the awake state.
local M = {}

-- Offsets in the selected v4 build's body-symbol coordinates (412 x 512).
local EYES = {
    { x = -95, y = -211, flip = 1, phase = 0 },
    { x = 93, y = -211, flip = -1, phase = 8 / 30 },
}
local SCALE_X, SCALE_Y = .62, .34
local FADE_TIME, PULSE_TIME = .35, .75

local function ClearVisuals(inst)
    if inst._frostvisualtask ~= nil then
        inst._frostvisualtask:Cancel()
        inst._frostvisualtask = nil
    end
    if inst._frosteyes ~= nil then
        for _, fx in ipairs(inst._frosteyes) do fx:Remove() end
        inst._frosteyes = nil
    end
    inst._frostfade = 0
    inst._frostlastupdate = nil
    inst.AnimState:SetAddColour(0, 0, 0, 0)
end

local function CreateEyes(inst)
    inst._frosteyes = {}
    for i, eye in ipairs(EYES) do
        local fx = CreateEntity()
        fx.entity:AddTransform()
        fx.entity:AddAnimState()
        fx.entity:AddFollower()
        fx.entity:SetParent(inst.entity)
        fx.Follower:FollowSymbol(inst.GUID, "body", eye.x, eye.y, 0, true)
        fx.AnimState:SetBank("coldfire_fire")
        fx.AnimState:SetBuild("coldfire_fire")
        fx.AnimState:PlayAnimation("level1_redux", true)
        fx.AnimState:SetTime(eye.phase)
        fx.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
        fx.AnimState:SetLightOverride(1)
        fx.AnimState:SetFinalOffset(2)
        fx.AnimState:SetMultColour(.8, .94, 1, 0)
        fx.AnimState:SetScale(SCALE_X * eye.flip, SCALE_Y)
        fx:AddTag("FX")
        fx:AddTag("NOCLICK")
        fx.persists = false
        inst._frosteyes[i] = fx
    end
end

local function UpdateVisuals(inst)
    local now = GetTime()
    local dt = math.min(.1, now - (inst._frostlastupdate or now - FRAMES))
    inst._frostlastupdate = now
    local remaining = math.max(0, (inst._frostpulseuntil or 0) - now)
    local target = (inst._frostawake:value() or remaining > 0) and 1 or 0
    local fade = inst._frostfade or 0
    inst._frostfade = target > fade and math.min(target, fade + dt / FADE_TIME)
        or math.max(target, fade - dt / FADE_TIME)
    if inst._frostfade == 0 and target == 0 then
        ClearVisuals(inst)
        return
    end
    local pulse = remaining > 0 and math.sin(math.pi * (1 - remaining / PULSE_TIME)) or 0
    local breathe = .94 + .06 * math.sin(now * 2.4)
    for i, fx in ipairs(inst._frosteyes) do
        local eye = EYES[i]
        local size = (.72 + .28 * inst._frostfade) * (1 + .25 * pulse)
        fx.AnimState:SetScale(SCALE_X * eye.flip * size, SCALE_Y * size)
        fx.AnimState:SetMultColour(.8, .94, 1, inst._frostfade * breathe)
        fx.AnimState:SetAddColour(.05 * pulse, .15 * pulse, .2 * pulse, 0)
    end
    -- A restrained cool flash accompanies use, rather than a constant statue tint.
    inst.AnimState:SetAddColour(.025 * pulse, .055 * pulse, .075 * pulse, 0)
end

local function RefreshVisuals(inst)
    if inst:IsAsleep() then return end
    if inst._frosteyes == nil then
        if not inst._frostawake:value() and (inst._frostpulseuntil or 0) <= GetTime() then return end
        CreateEyes(inst)
    end
    if inst._frostvisualtask == nil then
        inst._frostvisualtask = inst:DoPeriodicTask(FRAMES, UpdateVisuals)
    end
    UpdateVisuals(inst)
end

local function OnPulse(inst)
    inst._frostpulseuntil = GetTime() + PULSE_TIME
    RefreshVisuals(inst)
end

function M.Init(inst)
    inst._frostawake = net_bool(inst.GUID, "frostshrine.awake", "frostshrineawakedirty")
    inst._frostpulse = net_event(inst.GUID, "frostshrinepulse")
    if not TheNet:IsDedicated() then
        inst:ListenForEvent("frostshrineawakedirty", RefreshVisuals)
        if not TheWorld.ismastersim then inst:ListenForEvent("frostshrinepulse", OnPulse) end
        inst:ListenForEvent("onremove", ClearVisuals)
        inst.OnEntitySleep = ClearVisuals
        inst.OnEntityWake = RefreshVisuals
        -- Covers late joins/streaming in while the station is already awake.
        inst:DoTaskInTime(0, RefreshVisuals)
    end
end

function M.SetActive(inst, active)
    inst._frostawake:set(active)
    if not TheNet:IsDedicated() then RefreshVisuals(inst) end
end

function M.Pulse(inst)
    inst._frostpulse:push()
    if not TheNet:IsDedicated() then OnPulse(inst) end
end

return M
