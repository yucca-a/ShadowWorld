-- Updating an infusion meter must never move, unequip or destroy its item.
local View={}
local EVENT="weaponinfusionviewdirty2hm"
function View.Install(inst)
    inst.weaponinfusionview2hm=net_bool(inst.GUID,"weapon.infusionview2hm",EVENT)
    inst.weaponinfusionview2hm:set(true)
end
function View.Refresh(inst)
    inst.resetviewtask2hm=nil
    if not inst:IsValid() then return end
    if inst.weaponinfusionview2hm then
        inst.weaponinfusionview2hm:set(inst.components.perishable~=nil)
    end
    local inventoryitem=inst.replica.inventoryitem
    if inventoryitem and inventoryitem.classified then inventoryitem:SerializeUsage() end
    inst:PushEvent(EVENT)
end
function View.AttachTile(tile)
    local item=tile.item
    if not item or not item.weaponinfusionview2hm then return end
    local function refresh()
        local infused=item.weaponinfusionview2hm:value()
        tile.hasspoilage=infused
        if infused then
            if not tile.bg then
                tile.bg=tile:AddChild(require("widgets/image")(HUD_ATLAS,"inv_slot_spoiled.tex"))
                tile.bg:SetClickable(false);tile.bg:MoveToBack()
            end
            if not tile.spoilage then
                tile.spoilage=tile:AddChild(require("widgets/uianim")())
                local anim=tile.spoilage:GetAnimState()
                anim:SetBank("spoiled_meter");anim:SetBuild("spoiled_meter");anim:AnimateWhilePaused(false)
                tile.spoilage:SetClickable(false)
            end
            tile:ShowSpoilage()
        else tile:HideSpoilage() end
        tile:Refresh()
        -- Host Refresh prioritizes perishable; this weapon still has a separate
        -- finite-use percentage alongside its infusion meter.
        if item.components.finiteuses then tile:SetPercent(item.components.finiteuses:GetPercent()) end
    end
    tile.inst:ListenForEvent(EVENT,refresh,item)
    refresh()
end
return View
