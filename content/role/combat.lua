local SpDamageUtil = require("components/spdamageutil")
local mode = GetModConfigData("combat")
if mode == 4 then
    modimport("role/combat_progressive.lua")
    return
end
-- 伤害细节显示
local attackstatustip
local tiplength = 0
local function processexternaldamagemultipliers(v, mults, spmults, info)
    table.insert(mults, v._base or 1)
    if info and v._base and v._base ~= 1 then
        attackstatustip = attackstatustip .. "\n" .. tostring(v._base) .. info ..
                              (spmults and (TUNING.isCh2hm and "(支持特殊伤害)" or "(also Special dmg)") or "")
        tiplength = tiplength + 1
    end
    if spmults then table.insert(spmults, v._base or 1) end
    for source, src_params in pairs(v._modifiers) do
        for k, m in pairs(src_params.modifiers) do
            table.insert(mults, m or 1)
            if info and m and m ~= 1 then
                attackstatustip = attackstatustip .. "\n" .. tostring(m) .. info ..
                                      (k and k ~= "key" and type(k) == "string" and ((TUNING.isCh2hm and " 键 " or " Key ") .. k) or "") ..
                                      (source and (EntityScript.is_instance(source) or type(source) == "string") and
                                          ((TUNING.isCh2hm and " 源 " or " Src ") .. (source.name or source.prefab or source)) or "") ..
                                      (spmults and (TUNING.isCh2hm and " (支持特殊伤害)" or " (also Special dmg)") or "")
                tiplength = tiplength + 1
            end
            if spmults then table.insert(spmults, m or 1) end
        end
    end
end
local function processdamagetypebonus(self, target, mults, spmults, info)
    if target then
        for k, v in pairs(self.tags) do
            if target:HasTag(k) and v then
                processexternaldamagemultipliers(v, mults, spmults, info and
                                                     (info .. (TUNING.isCh2hm and "对" or " For ") .. k ..
                                                         (TUNING.isCh2hm and "标签伤害" or "Tag Dmg Mult")))
            end
        end
    end
end
local sptypenames = {planar = TUNING.isCh2hm and "[位面]" or "[planar]", medal_chaos = TUNING.isCh2hm and "[混沌]" or "[medal_chaos]"}
local function SpDamageUtilCollectSpDamage(ent, tbl, info)
    for sptype in pairs(SpDamageUtil._SpTypeMap) do
        local dmg = SpDamageUtil.GetSpDamageForType(ent, sptype)
        if dmg > 0 then
            if info then
                attackstatustip = attackstatustip .. "\n" ..
                                      (info .. (TUNING.isCh2hm and "特殊伤害" or " Special dmg") .. (sptypenames[sptype] or ("[" .. sptype .. "]")) ..
                                          ("：" .. tostring(dmg)))
                tiplength = tiplength + 1
            end
            tbl = tbl or {}
            tbl[sptype] = (tbl[sptype] or 0) + dmg
        end
    end
    return tbl
end
local function printspdamge(spdamage, info)
    for sptype in pairs(SpDamageUtil._SpTypeMap) do
        local dmg = spdamage[sptype]
        if dmg and dmg > 0 then
            attackstatustip = attackstatustip .. "\n" .. (info .. (sptypenames[sptype] or ("[" .. sptype .. "]")) .. ("：" .. tostring(dmg)))
            tiplength = tiplength + 1
        end
    end
end
local function cancelcdshowtask2hm(inst) inst.inspectstatustaskcd2hm = nil end
local function saytext(inst, self, text, time) self:Say(text, time or 20, true, true) end

local function canceldmgandspeed2hm(inst)
    inst.canceldmgandspeedtaskcd2hm = nil
    if inst.components.health then inst.components.health.externalabsorbmodifiers:RemoveModifier(inst, "damagemult_2hm") end
    if inst.components.locomotor then inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "damagemult_2hm") end
end

local function GetSpeedMultiplier(x)
    local base = 1.0
    local pivot_x = 1.5
    local pivot_y = 1.25
    
    if x <= 0 then
        return base
    elseif x <= pivot_x then
        local slope = (pivot_y - base) / pivot_x
        return base + slope * x
    else
        -- 之前猪pig用的log函数，在大于0的定义域存在值域负的，现在用arctan
        return pivot_y + 0.05 * math.atan(x - pivot_x)
    end
end

local function GetDamageMultiplier(x)
    local base = 0
    local pivot_x = 1.5
    local pivot_y = 0.15
    
    if x <= 0 then
        return base
    elseif x <= pivot_x then
        local slope = (pivot_y - base) / pivot_x
        return base + slope * x
    else
        return pivot_y + 0.05 * math.atan(x - pivot_x)
    end
end

local function NewCalcDamage(self, target, weapon, multiplier)
    if target:HasTag("alwaysblock") then return 0 end

    local printinfo = self.inspectstatus2hm and not self.inst.inspectstatustaskcd2hm
    if printinfo then
        attackstatustip = ""
        tiplength = 1
        self.inst.inspectstatustaskcd2hm = self.inst:DoTaskInTime(3, cancelcdshowtask2hm)
    else
        attackstatustip = nil
        tiplength = 0
    end

    local mults = {}
    local spmults = {}
    local basedamage
    local spdamage
    -- 需要后续读取的加成列表和相关信息
    local isplayertarget = target ~= nil and target:HasTag("player")
    local mount
    local basemultiplier = self.damagemultiplier
    local externaldamagemultipliers = self.externaldamagemultipliers -- 许多加成
    local bonus = self.damagebonus -- not affected by multipliers
    local externalinjured -- 目标额外易伤

    -- NOTE: playermultiplier is for damage towards players
    --      generally only applies for NPCs attacking players

    if weapon ~= nil and weapon.components.weapon ~= nil then
        -- No playermultiplier when using weapons
        -- basedamage, spdamage = weapon.components.weapon:GetDamage(self.inst, target)
        basedamage = FunctionOrValue(weapon.components.weapon.damage, weapon, self.inst, target) or 0
        if printinfo then
            attackstatustip = attackstatustip .. "\n" .. ((TUNING.isCh2hm and "武器伤害：" or "Weapon Dmg：") .. tostring(basedamage))
            tiplength = tiplength + 1
        end
        -- #DiogoW: entity's own SpDamage stacks with weapon's SpDamage
        spdamage = SpDamageUtilCollectSpDamage(self.inst, spdamage, printinfo and (TUNING.isCh2hm and "角色" or " Role"))
        spdamage = SpDamageUtilCollectSpDamage(weapon, spdamage, printinfo and (TUNING.isCh2hm and "武器" or " Weapon"))
        -- #V2C: entity's own damagetypebonus stacks with weapon's damagetypebonus
        if self.inst.components.damagetypebonus ~= nil then
            processdamagetypebonus(self.inst.components.damagetypebonus, target, mults, spmults, printinfo and (TUNING.isCh2hm and "倍 角色" or " Role"))
        end
        if weapon.components.damagetypebonus ~= nil then
            processdamagetypebonus(weapon.components.damagetypebonus, target, mults, spmults, printinfo and (TUNING.isCh2hm and "倍 武器" or "Weapon"))
        end
    else
        if self.inst.components.rider ~= nil and self.inst.components.rider:IsRiding() then
            mount = self.inst.components.rider:GetMount()
            if mount ~= nil and mount.components.combat ~= nil then
                basedamage = mount.components.combat.defaultdamage
                if printinfo then
                    attackstatustip = attackstatustip .. "\n" .. ((TUNING.isCh2hm and "坐骑伤害：" or "Mount Dmg：") .. tostring(basedamage or 0))
                    tiplength = tiplength + 1
                end
                spdamage = SpDamageUtilCollectSpDamage(mount, spdamage, printinfo and (TUNING.isCh2hm and "坐骑" or " Mount"))
                basemultiplier = mount.components.combat.damagemultiplier
                externaldamagemultipliers = mount.components.combat.externaldamagemultipliers
                bonus = mount.components.combat.damagebonus
                if mount.components.damagetypebonus ~= nil then
                    processdamagetypebonus(mount.components.damagetypebonus, target, mults, spmults, printinfo and (TUNING.isCh2hm and "倍 坐骑" or " Mount"))
                end
                local saddle = self.inst.components.rider:GetSaddle()
                if saddle ~= nil and saddle.components.saddler ~= nil then
                    local saddlebonusdmg = saddle.components.saddler:GetBonusDamage()
                    basedamage = basedamage + saddlebonusdmg
                    if printinfo and saddlebonusdmg and saddlebonusdmg ~= 0 then
                        attackstatustip = attackstatustip .. "\n" ..
                                              ((TUNING.isCh2hm and "牛鞍额外伤害：" or "Saddle Extra Dmg：") .. tostring(saddlebonusdmg))
                        tiplength = tiplength + 1
                    end
                    spdamage = SpDamageUtilCollectSpDamage(saddle, spdamage, printinfo and (TUNING.isCh2hm and "牛鞍" or " Saddle"))
                    if saddle.components.damagetypebonus ~= nil then
                        processdamagetypebonus(saddle.components.damagetypebonus, target, mults, spmults,
                                               printinfo and (TUNING.isCh2hm and "倍 牛鞍" or " Saddle"))
                    end
                end
            end
        end
        if mount == nil or mount.components.combat == nil then
            basedamage = self.defaultdamage
            if printinfo then
                attackstatustip = attackstatustip .. "\n" .. ((TUNING.isCh2hm and "角色伤害：" or "Role Dmg：") .. tostring(basedamage or 0))
                tiplength = tiplength + 1
            end
            spdamage = SpDamageUtilCollectSpDamage(self.inst, spdamage, printinfo and (TUNING.isCh2hm and "角色" or " Role"))
            if self.inst.components.damagetypebonus ~= nil then
                processdamagetypebonus(self.inst.components.damagetypebonus, target, mults, spmults, printinfo and (TUNING.isCh2hm and "倍 角色" or " Role"))
            end
        end
        local playermultiplier = isplayertarget and self.playerdamagepercent or 1
        table.insert(mults, playermultiplier)
        if printinfo and playermultiplier and playermultiplier ~= 1 then
            attackstatustip = attackstatustip .. "\n" .. tostring(playermultiplier) ..
                                  (TUNING.isCh2hm and "倍 对角色空手伤害" or " Role For player EmptyHands Dmg Mult")
            tiplength = tiplength + 1
        end
    end
    -- 可以直接得到的加成列表
    table.insert(mults, multiplier or 1)
    if printinfo and multiplier and multiplier ~= 1 then
        attackstatustip = attackstatustip .. "\n" .. tostring(multiplier) ..
                              (TUNING.isCh2hm and "倍 带电伤害或范围伤害" or " Electric/Areaattack Dmg Mult")
        tiplength = tiplength + 1
    end
    local pvpmultiplier = isplayertarget and self.inst:HasTag("player") and self.pvp_damagemod or 1
    table.insert(mults, pvpmultiplier)
    if printinfo and pvpmultiplier and pvpmultiplier ~= 1 then
        attackstatustip = attackstatustip .. "\n" .. tostring(pvpmultiplier) ..
                              (TUNING.isCh2hm and "倍 角色互相伤害(支持特殊伤害)" or " Role PVP Dmg Mult")
        tiplength = tiplength + 1
    end
    table.insert(spmults, pvpmultiplier)
    -- 后续读取加成列表完毕
    table.insert(mults, basemultiplier or 1)
    if printinfo and basemultiplier and basemultiplier ~= 1 then
        attackstatustip = attackstatustip .. "\n" .. tostring(basemultiplier) ..
                              (mount ~= nil and mount.components.combat ~= nil and (TUNING.isCh2hm and "倍 坐骑伤害系数" or " Mount Dmg Mult") or
                                  (TUNING.isCh2hm and "倍 角色伤害" or " Role Dmg Mult"))
        tiplength = tiplength + 1
    end
    processexternaldamagemultipliers(externaldamagemultipliers, mults, nil,
                                     printinfo and
                                         ((mount ~= nil and mount.components.combat ~= nil and
                                             (TUNING.isCh2hm and "倍 坐骑额外伤害" or " Mount Extra Dmg Mult") or
                                             (TUNING.isCh2hm and "倍 角色额外伤害" or " Role Extra Dmg Mult"))))
    table.insert(mults, (bonus or 0) + 1)
    if printinfo and bonus and bonus ~= 0 then
        attackstatustip = attackstatustip .. "\n" .. tostring(bonus + 1) ..
                              (mount ~= nil and mount.components.combat ~= nil and (TUNING.isCh2hm and "倍 坐骑伤害增幅" or " Mount Dmg Bonus") or
                                  (TUNING.isCh2hm and "倍 角色伤害增幅" or " Role Dmg Bonus"))
        tiplength = tiplength + 1
    end
    if self.customdamagemultfn ~= nil then
        local mult = self.customdamagemultfn(self.inst, target, weapon, multiplier, mount) or 1
        table.insert(mults, mult)
        if printinfo and mult and mult ~= 1 then
            attackstatustip = attackstatustip .. "\n" .. tostring(mult) .. (TUNING.isCh2hm and "倍 角色自适应伤害" or " Role Custrom Dmg Mult")
            tiplength = tiplength + 1
        end
    end
    if target and target:IsValid() and target.components.combat and target.components.combat.externaldamagetakenmultipliers:Get() and target.components.combat.externaldamagetakenmultipliers:Get() ~= 1 then
        externalinjured = target.components.combat.externaldamagetakenmultipliers:Get()
        if printinfo then
            attackstatustip = attackstatustip .. "\n" .. tostring(externalinjured) .. (TUNING.isCh2hm and "倍 目标额外受伤倍率" or " Target Injured Dmg Mult")
            tiplength = tiplength + 1
        end
    end
    -- 最后伤害计算
    local damage = basedamage or 0
    local all
    local extra
    local specialroles = {
        wathom = 4,
        wolfgang = 3.5,
    }
    local maxmult_ = specialroles[self.inst.prefab] or 2.5
    if damage ~= 0 then
        local mult = 1
        if mode == 2 then -- 2025.10.4 melon:小于1.5的倍率乘算，大于等于1.5的倍率加算，先乘算完再加算
            local add = 0
            for _, v in ipairs(mults) do
                if v >= 1.5 then
                    add = add + (v - 1)
                else
                    mult = mult * v
                end
            end
            mult = mult + add
        elseif mode == 3 then -- 封顶计算
            for _, v in ipairs(mults) do mult = mult * v end
            all = mult
            local whitemult
            if self.externaldamagemultipliers.CalculateModifierFromKey then
                if self.externaldamagemultipliers:CalculateModifierFromKey("glasscutter2hm") or self.externaldamagemultipliers:CalculateModifierFromKey("nightsword2hm") then
                    whitemult = self.externaldamagemultipliers:CalculateModifierFromKey("glasscutter2hm") or self.externaldamagemultipliers:CalculateModifierFromKey("nightsword2hm")
                end
                mult = mult / whitemult
            end
            if mult > maxmult_ then
                extra = mult - maxmult_
                mult = maxmult_
            end
            if whitemult ~= nil then
                mult = mult * whitemult
            end
            -- local maxmult = 1
            -- local extramult = 1
            -- for _, v in ipairs(mults) do
            --     if v > 1 then
            --         extramult = extramult + (v - 1) / 2
            --         if v > maxmult then maxmult = v end
            --     elseif v < 1 then
            --         mult = mult * v
            --     end
            -- end
            -- if maxmult > 1 then
            --     extramult = extramult - (maxmult - 1) / 2
            --     mult = mult * (maxmult + math.min(extramult, maxmult) - 1)
            -- end
        else -- 原本
            for _, v in ipairs(mults) do mult = mult * v end
        end
        if printinfo and mult and mult ~= 1 then
            local calc = mode == 2 and (TUNING.isCh2hm and "[算法：小于1.5的倍率乘算，大于等于1.5的倍率加算，先乘算完再加算]" or "[<1.5 -> mult, >=1.5 -> add, first mult then add]") or -- 2025.10.4 melon:先乘后加
                        mode == 3 and (TUNING.isCh2hm and "[算法：倍率乘算且封顶为" .. tostring(maxmult_) .. "倍，余出部分转化为减伤和移速加成]" or "[" .. tostring(maxmult_) .. " max mult, excess part is converted into damage reduction and speed bonus]") or -- 全加算
                        "" -- 原本
            attackstatustip = attackstatustip .. (mode == 3 and all ~= nil and ("\n" .. tostring(all * (externalinjured or 1)) .. (TUNING.isCh2hm and "倍 倍率总和" or " Sum Of Multiples")) or "") ..
                                  "\n" .. tostring(mult * (externalinjured or 1)) .. (TUNING.isCh2hm and "倍 结算伤害加成累计" or " Final Dmg Mult") .. calc ..
                                  (TUNING.isCh2hm and "\n原始伤害：" or "\nOriginal Dmg：") .. tostring(damage) ..
                                  (TUNING.isCh2hm and " >> 结算伤害：" or "Final Dmg：") .. tostring(damage * mult * (externalinjured or 1))
            tiplength = tiplength + 2
        end
        damage = damage * mult
    end
    if spdamage ~= nil then
        local mult = 1
        if mode == 2 then -- 2025.10.4 melon:先乘后加
            local add = 0
            for _, v in ipairs(spmults) do
                if v >= 1.5 then
                    add = add + (v - 1)
                else
                    mult = mult * v
                end
            end
            mult = mult + add
        elseif mode == 3 then -- 封顶计算
            for _, v in ipairs(mults) do mult = mult * v end
            if all ~= nil and all < mult then
                all = mult
            elseif all == nil then
                all = mult
            end
            if mult > maxmult_ then
                if extra ~= nil and extra < mult - maxmult_ then
                    extra = mult - maxmult_
                elseif extra == nil then
                    extra = mult - maxmult_
                end
                mult = maxmult_
            end
            -- local maxmult = 1
            -- local extramult = 1
            -- for _, v in ipairs(spmults) do
            --     if v > 1 then
            --         extramult = extramult + (v - 1) / 2
            --         if v > maxmult then maxmult = v end
            --     elseif v < 1 then
            --         mult = mult * v
            --     end
            -- end
            -- if maxmult > 1 then
            --     extramult = extramult - (maxmult - 1) / 2
            --     mult = mult * (maxmult + math.min(extramult, maxmult) - 1)
            -- end
            -- mult = mult * (maxmult + math.min(extramult, maxmult) - 1) -- melon:多写了一遍?
        else -- 原本
            for _, v in ipairs(spmults) do mult = mult * v end
        end
        if printinfo and mult and mult ~= 1 then
            printspdamge(spdamage, (TUNING.isCh2hm and "原始特殊伤害" or "Original Special Dmg"))
            attackstatustip = attackstatustip .. "\n" .. tostring(mult) .. (TUNING.isCh2hm and "倍 特殊伤害加成累计" or " Final Special Dmg Mult")
            tiplength = tiplength + 1
        end
        if mult ~= 1 then spdamage = SpDamageUtil.ApplyMult(spdamage, mult) end
        if printinfo and mult and mult ~= 1 then printspdamge(spdamage, (TUNING.isCh2hm and ">>结算特殊伤害" or "Final Special Dmg")) end
    end
    if mode == 3 and extra ~= nil then
        local speedmult = 0
        local damagemult = 0
        self.inst.components.health.externalabsorbmodifiers:RemoveModifier(self.inst, "damagemult_2hm")
        if 1 - ((1 - self.inst.components.health.externalabsorbmodifiers:Get()) * (1 - self.inst.components.health.absorb)) < 0.4 then
            extra = extra / 2
            damagemult = GetDamageMultiplier(extra)
            self.inst.components.health.externalabsorbmodifiers:SetModifier(self.inst, damagemult, "damagemult_2hm")
        end
        if self.inst and self.inst.components.locomotor then
            speedmult = GetSpeedMultiplier(extra)
            self.inst.components.locomotor:SetExternalSpeedMultiplier(self.inst, "damagemult_2hm", speedmult)
        end
        if self.inst.canceldmgandspeedtaskcd2hm then
            self.inst.canceldmgandspeedtaskcd2hm:Cancel()
        end
        self.inst.canceldmgandspeedtaskcd2hm = self.inst:DoTaskInTime(5, function()
            canceldmgandspeed2hm(self.inst)
        end)
        if printinfo then
            attackstatustip = attackstatustip .. "\n" .. (TUNING.isCh2hm and "转化的减伤百分比" or "Converted damage reduction percentage") .. tostring(damagemult * 100) .. 
            "    " .. (TUNING.isCh2hm and "转化的移速百分比" or "Converted speed percentage") .. tostring((speedmult - 1) * 100)
        end
    end
    if printinfo and attackstatustip then
        if self.inst.components.talker then
            local time = 1 + tiplength * 2
            attackstatustip = (TUNING.isCh2hm and "[为爽而虐]攻击伤害计算显示,冷却3秒,本次显示" or
                                  "HappyPatch Damage Status Display,cd 3s,show") .. time .. (TUNING.isCh2hm and "秒" or "s") .. attackstatustip
            self.inst:DoTaskInTime(0.1, saytext, self.inst.components.talker, attackstatustip, time)
        end
        tiplength = 0
        attackstatustip = nil
    end
    return damage, spdamage
end
local function processplayercombat(inst) if inst.components.combat then inst.components.combat.CalcDamage = NewCalcDamage end end
if mode == 2 then
    AddPlayerPostInit(function(inst)
        if not TheWorld.ismastersim then return end
        inst:DoTaskInTime(1, processplayercombat)
    end)
elseif mode == 3 then
    local MAXMULT2HM = 2.5
    local specialroles = {
        wathom = 4,
        wolfgang = 3.5,
    }
    local function applyextra2hm(inst, extra)
        if inst.components.health == nil then return end
        local speedmult = 0
        local damagemult = 0
        inst.components.health.externalabsorbmodifiers:RemoveModifier(inst, "damagemult_2hm")
        if 1 - ((1 - inst.components.health.externalabsorbmodifiers:Get()) * (1 - inst.components.health.absorb)) < 0.4 then
            extra = extra / 2
            damagemult = GetDamageMultiplier(extra)
            inst.components.health.externalabsorbmodifiers:SetModifier(inst, damagemult, "damagemult_2hm")
        end
        if inst.components.locomotor then
            speedmult = GetSpeedMultiplier(extra)
            inst.components.locomotor:SetExternalSpeedMultiplier(inst, "damagemult_2hm", speedmult)
        end
        if inst.canceldmgandspeedtaskcd2hm then
            inst.canceldmgandspeedtaskcd2hm:Cancel()
        end
        inst.canceldmgandspeedtaskcd2hm = inst:DoTaskInTime(5, function()
            canceldmgandspeed2hm(inst)
        end)
    end
    AddPlayerPostInit(function(inst)
        if not TheWorld.ismastersim then return end
        inst:DoTaskInTime(1, function(inst)
            local combat = inst.components.combat
            if combat == nil or combat.customdamagemultfn2hm then return end
            local oldfn = combat.customdamagemultfn
            local wrapper = function(self, target, weapon, multiplier, mount)
                local custom = 1
                if oldfn ~= nil then
                    custom = oldfn(self, target, weapon, multiplier, mount) or 1
                end
                local maxmult = specialroles[inst.prefab] or MAXMULT2HM
                local other = combat.damagemultiplier or 1
                if combat.externaldamagemultipliers ~= nil then
                    other = other * (combat.externaldamagemultipliers:Get() or 1)
                end
                other = other * ((combat.damagebonus or 0) + 1)
                other = other * (multiplier or 1)
                local total = other * custom
                if total <= maxmult then return custom end
                applyextra2hm(inst, total - maxmult)
                if other <= 0 then return custom end
                return maxmult / other
            end
            combat.customdamagemultfn2hm = wrapper
            combat.customdamagemultfn = wrapper
        end)
    end)
end
-- 显示开关
-- Legacy modes keep their own calculations; inspection must not replace them.
if mode ~= 2 then
    local Report = require("combatdisplay2hm")
    AddComponentPostInit("combat", function(combat)
        if not TheWorld.ismastersim then return end
        local previous = combat.CalcDamage
        combat.CalcDamage = function(self, ...)
            local damage, special = previous(self, ...)
            if self.inst:HasTag("player") then Report(self.inst, damage, special) end
            return damage, special
        end
    end)
end
local function wheninspectpunchingbag(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.inspectable then
        local GetDescription = inst.components.inspectable.GetDescription
        inst.components.inspectable.GetDescription = function(self, viewer, ...)
            local txt
            if viewer and viewer:IsValid() and viewer.userid and viewer.components.combat then
                viewer.components.combat.inspectstatus2hm = not viewer.components.combat.inspectstatus2hm
                txt = viewer.components.combat.inspectstatus2hm and
                          (TUNING.isCh2hm and "\n\n[为爽而虐]攻击伤害计算显示已开启\n检查拳击袋开关此功能" or
                              "\n\nHappyPatch Damage Status Display Now open\nInspect punching bag to close") or
                          (TUNING.isCh2hm and "\n\n[为爽而虐]攻击伤害计算显示已关闭\n检查拳击袋开关此功能" or
                              "\n\nHappyPatch Damage Status Display Now close\nInspect punching bag to open")
            end
            local desc, filter_context, author = GetDescription(self, viewer, ...)
            desc = (desc or "") .. (txt or "")
            return desc, filter_context, author
        end
    end
end
AddPrefabPostInit("punchingbag", wheninspectpunchingbag)
AddPrefabPostInit("punchingbag_lunar", wheninspectpunchingbag)
AddPrefabPostInit("punchingbag_shadow", wheninspectpunchingbag)
AddPrefabPostInit("punchingbag_chaos", wheninspectpunchingbag)
