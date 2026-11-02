-- 永恒-极地熊獾桶:天体珠宝升级熊罐;桶在物品栏时,桶内凑够40个同料理或同调料前缀就给buff

local SACK_PREFAB2HM = "beargerfur_sack"
local SACK_ETERNAL_TAG2HM = "eternal_beargerfur_sack2hm"
local SACK_MATERIAL2HM = "lunar_seed" -- 天体珠宝
local SACK_ACTIONTEXT2HM = "ETERNAL2HM"
local SACK_ETERNAL_NAME2HM_CH = "永恒-极地熊獾桶"
local SACK_ETERNAL_NAME2HM_EN = "Eternal Polar Bearger Bin"
local ETERNAL_SACK_NEED2HM = 40

local function IsEternalSack2hm(sack)
    if sack == nil or not sack:IsValid() then return false end
    if sack:HasTag(SACK_ETERNAL_TAG2HM) then return true end
    return sack._eternal2hm ~= nil and sack._eternal2hm:value()
end

if EntityScript ~= nil and EntityScript.GetBasicDisplayName ~= nil then
    local _GetBasicDisplayName = EntityScript.GetBasicDisplayName
    function EntityScript:GetBasicDisplayName()
        local name = _GetBasicDisplayName(self)
        if IsEternalSack2hm(self) then
            local prefix = TUNING.isCh2hm and "永恒-" or "Eternal "
            if name == nil or name == "" then
                name = STRINGS.NAMES[string.upper(self.prefab)]
            end
            if name ~= nil and name ~= "" and string.sub(name, 1, #prefix) ~= prefix then
                name = prefix .. name
            end
        end
        return name
    end
end

-- 料理 -> buff
local ETERNAL_SACK_FOODBUFFS2HM = {
    jellybean = { buff = "healthregenbuff" },
    voltgoatjelly = { buff = "buff_electricattack" },
    frogfishbowl = { buff = "buff_moistureimmunity" },
    tropicalbouillabaisse2hm = { buff = "tropicalfishbuff2hm", data = function() return {} end },
    carrotcake2hm = { buff = "gulumi_bless2hm", data = function() return { blessDuration = 240 } end },
    smallcandy2hm = {
        buff = "healthregenbuff2hm",
        data = function()
            return {
                healthTick = 1 / 8, healthTimer = 1, healthTime = 240,
                sanityTick = 1 / 8, sanityTimer = 1, sanityTime = 240,
            }
        end,
    },
}

-- 调料 -> buff
local ETERNAL_SACK_SPICEBUFFS2HM = {
    SPICE_GARLIC = "buff_playerabsorption",
    SPICE_SUGAR = "buff_workeffectiveness",
    SPICE_CHILI = "buff_attack",
}

local ETERNAL_SACK_SPICESUFFIX2HM = { "_spice_garlic", "_spice_sugar", "_spice_chili", "_spice_salt" }

-- 料理本体名(辣糖豆也算糖豆)
local function GetBaseFoodPrefab2hm(prefab)
    if prefab == nil then return nil end
    for i = 1, #ETERNAL_SACK_SPICESUFFIX2HM do
        local suffix = ETERNAL_SACK_SPICESUFFIX2HM[i]
        if string.sub(prefab, -#suffix) == suffix then
            return string.sub(prefab, 1, #prefab - #suffix)
        end
    end
    return prefab
end

-- 数桶里的料理和调料
local function CountEternalSackContents2hm(sack)
    local counts, spices = {}, {}
    local container = sack.components.container
    if container == nil then return counts, spices end
    local numslots = container.numslots or 0
    for i = 1, numslots do
        local item = container.slots[i]
        if item ~= nil and item:IsValid() then
            local num = (item.components.stackable ~= nil and item.components.stackable.stacksize) or 1
            local base = GetBaseFoodPrefab2hm(item.prefab)
            counts[base] = (counts[base] or 0) + num
            local edible = item.components.edible
            local spice = edible ~= nil and edible.spice or nil
            if spice ~= nil then
                spices[spice] = (spices[spice] or 0) + num
            end
        end
    end
    return counts, spices
end

-- 桶的主人(背包里也算)
local function GetEternalSackOwner2hm(sack)
    local inventoryitem = sack.components.inventoryitem
    local owner = inventoryitem ~= nil and inventoryitem:GetGrandOwner() or nil
    if owner == nil or not owner:IsValid() or owner.components.debuffable == nil then
        return nil
    end
    if owner.components.health ~= nil and owner.components.health:IsDead() then
        return nil
    end
    return owner
end

-- 撤掉自己挂的buff
local function RemoveEternalSackBuffs2hm(sack)
    local owner = sack._eternal_sack_owner2hm
    local applied = sack._eternal_sack_applied2hm
    sack._eternal_sack_owner2hm = nil
    sack._eternal_sack_applied2hm = nil
    if applied == nil or owner == nil or not owner:IsValid() or owner.components.debuffable == nil then return end
    local debuffable = owner.components.debuffable
    for name, ent in pairs(applied) do
        if debuffable:GetDebuff(name) == ent then
            debuffable:RemoveDebuff(name)
        end
    end
end

-- 每秒判定一次
local function RefreshEternalSackBuffs2hm(sack)
    if sack == nil or not sack:IsValid() then return end
    local owner = GetEternalSackOwner2hm(sack)
    if owner ~= sack._eternal_sack_owner2hm then
        RemoveEternalSackBuffs2hm(sack)
        sack._eternal_sack_owner2hm = owner
    end
    if owner == nil then return end
    local debuffable = owner.components.debuffable
    local applied = sack._eternal_sack_applied2hm
    if applied == nil then
        applied = {}
        sack._eternal_sack_applied2hm = applied
    end

    local wanted = {}
    local need = ETERNAL_SACK_NEED2HM or 40 -- 兜底,别崩
    local counts, spices = CountEternalSackContents2hm(sack)
    for prefab, config in pairs(ETERNAL_SACK_FOODBUFFS2HM or {}) do
        if (counts[prefab] or 0) >= need then
            wanted[config.buff] = config.data or false
        end
    end
    for spice, buff in pairs(ETERNAL_SACK_SPICEBUFFS2HM or {}) do
        if (spices[spice] or 0) >= need and wanted[buff] == nil then
            wanted[buff] = false
        end
    end

    for name, ent in pairs(applied) do
        if debuffable:GetDebuff(name) ~= ent then
            applied[name] = nil
        elseif wanted[name] == nil then
            debuffable:RemoveDebuff(name)
            applied[name] = nil
        end
    end

    for name, datafn in pairs(wanted) do
        if debuffable:GetDebuff(name) == nil then
            local data = (type(datafn) == "function" and datafn()) or nil
            applied[name] = debuffable:AddDebuff(name, name, data)
        end
    end
end

-- 开始监视
local function StartEternalSackWatch2hm(sack)
    if sack._eternal_sack_task2hm == nil then
        sack._eternal_sack_task2hm = sack:DoPeriodicTask(1, RefreshEternalSackBuffs2hm)
        sack:ListenForEvent("onremove", function() RemoveEternalSackBuffs2hm(sack) end)
    end
    local function RefreshSoon2hm()
        if sack._eternal_sack_soon2hm ~= nil then return end
        sack._eternal_sack_soon2hm = sack:DoTaskInTime(0, function()
            sack._eternal_sack_soon2hm = nil
            RefreshEternalSackBuffs2hm(sack)
        end)
    end
    sack:ListenForEvent("itemget", RefreshSoon2hm)
    sack:ListenForEvent("itemlose", RefreshSoon2hm)
    sack:ListenForEvent("onputininventory", RefreshSoon2hm)
    sack:ListenForEvent("ondropped", RefreshSoon2hm)
    sack:ListenForEvent("onpickup", RefreshSoon2hm)
    RefreshEternalSackBuffs2hm(sack)
end

-- 升级(playfx只在真升级时true)
local function ApplyEternalSackUpgrade2hm(sack, playfx)
    if sack == nil or not sack:IsValid() then return end
    if sack:HasTag(SACK_ETERNAL_TAG2HM) then return end
    sack:AddTag(SACK_ETERNAL_TAG2HM)
    if sack._eternal2hm ~= nil then
        sack._eternal2hm:set(true)
    end

    if playfx then
        local fx = SpawnPrefab("moonstorm_ground_lightning_fx2hm")
        if fx ~= nil then
            fx.Transform:SetPosition(sack.Transform:GetWorldPosition())
        end
    end

    if TheWorld.ismastersim then
        StartEternalSackWatch2hm(sack)
    end
end

-- 右键条件/动作
local function EternalSackCondition2hm(jewel, doer, actions, right, target)
    return jewel ~= nil and jewel:IsValid() and target ~= nil and target:IsValid() and
               target.prefab == SACK_PREFAB2HM and not IsEternalSack2hm(target)
end

local function EternalSackDoAction2hm(jewel, doer, target, pos, act)
    if target == nil or not target:IsValid() or target.prefab ~= SACK_PREFAB2HM then return false end
    if IsEternalSack2hm(target) then
        if doer ~= nil and doer:IsValid() and doer.components.talker ~= nil then
            doer:DoTaskInTime(0, function()
                doer.components.talker:Say(TUNING.isCh2hm and "它已经永恒了" or "It is already eternal.")
            end)
        end
        return false
    end
    ApplyEternalSackUpgrade2hm(target, true)
    -- 只消耗1个
    if jewel.components.stackable ~= nil then
        jewel.components.stackable:Get(1):Remove()
    else
        jewel:Remove()
    end
    return true
end

-- 天体珠宝
AddPrefabPostInit(SACK_MATERIAL2HM, function(inst)
    local oldcondition = inst.actionothercondition2hm
    inst.actionothercondition2hm = function(self, doer, actions, right, target)
        if oldcondition ~= nil and oldcondition(self, doer, actions, right, target) then return true end
        return EternalSackCondition2hm(self, doer, actions, right, target)
    end
    inst.actiontext2hm = SACK_ACTIONTEXT2HM
    if not TheWorld.ismastersim then return end
    if inst.components.action2hm == nil then
        inst:AddComponent("action2hm")
    end
    local oldactionfn = inst.components.action2hm.actionfn
    inst.components.action2hm.actionfn = function(self, doer, target, pos, act)
        if oldactionfn ~= nil and oldactionfn(self, doer, target, pos, act) then return true end
        return EternalSackDoAction2hm(self, doer, target, pos, act)
    end
end)

-- 熊罐:改名 + 存档
AddPrefabPostInit(SACK_PREFAB2HM, function(inst)
    inst._eternal2hm = net_bool(inst.GUID, "beargerfur_sack.eternal2hm", "eternal2hm_dirty")
    local oldname = inst.displaynamefn
    inst.displaynamefn = function(self)
        if IsEternalSack2hm(self) then
            return (TUNING.isCh2hm and SACK_ETERNAL_NAME2HM_CH) or SACK_ETERNAL_NAME2HM_EN
        end
        return oldname ~= nil and oldname(self) or nil
    end
    if not TheWorld.ismastersim then return end
    SetOnSave(inst, function(i, data)
        if data ~= nil and i:HasTag(SACK_ETERNAL_TAG2HM) then
            data.eternal_beargerfur_sack2hm = true
        end
    end)
    SetOnLoad(inst, function(i, data)
        if data ~= nil and data.eternal_beargerfur_sack2hm then
            ApplyEternalSackUpgrade2hm(i, false)
        end
    end)
end)

STRINGS.ACTIONS.ACTION2HM = STRINGS.ACTIONS.ACTION2HM or {}
STRINGS.ACTIONS.ACTION2HM[SACK_ACTIONTEXT2HM] = TUNING.isCh2hm and "升级" or "UPGRADE"
