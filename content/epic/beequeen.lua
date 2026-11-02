-- 蜂王攻速移速加强之前也许是海棠写的？但是一直是注释状态
-- TUNING.BEEQUEEN_SPEED = TUNING.BEEQUEEN_SPEED * 1.5
-- TUNING.BEEQUEEN_ATTACK_PERIOD = TUNING.BEEQUEEN_ATTACK_PERIOD * 2 / 3

-- 蜂王加强:玩家被蜂王本体打中后获得"沃尔特"debuff
-- debuff期间玩家带allergictobees标签(原版沃尔特对蜜蜂过敏),蜜蜂/杀人蜂/蜂卫/蜂王攻击时
-- 通过原版bonus_damage_via_allergy额外造成TUNING.BEE_ALLERGY_EXTRADAMAGE(=10)点伤害
local BEEQUEEN_SWARM_DEBUFF_TIME = 10

local function RemoveBeeSwarmDebuff(inst)
    inst:RemoveTag("allergictobees")
    if inst._beequeen_swarm_task then
        inst._beequeen_swarm_task:Cancel()
        inst._beequeen_swarm_task = nil
    end
end

local function ApplyBeeSwarmDebuff(inst)
    inst:AddTag("allergictobees")
    if inst._beequeen_swarm_task then inst._beequeen_swarm_task:Cancel() end
    inst._beequeen_swarm_task = inst:DoTaskInTime(BEEQUEEN_SWARM_DEBUFF_TIME, function()
        RemoveBeeSwarmDebuff(inst)
    end)
end

AddPlayerPostInit(function(inst)
    if not TheWorld.ismastersim then return end
    -- 被蜂王本体打中时获得沃尔特debuff(每次命中刷新时长)
    inst:ListenForEvent("attacked", function(inst, data)
        if data and data.attacker and data.attacker:IsValid()
            and data.attacker.prefab == "beequeen" then
            ApplyBeeSwarmDebuff(inst)
        end
    end)
    -- 死亡/复活清除debuff
    inst:ListenForEvent("death", function(inst) RemoveBeeSwarmDebuff(inst) end)
    inst:ListenForEvent("respawn", function(inst) RemoveBeeSwarmDebuff(inst) end)
end)

-- 蜂王掉落加强(与蜂王加强捆绑,仅开启蜂王加强时生效)
-- 1. 佩戴蜂王帽(hivehat)时, 随从伤害+20%
-- 2. 吃下蜂王浆(royal_jelly)后(最多生效一次), 随从永久每次攻击额外+5伤害
local ROYAL_JELLY_KEY2HM = "royal_jelly_eaten2hm"

-- 吃蜂王浆:给玩家打上永久标记(persistent2hm存档)
AddPrefabPostInit("royal_jelly", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.edible then
        -- 注意:edible组件的吃后回调字段是 oneaten (SetOnEatenFn 设置 self.oneaten)
        local oldoneaten = inst.components.edible.oneaten
        inst.components.edible.oneaten = function(inst, eater, ...)
            if oldoneaten then oldoneaten(inst, eater, ...) end
            if eater and eater:IsValid() and eater:HasTag("player") then
                if not eater.components.persistent2hm then eater:AddComponent("persistent2hm") end
                if not eater.components.persistent2hm.data[ROYAL_JELLY_KEY2HM] then
                    eater.components.persistent2hm.data[ROYAL_JELLY_KEY2HM] = true
                    eater._royal_jelly_eaten2hm = true
                end
            end
        end
    end
end)

-- 玩家重进恢复蜂王浆永久标记
AddPlayerPostInit(function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.persistent2hm and inst.components.persistent2hm.data and inst.components.persistent2hm.data[ROYAL_JELLY_KEY2HM] then
        inst._royal_jelly_eaten2hm = true
    end
    SetOnLoad2hm(inst, function(inst, data)
        if data and data[ROYAL_JELLY_KEY2HM] then
            inst._royal_jelly_eaten2hm = true
        end
    end)
end)

-- 随从伤害增强: 佩戴蜂王帽×1.2, 吃过蜂王浆+5固定
-- 仅在攻击者是玩家随从(follower.leader为玩家)时生效, 非随从直接走原逻辑
AddComponentPostInit("combat", function(self)
    if not TheWorld.ismastersim then return end
    local oldCalcDamage = self.CalcDamage
    self.CalcDamage = function(self, target, weapon, multiplier, ...)
        local damage, spdamage = oldCalcDamage(self, target, weapon, multiplier, ...)
        -- 仅在攻击者是玩家随从且伤害有效时增强
        if damage and damage > 0 then
            local follower = self.inst.components.follower
            local leader = follower and follower:GetLeader()
            if leader and leader:IsValid() and leader:HasTag("player") then
                local mult = 1
                local bonus = 0
                if leader.components.inventory then
                    local head = leader.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
                    if head and head:IsValid() and (head.prefab == "hivehat" or head.base_prefab == "hivehat") then
                        mult = 1.2
                    end
                end
                if leader._royal_jelly_eaten2hm or
                    (leader.components.persistent2hm and leader.components.persistent2hm.data and leader.components.persistent2hm.data[ROYAL_JELLY_KEY2HM]) then
                    bonus = 5
                end
                if mult ~= 1 or bonus ~= 0 then
                    damage = damage * mult + bonus
                end
            end
        end
        return damage, spdamage
    end
end)
