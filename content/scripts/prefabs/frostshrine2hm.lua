local assets =
{
    Asset("ANIM", "anim/chesspiece.zip"),
    Asset("ATLAS", "images/frostshrine2hm.xml"),
    Asset("IMAGE", "images/frostshrine2hm.tex"),
}

local prefabs =
{
    "collapse_small",

    "underwater_salvageable",
    "splash_green",
}

local function stormtaskfn(inst)
    local fx = SpawnPrefab("sharkboi_icefx2hm")
    fx.entity:SetParent(inst.entity)
    -- local parent = fx.entity:GetParent()
    -- if parent ~= nil and parent:HasTag("littlefencefx2hm") then
    --     fx.AnimState:SetScale(5,4)
    -- elseif parent ~= nil and parent:HasTag("FX") then
    --     fx.AnimState:SetScale(5,2)
    -- elseif parent ~= nil and parent:HasTag("sharkboi") and not parent:HasTag("littlefencefx2hm") then
    --     fx.AnimState:SetScale(8, 6)
    -- end
end

local function OnRefuseItem(inst, giver, item)
    inst.AnimState:PlayAnimation("jiggle")
    inst.SoundEmitter:PlaySound("ancientguardian_rework/environment/pillar_break")
end

local function GiveReward(inst, target, item, uses)
    if target and not target:IsValid() then
        target = nil
    end
    local _item = SpawnPrefab(item)
    if uses then
        _item.components.finiteuses:SetUses(uses)
    end
    LaunchAt(_item, inst, target, 1.35, 2, 1.25)
    inst.SoundEmitter:PlaySound("dontstarve/common/dropGeneric")
end

-- local staffs = {"icestaff", "icestaff2"}
local staffs = {
    icestaff = "shellweaver_icestaff2", 
    icestaff2 = "shellweaver_icestaff3"
}
local staffsreward = {
    icestaff = "icestaff2",
    icestaff2 = "icestaff3"
}
local function OnAcceptItem(inst, giver, item)
    if item.components.weighable then
        stormtaskfn(inst)
        GiveReward(inst, giver, "bootleg")
        if item.components.weighable:GetWeightPercent() >= TUNING.WEIGHABLE_HEAVY_WEIGHT_PERCENT then GiveReward(inst, giver, "bootleg") end
        item:Remove()
    elseif item.prefab == "bootleg" then
        stormtaskfn(inst)
        GiveReward(inst, giver, "bootleg_2hm")
        item:Remove()
    elseif staffs[item.prefab] and giver and AllRecipes[staffs[item.prefab]] then
        local recipe = AllRecipes[staffs[item.prefab]]
        for i, v in ipairs(recipe.ingredients) do
            if v.type ~= item.prefab then
                giver.components.inventory:ConsumeByName(v.type,v.amount)
            end
		end
        stormtaskfn(inst)
        local uses = item.components.finiteuses.current
        GiveReward(inst, giver, staffsreward[item.prefab], uses)
        item:Remove()
    elseif item.components.temperature then
        local tmp = item.components.temperature.mintemp
        item.components.temperature:SetTemperature(tmp)
        stormtaskfn(inst)
        LaunchAt(item, inst, giver, 1.35, 2, 1.25)
        inst.SoundEmitter:PlaySound("dontstarve/common/dropGeneric")
    else
        LaunchAt(item, inst, giver, 1.35, 2, 1.25)
        inst.SoundEmitter:PlaySound("dontstarve/common/dropGeneric")
    end
end

local function AbleToAcceptTest(inst, item, giver, count)
    if item:HasTag("oceanfish") and item.components.weighable then
        if item.components.weighable:GetWeight() >= 150 then
            return true
        else
            if giver.components.talker then
                giver:DoTaskInTime(0,function()
                    giver.components.talker:Say((TUNING.isCh2hm and "鱼太轻啦" or "The fish is not heavy enough"))
                end)
            end
            OnRefuseItem(inst)
            return false
        end
    elseif item.prefab == "bootleg" and not item:HasTag("cantslipperyfeet2hm") then
        return true
    elseif staffs[item.prefab] and giver then
        local recipe = AllRecipes[staffs[item.prefab]]
        if not recipe then 
            OnRefuseItem(inst)
            return false 
        end
        for i, v in ipairs(recipe.ingredients) do
            if v.type ~= item.prefab and not giver.components.inventory:Has(v.type, v.amount, true) then
                OnRefuseItem(inst)
				return false
			end
		end
        return true
    elseif item.components.temperature then
        return true
    end
    OnRefuseItem(inst)
    return false
end

local function onworkded(inst, worker, workleft, numworks)
    inst.AnimState:PlayAnimation("jiggle")
end

local function test()
end

local function onhammered(inst, worker)
    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("rock")
    if inst.components.lootdropper ~= nil then
        inst.components.lootdropper.droprecipeloot = true
        inst.components.lootdropper:DropLoot()
        inst.components.lootdropper.droprecipeloot = false
    end
    inst:Remove()
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeObstaclePhysics(inst, 1)

    inst.AnimState:SetBank("chesspiece")
    inst.AnimState:SetBuild("swap_chesspiece_sharkboi_marble")
    inst.AnimState:PlayAnimation("idle")
    inst.AnimState:SetMultColour(0.68, 0.85, 0.90, 1)	

    inst:AddTag("frostshrine2hm")
    inst:AddTag("structure")

    inst.displaynamefn = function() 
        return (TUNING.isCh2hm and "寒霜之祠") or "Frost Shrine"
    end
    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    local GetDescription = inst.components.inspectable.GetDescription
    inst.components.inspectable.GetDescription = function(self, ...)
        local desc, filter_context, author = GetDescription(self, ...)
        desc = TUNING.isCh2hm and "散发着森森寒气..." .. "\n" .. "海鱼交易出逃腿靴、升级出逃腿靴防滑、消耗制作材料升级冰魔杖、返还物品温度至最低温" 
        or "Exuding a chilling aura..."  .. "\n" .. "Oceanfish trade Bootleg Getaway, upgrade Bootleg Getaway to anti-slip, consume materials to upgrade Ice Staff wand, return item temperature to lowest temperature"
        return desc, filter_context, author
    end

    inst:AddComponent("trader")
    inst.components.trader:SetAbleToAcceptTest(AbleToAcceptTest)
    inst.components.trader.onaccept = OnAcceptItem
    inst.components.trader.onrefuse = OnRefuseItem
    inst.components.trader.deleteitemonaccept = false
    inst.components.trader.acceptnontradable = true

    inst:AddComponent("lootdropper")

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(4)
    inst.components.workable:SetOnWorkCallback(onworkded)
    inst.components.workable:SetOnFinishCallback(onhammered)

    -- NOTES(JBK): The component oceanthrowable looks unfinished at this time so I am repurposing the TOSS action.

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("frostshrine2hm", fn, assets, prefabs),
    MakePlacer("frostshrine2hm_placer", "chesspiece", "swap_chesspiece_sharkboi_marble", "idle")