-- Xianyu inventories and transfer receipts share the ordinary world snapshot.
-- Move real entities locally; retain overflow in its referenced source container.
local Recovery={}
local function valid(e)return e and e:IsValid() and e.components.container end
function Recovery.Available(c)
    local e=c and c.inst
    return e and not c.readonlycontainer and not e.dcs2hm and
        not e:HasTag("exchangeloading2hm") and not e.containersendtask2hm and
        not e.containerreceivetask2hm and not e.exchangeconfirmtask2hm
end
function Recovery.Slot(c,item)
    if not Recovery.Available(c) then return end
    -- An explicit empty slot avoids stack merging/splitting and preserves the
    -- individual entity, including nested inventories, references and skins.
    if item.components.stackable and item.components.stackable:StackSize()>1 and not c.acceptsstacks then return end
    for slot=1,c.numslots do
        if not c.slots[slot] and c:CanTakeItemInSlot(item,slot) then return slot end
    end
end
local function internal(c,fn)
    local readonly,overstacked,previous=c.readonlycontainer,c.ignoreoverstacked,c.worldexchange_internal2hm
    c:EnableReadOnlyContainer(false)
    c.ignoreoverstacked=true;c.worldexchange_internal2hm=true
    local ok,result=pcall(fn)
    c.ignoreoverstacked=overstacked;c.worldexchange_internal2hm=previous
    c:EnableReadOnlyContainer(readonly==true)
    if not ok then error(result) end
    return result
end
function Recovery.Put(c,item,slot)
    return internal(c,function()return c:GiveItem(item,slot,nil,false) and c.slots[slot]==item end)
end
function Recovery.Move(source,target)
    if source==target or not valid(source) or not valid(target) then return end
    local from,to=source.components.container,target.components.container
    if not Recovery.Available(to) or source:HasTag("exchangeloading2hm") then return end
    for slot=1,from.numslots do
        local item=from.slots[slot]
        local destination=item and Recovery.Slot(to,item)
        if destination then
            local taken=internal(from,function()return from:RemoveItemBySlot(slot,true)end)
            if taken and not Recovery.Put(to,taken,destination) then
                assert(Recovery.Put(from,taken,slot),"Xianyu recovery could not restore source slot")
            end
        end
    end
end
function Recovery.Drain(variants)
    if variants.mode~="classic" or not variants.xianyu_restore then return end
    local active=variants.banks.classic or {}
    for family,source in pairs(variants.banks.xianyu or {})do Recovery.Move(source,active[family]) end
    Recovery.Move(variants.second,active.shadow)
    Recovery.Move(variants.tacklesecond,active.tacklestation2hm)
end
function Recovery.Imports(service)
    for index=#service.imports,1,-1 do
        local entry=service.imports[index]
        local bank=entry.bank or 2
        local family=(bank==3 or bank==4) and "tacklestation2hm" or "shadow"
        local base=service.inst:GetPocketDimensionContainer(family)
        local c=valid(base) and base.components.container
        -- Keep the original record if its family is disabled, full or busy.
        local empty=false
        if Recovery.Available(c) then
            for slot=1,c.numslots do if not c.slots[slot] then empty=true;break end end
        end
        if empty then
            local item=SpawnSaveRecord(entry.record or entry)
            if item then
                local slot=Recovery.Slot(c,item)
                if slot and Recovery.Put(c,item,slot) then table.remove(service.imports,index)
                elseif item:IsValid() then item:Remove() end
            end
        end
    end
end
return Recovery
