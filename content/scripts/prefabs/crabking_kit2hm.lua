local assets =
{
    Asset("ANIM", "anim/boat_bumper_crabking_kit2hm.zip"),
    Asset("ATLAS", "images/inventoryimages/crabking_kit2hm.xml"),
    Asset("IMAGE", "images/inventoryimages/crabking_kit2hm.tex"),
}

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst:AddTag("boat_accessory")

    inst.AnimState:SetBank("boat_bumper_crabking_kit2hm")
    inst.AnimState:SetBuild("boat_bumper_crabking_kit2hm")
    inst.AnimState:PlayAnimation("idle")

    MakeInventoryFloatable(inst, "med")

    inst.entity:SetPristine()
    inst.displaynamefn = function() 
        return (TUNING.isCh2hm and "损坏的帝王蟹保险杠套装") or "Broken Crab King Bumper Kit"
    end
    inst.repairmaterials2hm = {
        rocks = 15 / 300 * 720,
        cutstone = 45 / 300 * 720,
        wall_stone_item = 15 / 300 * 720,
    }
    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    local GetDescription = inst.components.inspectable.GetDescription
    inst.components.inspectable.GetDescription = function(self, ...)
        local desc, filter_context, author = GetDescription(self, ...)
        desc = TUNING.isCh2hm and "损坏了...它需要一定时间恢复" or "Broken...It takes some time to recover"
        return desc, filter_context, author
    end

    inst:AddComponent("repairable2hm")
	inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "crabking_kit2hm"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/crabking_kit2hm.xml"
    inst:AddComponent("rechargeable")
    inst.components.rechargeable:SetOnChargedFn(function(inst)
        local container = inst.components.inventoryitem:GetContainer()
        local newboatbumpercrabking = SpawnPrefab("boat_bumper_crabking_kit")
        if container then
            container:GiveItem(newboatbumpercrabking)
        else
            newboatbumpercrabking.Transform:SetPosition(inst.Transform:GetWorldPosition())
        end
        inst:Remove()
    end)

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("crabking_kit2hm", fn, assets)