local assets =
{
    Asset("ANIM", "anim/monkey_small.zip"),

    --for water fx build overrides
    Asset("ANIM", "anim/slide_puff.zip"),
    Asset("ANIM", "anim/splash_water_rot.zip"),

    Asset("SOUND", "sound/monkey.fsb"),
}

local prefabs =
{
    "poop",
    "monkeyprojectile",
    "smallmeat",
    "cave_banana",
    "cutless",
    "cursed_monkey_token",
    "oar_monkey",
    "monkey_smallhat",
}

local brain = require "brains/powdermonkeybrainP"

local function IsPoop(item)
    return item.prefab == "poop"
end

local function oneat(inst)
    --Monkey ate some food. Give him some poop!
    if inst.components.inventory ~= nil then
        local maxpoop = 3
        local poopstack = inst.components.inventory:FindItem(IsPoop)
        if poopstack == nil or poopstack.components.stackable.stacksize < maxpoop then
            inst.components.inventory:GiveItem(SpawnPrefab("poop"))
        end
    end
end

local function _ForgetTarget(inst)
    inst.components.combat:SetTarget(nil)
end

local MONKEY_TAGS = { "monkey" }
local function OnAttacked(inst, data)
    inst.components.combat:SetTarget(data.attacker)
    if inst.task ~= nil then
        inst.task:Cancel()
    end
    inst.task = inst:DoTaskInTime(math.random(55, 65), _ForgetTarget) --Forget about target after a minute

    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 30, MONKEY_TAGS)
    for i, v in ipairs(ents) do
        if v ~= inst and v.components.combat then
            v.components.combat:SuggestTarget(data.attacker)
            if v.task ~= nil then
                v.task:Cancel()
            end
            v.task = v:DoTaskInTime(math.random(55, 65), _ForgetTarget) --Forget about target after a minute
        end
    end
end

local function retargetfn(inst)
    return nil
end

local function shouldKeepTarget(inst, target)
    return (inst.components.crewmember ~= nil)
        or inst.components.combat:CanTarget(target)
end

local function OnPickup(inst, data)
	local item = data ~= nil and data.item or nil
    if item ~= nil and
        item.components.equippable ~= nil and
        item.components.equippable.equipslot == EQUIPSLOTS.HEAD and
        not inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD) then
        --Ugly special case for how the PICKUP action works.
        --Need to wait until PICKUP has called "GiveItem" before equipping item.
        inst:DoTaskInTime(0, function()
            if item:IsValid() and
                item.components.inventoryitem ~= nil and
                item.components.inventoryitem.owner == inst then
                inst.components.inventory:Equip(item)
            end
        end)
    end
end

local function OnDropItem(inst, data)
	if data ~= nil and data.item ~= nil then
		data.item:RemoveTag("personal_possession")
	end
	if data ~= nil and data.item ~= nil and data.item.prefab == "oar_monkey" then
		data.item:Remove()
	end
end

local function OnSave(inst, data)
	if inst.components.inventory then
		local personal_item = {}
		for k, v in pairs(inst.components.inventory.itemslots) do
			if v.persists and v:HasTag("personal_possession") then
				personal_item[k] = v.prefab
			end
		end
		data.personal_item = (next(personal_item) ~= nil and personal_item) or nil

		local personal_equip = {}
		for k, v in pairs(inst.components.inventory.equipslots) do
			if v.persists and v:HasTag("personal_possession") then
				personal_equip[k] = v.prefab
			end
		end
		data.personal_equip = (next(personal_equip) ~= nil and personal_equip) or nil
	end
	------------------------------------------------------------------
	if inst.components.follower and inst.components.follower.leader then
		local leader = inst.components.follower.leader
		if leader:IsValid() then
			data.leader_guid = leader.GUID  -- 保存唯一 ID
			data.leader_prefab = leader.prefab  -- 保存 prefab（如 "wilson"）
		end
	end
end

local function OnLoad(inst, data)
	if data ~= nil then
		if data.personal_item ~= nil then
			for k, v in pairs(data.personal_item) do
				local item = inst.components.inventory:GetItemInSlot(k)
				if item ~= nil and item.prefab == v then
					item:AddTag("personal_possession")
				end
			end
		end
		if data.personal_equip ~= nil then
			for k, v in pairs(data.personal_equip) do
				local item = inst.components.inventory:GetEquippedItem(k)
				if item ~= nil and item.prefab == v then
					item:AddTag("personal_possession")
				end
			end
		end
		if data.leader_guid then
			local leader = Ents[data.leader_guid]  -- 通过全局实体表查找
		elseif data.leader_prefab then
			-- 如果 GUID 失效，尝试通过 prefab 找回（如玩家角色）
			local leader = FindEntityByPrefab(data.leader_prefab)
		end
	end
end

local function ClearTinkerTarget(inst)
    if inst.tinkertarget then
        local bc = (inst.components.crewmember and
                   inst.components.crewmember.boat and
                   inst.components.crewmember.boat.components.boatcrew)
                   or nil
        if bc then
            bc:removeinkertarget(inst.tinkertarget)
        end
        inst.tinkertarget = nil
    end
end

local function OnGotItem(inst,data)
    if data.item and (data.item.prefab == "cave_banana" or data.item.prefab == "cave_banana_cooked") then
        inst:PushEvent("victory", {
            item = data.item,
            say = STRINGS["MONKEY_BATTLECRY_VICTORY"][math.random(#STRINGS["MONKEY_BATTLECRY_VICTORY"])]
        })
    end
end

local function speech_override_fn(inst, speech)
    return (ThePlayer and not ThePlayer:HasTag("wonkey") and CraftMonkeySpeech())
        or speech
end

local function battlecry(combatcmp, target)
    if target ~= nil then
        local strtbl = (target:HasTag("monkey") and "MONKEY_MONKEY_BATTLECRY")
            or (target.components.inventory ~= nil
                and target.components.inventory:NumItems() > 0
                and "MONKEY_STUFF_BATTLECRY")
            or "MONKEY_BATTLECRY"

        return strtbl, math.random(#STRINGS[strtbl])
    end
end

local function onmonkeychange(inst, data)
    if data and data.player then
        if inst.components.combat and inst.components.combat.target == data.player then
            inst.components.combat:DropTarget()
        end
    end
end

local function modifiedsleeptest(inst)
    return (inst.components.crewmember == nil and DefaultSleepTest(inst) and inst.components.follower.leader == nil)
        or nil
end

local function ontalk(inst, script)
    inst.SoundEmitter:PlaySound("monkeyisland/powdermonkey/speak")
end

local function OnGetItemFromPlayer(inst, giver, item)
	if item.components.equippable ~= nil and item.components.equippable.equipslot == EQUIPSLOTS.HEAD then
		local current = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
		if current ~= nil then
			inst.components.inventory:DropItem(current)
		end
		inst.components.inventory:Equip(item)
		inst.AnimState:Show("hat")
	elseif item.components.equippable ~= nil and item.components.equippable.equipslot == EQUIPSLOTS.HANDS then
		local current = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
		if current ~= nil then
			inst.components.inventory:DropItem(current)
		end
		inst.components.inventory:Equip(item)
	end
end

local function ShouldAcceptItem(inst, item)
	if item.components.equippable ~= nil and item.components.equippable.equipslot == EQUIPSLOTS.HEAD then
		return true
	elseif not inst.rangeweapondata2hm and item.components.equippable ~= nil and item.components.equippable.equipslot == EQUIPSLOTS.HANDS then
		return true
	end
end

local function onhit(inst)
    inst:ClearBufferedAction()
end

local function onremove(inst)
    if inst.cannon then
        inst.cannon.operator = nil
    end
    inst:ClearTinkerTarget()
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

    inst.DynamicShadow:SetSize(2, 1.25)

    inst.Transform:SetFourFaced()

    MakeCharacterPhysics(inst, 10, 0.25)

    inst.AnimState:SetBank("monkey_small")
    inst.AnimState:SetBuild("monkey_small")
    inst.AnimState:PlayAnimation("idle", true)

    inst.AnimState:OverrideSymbol("fx_slidepuff01", "slide_puff", "fx_slidepuff01")
    inst.AnimState:OverrideSymbol("splash_water_rot", "splash_water_rot", "splash_water_rot")
    inst.AnimState:OverrideSymbol("fx_water_spot", "splash_water_rot", "fx_water_spot")
    inst.AnimState:OverrideSymbol("fx_splash_wide", "splash_water_rot", "fx_splash_wide")
    inst.AnimState:OverrideSymbol("fx_water_spray", "splash_water_rot", "fx_water_spray")

    inst.AnimState:Hide("ARM_carry")
    inst.scrapbook_hide = {"ARM_carry"}
    inst.scrapbook_specialinfo = "POWDERMONKEY"

    inst:AddTag("character")
    inst:AddTag("monkey")
	inst:AddTag("scarytoprey")
    inst:AddTag("pirate")

    local talker = inst:AddComponent("talker")
    talker.fontsize = 35
    talker.font = TALKINGFONT
    talker.offset = Vector3(0, -400, 0)
    talker:MakeChatter()
    talker.ontalk = ontalk

    inst.speech_override_fn = speech_override_fn

    inst.scrapbook_removedeps = {"oar_monkey"}

    inst.entity:SetPristine()
	
	inst.displaynamefn = function() 
        return (TUNING.isCh2hm and "火药猴") or "Powder Monkey"
    end
    if not TheWorld.ismastersim then
        return inst
    end

    inst.soundtype = ""

    MakeMediumBurnableCharacter(inst,"m_skirt")
    MakeMediumFreezableCharacter(inst)

    inst:AddComponent("bloomer")

    inst:AddComponent("inventory")
    inst.components.inventory.maxslots = 20

    inst:AddComponent("workmultiplier")
    inst.components.workmultiplier:AddMultiplier(ACTIONS.CHOP, 0.25, "hard2hm")
    inst.components.workmultiplier:AddMultiplier(ACTIONS.MINE, 0.1, "hard2hm")
	
	inst:AddComponent("follower") -- 添加跟随者组件
	inst.components.follower.keepdeadleader = true  -- 誓死追随玩家
	
	inst:AddComponent("trader") -- 可以给头部装备
	inst.components.trader:SetAcceptTest(ShouldAcceptItem)
	inst.components.trader.onaccept = OnGetItemFromPlayer
	inst.components.trader.deleteitemonaccept = false
	inst.components.trader.acceptnontradable = true

    inst:AddComponent("inspectable")

    inst:AddComponent("thief")

    local locomotor = inst:AddComponent("locomotor")
    locomotor:SetSlowMultiplier( 1 )
    locomotor:SetTriggersCreep(false)
    locomotor.pathcaps = { ignorecreep = false }
    locomotor.walkspeed = TUNING.MONKEY_MOVE_SPEED

    local combat = inst:AddComponent("combat")
    combat:SetAttackPeriod(TUNING.MONKEY_ATTACK_PERIOD)
    combat:SetDefaultDamage(TUNING.POWDER_MONKEY_DAMAGE)
    combat:SetRange(TUNING.MONKEY_MELEE_RANGE)
    combat:SetRetargetFunction(1, retargetfn)
    combat:SetOnHit(onhit)
    inst.components.combat:AddNoAggroTag("player")
    combat.GetBattleCryString = battlecry

    inst.components.combat:SetKeepTargetFunction(shouldKeepTarget)

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(TUNING.POWDER_MONKEY_HEALTH)

    inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetChanceLootTable(nil)

    inst:AddComponent("eater")
    inst.components.eater:SetDiet({ FOODTYPE.VEGGIE }, { FOODTYPE.VEGGIE })
    inst.components.eater:SetOnEatFn(oneat)

    inst:AddComponent("sleeper")
    inst.components.sleeper.sleeptestfn = modifiedsleeptest
    inst.components.sleeper.waketestfn = DefaultWakeTest

    inst:AddComponent("embarker")
    inst.components.embarker.embark_speed = inst.components.locomotor.runspeed

    inst:AddComponent("drownable")

    inst.components.locomotor:SetAllowPlatformHopping(true)

    inst:AddComponent("areaaware")

    inst:AddComponent("timer")


    inst.ClearTinkerTarget = ClearTinkerTarget

    inst:ListenForEvent("onremove", onremove)

    inst:SetBrain(brain)
    inst:SetStateGraph("SGpowdermonkey")

    inst:AddComponent("knownlocations")

    inst:ListenForEvent("onpickupitem", OnPickup)
	inst:ListenForEvent("dropitem", OnDropItem)
    inst:ListenForEvent("attacked", OnAttacked)
    inst:ListenForEvent("itemget", OnGotItem)
    inst:ListenForEvent("ms_seamlesscharacterspawned", onmonkeychange, TheWorld)

    MakeHauntablePanic(inst)

    --inst.weaponitems = {}
    --EquipWeapons(inst)

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    return inst
end

return Prefab("powder_monkey_p", fn, assets, prefabs)
