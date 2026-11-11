------------------------[机制(非建筑、非装备、非物品、非生物)]--------------------------
--------------------------------------------------------------------------------------
local hardmode = TUNING.hardmode2hm

-- 危险时正常入睡
local sleepoption = GetModConfigData("Sleep In Tent Even Danger")
if sleepoption then
    local function makeshadowcreaturesleave(inst)
        if inst.sg and (inst.sg:HasStateTag("sleeping") or inst.sg:HasStateTag("tent")) and inst.replica and inst.replica.combat then
            inst:PushEvent("transfercombattarget")
        end
    end
    AddStategraphPostInit("wilson", function(sg)
        local oldbedrollonenter = sg.states.bedroll.onenter
        sg.states.bedroll.onenter = function(inst, ...)
            local changeisday, isdayvalue
            local action = inst:GetBufferedAction()
            local target = action and (action.invobject or action.target)
            if TheWorld.state.isday and target and target.components.sleepingbag and target.components.persistent2hm and
                target.components.persistent2hm.data.upgrade then
                isdayvalue = TheWorld.state.isday
                changeisday = true
                TheWorld.state.isday = false
            end
            local oldIsNearDanger = inst.IsNearDanger
            inst.IsNearDanger = falsefn
            oldbedrollonenter(inst, ...)
            inst.IsNearDanger = oldIsNearDanger
            if changeisday then TheWorld.state.isday = isdayvalue end
        end
        local animqueueover = sg.states.bedroll.events.animqueueover
        local animqueueoverfn = type(animqueueover) == "table" and animqueueover.fn or animqueueover
        sg.states.bedroll.events.animqueueover = EventHandler("animqueueover", function(inst, ...)
            local changeisday, isdayvalue
            local action = inst:GetBufferedAction()
            local target = action and (action.invobject or action.target)
            if TheWorld.state.isday and target and target.components.sleepingbag and target.components.persistent2hm and
                target.components.persistent2hm.data.upgrade then
                isdayvalue = TheWorld.state.isday
                changeisday = true
                TheWorld.state.isday = false
            end
            if animqueueoverfn then animqueueoverfn(inst, ...) end
            if changeisday then TheWorld.state.isday = isdayvalue end
        end)
        local oldtentonenter = sg.states.tent.onenter
        sg.states.tent.onenter = function(inst, ...)
            local changeisday, isdayvalue
            local action = inst:GetBufferedAction()
            local target = action and (action.target or action.invobject)
            if target and target.components.sleepingbag and target.components.persistent2hm and target.components.persistent2hm.data.upgrade then
                local siesta = target:HasTag("siestahut")
                if siesta ~= TheWorld.state.isday then
                    isdayvalue = TheWorld.state.isday
                    changeisday = true
                    TheWorld.state.isday = siesta
                end
            end
            local oldIsNearDanger = inst.IsNearDanger
            inst.IsNearDanger = falsefn
            oldtentonenter(inst, ...)
            inst.IsNearDanger = oldIsNearDanger
            inst.sg:AddStateTag("notarget")
            inst.sg:AddStateTag("noattack")
            if sleepoption == true then inst:DoTaskInTime(5 * FRAMES, makeshadowcreaturesleave) end
            if changeisday then TheWorld.state.isday = isdayvalue end
        end
        local oldtentontimeout = sg.states.tent.ontimeout
        sg.states.tent.ontimeout = function(inst, ...)
            local changeisday, isdayvalue
            local action = inst:GetBufferedAction()
            local target = action and (action.target or action.invobject)
            if target and target.components.sleepingbag and target.components.persistent2hm and target.components.persistent2hm.data.upgrade then
                local siesta = target:HasTag("siestahut")
                if siesta ~= TheWorld.state.isday then
                    isdayvalue = TheWorld.state.isday
                    changeisday = true
                    TheWorld.state.isday = siesta
                end
            end
            if oldtentontimeout then oldtentontimeout(inst, ...) end
            if changeisday then TheWorld.state.isday = isdayvalue end
        end
    end)
    local function cyclesrepair(inst)
        if inst.components.finiteuses and inst.components.finiteuses:GetPercent() < 1 then inst.components.finiteuses:Repair(1) end
    end
    local function worldphase() return TheWorld.state.phase end
    local function upgradesleep(inst)
        inst.components.finiteuses:SetMaxUses(inst.components.finiteuses.total * 2)
        inst:WatchWorldState("cycles", cyclesrepair)
        if inst.components.sleepingbag then inst.components.sleepingbag.GetSleepPhase = worldphase end
        inst.level2hm:set(2)
    end
    local function customrepair(inst, repairuse, doer, repair_item)
        if inst.people_num and inst.people_num:value() > 0 then return false end
        if not inst.components.persistent2hm.data.upgrade then
            inst.components.persistent2hm.data.upgrade = true
            upgradesleep(inst)
        elseif inst.components.finiteuses:GetPercent() >= 1 then
            return false
        end
        local shinefx = SpawnPrefab("pocketwatch_warpback_fx")
        shinefx.AnimState:SetTime(10 * FRAMES)
        local parent = inst.components.inventoryitem and inst.components.inventoryitem:GetGrandOwner() or inst
        parent:AddChild(shinefx)
        inst.components.finiteuses:SetUses(inst.components.finiteuses.total)
        if repair_item.components.stackable then
            repair_item.components.stackable:Get():Remove()
        else
            repair_item:Remove()
        end
        return true
    end
    local function onsave(inst, data)
        if inst.components.persistent2hm.data.upgrade == true and inst.components.finiteuses then
            data.upgrade2hm = true
            data.usenums2hm = inst.components.finiteuses:GetUses()
        end
    end
    local function onload(inst, data)
        if data and data.upgrade2hm == true then 
            upgradesleep(inst)
            if data.usenums2hm then
                inst.components.finiteuses:SetUses(data.usenums2hm)
            end
        end
    end
    local function DisplayNameFn(inst)
        if inst.level2hm:value() > 1 then
            if inst.repairtext2hm then inst.repairtext2hm = nil end
            return (TUNING.isCh2hm and "高级" or "Upgraded ") .. inst.name
        else
            return inst.name
        end
    end
    local function sleepbombcanrepair(inst)
        inst.repairmaterials2hm = {sleepbomb = 1}
        inst.repairtext2hm = "UPGRADE"
        if not inst.displaynamefn then inst.displaynamefn = DisplayNameFn end
        inst.level2hm = net_byte(inst.GUID, "tent.level2hm")
        if not TheWorld.ismastersim then return end
        inst.level2hm:set(1)
        if inst.components.finiteuses then
            inst:AddComponent("repairable2hm")
            inst.components.repairable2hm.customrepair = customrepair
            inst:AddComponent("persistent2hm")
            SetOnSave2hm(inst, onsave)
            SetOnLoad2hm(inst, onload)
        end
    end
    AddPrefabPostInit("bedroll_furry", sleepbombcanrepair)
    AddPrefabPostInit("tent", sleepbombcanrepair)
    AddPrefabPostInit("siestahut", sleepbombcanrepair)
end

-- 可以治疗怪兽肉为肉
if GetModConfigData("Spider Gland Can Heal Monster Meat") then
    local monstermeats = {
        monstermeat = "meat",
        cookedmonstermeat = "cookedmeat",
        monstermeat_dried = "meat_dried",
        monstersmallmeat = "smallmeat",
        cookedmonstersmallmeat = "cookedsmallmeat",
        monstersmallmeat_dried = "smallmeat_dried",
        um_monsteregg = "bird_egg",
        um_monsteregg_cooked = "bird_egg_cooked"
    }
    AddComponentPostInit("healer", function(self)
        local oldHeal = self.Heal
        self.Heal = function(self, target, ...)
            if oldHeal(self, target, ...) then return true end
            if monstermeats[target.prefab] and self.health > 0 and target.components.edible and target.components.edible.healthvalue and
                target.components.inventoryitem and self.inst.components.inventoryitem then
                if (target.components.edible.healthvalue >= 0) or (math.random() < self.health / math.abs(target.components.edible.healthvalue)) then
                    local owner = target.components.inventoryitem:GetGrandOwner() or self.inst.components.inventoryitem:GetGrandOwner()
                    local receiver = owner ~= nil and (owner.components.inventory or owner.components.container) or nil
                    if receiver then
                        receiver:GiveItem(SpawnPrefab(monstermeats[target.prefab]), nil, self.inst:GetPosition())
                    else
                        SpawnPrefab(monstermeats[target.prefab]).Transform:SetPosition(self.inst.Transform:GetWorldPosition())
                    end
                    target.components.stackable:Get():Remove()
                end
                if self.inst.components.stackable ~= nil and self.inst.components.stackable:IsStack() then
                    self.inst.components.stackable:Get():Remove()
                else
                    self.inst:Remove()
                end
                return true
            end
        end
    end)
    local oldHealActionFn = ACTIONS.HEAL.fn
    ACTIONS.HEAL.fn = function(act)
        if oldHealActionFn(act) then return true end
        local target = act.target
        if target ~= nil and monstermeats[target.prefab] and act.invobject ~= nil and act.invobject.components.healer ~= nil then
            return act.invobject.components.healer:Heal(target, act.doer)
        end
    end
    AddComponentAction("USEITEM", "healer",
                       function(inst, doer, target, actions) if monstermeats[target.prefab] then table.insert(actions, ACTIONS.HEAL) end end)
end

-- 灵魂移速加快
if GetModConfigData("Player Ghost Speed Up") and false then
    local ex_fns = require "prefabs/player_common_extensions"
    local oldConfigureGhostLocomotor = ex_fns.ConfigureGhostLocomotor
    ex_fns.ConfigureGhostLocomotor = function(inst, ...)
        oldConfigureGhostLocomotor(inst, ...)
        inst.components.locomotor.walkspeed = TUNING.WILSON_WALK_SPEED * 2.5
        inst.components.locomotor.runspeed = TUNING.WILSON_RUN_SPEED * 2.5
    end
    local oldOnMakePlayerGhost = ex_fns.OnMakePlayerGhost
    ex_fns.OnMakePlayerGhost = function(inst, ...)
        oldOnMakePlayerGhost(inst, ...)
        inst.components.locomotor.walkspeed = TUNING.WILSON_WALK_SPEED * 2.5
        inst.components.locomotor.runspeed = TUNING.WILSON_RUN_SPEED * 2.5
    end
end

-- 用燃烧火焰烹饪
if GetModConfigData("Use Fire To Cook") then
    -- 猪人火炬直接加厨具标签便于排队论
    AddPrefabPostInit("pigking_pigtorch", function(inst)
        if not TheWorld.ismastersim then return end
        if not inst.components.cooker then inst:AddComponent("cooker") end
    end)
    -- 其他燃烧道具则使用复刻动作
    local action = Action({})
    action.priority = 1
    action.id = "MOD_HARDMODE_COOK"
    action.str = STRINGS.ACTIONS.COOK
    action.fn = function(act)
        if act.target and act.target.components.cooker == nil and act.target.components.burnable ~= nil and
            (act.target.components.burnable:IsBurning() or (act.target.components.fueled ~= nil and act.target.components.fueled:GetPercent() > 0)) then
            local cook_pos = act.target:GetPosition()
            local ingredient = act.doer.components.inventory:RemoveItem(act.invobject)
            ingredient.Transform:SetPosition(cook_pos:Get())
            if ingredient.components.cookable == nil then
                act.doer.components.inventory:GiveItem(ingredient, nil, cook_pos)
                return false
            end
            if ingredient.components.health ~= nil then
                act.doer:PushEvent("murdered", {victim = ingredient, stackmult = 1})
                if ingredient.components.combat ~= nil then act.doer:PushEvent("killed", {victim = ingredient}) end
            end
            local product = ingredient.components.cookable:Cook(ingredient, act.doer)
            ProfileStatsAdd("cooked_" .. ingredient.prefab)
            if product ~= nil then
                act.doer.components.inventory:GiveItem(product, nil, cook_pos)
                ingredient:Remove()
                return true
            elseif ingredient:IsValid() then
                act.doer.components.inventory:GiveItem(ingredient, nil, cook_pos)
            end
        end
    end
    -- 添加动作
    AddAction(action)
    AddComponentAction("USEITEM", "cookable", function(inst, doer, target, actions)
        if target:HasTag("fire") and not target:HasTag("cooker") and not (doer.replica.rider ~= nil and doer.replica.rider:IsRiding() and
            not (target.replica.inventoryitem ~= nil and target.replica.inventoryitem:IsGrandOwner(doer))) then
            table.insert(actions, ACTIONS.MOD_HARDMODE_COOK)
        end
    end)
    -- 排队论支持批量
    local function clientDetect(target)
        return target and target:HasTag("fire") and not target:HasTag("cooker") and ThePlayer and
                   not (ThePlayer.replica.rider ~= nil and ThePlayer.replica.rider:IsRiding() and
                       not (target.replica and target.replica.inventoryitem ~= nil and target.replica.inventoryitem:IsGrandOwner(ThePlayer)))
    end
    AddComponentPostInit("actionqueuer", function(self) if self.AddAction then self.AddAction("leftclick", "MOD_HARDMODE_COOK", clientDetect) end end)
    -- 角色状态图里加入动作执行函数和响应动画
    AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.MOD_HARDMODE_COOK,
                                                       function(inst, action) return inst:HasTag("expertchef") and "domediumaction" or "dolongaction" end))
    -- 角色状态图里加入动作响应动画
    AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.MOD_HARDMODE_COOK, function(inst, action)
        return inst:HasTag("expertchef") and "domediumaction" or "dolongaction"
    end))
end

-- 洞穴铺码头
if GetModConfigData("Use Dock kit in Cave") then
    local autodamage = GetModConfigData("Use Dock kit in Cave") ~= -1
    AddPrefabPostInit("world", function(inst)
        if not inst.ismastersim then return end
        if inst:HasTag("cave") and not inst.has_ocean and not inst.components.dockmanager then inst:AddComponent("dockmanager") end
    end)
    local function IsDockNearOtherOnOcean(other, pt, min_spacing_sq)
        local min_spacing_sq_resolved =
            (other.deploy_extra_spacing ~= nil and math.max(other.deploy_extra_spacing * other.deploy_extra_spacing, min_spacing_sq)) or min_spacing_sq
        local ox, oy, oz = other.Transform:GetWorldPosition()
        return distsq(pt.x, pt.z, ox, oz) < min_spacing_sq_resolved -- Throw out any tests for anything that's not in the ocean.
    end
    local min_distance_from_entities = (TILE_SCALE / 2) + 1.2
    AddPrefabPostInit("dock_kit", function(inst)
        if TheWorld:HasTag("cave") and not TheWorld.has_ocean then
            local CLIENT_CanDeployDockKit = inst._custom_candeploy_fn
            inst._custom_candeploy_fn = function(inst, pt, mouseover, deployer, rotation, ...)
                local result = CLIENT_CanDeployDockKit(inst, pt, mouseover, deployer, rotation, ...)
                if not result and (mouseover == nil or mouseover:HasTag("player")) then
                    if TileGroupManager:IsInvalidTile(TheWorld.Map:GetTileAtPoint(pt.x, 0, pt.z)) then
                        local tx, ty = TheWorld.Map:GetTileCoordsAtPoint(pt.x, 0, pt.z)
                        local found_adjacent_safetile = false
                        for x_off = -1, 1, 1 do
                            for y_off = -1, 1, 1 do
                                if (x_off ~= 0 or y_off ~= 0) and not TileGroupManager:IsInvalidTile(TheWorld.Map:GetTile(tx + x_off, ty + y_off)) then
                                    found_adjacent_safetile = true
                                    break
                                end
                            end
                            if found_adjacent_safetile then break end
                        end
                        if found_adjacent_safetile then
                            local center_pt = Vector3(TheWorld.Map:GetTileCenterPoint(tx, ty))
                            return TheWorld.Map:IsDeployPointClear(center_pt, nil, min_distance_from_entities, nil, IsDockNearOtherOnOcean)
                        end
                    end
                end
                return result
            end
        end
    end)
    local damage = TUNING.GUNPOWDER_DAMAGE / 2
    local function OnDayComplete(inst)
        local self = inst.components.dockmanager
        if self and self.tiles2hm then
            for i = #self.tiles2hm, 1, -1 do
                local tilepos = self.tiles2hm[i]
                if tilepos and tilepos.x and tilepos.y and tilepos.day and tilepos.day < TheWorld.state.cycles then
                    tilepos.day = TheWorld.state.cycles
                    local current_tile = TheWorld.Map:GetTile(tilepos.x, tilepos.y)
                    if current_tile == WORLD_TILES.IMPASSABLE or current_tile == WORLD_TILES.INVALID then
                        table.remove(self.tiles2hm, i)
                    else
                        self:DamageDockAtTile(tilepos.x, tilepos.y, damage)
                    end
                else
                    table.remove(self.tiles2hm, i)
                end
            end
        end
    end
    AddComponentPostInit("undertile", function(self)
        local GetTileUnderneath = self.GetTileUnderneath
        self.GetTileUnderneath = function(self, x, y, ...)
            if self.inst.noundertile2hm then return WORLD_TILES.IMPASSABLE end
            return GetTileUnderneath(self, x, y, ...)
        end
    end)
    local function NewIsOceanTile(tile) return tile == WORLD_TILES.IMPASSABLE end
    AddComponentPostInit("dockmanager", function(self)
        if self.inst:HasTag("cave") and not self.inst.has_ocean then
            local DestroyDockAtPoint = self.DestroyDockAtPoint
            self.DestroyDockAtPoint = function(self, x, y, z, dont_toss_loot, ...)
                dont_toss_loot = true
                self.inst.noundertile2hm = true
                local oldtile1 = WORLD_TILES.MONKEY_DOCK
                local oldtile2 = WORLD_TILES.OCEAN_COASTAL
                WORLD_TILES.OCEAN_COASTAL = WORLD_TILES.IMPASSABLE
                WORLD_TILES.MONKEY_DOCK = TheWorld.Map:GetTile(TheWorld.Map:GetTileCoordsAtPoint(x, y, z))
                local oldfn = IsOceanTile
                GLOBAL.IsOceanTile = NewIsOceanTile
                local result = DestroyDockAtPoint(self, x, y, z, dont_toss_loot, ...)
                WORLD_TILES.OCEAN_COASTAL = oldtile2
                WORLD_TILES.MONKEY_DOCK = oldtile1
                GLOBAL.IsOceanTile = oldfn
                self.inst.noundertile2hm = nil
                return result
            end
            local QueueDestroyForDockAtPoint = self.QueueDestroyForDockAtPoint
            self.QueueDestroyForDockAtPoint = function(self, x, y, z, dont_toss_loot, ...)
                dont_toss_loot = true
                self.inst.noundertile2hm = true
                local oldtile = WORLD_TILES.OCEAN_COASTAL
                WORLD_TILES.OCEAN_COASTAL = WORLD_TILES.IMPASSABLE
                local oldfn = IsOceanTile
                GLOBAL.IsOceanTile = NewIsOceanTile
                local result = QueueDestroyForDockAtPoint(self, x, y, z, dont_toss_loot, ...)
                WORLD_TILES.OCEAN_COASTAL = oldtile
                GLOBAL.IsOceanTile = oldfn
                self.inst.noundertile2hm = nil
                return result
            end
            if autodamage then
                self.tiles2hm = {}
                local CreateDockAtTile = self.CreateDockAtTile
                self.CreateDockAtTile = function(self, tile_x, tile_y, dock_tile_type, ...)
                    -- 可以忽略其他地皮
                    if dock_tile_type == WORLD_TILES.MONKEY_DOCK then dock_tile_type = WORLD_TILES.DIRT end
                    local result = CreateDockAtTile(self, tile_x, tile_y, dock_tile_type, ...)
                    if result then table.insert(self.tiles2hm, {x = tile_x, y = tile_y, day = TheWorld.state.cycles}) end
                    return result
                end
                local OnSave = self.OnSave
                self.OnSave = function(self, ...)
                    local data = OnSave(self, ...)
                    data.tiles2hm = self.tiles2hm
                    return data
                end
                local OnLoad = self.OnLoad
                self.OnLoad = function(self, data, ...)
                    OnLoad(self, data, ...)
                    if data.tiles2hm then self.tiles2hm = data.tiles2hm end
                end
                self.inst:WatchWorldState("cycles", OnDayComplete)
            end
        end
    end)
end

-- 玩家上线时自动拣起来周围的眼骨类道具
if GetModConfigData("pickup irreplaceable item") then
    local PICKUP_MUST_ONEOF_TAGS = {"_inventoryitem", "pickable"}
    local PICKUP_CANT_TAGS = {
        -- Items
        "INLIMBO",
        "NOCLICK",
        "knockbackdelayinteraction",
        "event_trigger",
        "minesprung",
        "mineactive",
        "catchable",
        "fire",
        "light",
        "spider",
        "cursed",
        "paired",
        "bundle",
        "heatrock",
        "deploykititem",
        "boatbuilder",
        "singingshell",
        "archive_lockbox",
        "simplebook",
        "furnituredecor",
        -- Pickables
        "flower",
        "gemsocket",
        "structure",
        -- Either
        "donotautopick"
    }
    local function whenconnectpickupitems(inst)
        if inst.components.inventory then
            local x, y, z = inst.Transform:GetWorldPosition()
            local nearents = TheSim:FindEntities(x, y, z, 4, {"irreplaceable"}, PICKUP_CANT_TAGS, PICKUP_MUST_ONEOF_TAGS)
            for index, ent in ipairs(nearents) do
                if ent and ent:IsValid() and ent.components.inventoryitem and not ent.components.inventoryitem.owner and
                    ent.components.inventoryitem.canbepickedup then inst.components.inventory:GiveItem(ent) end
            end
        end
    end
    AddPlayerPostInit(function(inst)
        if not TheWorld.ismastersim then return end
        inst:DoTaskInTime(0, whenconnectpickupitems)
    end)
end

-- 帐篷类建筑可多人入睡 (代码参考自 作者:liximi -《多人帐篷》)
-- 本模组额外优化了动画细节处理以及帐篷耐久不满足入睡时限制处理
if GetModConfigData("The tent supports multiple people sharing it") then
    local container_nums = GetModConfigData("The tent supports multiple people sharing it")
    if type(container_nums) == "number" then
        container_nums = 1 - container_nums
    end

    -- local tents = {
    --     "tent",
    --     "siestahut",
    -- }

    local SPG = require("components/sleepingbag")
    local FollowText = require("widgets/followtext")
    local function CreateExSleepingBag(self)    --创建子帐篷（传入sleepingbag组件）
        --[[
            给sleepingbag组件添加一个额外的ex_bag表，该表继承自self.inst，
            给ex_bag表添加一个components表，并重新添加一个sleepingbag组件，该components表继承自self.inst.components
            角色睡觉时和醒来时会找到新添加的sleepingbag组件，而此外所有的操作都会指向原本的self.inst
        ]]
        local ex_bag = {}
        setmetatable(ex_bag, {__index = self.inst})
        ex_bag.components = {
            sleepingbag = SPG(ex_bag)
        }
        setmetatable(ex_bag.components, {__index = self.inst.components})
        --手动应用mod的postinit修改
        local postinitfns = ModManager:GetPostInitFns("ComponentPostInit", "sleepingbag")
        for i, fn in ipairs(postinitfns) do
            fn(ex_bag.components.sleepingbag, ex_bag)
        end
        --复制必要的属性
        for k,v in pairs(self) do
            if k =="onsleep" or k =="onwake"
            or k =="health_tick" or k == "hunger_tick" or k == "sanity_tick"
            or k =="dryingrate" or k =="temperaturetickfn" or k == "sleep_phase" or k == "GetSleepPhase" then
                ex_bag.components.sleepingbag[k] = v
            end
        end

        --标记该组件为额外组件，并关联本体组件
        ex_bag.components.sleepingbag.is_ex_bag = true
        ex_bag.components.sleepingbag.real_bag = self

        --去除文字显示widget
        if ex_bag.components.sleepingbag.widget ~= nil then
            ex_bag.components.sleepingbag.widget:Kill()
            ex_bag.components.sleepingbag.widget = nil
        end
        
        return ex_bag
    end

    local function count_people_num(self)       --计算当前睡觉人数（传入sleepingbag组件）
        if self ~= nil then
            local num = 0
            if self.is_ex_bag == false then
                if self.sleeper ~= nil then
                    num = 1
                end
                for k,v in pairs(self.ex_bags) do
                    num = num + 1
                end
            else
                if self.real_bag.sleeper ~= nil then
                    num = 1
                end
                for k,v in pairs(self.real_bag.ex_bags) do
                    num = num + 1
                end
            end
            return num
        end
    end

    local function new_onsleeper(self, sleeper, old_sleeper)
        if old_sleeper ~= nil and old_sleeper.player_classified ~= nil then
            old_sleeper.player_classified.issleephealing:set(false)
        end
        if sleeper ~= nil then
            if sleeper.player_classified ~= nil then
                sleeper.player_classified.issleephealing:set(self.healthsleep)
            end
        end

        local num = count_people_num(self)
        --设置网络变量(用于在玩家鼠标悬浮于帐篷上时，显示睡觉人数)
        if self.inst.people_num ~= nil then
            self.inst.people_num:set(num)
        end

        -- 人满或者耐久不支持下一个人时不可入睡
        local cansleep = true
        if self.inst.components and self.inst.components.finiteuses and num >= self.inst.components.finiteuses.current then cansleep = false end
        if type(container_nums) == "number" and num >= container_nums then cansleep = false end
        if not cansleep then
            self.inst:AddTag("hassleeper")
        else
            self.inst:RemoveTag("hassleeper")
        end
        --print("当前人数: "..tostring(num))
    end

    local function SleepingBagInit(self)
        self.sleeper_list = {}
        self.ex_bags = {}
        self.is_ex_bag = false

        --修改onsleeper函数
        addsetter(self, "sleeper", new_onsleeper)

        local function worked_do_wakeup(inst)
            if self.sleeper ~= nil then
                self:DoWakeUp()
            end
        end
        local function used_do_wakeup(inst, data)
            if data and data.percent and data.percent <= 0 then
                if self.sleeper ~= nil then
                    self:DoWakeUp()
                end
            end
        end

        local old_dosleep = self.DoSleep
        self.DoSleep = function (selff, doer)
            -- 动画细节处理，不重复触发动画
            local num = count_people_num(selff)
            local sleep_anim
            if selff.is_ex_bag == false and num > 0 and rawget(selff.inst, "sleep_anim") then
                sleep_anim = rawget(selff.inst, "sleep_anim")
                rawset(selff.inst, "sleep_anim", nil)
            end

            --如果本组件不是额外组件并且已经有人睡，则创建新组件，让新来的睡新的
            --否则，本组件是额外组件或无人睡，则直接睡
            if selff.is_ex_bag == false and selff.sleeper ~= nil then
                selff.ex_bags[doer] = CreateExSleepingBag(selff)
                selff.ex_bags[doer].components.sleepingbag:DoSleep(doer)
                selff.sleeper_list[doer] = true
            else
                old_dosleep(selff, doer)
            end

            if selff.is_ex_bag == false and sleep_anim then 
                rawset(selff.inst, "sleep_anim", sleep_anim)
            end
            --如果本组件是额外组件，则需要为睡觉者添加事件监听器
            --目的是当帐篷被烧/被锤/被其他人使用完耐久时，让所有人都醒过来
            if selff.is_ex_bag == true then
                doer:ListenForEvent("onignite", worked_do_wakeup, selff.real_bag.inst)
                doer:ListenForEvent("percentusedchange", used_do_wakeup, selff.real_bag.inst)
                doer:ListenForEvent("worked", worked_do_wakeup, selff.real_bag.inst)
            end
            
            -- 添加颜色提示
            local num = count_people_num(selff)
            local cansleep = true
            if selff.inst.components and selff.inst.components.finiteuses and num >= selff.inst.components.finiteuses.current then cansleep = false end
            if type(container_nums) == "number" and num >= container_nums then cansleep = false end
            if selff.inst:HasTag("tent") and not cansleep then selff.inst.AnimState:SetMultColour(1, 0, 0, 1) end
        end

        local old_dowakeup = self.DoWakeUp
        self.DoWakeUp = function (selff, nostatechange)
            -- 动画细节处理，非最后一个玩家出帐篷不暂停当前动画
            local num = count_people_num(selff)
            local sleep_anim
            if selff.is_ex_bag == true then
                if num > 1 and rawget(selff.real_bag.inst, "sleep_anim") then
                    sleep_anim = rawget(selff.real_bag.inst, "sleep_anim")
                    rawset(selff.real_bag.inst, "sleep_anim", nil)
                end
            else
                if num > 1 and rawget(selff.inst, "sleep_anim") then
                    sleep_anim = rawget(selff.inst, "sleep_anim")
                    rawset(selff.inst, "sleep_anim", nil)
                end
            end
            --如果本组件是额外组件，则移除新添加的监听器
            if selff.is_ex_bag == true then
                selff.sleeper:RemoveEventCallback("onignite", worked_do_wakeup, selff.real_bag.inst)
                selff.sleeper:RemoveEventCallback("percentusedchange", used_do_wakeup, selff.real_bag.inst)
                selff.sleeper:RemoveEventCallback("worked", worked_do_wakeup, selff.real_bag.inst)
            end
            --取消本体与本组件的关联(将本组件从本体的ex_bags表中移除)
            if selff.is_ex_bag == true then
                local doer
                for k,v in pairs(selff.real_bag.ex_bags) do
                    if v == selff.inst then
                        doer = k
                        break
                    end
                end
                if doer ~= nil then
                    selff.real_bag.sleeper_list[doer] = nil
                    selff.real_bag.ex_bags[doer] = nil
                end
            end
            --直接从本组件唤醒睡觉的人
            old_dowakeup(selff, nostatechange)

            if selff.is_ex_bag == true then
                if sleep_anim then 
                    rawset(selff.real_bag.inst, "sleep_anim", sleep_anim)
                end
            else
                if sleep_anim then 
                    rawset(selff.inst, "sleep_anim", sleep_anim)
                end
            end

            -- 清理颜色提示
            local num = count_people_num(selff)
            local cansleep = true
            if selff.inst.components and selff.inst.components.finiteuses and num >= selff.inst.components.finiteuses.current then cansleep = false end
            if type(container_nums) == "number" and num >= container_nums then cansleep = false end
            if selff.inst:HasTag("tent") then 
                if cansleep then
                    selff.inst.AnimState:SetMultColour(1, 1, 1, 1) 
                elseif not cansleep then
                    selff.inst:AddTag("hassleeper")
                end
            end
        end

        local oldInUse = self.InUse
        self.InUse = function(self, ...)
            return oldInUse(self, ...) or count_people_num(self) > 0
        end
    end

    AddComponentPostInit("sleepingbag", SleepingBagInit)

        ----设置帐篷人数显示----
    local function TentInit(inst)
        if not inst:HasTag("tent") then return end
        inst.people_num = net_uint(inst.GUID,"people_num","leveldirty")
    end

    AddPrefabPostInitAny(TentInit)

    local function GetBasicDisplayNameInit(self, entity)
        local old_func = self.GetBasicDisplayName
        self.GetBasicDisplayName = function (self)
            local name = old_func(self)
            if self:HasTag("tent") then
                name = name..(TUNING.isCh2hm and " 当前睡觉人数: " or " Current number of sleepers: ")..tostring(count_people_num(self.components.sleepingbag) or self.people_num and self.people_num:value() or 0)
            end
            return name
        end
    end
    AddGlobalClassPostConstruct("entityscript", "EntityScript", GetBasicDisplayNameInit)
end
