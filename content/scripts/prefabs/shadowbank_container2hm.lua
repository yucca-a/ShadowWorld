local function ontarget(inst, data)
    local container = inst.components.container
    if container.opencount > 1 then inst.Network:SetClassifiedTarget(nil)
    elseif container.opencount == 1 then
        local opener = data and container.openlist[data.doer] and data.doer or next(container.openlist)
        inst.Network:SetClassifiedTarget(opener)
    else inst.Network:SetClassifiedTarget(inst) end
end

local function fn()
    local inst = CreateEntity()
    if TheWorld.ismastersim then inst.entity:AddTransform() end
    inst.entity:AddNetwork()
    inst.entity:AddServerNonSleepable()
    inst.entity:SetCanSleep(false)
    inst.entity:Hide()
    inst:AddTag("CLASSIFIED")
    inst:AddTag("pocketdimension_container")
    inst:AddTag("irreplaceable")
    inst:AddTag("spoiler")
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        inst.OnEntityReplicated = function(inst)
            if inst.replica.container then inst.replica.container:WidgetSetup("shadow_container") end
        end
        return inst
    end
    inst.Network:SetClassifiedTarget(inst)
    inst:AddComponent("container")
    inst.components.container:WidgetSetup("shadow_container")
    inst.components.container.skipclosesnd = true
    inst.components.container.skipopensnd = true
    inst.components.container.skipautoclose = true
    inst.components.container.onanyopenfn = ontarget
    inst.components.container.onanyclosefn = ontarget
    TheWorld.shadowbanksecond2hm = inst
    return inst
end

return Prefab("shadowbank_container2hm", fn, {Asset("ANIM", "anim/ui_portal_shadow_3x4.zip")})
