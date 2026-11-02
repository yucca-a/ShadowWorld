local hardmode = TUNING.hardmode2hm and GetModConfigData("role_nerf") and GetModConfigData("wanda")

-- 旺达不再持续衰老
if GetModConfigData("Wanda Don't Auto Drop Age") then AddComponentPostInit("oldager", function(self) self.base_rate = 0 end) end

-- 旺达不老表回温
if GetModConfigData("Ageless Watch Help Temperature") then
    AddPrefabPostInit("pocketwatch_heal", function(inst)
        if inst.components.pocketwatch then
            local cast = inst.components.pocketwatch.DoCastSpell
            inst.components.pocketwatch.DoCastSpell = function(inst, doer, ...)
                local result = cast(inst, doer, ...)
                if result and doer and doer:IsValid() and doer.components.temperature.current then
                    doer.components.temperature:SetTemperature(math.clamp(doer.components.temperature.current +
                                                                              (TUNING.BOOK_TEMPERATURE_AMOUNT - doer.components.temperature.current) / 3, 11, 59))
                    return true
                end
                return result
            end
        end
    end)
end

if GetModConfigData("wanda Eat Petals Get Dark Petals") then
    local function OnEat(inst, data)
        if data.food ~= nil and data.food.prefab == "petals" then
            inst.components.inventory:GiveItem(SpawnPrefab("petals_evil")) 
        end
    end
    local function unlockrecipes(inst)
        if inst.components.builder then
            if not inst.components.builder:KnowsRecipe("nightmarefuel") and 
               inst.components.builder:CanLearn("nightmarefuel") then
                inst.components.builder:UnlockRecipe("nightmarefuel")
            end
        end
    end
    AddPrefabPostInit("wanda", function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("oneat", OnEat)
        inst:DoTaskInTime(0, unlockrecipes)
    end)
end

-- 2025.5.3 melon:旺达加强
if GetModConfigData("wanda strengthen") then
    if hardmode then TUNING.POCKETWATCH_SHADOW_DAMAGE = 68 end -- 警钟伤害68
    TUNING.WANDA_AGE_THRESHOLD_OLD = .34 -- 60岁老年，原本.25
    -- if hardmode then TUNING.WANDA_SHADOW_DAMAGE_OLD = 1.5 end -- 2025.8.2 melon:老年削弱至1.5倍
    AddPrefabPostInit("wanda", function(inst)
        if inst.components.oldager then
            inst.components.oldager.base_rate = GetModConfigData("Wanda Don't Auto Drop Age") and 0 or 0.02 -- 显式停老化优先；默认1/40
        end
        if TUNING.DSTU then inst.skeleton_prefab = "skeleton_player" end -- 旺达死亡有骨架
    end)
    -- 用原版的伤害计算覆盖妥协，改回表的伤害计算
    if TUNING.DSTU then
        AddPrefabPostInit("wanda", function(inst)
            if inst.components.combat ~= nil then
                local _customdamagemultfn = inst.components.combat.customdamagemultfn
                inst.components.combat.customdamagemultfn = function(inst, target, weapon, multiplier, mount)
                    if mount == nil then
                        if weapon ~= nil and weapon:HasTag("shadow_item") then -- 原本的 只改的这里
                            return inst.age_state == "old" and TUNING.WANDA_SHADOW_DAMAGE_OLD
                                    or inst.age_state == "normal" and TUNING.WANDA_SHADOW_DAMAGE_NORMAL
                                    or TUNING.WANDA_SHADOW_DAMAGE_YOUNG
                        end
                    end
                    if _customdamagemultfn ~= nil then return _customdamagemultfn(inst, target, weapon, multiplier, mount) end
                end
            end
        end)
    end
end

-- 2025.5.3 melon:裂开的不老表
if GetModConfigData("pocketwatch_heal2hm") then
    -- 新不老表制作
    AddRecipe2( --配方1不老表1时间碎片1蓝宝石(防刷)
        "pocketwatch_heal2hm",
        {Ingredient("pocketwatch_heal", 1), Ingredient("pocketwatch_parts", 1), Ingredient("bluegem", 1)},
        TECH.NONE,
        {
            builder_tag="clockmaker", 
            atlas = "images/inventoryimages/pocketwatch_heal2hm.xml", 
            images = "images/inventoryimages/pocketwatch_heal2hm.tex",
        },
        {"CHARACTER"}
    )
    STRINGS.NAMES.POCKETWATCH_HEAL2HM = TUNING.isCh2hm and "裂开的不老表" or "cracked ageless watch"
    STRINGS.RECIPE_DESC.POCKETWATCH_HEAL2HM = TUNING.isCh2hm and "好像制作的时候被宝石砸成3瓣了，使用扣除1/3耐久" or "Use deduction of 1/3 durability"
    STRINGS.CHARACTERS.GENERIC.DESCRIBE.POCKETWATCH_HEAL2HM = TUNING.isCh2hm and "好像制作的时候被宝石砸成3瓣了" or "It seems that I was smashed into three pieces by a gemstone during production"
    -- 加动作
    local action = Action({})
    action.priority = 6
    action.id = "USEWATCH"
    action.str = "使用"
    action.distance = 999999
    action.mount_valid = true -- 牛上可使用
    action.fn = function(act)
        -- if true or act.doer.prefab == "wanda" then
        if act.invobject then
            return act.invobject.onuse(act.invobject, act.doer)
        end
        return false
    end
    -- 添加动作 POINT INVENTORY(物品栏里执行)  USEITEM
    AddAction(action)
    AddComponentAction("INVENTORY", "useableitem", function(inst, doer, actions, right) -- 根据组件判断
        -- if right and inst:HasTag("pocketwatch_heal2hm") then
        if inst:HasTag("pocketwatch_heal2hm") then -- 不加right右键直接用
            table.insert(actions, ACTIONS.USEWATCH)
        end
    end)
    -- 做完USEWATCH触发吧
    local handler = ActionHandler(ACTIONS.USEWATCH, function(inst, action) return "doshortaction" end)
    AddStategraphActionHandler("wilson", handler)
    AddStategraphActionHandler("wilson_client", handler)
end

-- 2025.5.3 melon:钟表加强
if GetModConfigData("pocketwatch strengthen") then
    TUNING.POCKETWATCH_HEAL_HEALING = 25 -- 不老表回血变多抵消生存险境
    -- 警钟攻击触发两面夹击-----------------------------------------
    STRINGS.NAMES[string.upper("watch_weapon_horn2hm")] = TUNING.isCh2hm and "夹击" or "watch_weapon_horn2hm"
    -- local horndmg = 17 -- 夹击伤害17
    local horncd = 1 -- 夹击cd 1秒
    local function SpawnDoubleHornAttack2hm(attacker, target) -- 潜伏梦魇的两面夹击
        if attacker.age_state then
            local left = SpawnPrefab("watch_weapon_horn2hm") -- 自定义袭击
            left:SetUp(attacker, target, nil)
            if attacker.age_state == "normal" or attacker.age_state == "old" then -- 中老年有第二个
                local right = SpawnPrefab("watch_weapon_horn2hm")
                right:SetUp(attacker, target, left) -- 和left配对
            end
            -- 老年有第3个
            if attacker.age_state == "old" then
                local three = SpawnPrefab("watch_weapon_horn2hm")
                three:SetUp(attacker, target, left, true)
            end
        end
    end
    AddPrefabPostInit("pocketwatch_weapon", function(inst)
        if not TheWorld.ismastersim then return end
        inst.notHornAttack2hm = true
        if inst.components.weapon ~= nil then
            local oldOnattack = inst.components.weapon.onattack
            inst.components.weapon.onattack = function(inst, attacker, target)
                if attacker.prefab == "wanda" and inst.notHornAttack2hm then
                    inst.notHornAttack2hm = false
                    -- 间隔1秒防止Horn触发Horn
                    inst:DoTaskInTime(horncd, function(inst) inst.notHornAttack2hm = true end)
                    SpawnDoubleHornAttack2hm(attacker, target)
                end
                oldOnattack(inst, attacker, target)
            end
        end
    end)
    -- 猫鞭也触发
    AddPrefabPostInit("whip", function(inst)
        if not TheWorld.ismastersim then return end
        inst:AddTag("shadow_item") -- 加暗影武器标签触发旺达年龄加伤
        inst.notHornAttack2hm = true
        if inst.components.weapon ~= nil then
            local oldOnattack = inst.components.weapon.onattack
            inst.components.weapon.onattack = function(inst, attacker, target)
                if attacker.prefab == "wanda" and inst.notHornAttack2hm then
                    inst.notHornAttack2hm = false
                    -- 间隔1秒防止Horn触发Horn
                    inst:DoTaskInTime(horncd, function(inst) inst.notHornAttack2hm = true end)
                    SpawnDoubleHornAttack2hm(attacker, target) -- 根据年龄算数量
                end
                -- oldOnattack(inst, attacker, target)
                -- 2025.8.8 melon:不再消除仇恨 (oldOnattack里有消仇恨)
                local snap = SpawnPrefab("impact")
                local x, y, z = inst.Transform:GetWorldPosition()
                local x1, y1, z1 = target.Transform:GetWorldPosition()
                local angle = -math.atan2(z1 - z, x1 - x)
                snap.Transform:SetPosition(x1, y1, z1)
                snap.Transform:SetRotation(angle * RADIANS)
                if target ~= nil and target:IsValid() and target.SoundEmitter ~= nil then
                    target.SoundEmitter:PlaySound(inst.skin_sound_small or "dontstarve/common/whip_small")
                end
            end
        end
    end)
    AddRecipePostInit("whip",function(inst) -- 更改猫鞭配方
		inst.ingredients = {
            Ingredient("coontail", 2)
		}
	end)
    AddPrefabPostInit("wanda", function(inst) -- 旺达开局可做猫鞭
        if not TheWorld.ismastersim then return end
        inst:DoTaskInTime(0, function(inst)
            if inst.components.builder then
                if not inst.components.builder:KnowsRecipe("whip") and inst.components.builder:CanLearn("whip") then
                    inst.components.builder:UnlockRecipe("whip")
                end
            end
        end)
    end)
    AddPrefabPostInit("catcoon", function(inst) -- 浣猫
        if not TheWorld.ismastersim then return end
        if inst.components.lootdropper then
            inst.components.lootdropper:SetLoot({"meat","coontail"}) -- 更改猫必掉猫尾
            inst.components.lootdropper:SetChanceLootTable(nil) -- 概率掉落改为空
        end
    end)
    -- 原版倒走表无敌0.3秒---------------------
    AddPrefabPostInit("pocketwatch_warp", function(inst) -- 倒走表
        if not TheWorld.ismastersim then return end
        if inst.components.pocketwatch then
            local oldcast = inst.components.pocketwatch.DoCastSpell
            inst.components.pocketwatch.DoCastSpell = function(inst, doer)
                if doer then  -- 0.3秒无敌
                    doer.allmiss2hm = true
                    doer:DoTaskInTime(0.3, function(inst)
                        if doer.allmiss2hm then inst.allmiss2hm = nil end
                    end)
                end
                return oldcast(inst, doer)
            end
        end
    end)
end

-- 2025.5.3 melon:警钟开局可做但配方增加1黄宝石
if GetModConfigData("pocketwatch_weapon at start") then
    if hardmode then
        AddRecipePostInit("pocketwatch_weapon",function(inst)
            table.insert(inst.ingredients, Ingredient("yellowgem", 1)) -- 2025.7.9 melon:改成插入
        end)
    end
    AddPrefabPostInit("wanda", function(inst) -- 旺达开局可做警钟
        if not TheWorld.ismastersim then return end
        inst:DoTaskInTime(0, function(inst)
            if inst.components.builder then
                if not inst.components.builder:KnowsRecipe("pocketwatch_weapon") and inst.components.builder:CanLearn("pocketwatch_weapon") then
                    inst.components.builder:UnlockRecipe("pocketwatch_weapon")
                end
            end
        end)
    end)
end

-- 旺达右键倒走
if GetModConfigData("Wanda Right Wrapback") and not GetModConfigData("Wanda Right Wrapfront") then
    AddPrefabPostInit("wanda", function(inst)
        AddWrapAbility(inst)
        inst.rightaction2hm_cooldown = GetModConfigData("Wanda Right Wrapback")==1 and 1.5 or TUNING.POCKETWATCH_WARP_COOLDOWN -- 2025.8.8 melon:原版1.5 正后2
    end)
end

-- 旺达右键未来行走
if GetModConfigData("Wanda Right Wrapfront") then
    AddPrefabPostInit("wanda", function(inst)
        AddWrapFrontAbility(inst)
        inst.rightaction2hm_cooldown = GetModConfigData("Wanda Right Wrapfront")
        if inst.rightaction2hm_cooldown == true then inst.rightaction2hm_cooldown = TUNING.POCKETWATCH_WARP_COOLDOWN * 4 end
    end)
end

-- 旺达右键自身定位和溯源，用钟表匠工具自身可以解除定位
if GetModConfigData("Wanda Right Self Backtrek") then
    local NOTENTCHECK_CANT_TAGS = {"FX", "INLIMBO"}
    local function DelayedMarkTalker(player)
        if player.sg == nil or player.sg:HasStateTag("idle") then player.components.talker:Say(GetString(player, "ANNOUNCE_POCKETWATCH_MARK")) end
    end
    local function noentcheckfn(pt)
        return not TheWorld.Map:IsPointNearHole(pt) and #TheSim:FindEntities(pt.x, pt.y, pt.z, 1, nil, NOTENTCHECK_CANT_TAGS) == 0
    end
    local function DoCastSpell(inst, doer, target, pos)
        local recallmark = inst.components.recallmark
        if recallmark:IsMarked() then
            local pt = doer:GetPosition()
            local offset = FindWalkableOffset(pt, math.random() * 2 * PI, 3 + math.random(), 16, false, true, noentcheckfn, true, true) or
                               FindWalkableOffset(pt, math.random() * 2 * PI, 5 + math.random(), 16, false, true, noentcheckfn, true, true) or
                               FindWalkableOffset(pt, math.random() * 2 * PI, 7 + math.random(), 16, false, true, noentcheckfn, true, true)
            if offset ~= nil then pt = pt + offset end
            if not Shard_IsWorldAvailable(recallmark.recall_worldid) then return false, "SHARD_UNAVAILABLE" end
            local portal = SpawnPrefab("pocketwatch_portal_entrance")
            portal.Transform:SetPosition(pt:Get())
            portal:SpawnExit(recallmark.recall_worldid, recallmark.recall_x, recallmark.recall_y, recallmark.recall_z)
            inst.SoundEmitter:PlaySound("wanda1/wanda/portal_entrance_pre")
            inst.owner2hm.components.timer:StopTimer("selfportal2hm")
            inst.owner2hm.components.timer:StartTimer("selfportal2hm", TUNING.POCKETWATCH_RECALL_COOLDOWN * 3)
            inst:Remove()
            return true
        else
            local x, y, z = doer.Transform:GetWorldPosition()
            recallmark:MarkPosition(x, y, z)
            inst.owner2hm.components.persistent2hm.data.recallmark2hm = inst.components.recallmark:OnSave()
            inst.SoundEmitter:PlaySound("wanda2/characters/wanda/watch/MarkPosition")
            doer:DoTaskInTime(12 * FRAMES, DelayedMarkTalker)
            return true
        end
    end
    AddPrefabPostInit("wanda", function(inst)
        if not TheWorld.ismastersim then return end
        if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
    end)
    local function delayremove(inst) inst:DoTaskInTime(0, inst.Remove) end
    local function onremove(inst) if inst.owner2hm then inst.owner2hm.selfwatch2hm = nil end end
    local function processwatch(inst, owner)
        inst.persists = false
        inst:AddTag("wandaself2hm")
        inst.owner2hm = owner
        owner.selfwatch2hm = inst
        inst.components.inventoryitem.canonlygoinpocket = true
        inst.components.inventoryitem:SetOnDroppedFn(delayremove)
        inst:ListenForEvent("onputininventory", delayremove)
        inst:ListenForEvent("ondropped", delayremove)
        inst.components.inventoryitem.onactiveitemfn = delayremove
        inst:ListenForEvent("onremove", onremove)
        -- 初始化数据
        if owner.components.persistent2hm.data.recallmark2hm then inst.components.recallmark:OnLoad(owner.components.persistent2hm.data.recallmark2hm) end
        inst.components.rechargeable:SetMaxCharge(TUNING.POCKETWATCH_RECALL_COOLDOWN * 3)
        inst.components.rechargeable:Discharge(owner.components.timer:GetTimeLeft("selfportal2hm") or 0)
        inst.components.pocketwatch.DoCastSpell = DoCastSpell
    end
    AddRightSelfAction("wanda", 3, "dolongaction", nil, function(act)
        if act.doer and act.doer.prefab == "wanda" and act.doer.components.inventory and not act.doer.selfwatch2hm then
            local watch = SpawnPrefab("pocketwatch_portal")
            if watch then
                act.doer.components.inventory:GiveItem(watch)
                processwatch(watch, act.doer)
                return true
            end
        end
        return false
    end, STRINGS.NAMES.POCKETWATCH_PORTAL)
    AddComponentPostInit("pocketwatch_dismantler", function(self)
        local oldDismantle = self.Dismantle
        self.Dismantle = function(self, target, doer, ...)
            if target and target.persists == false and target:HasTag("wandaself2hm") then
                target:Remove()
                -- 移除定位
                if target.owner2hm and target.owner2hm.prefab == "wanda" then target.owner2hm.components.persistent2hm.data.recallmark2hm = nil end
                SpawnPrefab("brokentool").Transform:SetPosition(doer.Transform:GetWorldPosition())
                return
            end
            return oldDismantle(self, target, doer, ...)
        end
    end)
end

-- 旺达复活自己
if GetModConfigData("Wanda Resurrect Self") then
    local enableallroles = GetModConfigData("Wanda Resurrect Self") == -1
    local tex = "pocketwatch_revive.tex"
    local function updateresurrectbuttonstatus(self)
        if self.owner and self.owner.canresurrectself2hm and self.resurrectbutton and self.resurrectbutton.button and self.resurrectbutton.button and
            self.resurrectbutton.text then
            if self.owner.canresurrectself2hm:value() then
                self.resurrectbutton.button:SetTextures(GetInventoryItemAtlas(tex), tex, nil, tex)
                self.resurrectbutton.text:SetString(TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_CONTROLLER_ATTACK) .. " " ..
                                                        STRINGS.NAMES.POCKETWATCH_REVIVE)
                self.resurrectbutton:SetTooltip(STRINGS.NAMES.POCKETWATCH_REVIVE)
            else
                self.resurrectbutton.button:SetTextures("images/hud.xml", "effigy_button_mouseover.tex", nil, "effigy_button.tex")
                self.resurrectbutton.text:SetString(TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_CONTROLLER_ATTACK) .. " " ..
                                                        STRINGS.ACTIONS.REMOTERESURRECT)
                self.resurrectbutton:SetTooltip(STRINGS.UI.HUD.ACTIVATE_RESURRECTION)
            end
        end
    end
    AddClassPostConstruct("widgets/statusdisplays", function(self)
        updateresurrectbuttonstatus(self)
        local EnableResurrect = self.EnableResurrect
        self.EnableResurrect = function(self, ...)
            EnableResurrect(self, ...)
            updateresurrectbuttonstatus(self)
        end
    end)
    local function refreshresurrectself2hmbutton(inst)
        if inst.HUD and inst.HUD.controls and inst.HUD.controls.status and inst.HUD.controls.status.EnableResurrect then
            inst.HUD.controls.status:EnableResurrect(inst.components.attuner and inst.components.attuner:HasAttunement("remoteresurrector"))
        end
    end
    local function ontimedone(inst, data)
        if data and data.name == "resurrectself2hmcd" and inst.canresurrectself2hm then inst.canresurrectself2hm:set(true) end
    end
    local function onwandadeath(inst)
        local reset_time = nil
        TheWorld:PushEvent("ms_setworldsetting", {setting = "reset_time", value = reset_time})
        TheWorld:PushEvent("ms_setworldresettime", reset_time)
    end
    local function onpreload(inst, data)
        if data and data.timer and data.timer.timers and data.timer.timers.resurrectself2hmcd then inst.canresurrectself2hm:set(false) end
    end
    local function hasresurrectbtn(inst)
        inst.canresurrectself2hm = net_bool(inst.GUID, "role.resurrectself2hm", "resurrectself2hmdirty")
        inst.canresurrectself2hm:set(true)
        if not TheNet:IsDedicated() then inst:ListenForEvent("resurrectself2hmdirty", refreshresurrectself2hmbutton) end
        if inst.components.attuner then
            local HasAttunement = inst.components.attuner.HasAttunement
            inst.components.attuner.HasAttunement = function(self, tag, ...)
                if tag == "remoteresurrector" and self.inst.canresurrectself2hm and self.inst.canresurrectself2hm:value() then return true end
                return HasAttunement(self, tag, ...)
            end
        end
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("timerdone", ontimedone)
        inst:ListenForEvent("ms_becameghost", onwandadeath)
        SetOnPreLoad(inst, onpreload)
    end
    if enableallroles then
        AddPlayerPostInit(hasresurrectbtn)
    else
        AddPrefabPostInit("wanda", hasresurrectbtn)
    end
    local fn = ACTIONS.REMOTERESURRECT.fn
    ACTIONS.REMOTERESURRECT.fn = function(act, ...)
        if act.doer and act.doer:IsValid() and act.doer.canresurrectself2hm and act.doer.canresurrectself2hm:value() and act.doer.components.timer and
            act.doer:HasTag("playerghost") and not act.doer:HasTag("reviving") then
            local pocketwatch_revive = SpawnPrefab("pocketwatch_revive")
            if pocketwatch_revive then
                pocketwatch_revive.persists = false
                pocketwatch_revive:RemoveFromScene()
                pocketwatch_revive:DoTaskInTime(30, pocketwatch_revive.Remove)
                local state
                if act.doer.sg and act.doer.sg.currentstate and act.doer.sg.currentstate.name == "remoteresurrect" then
                    state = act.doer.sg.currentstate
                    state.name = "remoteresurrect2hm"
                end
                if pocketwatch_revive.components.pocketwatch and pocketwatch_revive.components.pocketwatch:CastSpell(act.doer, act.doer, act.doer:GetPosition()) then
                    if state then state.name = "remoteresurrect" end
                    act.doer.components.timer:StopTimer("resurrectself2hmcd")
                    act.doer.canresurrectself2hm:set(false)
                    act.doer.components.timer:StartTimer("resurrectself2hmcd", TUNING.POCKETWATCH_REVIVE_COOLDOWN)
                    return true
                end
                if state then state.name = "remoteresurrect" end
            end
        end
        return fn(act, ...)
    end
end
