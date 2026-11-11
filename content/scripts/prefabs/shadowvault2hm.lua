-- Legacy saved pages and transfer custody; new pages use their native prefabs.
local function OnOpen(inst, data)
    if inst.components.container.opencount > 1 then inst.Network:SetClassifiedTarget(nil)
    else inst.Network:SetClassifiedTarget(data.doer) end
end
local function OnClose(inst)
    local c = inst.components.container
    if c.opencount == 0 then inst.Network:SetClassifiedTarget(inst)
    elseif c.opencount == 1 then inst.Network:SetClassifiedTarget(next(c.openlist)) end
end
local function Container(widget, single, spoiler)
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddNetwork()
    inst.entity:AddServerNonSleepable()
    inst.entity:SetCanSleep(false)
    inst.entity:Hide()
    inst:AddTag("CLASSIFIED")
    inst:AddTag("irreplaceable")
    inst:AddTag("shadowvault_container2hm")
    if not single then inst:AddTag("pocketdimension_container") end
    if spoiler then inst:AddTag("spoiler") end
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end
    inst.Network:SetClassifiedTarget(inst)
    inst:AddComponent("container")
    local c = inst.components.container
    c:WidgetSetup(widget)
    c.skipclosesnd, c.skipopensnd, c.skipautoclose = true, true, true
    c.onanyopenfn, c.onanyclosefn = OnOpen, OnClose
    return inst
end
local function Access()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddNetwork()
    inst.entity:Hide()
    inst:AddTag("NOCLICK")
    inst:AddTag("shadowvault_access2hm")
    inst:AddComponent("container_proxy")
    inst.entity:SetPristine()
    inst.persists = false
    return inst
end
return Prefab("shadowvaultpage2hm", function() return Container("shadow_container", false, true) end,
        {Asset("ANIM", "anim/ui_portal_shadow_3x4.zip")}),
    Prefab("shadowvaulttacklepage2hm", function() return Container("shadowvaulttacklepage2hm") end,
        {Asset("ANIM", "anim/ui_fish_box_5x4.zip")}),
    Prefab("shadowvaulttransfer2hm", function() return Container("shadowvaulttransfer2hm", true) end),
    Prefab("shadowvaultaccess2hm", Access),
    Prefab("shadowvaultpair2hm", function() return Container("shadowvaultpair2hm", true) end)
