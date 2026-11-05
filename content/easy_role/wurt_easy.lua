local hardmode = TUNING.hardmode2hm and GetModConfigData("role_nerf") and GetModConfigData("wurt")

-- 沃特吃食物收买附近鱼人
if GetModConfigData("Wurt Eat Food Lead Wild Merm") then
    local MERM_TAGS = {"merm"}
    local MERM_IGNORE_TAGS = {"FX", "NOCLICK", "DECOR", "INLIMBO", "player", "swc2hm"}
    local function OnEat(inst, data)
        if data.food ~= nil and data.food.components.edible and inst.components.leader then
            local self = inst.components.leader
            local num = 1
            local max
            if inst.components.hunger.current > 101 then
                max = 1 + math.floor((inst.components.hunger.current - 100) / 2)
                if TUNING.maxfollowernum2hm and self.calculaterepeatfollowers2hm then
                    local followers = self:calculaterepeatfollowers2hm()
                    max = math.min(TUNING.maxfollowernum2hm - #followers, max)
                    if max <= 0 then return end
                end
                num = max
            end
            local hasking = TheWorld.components.mermkingmanager and TheWorld.components.mermkingmanager:HasKing() or false
            local x, y, z = inst.Transform:GetWorldPosition()
            local ents = TheSim:FindEntities(x, y, z, 20, nil, MERM_IGNORE_TAGS, MERM_TAGS)
            for k, v in pairs(ents) do
                if v.components.follower and not v.components.follower.leader then
                    self:AddFollower(v)
                    local isguard = v:HasTag("mermguard")
                    local loyalty_max = isguard and TUNING.MERM_GUARD_LOYALTY_MAXTIME or TUNING.MERM_LOYALTY_MAXTIME
                    local loyalty_per_hunger = isguard and TUNING.MERM_GUARD_LOYALTY_PER_HUNGER or TUNING.MERM_LOYALTY_PER_HUNGER
                    if hasking then
                        loyalty_max = loyalty_max + TUNING.MERM_LOYALTY_MAXTIME_KINGBONUS
                        loyalty_per_hunger = loyalty_per_hunger + TUNING.MERM_LOYALTY_PER_HUNGER_KINGBONUS
                    end
                    local loyalty_count = (isguard and TUNING.MERM_GUARD_FOLLOWER_COUNT or TUNING.MERM_FOLLOWER_COUNT) + 1
                    v.components.follower.maxfollowtime = loyalty_max
                    v.components.follower:AddLoyaltyTime(loyalty_per_hunger * loyalty_count)
                    num = num - 1
                    if num <= 0 then break end
                end
            end
            if max and num ~= max and max - num > 1 then inst.components.hunger:DoDelta(-(max - num - 1) * 2) end
        end
    end
    AddPrefabPostInit("wurt", function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("oneat", OnEat)
        if inst.components.hunger then inst.components.hunger.delayoverflow2hm = true end
    end)
end

-- 沃特吃食物提高鱼人随从忠诚
if GetModConfigData("Wurt Eat Food Loyalty Follower") then
    local function OnEat(inst, data)
        if data.food ~= nil and data.food.components.edible and inst.components.leader then
            local num = 1
            local max
            if inst.components.hunger.current > 151 then
                max = 1 + math.floor((inst.components.hunger.current - 150) / 2)
                num = max
            end
            local hasking = TheWorld.components.mermkingmanager and TheWorld.components.mermkingmanager:HasKing() or false
            for follower, v in pairs(inst.components.leader.followers) do
                if follower:HasTag("merm") and not follower:HasTag("swc2hm") and follower.components.follower and
                        not follower.components.follower.neverexpire and follower.components.follower:GetLoyaltyPercent() < 0.3 then
                    local isguard = follower:HasTag("mermguard")
                    local loyalty_per_hunger = isguard and TUNING.MERM_GUARD_LOYALTY_PER_HUNGER or TUNING.MERM_LOYALTY_PER_HUNGER
                    if hasking then loyalty_per_hunger = loyalty_per_hunger + TUNING.MERM_LOYALTY_PER_HUNGER_KINGBONUS end
                    local loyalty_count = (isguard and TUNING.MERM_GUARD_FOLLOWER_COUNT or TUNING.MERM_FOLLOWER_COUNT) + 1
                    for i = 1, 3, 1 do
                        follower.components.follower:AddLoyaltyTime(loyalty_per_hunger * loyalty_count)
                        num = num - 1
                        if follower.components.follower:GetLoyaltyPercent() >= 0.3 or num <= 0 then break end
                    end
                    if num <= 0 then break end
                end
            end
            if max and num ~= max and max - num > 1 then inst.components.hunger:DoDelta(-(max - num - 1) * 2) end
        end
    end
    AddPrefabPostInit("wurt", function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("oneat", OnEat)
        if inst.components.hunger then inst.components.hunger.delayoverflow2hm = true end
    end)
end

-- 鱼人王不再饥饿
if GetModConfigData("Mermking Won't Hungry") then
    TUNING.MERM_KING_HUNGER_RATE = 0
    AddPrefabPostInit("mermking", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.hunger then inst.components.hunger:Pause() end
        inst:ListenForEvent("startstarving", function()
            if inst.components.hunger then
                inst.components.hunger:SetPercent(0.5)
                inst.components.hunger:Pause()
            end
        end)
    end)
end

-- -- 鱼人王世界共享
-- if GetModConfigData("Mermking Multi World Share") then
--     AddShardModRPCHandler("MOD_HARDMODE", "onmermkingcreated2hm", function(shard_id)
--         if not (TheWorld and TheWorld.components.mermkingmanager) then return end
--         if TheShard and tostring(TheShard:GetShardId()) ~= tostring(shard_id) then
--             local oldhas = TheWorld.components.mermkingmanager:HasKing()
--             TheWorld.components.mermkingmanager.otherworld2hm = TheWorld.components.mermkingmanager.otherworld2hm or {}
--             TheWorld.components.mermkingmanager.otherworld2hm[shard_id] = true
--             if not oldhas and TheWorld then
--                 TheWorld.rejectonmermkingcreated2hm = true
--                 TheWorld:PushEvent("onmermkingcreated", {})
--             end
--         end
--     end)
--     AddShardModRPCHandler("MOD_HARDMODE", "onmermkingdestroyed2hm", function(shard_id)
--         if not (TheWorld and TheWorld.components.mermkingmanager) then return end
--         if TheShard and tostring(TheShard:GetShardId()) ~= tostring(shard_id) then
--             local oldhas = TheWorld.components.mermkingmanager:HasKing()
--             TheWorld.components.mermkingmanager.otherworld2hm = TheWorld.components.mermkingmanager.otherworld2hm or {}
--             TheWorld.components.mermkingmanager.otherworld2hm[shard_id] = false
--             local nowhas = TheWorld.components.mermkingmanager:HasKing()
--             if oldhas and not nowhas then
--                 TheWorld.rejectonmermkingdestroyed2hm = true
--                 TheWorld:PushEvent("onmermkingdestroyed", {})
--             end
--         end
--     end)
--     local function refreshmermking(inst)
--         if inst.components.mermkingmanager:oldHasKing2hm() then
--             SendModRPCToShard(GetShardModRPC("MOD_HARDMODE", "onmermkingcreated2hm"), nil)
--             -- 额外多通知8次来保证其他世界通知得到,虽然并不必要
--             inst.refreshmermkingindex2hm = 0
--             if not inst.refreshmermkingtask2hm then
--                 inst.refreshmermkingtask2hm = inst:DoPeriodicTask(30, function()
--                     if inst.components.mermkingmanager:oldHasKing2hm() then
--                         SendModRPCToShard(GetShardModRPC("MOD_HARDMODE", "onmermkingcreated2hm"), nil)
--                         inst.refreshmermkingindex2hm = inst.refreshmermkingindex2hm + 1
--                         if inst.refreshmermkingindex2hm >= 8 then
--                             inst.refreshmermkingtask2hm:Cancel()
--                             inst.refreshmermkingtask2hm = nil
--                         end
--                     else
--                         inst.refreshmermkingtask2hm:Cancel()
--                         inst.refreshmermkingtask2hm = nil
--                     end
--                 end)
--             end
--         end
--     end
--     local function onmermkingcreated(inst)
--         if inst.rejectonmermkingcreated2hm then
--             inst.rejectonmermkingcreated2hm = nil
--             return
--         end
--         refreshmermking(inst)
--     end
--     local function onmermkingdestroyed(inst)
--         if inst.rejectonmermkingdestroyed2hm then
--             inst.rejectonmermkingdestroyed2hm = nil
--             return
--         end
--         if not inst.components.mermkingmanager:oldHasKing2hm() then SendModRPCToShard(GetShardModRPC("MOD_HARDMODE", "onmermkingdestroyed2hm"), nil) end
--     end
--     local function newHasKing(self, ...)
--         if self.oldHasKing2hm(self, ...) then return true end
--         if self.otherworld2hm then for _, has in pairs(self.otherworld2hm) do if has then return true end end end
--         return false
--     end
--     AddPrefabPostInit("world", function(inst)
--         if not inst.ismastersim then return inst end
--         if not inst.components.mermkingmanager then return end
--         inst.components.mermkingmanager.oldHasKing2hm = inst.components.mermkingmanager.HasKing
--         inst.components.mermkingmanager.HasKing = newHasKing
--         inst:ListenForEvent("onmermkingcreated", onmermkingcreated)
--         inst:ListenForEvent("onmermkingdestroyed", onmermkingdestroyed)
--         inst:ListenForEvent("migration_available", refreshmermking)
--     end)
-- end

-- 和普通鱼人交易鱼
if GetModConfigData("Trade Fish with Merm") then
    local trading_items = {
        {prefabs = {"kelp"}, min_count = 2, max_count = 4, reset = false, add_filler = false},
        {prefabs = {"kelp"}, min_count = 2, max_count = 3, reset = false, add_filler = false},
        {prefabs = {"seeds"}, min_count = 4, max_count = 6, reset = false, add_filler = false},
        {prefabs = {"tentaclespots"}, min_count = 1, max_count = 1, reset = false, add_filler = true},
        {prefabs = {"cutreeds"}, min_count = 1, max_count = 2, reset = false, add_filler = true},
        {
            prefabs = {
                -- These trinkets are generally good for team play, but tend to be poor for solo play.
                -- Theme
                "trinket_12", -- Dessicated Tentacle
                "trinket_25", -- Air Unfreshener
                -- Team
                "trinket_1", -- Melted Marbles
                -- Fishing
                "trinket_17", -- Bent Spork
                "trinket_8" -- Rubber Bung
            },
            min_count = 1,
            max_count = 1,
            reset = false,
            add_filler = true
        },
        {
            prefabs = {"durian_seeds", "pepper_seeds", "eggplant_seeds", "pumpkin_seeds", "onion_seeds", "garlic_seeds"},
            min_count = 1,
            max_count = 2,
            reset = false,
            add_filler = true
        }
    }
    local trading_filler = {"seeds", "kelp", "seeds", "seeds"}
    local function OnGivenItem(inst, giver, item)
        if giver.trading_items2hm == nil then giver.trading_items2hm = deepcopy(trading_items) end
        inst.SoundEmitter:PlaySound("dontstarve/common/researchmachine_science_gift_recieve")
        local selected_index = math.random(1, #giver.trading_items2hm)
        local selected_item = giver.trading_items2hm[selected_index]
        local isabigheavyfish = item.components.weighable and item.components.weighable:GetWeightPercent() >= TUNING.WEIGHABLE_HEAVY_WEIGHT_PERCENT or false
        local bigheavyreward = isabigheavyfish and math.random(1, 2) or 0
        local filler_min = 2 -- Not biasing minimum for filler.
        local filler_max = 4 + bigheavyreward
        local reward_count = math.random(selected_item.min_count, selected_item.max_count) + bigheavyreward
        for k = 1, reward_count do
            giver.components.inventory:GiveItem(SpawnPrefab(selected_item.prefabs[math.random(1, #selected_item.prefabs)]), nil, inst:GetPosition())
        end
        if selected_item.add_filler then
            for i = filler_min, filler_max do
                giver.components.inventory:GiveItem(SpawnPrefab(trading_filler[math.random(1, #trading_filler)]), nil, inst:GetPosition())
            end
        end
        if item:HasTag("oceanfish") then
            local goldmin, goldmax, goldprefab = 1, 2, "goldnugget"
            if item.prefab:find("oceanfish_medium_") == 1 then
                goldmin, goldmax = 2, 4
                if item.prefab == "oceanfish_medium_6_inv" or item.prefab == "oceanfish_medium_7_inv" then -- YoT events.
                    goldprefab = "lucky_goldnugget"
                end
            end
            local amt = math.random(goldmin, goldmax) + bigheavyreward
            for i = 1, amt do giver.components.inventory:GiveItem(SpawnPrefab(goldprefab), nil, inst:GetPosition()) end
        end
        -- Cycle out rewards.
        table.remove(giver.trading_items2hm, selected_index)
        if #giver.trading_items2hm == 0 or selected_item.reset then giver.trading_items2hm = deepcopy(trading_items) end
        item:Remove()
    end
    AddPrefabPostInit("merm", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.trader then
            inst.components.trader.acceptnontradable = true
            local test = inst.components.trader.test
            inst.components.trader:SetAcceptTest(function(inst, item, giver, ...)
                if not inst.rangeweapondata2hm and item.components.equippable ~= nil and item.components.equippable.equipslot == EQUIPSLOTS.HANDS and
                    (giver:HasTag("merm") or giver:HasTag("mermdisguise")) and not inst.components.combat:TargetIs(giver) then
                    if inst.components.sleeper and inst.components.sleeper:IsAsleep() then inst.components.sleeper:WakeUp() end
                    return true
                end
                return test and test(inst, item, giver, ...)
            end)
            local onaccept = inst.components.trader.onaccept
            inst.components.trader.onaccept = function(inst, giver, item, ...)
                if item.components.equippable ~= nil and item.components.equippable.equipslot == EQUIPSLOTS.HANDS then
                    local current = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                    if current ~= nil then inst.components.inventory:DropItem(current, true) end
                    inst.components.inventory:Equip(item)
                    return
                end
                if onaccept then onaccept(inst, giver, item, ...) end
                if (giver:HasTag("merm") or giver:HasTag("mermdisguise")) and item:HasTag("fish") and not inst.components.combat:TargetIs(giver) and
                    (inst.fishtradecycle2hm or 0) < TheWorld.state.cycles then
                    inst.fishtradecycle2hm = TheWorld.state.cycles
                    OnGivenItem(inst, giver, item)
                end
            end
        end
    end)
    AddStategraphPostInit("merm", function(sg)
        local oldOnEnterattack = sg.states.attack.onenter
        sg.states.attack.onenter = function(inst, ...)
            oldOnEnterattack(inst, ...)
            if inst.prefab == "merm" then
                local current = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                if current ~= nil then inst.AnimState:PlayAnimation("atk_object") end
            end
        end
    end)
end

-- 2025.3.16 melon: 鱼妹|沃特|wurt 可以吃肉但只有30%收益(抄的武神吃素)
if GetModConfigData("Wurt can eat any") then
    AddPrefabPostInit("wurt", function(inst)
        local function OnCustomStatsModFn(inst, health, hunger, sanity, food, feeder)
            if inst.components.hunger then
                inst.components.hunger.lasthunger = inst.components.hunger.current
            end
            -- 强制生效：肉食收益固定减半（无需配置）
            if food.components.edible.foodtype ~= FOODTYPE.VEGGIE and
                food.components.edible.foodtype ~= FOODTYPE.GOODIES then
                return health > 0 and health * 0.3 or health,
                        hunger > 0 and hunger * 0.3 or hunger,
                        sanity > 0 and sanity * 0.7 or sanity -- 2025.8.22 melon:正的70%收益,负的全收益
            end
            return health, hunger, sanity
        end
        if not TheWorld.ismastersim then return inst end
        if inst.components.eater ~= nil then
            -- 永久解锁全食谱
            inst.components.eater:SetDiet({FOODGROUP.OMNI}) -- 强制生效
            -- 永久绑定食物收益修正
            inst.components.eater.custom_stats_mod_fn = OnCustomStatsModFn
        end
    end)

    -- 海带盘永鲜
    local pots = {
        "offering_pot_upgraded",
        "offering_pot",
    }
    
    for i ,v in pairs(pots) do
        AddPrefabPostInit(v, function(inst)
            if not TheWorld.ismastersim then return inst end
            if inst.components.preserver == nil then inst:AddComponent("preserver") end
            if inst.components.preserver then
                inst.components.preserver:SetPerishRateMultiplier(0)
            end
        end)
    end

    AddReadBookRightSelfAction("wurt", "book_horticulture", 240, STRINGS.RECIPE_DESC.BOOK_HORTICULTURE)
end -- 2025.3.16 end

-- 鱼妹可制作鱼类之书(保留bookbuilder标签限制防止全员可做,仅对鱼妹放行book_fish一本)
if GetModConfigData("Wurt Can Craft Book Fish") then
    AddPrefabPostInit("wurt", function(inst)
        if not TheWorld.ismastersim then return end
        inst:DoTaskInTime(0, function(inst)
            if inst.components.builder then
                -- 让鱼妹学会这本书(加入已解锁列表,同步客户端制作栏)
                inst.components.builder:UnlockRecipe("book_fish")
                -- 放行KnowsRecipe的builder_tag检查(鱼妹没有bookbuilder标签)
                local oldKnowsRecipe = inst.components.builder.KnowsRecipe
                inst.components.builder.KnowsRecipe = function(self, recipe, ...)
                    if type(recipe) == "string" then recipe = GetValidRecipe(recipe) end
                    if recipe and recipe.name == "book_fish" then return true end
                    return oldKnowsRecipe(self, recipe, ...)
                end
                local oldCanLearn = inst.components.builder.CanLearn
                inst.components.builder.CanLearn = function(self, recname, ...)
                    if recname == "book_fish" then return true end
                    return oldCanLearn(self, recname, ...)
                end
            end
        end)
    end)
    -- 客户端replica放行(制作栏显示)
    AddClassPostConstruct("components/builder_replica", function(self)
        local oldKnowsRecipe = self.KnowsRecipe
        self.KnowsRecipe = function(self, recipe, ...)
            if type(recipe) == "string" then recipe = GetValidRecipe(recipe) end
            if recipe and recipe.name == "book_fish" and self.inst and self.inst.prefab == "wurt" then return true end
            return oldKnowsRecipe(self, recipe, ...)
        end
        local oldCanLearn = self.CanLearn
        self.CanLearn = function(self, recname, ...)
            if recname == "book_fish" and self.inst and self.inst.prefab == "wurt" then return true end
            return oldCanLearn(self, recname, ...)
        end
    end)
end

-- 怪物角色夜视开启时，保留鱼妹的夜晚理智效果。
if GetModConfigData("Monster Night Vision") then
    AddPrefabPostInit("wurt", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.sanity then inst.components.sanity.night_drain_mult = 0 end
    end)
end
