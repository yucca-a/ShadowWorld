if CONSTRUCTION_PLANS and CONSTRUCTION_PLANS["mermthrone_construction"] then
    table.insert(CONSTRUCTION_PLANS["mermthrone_construction"], Ingredient("trident", 1))
else
    AddRecipePostInit("mermthrone_construction", function(inst) table.insert(inst.ingredients, Ingredient("trident", 1)) end)
end

-- 鱼人堡垒/守卫强化(受"鱼人堡垒材料增加,鱼人守卫数值提升"配置控制,默认开启)
if GetModConfigData("wurt_merm_stronger") then
    -- 堡垒造价提升:10木板+2触手皮+2长矛+2猪皮
    AddRecipePostInit("mermwatchtower", function(recipe)
        recipe.ingredients = {
            Ingredient("boards", 10),
            Ingredient("tentaclespots", 2),
            Ingredient("spear", 2),
            Ingredient("pigskin", 2),
        }
    end)

    TUNING.PUNY_MERM_DAMAGE = 40                        -- 无鱼王伤害(原模组30)
    TUNING.PUNY_MERM_HEALTH = 600                       -- 无鱼王血量(原模组500)
    TUNING.MERM_GUARD_DAMAGE = 70                       -- 有鱼王伤害(原50)
    TUNING.MERM_GUARD_HEALTH = 800                      -- 有鱼王血量(原660)
    TUNING.MERM_LUNAR_GUARD_EXTRA_HEALTH = 200          -- 月灵战斗鱼人额外血量(原40)
    TUNING.MERM_LUNAR_THORN_DAMAGE = 50                 -- 月灵鱼人反伤(原40)
    TUNING.MERMKING_TRIDENTBUFF_TRIPLEHIT_DAMAGECHANGE = 1.0 -- 三叉戟buff三连击每下伤害(原0.5)
else
    -- 原模组:战斗鱼人虚弱正常化(PUNY=普通鱼人数值)
    TUNING.PUNY_MERM_DAMAGE = TUNING.MERM_DAMAGE
    TUNING.PUNY_MERM_HEALTH = TUNING.MERM_HEALTH
end

TUNING.WURT_TERRAFORMING_SHADOW_PROCCHANCE = TUNING.WURT_TERRAFORMING_SHADOW_PROCCHANCE / 2.5

local function StartSpawning(inst)
    if not inst:HasTag("burnt") and TheWorld.components.mermkingmanager and not TheWorld.components.mermkingmanager:HasKing() and inst.components.childspawner ~=
        nil then inst.components.childspawner:StartSpawning() end
end

AddPrefabPostInit("mermwatchtower", function(inst)
    if not TheWorld.ismastersim then return end
    if not (TheWorld.components.mermkingmanager and TheWorld.components.mermkingmanager:HasKing()) then StartSpawning(inst) end
    inst:ListenForEvent("onmermkingdestroyed", StartSpawning, TheWorld)
end)

local merms = {"merm", "mermguard"}
local newloot = {"pondfish", "frog"}
for index, merm in ipairs(merms) do
    AddPrefabPostInit(merm, function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.lootdropper and math.random() < 0.1 then inst.components.lootdropper:SetLoot(newloot) end
    end)
end

-- 鱼人闪避50%概率触发
AddPrefabPostInit("mermking_buff_crown", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.debuff then
        local onattachedfn = inst.components.debuff.onattachedfn
        inst.components.debuff.onattachedfn = function(inst, target, ...)
            if onattachedfn then onattachedfn(inst, target, ...) end
            if not inst.candodgefn2hm and not target.isplayer and target:HasTag("mermguard") and target.components.attackdodger then
                inst.candodgefn2hm = true
                local oldcandodgefn = target.components.attackdodger.CanDodge
                target.components.attackdodger.CanDodge = function(self, attacker, ...)
                    local res
                    if oldcandodgefn then res = oldcandodgefn(self, attacker) end
                    return res and math.random() > 0.5
                end
            end
        end

        local ondetached = inst.components.debuff.ondetachedfn
        inst.components.debuff.ondetachedfn = function(inst, target, ...)
            if ondetached then ondetached(inst, target, ...) end
            if not target.isplayer then
                inst.candodgefn2hm = nil
            end
        end
    end
end)

