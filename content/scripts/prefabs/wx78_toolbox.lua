--2025.11.2夜风wx-78虚拟芯片容器
require "prefabutil"

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddNetwork()
    
    -- 虚拟容器标签
    inst:AddTag("NOCLICK")
    inst:AddTag("notarget")
    inst:AddTag("FX")
    inst:AddTag("wx78_special_container")  -- 2025.11.8 夜风防止被其他容器代码干扰
    
    inst.entity:SetPristine()
    
    if not TheWorld.ismastersim then
        -- 客户端设置容器UI
        inst.OnEntityReplicated = function(inst)
            inst.replica.container:WidgetSetup("wx78_toolbox")
        end
        return inst
    end
    
    -- 服务端：添加容器组件
    inst:AddComponent("container")
    inst.components.container:WidgetSetup("wx78_toolbox")
    inst.components.container.droponopen = false
    inst.components.container.skipautoclose = true
    inst.persists = false  -- 使用手动序列化
    
    return inst
end

return Prefab("wx78_toolbox", fn, {
    Asset("ANIM", "anim/ui_tacklecontainer_3x2.zip")
})
