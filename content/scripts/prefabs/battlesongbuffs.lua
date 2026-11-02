
-- 原有风筝速度定义
local kitespeed_speed = 1.35
local kitespeed_duration = 1.5

-- 新增攻击倍率定义
local attackbuff_mult = 0.25  --
local attackbuff_duration = 3

-- 原有速度控制函数
local function kitespeed_attach(inst, target)
    if target.components.locomotor ~= nil then
        -- 检查 SetExternalSpeedMultiplier 方法是否存在
        if target.components.locomotor.SetExternalSpeedMultiplier then
            target.components.locomotor:SetExternalSpeedMultiplier(inst, "kitespeed", kitespeed_speed)
        else
            print("Error: locomotor component does not have SetExternalSpeedMultiplier method.")
        end
    end
end

local function kitespeed_detach(inst, target)
    if target.components.locomotor ~= nil then
        -- 检查 RemoveExternalSpeedMultiplier 方法是否存在
        if target.components.locomotor.RemoveExternalSpeedMultiplier then
            target.components.locomotor:RemoveExternalSpeedMultiplier(inst, "kitespeed")
        else
            print("Error: locomotor component does not have RemoveExternalSpeedMultiplier method.")
        end
    end
end

-- 新增攻击倍率控制函数
local function attackbuff_attach(inst, target)
    if target.components.combat ~= nil then
        target.components.combat.externaldamagemultipliers:SetModifier(
            inst, 
            1 + attackbuff_mult, 
            "custom_attackbuff"
        )
    end
end

local function attackbuff_detach(inst, target)
    if target.components.combat ~= nil then
        target.components.combat.externaldamagemultipliers:RemoveModifier(
            inst, 
            "custom_attackbuff"
        )
    end
end


-------------------------------------------------------------------------
----------------------- Prefab building functions -----------------------
-------------------------------------------------------------------------

-- 当计时器完成时调用的函数
local function OnTimerDone(inst, data)
    -- 检查计时器完成的事件名称是否为 "buffover"
    if data.name == "buffover" then
        -- 如果是，停止当前的 debuff 效果
        inst.components.debuff:Stop()
    end
end

-- 创建 buff 或 debuff 预制体的通用函数
local function MakeBuff(name, onattachedfn, onextendedfn, ondetachedfn, duration, priority, prefabs, IsDebuff)
    -- 当 buff 或 debuff 附加到目标上时调用的函数
    local function OnAttached(inst, target)
        -- 将当前实体的父对象设置为目标实体
        inst.entity:SetParent(target.entity)
        -- 设置实体的位置为 (0, 0, 0)，以防加载时出现问题
        inst.Transform:SetPosition(0, 0, 0) 
        -- 监听目标的死亡事件，当目标死亡时停止当前的 debuff 效果
        inst:ListenForEvent("death", function()
            inst.components.debuff:Stop()
        end, target)

        -- 如果有附加时的处理函数，调用该函数
        if onattachedfn ~= nil then
            onattachedfn(inst, target)
        end
    end

    -- 当 buff 或 debuff 效果延长时调用的函数
    local function OnExtended(inst, target)
        -- 停止 "buffover" 计时器
        inst.components.timer:StopTimer("buffover")
        -- 重新启动 "buffover" 计时器，设置新的持续时间
        inst.components.timer:StartTimer("buffover", duration)

        -- 如果有效果延长时的处理函数，调用该函数
        if onextendedfn ~= nil then
            onextendedfn(inst, target)
        end
    end

    -- 当 buff 或 debuff 从目标上移除时调用的函数
    local function OnDetached(inst, target)
        -- 如果有移除时的处理函数，调用该函数
        if ondetachedfn ~= nil then
            ondetachedfn(inst, target)
        end

        -- 移除当前实体
        inst:Remove()
    end

    -- 创建实体的主函数
    local function fn()
        -- 创建一个新的实体
        local inst = CreateEntity()

        -- 如果不是主服务器模拟，移除该实体，因为该实体不应该在客户端存在
        if not TheWorld.ismastersim then
            --Not meant for client!
            inst:DoTaskInTime(0, inst.Remove)
            return inst
        end

        -- 为实体添加 Transform 组件，用于处理位置、旋转等信息
        inst.entity:AddTransform()

        -- 以下是关于非网络实体的设置，这里注释掉了
        --[[Non-networked entity]]
        --inst.entity:SetCanSleep(false)
        -- 隐藏实体
        inst.entity:Hide()
        -- 实体不持久化
        inst.persists = false

        -- 为实体添加 "CLASSIFIED" 标签
        inst:AddTag("CLASSIFIED")

        -- 为实体添加 debuff 组件
        inst:AddComponent("debuff")
        -- 设置 debuff 组件的附加处理函数
        inst.components.debuff:SetAttachedFn(OnAttached)
        -- 设置 debuff 组件的移除处理函数
        inst.components.debuff:SetDetachedFn(OnDetached)
        -- 设置 debuff 组件的效果延长处理函数
        inst.components.debuff:SetExtendedFn(OnExtended)
        -- 设置 debuff 组件在实体消失时保留
        inst.components.debuff.keepondespawn = true

        -- 为实体添加计时器组件
        inst:AddComponent("timer")
        -- 启动 "buffover" 计时器，设置持续时间
        inst.components.timer:StartTimer("buffover", duration)
        -- 监听计时器完成事件，调用 OnTimerDone 函数
        inst:ListenForEvent("timerdone", OnTimerDone)

        -- 为实体添加 saveddata 组件，用于保存动态值
        inst:AddComponent("saveddata") 

        return inst
    end

    -- 根据是否为 debuff 生成预制体名称，并创建预制体
    return Prefab((IsDebuff and "debuff_" or "buff_")..name, fn, nil, prefabs)
end

-- 创建并返回风筝速度 buff、被嘲讽 debuff 和免眩晕 debuff 的预制体
return 
    MakeBuff("kitespeed", kitespeed_attach, nil, kitespeed_detach, kitespeed_duration, 1, nil, false),
    MakeBuff("attackbuff", attackbuff_attach, nil, attackbuff_detach, attackbuff_duration, 2, nil, false)