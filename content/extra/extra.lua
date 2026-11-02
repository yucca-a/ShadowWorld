local cache = {}
local function modconfigs(key, ...)
    if cache[key] == nil then cache[key] = GetModConfigData(key, ...) end
    return cache[key]
end

local function enddisableregentask(inst)
    inst:RemoveTag("disableregen2hm")
    inst.disableregen2hmtask = nil
end
local function healthregen(inst, self, v) if self and (not self:IsDead() and (self.minhealth and self.currenthealth and self.currenthealth > self.minhealth)) then self:DoDelta(v, true, "regen") end end
AddPrefabPostInitAny(function(inst)
    if not TheWorld.ismastersim or not inst.components or inst:HasTag("player") then return inst end
    if inst:HasTag("epic") or inst:HasTag("shadowchesspiece") or inst:HasTag("crabking") then
        if modconfigs("boss_speed") and inst.components.locomotor then
            inst.components.locomotor:SetExternalSpeedMultiplier(inst, "HappyPatchExtra", modconfigs("boss_speed"))
        end
        if modconfigs("boss_damage") and inst.components.combat then
            inst.components.combat.externaldamagemultipliers:SetModifier(inst, modconfigs("boss_damage"), "HappyPatchExtra")
        end
        if modconfigs("boss_damagetake") and inst.components.combat then
            inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, 1 - modconfigs("boss_damagetake"), "HappyPatchExtra")
        end
        if modconfigs("boss_maxdamagetake") and inst.components.health then
            inst.components.health:SetMaxDamageTakenPerHit(modconfigs("boss_maxdamagetake"))
        end
        if modconfigs("boss_healthregen") and inst.components.health then
            inst:DoPeriodicTask(1, healthregen, nil, inst.components.health, modconfigs("boss_healthregen"))
        end
        if modconfigs("boss_notenemyregen") and inst.components.health then
            inst:ListenForEvent("onhitother", function(inst, data)
                if data and data.target and not data.target:HasTag("epic") and not data.target:HasTag("shadowchesspiece") and not data.target:HasTag("crabking") then
                    if data.target.disableregen2hmtask then data.target.disableregen2hmtask:Cancel() end
                    data.target:AddTag("disableregen2hm")
                    data.target.disableregen2hmtask = data.target:DoTaskInTime(15, enddisableregentask)
                end
            end)
        end
    elseif not modconfigs("notboss_range") or inst:HasTag("hostile") then
        if modconfigs("notboss_speed") and inst.components.locomotor then
            inst.components.locomotor:SetExternalSpeedMultiplier(inst, "HappyPatchExtra", modconfigs("notboss_speed"))
        end
        if modconfigs("notboss_damage") and inst.components.combat then
            inst.components.combat.externaldamagemultipliers:SetModifier(inst, modconfigs("notboss_damage"), "HappyPatchExtra")
        end
        if modconfigs("notboss_damagetake") and inst.components.combat then
            inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, 1 - modconfigs("notboss_damagetake"), "HappyPatchExtra")
        end
        if modconfigs("notboss_maxdamagetake") and inst.components.health then
            inst.components.health:SetMaxDamageTakenPerHit(modconfigs("notboss_maxdamagetake"))
        end
        if modconfigs("notboss_healthregen") and inst.components.health then
            inst:DoPeriodicTask(1, healthregen, nil, inst.components.health, modconfigs("notboss_healthregen"))
        end
    end
end)

if modconfigs("boss_damagetake2") or modconfigs("notboss_damagetake2") or modconfigs("boss_notenemyregen") or modconfigs("boss_health") or
    modconfigs("notboss_health") then
    local damagetake2 = modconfigs("boss_damagetake2") or modconfigs("notboss_damagetake2") or modconfigs("boss_notenemyregen")
    local health2 = modconfigs("boss_health") or modconfigs("notboss_health")
    AddComponentPostInit("health", function(self)
        if damagetake2 then
            local oldDoDelta = self.DoDelta
            self.DoDelta = function(self, amount, ...)
                local inst = self.inst
                if modconfigs("boss_notenemyregen") and not inst:HasTag("epic") and inst:HasTag("disableregen2hm") and amount > 0 then amount = 0 end
                if self.inst:HasTag("player") then return oldDoDelta(self, amount, ...) end
                if inst:HasTag("epic") or inst:HasTag("shadowchesspiece") or inst:HasTag("crabking") then
                    if modconfigs("boss_damagetake2") and amount < 0 and not self._ignore_maxdamagetakenperhit then
                        return oldDoDelta(self, amount * (1 - modconfigs("boss_damagetake2")), ...)
                    end
                elseif not modconfigs("notboss_range") or inst:HasTag("hostile") then
                    if modconfigs("notboss_damagetake2") and amount < 0 and not self._ignore_maxdamagetakenperhit then
                        return oldDoDelta(self, amount * (1 - modconfigs("notboss_damagetake2")), ...)
                    end
                end
                return oldDoDelta(self, amount, ...)
            end
        end
        if health2 then
            if self.inst:HasTag("player") then return end
            local oldSetMaxHealth = self.SetMaxHealth
            self.SetMaxHealth = function(self, amount)
                local inst = self.inst
                if inst:HasTag("epic") or inst:HasTag("shadowchesspiece") or inst:HasTag("crabking") then
                    if modconfigs("boss_health") then return oldSetMaxHealth(self, amount * modconfigs("boss_health")) end
                elseif not modconfigs("notboss_range") or inst:HasTag("hostile") then
                    if modconfigs("notboss_health") then return oldSetMaxHealth(self, amount * modconfigs("notboss_health")) end
                end
                return oldSetMaxHealth(self, amount)
            end
        end
    end)
end

if modconfigs("boss_notfreezable") then
    AddComponentPostInit("freezable", function(self)
        if self.inst:HasTag("player") then return end
        local oldAddColdness = self.AddColdness
        self.AddColdness = function(self, ...)
            local inst = self.inst
            if inst:HasTag("epic") or inst:HasTag("shadowchesspiece") or inst:HasTag("crabking") then return end
            return oldAddColdness(self, ...)
        end
        local oldFreeze = self.Freeze
        self.Freeze = function(self, ...)
            local inst = self.inst
            if inst:HasTag("epic") or inst:HasTag("shadowchesspiece") or inst:HasTag("crabking") then
                self.coldness = 0
                self:UpdateTint()
                return
            end
            return oldFreeze(self, ...)
        end
    end)
end

if modconfigs("boss_notsleeper") then
    AddComponentPostInit("sleeper", function(self)
        if self.inst:HasTag("player") then return end
        local oldAddSleepiness = self.AddSleepiness
        self.AddSleepiness = function(self, ...)
            local inst = self.inst
            if inst:HasTag("epic") or inst:HasTag("shadowchesspiece") or inst:HasTag("crabking") then return end
            return oldAddSleepiness(self, ...)
        end
        local oldGoToSleep = self.GoToSleep
        self.GoToSleep = function(self, ...)
            local inst = self.inst
            if inst:HasTag("epic") or inst:HasTag("shadowchesspiece") or inst:HasTag("crabking") then
                self.sleepiness = 0
                return
            end
            return oldGoToSleep(self, ...)
        end
    end)
end

if modconfigs("boss_attackspeed") or modconfigs("boss_attackrange") or modconfigs("notboss_attackspeed") or modconfigs("notboss_attackrange") then
    if modconfigs("boss_attackrange") then TUNING.DEERCLOPS_ATTACK_RANGE = TUNING.DEERCLOPS_ATTACK_RANGE * modconfigs("boss_attackrange") end
    AddComponentPostInit("combat", function(self)
        if self.inst:HasTag("player") then return end
        local inst = self.inst
        if inst:HasTag("epic") or inst:HasTag("shadowchesspiece") or inst:HasTag("crabking") then
            if modconfigs("boss_attackspeed") then self.min_attack_period = self.min_attack_period / modconfigs("boss_attackspeed") end
            if modconfigs("boss_attackrange") and not inst:HasTag("deerclops") then
                self.attackrange = self.attackrange * modconfigs("boss_attackrange")
                self.hitrange = self.attackrange * modconfigs("boss_attackrange")
            end
        elseif not modconfigs("notboss_range") or inst:HasTag("hostile") then
            if modconfigs("notboss_attackspeed") then self.min_attack_period = self.min_attack_period / modconfigs("notboss_attackspeed") end
            if modconfigs("notboss_attackrange") then
                self.attackrange = self.attackrange * modconfigs("notboss_attackrange")
                self.hitrange = self.hitrange * modconfigs("notboss_attackrange")
            end
        end
        if modconfigs("boss_attackspeed") or modconfigs("notboss_attackspeed") then
            local oldSetAttackPeriod = self.SetAttackPeriod
            self.SetAttackPeriod = function(self, period, ...)
                local inst = self.inst
                if inst:HasTag("epic") or inst:HasTag("shadowchesspiece") or inst:HasTag("crabking") then
                    if modconfigs("boss_attackspeed") then
                        if period and type(period) == "table" then
                            local newperiod = {}
                            for index, value in pairs(period) do newperiod[index] = value and value / modconfigs("boss_attackspeed") end
                            return oldSetAttackPeriod(self, newperiod, ...)
                        else
                            return oldSetAttackPeriod(self, period and period / modconfigs("boss_attackspeed") or period, ...)
                        end
                    end
                elseif not modconfigs("notboss_range") or inst:HasTag("hostile") then
                    if modconfigs("notboss_attackspeed") then
                        if period and type(period) == "table" then
                            local newperiod = {}
                            for index, value in pairs(period) do
                                newperiod[index] = value and value / modconfigs("notboss_attackspeed")
                            end
                            return oldSetAttackPeriod(self, newperiod, ...)
                        else
                            return oldSetAttackPeriod(self, period and period / modconfigs("notboss_attackspeed") or period, ...)
                        end
                    end
                end
                return oldSetAttackPeriod(self, period, ...)
            end
        end
        if modconfigs("boss_attackrange") or modconfigs("notboss_attackrange") then
            local oldSetRange = self.SetRange
            self.SetRange = function(self, attack, hit, ...)
                local inst = self.inst
                if inst:HasTag("epic") or inst:HasTag("shadowchesspiece") or inst:HasTag("crabking") then
                    if modconfigs("boss_attackrange") then
                        return oldSetRange(self, attack and attack * modconfigs("boss_attackrange") or attack,
                                           hit and hit * modconfigs("boss_attackrange") or hit, ...)
                    end
                elseif not modconfigs("notboss_range") or inst:HasTag("hostile") then
                    if modconfigs("notboss_attackrange") then
                        return oldSetRange(self, attack and attack * modconfigs("notboss_attackrange") or attack,
                                           hit and hit * modconfigs("notboss_attackrange") or hit, ...)
                    end
                end
                return oldSetRange(self, attack, hit, ...)
            end
            local oldSetAreaDamage = self.SetAreaDamage
            self.SetAreaDamage = function(self, range, ...)
                local inst = self.inst
                if inst:HasTag("epic") or inst:HasTag("shadowchesspiece") or inst:HasTag("crabking") then
                    if modconfigs("boss_attackrange") then
                        return oldSetAreaDamage(self, range and range * modconfigs("boss_attackrange") or range, ...)
                    end
                elseif not modconfigs("notboss_range") or inst:HasTag("hostile") then
                    if modconfigs("notboss_attackrange") then
                        return oldSetAreaDamage(self, range and range * modconfigs("notboss_attackrange") or range, ...)
                    end
                end
                return oldSetAreaDamage(self, range, ...)
            end
        end
    end)
end
if modconfigs("boss_ocean") or modconfigs("notboss_ocean") then
    AddPrefabPostInitAny(function(inst)
        if inst:HasTag("player") or not inst.Physics or not TheWorld.has_ocean then return end
        if inst:HasTag("epic") or inst:HasTag("shadowchesspiece") or inst:HasTag("crabking") then
            if modconfigs("boss_ocean") then
                RemovePhysicsColliders(inst)
                if inst.components.drownable then inst.components.drownable.ShouldDrown = falsefn end
                if inst.components.inventoryitem then inst.components.inventoryitem:SetSinks(false) end
            end
        elseif not modconfigs("notboss_range") or inst:HasTag("hostile") then
            if modconfigs("notboss_ocean") then
                RemovePhysicsColliders(inst)
                if inst.components.drownable then inst.components.drownable.ShouldDrown = falsefn end
                if inst.components.inventoryitem then inst.components.inventoryitem:SetSinks(false) end
            end
        end
    end)
end

-- ==================== Boss 掉落物随血量增加 ====================
local boss_health_cfg = modconfigs("boss_health")
if boss_health_cfg and boss_health_cfg > 1 then
    local loot_mult = 1 + (boss_health_cfg - 1) / 2

    local function ExtraRoll(mult)
        local whole, frac = math.floor(mult), mult - math.floor(mult)
        return whole + ((frac > 0 and math.random() < frac) and 1 or 0)
    end

    -- 织影者和他的几个变体
    -- 死亡掉落的化石碎片和暗影心房不参与多倍,保持原版数量
    local STALKER_NOMULT2HM = { fossil_piece = true, shadowheart = true }

    -- 通用 Boss 掉落
    AddComponentPostInit("lootdropper", function(self)
        local old_Spawn = self.SpawnLootPrefab
        self.SpawnLootPrefab = function(self, lootprefab, pt, skin, sid, uid)
            if not (self.inst and self.inst:HasTag("epic")) then
                return old_Spawn(self, lootprefab, pt, skin, sid, uid)
            end
            old_Spawn(self, lootprefab, pt, skin, sid, uid)
            -- 织影者家族的化石碎片/暗影心房只掉一个,不翻倍
            if self.inst:HasTag("stalker") and STALKER_NOMULT2HM[lootprefab] then
                return
            end
            for _ = 1, ExtraRoll(loot_mult - 1) do
                old_Spawn(self, lootprefab, pt, skin, sid, uid)
            end
        end
    end)

    -- 克劳斯赃物袋:里面的包裹(礼物包)随血量翻倍
    AddComponentPostInit("klaussackloot", function(self)
        local old_GetLoot = self.GetLoot
        self.GetLoot = function(self, ...)
            local loot = old_GetLoot(self, ...)
            if loot == nil then return loot end
            local final = {}
            for _, bundle in ipairs(loot) do
                table.insert(final, bundle)
                for _ = 1, ExtraRoll(loot_mult - 1) do
                    local copy = {}
                    for _, v in ipairs(bundle) do
                        if type(v) == "table" then
                            table.insert(copy, { v[1], v[2] })
                        else
                            table.insert(copy, v)
                        end
                    end
                    table.insert(final, copy)
                end
            end
            return final
        end
    end)

    -- 远古宝箱(minotaurchest):物品随血量翻倍,溢出的物品再生成一个箱子装
    local function ChestOverflowFX2hm(chest)
        local x, y, z = chest.Transform:GetWorldPosition()
        if chest.SoundEmitter ~= nil then
            chest.SoundEmitter:PlaySound("dontstarve/common/ghost_spawn")
        end
        local fx = SpawnPrefab("statue_transition_2")
        if fx ~= nil then
            fx.Transform:SetPosition(x, y, z)
            fx.Transform:SetScale(1, 2, 1)
        end
        fx = SpawnPrefab("statue_transition")
        if fx ~= nil then
            fx.Transform:SetPosition(x, y, z)
            fx.Transform:SetScale(1, 1.5, 1)
        end
    end

    local function FillChest2hm(chest, item, depth)
        if item == nil or chest == nil or not chest:IsValid() then return end
        if chest.components.container ~= nil and chest.components.container:GiveItem(item) then
            return
        end
        depth = (depth or 0) + 1
        if depth > 8 then
            -- 兜底:实在放不下就丢在主箱子位置地上
            item.Transform:SetPosition(chest.Transform:GetWorldPosition())
            return
        end
        local overflow = chest.overflow2hm
        if overflow == nil or not overflow:IsValid() or overflow.components.container == nil then
            local x, y, z = chest.Transform:GetWorldPosition()
            overflow = SpawnPrefab("minotaurchest")
            if overflow ~= nil then
                overflow.Transform:SetPosition(x + 2.5, 0, z)
                overflow.lootmult2hm = true -- 溢出箱本身不再翻倍
                chest.overflow2hm = overflow
                ChestOverflowFX2hm(overflow)
            end
        end
        FillChest2hm(overflow, item, depth)
    end

    AddPrefabPostInit("minotaurchest", function(inst)
        if not TheWorld.ismastersim then return end
        -- 翻倍只做一次:存盘标记,防止重进游戏或玩家拿放时重复翻倍
        SetOnSave(inst, function(inst, data)
            if data ~= nil and inst.lootmult2hm then data.lootmult2hm = true end
        end)
        SetOnLoad(inst, function(inst, data)
            if data ~= nil and data.lootmult2hm then inst.lootmult2hm = true end
        end)
        inst:DoTaskInTime(0, function(inst)
            if not inst:IsValid() or inst.components.container == nil then return end
            if inst.lootmult2hm then return end
            inst.lootmult2hm = true
            -- 本mod自带的"限制收益"监听 stacksizechange,复制品与原有堆叠合并会被当成"拿取"而扣额度,
            -- 导致原有物品被提前删除。翻倍期间先把记录表摘下来、复制完再挂回去:
            -- 这样合并不占用玩家那5个拿取额度,箱子自带的限制保持原样(玩家开箱拿取时才生效)。
            local savedrecords2hm = inst.recorditems2hm
            inst.recorditems2hm = nil
            -- 记录原本就在箱子里的物品(不含钥匙)
            local items = inst.components.container:FindItems(function(item)
                return item.prefab ~= "atrium_key"
            end)
            for _, item in ipairs(items) do
                local stack = item.components.stackable ~= nil and item.components.stackable:StackSize() or 1
                for _ = 1, ExtraRoll(loot_mult - 1) do
                    local copy = SpawnPrefab(item.prefab)
                    if copy ~= nil then
                        if copy.components.stackable ~= nil then
                            copy.components.stackable:SetStackSize(stack)
                        end
                        FillChest2hm(inst, copy)
                    end
                end
            end
            inst.recorditems2hm = savedrecords2hm
        end)
    end)

    -- 飞翼掉羽毛
    AddPrefabPostInit("malbatross", function(inst)
        inst:DoTaskInTime(0, function(inst)
            if not inst:IsValid() or not inst.spawnfeather then return end
            local old_Spawn = inst.spawnfeather
            inst.spawnfeather = function(inst, time)
                old_Spawn(inst, time)
                for _ = 1, ExtraRoll(loot_mult - 1) do old_Spawn(inst, time) end
            end
        end)
    end)

    -- 蠕虫Boss
    local function patchWorm(inst)
        inst:DoTaskInTime(0, function(inst)
            if not inst:IsValid() or not inst.components.lootdropper then return end
            local old_Fling = inst.components.lootdropper.FlingItem
            inst.components.lootdropper.FlingItem = function(self, item, ...)
                old_Fling(self, item, ...)
                if item and item.prefab then
                    for _ = 1, ExtraRoll(loot_mult - 1) do
                        local c = SpawnPrefab(item.prefab)
                        if c then old_Fling(self, c, ...) end
                    end
                end
            end
        end)
    end
    AddPrefabPostInit("worm_boss", patchWorm)
    AddPrefabPostInit("worm_boss_segment", patchWorm)
end
