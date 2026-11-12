---------------------------------------------------------------------------------
------------------------[[2025.5.3 melon:猪猪boss]]------------------------------
-- 目前的问题，重进游戏后体型变1倍
-- 有好的想法可以随便改这里
-------------------------------------------------------------------------
-- 劣质装甲代码来自poor_armor.lua
local ALLMISS_TIME = 5 -- 5秒无敌
-- 装甲特效
local function makepoor_armor2hm_fx(inst)
    if not inst.poor_armor2hm_fx or inst.poor_armor2hm_fx:IsValid() then
        inst.poor_armor2hm_fx = SpawnPrefab("forcefieldfx")
        local range = inst:GetPhysicsRadius(0.2) + 0.5
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
        inst:RemoveEventCallback("healthdelta", inst.poor_armor2hm) -- 仅触发一次
        inst.allmiss2hm = true
        inst:DoTaskInTime(ALLMISS_TIME, function(inst) inst.allmiss2hm = nil end)
    end
end
-- 非常单纯的加装甲函数
local function addpoor_armor2hm(inst)
    if inst.hasarmor2hm then return end -- 已经有装甲，返回
    if inst.startgame2hm ~= nil then return end  -- 每次进游戏只能执行一次 (冗余的?)
    inst.startgame2hm = 1
    inst.hasarmor2hm = true  -- 标记有装甲
    -- 加装甲其实就是加个监听事件
    inst:ListenForEvent("healthdelta", poor_armor2hm)
    inst.poor_armor2hm = poor_armor2hm -- 记录，用于移除
end
-------------------------------------------------------------------------
-- 修改随机大小代码  体型3倍，攻击范围不变，移速固定?，攻击力2倍
local SCALE_PIGBOSS = 3 -- 3倍体型
local HEALTH_PIGBOSS = 3000
local function strengthen_toboss(inst)
    if inst.strengthen_once then return end
    inst.strengthen_once = true
    -- 体型
    local Rand = (SCALE_PIGBOSS - 1) / 2 + 1
    local sx, sy, sz = inst.Transform:GetScale()
    inst.Transform:SetScale(sx * Rand, sy * Rand, sz * Rand)
    if inst.components.aura and Rand > 1 then inst.components.aura.radius = inst.components.aura.radius * Rand end
    -- 血量
    if inst.components.health then
        inst.components.health:SetMaxHealth(HEALTH_PIGBOSS)
        inst.components.health:SetPercent(1)
    end
    -- 更改攻击力 仅变为2倍
    if inst.components.combat then
        inst.components.combat.defaultdamage = math.ceil(inst.components.combat.defaultdamage * 2)
    end
end
---------------------------------------------------------------
-- 改变inst的保存与载入函数，增加存储是否加装甲参数.
local function saveandloadtarget2hm(inst)
    SetOnSave(inst, function(inst, data)
        data.toBoss2hm = inst.toBoss2hm -- 记录是否是boss
    end)
    SetOnLoad(inst, function(inst, data)
        inst.toBoss2hm = data and data.toBoss2hm -- 记录是否是boss
    end)
end
local RETARGET_MUST_TAGS = { "player" } -- 只找玩家
local RETARGET_CANT_TAGS = { "structure" }  -- 随便写一个
local function RetargetFn2hm(inst) -- 找目标函数
    local range = inst:GetPhysicsRadius(0) + 8
    return FindEntity(inst, 30,
            function(guy)
                return inst.components.combat:CanTarget(guy)
                    and (   guy.components.combat:TargetIs(inst) or
                            guy:IsNear(inst, range)
                        )
            end,
            RETARGET_MUST_TAGS, RETARGET_CANT_TAGS
        )
end
local function teleport2hm(inst) -- 随机传送
    SpawnPrefab("shadow_puff").Transform:SetPosition(inst.Transform:GetWorldPosition())
    local theta = inst.Transform:GetRotation()
    theta = (theta + 165 + math.random() * 30) * DEGREES
    local pos = inst:GetPosition()
    pos.y = 0
    local offs = FindWalkableOffset(pos, theta, 30 + math.random(6), 8, false, true, NotBlocked, false, true)  
            or FindWalkableOffset(pos, theta, 20 + math.random(5), 6, false, true, NotBlocked, false, true)
    if offs ~= nil then
        pos.x = pos.x + offs.x
        pos.z = pos.z + offs.z
    end
    inst.Physics:Teleport(pos:Get())
    SpawnPrefab("shadow_puff").Transform:SetPosition(inst.Transform:GetWorldPosition())
end
-- 守护极光
local function generatecoldstar(inst)
    if inst:HasTag("swc2hm") then return end
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 25, {"staffcoldlight2hm"})
    if #ents < 1 then
        local star = SpawnPrefab("staffcoldlight2hm")
        star.Transform:SetPosition(x, y, z)
        star.index2hm = 1
        star.boss2hm = inst
    end
end
-- 2025.10.15 melon:angry2hm状态同时随机周围3处延迟攻击
local function attack_angry2hm(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    -- 一次近距离一次远距离
    local dist = 3
    if inst.attack_angry2hm_long then dist = 6 end
    inst.attack_angry2hm_long = not inst.attack_angry2hm_long
    -- 先上下左右4个地方
    local dx = {0, 0, -1, 1}
    local dz = {1, -1, 0, 0}
    for i=1, 4 do
        local attack_x = x + dx[i] * dist
        local attack_z = z + dz[i] * dist
        inst:DoTaskInTime(0.5, function(inst)
            SpawnPrefab("petrified_tree_fx_short").Transform:SetPosition(attack_x, 0, attack_z)
        end)
        inst:DoTaskInTime(1, function(inst)
            SpawnPrefab("petrified_tree_fx_normal").Transform:SetPosition(attack_x, 0, attack_z)
        end)
        inst:DoTaskInTime(2, function(inst)
            SpawnPrefab("collapse_small").Transform:SetPosition(attack_x, 0, attack_z)
            -- 造成伤害
            local players = TheSim:FindEntities(attack_x, 0, attack_z, 2, {"player"})
            for i, v in ipairs(players) do
                if v:IsValid() and v.components.combat then v.components.combat:GetAttacked_Internal(inst,30) end
            end
        end)
    end
end
local blacklist = {
    "watch_weapon_horn2hm"
}
local function toboss2hm(inst) -- 把猪变小boss
    if inst == nil or inst.components.combat == nil then return end
    strengthen_toboss(inst)
    inst.myscale = 1  -- 让影子攻击范围别太大
    -- 放弃回家
    if inst.components.homeseeker then inst.components.homeseeker = nil end
    -- 从附近寻找玩家作为攻击目标
    if inst.components.combat then inst.components.combat:SetRetargetFunction(1, RetargetFn2hm) end
    -- 掉落1个彩虹
    if inst.components.lootdropper ~= nil then
        local oldDropLoot = inst.components.lootdropper.DropLoot
        inst.components.lootdropper.DropLoot = function(self, ...)
            local loot = SpawnPrefab("opalpreciousgem") -- opalpreciousgem/orangegem
            if loot then loot.Transform:SetPosition(inst.Transform:GetWorldPosition()) end
            return oldDropLoot(self, ...)
        end
    end
    -- 升级后不再接受
    if inst.components.trader ~= nil then
        inst.components.trader:SetAbleToAcceptTest(function(...) return false end)
    end
    -- 增加实体抵抗
    -- if inst.components.planarentity == nil then inst:AddComponent("planarentity") end
    -- 打别的生物、被别的生物打无伤，免疫远程
    if inst.components.combat ~= nil then
        -- 被非玩家打无伤，免疫远程
        local _GetAttacked_Internal = inst.components.combat.GetAttacked_Internal -- 别少个self↓
        inst.components.combat.GetAttacked_Internal = function(self, attacker, damage, weapon, stimuli, spdamage, ...)
            -- 非玩家   或远程武器  或法杖类武器
            if attacker ~= nil and not attacker:HasTag("player") and not table.contains(blacklist, attacker.prefab) or 
            weapon and (weapon.components.projectile or string.find(weapon.prefab, "staff")) then
                if damage ~= nil then damage = 0 end
                if spdamage ~= nil then
                    for sptype, dmg in pairs(spdamage) do spdamage[sptype] = 0 end
                end
                -- 随机传送 防止永动机
                teleport2hm(inst)
            end
            return _GetAttacked_Internal(self, attacker, damage, weapon, stimuli, spdamage, ...)
        end
        -- 不能攻击其它生物
        local _CanHitTarget = inst.components.combat.CanHitTarget
        inst.components.combat.CanHitTarget = function(self, target, ...) -- 别少个self
            if target ~= nil and not target.components.sanity then return false end -- 没san不是玩家
            return _CanHitTarget(self, target, ...)
        end
    end
    -- 催眠抗性、冰冻抗性、免疫恐惧
    if inst.components.freezable ~= nil then inst.components.freezable:SetResistance(20) end -- 冰冻抗性
    if inst.components.sleeper ~= nil then inst.components.sleeper:SetResistance(20) end -- 催眠抗性
    if inst.components.hauntable ~= nil then inst.components.hauntable.panicable = false end -- 免疫恐惧
    -- 极光和矮星  矮星会消极光，2个随机1个？
    generatecoldstar(inst)
    -- 2025.10.21 melon:增加攻击特效，攻击后做发怒表情并在周围造成小范围群伤(只打玩家)   兼容写法
    if inst.sg and inst.sg.sg.states and inst.sg.sg.states.attack and inst.sg.sg.states.attack.events.animover then
        inst.sg.sg.states.attack.events.animover.fn = function(inst)
            inst.sg:GoToState("angry2hm")
        end
    end
end
-------------------------------------------------------------------------
-- 猪拒绝金子变boss
local function OnRefuseItem(inst, giver, item)
    -- 给紫宝石 影子不能给  goldnugget
    if item and item.prefab == "purplegem" and not inst.haspoor_armor2hm and not inst:HasTag("swc2hm") then
        if item.components.stackable then
            item.components.stackable:Get():Remove() -- 2025.10.3 melon:消耗紫宝石
        end
        inst.toBoss2hm = true -- 用于保存和读取
        toboss2hm(inst) -- 变boss
        addpoor_armor2hm(inst) -- 加劣质装甲
        -- 装备火腿
        if inst.components.inventory then
            local hambattemp = SpawnPrefab("hambat")
            hambattemp:AddTag("nosteal") -- 不会被猴子青蛙海獭击落
            if hambattemp.components.hambat2hm then
                hambattemp.components.hambat2hm.weight = 2.5 -- 重量2.5
                hambattemp.components.hambat2hm.dirty = 0
            end
            inst.components.inventory:Equip(hambattemp)
            inst.components.inventory:Equip(SpawnPrefab("footballhat"))
        end
        -- 回满血
        if inst.components.health ~= nil then inst.components.health:SetPercent(1) end
        -- 仇恨 = giver
        inst:DoTaskInTime(2,  function(inst) inst.components.combat:SuggestTarget(giver) end)
    end
end
-- 2025.5.3 melon:猪猪boss
if GetModConfigData("poor_armor") and GetModConfigData("pig_boss") then -- 开启普通生物装甲才起效
    AddPrefabPostInit("pigman", function(inst)  -- 给猪金子变小boss，掉落彩虹
        if not TheWorld.ismastersim then return end
        saveandloadtarget2hm(inst) -- 重写存储函数
        inst:DoTaskInTime(0, function()
            if inst.toBoss2hm then -- 强化一下 第2次进游戏执行
                toboss2hm(inst) -- 变boss
            end
            if not inst.toBoss2hm and inst.components.trader then
                local _onrefuse = inst.components.trader.onrefuse
                inst.components.trader.onrefuse = function(inst, giver, item)
                    _onrefuse(inst, giver, item)
                    OnRefuseItem(inst, giver, item)
                end
            end
        end)
    end)
    -- 2025.10.21 melon:加状态  发怒表情并在周围造成小范围群伤(只打玩家，不拆家)
    AddStategraphState("pig", State{
        name = "angry2hm",
        tags = { "attack", "busy" },
        onenter = function(inst)
            inst.Physics:Stop()
            inst.SoundEmitter:PlaySound("dontstarve/pig/oink")
            inst.AnimState:PlayAnimation("idle_angry")
            attack_angry2hm(inst) -- 在周围延迟攻击
        end,
        events ={EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),},
    })
end
-------------------------------------------------------------------------


