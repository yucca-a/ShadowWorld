-- -- 受到攻击时
-- local function OnAttacked(inst, data) end
-- 骑乘时残血提醒骑乘者
local function OnHealthDelta(inst, data)
    if data.oldpercent >= 0.2 and data.newpercent < 0.2 and inst.components.rideable.rider ~= nil then
        inst.components.rideable.rider:PushEvent("mountwounded")
    end
end
-- -- 开始被骑乘时
-- local function OnBeingRidden(inst, dt) end
-- -- 骑乘者攻击时
-- local function OnRiderDoAttack(inst, data) end
-- 骑乘者不能装备手部工具
local function onriderequip(inst)
    local equip = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    if equip and not equip.components.curseditem then
        inst.components.inventory:Unequip(EQUIPSLOTS.HANDS)
        inst.components.inventory:GiveItem(equip)
    end
end
local function ToggleOffPhysics(inst)
    -- inst.sg.statemem.isphysicstoggle = true
    inst.Physics:ClearCollisionMask()
    inst.Physics:CollidesWith(COLLISION.WORLD)
end
local function ToggleOnPhysics(inst)
    -- inst.sg.statemem.isphysicstoggle = nil
    inst.Physics:ClearCollisionMask()
    inst.Physics:CollidesWith(COLLISION.WORLD)
    inst.Physics:CollidesWith(COLLISION.OBSTACLES)
    inst.Physics:CollidesWith(COLLISION.SMALLOBSTACLES)
    inst.Physics:CollidesWith(COLLISION.CHARACTERS)
    inst.Physics:CollidesWith(COLLISION.GIANTS)
end
local events = {"attacked", "locomote", "doattack"}
local function delayonriderequip(inst) inst:DoTaskInTime(0, onriderequip) end
local function OnRiderChanged(inst, data)
    -- 驾驶结束时
    if data.oldrider and inst.rider2hm and inst.rider2hm == data.oldrider then
        if inst.rider2hm.components.inventory then inst.rider2hm:RemoveEventCallback("equip", delayonriderequip) end
        if inst.components.knownlocations then inst.components.knownlocations:RememberLocation("home", inst:GetPosition()) end
        if inst.locomotor2hm then
            inst.components.locomotor.WantsToMoveForward = inst.locomotor2hm.WantsToMoveForward
            inst.components.locomotor.WantsToRun = inst.locomotor2hm.WantsToRun
            inst.locomotor2hm = nil
        end
        inst.rider2hm.AnimState:SetMultColour(1, 1, 1, 1)
        ToggleOnPhysics(inst.rider2hm)
        inst.rider2hm.DynamicShadow:Enable(true)
        inst.rider2hm = nil
    end
    -- 驾驶开始时
    if data.newrider ~= nil and data.newrider.AnimState then
        inst.rider2hm = data.newrider
        -- inst:ReturnToScene()
        -- inst:StopBrain()
        inst:Show()
        inst.sg:Start()
        inst.AnimState:Resume()
        inst.DynamicShadow:Enable(true)
        inst.rider2hm.AnimState:SetMultColour(0, 0, 0, 0)
        ToggleOffPhysics(inst.rider2hm)
        inst.rider2hm.DynamicShadow:Enable(false)
        inst.locomotor2hm = {}
        inst.locomotor2hm.WantsToMoveForward = inst.components.locomotor.WantsToMoveForward
        inst.components.locomotor.WantsToMoveForward = function(...) return inst.rider2hm.sg and inst.rider2hm.sg:HasStateTag("moving") end
        inst.locomotor2hm.WantsToRun = inst.components.locomotor.WantsToRun
        inst.components.locomotor.WantsToRun = function(...) return inst.rider2hm.sg and inst.rider2hm.sg:HasStateTag("running") end
        if inst.components.knownlocations then inst.components.knownlocations:ForgetLocation("home") end
        if inst.rider2hm.components.inventory then
            local equip = inst.rider2hm.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if equip and not equip.components.curseditem then
                inst.rider2hm.components.inventory:Unequip(EQUIPSLOTS.HANDS)
                inst.rider2hm.components.inventory:GiveItem(equip)
            end
            inst.rider2hm:ListenForEvent("equip", delayonriderequip)
        end
        if inst.sg and inst.sg.sg and inst.sg.sg.events then
            inst.eventsfn2hm = {}
            for index, event in ipairs(events) do
                if inst.sg.sg.events[event] and inst.sg.sg.events[event].fn then
                    inst.eventsfn2hm[event] = function(rider, ...) inst.sg.sg.events[event].fn(inst, ...) end
                    inst:ListenForEvent(event, inst.eventsfn2hm[event], inst.rider2hm)
                end
            end
        end
        if inst.components.sleeper ~= nil then inst.components.sleeper:WakeUp() end
        inst.sg:GoToState("idle")
    elseif inst.components.health:IsDead() then
        if inst.sg.currentstate.name ~= "death" then inst.sg:GoToState("death") end
    elseif inst.components.sleeper ~= nil then
        inst.components.sleeper:StartTesting()
    end
end
-- 骑乘时死亡会把骑乘者摔下来,然后再进入死亡状态
local function OnDeath(inst)
    inst.persists = false
    inst:AddTag("NOCLICK")
    if inst.components.knownlocations then inst.components.knownlocations:RememberLocation("home", inst:GetPosition(), false) end
    if inst.components.rideable:IsBeingRidden() then inst.components.rideable:Buck(true) end
end
-- 拒绝骑乘者时触发的动作
local function _OnRefuseRider(inst) if inst.components.sleeper:IsAsleep() and not inst.components.health:IsDead() then inst.components.sleeper:WakeUp() end end
local function OnRefuseRider(inst, data) inst:DoTaskInTime(0, _OnRefuseRider) end
-- 是否拒绝骑乘
local function RiderTest(inst, doer)
    return not inst:HasTag("swc2hm") and not (inst.components.persistent2hm and inst.components.persistent2hm.data.supermonster) and
               inst.components.follower:GetLeader() ~= nil
end
local function refreshcanride(inst)
    inst.components.rideable.canride = inst.components.follower and inst.components.follower:GetLeader() ~= nil
    if not inst.components.rideable.canride and inst.components.rideable:IsBeingRidden() then inst.components.rideable:Buck(true) end
end
-- 骑乘战车,不需要牛鞍
local function rookpostinit(inst)
    if not TheWorld.ismastersim then return end
    if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
    if not inst.components.rideable then
        inst:AddComponent("rideable")
        inst.components.rideable:SetSaddleable(false)
        inst.components.rideable:SetCustomRiderTest(RiderTest)
        inst:ListenForEvent("refusedrider", OnRefuseRider)
        inst:ListenForEvent("death", OnDeath) -- need to handle this due to being mountable
        inst:ListenForEvent("healthdelta", OnHealthDelta) -- to inform rider
        -- inst:ListenForEvent("attacked", OnAttacked)
        -- inst:ListenForEvent("beingridden", OnBeingRidden)
        inst:ListenForEvent("riderchanged", OnRiderChanged)
        -- inst:ListenForEvent("riderdoattackother", OnRiderDoAttack)
        inst:ListenForEvent("startleashing", refreshcanride)
        inst:ListenForEvent("stopleashing", refreshcanride)
    end
end
-- 骑乘战车
local rooks = {"rook", "rook_nightmare"}
for _, rook in ipairs(rooks) do AddPrefabPostInit(rook, rookpostinit) end
-- 拒绝骑乘时会咆哮
AddStategraphEvent("rook", EventHandler("refusedrider", function(inst, data)
    if not inst.components.health:IsDead() and not inst.sg:HasStateTag("attack") and not inst.sg:HasStateTag("busy") then inst.sg:GoToState("taunt") end
end))
-- 被骑乘时死亡延迟到摔下来后再死亡
AddStategraphPostInit("rook", function(sg)
    local deatheventfn = sg.events.death.fn
    sg.events.death.fn = function(inst, data)
        if not (inst.components.rideable and inst.components.rideable:IsBeingRidden()) then deatheventfn(inst, data) end
    end
end)
