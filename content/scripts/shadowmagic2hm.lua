-- One world-time deadline shared by station purchases and journal renewals.
local M = {}
local EPSILON = 1e-7
local PHASES = {"day", "dusk", "night"}
local function Data(inst)
    local persistent = inst.components.persistent2hm
    return persistent and persistent.data
end

function M.Now()
    local clock = TheWorld.net and TheWorld.net.components.clock
    if clock and clock.OnSave then
        -- Read cycles and phase progress from one authoritative snapshot. The
        -- replicated world-state fields can update on opposite sides of dawn.
        local state = clock:OnSave()
        local elapsed = state.totaltimeinphase - state.remainingtimeinphase
        for _, phase in ipairs(PHASES) do
            if phase == state.phase then break end
            elapsed = elapsed + state.segs[phase] * TUNING.SEG_TIME
        end
        return state.cycles * TUNING.TOTAL_DAY_TIME + elapsed
    end
    return ((TheWorld.state.cycles or 0) + (TheWorld.state.time or 0)) * TUNING.TOTAL_DAY_TIME
end

function M.Ensure(inst)
    local data = Data(inst)
    if not data then return end
    if data.shadowmagicexpires2hm == nil and type(data.shadowmagiccycle) == "number" then
        -- The old record has no time of day. Preserve its remaining advertised
        -- days at migration, cap old journal stockpiles, and migrate only once.
        local now = M.Now()
        local days = math.clamp(20 - (math.floor(now / TUNING.TOTAL_DAY_TIME) - data.shadowmagiccycle), 0, 20)
        data.shadowmagicexpires2hm = now + days * TUNING.TOTAL_DAY_TIME
    end
    return data
end

function M.Remaining(inst)
    local data = M.Ensure(inst)
    return data and data.shadowmagicexpires2hm and
        math.clamp(data.shadowmagicexpires2hm - M.Now(), 0, 20 * TUNING.TOTAL_DAY_TIME) or 0
end

function M.Enrolled(inst)
    local data = Data(inst)
    return data and (data.shadowmagiccycle ~= nil or data.shadowmagicexpires2hm ~= nil) or false
end

function M.Cost(inst)
    if not inst or not Data(inst) then return 0 end
    if not M.Enrolled(inst) and inst:HasTag("shadowmagic") and inst:HasTag("magician") and
        inst.components.magician and (not inst.components.reader or (inst.components.reader.sanity_mult or 1) <= 1) then
        return 0 -- Native abilities do not need to be purchased.
    end
    local missing = 20 * TUNING.TOTAL_DAY_TIME - M.Remaining(inst)
    return math.max(0, math.ceil((missing - EPSILON) / (5 * TUNING.TOTAL_DAY_TIME)))
end

local function UpdateHat(inst)
    local inventory = inst.components.inventory
    local hat = inventory and inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
    if hat and hat:IsValid() and hat.checkstatus2hm then hat:checkstatus2hm() end
end

local function Apply(inst, data)
    if not inst:HasTag("shadowmagic") then inst:AddTag("shadowmagic") end
    if not inst:HasTag("magician") then inst:AddTag("magician") end
    if not inst.components.magician then inst:AddComponent("magician") end
    local reader = inst.components.reader
    if reader and (reader.sanity_mult or 1) > 1 then
        if data.originalsanity_mult == nil then data.originalsanity_mult = reader.sanity_mult end
        reader:SetSanityPenaltyMultiplier(1)
    end
    inst.shadowmagicactive2hm = true
    UpdateHat(inst)
end

local function Remove(inst, data, notify)
    inst.shadowmagicactive2hm = false
    if not data.shadowmagic_tag and inst:HasTag("shadowmagic") then inst:RemoveTag("shadowmagic") end
    if not data.magician_tag and inst:HasTag("magician") then inst:RemoveTag("magician") end
    if not data.magician_component and inst.components.magician then inst:RemoveComponent("magician") end
    -- The native component removes its tag during destruction, even if that
    -- tag originally belonged to another source before we added the component.
    if data.magician_tag and not inst:HasTag("magician") then inst:AddTag("magician") end
    if inst.components.reader and data.originalsanity_mult ~= nil then
        inst.components.reader:SetSanityPenaltyMultiplier(data.originalsanity_mult)
    end
    UpdateHat(inst)
    if notify then
        local fx = SpawnPrefab("shadow_despawn")
        if fx then inst:AddChild(fx) end
        if inst.components.talker then
            inst.components.talker:Say(TUNING.isCh2hm and "我体内的暗影魔法渴望燃料..." or "The shadow magic within me craves fuel...")
        end
    end
end

function M.Refresh(inst, force)
    if inst.shadowmagicexpirycheck2hm then
        inst.shadowmagicexpirycheck2hm:Cancel()
        inst.shadowmagicexpirycheck2hm = nil
    end
    local data = M.Ensure(inst)
    if not data or data.shadowmagicexpires2hm == nil then return end
    local remaining = M.Remaining(inst)
    if remaining > EPSILON then
        if force or not inst.shadowmagicactive2hm then Apply(inst, data) end
        -- World sleep/clock jumps can advance world time without advancing a
        -- normal timer by the same amount. Only active grants need this check.
        inst.shadowmagicexpirycheck2hm = inst:DoTaskInTime(math.min(remaining, 1), M.Refresh)
    elseif inst.shadowmagicactive2hm ~= false then
        Remove(inst, data, inst.shadowmagicactive2hm == true)
    end
end

function M.SetRemaining(inst, seconds)
    local data = M.Ensure(inst)
    if not data then return false end
    if not M.Enrolled(inst) then
        data.shadowmagic_tag = inst:HasTag("shadowmagic") or nil
        data.magician_tag = inst:HasTag("magician") or nil
        data.magician_component = inst.components.magician ~= nil or nil
    end
    -- Keep the historical enrollment marker for broom/hat compatibility;
    -- expiry is exclusively controlled by the new fractional deadline.
    if data.shadowmagiccycle == nil then data.shadowmagiccycle = TheWorld.state.cycles end
    data.shadowmagicexpires2hm = M.Now() + math.clamp(seconds, 0, 20 * TUNING.TOTAL_DAY_TIME)
    M.Refresh(inst, true)
    return true
end

function M.RenewJournal(inst)
    if not M.Enrolled(inst) then return false end
    return M.SetRemaining(inst, M.Remaining(inst) + TUNING.TOTAL_DAY_TIME)
end

return M
