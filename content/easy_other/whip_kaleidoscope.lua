-- 鞭子加强 + 万花筒(2026.8.9 melon): 全部玩家通用, 不受简单模式/角色开关门控
-- 鞭子: 伤害34, 配方在现有基础上追加2蜘蛛丝+1触手皮; 攻击标记敌人5秒, 期间该玩家随从攻击额外+30伤害
-- 万花筒: 51伤害/200耐久, 攻击标记敌人5秒, 期间该玩家随从攻击30%概率双倍伤害; 特效在 prefab 内
-- 标记规则: 所有玩家通用(不区分角色); 玩家用鞭子/万花筒打中敌人 → 打上标记(记录标记者);
--           该标记玩家的随从(follower.leader == 标记者)攻击被标记的敌人时, 触发加成。
local MARK_TIME = 5
local WHIP_EXTRA_DAMAGE = 30
local KALEIDO_DOUBLE_CHANCE = 0.3
local WHIP_TAG = "whip_mark2hm"
local KALEIDO_TAG = "kaleidoscope_mark2hm"

-- 目标被自己随从攻击时触发的加成
local function OnMarkedAttacked(target, data)
    local owner = target._whip_mark_owner2hm
    if not owner or not owner:IsValid() then return end
    local attacker = data and data.attacker
    if not attacker or not attacker:IsValid() or attacker == owner then return end
    -- 必须是标记者自己的随从(follower.leader指向标记者)
    if not (attacker.components.follower and attacker.components.follower.leader == owner) then return end
    if not target.components.health then return end
    if target:HasTag(KALEIDO_TAG) then
        -- 万花筒: 30%概率补一次等额伤害(等效双倍)
        if math.random() < KALEIDO_DOUBLE_CHANCE and data.damage and data.damage > 0 then
            target.components.health:DoDelta(-data.damage, nil, "kaleidoscope_mark2hm")
        end
    elseif target:HasTag(WHIP_TAG) then
        -- 鞭子: 固定额外30伤害
        target.components.health:DoDelta(-WHIP_EXTRA_DAMAGE, nil, "whip_mark2hm")
    end
end

local function ClearMark(target)
    target:RemoveTag(WHIP_TAG)
    target:RemoveTag(KALEIDO_TAG)
    target._whip_mark_owner2hm = nil
    if target._whip_mark_task2hm then
        target._whip_mark_task2hm:Cancel()
        target._whip_mark_task2hm = nil
    end
    target:RemoveEventCallback("attacked", OnMarkedAttacked)
end

-- 攻击命中后标记目标5秒
local function MarkTarget(weapon, target)
    local owner = weapon.components.inventoryitem and weapon.components.inventoryitem:GetGrandOwner()
    if not owner or not owner:IsValid() or not owner:HasTag("player") then return end
    ClearMark(target)
    target:AddTag(weapon.prefab == "kaleidoscope2hm" and KALEIDO_TAG or WHIP_TAG)
    target._whip_mark_owner2hm = owner
    target:ListenForEvent("attacked", OnMarkedAttacked)
    target._whip_mark_task2hm = target:DoTaskInTime(MARK_TIME, function()
        if target:IsValid() then ClearMark(target) end
    end)
end

local function AddMarkOnAttack(inst)
    if not TheWorld.ismastersim then return end
    if inst._whip_mark_hooked2hm then return end
    inst._whip_mark_hooked2hm = true
    inst:ListenForEvent("onattackother", function(inst, data)
        local target = data and data.target
        if target and target:IsValid() and not target:HasTag("player") and not target:HasTag("playerghost") then
            MarkTarget(inst, target)
        end
    end)
end

-- 鞭子加强: 伤害34 + 标记
AddPrefabPostInit("whip", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.weapon then
        inst.components.weapon:SetDamage(34)
    end
    AddMarkOnAttack(inst)
end)

-- 鞭子配方: 在现有配方基础上追加材料(已有同材料则合并数量, 不覆盖其他来源的配方改动)
local function MergeIngredients(recipe, ...)
    local extra = { ... }
    local ings = recipe.ingredients or {}
    for _, ai in ipairs(extra) do
        local found = false
        for _, ei in ipairs(ings) do
            if ei and ei.prefab == ai.prefab then
                ei.amount = (ei.amount or 1) + (ai.amount or 1)
                found = true
                break
            end
        end
        if not found then
            ings[#ings + 1] = ai
        end
    end
    recipe.ingredients = ings
end

AddRecipePostInit("whip", function(inst)
    MergeIngredients(inst, Ingredient("silk", 2), Ingredient("tentaclespots", 1))
end)

-- 万花筒: 标记(51伤害/200耐久/特效在prefab内)
AddPrefabPostInit("kaleidoscope2hm", function(inst)
    AddMarkOnAttack(inst)
end)

-- 万花筒配方: 三叉戟 + 纯粹辉煌x3 + 猫尾鞭 (image 必须在 config 第4参数, 否则制作栏图标不生效)
AddRecipe2("kaleidoscope2hm",
    { Ingredient("trident", 1), Ingredient("purebrilliance", 3), Ingredient("whip", 1) },
    TECH.CELESTIAL,
    { image = "whip.tex" })

STRINGS.NAMES.KALEIDOSCOPE2HM = "万花筒"
STRINGS.RECIPE_DESC.KALEIDOSCOPE2HM = "攻击标记敌人,标记期间随从攻击有30%概率双倍伤害"
STRINGS.CHARACTERS.GENERIC.DESCRIBE.KALEIDOSCOPE2HM = "被它抽到的敌人会被标上月亮的记号,让随从们的攻击变得更痛。"
