function A.backpack_lock()
    local p=A.player(1)
    local rpc=GetModRPCHandler("MOD_HARDMODE","lockbtn2hm")
    local rows={}
    for _,prefab in ipairs({"backpack","piggyback","krampus_sack","icepack","seedpouch","spicepack"}) do
        local bag=SpawnPrefab(prefab)
        local c=bag and bag.components.container
        if c then
            local gold=SpawnPrefab("goldnugget")
            c:GiveItem(gold,1)
            rpc(p,bag)
            local locked=c.itemtestfnprefabs2hm~=nil
            rpc(p,bag)
            rows[#rows+1]={prefab=prefab,locked=locked,unlocked=c.itemtestfnprefabs2hm==nil,
                tag=bag:HasTag("lockcontainer2hm"),specific=c.usespecificslotsforitems}
            if gold:IsValid() and not gold.components.inventoryitem.owner then gold:Remove() end
            c:DestroyContents();bag:Remove()
        end
    end
    emit({kind="backpack_lock",rows=rows})
end
