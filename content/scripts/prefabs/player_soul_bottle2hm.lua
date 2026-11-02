local assets = {
    Asset("ANIM", "anim/hpm_soul_bottle.zip"),
    -- soul_bottle:up, near, down, idle
}

local function OnNear(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    if TheWorld.Map:IsOceanAtPoint(x, y, z, false) then
        return
    end
    inst.AnimState:PlayAnimation("up")
    inst.AnimState:PushAnimation("near", true)
end

local function OnFar(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    if TheWorld.Map:IsOceanAtPoint(x, y, z, false) then
        return
    end
    inst.AnimState:PlayAnimation("down")
    inst.AnimState:PushAnimation("idle", true)
end

local function playidleanim_empty(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    if TheWorld.Map:IsOceanAtPoint(x, y, z, false) then
        inst.AnimState:PlayAnimation("up")
        inst.AnimState:PushAnimation("near", true)
    else
        local prox = inst.components.playerprox
        local player = FindClosestPlayerInRange(x, y, z, prox.near, prox.alivemode)
        if player then
            inst.AnimState:PlayAnimation("up")
            inst.AnimState:PushAnimation("near", true)
        else
            inst.AnimState:PlayAnimation("down")
            inst.AnimState:PushAnimation("idle", true)
        end
    end
end

local function OnSave(inst, data)
    data.username = inst.username
    data.cause = inst.cause
    data.afflicter = inst.afflicter
    data.userid = inst.userid
end

local function OnLoad(inst, data)
    if data then
        if data.username then
            inst.components.named:SetName(data.username)
        end
        inst.username = data.username or inst.components.named.name or TUNING.util2hm.GetLanguage("神秘人", "unnamed")
        inst.cause = data.cause
        inst.afflicter = data.afflicter
        inst.userid = data.userid
    end
end

local function getdescription(inst, viewer)
    if TUNING.isCh2hm then
        local str = {"这看起来装着[" .. inst.username .. "]的灵魂"}
        if inst.cause then
            table.insert(str, "死因:" .. (STRINGS.NAMES[string.upper(inst.cause)] or STRINGS.NAMES.SHENANIGANS))
        end
        if inst.afflicter then
            table.insert(str, "死于:" .. inst.afflicter)
        end
        return table.concat(str, "\n")
    else
        local str = {"It seems hold soul of [" .. inst.username .. "]"}
        if inst.cause then
            table.insert(str, "cause:" .. (STRINGS.NAMES[string.upper(inst.cause)] or STRINGS.NAMES.SHENANIGANS))
        end
        if inst.afflicter then
            table.insert(str, "afflicter:" .. inst.afflicter)
        end
        return table.concat(str, "\n")
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)
    inst.AnimState:SetBuild("hpm_soul_bottle")
    inst.AnimState:SetBank("soul_bottle")
    inst.AnimState:PlayAnimation("idle")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end


    inst:AddComponent("named")
    inst.components.named:SetName("小丑猫")

    inst:AddComponent("playerprox")
    inst.components.playerprox:SetDist(5, 6)
    inst.components.playerprox:SetOnPlayerNear(OnNear)
    inst.components.playerprox:SetOnPlayerFar(OnFar)

    inst:ListenForEvent("on_landed", playidleanim_empty)

    inst:AddComponent("inventoryitem")
    -- inst.components.inventoryitem:SetOnDroppedFn(ondropped)
    inst.components.inventoryitem.atlasname = "images/inventoryimages/bottle_soul.xml"
    inst.components.inventoryitem.imagename = "bottle_soul"

    inst.username = nil
    inst.cause = nil
    inst.afflicter = nil
    inst.userid = nil

    inst:AddComponent("inspectable")
    inst.components.inspectable.descriptionfn = getdescription

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    return inst
end

return Prefab("player_soul_bottle2hm", fn, assets)
