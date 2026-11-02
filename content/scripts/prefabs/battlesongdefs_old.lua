-- 2025.9.10 melon:已改为兼容写法，此文件未加入PrefabFiles因此不起效


-- 定义一个函数，用于为装备添加耐久度倍率修饰符
-- inst: 通常是一个实例对象，可看作是触发添加耐久度倍率效果的源头，例如某种技能、物品或事件实例
-- equip: 要添加耐久度倍率修饰符的装备对象
local function AddDurabilityMult(inst, equip)
    -- 进行条件检查，确保装备对象存在，并且该装备具备武器组件和有限使用次数组件
    -- 只有满足这些条件，才能对装备的耐久度倍率进行修改操作
    if equip ~= nil and equip.components.weapon ~= nil and equip.components.finiteuses ~= nil then
        -- 调用装备武器组件的 attackwearmultipliers 的 SetModifier 方法
        -- inst 作为修饰符的唯一标识符，用于后续可能的移除操作
        -- TUNING.BATTLESONG_DURABILITY_MOD 是具体的耐久度倍率值，通过该值来调整装备的耐久消耗速度
        equip.components.weapon.attackwearmultipliers:SetModifier(inst, TUNING.BATTLESONG_DURABILITY_MOD)
    end
end

-- 定义一个函数，用于移除装备上的耐久度倍率修饰符
-- inst: 与添加修饰符时使用的相同实例对象，作为移除修饰符的唯一标识
-- equip: 要移除耐久度倍率修饰符的装备对象
local function RemoveDurabilityMult(inst, equip)
    -- 进行条件检查，确保装备对象存在，并且该装备具备武器组件和有限使用次数组件
    -- 只有满足这些条件，才能执行移除装备上耐久度倍率修饰符的操作
    if equip ~= nil and equip.components.weapon ~= nil and equip.components.finiteuses ~= nil then
        -- 调用装备武器组件的 attackwearmultipliers 的 RemoveModifier 方法
        -- 传入 inst 作为要移除的修饰符的标识符，从而将之前添加的耐久度倍率修饰符移除
        equip.components.weapon.attackwearmultipliers:RemoveModifier(inst)
    end
end

-- 定义一个函数，用于在目标对象位置添加敌人减益特效
-- fx: 特效的预制体名称，指定要生成的特效类型
-- target: 目标对象，特效将在该对象的位置生成
local function AddEnemyDebuffFx(fx, target)
    -- 使用 DoTaskInTime 方法，在随机的 0 到 0.25 秒延迟后执行后续代码
    -- 这种随机延迟可以让特效的生成有一定的随机性，避免所有特效同时生成，增强视觉效果的多样性
    target:DoTaskInTime(math.random()*0.25, function()
        -- 获取目标对象的世界坐标
        local x, y, z = target.Transform:GetWorldPosition()
        -- 根据传入的预制体名称生成特效对象
        local fx = SpawnPrefab(fx)
        -- 检查特效对象是否成功生成
        if fx then
            -- 如果特效对象存在，将其位置设置为目标对象的位置
            fx.Transform:SetPosition(x, y, z)
        end
        -- 返回生成的特效对象，如果生成失败则返回 nil
        return fx
    end)
end

-- 定义一个函数，用于复活目标对象
-- target: 要复活的目标对象
-- singer: 执行复活操作的对象，可看作是复活效果的触发者
local function DoRevive(target, singer)
    -- 触发目标对象的 "respawnfromghost" 事件，模拟从幽灵状态复活的过程
    -- 传入一个包含触发者信息的表，其中 user 字段为执行复活操作的对象
    target:PushEvent("respawnfromghost", { user = singer })

    -- 获取目标对象的世界坐标
    local x, y, z = target.Transform:GetWorldPosition()
    -- 生成一个名为 "lightning" 的预制体对象，通常用于表示复活时的特效
    local fx = SpawnPrefab("lightning")
    -- 检查特效对象是否成功生成
    if fx then
        -- 如果特效对象存在，将其位置设置为目标对象的位置
        fx.Transform:SetPosition(x, y, z)
    end
end

-- 定义一个函数，用于检查攻击数据是否有效
-- attacker: 攻击者对象
-- data: 攻击相关的数据，包含了攻击的详细信息，如使用的武器、是否为弹射物等
local function CheckValidAttackData(attacker, data)
    -- 检查攻击数据是否存在
    if data then
        -- 检查攻击是否由弹射物发起，并且该弹射物已经弹射过
        -- 如果是弹射过的弹射物，认为该攻击数据无效，不进行后续处理
        if data.projectile and data.projectile.components.projectile and data.projectile.components.projectile:IsBounced() then
            -- 弹射过的弹射物攻击不计入有效攻击
            return false
        -- 检查攻击使用的武器是否没有库存物品组件
        -- 一些用于范围伤害的假 "武器"（如火焰喷射器特效）没有库存物品组件，认为这类攻击数据无效
        elseif data.weapon and data.weapon.components.inventoryitem == nil then
            -- 用于范围伤害的假 "武器" 攻击不计入有效攻击
            return false
        end
    end
    -- 如果不满足上述无效条件，则认为攻击数据有效
    return true
end

-- Possible params: TICK_RATE, ONAPPLY, ONEXTENDED, ONDETACH, TICK_FN, ATTACH_FX, DETTACH_FX, INSTANT, DELTA, USES, SOUND
-- INSTANT, DELTA AND TARGET_PLAYERS are quote only
-- I'm keeping USES around in case we change our minds and decide the make the battlesongs consumable
-- 定义一个包含各种战斗歌曲效果定义的表
local song_defs =
{
   	battlesong_durability =
	{
		  -- 当歌曲效果应用到目标时触发的函数
        ONAPPLY = function(inst, target)
            -- 检查目标是否有可施加减益效果的组件，并且该组件是否可用
            if target.components.debuffable ~= nil and target.components.debuffable:IsEnabled() then
                -- 监听目标的攻击事件
                inst:ListenForEvent("onattackother", function(attacker, data) 
                    -- 为目标添加“”增益效果
                    target.components.debuffable:AddDebuff("buff_attackbuff", "buff_attackbuff")
                end, target)
            end
        end,
		ATTACH_FX = "battlesong_attach",
		LOOP_FX = "battlesong_durability_fx",
		DETACH_FX = "battlesong_detach",
		SOUND = "dontstarve_DLC001/characters/wathgrithr/song/durability",
	},


    -- 定义 "生命增益之歌" 的效果
    battlesong_healthgain =
    {
        -- 当歌曲效果应用到目标时执行的函数
        ONAPPLY = function(inst, target)
            -- 检查目标是否有健康组件
            if target.components.health then
                -- 监听目标的攻击其他对象事件
                inst:ListenForEvent("onattackother", function(attacker, data)
                    -- 检查攻击数据是否有效
                    if CheckValidAttackData(attacker, data) then
                        -- 检查目标是否有 "battlesinger" 标签
                        if target:HasTag("battlesinger") then
                            -- 如果目标是歌手，根据对应配置增加生命值
                            target.components.health:DoDelta(TUNING.BATTLESONG_HEALTHGAIN_DELTA_SINGER)
                        else
                            -- 如果目标不是歌手，根据通用配置增加生命值
                            target.components.health:DoDelta(TUNING.BATTLESONG_HEALTHGAIN_DELTA)
                        end
                    end
                end, target)
            end
        end,

        -- 歌曲效果附加到目标时播放的特效名称
        ATTACH_FX = "battlesong_attach",
        -- 歌曲效果持续期间循环播放的特效名称
        LOOP_FX = "battlesong_healthgain_fx",
        -- 歌曲效果从目标移除时播放的特效名称
        DETACH_FX = "battlesong_detach",
        -- 歌曲播放时的音效名称
        SOUND = "dontstarve_DLC001/characters/wathgrithr/song/healthgain",
    },

    -- 定义 "理智增益之歌" 的效果
    battlesong_sanitygain =
    {
        -- 当歌曲效果应用到目标时执行的函数
        ONAPPLY = function(inst, target)
            -- 检查目标是否有理智组件
            if target.components.sanity then
                -- 监听目标的攻击其他对象事件
                inst:ListenForEvent("onattackother", function(attacker, data)
                    -- 检查攻击数据是否有效
                    if CheckValidAttackData(attacker, data) then
                        -- 根据配置增加目标的理智值
                        target.components.sanity:DoDelta(TUNING.BATTLESONG_SANITYGAIN_DELTA)
                    end
                end, target)
            end
        end,

        -- 歌曲效果附加到目标时播放的特效名称
        ATTACH_FX = "battlesong_attach",
        -- 歌曲效果持续期间循环播放的特效名称
        LOOP_FX = "battlesong_sanitygain_fx",
        -- 歌曲效果从目标移除时播放的特效名称
        DETACH_FX = "battlesong_detach",
        -- 歌曲播放时的音效名称
        SOUND = "dontstarve_DLC001/characters/wathgrithr/song/sanitygain",
    },

    -- 理智光环之歌的定义
battlesong_sanityaura =
    {
        ONAPPLY = function(inst, target)
            if target.components.debuffable ~= nil and target.components.debuffable:IsEnabled() then
                inst:ListenForEvent("onattackother", function(attacker, data)
                    -- 新增条件：当角色是女武神且正在骑牛时不触发效果
                    if target.prefab == "wathgrithr" and          -- 确认是女武神角色
                       target.components.rider ~= nil and          -- 有骑乘组件
                       target.components.rider:IsRiding() then    -- 正在骑乘状态
                        return
                    end
                    target.components.debuffable:AddDebuff("buff_kitespeed", "buff_kitespeed")
                end, target)
            end
        end,
        ATTACH_FX = "battlesong_attach",
        LOOP_FX = "battlesong_sanityaura_fx",
        DETACH_FX = "battlesong_detach",
        SOUND = "dontstarve_DLC001/characters/wathgrithr/song/sanityaura",
    },

    -- 定义 "火焰抗性之歌" 的效果
battlesong_fireresistance =
{
    -- 当歌曲效果应用到目标时执行的函数
    ONAPPLY = function(inst, target)
        -- 检查目标是否有健康组件
        if target.components.health ~= nil then
            -- 设置目标的外部火焰伤害倍率修饰符为 0，实现 100% 免疫火焰伤害
            target.components.health.externalfiredamagemultipliers:SetModifier(inst, 0)
        end
    end,

    -- 当歌曲效果从目标移除时执行的函数
    ONDETACH = function(inst, target)
        -- 检查目标是否有健康组件
        if target.components.health ~= nil then
            -- 移除目标的外部火焰伤害倍率修饰符
            target.components.health.externalfiredamagemultipliers:RemoveModifier(inst)
        end
    end,

    -- 歌曲效果附加到目标时播放的特效名称
    ATTACH_FX = "battlesong_attach",
    -- 歌曲效果持续期间循环播放的特效名称
    LOOP_FX = "battlesong_fireresistance_fx",
    -- 歌曲效果从目标移除时播放的特效名称
    DETACH_FX = "battlesong_detach",
    -- 歌曲播放时的音效名称
    SOUND = "dontstarve_DLC001/characters/wathgrithr/song/fireresistance",
},

    -- 定义 "月之共鸣之歌" 的效果
    battlesong_lunaraligned =
    {
        -- 当歌曲效果应用到目标时执行的函数
        ONAPPLY = function(inst, target)
            -- 检查目标是否有伤害类型抗性组件
            if target.components.damagetyperesist ~= nil then
                -- 为目标添加对月之属性伤害的抗性
                target.components.damagetyperesist:AddResist("lunar_aligned", inst, TUNING.BATTLESONG_LUNARALIGNED_LUNAR_RESIST, "battlesong_lunaraligned")
            end

            -- 检查目标是否有伤害类型加成组件
            if target.components.damagetypebonus ~= nil then
                -- 为目标添加对影之属性敌人的伤害加成
                target.components.damagetypebonus:AddBonus("shadow_aligned", inst, TUNING.BATTLESONG_LUNARALIGNED_VS_SHADOW_BONUS, "battlesong_lunaraligned")
            end
        end,

        -- 当歌曲效果从目标移除时执行的函数
        ONDETACH = function(inst, target)
            -- 检查目标是否有伤害类型抗性组件
            if target.components.damagetyperesist ~= nil then
                -- 移除目标对月之属性伤害的抗性
                target.components.damagetyperesist:RemoveResist("lunar_aligned", inst, "battlesong_lunaraligned")
            end

            -- 检查目标是否有伤害类型加成组件
            if target.components.damagetypebonus ~= nil then
                -- 移除目标对影之属性敌人的伤害加成
                target.components.damagetypebonus:RemoveBonus("shadow_aligned", inst, "battlesong_lunaraligned")
            end
        end,

        -- 歌曲效果附加到目标时播放的特效名称
        ATTACH_FX = "battlesong_attach",
        -- 歌曲效果持续期间循环播放的特效名称
        LOOP_FX = "battlesong_lunaraligned_fx",
        -- 歌曲效果从目标移除时播放的特效名称
        DETACH_FX = "battlesong_detach",
        -- 歌曲播放时的音效名称
        SOUND = "dontstarve_DLC001/characters/wathgrithr/song/lunar",
        -- 激活该歌曲效果需要的技能
        REQUIRE_SKILL = "wathgrithr_allegiance_lunar",
    },

    -- 定义 "影之共鸣之歌" 的效果
    battlesong_shadowaligned =
    {
        -- 当歌曲效果应用到目标时执行的函数
        ONAPPLY = function(inst, target)
            -- 检查目标是否有伤害类型抗性组件
            if target.components.damagetyperesist ~= nil then
                -- 为目标添加对影之属性伤害的抗性
                target.components.damagetyperesist:AddResist("shadow_aligned", inst, TUNING.BATTLESONG_SHADOWALIGNED_SHADOW_RESIST, "battlesong_shadowaligned")
            end

            -- 检查目标是否有伤害类型加成组件
            if target.components.damagetypebonus ~= nil then
                -- 为目标添加对月之属性敌人的伤害加成
                target.components.damagetypebonus:AddBonus("lunar_aligned", inst, TUNING.BATTLESONG_SHADOWALIGNED_VS_LUNAR_BONUS, "battlesong_shadowaligned")
            end
        end,

        -- 当歌曲效果从目标移除时执行的函数
        ONDETACH = function(inst, target)
            -- 检查目标是否有伤害类型抗性组件
            if target.components.damagetyperesist ~= nil then
                -- 移除目标对影之属性伤害的抗性
                target.components.damagetyperesist:RemoveResist("shadow_aligned", inst, "battlesong_shadowaligned")
            end

            -- 检查目标是否有伤害类型加成组件
            if target.components.damagetypebonus ~= nil then
                -- 移除目标对月之属性敌人的伤害加成
                target.components.damagetypebonus:RemoveBonus("lunar_aligned", inst, "battlesong_shadowaligned")
            end
        end,

        -- 歌曲效果附加到目标时播放的特效名称
        ATTACH_FX = "battlesong_attach",
        -- 歌曲效果持续期间循环播放的特效名称
        LOOP_FX = "battlesong_shadowaligned_fx",
        -- 歌曲效果从目标移除时播放的特效名称
        DETACH_FX = "battlesong_detach",
        -- 歌曲播放时的音效名称
        SOUND = "dontstarve_DLC001/characters/wathgrithr/song/shadow",
        -- 激活该歌曲效果需要的技能
        REQUIRE_SKILL = "wathgrithr_allegiance_shadow",
    },


    ------------------------------------------------
    ------------- Quotes/Instant songs -------------
    ------------------------------------------------

 battlesong_instant_taunt =
{
    -- 当歌曲即时生效时执行的函数
    ONINSTANT = function(singer, target)
        -- 检查目标是否没有 "bird" 标签且具有战斗组件
        -- 避免对鸟类目标使用嘲讽效果，因为鸟类可能没有合适的战斗逻辑
        if not target:HasTag("bird") and target.components.combat then
            -- 将目标的攻击目标设置为歌手，使其攻击歌手
            target.components.combat:SetTarget(singer)
            -- 在目标位置添加敌人减益特效，增强视觉效果
            AddEnemyDebuffFx("battlesong_instant_taunt_fx", target)
        end
    end,

    -- 标记该歌曲为即时生效类型
    INSTANT = true,
    -- 歌曲使用时消耗的资源量，具体数值由配置 TUNING.BATTLESONG_INSTANT_COST 决定
    DELTA = TUNING.BATTLESONG_INSTANT_COST,
    -- 歌曲的冷却时间，具体数值由配置 TUNING.SKILLS.WATHGRITHR.BATTLESONG_INSTANT_COOLDOWN 决定
    COOLDOWN = TUNING.SKILLS.WATHGRITHR.BATTLESONG_INSTANT_COOLDOWN,
    -- 歌曲效果附加到目标时播放的特效名称
    ATTACH_FX = "battlesong_instant_taunt_fx",
    -- 歌曲播放时的音效名称
    SOUND = "dontstarve_DLC001/characters/wathgrithr/quote/taunt",
},

-- 定义即时战斗歌曲 "恐慌之歌" 的效果
battlesong_instant_panic =
{
    -- 当歌曲即时生效时执行的函数
    ONINSTANT = function(singer, target)
        -- 检查目标是否有可作祟组件，并且该组件是否支持恐慌效果
        if target.components.hauntable ~= nil and target.components.hauntable.panicable then
            -- 使目标陷入恐慌状态，持续时间由配置 TUNING.BATTLESONG_PANIC_TIME 决定
            target.components.hauntable:Panic(TUNING.BATTLESONG_PANIC_TIME)
            -- 在目标位置添加敌人减益特效，增强视觉效果
            AddEnemyDebuffFx("battlesong_instant_panic_fx", target)
        end
    end,

    -- 标记该歌曲为即时生效类型
    INSTANT = true,
    -- 歌曲使用时消耗的资源量，具体数值由配置 TUNING.BATTLESONG_INSTANT_COST 决定
    DELTA = TUNING.BATTLESONG_INSTANT_COST,
    -- 歌曲的冷却时间，具体数值由配置 TUNING.SKILLS.WATHGRITHR.BATTLESONG_INSTANT_COOLDOWN 决定
    COOLDOWN = TUNING.SKILLS.WATHGRITHR.BATTLESONG_INSTANT_COOLDOWN,
    -- 歌曲效果附加到目标时播放的特效名称
    ATTACH_FX = "battlesong_instant_panic_fx",
    -- 歌曲播放时的音效名称
    SOUND = "dontstarve_DLC001/characters/wathgrithr/quote/dropattack",
},

-- 定义即时战斗歌曲 "复活之歌" 的效果
battlesong_instant_revive =
{
    -- 当歌曲即时生效时执行的函数
    ONINSTANT = function(singer, target)
        -- 检查目标是否为玩家幽灵状态
        if target:HasTag("playerghost") then
            -- 在 0.5 到 3 秒（0.5 + (math.random() * 2.5)）的随机延迟后执行复活操作
            -- DoRevive 是之前定义的复活函数，传入目标和歌手作为参数
            target:DoTaskInTime(0.5 + (math.random() * 2.5), DoRevive, singer)
        end
    end,

    -- 自定义目标选择函数，用于确定可以使用该歌曲复活的目标
    CUSTOMTARGETFN = function(singer)
        -- 检查当前游戏是否开启 PVP 模式
        if TheNet:GetPVPEnabled() then
            -- 如果开启 PVP 模式，不提供可复活的目标
            return nil
        end

        -- 获取歌手的世界坐标
        local x, y, z = singer.Transform:GetWorldPosition()
        -- 获取歌手的歌唱激励组件中的附着半径
        local radius = singer.components.singinginspiration.attach_radius

        -- 在歌手周围半径为 radius 的范围内查找玩家
        local players = FindPlayersInRange(x, y, z, radius, false)
        -- 确定可复活的玩家数量，取查找结果数量和配置 TUNING.BATTLESONG_INSTANT_REVIVE_NUM_PLAYERS 中的较小值
        local num = players ~= nil and math.min(#players, TUNING.BATTLESONG_INSTANT_REVIVE_NUM_PLAYERS) or nil

        -- 如果可复活玩家数量不为空，从查找结果中随机选择 num 个玩家作为可复活目标
        return num ~= nil and PickSome(num, players) or nil
    end,

    -- 标记该歌曲为即时生效类型
    INSTANT = true,
    -- 歌曲使用时消耗的资源量，该歌曲消耗较高，具体数值由配置 TUNING.BATTLESONG_INSTANT_COST_HIGH 决定
    DELTA = TUNING.BATTLESONG_INSTANT_COST_HIGH,
    -- 歌曲的冷却时间，该歌曲冷却时间较长，具体数值由配置 TUNING.SKILLS.WATHGRITHR.BATTLESONG_INSTANT_COOLDOWN_HIGH 决定
    COOLDOWN = TUNING.SKILLS.WATHGRITHR.BATTLESONG_INSTANT_COOLDOWN_HIGH,
    -- 歌曲效果附加到目标时播放的特效名称
    ATTACH_FX = "battlesong_instant_electric_fx",
    -- 歌曲播放时的音效名称
    SOUND = "dontstarve_DLC001/characters/wathgrithr/song/revive",
    -- 激活该歌曲效果需要的技能
    REQUIRE_SKILL = "wathgrithr_songs_revivewarrior",
},
}

-- 初始化战斗歌曲的网络 ID，从 1 开始
-- 这个 ID 用于在网络环境中唯一标识每首战斗歌曲，方便服务器和客户端之间同步歌曲信息
local battlesong_netid = 1
-- 用于存储战斗歌曲预制体名称与网络 ID 的映射关系
-- 列表的索引即为网络 ID，对应的值为歌曲的预制体名称，通过这个表可以根据网络 ID 快速查找对应的歌曲预制体
local battlesong_netid_lookup = {}

-- 定义一个函数，用于为新的战斗歌曲分配网络 ID
-- prefab: 歌曲的预制体名称，用于标识不同的战斗歌曲
-- song_def: 歌曲的定义表，包含歌曲的各种属性和效果，如 ONAPPLY、ONDETACH 等
local function AddNewBattleSongNetID(prefab, song_def)
    -- 为歌曲定义表添加 battlesong_netid 属性，并赋值为当前的网络 ID
    -- 这样在后续的网络通信中，可以通过这个 ID 来识别歌曲
    song_def.battlesong_netid = battlesong_netid
    -- 将歌曲的预制体名称插入到 battlesong_netid_lookup 列表中
    -- 列表的索引即为当前的网络 ID，方便后续根据网络 ID 查找对应的预制体名称
    table.insert(battlesong_netid_lookup, prefab)
    -- 使用 assert 函数进行断言检查
    -- 确保当前的网络 ID 小于 8
    -- 如果超过 8，会抛出错误信息，提示需要修改玩家分类的网络变量以支持更多歌曲
    -- 这是因为可能游戏中玩家分类的网络变量（如 player_classified.inspirationsong1/2/3）的设计最多只支持 8 首歌曲
    assert(battlesong_netid < 8, "the max number of battle songs has been passed, you will need to change the netvar for player_classified.inspirationsong1/2/3 to support more")
    -- 网络 ID 自增 1，为下一首歌曲分配新的 ID
    battlesong_netid = battlesong_netid + 1
end

-- 遍历之前定义的所有战斗歌曲（存储在 song_defs 表中）
for k, v in pairs(song_defs) do
    -- 为每首歌曲的定义表添加 ITEM_NAME 属性，值为歌曲的键名
    -- 这个属性可以用于标识歌曲的名称，方便后续的处理和显示
    v.ITEM_NAME  = k
    -- 为每首歌曲的定义表添加 NAME 属性，值为歌曲键名加上 "_buff"
    -- 这个名称实际上是歌曲对应的增益效果的名称，而不是物品名称
    -- 在游戏中，歌曲可能会给玩家或目标施加某种增益效果，这个名称用于标识该增益效果
    v.NAME = k.."_buff"
    -- 检查歌曲是否不是即时生效的歌曲
    -- 即时生效的歌曲可能不需要网络 ID 来同步状态，因为它们的效果是立即发生的
    if not v.INSTANT then
        -- 如果不是即时生效的歌曲，调用 AddNewBattleSongNetID 函数为其分配网络 ID
        AddNewBattleSongNetID(k, v)
    end
end

-- 定义一个函数，用于根据网络 ID 获取对应的战斗歌曲定义
-- netid: 要查询的网络 ID
local function GetBattleSongDefFromNetID(netid)
    -- 根据网络 ID 从 battlesong_netid_lookup 列表中获取对应的预制体名称
    -- 如果 netid 不为 nil，则获取对应的值，否则为 nil
    local def = netid ~= nil and battlesong_netid_lookup[netid] or nil
    -- 根据预制体名称从 song_defs 表中获取对应的歌曲定义
    -- 如果 def 不为 nil，则获取对应的值，否则为 nil
    return def ~= nil and song_defs[def] or nil
end

-- 返回一个表，包含所有战斗歌曲的定义、根据网络 ID 获取歌曲定义的函数以及分配网络 ID 的函数
-- 这样其他模块可以方便地使用这些数据和功能，例如在网络通信中根据网络 ID 查找歌曲定义，或者为新歌曲分配网络 ID
return {song_defs = song_defs, GetBattleSongDefFromNetID = GetBattleSongDefFromNetID, AddNewBattleSongNetID = AddNewBattleSongNetID}