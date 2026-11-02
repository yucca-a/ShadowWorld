local _activeplayers
AddComponentPostInit("kramped", function(self) _activeplayers = getupvalue2hm(self.GetDebugString, "_activeplayers") end)
local lightfn = ACTIONS.LIGHT.fn
ACTIONS.LIGHT.fn = function(act, ...)
    local result, reason = lightfn(act, ...)
    if result and act.doer and act.target and act.target:IsValid() and (act.target:HasTag("plant") or act.target:HasTag("structure")) and _activeplayers and
        _activeplayers[act.doer] and _activeplayers[act.doer].actions then _activeplayers[act.doer].actions = _activeplayers[act.doer].actions + 1 end
    return result, reason
end
local function onsavekramped(inst, data)
    if _activeplayers and _activeplayers[inst] and _activeplayers[inst].actions and _activeplayers[inst].threshold and _activeplayers[inst].timetodecay then
        local timetodecay = _activeplayers[inst].timetodecay
        if timetodecay == math.huge then timetodecay = nil end
        data.kramped = {actions = _activeplayers[inst].actions, threshold = _activeplayers[inst].threshold, timetodecay = timetodecay}
    end
end
local function onloadkramped(inst, data)
    if _activeplayers ~= nil and data.kramped and _activeplayers[inst] ~= nil then
        _activeplayers[inst].actions = math.max(data.kramped.actions or 0, _activeplayers[inst].actions or 0)
        _activeplayers[inst].threshold = math.max(data.kramped.threshold or 1, _activeplayers[inst].threshold or 1)
        if data.kramped.timetodecay == nil then data.kramped.timetodecay = math.huge end
        _activeplayers[inst].timetodecay = data.kramped.timetodecay
        data.kramped = nil
    elseif GetTime() - inst.spawntime < 1 then
        inst:DoTaskInTime(3, onloadkramped, data)
    else
        data.kramped = nil
    end
end
AddPlayerPostInit(function(inst)
    if not TheWorld.ismastersim then return end
    SetOnSave2hm(inst, onsavekramped)
    SetOnLoad2hm(inst, onloadkramped)
end)

-- 坎普斯加强，猎犬友好共享仇恨，有一个火猎犬朋友和一个冰猎犬朋友，存在60秒后逃跑
local RETARGET_CANT_TAGS = {"wall", "houndmound", "hound", "houndfriend", "deergemresistance", "klaus"}
local function newhoundretargetfn(inst)
    if inst.sg:HasStateTag("statue") then return end
    local leader = inst.components.follower.leader
    if leader ~= nil and leader.sg ~= nil and leader.sg:HasStateTag("statue") then return end
    local playerleader = leader ~= nil and leader:HasTag("player")
    local ispet = inst:HasTag("pet_hound")
    return (leader == nil or (ispet and not playerleader) or inst:IsNear(leader, TUNING.HOUND_FOLLOWER_AGGRO_DIST)) and
               FindEntity(inst, (ispet or leader ~= nil) and TUNING.HOUND_FOLLOWER_TARGET_DIST or TUNING.HOUND_TARGET_DIST,
                          function(guy) return guy ~= leader and inst.components.combat:CanTarget(guy) end, nil, RETARGET_CANT_TAGS) or nil
end
local function processhound(inst, krampus)
    inst.krampus2hm = krampus or (inst.swp2hm and inst.swp2hm.krampus2hm)
    inst:AddTag("deergemresistance")
    inst:AddTag("pet_hound")
    if inst.krampus2hm and inst.krampus2hm:IsValid() then
        if not inst.components.follower then inst:AddComponent("follower") end
        inst.components.follower:SetLeader(inst.krampus2hm)
    end
    if inst.components.combat then inst.components.combat:SetRetargetFunction(3, newhoundretargetfn) end
    inst.swc2hmfn = processhound
end

AddPrefabPostInit("krampus", function(inst)
    if not TheWorld.ismastersim then return end
    inst:DoTaskInTime(0.25, function(inst)
        if inst:HasTag("swc2hm") or (inst.components.health and inst.components.health:IsDead()) then return end
        processhound(SpawnMonster2hm(inst.components.combat.target or inst, "firehound"), inst)
        processhound(SpawnMonster2hm(inst.components.combat.target or inst, "icehound"), inst)
    end)
    inst:DoTaskInTime(60, function(inst) if not (inst.components.health and inst.components.health:IsDead()) then inst.sg:GoToState("exit") end end)
end)

AddStategraphPostInit("krampus", function(sg)
    -- local oldOnEnterexit = sg.states.exit.onenter
    -- sg.states.exit.onenter = function(inst, ...)
    --     oldOnEnterexit(inst, ...)
    --     inst:DoTaskInTime(40 * FRAMES, inst.Remove)
    -- end
    AddStateTimeEvent2hm(sg.states.exit, 40 * FRAMES, function(inst) inst:Remove() end)
end)
