-- Preserve the three existing role options, including their parent switches.
-- Their server-authoritative ability is separate from the monster-tag bonus.
local OPTIONS = {
    webber = "Webber Night Version",
    wurt = "Wurt Night Version",
    wonkey = "Wonkey Night Version",
}
local SOURCE = "role_nightvision2hm"
local DIRTY = "rolenightvision2hmdirty"
local CHANGED = "rolenightvision2hmchanged"

local function IsAlive(inst)
    return not inst:HasTag("playerghost") and
        (inst.components.health == nil or not inst.components.health:IsDead()) and
        (inst.components.playervision == nil or not inst.components.playervision:HasGhostVision())
end

local function ApplyVision(inst)
    local state = inst._rolevisionstate2hm
    local vision = inst.components.playervision
    local active = inst._rolenightvision2hm:value() and IsAlive(inst)
    local changed = state.active ~= active
    state.active = active
    if state.vision ~= vision then
        state.vision = vision
        state.applied = false
    end
    if vision ~= nil then
        if active and not state.applied then
            state.applied = true
            vision:PushForcedNightVision(SOURCE, -11, nil, nil, nil, true)
        elseif not active and state.applied then
            state.applied = false
            vision:PopForcedNightVision(SOURCE)
        end
    end
    if changed then inst:PushEvent(CHANGED) end
end

local function RefreshServer(inst)
    -- Native worldstate notifies phase watchers BEFORE updating isday/isdusk/isnight.
    local phase = TheWorld.state.phase
    local active = inst._rolevisionstate2hm.enabled and IsAlive(inst) and
        (TheWorld:HasTag("cave") or phase == "night" or phase == "dusk") or false
    if inst._rolenightvision2hm:value() ~= active then
        inst._rolenightvision2hm:set(active)
    end
    ApplyVision(inst)
end

AddPlayerPostInit(function(inst)
    if OPTIONS[inst.prefab] == nil or inst._rolevisionstate2hm ~= nil then return end
    inst._rolevisionstate2hm = {}
    inst._rolenightvision2hm = net_bool(inst.GUID, "rolenightvision2hm.active", DIRTY)
    inst:ListenForEvent(DIRTY, ApplyVision)
    local refresh = TheWorld.ismastersim and RefreshServer or ApplyVision
    inst:ListenForEvent("ghostvision", refresh)
    inst:ListenForEvent("death", refresh)
    inst:ListenForEvent("ms_respawnedfromghost", function()
        refresh(inst)
        inst:DoTaskInTime(0, refresh)
    end)
    inst:ListenForEvent("playeractivated", refresh)
    if TheWorld.ismastersim then
        inst._rolevisionstate2hm.enabled = TUNING.easymode2hm and GetModConfigData("role_easy") and
            GetModConfigData(inst.prefab .. "_easy") and GetModConfigData(OPTIONS[inst.prefab]) or false
        inst:WatchWorldState("phase", RefreshServer)
    end
    refresh(inst)
    inst:DoTaskInTime(0, refresh)
end)
