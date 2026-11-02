local chargetime = 480 * 4
local tasktime = 12
local repairuse = 1 / (chargetime / tasktime)

local assets = {
    Asset("ANIM", "anim/bootleg.zip"),
    Asset("ANIM", "anim/swap_bootleg.zip"),
    Asset("ATLAS", "images/inventoryimages/bootleg2hm.xml"),
	Asset("IMAGE", "images/inventoryimages/bootleg2hm.tex"),
}
local prefabs = {
    "oceanwhirlportal",
    "dirt_puff",
}

local function onupgrade(inst, doer, target, pos, act)
    local nums = inst.item_num:value()
    local needs = math.max(5 - target.item_num:value(), 1)
    local final = (nums > needs and needs) or nums
    target.item_num:set(target.item_num:value() + final)
    target.components.finiteuses:SetMaxUses(target.item_num:value())
    local uses = target.components.finiteuses:GetUses()
    local _uses = math.min(final, inst.components.finiteuses:GetUses())
    target.components.finiteuses:SetUses(uses + _uses)
    if final == nums then
        inst:Remove()
    else
        inst.item_num:set(inst.item_num:value() - final)
        inst.components.finiteuses:SetMaxUses(inst.item_num:value())
        local uses = inst.components.finiteuses:GetUses()
        inst.components.finiteuses:SetUses(uses - final)
    end
    return true
end

local function upgradehatcondition(inst, doer, actions, right, target)
    if target.prefab == "bootleg2hm" and inst.item_num and target.item_num and target.item_num:value() < 5 then
        return true
    end
    return false
end

local function CreateOceanWhirlportal(inst, enter_pt, exit_pt)
    local enter = SpawnPrefab("oceanwhirlportal")
    enter.Transform:SetPosition(enter_pt:Get())

    local exit = SpawnPrefab("oceanwhirlportal")
    exit.Transform:SetPosition(exit_pt:Get())

    -- NOTES(JBK): The enter goes to exit and the exit goes to enter as a two way teleport system.
    enter:SetExit(exit)
    exit:SetExit(enter)
end

local function onequip(inst, owner)
    owner.AnimState:OverrideSymbol("swap_object", "swap_bootleg", "swap_bootleg")
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")
end

local function onunequip(inst, owner)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
end

local function onthrown(inst, attacker, targetpos)
    inst:AddTag("NOCLICK")
    inst.AnimState:PlayAnimation("spin_loop", true)

    inst.Physics:SetMass(1)
    inst.Physics:SetCapsule(0.2, 0.2)
    inst.Physics:SetFriction(0)
    inst.Physics:SetDamping(0)
    inst.Physics:SetCollisionGroup(COLLISION.WORLD)
	inst.Physics:SetCollisionMask(COLLISION.GROUND)

    inst._oceanwhirlportal_spawnpos = Vector3(targetpos.x, 0, targetpos.z)
end

local function onhit(inst, attacker, target)
    local x, y, z = inst.Transform:GetWorldPosition()
    inst:RemoveTag("NOCLICK")
    -- inst.persists = true
    MakeInventoryPhysics(inst)
    inst.AnimState:PlayAnimation("idle")
    if not TheWorld.Map:IsOceanAtPoint(x, y, z) then
        inst._oceanwhirlportal_spawnpos = nil
        inst.SoundEmitter:PlaySound("dontstarve/common/together/infection_burst")
        SpawnPrefab("dirt_puff").Transform:SetPosition(x, y, z)
        return
    end
    inst:DoTaskInTime(0, function()
        if attacker and (attacker.components.inventory or attacker.components.container) then
            local container = attacker.components.inventory or attacker.components.container
            container:GiveItem(inst, nil, inst:GetPosition())
        end
    end)
    if inst.components.finiteuses:GetUses() < 1 then
        inst._oceanwhirlportal_spawnpos = nil
        return
    end
    inst.components.finiteuses:Use(1)
    inst:CreateOceanWhirlportal(Vector3(x, 0, z), inst._oceanwhirlportal_spawnpos)
    inst.Physics:Teleport(x, 0, z)
    -- inst.persists = false
    inst.SoundEmitter:PlaySound("turnoftides/common/together/water/submerge/large")
    -- inst:ListenForEvent("animqueueover", function(inst)
    --     inst:Remove()
    --     local new = SpawnPrefab("bootleg2hm")
    --     if new then
    --         new.components.rechargeable:Discharge(4 * 480)
    --         if attacker and (attacker.components.inventory or attacker.components.container) then
    --             local container = attacker.components.inventory or attacker.components.container
    --             container:GiveItem(new)
    --         end
    --     end
    -- end)
end

local function CanTossOnMap(_, doer)
    local platform = doer:GetCurrentPlatform()
    return (platform ~= nil and platform:HasTag("boat"))
end

local function InitMapDecorations(inst) -- NOTES(JBK): This is used in mapscreen and has access to minimap icons.
    return {
        {
            atlas = GetInventoryItemAtlas("bootleg.tex"),
            image = "bootleg.tex",
            scale = 0.75,
        },
        {
            atlas = GetMinimapAtlas("oceanwhirlportal.png"),
            image = "oceanwhirlportal.png",
            --scale = 1.0,
        },
    }
end

local function CalculateMapDecorations(inst, rmbents, px, pz, rmbx, rmbz)
    local dx, dz = rmbx - px, rmbz - pz
    if dx == 0 and dz == 0 then
        dx = 1
    end

    local dist = math.sqrt(dx * dx + dz * dz)

    rmbents[1].worldx = dx * (ACTIONS.TOSS.distance / dist) + px
    rmbents[1].worldz = dz * (ACTIONS.TOSS.distance / dist) + pz

    rmbents[2].worldx = dx + px
    rmbents[2].worldz = dz + pz
end

local function bootlegcancel(inst)
    local oldowner = inst.oldowner2hm
    inst.oldowner2hm = nil
    if oldowner and oldowner:IsValid() and oldowner.bootlegs2hm then
        for i = #oldowner.bootlegs2hm, 1, -1 do
            local bootleg = oldowner.bootlegs2hm[i]
            if bootleg == inst then
                table.remove(oldowner.bootlegs2hm, i)
                break
            end
        end
        if IsTableEmpty(oldowner.bootlegs2hm) and not oldowner:HasTag("playerghost") and not oldowner.components.slipperyfeet then
            oldowner:AddComponent("slipperyfeet")
            oldowner.bootlegs2hm = nil
        end
    end
end
local function bootlegupdate(inst)
    local owner = inst.components.inventoryitem:GetGrandOwner()
    if owner == inst.oldowner2hm then return end
    bootlegcancel(inst)
    if owner and owner:IsValid() and owner:HasTag("player") and owner.components.slipperyfeet then
        inst.oldowner2hm = owner
        inst.oldowner2hm:RemoveComponent("slipperyfeet")
        owner.bootlegs2hm = owner.bootlegs2hm or {}
        table.insert(owner.bootlegs2hm, inst)
    end
end
local function delaybootlegupdate(inst) inst:DoTaskInTime(0, bootlegupdate) end

local function onsave(inst, data) 
    data.item_num2hm = inst.item_num and inst.item_num:value()
    data.use2hm = inst.components.finiteuses:GetUses()
end
local function onload(inst, data)
    if data then
        if data.item_num2hm then
            inst.item_num:set(data.item_num2hm)
            inst.components.finiteuses:SetMaxUses(data.item_num2hm)
            if data.use2hm then
                inst.components.finiteuses:SetUses(data.use2hm)
            end
        end
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("bootleg")
    inst.AnimState:SetBuild("bootleg")
    inst.AnimState:PlayAnimation("idle")

    MakeInventoryFloatable(inst, "med", nil, 0.62)

    inst:AddTag("cantslipperyfeet2hm")
    inst:AddTag("tool")
    inst:AddTag("allow_action_on_impassable") -- Allow on ocean.
    inst:AddTag("complexprojectile_showoceanaction") -- Show action TOSS on ocean.
    inst:AddTag("action_pulls_up_map") -- Make the non-map action pull up the map instead.
    inst.item_num = net_uint(inst.GUID, "item_number","numbers")

    inst.map_remap_min_dist = ACTIONS.TOSS.distance + TUNING.OCEANWHIRLPORTAL_BOAT_INTERACT_DISTANCE * 2
    inst.CanTossInWorld = CanTossOnMap
    inst.CanTossOnMap = CanTossOnMap
    inst.InitMapDecorations = InitMapDecorations
    inst.CalculateMapDecorations = CalculateMapDecorations
    inst.valid_map_actions = {
        [ACTIONS.TOSS] = true,
    }

    inst.actionothercondition2hm = upgradehatcondition
    inst.displaynamefn = function()
        local percent = math.floor (100 / (inst.item_num and inst.item_num:value() or 1) * 10 ) / 10
        return ((TUNING.isCh2hm and "永恒-出逃腿靴") or "Eternal-Bootleg Getaway") .. " ×" .. tostring(inst.item_num and inst.item_num:value() or 1) .. " " ..tostring(percent) .. "%/次"
    end
    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.item_num:set(1)
    inst.CreateOceanWhirlportal = CreateOceanWhirlportal

    inst:AddComponent("inspectable")
    local GetDescription = inst.components.inspectable.GetDescription
    inst.components.inspectable.GetDescription = function(self, ...)
        local desc, filter_context, author = GetDescription(self, ...)
        desc = TUNING.isCh2hm and "看起来永远用不坏" or "Looks like it will never wear out"
        return desc, filter_context, author
    end

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "bootleg2hm"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/bootleg2hm.xml"

    local equippable = inst:AddComponent("equippable")
    equippable:SetOnEquip(onequip)
    equippable:SetOnUnequip(onunequip)

    -- NOTES(JBK): The component oceanthrowable looks unfinished at this time so I am repurposing the TOSS action.
    local complexprojectile = inst:AddComponent("complexprojectile")
    complexprojectile:SetHorizontalSpeed(15)
    complexprojectile:SetGravity(-35)
    complexprojectile:SetLaunchOffset(Vector3(.25, 1, 0))
    complexprojectile:SetOnLaunch(onthrown)
    complexprojectile:SetOnHit(onhit)

    inst:AddComponent("action2hm")
    inst.components.action2hm.actionfn = onupgrade

    inst:AddComponent("finiteuses")
    inst.components.finiteuses:SetMaxUses(1)
    inst.components.finiteuses:SetUses(1)
    -- inst.components.rechargeable:SetOnChargedFn(function(inst)
    --     local equippable = inst:AddComponent("equippable")
    --     equippable:SetOnEquip(onequip)
    --     equippable:SetOnUnequip(onunequip)
    -- end)
    -- inst.components.rechargeable:SetOnDischargedFn(function(inst)
    --     inst:RemoveComponent("equippable")
    -- end)

    inst:ListenForEvent("onputininventory", delaybootlegupdate)
    inst:ListenForEvent("ondropped", delaybootlegupdate)
    inst:ListenForEvent("onremove", bootlegcancel)
    inst:DoPeriodicTask(tasktime, function()
        inst.components.finiteuses:Repair(repairuse * (inst.item_num:value() or 1))
    end)

    inst.OnSave = onsave
    inst.OnLoad = onload
    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("bootleg2hm", fn, assets, prefabs)