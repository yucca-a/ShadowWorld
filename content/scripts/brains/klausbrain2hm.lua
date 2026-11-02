-- 引入所需的行为模块：追击攻击和漫游行为
require "behaviours/chaseandattack"
require "behaviours/wander"

-- 定义重置战斗状态的延迟时间（秒）
local RESET_COMBAT_DELAY = 10

-- 克劳斯AI脑部类，继承自基础Brain类
local KlausBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)  -- 调用父类构造函数
end)

--[[ 获取生成点位置函数
参数：inst - 克劳斯实体实例
返回：存储的生成点坐标 ]]
local function GetHomePos(inst)
    return inst.components.knownlocations:GetLocation("spawnpoint")
end

--[[ 激怒状态判断函数
条件：未处于激怒状态 且 当前士兵数量 < 总士兵数 ]]
local function ShouldEnrage(inst)
    return not inst.enraged
        and inst.components.commander:GetNumSoldiers() < inst.TotalDeer
end

--[[ 重击技能判断函数
条件：处于非锁链状态 且 有攻击目标 且 技能冷却结束 ]]
local function ShouldChomp(inst)
    return inst:IsUnchained()                   -- 未被锁链束缚
        and inst.components.combat:HasTarget()  -- 存在攻击目标
        and not inst.components.timer:TimerExists("chomp_cd")  -- 技能不在冷却
end

-- 脑部主逻辑初始化函数
function KlausBrain:OnStart()
    -- 构建优先级行为树（数值0.5表示行为树更新间隔）
    local root = PriorityNode(
    {
        -- 激怒行为节点：当满足条件时触发enrage事件
        WhileNode(function() return ShouldEnrage(self.inst) end, "Enrage",
            ActionNode(function() self.inst:PushEvent("enrage") end)),
            
        -- 重击技能节点：当满足条件时触发chomp事件
        WhileNode(function() return ShouldChomp(self.inst) end, "Chomp",
            ActionNode(function() self.inst:PushEvent("chomp") end)),
        
        -- 核心战斗行为：追击并攻击目标
        ChaseAndAttack(self.inst),
        
        -- 并行节点：同时执行多个行为（战斗状态重置 + 漫游）
        ParallelNode{
            -- 顺序节点：等待指定时间后重置战斗状态
            SequenceNode{
                WaitNode(RESET_COMBAT_DELAY),  -- 等待重置延迟时间
                ActionNode(function() self.inst:SetEngaged(false) end),  -- 退出战斗状态
            },
            -- 漫游行为：以生成点为中心，5为半径的漫游
            Wander(self.inst, GetHomePos, 5),
        },
    }, .5)

    -- 初始化行为树
    self.bt = BT(self.inst, root)
end

-- 初始化完成回调函数
function KlausBrain:OnInitializationComplete()
    -- 记录初始生成点位置（y坐标归零避免高度问题）
    local pos = self.inst:GetPosition()
    pos.y = 0
    self.inst.components.knownlocations:RememberLocation("spawnpoint", pos, true)
end

return KlausBrain