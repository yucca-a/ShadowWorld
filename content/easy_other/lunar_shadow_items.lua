-------------------------------------------------------------------------------------
--------------[[2025.5.3 melon:月后影后装备加强(裂隙/位面装备)]]---------------------
-- melon:随便加强一下，后面有好想法改了这里就行
--------------------------------------------------------------------------------
--[[修改列表：
月对暗影加成1.2，影对月加成1.2
虚空头 两下叠满
虚空长袍(虚空甲) 85%防御 霸体
亮茄盔甲(亮茄甲) 85%防御20位面防御
亮茄魔杖(亮茄杖) 20伤害
绝望石盔甲(绝望甲) 霸体效果(大理石甲的霸体)
亮茄头盔 微光
W.A.R.B.I.S.老瓦头 迅速叠满
W.A.R.B.I.S.老瓦甲 日常15%加速打架迅速叠满30%
嚎弹炮(狗牙吹箭) 80%返还子弹
护甲值/耐久*1.5 (护甲武器)
用梦魇鞍具不会被打下牛
熊罐可放新鲜度物品，料理0.1反鲜其它0.05倍
熊罐不受毒雾影响(disabledroponopen导致的问题) 互通容器也不影响
亮茄剑 带月灵攻击
虚空镰刀(暗影收割者) 恐惧弹药效果
冰眼结晶器 恒温15度，可做避茄针
亮茄粉碎者同样多用工具
恶液箱 锤掉返还
暗影伞(虚空伞) 隔热 装备时清空潮湿
暗影锤 位面伤害翻倍 饥饿速率恒为0 旺达用有夹击 攻击叠层暗影buff(5层怪100%易伤+吸血翻倍)
暗影回旋镖 旺达用有夹击
月三王增加掉落对应物品 鹿掉结晶器 熊掉熊罐 狗掉吹箭
阴郁皮弗娄牛铃 可收回牛
------部分月前内容------
蘑菇灯菌伞灯 反鲜、范围更大  (去除了所有监听事件，易出问题)

--]]
--------------------------------------------------------------------------------
-- 引用
local UpvalueHacker = require("upvaluehacker2hm")
--------------------------------------------------------------------------------
-- 月对暗影加成1.2，影对月加成1.2--------------------------------------------------
TUNING.WEAPONS_LUNARPLANT_VS_SHADOW_BONUS = 1.2
TUNING.WEAPONS_VOIDCLOTH_VS_LUNAR_BONUS = 1.2
-- 虚空头 两下叠满-----------------------------------------------------------------
TUNING.ARMOR_VOIDCLOTH_SETBONUS_PLANARDAMAGE_MAX_HITS = 2 -- 默认6次
-- 2025.8.26 melon:虚空头免疫酸雨
AddPrefabPostInit("voidclothhat", function(inst) inst:AddTag("acidrainimmune") end)
-- 虚空长袍(虚空甲) 85%防御 霸体----------------------------------------------------
TUNING.ARMOR_VOIDCLOTH_ABSORPTION = 0.85
AddPrefabPostInit("armor_voidcloth", function(inst) inst:AddTag("heavyarmor") end)
-- 亮茄盔甲(亮茄甲) 85%防御20位面防御-------------------------------------------------
TUNING.ARMOR_LUNARPLANT_ABSORPTION = 0.85
if TUNING.ARMOR_LUNARPLANT_PLANAR_DEF == 10 then -- 其它mod没改过再改
    TUNING.ARMOR_LUNARPLANT_PLANAR_DEF = 20 -- 默认10
end
-- 亮茄魔杖(亮茄杖) 20伤害---------------------------------------------------------
TUNING.STAFF_LUNARPLANT_PLANAR_DAMAGE = 20
-- 绝望石盔甲(绝望甲) 霸体效果(大理石甲的霸体)---------------------------------------
AddPrefabPostInit("armordreadstone", function(inst) inst:AddTag("heavyarmor") end)
-- 2025.8.2 melon:套装恢复速度更快  1.5 + 1 = 2.5
-- TUNING.ARMOR_DREADSTONE_REGEN_SETBONUS = TUNING.ARMOR_DREADSTONE_REGEN_SETBONUS + 1
-- 2025.8.2 melon:爬行恐惧回血时可给绝望头/甲回20耐久   写在爬行恐惧加强里
-- 亮茄头盔 微光--------------------------------------------------------------------
local function addlightcontrol(inst)
    -- 仅佩戴时发光
    if inst.components.equippable then
        local _onequipfn = inst.components.equippable.onequipfn
        inst.components.equippable.onequipfn = function(inst, owner)
            if inst.light2hm then inst.light2hm.Light:Enable(true) end -- 佩戴时开启
            _onequipfn(inst, owner)
        end
        local _onunequipfn = inst.components.equippable.onunequipfn
        inst.components.equippable.onunequipfn = function(inst, owner)
            if inst.light2hm then inst.light2hm.Light:Enable(false) end -- 脱下时关闭
            _onunequipfn(inst, owner)
        end
    end
end
AddPrefabPostInit("lunarplanthat", function(inst)
    if not TheWorld.ismastersim then return end
    if not (inst.light2hm and inst.light2hm:IsValid()) then
        inst.light2hm = SpawnPrefab("deathcurselight2hm") -- 微光
    end
    inst.light2hm.entity:SetParent(inst.entity)
    inst.light2hm.Light:SetFalloff(0.4)
    inst.light2hm.Light:SetIntensity(.7)
    inst.light2hm.Light:SetRadius(1.5) -- 范围大一点
    inst.light2hm.Light:SetColour(255 / 255, 255 / 255, 255 / 255)
    inst.light2hm.Light:Enable(false) -- 默认关闭
    -- 仅佩戴时发光
    addlightcontrol(inst)
    -- 修理函数里再加一次
    if inst.components.forgerepairable then
        local _onrepaired = inst.components.forgerepairable.onrepaired
        inst.components.forgerepairable.onrepaired = function(inst, ...)
            _onrepaired(inst, ...)
            addlightcontrol(inst)
        end
    end
end)

-- W.A.R.B.I.S.老瓦头 迅速叠满-----------------------------------------------------
TUNING.ARMOR_WAGPUNK_HAT_STAGE3 = 1.3 -- 伤害  默认1.2
AddPrefabPostInit("wagpunkhat", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.equippable then
        if inst.components.targettracker then
            -- 打架时
            local _ontimeupdatefn = inst.components.targettracker.ontimeupdatefn
            inst.components.targettracker.ontimeupdatefn = function(inst, ...)
                _ontimeupdatefn(inst, ...)
                local owner = inst.components.inventoryitem.owner
                if owner ~= nil and owner.components.combat ~= nil then
                    owner.components.combat.externaldamagemultipliers:SetModifier(inst, TUNING.ARMOR_WAGPUNK_HAT_STAGE3) -- 直接设为最高伤
                end
            end
            -- 换目标时
            local _onresettarget = inst.components.targettracker.onresettarget
            inst.components.targettracker.onresettarget = function(inst)
                _onresettarget(inst)
                local owner = inst.components.inventoryitem.owner
                if owner ~= nil and owner.components.combat ~= nil then
                    owner.components.combat.externaldamagemultipliers:SetModifier(inst, TUNING.ARMOR_WAGPUNK_HAT_STAGE3) -- 直接设为最高伤
                end
            end
        end
    end
end)
AddRecipePostInit("wagpunkhat",function(inst) -- 把材料的启迪碎片换成注能碎片
    inst.ingredients = {
        Ingredient("wagpunk_bits", 8), Ingredient("transistor", 3), Ingredient("moonglass_charged", 5)
    }
end)
-- W.A.R.B.I.S.老瓦甲 日常15%打架迅速叠满30%------------------------------------------
TUNING.WAGPUNK_MAXRANGE = 32 -- 索敌距离? 默认16
TUNING.ARMOR_WAGPUNK_HAT_ABSORPTION = 0.85 -- 防御85%
local function addspeed(inst)
    inst.components.equippable.walkspeedmult = 1.15 -- 穿的时候的加速
    -- 装备时
    local _onequipfn = inst.components.equippable.onequipfn
    inst.components.equippable.onequipfn = function(inst, ...)
        _onequipfn(inst, ...)
        inst.components.equippable.walkspeedmult = 1.15 -- 改回1.15
    end
end
AddPrefabPostInit("armorwagpunk", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.equippable then
        addspeed(inst) -- 修改加速
        if inst.components.targettracker then
            -- 重置目标时
            local _onresettarget = inst.components.targettracker.onresettarget
            inst.components.targettracker.onresettarget = function(inst)
                _onresettarget(inst)
                inst.components.equippable.walkspeedmult = 1.15 -- 改回1.15
            end
            -- 打架时
            local _ontimeupdatefn = inst.components.targettracker.ontimeupdatefn
            inst.components.targettracker.ontimeupdatefn = function(inst, ...)
                _ontimeupdatefn(inst, ...)
                inst.components.equippable.walkspeedmult = 1.30 -- 战斗时改回1.30
            end
        end
    end
    -- 修理函数里再加一次
    if inst.components.forgerepairable then
        local _onrepaired = inst.components.forgerepairable.onrepaired
        inst.components.forgerepairable.onrepaired = function(inst, ...)
            _onrepaired(inst, ...)
            addspeed(inst) -- 修改加速
        end
    end
end)
AddRecipePostInit("armorwagpunk",function(inst) -- 把材料的启迪碎片换成注能碎片
    inst.ingredients = {
        Ingredient("wagpunk_bits", 8), Ingredient("transistor", 3), Ingredient("moonglass_charged", 5)
    }
end)
-- 嚎弹炮(狗牙吹箭) 80%返还子弹-----------------------------------------------------
AddPrefabPostInit("houndstooth_blowpipe", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.weapon then
        local _onprojectilelaunched = inst.components.weapon.onprojectilelaunched
        inst.components.weapon.onprojectilelaunched = function(inst, attacker, target)
            if not inst.components.container:IsEmpty() and math.random() < 0.8 and attacker and attacker.components.inventory then
                -- attacker.components.inventory:GiveItem(SpawnPrefab("houndstooth")) -- 80%概率返还狗牙
                inst.components.container:GiveItem(SpawnPrefab("houndstooth")) -- 直接返还到吹箭
            end
            _onprojectilelaunched(inst, attacker, target)
        end
    end
end)
-- 护甲值/耐久*1.5-----------------------------------------------------------------
local armor_prefabs = {
    "lunarplanthat", "armor_lunarplant", "sword_lunarplant", "pickaxe_lunarplant", -- 亮茄头/甲/剑/锤
    "voidclothhat", "armor_voidcloth", "voidcloth_scythe", "shadow_battleaxe", -- 虚空头/甲/刀/槌
    "wagpunkhat", "armorwagpunk", "staff_lunarplant",  -- 老瓦头甲/茄杖
    "armordreadstone", "dreadstonehat", "armor_lunarplant_husk",  -- 绝望头/绝望甲/荆棘茄甲
}
for _,prefab in ipairs(armor_prefabs) do
    AddPrefabPostInit(prefab, function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.armor and inst.components.armor.maxcondition < 1000 then -- 护甲
            inst.components.armor.condition = inst.components.armor.condition * 1.5
            inst.components.armor.maxcondition = inst.components.armor.maxcondition * 1.5
        end
        if inst.components.finiteuses then -- 工具
            inst.components.finiteuses.current = inst.components.finiteuses.current * 1.5
            inst.components.finiteuses.total = inst.components.finiteuses.total * 1.5
        end
    end)
end
-- 用梦魇鞍具不会被打下牛----------------------------------------------------
AddStategraphPostInit("wilson", function(sg)
    if sg.events and sg.events.knockback and sg.events.knockback.fn then
        local _fn = sg.events.knockback.fn
        sg.events.knockback.fn = function(inst, data)-- 改为hook方式
            if not inst.components.health:IsDead()
            -- and not inst:HasTag("wereplayer")
            and (inst:HasTag("player") or inst.components.sanity) -- 2025.10.3 melon:是玩家
            -- and not inst.sg:HasStateTag("parrying")
            -- and not (data.forcelanded or inst.components.inventory:EquipHasTag("heavyarmor") or inst:HasTag("heavybody"))
            and inst.components.rider and inst.components.rider.saddle -- 骑牛
            and inst.components.rider.saddle.prefab == "saddle_shadow" then -- 梦魇鞍
                inst.sg:GoToState("hit", data) -- 如果用的是梦魇鞍具就改为普通受击
            else
                _fn(inst, data)
            end
        end
    end
end)
-- 熊罐可放新鲜度物品，料理0.1反鲜其它0.05倍----------------------------------------------------
-- 2025.8.12 melon:熊罐可放晾干食物item.dryplants2hm
local containers = require("containers")
if containers and containers.params and containers.params.beargerfur_sack then
    local olditemtestfn = containers.params.beargerfur_sack.itemtestfn
    containers.params.beargerfur_sack.itemtestfn = function(container, item, slot)
        return olditemtestfn == nil or olditemtestfn(container, item, slot) or item and item:HasTag("fresh") or item:HasTag("stale") or item:HasTag("spoiled") or item.dryplants2hm
    end
end
AddPrefabPostInit("beargerfur_sack", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.preserver then
        -- 料理0.1反鲜其它0.05倍
        local function perish_rate_multiplier(inst, item) return item and (item:HasTag("beargerfur_sack_valid") or item:HasTag("preparedfood")) and -0.1 or -0.05 end -- 其它0.05反鲜
        inst.components.preserver:SetPerishRateMultiplier(perish_rate_multiplier)
    end
end)
-- 2025.5.3 melon:熊罐不受毒雾影响(disabledroponopen导致的问题)-----------------------
local spore_resist_prefabs = {
    "beargerfur_sack", "spicepack", "rabbitkinghorn_container",
    "tacklestation2hm", "shadow_container", "skullchest", -- 钓具容器、暗影空间
    "elixir_container", "alterguardianhat", -- 野餐盒、启迪头
    "mushroom_light", "mushroom_light2", -- 蘑菇灯、菌伞灯
    "alterguardianhatshard", -- 启迪碎片
}
local function TryPerish(item)
    if item:IsInLimbo() then
        local owner = item.components.inventoryitem ~= nil and item.components.inventoryitem.owner or nil
        -- 里面的食物不扣新鲜:熊罐、厨师袋 钓具容器/暗影空间/兔王洞/妥协骷髅箱在(0,0,0)点
        if owner and table.contains(spore_resist_prefabs, owner.prefab) then return end
        if owner == nil or
            (   owner.components.container ~= nil and
                not owner.components.container:IsOpen() and
                owner:HasOneOfTags({ "structure", "portablestorage" })
            )
        then
            return
        end
    end
    item.components.perishable:ReducePercent(TUNING.TOADSTOOL_SPORECLOUD_ROT)
end
local SPOIL_CANT_TAGS = { "small_livestock" }
local SPOIL_ONEOF_TAGS = { "fresh", "stale", "spoiled" }
local function DoAreaSpoil(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, inst.components.aura.radius, nil, SPOIL_CANT_TAGS, SPOIL_ONEOF_TAGS)
    for i, v in ipairs(ents) do
        TryPerish(v)
    end
end

local sporecloud = {"sporecloud", "sporecloud_toad"} -- 妥协与原版毒雾
for i, v in pairs(sporecloud) do
    AddPrefabPostInit(v, function(inst) -- 孢子云  毒雾
        if not TheWorld.ismastersim then return end
        inst._spoiltask:Cancel() -- 取消原有任务
        inst._spoiltask = inst:DoPeriodicTask(inst.components.aura.tickperiod, DoAreaSpoil, inst.components.aura.tickperiod * .5)
    end)
end
-- 亮茄剑 带月灵攻击---------------------------------------------------------------------
local function canattack_fn(inst)
    inst.canattack_task2hm = nil
    if not inst.canattack2hm then inst.canattack2hm = true end
end
local function alterguardian_spawngestalt_fn(inst, owner, data)
    -- 间隔0.4s防止出现太多
    if not inst.canattack2hm then
        if not inst.canattack_task2hm then inst.canattack_task2hm = inst:DoTaskInTime(0.4, canattack_fn) end
        return
    end
    inst.canattack2hm = false
    if not inst.canattack_task2hm then inst.canattack_task2hm = inst:DoTaskInTime(0.4, canattack_fn) end
    --
    if owner ~= nil and (owner.components.health == nil or not owner.components.health:IsDead()) then
        local target = data.target
        if target and target ~= owner and target:IsValid() and (target.components.health == nil or not target.components.health:IsDead() and not target:HasTag("structure") and not target:HasTag("wall")) then
            if data.weapon ~= nil and data.projectile == nil
                    and (data.weapon.components.projectile ~= nil
                        or data.weapon.components.complexprojectile ~= nil
                        or data.weapon.components.weapon:CanRangedAttack()) then
                return
            end
            local x, y, z = target.Transform:GetWorldPosition()
            local gestalt = SpawnPrefab("alterguardianhat_projectile")
            local r = GetRandomMinMax(3, 5)
            local delta_angle = GetRandomMinMax(-90, 90)
            local angle = (owner:GetAngleToPoint(x, y, z) + delta_angle) * DEGREES
            gestalt.Transform:SetPosition(x + r * math.cos(angle), y, z + r * -math.sin(angle))
            gestalt:ForceFacePoint(x, y, z)
            gestalt:SetTargetPosition(Vector3(x, y, z))
            gestalt.components.follower:SetLeader(owner)
            owner.gestalt2hm = gestalt -- 存储月灵gestalt
            if owner.components.sanity ~= nil then
                owner.components.sanity:DoDelta(1, true) -- 攻击+san?
            end
        end
    end
end
local function alterguardian_onequip(inst, owner)
    inst.alterguardian_spawngestalt_fn = function(_owner, _data) alterguardian_spawngestalt_fn(inst, _owner, _data) end
    inst:ListenForEvent("onattackother", inst.alterguardian_spawngestalt_fn, owner)
end

local function alterguardian_onunequip(inst, owner)
    inst:RemoveEventCallback("onattackother", inst.alterguardian_spawngestalt_fn, owner)
    if owner.gestalt2hm ~= nil then -- 删除月灵
        if owner.gestalt2hm:IsValid() then owner.gestalt2hm:Remove() end
        owner.gestalt2hm = nil
    end
end
local function addspawngestalt(inst) -- 加虚影攻击
    if inst.components.equippable then
        local _onequipfn = inst.components.equippable.onequipfn
        inst.components.equippable.onequipfn = function(inst, owner)
            alterguardian_onequip(inst, owner)
            _onequipfn(inst, owner)
        end
        local _onunequipfn = inst.components.equippable.onunequipfn
        inst.components.equippable.onunequipfn = function(inst, owner)
            alterguardian_onunequip(inst, owner)
            _onunequipfn(inst, owner)
        end
    end
end
AddPrefabPostInit("sword_lunarplant", function(inst)
    if not TheWorld.ismastersim then return end
    inst.canattack2hm = true
    inst.setcanattacktask2hm = nil
    addspawngestalt(inst) -- 加虚影攻击
    -- 修理函数里再加一次
    if inst.components.forgerepairable then
        local _onrepaired = inst.components.forgerepairable.onrepaired
        inst.components.forgerepairable.onrepaired = function(inst, ...)
            _onrepaired(inst, ...)
            addspawngestalt(inst) -- 加虚影攻击
        end
    end
end)
-- 虚空镰刀(暗影收割者) 恐惧弹药效果----------------------------------------------
-- 先抄原版代码
local AOE_TARGET_MUST_TAGS     = { "_combat", "_health" }
local AOE_TARGET_CANT_TAGS     = { "INLIMBO", "notarget", "noattack", "flight", "invisible", "playerghost", "companion", "player", "wall" }
local AOE_TARGET_CANT_TAGS_PVP = { "INLIMBO", "notarget", "noattack", "flight", "invisible", "playerghost" }
local AOE_RADIUS_PADDING = 3
local NUM_HORROR_VARIATIONS = 3 -- 原本6
local MAX_HORRORS = 2 -- 原本4
local HORROR_PERIOD = 1
local INITIAL_RND_PERIOD = 0.35
local HORROR_SETBONUS_TICKS = 5  -- 原本TUNING.SLINGSHOT_HORROR_SETBONUS_TICKS
local HORROR_TICKS = 3  -- 攻击次数 原本TUNING.SLINGSHOT_HORROR_TICKS
local function UpdateFlash(target, data, id, r, g, b)
    if data.flashstep < 4 then
        local value = (data.flashstep > 2 and 4 - data.flashstep or data.flashstep) * 0.05
        if target.components.colouradder == nil then
            target:AddComponent("colouradder")
        end
        target.components.colouradder:PushColour(id, value * r, value * g, value * b, 0)
        data.flashstep = data.flashstep + 1
    else
        target.components.colouradder:PopColour(id)
        data.task:Cancel()
    end
end
local function OnUpdate_HorrorFuel(target, attacker, data, endtime, first)
    if not (target.components.health and target.components.health:IsDead()) and
        target.components.combat and target.components.combat:CanBeAttacked()
    then
        local rnd = math.random(math.clamp(NUM_HORROR_VARIATIONS - #data.tasks, 2, NUM_HORROR_VARIATIONS / 2))
        local variation = data.variations[rnd]
        for i = rnd, NUM_HORROR_VARIATIONS - 1 do
            data.variations[i] = data.variations[i + 1]
        end
        data.variations[NUM_HORROR_VARIATIONS] = variation

        local fx
        if #data.pool > 0 then
            fx = table.remove(data.pool)
            fx:ReturnToScene()
        else
            fx = SpawnPrefab("slingshotammo_horrorfuel_debuff_fx")
            fx.pool = data.pool
            fx.onrecyclefn = RecycleHorrorDebuffFX
        end
        fx.entity:SetParent(target.entity)
        fx:Restart(attacker, target, variation, data.pool, first)
    end

    if GetTime() >= endtime then
        table.remove(data.tasks, 1):Cancel()
        if #data.tasks <= 0 then
            for i, v in ipairs(data.pool) do
                v:Remove()
            end
            target._slingshot_horror = nil
        end
    end
end
local function StartFlash(inst, target, r, g, b)
    local data = { flashstep = 1 }
    local id = inst.prefab.."::"..tostring(inst.GUID)
    data.task = target:DoPeriodicTask(0, UpdateFlash, nil, data, id, r, g, b)
    UpdateFlash(target, data, id, r, g, b)
end
local function DoAOECallback(inst, x, z, radius, cb, attacker, target)
    local combat = attacker and attacker.components.combat or nil

    if combat == nil then
        return
    end

    for i, v in ipairs(TheSim:FindEntities(x, 0, z, radius + AOE_RADIUS_PADDING, AOE_TARGET_MUST_TAGS, TheNet:GetPVPEnabled() and AOE_TARGET_CANT_TAGS_PVP or AOE_TARGET_CANT_TAGS)) do
        if v ~= target and
            combat:CanTarget(v) and
            v.components.combat:CanBeAttacked(attacker) and
            not combat:IsAlly(v)
        then
            local range = radius + v:GetPhysicsRadius(0)

            if v:GetDistanceSqToPoint(x, 0, z) < range * range then
                cb(inst, attacker, v)
            end
        end
    end
end
local function DoHit_HorrorFuel(inst, attacker, target, instant)
    if target and target:IsValid() then
        StartFlash(inst, target, 1, 0, 0)
        local data = target._slingshot_horror
        if data == nil then
            data = { tasks = {}, variations = {}, pool = {} }
            for i = 1, NUM_HORROR_VARIATIONS do
                table.insert(data.variations, math.random(i), i)
            end
            target._slingshot_horror = data
        elseif #data.tasks >= MAX_HORRORS then
            table.remove(data.tasks, 1):Cancel()
        end
        local numticks = inst.voidbonusenabled and HORROR_SETBONUS_TICKS or HORROR_TICKS -- 攻击次数
        local endtime = GetTime() + HORROR_PERIOD * (numticks - 1) - 0.001
        if instant then
            table.insert(data.tasks, target:DoPeriodicTask(HORROR_PERIOD, OnUpdate_HorrorFuel, nil, attacker, data, endtime))
            OnUpdate_HorrorFuel(target, attacker, data, endtime, true)
        else
            local initialdelay = math.random() * INITIAL_RND_PERIOD
            endtime = endtime + initialdelay
            table.insert(data.tasks, target:DoPeriodicTask(HORROR_PERIOD, OnUpdate_HorrorFuel, initialdelay, attacker, data, endtime))
        end
    end
end
local function OnHit_HorrorFuel(inst, attacker, target) -- 调用函数
	if target and target:IsValid() then
		DoHit_HorrorFuel(inst, attacker, target, true)
		if inst.magicamplified then
			local x, y, z = target.Transform:GetWorldPosition()
			DoAOECallback(inst, x, z, TUNING.SLINGSHOT_MAGIC_AMP_RANGE, DoHit_HorrorFuel, attacker, target)
			local fx = SpawnPrefab("slingshot_aoe_fx")
			fx.Transform:SetPosition(x, 0, z)
			fx:SetColorType("horror")
		end
	end
end -- 恐惧弹效果↑
-- 潜伏梦魇的两面夹击
local function SpawnDoubleHornAttack2hm(attacker, target)
    if attacker.age_state then
        local left = SpawnPrefab("watch_weapon_horn2hm") -- 自定义袭击
        left:SetUp(attacker, target, nil)
        if attacker.age_state == "normal" or attacker.age_state == "old" then -- 中老年有第二个
            local right = SpawnPrefab("watch_weapon_horn2hm")
            right:SetUp(attacker, target, left) -- 和left配对
        end
        if attacker.age_state == "old" then -- 老年有第3个
            local three = SpawnPrefab("watch_weapon_horn2hm")
            three:SetUp(attacker, target, left, true)
        end
    end
end
local function addhorrorfuel(inst) -- 加恐惧弹药效果、旺达夹击
    inst.notHornAttack2hm = true
    if inst.components.weapon then
        local _onattack = inst.components.weapon.onattack
        inst.components.weapon.onattack = function(inst, attacker, target)
            _onattack(inst, attacker, target)
            OnHit_HorrorFuel(inst, attacker, target) -- 恐惧弹药效果原本函数
            -- 旺达触发夹击
            if attacker.prefab == "wanda" and inst.notHornAttack2hm then
                inst.notHornAttack2hm = false
                -- 间隔1秒防止Horn触发Horn
                inst:DoTaskInTime(1, function(inst) inst.notHornAttack2hm = true end)
                SpawnDoubleHornAttack2hm(attacker, target, 17)
            end
        end
    end
end
AddPrefabPostInit("voidcloth_scythe", function(inst)
    if not TheWorld.ismastersim then return end
    addhorrorfuel(inst) -- 加恐惧弹药效果
    -- 修理函数里再加一次
    if inst.components.forgerepairable then
        local _onrepaired = inst.components.forgerepairable.onrepaired
        inst.components.forgerepairable.onrepaired = function(inst, ...)
            _onrepaired(inst, ...)
            addhorrorfuel(inst) -- 加恐惧弹药效果
        end
    end
end)
-- 冰眼结晶器--------------------------------------------------------------------
TUNING.DEERCLOPSEYEBALL_SENTRYWARD_TEMPERATURE_OVERRIDE = 15 -- 冰眼结晶器温度15度
-- 这样写会有bug:查找亮茄标签的目标是否攻击，但没有攻击组件
AddPrefabPostInit("deerclopseyeball_sentryward", function(inst)
    inst:AddTag("lunarthrall_plant") -- 生成亮茄时也判断结晶器，这样充当避茄针了
    if not TheWorld.ismastersim then return end
    -- 放冰眼后:每10秒让恒温场半径(35)内生长的作物快进10秒(暂停的植物不催熟)
    local GROW_TAGS2HM = { "plant", "farm_plant", "bush", "pickable" }
    local GROW_STEP2HM = 10 -- 每次催熟10秒
    -- 直接平移 pickable 的剩余重生时间;不要用 pickable:LongUpdate:
    -- 它内部会走 SpringGrowthMod,春天时每10秒调用一次剩余会乘 SPRING_GROWTH_MODIFIER(0.75),
    -- 变成指数衰减,几分钟就能把数小时的剩余直接催熟
    local function SpeedUpPickable2hm(plant)
        local pickable = plant.components.pickable
        if pickable == nil or pickable.paused or plant:HasTag("withered") then
            return
        end
        if pickable.useexternaltimer then
            if pickable.getregentimertime ~= nil and pickable.setregentimertime ~= nil then
                local remain = pickable.getregentimertime(plant)
                if remain ~= nil then
                    pickable.setregentimertime(plant, math.max(0, remain - GROW_STEP2HM))
                end
            end
        elseif pickable.targettime ~= nil then
            local remain = pickable.targettime - GetTime() - GROW_STEP2HM
            if remain <= 0 then
                pickable:Regen()
            else
                if pickable.task ~= nil then
                    pickable.task:Cancel()
                    pickable.task = nil
                end
                pickable.task = plant:DoTaskInTime(remain, function(inst)
                    if inst.components.pickable ~= nil then
                        inst.components.pickable:Regen()
                    end
                end)
                pickable.targettime = GetTime() + remain
            end
        end
    end
    local function GrowNearbyPlants2hm()
        if inst._active == nil or not inst._active:value() then return end -- 没眼球不生效
        local x, y, z = inst.Transform:GetWorldPosition()
        local plants = TheSim:FindEntities(x, y, z, TUNING.DEERCLOPSEYEBALL_SENTRYWARD_RADIUS, nil, nil, GROW_TAGS2HM)
        for i, plant in ipairs(plants) do
            if plant.components.pickable then
                SpeedUpPickable2hm(plant)
            end
            if plant.components.growable then
                plant.components.growable:LongUpdate(GROW_STEP2HM)
            end
        end
    end
    inst.plantgrowtask2hm = inst:DoPeriodicTask(10, GrowNearbyPlants2hm)
    -- 放冰眼后:每分钟给范围内耕地补水补肥(凭空)
    local WATER_AMOUNT2HM = 30 -- 每次补水量0~100
    local FERT_AMOUNT2HM = 20 -- 每次三样养分各加值,一格多种植物按整格叠加
    local function WaterAndFertilizeSoil2hm()
        if inst._active == nil or not inst._active:value() then return end -- 没眼球不生效
        local map = TheWorld.Map
        local fm = TheWorld.components.farming_manager
        if map == nil or fm == nil then return end
        local x, y, z = inst.Transform:GetWorldPosition()
        local tx, ty = map:GetTileCoordsAtPoint(x, y, z)
        local rad = TUNING.DEERCLOPSEYEBALL_SENTRYWARD_RADIUS
        local tr = math.ceil(rad / TILE_SCALE)
        local w, h = map:GetSize()
        for dx = -tr, tr do
            for dz = -tr, tr do
                local cx, cy = tx + dx, ty + dz
                if cx >= 0 and cy >= 0 and cx < w and cy < h and map:GetTile(cx, cy) == WORLD_TILES.FARMING_SOIL then
                    local px, py, pz = map:GetTileCenterPoint(cx, cy)
                    local ddx, ddz = px - x, pz - z
                    if ddx * ddx + ddz * ddz <= rad * rad then
                        fm:AddSoilMoistureAtPoint(px, py, pz, WATER_AMOUNT2HM)
                        fm:AddTileNutrients(cx, cy, FERT_AMOUNT2HM, FERT_AMOUNT2HM, FERT_AMOUNT2HM)
                    end
                end
            end
        end
    end
    inst.soilcaretask2hm = inst:DoPeriodicTask(60, WaterAndFertilizeSoil2hm)
end)
-- 修bug 判断结晶器时没有攻击组件然后报错
local PLANT_MUST = {"lunarthrall_plant"}
local PLANT_CANT = {"structure"} -- 避免找结晶器
local TARGET_MUST_TAGS = { "_combat", "character" }
local TARGET_CANT_TAGS = { "INLIMBO","lunarthrall_plant", "lunarthrall_plant_end" }
local function Retarget(inst)
    --print("RETARGET")
    if not inst.no_targeting then
        local target = FindEntity(
            inst,
            TUNING.LUNARTHRALL_PLANT_RANGE,
            function(guy)
                local total = 0
                local x,y,z = inst.Transform:GetWorldPosition()
                if inst.tired then
                    return nil
                end
                local plants = TheSim:FindEntities(x,y,z, 15, PLANT_MUST, PLANT_CANT)-- 加cant
                for i, plant in ipairs(plants)do
                    if plant ~= inst then
                        if plant.components.combat.target and plant.components.combat.target == guy then
                            total = total +1
                        end
                    end
                end
                if total < 3 then
                    return inst.components.combat:CanTarget(guy)
                end
            end,
            TARGET_MUST_TAGS,
            TARGET_CANT_TAGS
        )
        if inst.vinelimit > 0 then
            if target and ( not inst.components.freezable or not inst.components.freezable:IsFrozen()) then
                local pos = inst:GetPosition()
                local theta = math.random()*TWOPI
                local radius = TUNING.LUNARTHRALL_PLANT_MOVEDIST
                local offset = Vector3(radius * math.cos( theta ), 0, -radius * math.sin( theta ))
                pos = pos + offset

                if TheWorld.Map:IsVisualGroundAtPoint(pos.x,pos.y,pos.z) then

                    local vine = SpawnPrefab("lunarthrall_plant_vine_end")
                    vine.Transform:SetPosition(pos.x,pos.y,pos.z)
                    vine.Transform:SetRotation(inst:GetAngleToPoint(pos.x, pos.y, pos.z))
                    vine.components.freezable:SetRedirectFn(vine_addcoldness)
                    vine.sg:RemoveStateTag("nub")
                    if inst.tintcolor then
                        vine.AnimState:SetMultColour(inst.tintcolor, inst.tintcolor, inst.tintcolor, 1)
                        vine.tintcolor = inst.tintcolor
                    end

                    inst.components.colouradder:AttachChild(vine)

                    vine.parentplant = inst
                    table.insert(inst.vines,vine)
                    inst.vinelimit = inst.vinelimit -1
                    inst:DoTaskInTime(0,function() vine:ChooseAction() end)

                    return target
                end
            end
        end
    end
end
AddPrefabPostInit("lunarthrall_plant", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.combat then
        -- 必须要用set，里面有DoPeriodicTask
        inst.components.combat:SetRetargetFunction(1, Retarget)
    end
end)
------------------------------------------------------------------------
-- 2025.5.3 melon:亮茄粉碎者同样多用工具 -------------------------------------------------------
-- local函数复制自easy_other
local function NewTerraform(self, pt, doer, ...)
    self.inst.RefreshSpecialAbility2hm(self.inst)
    return self.oldAction2hm(self, pt, doer, ...)
end
local TILLSOIL_IGNORE_TAGS = {"NOBLOCK", "player", "FX", "INLIMBO", "DECOR", "WALKABLEPLATFORM", "soil"}
local function NewTill(self, pt, doer, ...)
    if self.inst.oldtill2hm then return self.oldAction2hm(self, pt, doer, ...) end
    if not self.oldAction2hm(self, pt, doer, ...) then return false end
    local inst = self.inst
    local x, y, z = pt:Get()
    if not TheWorld.Map:GetTileAtPoint(x, 0, z) == WORLD_TILES.FARMING_SOIL then return false end
    local cx, cy, cz = TheWorld.Map:GetTileCenterPoint(x, y, z)
    -- 获取地皮中心坐标点
    local spacing = 1.3
    -- 土堆间距
    local farm_plant_pos = {}
    -- 农场作物坐标
    local totaluse = 0
    -- 清除这块地皮上多余的土堆
    local ents = TheWorld.Map:GetEntitiesOnTileAtPoint(cx, 0, cz)
    for _, ent in ipairs(ents) do
        if ent ~= doer and ent:HasTag("soil") then -- 是土堆，则清除
            if not ent:HasTag("NOCLICK") then totaluse = totaluse - 4 end
            ent:PushEvent("collapsesoil")
        end
    end
    -- 生成整齐的土堆
    for i = -1, 1 do
        for j = -1, 1 do
            local nx = cx + spacing * i
            local nz = cz + spacing * j
            local rot = doer and doer.Transform:GetRotation()
            if rot then
                if rot <= -90 then
                    nx = cx + spacing * j
                    nz = cz - spacing * i
                elseif rot <= 0 then
                    nx = cx - spacing * i
                    nz = cz - spacing * j
                elseif rot >= 0 then
                    nx = cx - spacing * j
                    nz = cz + spacing * i
                end
            end
            -- 生成的预置物名,默认为土堆
            local spawnItem = "farm_soil"
            if TheWorld.Map:IsDeployPointClear(Vector3(nx, 0, nz), nil, GetFarmTillSpacing(), nil, nil, nil, TILLSOIL_IGNORE_TAGS) then
                local plant = SpawnPrefab(spawnItem)
                plant.Transform:SetPosition(nx, 0, nz)
                totaluse = totaluse + 4
            end
        end
    end
    inst.components.finiteuses:Use(totaluse)
    return true
end
local function RemoveSpecialAbility(inst)
    if inst.specialtask2m then
        inst.specialtask2m:Cancel()
        inst.specialtask2m = nil
    end
    local owner = inst.components.inventoryitem:GetGrandOwner()
    if owner and owner.sg and owner.sg:HasStateTag("busy") then
        inst.specialtask2m = inst:DoTaskInTime(6, inst.RemoveSpecialAbility2hm)
        return
    end
    -- 干草叉,耕地机
    inst:RemoveInherentAction(ACTIONS.TERRAFORM)
    inst:RemoveComponent("terraformer")
end
local function RefreshSpecialAbility(inst)
    if inst.specialtask2m then
        inst.specialtask2m:Cancel()
        inst.specialtask2m = inst:DoTaskInTime(6, inst.RemoveSpecialAbility2hm)
    end
end
local function AddSpecialAbility(inst)
    if inst.specialtask2m then
        inst.specialtask2m:Cancel()
        inst.specialtask2m = inst:DoTaskInTime(6, inst.RemoveSpecialAbility2hm)
        return
    end
    inst.specialtask2m = inst:DoTaskInTime(6, inst.RemoveSpecialAbility2hm)
    -- 干草叉,耕地机
    inst:AddInherentAction(ACTIONS.TERRAFORM)
    inst:AddComponent("terraformer")
    inst.components.terraformer.oldAction2hm = inst.components.terraformer.Terraform
    inst.components.terraformer.Terraform = NewTerraform
end
local function modifyuseconsumption(uses, action, doer, target)
    if (action == ACTIONS.ROW or action == ACTIONS.ROW_FAIL or action == ACTIONS.ROW_CONTROLLER) and doer:HasTag("master_crewman") then
        uses = uses / 2
    end
    return uses
end
AddPrefabPostInit("pickaxe_lunarplant", function(inst)
    inst:AddTag("allow_action_on_impassable")
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("ondropped", AddSpecialAbility)
    inst.AddSpecialAbility2hm = AddSpecialAbility
    inst.RefreshSpecialAbility2hm = RefreshSpecialAbility
    inst.RemoveSpecialAbility2hm = RemoveSpecialAbility
    -- 干草叉,掉地上才有
    inst.components.finiteuses:SetConsumption(ACTIONS.TERRAFORM, 0.5)
    -- 剃须刀
    -- inst:AddComponent("shaver2hm") -- 2025.10.4 melon:去除
    -- 铲子
    inst.components.tool:SetAction(ACTIONS.DIG, TUNING.MULTITOOL_AXE_PICKAXE_EFFICIENCY)
    inst:AddInherentAction(ACTIONS.DIG)
    inst.components.finiteuses:SetConsumption(ACTIONS.DIG, 4)
    -- 园艺锄,耕地机
    inst:AddInherentAction(ACTIONS.TILL)
    inst:AddComponent("farmtiller")
    inst.components.farmtiller.oldAction2hm = inst.components.farmtiller.Till
    inst.components.farmtiller.Till = NewTill
    inst.components.finiteuses:SetConsumption(ACTIONS.TILL, 4)
    -- 桨
    inst:AddComponent("oar")
    inst.components.oar.force = TUNING.BOAT.OARS.MONKEY.FORCE
    inst.components.oar.max_velocity = TUNING.BOAT.OARS.MONKEY.MAX_VELOCITY
    inst.components.finiteuses:SetConsumption(ACTIONS.ROW, 0.2)
    inst.components.finiteuses:SetConsumption(ACTIONS.ROW_CONTROLLER, 0.2)
    inst.components.finiteuses:SetConsumption(ACTIONS.ROW_FAIL, TUNING.BOAT.OARS.MONKEY.ROW_FAIL_WEAR * 0.2)
    inst.components.finiteuses.modifyuseconsumption = modifyuseconsumption
    -- 劈砍动作
    if ACTIONS.HACK and TOOLACTIONS[ACTIONS.HACK.id] then inst.components.tool:SetAction(ACTIONS.HACK) end
    -- 斧子(新增)
    inst.components.tool:SetAction(ACTIONS.CHOP, TUNING.MULTITOOL_AXE_PICKAXE_EFFICIENCY)
    inst:AddInherentAction(ACTIONS.CHOP)
    inst.components.finiteuses:SetConsumption(ACTIONS.CHOP, 1)
    -- 钓鱼
    inst:AddComponent("fishingrod")
    inst.components.fishingrod:SetWaitTimes(2, 20) -- 等鱼事件 钓竿(4, 40)
    inst.components.fishingrod:SetStrainTimes(0, 5)
    -- 斧子铲子("tool")需要在修好后重新加
    if inst.components.forgerepairable then
        local _onrepaired = inst.components.forgerepairable.onrepaired
        inst.components.forgerepairable.onrepaired = function(inst, ...)
            _onrepaired(inst, ...)
            -- 铲子
            inst.components.tool:SetAction(ACTIONS.DIG, TUNING.MULTITOOL_AXE_PICKAXE_EFFICIENCY)
            inst.components.finiteuses:SetConsumption(ACTIONS.DIG, 4)
            -- 斧子
            inst.components.tool:SetAction(ACTIONS.CHOP, TUNING.MULTITOOL_AXE_PICKAXE_EFFICIENCY)
            inst.components.finiteuses:SetConsumption(ACTIONS.CHOP, 1)
        end
    end
end)
-- 划船
AddComponentPostInit("playercontroller", function(self)
    if self.automation_tasks and self.automation_tasks.paddle and self.automation_tasks.paddle.IsValidOar then
        local oldIsValidOar = self.automation_tasks.paddle.IsValidOar
        self.automation_tasks.paddle.IsValidOar = function(ent, ...)
            return ent ~= nil and (oldIsValidOar(ent, ...) or ent.prefab == "pickaxe_lunarplant")
        end
    end
end)
-- 恶液箱 锤掉返还------------------------------------------------------------------
AddPrefabPostInit("gelblob_storage", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.workable then
        inst.components.workable.onfinish = function(inst)
            -- inst.components.lootdropper:DropLoot() -- 不执行掉落(包括材料)
            -- 生成套件
            local kit = SpawnPrefab("gelblob_storage_kit")
            kit.Transform:SetPosition(inst.Transform:GetWorldPosition())
            -- 特效
            local fx = SpawnPrefab("collapse_small")
            fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
            fx:SetMaterial("rock")
            -- 掉落里面物品
            if inst.components.inventoryitemholder ~= nil then
                inst.components.inventoryitemholder:TakeItem()
            end
            inst:Remove() -- 直接移除?
        end
    end
end)
-- 暗影伞(虚空伞) 隔热 装备时清空潮湿----------------------------------------------------
AddComponentPostInit("sheltered", function(self) -- 隐蔽
    local SetSheltered = self.SetSheltered
    self.SetSheltered = function(self, issheltered, level, ...)
        if self.inst.components.inventory and self.inst.components.temperature then
            self.level2hm = level
            local equip = self.inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if equip and equip:IsValid() and equip.prefab == "voidcloth_umbrella" and equip.components.fueled then
                issheltered = true
                -- level = self.inst.components.temperature.current < self.inst.components.temperature.overheattemp - 4 and 2 or math.max(level or 1, 1)
                level = 2 -- melon:直接固定2
            end
        end
        SetSheltered(self, issheltered, level, ...)
    end
end)
local function addclearmoisture(inst) -- 加装备时清空潮湿值
    if inst.components.equippable then
        local _onequipfn = inst.components.equippable.onequipfn
        inst.components.equippable.onequipfn = function(inst, owner)
            if owner and owner.components.moisture then owner.components.moisture:SetPercent(0) end
            _onequipfn(inst, owner)
        end
    end
end
AddPrefabPostInit("voidcloth_umbrella", function(inst)
    if not TheWorld.ismastersim then return end
    addclearmoisture(inst) -- 加装备时清空潮湿值
    -- 修理函数里再加一次
    if inst.components.forgerepairable then
        local _onrepaired = inst.components.forgerepairable.onrepaired
        inst.components.forgerepairable.onrepaired = function(inst, ...)
            _onrepaired(inst, ...)
            addclearmoisture(inst) -- 加装备时清空潮湿值
        end
    end
end)
-- 暗影锤 ---------------------------------------------------------------------------
TUNING.SHADOW_BATTLEAXE.LEVEL[1].PLANAR_DAMAGE = 10 * 2 -- 升级伤害
TUNING.SHADOW_BATTLEAXE.LEVEL[2].PLANAR_DAMAGE = 14 * 2
TUNING.SHADOW_BATTLEAXE.LEVEL[3].PLANAR_DAMAGE = 18 * 2
TUNING.SHADOW_BATTLEAXE.LEVEL[4].PLANAR_DAMAGE = 22 * 2

TUNING.SHADOW_BATTLEAXE.LEVEL[2].HUNGER_RATE = 0 -- 饥饿速率
TUNING.SHADOW_BATTLEAXE.LEVEL[3].HUNGER_RATE = 0
TUNING.SHADOW_BATTLEAXE.LEVEL[4].HUNGER_RATE = 0
-- 暗影锤
-- 攻击命中给怪挂"恐惧缠身"(和弹弓恐惧弹药/虚空镰刀同机制): 持续5秒每秒17位面伤害+暗影特效
-- 每击叠1层(缠身数=层数,最多5层),叠满5层触发"暗影锤buff": 怪物100%易伤(承伤翻倍)+暗影锤攻击该怪吸血翻倍
-- buff持续5秒(满层锁5秒,停止攻击后缠身逐个到期开始衰减,重新叠满回5秒),层数归零buff结束
local SBA_MAX_LAYERS = 5
local SBA_HIT_PLANAR = 17
local SBA_VULN_MULT = 2.0
local SBA_VULN_KEY = "shadow_battleaxe_vuln2hm"
local SBA_FX_TICKS = 5 -- 每层缠身持续5秒(每秒1次tick) = buff持续5秒
local SBA_FX_MAX = 5   -- 最多5层缠身并行(叠满5层触发buff)

-- 17位面伤害
local function SBAOnTick(target, attacker, data, endtime)
    if not (target.components.health and target.components.health:IsDead()) and
        target.components.combat and target.components.combat:CanBeAttacked()
    then
        local fx = SpawnPrefab("slingshotammo_horrorfuel_debuff_fx")
        if fx then
            if fx.components.planardamage then fx.components.planardamage:SetBaseDamage(SBA_HIT_PLANAR) end
            fx.entity:SetParent(target.entity)
            fx:Restart(attacker, target, math.random(NUM_HORROR_VARIATIONS), nil, true)
        end
    end
    if GetTime() >= endtime then
        table.remove(data.tasks, 1):Cancel()
        if #data.tasks <= 0 then
            target._sba_fx2hm = nil
            -- 层数归零: 暗影锤buff结束(移除易伤)
            if target._sba_buff2hm then
                target._sba_buff2hm = nil
                if target.components and target.components.combat then
                    target.components.combat.externaldamagetakenmultipliers:RemoveModifier(target, SBA_VULN_KEY)
                end
            end
        end
    end
end

-- 攻击命中挂缠身(每击1层,最多5层); 叠满5层激活buff
local function SBADoHit(attacker, target)
    local data = target._sba_fx2hm
    if data == nil then
        data = { tasks = {} }
        target._sba_fx2hm = data
    elseif #data.tasks >= SBA_FX_MAX then
        table.remove(data.tasks, 1):Cancel()
    end
    local endtime = GetTime() + SBA_FX_TICKS - 1 - 0.001
    table.insert(data.tasks, target:DoPeriodicTask(1, SBAOnTick, nil, attacker, data, endtime))
    SBAOnTick(target, attacker, data, endtime) -- 立即先造成一下
    -- 叠满5层 → 激活暗影锤buff(100%易伤)
    if #data.tasks >= SBA_MAX_LAYERS and not target._sba_buff2hm then
        target._sba_buff2hm = true
        if target.components and target.components.combat then
            target.components.combat.externaldamagetakenmultipliers:SetModifier(target, SBA_VULN_MULT, SBA_VULN_KEY)
        end
    end
end

-- 目标移除: 清理缠身任务与buff
local function SBAClear(target)
    if target._sba_fx2hm then
        for i, v in ipairs(target._sba_fx2hm.tasks) do
            v:Cancel()
        end
        target._sba_fx2hm = nil
    end
    target._sba_buff2hm = nil
    if target.components and target.components.combat then
        target.components.combat.externaldamagetakenmultipliers:RemoveModifier(target, SBA_VULN_KEY)
    end
end

-- 暗影锤攻击命中: 挂缠身叠层+buff吸血翻倍
local function SBAOnAttack(weapon, attacker, target)
    if not target or not target:IsValid() then return end
    if not target.components or not target.components.combat then return end
    if target.components.health and target.components.health:IsDead() then return end
    if not attacker or not attacker:IsValid() then return end

    -- 恐惧缠身: 挂一层(最多5层), 叠满5层触发buff(易伤)
    SBADoHit(attacker, target)
    -- buff期间攻击该怪: 吸血翻倍(补吸一份), san按回血一半扣(满血不掉san)
    if target._sba_buff2hm and weapon._lifesteal and weapon._lifesteal > 0
        and attacker.components.health and attacker.components.health:IsHurt() then
        local mult = attacker.components.aoediminishingreturns and attacker.components.aoediminishingreturns.mult:Get() or 1
        attacker.components.health:DoDelta(weapon._lifesteal * mult, false, "shadow_battleaxe")
        if attacker.components.sanity then
            attacker.components.sanity:DoDelta(-weapon._lifesteal * mult * TUNING.SHADOW_BATTLEAXE.LIFE_STEAL_SANITY_LOSS_SCALE)
        end
    end
    -- 目标移除清理
    if not target._sba_cleanup2hm then
        target._sba_cleanup2hm = true
        target:ListenForEvent("onremove", function() SBAClear(target) end)
    end
end

local function addhorn(inst) -- 加旺达夹击
    inst.notHornAttack2hm = true
    if inst.components.weapon then
        local _onattack = inst.components.weapon.onattack
        -- broken修复重建组件后onattack被原版重置,重新包装;非重建重复调用不重复包
        if _onattack ~= inst._sba_wrap2hm then
            inst._sba_wrap2hm = function(inst, attacker, target)
                _onattack(inst, attacker, target)
                SBAOnAttack(inst, attacker, target) -- 暗影锤叠层/暗影buff机制
                -- 旺达触发夹击
                if attacker.prefab == "wanda" and inst.notHornAttack2hm then
                    inst.notHornAttack2hm = false
                    -- 间隔1秒防止Horn触发Horn
                    inst:DoTaskInTime(1, function(inst) inst.notHornAttack2hm = true end)
                    SpawnDoubleHornAttack2hm(attacker, target, 17)
                end
            end
            inst.components.weapon.onattack = inst._sba_wrap2hm
        end
    end
end
AddPrefabPostInit("shadow_battleaxe", function(inst)
    if not TheWorld.ismastersim then return end
    addhorn(inst) -- 加旺达夹击
    -- 修理函数里再加一次
    if inst.components.forgerepairable then
        local _onrepaired = inst.components.forgerepairable.onrepaired
        inst.components.forgerepairable.onrepaired = function(inst, ...)
            _onrepaired(inst, ...)
            addhorn(inst) -- 加旺达夹击
        end
    end
end)
-- 暗影回旋镖 ------------------------------------------------------------------------
local function addhornboomerang(inst) -- 加旺达夹击
    inst.notHornAttack2hm = true
    if inst.components.weapon then
        local _onprojectilelaunched = inst.components.weapon.onprojectilelaunched
        inst.components.weapon.onprojectilelaunched = function(inst, attacker, target)
            if _onprojectilelaunched then _onprojectilelaunched(inst, attacker, target) end -- 要判空
            -- 旺达触发夹击
            if attacker.prefab == "wanda" and inst.notHornAttack2hm then
                inst.notHornAttack2hm = false
                -- 间隔1秒防止Horn触发Horn
                inst:DoTaskInTime(1, function(inst) inst.notHornAttack2hm = true end)
                SpawnDoubleHornAttack2hm(attacker, target, 17)
            end
        end
    end
end
AddPrefabPostInit("voidcloth_boomerang", function(inst)
    if not TheWorld.ismastersim then return end
    addhornboomerang(inst) -- 加旺达夹击
    -- 修理函数里再加一次
    if inst.components.forgerepairable then
        local _onrepaired = inst.components.forgerepairable.onrepaired
        inst.components.forgerepairable.onrepaired = function(inst, ...)
            _onrepaired(inst, ...)
            addhornboomerang(inst) -- 加旺达夹击
        end
    end
end)
-- 月三王增加掉落对应物品-------------------------------------------------------------
AddSimPostInit(function() -- 2025.10.21
    if LootTables['mutateddeerclops'] then -- 2025.10.22加判空
        table.insert(LootTables['mutateddeerclops'], {'deerclopseyeball_sentryward_kit',1}) -- 月鹿掉结晶器  晶体独眼巨鹿
    end
    if LootTables['mutateddeerclops'] then
        table.insert(LootTables['mutatedbearger'], {'beargerfur_sack',1}) -- 月熊掉熊罐  装甲熊獾
    end
    if LootTables['mutateddeerclops'] then
        table.insert(LootTables['mutatedwarg'], {'houndstooth_blowpipe',1}) -- 月狗掉吹箭  附身座狼
    end
end)
-- 阴郁皮弗娄牛铃 可收回牛------------------------------------------------------------
TUNING.SHADOW_BEEF_BELL_REVIVE_COOLDOWN = 240 -- melon:复活冷却改为240秒
-- 下面函数复制自easy_other.lua-----------------------
local function resetbeefaloskin(inst, clothingdata, player)
    if inst.components.skinner_beefalo and player and player:IsValid() and clothingdata then
        local newdata = deepcopy(clothingdata)
        inst.components.skinner_beefalo:ApplyTargetSkins(newdata, player)
    end
end
local function processnewsummonbeefalo(inst, beefalo, record)
    if beefalo.components.lootdropper then
        beefalo.components.lootdropper:SetLoot()
        beefalo.components.lootdropper:SetChanceLootTable()
        beefalo.components.lootdropper.SpawnLootPrefab = nillootdropperSpawnLootPrefab
        beefalo.components.lootdropper.GenerateLoot = emptytablefn
        beefalo.components.lootdropper.DropLoot = emptytablefn
    end
    if beefalo.components.writeable then beefalo.components.writeable:SetOnWritingEndedFn() end
    if inst and record then
        beefalo.Transform:SetPosition(inst.Transform:GetWorldPosition())
        local owner = inst.components.inventoryitem and inst.components.inventoryitem:GetGrandOwner()
        if not inst.initskin2hm and owner and owner:IsValid() and owner:HasTag("player") then
            inst.initskin2hm = true
            if record.clothing and beefalo.components.skinner_beefalo then beefalo:DoTaskInTime(0, resetbeefaloskin, record.clothing, owner) end
        end
    end
end
local function killbeefalo(inst, beefalo)
    if beefalo and beefalo:IsValid() and beefalo.components.health and not beefalo.components.health:IsDead() then beefalo.components.health:Kill() end
end
local function on_beef_disappeared(inst, beefalo)
    inst:RemoveTag("hasbeefalo2hm")
    -- 牛被拐走了,被拐走的牛直接杀掉
    if not inst.components.persistent2hm.data.beefalotmp and beefalo and beefalo:IsValid() and beefalo.components.health and
        not beefalo.components.health:IsDead() then inst:DoTaskInTime(0, killbeefalo, beefalo) end
end
local function on_stop_use(inst)
    if inst.components.useabletargeteditem then inst.components.useabletargeteditem.inuse_targeted = true end
    if inst:GetBeefalo() then
        -- 已有牛则召回牛
        local beefalo = inst:GetBeefalo()
        -- 牛死时不执行操作!!!!!!!!!!!!!!!!!!不然牛寄了一右键就崩
        if beefalo and beefalo.components.health:IsDead() then return end
        if beefalo.components.rideable.rider then beefalo.components.rideable.rider.components.rider:ActualDismount() end
        inst.components.persistent2hm.data.beefalotmp = nil
        local data = {}
        inst:OnSave(data)
        inst.components.persistent2hm.data.beefalotmp = data
        if inst:HasTag("hasbeefalo2hm") then
            inst:PushEvent("player_despawn")
            inst:RemoveTag("hasbeefalo2hm")
        end
    elseif inst.components.persistent2hm.data.beefalotmp then
        -- 没有牛但有召回存档则召唤牛
        inst.tmpenable2hm = true
        inst:OnLoad(inst.components.persistent2hm.data.beefalotmp)
        if inst:GetBeefalo() then
            inst:AddTag("hasbeefalo2hm")
            local beefalo = inst:GetBeefalo()
            processnewsummonbeefalo(inst, beefalo, inst.components.persistent2hm.data.beefalotmp)
        end
        inst.components.persistent2hm.data.beefalotmp = nil
        inst.tmpenable2hm = nil
    end
end
-- 升级后改造牛铃铛和牛
local function upgradebeef_bell(inst)
    inst:AddTag("minotaurhorn2hm")
    if inst.components.useabletargeteditem then
        inst.components.useabletargeteditem:SetOnStopUseFn(on_stop_use)
    end
    if inst.components.leader then inst.components.leader.onremovefollower = on_beef_disappeared end
    if inst:GetBeefalo() then
        -- 升级时有牛,则改造牛
        inst:AddTag("hasbeefalo2hm")
        local beefalo = inst:GetBeefalo()
        processnewsummonbeefalo(inst, beefalo)
    elseif not inst.components.persistent2hm.data.beefalotmp then
        -- 开局升级时没有牛,则要么牛死亡中,要么牛召回了
        on_beef_disappeared(inst)
    end
    if inst.components.useabletargeteditem then inst.components.useabletargeteditem.inuse_targeted = true end
end

local function processpersistent(inst)
    if inst.components.persistent2hm.data.minotaurhorn then
        upgradebeef_bell(inst)
        inst.components.inventoryitem:ChangeImageName("shadow_beef_bell_linked")
        inst.AnimState:PlayAnimation("idle2", true)
        inst:AddTag("nobundling")
    end
end
-- 显示
STRINGS.ACTIONS.STOPUSINGITEM.SHOWBEEFSHADOW2HM = TUNING.isCh2hm and "召唤" or "Out"
STRINGS.ACTIONS.STOPUSINGITEM.HIDEBEEFSHADOW2HM = TUNING.isCh2hm and "召回" or "In"
local oldSTOPUSINGITEMstrfn = ACTIONS.STOPUSINGITEM.strfn
ACTIONS.STOPUSINGITEM.strfn = function(act)
    local res = oldSTOPUSINGITEMstrfn(act)
    if res == "SHADOW_BEEF_BELL" and act.invobject and act.invobject.prefab == "shadow_beef_bell" and act.invobject:HasTag("minotaurhorn2hm") then
        return act.invobject:HasTag("hasbeefalo2hm") and "HIDEBEEFSHADOW2HM" or "SHOWBEEFSHADOW2HM"
    end
    return res
end -- 以上函数为复制，略微修改------------------------------------
local function ShadowBell_CanReviveTarget(inst, target, doer)
    return target.GetBeefBellOwner ~= nil and target:GetBeefBellOwner() == doer and inst.components.rechargeable and inst.components.rechargeable:IsCharged() -- 充能好才能用
end
local function ShadowBell_ReviveTarget(inst, target, doer)
    target:OnRevived(inst)
    -- doer:AddDebuff("shadow_beef_bell_curse", "shadow_beef_bell_curse") -- 扣上限
    inst.components.rechargeable:Discharge(TUNING.SHADOW_BEEF_BELL_REVIVE_COOLDOWN)
end
-- 主要部分
AddPrefabPostInit("shadow_beef_bell", function(inst)
    if not TheWorld.ismastersim then return end
    inst.CanReviveTarget = ShadowBell_CanReviveTarget -- 牛铃不cd才能复活
    inst.ReviveTarget = ShadowBell_ReviveTarget -- 去除扣上限
    -- 修改使用函数
    local _onusefn = inst.components.useabletargeteditem.onusefn
    inst.components.useabletargeteditem.onusefn = function(inst, target, user)
        if inst.components.useabletargeteditem then inst.components.useabletargeteditem.inuse_targeted = true end
        local beefalo = inst:GetBeefalo()
        -- 牛死时不执行操作!!!!!!!!!!!!!!!!!!不然牛寄了一右键就崩
        if beefalo and beefalo.components.health and beefalo.components.health:IsDead() then
            return false, "BEEF_DEAD"
        end
        local success, word = _onusefn(inst, target, user)
        -- 未绑定过牛时，成功绑定牛，执行保存牛数据
        if not inst.components.persistent2hm.data.minotaurhorn and success then
            inst.components.persistent2hm.data.minotaurhorn = true
            local beefalo = inst:GetBeefalo()
            if beefalo.components.health then beefalo.components.health:SetPercent(1) end
            if beefalo.components.rideable then
                if beefalo.components.rideable.rider then beefalo.components.rideable.rider.components.rider:ActualDismount() end
                beefalo.components.rideable:SetSaddle(nil, nil)
            end
            if beefalo.components.container then beefalo.components.container:DropEverything() end
            if beefalo.components.inventory then beefalo.components.inventory:DropEverything(false) end
            inst.components.persistent2hm.data.beefalo = nil
            inst.components.persistent2hm.data.beefalotmp = nil
            local data = {}
            inst:OnSave(data)
            inst.components.persistent2hm.data.beefalo = data
            upgradebeef_bell(inst)
        end
        return success, word
    end
    if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
    inst:DoTaskInTime(0, processpersistent) -- 修改牛铃
end)
-- 阴郁牛铃cd时牛尸体也不消失
local function ShouldKeepCorpse(inst)
    local leader = inst.components.follower:GetLeader()
    return
        leader ~= nil and
        leader:HasTag("shadowbell") and
        leader.components.rechargeable ~= nil
        -- and leader.components.rechargeable:IsCharged() -- 充能好了
end
AddPrefabPostInit("beefalo", function(inst)
    if not TheWorld.ismastersim then return end
    -- 是否保持尸体
    inst.ShouldKeepCorpse = ShouldKeepCorpse
end)

----------------------------------------------------------------------------------------
-----------------------------[[其它内容]]--------------------------------------------
-- 不知道放哪里先放这里
----------------------------------------------------------------------------------------
-- test
-------------------------------------------------------------------------------------
