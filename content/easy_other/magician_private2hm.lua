local PRIVATE_PREFAB2HM = "magician_private_container2hm"
local UPGRADED_TAG2HM = "magicianupgraded2hm"


local containers = require("containers")
containers.params.magician_private2hm = {
    widget = {slotpos = {}, animbank = "ui_fish_box_5x4", animbuild = "ui_fish_box_5x4", pos = Vector3(0, 220, 0), side_align_tip = 160},
    type = "magician_private2hm"
}
for y = 2.5, -0.5, -1 do
    for x = -1, 3 do
        table.insert(containers.params.magician_private2hm.widget.slotpos, Vector3(75 * x - 75 * 2 + 75, 75 * y - 75 * 2 + 75, 0))
    end
end

TUNING.util2hm.magicianprivate2hm_cache = TUNING.util2hm.magicianprivate2hm_cache or {}

AddComponentPostInit("magiciantool", function(self)
    local OnStartUsing = self.OnStartUsing
    self.OnStartUsing = function(self, doer, ...)
        if TheWorld.ismastersim and doer ~= nil and doer:IsValid() and doer.magicianhatupgraded2hm ~= nil then
            local hat = self.inst
            doer.magicianhatupgraded2hm:set(hat ~= nil and hat:HasTag(UPGRADED_TAG2HM) or false)
        end
        if OnStartUsing ~= nil then return OnStartUsing(self, doer, ...) end
    end

    local OnStopUsing = self.OnStopUsing
    self.OnStopUsing = function(self, doer, ...)
        if TheWorld.ismastersim and doer ~= nil and doer:IsValid() then
            local c = doer.magicianprivatecontainer2hm
            if c ~= nil and c:IsValid() and c.components.container ~= nil and c.components.container:IsOpenedBy(doer) then
                c.components.container:Close(doer)
            end
        end
        if OnStopUsing ~= nil then return OnStopUsing(self, doer, ...) end
    end
end)

local function GetPrivateContainer2hm(inst)
    if inst ~= nil and inst.magicianprivatecontainer2hm ~= nil and inst.magicianprivatecontainer2hm:IsValid() then
        return inst.magicianprivatecontainer2hm
    end
end

local function CachePrivateContainer2hm(inst)
    if inst == nil or inst.userid == nil or inst.userid == "" then return end
    local container = GetPrivateContainer2hm(inst)
    if container == nil then return end
    local data = container:GetPersistData()
    if data ~= nil and not IsTableEmpty(data) then
        TUNING.util2hm.magicianprivate2hm_cache[inst.userid] = data
    end
end

local function InitPrivateContainer2hm(inst, force)
    if inst == nil or not inst:IsValid() then return end
    local exist = GetPrivateContainer2hm(inst)
    if exist ~= nil then return exist end

    local saved
    if inst.components.persistent2hm ~= nil then
        saved = inst.components.persistent2hm.data.magicianprivatecontainer2hm
    end
    if saved == nil and inst.userid ~= nil and inst.userid ~= "" then
        saved = TUNING.util2hm.magicianprivate2hm_cache[inst.userid]
    end
    if not force and saved == nil then return end

    local container = SpawnPrefab(PRIVATE_PREFAB2HM)
    if container == nil or not container:IsValid() or container.components.container == nil then return end

    if saved ~= nil then
        container:SetPersistData(saved)
        if inst.components.persistent2hm ~= nil then
            inst.components.persistent2hm.data.magicianprivatecontainer2hm = nil
        end
    end

    container:AddTag("NOBLOCK")
    container:Hide()
    container.persists = false
    container.master2hm = inst
    inst.magicianprivatecontainer2hm = container
    inst:AddChild(container)

    return container
end

AddPlayerPostInit(function(inst)
    inst.magicianhatupgraded2hm = net_bool(inst.GUID, "player.magicianhatupgraded2hm", "magicianhatupgradeddirty2hm")

    if not TheWorld.ismastersim then return end
    if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end

    local OnPreLoad, OnLoad = inst.OnPreLoad, inst.OnLoad
    local restoringtool = false
    inst.OnPreLoad = function(player, data, ...)
        -- 非老麦的魔术能力在下一帧恢复；先接住旧存档里仍由 magician 保管的帽子。
        if data and data.magician and data.magician.item and not player.components.magician then
            player:AddComponent("magician")
            restoringtool = true
        end
        if OnPreLoad then return OnPreLoad(player, data, ...) end
    end
    inst.OnLoad = function(player, data, ...)
        if OnLoad then OnLoad(player, data, ...) end
        -- 与老麦原生读档一致，库存加载完成后归还帽子，不恢复临时打开的界面。
        if player.components.magician then player.components.magician:StopUsing() end
        if restoringtool then
            restoringtool = false
            -- 临时组件只负责找回物品，魔术能力仍由原有角色/兑换逻辑恢复。
            player:RemoveComponent("magician")
        end
    end

    SetOnSave2hm(inst, function(i, data)
        local container = GetPrivateContainer2hm(i)
        if container ~= nil then
            local persistdata, refs = container:GetPersistData()
            if persistdata ~= nil and not IsTableEmpty(persistdata) then
                data.magicianprivatecontainer2hm = persistdata
            end
            return refs
        end
    end)

    SetOnLoad2hm(inst, function(i, data)
        i:DoTaskInTime(0, InitPrivateContainer2hm)
    end)

    inst:ListenForEvent("ms_playerreroll", CachePrivateContainer2hm)
    inst:ListenForEvent("onremove", CachePrivateContainer2hm)

    inst:DoTaskInTime(0, InitPrivateContainer2hm)
end)

AddPrefabPostInit("world", function(inst)
    if not inst.ismastersim then return end
    inst:ListenForEvent("ms_seamlesscharacterspawned", function(world, player)
        if player ~= nil and player:IsValid() then
            player:DoTaskInTime(0, InitPrivateContainer2hm)
        end
    end)
end)


local function OpenPrivateSpace2hm(player, inst)
    if not TheWorld.ismastersim then return end
    if player == nil or not player:IsValid() then return end
    if not player:HasTag("magician") then return end
    if not player:HasTag("usingmagiciantool") then
        if player.components.talker ~= nil then
            player.components.talker:Say(TUNING.isCh2hm and "只有正在使用附身的魔术师帽子时才能打开私人空间" or
                "Only while using the possessed magician's top hat can the private space be opened")
        end
        return
    end
    if not TUNING.util2hm.CanUseMagicianPrivate2hm(player) then
        if player.components.talker ~= nil then
            player.components.talker:Say(TUNING.isCh2hm and "只有附身的魔术师帽子才能打开私人空间" or
                "Only the possessed magician's top hat can open the private space")
        end
        return
    end

    local container = InitPrivateContainer2hm(player, true)
    if container == nil or not container:IsValid() or container.components.container == nil then
        if player.components.talker ~= nil then
            player.components.talker:Say(TUNING.isCh2hm and "私人空间打开失败" or "Failed to open the private space")
        end
        return
    end

    if container.components.container:IsOpenedBy(player) then
        container.components.container:Close(player)
    end
    container.components.container:Open(player)
    if player.components.talker ~= nil then
        player.components.talker:Say(TUNING.isCh2hm and "穿越到我自己的世界了" or "I've crossed into my own world")
    end
end

AddModRPCHandler("MOD_HARDMODE", "magicianprivatespace2hm", OpenPrivateSpace2hm)

TUNING.util2hm.OpenMagicianPrivate2hm = function(inst, doer)
    if doer == nil then return end
    if TheWorld.ismastersim then
        OpenPrivateSpace2hm(doer, inst)
    else
        SendModRPCToServer(GetModRPC("MOD_HARDMODE", "magicianprivatespace2hm"), inst)
    end
end

TUNING.util2hm.CanUseMagicianPrivate2hm = function(doer)
    return doer ~= nil and doer.magicianhatupgraded2hm ~= nil and doer.magicianhatupgraded2hm:value()
end

local function MakeHatRepairMaterials2hm(hat)
    return setmetatable({}, {
        __index = function(_, key)
            if not hat:HasTag("magiciantool") then return nil end
            if hat:HasTag(UPGRADED_TAG2HM) then return nil end
            return key == "shadowheart_infused" and 1 or nil
        end,
    })
end

local function ApplyMagicianHatUpgrade2hm(hat)
    if hat == nil or not hat:IsValid() or hat:HasTag(UPGRADED_TAG2HM) then return end
    hat:AddTag(UPGRADED_TAG2HM)
end

AddPrefabPostInit("tophat", function(inst)
    inst.repairmaterials2hm = MakeHatRepairMaterials2hm(inst)
    inst.repairtext2hm = "UPGRADE"
    local oldname = inst.displaynamefn
    inst.displaynamefn = function(i)
        if i:HasTag(UPGRADED_TAG2HM) then
            return (TUNING.isCh2hm and "附身的魔术师帽子") or "Possessed Magician's Top Hat"
        end
        return oldname ~= nil and oldname(i) or nil
    end

    if not TheWorld.ismastersim then return end

    inst:AddComponent("persistent2hm")
    inst:AddComponent("repairable2hm")
    inst.components.repairable2hm.ignoremax = true
    inst.components.repairable2hm.customrepair = function(hat, repairuse, doer, repair_item)
        if repair_item == nil or not repair_item:IsValid() then return false end
        if repair_item.prefab ~= "shadowheart_infused" then return false end
        if not hat:HasTag("magiciantool") then return false end
        if hat:HasTag(UPGRADED_TAG2HM) then return false end
        if doer == nil or not doer:IsValid() then return false end

        if repair_item.components.stackable ~= nil then
            repair_item.components.stackable:Get(1):Remove()
        else
            repair_item:Remove()
        end

        ApplyMagicianHatUpgrade2hm(hat)

        if doer.components.talker ~= nil then
            doer.components.talker:Say(TUNING.isCh2hm and "成功附魔" or
                "success")
        end
        return true
    end

    SetOnSave2hm(inst, function(i, data) data.magicianhatupgraded2hm = i:HasTag(UPGRADED_TAG2HM) or nil end)
    SetOnLoad2hm(inst, function(i, data)
        if data ~= nil and data.magicianhatupgraded2hm then ApplyMagicianHatUpgrade2hm(i) end
    end)
end)
