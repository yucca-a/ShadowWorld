require "behaviours/follow"
local dens = {"spiderden", "spiderden_2", "spiderden_3"}

local function killselftocallchild(inst, target)
    if inst.disableotherspider2hm or inst.killed2hm then return end
    if inst.components.childspawner:NumChildren() <= 0 and not inst:IsAsleep() and inst.components.shaveable and inst.components.shaveable.on_shaved then
        inst.disableotherspider2hm = (inst.data and inst.data.stage or 1) == 1
        -- 生成一个白蜘蛛防卫
        local spider = SpawnPrefab("spider_dropper")
        spider.Transform:SetPosition(inst.Transform:GetWorldPosition())
        if spider.components.knownlocations then spider.components.knownlocations:RememberLocation("home", inst:GetPosition()) end
        if target ~= nil and spider.components.combat ~= nil then spider.components.combat:SetTarget(target) end
        if inst.components.lootdropper and not inst.disableotherspider2hm then
            inst.components.lootdropper:SpawnLootPrefab("silk")
            inst.components.lootdropper:SpawnLootPrefab("silk")
        end
        -- 掉1级，如果1级会直接杀死巢穴,巢穴被杀死时会掉落1个蜘蛛丝
        inst.components.shaveable.on_shaved(inst, target)
        -- 如果掉1级后还有等级，新等级召唤所有蜘蛛进行防卫
        if inst and inst:IsValid() and not inst.disableotherspider2hm then inst.components.combat.onhitfn(inst, target) end
    else
        inst.components.combat.onhitfn(inst, target)
    end
end

local function onchildkilledfn(inst, child)
    if inst.components.childspawner and inst.components.combat and child and child:IsValid() and child.components.health and child.components.health:IsDead() and
        child.components.combat and child.components.combat.target then
        inst:DoTaskInTime(0, killselftocallchild, child.components.combat.target)
    end
end

local function OnKilled(inst, attacker)
    -- 自己掉级的不会生成白蜘蛛防卫
    if inst.disableotherspider2hm or inst.killed2hm then return end
    inst.killed2hm = true
    for i = 1, (inst.data and inst.data.stage or 1) do
        local spider = SpawnPrefab("spider_dropper")
        spider.Transform:SetPosition(inst.Transform:GetWorldPosition())
        if attacker ~= nil and spider.components.combat ~= nil then spider.components.combat:SetTarget(attacker) end
    end
end

for index, den in ipairs(dens) do
    AddPrefabPostInit(den, function(inst)
        if not TheWorld.ismastersim then return end
        inst.data = inst.data or {}
        inst.data.stage = inst.data.stage or 1
        if inst.components.childspawner and not inst.components.childspawner.onchildkilledfn then
            inst.components.childspawner:SetOnChildKilledFn(onchildkilledfn)
        end
        if inst.components.combat and not inst.components.combat.onkilledbyother then inst.components.combat.onkilledbyother = OnKilled end
    end)
end

-- 蜘蛛女王和寡妇进食
local SEE_FOOD_DIST = 12
local EATFOOD_CANT_TAGS = {"outofreach", "INLIMBO"}
local function EatFoodAction(inst)
    if inst.sg:HasStateTag("busy") then return end
    inst.food2hm = FindEntity(inst, SEE_FOOD_DIST, function(item) return inst.components.eater:CanEat(item) and item:IsOnValidGround() end, nil,
                              EATFOOD_CANT_TAGS)
    return inst.food2hm ~= nil and BufferedAction(inst, inst.food2hm, ACTIONS.ACTION2HM) or nil
end

local function spiderdelaytaunt(inst)
    if inst.sg and not inst:IsInLimbo() and inst.components.health and not inst.components.health:IsDead() then inst.sg:GoToState("taunt") end
end
-- 蜘蛛女王生成的蜘蛛会立即跳到敌人脸上

local function onspiderqueeneat(inst, data)
    if data and data.feeder and data.feeder:IsValid() then
        inst.feeder2hm = data.feeder
        if inst.feedfollow2hmtask then inst.feedfollow2hmtask:Cancel() end
        inst.feedfollow2hmtask = inst:DoTaskInTime(30, function() inst.feedfollow2hmtask = nil end)
        if inst.sg and not inst.sg:HasStateTag("busy") then inst.sg:GoToState("taunt") end
    end
    local mutation_target = data and data.food and data.food:HasTag("spidermutator") and data.food.components.spidermutator and
                                data.food.components.spidermutator.mutation_target
    if inst.components.hunger and (mutation_target or inst.components.hunger:GetPercent() >= 0.9) and inst.components.lootdropper and inst.components.leader and
        inst.components.leader.numfollowers < 10 then
        inst.components.hunger:DoDelta(-25, nil, true)
        local chance = math.random()
        local prefab = mutation_target or (chance > 0.6 and "spider" or (chance > 0.3 and "spider_warrior" or "spider_healer"))
        local spider = inst.components.lootdropper:SpawnLootPrefab(prefab)
        if spider ~= nil then
            local angle = (inst.Transform:GetRotation() + 180) * DEGREES
            local rad = spider:GetPhysicsRadius(0) + inst:GetPhysicsRadius(0) + .25
            local x, y, z = inst.Transform:GetWorldPosition()
            spider.Transform:SetPosition(x + rad * math.cos(angle), 0, z - rad * math.sin(angle))
            if spider.sg then spider.sg:GoToState("taunt") end -- 2025.5.20 melon:工坊报错 sg是空
            inst.components.leader:AddFollower(spider)
            if inst.components.combat.target ~= nil then spider.components.combat:SetTarget(inst.components.combat.target) end
        end
    end
end
AddPrefabPostInit("spiderqueen", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.lootdropper then
        local oldSpawnLootPrefab = inst.components.lootdropper.SpawnLootPrefab
        inst.components.lootdropper.SpawnLootPrefab = function(inst, ...)
            local loot = oldSpawnLootPrefab(inst, ...)
            if loot and loot:HasTag("spider") and loot.sg then loot:DoTaskInTime(0, spiderdelaytaunt) end
            return loot
        end
    end
    if not inst.components.hunger then
        inst:AddTag("handfed")
        inst:AddTag("fedbyall")
        inst:AddComponent("hunger")
        inst.components.hunger:SetMax(200)
        inst.components.hunger:SetKillRate(0)
        inst.components.hunger:SetRate(TUNING.WILSON_HUNGER_RATE / 10)
        inst:ListenForEvent("oneat", onspiderqueeneat)
        if inst.GetTimeAlive then
            inst.GetTimeAlive2hm = inst.GetTimeAlive
            local GetTimeAlive = inst.GetTimeAlive
            inst.GetTimeAlive = function(self, ...)
                return (inst.components.hunger and inst.components.hunger.current > 0 or inst:HasTag("swc2hm")) and
                           math.clamp(GetTimeAlive(self, ...), 0, TUNING.SPIDERQUEEN_MINWANDERTIME) or GetTimeAlive(self, ...)
            end
        end
    end
end)
AddBrainPostInit("spiderqueenbrain", function(self)
    if self.bt.root and self.bt.root.children then
        table.insert(self.bt.root.children, 5, Follow(self.inst, function() return self.inst.feeder2hm end, 2, 6, 10))
        table.insert(self.bt.root.children, 4, DoAction(self.inst, function() return EatFoodAction(self.inst) end))
    end
end)
AddStategraphActionHandler("spiderqueen", ActionHandler(ACTIONS.ACTION2HM, "eat2hm"))
local function eatfood2hm(inst)
    if inst.food2hm and inst.food2hm:IsValid() and inst.food2hm:IsOnValidGround() and inst.food2hm:IsNear(inst, 4) then
        if inst.components.eater and inst.components.eater:CanEat(inst.food2hm) then
            inst.components.eater:Eat(inst.food2hm)
        else
            inst.food2hm:Remove()
        end
        inst.food2hm = nil
    end
    inst.sg:GoToState("idle")
end
AddStategraphState("spiderqueen", State {
    name = "eat2hm",
    tags = {"busy"},
    onenter = function(inst)
        inst.Physics:Stop()
        inst.AnimState:PlayAnimation("poop_pre")
        inst.AnimState:PushAnimation("poop_pst", false)
        inst:ClearBufferedAction()
        inst.SoundEmitter:PlaySound("dontstarve/creatures/spiderqueen/scream")
    end,
    timeline = {TimeEvent(24 * FRAMES, eatfood2hm)},
    events = {EventHandler("animqueueover", eatfood2hm)}
})
AddStategraphPostInit("spider", function(sg)
    local oldtauntonenter = sg.states.taunt.onenter
    sg.states.taunt.onexit = function(inst, ...)
        if inst.components.follower and inst.components.follower.leader and inst.components.follower.leader:IsValid() and inst.components.follower.leader.prefab ==
            "spiderqueen" and inst.components.combat and inst.components.follower.leader.components.combat and
            (inst.components.combat.target or inst.components.follower.leader.components.combat.target) then
            inst.spiderqueenjump2hm = not inst.spiderqueenjump2hm
            if inst.spiderqueenjump2hm then
                inst.sg:GoToState("warrior_attack", inst.components.combat.target or inst.components.follower.leader.components.combat.target)
                return
            end
        end
        oldtauntonenter(inst, ...)
    end
end)