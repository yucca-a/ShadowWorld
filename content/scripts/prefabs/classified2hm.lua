local function OnRemoveEntity(inst)
    if inst.setuserid then
        -- print("remove setuserid", inst, inst.setuserid)
        TUNING.util2hm.classified2hm_list[inst.setuserid] = nil
    end
end

local function on_userid_dirty(inst)
    -- print("on_userid_dirty", TheWorld.ismastersim, inst.userid:value(), inst)
    if TheWorld.ismastersim then return end
    inst.setuserid = inst.userid:value()
    TUNING.util2hm.classified2hm_list[inst.setuserid] = inst
    -- print("setuserid", inst, inst.setuserid)
end

local function fn()
    local inst = CreateEntity()

    -- inst.entity:AddTransform()
    inst.entity:AddNetwork()
    inst.entity:Hide()
    -- inst:AddTag("CLASSIFIED")

    inst.userid = net_string(inst.GUID, "classified2hm.userid", "on_userid_dirty")
    inst.take_cursed_item_num = net_bool(inst.GUID, "classified2hm.take_cursed_item_num")
    inst.take_cursed_item_num:set_local(false)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        inst:ListenForEvent("on_userid_dirty", on_userid_dirty)
        inst.OnRemoveEntity = OnRemoveEntity
        return inst
    end

    inst.persists = false

    return inst
end

return Prefab("classified2hm", fn)
