local ignorerange = GetModConfigData("container_live") == -1
local DONT_ACCEPT_FOODTYPES = {[FOODTYPE.INSECT] = true}
local function caneat(inst, food)
    if food and food:IsValid() and food.prefab ~= inst.prefab and food.components.edible and not food:HasTag("curse2hm") and
        not DONT_ACCEPT_FOODTYPES[food.components.edible.foodtype] then
        if inst.components.eater and inst.components.eater:CanEat(food) then
            return true
        elseif (inst.fish_def or inst:HasTag("pondfish")) and not (food.fish_def or food:HasTag("pondfish")) then
            local diet = inst.fish_def and inst.fish_def.diet and inst.fish_def.diet.caneat or FOODGROUP.BERRIES_AND_SEEDS
            if diet then
                for i, v in ipairs(diet) do
                    if type(v) == "table" then
                        for i2, v2 in ipairs(v.types) do if food:HasTag("edible_" .. v2) then return true end end
                    elseif food:HasTag("edible_" .. v) then
                        return true
                    end
                end
            end
        end
    end
end
local function trykillfish(inst, fish, rate)
    if fish and fish:IsValid() and (fish.fish_def or fish:HasTag("pondfish")) and fish.prefab ~= inst.prefab then
        local weight1 = inst.components.weighable and inst.components.weighable.weight or math.random(25, 315)
        local weight2 = fish.components.weighable and fish.components.weighable.weight or math.random(25, 315)
        if weight1 < weight2 then return false end
        if math.random() < math.abs((weight1 - weight2) / 300 / (rate or 8)) then
            fish:DoTaskInTime(0, fish.Remove)
            return fish
        end
    end
end

local function canceleatfoodtask(inst)
    if inst.eatfood2hmtask then
        inst.eatfood2hmtask:Cancel()
        inst.eatfood2hmtask = nil
    end
end

local function tryfindfood(inst)
    local owner = inst.components.inventoryitem and inst.components.inventoryitem.owner
    if not (owner and owner:IsValid()) then
        canceleatfoodtask(inst)
        return
    end
    local container = owner.components.inventory or owner.components.container
    local slots = container.itemslots or container.slots or {}
    local numslots = container.maxslots or container.numslots or 0
    if numslots <= 1 then
        canceleatfoodtask(inst)
        return
    end
    local prevslot
    for i = 1, numslots, 1 do
        if slots[i] == inst then
            prevslot = i
            break
        end
    end
    if not prevslot then
        canceleatfoodtask(inst)
        return
    end
    local foodslot
    for i = 1, numslots, 1 do
        local v = slots[i]
        if v ~= inst and caneat(inst, v) then
            if ignorerange then
                if not (inst.components.eater and inst.components.eater:Eat(v)) then container:RemoveItem(v):Remove() end
                return
            elseif foodslot then
                foodslot = math.abs(prevslot - foodslot) > math.abs(prevslot - i) and i or foodslot
            else
                foodslot = i
            end
        end
    end
    if foodslot then
        if math.abs(prevslot - foodslot) <= 1 then
            local food = slots[foodslot]
            if food and not (inst.components.eater and inst.components.eater:Eat(food)) then container:RemoveItem(food):Remove() end
        elseif inst.components.locomotor then
            local elseslot = foodslot > prevslot and prevslot + 1 or prevslot - 1
            container:RemoveItem(inst, true)
            local other = slots[elseslot]
            if other then container:RemoveItem(other, true) end
            container:GiveItem(inst, elseslot)
            if other then container:GiveItem(other, prevslot) end
        end
    elseif inst.fish_def or inst:HasTag("pondfish") then
        if ignorerange then
            local rate = (container.maxslots or container.numslots or 0) * 8
            for k, v in pairs(slots) do if trykillfish(inst, v, rate) == inst then return end end
        else
            if trykillfish(inst, slots[prevslot - 1]) ~= inst then trykillfish(inst, slots[prevslot + 1]) end
        end
    end
end

local function checkinventory(inst)
    if inst.components.inventoryitem and inst.components.inventoryitem:GetSlotNum() ~= nil then
        if not inst.eatfood2hmtask then inst.eatfood2hmtask = inst:DoPeriodicTask(60, tryfindfood, math.random(10, 60) + math.random()) end
    elseif inst.eatfood2hmtask then
        inst.eatfood2hmtask:Cancel()
        inst.eatfood2hmtask = nil
    end
end
local function onputininventory(inst) inst:DoTaskInTime(0, checkinventory) end
AddPrefabPostInitAny(function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.inventoryitem and (inst.components.eater or inst.fish_def or inst:HasTag("pondfish")) then
        inst:ListenForEvent("onputininventory", onputininventory)
        inst:DoTaskInTime(FRAMES, checkinventory)
    end
end)
