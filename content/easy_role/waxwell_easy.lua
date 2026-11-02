local hardmode = TUNING.hardmode2hm and GetModConfigData("role_nerf")

-- 麦斯威尔正常血量
if GetModConfigData("Maxwell Normal Health") then TUNING.WAXWELL_HEALTH = TUNING.WILSON_HEALTH end

-- 麦斯威尔吃花瓣获得恶魔花瓣
if GetModConfigData("Maxwell Eat Petals Get Dark Petals") then
    local function OnEat(inst, data)
        if data.food ~= nil and data.food.prefab == "petals" then inst.components.inventory:GiveItem(SpawnPrefab("petals_evil")) end
    end
    local function unlockrecipes(inst)
        if inst.components.builder then
            if not inst.components.builder:KnowsRecipe("nightmarefuel") and inst.components.builder:CanLearn("nightmarefuel") then
                inst.components.builder:UnlockRecipe("nightmarefuel")
            end
        end
    end
    AddPrefabPostInit("waxwell", function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("oneat", OnEat)
        inst:DoTaskInTime(0, unlockrecipes)
    end)
end

-- 麦斯威尔右键倒走
if GetModConfigData("Maxwell Right Wrapback") and false then
    AddPrefabPostInit("waxwell", function(inst)
        AddWrapAbility(inst)
        inst.rightaction2hm_cooldown = GetModConfigData("Maxwell Right Wrapback")
    end)
end

-- 麦斯威尔解锁暗影剑甲
if GetModConfigData("Maxwell Unlock Dark Sword/Armor") then
    -- table.insert(TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT.WAXWELL, "nightsword")
    -- table.insert(TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT.WAXWELL, "armor_sanity")
    local function unlockrecipes(inst)
        if inst.components.builder then
            if not inst.components.builder:KnowsRecipe("nightsword") and inst.components.builder:CanLearn("nightsword") then
                inst.components.builder:UnlockRecipe("nightsword")
            end
            if not inst.components.builder:KnowsRecipe("armor_sanity") and inst.components.builder:CanLearn("armor_sanity") then
                inst.components.builder:UnlockRecipe("armor_sanity")
            end
        end
    end
    AddPrefabPostInit("waxwell", function(inst)
        if not TheWorld.ismastersim then return end
        inst:DoTaskInTime(0, unlockrecipes)
    end)
end

-- 麦斯威尔右键闪袭,攻击闪烁
if GetModConfigData("Maxwell Right Lunge") or GetModConfigData("Maxwell Attacked Disappear") then
    local canlunge = GetModConfigData("Maxwell Right Lunge")
    local candisappear = GetModConfigData("Maxwell Attacked Disappear")
    local function checklevel(inst)
        if inst.shadowlungeendfn2hm then inst.shadowlungeendfn2hm = nil end
        local level = 0
        for k, v in pairs(EQUIPSLOTS) do
            local equip = inst.components.inventory:GetEquippedItem(v)
            if equip ~= nil and equip.components.shadowlevel ~= nil then level = level + equip.components.shadowlevel:GetCurrentLevel() end
        end
        inst.shadowlevel2hm = level
        if canlunge then
            if inst.shadowlungecdtask2hm then
                inst.shadowlungeendfn2hm = checklevel
            elseif level >= 4 then
                if not inst:HasTag("shadowlunge2hm") then inst:AddTag("shadowlunge2hm") end
            elseif inst:HasTag("shadowlunge2hm") then
                inst:RemoveTag("shadowlunge2hm")
            end
        end
    end
    local function NotBlocked(pt) return not TheWorld.Map:IsGroundTargetBlocked(pt) end
    local function onattacked(inst, data)
        if inst.components.rider and inst.components.rider:GetMount() ~= nil then return end
        if inst.shadowlevel2hm < 4 or inst.disappeartask2hm or inst.allmiss2hm then return end
        SpawnPrefab("shadow_puff").Transform:SetPosition(inst.Transform:GetWorldPosition())
        inst.disappeartask2hm = inst:DoTaskInTime(math.max(20 - inst.shadowlevel2hm * 2, 4), function() inst.disappeartask2hm = nil end)
        if inst.randomdisappear2hm then -- 2025.10.7 melon:randomdisappear2hm才随机闪烁，否则原地
            local attackerpos = data and data.attacker and data.attacker:GetPosition()
            local theta = attackerpos ~= nil and inst:GetAngleToPoint(attackerpos) or inst.Transform:GetRotation()
            theta = (theta + 165 + math.random() * 30) * DEGREES
            local pos = inst:GetPosition()
            pos.y = 0
            local offs = FindWalkableOffset(pos, theta, 4 + math.random(12), 8, false, true, NotBlocked, false, true) or
                            FindWalkableOffset(pos, theta, 2 + math.random(4), 6, false, true, NotBlocked, false, true)
            if offs ~= nil then
                pos.x = pos.x + offs.x
                pos.z = pos.z + offs.z
            end
            inst.Physics:Teleport(pos:Get())
            if attackerpos ~= nil then inst:ForceFacePoint(attackerpos) end
        end
        -- inst:DoTaskInTime(0, function() inst:PushEvent("transfercombattarget") end)
        SpawnPrefab("shadow_puff").Transform:SetPosition(inst.Transform:GetWorldPosition())
    end
    local function GetAttacked_Internal(inst, data)
        if inst.components.rider and inst.components.rider:GetMount() ~= nil then return end
        if inst.shadowlevel2hm < 4 or inst.disappeartask2hm or inst.allmiss2hm then return end
        if math.random() < 0.25 then
            inst.oncemiss2hm = true
            onattacked(inst, data)
        end
    end
    AddPrefabPostInit("waxwell", function(inst)
        if canlunge then AddLungeAbility(inst) end
        if not TheWorld.ismastersim then return end
        inst.shadowlevel2hm = 0
        inst:ListenForEvent("equip", checklevel)
        inst:ListenForEvent("unequip", checklevel)
        if candisappear then
            inst:ListenForEvent("GetAttacked_Internal2hm", GetAttacked_Internal)
            inst:ListenForEvent("attacked", onattacked)
        end
        inst.randomdisappear2hm = true -- 2025.10.7 melon:默认随机闪烁
    end)
    -- 2025.10.7 melon:戴魔法帽切换原地闪烁/随机闪烁
    local function onequip_tophat(inst, data)
        if data.owner and data.owner:IsValid() and data.owner.prefab == "waxwell" and inst:HasTag("shadow_item") then
            data.owner.randomdisappear2hm = not data.owner.randomdisappear2hm
            if data.owner.components.talker then
                data.owner.components.talker:Say((TUNING.isCh2hm and (data.owner.randomdisappear2hm and "随机闪烁" or "原地闪烁") or (data.owner.randomdisappear2hm and  "random disappear" or "disappear in place")), 1, true) -- 显示1秒
            end
        end
    end
    AddPrefabPostInit("tophat", function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("equipped", onequip_tophat)
    end)
end

-- 麦斯威尔右键自身睡前故事
if GetModConfigData("Maxwell Right Self Sleepytime Stories") then
    AddReadBookRightSelfAction("waxwell", "book_sleep", GetModConfigData("Maxwell Right Self Sleepytime Stories"),
                               STRINGS.CHARACTERS.WAXWELL.DESCRIBE.BIRDCAGE.SLEEPING)
end