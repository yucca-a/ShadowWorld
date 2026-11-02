-- 恐惧-警告表:旺达用附身暗影心房升级警钟
-- 3秒没续上攻击或挨打时清空层数
local DREADWATCH_TAG2HM = "dreadwatch2hm"
local DREAD_MAX_STACK2HM = 6 -- 攻速叠加上限
local DREAD_SPEED_PER_STACK2HM = 0.12 -- 每层攻速(12%)
local DREAD_RESET_TIME2HM = 3 -- 断攻击/挨打后清空层数的时间(秒)
local DREAD_PLANAR2HM = 34 -- 叠满后每次攻击附加的位面伤害
local DREAD_RANGE_MULT2HM = 1.2 -- 叠满后的攻击距离倍率
local DREAD_NIGHTMARE_FUEL_RATIO2HM = 0.10 -- 噩梦燃料补充的耐久(占最大耐久的比例);纯粹恐惧沿用原版燃料值=50%

local function MakeRepairMaterials2hm(watch)
    return setmetatable({}, {
        __index = function(_, key)
            if watch:HasTag(DREADWATCH_TAG2HM) then
                return nil
            end
            return key == "shadowheart_infused" and 1 or nil
        end,
    })
end

-- 清空叠层:恢复攻速/攻击距离/位面伤害
local function ClearDreadStack2hm(owner)
    if owner == nil or not owner:IsValid() then return end
    owner._dreadwatch_stack2hm = 0
    owner._dreadwatch_speed_mult2hm = nil
    if owner._dreadwatch_reset_task2hm ~= nil then
        owner._dreadwatch_reset_task2hm:Cancel()
        owner._dreadwatch_reset_task2hm = nil
    end
    if owner.components.combat ~= nil then
        if owner._dreadwatch_base_attackperiod ~= nil then
            owner.components.combat.min_attack_period = owner._dreadwatch_base_attackperiod
        end
        if owner._dreadwatch_base_attackrange ~= nil then
            owner.components.combat.attackrange = owner._dreadwatch_base_attackrange
            owner.components.combat.hitrange = owner._dreadwatch_base_hitrange
        end
    end
    if owner.components.planardamage ~= nil then
        owner.components.planardamage:SetBaseDamage(0)
    end
end

local function OnDreadWatchHit2hm(owner)
    if not TheWorld.ismastersim then return end
    if owner == nil or not owner:IsValid() or owner.components.combat == nil then return end
    if owner:HasTag("playerghost") then return end

    if not owner._dreadwatch_hooked2hm then
        owner._dreadwatch_hooked2hm = true
        owner:ListenForEvent("attacked", function(inst)
            if (inst._dreadwatch_stack2hm or 0) > 0 then ClearDreadStack2hm(inst) end
        end)
    end

    if owner._dreadwatch_base_attackperiod == nil then
        owner._dreadwatch_base_attackperiod = owner.components.combat.min_attack_period
        owner._dreadwatch_base_attackrange = owner.components.combat.attackrange
        owner._dreadwatch_base_hitrange = owner.components.combat.hitrange
    end

    local stacks = math.min((owner._dreadwatch_stack2hm or 0) + 1, DREAD_MAX_STACK2HM)
    owner._dreadwatch_stack2hm = stacks

    local mult = 1 + DREAD_SPEED_PER_STACK2HM * stacks
    owner._dreadwatch_speed_mult2hm = mult
    owner.components.combat.min_attack_period = owner._dreadwatch_base_attackperiod / mult

    if stacks >= DREAD_MAX_STACK2HM then
        if owner.components.planardamage == nil then
            owner:AddComponent("planardamage")
        end
        if owner.components.planardamage ~= nil then
            owner.components.planardamage:SetBaseDamage(DREAD_PLANAR2HM)
        end
        owner.components.combat.attackrange = owner._dreadwatch_base_attackrange * DREAD_RANGE_MULT2HM
        owner.components.combat.hitrange = owner._dreadwatch_base_hitrange * DREAD_RANGE_MULT2HM
    end

    if owner._dreadwatch_reset_task2hm ~= nil then owner._dreadwatch_reset_task2hm:Cancel() end
    owner._dreadwatch_reset_task2hm = owner:DoTaskInTime(DREAD_RESET_TIME2HM, function()
        ClearDreadStack2hm(owner)
    end)
end

AddStategraphPostInit("wilson", function(sg)
    local state = sg.states["attack"]
    if state == nil then return end

    local base_timeline2hm = {}
    if state.timeline ~= nil then
        for i = 1, #state.timeline do
            base_timeline2hm[i] = state.timeline[i].time
        end
    end

    local _onenter = state.onenter
    state.onenter = function(inst, ...)
        if _onenter ~= nil then _onenter(inst, ...) end
        local mult = inst._dreadwatch_speed_mult2hm
        if mult ~= nil and mult > 1 and inst.sg ~= nil and inst.sg.currentstate == state and inst.AnimState ~= nil then
            inst.AnimState:SetDeltaTimeMultiplier(mult)
            if inst.sg.timeout ~= nil then
                inst.sg:SetTimeout(inst.sg.timeout / mult)
            end
            if state.timeline ~= nil then
                for i = 1, #state.timeline do
                    state.timeline[i].time = base_timeline2hm[i] / mult
                end
            end
        end
    end

    local _onexit = state.onexit
    state.onexit = function(inst, ...)
        if inst.AnimState ~= nil then inst.AnimState:SetDeltaTimeMultiplier(1) end
        if state.timeline ~= nil then
            for i = 1, #state.timeline do
                state.timeline[i].time = base_timeline2hm[i]
            end
        end
        if _onexit ~= nil then _onexit(inst, ...) end
    end
end)

local function ApplyDreadWatch2hm(watch)
    if watch == nil or not watch:IsValid() or watch:HasTag(DREADWATCH_TAG2HM) then return end
    watch:AddTag(DREADWATCH_TAG2HM)

    if watch.components.fueled ~= nil then
        local old_takefueltiem2hm = watch.components.fueled.TakeFuelItem
        watch.components.fueled.TakeFuelItem = function(self, item, doer)
            if self.inst:HasTag(DREADWATCH_TAG2HM) and item ~= nil and item:IsValid()
                and item.prefab == "nightmarefuel" and self:CanAcceptFuelItem(item) then
                local fuel = item.components.fuel
                if fuel ~= nil then
                    local value = self.maxfuel * DREAD_NIGHTMARE_FUEL_RATIO2HM
                    self:DoDelta(value, doer)
                    fuel:Taken(self.inst)
                    if self.ontakefuelitemfn ~= nil then self.ontakefuelitemfn(self.inst, item, value, doer) end
                    item:Remove()
                    if self.ontakefuelfn ~= nil then self.ontakefuelfn(self.inst, value) end
                    self.inst:PushEvent("takefuel", { fuelvalue = value })
                    return true
                end
            end
            return old_takefueltiem2hm(self, item, doer)
        end
    end

    -- 攻击叠层
    if watch.components.weapon ~= nil then
        local oldonattack = watch.components.weapon.onattack
        watch.components.weapon.onattack = function(inst, attacker, target, ...)
            if oldonattack ~= nil then oldonattack(inst, attacker, target, ...) end
            if inst:HasTag(DREADWATCH_TAG2HM) and attacker ~= nil and attacker:IsValid() then
                OnDreadWatchHit2hm(attacker)
            end
        end
    end
end

-- 警钟:附身暗影心房升级
AddPrefabPostInit("pocketwatch_weapon", function(inst)
    inst.repairmaterials2hm = MakeRepairMaterials2hm(inst)
    inst.repairtext2hm = "UPGRADE" -- 右键动作文字(升级前)
    local oldname = inst.displaynamefn
    inst.displaynamefn = function()
        if inst:HasTag(DREADWATCH_TAG2HM) then
            return (TUNING.isCh2hm and "恐惧-警告表") or "Dread Alarming Clock"
        end
        return oldname and oldname(inst)
    end
    if not TheWorld.ismastersim then return end
    inst:AddComponent("persistent2hm")
    inst:AddComponent("repairable2hm")
    inst.components.repairable2hm.ignoremax = true
    inst.components.repairable2hm.customrepair = function(watch, repairuse, doer, repair_item)
        if repair_item == nil or not repair_item:IsValid() then return false end
        if repair_item.prefab == "shadowheart_infused" then
            if watch:HasTag(DREADWATCH_TAG2HM) then return false end
            if doer == nil or not doer:IsValid() or doer.prefab ~= "wanda" then return false end
            if repair_item.components.stackable then
                repair_item.components.stackable:Get(1):Remove()
            else
                repair_item:Remove()
            end
            ApplyDreadWatch2hm(watch)
            return true
        end
        return false
    end
    SetOnSave2hm(inst, function(i, data) data.dreadwatch2hm = i:HasTag(DREADWATCH_TAG2HM) or nil end)
    SetOnLoad2hm(inst, function(i, data)
        if data ~= nil and data.dreadwatch2hm then ApplyDreadWatch2hm(i) end
    end)
end)

STRINGS.ACTIONS.REPAIR2HM.UPGRADE = TUNING.isCh2hm and "升级" or "Upgrade"
