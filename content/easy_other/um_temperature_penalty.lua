local SETTLEMENT_INTERVAL = .25
local UM_WORKSHOP_IDS = {["2039181790"] = true, ["3193922031"] = true}

local function IsTemperatureCause(cause)
    return cause == "cold" or cause == "hot"
end

local function FindTemperatureListener(inst)
    local listeners = inst.event_listeners and inst.event_listeners.healthdelta
    listeners = listeners and listeners[inst]
    if listeners == nil then return end

    local index
    for i, fn in ipairs(listeners) do
        local source = debug.getinfo(fn, "S").source:gsub("\\", "/")
        local id = source:match("/workshop%-(%d+)/postinit/player%.lua$")
        if UM_WORKSHOP_IDS[id] then
            if index ~= nil then return end
            index = i
        end
    end
    if index ~= nil then return listeners, index end
end

AddPlayerPostInit(function(inst)
    if not TheWorld.ismastersim then return end
    local health = inst.components.health
    if health == nil then return end

    local listeners, index = FindTemperatureListener(inst)
    if listeners == nil then return end
    local originalListener = listeners[index]
    local listening = inst.event_listening and inst.event_listening.healthdelta
    listening = listening and listening[inst]
    if listening == nil then return end
    local listeningIndex
    for i, fn in ipairs(listening) do
        if fn == originalListener then
            listeningIndex = i
            break
        end
    end
    if listeningIndex == nil then return end

    local pending, task, inTemperatureListener
    local DeltaPenalty = health.DeltaPenalty

    local function ClearPending()
        if task ~= nil then task:Cancel() end
        pending, task = nil, nil
    end

    local function CommitPending()
        if pending == nil then return end
        local amount = pending
        ClearPending()
        if not inst:IsValid() or inst.components.health ~= health then return end
        if health.disable_penalty then
            -- These ticks were accepted before the penalty setting changed.
            health.penalty = math.min(health.penalty + amount, TUNING.MAXIMUM_HEALTH_PENALTY)
            health:ForceUpdateHUD(false)
        else
            DeltaPenalty(health, amount)
        end
    end

    local GetMaxWithPenalty = health.GetMaxWithPenalty
    function health:GetMaxWithPenalty(...)
        local maximum = GetMaxWithPenalty(self, ...)
        -- Gameplay can use the effective cap while the HUD uses the committed penalty.
        return pending == nil and maximum or maximum - self.maxhealth * pending
    end

    function health:DeltaPenalty(amount, ...)
        if not inTemperatureListener or amount <= 0 then
            CommitPending()
            return DeltaPenalty(self, amount, ...)
        end

        -- The UM callback requests at most one penalty. A synchronous HUD refresh can
        -- dispatch other mods' health listeners before that callback returns.
        inTemperatureListener = false
        if self.disable_penalty then
            CommitPending()
            return
        end
        local accumulated = math.min((pending or 0) + amount, TUNING.MAXIMUM_HEALTH_PENALTY - self.penalty)
        if accumulated <= 0 then return end
        pending = accumulated
        if self:IsDead() or self.currenthealth > self:GetMaxWithPenalty() + 1e-9 then
            CommitPending()
        elseif task == nil then
            task = inst:DoTaskInTime(SETTLEMENT_INTERVAL, CommitPending)
        end
    end

    local SetPenalty = health.SetPenalty
    function health:SetPenalty(amount, ...)
        CommitPending()
        return SetPenalty(self, amount, ...)
    end

    local DoDelta = health.DoDelta
    function health:DoDelta(amount, ...)
        if amount > 0 then CommitPending() end
        return DoDelta(self, amount, ...)
    end

    local SetVal = health.SetVal
    function health:SetVal(value, cause, ...)
        if not IsTemperatureCause(cause) or value > self.currenthealth or value <= 0 then
            CommitPending()
        end
        return SetVal(self, value, cause, ...)
    end

    -- Direct setters and transfers can bypass DoDelta and SetVal.
    for _, method in ipairs({"SetCurrentHealth", "SetMaxHealth", "TransferComponent"}) do
        local original = health[method]
        if original ~= nil then
            health[method] = function(self, ...)
                CommitPending()
                return original(self, ...)
            end
        end
    end

    local SaveForReroll = inst.SaveForReroll
    if SaveForReroll ~= nil then
        function inst:SaveForReroll(...)
            CommitPending()
            return SaveForReroll(self, ...)
        end
    end

    local OnSave, OnLoad = health.OnSave, health.OnLoad
    function health:OnSave(...)
        local data, refs = OnSave(self, ...)
        if type(data) == "table" and pending ~= nil then
            -- Player saves and shard transfers both carry the native health record.
            data.penalty = math.min(self.penalty + pending, TUNING.MAXIMUM_HEALTH_PENALTY)
            if type(data.health) == "number" then data.health = math.min(data.health, self:GetMaxWithPenalty()) end
        end
        return data, refs
    end

    function health:OnLoad(...)
        ClearPending()
        return OnLoad(self, ...)
    end

    local function OnHealthDelta(player, data)
        if data == nil or data.amount == nil or data.amount >= 0 or not IsTemperatureCause(data.cause) then
            return originalListener(player, data)
        end
        local previous = inTemperatureListener
        inTemperatureListener = true
        local ok, result = pcall(originalListener, player, data)
        inTemperatureListener = previous
        if not ok then error(result, 0) end
    end

    -- Replace both registrations in place to preserve the healthdelta listener order.
    listeners[index], listening[listeningIndex] = OnHealthDelta, OnHealthDelta
end)
