local hardmode = TUNING.hardmode2hm and GetModConfigData("role_nerf")

-- 威尔逊一本
if GetModConfigData("Wilson 1 Science Bonus") then
    AddPrefabPostInit("wilson", function(inst)
        if not TheWorld.ismastersim then return end
        inst.components.builder.science_bonus = 1
    end)
end

-- 威尔逊二本
if GetModConfigData("Wilson 2 Science Bonus") and false then
    AddPrefabPostInit("wilson", function(inst)
        if not TheWorld.ismastersim then return end
        inst.components.builder.science_bonus = 2
    end)
end

-- 威尔逊右键冲刺且只有1秒CD
if GetModConfigData("Wilson Right Dodge") then
    local cd = GetModConfigData("Wilson Right Dodge")
    cd = cd == true and 1 or cd
    AddPrefabPostInit("wilson", function(inst)
        AddDodgeAbility(inst)
        inst.rightaction2hm_cooldown = cd
    end)
end

-- 威尔逊右键科技书
if GetModConfigData("Wilson Right Self Everything Encyclopedia") then
    local cd = GetModConfigData("Wilson Right Self Everything Encyclopedia")
    cd = cd == true and 30 or cd
    AddReadBookRightSelfAction("wilson", "book_research_station", cd, STRINGS.RECIPE_DESC.BOOK_RESEARCH_STATION)
    STRINGS.CHARACTERS.GENERIC.ACTIONFAIL.RIGHTSELFACTION2HM = STRINGS.CHARACTERS.GENERIC.ACTIONFAIL_GENERIC
end

-- 威尔逊科技增强:解锁制作特定原型机 + 世界天数门槛后获得增强
-- 科学机器(一本)世界天数>10 +20%攻击/炼金引擎(二本)世界天数>30 -20%承伤/灵子分解器(魔法一本)世界天数>50 +20%移速
-- 暗影操作器(魔法二本)世界天数>70 攻击召唤暗影分身/暗影术基座世界天数>90 +10位面伤害+10位面防御
-- 辉煌制作台世界天数>110 攻击附带月灵(22.5伤害)，这个数值貌似不高不低吧，也就一百多天后，威尔逊每次攻击多40伤害左右。
if GetModConfigData("Wilson Tech Bonus") then
    local WILSON_SHADOW_DAMAGE = 11
    local WILSON_SHADOW_COUNT = 5 -- 每次触发生成5个分身
    local WILSON_SHADOW_DISTANCE = 5
    local WILSON_SHADOW_THRESHOLD = 5 -- 每5次命中触发一次分身风暴
    -- 暗影分身:命中次数达标后生成暗影分身冲撞目标
    local function WilsonShadowHit(inst, data)
        if not (inst._wilsontch4hm and data and data.target and data.target:IsValid()) then return end
        -- 排除AoE施法触发
        if data.weapon and data.weapon.components.aoespell and data.weapon.components.aoespell.casting then return end
        if inst.components.rider and inst.components.rider:IsRiding() then return end
        local count = (inst._wilsonhitcount2hm or 0) + 1
        if count < WILSON_SHADOW_THRESHOLD then
            inst._wilsonhitcount2hm = count
            return
        end
        inst._wilsonhitcount2hm = 0
        local target = data.target
        local angle = math.random() * 2 * math.pi
        for i = 1, WILSON_SHADOW_COUNT do
            inst:DoTaskInTime(0.1 * i, function()
                if target and target:IsValid() then
                    local shadow_fx = SpawnPrefab("passive_shadow_fx2hm")
                    if shadow_fx then
                        if inst:HasTag("player") and shadow_fx.components.skinner then
                            shadow_fx.components.skinner:CopySkinsFromPlayer(inst)
                        end
                        shadow_fx:SetDamage(WILSON_SHADOW_DAMAGE)
                        local a = angle + (2 * math.pi / WILSON_SHADOW_COUNT) * i
                        shadow_fx:SetTarget(target, Vector3(WILSON_SHADOW_DISTANCE * math.sin(a), 0, WILSON_SHADOW_DISTANCE * math.cos(a)))
                    end
                end
            end)
        end
    end
    -- 辉煌制作台:攻击附带月灵(22.5伤害)
    local function WilsonMoonHit(inst, data)
        if not (inst._wilsontch6hm and data and data.target and data.target:IsValid()) then return end
        if inst.components.rider and inst.components.rider:IsRiding() then return end
        local target = data.target
        if target.components.health and target.components.health:IsDead() then return end
        if target:HasTag("structure") or target:HasTag("wall") then return end
        -- 月灵从目标身边出现,再攻击目标
        local x, y, z = target.Transform:GetWorldPosition()
        local gestalt = SpawnPrefab("alterguardianhat_projectile")
        if gestalt then
            local r = GetRandomMinMax(3, 5)
            local delta_angle = GetRandomMinMax(-90, 90)
            local angle = (inst:GetAngleToPoint(x, y, z) + delta_angle) * DEGREES
            gestalt.Transform:SetPosition(x + r * math.cos(angle), y, z + r * -math.sin(angle))
            gestalt:ForceFacePoint(x, y, z)
            if gestalt.SetTargetPosition then
                gestalt:SetTargetPosition(Vector3(x, y, z))
            end
            if gestalt.components.follower then
                gestalt.components.follower:SetLeader(inst)
            end
            if gestalt.components.combat then
                gestalt.components.combat:SetDefaultDamage(22.5)
            end
        end
    end
    local function updatewilsontchbuff(inst)
        local tdata = inst.components.persistent2hm and inst.components.persistent2hm.data
        if not tdata then return end
        local sci = tdata.wilsonsci2hm or 0
        local mag = tdata.wilsontmagic2hm or 0
        local day = TheWorld.state and TheWorld.state.cycles or 0 
        -- 科学机器(科技一本):世界天数>10(即第11天起)+10%攻击
        if sci >= 1 and day >= 10 then
            if not inst._wilsontch1hm and inst.components.combat then
                inst._wilsontch1hm = true
                inst.components.combat.externaldamagemultipliers:SetModifier(inst, 1.10, "wilsontch1hm")
            end
        elseif inst._wilsontch1hm then
            inst._wilsontch1hm = nil
            if inst.components.combat then inst.components.combat.externaldamagemultipliers:RemoveModifier(inst, "wilsontch1hm") end
        end
        -- 炼金引擎(科技二本):世界天数>30 -10%承伤
        if sci >= 2 and day >= 30 then
            if not inst._wilsontch2hm and inst.components.combat then
                inst._wilsontch2hm = true
                inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, 0.90, "wilsontch2hm")
            end
        elseif inst._wilsontch2hm then
            inst._wilsontch2hm = nil
            if inst.components.combat then inst.components.combat.externaldamagetakenmultipliers:RemoveModifier(inst, "wilsontch2hm") end
        end
        -- 灵子分解器(魔法一本):世界天数>50 +15%移速
        if mag >= 2 and day >= 50 then
            if not inst._wilsontch3hm and inst.components.playerspeedmult then
                inst._wilsontch3hm = true
                inst.components.playerspeedmult:SetPredictedSpeedMult("wilsontch3hm", 1.2)
            end
        elseif inst._wilsontch3hm then
            inst._wilsontch3hm = nil
            if inst.components.playerspeedmult then inst.components.playerspeedmult:RemovePredictedSpeedMult("wilsontch3hm") end
        end
        -- 暗影操作器(魔法二本):世界天数>70 攻击召唤暗影分身
        if mag >= 3 and day >= 70 then
            if not inst._wilsontch4hm then
                inst._wilsontch4hm = true
                inst._wilsonhitcount2hm = 0
                inst:ListenForEvent("onhitother", WilsonShadowHit)
            end
        elseif inst._wilsontch4hm then
            inst._wilsontch4hm = nil
            inst:RemoveEventCallback("onhitother", WilsonShadowHit)
        end
        -- 暗影术基座:世界天数>90 +10位面伤害 +10位面防御
        if tdata.wilsonshadowforge2hm and day >= 90 then
            if not inst._wilsontch5hm then
                inst._wilsontch5hm = true
                if inst.components.planardamage then
                    inst.components.planardamage:AddBonus(inst, 10, "wilsontch5hm")
                end
                if inst.components.planardefense then
                    inst.components.planardefense:AddBonus(inst, 10, "wilsontch5hm")
                end
            end
        elseif inst._wilsontch5hm then
            inst._wilsontch5hm = nil
            if inst.components.planardamage then
                inst.components.planardamage:RemoveBonus(inst, "wilsontch5hm")
            end
            if inst.components.planardefense then
                inst.components.planardefense:RemoveBonus(inst, "wilsontch5hm")
            end
        end
        -- 辉煌制作台:世界天数>110 攻击附带月灵(22.5伤害)
        if tdata.wilsonlunarforge2hm and day >= 110 then
            if not inst._wilsontch6hm then
                inst._wilsontch6hm = true
                inst:ListenForEvent("onhitother", WilsonMoonHit)
            end
        elseif inst._wilsontch6hm then
            inst._wilsontch6hm = nil
            inst:RemoveEventCallback("onhitother", WilsonMoonHit)
        end
    end
    local function refreshtech(inst)
        local tdata = inst.components.persistent2hm and inst.components.persistent2hm.data
        if not tdata then return end
        local sci, mag = 1, 0 -- 科学机器开局可做,一本视为已解锁
        if inst.components.builder then
            for _, recname in ipairs(inst.components.builder.recipes) do
                if recname == "researchlab2" then
                    sci = math.max(sci, 2)
                elseif recname == "researchlab4" then
                    mag = math.max(mag, 2)
                elseif recname == "researchlab3" then
                    mag = math.max(mag, 3)
                end
            end
        end
        tdata.wilsonsci2hm, tdata.wilsontmagic2hm = sci, mag
        -- 如果世界存在对应站实体说明曾制作过
        if not tdata.wilsonshadowforge2hm or not tdata.wilsonlunarforge2hm then
            for _, ent in pairs(Ents) do
                if ent and ent:IsValid() then
                    if ent.prefab == "shadow_forge" and not tdata.wilsonshadowforge2hm then
                        tdata.wilsonshadowforge2hm = true
                    elseif ent.prefab == "lunar_forge" and not tdata.wilsonlunarforge2hm then
                        tdata.wilsonlunarforge2hm = true
                    end
                    if tdata.wilsonshadowforge2hm and tdata.wilsonlunarforge2hm then break end
                end
            end
        end
        updatewilsontchbuff(inst)
    end
    local function onunlockrecipe(inst, data)
        local recname = data and data.recipe
        if recname == "researchlab2" or recname == "researchlab4" or recname == "researchlab3" then
            refreshtech(inst)
        end
    end
    AddPrefabPostInit("wilson", function(inst)
        if not TheWorld.ismastersim then return end
        if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
        inst:ListenForEvent("unlockrecipe", onunlockrecipe)
        -- 搓过对应kit永久标记
        inst:ListenForEvent("builditem", function(inst2, data)
            if data and data.item then
                local tdata = inst2.components.persistent2hm and inst2.components.persistent2hm.data
                if tdata then
                    if data.item.prefab == "shadow_forge_kit" and not tdata.wilsonshadowforge2hm then
                        tdata.wilsonshadowforge2hm = true
                        updatewilsontchbuff(inst2)
                    elseif data.item.prefab == "lunar_forge_kit" and not tdata.wilsonlunarforge2hm then
                        tdata.wilsonlunarforge2hm = true
                        updatewilsontchbuff(inst2)
                    end
                end
            end
        end)
        inst:ListenForEvent("ms_respawnedfromghost", function() inst:DoTaskInTime(0, refreshtech) end)
        inst:DoTaskInTime(0, refreshtech) -- 加载/复活后初始化
        -- 跨天刷新
        if not TheWorld._wilsontchday2hm then
            TheWorld._wilsontchday2hm = true
            TheWorld:ListenForEvent("cycleschanged", function()
                for _, p in ipairs(AllPlayers) do
                    if p and p:IsValid() and p.prefab == "wilson" then refreshtech(p) end
                end
            end)
        end
    end)
end