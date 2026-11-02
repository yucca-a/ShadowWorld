-------------------------------------------------------------------------------------
---------------------[[2025.7.17 melon:生物暗影分身削弱]]-----------------------------
-- 削弱影子   (虚弱之影)
-- 一般削弱：boss攻击间隔变3倍、体型变0.75倍、血量减半、复活时间翻倍?
--          普通生物攻击间隔变3倍、血量减半?
-- 必须拉影子的boss:天体、织影、梦魇疯猪、寡妇(妥协)
--             削弱:除了一般削弱外->血量上限500
--------------------------------------------------------------------------------
local select_shadow_nerf = GetModConfigData("shadow_nerf")
local old_alterguardian = GetModConfigData("old_alterguardian") -- 旧版本天体英雄
local sharkboi = GetModConfigData("sharkboi")
select_shadow_nerf = select_shadow_nerf == true and 3 or select_shadow_nerf
local EPIC_PERIOD_TIMES = math.clamp(select_shadow_nerf,1,5) -- boss攻击间隔变为几倍
local PERIOD_TIMES = math.clamp(select_shadow_nerf,1,5) -- 普通生物
local HEALTH_TIMES = 0.5 -- 血量倍率
local HEALTH_SP = 2000 -- 特殊boss影子2000血
local SPAWN_TIMES = 3 -- 复活时间倍率
local TRANS_TIMES = 0.75 -- 体型倍率0.75
-- local HEALTH_MIN = 1500 -- 加倍复活时间的血量阈值

local NAMES_SP = { -- 特殊影子改为1000血
    -- ["alterguardian_phase1"]=HEALTH_SP, ["alterguardian_phase2"]=HEALTH_SP, ["alterguardian_phase3"]=HEALTH_SP, -- 天体
    ["stalker_atrium"]=HEALTH_SP, ["daywalker"]=HEALTH_SP, -- 织影/梦魇疯猪
    ["hoodedwidow"]=1000, ["moonmaw_dragonfly"]=HEALTH_SP, ["minotaur"]=HEALTH_SP, -- 寡妇/月龙/犀牛
}

local NAMES_NOT_PERIOD = { -- 不改攻击间隔的
    "alterguardian_phase3", "minotaur", -- 天3/犀牛
}

local function p(inst)
    TheNet:SystemMessage(inst.prefab .. tostring(inst.components.childspawner2hm.regenperiod))
end
local function weak(inst)
    -- 非影子退出
    if not inst:HasTag("swc2hm") then return end
    -- if inst.components.childspawner2hm then return end -- 用childspawner2hm组件代替tag  swc2hm
    -- 影子部分----------------------------------------
    if inst.components.combat then
        -- 加攻击间隔  boss:3倍  其它:3倍
        local period = inst.components.combat.min_attack_period
        period = period * (inst:HasTag("epic") and EPIC_PERIOD_TIMES or PERIOD_TIMES)
        if not table.contains(NAMES_NOT_PERIOD, inst.prefab) then -- 天3/犀牛不要改
            inst.components.combat:SetAttackPeriod(period)
        end
        -- 伤害变为30%
        inst.components.combat.defaultdamage = math.ceil(inst.components.combat.defaultdamage * TRANS_TIMES)
        -- 攻击范围  跟随体型变化倍率
        inst.components.combat.hitrange = inst.components.combat.hitrange * TRANS_TIMES
        inst.components.combat.attackrange = inst.components.combat.attackrange * TRANS_TIMES
    end
    -- 血量减半  特殊boss自定义血量
    if inst.components.health then
        local health = NAMES_SP[inst.prefab] or inst.components.health.maxhealth * HEALTH_TIMES
        inst.components.health:SetMaxHealth(health)
    end
    -- 体型变0.75倍
    if inst.Transform then
        local sx, sy, sz = inst.Transform:GetScale()
        inst.Transform:SetScale(sx * TRANS_TIMES, sy * TRANS_TIMES, sz * TRANS_TIMES)
    end
end

local NAMES_REGEN = { -- 特殊影子复活时间  *3
    "alterguardian_phase1", "alterguardian_phase2", "alterguardian_phase3", -- 天体
    "stalker_atrium", "daywalker", "minotaur", -- 织影/梦魇疯猪/犀牛
    "mutatedwarg", "mutatedbearger", "mutateddeerclops",  -- 月三王
    "deer_red", "deer_blue", -- 宝石鹿
    -- "moonmaw_dragonfly", "hoodedwidow", -- /寡妇/月龙
}
if TUNING.DSTU then -- "hoodedwidow", 
    table.insert(NAMES_REGEN, "hoodedwidow")
    table.insert(NAMES_REGEN, "moonmaw_dragonfly")
end
-- 修改特殊boss复活时间  *3
local function reset_regenperiod(inst)
    -- 在本体设置复活时间  非影子才有childspawner2hm组件  无影子的生物无childspawner2hm组件
    if inst.components.childspawner2hm then -- boss复活时间翻倍
        inst.components.childspawner2hm:SetRegenPeriod(480 * 3) -- 直接设置固定时间
        -- inst:DoPeriodicTask(5, p)
    end
end

-- 用于天体影子,2000血,回血最多到2000
local function resethealth_alterguardian(inst)
    if not inst:HasTag("swc2hm") then return end
    if inst.components.health then inst.components.health:SetMaxHealth(HEALTH_SP) end
    local _OnEntityWake = inst.OnEntityWake
    inst.OnEntityWake = function(inst)
        if inst.OnEntityWake ~= nil then _OnEntityWake(inst) end
        if inst.components.health then
            if inst.components.health.maxhealth > HEALTH_SP then
                inst.components.health:SetMaxHealth(HEALTH_SP)
            end
        end
    end
end
-- 用于巨鹿影子  *0.25 才是  *0.5
local function resethealth_deerclops(inst)
    if not inst:HasTag("swc2hm") then return end
    if inst.components.health then
        inst.components.health:SetMaxHealth(inst.components.health.maxhealth * 0.25)
    end
end
-----------------------------------------------------------------------
local function not_shadow(inst)
    return inst:HasTag("player") or inst:HasTag("shadow") or inst:HasTag("shadowminion") or inst:HasTag("shadowcreature") or inst:HasTag("nightmarecreature")
end
-----------------------------------------------------------------------
local MUST_TAGS = {}
local blacklist = {
    "deer_red", "deer_blue", "abigail", "bernie_big", "bernie_active", -- 宝石鹿/阿比/伯尼
    "shadowhutch2hm", "chester", "daywalker2", "glommer", -- 哈奇/小切/拾荒疯猪/格罗姆
    "mermguard", "mermguard_lunar", "mermguard_shadow", -- 鱼人守卫/月亮守卫/暗影守卫
    "alterguardian_phase3", "alterguardian_phase2", "alterguardian_phase1", -- 天体
    "alterguardian_phase4_lunarrift", -- 天体后裔
    "minotaur",
}
if sharkboi then table.insert(blacklist, "sharkboi") end
-- 开启暗影世界才起效  关闭困难模式时不起效
if GetModConfigData("Shadow World") and select_shadow_nerf and TUNING.hardmode2hm then
    -- 修改 攻击间隔/伤害/攻击范围/血量减半/体型
    AddPrefabPostInitAny(function(inst)
        if not TheWorld.ismastersim then return end
        -- 判断合法生物才执行
        -- if not_shadow(inst) then return end
        if table.contains(blacklist, inst.prefab) then return end
        if not inst.components.combat or not inst.components.health then return end -- 无攻击/血量组件的
        -- 0.3秒后再执行，保证标签已到位?
        inst.weaktask2hm = inst:DoTaskInTime(0.2, weak) -- 削弱影子属性
    end)
    -- 修改部分boss影子复活时间
    for _,prefab in ipairs(NAMES_REGEN) do
        AddPrefabPostInit(prefab, function(inst)
            if not TheWorld.ismastersim then return end
            inst.reset_regenperiod_task2hm = inst:DoTaskInTime(0.3, reset_regenperiod) -- 削弱复活时间
        end)
    end
    -- 天体影子仅削弱血量，天体影子脱加载最多回到2000血----------------------------------------
    local alterguardian_prefabs = {"alterguardian_phase1", "alterguardian_phase2", "alterguardian_phase3",}
    for _,prefab in ipairs(alterguardian_prefabs) do
        AddPrefabPostInit(prefab, function(inst)
            if not TheWorld.ismastersim or (inst.prefab == "alterguardian_phase3" and old_alterguardian) then return end
            -- 0.5秒后再执行，避免本体血量变1000   保证组件已到位?
            inst.resettask2hm = inst:DoTaskInTime(0.3, resethealth_alterguardian) -- 重设血量上限2000
        end)
    end
    -- 巨鹿晶体鹿单独改----------------------------------------
    local deerclops_prefabs = {"deerclops", "mutateddeerclops",}
    for _,prefab in ipairs(deerclops_prefabs) do
        AddPrefabPostInit(prefab, function(inst)
            if not TheWorld.ismastersim then return end
            -- 0.5秒后再执行，避免本体血量变1000   保证组件已到位?
            inst.reset2task2hm = inst:DoTaskInTime(0.3, resethealth_deerclops) -- 重设血量上限
        end)
    end
    -- 2025.9.3 melon:宝石鹿影子削弱体型、攻击范围、复活时间3天(写在上面)
    local DEERS = {"deer_red", "deer_blue"}
    for _, prefab in ipairs(DEERS) do
        AddPrefabPostInit(prefab, function(inst)
            if not TheWorld.ismastersim then return end
            inst.weaktask2hm = inst:DoTaskInTime(0.2, function(inst)
                if not inst:HasTag("swc2hm") then return end
                if inst.components.combat then -- 攻击范围  跟随体型变化倍率
                    inst.components.combat.hitrange = inst.components.combat.hitrange * TRANS_TIMES
                    inst.components.combat.attackrange = inst.components.combat.attackrange * TRANS_TIMES
                end
                if inst.Transform then -- 体型变0.75倍
                    local sx, sy, sz = inst.Transform:GetScale()
                    inst.Transform:SetScale(sx * TRANS_TIMES, sy * TRANS_TIMES, sz * TRANS_TIMES)
                end
                -- 2025.9.5 melon:不是跟随克劳斯的鹿  notaunt表示跟随
                if not inst:HasTag("notaunt") and inst.components.health then
                    inst.components.health:SetMaxHealth(inst.components.health.maxhealth * HEALTH_TIMES)
                end
            end)
        end)
    end
    -- 修改妥协月龙影子玻璃数量----------------------------------------
    if TUNING.DSTU then
        local function SpawnLavae2hm(inst)
            if not inst.SpawnedLavae then
                local x, y, z = inst.Transform:GetWorldPosition()
                local LIMIT = 4
                inst.lavae = {}
                -- for i = 1, 4 do
                --     inst.lavae[i] = SpawnPrefab("moonmaw_lavae_ring")
                --     inst.lavae[i].WINDSTAFF_CASTER = inst
                --     inst.lavae[i].components.linearcircler:SetCircleTarget(inst)
                --     inst.lavae[i].components.linearcircler:Start()
                --     inst.lavae[i].components.linearcircler.randAng = i * 0.125
                --     inst.lavae[i].components.linearcircler.clockwise = false
                --     inst.lavae[i].components.linearcircler.distance_limit = LIMIT
                --     inst.lavae[i].components.linearcircler.setspeed = 0.2
                --     inst.lavae[i].hidden = false
                --     inst.lavae[i].AnimState:PlayAnimation("hover")
                -- end
                for i = 1, 8 do -- 1~8玻璃直接隐藏
                    inst.lavae[i] = SpawnPrefab("moonmaw_lavae_ring")
                    inst.lavae[i].hidden = true -- 隐藏?
                end
                inst.SpawnedLavae = true
            end
        end
        AddPrefabPostInit("moonmaw_dragonfly", function(inst)
            if not TheWorld.ismastersim then return end
            inst.lavaetask2hm = inst:DoTaskInTime(0.2, function(inst)
                if inst:HasTag("swc2hm") then
                    inst.SpawnLavae = SpawnLavae2hm
                end
            end)
        end)
    end
end
