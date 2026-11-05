-- Independent server options; clients follow a replicated mode, never their
-- local/default mod configuration. Only player prefabs receive this patch.
local monster_enabled = GetModConfigData("Monster Night Vision")
local wathom_enabled = GetModConfigData("wathom nightvision")
local BLACKLIST = {wortox = true}
local EXTRA_ROLES = {wurt = true, wonkey = true}
local SOURCE = "monster_nightvision2hm"
local DIRTY = "monsternightvision2hmdirty"
local CHANGED = "monsternightvision2hmchanged"

local function GetMode(inst)
    return inst._monsternightvision2hm ~= nil and inst._monsternightvision2hm:value() or 0
end

local function GetServerMode(inst)
    if BLACKLIST[inst.prefab] then return 0 end
    local monster = monster_enabled and (EXTRA_ROLES[inst.prefab] or inst:HasTag("monster"))
    if inst.prefab == "wathom" and (monster or wathom_enabled) then return 2 end
    return monster and 1 or 0
end

-- Compatibility applies to ALL players, independently of the monster bonus.
-- Woodie's forms use native sources but never acquire the monster tag. A local
-- helper's ForceNightVision(false) must not disable those still-active sources.
-- Remember legacy requests separately so removing a native source does not
-- erase another caller's legitimate legacy vision either.
local function InstallVisionGuard(vision, state)
    if state.vision == vision then return end
    state.vision = vision
    state.applied = false
    local force = vision.ForceNightVision
    local push = vision.PushForcedNightVision
    local pop = vision.PopForcedNightVision
    local depth = 0
    local legacy = vision.forcenightvision and #vision.forcednightvisionstack == 0

    vision.ForceNightVision = function(self, enabled)
        if depth == 0 then legacy = enabled == true end
        return force(self, enabled or state.active or #self.forcednightvisionstack > 0)
    end
    local function FinishStack(self)
        -- Native Pop switches the colour table but does not restore the next
        -- source's nonightvisioncc flag. Restore that flag for our plain vision.
        local top = self.forcednightvisionstack[1]
        if top ~= nil then self:ForceNoNightVisionCC(top.nonightvisioncc) end
        force(self, state.active or top ~= nil or legacy)
    end
    vision.PushForcedNightVision = function(self, ...)
        depth = depth + 1
        local result = push(self, ...)
        depth = depth - 1
        if depth == 0 then FinishStack(self) end
        return result
    end
    vision.PopForcedNightVision = function(self, ...)
        depth = depth + 1
        local result = pop(self, ...)
        depth = depth - 1
        if depth == 0 then FinishStack(self) end
        return result
    end
    -- A transformation or a food source can already exist when the postinit
    -- hook runs. Repair a prior legacy disable without replacing its palette.
    if vision.forcednightvisionstack[1] ~= nil then FinishStack(vision) end
end

-- Both installed UM versions close over NIGHTVISION_CCS in CheckLight. Match
-- that upvalue AND its source instead of cancelling unrelated character tasks
-- or replacing all colour-cube calls. Scheduling continues normally when off.
local function IsWathomLightCheck(fn)
    if type(fn) ~= "function" then return false end
    local source = debug.getinfo(fn, "S").source:gsub("\\", "/")
    if source ~= "scripts/prefabs/wathom.lua" and
        source:sub(-#"/scripts/prefabs/wathom.lua") ~= "/scripts/prefabs/wathom.lua" then return false end
    local index = 1
    while true do
        local name = debug.getupvalue(fn, index)
        if name == nil then return false end
        if name == "NIGHTVISION_CCS" then return true end
        index = index + 1
    end
end

local function InstallWathomGuard(inst)
    local function Guard(fn)
        if not IsWathomLightCheck(fn) then return fn end
        return function(...)
            if GetMode(inst) ~= 2 then return fn(...) end
        end
    end
    for task in pairs(inst.pendingtasks or {}) do
        task.fn = Guard(task.fn)
    end
    local periodic = inst.DoPeriodicTask
    inst.DoPeriodicTask = function(self, period, fn, ...)
        return periodic(self, period, Guard(fn), ...)
    end
end

local function ApplyVision(inst)
    local state = inst._monstervisionstate2hm
    local mode = GetMode(inst)
    local vision = inst.components.playervision
    if mode == 2 and state.mode ~= 2 then
        -- Cancel the actual delayed reset task; never put a boolean/number in
        -- UM's task field (the Beta calls :Cancel() on it).
        if inst.updatewathomvisiontask ~= nil then
            inst.updatewathomvisiontask:Cancel()
            inst.updatewathomvisiontask = nil
        end
        inst:RemoveTag("WathomInDark")
        if vision ~= nil and #vision.forcednightvisionstack == 0 then
            vision:SetCustomCCTable(nil)
            vision:ForceNightVision(false)
        end
    end
    local changed = state.mode ~= mode
    state.mode = mode
    local active = mode > 0 and not inst:HasTag("playerghost") and
        (vision == nil or not vision:HasGhostVision())
    state.active = active
    if vision ~= nil then
        InstallVisionGuard(vision, state)
        if active and not state.applied then
            state.applied = true
            -- Low priority: native food/skill overlays remain authoritative.
            -- No mole filter or fixed spring palette; retain normal world CCs.
            vision:PushForcedNightVision(SOURCE, -10, nil, nil, nil, true)
        elseif not active and state.applied then
            state.applied = false
            vision:PopForcedNightVision(SOURCE)
        end
    end
    if changed then inst:PushEvent(CHANGED) end
end

local function RefreshServer(inst)
    local mode = GetServerMode(inst)
    if inst._monsternightvision2hm:value() ~= mode then
        inst._monsternightvision2hm:set(mode)
    end
    ApplyVision(inst)
end

AddPlayerPostInit(function(inst)
    if inst._monstervisionstate2hm ~= nil then return end
    inst._monstervisionstate2hm = {}
    inst._monsternightvision2hm = net_tinybyte(inst.GUID, "monsternightvision2hm.mode", DIRTY)
    if inst.prefab == "wathom" then InstallWathomGuard(inst) end
    inst:ListenForEvent(DIRTY, ApplyVision)
    inst:ListenForEvent("ghostvision", ApplyVision)
    inst:ListenForEvent("ms_respawnedfromghost", ApplyVision)
    inst:ListenForEvent("playeractivated", ApplyVision)
    if TheWorld.ismastersim then
        RefreshServer(inst)
        inst:DoTaskInTime(0, RefreshServer)
        -- Tags may change through skills, disguises or another mod's entity
        -- API. A cheap server-only check also covers changes without events.
        inst:DoPeriodicTask(1, RefreshServer)
    else
        inst:DoTaskInTime(0, ApplyVision)
    end
end)

-- UM's sonar is a separate HUD animation: disabling just the vision toggle
-- leaves its fog/heartbeat loop alive. Suppress only this widget, on both
-- versions, and react when the server setting arrives after HUD construction.
if TUNING.DSTU and not TheNet:IsDedicated() then
    AddClassPostConstruct("widgets/wathom_sonar", function(self, owner)
        local function Silence()
            self._suppressed2hm = true
            self.active = false
            self.time, self.alpha, self.alphagoal = 0, 0, 0
            self:StopUpdating()
            self:Hide()
            self.bg2:SetTint(0, 0, 0, 0)
        end
        local start = self.StartSonar
        local set = self.SetSonar
        local update = self.OnUpdate
        self.StartSonar = function(widget, ...)
            if GetMode(owner) == 2 then return Silence() end
            return start(widget, ...)
        end
        self.SetSonar = function(widget, ...)
            if GetMode(owner) == 2 then return Silence() end
            return set(widget, ...)
        end
        self.OnUpdate = function(widget, ...)
            if GetMode(owner) == 2 then return Silence() end
            return update(widget, ...)
        end
        local function Refresh()
            if GetMode(owner) == 2 then
                Silence()
            elseif self._suppressed2hm then
                self._suppressed2hm = nil
                start(self)
            end
        end
        self.inst:ListenForEvent(CHANGED, Refresh, owner)
        Refresh()
    end)
end
