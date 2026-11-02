local assets = {
    Asset("ANIM", "anim/hpm_player_ghost.zip"),
    -- dark_soul:suck, idle, appear, disappear
}

local OnAnimOver = function(inst)
    if inst.AnimState:IsCurrentAnimation("appear") then
        inst.AnimState:PlayAnimation("idle", true)
        inst.components.trader:Enable()
    elseif inst.AnimState:IsCurrentAnimation("suck") then
        inst:Remove()
        local bottle = SpawnPrefab("player_soul_bottle2hm")
        bottle.Transform:SetPosition(inst.Transform:GetWorldPosition())
        bottle.components.named:SetName(inst.username)
        bottle.username = inst.username
        bottle.cause = inst.cause
        bottle.afflicter = inst.afflicter
        bottle.userid = inst.userid
    elseif inst.AnimState:IsCurrentAnimation("disappear") then
        inst.isDisappear2hm = true
        inst:Remove()
    end
end

local function AbleToAcceptTest(inst, item, giver, count)
    return item.prefab == "messagebottleempty"
end

local function AcceptTest(inst, item, giver, count)
    return inst
end

local function OnGetItemFromPlayer(inst, giver, item, count)
    inst.components.trader:Disable()
    inst.AnimState:PlayAnimation("suck")
end

local function OnRefuseItem(inst, giver, item)
end

local function getdescription(inst, viewer)
    if TUNING.isCh2hm then
        local str = {"这看起来是[" .. inst.username .. "]的灵魂"}
        if inst.cause then
            table.insert(str, "死因:" .. TUNING.util2hm.GetName(inst.cause))
        end
        if inst.afflicter then
            table.insert(str, "死于:" .. inst.afflicter)
        end
        return table.concat(str, "\n")
    else
        local str = {"Is seems soul of [" .. inst.username .. "]"}
        if inst.cause then
            table.insert(str, "cause:" .. TUNING.util2hm.GetName(inst.cause))
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
    inst.entity:AddNetwork()

    inst:AddTag("trader")
    inst.AnimState:SetBuild("hpm_player_ghost")
    inst.AnimState:SetBank("dark_soul")
    inst.AnimState:PlayAnimation("appear")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end

    inst:ListenForEvent("animover", function()
        OnAnimOver(inst)
    end)

    inst:AddComponent("named")
    inst.components.named:SetName("小丑猫")

    inst:AddComponent("trader")
    inst.components.trader:SetAbleToAcceptTest(AbleToAcceptTest)
    inst.components.trader:SetAcceptTest(AcceptTest)
    inst.components.trader.onaccept = OnGetItemFromPlayer
    inst.components.trader.onrefuse = OnRefuseItem
    inst.components.trader.deleteitemonaccept = true
    inst.components.trader.acceptnontradable = true
    inst.components.trader:Disable()

    inst.username = nil
    inst.cause = nil
    inst.afflicter = nil
    inst.userid = nil

    inst.persists = false

    inst:AddComponent("inspectable")
    inst.components.inspectable.descriptionfn = getdescription

    inst:DoTaskInTime(20, function()
        if not inst.AnimState:IsCurrentAnimation("suck") then
            inst.AnimState:PlayAnimation("disappear")
            inst.components.trader:Disable()
        end
    end)

    return inst
end

return Prefab("player_soul2hm", fn, assets)
