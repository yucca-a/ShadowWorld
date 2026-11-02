local assets =
{
    Asset("ANIM", "anim/spider_cocoon.zip"),
    Asset("ANIM", "anim/ui_chest_3x3.zip"),
}

local prefabs = {}

-- 蜘蛛窝:蜘蛛在其中缓慢恢复新鲜度
local RESTORE_TIME = 10
local RESTORE_AMOUNT = 0.01

local function RestoreSpiders(inst)
    for k, v in pairs(inst.components.container.slots) do
        if v and v:IsValid() and v:HasTag("spider") and v.components.perishable then
            local percent = v.components.perishable:GetPercent()
            if percent < 1 then v.components.perishable:SetPercent(math.min(1, percent + RESTORE_AMOUNT)) end
        end
    end
end

-- 注意:SetPersistData 恢复物品不触发 itemget/itemlose 事件(硬规则#15),
-- 因此恢复任务无条件启动(空容器空转成本极低),保证重进游戏后也能恢复新鲜度。
local function ItemGet(inst)
    if inst.RestoreTask == nil then
        inst.RestoreTask = inst:DoPeriodicTask(RESTORE_TIME, RestoreSpiders)
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()
    inst.AnimState:SetBank("spider_cocoon")
    inst.AnimState:SetBuild("spider_cocoon")
    inst.AnimState:PlayAnimation("cocoon_small")

    inst:SetPrefabNameOverride("spiderden")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then return inst end

    inst:AddComponent("container")
    inst.components.container:WidgetSetup("spiderbag2hm")
    inst.components.container.skipclosesnd = true
    inst.components.container.skipopensnd = true
    ItemGet(inst)

    return inst
end

--------------------------------------------------------------------------

return Prefab("spiderbag2hm", fn, assets, prefabs)
