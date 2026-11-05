local shadownumber = GetModConfigData("Shadow World")
shadownumber = shadownumber == true and 1 or shadownumber
TUNING.shadowworld2hm = shadownumber
local shadowanimals = GetModConfigData("Shadow Animals")
if not TUNING.hardmode2hm then shadowanimals = 7 end -- 2025.7.17 melon:关闭困难模式时变为7仅宠物
local shadowhateplayer = GetModConfigData("Shadow Attack Player Actively")
local shadowregenperiod = math.max(GetModConfigData("Shadow Regen Period") or 1, 1)
local shadowhelpself = GetModConfigData("Shadow Help Self")
local shadownotindependent = GetModConfigData("Shadow Protect Creatures")
local swepicfarrange = GetModConfigData("Shadow Epic Far Range") or math.huge
local epicshadowfarrange = GetModConfigData("Epic Shadow Far Range") or math.huge
local shadowhardermode = GetModConfigData("Shadow Harder Level")
local maxshadownum = GetModConfigData("Shadow Num Limit")
TUNING.currentshadow2hm = 0
local UpvalueHacker = require("upvaluehacker2hm")
local old_alterguardian = GetModConfigData("old_alterguardian") -- 旧版本天体英雄
-- 模组兼容说明
-- 其他模组可以给实体设置disablesw2hm变量或添加"disablesw2hm"标签来禁用该实体出现影子
-- inst.disablesw2hm = true 或 inst:AddTag("disablesw2hm")
-- 其他模组可以给实体加swc2hmfn函数来处理影子,影子出现后会直接调用本体的swc2hmfn函数
-- inst.swc2hmfn = function(shadowchild) end

-- 某些生物的影子用其他实体实现
local specialshadows = {
    lavae = "mod_hardmode_lavae",
    hutch = "shadowhutch2hm",
    firehound = "hound",
    icehound = "hound",
    lightninghound = "hound",
    merm_shadow = "merm",
    merm_lunar = "merm",
    mermguard_shadow = "mermguard",
    mermguard_lunar = "mermguard"
}

-- 一些特殊怪物，其的影分身需要真正死亡来清除其相关实体和特效；格罗姆特殊优化来兼容一下
local realdeathlist = {"huimiezhe", "um_pawn_nightmare", "um_pawn", "glommer"}
-- 一些特殊单位，本体最少血量时会原地投降
local mindeathlist = {"daywalker", "daywalker2", "sharkboi"}

-- 哪些生物可以生成暗影分身;正常只有血量战斗移速组件的生物才能生成分身,但海鱼特殊处理
local whitenamelist = {"abigail", "bernie_big", "bernie_active", "hutch", "chester", "wagboss_robot", "wagdrone_flying"}
local blacknamelist = {
    "wobysmall",
    "wobybig",
    "winona_catapult",
    "mandrake_active",
    "canary_poisoned",
    "lightflier",
    "wormwood_lightflier",
    "um_bear_trap_equippable_tooth",
    "um_bear_trap_equippable_gold",
    "um_beeguard_shooter",
    -- 天体英雄模组
    "cca_alterguardian_phase1",
    "cca_alterguardian_phase2",
    "cca_alterguardian_phase3",
}
local function hasshadow(inst)
    if table.contains(whitenamelist, inst.prefab) then return true end
    if shadowanimals == 7 or inst:HasTag("player") or inst.disablesw2hm or inst:HasTag("disablesw2hm") or inst:HasTag("shadow") or inst:HasTag("shadowminion") or
        inst:HasTag("shadowcreature") or inst:HasTag("nightmarecreature") or inst:HasTag("shadowchesspiece") or inst:HasTag("brightmare") or
        inst:HasTag("pigelite") or table.contains(blacknamelist, inst.prefab) or
        (inst:HasTag("epic") and inst.components.follower and inst.components.follower.leader and inst.components.follower.leader:IsValid() and
            inst.components.follower.leader:HasTag("player")) or
        not ((inst.components.oceanfishable and inst.components.weighable) or (inst.components.health and inst.components.combat and inst.components.locomotor)) then
        return false
    end
    if shadowanimals == 1 then return not inst:HasTag("epic") end
    if shadowanimals == 2 or shadowanimals == 6 then return inst:HasTag("epic") end
    return true
end

-- 老麦影子可以打影怪
local crazycompanions = {"shadowprotector"}
for _, companion in ipairs(crazycompanions) do AddPrefabPostInit(companion, function(inst) inst:AddTag("crazy") end) end
-- 2025.8.31 melon:老麦的影人不主动打影怪
AddPrefabPostInit("shadowprotector", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.combat and inst.components.combat.targetfn then
        local COMBAT_CANTHAVE_TAGS = UpvalueHacker.GetUpvalue(inst.components.combat.targetfn, "COMBAT_CANTHAVE_TAGS")
        if COMBAT_CANTHAVE_TAGS ~= nil then
            table.insert(COMBAT_CANTHAVE_TAGS, "shadowcreature")
            table.insert(COMBAT_CANTHAVE_TAGS, "nightmarecreature")
        end
    end
end)
-- 2025.9.2 melon:阿比盖尔的影子不主动打影怪
AddPrefabPostInit("abigail", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.BecomeDefensive then
        local _DefensiveRetarget = UpvalueHacker.GetUpvalue(inst.BecomeDefensive, "DefensiveRetarget")
        local COMBAT_CANTHAVE_TAGS = nil
        if _DefensiveRetarget ~= nil then
            COMBAT_CANTHAVE_TAGS = UpvalueHacker.GetUpvalue(_DefensiveRetarget, "COMBAT_CANTHAVE_TAGS")
        end
        if COMBAT_CANTHAVE_TAGS ~= nil then
            table.insert(COMBAT_CANTHAVE_TAGS, "shadowcreature")
            table.insert(COMBAT_CANTHAVE_TAGS, "nightmarecreature")
            table.insert(COMBAT_CANTHAVE_TAGS, "player") -- 2025.10.7 melon:不打怪物类角色?
        end
    end
end)

-- 阿比优先打boss本体,普通/月阿比共用此索敌
AddPrefabPostInit("abigail", function(inst)
    if not TheWorld.ismastersim then return end
    if not TUNING.abigail_priority_boss2hm then
        TUNING.abigail_priority_boss2hm = true
        if inst.BecomeDefensive and inst.BecomeAggressive then
            local function PriorityRetarget(oldretarget)
                return function(inst, ...)
                    local result = oldretarget(inst, ...)
                    if result and result:IsValid() and result:HasTag("epic") and not result:HasTag("swc2hm") then
                        return result
                    end
                    local ix, iy, iz = inst.Transform:GetWorldPosition()
                    local ents = TheSim:FindEntities(ix, iy, iz, TUNING.ABIGAIL_COMBAT_TARGET_DISTANCE, { "_combat", "_health", "epic" }, { "INLIMBO", "noauradamage", "companion" })
                    for _, v in ipairs(ents) do
                        if v:IsValid() and not v:IsInLimbo() and not v:HasTag("swc2hm")
                            and inst.components.combat and inst.components.combat:CanTarget(v)
                            and not inst.components.combat:IsAlly(v)
                            and not inst.components.timer:TimerExists("block_retargets") then
                            return v
                        end
                    end
                    return result
                end
            end
            local _DefensiveRetarget = UpvalueHacker.GetUpvalue(inst.BecomeDefensive, "DefensiveRetarget")
            local _AggressiveRetarget = UpvalueHacker.GetUpvalue(inst.BecomeAggressive, "AggressiveRetarget")
            if _DefensiveRetarget then
                UpvalueHacker.SetUpvalue(inst.BecomeDefensive, PriorityRetarget(_DefensiveRetarget), "DefensiveRetarget")
            end
            if _AggressiveRetarget then
                UpvalueHacker.SetUpvalue(inst.BecomeAggressive, PriorityRetarget(_AggressiveRetarget), "AggressiveRetarget")
            end
        end
    end
end)

-- 什么情况下本体可以转移仇恨给自己的分身
local function canshadowhelpself(inst)
    if shadowhelpself == 1 then
        return inst.components.combat == nil or
            (inst.components.combat.defaultdamage == 0 and inst.weaponitems == nil and inst.components.combat:GetWeapon() == nil)
    elseif shadowhelpself == 2 then
        return not inst:HasTag("epic")
    elseif shadowhelpself == 3 then
        return not inst:HasTag("epic") or (inst.components.health and inst.components.health:GetPercent() <= 0.25)
    elseif shadowhelpself == 4 then
        return true
    end
    return false
end

-- 某个特殊模式,加强的boss才残血时生成暗影分身,其他直接出分身
local epicshasshadow = {"beequeen"}
if shadowanimals == 4 and TUNING.hardmode2hm and GetModConfigData("monster_change") then
    if GetModConfigData("minotaur") then table.insert(epicshasshadow, "minotaur") end
    if GetModConfigData("malbatross") then table.insert(epicshasshadow, "malbatross") end
    if GetModConfigData("dragonfly") then table.insert(epicshasshadow, "dragonfly") end
    if GetModConfigData("eyeofterror") then
        table.insert(epicshasshadow, "eyeofterror")
        table.insert(epicshasshadow, "twinofterror1")
        table.insert(epicshasshadow, "twinofterror2")
    end
    if GetModConfigData("atriumstalker") then table.insert(epicshasshadow, "stalker_atrium") end
    if GetModConfigData("alterguardian") then
        table.insert(epicshasshadow, "alterguardian_phase1")
        table.insert(epicshasshadow, "alterguardian_phase2")
        table.insert(epicshasshadow, "alterguardian_phase3")
    end
end

-- 第二周目传送分身到自己附近
local mutatedepics = {"mutatedbearger", "mutateddeerclops", "mutatedwarg"}
local function childteleport(child, inst, radius)
    local theta
    if shadownumber == 1 then
        theta = math.random() * 2 * PI
    elseif not inst.teleportchildindexhm then
        inst.teleportchildtheta2hm = math.random()
        inst.teleportchildindexhm = 0
        theta = inst.teleportchildtheta2hm * 2 * PI
    else
        inst.teleportchildindexhm = inst.teleportchildindexhm + 1
        theta = (inst.teleportchildtheta2hm + 1 / shadownumber * inst.teleportchildindexhm) * 2 * PI
    end
    radius = radius or 10
    local offset = Vector3(radius * math.cos(theta), 0, -radius * math.sin(theta))
    local pt = inst:GetPosition() + offset
    child.Transform:SetPosition(pt.x, pt.y, pt.z)
end
local function teleportchildren(inst, radius)
    if inst.components.childspawner2hm and inst.components.childspawner2hm.numchildrenoutside > 0 then
        local children = {}
        for k, child in pairs(inst.components.childspawner2hm.childrenoutside) do
            if child:IsValid() and not child.isdead2hm then
                childteleport(child, inst, radius)
                table.insert(children, child)
            end
        end
        if inst.teleportchildindexhm then inst.teleportchildindexhm = nil end
        if inst.teleportchildtheta2hm then inst.teleportchildtheta2hm = nil end
        return children
    end
end
local function childteleporttoparent(child)
    if shadowhardermode and TheWorld.components.riftspawner and
        (TheWorld.components.riftspawner.lunar_rifts_enabled or TheWorld.components.riftspawner.shadow_rifts_enabled) and child.swp2hm and
        child.swp2hm:IsValid() and (child:IsAsleep() or not (child.components.combat and child.components.combat.target) or not child:IsNear(child.swp2hm, 18)) then
        childteleport(child, child.swp2hm, 4)
        if child.swp2hm.teleportchildindexhm then child.swp2hm.teleportchildindexhm = nil end
        if child.swp2hm.teleportchildtheta2hm then child.swp2hm.teleportchildtheta2hm = nil end
    end
end
local function parentteleportchildren(inst)
    if shadowhardermode and TheWorld.components.riftspawner and
        (TheWorld.components.riftspawner.lunar_rifts_enabled or TheWorld.components.riftspawner.shadow_rifts_enabled) then
        teleportchildren(inst, 4)
    end
end
local function testparentteleportchildren(inst, data) if data and data.oldtarget == nil then parentteleportchildren(inst) end end

-- 分身消失时进行检测,如果不是被击杀而死,本体会快速刷出下个分身了
-- 要让分身快速回归则在本体初始化后给ent.shadowcantout2hm赋值即可
local killselfcd = math.clamp(shadowregenperiod / 5, 1, 30)
local function homeback(inst, cd)
    if cd and inst and inst:IsValid() and inst.components.childspawner2hm and inst.components.childspawner2hm.regening then
        inst.components.childspawner2hm:OnUpdate(cd > inst.components.childspawner2hm.regenperiod and
            inst.components.childspawner2hm.regenperiod or
            inst.components.childspawner2hm.regenperiod - cd)
    end
end
local function onchildremove(inst)
    if inst.changeswp2hm then
        inst.swp2hm = inst.changeswp2hm
        inst.changeswp2hm = nil
    end
    if inst.components.inventory ~= nil then inst.components.inventory:DropEverything() end
    if inst.components.container ~= nil then inst.components.container:DropEverything() end
    if (not inst.isdead2hm or inst.killself2hm) and inst.swp2hm and inst.swp2hm:IsValid() and inst.swp2hm.components.childspawner2hm then
        if inst.swp2hm.shadowcantout2hm then
            inst.swp2hm.components.childspawner2hm:AddChildrenInside(1)
            return
        end
        local killtime = inst.killself2hm and not (shadowhardermode and TheWorld.components.riftspawner and
                (TheWorld.components.riftspawner.lunar_rifts_enabled or TheWorld.components.riftspawner.shadow_rifts_enabled)) and
            (inst.killtime2hm or killselfcd) or 1
        local rangetime = (inst:IsInLimbo() or (shadowhardermode and TheWorld.components.riftspawner and
                (TheWorld.components.riftspawner.lunar_rifts_enabled or TheWorld.components.riftspawner.shadow_rifts_enabled))) and
            1 or
            (math.min(inst.disttime2hm or math.sqrt(inst:GetDistanceSqToInst(inst.swp2hm)), 1500) / 50)
        inst.swp2hm:DoTaskInTime(0, homeback, killtime + rangetime)
    end
    if maxshadownum and not inst:HasTag("epic") and not table.contains(whitenamelist, inst.prefab) then
        TUNING.currentshadow2hm =
            TUNING.currentshadow2hm - 1
    end
end
local function onchildrealdeath(child) if child then child.isdead2hm = true end end

-- 死亡动画
local deathanims = {"death", "dead", "idle"}
local function tryplaydeathanim(child)
    for _, anim in ipairs(deathanims) do
        child.AnimState:PlayAnimation(anim)
        if child.AnimState:IsCurrentAnimation(anim) then return true end
    end
end

-- 移除分身及其相关实体和特效
local function actualdelayremove(inst) inst:DoTaskInTime(0, inst.Remove) end
local alterguardians = {"alterguardian_phase1", "alterguardian_phase2", "alterguardian_phase3"}
local function removechild(child)
    if child and child:IsValid() then
        -- 原版天体英雄兼容
        if table.contains(alterguardians, child.prefab) and child.sg and child.sg.mem and child.sg.mem.summon_fx and child.sg.mem.summon_fx:IsValid() then
            child.sg.mem.summon_fx:PushEvent("endloop")
            child.sg.mem.summon_fx = nil
        end
        if table.contains(alterguardians, child.prefab) and child.sg and child.sg.mem and child.sg.mem.summon_circle ~= nil and
            child.sg.mem.summon_circle:IsValid() then
            child.sg.mem.summon_circle:Remove()
            child.sg.mem.summon_circle = nil
        end
        -- 妥协月光龙蝇兼容
        if child.prefab == "moonmaw_dragonfly" and child.lavae ~= nil then
            for i = 1, 8 do if child.lavae[i] and child.lavae[i]:IsValid() then child.lavae[i]:Remove() end end
        end
        -- 三合一大蛇兼容
        if child.prefab == "pugalisk" or child.components.multibody then
            local mb = child.components.multibody
            if mb and mb.bodies then
                for i, body in ipairs(mb.bodies) do
                    if body and body.components.segmented and body.components.segmented.segment_deathfn then
                        body.components.segmented.segment_deathfn = nil
                    end
                    if body and body.components.health then body.components.health:Kill() end
                end
                if mb.tail and mb.tail.components.health then mb.tail:Remove() end
                if mb.Kill then mb:Kill() end
            end
        end
        -- 移除分身的方式,原版自杀死亡/直接消失/定住播放死亡动画逐步变淡消失
        if table.contains(realdeathlist, child.prefab) and child.components.health then
            child:DoTaskInTime(10, child.Remove)
            child.components.health:Kill()
        elseif child:IsAsleep() or child:IsInLimbo() or child.components.oceanfishable then
            child:Remove()
        elseif not child.toremove2hm then
            child.toremove2hm = true
            child:AddTag("NOCLICK")
            child:AddTag("notarget")
            child.allmiss2hm = true
            child:StopBrain()
            if child.components.locomotor then child.components.locomotor:StopMoving() end
            if child.components.combat then child.components.combat.keeptargetfn = nil end
            if child.components.health then
                child.components.health.currenthealth = child.components.health.minhealth or 0
                child.components.health:SetInvincible(true)
            end
            if child.sg then child.sg:Stop() end
            if child.Physics then RemovePhysicsColliders(child) end
            if child.DynamicShadow then child.DynamicShadow:Enable(false) end
            if child.MiniMapEntity then child.MiniMapEntity:SetEnabled(false) end
            if child.components.spawnfader2hm then child.components.spawnfader2hm:Cancel() end
            if not child.components.despawnfader2hm then child:AddComponent("despawnfader2hm") end
            child.components.despawnfader2hm.fn = actualdelayremove
            child.components.despawnfader2hm:FadeOut() -- Remove
            if child.AnimState then
                child.AnimState:SetDeltaTimeMultiplier(1)
                if tryplaydeathanim(child) then
                    if child.AnimState:GetCurrentAnimationLength() > 0 then
                        child.components.despawnfader2hm.DeltaTimeMultiplier = 1 /
                            math.min(child.AnimState:GetCurrentAnimationLength(), 1.5)
                    end
                else
                    child.AnimState:Pause()
                end
            end
            child:DoTaskInTime(1.5, child.Remove)
        end
    end
end

-- 天体英雄消失时相关特效清除
local function backfxend(inst)
    if inst:IsValid() then
        inst.AnimState:PlayAnimation("summon_back_pst")
        inst:ListenForEvent("animover", inst.Remove)
    end
end
local function processbackfx(inst)
    if inst:IsValid() and inst._back_fx and inst._back_fx:IsValid() then
        inst._back_fx:ListenForEvent("onremove", function() backfxend(inst._back_fx) end, inst)
    end
end
local function lockalterguardian(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local alterguardians = TheSim:FindEntities(x, y, z, 4, {"brightmareboss"})
    if alterguardians and #alterguardians > 0 then
        local alterguardian = alterguardians[1]
        if alterguardian and alterguardian:IsValid() then
            inst:ListenForEvent("onremove", function() if inst:IsValid() then inst:PushEvent("endloop") end end,
                alterguardian)
        end
    end
end
AddPrefabPostInit("alterguardian_summon_fx", function(inst)
    if not TheNet:IsDedicated() then
        inst:DoTaskInTime(FRAMES, processbackfx)
        return
    end
    if not TheWorld.ismastersim then return end
    inst:DoTaskInTime(0, lockalterguardian)
end)

-- 当分身满足消失条件时,准备让分身消失
local function delayremovechild(child)
    if child and child:IsValid() and not child.removetask2hm then
        child.removetask2hm =
            child:DoTaskInTime(0, removechild)
    end
end
local function onchildbekilled(child)
    if child and child:IsValid() then
        child.isdead2hm = true
        delayremovechild(child)
    end
end
local function onchildkillself(child)
    if child and child:IsValid() then
        child.isdead2hm = true
        child.killself2hm = true
        delayremovechild(child)
    end
end

-- 分身海鱼钓上来后消失并视为海鱼的分身被杀死
local SWIMMING_COLLISION_MASK = COLLISION.GROUND + COLLISION.LAND_OCEAN_LIMITS + COLLISION.OBSTACLES +
    COLLISION.SMALLOBSTACLES
local PROJECTILE_COLLISION_MASK = COLLISION.GROUND
local function OnProjectileLand(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local land_in_water = not TheWorld.Map:IsPassableAtPoint(x, y, z)
    if land_in_water then
        inst:RemoveComponent("complexprojectile")
        inst.Physics:SetCollisionMask(SWIMMING_COLLISION_MASK)
        inst.AnimState:SetSortOrder(ANIM_SORT_ORDER_BELOW_GROUND.UNDERWATER)
        inst.AnimState:SetLayer(LAYER_WIP_BELOW_OCEAN)
        if inst.Light ~= nil then inst.Light:Enable(false) end
        inst.leaving = false
        inst.sg:GoToState("idle")
        inst:RestartBrain()
        SpawnPrefab("splash").Transform:SetPosition(x, y, z)
    else
        onchildbekilled(inst)
    end
end
local function oceanfishMakeProjectile(self)
    local inst = self.inst
    inst:AddComponent("complexprojectile")
    inst.components.complexprojectile:SetOnHit(OnProjectileLand)
    inst:StopBrain()
    inst.sg:GoToState("launched_out_of_water")
    inst.Physics:SetCollisionMask(PROJECTILE_COLLISION_MASK)
    inst.AnimState:SetSortOrder(0)
    inst.AnimState:SetLayer(LAYER_WORLD)
    if inst.Light ~= nil then inst.Light:Enable(true) end
    SpawnPrefab("splash").Transform:SetPosition(inst.Transform:GetWorldPosition())
    return inst
end

-- 分身在某些模式下具有远古影怪的仇恨机制
local maxrangesq = TUNING.SHADOWCREATURE_TARGET_DIST * TUNING.SHADOWCREATURE_TARGET_DIST
local maxrangesq4 = maxrangesq / 4
local function retargetfn_nightmarecreature(inst, ...)
    local rangesq, rangesq1, rangesq2 = maxrangesq, math.huge, math.huge
    local target1, target2 = nil, nil
    for i, v in ipairs(AllPlayers) do
        if not v:HasTag("playerghost") then
            local distsq = v:GetDistanceSqToInst(inst)
            if distsq < rangesq then
                if inst.components.shadowsubmissive and inst.components.shadowsubmissive:TargetHasDominance(v) then
                    if distsq < rangesq1 and inst.components.combat:CanTarget(v) then
                        target1 = v
                        rangesq1 = distsq
                        rangesq = math.max(rangesq1, rangesq2)
                    end
                elseif distsq < rangesq2 and inst.components.combat:CanTarget(v) then
                    target2 = v
                    rangesq2 = distsq
                    rangesq = math.max(rangesq1, rangesq2)
                end
            end
        end
    end
    if target1 and rangesq1 <= math.max(rangesq2, maxrangesq4) then
        return target1,
            not (inst.components.shadowsubmissive and inst.components.shadowsubmissive:TargetHasDominance(inst.components.combat.target))
    end
    if target2 then return target2 end
    return inst.swc2hmtargetfn and inst.swc2hmtargetfn(inst, ...)
end

-- 色彩校验重置
local function resetchildcolor(child)
    if child.AnimState then
        local r, g, b, alpha = child.AnimState:GetMultColour()
        if r ~= 0 or g ~= 0 or b ~= 0 or alpha ~= 0.5 then child.AnimState:SetMultColour(0, 0, 0, 0.5) end
    end
end
-- 位置跟随
local homelocationnames = {"home", "spawnpoint", "herd"}

-- 分身可以转移和共享仇恨目标给本体,部分实体距离本体过远强制回归
local canbackparent_ents = {
    "minotaur"
}
local function cansharetargettoparent(inst, data)
    local target = data and (data.attacker or data.target) or (inst.components.combat and inst.components.combat.target)
    if not target then return end
    local isplayer = target.components.follower and target.components.follower:GetLeader() and target.components.follower:GetLeader():HasTag("player") or target:HasTag("player")
    if inst.swp2hm and inst.swp2hm:IsValid() and table.contains(canbackparent_ents, inst.swp2hm.prefab)
        and (data.damage and data.damage > 0) and isplayer and not inst:IsNear(inst.swp2hm, 30) then
        delayremovechild(inst)
        return
    end
    if target:IsValid() and (target.components.health and not target.components.health:IsDead()) 
        and inst.swp2hm and inst.swp2hm:IsValid()
        and inst.swp2hm.components.combat and not inst.swp2hm.components.combat:HasTarget() then
            if inst.StartAggro then inst:StartAggro() end
            inst.swp2hm.components.combat:SuggestTarget(target)
    end
end

local cantfollow = {"chester", "shadowhutch2hm"}
local function bindpigshadowform(parent, child)
    local werebeast = child.components.werebeast
    if not (werebeast and parent.components.werebeast) then return end

    local setwere, setnormal = werebeast.SetWere, werebeast.SetNormal
    -- 本体完成变身时同步，分身自己的月相和复原计时不再单独变身。
    werebeast.SetWere = nilfn
    werebeast.SetNormal = nilfn
    local health, combat = child.components.health, child.components.combat
    local basehealth, basedamage, baseperiod = health.maxhealth, combat.defaultdamage, combat.min_attack_period

    local function sync()
        if child.toremove2hm or health:IsDead() then return end
        local iswere = parent:HasTag("werepig")
        if iswere == child:HasTag("werepig") then return end
        local percent = health:GetPercent()
        local healthmult = health.maxhealth / basehealth
        local damagemult = combat.defaultdamage / basedamage
        local periodmult = combat.min_attack_period / baseperiod
        local shadowretarget = combat.targetfn == retargetfn_nightmarecreature
        local retargetperiod = combat.retargetperiod
        if iswere then setwere(werebeast) else setnormal(werebeast) end
        basehealth, basedamage, baseperiod = health.maxhealth, combat.defaultdamage, combat.min_attack_period
        health:SetMaxHealth(basehealth * healthmult)
        health:SetPercent(percent)
        combat:SetDefaultDamage(basedamage * damagemult)
        combat:SetAttackPeriod(baseperiod * periodmult)
        if shadownotindependent then
            combat:SetRetargetFunction()
            combat:SetKeepTargetFunction()
        elseif shadowretarget then
            child.swc2hmtargetfn = combat.targetfn
            combat:SetRetargetFunction(retargetperiod, retargetfn_nightmarecreature)
        end
    end

    child:ListenForEvent("transformwere", sync, parent)
    child:ListenForEvent("transformnormal", sync, parent)
    sync()
end

-- 暗影世界机制:分身额外构造函数
local function onspawnchild(inst, child)
    if maxshadownum and not inst:HasTag("epic") and not table.contains(whitenamelist, inst.prefab) then
        TUNING.currentshadow2hm =
            TUNING.currentshadow2hm + 1
    end
    if child.AnimState then child.AnimState:SetMultColour(0, 0, 0, 0.5) end
    child.swp2hm = inst
    child:AddTag("swc2hm")
    child:AddTag("crazy")
    child.persists = false
    -- 骨架和腐化手杖会把合格目标替换成有正常掉落的新实体。
    -- 仅撤销分身的这种变身资格，其他使用同一标签的原生效果不受影响。
    local sgmem = child.sg and child.sg.mem
    if (sgmem and sgmem.canstalkercorrupt) or child.CanStalkerCorrupt then
        if sgmem then sgmem.canstalkercorrupt = nil end
        child.CanStalkerCorrupt = nil
        child:RemoveTag("nightmarecorruptable")
    end
    -- 妥协测试版会在生成后按地形替换蠕虫；分身直接沿用本体的种类。
    if TUNING.DSTU and (child.prefab == "worm" or child.prefab == "shockworm" or child.prefab == "viperworm") then
        child.checked_area_worm = true
    end
    local OnSave = child.OnSave
    child.OnSave = function(child, data, ...)
        data.shadowworld_clone2hm = true
        if OnSave then return OnSave(child, data, ...) end
    end
    if child.components.halloweenmoonmutable then child:RemoveComponent("halloweenmoonmutable") end
    if child.components.eater then child.components.eater.CanEat = falsefn end
    -- 随机生物大小兼容
    child.ray_suijidaxiao = inst.ray_suijidaxiao
    child.myscale = inst.myscale
    -- 暗影切斯特需要预备处理
    if (child.prefab == "chester" or child.prefab == "shadowhutch2hm") and child.OnPreLoad then
        child.OnPreLoad(child,
            {ChesterState = "SHADOW"})
    end
    -- 暗影猴直接狂暴
    if child.prefab == "monkey" then
        child.has_nightmare_state = false
        child:PushEvent("ms_forcenightmarestate", {duration = 10000})
    end
    -- 鱼人
    if child:HasTag("merm") then
        if child.TestForLunarMutation then child.TestForLunarMutation = nilfn end
        if child.DoLunarMutation then child.DoLunarMutation = function(inst) return inst end end
        if child.TestForShadowDeath then child.TestForShadowDeath = nilfn end
    end
    -- 分身受到致命伤害时如何处理
    if table.contains(realdeathlist, child.prefab) then
        child:ListenForEvent("death", onchildrealdeath)
    elseif child.components.health then
        local oldSetVal = child.components.health.SetVal
        child.components.health.SetVal = function(self, val, cause, afflicter, ...)
            if val <= (self.minhealth or 0) and not (child.prefab == "klaus" and not child:IsUnchained()) then
                oldSetVal(self, (self.minhealth or 0) + 0.01, cause, afflicter, ...)
                if self._ignore_maxdamagetakenperhit then
                    onchildkillself(child)
                else
                    onchildbekilled(child)
                end
                -- self.currenthealth = self.minhealth
                return
            end
            return oldSetVal(self, val, cause, afflicter, ...)
        end
    end
    child:ListenForEvent("onremove", onchildremove)
    -- 远古影怪仇恨
    if shadowhateplayer and not child:HasTag("companion") and child.components.combat and
        (child.components.combat.defaultdamage > 0 or child.weaponitems ~= nil or child.components.combat:GetWeapon() ~= nil) then
        child:AddTag("hostile")
        child:AddTag("shadowsubmissive")
        if not child.components.shadowsubmissive then child:AddComponent("shadowsubmissive") end
        if not child.components.sanityaura then child:AddComponent("sanityaura") end
        child.components.sanityaura.aura = math.min(child.components.sanityaura.aura or 0, -TUNING.SANITYAURA_LARGE)
        if not shadownotindependent then
            child.swc2hmtargetfn = child.components.combat.targetfn
            child.components.combat:SetRetargetFunction(inst.components.combat.retargetperiod or 3,
                retargetfn_nightmarecreature)
        end
    end
    -- 关闭独立仇恨
    if shadownotindependent and child.components.combat then
        child.components.combat:SetRetargetFunction()
        child.components.combat:SetKeepTargetFunction()
    end
    -- -- 分身出现时,本体符合条件则转移敌人仇恨到分身
    -- if canshadowhelpself(inst) then inst:PushEvent("transfercombattarget", child) end
    -- 分身没有掉落物
    if child.components.lootdropper then
        child.components.lootdropper:SetLoot()
        child.components.lootdropper:SetChanceLootTable()
        child.components.lootdropper.SpawnLootPrefab = nillootdropperSpawnLootPrefab
        child.components.lootdropper.GenerateLoot = emptytablefn
        child.components.lootdropper.DropLoot = emptytablefn
    end
    -- 分身附近没有玩家时消失,BOSS可无限存在
    if not child.components.playerprox2hm then child:AddComponent("playerprox2hm") end
    child.components.playerprox2hm:SetDist(30, inst:HasTag("epic") and epicshadowfarrange or 50) -- set specific values
    child.components.playerprox2hm:SetOnPlayerFar(delayremovechild)
    -- 被捡起来时回归;缀食者除外
    if child.prefab ~= "slurper" then
        child:ListenForEvent("onputininventory", onchildbekilled)
        child:ListenForEvent("onpickup", onchildbekilled)
    end
    if (child.prefab == "slurtle" or child.prefab == "snurtle") and child.components.burnable then
        child.components.burnable:SetOnExtinguishFn(function(inst) inst.SoundEmitter:KillSound("rattle") end)
    end
    -- 防止掉龙鳞和熊毛,谢天翁羽毛
    if child.prefab == "dragonfly" and child.components.damagetracker then child.components.damagetracker.damage_threshold_fn = nil end
    if child.prefab == "bearger" and child.components.shedder then child.components.shedder.shedItemPrefab = nil end
    if child.prefab == "malbatross" and child.recentlycharged and inst.recentlycharged then
        child.spawnfeather = nilfn
        inst.recentlycharged[child] = true
        child.recentlycharged[inst] = true
    end
    -- 妥协月光熔岩虫
    if child.prefab == "moonmaw_lavae" then child.severed = true end
    -- 草壁虎不掉落草
    if child.prefab == "grassgekko" then
        child.hasTail = false
        child.AnimState:Hide("tail")
        child.components.timer:StartTimer("growTail", TUNING.GRASSGEKKO_REGROW_TIME, true)
    end
    -- 伯尼暗影分身
    if child.prefab == "bernie_big" then
        child.GoInactive = child.Remove
        local brain = require("brains/berniebigbrain2hm")
        child:SetBrain(brain)
        if child.onLeaderChanged and inst.bernieleader then child:onLeaderChanged(inst.bernieleader) end
        if child.CheckForAllegiances and inst.bernieleader then child:CheckForAllegiances(inst.bernieleader) end
        child:RemoveComponent("activatable")
    end
    if child.prefab == "bernie_active" then
        child.GoInactive = child.Remove
        child.GoBig = child.Remove
        local brain = require("brains/berniebrain2hm")
        child:SetBrain(brain)
        child:RemoveComponent("inventoryitem")
    end
    -- 分身坐标跟随
    if child.components.knownlocations and inst.components.knownlocations then
        child.components.knownlocations:OnLoad(inst.components.knownlocations:OnSave())
        local GetLocation = child.components.knownlocations.GetLocation
        child.components.knownlocations.GetLocation = function(self, name, ...)
            if inst:IsValid() and table.contains(homelocationnames, name) then return inst:GetPosition() end
            return GetLocation(self, name, ...) or
                (inst:IsValid() and inst.components.knownlocations and inst.components.knownlocations:GetLocation(name, ...))
        end
    end
    -- 天体英雄三阶段脱离加载后不会休眠（太强了，削弱）
    if child.prefab == "alterguardian_phase3" and old_alterguardian then child.entity:SetCanSleep(false) end
    -- if child.components.entitytracker and inst.components.entitytracker and not child:HasTag("shadowthrall") then
    --     for k, v in pairs(inst.components.entitytracker.entities) do child.components.entitytracker:TrackEntity(k, v.inst) end
    -- end
    -- 织影者定位大门,但不被大门绑定
    if child.prefab == "stalker_atrium" then
        if child.components.entitytracker and inst.components.entitytracker and inst.components.entitytracker:GetEntity("stargate") then
            child.components.entitytracker:TrackEntity("stargate", inst.components.entitytracker:GetEntity("stargate"))
        end
        child.sg:GoToState("resurrect")
        child.FindMinions = emptytablefn
        child.OnLostAtrium = nilfn
        child.IsNearAtrium = truefn
    elseif child.prefab == "stalker_minion" and child.OnSpawnedBy and inst.components.entitytracker then
        local stalker = inst.components.entitytracker:GetEntity("stalker")
        if stalker then child:OnSpawnedBy(stalker) end
    end
    if child.prefab == "mossling" or child.prefab == "mothermossling" then child.mother_dead = true end
    -- 跟随本体的领袖
    if child.components.follower and inst.components.follower and inst.components.follower:GetLeader() ~= nil then
        local leader = inst.components.follower:GetLeader()
        leader = table.contains(cantfollow, child.prefab) and inst.components.follower.leader or leader
        child.components.follower.leader = leader
        child:ListenForEvent("onremove", child.components.follower.OnLeaderRemoved, leader)
        if leader:HasTag("player") or leader.components.inventoryitem ~= nil then
            child.components.follower
                :StartLeashing()
        end
    end
    -- 跟随母体行动
    if inst.components.childspawner then inst.components.childspawner:TakeOwnership(child) end
    -- 兽群代码
    if child.components.herdmember and inst.components.herdmember then
        child.components.herdmember:Enable(inst.components.herdmember.enabled)
        child.components.herdmember.herdprefab = inst.components.herdmember.herdprefab
        if inst.components.herdmember.herd and inst.components.herdmember.herd.components.herd then
            inst.components.herdmember.herd.components.herd:AddMember(child)
        end
    end
    if child.components.scaler and inst.components.scaler then
        child.components.scaler:SetScale(inst.components.scaler
            .scale)
    end
    -- 海鱼且防止钓上来,兼容海内龙虾
    if child.components.oceanfishable then
        child:AddTag("untrappable")
        child:AddTag("notraptrigger")
        if not child.components.health then child:AddTag("noattack") end
        child.components.oceanfishable.MakeProjectile = oceanfishMakeProjectile
    end
    -- 蜘蛛防守
    if inst.defensive and inst.no_targeting and child:HasTag("spider") then
        child:AddDebuff("spider_whistle_buff",
            "spider_whistle_buff")
    end
    -- 防止妥协渔网和炮弹轰炸
    if child.fish_def and child.fish_def.prefab then
        child.fish_def = deepcopy(child.fish_def)
        child.fish_def.prefab = nil
        child.fish_def.loot = {}
        child.edit_fish_def = false
        -- 兼容陆地龙虾
        if child._enter_water then child._enter_water = delayremovechild end
        if child.components.inventoryitem then child.components.inventoryitem.pushlandedevents = false end
        if child.junkfx then
            for i, v in ipairs(child.junkfx) do
                if v and v.AnimState then
                    v.AnimState:SetMultColour(0, 0,
                        0, 0.5)
                end
            end
        end
    end
    -- 机械猪人
    if child.prefab == "daywalker2" and child.components.entitytracker and inst.components.entitytracker and child.MakeFreed then
        local junk = inst.components.entitytracker:GetEntity("junk")
        if junk then
            child.components.entitytracker:TrackEntity("junk", junk)
            if not junk.buryprocess2hm and junk.TryBuryDaywalker then
                junk.buryprocess2hm = true
                local TryBuryDaywalker = junk.TryBuryDaywalker
                junk.TryBuryDaywalker = function(inst, daywalker, ...)
                    if daywalker and daywalker:IsValid() and daywalker:HasTag("swc2hm") then
                        daywalker:Remove()
                        return
                    end
                    TryBuryDaywalker(inst, daywalker, ...)
                end
            end
        end
        child.buried = true
        child:MakeFreed()
    end
    -- 启迪瓦器人
    if child.prefab == "wagboss_robot" then
        child.shattered = true
        child.sg:GoToState("activate")
        child.cantantrum = true
        child.canleap = true
        if child.components.healthtrigger then
            child.components.healthtrigger.triggers = {}
        end
        child:ListenForEvent("death", function(child)
            child.isdead2hm = true
            child:Remove()
        end)
    end
    -- 螨地爬
    if child.prefab == "wagdrone_rolling" then
        if inst:IsValid() and inst.components.entitytracker and inst.components.entitytracker:GetEntity("robot") ~= nil then
            local wagboss_robot = inst.components.entitytracker:GetEntity("robot")
            if wagboss_robot:IsValid() and wagboss_robot.components.commander then
                wagboss_robot.components.commander:AddSoldier(child)
                child:PushEvent("activate")
            end
        end
    end
    -- 黄莺
    if child.prefab == "wagdrone_flying" then
        if inst:IsValid() and inst.components.entitytracker and inst.components.entitytracker:GetEntity("robot") ~= nil then
            local wagboss_robot = inst.components.entitytracker:GetEntity("robot")
            if wagboss_robot:IsValid() and wagboss_robot.components.commander then
                wagboss_robot.components.commander:AddSoldier(child)
                child:PushEvent("activate")
            end
        end
    end
    -- 冰鲨
    if child.prefab == "sharkboi" then
        child:AddTag("hostile")
        child.OnEntitySleep = nil
    end
    -- 禁止捕捉砍伐碰撞等
    if child.components.workable then
        local onwork = child.components.workable.onwork
        child.components.workable:SetOnWorkCallback(function(...)
            if onwork then onwork(...) end
            child.components.workable:SetWorkLeft(child.components.workable.workleft + 1)
        end)
        child.components.workable:SetOnFinishCallback(function() child.components.workable:SetWorkLeft(1) end)
    end
    -- 克劳斯分身指挥宝石鹿分身,跟随狂暴
    if (child.prefab == "klaus" or child.prefab == "klaus2hm") and child.components.commander and inst.components.commander then
        child.components.commander.GetNumSoldiers = function()
            return inst and inst:IsValid() and inst.components.commander and inst.components.commander:GetNumSoldiers() or
                2
        end
        local deers = inst.components.commander:GetAllSoldiers()
        for index, deer in ipairs(deers) do
            if deer and deer:IsValid() and deer.components.childspawner2hm then
                for k, v in pairs(deer.components.childspawner2hm.childrenoutside) do
                    if v:IsValid() and v.components.entitytracker and v.components.entitytracker:GetEntity("keeper") == nil then
                        child.components.commander:AddSoldier(v)
                    end
                    break
                end
            end
        end
    end
    -- 宝石鹿分身跟随克劳斯的分身
    if (child.prefab == "deer_red" or child.prefab == "deer_blue" or child.prefab == "deer_red2hm" or child.prefab == "deer_blue2hm") and child.components.entitytracker and inst.components.entitytracker then
        local klaus = inst.components.entitytracker:GetEntity("keeper")
        if klaus and klaus:IsValid() and klaus.components.childspawner2hm then
            for k, v in pairs(klaus.components.childspawner2hm.childrenoutside) do
                if v:IsValid() and v.components.commander then
                    local deers = v.components.commander:GetAllSoldiers()
                    if #deers == 0 or (#deers == 1 and deers[1].prefab ~= child.prefab) then
                        v.components.commander
                            :AddSoldier(child)
                    end
                end
                break
            end
        end
    end
    -- 禁止做窝
    if TUNING.DSTU and child.prefab == "boulder_crab" then
        child.SpawnHole = function(inst, ...)
            child.isdead2hm = true
            inst:Remove()
        end
    end
    if child.prefab == "tallbird" then child.CanMakeNewHome = nilfn end
    -- 幼鸟长大时会生成新实体，分身应保持本体生成时的阶段。
    if (child.prefab == "smallbird" or child.prefab == "teenbird") and child.components.growable then
        child.components.growable:StopGrowing()
    end
    -- 洞穴只会从休眠的成年石虾里选首领，分身不能作为候选。
    if child.prefab == "rocky" then child.IsMaxSize = falsefn end
    if child.prefab == "mole" then child.make_home_delay = 10000 end
    if child.prefab == "spiderqueen" and child.GetTimeAlive then
        if not child.GetTimeAlive2hm then
            local GetTimeAlive = child.GetTimeAlive
            child.GetTimeAlive = function(self, ...)
                return math.clamp(GetTimeAlive(self, ...), 0,
                    TUNING.SPIDERQUEEN_MINWANDERTIME)
            end
        elseif child.components.hunger then
            child.components.hunger:Pause()
        end
    end
    -- 禁止刮牛毛
    if child.components.beard then child.components.beard.prize = nil end
    if child.components.brushable then child.components.brushable.brushable = nil end
    -- 阿比盖尔优化
    if child.prefab == "abigail" then
        if not (inst._playerlink and inst._playerlink:IsValid()) then
            child:RemoveFromScene()
            return
        end
        -- 2025.3.16 由leo468[修复阿比盖尔影子血量不正常]问题
        local bondlevel = (inst._playerlink ~= nil and inst._playerlink.components.ghostlybond ~= nil) and
            inst._playerlink.components.ghostlybond.bondlevel or 0
        local max_health = bondlevel == 3 and TUNING.ABIGAIL_HEALTH_LEVEL3 or
            bondlevel == 2 and TUNING.ABIGAIL_HEALTH_LEVEL2 or TUNING.ABIGAIL_HEALTH_LEVEL1
        if child.components.health then
            child.base_max_health = max_health -- 主要是添加了这句
            child.components.health:SetMaxHealth(max_health)
        end
        if child.components.debuffable and inst.components.debuffable then
            child.components.debuffable:OnLoad(inst.components.debuffable:OnSave())
        end
        -- 2025.3.16 end
        child._playerlink = inst._playerlink
        child:ListenForEvent("onremove", function(player)
            child._onlostplayerlink(player)
            child:RemoveFromScene()
        end, inst._playerlink)
        if inst.is_defensive then
            child:BecomeDefensive()
        else
            child:BecomeAggressive()
        end
    end
    -- 兼容富贵险中求防偷窃
    if child.components.ndnr_pluckable ~= nil then child.components.ndnr_pluckable:SetChance(0) end
    -- 禁止骑乘
    if child.components.rideable then child.components.rideable:SetCustomRiderTest(falsefn) end
    -- 牛铃会单独保存绑定的牛，影子也不能被阴郁牛铃绑定。
    if child.prefab == "beefalo" then
        child.SetBeefBellOwner = function() return false, "INVALID_TARGET" end
    end
    -- 禁止作祟
    if child.components.hauntable then child:AddTag("haunted") end
    -- 色彩和仇恨伤害补丁
    if child.components.combat then
        -- 颜色锁定，冗余代码但用来兼容其他模组
        child:ListenForEvent("droppedtarget", resetchildcolor)
        child:ListenForEvent("attacked", resetchildcolor)
        if inst.components.combat then
            -- 护主仇恨
            if inst.components.combat.target then child.components.combat:SetTarget(inst.components.combat.target) end
            -- 武器伤害
            if child.components.combat.defaultdamage == 0 and child.weaponitems == nil and child.components.combat:GetWeapon() == nil then
                if inst.components.combat.defaultdamage ~= 0 then
                    child.components.combat.defaultdamage = inst.components.combat.defaultdamage
                elseif inst.weaponitems ~= nil then
                    for _, weapon in pairs(inst.weaponitems) do
                        if weapon and weapon:IsValid() and weapon.components.weapon and weapon.components.weapon.damage and
                            type(weapon.components.weapon.damage) == "number" then
                            child.components.combat.defaultdamage = weapon.components.weapon.damage
                            break
                        end
                    end
                else
                    -- 大副
                    local weapon = inst.components.combat:GetWeapon()
                    if weapon and weapon:IsValid() and weapon.components.weapon and weapon.components.weapon.damage and type(weapon.components.weapon.damage) ==
                        "number" then
                        child.components.combat.defaultdamage = weapon.components.weapon.damage
                    end
                end
            end
        end
    elseif child.sg then
        -- 颜色锁定，冗余代码但用来兼容其他模组
        child:ListenForEvent("newstate", resetchildcolor)
    end
    -- 显现特效
    if not child.components.spawnfader2hm then child:AddComponent("spawnfader2hm") end
    child.components.spawnfader2hm:FadeIn()
    -- 第二周目
    if shadowhardermode and not table.contains(mutatedepics, child.prefab) then
        if child.components.combat then child:ListenForEvent("droppedtarget", childteleporttoparent) end
        child:ListenForEvent("entitysleep", childteleporttoparent)
    end
    -- 这个必须放最后面,有些单位前面处理中会把persists设为true
    child.persists = false
    -- 分身处理接口
    if child.swc2hmfn then
        child:swc2hmfn()
    elseif inst.swc2hmfn then
        inst.swc2hmfn(child)
    end
    if child.prefab == "pigman" or child.prefab == "pigguard" then bindpigshadowform(inst, child) end
    if child.shadowcantout2hm then
        -- child:ListenForEvent("newcombattarget", cansharetargettoparent)
        -- child:ListenForEvent("blocked", cansharetargettoparent)
        child:ListenForEvent("attacked", cansharetargettoparent)
        -- child:ListenForEvent("doattack", cansharetargettoparent)
    end
end

-- 影分身禁止拾取
require("actions")
local oldfn = ACTIONS.PICKUP.fn
if oldfn then
    ACTIONS.PICKUP.fn = function(act, ...)
        if act and act.target and act.target:HasTag("swc2hm") then
            if act.doer and act.doer.components.talker then
                act.doer:DoTaskInTime(0,function()
                    act.doer.components.talker:Say((TUNING.isCh2hm and "无法触摸的阴影..." or "Untouchable shadow..."))
                end)
            end
            return false
        end
        local result, reason = oldfn(act, ...)
        return result, reason
    end
end

-- 棋子影怪二周目牢不可分
if shadowhardermode then
    local shadowchesspieces = {"shadow_knight", "shadow_bishop", "shadow_rook"}
    local function shadowchesspieceteleport(inst)
        if inst.teleportinst2hm and TheWorld.components.riftspawner and
            (TheWorld.components.riftspawner.lunar_rifts_enabled or TheWorld.components.riftspawner.shadow_rifts_enabled) then
            inst:teleportinst2hm()
        end
    end
    for _, shadowchesspiece in ipairs(shadowchesspieces) do
        AddPrefabPostInit(shadowchesspiece, function(inst)
            if not TheWorld.ismastersim then return end
            inst:ListenForEvent("droppedtarget", shadowchesspieceteleport)
            inst:ListenForEvent("entitysleep", shadowchesspieceteleport)
        end)
    end
    -- 第二周目影子可以吞掉回旋或弹射弹药 -- 2025.6.15 melon:出裂隙用远程就崩 先注释
    -- AddComponentPostInit("projectile", function(self)
    --     local Hit = self.Hit
    --     self.Hit = function(self, target, ...)
    --         if target and target:IsValid() and target:HasTag("swc2hm") and TheWorld.components.riftspawner and
    --             (TheWorld.components.riftspawner.lunar_rifts_enabled or TheWorld.components.riftspawner.shadow_rifts_enabled) then
    --             Hit(self, target, ...)
    --             if self.inst and self.inst:IsValid() then self:Miss(target) end
    --         end
    --         return Hit(self, target, ...)
    --     end
    -- end)
end

-- 织影者分身不再施法
AddStategraphPostInit("SGstalker", function(sg)
    local summon_channelers_pre = sg.states.summon_channelers_pre.onenter
    sg.states.summon_channelers_pre.onenter = function(inst, ...)
        if inst:HasTag("swc2hm") and inst.components.timer and inst.components.health and not inst.components.health:IsDead() then
            inst.components.health:DoDelta(inst.components.health.maxhealth * 0.05)
            inst.components.timer:StopTimer("channelers_cd")
            inst.components.timer:StartTimer("channelers_cd", TUNING.STALKER_CHANNELERS_CD)
            inst.sg:GoToState("idle")
            return
        end
        summon_channelers_pre(inst, ...)
    end
    local summon_minions_pre = sg.states.summon_minions_pre.onenter
    sg.states.summon_minions_pre.onenter = function(inst, ...)
        if inst:HasTag("swc2hm") and inst.components.timer then
            inst.components.health:DoDelta(inst.components.health.maxhealth * 0.05)
            inst.components.timer:StopTimer("minions_cd")
            inst.components.timer:StartTimer("minions_cd", TUNING.STALKER_MINIONS_CD)
            inst.sg:GoToState("idle")
            return
        end
        summon_minions_pre(inst, ...)
    end
end)

-- 阿比盖尔操控激进
local function RefreshFlowerTooltip(inst)
    local ghost = inst.components.ghostlybond and inst.components.ghostlybond.ghost
    if ghost and ghost.prefab == "abigail" and ghost:IsValid() and ghost.is_defensive ~= nil and ghost.components.childspawner2hm and
        ghost.components.childspawner2hm.childrenoutside then
        for k, child in pairs(ghost.components.childspawner2hm.childrenoutside) do
            if child and child.prefab == "abigail" and child:IsValid() and child.is_defensive ~= nil then
                if ghost.is_defensive ~= child.is_defensive then
                    if ghost.is_defensive and not ghost.changeswp2hm then
                        child:BecomeDefensive()
                    else
                        child:BecomeAggressive()
                    end
                end
            end
        end
    end
end
-- 阿比盖尔在线升级
local function onghostlybond_level_change(inst, data)
    local ghost = inst.components.ghostlybond and inst.components.ghostlybond.ghost
    if ghost and ghost.prefab == "abigail" and ghost:IsValid() and ghost.components.childspawner2hm and ghost.components.childspawner2hm.childrenoutside then
        local level = data and data.level or 1
        local max_health = level == 3 and TUNING.ABIGAIL_HEALTH_LEVEL3 or level == 2 and TUNING.ABIGAIL_HEALTH_LEVEL2 or
            TUNING.ABIGAIL_HEALTH_LEVEL1
        for k, child in pairs(ghost.components.childspawner2hm.childrenoutside) do
            if child and child.prefab == "abigail" and child:IsValid() and not child.isdead2hm and child.components.health and
                not child.components.health:IsDead() then
                if level > 1 and not child.sg:HasStateTag("busy") then
                    inst.sg:GoToState("ghostlybond_levelup",
                        {level = level})
                end
                local health_percent = child.components.health:GetPercent()
                child.components.health:SetMaxHealth(max_health)
                child.components.health:SetPercent(health_percent, true)
            end
        end
    end
end
AddComponentPostInit("ghostlybond", function(self)
    if not TheWorld.ismastersim then return end
    self.inst:ListenForEvent("refreshflowertooltip", RefreshFlowerTooltip)
    self.inst:ListenForEvent("ghostlybond_level_change", onghostlybond_level_change)
end)
-- 阿比盖尔共享BUFF
AddComponentPostInit("ghostlyelixir", function(self)
    local Apply = self.Apply
    self.Apply = function(self, doer, target, ...)
        if self.doapplyelixerfn and not self.doapplyelixerfn2hm then
            self.doapplyelixerfn2hm = true
            local old = self.doapplyelixerfn
            self.doapplyelixerfn = function(inst, doer, target, ...)
                if target and target.prefab == "abigail" and target:IsValid() and target.components.childspawner2hm and
                    target.components.childspawner2hm.childrenoutside then
                    for k, child in pairs(target.components.childspawner2hm.childrenoutside) do
                        if child and child.prefab == "abigail" and child:IsValid() then old(inst, doer, child, ...) end
                    end
                end
                return old(inst, doer, target, ...)
            end
        end
        return Apply(self, doer, target, ...)
    end
end)
local function ghostsg(sg)
    local start = sg.events and sg.events.startaura and sg.events.startaura.fn
    if start then
        sg.events.startaura.fn = function(inst, ...)
            start(inst, ...)
            if inst:HasTag("swc2hm") then inst.AnimState:SetMultColour(0, 0, 0, 0.5) end
        end
    end
    local stop = sg.events and sg.events.startaura and sg.events.stopaura.fn
    if stop then
        sg.events.stopaura.fn = function(inst, ...)
            stop(inst, ...)
            if inst:HasTag("swc2hm") then inst.AnimState:SetMultColour(0, 0, 0, 0.5) end
        end
    end
end
AddStategraphPostInit("abigail", ghostsg)
AddStategraphPostInit("ghost", ghostsg)

-- 玩家远离本体后分身回归
local function onfar(inst)
    if inst.components.childspawner2hm and inst.components.childspawner2hm.childrenoutside then
        for k, child in pairs(inst.components.childspawner2hm.childrenoutside) do
            if child and child:IsValid() then
                delayremovechild(child)
            end
        end
    end
end
local function onfar_sp(inst) -- 2025.9.10 melon:梦魇疯猪需要判断被击败状态才收回影子
    if inst.components.childspawner2hm and inst.components.childspawner2hm.childrenoutside
        and (inst.prefab ~= "daywalker" or inst.hostile) then
        for k, child in pairs(inst.components.childspawner2hm.childrenoutside) do
            if child and child:IsValid() then
                delayremovechild(child)
            end
        end
    end
end

local function canspawnchild(inst)
    if TUNING.currentshadow2hm < maxshadownum or inst:HasTag("epic") then
        if inst.components.combat then inst.components.combat.externaldamagetakenmultipliers:RemoveModifier("swcmax2hm") end
        return true
    elseif inst.components.combat then
        inst.components.combat.externaldamagetakenmultipliers:SetModifier("swcmax2hm",
            1 / (2 + inst.components.childspawner2hm.childreninside))
    end
end

local function ShouldBeDefeated(inst)
    return inst.components.health.currenthealth <= inst.components.health.minhealth
end
-- 满足条件释放分身
local function releasechildren(inst, target, trytransfer, force)
    if table.contains(mindeathlist, inst.prefab) and (inst.defeated or inst.sg:HasStateTag("defeated") or (inst.prefab ~= "daywalker" and ShouldBeDefeated(inst))) then return end
    if target then
        if not target:IsValid() then target = nil end
        if inst.swhastarget2hmtask then inst.swhastarget2hmtask = nil end
    elseif inst.swonnear2hmtask then
        inst.swonnear2hmtask = nil
    end
    if not (inst.disablesw2hm or inst:HasTag("disablesw2hm")) and inst.components.childspawner2hm and inst.components.childspawner2hm.childreninside > 0 and
        (inst.components.childspawner2hm.canspawnfn == nil or inst.components.childspawner2hm.canspawnfn(inst)) and not inst:IsAsleep() and
        not inst:HasTag("INLIMBO") and not (inst.components.inventoryitem and inst.components.inventoryitem.owner) and
        not (inst:HasTag("epic") and inst.components.follower and inst.components.follower.leader and inst.components.follower.leader:IsValid() and
            inst.components.follower.leader:HasTag("player")) and inst.components.playerprox2hm and inst.components.playerprox2hm:IsPlayerClose() and
        ((inst.components.health and not inst.components.health:IsDead() and ( -- 远古仇恨模式
            force or shadowhateplayer or                                       -- 蟹钳
            inst.prefab == "crabking_claw" or (inst.components.combat and (    -- 有仇恨目标
                target or inst.components.combat.target or (                   -- 攻击力为0的单位也默认生成影子,但格罗姆随从除外
                    inst.components.combat.defaultdamage == 0 and inst.weaponitems == nil and inst.components.combat:GetWeapon() == nil and inst.prefab ~= "glommer" and
                    not inst:HasTag("companion")))))) or (inst.components.oceanfishable and inst.components.weighable)) and
        (table.contains(whitenamelist, inst.prefab) or               -- false 全部生成
            not shadowanimals or (                                   -- 1 除boss外的生物会生成暗影分身
                shadowanimals == 1 and not inst:HasTag("epic")) or ( -- 2 仅boss会生成暗影分身
                shadowanimals == 2 and inst:HasTag("epic")) or (     -- 3 全部生成但boss残血25%或2500血以下时才生成
                shadowanimals == 3 and
                (not inst:HasTag("epic") or
                    (inst.components.health and (inst.components.health:GetPercent() <= 0.25 or inst.components.health.currenthealth <= 2500)))) -- 4 全部生成但蜂后和部分困难加强boss半血时生成
            or (                                                                                                                                 -- 4 全部生成但蜂后和部分困难加强boss半血时生成
                shadowanimals == 4 and (not table.contains(epicshasshadow, inst.prefab) or
                    (inst.components.health and (inst.components.health:GetPercent() <= 0.5 or inst.components.health.currenthealth <= 5000)))) or
            ( -- 5 全部生成但boss半血50%或5000血以下时才生成
                shadowanimals == 5 and
                (not inst:HasTag("epic") or
                    (inst.components.health and (inst.components.health:GetPercent() <= 0.5 or inst.components.health.currenthealth <= 5000)))) or
            ( -- 6 仅boss残血25%或2500血以下时生成暗影分身
                shadowanimals == 6 and
                (inst:HasTag("epic") and inst.components.health and
                    (inst.components.health:GetPercent() <= 0.25 or inst.components.health.currenthealth <= 2500)))) then
        -- 释放分身
        inst.components.childspawner2hm:ReleaseAllChildren(
            target or (inst.components.combat and inst.components.combat.target),
            inst.components.childspawner2hm.childname)
    end
    -- 分享和转移仇恨
    if inst.components.childspawner2hm and inst.components.childspawner2hm.numchildrenoutside > 0 and inst.components.combat then
        if target or inst.components.combat.target then
            for k, v in pairs(inst.components.childspawner2hm.childrenoutside) do
                if v and v:IsValid() and v.components.combat and not v.changeswp2hm and (shadownotindependent or not v.components.combat.target) then
                    v.components.combat:SetTarget(target or inst.components.combat.target)
                end
            end
        end
        if trytransfer and canshadowhelpself(inst) then
            local usetransfercombattarget = false
            for k, v in pairs(inst.components.childspawner2hm.childrenoutside) do
                if v and v:IsValid() and not usetransfercombattarget and not v.changeswp2hm and v.components.health and not v.components.health:IsDead() then
                    usetransfercombattarget = true
                    inst:PushEvent("transfercombattarget", v)
                    break
                end
            end
        end
    end
end
local function onnear(inst) if not inst.swonnear2hmtask then inst.swonnear2hmtask = inst:DoTaskInTime(0, releasechildren) end end
local function onhastarget(inst, target, trytransfer)
    if not inst.swhastarget2hmtask and target then
        inst.swhastarget2hmtask = inst:DoTaskInTime(0, releasechildren, target,
            trytransfer)
    end
end
local function onattacked(inst, data)
    onhastarget(inst,
        data and data.attacker or (inst.components.combat and inst.components.combat.target), true)
end
local function onhitother(inst, data)
    onhastarget(inst,
        data and data.target or (inst.components.combat and inst.components.combat.target))
end
local function onaddchild(inst)
    if inst.components.playerprox2hm and inst.components.playerprox2hm:IsPlayerClose() then
        onnear(inst)
    end
end

-- 暗影世界机制:本体改动
local function processshadowparent(inst)
    if inst:HasTag("swc2hm") or inst.disablesw2hm or inst:HasTag("disablesw2hm") then return end
    inst:AddTag("swp2hm")
    if not inst.components.childspawner2hm then inst:AddComponent("childspawner2hm") end
    inst.components.childspawner2hm.childname = specialshadows[inst.prefab] or inst.prefab
    inst.components.childspawner2hm:SetMaxChildren(shadownumber)
    inst.components.childspawner2hm.allowboats = true
    inst.components.childspawner2hm.allowwater = true
    if inst.prefab == "glommer" then
        inst.components.childspawner2hm:SetRegenPeriod(shadowregenperiod + 480)
        inst.components.childspawner2hm.childreninside = 0
    else
        inst.components.childspawner2hm:SetRegenPeriod(shadowregenperiod)
    end
    inst.components.childspawner2hm:SetSpawnedFn(onspawnchild)
    inst.components.childspawner2hm:SetOnAddChildFn(onaddchild)
    if maxshadownum and not inst:HasTag("epic") and not table.contains(whitenamelist, inst.prefab) then
        inst.components.childspawner2hm.canspawnfn = canspawnchild
    end
    if not inst.components.playerprox2hm then inst:AddComponent("playerprox2hm") end
    inst.components.playerprox2hm:SetDist(inst:HasTag("epic") and 60 or 30, inst:HasTag("epic") and swepicfarrange or 50) -- set specific values
    inst.components.playerprox2hm:SetOnPlayerNear(onnear)
    inst.components.playerprox2hm:SetOnPlayerFar(onfar)
    inst:ListenForEvent("newcombattarget", onhitother)
    inst:ListenForEvent("blocked", onattacked)
    inst:ListenForEvent("attacked", onattacked)
    inst:ListenForEvent("doattack", onhitother)
    if inst.prefab ~= "slurper" then
        inst:ListenForEvent("onputininventory", onfar)
        inst:ListenForEvent("onpickup", onfar)
        inst:ListenForEvent("enterlimbo", onfar)
    end
    if not table.contains(realdeathlist, inst.prefab) then inst:ListenForEvent("death", onfar) end
    if table.contains(mindeathlist, inst.prefab) then inst:ListenForEvent("minhealth", onfar_sp) end
    -- 第二周目
    if shadowhardermode and not table.contains(mutatedepics, inst.prefab) then
        if inst.components.combat then
            inst:ListenForEvent("droppedtarget", parentteleportchildren)
            inst:ListenForEvent("newcombattarget", testparentteleportchildren)
        end
        inst:ListenForEvent("entitysleep", parentteleportchildren)
    end
    inst:ListenForEvent("onremove", onfar)
    if inst.swp2hmfn then inst:swp2hmfn() end
    if inst.components.childspawner2hm.tmpprefabposlist then
        if inst.swonnear2hmtask then inst.swonnear2hmtask:Cancel() end
        inst.swonnear2hmtask = inst:DoTaskInTime(0, releasechildren, nil, nil, true)
    end
end

-- 暗影世界机制:生物生成分身
AddPrefabPostInitAny(function(inst)
    if not TheWorld.ismastersim then return end
    if not hasshadow(inst) then return end
    inst:DoTaskInTime(0, processshadowparent)
end)

-- 影分身免疫高亮
AddComponentPostInit("highlight",
    function(self) if self.inst and self.inst:HasTag("swc2hm") then self.ApplyColour = nilfn end end)

-- 分身攻击不到本体,本体攻击不到分身
AddComponentPostInit("combat", function(self)
    local oldCanHitTarget = self.CanHitTarget
    self.CanHitTarget = function(self, target, ...)
        return target and oldCanHitTarget(self, target, ...) and
            not (self.inst.swp2hm == target or target.swp2hm == self.inst or (target.swp2hm and self.inst.swp2hm == target.swp2hm))
    end
    local oldIsValidTarget = self.IsValidTarget
    self.IsValidTarget = function(self, target, ...)
        return target and oldIsValidTarget(self, target, ...) and
            not (self.inst.swp2hm == target or target.swp2hm == self.inst or (target.swp2hm and self.inst.swp2hm == target.swp2hm))
    end
end)

-- 分身免疫陷阱和捕鸟陷阱
AddComponentPostInit("trap", function(self)
    local oldDoSpring = self.DoSpring
    self.DoSpring = function(self, ...)
        if self.target and (not self.target:IsValid() or self.target:HasTag("swc2hm")) then
            self:StopUpdating()
            return
        end
        return oldDoSpring(self, ...)
    end
end)

-- 无眼鹿不掉落宝石且变成其他鹿
AddStategraphPostInit("deer", function(sg)
    local unshacklefn_Old = sg.events["unshackle"].fn
    sg.events["unshackle"].fn = function(inst, ...) if not inst:HasTag("swc2hm") then unshacklefn_Old(inst, ...) end end
end)

-- 鲸鱼攻击船时不会变成角
AddStategraphPostInit("gnarwail", function(sg)
    local old = sg.states["finish_boat_attack"].onenter
    sg.states["finish_boat_attack"].onenter = function(inst, target_info, ...)
        if not inst:HasTag("swc2hm") then
            old(inst, target_info, ...)
        else
            local tx, ty, tz = target_info.target_pos:Get()
            local target = target_info.target
            if target and target:IsValid() then
                if target:GetDistanceSqToPoint(tx, ty, tz) < TUNING.GNARWAIL.BOATATTACK_RADIUSSQ then
                    target.components.combat:GetAttacked_Internal(inst, TUNING.GNARWAIL.DAMAGE)
                end
            end
            local platform = target_info.boat
            if platform ~= nil and platform:IsValid() and platform.components.hullhealth ~= nil and platform.components.health ~= nil then
                platform.components.health:DoDelta(-TUNING.GNARWAIL.HORN_BOAT_DAMAGE / 4)
            end
            if TheWorld.Map:IsOceanTileAtPoint(tx, ty, tz) and not TheWorld.Map:IsVisualGroundAtPoint(tx, ty, tz) then
                inst.Transform:SetPosition(tx, ty, tz)
            end
            inst.components.combat:CancelAttack()
            inst.sg:GoToState("emerge")
        end
    end
end)

-- 分身克劳斯停止播放音乐
local function klausclientprocess(inst)
    if inst:HasTag("swc2hm") and not TheWorld.ismastersim and not TheNet:IsDedicated() and inst._musictask ~= nil then
        inst._musictask:Cancel()
        inst._musictask = nil
    end
end
AddPrefabPostInit("klaus",
    function(inst) if not TheWorld.ismastersim then inst:DoTaskInTime(FRAMES, klausclientprocess) end end)
AddPrefabPostInit("klaus2hm",
    function(inst) if not TheWorld.ismastersim then inst:DoTaskInTime(FRAMES, klausclientprocess) end end)
-- 噩梦猪人头颅暗影化
local function OnHeadTrackingDirty(inst)
    if inst.head ~= nil and inst:HasTag("swc2hm") and inst.head.AnimState then
        inst.head.AnimState:SetMultColour(0, 0, 0,
            0.5)
    end
end
local function processdaywalker(inst)
    if not TheWorld.ismastersim then
        inst:ListenForEvent("headtrackingdirty",
            OnHeadTrackingDirty)
    end
end
AddPrefabPostInit("daywalker", processdaywalker)
AddPrefabPostInit("daywalker2", processdaywalker)
AddPrefabPostInit("daywalker_pillar", function(inst)
    if not TheWorld.ismastersim then return end
    local OnCollided = inst.OnCollided
    inst.OnCollided = function(inst, other, ...)
        if other == nil or not other:IsValid() or other:HasTag("swc2hm") then
            if inst.SoundEmitter then inst.SoundEmitter:PlaySound("daywalker/pillar/hit") end
            return
        end
        OnCollided(inst, other, ...)
    end
end)

-- 韦伯口哨，驱散分身的影子
AddPrefabPostInit("spider_whistle", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.followerherder and inst.components.followerherder.onherfn then
        local onherfn = inst.components.followerherder.onherfn
        inst.components.followerherder.onherfn = function(inst, leader, ...)
            for follower, v in pairs(leader.components.leader.followers) do
                if follower and follower:IsValid() and not follower:IsInLimbo() and follower:HasTag("spider") and follower:HasTag("swp2hm") and
                    follower.components.childspawner2hm and follower.components.childspawner2hm.numchildrenoutside > 0 then
                    for k, v in pairs(follower.components.childspawner2hm.childrenoutside) do
                        if v and v:IsValid() and v:HasTag("spider") and v.components.health and not v.components.health:IsDead() then
                            v:AddDebuff("spider_whistle_buff", "spider_whistle_buff")
                        end
                    end
                end
            end
            onherfn(inst, leader, ...)
            for follower, v in pairs(leader.components.leader.followers) do
                if follower and follower:IsValid() and not follower:IsInLimbo() and follower:HasTag("spider") and follower:HasTag("swp2hm") and
                    follower.components.childspawner2hm and follower.components.childspawner2hm.numchildrenoutside > 0 and follower.components.playerprox2hm and
                    follower.components.playerprox2hm.isclose and follower.components.combat and not follower.components.combat.target then
                    follower.components.playerprox2hm.isclose = false
                    follower:PushEvent("onfar2hm")
                    if follower.components.playerprox2hm.onfar ~= nil then
                        follower.components.playerprox2hm.onfar(
                            follower)
                    end
                end
            end
        end
    end
end)
AddPrefabPostInit("spider_repellent", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.repellent and inst.components.repellent.Repel then
        local Repel = inst.components.repellent.Repel
        inst.components.repellent.Repel = function(self, doer, ...)
            for follower, v in pairs(doer.components.leader.followers) do
                if follower and follower:IsValid() and not follower:IsInLimbo() and follower:HasTag("spider") and follower:HasTag("swp2hm") and
                    follower.components.childspawner2hm and follower.components.childspawner2hm.numchildrenoutside > 0 and follower.components.playerprox2hm and
                    follower.components.playerprox2hm.isclose and follower.components.combat and not follower.components.combat.target then
                    follower.components.playerprox2hm.isclose = false
                    follower:PushEvent("onfar2hm")
                    if follower.components.playerprox2hm.onfar ~= nil then
                        follower.components.playerprox2hm.onfar(
                            follower)
                    end
                end
            end
            Repel(self, doer, ...)
        end
    end
end)

-- 切斯特和哈奇分身额外增加打开容器或检查召唤分身
local function chesterandhutch(inst)
    if not TheWorld.ismastersim or not hasshadow(inst) then return end
    if inst.components.container then
        local oldonopenfn = inst.components.container.onopenfn
        inst.components.container.onopenfn = function(inst)
            oldonopenfn(inst)
            if inst.components.childspawner2hm then
                inst.components.childspawner2hm:ReleaseAllChildren(nil, inst.components.childspawner2hm.childname)
            end
        end
    end
    if inst.components.inspectable then
        local olddescription = inst.components.inspectable.GetDescription
        inst.components.inspectable.GetDescription = function(self, viewer, ...)
            local desc, filter_context, author = olddescription(self, viewer, ...)
            if inst.components.childspawner2hm then
                inst.components.childspawner2hm:ReleaseAllChildren(nil, inst.components.childspawner2hm.childname)
            end
            return desc, filter_context, author
        end
    end
end
AddPrefabPostInit("chester", chesterandhutch)
AddPrefabPostInit("hutch", chesterandhutch)

-- 启迪瓦器人
AddPrefabPostInit("wagboss_robot", function(inst)
    if not TheWorld.ismastersim or inst:HasTag("swc2hm") or not hasshadow(inst) then return end
    inst:ListenForEvent("deactivate", function(inst)
        onfar(inst)
    end)
end)
-- 螨地爬启动时召唤所有分身
local wagdrone_rollingbrain = require("brains/wagdrone_rollingbrain2hm")
AddPrefabPostInit("wagdrone_rolling", function(inst)
    if not TheWorld.ismastersim or not hasshadow(inst) then return end
    if not inst:HasTag("swc2hm") then
        inst:ListenForEvent("activate", function(inst)
            if inst.components.childspawner2hm then
                inst.components.childspawner2hm:ReleaseAllChildren(nil, inst.components.childspawner2hm.childname)
                for i, v in pairs(inst.components.childspawner2hm.childrenoutside) do
                    if inst:IsValid() and inst.components.entitytracker and inst.components.entitytracker:GetEntity("robot") ~= nil then
                        local wagboss_robot = inst.components.entitytracker:GetEntity("robot")
                        if wagboss_robot:IsValid() and wagboss_robot.components.commander then
                            wagboss_robot.components.commander:AddSoldier(v)
                            v:PushEvent("activate")
                        end
                    end
                end
            end
        end)
    end
    local oldSetBrainEnabled = inst.SetBrainEnabled
    inst.SetBrainEnabled = function(inst, enable, ...)
        if not inst:HasTag("swc2hm") then
            oldSetBrainEnabled(inst, enable, ...)
        elseif inst:HasTag("swc2hm") then
            if enable then
                inst:SetBrain(wagdrone_rollingbrain)
                if not inst:IsAsleep() then
                    inst:RestartBrain()
                end
            else
                inst:SetBrain(nil)
            end
        end
    end
    if inst:HasTag("swc2hm") then return end
    inst:ListenForEvent("deactivate", function(inst)
        onfar(inst)
    end)
end)

-- 黄莺启动时召唤所有分身
AddPrefabPostInit("wagdrone_flying", function(inst)
    if not TheWorld.ismastersim or not hasshadow(inst) then return end
    if not inst:HasTag("swc2hm") then
        inst:ListenForEvent("activate", function(inst)
            if inst.components.childspawner2hm then
                inst.components.childspawner2hm:ReleaseAllChildren(nil, inst.components.childspawner2hm.childname)
                for i, v in pairs(inst.components.childspawner2hm.childrenoutside) do
                    if inst:IsValid() and inst.components.entitytracker and inst.components.entitytracker:GetEntity("robot") ~= nil then
                        local wagboss_robot = inst.components.entitytracker:GetEntity("robot")
                        if wagboss_robot:IsValid() and wagboss_robot.components.commander then
                            wagboss_robot.components.commander:AddSoldier(v)
                            v:PushEvent("activate")
                        end
                    end
                end
            end
        end)
    end
    if inst:HasTag("swc2hm") then return end
    inst:ListenForEvent("deactivate", function(inst)
        onfar(inst)
    end)
end)

-- 冰鲨战败投降添加检测
AddPrefabPostInit("sharkboi", function(inst)
    if not TheWorld.ismastersim then return end
    inst.defeated = false
    local MakeTrader = inst.MakeTrader
    inst.MakeTrader = function(inst, ...)
        inst.defeated = true
        MakeTrader(inst, ...)
    end
    local OnLoad = inst.OnLoad
    inst.OnLoad = function(inst, ...)
        OnLoad(inst, ...)
        if inst.components.health.currenthealth <= inst.components.health.minhealth then inst.defeated = true end
    end
    local OnEntitySleep = inst.OnEntitySleep
    inst.OnEntitySleep = function(inst, ...)
        OnEntitySleep(inst, ...)
        if inst.components.health.currenthealth <= inst.components.health.minhealth then inst.defeated = true end
    end
end)

-- 犀牛分身本体别再相互检测影响索敌了
local tags = {"nightmarecreature", "minotaur", "shadowcreature", "minotaur_organ"}
AddPrefabPostInit("minotaur", function(inst)
    if not TheWorld.ismastersim then return end
    -- 禁止攻击仇恨影怪
    if inst.components.combat then
        local oldCanHitTarget = inst.components.combat.CanHitTarget
        inst.components.combat.CanHitTarget = function(self, target, ...)
            return target and oldCanHitTarget(self, target, ...) and not target:HasTag("nightmarecreature")
        end
        local oldIsValidTarget = inst.components.combat.IsValidTarget
        inst.components.combat.IsValidTarget = function(self, target, ...)
            return target and oldIsValidTarget(self, target, ...) and not target:HasTag("nightmarecreature")
        end
    end

    local RETARGET_CANT_TAGS = UpvalueHacker.GetUpvalue(inst.components.combat.targetfn, "RETARGET_CANT_TAGS")
    if RETARGET_CANT_TAGS ~= nil then
        for i, v in pairs(tags) do
            table.insert(RETARGET_CANT_TAGS, v)
        end
    end
    -- 2025.10.15 melon:永不妥协补丁中去掉了犀牛影子的minotaur标签,增加minotaur2hm标签
    -- if TUNING.DSTU and RETARGET_CANT_TAGS ~= nil then table.insert(RETARGET_CANT_TAGS, "minotaur2hm") end
end)

-- 天体英雄分身本体别再相互检测影响索敌了
local alterguardians = {"alterguardian_phase1", "alterguardian_phase2", "alterguardian_phase3"}
for i, v in pairs(alterguardians) do
    AddPrefabPostInit(v, function(inst)
        if not TheWorld.ismastersim then return end
        local RETARGET_CANT_TAGS = UpvalueHacker.GetUpvalue(inst.components.combat.targetfn, "RETARGET_CANT_TAGS")
        if RETARGET_CANT_TAGS ~= nil then table.insert(RETARGET_CANT_TAGS, "brightmareboss") end
    end)
end

-- 毒菌蟾蜍分身本体别再相互检测影响索敌了
local toadstools = {"toadstool", "toadstool_dark"}
for i, v in pairs(toadstools) do
    AddPrefabPostInit(v, function(inst)
        if not TheWorld.ismastersim then return end
        local RETARGET_CANT_TAGS = UpvalueHacker.GetUpvalue(inst.components.combat.targetfn, "RETARGET_CANT_TAGS")
        if RETARGET_CANT_TAGS ~= nil then table.insert(RETARGET_CANT_TAGS, "toadstool") end
    end)
end

-- 妥协石头蟹暗影化且巨石无掉落
if TUNING.DSTU then
    AddPrefabPostInit("boulder_crab", function(inst)
        if not TheWorld.ismastersim then return end
        inst:DoTaskInTime(2 * FRAMES, function()
            if inst.myrock and inst:HasTag("swc2hm") then
                inst.myrock.AnimState:SetMultColour(0, 0, 0, 0.5)
                if inst.myrock.components.lootdropper then
                    inst.myrock.components.lootdropper:SetLoot()
                    inst.myrock.components.lootdropper:SetChanceLootTable()
                    inst.myrock.components.lootdropper.SpawnLootPrefab = nillootdropperSpawnLootPrefab
                    inst.myrock.components.lootdropper.GenerateLoot = emptytablefn
                    inst.myrock.components.lootdropper.DropLoot = emptytablefn
                end
            end
        end)
    end)
end

AddPrefabPostInit("beefalo", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.combat and inst.components.combat.AddNoAggroTag then
        inst.components.combat:AddNoAggroTag("nightmarecreature")
    end
end)
