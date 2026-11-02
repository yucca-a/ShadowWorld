require "prefabutil"

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddNetwork()

    inst:AddTag("NOCLICK")
    inst:AddTag("notarget")
    inst:AddTag("FX")
    inst:AddTag("magician_private2hm")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        inst.OnEntityReplicated = function(inst)
            if inst.replica.container ~= nil then
                inst.replica.container:WidgetSetup("magician_private2hm")
            end
        end
        return inst
    end

    inst:AddComponent("container")
    inst.components.container:WidgetSetup("magician_private2hm")
    inst.components.container.droponopen = false
    inst.components.container.skipautoclose = true
    inst.persists = false

    return inst
end

return Prefab("magician_private_container2hm", fn, {
    Asset("ANIM", "anim/ui_fish_box_5x4.zip")
})
