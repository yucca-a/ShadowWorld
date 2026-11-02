local assets = {
    Asset("ANIM", "anim/cursed_beads.zip"),
    Asset("INV_IMAGE", "unknown_hand"),
    Asset("INV_IMAGE", "unknown_head"),
    Asset("INV_IMAGE", "unknown_body")
}

local function deathcurselightfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst:AddTag("FX")

    inst.Light:SetFalloff(0.4)
    inst.Light:SetIntensity(.7)
    inst.Light:SetRadius(0.5)
    inst.Light:SetColour(180 / 255, 195 / 255, 150 / 255)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then return inst end

    inst.persists = false

    return inst
end

-- 进入冷却
local function PutCurseOnCooldown(inst)
    if inst and inst.components.rechargeable and inst.components.rechargeable.IsCharged and inst.components.rechargeable:IsCharged() and inst:HasTag("curse2hm") then
        local owner = inst.components.inventoryitem.owner
        if not (owner and owner.components.inventory and owner.components.inventory:IsItemEquipped(inst)) then inst.components.rechargeable:Discharge(10) end
    end
end

-- 装备后必定进入3秒锁定时间
local function OnEquip(inst, owner)
    inst.lockowner2hm = owner
    if inst._light == nil or not inst._light:IsValid() then inst._light = SpawnPrefab("deathcurselight2hm") end
    if owner ~= nil then inst._light.entity:SetParent(owner.entity) end
    if owner.components.hunger ~= nil then
        owner.components.hunger.burnratemodifiers:SetModifier(inst, 2, "deathcurse2hm" .. inst.components.equippable.equipslot)
    end
    if inst.components.fueled ~= nil then inst.components.fueled:StartConsuming() end
    if inst.components.rechargeable then
        inst.components.rechargeable:Discharge(3)
        -- 这个属性很好，但捡背包没修好
        -- inst.components.equippable:SetPreventUnequipping(true)
    end
    if inst.task then
        inst.task:Cancel()
        inst.task = nil
    end
end

local function OnUnequipDelay(inst, owner)
    owner = owner or inst.lockowner2hm
    if owner and owner:IsValid() and owner.components.inventory and inst and inst:IsValid() then
        if owner.components.hunger ~= nil then
            owner.components.hunger.burnratemodifiers:RemoveModifier(inst, "deathcurse2hm" .. inst.components.equippable.equipslot)
        end
        if inst.components.equippable and not inst.components.equippable:IsEquipped() then
            local current = owner.components.inventory:GetEquippedItem(inst.components.equippable.equipslot)
            if current == inst then return end
            -- 已冷却完毕卸下来时,全部进入冷却,未冷却完毕卸下来时,强制回到装备
            if inst.components.inventoryitem.owner == owner and inst.components.rechargeable and inst.components.rechargeable:IsCharged() and
                owner.components.inventory.activeitem ~= inst then
                owner.components.inventory:ForEachItem(PutCurseOnCooldown)
            elseif current == nil then
                owner.components.inventory:Equip(inst)
            elseif current and current:IsValid() and current.prefab ~= inst.prefab then
                if current.components.inventoryitem ~= nil and current.components.inventoryitem.cangoincontainer then
                    local equip = owner.components.inventory:Unequip(inst.components.equippable.equipslot)
                    owner.components.inventory:Equip(inst)
                    if equip then owner.components.inventory:GiveItem(equip) end
                else
                    owner.components.inventory:DropItem(current, true, true)
                    owner.components.inventory:Equip(inst)
                end
            elseif owner.components.cursable then
                owner.components.cursable:ForceOntoOwner(inst)
            end
        end
    end
end

-- 正在冷却时,卸下来强制回到装备栏;卸下来时也进入冷却不会立即回到装备栏
local function OnUnequip(inst, owner)
    if inst._light ~= nil then
        if inst._light:IsValid() then inst._light:Remove() end
        inst._light = nil
    end
    if inst.components.fueled ~= nil then inst.components.fueled:StopConsuming() end
    if inst.task then
        inst.task:Cancel()
        inst.task = nil
    end
    if owner.components.health and owner.components.health.invincible and owner.components.health.minhealth and owner.components.health.minhealth > 0 then
        inst:DoTaskInTime(0, inst.Remove)
        return
    end
    if owner.components.inventory and owner.components.inventory:IsFull() and inst.components.rechargeable then inst.components.rechargeable:Discharge(3) end
    inst.task = inst:DoTaskInTime(FRAMES, OnUnequipDelay, owner)
end

local function OnDropped(inst)
    if inst.components.rechargeable then inst.components.rechargeable:Discharge(3) end
    OnUnequip(inst, inst.lockowner2hm or inst.components.inventoryitem.owner)
end

-- 冷却完毕时尝试回到装备栏
local function OnCharged(inst)
    -- if inst.components.equippable then inst.components.equippable:SetPreventUnequipping(false) end
    if inst.components.inventoryitem and inst.components.equippable and not inst.components.equippable:IsEquipped() then
        local owner = inst.lockowner2hm or inst.components.inventoryitem.owner
        if owner and owner:IsValid() and owner.components.inventory then
            local current = owner.components.inventory:GetEquippedItem(inst.components.equippable.equipslot)
            if current == inst then return end
            if current == nil then
                owner.components.inventory:Equip(inst)
            elseif current and current:IsValid() and current.prefab ~= inst.prefab then
                if current.components.inventoryitem ~= nil and current.components.inventoryitem.cangoincontainer then
                    local equip = owner.components.inventory:Unequip(inst.components.equippable.equipslot)
                    owner.components.inventory:Equip(inst)
                    if equip then owner.components.inventory:GiveItem(equip) end
                else
                    owner.components.inventory:DropItem(current, true, true)
                    owner.components.inventory:Equip(inst)
                end
            elseif owner.components.cursable then
                owner.components.cursable:ForceOntoOwner(inst)
            end
        end
    end
end

local function consumeItem(inst)
    if inst.components.stackable and inst.components.stackable:IsStack() then
        inst.components.stackable:SetStackSize(inst.components.stackable:StackSize() - 1)
    else
        inst:Remove()
    end
end

-- 燃料耗尽时,首先消耗物品栏内同名道具,无则消耗本体
local function OnDepleted(inst)
    if inst.components.fueled then inst.components.fueled:DoDelta(240) end
    if inst.components.inventoryitem then
        local owner = inst.components.inventoryitem.owner
        if owner and owner.components.inventory then
            local item = owner.components.inventory:FindItem(function(item) return item ~= nil and item.prefab == inst.prefab end)
            if item ~= nil then
                consumeItem(item)
                return
            end
        end
    end
    consumeItem(inst)
end

local function OnRemoveEntity(inst)
    if inst._light ~= nil then
        if inst._light:IsValid() then inst._light:Remove() end
        inst._light = nil
    end
end

local function OnSave(inst, data) data.userid = inst.userid end

local function OnLoad(inst, data)
    if data ~= nil then
        inst.userid = data.userid
        OnCharged(inst)
    end
end

local function updateseason(inst)
    if TheWorld.state.season == "summer" then
        inst.components.insulator:SetSummer()
    else
        inst.components.insulator:SetWinter()
    end
end

local function common_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)
    inst.Physics:ClearCollisionMask()
    inst.Physics:CollidesWith(COLLISION.GROUND)
    inst.Physics:CollidesWith(COLLISION.OBSTACLES)
    inst.Physics:CollidesWith(COLLISION.SMALLOBSTACLES)

    inst.AnimState:SetBank("cursedbeads")
    inst.AnimState:SetBuild("cursed_beads")
    inst.AnimState:PlayAnimation("idle1")

    inst:AddTag("curse2hm")
    inst:AddTag("cattoy")
    inst:AddTag("nosteal")
    inst:AddTag("cursed")
    -- inst:AddTag("maxstacksize2hm")

    MakeInventoryFloatable(inst, "med", 0.05, 0.68)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then return inst end

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.keepondeath = true
    inst.components.inventoryitem.keepondrown = true
    inst.components.inventoryitem.canonlygoinpocket = true
    inst:ListenForEvent("ondropped", OnDropped)

    inst:AddComponent("fueled")
    inst.components.fueled.fueltype = FUELTYPE.MAGIC
    inst.components.fueled:InitializeFuelLevel(240)
    inst.components.fueled:SetDepletedFn(OnDepleted)
    inst.components.fueled.no_sewing = true

    inst:AddComponent("rechargeable")
    inst.components.rechargeable:SetOnChargedFn(OnCharged)

    inst:DoTaskInTime(1, OnCharged)

    inst:AddComponent("equippable")
    inst.components.equippable.equipstack = true
    inst.components.equippable:SetOnEquip(OnEquip)
    inst.components.equippable:SetOnUnequip(OnUnequip)

    inst:AddComponent("stackable")
    inst.components.stackable.maxsize = TUNING.STACK_SIZE_TINYITEM
    -- inst.components.stackable.maxsize = 9999

    inst:AddComponent("curseditem")
    inst.components.curseditem.curse = "MOD_HARDMODE_DEATH"

    MakeHauntableLaunchAndIgnite(inst)

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad
    inst.DoCurse2hm = OnDropped

    inst._light = nil
    inst.OnRemoveEntity = OnRemoveEntity

    return inst
end

local invimgs = {hands = "unknown_hand", head = "unknown_head", body = "unknown_body"}

local strs = {hands = STRINGS.UI.WARDROBESCREEN.HAND, head = STRINGS.UI.WARDROBESCREEN.BASE, body = STRINGS.UI.WARDROBESCREEN.BODY}

-- 这个i是贴图序号但废弃了
local function makecurseequipprefab(slot, i)
    -- if i > 13 then
    --     i = i % 13
    -- end
    return function()
        local inst = common_fn()
        if not TheWorld.ismastersim then return inst end
        inst.components.equippable.equipslot = slot
        if slot == EQUIPSLOTS.HEAD or slot == EQUIPSLOTS.BODY then
            inst:AddComponent("waterproofer")
            inst.components.waterproofer:SetEffectiveness(0.5)
            inst:AddComponent("insulator")
            inst.components.insulator:SetInsulation(TUNING.INSULATION_LARGE)
            updateseason(inst)
            inst:WatchWorldState("season", updateseason)
        end
        inst.components.inventoryitem:ChangeImageName(invimgs[slot] or invimgs.body)
        return inst
    end
end
TUNING.deathcursedequip2hm = {}
local prefabs = {}
local slots = {}
local i = 1
for key, slot in pairs(EQUIPSLOTS) do
    if slot ~= EQUIPSLOTS.BEARD then
        local name = "mod_hardmode_deathcursedequip_" .. slot
        table.insert(TUNING.deathcursedequip2hm, name)
        table.insert(prefabs, Prefab(name, makecurseequipprefab(slot, i), assets, {"deathcurselight2hm"}))
        local str = string.upper(name)
        STRINGS.NAMES[str] = STRINGS.UI.SANDBOXMENU.DISABLED .. " " .. (strs[slot] or strs.body)
        table.insert(slots, slot)
        i = i + 1
    end
end

table.insert(TUNING.deathcursedequip2hm, "mod_hardmode_deathcursedequip")

local function randomcurseequipprefab()
    local i = math.random(#slots)
    local slot = slots[i]
    local inst = makecurseequipprefab(slot, i)()
    inst:SetPrefabName("mod_hardmode_deathcursedequip_" .. slot)
    return inst
end

table.insert(prefabs, Prefab("mod_hardmode_deathcursedequip", randomcurseequipprefab, assets, {"deathcurselight2hm"}))
table.insert(prefabs, Prefab("deathcurselight2hm", deathcurselightfn))

return unpack(prefabs)
