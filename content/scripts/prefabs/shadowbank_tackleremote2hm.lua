local function fn()
    local inst = CreateEntity()
    if TheWorld.ismastersim then inst.entity:AddTransform() end
    inst.entity:AddNetwork()
    inst.entity:AddServerNonSleepable()
    inst.entity:SetCanSleep(false)
    inst.entity:Hide()
    inst:AddTag("CLASSIFIED")
    inst:AddTag("pocketdimension_container")
    inst:AddTag("shadowbankremote2hm")
    inst:AddTag("shadowbanktackleremote2hm")
    inst:AddTag("irreplaceable")
    inst:AddTag("spoiler")
    inst.entity:SetPristine()
    inst.persists = false
    if not TheWorld.ismastersim then
        inst.OnEntityReplicated = function(inst)
            if inst.replica.container then inst.replica.container:WidgetSetup("tacklestation2hm") end
        end
        return inst
    end
    inst.Network:SetClassifiedTarget(inst)
    inst:AddComponent("container")
    local container = inst.components.container
    local data = {}
    for k, v in pairs(require("containers").params.tacklestation2hm) do data[k] = v end
    data.itemtestfn = function() return false end
    data.openlimit = 1
    container:WidgetSetup("tacklestation2hm", data)
    container.skipopensnd = true
    container.skipclosesnd = true
    container.skipautoclose = true
    return inst
end

return Prefab("shadowbank_tackleremote2hm", fn, {Asset("ANIM", "anim/ui_fish_box_5x4.zip")})
