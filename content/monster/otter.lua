local function OnHitOther(inst, data)
    local target = data.target
    if target then
        if target:HasTag("player") and target.components.moisture then
            local waterproofness = target.components.moisture:GetWaterproofness()
            target.components.moisture:DoDelta(10 * (1 - waterproofness))
            if target.components.moisture:GetMoisturePercent() >= 0.95 then
                target:PushEvent("knockback2hm", {
                    disablecollision = true,
                    propsmashed = true,
                    knocker = inst,
                    radius = 3,
                    strengthmult = 1,
                })
            end
        end
        if not inst.attackTimes or inst.attackTimes <= 0 then
            inst.attackTimes = math.random(3) + 2
        else
            inst.attackTimes = inst.attackTimes - 3
        end
        if inst.attackTimes and inst.attackTimes > 0 then
            if not inst.components.timer:TimerExists("doattack") then
                inst.components.timer:StartTimer("doattack", 0.5)
            end
        end
    end
end

local function OnMissOther(inst, data)
    local target = data.target
    if target then
        if not inst.attackTimes or inst.attackTimes <= 0 then
            inst.attackTimes = math.random(2) + 2
        else
            inst.attackTimes = inst.attackTimes - 1
        end
        if inst.attackTimes and inst.attackTimes > 0 then
            if not inst.components.timer:TimerExists("doattack") then
                inst.components.timer:StartTimer("doattack", 0.5)
            end
        end
    end
end

local lungeState =
    State{
        name = "lunge2hm",
        tags = { "busy", "nopredict", "nomorph", "nodangle", "nointerrupt", "jumping" },

        onenter = function(inst, target)
            -- print("执行飞扑", inst.sg:HasStateTag("busy"))

            if target == nil then target = inst.components.combat.target end
            if target ~= nil and target:IsValid() then
                inst.sg.statemem.target = target
                inst:ForceFacePoint(target.Transform:GetWorldPosition())
            else
                inst.sg:GoToState("idle")
                return
            end
            if target:HasTag("player") and inst.components.talker then
                inst.components.talker:Say(TUNING.isCh2hm and "兄弟,给我尝尝" or "taste you")
            end
            inst.AnimState:PlayAnimation("jump")
            inst.AnimState:PushAnimation("jump_loop", true)
            SpawnPrefab("splash_green").Transform:SetPosition(inst.Transform:GetWorldPosition())
            inst:ClearBufferedAction()
            inst.sg.statemem.inlunge2hm = true
            inst.sg.statemem.inlunge2hmtime = GetTime()
            inst.sg.statemem.inlunge2hmdistance = inst:GetPhysicsRadius(0.2) + target:GetPhysicsRadius(0.2) + 0.5
            inst.sg.statemem.collisionmask = inst.Physics:GetCollisionMask()
	        inst.Physics:SetCollisionMask(COLLISION.GROUND)
            inst.components.locomotor:Stop()
            inst.components.locomotor:EnableGroundSpeedMultiplier(false)
            inst.Physics:SetMotorVelOverride(20,0,0)
        end,

        onupdate = function(inst)
            if not inst.sg.statemem.inlunge2hm then
                return
            end
            -- local ticks = GetTick()
            -- inst.sg.statemem.lastlunge2hmTime, ticks = ticks, (ticks - inst.sg.statemem.lastlunge2hmTime) * FRAMES
            if inst.sg.statemem.target and inst.sg.statemem.target:IsValid() then
                -- local tx, ty, tz = inst.sg.statemem.target.Transform:GetWorldPosition()
                -- local dx, dy, dz = inst.Transform:GetWorldPosition()
                -- local x, y, z = tx - dx, ty - dy, tz - dz
                -- local d = math.sqrt(x * x + z * z)
                -- local arrive = false
                -- local val = 15 * ticks
                -- if d > 0 then
                --     if val > d then
                --         val = d
                --         arrive = true
                --     end
                --     inst.Physics:Teleport(x / d * val + dx, dy, z / d * val + dz)
                --     inst:ForceFacePoint(tx, ty, tz)
                -- end
                -- print("距离", d, inst.sg.statemem.inlunge2hmdistance)
                -- if d <= inst.sg.statemem.inlunge2hmdistance or arrive then
                inst:ForceFacePoint(inst.sg.statemem.target.Transform:GetWorldPosition())
                if inst:IsNear(inst.sg.statemem.target, inst.sg.statemem.inlunge2hmdistance) then
                    inst.Physics:Stop()
                    inst.AnimState:PlayAnimation("jump_pst")
                    inst.components.timer:StopTimer("lunge2hmend")
                    inst.components.timer:StartTimer("lunge2hmend", 0.1)
                    inst.sg.statemem.inlunge2hm = false
                    SpawnPrefab("splash_green").Transform:SetPosition(inst.Transform:GetWorldPosition())
                    if inst.sg.statemem.target:HasTag("player") and inst.sg.statemem.target.components.moisture then
                        local waterproofness = inst.sg.statemem.target.components.moisture:GetWaterproofness()
                        inst.sg.statemem.target.components.moisture:DoDelta(6 * (1 - waterproofness))
                        if inst.sg.statemem.target.components.moisture:GetMoisturePercent() >= 0.95 then
                            -- inst.sg.statemem.target:PushEvent("knockback2hm", {
                            --     disablecollision = false,
                            --     propsmashed = false,
                            --     knocker = inst,
                            --     radius = 1,
                            --     strengthmult = -1,
                            -- })
                            inst.sg.statemem.target:PushEvent("slip2hm")
                        end
                    end
                    if inst.components.combat.target == inst.sg.statemem.target then
                        inst.sg.statemem.doattack = true
                    end
                end
            end
            if GetTime() - inst.sg.statemem.inlunge2hmtime > 0.5 then
                inst.components.timer:StopTimer("lunge2hmend")
                inst.components.timer:StartTimer("lunge2hmend", 0.1)
                inst.sg.statemem.inlunge2hm = false
            end
        end,

        timeline =
        {
            TimeEvent(0.1, function(inst)
                inst.SoundEmitter:PlaySound("turnoftides/common/together/water/submerge/medium")
                SpawnPrefab("splash_green").Transform:SetPosition(inst.Transform:GetWorldPosition())
            end),
            TimeEvent(0.2, function(inst)
                inst.SoundEmitter:PlaySound("turnoftides/common/together/water/submerge/medium")
                SpawnPrefab("splash_green").Transform:SetPosition(inst.Transform:GetWorldPosition())
            end),
            TimeEvent(0.3, function(inst)
                inst.SoundEmitter:PlaySound("turnoftides/common/together/water/submerge/medium")
                SpawnPrefab("splash_green").Transform:SetPosition(inst.Transform:GetWorldPosition())
            end),
            TimeEvent(0.4, function(inst)
                inst.SoundEmitter:PlaySound("turnoftides/common/together/water/submerge/medium")
                SpawnPrefab("splash_green").Transform:SetPosition(inst.Transform:GetWorldPosition())
            end),
            TimeEvent(0.5, function(inst)
                inst.SoundEmitter:PlaySound("turnoftides/common/together/water/submerge/medium")
                SpawnPrefab("splash_green").Transform:SetPosition(inst.Transform:GetWorldPosition())
            end),
        },

        events =
        {
            EventHandler("timerdone", function(inst,data)
                if data.name == "lunge2hmend" then
                    -- if math.random() < 0.5 then
                    inst.components.timer:StopTimer("lunge2hmcd")
                    inst.components.timer:StartTimer("lunge2hmcd", 5)
                    if inst.sg.statemem.doattack then
                        inst.sg:GoToState("attack")
                    else
                        inst.sg:GoToState("idle")
                    end
                    -- else
                    --     inst.sg:GoToState("lunge2hm", inst.sg.statemem.target)
                    -- end
                end
            end),
        },

        onexit = function(inst)
            -- print("exit")
            inst.Physics:Stop()
            inst.components.locomotor:EnableGroundSpeedMultiplier(true)
            if inst.sg.statemem.collisionmask ~= nil then
                inst.Physics:SetCollisionMask(inst.sg.statemem.collisionmask)
            end
        end,
    }
AddStategraphState("otter", lungeState)

local OnPerformaction = function(inst, data)
    local action = data.action
    if action.action.id == "STEAL" then
        local owner = action.target.components.inventory ~= nil and action.target or action.target.components.inventoryitem ~= nil and action.target.components.inventoryitem.owner or nil
        if owner then
            inst.addListenerFunc2hm_onitemstolen(function(_, data)
                if data then
                    if data.thief == inst then
                        inst.clearFunc2hm_onitemstolen()
                        inst.addListenerFunc2hm_onpickup(function(_, data2)
                            inst.clearFunc2hm_onpickup()
                            if data2.owner == owner then
                                if inst.components.combat then
                                    inst.components.combat:SuggestTarget(data2.owner)
                                    inst:RestartBrain()
                                end
                                if data2.owner:HasTag("player") and inst.components.talker then
                                    inst.components.talker:Say(TUNING.isCh2hm and "兄弟,还给我!!!!!!!" or "give me bro !!!!!!!")
                                end
                            end
                        end, data.item)
                    end
                else
                    inst.clearFunc2hm_onitemstolen()
                end
            end, owner)
            inst.doTaskFunc2hm_performaction(5, function()
                inst.clearFunc2hm_onitemstolen()
                inst.clearFunc2hm_onpickup()
            end)
        else
            inst.clearFunc2hm_onitemstolen()
        end
    end
end

local fish_defs = require("prefabs/oceanfishdef").fish
local lootFunc = function(self)
    local loots = {}
    if math.random() < 0.5 then
        table.insert(loots, "meat")
        table.insert(loots, "fishmeat_small")
    else
        table.insert(loots, "smallmeat")
        table.insert(loots, "fishmeat")
    end
    if math.random() < 0.5 then
        table.insert(loots, "kelp")
    else
        if math.random() < 0.25 then
            table.insert(loots, "kelp")
            table.insert(loots, "kelp")
        end
    end
    if math.random() < 0.1 then
        table.insert(loots, "messagebottle")
    end
    local fishName
    if math.random() < 0.5 then
        fishName = "oceanfish_small_" .. math.random(5)
    else
        fishName = "oceanfish_medium_" .. math.random(7)
    end
    if fish_defs[fishName] then
        table.insert(loots, fishName .. "_inv")
    end
    self.inst.components.lootdropper:SetLoot(loots)
end

AddPrefabPostInit("otter", function(inst)
    if not inst.components.talker then
        inst:AddComponent("talker")
    end
    if not TheWorld.ismastersim then return end
    inst.components.health:SetMaxHealth(TUNING.OTTER_HEALTH * 1.4)
    if not inst.components.timer then
        inst:AddComponent("timer")
    end
    inst:ListenForEvent("onhitother", OnHitOther)
    inst:ListenForEvent("onmissother", OnMissOther)
    inst:ListenForEvent("timerdone", function(inst, data)
        if data.name == "doattack" then
            local target = inst.components.combat.target
            if target and target:IsValid() then
                inst:PushEvent("doattack")
            else
                OnMissOther(inst, {target = target})
            end
        end
    end)
    inst.clearFunc2hm_onitemstolen, inst.addListenerFunc2hm_onitemstolen = TUNING.util2hm.GenListenFunc(inst, "onitemstolen")
    inst.clearFunc2hm_onpickup, inst.addListenerFunc2hm_onpickup = TUNING.util2hm.GenListenFunc(inst, "onpickup")
    inst.clearFunc2hm_performaction, inst.doTaskFunc2hm_performaction = TUNING.util2hm.GenTaskFunc(inst)
    inst:ListenForEvent("performaction", OnPerformaction)

    inst:DoTaskInTime(0, function()
        if inst.components.eater then
            table.insert(inst.components.eater.caneat, FOODTYPE.VEGGIE)
        end
        if inst.components.lootdropper then
            inst.components.lootdropper.chanceloottable = nil
            inst.components.lootdropper.chanceloot = nil
            inst.components.lootdropper:SetLootSetupFn(lootFunc)
        end
    end)
end)

AddBrainPostInit("otterbrain", function(self)
    if self.bt.root.children then
        local addIndex
        for index, child in ipairs(self.bt.root.children) do
            if child and child.name == "Parallel" then
                if child.children[1] and (child.children[1].name == "Not Enough Items" or child.children[1].name == "Is Hungry") then
                    if child.children[2] then
                        for _, child2 in ipairs(child.children[2].children) do
                            if child2 and child2.name == "Look For Character Food" then
                                local getactionfn = child2.getactionfn
                                child2.getactionfn = function(inst)
                                    local result = getactionfn(inst)
                                    if result then
                                        local target = result.target
                                        if target and target.components.inventoryitem then
                                            local owner = target.components.inventoryitem.owner
                                            if owner then
                                                if owner:HasTag("player") and inst.components.talker then
                                                    inst.components.talker:Say(TUNING.isCh2hm and "兄弟,你好香" or "delicious bro")
                                                end
                                                if not inst.trylunge2hmTargettask then
                                                    inst.lunge2hmTarget = owner
                                                    inst.trylunge2hmTargettask = inst:DoTaskInTime(0.3, function()
                                                        inst.trylunge2hmTargettask = nil
                                                        inst.lunge2hmTarget = nil
                                                    end)
                                                end
                                            end
                                        end
                                    end
                                    return result
                                end
                                break
                            end
                        end
                    end
                end
            elseif child and child.name == "ChaseAndAttack" then
                addIndex = index
            end
        end

        if addIndex then
            local newAction = PriorityNode({
                IfNode(
                    function()
                        return not self.inst.sg:HasStateTag("busy")
                            and not self.inst.components.timer:TimerExists("lunge2hmcd")
                            and (self.inst.components.combat.target or self.inst.lunge2hmTarget and self.inst.lunge2hmTarget:IsValid())
                    end,
                    "lunge2hm",
                    ActionNode(function() self.inst.sg:GoToState("lunge2hm", self.inst.components.combat.target or self.inst.lunge2hmTarget) end))
            }, 0.25)
            table.insert(self.bt.root.children, addIndex, newAction)
        end
    end
end)