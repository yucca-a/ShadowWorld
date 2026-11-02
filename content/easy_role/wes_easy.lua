local hardmode = TUNING.hardmode2hm and GetModConfigData("role_nerf")

-- 韦斯正常数据
if GetModConfigData("Wes Normal Data Attack Work") then
    TUNING.WES_HEALTH = TUNING.WILSON_HEALTH
    TUNING.WES_HUNGER = TUNING.WILSON_HUNGER
    TUNING.WES_SANITY = TUNING.WILSON_SANITY
    TUNING.WES_WORKEFFECTIVENESS_MODIFIER = 1
    TUNING.WES_DAMAGE_MULT = 1
    -- AddPrefabPostInit("wes", function(inst)
    --     if not TheWorld.ismastersim then return end
    --     -- inst.components.workmultiplier:AddMultiplier(ACTIONS.CHOP, 1, inst)
    --     -- inst.components.workmultiplier:AddMultiplier(ACTIONS.MINE, 1, inst)
    --     -- inst.components.workmultiplier:AddMultiplier(ACTIONS.HAMMER, 1, inst)
    --     -- inst.components.efficientuser:AddMultiplier(ACTIONS.CHOP, 1, inst)
    --     -- inst.components.efficientuser:AddMultiplier(ACTIONS.MINE, 1, inst)
    --     -- inst.components.efficientuser:AddMultiplier(ACTIONS.HAMMER, 1, inst)
    --     -- inst.components.efficientuser:AddMultiplier(ACTIONS.ATTACK, 1, inst)

    --     inst.components.combat.damagemultiplier = 1
    -- end)
end

-- 气球装备加速
if GetModConfigData("Equip Balloon Increase Speed") then
    TUNING.BALLOON_SPEED_DURATION = TUNING.PERISH_ONE_DAY
    AddComponentPostInit("fueled", function(self)
        local oldInitializeFuelLevel = self.InitializeFuelLevel
        self.InitializeFuelLevel = function(self, fuel, ...)
            if self.inst and self.inst:HasTag("balloon") and fuel then fuel = fuel * 1 end
            return oldInitializeFuelLevel(self, fuel, ...)
        end
    end)
    AddPrefabPostInit("balloon", function(inst)
        if not TheWorld.ismastersim then return end
        inst.components.equippable.walkspeedmult = 1.3
    end)
    AddPrefabPostInit("balloonhat", function(inst)
        if not TheWorld.ismastersim then return end
        inst.components.equippable.walkspeedmult = 1.2 -- 2025.10.24 melon:1.3->1.2
    end)
    AddPrefabPostInit("balloonvest", function(inst)
        if not TheWorld.ismastersim then return end
        inst.components.equippable.walkspeedmult = 1.1 -- 2025.10.24 melon:1.3->1.1
    end)
end

-- 韦斯右键冲刺
if GetModConfigData("Wes Right Dodge Collide Balloon") then
    AddPrefabPostInit("wes", function(inst)
        inst.rightaction2hm_double = true
        AddDodgeAbility(inst)
        inst.rightaction2hm_cooldown = GetModConfigData("Wes Right Dodge Collide Balloon")
    end)
end

-- 气球堆叠爆炸如同火药
if GetModConfigData("Balloon Stackable Per 50 Damage") then
    local BALLOONS = require "prefabs/balloons_common"
    -- 气球跟随目标
    local function cancelPassivefollowtargettask(inst)
        if inst and inst:IsValid() and inst.components.locomotor then
            inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "wesballoon2hm")
            inst.notwesballoontask2hm = nil
            inst.passivefollowtarget2hm = nil
        end
    end
    local function cancelfollowtargettask(inst)
        if inst and inst:IsValid() then
            if inst.followtargettask2hm then
                inst.followtargettask2hm:Cancel()
                inst.followtargettask2hm = nil
            end
            local phys = inst.Physics
            phys:CollidesWith((TheWorld.has_ocean and COLLISION.GROUND) or COLLISION.WORLD)
            phys:CollidesWith(COLLISION.OBSTACLES)
            phys:CollidesWith(COLLISION.SMALLOBSTACLES)
            phys:CollidesWith(COLLISION.CHARACTERS)
            phys:CollidesWith(COLLISION.GIANTS)
            inst.canfollowtarget2hm = false
            if not inst:IsInLimbo() and inst.followtarget2hm and inst.followtarget2hm:IsValid() and not inst.followtarget2hm:IsInLimbo() then
                local theta = (inst.followtarget2hm.Transform:GetRotation() - 180) * DEGREES
                local radius = inst.followtarget2hm:GetPhysicsRadius(0.1) + 0.3
                local offset = Vector3(radius * math.cos(theta), 0, -radius * math.sin(theta))
                local pos = Vector3(inst.followtarget2hm.Transform:GetWorldPosition())
                inst.Transform:SetPosition(pos.x + offset.x, 0, pos.z + offset.z)
                inst.Physics:SetMotorVel(0, 0, 0)
                inst.Physics:Stop()
            end
        end
        local other = inst.followtarget2hm
        if other and other:IsValid() then
            other.passivefollowtarget2hm = nil
            if other.components.locomotor then
                other.components.locomotor:RemoveExternalSpeedMultiplier(inst, "wesballoon2hm")
                if other.notwesballoontask2hm then
                    other.notwesballoontask2hm:Cancel()
                    other.notwesballoontask2hm = nil
                end
            end
        end
        inst.followtarget2hm = nil
    end
    local function followtarget(inst)
        if inst and inst:IsValid() and not inst:IsInLimbo() and inst.followtarget2hm and inst.followtarget2hm:IsValid() and not inst.followtarget2hm:IsInLimbo() then
            local other = inst.followtarget2hm
            if other.components.locomotor then
                if other.notwesballoontask2hm then
                    other.notwesballoontask2hm:Cancel()
                    other.notwesballoontask2hm = nil
                end
                other.notwesballoontask2hm = other:DoTaskInTime(2 * FRAMES, cancelPassivefollowtargettask)
            end
            local theta = (inst.followtarget2hm.Transform:GetRotation() - 180) * DEGREES
            local radius = inst.followtarget2hm:GetPhysicsRadius(0.1) + 0.1
            local offset = Vector3(radius * math.cos(theta), 0, -radius * math.sin(theta))
            local pos = Vector3(inst.followtarget2hm.Transform:GetWorldPosition())
            inst.Transform:SetPosition(pos.x + offset.x, 0, pos.z + offset.z)
        elseif inst and inst:IsValid() then
            cancelfollowtargettask(inst)
        end
    end
    local function oncollide(inst, other)
        -- 气球缠绕到指定单位身上，减速单位，此时不再检测碰撞
        if inst:IsValid() and other and other:IsValid() and not other.passivefollowtarget2hm and inst.canfollowtarget2hm and not inst.followtargettask2hm and
            other.prefab ~= "wes" and not other:HasTag("balloon") and other.components.health then
            inst.Physics:ClearCollisionMask()
            inst.followtarget2hm = other
            other.passivefollowtarget2hm = inst
            if other.components.locomotor then
                other.components.locomotor:SetExternalSpeedMultiplier(inst, "wesballoon2hm", other:HasTag("epic") and 0.7 or 0.4)
                other.notwesballoontask2hm = other:DoTaskInTime(2 * FRAMES, cancelPassivefollowtargettask)
            end
            inst.followtargettask2hm = inst:DoPeriodicTask(FRAMES, followtarget)
            inst:DoTaskInTime(other:HasTag("epic") and 8 or 12, cancelfollowtargettask)
        end
        if inst:IsValid() and inst.followtargettask2hm then
            inst.Physics:SetMotorVel(0, 0, 0)
            inst.Physics:Stop()
            return
        end
        -- 气球被碰到后会有碰撞动画
        if inst:IsValid() and (inst:IsValid() and Vector3(inst.Physics:GetVelocity()):LengthSq() > .1) or
            (other ~= nil and other:IsValid() and other.Physics ~= nil and Vector3(other.Physics:GetVelocity()):LengthSq() > .1) then
            inst.AnimState:PlayAnimation("hit")
            inst.AnimState:PushAnimation("idle", true)
        end
    end
    local oldMakeFloatingBallonPhysics = BALLOONS.MakeFloatingBallonPhysics
    BALLOONS.MakeFloatingBallonPhysics = function(inst, ...)
        local phys = oldMakeFloatingBallonPhysics(inst, ...)
        if phys then
            phys:CollidesWith(COLLISION.FLYERS)
            phys:CollidesWith(COLLISION.SANITY)
            phys:SetCollisionCallback(oncollide)
        end
    end
    TUNING.BALLOON_DAMAGE = TUNING.BALLOON_DAMAGE * 10
    local oldMakeBalloonMasterInit = BALLOONS.MakeBalloonMasterInit
    BALLOONS.MakeBalloonMasterInit = function(inst, ...)
        oldMakeBalloonMasterInit(inst, ...)
        inst.components.combat.playerdamagepercent = 0.1
    end
    local function onstacksizechange(inst, data)
        inst.canfollowtarget2hm = data and data.stacksize and data.stacksize >= inst.components.stackable.maxsize / 2
        local size = (data and data.stacksize and data.stacksize or 1) * 0.05 + 0.95
        inst.AnimState:SetScale(size, size, size)
    end
    local function onpickup(inst)
        if inst.components.stackable then inst.canfollowtarget2hm = inst.components.stackable.stacksize >= inst.components.stackable.maxsize / 2 end
    end
    AddPrefabPostInit("balloon", function(inst)
        if not TheWorld.ismastersim then return end
        if not inst.components.stackable then
            inst:AddComponent("stackable")
            inst.components.stackable.maxsize = TUNING.STACK_SIZE_LARGEITEM
        end
        inst:ListenForEvent("stacksizechange", onstacksizechange)
        inst:ListenForEvent("onpickup", onpickup)
        inst:ListenForEvent("stacksizechange", function(inst, data) inst.components.combat:SetDefaultDamage(TUNING.BALLOON_DAMAGE * data.stacksize) end)
    end)
end

-- 气球旋风
if GetModConfigData("Equip Balloon Summon Tornado") then
    -- 迅捷气球释放一次天气风向标的能力，但持续时间只有2.5秒
    local diffindex
    local function getspawnlocation(inst, target)
        local x1, y1, z1 = inst.Transform:GetWorldPosition()
        if target == inst then
            local theta = (-180 + math.random() * 360) * DEGREES
            return x1 + math.cos(theta) * 0.25, 0, z1 - math.sin(theta) * 0.25
        end
        local x2, y2, z2 = target.Transform:GetWorldPosition()
        return x1 + .15 * (x2 - x1), 0, z1 + .15 * (z2 - z1)
    end
    local function onworking(inst, data)
        if data and data.target and data.target:IsValid() and data.target.components.workable and data.target.components.workable:GetWorkAction() ==
            ACTIONS.HAMMER then data.target.components.workable:SetWorkLeft(data.target.components.workable.workleft + 2) end
    end
    local function spawntornado(inst, target)
        local tornado = SpawnPrefab("tornado")
        tornado.WINDSTAFF_CASTER = inst.components.inventoryitem and inst.components.inventoryitem.owner or inst.caster2hm
        if not (tornado.WINDSTAFF_CASTER:IsValid()) then tornado.WINDSTAFF_CASTER = nil end
        tornado.WINDSTAFF_CASTER_ISPLAYER = tornado.WINDSTAFF_CASTER ~= nil and tornado.WINDSTAFF_CASTER:HasTag("player")
        tornado.Transform:SetPosition(getspawnlocation(inst, target))
        tornado.components.knownlocations:RememberLocation("target", target:GetPosition())
        if tornado.WINDSTAFF_CASTER_ISPLAYER then
            tornado.overridepkname = tornado.WINDSTAFF_CASTER:GetDisplayName()
            tornado.overridepkpet = true
        end
        local duration = TUNING.TORNADO_LIFETIME * (inst.components.fueled and inst.components.fueled:GetPercent() or 1)
        if inst.forcespawn2hm or target ~= tornado.WINDSTAFF_CASTER or tornado.WINDSTAFF_CASTER == nil then duration = duration / 2 end
        tornado:SetDuration(duration)
        tornado:ListenForEvent("working", onworking)
        if inst.forcespawn2hm and tornado.sg then tornado.sg:GoToState("idle") end
        return tornado
    end
    local function spawntornados(inst, target)
        if inst.tornado2hm then return end
        inst.tornado2hm = true
        if inst.forcespawn2hm then
            -- 受到攻击制造旋风
            for i = 1, math.clamp(inst.components.stackable and inst.components.stackable.stacksize or 1, 1, 10) do spawntornado(inst, target) end
        else
            -- 主动制造旋风
            local tornado = spawntornado(inst, target)
            if tornado.WINDSTAFF_CASTER and tornado.WINDSTAFF_CASTER.components.hunger then
                tornado.WINDSTAFF_CASTER.components.hunger:DoDelta(-1.5 * (inst.components.fueled and inst.components.fueled:GetPercent() or 1), nil, true)
            end
            if inst.components.stackable then
                inst:DoTaskInTime(0, function() inst.components.stackable:Get(1):Remove() end)
            else
                inst:DoTaskInTime(0, inst.Remove)
            end
        end
    end
    local function maketornado(inst, target)
        if not inst.tornado2hm then
            inst.forcespawn2hm = true
            spawntornados(inst, target or (inst.components.inventoryitem and inst.components.inventoryitem:GetGrandOwner()) or inst)
        end
    end
    local BALLOONS = require "prefabs/balloons_common"
    local DoPop = BALLOONS.DoPop
    BALLOONS.DoPop = function(inst, ...)
        if inst.components.inventoryitem and inst.components.inventoryitem.owner then maketornado(inst) end
        if inst.components.combat then inst.components.combat.playerdamagepercent = 0 end
        DoPop(inst, ...)
    end
    local DoPop_Floating = BALLOONS.DoPop_Floating
    BALLOONS.DoPop_Floating = function(inst, ...)
        if inst.components.inventoryitem and inst.components.inventoryitem.owner then maketornado(inst) end
        if inst.components.combat then inst.components.combat.playerdamagepercent = 0 end
        DoPop_Floating(inst, ...)
    end
    local function onballoonattack(inst, attacker, target, skipsanity) spawntornados(inst, target) end
    STRINGS.ACTIONS.CASTSPELL.TORNADO = STRINGS.NAMES.TORNADO
    local balloons = {"balloonspeed", "balloon", "balloonparty"}
    local function balloonhandpostinit(inst)
        inst.spelltype = "TORNADO"
        if not TheWorld.ismastersim then return end
        if not inst.components.spellcaster then
            inst:AddTag("nopunch")
            inst:AddTag("quickcast")
            inst:AddComponent("spellcaster")
            inst.components.spellcaster.canuseontargets = true
            inst.components.spellcaster.canonlyuseonworkable = true
            inst.components.spellcaster.canonlyuseoncombat = true
            inst.components.spellcaster.quickcast = true
            inst.components.spellcaster:SetSpellFn(spawntornados)
            inst.components.spellcaster.castingstate = "castspell_tornado"
        end
        if not inst.components.weapon then
            inst:AddComponent("weapon")
            inst.components.weapon:SetDamage(0)
            inst.components.weapon:SetRange(8, 10)
            inst.components.weapon:SetOnAttack(onballoonattack)
        end
    end
    for index, balloon in ipairs(balloons) do AddPrefabPostInit(balloon, balloonhandpostinit) end
    local equipslots = {EQUIPSLOTS.BODY, EQUIPSLOTS.HEAD}
    AddRightSelfAction("wes", 3, "dolongaction", nil, function(act)
        if act.doer and act.doer.prefab == "wes" and act.doer.components.inventory then
            local self = act.doer.components.inventory
            for _, slot in ipairs(equipslots) do
                local equip = self.equipslots[slot]
                if equip and equip:HasTag("balloon") and equip.prefab ~= "balloon" then
                    spawntornados(equip, act.doer)
                    return true
                end
            end
        end
        return false
    end, STRINGS.NAMES.TORNADO)
end