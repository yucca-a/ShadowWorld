function A.survival_difficulty(variant)
    local rows, cleanup = {}, {}
    local bear, ed = variant ~= "default", variant ~= "default"
    local optional = variant == "all" or variant == "um"
    local function check(name, fn)
        local ok, result = pcall(fn)
        rows[#rows + 1] = {name = name, passed = ok and result ~= false, error = not ok and tostring(result) or nil}
    end
    local function spawn(name)
        local inst = assert(SpawnPrefab(name), name)
        cleanup[#cleanup + 1] = inst
        inst.Transform:SetPosition(800, 0, 800)
        return inst
    end
    local player = A.player(1)
    local axe = spawn("axe")
    check("crafted_durability", function()
        axe.components.finiteuses:SetPercent(1)
        player:PushEvent("builditem", {item = axe})
        local percent = axe.components.finiteuses:GetPercent()
        return bear and percent > 0 and percent < 0.6 or not bear and percent == 1
    end)
    check("proficiency_and_durability_cap", function()
        if not bear then return player.ray_zhizao_manufactured_items == nil end
        for i = 1, 80 do
            axe.components.finiteuses:SetPercent(1) -- each freshly crafted item starts full.
            player:PushEvent("builditem", {item = axe})
        end
        local record = player:GetSaveRecord()
        return player.ray_zhizao_manufactured_items.axe == 243
            and axe.components.finiteuses:GetPercent() == 1
            and record.data.ray_zhizao_manufactured_items.axe == 243
    end)
    check("sharpen_weapon", function()
        if not bear then return ACTIONS.RAY_MODAOCASHI == nil end
        local weapon, stone = spawn("spear"), spawn("purebrilliance")
        -- Synthetic server player has no connection; suppress this action's sound packet.
        local uid = player.userid; player.userid = nil
        local ok, result = pcall(ACTIONS.RAY_MODAOCASHI.fn, {target = weapon, invobject = stone, doer = player})
        player.userid = uid
        assert(ok, result)
        return result and not stone:IsValid() and weapon.components.planardamage:GetDamage() >= 15
    end)
    check("recipe_ingredients", function()
        -- Native torch costs two grass and two twigs before the optional multiplier.
        local recipe = AllRecipes.torch
        return recipe.ingredients[1].amount == (optional and 4 or 2)
    end)
    check("slow_build_state", function()
        if not bear then return player.sg.sg.states.ray_manzuozhizao == nil end
        player.bufferedaction = BufferedAction(player, nil, ACTIONS.BUILD, nil, player:GetPosition(), "spear")
        player.sg:GoToState("ray_manzuozhizao")
        local ok = player.sg.currentstate.name == "dolongaction" and player.sg.timeout >= 1
        player:ClearBufferedAction(); player.sg:GoToState("idle")
        return ok
    end)
    check("resource_drop_halving", function()
        local tree = spawn("evergreen")
        tree.components.workable:WorkedBy_Internal(player, 1)
        local first = tree.components.lootdropper:SpawnLootPrefab("log")
        local second = tree.components.lootdropper:SpawnLootPrefab("log")
        if first then cleanup[#cleanup + 1] = first end
        if second then cleanup[#cleanup + 1] = second end
        return first ~= nil and ((second == nil) == bear)
    end)
    check("pigking_gold_trade", function()
        local king, meat = spawn("pigking"), spawn("meat")
        local accepted = king.components.trader.test(king, meat, player, 1)
        return (accepted == false) == bear
    end)
    check("cookbook_durability", function()
        local book = spawn("cookbook")
        return optional and book.components.finiteuses and book.components.finiteuses:GetUses() == 5
            or not optional and book.components.finiteuses == nil
    end)
    check("food_stack_and_old_save_count", function()
        local food, other = spawn("meatballs"), spawn("meatballs")
        if optional then
            if food.components.stackable.maxsize ~= 1 or food.components.stackable:CanStackWith(other) then return false end
            food.components.stackable:OnLoad({stack = 9})
            local saved = food:GetSaveRecord()
            return saved.data.stackable.stack == 9
        end
        return food.components.stackable.maxsize > 1 and food.components.stackable:CanStackWith(other)
    end)
    check("armor_invalid", function()
        local armor = spawn("armorwood")
        local inventory = player.components.inventory
        inventory:Equip(armor)
        local before = armor.components.armor:GetPercent()
        local damage = inventory:ApplyDamage(50, nil, nil, nil)
        local same = armor.components.armor:GetPercent() == before
        inventory:Unequip(EQUIPSLOTS.BODY)
        return optional and damage == 50 and same or not optional and damage < 50 and not same
    end)
    check("shadow_protection", function()
        local shadow = spawn("crawlinghorror")
        local before = player.components.health.currenthealth
        player.components.health:SetInvincible(false)
        player.components.combat:GetAttacked_Internal(shadow, 10)
        local after = player.components.health.currenthealth
        player.components.health:SetInvincible(true)
        return optional and shadow:HasTag("ray_lishijieguaiwu") and before == after
            or not optional and not shadow:HasTag("ray_lishijieguaiwu") and before > after
    end)
    check("freeze_cooldown", function()
        local pig = spawn("pigman")
        pig.components.freezable:Freeze(20)
        return (pig.ray_bingfengzhuangtaidaojishi ~= nil) == ed
    end)
    check("rain_fire_and_shelter", function()
        local fire = spawn("campfire")
        fire.Transform:SetPosition(900, 0, 900)
        fire.components.burnable:Extinguish()
        local raining = TheWorld.state.israining
        TheWorld.state.israining = true
        fire.components.burnable:Ignite()
        local blocked = not fire.components.burnable:IsBurning()
        fire.components.burnable:Extinguish()
        local shelter = spawn("evergreen"); shelter:AddTag("shelter")
        shelter.Transform:SetPosition(900, 0, 900)
        fire.components.burnable:Ignite()
        local sheltered = fire.components.burnable:IsBurning()
        TheWorld.state.israining = raining
        return blocked == ed and sheltered
    end)
    check("torch_heat", function()
        local fx = spawn("torchfire")
        return (fx.components.heater ~= nil) == ed
    end)
    check("attack_in_place", function() return (ACTIONS.ATTACK.do_not_locomote == true) == optional end)
    check("private_native_query", function()
        local wire, sent = G.SendModRPCToClient, {}
        local rpc = GetClientModRPC("ShadowWorld", "difficulty_result")
        G.SendModRPCToClient = function(channel, userid, ...)
            if channel.namespace == rpc.namespace and channel.id == rpc.id then
                sent[#sent + 1] = {userid = userid, values = {...}}
            else return wire(channel, userid, ...) end
        end
        player._difficultyquery2hm = nil
        local query = GetModRPCHandler("ShadowWorld", "difficulty_query")
        local ok, err = pcall(query, player, "someone_else")
        G.SendModRPCToClient = wire
        assert(ok, err)
        return #sent == 1 and sent[1].userid == player.userid
            and sent[1].values[1] == (variant == "default" and "default" or optional and "hell" or "default")
    end)
    check("native_slash_command_registration", function()
        local command = require("usercommands").GetCommandFromName("nd")
        return command.permission == COMMAND_PERMISSION.USER and command.slash and command.serverfn ~= nil
    end)
    for _, inst in ipairs(cleanup) do if inst:IsValid() then inst:Remove() end end
    local passed = true
    for _, row in ipairs(rows) do passed = passed and row.passed end
    emit({kind = "survival_difficulty", variant = variant, passed = passed, rows = rows})
end
