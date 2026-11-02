local hardmode = TUNING.hardmode2hm and GetModConfigData("role_nerf")

-- 全员热铃
if GetModConfigData("All dumbbell heat") then
    AddRecipePostInit("dumbbell_heat", function(inst)
        inst.builder_tag = nil
        inst.builder_skill = nil
        inst.ingredients = {
            Ingredient("heatrock", 0),
            Ingredient("twigs", 1),
            Ingredient("heatrock", 2),
        }
    end)
end

-- 全员冲刺
if GetModConfigData("All Right Dodge") then
    local cd = GetModConfigData("All Right Dodge")
    cd = cd == true and 1 or cd
    local function resetaction(inst)
        if inst.weremode:value() == 0 and inst.woodiepointspecialactionsfn2hm and inst.components.playeractionpicker then
            inst.components.playeractionpicker.pointspecialactionsfn = inst.woodiepointspecialactionsfn2hm
        end
    end
    local function OnWereModeDirty(inst) inst:DoTaskInTime(3, resetaction) end
    AddPlayerPostInit(function(inst)
        if inst.rightaction2hm then return end
        AddDodgeAbility(inst)
        inst.rightaction2hm_cooldown = cd
        inst.rightaction2hm_both = true
        if inst.prefab == "woodie" and inst.weremode then inst:ListenForEvent("weremodedirty", OnWereModeDirty) end
    end)
end