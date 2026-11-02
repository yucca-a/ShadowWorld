-- 2025.9.25 melon:涡流刀(滑铲刀)  每次攻击后可冲刺一次(没有无敌),并将敌人牵引一段距离造成一半伤害

local assets =
{
    Asset("ANIM", "anim/nightmaresword.zip"),
    Asset("ANIM", "anim/swap_nightmaresword.zip"),
    Asset("ATLAS", "images/inventoryimages/sword_vortex2hm.xml"),
	Asset("IMAGE", "images/inventoryimages/sword_vortex2hm.tex"),
}

local function onattack(inst, attacker, target)
    if attacker and target then
        attacker.sword_vortex_target2hm = target
        if attacker.sword_vortex_count2hm == nil then attacker.sword_vortex_count2hm = 0 end
        attacker.sword_vortex_count2hm = math.min(attacker.sword_vortex_count2hm + 1, 2) -- 最多连续冲刺2次
    end
end

local function onequip(inst, doer)
    doer.AnimState:OverrideSymbol("swap_object", "swap_nightmaresword", "swap_nightmaresword")
    doer.AnimState:Show("ARM_carry")
    doer.AnimState:Hide("ARM_normal")
end

local function onunequip(inst, doer)
    doer.AnimState:Hide("ARM_carry")
    doer.AnimState:Show("ARM_normal")
end

-- 帝王蟹/蚁狮/大触手/触手/恐怖尖喙/梦魇尖喙/暗影主教/暗影战车
local CANT_PREFABS = {"crabking", "antlion", "tentacle_pillar", "tentacle", "terrorbeak", "nightmarebeak", "shadow_bishop", "shadow_rook", }
local CANT_TAGS = {"structure", "cant_vortex_target2hm", } -- use cant_vortex_target2hm tag, cant be pulled
local function canmove(target)
    if not target:IsValid() or
    target:HasOneOfTags(CANT_TAGS) or
    table.contains(CANT_PREFABS, target.prefab) then
        return false
    end
    return true
end

-- 牵引敌人并造成30伤害?
local function castspell(inst, target, pos, doer, ...)
    doer.sword_vortex_count2hm = doer.sword_vortex_count2hm - 1 -- 牵引次数-1
    if pos == nil or doer == nil or doer.sword_vortex_target2hm == nil then return end
    local vortex_target2hm = doer.sword_vortex_target2hm
    -- 攻击一次
    if vortex_target2hm:IsValid() and vortex_target2hm.components.combat then
        vortex_target2hm.components.combat:GetAttacked_Internal(inst, inst.sword_vortex2hm_damage) -- 30伤害
        vortex_target2hm.components.combat:SuggestTarget(doer) -- 仇恨受攻击目标
    end
    -- 牵引，目标不能是建筑
    if not inst.canmove(vortex_target2hm) then return end
    if doer.Transform == nil or vortex_target2hm.Transform == nil then return end
    local x,y,z = doer.Transform:GetWorldPosition()
    local x1,y1,z1 = pos:Get()
    local x2,y2,z2 = vortex_target2hm.Transform:GetWorldPosition()
    local dx = x1 - x
    local dz = z1 - z
    local r = math.sqrt(dx^2 + dz^2)
    dx = dx / r
    dz = dz / r
    local dist = vortex_target2hm:HasTag("epic") and 4 or 3.2 -- 牵引距离
    local TASK_NUM = 20
    for i = 1, TASK_NUM do
        if not vortex_target2hm:IsValid() then break end
        vortex_target2hm:DoTaskInTime((i - 1) * FRAMES, function(vortex_target2hm)
            vortex_target2hm.Transform:SetPosition(x2 + dx*dist*i/TASK_NUM,y2,z2 + dz*dist*i/TASK_NUM)
        end)
    end
end
-- 牵引次数>0才行
local function can_cast_fn(doer, ...)
    return doer.sword_vortex_count2hm and doer.sword_vortex_count2hm > 0
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("nightmaresword")
    inst.AnimState:SetBuild("nightmaresword")
    inst.AnimState:PlayAnimation("idle")
    inst.AnimState:SetMultColour(1, 1, 1, .6) -- 调色?

    inst:AddTag("shadow_item") -- 去除
    inst:AddTag("shadow") -- 去除
    inst:AddTag("sharp")
    inst:AddTag("weapon")
    inst:AddTag("sword_vortex2hm") -- 标记自己
	inst:AddTag("shadowlevel") -- 去除

    local swap_data = {sym_build = "swap_nightmaresword", bank = "nightmaresword"}
    MakeInventoryFloatable(inst, "med", 0.05, {1.0, 0.4, 1.0}, true, -17.5, swap_data)
    inst.entity:SetPristine()

    if not TheWorld.ismastersim then return inst end

    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(TUNING.HAMBAT_DAMAGE) -- 伤害59.5
    inst.components.weapon:SetOnAttack(onattack)
    inst:AddComponent("finiteuses")
    inst.components.finiteuses:SetMaxUses(100 * 2) -- 200耐久
    inst.components.finiteuses:SetUses(100 * 2)
    inst.components.finiteuses:SetOnFinished(inst.Remove)
    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "sword_vortex2hm"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/sword_vortex2hm.xml"
    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)
    inst.components.equippable.dapperness = TUNING.CRAZINESS_SMALL -- 慢速扣san  快速CRAZINESS_MED
    inst.components.equippable.is_magic_dapperness = true
	inst:AddComponent("shadowlevel")
	inst.components.shadowlevel:SetDefaultLevel(TUNING.NIGHTSWORD_SHADOW_LEVEL)
    inst:AddComponent("spellcaster") -- 右键使用
    inst.components.spellcaster:SetSpellFn(castspell)
    inst.components.spellcaster:SetCanCastFn(can_cast_fn)
    inst.components.spellcaster.canuseontargets = true
    inst.components.spellcaster.canuseondead = true
    inst.components.spellcaster.canuseonpoint = true
    inst.components.spellcaster.canuseonpoint_water = true
    inst.components.spellcaster.canusefrominventory = false
    MakeHauntableLaunch(inst)
    -- 
    inst.canmove = canmove
    inst.sword_vortex2hm_damage = 30
    return inst
end

return Prefab("sword_vortex2hm", fn, assets) -- 涡流刀
