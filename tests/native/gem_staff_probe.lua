function A.gem_staff()
    local caster = A.player(1)
    local staff = SpawnPrefab("greenstaff")
    caster.components.inventory:GiveItem(staff)
    -- Let all mods finish their deferred per-instance spell wrappers first.
    staff:DoTaskInTime(0.1, function()
        local rows = {}
        for _, dictionary in ipairs({false, true}) do
            local target = SpawnPrefab("treasurechest")
            target.Transform:SetPosition(caster.Transform:GetWorldPosition())
            local recipe = AllRecipes.treasurechest
            local saved = recipe.gemdict_ingredients
            if dictionary then
                recipe.gemdict_ingredients = {{type="goldnugget", amount=2,
                    ingredientspawnfn=function() return {"goldnugget", "goldnugget"} end}}
            end
            local before = {}
            for guid in pairs(Ents) do before[guid]=true end
            local uses = staff.components.finiteuses:GetUses()
            local ok, err = pcall(staff.components.spellcaster.spell, staff, target)
            recipe.gemdict_ingredients = saved
            local loot = {}
            for guid, item in pairs(Ents) do
                if not before[guid] and item:IsValid() and item.components.inventoryitem then
                    loot[item.prefab]=(loot[item.prefab] or 0)+(item.components.stackable and item.components.stackable:StackSize() or 1)
                end
            end
            rows[#rows+1]={dictionary=dictionary,ok=ok,removed=not target:IsValid(),
                uses=uses-staff.components.finiteuses:GetUses(),loot=loot}
            if not ok then print("[GemStaffProbe]",err) end
            if target:IsValid() then target:Remove() end
        end
        staff:Remove()
        local passed = true
        for _, row in ipairs(rows) do
            passed = passed and row.ok and row.removed and row.uses==1 and row.loot.boards==3
                and (not row.dictionary or row.loot.goldnugget==2)
        end
        emit({kind="gem_staff",passed=passed,rows=rows,
            private_helper=UpvalueHacker~=require("upvaluehacker2hm"),
            compat=ModManager:GetMod("workshop-1378549454").gemstaffcompat2hm==true})
    end)
end
