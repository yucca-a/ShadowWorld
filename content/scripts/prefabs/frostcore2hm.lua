local assets = {
    -- Asset("ANIM", "anim/bootleg.zip"),
    -- Asset("ANIM", "anim/swap_bootleg.zip"),
    -- Asset("ATLAS", "images/inventoryimages/frostcore2hm.xml"),
	-- Asset("IMAGE", "images/inventoryimages/frostcore2hm.tex"),
}
local prefabs = {
    "oceanwhirlportal",
    "dirt_puff",
}

local function getcontainerspace2hm(inst, container, data, addprefab)
    local slots = container.slots or container.itemslots
    local numslots = container.numslots or container.maxslots
    -- 没有剩余空间时返回true
    local prefabs = data.prefabs or {}
    local infiniteprefabs = data.infiniteprefabs or {}
    local lacksize = data.lacksize or {}
    local leftnumslots = numslots
    for i = 1, numslots do
        local item = slots[i]
        if item ~= nil and item:IsValid() then
            leftnumslots = leftnumslots - 1
            local hasprefab = prefabs and table.contains(prefabs, item.prefab)
            if not hasprefab and addprefab ~= false and prefabs and not table.contains(itemsblacklist, item.prefab) then
                table.insert(prefabs, item.prefab)
                hasprefab = true
            end
            if hasprefab and item.components.stackable then
                if container.infinitestacksize or item.components.stackable.maxsize == math.huge then
                    infiniteprefabs[item.prefab] = true
                    if lacksize[item.prefab] then lacksize[item.prefab] = nil end
                elseif not infiniteprefabs[item.prefab] and item.components.stackable.stacksize < item.components.stackable.maxsize then
                    lacksize[item.prefab] = (lacksize[item.prefab] or 0) + item.components.stackable.maxsize -
                        item.components.stackable.stacksize
                end
            end
        end
    end
    return leftnumslots, lacksize, infiniteprefabs
end

local time = 120
local function createice(inst)
    local container = inst.components.container or inst.components.inventory
    if not container then return end
    local x,y,z = inst:GetPosition()
    local container = inst.components.container or inst.components.inventory
    local data = {}
    data.prefabs = {"ice"}
    local leftnumslots, lacksize, infiniteprefabs = getcontainerspace2hm(inst, container, data, false)
    if not container:IsFull() then
        local ice = SpawnPrefab("ice")
        if not container:GiveItem(ice, nil, x,y,z) then
            ice:Remove()
        end
    elseif container:IsFull() and lacksize and lacksize["ice"] and lacksize["ice"] > 0 or lacksize == nil then
        local ice = SpawnPrefab("ice")
        if not container:GiveItem(ice, nil, x,y,z) then
            ice:Remove()
        end
    end
    if inst.createicetask2hm then
        inst.createicetask2hm:Cancel()
        inst.createicetask2hm = inst:DoPeriodicTask(math.random(-1,1) * 20 + time,createice)
    end
end

local function onupgrade(inst, doer, target, pos, act)
    if not target then return false end
    if target:HasTag("pocketdimension_container") and not target:HasTag("frostcore2hm") then
        SendModRPCToShard(GetShardModRPC("MOD_HARDMODE", "ms_preserver_update"), nil, true)
        local item = inst.components.stackable:Get(1)
        item:Remove()
        return true
    elseif target.prefab == "tacklestation" then
        local container = target.components.container_proxy:GetMaster()
        if not container then return false end
        if container:HasTag("frostcore2hm") then
            if doer and doer.components and doer.components.talker then
                doer:DoTaskInTime(0, function()
                    doer.components.talker:Say(TUNING.isCh2hm and ("容器已经升级过啦") or ("The container has already been upgraded."))
                end)
            end
            return false
        end
        if container.onupgrade then container:onupgrade() end
        local item = inst.components.stackable:Get(1)
        item:Remove()
        return true
    end
    target:AddTag("frostcore2hm")
    local fx = SpawnPrefab("sharkboi_icefx2hm")
    fx.entity:SetParent(target.entity)
    if target.components.preserver then
        local oldperish = target.components.preserver.perish_rate_multiplier
        if oldperish then
            target.components.preserver.perish_rate_multiplier = function(inst, item, ...)
                local num = FunctionOrValue(oldperish, inst, item, ...)
                if num and num > 0 then 
                    num = num / 2
                elseif num and num < 0 then
                    num = num * 2
                end
                return num
            end
        end
    else
        target:AddComponent("preserver")
        local num = TUNING.PERISH_FRIDGE_MULT
        if target:HasTag("fridge") then
            num = function(_inst, _item) 
                return (_item and _item:HasTag("frozen") and not _inst:HasTag("nocool") and not _inst:HasTag("lowcool") and TUNING.PERISH_COLD_FROZEN_MULT / 2) 
                or TUNING.PERISH_FRIDGE_MULT / 2
            end
        elseif target:HasTag("foodpreserver") then
            num = TUNING.PERISH_FOOD_PRESERVER_MULT / 2
        end
        target.components.preserver:SetPerishRateMultiplier(num)
    end
    if target.prefab == "icebox" then
        target.createicetask2hm = target:DoPeriodicTask(math.random(-1,1) * 20 + time ,createice)
    end
    local item = inst.components.stackable:Get(1)
    item:Remove()
    return true
end

local function upgradehatcondition(inst, doer, actions, right, target)
    if target:HasTag("canfrostcoreUP2hm") and not target:HasTag("frostcore2hm") then
        return true
    elseif target.prefab == "tacklestation" and target.components and target.components.container_proxy and target.components.container_proxy:GetMaster() then
        local container = target.components.container_proxy:GetMaster()
        if not container then return false end
        return true
    end
    return false
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("winter_ornaments2023")
    inst.AnimState:SetBuild("winter_ornaments2023")
    inst.AnimState:PlayAnimation("boss_mutateddeerclops")

    MakeInventoryFloatable(inst, nil, .075, 0.8)


    inst:AddTag("frostcore2hm")
    inst.actionothercondition2hm = upgradehatcondition

    -- inst.displaynamefn = function() 
    --     return (TUNING.isCh2hm and "霜冻核心") or "Frost Core"
    -- end
    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    local GetDescription = inst.components.inspectable.GetDescription
    inst.components.inspectable.GetDescription = function(self, ...)
        local desc, filter_context, author = GetDescription(self, ...)
        desc = TUNING.isCh2hm and "寒气刺骨...." or "The cold pierced to the bone ..."
        return desc, filter_context, author
    end

    -- inst:AddComponent("named")
    -- inst.components.named:SetName((TUNING.isCh2hm and "霜冻核心") or "Frost Core")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "frostcore2hm"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/frostcore2hm.xml"

    inst:AddComponent("action2hm")
    inst.components.action2hm.actionfn = onupgrade

    inst:AddComponent("stackable")
    inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM

    -- NOTES(JBK): The component oceanthrowable looks unfinished at this time so I am repurposing the TOSS action.

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("frostcore2hm", fn, assets, prefabs)