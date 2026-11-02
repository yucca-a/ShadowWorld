-- 恶液存储套件
local GELBLOB_TAG2HM = "gelblob2hm"
local GELBLOB_CANTAG2HM = "canfrostcoreUP2hm"
local GELBLOB_ACTIONTEXT2HM = "GELBLOB2HM"

-- 给容器上永鲜
local function ApplyGelblobUpgrade2hm(target)
    if target == nil or not target:IsValid() or target:HasTag(GELBLOB_TAG2HM) then return end
    target:AddTag(GELBLOB_TAG2HM)
    if target.components.preserver == nil then
        target:AddComponent("preserver")
    end
    target.components.preserver:SetPerishRateMultiplier(0)
end

-- 右键条件:目标是可升级容器,且尚未恶液升级过
local function GelblobCondition2hm(inst, doer, actions, right, target)
    return target ~= nil and target:IsValid() and target:HasTag(GELBLOB_CANTAG2HM) and
               not target:HasTag(GELBLOB_TAG2HM)
end

-- 右键动作:消耗1个套件,给容器上永鲜
local function GelblobDoAction2hm(kit, doer, target, pos, act)
    if target == nil or not target:IsValid() or target:HasTag(GELBLOB_TAG2HM) then return false end
    ApplyGelblobUpgrade2hm(target)
    if kit.components.stackable ~= nil then
        kit.components.stackable:Get(1):Remove()
    else
        kit:Remove()
    end
    return true
end


if EntityScript ~= nil and EntityScript.GetBasicDisplayName ~= nil then
    local _gelblob_GetBasicDisplayName = EntityScript.GetBasicDisplayName
    function EntityScript:GetBasicDisplayName()
        local name = _gelblob_GetBasicDisplayName(self)
        if self:HasTag(GELBLOB_TAG2HM) then
            if name == nil or name == "" then
                name = STRINGS.NAMES[string.upper(self.prefab)]
            end
            if name ~= nil and name ~= "" then
                local prefix = TUNING.isCh2hm and "恶液-" or "Ooze-"
                if name:sub(1, #prefix) ~= prefix then
                    name = prefix .. name
                end
            end
        end
        return name
    end
end

STRINGS.ACTIONS.ACTION2HM = STRINGS.ACTIONS.ACTION2HM or {}
STRINGS.ACTIONS.ACTION2HM[GELBLOB_ACTIONTEXT2HM] = TUNING.isCh2hm and "升级" or "UPGRADE"


AddPrefabPostInit("gelblob_storage_kit", function(inst)
    inst.actionothercondition2hm = GelblobCondition2hm
    inst.actiontext2hm = GELBLOB_ACTIONTEXT2HM
    if not TheWorld.ismastersim then return end
    inst:AddComponent("action2hm")
    inst.components.action2hm.actionfn = GelblobDoAction2hm
end)

AddPrefabPostInitAny(function(inst)
    if inst:HasTag("player") then return end
    inst:DoTaskInTime(0, function()
        if inst:IsValid() and (inst.components.container or inst.replica.container) ~= nil then
            inst:AddTag(GELBLOB_CANTAG2HM)
        end
    end)
    if not TheWorld.ismastersim or inst.components.container == nil then return end
    SetOnSave(inst, function(i, data)
        if data ~= nil and i:HasTag(GELBLOB_TAG2HM) then data.gelblob2hm = true end
    end)
    SetOnLoad(inst, function(i, data)
        if data ~= nil and data.gelblob2hm then ApplyGelblobUpgrade2hm(i) end
    end)
end)
