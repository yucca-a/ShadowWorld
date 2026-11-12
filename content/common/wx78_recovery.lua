-- Compatibility only: no old circuit bonuses, actions, or permanent stats.
local function GiveOrDrop(owner, item, origin)
    -- Native module-removal callbacks may already have returned the item.
    if item.components.inventoryitem and item.components.inventoryitem.owner then return end
    local x, y, z = origin.Transform:GetWorldPosition()
    item.Transform:SetPosition(x, y, z)
    if owner and owner.components.inventory then owner.components.inventory:GiveItem(item) end
    -- GiveItem drops an item at its position if the inventory is full.
end

local function RefundModules(inst)
    local count = inst.wx78refund2hm or 0
    if count <= 0 then return end
    local module = inst.components.upgrademodule
    local owner = module and module.target
    if not owner and inst.components.inventoryitem then owner = inst.components.inventoryitem:GetGrandOwner() end
    local origin = owner or inst
    while count > 0 do
        local item = SpawnPrefab(inst.prefab, inst.skinname, inst.skin_id)
        if not item then break end
        if item.components.finiteuses and inst.components.finiteuses then
            item.components.finiteuses:SetPercent(inst.components.finiteuses:GetPercent())
        end
        if item.components.fueled and inst.components.fueled then
            item.components.fueled:SetPercent(inst.components.fueled:GetPercent())
        end
        GiveOrDrop(owner, item, origin)
        count = count - 1
        inst.wx78refund2hm = count
    end
    if count > 0 then inst:DoTaskInTime(1, RefundModules) end
end

for _, def in ipairs(require("wx78_moduledefs").module_definitions) do
    AddPrefabPostInit("wx78module_" .. def.name, function(inst)
        if not TheWorld.ismastersim then return end
        local save, load = inst.OnSave, inst.OnLoad
        inst.OnSave = function(inst, data, ...)
            local refs = save and save(inst, data, ...)
            data.wx78refund2hm = inst.wx78refund2hm
            return refs
        end
        inst.OnLoad = function(inst, data, ...)
            if load then load(inst, data, ...) end
            if data then
                inst.wx78refund2hm = math.max(0, math.floor(tonumber(data.wx78refund2hm) or 0))
                if TUNING.wx78recoverfusion2hm then
                    inst.wx78refund2hm = inst.wx78refund2hm + math.max(0, math.floor(tonumber(data.level) or 1) - 1)
                end
                if inst.wx78refund2hm > 0 then inst:DoTaskInTime(0, RefundModules) end
            end
        end
    end)
end

if TUNING.wx78recoverbox2hm then
    local containers = require("containers")
    local slots = {}
    for y = 0, 2 do
        for x = 0, 2 do table.insert(slots, Vector3(80 * x - 80, 80 * y - 80, 0)) end
    end
    containers.params.wx78_toolbox = containers.params.wx78_toolbox or {
        widget = {slotpos = slots, animbank = "ui_chest_3x3", animbuild = "ui_chest_3x3", pos = Vector3(0, 200, 0)},
        type = "chest",
    }
end

local function RecoverBox(inst)
    local persistent = inst.components.persistent2hm
    local saved = persistent and persistent.data.wx78_toolbox
    if not saved then return end
    local items = saved.container and saved.container.items
    if not items then return end
    -- Consume records individually. A temporarily unavailable prefab remains
    -- saved, rather than being discarded by Container:OnLoad's skip behavior.
    for slot, record in pairs(items) do
        local item = SpawnSaveRecord(record)
        if item then
            GiveOrDrop(inst, item, inst)
            items[slot] = nil
        end
    end
    if next(items) == nil then
        persistent.data.wx78_toolbox = nil
    else
        inst:DoTaskInTime(1, RecoverBox)
    end
end

local function NormalizeSlots(inst)
    local owner = inst.components.upgrademoduleowner
    if not owner then return end
    for bar, modules in pairs(owner.module_bars) do
        local used, index = 0, 1
        while modules[index] do
            local slots = modules[index].components.upgrademodule:GetSlots()
            if used + slots > owner:GetMaxChargeLevel() then
                -- PopModule detaches without unplug durability/charge costs.
                local item = owner:PopModule(bar, index)
                GiveOrDrop(inst, item, inst)
            else
                used, index = used + slots, index + 1
            end
        end
    end
    owner:SetChargeLevel(owner:GetChargeLevel())
end

local recoverScanner = TUNING.wx78mode2hm == "draft" or TUNING.wx78mode2hm == "off" or
    (TUNING.wx78mode2hm ~= "legacy" and not GetModConfigData("WX-78 Safe Remove Module"))
local function RecoverScanner(inst)
    local record = inst.wx78recoveryscanner2hm
    if not record then return end
    local scanner = SpawnSaveRecord(record)
    if scanner then
        scanner.Transform:SetPosition(inst.Transform:GetWorldPosition())
        inst.components.leader:AddFollower(scanner)
        inst.wx78recoveryscanner2hm = nil
    else
        inst:DoTaskInTime(1, RecoverScanner)
    end
end

for _, prefab in ipairs({"wx78", "wx78_backupbody", "wx78_possessedbody"}) do
    AddPrefabPostInit(prefab, function(inst)
        if not TheWorld.ismastersim then return end
        if prefab == "wx78" and TUNING.wx78recoverbox2hm and not inst.components.persistent2hm then
            inst:AddComponent("persistent2hm")
        end
        local save, load = inst.OnSave, inst.OnLoad
        inst.OnSave = function(inst, data, ...)
            local refs = save and save(inst, data, ...)
            data.wx78nutrition2hm = inst.wx78nutrition2hm
            if recoverScanner and prefab == "wx78" then data.wx78_scanner_save2hm = inst.wx78recoveryscanner2hm end
            return refs
        end
        inst.OnLoad = function(inst, data, ...)
            if load then load(inst, data, ...) end
            if recoverScanner and prefab == "wx78" and data and data.wx78_scanner_save2hm then
                inst.wx78recoveryscanner2hm = data.wx78_scanner_save2hm
                inst:DoTaskInTime(.1, RecoverScanner)
            end
            inst.wx78nutrition2hm = math.clamp(tonumber(data and data.wx78nutrition2hm) or 0, 0, 44.999999)
            local owner = inst.components.upgrademoduleowner
            if TUNING.wx78mode2hm == "draft" and owner and owner:GetChargeLevel() >= owner:GetMaxChargeLevel() then
                inst.wx78nutrition2hm = 0
            end
            if TUNING.wx78mode2hm == "draft" or TUNING.wx78mode2hm == "off" then
                -- Maxima were rebuilt by native circuit activation; don't carry
                -- over old gear/fusion absolute values above the new maxima.
                if inst.components.health then
                    local health = inst.components.health
                    health:SetCurrentHealth(math.min(health.currenthealth, health:GetMaxWithPenalty()))
                end
                if inst.components.hunger then
                    inst.components.hunger.current = math.min(inst.components.hunger.current, inst.components.hunger.max)
                end
                if inst.components.sanity then
                    inst.components.sanity.current = math.min(inst.components.sanity.current, inst.components.sanity:GetMaxWithPenalty())
                end
            end
        end
        if prefab == "wx78" and TUNING.wx78recoverbox2hm then inst:DoTaskInTime(0, RecoverBox) end
        if TUNING.wx78recoverfusion2hm then inst:DoTaskInTime(.1, NormalizeSlots) end
    end)
end
