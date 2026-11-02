---------------------------------------------------------------------------------
---------------------[[2025.9.20 melon:劣质装甲]]-------------------
-- 普通生物半血触发一次5秒无敌。由普通装甲简化代码而来。
---------------------------------------------------------------------------------
-- 劣质装甲其实就是加个半血的监听函数
local ALLMISS_TIME = 5 -- 5秒无敌
-- 装甲特效
local function makepoor_armor2hm_fx(inst)
    if not inst.poor_armor2hm_fx or not inst.poor_armor2hm_fx:IsValid() then
        inst.poor_armor2hm_fx = SpawnPrefab("forcefieldfx")
        local range = inst:GetPhysicsRadius(0.2) + 0.5 -- 原来1
        if inst.components.weapon then
            range = range + (inst.components.weapon:GetAttackRange() or 0)
        end
        inst.poor_armor2hm_fx.entity:SetParent(inst.entity)
        inst.poor_armor2hm_fx:AddTag("NOCLICK")
        inst.poor_armor2hm_fx:AddTag("FX")
        inst.poor_armor2hm_fx.Transform:SetPosition(0, range + 0.2, 0)
        inst.poor_armor2hm_fx.Transform:SetScale(range, range, range)
        inst.poor_armor2hm_fx:DoTaskInTime(ALLMISS_TIME, function(inst) -- 5秒消失
            if inst:IsValid() then inst:Remove() end
        end)
    end
end
-- 监听函数
local function poor_armor2hm(inst)
    if inst.components.health and inst.components.health:GetPercent() < 0.5 then
        makepoor_armor2hm_fx(inst)
        inst.haspoor_armor2hm = nil -- 这样回档也没劣质装甲了
        inst:RemoveEventCallback("healthdelta", inst.poor_armor2hm) -- 仅触发一次
        inst.allmiss2hm = true
        inst:DoTaskInTime(ALLMISS_TIME, function(inst) inst.allmiss2hm = nil end)
    end
end
---------------------------------------------------------------------------------
-- 改变inst的保存与载入函数，增加存储是否加装甲参数.
local function saveandload2hm(inst)
    local oldsave = inst.OnSave
    inst.OnSave = function(inst, data)
        if oldsave ~= nil then oldsave(inst, data) end
        data.hasjudgedpoor_armor2hm = inst.hasjudgedpoor_armor2hm  -- 是否判定过
        data.haspoor_armor2hm = inst.haspoor_armor2hm  -- 有装甲
    end
    local oldload = inst.OnLoad
    inst.OnLoad = function(inst, data)
        if oldload ~= nil then oldload(inst, data) end
        inst.hasjudgedpoor_armor2hm = data and data.hasjudgedpoor_armor2hm
        inst.haspoor_armor2hm = data and data.haspoor_armor2hm
    end
end
local function hastag2hm(inst, tagtable) -- 判断inst是否有tagtable中的tag
    if inst == nil or tagtable == nil then return false end
    for _, v in ipairs(tagtable) do
        if inst:HasTag(v) then return true end
    end
    return false
end
-- 普通生物10%巨兽装甲 0级
local ARMOR_CANT_TAGS = {
    "epic", -- 非boss
    "swc2hm", -- 非影子
    "structure", -- 非建筑
    "wall", -- 非墙
    "shadow", -- 非暗影
    "shadowminion", -- 非暗影生物
    "shadowcreature", -- 非暗影生物
    "balloon", -- 非气球 (会崩溃)
    "groundspike", -- 非沙刺、沙堡、触手和暗影触手根须藤曼(针刺旋花)ivy_snare
    "stalkerminion", -- 非编织暗影  织影小虫子
    "crabking_ally", -- 非帝王蟹相关 塔、兵、钳、冰
    -- "character", -- 非角色
    -- "companion", -- 非同伴
    -- 妥协
    "nightmarecreature", -- 非 妥协夜间事件 生物
    "trap", -- 防止妥协陷阱崩溃
    -- 
    "noarmor2hm", -- if your mod's creature don't want to add EpicArmor, plase add this tag
}
local ARMOR_CANT_PREFABS = { -- 与tag方式不同，运行更快?
    "abigail", -- 非阿比盖尔
    "bernie_big", -- 非大伯尼
    "lureplant", -- 非食人花
    "cookiecutter", -- 非切割机
    "bird_mutant", -- 非月盲乌鸦
    "bird_mutant_spitter", -- 非奇形鸟
    "tentacle_pillar_arm", -- 非小触手
    -- ["crabking_mob", -- 非蟹兵
    -- 妥协
    "minotaur_organ", -- 非犀牛心脏
}
-- 非常单纯的加装甲函数
local function addpoor_armor2hm(inst)
    if inst.haspoor_armor2hm then return end -- 已经有装甲，返回
    if inst.startgame2hm ~= nil then return end  -- 每次进游戏只能执行一次 (冗余的?)
    inst.startgame2hm = 1
    if table.contains(ARMOR_CANT_PREFABS, inst.prefab) or hastag2hm(inst, ARMOR_CANT_TAGS) then return end-- 冗余判断
    inst.haspoor_armor2hm = true  -- 标记有装甲
    -- 加装甲其实就是加个监听事件
    inst:ListenForEvent("healthdelta", poor_armor2hm)
    inst.poor_armor2hm = poor_armor2hm -- 记录，用于移除
end
------------------------------------------------------------------------------
if GetModConfigData("poor_armor") then -- 设置开启才执行
    local select_poor_armor = GetModConfigData("poor_armor")
    select_poor_armor = select_poor_armor == true and 1 or select_poor_armor
    -- 生物带装甲的概率:选1->0.1  2->0.3  3->0.5
    local persent_armor = (select_poor_armor * 2 - 1) * 0.1
    persent_armor = math.clamp(persent_armor,0.1,0.5)
    -- 为所有满足条件的实体增加装甲
    AddPrefabPostInitAny(function(inst)
        if not TheWorld.ismastersim then return end
        if not inst.components.combat then return end -- 无攻击组件就return
        -- 判断tag和prefab是否合法
        if table.contains(ARMOR_CANT_PREFABS, inst.prefab) or hastag2hm(inst, ARMOR_CANT_TAGS) then return end
        -- 代码执行顺序AddPrefabPostInitAny->inst.OnLoad->DoTaskInTime
        saveandload2hm(inst) -- 读取和保存的时候加入装甲标记
        -- --------------------------------------------------------
        inst:DoTaskInTime(0, function()  -- 不加DoTaskInTime影子也会有装甲
            if inst.hasjudgedpoor_armor2hm then  -- 是否判断过加装甲了(可能判断过但不加装甲)
                if inst.haspoor_armor2hm then  -- 有装甲就加一下
                    addpoor_armor2hm(inst) -- 加装甲
                end
            else
                inst.hasjudgedpoor_armor2hm = true -- 已经判定过是否加装甲了
                if math.random() < persent_armor then  -- 10%概率  0.8方便测试
                    addpoor_armor2hm(inst) -- 加装甲
                end
            end
        end)
    end)
end

----------------------------------------------------------------------------


