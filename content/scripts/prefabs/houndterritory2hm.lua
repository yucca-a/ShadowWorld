local rock_ice_assets = {Asset("ANIM", "anim/ice_boulder.zip")}

local prefabs = {"ice_puddle"}

local STAGES = {{name = "dryup", animation = "dryup"}, {name = "empty", animation = "melted"}}

local STAGE_INDICES = {}
for i, v in ipairs(STAGES) do STAGE_INDICES[v.name] = i end

local function DeserializeStage(inst)
    return inst._stage:value() + 1 -- back to 1-based index
end

local function OnStageDirty(inst)
    local stagedata = STAGES[DeserializeStage(inst)]
    if stagedata ~= nil then
        if inst._puddle ~= nil then
            inst._puddle.AnimState:PlayAnimation(stagedata.animation)
            if stagedata.name == "empty" then inst._puddle.AnimState:PushAnimation("idle", true) end
        end
    end
end

local function SerializeStage(inst, stageindex, source)
    inst._ismelt:set(source == "melt")
    inst._stage:set(stageindex - 1) -- convert to 0-based index
    OnStageDirty(inst)
end

local function SetDryupStage(inst)
    if inst:IsAsleep() then
        inst:Remove()
    else
        SerializeStage(inst, STAGE_INDICES["dryup"], "melt")
        inst.persists = false
        inst:DoTaskInTime(2, inst.Remove)
    end
end

local function DayEnd(inst)
    if not inst.components.timer:TimerExists("change2hm") or not inst.components.timer:TimerExists("other2hm") then
        inst.components.timer:StartTimer("change2hm", math.random(TUNING.TOTAL_DAY_TIME, TUNING.TOTAL_DAY_TIME * 3))
    end
end

local function _OnFireMelt(inst)
    inst.firemelttask = nil
    SetDryupStage(inst)
end

local function StartFireMelt(inst) if inst.firemelttask == nil then inst.firemelttask = inst:DoTaskInTime(4, _OnFireMelt) end end

local function StopFireMelt(inst)
    if inst.firemelttask ~= nil then
        inst.firemelttask:Cancel()
        inst.firemelttask = nil
    end
end

local function ontimerdone(inst, data)
    if data and data.name == "change2hm" and inst:IsAsleep() and math.random() < 0.6 then
        SpawnPrefab("houndmound").Physics:Teleport(inst.Transform:GetWorldPosition())
        inst:Remove()
        return
    elseif data and data.name == "other2hm" and inst:IsAsleep() and math.random() < 0.3 then
        SpawnPrefab("boneshard").Physics:Teleport(inst.Transform:GetWorldPosition())
        inst:Remove()
        return
    end
    SetDryupStage(inst)
end

local function rock_ice_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("ice_boulder")
    inst.AnimState:SetBuild("ice_boulder")
    inst.AnimState:Hide("rock")
    inst.AnimState:Hide("snow")

    inst:AddTag("antlion_sinkhole_blocker")
    inst:AddTag("frozen")
    inst:AddTag("houndterritory2hm")

    inst.no_wet_prefix = true

    inst._ismelt = net_bool(inst.GUID, "rock_ice.ismelt", "stagedirty")
    inst._stage = net_tinybyte(inst.GUID, "rock_ice.stage", "stagedirty")
    inst._stage:set(STAGE_INDICES["empty"])

    inst.entity:SetPristine()

    if not TheNet:IsDedicated() then
        inst._puddle = SpawnPrefab("ice_puddle")
        inst._puddle.entity:SetParent(inst.entity)
        inst._puddle.AnimState:SetMultColour(0.53, 0.53, 0.53, 1)
        if not TheWorld.ismastersim then inst:ListenForEvent("stagedirty", OnStageDirty) end
    end

    OnStageDirty(inst)

    if not TheWorld.ismastersim then return inst end

    inst:AddComponent("timer")
    inst:ListenForEvent("timerdone", ontimerdone)

    inst:ListenForEvent("firemelt", StartFireMelt)
    inst:ListenForEvent("stopfiremelt", StopFireMelt)

    inst:WatchWorldState("cycles", DayEnd)

    return inst
end

return Prefab("houndterritory2hm", rock_ice_fn, rock_ice_assets, prefabs)
