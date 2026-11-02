local speedup = GetModConfigData("extra_change") and GetModConfigData("boss_speed") or 1
-- 鲨鱼增强
AddStategraphPostInit("shark", function(sg)
    local leappstonenter = sg.states.leap_pst.onenter
    sg.states.leap_pst.onenter = function(inst, ...)
        local target = inst.components.combat.target
        if target and target:IsValid() and inst.sg.laststate and inst.sg.laststate.name == "leap" then
            local x, y, z = inst.Transform:GetWorldPosition()
            if target:GetDistanceSqToInst(inst) < (TUNING.SHARK.ATTACK_RANGE / 2 * TUNING.SHARK.ATTACK_RANGE / 2) and
                (TheWorld.Map:IsVisualGroundAtPoint(x, y, z) or inst:GetCurrentPlatform()) then
                inst.components.combat:DoAttack(target)
                local forcelanded = target.components.inventory ~= nil and target.components.inventory:ArmorHasTag("heavyarmor") or target:HasTag("heavybody")
                target:PushEvent("knockback", {knocker = inst, radius = 1.75, strengthmult = forcelanded and 0.25 or 1, forcelanded = forcelanded})
            end
        end
        leappstonenter(inst, ...)
    end
    local eatpreonenter = sg.states.eat_pre.events.animover.fn
    sg.states.eat_pre.events.animover.fn = function(inst, ...)
        inst.sg:AddStateTag("noattack")
        eatpreonenter(inst, ...)
    end
    local eatpstonenter = sg.states.eat_pst.onenter
    sg.states.eat_pst.onenter = function(inst, ...)
        local target = inst.components.combat and inst.components.combat.target or FindClosestPlayerToInst(inst, TUNING.SHARK.ATTACK_RANGE, true)
        if target and target:IsValid() then
            inst.components.combat:StartAttack()
            inst.components.combat:DoAttack(target)
        end
        eatpstonenter(inst, ...)
    end
end)
-- -- 冰鲨,每次制造冰墙都会增加移速攻速，至高6级
-- local function delayunroot(inst)
--     inst.delayunroottask2hm = nil
--     inst:PushEvent("teleported")
-- end
-- local function onrooted(inst) if not inst.delayunroottask2hm then inst.delayunroottask2hm = inst:DoTaskInTime(1, delayunroot) end end
-- AddPrefabPostInit("sharkboi", function(inst)
--     if not TheWorld.ismastersim then return inst end
--     inst:AddComponent("drownable")
--     inst:ListenForEvent("rooted", onrooted)
-- end)
-- TUNING.SHARKBOI_DEAGGRO_DIST = TUNING.SHARKBOI_DEAGGRO_DIST * 2
-- local function delayrecover(inst)
--     if inst.hostile and inst.components.combat and inst.components.combat.target then
--         inst.delayrecovertask2hm = inst:DoTaskInTime(240, delayrecover)
--         return
--     end
--     inst.delayrecovertask2hm = nil
--     inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "speedup2hm")
--     if speedup > 1 then inst.components.locomotor:SetExternalSpeedMultiplier(inst, "HappyPatchExtra", speedup) end
-- end
-- local function updatespeed(inst, speed)
--     inst.upatklevel2hm = math.clamp((inst.upatklevel2hm or 0) + (speed or 1), 1, 6)
--     if speedup > 1 then inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "HappyPatchExtra") end
--     local runup = math.max((1 + inst.upatklevel2hm * 0.15), speedup)
--     inst.components.locomotor:SetExternalSpeedMultiplier(inst, "speedup2hm", runup)
--     if inst.delayrecovertask2hm then inst.delayrecovertask2hm:Cancel() end
--     inst.delayrecovertask2hm = inst:DoTaskInTime(240, delayrecover)
-- end
-- local function onsave(inst, data) data.upatklevel2hm = inst.upatklevel2hm end
-- local function onload(inst, data) if data and data.upatklevel2hm then updatespeed(inst, data.upatklevel2hm) end end
-- AddPrefabPostInit("sharkboi", function(inst)
--     if not TheWorld.ismastersim then return end
--     SetOnSave2hm(inst, onsave)
--     SetOnLoad2hm(inst, onload)
-- end)
-- -- 攻击动画也会加速
-- local function updateattackspeed(sg)
--     for _, state in pairs(sg.states) do
--         if state and state.tags and (state.tags.attack or state.tags.tired or state.tags.rummaging) and not state.tags.hit and not state.upanim2hm then
--             state.upanim2hm = true
--             local onenter = state.onenter
--             state.onenter = function(inst, ...)
--                 onenter(inst, ...)
--                 if inst.sg.currentstate == state then
--                     if not inst.defeated and inst.hostile then
--                         SpeedUpState2hm(inst, state, math.max(1 + (inst.upatklevel2hm or 0) * 0.15, TUNING.epicupatkanim2hm or 1, TUNING.upatkanim2hm or 1))
--                     else
--                         SpeedUpState2hm(inst, state, 1)
--                     end
--                 end
--             end
--             local onexit = state.onexit
--             state.onexit = function(inst, ...)
--                 if onexit then onexit(inst, ...) end
--                 RemoveSpeedUpState2hm(inst, state, true)
--             end
--         end
--     end
-- end
-- AddStategraphPostInit("sharkboi", function(sg)
--     local ice_summon = sg.states.ice_summon.onenter
--     sg.states.ice_summon.onenter = function(inst, ...)
--         if inst.components.locomotor then updatespeed(inst) end
--         ice_summon(inst, ...)
--     end
--     updateattackspeed(sg)
-- end)
