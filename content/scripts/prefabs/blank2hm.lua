
-- local function on_msg_dirty(inst)
--     if TheWorld.ismastersim then return end
--     TUNING.msg = inst.msg:value() -- 将地图种子存到客户端TUNING中
--     print("#####222TUNING.msg", TUNING.msg)
-- end

local function fn()
    local inst = CreateEntity()
    inst.entity:AddNetwork()
    inst.entity:Hide()
    -- 服务器客户端都会创建inst.msg。第二个参数填什么都行，填temp.msg22也行
    -- inst.msg = net_string(inst.GUID, "blank2hm.msg", "on_msg_dirty")
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        -- inst:ListenForEvent("on_msg_dirty", on_msg_dirty) -- 仅客户端监听
        return inst
    end
    inst.persists = false -- 不持久化?
    return inst
end

return Prefab("blank2hm", fn) -- 2025.6.8 melon:空白prefab，用于给客户端同步信息
-- 同步方法:取消上面的注释，创建blank2hm，服务器inst.msg:set()，客户端即可触发on_msg_dirty事件