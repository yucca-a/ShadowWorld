function A.compat_blocked()
    local v=service();local p=A.player(1);local c=A.bank(2)
    local outcomes={}
    for _,kind in ipairs({"references","save_error","irreplaceable","nested_reference"})do
        local e=SpawnPrefab(kind=="nested_reference"and"backpack"or"rocks")
        local target=e
        if kind=="nested_reference"then target=SpawnPrefab("rocks");e.components.container:GiveItem(target,1)end
        local save=target.GetSaveRecord
        if kind=="save_error"then target.GetSaveRecord=function()error("audit unsupported save")end
        elseif kind=="irreplaceable"then e:AddTag("irreplaceable")
        else target.GetSaveRecord=function(...)local record=save(...);return record,{987654321}end end
        assert(p.components.inventory:GiveItem(e),"original bag custody")
        local before=e.components.inventoryitem.owner
        local allowed=c:CanTakeItemInSlot(e,12)
        local ok=not allowed and e:IsValid()and e.components.inventoryitem.owner==before and not v.error
        outcomes[kind]=ok
        target.GetSaveRecord=save;e:Remove()
    end
    emit({kind="compat_blocked",outcomes=outcomes})
end
function A.compat_refresh()
    local results={}
    for _,prefab in ipairs({"nightsword","glasscutter"})do
        local escrow=SpawnPrefab("shadowvaulttransfer2hm");local c=escrow.components.container
        local e=SpawnPrefab(prefab)
        assert(c:GiveItem(e,1))
        c:EnableReadOnlyContainer(true)
        local id=e.GUID
        for i=1,6 do require("weaponinfusionview2hm").Refresh(e)end
        results[prefab]={valid=e:IsValid(),same=c.slots[1]==e and e.GUID==id,readonly=c.readonlycontainer}
        e:Remove();escrow:Remove()
    end
    emit({kind="compat_refresh",results=results})
end
function A.compat_gift()
    local gift=SpawnPrefab("gift");gift.components.vaultauditmark.token="gift"
    local gold=SpawnPrefab("goldnugget");gold.components.stackable:SetStackSize(23)
    local weapon=SpawnPrefab("medal_tentaclespike");weapon.components.finiteuses:SetUses(31)
    gift.components.unwrappable:WrapItems({gold,weapon},A.player(1));gold:Remove();weapon:Remove()
    assert(A.bank(2):GiveItem(gift,6),"wrapped mod item accepted")
    emit({kind="compat_gift"})
end
function A.compat_transient()
    local v=service();local e=A.bank(2).slots[1]
    assert(e,"saved item for capture retry")
    local save=e.GetSaveRecord;local guid=e.GUID
    e.GetSaveRecord=function(...)local record=save(...);return record,{987654321}end
    v.native.checkpoint_epochs={};v.journal:Flush()
    assert(v.error=="linked_items","capture was protected")
    e.GetSaveRecord=save
    TheWorld:DoStaticTaskInTime(12,function()
        emit({kind="compat_recovered",valid=e:IsValid(),same=A.bank(2).slots[1]==e and e.GUID==guid,
            error=v.error,journal_error=v.journal.error})
    end)
    emit({kind="compat_transient"})
end
