-- 升级剑自带+20%攻击距离;各武器影人命中后有独立附加效果(流血/回三维/易伤/辉煌标记/暗影触手/减伤/boss百分比伤害)
local SWORD_SHADOW_TAG = "sword_shadow2hm" -- 升级标记
local SWORD_ATTACK_RANGE_BONUS = 0.6 -- 攻击距离

-- ===== 影人武器附加效果
local function NoHoles(pt)
    return not TheWorld.Map:IsPointNearHole(pt)
end

-- 触手尖刺: 目标流血(每秒51,持续5秒)
local function EffectTentaclespike(owner, target)
    if not target:IsValid() or not target.components.health or target.components.health:IsDead() then return end
    if target._sword_bleedtask2hm then target._sword_bleedtask2hm:Cancel() end
    local ticks = 0
    target._sword_bleedtask2hm = target:DoPeriodicTask(1, function(t)
        ticks = ticks + 1
        if t:IsValid() and t.components.health and not t.components.health:IsDead() then
            t.components.health:DoDelta(-51)
        end
        if ticks >= 5 then
            if t._sword_bleedtask2hm then t._sword_bleedtask2hm:Cancel() end
            t._sword_bleedtask2hm = nil
        end
    end)
end

-- 火腿棒: 影人命中后玩家恢复6.8三维(饱食度/精神值/血量)
local function EffectHambat(owner, target)
    if owner and owner:IsValid() then
        if owner.components.hunger then owner.components.hunger:DoDelta(6.8) end
        if owner.components.sanity then owner.components.sanity:DoDelta(6.8) end
        if owner.components.health then owner.components.health:DoDelta(6.8) end
    end
end

-- 暗影剑: 目标易伤(5秒内挨打多掉50%血)
local function EffectNightsword(owner, target)
    if not target:IsValid() or not target.components.combat then return end
    target.components.combat.externaldamagetakenmultipliers:SetModifier(target, 1.5, "sword_shadow_vuln2hm")
    if target._sword_vulntask2hm then target._sword_vulntask2hm:Cancel() end
    target._sword_vulntask2hm = target:DoTaskInTime(5, function(t)
        if t:IsValid() and t.components.combat then
            t.components.combat.externaldamagetakenmultipliers:RemoveModifier(t, "sword_shadow_vuln2hm")
        end
        t._sword_vulntask2hm = nil
    end)
end

-- 玻璃刀: 辉煌标记
local function EffectGlasscutter(owner, target)
    if not target:IsValid() or not target.components.health then return end
    if target._sword_brilliance_hooked2hm then
        -- 已有标记: 刷新持续时间
        if target._sword_brilliance_task2hm then target._sword_brilliance_task2hm:Cancel() end
        target._sword_brilliance_task2hm = target:DoTaskInTime(30, function(t)
            if t:IsValid() and t._sword_brilliance_hooked2hm then
                t._sword_brilliance_hooked2hm = nil
                if t._sword_brilliance_fn2hm then t:RemoveEventCallback("attacked", t._sword_brilliance_fn2hm) end
                t._sword_brilliance_fn2hm = nil
                if t._sword_brilliance_fx2hm and t._sword_brilliance_fx2hm:IsValid() then t._sword_brilliance_fx2hm:Remove() end
                t._sword_brilliance_fx2hm = nil
            end
        end)
        return
    end
    target._sword_brilliance_hooked2hm = true
    local function onattacked(t)
        if t:IsValid() and t.components.health and not t.components.health:IsDead() then
            t.components.health:DoDelta(-34)
        end
    end
    target._sword_brilliance_fn2hm = onattacked
    target:ListenForEvent("attacked", onattacked)
    -- 原版辉煌标记发光fx(挂在目标身上,玩家可见)
    local markfx = SpawnPrefab("slingshotammo_purebrilliance_debuff_fx")
    if markfx then
        -- 无AnimState的目标(如巨大洞穴蠕虫)挂不上辉煌标记fx,跳过避免崩溃
        if target.AnimState then
            markfx:AttachTo(target)
            target._sword_brilliance_fx2hm = markfx
        else
            markfx:Remove()
        end
    end
    target._sword_brilliance_task2hm = target:DoTaskInTime(30, function(t)
        if t:IsValid() and t._sword_brilliance_hooked2hm then
            t._sword_brilliance_hooked2hm = nil
            if t._sword_brilliance_fn2hm then t:RemoveEventCallback("attacked", t._sword_brilliance_fn2hm) end
            t._sword_brilliance_fn2hm = nil
            if t._sword_brilliance_fx2hm and t._sword_brilliance_fx2hm:IsValid() then t._sword_brilliance_fx2hm:Remove() end
            t._sword_brilliance_fx2hm = nil
        end
    end)
end

-- 铥矿棒: 目标周围召唤3个暗影触手
local function EffectRuinsBat(owner, target)
    if not target:IsValid() then return end
    local pt = target:GetPosition()
    for i = 1, 3 do
        local offset = FindWalkableOffset(pt, math.random() * TWOPI, 1, 3, false, true, NoHoles, false, true, true)
        if offset ~= nil then
            local tentacle = SpawnPrefab("shadowtentacle")
            if tentacle ~= nil then
                tentacle.owner = owner
                tentacle.Transform:SetPosition(pt.x + offset.x, 0, pt.z + offset.z)
                tentacle.components.combat:SetTarget(target)
            end
        end
    end
end

-- 恐怖盾牌: 玩家获得50%额外减伤,持续5秒
local function EffectShieldOfTerror(owner, target)
    if owner and owner:IsValid() and owner.components.combat then
        owner.components.combat.externaldamagetakenmultipliers:SetModifier(owner, 0.5, "sword_shadow_shield2hm")
        if owner._sword_shieldtask2hm then owner._sword_shieldtask2hm:Cancel() end
        owner._sword_shieldtask2hm = owner:DoTaskInTime(5, function(p)
            if p:IsValid() and p.components.combat then
                p.components.combat.externaldamagetakenmultipliers:RemoveModifier(p, "sword_shadow_shield2hm")
            end
            p._sword_shieldtask2hm = nil
        end)
    end
end

-- 亮茄剑: 对boss额外造成1%最大生命值伤害
local function EffectSwordLunarplant(owner, target)
    if target and target:IsValid() and target:HasTag("epic") and target.components.health and not target.components.health:IsDead() then
        target.components.health:DoDelta(-target.components.health.maxhealth * 0.01)
    end
end

-- 影人武器顺序表
local SHADOW_WEAPONS = {
    {prefab = "spear",            build = "swap_spear",          symbol = "swap_spear"},
    {prefab = "tentaclespike",    build = "swap_spike",          symbol = "swap_spike",            effect = EffectTentaclespike},
    {prefab = "hambat",           build = "swap_ham_bat",        symbol = "swap_ham_bat",          effect = EffectHambat},
    {prefab = "nightsword",       build = "swap_nightmaresword", symbol = "swap_nightmaresword",   effect = EffectNightsword},
    {prefab = "glasscutter",      build = "swap_glasscutter",    symbol = "swap_glasscutter",      effect = EffectGlasscutter},
    {prefab = "ruins_bat",        build = "swap_ruins_bat",      symbol = "swap_ruins_bat",        effect = EffectRuinsBat},
    {prefab = "shieldofterror",   build = "swap_eye_shield",     symbol = "swap_shield",     sym = "lantern_overlay", effect = EffectShieldOfTerror},
    {prefab = "sword_lunarplant", build = "sword_lunarplant",    symbol = "swap_sword_lunarplant", effect = EffectSwordLunarplant},
}

-- 按顺序取下一个武器(循环), 计数存在剑实例上(每把剑独立)
local function NextWeapons(sword, count)
    local list = {}
    local idx = sword._sword_shadow_idx2hm or 1
    for i = 1, count do
        list[i] = SHADOW_WEAPONS[idx]
        idx = idx + 1
        if idx > #SHADOW_WEAPONS then idx = 1 end
    end
    sword._sword_shadow_idx2hm = idx
    return list
end

-- 生成1个影人: 指定武器,复制玩家外观,手持对应武器冲目标,造成武器同额伤害并触发附加效果后消失
local function SpawnShadowAttack(owner, target, weaponinfo)
    if not owner:IsValid() or not target:IsValid() or not target.components.combat then return end
    -- 生成武器实体取伤害,取完销毁
    local weapon = SpawnPrefab(weaponinfo.prefab)
    if not weapon then return end
    local dmg = weapon.components.weapon and weapon.components.weapon:GetDamage() or 34
    weapon:Remove()
    -- 生成影人: 复制玩家外观+指定武器外观+伤害+附加效果+冲刺目标
    local shadow = SpawnPrefab("passive_shadow_fx2hm")
    if not shadow then return end
    shadow:SetShadowOwner2hm(owner)
    shadow:SetShadowWeapon2hm(weaponinfo.build, weaponinfo.symbol, weaponinfo.sym)
    shadow:SetDamage(dmg)
    if weaponinfo.effect then shadow:SetShadowEffect2hm(weaponinfo.effect) end
    -- 目标周围随机偏移,避免3个影人完全重叠
    local theta = math.random() * TWOPI
    local r = 1 + math.random() * 1.5
    shadow:SetTarget(target, Vector3(r * math.cos(theta), 0, -r * math.sin(theta)))
end

-- 升级: 攻击距离增强 + 攻击时按顺序召唤3个影人
local function ApplySwordUpgrade(sword)
    if not sword:IsValid() then return end
    sword._sword_shadow2hm = true
    sword:AddTag(SWORD_SHADOW_TAG)
    if sword.components.weapon then
        -- 攻击距离+20%
        if not sword._sword_range2hm then
            sword._sword_range2hm = true
            sword.components.weapon.attackrange = (sword.components.weapon.attackrange or 0) + SWORD_ATTACK_RANGE_BONUS
            sword.components.weapon.hitrange = (sword.components.weapon.hitrange or 0) + SWORD_ATTACK_RANGE_BONUS
        end
        -- 影人
        local oldonattack = sword.components.weapon.onattack
        if oldonattack ~= sword._sword_onattack_wrap2hm then
            sword._sword_onattack_wrap2hm = function(inst, attacker, target, skipsanity)
                if oldonattack then oldonattack(inst, attacker, target, skipsanity) end
                if attacker and attacker:IsValid() and target and target:IsValid() and not target:HasTag("playerghost") then
                    -- 每次攻击3个影人,武器按顺序循环(第一刀:长矛/触手刺/火腿棒)
                    local weapons = NextWeapons(inst, 3)
                    for i = 1, #weapons do
                        SpawnShadowAttack(attacker, target, weapons[i])
                    end
                end
            end
            sword.components.weapon.onattack = sword._sword_onattack_wrap2hm
        end
    end
end

-- 亮茄剑: 天体珠宝升级
AddPrefabPostInit("sword_lunarplant", function(inst)
    inst.repairmaterials2hm = {lunar_seed = 1}
    inst.repairtext2hm = "UPGRADE" -- 右键动作文字
    local oldname = inst.displaynamefn
    inst.displaynamefn = function()
        if inst:HasTag(SWORD_SHADOW_TAG) then
            return (TUNING.isCh2hm and "附魔亮茄剑" or "Infused Sword Lunarplant")
        end
        return oldname and oldname(inst)
    end
    if not TheWorld.ismastersim then return end
    inst:AddComponent("persistent2hm")
    inst:AddComponent("repairable2hm")
    inst.components.repairable2hm.ignoremax = true -- 满耐久也能升级
    inst.components.repairable2hm.customrepair = function(sword, repairuse, doer, repair_item)
        if sword:HasTag(SWORD_SHADOW_TAG) then
            return false -- 已升级,不再消耗天体珠宝
        end
        -- 只消耗1个珠宝
        if repair_item and repair_item:IsValid() then
            if repair_item.components.stackable then
                repair_item.components.stackable:Get(1):Remove()
            else
                repair_item:Remove()
            end
        end
        ApplySwordUpgrade(sword)
        return true -- 已自行处理消耗,不再走默认流程
    end
    -- 修复后重新应用升级效果
    if inst.components.forgerepairable then
        local _forgerep = inst.components.forgerepairable.onrepaired
        inst.components.forgerepairable.onrepaired = function(inst, ...)
            if _forgerep then _forgerep(inst, ...) end
            if inst:HasTag(SWORD_SHADOW_TAG) then
                ApplySwordUpgrade(inst)
            end
        end
    end
    -- 持久化升级状态
    SetOnSave2hm(inst, function(i, data) data.sword_shadow2hm = i._sword_shadow2hm or nil end)
    SetOnLoad2hm(inst, function(i, data)
        if data and data.sword_shadow2hm then ApplySwordUpgrade(i) end
    end)
end)

-- 升级动作文字
STRINGS.ACTIONS.REPAIR2HM.UPGRADE = TUNING.isCh2hm and "升级" or "Upgrade"
