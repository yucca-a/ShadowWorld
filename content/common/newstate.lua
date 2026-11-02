local function ClearStatusAilments(inst)
    if inst.components.freezable ~= nil and inst.components.freezable:IsFrozen() then
        inst.components.freezable:Unfreeze()
    end
    if inst.components.pinnable ~= nil and inst.components.pinnable:IsStuck() then
        inst.components.pinnable:Unstick()
    end
end

local function ForceStopHeavyLifting(inst)
    if inst.components.inventory:IsHeavyLifting() then
        inst.components.inventory:DropItem(
            inst.components.inventory:Unequip(EQUIPSLOTS.BODY),
            true,
            true
        )
    end
end

local function IsMinigameItem(inst)
    return inst:HasTag("minigameitem")
end

local knockbackState =
    State{
        name = "knockback2hm",
        tags = { "busy", "nopredict", "nomorph", "nodangle", "nointerrupt", "jumping" },

        onenter = function(inst, data)
            ClearStatusAilments(inst)
            ForceStopHeavyLifting(inst)
            inst.components.rider:ActualDismount()
            inst.components.locomotor:Stop()
            inst:ClearBufferedAction()

            inst.AnimState:PlayAnimation("knockback_high")

            if data ~= nil then
                if data.disablecollision then
                    inst.sg.statemem.collisionmask = inst.Physics:GetCollisionMask()
                    inst.Physics:SetCollisionMask(COLLISION.GROUND)
                end
                if data.propsmashed then
                    local item = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                    local pos
                    if item ~= nil then
                        pos = inst:GetPosition()
                        pos.y = TUNING.KNOCKBACK_DROP_ITEM_HEIGHT_HIGH
                        local dropped = inst.components.inventory:DropItem(item, true, true, pos)
                        if dropped ~= nil then
                            dropped:PushEvent("knockbackdropped", { owner = inst, knocker = data.knocker, delayinteraction = TUNING.KNOCKBACK_DELAY_INTERACTION_HIGH, delayplayerinteraction = TUNING.KNOCKBACK_DELAY_PLAYER_INTERACTION_HIGH })
                        end
                    end
                    if item == nil or not item:HasTag("propweapon") then
                        item = inst.components.inventory:FindItem(IsMinigameItem)
                        if item ~= nil then
                            pos = pos or inst:GetPosition()
                            pos.y = TUNING.KNOCKBACK_DROP_ITEM_HEIGHT_LOW
                            item = inst.components.inventory:DropItem(item, false, true, pos)
                            if item ~= nil then
                                item:PushEvent("knockbackdropped", { owner = inst, knocker = data.knocker, delayinteraction = TUNING.KNOCKBACK_DELAY_INTERACTION_LOW, delayplayerinteraction = TUNING.KNOCKBACK_DELAY_PLAYER_INTERACTION_LOW })
                            end
                        end
                    end
                end
                if data.radius ~= nil and data.knocker ~= nil and data.knocker:IsValid() then
                    local x, y, z = data.knocker.Transform:GetWorldPosition()
                    local distsq = inst:GetDistanceSqToPoint(x, y, z)
                    local rangesq = data.radius * data.radius
                    local rot = inst.Transform:GetRotation()
                    local rot1 = distsq > 0 and inst:GetAngleToPoint(x, y, z) or data.knocker.Transform:GetRotation() + 180
                    local drot = math.abs(rot - rot1)
                    while drot > 180 do
                        drot = math.abs(drot - 360)
                    end
                    local k = distsq < rangesq and .3 * distsq / rangesq - 1 or -.7
                    inst.sg.statemem.speed = (data.strengthmult or 1) * 12 * k
                    inst.sg.statemem.dspeed = 0
                    if drot > 90 then
                        inst.sg.statemem.reverse = true
                        inst.Transform:SetRotation(rot1 + 180)
                        inst.Physics:SetMotorVel(-inst.sg.statemem.speed, 0, 0)
                    else
                        inst.Transform:SetRotation(rot1)
                        inst.Physics:SetMotorVel(inst.sg.statemem.speed, 0, 0)
                    end
                end
            end
        end,

        onupdate = function(inst)
            if inst.sg.statemem.speed ~= nil then
                inst.sg.statemem.speed = inst.sg.statemem.speed + inst.sg.statemem.dspeed
                if inst.sg.statemem.speed < 0 then
                    inst.sg.statemem.dspeed = inst.sg.statemem.dspeed + .075
                    inst.Physics:SetMotorVel(inst.sg.statemem.reverse and -inst.sg.statemem.speed or inst.sg.statemem.speed, 0, 0)
                else
                    inst.sg.statemem.speed = nil
                    inst.sg.statemem.dspeed = nil
                    inst.Physics:Stop()
                end
            end
        end,

        timeline =
        {
            TimeEvent(8 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/movement/bodyfall_dirt")
            end),
            FrameEvent(10, function(inst)
                inst.sg.statemem.landed = true
                inst.sg:RemoveStateTag("nointerrupt")
                inst.sg:RemoveStateTag("jumping")
                if inst.components.drownable then
                    if inst.components.drownable:ShouldDrown() then
                        inst.sg:GoToState("sink_fast")
                    end
                end
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("knockback_pst")
                end
            end),
        },

        onexit = function(inst)
            if inst.sg.statemem.restoremass ~= nil then
                inst.Physics:SetMass(inst.sg.statemem.restoremass)
            end
            if inst.sg.statemem.collisionmask ~= nil then
                inst.Physics:SetCollisionMask(inst.sg.statemem.collisionmask)
            end
            if inst.sg.statemem.speed ~= nil then
                inst.Physics:Stop()
            end
        end,
    }
AddStategraphState("wilson", knockbackState)
AddStategraphState("wilson_client", knockbackState)


AddStategraphEvent("wilson", EventHandler("knockback2hm", function(inst, data)
    if not inst.sg:HasStateTag("nointerrupt") then
        inst.sg:GoToState("knockback2hm", data)
    end
end))
AddStategraphEvent("wilson", EventHandler("slip2hm", function(inst)
    if not inst.sg:HasStateTag("nointerrupt") and not inst.sg:HasStateTag("noslip") then
        inst.sg:GoToState("slip")
    end
end))


local wormwoodState =
    State{
        name = "form_ghostflower2hm",
        tags = { "doing", "busy", "nocraftinginterrupt", "nomorph" },

        onenter = function(inst, product)
            -- print("inst.bufferedaction", inst.bufferedaction)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("form_log_pre")
            inst.AnimState:PushAnimation("form_log", false)
            product = "bulb"
            if product == nil or product == "log" then
                -- inst.sg.statemem.islog = true
                inst.AnimState:OverrideSymbol("wood_splinter", "player_wormwood", "wood_splinter")
            else
                inst.AnimState:OverrideSymbol("wood_splinter", "wormwood_skills_fx", "wood_splinter_"..product)
            end
            inst.sg.statemem.action = inst.bufferedaction
        end,

        timeline =
        {
            FrameEvent(0, function(inst)
                if not inst.sg.statemem.islog then
                    inst.SoundEmitter:PlaySound("meta2/wormwood/armchop_f0")
                end
            end),
            FrameEvent(2, function(inst)
                if inst.sg.statemem.islog then
                    inst.SoundEmitter:PlaySound("dontstarve/characters/wormwood/living_log_craft")
                end
            end),
            FrameEvent(40, function(inst)
                if not inst.sg.statemem.islog then
                    inst.SoundEmitter:PlaySound("meta2/wormwood/armchop_f40")
                end
            end),
            FrameEvent(50, function(inst)
                -- print("inst:PerformBufferedAction()", inst.bufferedaction)
                inst:PerformBufferedAction()
            end),
            FrameEvent(58, function(inst)
                inst.sg:RemoveStateTag("busy")
            end),
        },

        events =
        {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = function(inst)
            if inst.bufferedaction == inst.sg.statemem.action and
                    (not inst.components.playercontroller or
                    inst.components.playercontroller.lastheldaction ~= inst.bufferedaction) then
                inst:ClearBufferedAction()
            end
            inst.AnimState:ClearOverrideSymbol("wood_splinter")
        end,
    }

AddStategraphState("wilson", wormwoodState)
AddStategraphState("wilson_client", wormwoodState)