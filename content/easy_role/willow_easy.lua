local hardmode = TUNING.hardmode2hm and GetModConfigData("role_nerf") and GetModConfigData("willow")

-- 薇洛攻击干燥和燃烧的敌人伤害提升,且刷新狂热焚烧BUFF
if GetModConfigData("Willow Attack Dry/Burning Enemy") then
    -- local function cancelfirefrenzyindex(inst)
    --     inst.firefrenzyindextask2hm = nil
    --     inst.firefrenzyindex2hm = nil
    -- end
    local function CustomCombatDamage(inst, target, weapon, multiplier, mount)
        if inst:HasTag("firefrenzy") then
            inst:AddDebuff("buff_firefrenzy", "buff_firefrenzy")
            if mount or not (target and target:IsValid()) or target:GetIsWet() or (target.components.freezable and target.components.freezable:IsFrozen()) then
                return (target and target:IsValid() and target.components.burnable and target.components.burnable:IsBurning()) and (hardmode and 0.8 or 1) or
                           (hardmode and 1 or 1.25)
            end
            if target:HasTag("fire") or target:HasTag("burnt") or (target.components.burnable and target.components.burnable:IsBurning()) then
                return (target.components.burnable and target.components.burnable:IsBurning()) and (hardmode and 1.2 or 2) or (hardmode and 1.5 or 2.5)
            end
            return (target.components.burnable and target.components.burnable:IsBurning()) and (hardmode and 1 or 1.2) or (hardmode and 1.25 or 1.5)
        else
            -- inst.firefrenzyindex2hm = (inst.firefrenzyindex2hm or 0) + 1
            -- if inst.firefrenzyindex2hm >= 10 then
            --     inst:AddDebuff("buff_firefrenzy", "buff_firefrenzy")
            --     inst.firefrenzyindex2hm = nil
            --     if inst.firefrenzyindextask2hm then
            --         inst.firefrenzyindextask2hm:Cancel()
            --         inst.firefrenzyindextask2hm = nil
            --     end
            -- else
            --     if inst.firefrenzyindextask2hm then inst.firefrenzyindextask2hm:Cancel() end
            --     inst.firefrenzyindextask2hm = inst:DoTaskInTime(3, cancelfirefrenzyindex)
            -- end
            -- if mount or not (target and target:IsValid()) or target:GetIsWet() or (target.components.freezable and target.components.freezable:IsFrozen()) then return 1 end -- 2025.9.21 melon:换为下面
            if not (target and target:IsValid()) or target:GetIsWet() or (target.components.freezable and target.components.freezable:IsFrozen()) then
                return 1
            end
            if target:HasTag("fire") or target:HasTag("burnt") or (target.components.burnable and target.components.burnable:IsBurning()) then
                if mount then return hardmode and 1.1 or 1.2 end -- 2025.9.21 melon:增加骑牛1.1倍率
                return hardmode and 1.25 or 2.5
            end
            return hardmode and 1 or 1.5
        end
    end
    AddPrefabPostInit("willow", function(inst)
        if not TheWorld.ismastersim then return end
        if not inst.components.combat.customdamagemultfn then
            inst.components.combat.customdamagemultfn = CustomCombatDamage
        else
            local old = inst.components.combat.customdamagemultfn
            inst.components.combat.customdamagemultfn = function(...) return (old(...) or 1) * CustomCombatDamage(...) end
        end
    end)
    local function RefreshDebuff(inst)
        if inst.fire_thorns_task then
            local fn = inst.fire_thorns_task.fn
            inst.fire_thorns_task:Cancel()
            inst.fire_thorns_task = inst:DoTaskInTime(20, fn)
        end
    end
    AddPrefabPostInit("bernie_big", function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("onhitother", RefreshDebuff)
    end)
    AddPrefabPostInit("willow_frenzy", function(inst)
        if not TheWorld.ismastersim then return end
        inst.light2hm = SpawnPrefab("firefx_light")
        inst.light2hm.entity:SetParent(inst.entity)
        inst.light2hm.Light:SetRadius(1)
        inst.light2hm.Light:SetIntensity(.8)
        inst.light2hm.Light:SetFalloff(.33)
        inst.light2hm.Light:SetColour(253 / 255, 179 / 255, 179 / 255)
    end)
end

-- 薇洛击败燃烧敌人正常掉落
if GetModConfigData("Willow Normal Kill Burning Enemy") and false then
    AddComponentPostInit("lootdropper", function(self)
        local oldDropLoot = self.DropLoot
        self.DropLoot = function(self, ...)
            local removeburnttag
            local oldburningfn
            if self.inst ~= nil then
                if self.inst.willow_burnt_loot_task ~= nil and self.inst:HasTag("burnt") then
                    self.inst:RemoveTag("burnt")
                    removeburnttag = true
                end
            end
            if self.inst.components.burnable ~= nil and self.inst.components.burnable:IsBurning() and
                (self.inst.components.fueled == nil or self.inst.components.burnable.ignorefuel) and not self.inst.components.burnable:GetControlledBurn() then
                oldburningfn = self.inst.components.burnable.IsBurning
                self.inst.components.burnable.IsBurning = falsefn
            end
            oldDropLoot(self, ...)
            if removeburnttag then self.inst:AddTag("burnt") end
            if oldburningfn then self.inst.components.burnable.IsBurning = oldburningfn end
        end
    end)
    local function ApplyDebuff(inst, data)
        local target = data ~= nil and data.target
        if target ~= nil and data.target:HasTag("burnt") then
            if target.willow_burnt_loot_task ~= nil then target.willow_burnt_loot_task:Cancel() end
            target.willow_burnt_loot_task = target:DoTaskInTime(30, function()
                if target.willow_burnt_loot_task ~= nil then target.willow_burnt_loot_task:Cancel() end
                target.willow_burnt_loot_task = nil
            end)
        end
    end
    AddPrefabPostInit("willow", function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("onhitother", ApplyDebuff)
    end)
end

-- 薇洛右键自身施放意念灭火术
if GetModConfigData("Willow Right Self Pyrokinetics Explained") then
    TUNING.WILLOW_SANITY = TUNING.WILSON_SANITY
    local cd = GetModConfigData("Willow Right Self Pyrokinetics Explained")
    cd = cd == true and 3 or cd
    AddReadBookRightSelfAction("willow", "book_fire", cd, STRINGS.CHARACTERS.WILLOW.ACTIONFAIL.ACTIVATE.LOCKED_GATE,
                               STRINGS.ACTIONS.START_CHANNELCAST.LIGHTER .. "/")
    local SNUFF_ONEOF_TAGS = {"smolder", "fire", "willow_ember"}
    local SNUFF_NO_TAGS = {"INLIMBO", "snuffed"}
    local ABSORB_RANGE = TUNING.BOOK_FIRE_RADIUS
    local function rightselfaction2hm_replacefn(action)
        local owner = action and action.doer
        if owner and owner.components and owner.components.skilltreeupdater and owner.components.skilltreeupdater:IsActivated("willow_embers") then
            local x, y, z = owner.Transform:GetWorldPosition()
            local ExtinguishFire = false
            local ents = TheSim:FindEntities(x, 0, z, ABSORB_RANGE, nil, SNUFF_NO_TAGS, SNUFF_ONEOF_TAGS)
            for i, v in ipairs(ents) do
                if v:IsValid() and not v:IsInLimbo() and v:HasTag("willow_ember") then
                    ExtinguishFire = true
                    break
                end
            end
            if ExtinguishFire then
                for i, v in ipairs(ents) do
                    if v:IsValid() and not v:IsInLimbo() then
                        local fx = nil
                        local giveember = nil
                        if v:HasTag("willow_ember") then
                            v:AddTag("snuffed")
                            fx = "channel_absorb_embers"
                            giveember = true
                        elseif v.components.burnable then
                            if v.components.burnable:IsBurning() then
                                v.components.burnable:Extinguish()
                                fx = "channel_absorb_fire"
                            elseif v.components.burnable:IsSmoldering() then
                                v.components.burnable:SmotherSmolder()
                                fx = "channel_absorb_smoulder"
                            end
                        end
                        if fx then
                            owner.SoundEmitter:PlaySound("meta3/willow_lighter/ember_absorb")
                            local fxprefab = SpawnPrefab(fx)
                            fxprefab.Follower:FollowSymbol(owner.GUID, "swap_object", 56, -40, 0)
                            if giveember then
                                v.AnimState:PlayAnimation("idle_pst")
                                v:DoTaskInTime(10 * FRAMES, function()
                                    if not owner.components.health:IsDead() then
                                        owner.components.inventory:GiveItem(v, nil, owner:GetPosition())
                                    end
                                    v:RemoveTag("snuffed")
                                    v.AnimState:PlayAnimation("idle_pre")
                                    v.AnimState:PushAnimation("idle_loop", true)
                                end)
                            end
                        end
                    end
                end
                return true
            end
        end
    end
    AddPrefabPostInit("willow", function(inst)
        if not TheWorld.ismastersim then return end
        inst.rightselfaction2hm_replacefn = rightselfaction2hm_replacefn
    end)
    AddPrefabPostInit("willow_ember", function(inst)
        MakeUnlimitStackSize(inst)
        if inst.components.inventoryitem then
            inst.components.inventoryitem.keepondeath = true
            inst.components.inventoryitem.keepondrown = true
        end
        if inst.components.stackable then inst.components.stackable.forcedropsingle = true end
    end)
end

-- 薇洛的火焰武器
if GetModConfigData("Willow Fire Weapon Attack") then
    -- 当火把切换到其他武器后会继续火焰，且攻击会仍然点燃目标
    local function checknewequip(inst)
        if inst.fires2hm and inst.firessource2hm then
            local equip = inst.components.inventory and inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            if equip == nil or not equip:IsValid() or equip == inst.firessource2hm or equip.prefab == "torch" or equip.prefab == "lighter" or
                not inst.firessource2hm:IsValid() or (inst.firessource2hm.components.fueled and inst.firessource2hm.components.fueled.currentfuel <= 0) or
                (inst.firessource2hm.components.inventoryitem and inst.firessource2hm.components.inventoryitem:GetGrandOwner() ~= inst) then
                if equip ~= inst.firessource2hm and inst.firessource2hm:IsValid() and inst.firessource2hm.components.burnable and
                    inst.firessource2hm.components.burnable.burning then inst.firessource2hm.components.burnable:Extinguish() end
                for i, fx in ipairs(inst.fires2hm) do fx:Remove() end
                inst.fires2hm = nil
                inst.firessource2hm.bindwillow2hm = nil
                inst.firessource2hm = nil
                if inst.checkfirestask2hm then
                    inst.checkfirestask2hm:Cancel()
                    inst.checkfirestask2hm = nil
                end
            elseif not inst.firessource2hm.bindwillow2hm then
                inst.firessource2hm.bindwillow2hm = inst
                if inst.firessource2hm.components.burnable and not inst.firessource2hm.components.burnable.burning then
                    inst.firessource2hm.components.burnable:Ignite()
                end
            elseif inst.firessource2hm.components.burnable and not inst.firessource2hm.components.burnable.burning then
                inst.firessource2hm.components.burnable:Ignite()
            end
        end
    end
    local function onunequip(inst, data)
        inst:DoTaskInTime(0, checknewequip)
        if data and data.item and data.item:IsValid() then
            if data.item.components.weapon and data.item.components.weapon.projectile == "torchfireprojectile2hm" then
                data.item.components.weapon.projectile = "fire_projectile"
                data.item.components.weapon:SetDamage(data.item.olddamage2hm or 0)
                data.item.olddamage2hm = nil
                -- if hardmode then data.item.components.weapon.attackwearmultipliers:RemoveModifier(inst, "willow2hm") end
            end
        end
    end
    local function onequip(inst, data)
        checknewequip(inst)
        if data and data.item and data.item:IsValid() then
            if data.item.components.weapon and data.item.components.weapon.projectile == "fire_projectile" then
                data.item.components.weapon.projectile = "torchfireprojectile2hm"
                data.item.olddamage2hm = data.item.components.weapon.damage
                data.item.components.weapon:SetDamage(34)
                -- if hardmode then data.item.components.weapon.attackwearmultipliers:SetModifier(inst, 1, "willow2hm") end
            end
        end
    end
    local function onhitother(inst, data)
        if data and data.target and data.target:IsValid() and data.target.components.burnable and not data.target:GetIsWet() and
            not data.target.flamethrowerdamagetask2hm and not (data.target.components.freezable and data.target.components.freezable:IsFrozen()) and
            ((inst.fires2hm and inst.firessource2hm and inst.firessource2hm:IsValid()) or inst:HasTag("firefrenzy")) and
            -- not (inst.components.rider and inst.components.rider.riding) and -- 2025.9.3 melon:注释掉
            ((inst.components.skilltreeupdater and inst.components.skilltreeupdater:IsActivated("willow_controlled_burn_1")) or math.random() <
                data.target.components.burnable.flammability) then data.target.components.burnable:Ignite(nil, inst) end
    end
    AddPrefabPostInit("willow", function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("equip", onequip)
        inst:ListenForEvent("unequip", onunequip)
        inst:ListenForEvent("onhitother", onhitother)
    end)
    local fireweapons = {"torch", "lighter"}
    for index, item in ipairs(fireweapons) do
        AddPrefabPostInit(item, function(inst)
            if not TheWorld.ismastersim then return end
            if inst.components.equippable then
                local onunequipfn = inst.components.equippable.onunequipfn
                inst.components.equippable.onunequipfn = function(inst, owner, ...)
                    if inst:IsValid() and owner and owner:IsValid() and owner.prefab == "willow" and inst.components.fueled and
                        inst.components.fueled.currentfuel > 0 and inst.fires then
                        if owner.firessource2hm and owner.firessource2hm:IsValid() then
                            if owner.firessource2hm.components.burnable and owner.firessource2hm.components.burnable.burning then
                                owner.firessource2hm.components.burnable:Extinguish()
                            end
                            owner.firessource2hm.bindwillow2hm = nil
                        end
                        if owner.fires2hm then for i, fx in ipairs(owner.fires2hm) do fx:Remove() end end
                        if not owner.checkfirestask2hm then owner.checkfirestask2hm = owner:DoPeriodicTask(1, checknewequip) end
                        owner.fires2hm = inst.fires
                        owner.firessource2hm = inst
                        inst.fires = nil
                    end
                    return onunequipfn(inst, owner, ...)
                end
            end
        end)
    end
end

-----------------------------------------------------------------------------------------------------------
-- 薇洛优化  影火优先打boss本体,牛上装备打火机时，1格地皮灭火、吸余烬,可控燃烧不烧玩家,过冷掉血变正常
if GetModConfigData("willow_improve") then
    -- 2025.8.26 melon:影火优先打boss、本体------------------------------------------------------------
    local CLOSERANGE = 1
    local TARGETS_MUST = { "_health", "_combat" }
    local TARGETS_CANT = { "INLIMBO", "invisible", "noattack", "notarget", "flight" }
    local function TargetIsHostile(isplayer, source, target)
        if source.HostileTest then
            return source:HostileTest(target)
        elseif isplayer and target.HostileToPlayerTest then
            return target:HostileToPlayerTest(source)
        else
            return target:HasTag("hostile")
        end
    end
    local function settarget2hm(inst,target,life,source)
        local maxdeflect = 30
        if life > 0 then
            inst.shadowfire_task = inst:DoTaskInTime(0.1,function()
                local theta = inst.Transform:GetRotation() * DEGREES
                local radius = CLOSERANGE
                if not (source and source.components.combat and source:IsValid()) then
                    target = nil
                elseif target == nil or not source.components.combat:CanTarget(target) then
                    target = nil
                    local isplayer = source:HasTag("player")
                    local x, y, z = inst.Transform:GetWorldPosition()
                    local ents = TheSim:FindEntities(x, y, z, 20, TARGETS_MUST, TARGETS_CANT)
                    if #ents > 0 then
                        --mimic playercontroller attack targeting
                        for i=#ents, 1, -1 do
                            local ent = ents[i]
                            if not source.components.combat:CanTarget(ent) or
                                source.components.combat:IsAlly(ent)
                            then
                                table.remove(ents, i)
                            elseif isplayer and ent.HostileToPlayerTest and ent.components.shadowsubmissive and not ent:HostileToPlayerTest(source) then
                                --shadowsubmissive needs to ignore TargetIs() test,
                                --since they have you targeted even when not hostile
                                table.remove(ents, i)
                            elseif not ent.components.combat:TargetIs(source) then
                                if not TargetIsHostile(isplayer, source, ent) then
                                    table.remove(ents, i)
                                elseif ent.components.follower then
                                    local leader = ent.components.follower:GetLeader()
                                    if leader and leader:HasTag("player") and not leader.components.combat:TargetIs(source) then
                                        table.remove(ents, i)
                                    end
                                end
                            end
                        end
                    end
                    if #ents > 0 then
                        local anglediffs = {}
                        local lowestdiff = nil
                        local lowestent = nil
                        for i, ent in ipairs(ents) do
                            -- melon:优先选boss、本体
                            if ent:HasTag("epic") and not ent:HasTag("swc2hm") then
                                lowestent = ent
                                break
                            end
                            local ex,ey,ez = ent.Transform:GetWorldPosition()
                            local diff = math.abs(inst:GetAngleToPoint(ex,ey,ez) - inst.Transform:GetRotation())
                            if diff > 180 then diff = math.abs(diff - 360) end
                            if not lowestdiff or lowestdiff > diff then
                                lowestdiff = diff
                                lowestent = ent
                            end                        
                        end
                        target = lowestent
                    end
                end
                if target then
                    local dist = inst:GetDistanceSqToInst(target)
                    if dist<CLOSERANGE*CLOSERANGE then
                        local blast = SpawnPrefab("willow_shadow_fire_explode")
                        local pos = Vector3(target.Transform:GetWorldPosition())
                        blast.Transform:SetPosition(pos.x,pos.y,pos.z)
                        local weapon = inst
                        source.components.combat.ignorehitrange = true
                        source.components.combat.ignoredamagereflect = true
                        source.components.combat:DoAttack(target, weapon)
                        source.components.combat.ignorehitrange = false
                        source.components.combat.ignoredamagereflect = false
                        theta = nil
                    else
                        local pt = Vector3(target.Transform:GetWorldPosition())
                        local angle = inst:GetAngleToPoint(pt.x,pt.y,pt.z)
                        local anglediff = angle - inst.Transform:GetRotation()
                        if anglediff > 180 then
                            anglediff = anglediff - 360
                        elseif anglediff < -180 then
                            anglediff = anglediff + 360
                        end
                        if math.abs(anglediff) > maxdeflect then
                            anglediff = math.clamp(anglediff, -maxdeflect, maxdeflect)
                        end
                        theta = (inst.Transform:GetRotation() + anglediff) * DEGREES
                    end
                else
                    if not inst.currentdeflection then
                        inst.currentdeflection = {time = math.random(1,10), deflection = maxdeflect * ((math.random() *2)-1) }
                    end
                    inst.currentdeflection.time = inst.currentdeflection.time -1
                    if inst.currentdeflection.time then
                        inst.currentdeflection = {time = math.random(1,10), deflection = maxdeflect * ((math.random() *2)-1) }
                    end
                    theta =  (inst.Transform:GetRotation() + inst.currentdeflection.deflection) * DEGREES
                end

                if theta  then
                    local offset = Vector3(radius * math.cos( theta ), 0, -radius * math.sin( theta ))
                    local newpos = Vector3(inst.Transform:GetWorldPosition()) + offset
                    local newangle = inst:GetAngleToPoint(newpos.x,newpos.y,newpos.z)
                    local fire = SpawnPrefab("willow_shadow_flame")
                    fire.Transform:SetRotation(newangle)
                    fire.Transform:SetPosition(newpos.x,newpos.y,newpos.z)
                    fire:settarget(target,life-1, source)
                end
            end)

        end
    end
    AddPrefabPostInit("willow_shadow_flame", function(inst)
        if not TheWorld.ismastersim then return end
        inst.settarget = settarget2hm
    end)

    -- 2025.9.5 melon:可控燃烧不烧玩家  改成兼容写法
    local TARGET_CANT_TAGS = { "INLIMBO" }
    local TARGET_MELT_MUST_TAGS = { "frozen", "firemelt" }
    AddComponentPostInit("propagator", function(self)
        local _OnUpdate = self.OnUpdate
        self.OnUpdate = function(self, dt)
            -- 是可控燃烧
            if self.inst and self.inst:HasTag("player") and self.damages and self.inst.components.burnable ~= nil and -- 会造成伤害
                self.inst.components.burnable.controlled_burn ~= nil then -- 是可控燃烧
                local x, y, z = self.inst.Transform:GetWorldPosition()
                local prop_range = TheWorld.state.isspring and self.propagaterange * TUNING.SPRING_FIRE_RANGE_MOD or self.propagaterange
                if self.spreading then
                    local ents = TheSim:FindEntities(x, y, z, prop_range, nil, TARGET_CANT_TAGS)
                    if #ents > 0 and prop_range > 0 then
                        local dmg_range = TheWorld.state.isspring and self.damagerange * TUNING.SPRING_FIRE_RANGE_MOD or self.damagerange
                        local dmg_range_sq = dmg_range * dmg_range
                        for i, v in ipairs(ents) do
                            if v:IsValid() then
                                local vx, vy, vz = v.Transform:GetWorldPosition()
                                local dsq = VecUtil_LengthSq(x - vx, z - vz)
                                if self.damages and
                                    -- 2025.10.13 melon:可控燃烧不烧玩家
                                    (dsq == 0 or not v:HasTag("player")) and -- =0就烧，>0不能是玩家
                                    v.components.propagator ~= nil and
                                    dsq < dmg_range_sq and
                                    v.components.health ~= nil and
                                    v.components.health.vulnerabletoheatdamage ~= false then
                                    local percent_damage = self.source ~= nil and self.source:HasTag("player") and self.pvp_damagemod or 1
                                    v.components.health:DoFireDamage(self.heatoutput * percent_damage * dt)
                                end
                            end
                        end
                    end
                end
                -- 执行原本代码,但不执行伤害(上面执行了)
                self.damages = false
                _OnUpdate(self, dt)
                self.damages = true
            else
                _OnUpdate(self, dt) -- 直接执行原代码
            end
        end
    end)

    -- 2025.9.19 牛上装备打火机时，1格地皮灭火、吸余烬
    local SNUFF_ONEOF_TAGS = { "smolder", "fire", "willow_ember" }
    local SNUFF_NO_TAGS = { "INLIMBO","snuffed" }
    local ABSORB_RANGE = 2.5 -- 原来2.5
    local function absorb_ember(owner)
        local x, y, z = owner.Transform:GetWorldPosition()
        for i, v in ipairs(TheSim:FindEntities(x, 0, z, ABSORB_RANGE, nil, SNUFF_NO_TAGS, SNUFF_ONEOF_TAGS)) do
            if v:IsValid() and not v:IsInLimbo() then
                if v:HasTag("willow_ember") then
                    if not owner.components.health:IsDead() then
                        owner.components.inventory:GiveItem(v, nil, owner:GetPosition())
                    end
                elseif v.components.burnable then
                    if v.components.burnable:IsBurning() then
                        v.components.burnable:Extinguish()
                    elseif v.components.burnable:IsSmoldering() then
                        v.components.burnable:SmotherSmolder()
                    end
                end
            end
        end
    end
    local function absorb2hm(inst, data) -- 或者用data.owner.prefab == "willow"
        if data and data.owner and data.owner:HasTag("ember_master") and data.owner.components.rider and data.owner.components.rider:IsRiding() then absorb_ember(data.owner) end
    end
    AddPrefabPostInit("lighter", function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("equipped", absorb2hm)
        inst:ListenForEvent("unequipped", absorb2hm)
        inst.absorb2hm = absorb2hm
    end)

    -- 2025.10.24 melon:过冷掉血降低  正常1.25  
    AddPrefabPostInit("willow", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.temperature and inst.components.temperature.hurtrate > 1.5 then
            inst.components.temperature.hurtrate = 1.5 -- 原本2.5
        end
    end)
end -- willow_improve