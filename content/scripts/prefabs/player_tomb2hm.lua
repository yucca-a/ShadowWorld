local assets = {
    Asset("ANIM", "anim/hpm_player_tomb.zip"),
    -- tomb:dirt, full, full_shake, empty, empty_shake, preview
    Asset("ATLAS", "images/tomb_repair.xml"),
    Asset("IMAGE", "images/tomb_repair.tex"),
}

local function Plant(inst, seed)
    local plant_prefab = FunctionOrValue(seed.components.farmplantable.plant, seed)
    local plant_name = TUNING.Plants[plant_prefab]
    if plant_name then
        local plant = SpawnPrefab(plant_name)
        inst.plant = plant
        plant.tomb = inst
        local x, y, z = inst.Transform:GetWorldPosition()
        plant.Transform:SetPosition(x, y + 0.05, z)
        inst.listenforplantremoveFunc = function(it)
            inst.plant = nil
            inst.listenforplantremoveFunc = nil
        end
        inst:ListenForEvent("onremove", inst.listenforplantremoveFunc, inst.plant)
        return true
    end
end

local function ReplaceWithPlant(inst, new_plant)
    inst:RemovePlant()
    inst.plant = new_plant
    new_plant.tomb = inst
    inst.listenforplantremoveFunc = function(it)
        inst.plant = nil
        inst.listenforplantremoveFunc = nil
    end
    inst:ListenForEvent("onremove", inst.listenforplantremoveFunc, inst.plant)
end

local CANTHAVE_GHOST_TAGS = {"questing"}
local MUSTHAVE_GHOST_TAGS = {"ghostkid"}
local MAX_GHOST_NUM = 5
local function SpawnSmallGhost(inst)
    if not inst.userid or inst.ghost then return end
    local gx, gy, gz = inst.Transform:GetWorldPosition()
    local nearby_ghosts = TheSim:FindEntities(gx, gy, gz, TUNING.UNIQUE_SMALLGHOST_DISTANCE, MUSTHAVE_GHOST_TAGS, CANTHAVE_GHOST_TAGS)
    if #nearby_ghosts < MAX_GHOST_NUM then
        inst.ghost = SpawnPrefab("smallghost")
        inst.ghost.Transform:SetPosition(gx + 0.3, gy, gz + 0.3)
        inst.ghost:LinkToHome(inst)
        if inst.username then
            if not inst.ghost.components.named then
                inst.ghost:AddComponent("named")
            end
            if TUNING.isCh2hm then
                inst.ghost.components.named:SetName("小" .. inst.username)
            else
                inst.ghost.components.named:SetName("small " .. inst.username)
            end
        end

        inst.listenforghostremoveFunc = function()
            inst.ghost = nil
            inst.listenforghostremoveFunc = nil
        end
        inst:ListenForEvent("onremove", inst.listenforghostremoveFunc, inst.ghost)
    end
end

local function RemoveSmallGhost(inst)
    if inst.ghost then
        if inst.ghost:IsValid() then
            if not inst.ghost:IsInLimbo() and inst.ghost.sg then
                inst.ghost.sg:GoToState("dissipate")
                inst.ghost:DoTaskInTime(2, inst.ghost.Remove)
            else
                inst.ghost:Remove()
            end
        end
        inst.ghost = nil
    end
end

local function SpawnAngryGhost(inst, worker)
    local ghost = SpawnPrefab("ghost")
    if ghost then
        local x, y, z = inst.Transform:GetWorldPosition()
        ghost.Transform:SetPosition(x - .3, y, z - .3)
        if inst.username then
            if not ghost.components.named then
                ghost:AddComponent("named")
            end
            if TUNING.isCh2hm then
                ghost.components.named:SetName("愤怒的" .. inst.username)
            else
                ghost.components.named:SetName("angry " .. inst.username)
            end
        end
        if worker and ghost.components.combat then
            ghost.components.combat:SuggestTarget(worker)
        end
        if ghost.components.locomotor then
            ghost.components.locomotor.walkspeed = ghost.components.locomotor.walkspeed * 3
            ghost.components.locomotor.runspeed = ghost.components.locomotor.runspeed * 3
        end
        if ghost.components.combat then
            ghost.components.combat.defaultdamage = ghost.components.combat.defaultdamage * 2
        end
    end
end

local function onworkded(inst, worker, workleft, numworks)
    if workleft > 0 then
        if inst.userid then
            inst.AnimState:PlayAnimation("full_shake")
            inst.AnimState:PushAnimation("full", true)
        else
            inst.AnimState:PlayAnimation("empty_shake")
            inst.AnimState:PushAnimation("empty", true)
        end
    end
    inst:RemovePlant()
end

local function onhammered(inst, worker)
    if inst.components.burnable ~= nil and inst.components.burnable:IsBurning() then
        inst.components.burnable:Extinguish()
    end
    if inst.components.grower ~= nil then
        inst.components.grower:Reset()
    end

    if inst.userid then
        SpawnAngryGhost(inst, worker)
    end


    inst:RemovePlant()

    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("wood")
    if inst.components.lootdropper ~= nil then
        inst.components.lootdropper.droprecipeloot = true
        inst.components.lootdropper:DropLoot()
        inst.components.lootdropper.droprecipeloot = false
    end
    inst:Remove()
end

local function OnRemoveEntity(inst)
    if inst.listenforghostremoveFunc then
        inst:RemoveEventCallback("onremove", inst.listenforghostremoveFunc, inst.ghost)
        inst.listenforghostremoveFunc = nil
    end
    if inst.listenforplantremoveFunc then
        inst:RemoveEventCallback("onremove", inst.listenforplantremoveFunc, inst.plant)
        inst.listenforplantremoveFunc = nil
    end
    inst:RemoveSmallGhost()
    if inst.dirt then
        if inst.dirt:IsValid() then
            inst.dirt:Remove()
        end
        inst.dirt = nil
    end

    inst:RemovePlant()
end

local function OnLoadPostPass(inst, newents, savedata)
    inst.ghost = nil
    if savedata ~= nil then
        if savedata.ghost_id ~= nil and newents[savedata.ghost_id] ~= nil then
            inst.ghost = newents[savedata.ghost_id].entity
            inst.ghost:LinkToHome(inst)
            if inst.username then
                if not inst.ghost.components.named then
                    inst.ghost:AddComponent("named")
                end
                if TUNING.isCh2hm then
                    inst.ghost.components.named:SetName("小" .. inst.username)
                else
                    inst.ghost.components.named:SetName("small " .. inst.username)
                end
            end
            inst.listenforghostremoveFunc = function()
                inst.ghost = nil
                inst.listenforghostremoveFunc = nil
            end
            inst:ListenForEvent("onremove", inst.listenforghostremoveFunc, inst.ghost)
        end
        if savedata.plant_id and newents[savedata.plant_id] then
            inst.plant = newents[savedata.plant_id].entity
            local x, y, z = inst.Transform:GetWorldPosition()
            inst.plant.Transform:SetPosition(x, y + 0.05, z)
            inst.plant.tomb = inst
            if inst.plant.makePickable_farm then
                inst:MakePickable_farm(inst.plant.makePickable_farm)
                inst.plant.makePickable_farm = nil
            end
            if inst.plant.makePickable_weed then
                inst:MakePickable_weed(inst.plant.makePickable_weed)
                inst.plant.makePickable_weed = nil
            end
            inst.listenforplantremoveFunc = function()
                inst.plant = nil
                inst.listenforplantremoveFunc = nil
            end
            inst:ListenForEvent("onremove", inst.listenforplantremoveFunc, inst.plant)
        end
    end
end

local function OnSave(inst, data)
    data.username = inst.username
    data.cause = inst.cause
    data.afflicter = inst.afflicter
    data.userid = inst.userid
    data.atonce = inst.atonce and 1 or 0

    local ents = {}
    if inst.ghost then
        data.ghost_id = inst.ghost.GUID
        table.insert(ents, data.ghost_id)
    end
    if inst.plant then
        data.plant_id = inst.plant.GUID
        table.insert(ents, data.plant_id)
    end

    return ents
end

local function OnLoad(inst, data)
    if data then
        if data.username then
            inst.components.named:SetName(data.username .. TUNING.util2hm.GetLanguage("的坟墓", " tomb"))
        end
        inst.username = data.username or inst.components.named.name or TUNING.util2hm.GetLanguage("神秘人", "unnamed")
        inst.cause = data.cause
        inst.afflicter = data.afflicter
        inst.userid = data.userid
        inst.atonce = data.atonce == 1
        if inst.userid then
            -- inst.components.trader:Disable()
            inst.AnimState:PlayAnimation("full")
        else
            inst.components.trader:Enable()
        end
    end
end

local function AbleToAcceptTest(inst, item, giver, count)
    if not inst.userid then
        return item.prefab == "player_soul_bottle2hm" and item.userid and item.username
    elseif not inst.plant then
        return item.components.farmplantable
    elseif inst.plant then
        return (item.prefab == "ghostflower") and inst.plant:CanGetFlower()
    end
end

local function AcceptTest(inst, item, giver, count)
    return inst
end

local function OnGetItemFromPlayer(inst, giver, item, count)
    -- inst.components.trader:Disable()
    local removeIt = false
    if item.prefab == "player_soul_bottle2hm" and not inst.userid then
        inst.AnimState:PlayAnimation("full")
        -- inst.dirt = SpawnPrefab("dirt2hm")
        -- inst.dirt.Transform:SetPosition(inst:GetPosition())
        inst.userid = item.userid
        inst.username = item.username
        inst.cause = item.cause
        inst.afflicter = item.afflicter
        inst.components.named:SetName(inst.username .. TUNING.util2hm.GetLanguage("的坟墓", " tomb"))
        SpawnSmallGhost(inst)
        removeIt = true
    elseif not inst.plant and Plant(inst, item) then
        removeIt = true
    elseif inst.plant and (item.prefab == "ghostflower") and inst.plant:CanGetFlower() then
        inst.plant:AddFlower()
        removeIt = true
    end

    if removeIt then
        if item.components.stackable ~= nil and item.components.stackable.stacksize > count then
            item = item.components.stackable:Get(count)
        else
            item.components.inventoryitem:RemoveFromOwner(true)
        end
        item:Remove()
    end
end

local function OnRefuseItem(inst, giver, item)
end

local function on_day_change(inst)
    if (inst.ghost == nil or not inst.ghost:IsValid()) and #AllPlayers > 0 and inst.userid then
        local ghost_spawn_chance = 0
        for _, v in ipairs(AllPlayers) do
            if v:HasTag("ghostlyfriend") then
                ghost_spawn_chance = ghost_spawn_chance + TUNING.GHOST_GRAVESTONE_CHANCE * 2
            end
        end

        if ghost_spawn_chance > 0 then
            if inst.atonce then
                inst.atonce = false
                ghost_spawn_chance = 1
            end
            if math.random() < ghost_spawn_chance then
                SpawnSmallGhost(inst)
            end
        end
    end

    if (inst.ghost and inst.ghost:IsValid()) and #AllPlayers > 0 then
        local ghost_spawn_chance = 0
        for _, v in ipairs(AllPlayers) do
            if v:HasTag("ghostlyfriend") then
                ghost_spawn_chance = ghost_spawn_chance + TUNING.GHOST_GRAVESTONE_CHANCE * 2
            end
        end

        if ghost_spawn_chance == 0 then
            inst.atonce = true
            -- print("on_day_change", inst, inst.ghost)
            inst:RemoveSmallGhost()
        end
    end
end

local function GetGrowStr(class)
    local str = {}
    if class then
        if class.targettime ~= nil and class.stage ~= class:GetNextStage() then
            table.insert(str, string.format(TUNING.isCh2hm and "生长中 还需 %s" or "growing timeleft %s", TUNING.util2hm.GetTime(class.targettime - GetTime())))
        elseif class.pausedremaining then
            table.insert(str, string.format(TUNING.isCh2hm and "暂停生长 还需 %s" or "paused timeleft %s", TUNING.util2hm.GetTime(class.pausedremaining)))
        else
            table.insert(str, TUNING.isCh2hm and "停止生长" or "not growing")
        end
    end
    return table.concat(str, "\n")
end

local function getdescription(inst, viewer)
    local str = {}

    if inst.userid then
        if TUNING.isCh2hm then
            table.insert(str, "这里埋着[" .. inst.username .. "],愿他安息")
            if inst.cause then
                table.insert(str, "死因:" .. TUNING.util2hm.GetName(inst.cause))
            end
            if inst.afflicter then
                table.insert(str, "死于:" .. inst.afflicter)
            end
        else
            table.insert(str, "tomb of [" .. inst.username .. "]")
            if inst.cause then
                table.insert(str, "cause:" .. TUNING.util2hm.GetName(inst.cause))
            end
            if inst.afflicter then
                table.insert(str, "afflicter:" .. inst.afflicter)
            end
        end
        if inst.plant then
            if TUNING.isCh2hm then
                if inst.plant.plant_def then
                    table.insert(str, "[" .. inst.username .. "]呵护着[" .. TUNING.util2hm.GetName(inst.plant.plant_def.prefab) .. "]成长")
                elseif inst.plant.weed_def then
                    table.insert(str, "究竟是谁在[" .. inst.username .. "]的坟头种[" .. TUNING.util2hm.GetName(inst.plant.weed_def.prefab) .."]???")
                end
            else
                if inst.plant.plant_def then
                    table.insert(str, "[" .. inst.username .. "] protect [" .. TUNING.util2hm.GetName(inst.plant.plant_def.prefab) .. "]")
                elseif inst.plant.weed_def then
                    table.insert(str, "who fucking plant [" .. TUNING.util2hm.GetName(inst.plant.weed_def.prefab) .."] on tomb of [" .. inst.username .. "]???")
                end
            end
            table.insert(str, GetGrowStr(inst.plant.components.growable))
        end
    else
        if TUNING.isCh2hm then
            table.insert(str, "这里空荡荡的,很适合放个队友进去")
        else
            table.insert(str, "empty tomb")
        end
    end

    return table.concat(str, "\n")
end

local function RemovePlant(inst, notDrop)
    -- print("inst.components.pickable " .. tostring(inst.components.pickable))
    if inst.components.pickable then
        inst:RemoveTag("farm_plant")
        if not notDrop then
            inst.components.lootdropper:DropLoot()
        end
        inst:RemoveComponent("pickable")
        inst.components.lootdropper.lootsetupfn = nil
        inst.components.lootdropper:SetLoot(nil)
    end
    if inst.plant then
        if inst.plant:IsValid() then
            inst.plant:Remove()
        end
        inst.plant = nil
    end
end

local function OnPicked(inst)
    RemovePlant(inst, true)
end

local spoiled_food_loot = {"spoiled_food"}
local function SetupLoot_farm(lootdropper)
    -- print("SetupLoot_farm")
    local inst = lootdropper.inst
    local plant = inst.plant
    if plant then
        if plant.is_rotten then -- if rotten
            lootdropper:SetLoot(plant.is_oversized and plant.plant_def.loot_oversized_rot or spoiled_food_loot)
        elseif inst.components.pickable ~= nil then
            if plant.is_oversized then
                lootdropper:SetLoot({plant.plant_def.product_oversized, plant.plant_def.product_oversized})
            else
                if math.random() < 0.5 then
                    lootdropper:SetLoot({plant.plant_def.product, plant.plant_def.product})
                else
                    lootdropper:SetLoot({plant.plant_def.product})
                end
            end
        end
    end
end

local function MakePickable_farm(inst, enable, product)
    -- print("MakePickable_farm " .. tostring(enable))
    if not enable then
        inst:RemoveComponent("pickable")
        inst.components.lootdropper.lootsetupfn = nil
    else
        if inst.components.pickable == nil then
            inst:AddComponent("pickable")
            -- inst.components.pickable.remove_when_picked = true
        end
        if inst.components.lootdropper then
            inst.components.lootdropper.lootsetupfn = SetupLoot_farm
        end
        inst.components.pickable:SetUp(nil)
        inst.components.pickable.use_lootdropper_for_product = true
        inst.components.pickable.picksound = product == "spoiled_food" and "dontstarve/wilson/harvest_berries" or "dontstarve/wilson/pickup_plants"
        inst:AddTag("farm_plant")
        inst.components.pickable:SetOnPickedFn(OnPicked)
    end
end

local function SetupLoot_weed(lootdropper)
    local inst = lootdropper.inst
    local plant = inst.plant
    if plant then
        if inst.components.pickable ~= nil then
            lootdropper:SetLoot({plant.weed_def.product})
        end
    end
end

local function MakePickable_weed(inst, enable)
    if not enable then
        inst:RemoveComponent("pickable")
        inst.components.lootdropper.lootsetupfn = nil
    else
        if inst.components.pickable == nil then
            inst:AddComponent("pickable")
            -- inst.components.pickable.remove_when_picked = true
        end
        if inst.components.lootdropper then
            inst.components.lootdropper.lootsetupfn = SetupLoot_weed
        end
        inst.components.pickable:SetUp(nil)
        inst.components.pickable.use_lootdropper_for_product = true
        inst.components.pickable.picksound = "dontstarve/wilson/pickup_plants"
        inst.components.pickable:SetOnPickedFn(OnPicked)
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    MakeObstaclePhysics(inst, 0.8)
    inst:AddTag("structure")
    inst.AnimState:SetBuild("hpm_player_tomb")
    inst.AnimState:SetBank("tomb")
    inst.AnimState:PlayAnimation("empty")
    inst.MiniMapEntity:SetIcon("tomb_repair.tex")

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    -- inst.AnimState:SetLayer(LAYER_BACKGROUND)
    -- inst.AnimState:SetSortOrder(3)

    -- MakeLargeBurnable(inst, nil, nil, true)
    -- MakeMediumPropagator(inst)

    inst.username = nil
    inst.cause = nil
    inst.afflicter = nil
    inst.userid = nil

    inst:AddComponent("named")
    inst.components.named:SetName("哀悼之穴")

    inst:AddComponent("trader")
    inst.components.trader:SetAbleToAcceptTest(AbleToAcceptTest)
    inst.components.trader:SetAcceptTest(AcceptTest)
    inst.components.trader.onaccept = OnGetItemFromPlayer
    inst.components.trader.onrefuse = OnRefuseItem
    inst.components.trader.deleteitemonaccept = false
    inst.components.trader.acceptnontradable = true
    -- inst.components.trader:Enable()

    inst:AddComponent("lootdropper")
    inst.components.lootdropper.droprecipeloot = false

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(4)
    inst.components.workable:SetOnWorkCallback(onworkded)
    inst.components.workable:SetOnFinishCallback(onhammered)

    inst:AddComponent("inspectable")
    inst.components.inspectable.descriptionfn = getdescription

    inst:WatchWorldState("cycles", on_day_change)

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad
    inst.OnLoadPostPass = OnLoadPostPass
    inst.OnRemoveEntity = OnRemoveEntity
    inst.MakePickable_farm = MakePickable_farm
    inst.MakePickable_weed = MakePickable_weed
    inst.RemovePlant = RemovePlant
    inst.RemoveSmallGhost = RemoveSmallGhost
    inst.ReplaceWithPlant = ReplaceWithPlant

    return inst
end

return Prefab("player_tomb2hm", fn, assets),
    MakePlacer("player_tomb2hm_placer", "tomb", "hpm_player_tomb", "preview")