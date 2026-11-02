-- 冰霜核心冰杖
-- 攻击命中直接上3层冰冻,之后每15秒再施加3层冰冻,持续16分钟
local ICESTAFF_COLDNESS_2HM = 3 -- 每次上冰冻层数
local ICESTAFF_MAX_USES_2HM = 1 -- 总耐久1
local ICESTAFF_ATTACK_COST_2HM = 999 -- 每次攻击消耗999耐久,因为妥测可以给装备加耐久上限，所以这样写的
local ICESTAFF_DEBUFF_INTERVAL_2HM = 15 -- 持续冰冻debuff间隔(秒)
local ICESTAFF_DEBUFF_DURATION_2HM = 16 * 60 -- 持续16分钟

-- 目标持续冰冻:每15秒3层,持续16分钟
local function StartFrostDebuff(target)
    if not target:IsValid() or not target.components.freezable then return end
    if target._frostcore_icestaff_debuff2hm then return end
    target._frostcore_icestaff_debuff2hm = true
    local remaining = ICESTAFF_DEBUFF_DURATION_2HM
    target._frostcore_icestaff_debufftask2hm = target:DoPeriodicTask(ICESTAFF_DEBUFF_INTERVAL_2HM, function(t)
        remaining = remaining - ICESTAFF_DEBUFF_INTERVAL_2HM
        if remaining <= 0 or not t:IsValid() or not t.components.freezable then
            if t._frostcore_icestaff_debufftask2hm then
                t._frostcore_icestaff_debufftask2hm:Cancel()
                t._frostcore_icestaff_debufftask2hm = nil
            end
            t._frostcore_icestaff_debuff2hm = nil
            return
        end
        t.components.freezable:AddColdness(ICESTAFF_COLDNESS_2HM, 300)
        t.components.freezable:SpawnShatterFX()
    end)
end

-- 冰杖升级改造(升级时/重进恢复时调用)
local function ApplyIcestaffUpgrade(staff)
    if not staff:IsValid() then return end
    if staff._frostcore_icestaff2hm then return end
    staff._frostcore_icestaff2hm = true
    staff:AddTag("frostcore_icestaff2hm")
    staff.icestaff_coldness = ICESTAFF_COLDNESS_2HM -- 原版onattack_blue按此值加3层
    if staff.components.finiteuses then
        staff.components.finiteuses:SetIgnoreCombatDurabilityLoss(true) -- 关闭原版每次攻击掉耐久
        staff.components.finiteuses:SetMaxUses(ICESTAFF_MAX_USES_2HM)
        staff.components.finiteuses:SetUses(ICESTAFF_MAX_USES_2HM)
    end
    if staff.components.weapon then
        local oldonattack = staff.components.weapon.onattack
        staff.components.weapon.onattack = function(inst, attacker, target, skipsanity)
            if oldonattack then oldonattack(inst, attacker, target, skipsanity) end
            if target and target:IsValid() then
                StartFrostDebuff(target)
            end
            -- 一次性:攻击一次掉999耐久直接报废
            if inst.components.finiteuses then
                inst.components.finiteuses:Use(ICESTAFF_ATTACK_COST_2HM)
            end
        end
    end
    -- 持久化由AddPrefabPostInit统一处理
end

-- 冰杖:冰核升级
AddPrefabPostInit("icestaff", function(inst)
    inst.repairmaterials2hm = {frostcore2hm = 1}
    local oldname = inst.displaynamefn
    inst.displaynamefn = function()
        if inst:HasTag("frostcore_icestaff2hm") then
            return (TUNING.isCh2hm and "冰霜核心冰杖") or "Frost Core Ice Staff"
        end
        return oldname and oldname(inst)
    end
    if not TheWorld.ismastersim then return end
    inst:AddComponent("persistent2hm")
    inst:AddComponent("repairable2hm")
    inst.components.repairable2hm.ignoremax = true -- 满耐久也能用冰核升级
    inst.components.repairable2hm.customrepair = function(staff, repairuse, doer, repair_item)
        if staff:HasTag("frostcore_icestaff2hm") then
            return false -- 已升级,不再消耗冰核
        end
        -- 只消耗1个冰核
        if repair_item and repair_item:IsValid() then
            if repair_item.components.stackable then
                repair_item.components.stackable:Get(1):Remove()
            else
                repair_item:Remove()
            end
        end
        ApplyIcestaffUpgrade(staff)
        return true -- 已自行处理消耗,不再走默认流程
    end
    -- 持久化升级状态
    SetOnSave2hm(inst, function(i, data) data.frostcore_icestaff2hm = i._frostcore_icestaff2hm or nil end)
    SetOnLoad2hm(inst, function(i, data)
        if data and data.frostcore_icestaff2hm then ApplyIcestaffUpgrade(i) end
    end)
end)
