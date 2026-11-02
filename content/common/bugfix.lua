local checkCause = function(self, cause)
    if cause and type(cause) ~= "string" then
        -- local str = '检测到血量变化信息错误 ' ..tostring(self.inst) .. " 来源 " .. tostring(cause) .. ", 已规避崩溃"
        -- TheNet:Announce(str)
        -- print(str .. "\n" .. TUNING.util2hm.GetStack())
        if type(cause) == "table" and cause.GetDisplayName then
            cause = cause:GetDisplayName() or cause.prefab or "unknown"
        end
    end
    return cause
end

AddComponentPostInit("health", function(health)
    local oldDoDelta = health.DoDelta
    health.DoDelta = function(self, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
        cause = checkCause(self, cause)
        return oldDoDelta(self, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
    end

    local oldSetPercent = health.SetPercent
    health.SetPercent = function(self, percent, overtime, cause)
        cause = checkCause(self, cause)
        return oldSetPercent(self, percent, overtime, cause)
    end

    local oldSetVal = health.SetVal
    health.SetVal = function(self, val, cause, afflicter)
        cause = checkCause(self, cause)
        return oldSetVal(self, val, cause, afflicter)
    end
end)

AddStategraphPostInit("wilson", function(sg)
    local wathomleap = sg.states.wathomleap
    if wathomleap then
        local oldonenter = wathomleap.onenter
        wathomleap.onenter = function(inst, data)
            local buffaction = inst:GetBufferedAction()
            local target = buffaction ~= nil and buffaction.target or nil
            if target then
                local canRange = inst.components.combat:CalcAttackRangeSq(target)
                canRange = math.min(canRange * 1.2, canRange + 12)
                if inst:GetDistanceSqToInst(target) > canRange then
                    inst.sg:GoToState("knockback2hm", {
                        propsmashed = true,
                        knocker = inst,
                        radius = 3,
                        strengthmult = 1,
                    })
                    return
                end
            end
            oldonenter(inst, data)
        end
    end
end)

-- 修复:旺达倒走表状态 pocketwatch_warpback 的 animover 处理未做有效性检查,会崩溃
-- 该状态 onenter 生成的 pocketwatch_warpback_fx 虽挂靠玩家(entity:SetParent),但 AnimState 独立;
-- 被天体时停 Pause 玩家动画后,玩家动画冻结而特效照常播完并自行 Remove;
-- 等玩家动画恢复播完触发 animover 时,官方代码直接访问已失效实体(stafffx.entity:SetParent) → 崩溃
-- 官方只在此状态的 onexit 做了 :IsValid() 保护,animover 漏了,这里补上
AddStategraphPostInit("wilson", function(sg)
    local warpback = sg.states.pocketwatch_warpback
    if warpback == nil or warpback.events == nil then return end
    local animover = warpback.events.animover
    if animover == nil or animover.fn == nil then return end
    local oldanimoverfn = animover.fn
    animover.fn = function(inst, data)
        local statemem = inst.sg ~= nil and inst.sg.statemem or nil
        -- 特效已自行移除:清空引用,避免官方 animover 访问失效实体
        if statemem ~= nil and statemem.stafffx ~= nil and not statemem.stafffx:IsValid() then
            statemem.stafffx = nil
        end
        return oldanimoverfn(inst, data)
    end
end)
