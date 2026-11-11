local checkCause = function(self, cause)
    if cause and type(cause) ~= "string" then
        -- local str = '检测到血量变化信息错误 ' ..tostring(self.inst) .. " 来源 " .. tostring(cause) .. ", 已规避崩溃"
        -- TheNet:Announce(str)
        -- print(str .. "\n" .. TUNING.util2hm.GetStack())
        if type(cause) == "table" then
            -- A nameless entity can throw inside GetDisplayName while adding a
            -- wet/burnt adjective, before an ordinary `or prefab` fallback runs.
            if type(cause.GetDisplayName) == "function" then
                local ok, name = pcall(cause.GetDisplayName, cause)
                if ok and type(name) == "string" and name ~= "" then return name end
            end
            if type(cause.prefab) == "string" and cause.prefab ~= "" then return cause.prefab end
        end
        return "unknown"
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

-- 深埋之下的杂食电路可以处理变质营养砖，但发酵计数依赖消化电路初始化。
AddSimPostInit(function()
    if not (TheWorld and TheWorld.ismastersim) then return end
    local definitions = require("wx78_moduledefs").module_definitions
    for _, definition in ipairs(definitions) do
        if definition.name == "worm" and type(definition.activatefn) == "function" then
            local onEaten, index, scope = require("upvaluehacker2hm").GetUpvalue(definition.activatefn, "wormdigestion_OnEaten")
            if type(onEaten) == "function" then
                debug.setupvalue(scope, index, function(wx, data)
                    if type(wx._digestion_modules) == "number" then return onEaten(wx, data) end
                end)
            end
            break
        end
    end
end)

-- 洞穴蠕虫的电反击会再次击中巨型蠕虫的土堆，重入棘刺反伤。
local function GuardWormDirtRedirect(inst)
    local combat = inst.components.combat
    local redirect = combat and combat.redirectdamagefn
    if not redirect then return end
    local redirecting = {}
    combat.redirectdamagefn = function(dirt, attacker, ...)
        if attacker == nil or redirecting[attacker] then
            -- 反击伤害仍由本体承受，这次转发不再触发棘刺。
            local worm = dirt.worm
            return worm and worm:IsValid() and worm or nil
        end
        redirecting[attacker] = true
        local target = redirect(dirt, attacker, ...)
        redirecting[attacker] = nil
        return target
    end
end
AddPrefabPostInit("worm_boss_dirt", GuardWormDirtRedirect)
AddPrefabPostInit("worm_boss_shadow_dirt", GuardWormDirtRedirect)

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
