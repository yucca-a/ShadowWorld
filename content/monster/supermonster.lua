local chance_range = GetModConfigData("rangesupermonster")
local chance_special = GetModConfigData("specialsupermonster")
local function cansuper(inst)
    return not (inst:HasTag("player") or inst:HasTag("shadow") or inst:HasTag("companion") or inst:HasTag("shadowminion") or inst:HasTag("shadowcreature") or
               inst:HasTag("nightmarecreature") or inst:HasTag("shadowchesspiece") or inst:HasTag("abigail")) and inst.components.health and
               inst.components.health.maxhealth > 1 and
               (not (inst:HasTag("epic") or inst:HasTag("shadowchesspiece") or inst:HasTag("crabking")) or inst.components.health.maxhealth < 3500) and
               inst.components.combat and inst.components.combat.defaultdamage > 0 and inst.AnimState
end

local function OnRedHitOther(inst, data)
    if data and data.target ~= nil and data.target:IsValid() and data.target.components.burnable ~= nil and
        not (inst.components.rideable and inst.components.rideable:IsBeingRidden()) then data.target.components.burnable:Ignite(nil, inst) end
end

local function bluetaskcooldown(inst) inst._bluecdtask2hm = nil end
local function OnBlueHitOther(inst, data)
    if data and data.target ~= nil and data.target:IsValid() and data.target.components.freezable ~= nil and inst._bluecdtask2hm == nil and
        not (inst.components.rideable and inst.components.rideable:IsBeingRidden()) then
        inst._bluecdtask2hm = inst:DoTaskInTime(12, bluetaskcooldown)
        data.target.components.freezable:AddColdness(4)
        data.target.components.freezable:SpawnShatterFX()
    end
end

local function EndSpeedMult(target)
    target.purplereducespeedtask2hm = nil
    target.purplereducespeedfx2hm:KillFX()
    target.purplereducespeedfx2hm = nil
    if target.components.locomotor ~= nil then target.components.locomotor:RemoveExternalSpeedMultiplier(target, "purplereducespeedtask2hm") end
end
local function OnPurpleHitOther(inst, data)
    if data and data.target ~= nil and data.target:IsValid() and data.target.components.locomotor ~= nil and data.target.entity and
        not (inst.components.rideable and inst.components.rideable:IsBeingRidden()) then
        if data.target.purplereducespeedtask2hm then
            data.target.purplereducespeedtask2hm:Cancel()
        else
            data.target.purplereducespeedfx2hm = SpawnPrefab("shadow_trap_debuff_fx")
            data.target.purplereducespeedfx2hm.entity:SetParent(data.target.entity)
            data.target.purplereducespeedfx2hm:OnSetTarget(data.target)
        end
        data.target.purplereducespeedtask2hm = data.target:DoTaskInTime(12, EndSpeedMult)
        data.target.components.locomotor:SetExternalSpeedMultiplier(data.target, "purplereducespeedtask2hm", 0.5)
    end
end

local function taser_cooldown(inst) inst._cdtask2hm = nil end
local function OnYellowHitOther(inst, data)
    if (data ~= nil and data.target ~= nil and not data.redirected) and inst._cdtask2hm == nil and
        not (inst.components.rideable and inst.components.rideable:IsBeingRidden()) then
        inst._cdtask2hm = inst:DoTaskInTime(0.3, taser_cooldown)
        if data.target.components.combat ~= nil and (data.target.components.health ~= nil and not data.target.components.health:IsDead()) and
            (data.target.components.inventory == nil or not data.target.components.inventory:IsInsulated()) and
            (data.weapon == nil or
                (data.weapon.components.projectile == nil and (data.weapon.components.weapon == nil or data.weapon.components.weapon.projectile == nil))) then
            SpawnPrefab("electrichitsparks"):AlignToTarget(data.target, inst, true)
            local damage_mult = 1
            if not (data.target:HasTag("electricdamageimmune") or (data.target.components.inventory ~= nil and data.target.components.inventory:IsInsulated())) then
                damage_mult = TUNING.ELECTRIC_DAMAGE_MULT
                local wetness_mult = (data.target.components.moisture ~= nil and data.target.components.moisture:GetMoisturePercent()) or
                                         (data.target:GetIsWet() and 1) or 0
                damage_mult = damage_mult + wetness_mult
            end
            data.target.components.combat:GetAttacked_Internal(inst, damage_mult * TUNING.WX78_TASERDAMAGE, nil, "electric")
        elseif data.target.components.inventory and data.target.components.inventory.equipslots then
            for _, v in pairs(data.target.components.inventory.equipslots) do
                if v and v.components.equippable:IsInsulated() then
                    if v.components.fueled then v.components.fueled:DoDelta(-60, inst) end
                    if v.components.finiteuses then v.components.finiteuses:Use(1) end
                    if v.components.armor then v.components.armor:TakeDamage(10) end
                    break
                end
            end
        end
    end
end

local function orangetaskcooldown(inst) inst._orangecdtask2hm = nil end
local function OnOrangeHitOther(inst, data)
    if data and data.target ~= nil and data.target:IsValid() and inst._orangecdtask2hm == nil and
        not (inst.components.rideable and inst.components.rideable:IsBeingRidden()) then
        inst._orangecdtask2hm = inst:DoTaskInTime(0.3, orangetaskcooldown)
        data.target:PushEvent("knockback", {
            knocker = inst,
            radius = 3,
            strengthmult = (data.target.components.inventory ~= nil and data.target.components.inventory:ArmorHasTag("heavyarmor") or
                data.target:HasTag("heavybody")) and 0.35 or 0.7,
            forcelanded = false
        })
    end
end

local function dropandhit(inst)
    if inst.components.inventoryitem then
        local owner = inst.components.inventoryitem:GetGrandOwner()
        if owner and owner:IsValid() then
            local container = owner.components.inventory or owner.components.container
            if container then
                local pos = owner:GetPosition()
                if container.DropOverstackedExcess then
                    container:DropOverstackedExcess(inst)
                else
                    container:DropItem(inst, true, true, pos)
                end
                if not (inst.components.follower and inst.components.follower.leader == owner) then
                    owner:PushEvent("attacked", {attacker = inst, damage = 0})
                end
            end
        end
    end
end
local function dropandhitdelay(inst)
    -- inst:DoTaskInTime(0, dropandhit)
    inst:DoTaskInTime(0.3, dropandhit)
end

local function onnearrangemonster(inst)
    if inst.followfx2hm or inst:IsAsleep() or inst:IsInLimbo() then return end
    if inst.components.health and inst.components.health:IsDead() then return end
    local fx = SpawnPrefab(inst.rangeweapondata2hm.fx or "lighterfire_haunteddoll")
    if fx ~= nil then
        fx:AddTag("bluecolour2hm")
        fx.entity:SetParent(inst.entity)
        if inst.fxfollow2hm then
            fx.entity:AddFollower():FollowSymbol(inst.GUID, inst.fxfollow2hm, inst.fxfollowoffset2hm.x, inst.fxfollowoffset2hm.y, inst.fxfollowoffset2hm.z)
        else
            inst:AddChild(fx)
        end
        if fx.AttachLightTo then fx:AttachLightTo(inst) end
        inst.followfx2hm = fx
    end
end
local function onfarrangemonster(inst)
    if inst.followfx2hm then
        inst.followfx2hm:Remove()
        inst.followfx2hm = nil
    end
end

local function invisiblehide(inst)
    if not inst:IsValid() then return end
    if not inst.invisiblehide2hm then
        SpawnPrefab("crab_king_shine").Transform:SetPosition(inst.Transform:GetWorldPosition())
        inst:Hide()
        if inst.DynamicShadow then inst.DynamicShadow:Enable(false) end
        inst.invisiblehide2hm = true
    end
    if inst.delayhidetask2hm then
        inst.delayhidetask2hm:Cancel()
        inst.delayhidetask2hm = nil
    end
end
local function invisibledelayhide(inst, delay)
    if inst.delayhidetask2hm then inst.delayhidetask2hm:Cancel() end
    inst.delayhidetask2hm = inst:DoTaskInTime(delay, invisiblehide)
end
local function invisibleshow(inst)
    if inst.invisiblehide2hm then
        inst:Show()
        if inst.DynamicShadow then inst.DynamicShadow:Enable(true) end
        inst.invisiblehide2hm = nil
    end
    if inst.delayhidetask2hm then
        inst.delayhidetask2hm:Cancel()
        inst.delayhidetask2hm = nil
    end
    if inst.delayshowtask2hm then
        inst.delayshowtask2hm:Cancel()
        inst.delayshowtask2hm = nil
    end
end
local function invisibledelayshow(inst, delay)
    if inst.delayshowtask2hm then inst.delayshowtask2hm:Cancel() end
    inst.delayshowtask2hm = inst:DoTaskInTime(delay, invisibleshow)
end
-- 预备攻击别人时会隐形至多7秒
local function OninvisibleCombatTarget(inst, data)
    if not inst.invisiblehide2hm and not (data and data.oldtarget) then
        invisibledelayhide(inst, 0.75)
        invisibledelayshow(inst, 3.75)
    end
end
-- 隐身时攻击别人会立即显形,3秒后隐身
local function OninvisibleAttackOther(inst)
    invisibleshow(inst)
    invisibledelayhide(inst, 3)
    invisibledelayshow(inst, 6)
end
-- 显形时被攻击会立即隐形;但有的攻击是被反击,此类不能隐形
local function OninvisibleAttacked(inst)
    if not inst.attackedhidetask2hm then
        inst.attackedhidetask2hm = inst:DoTaskInTime(3, function() inst.attackedhidetask2hm = nil end)
        invisibledelayhide(inst, 0.15)
        invisibledelayshow(inst, 3.15)
    end
end

local function showtransitionfx(inst)
    local fx = SpawnPrefab("ghostlyelixir_speed_dripfx")
    fx.Transform:SetScale(.5, .5, .5)
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
end
local function greenhealthregentask(inst, src)
    if inst.components.health and not inst.components.health:IsDead() then
        inst.components.health:DoDelta(-math.clamp(inst.components.health.maxhealth / 100, 1, 10), nil, src)
        showtransitionfx(inst)
    end
    inst.greenhealthregentask2hmindex = (inst.greenhealthregentask2hmindex or 0) + 1
    if inst.greenhealthregentask2hmindex >= 10 and inst.greenhealthregentask2hm then
        inst.greenhealthregentask2hm:Cancel()
        inst.greenhealthregentask2hm = nil
        inst.greenhealthregentask2hmindex = nil
    end
end
local function ongreenhitother(inst, data)
    if data and data.target and data.target.components.health then
        data.target.greenhealthregentask2hmindex = 0
        if data.target.greenhealthregentask2hm == nil then
            data.target.greenhealthregentask2hm = data.target:DoPeriodicTask(1, greenhealthregentask, 0.25, inst.nameoverride or inst.prefab or "NIL")
        end
    end
end
local function ongreendeath(inst) SpawnPrefab("sporecloud").Transform:SetPosition(inst.Transform:GetWorldPosition()) end

local function testsupermonkey(inst)
    if inst.has_nightmare_state then inst.has_nightmare_state = false end
    -- 精英猴子不会变身
    if inst.prefab == "monkey" then
        SetOnSave(inst, function(inst, data) data.nightmare = nil end)
        if inst.components.timer then inst.components.timer:StartTimer("forcenightmare", 1000, true) end
        if inst:HasTag("nightmare") then
            inst.AnimState:SetBuild("kiki_basic")
            inst.soundtype = ""
            inst.AnimState:SetMultColour(1, 1, 1, 1)
        end
    end
end
local onattackproj = {
    fire_projectile = {fn = function(inst, attacker, target, skipsanity)
        if attacker and attacker:IsValid() and attacker.SoundEmitter then attacker.SoundEmitter:PlaySound(inst.skin_sound or "dontstarve/wilson/fireball_explo") end

        if not target:IsValid() then
            -- target killed or removed in combat damage phase
            return
        elseif target.components.burnable ~= nil and not target.components.burnable:IsBurning() then
            if target.components.freezable ~= nil and target.components.freezable:IsFrozen() then
                target.components.freezable:Unfreeze()
            elseif target.components.fueled == nil or
                (target.components.fueled.fueltype ~= FUELTYPE.BURNABLE and target.components.fueled.secondaryfueltype ~= FUELTYPE.BURNABLE) then
                -- does not take burnable fuel, so just burn it
                if target.components.burnable.canlight or target.components.combat ~= nil then
                    target.components.burnable:Ignite(true, attacker and attacker:IsValid() and attacker or inst)
                end
            elseif target.components.fueled.accepting then
                -- takes burnable fuel, so fuel it
                local fuel = SpawnPrefab("cutgrass")
                if fuel ~= nil then
                    if fuel.components.fuel ~= nil and fuel.components.fuel.fueltype == FUELTYPE.BURNABLE then
                        target.components.fueled:TakeFuelItem(fuel)
                    else
                        fuel:Remove()
                    end
                end
            end
        end

        if target.components.freezable ~= nil then
            target.components.freezable:AddColdness(-1) -- Does this break ice staff?
            if target.components.freezable:IsFrozen() then target.components.freezable:Unfreeze() end
        end

        if target.components.sleeper ~= nil and target.components.sleeper:IsAsleep() then target.components.sleeper:WakeUp() end

        -- if target.components.combat ~= nil then
        --     target.components.combat:SuggestTarget(attacker)
        -- end

        -- target:PushEvent("attacked", {attacker = attacker, damage = 0, weapon = inst})
    end},

    ice_projectile = {fn = function(inst, attacker, target, skipsanity)
        if inst.skin_sound and attacker.SoundEmitter then attacker.SoundEmitter:PlaySound(inst.skin_sound) end

        if not target:IsValid() then
            -- target killed or removed in combat damage phase
            return
        end

        if target.components.sleeper ~= nil and target.components.sleeper:IsAsleep() then target.components.sleeper:WakeUp() end

        if target.components.burnable ~= nil then
            if target.components.burnable:IsBurning() then
                target.components.burnable:Extinguish()
            elseif target.components.burnable:IsSmoldering() then
                target.components.burnable:SmotherSmolder()
            end
        end

        -- if target.components.combat ~= nil then
        --     target.components.combat:SuggestTarget(attacker)
        -- end

        -- if target.sg ~= nil and not target.sg:HasStateTag("frozen") then
        --     target:PushEvent("attacked", {attacker = attacker, damage = 0, weapon = inst})
        -- end

        if target.components.freezable ~= nil then
            target.components.freezable:AddColdness(target:HasTag("player") and 1 or 0.5)
            target.components.freezable:SpawnShatterFX()
        end
    end},

    blowdart_yellow = {fn = function(inst, attacker, target)
        -- target could be killed or removed in combat damage phase
        if target:IsValid() then SpawnPrefab("electrichitsparks"):AlignToTarget(target, inst) end
    end},

    blowdart_sleep = {fn = function(inst, attacker, target)
        if not target:IsValid() then
            -- target killed or removed in combat damage phase
            return
        end

        if target.SoundEmitter ~= nil then target.SoundEmitter:PlaySound("dontstarve/wilson/blowdart_impact_sleep") end

        local mount = target.components.rider ~= nil and target.components.rider:GetMount() or nil
        if mount ~= nil then mount:PushEvent("ridersleep", {sleepiness = 4, sleeptime = 6}) end
        if target.components.sleeper ~= nil then
            target.components.sleeper:AddSleepiness(1, 6, inst)
        elseif target.components.grogginess ~= nil then
            target.components.grogginess:AddGrogginess(1, 6)
        end
        -- if target.components.combat ~= nil and not target:HasTag("player") then
        --     target.components.combat:SuggestTarget(attacker)
        -- end
        -- target:PushEvent("attacked", {attacker = attacker, damage = 0, weapon = inst})
    end},

    blowdart_fire = {fn = function(inst, attacker, target)
        if not target:IsValid() then
            -- target killed or removed in combat damage phase
            return
        end

        if target.SoundEmitter ~= nil then target.SoundEmitter:PlaySound("dontstarve/wilson/blowdart_impact_fire") end

        -- target:PushEvent("attacked", {attacker = attacker, damage = 0})
        if target.components.burnable then target.components.burnable:Ignite(nil, attacker) end
        if target.components.freezable then target.components.freezable:Unfreeze() end
        if target.components.health then target.components.health:DoFireDamage(0, attacker) end
        -- if target.components.combat then
        --     target.components.combat:SuggestTarget(attacker)
        -- end
    end},
}
local ammos = {require "prefabs/slingshotammo"} 
local rangelimitprefabs = {"sporehound", "knook"}
local redskilltreeupdater = {IsActivated = falsefn, CountSkillTag = falsefn}
local superabilities = {
    red = function(inst)
        inst:AddTag("controlled_burner")
        inst.components.skilltreeupdater = redskilltreeupdater
        SetAnimstateColor2hm(inst, "red")
        inst:ListenForEvent("onhitother", OnRedHitOther)
    end,
    blue = function(inst)
        SetAnimstateColor2hm(inst, "blue")
        inst:ListenForEvent("onhitother", OnBlueHitOther)
    end,
    green = function(inst)
        SetAnimstateColor2hm(inst, "green")
        inst:ListenForEvent("death", ongreendeath)
        inst:ListenForEvent("onhitother", ongreenhitother)
    end,
    yellow = function(inst)
        SetAnimstateColor2hm(inst, "yellow")
        inst:ListenForEvent("onhitother", OnYellowHitOther)
    end,
    orange = function(inst)
        SetAnimstateColor2hm(inst, "orange")
        inst:ListenForEvent("onhitother", OnOrangeHitOther)
        if inst.components.combat then inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, 0.33, "iridescent2hm") end
    end,
    purple = function(inst)
        SetAnimstateColor2hm(inst, "purple")
        inst:ListenForEvent("onhitother", OnPurpleHitOther)
    end,
    iridescent = function(inst)
        inst:ListenForEvent("newcombattarget", OninvisibleCombatTarget)
        inst:ListenForEvent("doattack", OninvisibleAttackOther)
        -- inst:ListenForEvent("blocked", OninvisibleAttacked)
        inst:ListenForEvent("attacked", OninvisibleAttacked)
        inst:ListenForEvent("death", invisibleshow)
        if inst.components.combat then inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, 0.75, "iridescent2hm") end
        if inst.components.locomotor then inst.components.locomotor:SetExternalSpeedMultiplier(inst, "iridescent2hm", 1.5) end
    end,
    rangeweapon = function(inst, weapondata)
        if not inst.components.combat then return end
        inst.rangeweapondata2hm = weapondata
        inst.components.combat.GetWeapon = function(self, ...)
            if not (inst.superweapon2hm and inst.superweapon2hm:IsValid()) then
                local weapon = CreateEntity()
                weapon.persists = false
                weapon.entity:AddTransform()
                weapon.entity:SetParent(inst.entity)
                weapon:RemoveFromScene()
                weapon:AddComponent("inventoryitem")
                weapon.components.inventoryitem.owner = inst
                weapon:AddComponent("weapon")
                weapon.projectilemissremove2hm = true
                weapon.projectileneedstartpos2hm = true
                weapon.projectilehasdamageset2hm = 0.5
                weapon.projectilespeed2hm = weapondata.speed or 20
                weapon.projectilehoming2hm = false
                weapon.projectilephysics2hm = false
                weapon.projectilesize2hm = weapondata.size
				weapon.components.weapon:SetProjectile(weapondata.proj)
				if weapondata.onattack and onattackproj[weapondata.proj] then
                    weapon.components.weapon:SetOnAttack(onattackproj[weapondata.proj].fn)
                end
                if weapondata.electric then weapon.components.weapon:SetElectric() end
                weapon.components.weapon:SetDamage(math.max(inst.weaponitems and inst.components.combat.defaultdamage * 3 / 2 or
                                                                inst.components.combat.defaultdamage * 2 / 3, 10))
                if table.contains(rangelimitprefabs, inst.prefab) then
                    weapon.components.weapon:SetRange(inst.components.combat.attackrange, inst.components.combat.hitrange)
                else
                    weapon.components.weapon:SetRange(weapondata.attackrange or inst.components.combat.attackrange,
                                                      weapondata.hitrange or inst.components.combat.hitrange)
                end
                if inst.prefab == "monkey" and inst.HasAmmo then inst.HasAmmo = truefn end
                if inst.weaponitems then for key, value in pairs(inst.weaponitems) do inst.weaponitems[key] = weapon end end
                inst.superweapon2hm = weapon
            end
            return inst.superweapon2hm
        end
        local fxfollow = inst.components.combat.hiteffectsymbol
        local offset = Vector3(0, 0, 0)
        if fxfollow == "marker" then
            if inst.components.burnable and inst.components.burnable.fxdata and inst.components.burnable.fxdata[1] and inst.components.burnable.fxdata[1].follow ~=
                nil then
                fxfollow = inst.components.burnable.fxdata[1].follow
                offset = Vector3(inst.components.burnable.fxdata[1].x, inst.components.burnable.fxdata[1].y, inst.components.burnable.fxdata[1].z)
            elseif inst.components.freezable and inst.components.freezable.fxdata and inst.components.freezable.fxdata[1] and
                inst.components.freezable.fxdata[1].follow ~= nil then
                fxfollow = inst.components.freezable.fxdata[1].follow
                offset = Vector3(inst.components.freezable.fxdata[1].x, inst.components.freezable.fxdata[1].y, inst.components.freezable.fxdata[1].z)
            else
                fxfollow = nil
            end
        end
        inst.fxfollow2hm = fxfollow
        inst.fxfollowoffset2hm = offset
        -- 无法放入物品栏
        if inst.prefab ~= "slurper" then
            dropandhitdelay(inst)
            inst:ListenForEvent("onputininventory", dropandhitdelay)
            inst:ListenForEvent("onpickup", dropandhitdelay)
        end
        -- 远程特效
        inst:DoTaskInTime(0, onnearrangemonster)
        inst:ListenForEvent("entitywake", onnearrangemonster)
        inst:ListenForEvent("exitlimbo", onnearrangemonster)
        -- 移除特效
        inst:ListenForEvent("entitysleep", onfarrangemonster)
        inst:ListenForEvent("enterlimbo", onfarrangemonster)
        inst:ListenForEvent("death", onfarrangemonster)
        inst:ListenForEvent("onremove", onfarrangemonster)
        -- 无法被捕捉
        if inst.components.workable and inst.components.workable.action == ACTIONS.NET then inst.components.workable.action = nil end
    end
}

local function updatecolour(inst) if inst:HasTag("bluecolour2hm") and inst._light and inst._light.Light then inst._light.Light:SetColour(0, 183 / 255, 1) end end
AddPrefabPostInit("lighterfire_haunteddoll", function(inst) if not TheWorld.ismastersim then inst:DoTaskInTime(0, updatecolour) end end)

local superkey = {"red", "blue", "green", "yellow", "orange", "purple", "iridescent"}
local totalsuperkey = #superkey
-- 新处理aoe伤害函数 怪物aoe子弹只对玩家造成伤害
local SpDamageUtil = require("components/spdamageutil")
local AOE_TARGET_MUST_TAGS  = { "_combat", "_health"}
local AOE_TARGET_CANT_TAGS  = { "INLIMBO", "notarget", "noattack", "flight", "invisible", "playerghost", "companion", "wall" }
local AOE_TARGET_CANT_TAGS_PVP = { "INLIMBO", "notarget", "noattack", "flight", "invisible", "playerghost" }
local function newDoAOEDamage(inst, attacker, target, damage, radius)
    local combat = attacker ~= nil and attacker.components.combat or nil
	
    if combat == nil or not target:IsValid() then
        return
    end

	local x, y, z = target.Transform:GetWorldPosition()

    local _ignorehitrange = combat.ignorehitrange

    combat.ignorehitrange = true
    for i, v in ipairs(TheSim:FindEntities(x, y, z, radius + (not attacker:HasTag("player") and 3 or 0), AOE_TARGET_MUST_TAGS, TheNet:GetPVPEnabled() and AOE_TARGET_CANT_TAGS_PVP or AOE_TARGET_CANT_TAGS)) do
        if v ~= target and 
			 v.prefab ~= attacker.prefab and not -- 检测远程精英aoe伤害范围内是否有同类
			((v:HasTag("merm") and attacker:HasTag("merm")) or -- 排除鱼人
			(v:HasTag("pig") and attacker:HasTag("pig")) or -- 排除猪人
			(v:HasTag("beefalo") and attacker:HasTag("beefalo")) or -- 排除牛牛
			((v:HasTag("spider") or v:HasTag("spiderden")) and attacker:HasTag("spider")) or -- 排除蜘蛛
			((v:HasTag("bee") or v:HasTag("beehive")) and attacker:HasTag("bee")) or -- 排除蜜蜂
			((v:HasTag("otter") or v:HasTag("wet")) and attacker:HasTag("otter")) or -- 排除兄弟
			(v:HasTag("chess") and attacker:HasTag("chess")) or -- 排除发条
			((v:HasTag("hound") or v:HasTag("houndmound")) and attacker:HasTag("hound")) or  -- 排除猎犬
			(v:HasTag("koalefant") and attacker:HasTag("koalefant")) or  -- 排除考拉象
			(v:HasTag("explosive") and attacker:HasTag("explosive")) or -- 排除蜗牛
			(v:HasTag("pirate") and attacker:HasTag("pirate")) or -- 排除海盗猴
			(v:HasTag("crabking_ally") and attacker:HasTag("crabking_ally")) or -- 排除帝王蟹护卫
			(v:HasTag("walrus") and attacker:HasTag("walrus")) or -- 海象父子
			(v:HasTag("frog") and attacker:HasTag("frog")) or -- 妥协青蛙
			(v:HasTag("lightninggoat") and attacker:HasTag("lightninggoat")) or  -- 妥协伏特羊
			(v:HasTag("worm") and attacker:HasTag("worm")) or -- 妥协蠕虫
			(v:HasTag("bat") and attacker:HasTag("bat")) or -- 妥协蝙蝠
			(attacker.components.follower and attacker.components.follower.leader and attacker.components.follower.leader == v) or -- 排除随从对领导者的伤害
			(v.components.follower and v.components.follower.leader and v.components.follower.leader == attacker) or -- 排除领导者对随从的伤害
			(attacker:HasTag("player") and v.components.follower and v.components.follower.leader and v.components.follower.leader:HasTag("player")) or -- 排除玩家对玩家随从的伤害
			(attacker.components.follower and attacker.components.follower.leader and attacker.components.follower.leader:HasTag("player") and v:HasTag("player"))) and -- 排除玩家雇佣生物aoe伤害对玩家群体的伤害 
            combat:CanTarget(v) and
            v.components.combat:CanBeAttacked(attacker) and
            not combat:IsAlly(v)
        then
            local range = radius + (not attacker:HasTag("player") and 3 or 0) + v:GetPhysicsRadius(0) + 1

            if v:GetDistanceSqToPoint(x, y, z) < range * range then
                local spdmg = SpDamageUtil.CollectSpDamage(inst)

                v.components.combat:GetAttacked_Internal(attacker, damage, inst, inst.components.projectile and inst.components.projectile.stimuli, spdmg)
            end
        end
    end

    combat.ignorehitrange = _ignorehitrange
end

local function SetSpeed_Slow(target, fx, numstacks)
	local mult = TUNING.SLINGSHOT_AMMO_MOVESPEED_MULT ^ numstacks
	if target._slingshot_gelblob then
		mult = math.min(1, mult / TUNING.CAREFUL_SPEED_MOD)
	end
	target.components.locomotor:SetExternalSpeedMultiplier(target, "slingshotammo_slow", mult)
	fx:SetFXLevel(numstacks)
end

local function OnGelblobChanged_Slow(target)
	local data = target._slingshot_slow
	if data and #data.tasks > 0 then
		SetSpeed_Slow(target, data.fx, #data.tasks)
	end
end
local function TrySpawnGelBlob(target)
	local x, y, z = target.Transform:GetWorldPosition()
	if TheWorld.Map:IsPassableAtPoint(x, 0, z) then
		local blob = SpawnPrefab("gelblob_small_fx")
		blob.Transform:SetPosition(x, 0, z)
		blob:SetLifespan(TUNING.SLINGSHOT_AMMO_GELBLOB_DURATION)
		blob:ReleaseFromAmmoAfflicted()
		return blob
	elseif TheWorld.has_ocean then
		SpawnPrefab("ocean_splash_ripple"..tostring(math.random(2))).Transform:SetPosition(x, 0, z)
	end
end

local function OnRemoveTarget_GelBlob(target)
	if target._slingshot_gelblob.blob and target._slingshot_gelblob.blob:IsValid() then
		target._slingshot_gelblob.blob:KillFX()
		target._slingshot_gelblob.blob = nil
	end
end

local function OnUpdate_GelBlob(target)
	local data = target._slingshot_gelblob
	local elapsed = GetTime() - data.t0
	if not target:HasTag("player") and elapsed < TUNING.SLINGSHOT_AMMO_GELBLOB_DURATION then
		if data.blob then
			if not data.blob:IsValid() then
				data.blob = nil
				data.wasafflicted = false
			elseif data.start or (data.wasafflicted and data.blob._targets[target] == nil) then
				data.blob:KillFX(true)
				data.blob = nil
				data.wasafflicted = false
			end
		end
		if data.blob == nil then
			data.blob = TrySpawnGelBlob(target)
		end
		if not data.wasafflicted and data.blob and data.blob._targets[target] then
			data.wasafflicted = true
		end
		data.start = nil
	elseif target:HasTag("player") and elapsed < 5 then
		if data.blob then
			if not data.blob:IsValid() then
				data.blob = nil
				data.wasafflicted = false
			elseif data.start or (data.wasafflicted and data.blob._targets[target] == nil) then
				data.blob:KillFX(true)
				data.blob = nil
				data.wasafflicted = false
			end
		end
		if data.blob == nil then
			data.blob = TrySpawnGelBlob(target)
		end
		if not data.wasafflicted and data.blob and data.blob._targets[target] then
			data.wasafflicted = true
		end
		data.start = nil
	else
		if data.blob then
			data.blob:KillFX(true)
			data.blob = nil
		end
		data.task:Cancel()
		target._slingshot_gelblob = nil
		target:RemoveTag("gelblob_ammo_afflicted")
		target:RemoveEventCallback("onremove", OnRemoveTarget_GelBlob)

		--NOTE: no stacking with Slow ammo
		OnGelblobChanged_Slow(target)

		target:PushEvent("stop_gelblob_ammo_afflicted")
	end
end

-- 恶液弹
local UpvalueHacker = require("upvaluehacker2hm")
AddPrefabPostInit("slingshotammo_gelblob_proj", function(inst)
	if inst.ammo_def.onhit then
        local oldOnUpdate_GelBlob = UpvalueHacker.GetUpvalue(inst.ammo_def.onhit, "OnUpdate_GelBlob")
        if oldOnUpdate_GelBlob then UpvalueHacker.SetUpvalue(inst.ammo_def.onhit, OnUpdate_GelBlob ,"OnUpdate_GelBlob") end
        local oldOnRemoveTarget_GelBlob = UpvalueHacker.GetUpvalue(inst.ammo_def.onhit, "OnRemoveTarget_GelBlob")
        if oldOnRemoveTarget_GelBlob then UpvalueHacker.SetUpvalue(inst.ammo_def.onhit, OnRemoveTarget_GelBlob ,"OnRemoveTarget_GelBlob") end
    end
end)
-- 火药弹
AddPrefabPostInit("slingshotammo_gunpowder_proj", function(inst)
	if not TheWorld.ismastersim then return end
	if inst.ammo_def.onhit then
        local oldDoAOEDamage = UpvalueHacker.GetUpvalue(inst.ammo_def.onhit, "DoAOEDamage")
        if oldDoAOEDamage then UpvalueHacker.SetUpvalue(inst.ammo_def.onhit, newDoAOEDamage ,"DoAOEDamage") end
    end
end)
-- 蜂刺弹
local function newOnHit_Stinger(inst, attacker, target)
    newDoAOEDamage(inst, attacker, target, TUNING.SLINGSHOT_AMMO_DAMAGE_STINGER_AOE, TUNING.SLINGSHOT_AMMO_RANGE_STINGER_AOE)
end
-- 月亮弹
local function newOnHit_MoonGlass(inst, attacker, target)
    newDoAOEDamage(inst, attacker, target, TUNING.SLINGSHOT_AMMO_DAMAGE_MOONGLASS_AOE, TUNING.SLINGSHOT_AMMO_RANGE_MOONGLASS_AOE)
end
--添加到预制件中
AddPrefabPostInit("slingshotammo_stinger_proj", function(inst)
	if not TheWorld.ismastersim then return end
	inst.ammo_def.onhit = newOnHit_Stinger
end)

AddPrefabPostInit("slingshotammo_moonglass_proj", function(inst)
	if not TheWorld.ismastersim then return end
	inst.ammo_def.onhit = newOnHit_MoonGlass
end)

local charges = {"bishop_charge", "eye_charge"}
for _, charge in ipairs(charges) do AddPrefabPostInit(charge, function(inst) inst.AnimState:SetDeltaTimeMultiplier(.5) end) end
local rangeweaponkey = {
    bishop_charge = {proj = "bishop_charge", attackrange = TUNING.BISHOP_ATTACK_DIST, hitrange = TUNING.BISHOP_ATTACK_DIST + 4, size = 0.35},
    eye_charge = {proj = "eye_charge", attackrange = TUNING.EYETURRET_RANGE, hitrange = TUNING.EYETURRET_RANGE + 4, size = 0.35},
    -- monkeyprojectile = {
    --     proj = "monkeyprojectile",
    --     attackrange = TUNING.MONKEY_RANGED_RANGE,
    --     hitrange = nil
    -- },
    -- spat_bomb = {
    --     proj = "spat_bomb",
    --     attackrange = TUNING.SPAT_PHLEGM_ATTACKRANGE,
    --     hitrange = nil,
    --     disablesuper = true,
    --     speed = 10
    -- },
    spider_web_spit = {proj = "spider_web_spit", attackrange = TUNING.SPIDER_SPITTER_ATTACK_RANGE, hitrange = TUNING.SPIDER_SPITTER_ATTACK_RANGE + 4},
    fire_projectile = {proj = "fire_projectile", attackrange = 8, hitrange = 10, onattack = true, super = "red"},
    ice_projectile = {proj = "ice_projectile", attackrange = 8, hitrange = 10, onattack = true},
    -- waterplant_projectile = {
    --     proj = "waterplant_projectile",
    --     attackrange = TUNING.BISHOP_ATTACK_DIST,
    --     hitrange = TUNING.BISHOP_ATTACK_DIST + 4
    -- },
    blowdart_walrus = {proj = "blowdart_walrus", attackrange = TUNING.WALRUS_ATTACK_DIST, hitrange = nil},
    blowdart_sleep = {proj = "blowdart_sleep", attackrange = 8, hitrange = 10, onattack = true},
    blowdart_fire = {proj = "blowdart_fire", attackrange = 8, hitrange = 10, super = "red",onattack = true},
    blowdart_pipe = {proj = "blowdart_pipe", attackrange = 8, hitrange = 10},
    blowdart_yellow = {proj = "blowdart_yellow", attackrange = 8, hitrange = 10, electric = true,onattack = true},
    slingshotammo_rock_proj = {
        proj = "slingshotammo_rock_proj",
        attackrange = TUNING.SLINGSHOT_DISTANCE,
        hitrange = TUNING.SLINGSHOT_DISTANCE_MAX,
    },
    slingshotammo_gold_proj = {
        proj = "slingshotammo_gold_proj",
        attackrange = TUNING.SLINGSHOT_DISTANCE,
        hitrange = TUNING.SLINGSHOT_DISTANCE_MAX,
    },
    slingshotammo_marble_proj = {
        proj = "slingshotammo_marble_proj",
        attackrange = TUNING.SLINGSHOT_DISTANCE,
        hitrange = TUNING.SLINGSHOT_DISTANCE_MAX,
    },
    slingshotammo_poop_proj = {
        proj = "slingshotammo_poop_proj",
        attackrange = TUNING.SLINGSHOT_DISTANCE,
        hitrange = TUNING.SLINGSHOT_DISTANCE_MAX,
    },
    slingshotammo_freeze_proj = {
        proj = "slingshotammo_freeze_proj",
        attackrange = TUNING.SLINGSHOT_DISTANCE,
        hitrange = TUNING.SLINGSHOT_DISTANCE_MAX,
    },
    slingshotammo_slow_proj = {
        proj = "slingshotammo_slow_proj",
        attackrange = TUNING.SLINGSHOT_DISTANCE,
        hitrange = TUNING.SLINGSHOT_DISTANCE_MAX,
    },
    slingshotammo_thulecite_proj = {
        proj = "slingshotammo_thulecite_proj",
        attackrange = TUNING.SLINGSHOT_DISTANCE,
        hitrange = TUNING.SLINGSHOT_DISTANCE_MAX,
    },
	slingshotammo_gelblob_proj = {
        proj = "slingshotammo_gelblob_proj",
        attackrange = TUNING.SLINGSHOT_DISTANCE,
        hitrange = TUNING.SLINGSHOT_DISTANCE_MAX,
    },
	slingshotammo_scrapfeather_proj = {
        proj = "slingshotammo_scrapfeather_proj",
        attackrange = TUNING.SLINGSHOT_DISTANCE,
        hitrange = TUNING.SLINGSHOT_DISTANCE_MAX,
		electric = true
    },
	slingshotammo_gunpowder_proj = {
        proj = "slingshotammo_gunpowder_proj",
        attackrange = TUNING.SLINGSHOT_DISTANCE,
        hitrange = TUNING.SLINGSHOT_DISTANCE_MAX,
	},
	slingshotammo_honey_proj = {
        proj = "slingshotammo_honey_proj",
        attackrange = TUNING.SLINGSHOT_DISTANCE,
        hitrange = TUNING.SLINGSHOT_DISTANCE_MAX,
	},
	slingshotammo_stinger_proj =  {
        proj = "slingshotammo_stinger_proj",
        attackrange = TUNING.SLINGSHOT_DISTANCE,
        hitrange = TUNING.SLINGSHOT_DISTANCE_MAX,
	},
	slingshotammo_stinger_proj =  {
        proj = "slingshotammo_moonglass_proj",
        attackrange = TUNING.SLINGSHOT_DISTANCE,
        hitrange = TUNING.SLINGSHOT_DISTANCE_MAX,
	}
    -- -- totest
    -- gestalt_alterguardian_projectile = {
    --     proj = "gestalt_alterguardian_projectile",
    --     attackrange = TUNING.BISHOP_ATTACK_DIST,
    --     hitrange = TUNING.BISHOP_ATTACK_DIST + 4
    -- },
    -- smallguard_alterguardian_projectile = {
    --     proj = "smallguard_alterguardian_projectile",
    --     attackrange = TUNING.BISHOP_ATTACK_DIST,
    --     hitrange = TUNING.BISHOP_ATTACK_DIST + 4
    -- },
    -- largeguard_alterguardian_projectile = {
    --     proj = "largeguard_alterguardian_projectile",
    --     attackrange = TUNING.BISHOP_ATTACK_DIST,
    --     hitrange = TUNING.BISHOP_ATTACK_DIST + 4
    -- },
    -- blowdart_lava_projectile = {
    --     proj = "blowdart_lava_projectile",
    --     attackrange = TUNING.BISHOP_ATTACK_DIST,
    --     hitrange = TUNING.BISHOP_ATTACK_DIST + 4
    -- },
    -- fireball_projectile = {
    --     proj = "fireball_projectile",
    --     attackrange = TUNING.BISHOP_ATTACK_DIST,
    --     hitrange = TUNING.BISHOP_ATTACK_DIST + 4
    -- },
    -- eyeofterror_mini_projectile = {
    --     proj = "eyeofterror_mini_projectile",
    --     attackrange = TUNING.BISHOP_ATTACK_DIST,
    --     hitrange = TUNING.BISHOP_ATTACK_DIST + 4
    -- },
    -- staff_projectile = {
    --     proj = "staff_projectile",
    --     attackrange = TUNING.BISHOP_ATTACK_DIST,
    --     hitrange = TUNING.BISHOP_ATTACK_DIST + 4
    -- },
    -- winona_catapult_projectile = {
    --     proj = "winona_catapult_projectile",
    --     attackrange = TUNING.BISHOP_ATTACK_DIST,
    --     hitrange = TUNING.BISHOP_ATTACK_DIST + 4
    -- }
}

-- 远程精英
local rangeweapons = {}
for k, v in pairs(rangeweaponkey) do table.insert(rangeweapons, v) end
local totalrangeweapons = #rangeweapons
local blacknames_range = {
    "waterplant",
    "ivy_snare",
    "rook",
    "rook_nightmare",
    "winona_catapult",
    "crabking_claw",
    "crabking2hm_claw",
    "sandspike_short",
    "sandspike_med",
    "sandspike_tall",
    "sandblock",
    "gestalt_guard",
    "wagdrone_rolling", -- 2025.6.28 melon:螨地爬
}
local function processrangemonster(inst)
    if inst:HasTag("swc2hm") or inst.components.persistent2hm.data.notrangemonster or
        (inst.components.inventory and inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)) or inst.weapon or inst.weaponitems or
        table.contains(blacknames_range, inst.prefab) then return end
    if not inst.components.persistent2hm.data.rangemonster then
        if type(chance_range) == "number" and not inst:IsInLimbo() and math.random() < chance_range  then
            inst.components.persistent2hm.data.rangemonster = true
        else
            inst.components.persistent2hm.data.notrangemonster = true
            return
        end
    end
	if not inst.components.persistent2hm.data.rangeweapon then
		local weapon = rangeweapons[math.random(#rangeweapons)]
		if weapon then
			inst.components.persistent2hm.data.rangeweapon = {
				proj = weapon.proj,
				attackrange = weapon.attackrange,
				hitrange = weapon.hitrange,
				electric = weapon.electric,
				onattack = weapon.onattack,
				super = weapon.super
			}
		end
	end
    if inst.components.persistent2hm.data.rangeweapon then
        superabilities.rangeweapon(inst, inst.components.persistent2hm.data.rangeweapon)
        testsupermonkey(inst)
        if inst.components.persistent2hm.data.rangeweapon.disablesuper then
            inst.components.persistent2hm.data.notsupermonster = true
        elseif inst.components.persistent2hm.data.rangeweapon.super then
            inst.components.persistent2hm.data.supermonster = true
            inst.components.persistent2hm.data.super = inst.components.persistent2hm.data.rangeweapon.super
        end
    end
    if inst.components.rideable then inst.components.rideable:SetCustomRiderTest(falsefn) end
end
-- 属性精英
local blacknames_super = {"ivy_snare", "winona_catapult", "crabking_claw", "crabking2hm_claw", "gestalt_guard","wagdrone_rolling"}
local function processspecialmonster(inst)
    if inst:HasTag("swc2hm") or inst.components.persistent2hm.data.notsupermonster or table.contains(blacknames_super, inst.prefab) then return end
    if not inst.components.persistent2hm.data.supermonster then
        if type(chance_special) == "number" and not inst:IsInLimbo() and math.random() < chance_special then
            inst.components.persistent2hm.data.supermonster = true
        else
            inst.components.persistent2hm.data.notsupermonster = true
            return
        end
    end
    if not inst.components.persistent2hm.data.super then
        -- if inst.prefab == "deer_red" or inst.prefab == "firehound" then
        --     inst.components.persistent2hm.data.super = "red"
        -- elseif inst.prefab == "deer_blue" or inst.prefab == "icehound" then
        --     inst.components.persistent2hm.data.super = "blue"
        -- else
        inst.components.persistent2hm.data.super = superkey[math.random(totalsuperkey)]
        -- end
    end
    if superabilities[inst.components.persistent2hm.data.super] then
        testsupermonkey(inst)
        superabilities[inst.components.persistent2hm.data.super](inst)
    end
    if inst.components.rideable then inst.components.rideable:SetCustomRiderTest(falsefn) end
end
local function processsupermonster(inst)
    inst.supermonstertask2hm = nil
    if chance_range then processrangemonster(inst) end
    if chance_special then processspecialmonster(inst) end
end

-- 陷阱免疫
local function SetTrapData(inst) return {persistent2hm = inst.components.persistent2hm.data} end
local function RestoreDataFromTrap(inst, data)
    if data ~= nil and data.persistent2hm ~= nil then
        inst.components.persistent2hm.data = data.persistent2hm
        if inst.supermonstertask2hm then
            inst.supermonstertask2hm:Cancel()
            inst.supermonstertask2hm = nil
        end
        inst.supermonstertask2hm = inst:DoTaskInTime(0, processsupermonster)
    end
end

-- 初始化
AddPrefabPostInitAny(function(inst)
    if not TheWorld.ismastersim then return end
    if not cansuper(inst) then return end
    if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
    if inst.components.inventoryitem ~= nil and inst.components.inventoryitem.trappable and not inst.restoredatafromtrap and not inst.settrapdata then
        inst.restoredatafromtrap = RestoreDataFromTrap
        inst.settrapdata = SetTrapData
    end
    inst.supermonstertask2hm = inst:DoTaskInTime(0, processsupermonster)
end)
