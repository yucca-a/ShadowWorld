local beefalochange = GetModConfigData("Random sized beefalo") == 1
local woodiemooserandomscale = GetModConfigData("Woodie Moose Random Scale")
--------让小鸭子变旋风时，大小不会被重置，前置准备。
AddPrefabPostInit("mossling", function(inst)
    if inst.components.sizetweener then
        local sizetweener = inst.components.sizetweener
        local oldStartTween = sizetweener.StartTween
        sizetweener.StartTween = function(self, size, ...)
            local my_size = self.inst.myscale or 1
            my_size = my_size > 1 and ((my_size - 1) / 2 + 1) or my_size
            local change
            if my_size >= 1 then
                size = 1.4
                change = 0.5
                my_size = math.min(my_size - 1, 0.5) / 0.5
                change = change * my_size
                size = size + change
            elseif my_size < 1 then
                size = 1.4
                change = 0.25
                my_size = math.min(1 - my_size, 0.25) / 0.25
                change = change * my_size
                size = size - change
            end
            oldStartTween(self, size, ...)
        end
        -- sizetweener.OnUpdate = function(self, dt)
        --     local my_size = self.inst.myscale or 1
        --     my_size = my_size > 1 and ((my_size - 1) / 2 + 1) or my_size
        --     self.timepassed = self.timepassed + dt
        --     if self.timepassed >= self.time then
        --         self:EndTween()
        --     elseif self.t_size ~= nil and self.i_size ~= nil then
        --         local s = Lerp(self.i_size, self.t_size, self.timepassed / self.time)
        --         self.inst.Transform:SetScale(s * my_size, s * my_size, s * my_size)
        --     end
        -- end
        -- local old = sizetweener.EndTween
        -- sizetweener.EndTween = function(self)
        --     old(self)
        --     if self.inst.myscale ~= nil then
        --         local my_size = self.inst.myscale or 1
        --         my_size = my_size > 1 and ((my_size - 1) / 2 + 1) or my_size
        --         local Scale = self.inst.Transform:GetScale()
        --         self.inst.Transform:SetScale(Scale * my_size, Scale * my_size, Scale * my_size)
        --     end
        -- end
    end
end)
-- -----------修改组件，重置大小时应该加什么属性
-- AddComponentPostInit("scaler", function(self)
--     local old_ApplyScale = self.ApplyScale
--     function self:ApplyScale()
--         old_ApplyScale(self)
--         local inst = self.inst
--         if inst.myscale ~= nil then
--             local Rand = inst.myscale
--             local Scale = inst.Transform:GetScale()
--             inst.Transform:SetScale(Scale * Rand, Scale * Rand, Scale * Rand)

--             if inst.components.health ~= nil then
--                 local percent = inst.components.health:GetPercent()
--                 inst.components.health:SetMaxHealth(math.ceil(inst.components.health.maxhealth * Rand))
--                 inst.components.health:SetPercent(percent)
--             end

--             if inst.components.combat then inst.components.combat.defaultdamage = math.ceil(inst.components.combat.defaultdamage * Rand) end

--         end
--     end
-- end)
------修改小牛的判断
AddPrefabPostInit("beefalo", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.combat then
        local oldSetDefaultDamage = inst.components.combat.SetDefaultDamage
        inst.components.combat.SetDefaultDamage = function(self, ...)
            local inst = self.inst
            local defaultdamage = inst.components.combat.defaultdamage
            return (inst.qianghuayici and defaultdamage) or oldSetDefaultDamage(self, ...)
        end
    end
    local oldSetTendency = inst.SetTendency
    inst.SetTendency = function(inst, ...)
        oldSetTendency(inst, ...)
        if beefalochange and inst.tendency == TENDENCY.PUDGY and inst.components.domesticatable:IsDomesticated()
            and inst.components.sanityaura and inst.myscale then
            inst:DoTaskInTime(0, function()
                local Rand = math.min(inst.myscale, 2)
                Rand = math.ceil(Rand * 100) / 100
                inst.components.sanityaura.aura = TUNING.SANITYAURA_TINY * Rand
            end)
        end
    end
end)

-----主代码，用来随机生物大小
-- Only ordinary meat portions are reduced; horns, trunks, hides and other
-- special drops keep their original quantities and chance rolls.
local SMALL_CREATURE_MEAT_LOOT = {
    meat = true, smallmeat = true, monstermeat = true, drumstick = true,
    froglegs = true, batwing = true, plantmeat = true, fishmeat = true, fishmeat_small = true,
    cookedmeat = true, cookedsmallmeat = true, cookedmonstermeat = true,
    drumstick_cooked = true, froglegs_cooked = true, batwing_cooked = true,
    plantmeat_cooked = true, fishmeat_cooked = true, fishmeat_small_cooked = true,
}
local function ReduceSmallCreatureMeat(loots, amount)
    local counts = {}
    for _, prefab in ipairs(loots) do
        if SMALL_CREATURE_MEAT_LOOT[prefab] then counts[prefab] = (counts[prefab] or 0) + 1 end
    end
    local reduce = false
    for prefab, count in pairs(counts) do
        counts[prefab] = math.min(amount, count - 1)
        if counts[prefab] > 0 then reduce = true end
    end
    if not reduce then return loots end
    local result = {}
    for _, prefab in ipairs(loots) do
        if counts[prefab] ~= nil and counts[prefab] > 0 then
            counts[prefab] = counts[prefab] - 1
        else
            result[#result + 1] = prefab
        end
    end
    return result
end
local function getrandomscale(inst)
    if inst.myscale then return inst.myscale end
    -- 区分有生命值和无生命值实体的概率分布：
    -- 有生命值：5% -> 1.40~2.00（其中 2% -> 1.40~1.80，3% -> 1.80~2.00，如果出大牛了，则更容易出完美属性牛），
    -- 有生命值：95% -> 0.75~1.30；当缩放 > 1.35 时判定为双倍掉落
    -- 无生命值：10% -> 1.50，90% -> 0.75~1.20；当缩放 > 1.30 时判定为双倍掉落
    local chance = math.random(100) -- 1..100
    local scale
    if inst:HasTag("_health") then
        if chance <= 2 then
            -- 2% 概率：1.40 ~ 1.80
            scale = math.random() * (1.8 - 1.4) + 1.4
        elseif chance <= 5 then
            -- 3% 概率：1.80 ~ 2.00
            scale = math.random() * (2.0 - 1.8) + 1.8
        else
            -- 95%：0.75 ~ 1.30
            scale = math.random() * (1.3 - 0.75) + 0.75
        end
    else
        if chance <= 10 then
            scale = 1.5
        else
            scale = math.random() * (1.2 - 0.75) + 0.75
        end
    end
    -- 保留两位小数，便于观察和调试
    return math.ceil(scale * 100) / 100
end
local function qianghua(inst, myscale, loot)
    if inst ~= nil and inst.qianghuayici == nil and inst.ray_suijidaxiao == 1 then
        inst.qianghuayici = 1 ---不允许在不重载的情况下，执行两次。
        local Rand = inst.myscale or myscale
        local sx, sy, sz = inst.Transform:GetScale()
        if not (sx and sy and sz) then return end -------无法获取就无法缩小，代码终止。
        local scaleRand = Rand > 1 and ((Rand - 1) / 2 + 1) or Rand
        inst.Transform:SetScale(sx * scaleRand, sy * scaleRand, sz * scaleRand)
        -- Scale+Scale*0.1*Rand
        ------下面则更改属性。
        if inst.components.aura and Rand > 1 then inst.components.aura.radius = inst.components.aura.radius * Rand end
        -------更改血量
        if inst.components.health ~= nil and not inst.myscalehealth2hm then
            local percent = inst.components.health:GetPercent()
            inst.components.health:SetMaxHealth(math.ceil(inst.components.health.maxhealth * Rand))
            inst.components.health:SetPercent(percent)
            inst.myscalehealth2hm = true
        end
        if inst.components.combat then
            -- 攻击范围和攻击距离只增加10%，避免过于夸张，
            -- 比如当Rand=2时，攻击范围和攻击距离增加100%就太离谱了，
            -- 现在改为增加20%（当Rand=2时，攻击范围和攻击距离增加20%），并且这个增加是线性的，而不是直接乘以Rand。
            inst.components.combat.hitrange = inst.components.combat.hitrange +
                0.1 * Rand * inst.components.combat.hitrange
            inst.components.combat.attackrange = inst.components.combat.attackrange +
                0.1 * Rand * inst.components.combat.attackrange

            -- inst.components.combat.hitrange = inst.components.combat.hitrange * Rand
            -- inst.components.combat.attackrange = inst.components.combat.attackrange * Rand
            -----更改攻击力
            if inst.components.domesticatable ~= nil and inst.components.domesticatable:IsDomesticated() then
                Rand = math
                    .min(Rand, 2)
            end
            if beefalochange and inst.prefab == "beefalo" and inst.components.domesticatable and inst.components.domesticatable:IsDomesticated() then
                local _Rand = Rand
                if _Rand > 1 then
                    if inst.tendency == TENDENCY.DEFAULT then
                        -- 无训势
                        _Rand = (_Rand - 1) / 2 + 1
                    elseif inst.tendency == TENDENCY.ORNERY then
                        -- 战牛
                        _Rand = _Rand
                    elseif inst.tendency == TENDENCY.RIDER then
                        -- 行牛
                        _Rand = 1
                    elseif inst.tendency == TENDENCY.PUDGY then
                        -- 肥牛
                        _Rand = 1
                    else
                        _Rand = 1
                    end
                end
                inst.components.combat.defaultdamage = math.ceil(inst.components.combat.defaultdamage * _Rand)
            elseif beefalochange and inst.prefab == "beefalo" and inst.components.domesticatable and not inst.components.domesticatable:IsDomesticated() then
                local _Rand = Rand
                if _Rand > 1 then
                    _Rand = (_Rand - 1) / 2 + 1
                end
                inst.components.combat.defaultdamage = math.ceil(inst.components.combat.defaultdamage * _Rand)
            else
                inst.components.combat.defaultdamage = math.ceil(inst.components.combat.defaultdamage * Rand)
            end
        end
        -- 更改掉落：根据是否有生命值使用不同阈值判定双倍掉落
        local drop_threshold = inst:HasTag("_health") and 1.35 or 1.3
        if Rand > drop_threshold then
            if loot and not inst:HasTag("structure") and not inst:HasTag("swc2hm") then ----更改目标战利品
                -- 为爽改动:大于阈值的生物才双倍掉落，便于明显区分
                if inst.components.lootdropper ~= nil then
                    local GenerateLoot = inst.components.lootdropper.GenerateLoot
                    inst.components.lootdropper.GenerateLoot = function(self, ...)
                        -- Traps and inventory murder use GenerateLoot directly.
                        -- Roll here so those paths share normal death's bonus.
                        local first = GenerateLoot(self, ...)
                        local result = {}
                        for _, prefab in ipairs(first) do result[#result + 1] = prefab end
                        for _, prefab in ipairs(GenerateLoot(self, ...)) do result[#result + 1] = prefab end
                        return result
                    end
                    if inst.prefab == "rock_ice" then
                        local SpawnLootPrefab = inst.components.lootdropper.SpawnLootPrefab
                        inst.components.lootdropper.SpawnLootPrefab = function(self, ...)
                            SpawnLootPrefab(self, ...)
                            return SpawnLootPrefab(self, ...)
                        end
                    end
                end
                if inst.prefab == "tumbleweed" and inst.loot ~= nil and next(inst.loot) then
                    local newloot = {}
                    for i, v in ipairs(inst.loot) do table.insert(newloot, v) end
                    for i, v in ipairs(newloot) do table.insert(inst.loot, v) end
                end
            end

            -- 为爽改动:有trader组件的单位采集倍率不能改变
            if inst.components.pickable and not inst.components.trader then ----更改目标采集组件
                inst.components.pickable.numtoharvest = inst.components.pickable.numtoharvest * 2
            end
        elseif loot and Rand < 0.90 and inst:HasTag("_health") and
            not inst:HasTag("structure") and not inst:HasTag("swc2hm") and inst.components.lootdropper ~= nil then
            local amount = Rand <= 0.80 and 2 or 1
            local GenerateLoot = inst.components.lootdropper.GenerateLoot
            inst.components.lootdropper.GenerateLoot = function(self, ...)
                -- Filter after the original rolls, preserving non-meat loot and
                -- leaving at least one of each meat prefab in the actual result.
                return ReduceSmallCreatureMeat(GenerateLoot(self, ...), amount)
            end
        end
        inst.myscale = Rand
    end
end

local function saveandload(inst) ----保存与载入，主要是保存生物的各种数据已贴图
    SetOnSave(inst, function(inst, data)
        data.ray_suijidaxiao = inst.ray_suijidaxiao
        data.ray_nars2hm = inst.ray_nars2hm
        if inst.myscale ~= nil then data.myscale = inst.myscale end
    end)

    SetOnLoad(inst, function(inst, data)
        if data and data.ray_suijidaxiao ~= nil then inst.ray_suijidaxiao = data.ray_suijidaxiao end
        -- 为爽改动:感染性继承
        if data and data.ray_nars2hm ~= nil then
            inst.ray_nars2hm = data.ray_nars2hm
            if inst.ray_nars2hm then inst:AddTag("ray_nars2hm") end
        end
        if data and data.myscale ~= nil then inst.myscale = data.myscale end
    end)
    local old_OnPreLoad = inst.OnPreLoad
    inst.OnPreLoad = function(inst, data)
        if old_OnPreLoad ~= nil then old_OnPreLoad(inst, data) end
        if data and data.myscale and inst.components.health ~= nil then
            if not (data.health and data.health.maxhealth) then
                inst.components.health.maxhealth = math.ceil(inst.components.health.maxhealth * data.myscale)
                if data.health and data.health.health then inst.components.health:SetCurrentHealth(data.health.health) end
                inst.components.health:DoDelta(0)
            end
            inst.myscalehealth2hm = true
        end
    end
end

local function RestoreCapturedHealth(inst, state)
    local health = inst.components.health
    if health == nil or inst.components.stackable ~= nil or not inst:IsValid() or health:IsDead() then return end
    health.save_maxhealth = true
    health:SetMaxHealth(state.maxhealth)
    health:SetPenalty(state.penalty or 0)
    health:SetCurrentHealth(state.health)
    health:ForceUpdateHUD(true)
end
local function InstallTrapIdentity(inst)
    if inst == nil or inst.randomsizetraphooks2hm or inst:HasTag("player") or
        inst.components.health == nil or inst.components.inventoryitem == nil or
        not inst.components.inventoryitem.trappable then return end
    inst.randomsizetraphooks2hm = true
    local SetTrapData, RestoreDataFromTrap = inst.settrapdata, inst.restoredatafromtrap
    inst.settrapdata = function(inst, ...)
        local original
        if SetTrapData ~= nil then original = SetTrapData(inst, ...) end
        -- Stack mods deliberately keep their existing live-capture behavior.
        if inst.components.stackable ~= nil then return original end
        local health = inst.components.health
        local data = {}
        if type(original) == "table" then
            for key, value in pairs(original) do data[key] = value end
        end
        data.randomsizecapture2hm = {
            version = 1, originalwrapped = type(original) ~= "table",
            randomsize = inst.ray_suijidaxiao or 0, myscale = inst.myscale, norandom = inst.ray_nars2hm,
            health = health.currenthealth, maxhealth = health.maxhealth, penalty = health.penalty,
        }
        if data.randomsizecapture2hm.originalwrapped then data.randomsizecapture2hm.original = original end
        return data
    end
    inst.restoredatafromtrap = function(inst, data, ...)
        local state = type(data) == "table" and data.randomsizecapture2hm or nil
        if type(state) ~= "table" or state.version ~= 1 then state = nil end
        local original = data
        if state and state.originalwrapped then original = state.original end
        local result
        if RestoreDataFromTrap ~= nil then result = RestoreDataFromTrap(inst, original, ...) end
        if inst.components.stackable ~= nil or type(state) ~= "table" or state.version ~= 1 or
            type(state.maxhealth) ~= "number" or state.maxhealth <= 0 or type(state.health) ~= "number" then return result end
        inst.ray_suijidaxiao, inst.myscale, inst.ray_nars2hm = state.randomsize, state.myscale, state.norandom
        if state.norandom then inst:AddTag("ray_nars2hm") end
        inst.myscalehealth2hm = true
        if state.randomsize == 1 and type(state.myscale) == "number" then qianghua(inst, state.myscale, true) end
        RestoreCapturedHealth(inst, state)
        -- Finish after existing prefab/elite restoration tasks, keeping their
        -- own trap data and avoiding a second random-size or health multiplier.
        if inst.randomsizecapturetask2hm ~= nil then inst.randomsizecapturetask2hm:Cancel() end
        inst.randomsizecapturetask2hm = inst:DoTaskInTime(0, function(inst)
            inst.randomsizecapturetask2hm = nil
            RestoreCapturedHealth(inst, state)
        end)
        return result
    end
end

-- entity_spawned runs after every prefab post-init, so existing native/elite
-- trap handlers have already been installed before we wrap them.
AddSimPostInit(function()
    if TheWorld.ismastersim then
        TheWorld:ListenForEvent("entity_spawned", function(_, inst) InstallTrapIdentity(inst) end)
    end
end)

-- 提取判断是否随机缩放的逻辑，方便在其他地方调用
local function isRandScale(inst, ...)
    -- if  not POPULATING then
    -- 为爽改动开头:玩家周围的单位不会改变大小,该单位周围的单位也不会改变大小
    if inst.ray_suijidaxiao == nil then
        -- local f, g, b = inst.Transform:GetWorldPosition()
        -- local buyua = TheSim:FindEntities(f, g, b, 4, { "player" })
        -- 	if  #buyua < 1 and math.random(1,100) <= 80 then
        -- 		inst.ray_suijidaxiao = 1
        -- 		else
        -- 		inst.ray_suijidaxiao = 0
        -- 	end
        for i, v in ipairs(AllPlayers) do
            if v:IsValid() and inst:IsNear(v, 4) then
                inst.ray_suijidaxiao = 0
                inst.ray_nars2hm = true
                inst:AddTag("ray_nars2hm")
                break
            end
        end
        -- 这里是否可以考虑放开限制？每个实体是否缩放不应该受周围实体的影响
        if inst.ray_suijidaxiao ~= 0 then
            local x, y, z = inst.Transform:GetWorldPosition()
            local norandomsizeitem = TheSim:FindEntities(x, y, z, 4, {"ray_nars2hm"})
            if #norandomsizeitem < 1 and math.random() < 0.8 then
                inst.ray_suijidaxiao = 1
            else
                inst.ray_suijidaxiao = 0
            end
        end
    end
    return inst.ray_suijidaxiao == 1
end

local blacklist = {
    "deer",
}
AddPrefabPostInitAny(function(inst)
    if inst ~= nil and inst.Transform and not inst:HasTag("player") and                                   ---非玩家
    not table.contains(blacklist,inst.prefab) and                                                         ---黑名单
        not inst:HasTag("structure") and                                                                  ---非建筑
        not inst:HasTag("wall") and                                                                       ---非墙
        not inst:HasTag("shadow") and                                                                     ---非暗影
        not inst:HasTag("groundtile") and                                                                 ---非地砖
        not inst:HasTag("molebait") and                                                                   ---非分子
        not inst:HasTag("FX") and                                                                         ---非特效
        not inst:HasTag("shadowminion") and                                                               ---非暗影生物
        not inst:HasTag("shadowcreature") and                                                             ---非暗影生物
        not inst:HasTag("epic") and                                                                       ----非史诗生物。
        not inst:HasTag("shadowchesspiece") and                                                           ----非史诗生物。
        not inst:HasTag("crabking") and                                                                   ----非史诗生物。
        not inst:HasTag("companion") and                                                                  ----非同伴。
        not inst:HasTag("boat") and                                                                       ----非船。
        -- not inst:HasTag("character") and ----非角色。
        not inst:HasTag("ghost") and                                                                      ----非幽灵。
        not inst:HasTag("abigail") and                                                                    ----非阿比盖尔。
        not inst.components.scaler and                                                                    ----非石虾
        (inst:HasTag("_health") or inst:HasTag("boulder") or inst:HasTag("tree") or inst:HasTag("plant")) ---有生命值或石头或树木或植物。
    then
        if not TheWorld.ismastersim then                                                                  ---接下来服务器执行
            return inst
        end

        inst:DoTaskInTime(0, function(inst, ...)
            InstallTrapIdentity(inst)
            if isRandScale(inst, ...) then
                qianghua(inst, getrandomscale(inst), true)
            end
        end)

        saveandload(inst)
    end
end)

--保证 pigman 在变身为狼人(werebeast)或恢复时，按已保存的 inst.myscale 重新应用最大生命值和基础伤害的缩放，避免变身重置大小带来的属性不一致
AddPrefabPostInit("pigman", function(inst)
    if inst.components.werebeast then
        local old_onsetwerefn = inst.components.werebeast.onsetwerefn or function(...) end
        inst.components.werebeast.onsetwerefn = function(inst)
            old_onsetwerefn(inst)
            if inst.myscale ~= nil then
                if inst.components.health ~= nil then
                    if inst.components.health then
                        inst.components.health:SetMaxHealth(math.ceil(inst.components.health.maxhealth * inst.myscale))
                    end
                end

                if inst.components.combat then
                    inst.components.combat.defaultdamage = math.ceil(inst.components.combat.defaultdamage * inst.myscale)
                end
            end
        end
        local old_onsetnormalfn = inst.components.werebeast.onsetnormalfn or function(...) end
        inst.components.werebeast.onsetnormalfn = function(inst)
            old_onsetnormalfn(inst)
            if inst.myscale ~= nil then
                if inst.components.health ~= nil then
                    if inst.components.health then
                        inst.components.health:SetMaxHealth(math.ceil(inst.components.health.maxhealth * inst.myscale))
                    end
                end

                if inst.components.combat then
                    inst.components.combat.defaultdamage = math.ceil(inst.components.combat.defaultdamage * inst.myscale)
                end
            end
        end
    end
end)

-- 伍迪鹿形态的随机缩放，0.75~1.5的范围内
local function getwoodiemoosescale()
    local scale = math.random() * (1.5 - 0.75) + 0.75
    return math.floor(scale * 100 + 0.5) / 100
end

local function getwoodiemoosescaleddamage(inst, damage)
    if damage == nil then
        return damage
    end
    local scale = inst ~= nil and inst._ray_woodie_moose_scale2hm or 1
    return math.max(0, math.ceil(damage * scale))
end

local function cachewoodiehumanstats(inst)
    if inst == nil or inst.components.health == nil or inst.components.combat == nil then
        return
    end
    inst._ray_woodie_moose_humanstats2hm = {
        maxhealth = inst.components.health.maxhealth,
        defaultdamage = inst:HasTag("weremoose") and TUNING.UNARMED_DAMAGE or inst.components.combat.defaultdamage,
    }
end

local function applywoodiemoosescale(inst)
    if inst == nil or inst._ray_woodie_moose_active2hm or not inst:HasTag("weremoose") then
        return
    end
    if inst.components.health == nil or inst.components.combat == nil or inst.ApplyScale == nil then
        return
    end

    local humanstats = inst._ray_woodie_moose_humanstats2hm
    if humanstats == nil then
        cachewoodiehumanstats(inst)
        humanstats = inst._ray_woodie_moose_humanstats2hm
    end
    if humanstats == nil then
        return
    end

    local health = inst.components.health
    local combat = inst.components.combat
    local percent = health:GetPercent()
    local scale = getwoodiemoosescale()

    inst._ray_woodie_moose_scale2hm = scale
    inst._ray_woodie_moose_active2hm = true
    inst:ApplyAnimScale("ray_woodie_moose_scale2hm", scale)

    health:SetMaxHealth(math.max(1, math.ceil(humanstats.maxhealth * scale)))
    health:SetPercent(percent)
    combat:SetDefaultDamage(combat.defaultdamage)
end

local function restorewoodiemoosescale(inst)
    if inst == nil then
        return
    end

    if not inst._ray_woodie_moose_active2hm or inst.ApplyScale == nil then
        if inst.components.combat ~= nil and not inst:HasTag("weremoose") then
            inst.components.combat:SetDefaultDamage(TUNING.UNARMED_DAMAGE)
        end
        inst._ray_woodie_moose_scale2hm = nil
        inst._ray_woodie_moose_active2hm = nil
        inst._ray_woodie_moose_humanstats2hm = nil
        return
    end

    local humanstats = inst._ray_woodie_moose_humanstats2hm
    local health = inst.components.health
    local combat = inst.components.combat
    local percent = health ~= nil and health:GetPercent() or nil

    inst:ApplyAnimScale("ray_woodie_moose_scale2hm", 1)
    inst._ray_woodie_moose_scale2hm = nil
    inst._ray_woodie_moose_active2hm = nil

    if health ~= nil and humanstats ~= nil and humanstats.maxhealth ~= nil then
        health:SetMaxHealth(math.max(1, humanstats.maxhealth))
        if percent ~= nil then
            health:SetPercent(percent)
        end
    end

    if combat ~= nil then
        combat:SetDefaultDamage(humanstats ~= nil and humanstats.defaultdamage or TUNING.UNARMED_DAMAGE)
    end

    inst._ray_woodie_moose_humanstats2hm = nil
end

if woodiemooserandomscale then
    AddPrefabPostInit("woodie", function(inst)
        if not TheWorld.ismastersim then
            return
        end

        if inst.components.combat ~= nil and not inst.components.combat._ray_woodie_moose_damagehook2hm then
            local combat = inst.components.combat
            local oldSetDefaultDamage = combat.SetDefaultDamage
            combat._ray_woodie_moose_damagehook2hm = true
            combat.SetDefaultDamage = function(self, damage, ...)
                if self.inst._ray_woodie_moose_active2hm and damage ~= nil then
                    damage = getwoodiemoosescaleddamage(self.inst, damage)
                end
                return oldSetDefaultDamage(self, damage, ...)
            end
        end

        inst:ListenForEvent("transform_wereplayer", function(inst, data)
            if data ~= nil and data.mode == "moose" then
                cachewoodiehumanstats(inst)
            end
        end)

        inst:ListenForEvent("startwereplayer", function(inst)
            if inst:HasTag("weremoose") then
                applywoodiemoosescale(inst)
            end
        end)

        inst:ListenForEvent("stopwereplayer", function(inst)
            restorewoodiemoosescale(inst)
        end)
    end)
end

-- 在 spiderden 的升级阶段变化时，按实体的 myscale 放大其最大生命值
AddPrefabPostInit("spiderden", function(inst)
    if inst.components.upgradeable then
        local old = inst.components.upgradeable.SetStage
        inst.components.upgradeable.SetStage = function(self, num)
            old(self, num)
            if self.inst.myscale ~= nil and self.inst.components.health ~= nil then
                self.inst.components.health:SetMaxHealth(math.ceil(self.inst.components.health.maxhealth *
                    self.inst.myscale))
            end
        end
    end
end)

-- 骑牛前后正常体型
local function onmounted(inst, data)
    if data and data.target ~= nil then
        local ent = data.target
        local sx = data.target.Transform:GetScale()
        local _sx = sx
        if beefalochange and ent and ent.components.domesticatable and ent.components.domesticatable:IsDomesticated() then
            if sx > 1 then
                if ent.tendency == TENDENCY.DEFAULT then
                    -- 无训势
                    sx = (sx - 1) / 2 + 1
                elseif ent.tendency == TENDENCY.ORNERY then
                    -- 战牛
                    sx = 1
                elseif ent.tendency == TENDENCY.RIDER then
                    -- 行牛
                    sx = sx
                elseif ent.tendency == TENDENCY.PUDGY then
                    -- 肥牛
                    sx = 1
                else
                    sx = 1
                end
            end
            inst.Transform:SetScale(sx, sx, sx)
        elseif beefalochange and ent and ent.components.domesticatable and not ent.components.domesticatable:IsDomesticated() then
            if sx > 1 then
                sx = (sx - 1) / 2 + 1
            end
            inst.Transform:SetScale(sx, sx, sx)
        else
            inst.Transform:SetScale(sx, sx, sx)
        end
        if _sx > sx then
            local x = _sx / sx
            inst.AnimState:SetScale(x, x)
        end
    end
end
local function ondismounted(inst, data)
    inst.Transform:SetScale(1, 1, 1)
    inst.AnimState:SetScale(1, 1)
end
local function playerpostInit(inst)
    if not TheWorld.ismastersim then return inst end
    inst:ListenForEvent("mounted", onmounted)
    inst:ListenForEvent("dismounted", ondismounted)
end
AddPlayerPostInit(playerpostInit)

-----------驯好的牛不退化---------------------------------------------
local function OnDomesticationDelta(inst, data)
    if inst.components.domesticatable:IsDomesticated() and data and data.new < 1 then
        inst.components.domesticatable
            :DeltaDomestication(1)
    end
end
AddPrefabPostInit("beefalo",
    function(inst) if TheWorld.ismastersim then inst:ListenForEvent("domesticationdelta", OnDomesticationDelta) end end)

-- ====重写打蜡的函数
require("prefabs/veggies")
if GLOBAL.VEGGIES ~= nil then
    for k, v in pairs(GLOBAL.VEGGIES) do
        AddPrefabPostInit(k .. "_oversized", function(inst)
            if inst.components.waxable then
                inst.components.waxable.waxfn = function(inst, doer)
                    local waxedveggie = SpawnPrefab(inst.prefab .. "_waxed")
                    if inst.myscale ~= nil then waxedveggie.myscale = inst.myscale end
                    if doer.components.inventory and doer.components.inventory:IsHeavyLifting() and doer.components.inventory:GetEquippedItem(EQUIPSLOTS.BODY) ==
                        inst then
                        doer.components.inventory:Unequip(EQUIPSLOTS.BODY)
                        doer.components.inventory:Equip(waxedveggie)
                    else
                        waxedveggie.Transform:SetPosition(inst.Transform:GetWorldPosition())
                        waxedveggie.AnimState:PlayAnimation("wax_oversized", false)
                        waxedveggie.AnimState:PushAnimation("idle_oversized")
                    end
                    inst:Remove()
                    return true
                end
            end
            if inst.components.perishable then
                inst.components.perishable.perishfn = function(inst)
                    if inst.components.inventoryitem:GetGrandOwner() ~= nil then
                        local loots = {}
                        for i = 1, #inst.components.lootdropper.loot do table.insert(loots, "spoiled_food") end
                        inst.components.lootdropper:SetLoot(loots)
                        inst.components.lootdropper:DropLoot()
                    else
                        local rotten = SpawnPrefab(inst.prefab .. "_rotten")
                        if inst.myscale ~= nil then rotten.myscale = inst.myscale end
                        rotten.Transform:SetPosition(inst.Transform:GetWorldPosition())
                    end
                    inst:Remove()
                end
            end
        end)
    end
end

---给洞穴添加一个猎人组件，让洞穴会生成脚印
AddPrefabPostInit("cave",
    function(inst) if inst.ismastersim and inst.components.hunter == nil then inst:AddComponent("hunter") end end)

---让座狼和蠕虫 不会互相攻击
local function processworm(inst) if TheWorld.ismastersim and TheWorld:HasTag("cave") then inst:AddTag("warg") end end
AddPrefabPostInit("worm", processworm)
if TUNING.DSTU then
    AddPrefabPostInit("gatorsnake", processworm)
    AddPrefabPostInit("shockworm", processworm)
    AddPrefabPostInit("viperling", processworm)
    AddPrefabPostInit("viperworm", processworm)
end
AddPrefabPostInit("warg",
    function(inst) if TheWorld.ismastersim and TheWorld:HasTag("cave") then inst:AddTag("worm") end end)
