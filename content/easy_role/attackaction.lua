local function addgymtag(inst) inst:AddTag("slingshot_gym2hm") end
local function endgymbuff(inst)
    if inst:HasTag("slingshot_gym2hm") then inst.components.combat.externaldamagemultipliers:RemoveModifier(inst, "slingshot_gym2hm") end
end
local state_slingshot_gym2hm = State {
    name = "slingshot_gym2hm",
    tags = {"attack", "busy"},
    onenter = function(inst, target)
        inst.AnimState:PlayAnimation("dumbbell_mighty_loop")
        inst.SoundEmitter:PlaySound("wolfgang2/characters/wolfgang/grunt")
        target = target or (inst.components.combat and inst.components.combat.target)
        if target ~= nil and target:IsValid() then
            local targetpos = target:GetPosition()
            inst:ForceFacePoint(targetpos:Get())
        end
    end,
    events = {
        EventHandler("animover", function(inst)
            if TheWorld.ismastersim then
                inst.components.combat.externaldamagemultipliers:SetModifier(inst, TUNING.DSTU and 1.5 or 2, "slingshot_gym2hm")
                inst:RemoveTag("slingshot_gym2hm")
                if inst.slingshot_gym2hm_attack_task ~= nil then
                    inst.slingshot_gym2hm_attack_task:Cancel()
                    inst.slingshot_gym2hm_attack_task = nil
                end
                inst.slingshot_gym2hm_attack_task = inst:DoTaskInTime(4.5, addgymtag)
                inst:DoTaskInTime(6, endgymbuff)
            end
            inst.sg:GoToState(inst.nextattackstate2hm == "slingshot_gym2hm" and "idle" or inst.nextattackstate2hm)
        end)
    }
}
AddStategraphState("wilson", state_slingshot_gym2hm)
AddStategraphState("wilson_client", state_slingshot_gym2hm)

-- 拥有slingshot_gym2hm标签即可
AddStategraphPostInit("wilson", function(sg)
    local Attack_Old = sg.actionhandlers[ACTIONS.ATTACK].deststate
    sg.actionhandlers[ACTIONS.ATTACK].deststate = function(inst, action)
        local handler = Attack_Old(inst, action)
        local equip = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        if inst:HasTag("slingshot_gym2hm") and equip ~= nil and not (inst.components.rider and inst.components.rider:IsRiding()) and equip:HasTag("slingshot") then
            inst.nextattackstate2hm = handler
            return "slingshot_gym2hm"
        end
        return handler
    end
end)
AddStategraphPostInit("wilson_client", function(sg)
    local ClientAttack_Old = sg.actionhandlers[ACTIONS.ATTACK].deststate
    sg.actionhandlers[ACTIONS.ATTACK].deststate = function(inst, action)
        local handler = ClientAttack_Old(inst, action)
        local equip = inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        local rider = inst.replica.rider
        if inst:HasTag("slingshot_gym2hm") and equip ~= nil and not (rider ~= nil and rider:IsRiding()) and equip:HasTag("slingshot") then
            inst.nextattackstate2hm = handler
            return "slingshot_gym2hm"
        end
        return handler
    end
end)
