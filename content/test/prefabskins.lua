local processdequip = {}
local specialdata = {}

local function newonequipnoskinfn(inst, owner, ...)
    print("测试数据", inst.skinname, inst:GetSkinName(), inst:GetSkinBuild(), inst.AnimState:GetBuild(), inst.AnimState:GetSkinBuild())
    if inst.oldskinonequipfn2hm then
        local oldOverrideSymbol
        if owner and owner.AnimState then
            oldOverrideSymbol = getmetatable(owner.AnimState).__index["OverrideSymbol"]
            getmetatable(owner.AnimState).__index["OverrideSymbol"] = function(self, follow, build, symbol, ...)
                local skin_build = inst:GetSkinBuild()
                local skinname = inst:GetSkinName()
                if specialdata[inst.prefab] and specialdata[inst.prefab][skinname] then
                    build = specialdata[inst.prefab][skinname].overridebuild
                    symbol = specialdata[inst.prefab][skinname].overridesymbol
                end
                if skin_build then
                    owner:PushEvent("equipskinneditem", skinname)
                    return owner.AnimState:OverrideItemSkinSymbol(follow, skin_build, build, inst.GUID, symbol, ...)
                else
                    local animbuild = inst.AnimState:GetBuild()
                    if specialdata[inst.prefab] and specialdata[inst.prefab][animbuild] then
                        build = specialdata[inst.prefab][animbuild].overridebuild
                        symbol = specialdata[inst.prefab][animbuild].overridesymbol
                    end
                    return oldOverrideSymbol(self, follow, build, symbol, ...)
                end
            end
        end
        inst.oldskinonequipfn2hm(inst, owner, ...)
        if oldOverrideSymbol then getmetatable(owner.AnimState).__index["OverrideSymbol"] = oldOverrideSymbol end
    end
end

local function newonunequipnoskinfn(inst, owner, ...)
    if inst.oldskinonunequipfn2hm then inst.oldskinonunequipfn2hm(inst, owner, ...) end
    local skin_build = inst:GetSkinBuild()
    if owner and skin_build ~= nil then owner:PushEvent("unequipskinneditem", inst:GetSkinName()) end
end

local function newonequiphasskinfn(inst, owner, ...)
    if inst.oldskinonunequipfn2hm then
        local oldOverrideSymbol
        if owner and owner.AnimState then
            oldOverrideSymbol = getmetatable(owner.AnimState).__index["OverrideSymbol"]
            oldOverrideItemSkinSymbol = getmetatable(owner.AnimState).__index["OverrideItemSkinSymbol"]
            getmetatable(owner.AnimState).__index["OverrideSymbol"] = function(self, follow, build, symbol, ...)
                local skin_build = inst:GetSkinBuild()
                local skinname = inst:GetSkinName()
                if specialdata[inst.prefab] and specialdata[inst.prefab][skinname] then
                    build = specialdata[inst.prefab][skinname].overridebuild
                    symbol = specialdata[inst.prefab][skinname].overridesymbol
                end
                if skin_build then owner:PushEvent("equipskinneditem", skinname) end
                print("测试", inst.prefab, skinname, skin_build)
                return owner.AnimState:OverrideItemSkinSymbol(follow, skin_build or skinname or inst.prefab, build, inst.GUID, symbol, ...)
            end
        end
        inst.oldskinonequipfn2hm(inst, owner, ...)
        if oldOverrideSymbol then
            getmetatable(owner.AnimState).__index["OverrideSymbol"] = oldOverrideSymbol
            getmetatable(owner.AnimState).__index["OverrideItemSkinSymbol"] = oldOverrideItemSkinSymbol
        end
    end
end

local function resetInventoryItemImage(inst)
    local skin_build = inst:GetSkinBuild()
    if skin_build then return end
    if inst.AnimState then
        local build = inst.AnimState:GetBuild()
        local prefab = specialdata[inst.prefab][build].prefab
        inst.components.inventoryitem:ChangeImageName(prefab)
    end
end

local function copyitemskins(instprefab, itemprefab, instdata, itemdata)
    if instprefab == itemprefab then return end
    PREFAB_SKINS[instprefab] = PREFAB_SKINS[instprefab] or {}
    if not processdequip[instprefab] then
        processdequip[instprefab] = true
        if IsTableEmpty(PREFAB_SKINS[instprefab]) then
            -- 兼容那些默认没有皮肤样式的装备
            AddPrefabPostInit(instprefab, function(inst)
                if not TheWorld.ismastersim then return end
                if inst.components.inventoryitem then inst:DoTaskInTime(0, resetInventoryItemImage) end
                if inst.components.equippable then
                    inst.oldskinonequipfn2hm = inst.components.equippable.onequipfn
                    inst.components.equippable.onequipfn = newonequipnoskinfn
                    inst.oldskinonunequipfn2hm = inst.components.equippable.onunequipfn
                    inst.components.equippable.onunequipfn = newonunequipnoskinfn
                end
            end)
        else
            -- 处理那些本来就有皮肤样式的装备
            AddPrefabPostInit(instprefab, function(inst)
                if not TheWorld.ismastersim then return end
                if inst.components.inventoryitem then inst:DoTaskInTime(0, resetInventoryItemImage) end
                if inst.components.equippable then
                    inst.oldskinonequipfn2hm = inst.components.equippable.onequipfn
                    inst.components.equippable.onequipfn = newonequiphasskinfn
                end
            end)
        end
    end
    -- bank build的一些处理
    if instdata and itemdata then
        specialdata[instprefab] = specialdata[instprefab] or {}
        -- 本身皮肤
        table.insert(PREFAB_SKINS[instprefab], instprefab)
        if not specialdata[instprefab][instdata.build] then specialdata[instprefab][instdata.build] = instdata end
        if not specialdata[instprefab][instprefab] then specialdata[instprefab][instprefab] = instdata end
        -- 对手皮肤
        table.insert(PREFAB_SKINS[instprefab], itemprefab)
        if not specialdata[instprefab][itemdata.build] then specialdata[instprefab][itemdata.build] = itemdata end
        if not specialdata[instprefab][itemprefab] then specialdata[instprefab][itemprefab] = itemdata end
        for index, skin in ipairs(PREFAB_SKINS[itemprefab] or {}) do
            table.insert(PREFAB_SKINS[instprefab], skin)
            if not specialdata[instprefab][skin] then specialdata[instprefab][skin] = itemdata end
        end
    end
end

local lucy = {prefab = "lucy", build = "lucy_axe", overridebuild = "swap_lucy_axe", overridesymbol = "swap_lucy_axe"}
local axe = {prefab = "axe", build = "axe", overridebuild = "swap_axe", overridesymbol = "swap_axe"}
local goldenaxe = {prefab = "goldenaxe", build = "goldenaxe", overridebuild = "swap_axe", overridesymbol = "swap_axe"}
copyitemskins("lucy", "axe", lucy, axe)
copyitemskins("lucy", "goldenaxe", lucy, goldenaxe)
copyitemskins("axe", "goldenaxe", axe, goldenaxe)
