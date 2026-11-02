local hardmode = TUNING.hardmode2hm and GetModConfigData("role_nerf") and GetModConfigData("wortox")

-- 沃拓克斯吃食物正常增加三维
if GetModConfigData("Wortox Eat Food Normal") then
    AddPrefabPostInit("wortox", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.eater ~= nil then inst.components.eater:SetAbsorptionModifiers(0.75, 0.75, 0.75) end
    end)
end

-- 沃拓克斯灵魂过多时不再溢出
if GetModConfigData("Wortox Has No Soul Limit") then
    -- 调整小恶魔灵魂的相关参数
    -- 将小恶魔能拥有的最大灵魂数量设置为一个极大值，这里用 math.huge 表示理论上的无上限
    TUNING.WORTOX_MAX_SOULS = 999999
    -- 调整小恶魔关于灵魂数量太少时的俏皮话触发比例，这里根据新的上限重新计算
    TUNING.WORTOX_WISECRACKER_TOOFEW = 4 / 999999
    -- 调整小恶魔关于灵魂数量太多时的俏皮话触发比例，设为 1 表示只要灵魂数量超过某个阈值就可能触发
    TUNING.WORTOX_WISECRACKER_TOOMANY = 1
    -- 对小恶魔灵魂物品（wortox_soul）进行初始化后处理
    AddPrefabPostInit("wortox_soul", function(inst)
		if not TheWorld.ismastersim then return end
        -- 为了确保 stackable 组件已完全初始化，延迟一小段时间后执行设置无限堆叠的操作
        inst:DoTaskInTime(0, function()
			if inst.components.stackable then
				inst.components.stackable:SetIgnoreMaxSize(true)
				inst.components.stackable.SetIgnoreMaxSize = nilfn
			end
            -- 检查物品是否有 inventoryitem 组件
            if inst.components.inventoryitem then
                -- 设置灵魂物品在角色死亡时不丢失
                inst.components.inventoryitem.keepondeath = true
                -- 设置灵魂物品在角色溺水时不丢失
                inst.components.inventoryitem.keepondrown = true
            end
        end)
    end)
	AddPrefabPostInit("wortox_souljar", function(inst) -- 更改灵魂罐堆叠后灵魂罐正常漏魂
		if not TheWorld.ismastersim then return end
		local oldUpdatePercent = inst.UpdatePercent
		inst.UpdatePercent = function(inst)
			oldUpdatePercent(inst)
			local owner = inst.components.inventoryitem and inst.components.inventoryitem.owner or nil
			local shouldleakfrombadowner = owner == nil or owner.components.skilltreeupdater == nil or not owner.components.skilltreeupdater:IsActivated("wortox_souljar_1") 
			if inst.soulcount ~= 0 and shouldleakfrombadowner and not inst.components.container:IsOpen() then
				if inst.leaksoulstask == nil then
					inst.leaksoulstask = inst:DoPeriodicTask(TUNING.SKILLS.WORTOX.SOULJAR_LEAK_TIME, inst.LeakSouls, (math.random() * 0.5 + 0.5) * TUNING.SKILLS.WORTOX.SOULJAR_LEAK_TIME)
				end
			else
				if inst.leaksoulstask ~= nil then
					inst.leaksoulstask:Cancel()
					inst.leaksoulstask = nil
				end
			end
		end
		if inst.components.container and inst.components.container.onopenfn then
			inst.components.container.onopenfn = function(inst)
				inst.components.inventoryitem:ChangeImageName("wortox_souljar_open")
				if not inst.components.inventoryitem:IsHeld() then
					inst.AnimState:PlayAnimation("lidoff")
					inst.AnimState:PushAnimation("lidoff_idle")
					inst.SoundEmitter:PlaySound("meta5/wortox/souljar_open")
					inst:UpdatePercent()
				else
					inst.AnimState:PlayAnimation("lidoff_idle")
				end
			end
		end
	end)
end

-- 沃拓克斯自动获得灵魂
-- 2025.3.16 melon:削弱排箫，增加给魂
local autoreceivesoul = GetModConfigData("Wortox Auto Receive Soul")
if autoreceivesoul then
    -- 吹排箫无仇恨时间
    if hardmode then -- 困难模式削弱
	TUNING.SKILLS.WORTOX.WORTOX_PANFLUTE_FORGET_DURATION = 0
	TUNING.SKILLS.WORTOX.WORTOX_PANFLUTE_INSPIRATION_WAIT = 4 * 480 --削弱免费排箫刷新时间为4天
	end
    
    local function addsoul(inst)
        if not inst:HasTag("playerghost") then
			-- 小恶魔检测物品栏内灵魂数量和容器
            local AllSoulAndContainer = inst.components.inventory:FindItems(function(item) return item:IsValid() and (item.prefab == "wortox_soul" or item.prefab == "wortox_souljar") end)
            local count = 0
            for i, v in pairs(AllSoulAndContainer) do
				if v.prefab == "wortox_soul" then -- 对灵魂数量进行计数
					count = count + (v.components.stackable ~= nil and v.components.stackable:StackSize() or 1) 
				elseif v.prefab == "wortox_souljar" then -- 对灵魂罐灵魂进行计数
					count = count + (v.soulcount or 0)
				end
			end
            if count < 10 then
                local soul = SpawnPrefab("wortox_soul")
                inst.components.inventory:GiveItem(soul)
                inst.SoundEmitter:PlaySound("dontstarve/characters/wortox/soul/spawn", nil, .5)
            end
        end
    end
    AddPrefabPostInit("wortox", function(inst)
        if not TheWorld.ismastersim then return end
        -- 2025.3.16 melon:给魂时间，实际是把排箫削的加到自动给的上了
        inst:DoPeriodicTask(hardmode and 240 or 120, addsoul)
    end)
end -- 2025.3.16 end

-- 沃拓克斯首传免费
if GetModConfigData("Wortox Free Blink") then
    if hardmode then TUNING.WORTOX_FREEHOP_TIMELIMIT = TUNING.WORTOX_FREEHOP_TIMELIMIT * 2 end
	AddStategraphPostInit("wilson", function(sg) -- 重写诱饵释放条件
		if sg.states.portal_jumpin and sg.states.portal_jumpin.timeline and sg.states.portal_jumpin.timeline[3] then
            sg.states.portal_jumpin.timeline[3].fn = function(inst)
                local skilltreeupdater = inst.components.skilltreeupdater
                inst.sg:AddStateTag("noattack")
                inst.components.health:SetInvincible(true)
                inst.DynamicShadow:Enable(false)
                if skilltreeupdater and skilltreeupdater:IsActivated("wortox_souldecoy_1") then
                    if inst._freesoulhop_counterP and inst._freesoulhop_counterP >= (skilltreeupdater and skilltreeupdater:IsActivated("wortox_liftedspirits_3") and 2 or 1) then  -- 消耗灵魂后释放分身
                        inst._freesoulhop_counterP = 0 -- 重置计数器
                        local x, y, z = inst.Transform:GetWorldPosition()
                        local decoy = SpawnPrefab("wortox_decoy")
                        decoy.Transform:SetPosition(x, y, z)
                        decoy:SetOwner(inst) -- The decoy can now be invalid after here.
                    end
                end
            end
        end
	end)
    AddPrefabPostInit("wortox", function(inst)
        if not TheWorld.ismastersim then return end
		if not inst._freesoulhop_counterP then inst._freesoulhop_counterP = 0 end -- 新建计数器给state表中使用
        -- CD结束时不再消耗灵魂
        local FinishPortalHop = inst.FinishPortalHop
        inst.FinishPortalHop2hm = function(inst, ...)
            local inv = inst.components.inventory
            inst.components.inventory = nil
            FinishPortalHop(inst, ...)
            inst.components.inventory = inv
        end
		-- 免费跳跃
        local oldTryToPortalHop = inst.TryToPortalHop
        inst.TryToPortalHop = function(inst, souls, consumeall, ...)
            local skilltreeupdater = inst.components.skilltreeupdater
            if inst._freesoulhop_counterP ~= nil then inst._freesoulhop_counterP = inst._freesoulhop_counter end
            if oldTryToPortalHop(inst, souls, consumeall, ...) then
                local cooldowntime = inst:GetSoulEchoCooldownTime()
                if skilltreeupdater and skilltreeupdater:IsActivated("wortox_liftedspirits_1") then
                    if inst:HasDebuff("wortox_soulecho_buff") then
                        inst:RemoveDebuff("wortox_soulecho_buff")
                        inst:AddDebuff("wortox_soulecho_buff", "wortox_soulecho_buff", {duration = cooldowntime / 2,})
                    end 
                end
                if inst._freesoulhop_counterP <= (skilltreeupdater and skilltreeupdater:IsActivated("wortox_liftedspirits_3") and 1 or 0) then
                    if inst.finishportalhoptask ~= nil then
                        inst.finishportalhoptask:Cancel()
                        inst.finishportalhoptask = inst:DoTaskInTime(cooldowntime, inst.FinishPortalHop2hm)
                    end
                end
                return true
            end
            return oldTryToPortalHop(inst, souls, consumeall, ...)
        end
    end)
end

-- 沃拓克斯增伤
if GetModConfigData("Wortox damage upgrade") then
    local rate = hardmode and 0.25 or 0.35
    local function CustomCombatDamage(inst, target, weapon, multiplier, mount)
        if mount or not target:IsValid() then return 1 end
         return 1 + (inst.components.sanity and inst.components.sanity:GetPercent() >= 0.95 and rate or 0) +
                    (inst.components.health and inst.components.health:GetPercent() >= 0.85 and rate or 0) +
                   (inst.components.hunger and inst.components.hunger:GetPercent() >= 0.90 and rate or 0)
    end
    AddPrefabPostInit("wortox", function(inst)
        if not TheWorld.ismastersim then return end
        if not inst.components.combat.customdamagemultfn then
            inst.components.combat.customdamagemultfn = CustomCombatDamage
        else
            local old = inst.components.combat.customdamagemultfn
            inst.components.combat.customdamagemultfn = function(...) return (old(...) or 1) * CustomCombatDamage(...) end
        end
        -- if not inst.components.combat.onhitotherfn then inst.components.combat.onhitotherfn = WilowAttackFx end
    end)
end

-- 沃拓克斯使用灵魂攻击
if GetModConfigData("Wortox Use Soul Attack") then
    local SCALE = .8
    local SPEED = 10

    local function CreateTail()
        local inst = CreateEntity()

        inst:AddTag("FX")
        inst:AddTag("NOCLICK")
        --[[Non-networked entity]]
        inst.entity:SetCanSleep(false)
        inst.persists = false

        inst.entity:AddTransform()
        inst.entity:AddAnimState()

        MakeInventoryPhysics(inst)
        inst.Physics:ClearCollisionMask()

        inst.AnimState:SetBank("wortox_soul_ball")
        inst.AnimState:SetBuild("wortox_soul_ball")
        inst.AnimState:PlayAnimation("disappear")
        inst.AnimState:SetScale(SCALE, SCALE)
        inst.AnimState:SetFinalOffset(3)

        inst:ListenForEvent("animover", inst.Remove)

        return inst
    end

    local function OnUpdateProjectileTail(inst) -- , dt)
        local x, y, z = inst.Transform:GetWorldPosition()
        for tail, _ in pairs(inst._tails) do tail:ForceFacePoint(x, y, z) end
        if inst.entity:IsVisible() then
            local tail = CreateTail()
            tail.AnimState:SetMultColour(.2, .2, .2, 1)
            local rot = inst.Transform:GetRotation()
            tail.Transform:SetRotation(rot)
            rot = rot * DEGREES
            local offsangle = math.random() * 2 * PI
            local offsradius = (math.random() * .2 + .2) * SCALE
            local hoffset = math.cos(offsangle) * offsradius
            local voffset = math.sin(offsangle) * offsradius
            tail.Transform:SetPosition(x + math.sin(rot) * hoffset, y + voffset, z + math.cos(rot) * hoffset)
            tail.Physics:SetMotorVel(SPEED * (.2 + math.random() * .3), 0, 0)
            inst._tails[tail] = true
            inst:ListenForEvent("onremove", function(tail) inst._tails[tail] = nil end, tail)
            tail:ListenForEvent("onremove", function(inst) tail.Transform:SetRotation(tail.Transform:GetRotation() + math.random() * 30 - 15) end, inst)
        end
    end
    local function OnHasTailDirty(inst)
        if inst._hastail:value() and inst._tails == nil then
            inst._tails = {}
            if inst.components.updatelooper == nil then inst:AddComponent("updatelooper") end
            inst.components.updatelooper:AddOnUpdateFn(OnUpdateProjectileTail)
        end
    end
    local function OnThrownTimeout(inst)
        inst._timeouttask = nil
        inst.components.projectile:Miss(inst.components.projectile.target)
    end
    local function OnThrown(inst)
        inst.AnimState:SetMultColour(.2, .2, .2, 1)
        if inst._task then inst._task:Cancel() end
        if inst._timeouttask ~= nil then inst._timeouttask:Cancel() end
        inst._timeouttask = inst:DoTaskInTime(6, OnThrownTimeout)
        inst.AnimState:Hide("blob")
        inst._hastail:set(true)
        if not TheNet:IsDedicated() then OnHasTailDirty(inst) end
    end
    local function OnHit(inst, attacker, target)
        if target ~= nil then
            local fx = SpawnPrefab("wortox_soul_heal_fx")
            fx.AnimState:SetMultColour(.2, .2, .2, 1)
            fx.entity:AddFollower():FollowSymbol(target.GUID, target.components.combat and target.components.combat.hiteffectsymbol or nil, 0, -50, 0)
            fx:Setup(target)
        end
        inst.SoundEmitter:PlaySound("dontstarve/characters/wortox/soul/spawn", nil, .5)
        inst:Remove()
    end
    local function OnMiss(inst, attacker, target)
        local fx = SpawnPrefab("wortox_soul_spawn")
        fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
        inst:Remove()
    end
    local function onequiptomodel(inst, owner)
        if inst.components.inventoryitem then
            local owner = inst.components.inventoryitem:GetGrandOwner()
            if owner and owner.Transform then
                local x, y, z = owner.Transform:GetWorldPosition()
                inst.components.inventoryitem:RemoveFromOwner(true)
                inst.components.inventoryitem:DoDropPhysics(x, y, z, true)
            end
        end
    end
    -- 修改伤害计算函数，使其返回固定值，
    local function damagefn(inst, attacker, target) -- 根据血量返回固定数值
		if target == nil then return end
		if target ~= nil and target.components.combat then
			if  target.components.health and target.components.health.maxhealth < 23 and not target:HasTag("epic") then 
				target.components.combat:GetAttacked_Internal(attacker, 15, inst)
				return true 
			elseif target.components.health and target.components.health.maxhealth < 46 and target.components.health.maxhealth > 23 and not target:HasTag("epic") then -- 低血量生物造成23伤害
				target.components.combat:GetAttacked_Internal(attacker, 23, inst)
				return true 
			elseif (target.components.health and target.components.health.maxhealth > 23 and target.components.health.maxhealth < 98 and not target:HasTag("epic")) or target:HasTag("epic") then -- 中血量及巨兽造成46伤害
				target.components.combat:GetAttacked_Internal(attacker, 46, inst)
				return true 
			elseif target.components.health and target.components.health.maxhealth > 98 and not target:HasTag("epic") then -- 高血量生物造成98伤害
				target.components.combat:GetAttacked_Internal(attacker, 98, inst)
				return true
			else
				target.components.combat:GetAttacked_Internal(attacker, 46, inst) -- 其他情况则返回固定46伤害
				return true
			end
		end
    end
    AddPrefabPostInit("wortox_soul", function(inst)
        if not inst._hastail then
            inst._hastail = net_bool(inst.GUID, "wortox_soul._hastail", "hastaildirty")
            if not TheWorld.ismastersim then inst:ListenForEvent("hastaildirty", OnHasTailDirty) end
        end
        if not TheWorld.ismastersim then return end
        if not inst.components.equippable and not inst.components.projectile and not inst.components.weapon then
            inst:AddTag("weapon")
            inst:AddTag("rangedweapon")
            inst:AddTag("projectile")
            inst:AddComponent("weapon")
            inst.components.weapon:SetOnAttack(damagefn) --不吃额外倍率加成
			inst.components.weapon:SetDamage(0)
            inst.components.weapon:SetRange(8, 10)
            inst:AddComponent("projectile")
            inst.components.projectile:SetRange(15)
            inst.components.projectile:SetSpeed(20)
            inst.components.projectile:SetHitDist(.5)
            inst.components.projectile:SetHoming(true)
            inst.components.projectile:SetOnThrownFn(OnThrown)
            inst.components.projectile:SetOnHitFn(OnHit)
            inst.components.projectile:SetOnMissFn(OnMiss)
			inst.components.projectile.has_damage_set = true
            inst:AddComponent("equippable")
            inst.components.equippable:SetOnEquipToModel(onequiptomodel)
            inst.components.equippable.equipstack = true
            inst.components.equippable.restrictedtag = "souleater"
        end
    end)
    AddComponentPostInit("inventory", function(self)
        local oldSwapEquipment = self.SwapEquipment
        self.SwapEquipment = function(self, other, equipslot_to_swap, ...)
            if other == nil then return false end
            local other_inventory = other.components.inventory
            if other_inventory == nil or other_inventory.equipslots == nil then return false end
            local item = other_inventory:GetEquippedItem(equipslot_to_swap)
            if item ~= nil and item:IsValid() and item.prefab == "wortox_soul" then return false end
            return oldSwapEquipment(self, other, equipslot_to_swap, ...)
        end
    end)
end