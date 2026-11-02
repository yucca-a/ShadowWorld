require "prefabutil"

local assets = {Asset("ANIM", "anim/bookstation.zip"), Asset("ANIM", "anim/ui_bookstation_4x5.zip")}

local prefabs = {}
local function RestoreBooks(inst)
    local wicker_bonus = 1
    local x, y, z = inst.Transform:GetWorldPosition()
    local players = FindPlayersInRange(x, y, z, TUNING.BOOKSTATION_BONUS_RANGE, true)
    for _, player in ipairs(players) do
        if player:HasTag("bookbuilder") then
            wicker_bonus = TUNING.BOOKSTATION_WICKER_BONUS
            break
        end
    end
    for k, v in pairs(inst.components.container.slots) do
        if v and v:HasTag("book") and not v:HasTag("dailybook2hm") and v.components.finiteuses then
            local percent = v.components.finiteuses:GetPercent()
            if percent < 1 then v.components.finiteuses:SetPercent(math.min(1, percent + (TUNING.BOOKSTATION_RESTORE_AMOUNT * wicker_bonus))) end
        end
    end
end

local function ItemGet(inst)
    if inst.RestoreTask == nil then
        if inst.components.container:HasItemWithTag("book", 1) then inst.RestoreTask = inst:DoPeriodicTask(TUNING.BOOKSTATION_RESTORE_TIME, RestoreBooks) end
    end
end

local function ItemLose(inst)
    if not inst.components.container:HasItemWithTag("book", 1) then
        if inst.RestoreTask ~= nil then
            inst.RestoreTask:Cancel()
            inst.RestoreTask = nil
        end
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()
    inst.AnimState:SetBank("bookstation")
    inst.AnimState:SetBuild("bookstation")
    inst.AnimState:PlayAnimation("idle")

    inst:SetPrefabNameOverride("bookstation")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then return inst end

    inst:AddComponent("inspectable")

    inst:AddComponent("container")
    inst.components.container:WidgetSetup("bookstation2hm")
    inst.components.container.skipclosesnd = true
    inst.components.container.skipopensnd = true
    inst:ListenForEvent("itemget", ItemGet)
    inst:ListenForEvent("itemlose", ItemLose)

    return inst
end

--------------------------------------------------------------------------

return Prefab("bookstation2hm", fn, assets, prefabs)
