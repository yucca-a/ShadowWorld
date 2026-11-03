local containers = require("containers")
local ImageButton = require "widgets/imagebutton"
local CraftingMenuIngredients = require "widgets/redux/craftingmenu_ingredients"
local Widget = require "widgets/widget"
local ThreeSlice = require "widgets/threeslice"
local Image = require "widgets/image"
local cooking = require("cooking")
require "widgets/widgetutil"
local containercfg = GetModConfigData("Container Sort")
local itemscfg = GetModConfigData("Items collect")
local hasmultisortbtn = containercfg == -2 or containercfg == true
local haslockbutton = containercfg == -3 or containercfg == -6 -- 2025.7.9 melon:新增无提示文字版
local hassortbutton = containercfg ~= -5
local hascollectbutton = containercfg ~= -4
local craftmenucollectsupport = itemscfg ~= -1
local hasitemscollect = craftmenucollectsupport
local foodingredientcollectsupport = craftmenucollectsupport
local hasitemsstore = itemscfg ~= -2
local danger = false
local no_help_text = containercfg == -6 -- 2025.7.9 melon:新增无提示文字版
if GetModConfigData("Items collect danger") and GetModConfigData("role_nerf") then danger = true end

local isclient = TheNet:GetIsClient() or TUNING.DSA_ONE_PLAYER_MODE or
    (TheNet:GetServerIsClientHosted() and TheNet:GetIsServerAdmin())
-- 按钮位置可调整
TUNING.TEMP2HM = TUNING.TEMP2HM or {}
TUNING.TEMP2HM.btnotherdir = TUNING.TEMP2HM.btnotherdir or {}
-- 强制显示整理
TUNING.DATA2HM = TUNING.DATA2HM or {}
TUNING.DATA2HM.opensort = hassortbutton
if isclient and TUNING.TEMP2HM.opensort ~= nil then TUNING.DATA2HM.opensort = TUNING.TEMP2HM.opensort end

-- 给容器添加tag"dcs2hm"或容器inst.dcs2hm = true可以禁用对容器进行的各种功能,且不显示各类按钮
-- 不会从下列容器中收集道具
local collectwhitelist = { "seedpouch", "candybag" }
local collectblacklist = { "pandoraschest", "minotaurchest", "terrariumchest", "sisturn"}
-- 条件存放容器和黑名单白名单存放容器
local conditionstorelist = { dragonflyfurnace = function(v) return TheWorld.state.iswinter and v:HasTag("heatrock") end }
local storeblacklist = {
    "oceantree_pillar",
    "researchlab",
    "researchlab2",
    "researchlab3",
    "researchlab4",
    "plant_nepenthes_l",
    "iai_rubbishbox",
    "pandoraschest",
    "minotaurchest",
    "terrariumchest"
}
local storewhitelist = { "seedpouch", "candybag" }
-- 晾肉架相关容器
local meatracklist = {
    "meatrack", 
    "meatrack_hermit_multi", 
    "jx_pickling_barrel",  -- 景熹家居包模组 - 复古橡木腌制桶
}

local canuseinrain_meatracklist = {
    "jx_pickling_barrel",  -- 景熹家居包模组 - 复古橡木腌制桶
}

for i, v in pairs(meatracklist) do
    table.insert(collectblacklist, v)
end
-- 禁止收集存放的道具,溯源表
local itemsblacklist = { "pocketwatch_portal", "pocketwatch_recall" , "wx78_inventorycontainer"}
if ACTIONS.BEIZHU and ACTIONS.BEIZHU.str == STRINGS.SIGNS.MENU.ACCEPT then itemsblacklist = {} end
-- 优先存放容器
local prioritystorelist = { "candybag", "dragonflyfurnace" }
if TUNING.SEEDPOUCH_PRESERVER_RATE <= 0 then table.insert(prioritystorelist, 1, "seedpouch") end
local prioritystoreents = {}
for i, v in ipairs(prioritystorelist) do prioritystoreents[v] = i end
-- 道具存取特效,以及持续高亮展示
local function stopthighlightcontainer(inst)
    inst.cshighlight2hm = nil
    if inst.AnimState then
        inst.AnimState:SetMultColour(1, 1, 1, 1)
    end
end
local function starthighlightcontainer(inst)
    if inst.AnimState then inst.AnimState:SetMultColour(1, 0.6, 0, 1) end
    if inst.cshighlight2hm then inst.cshighlight2hm:Cancel() end
    inst.cshighlight2hm = inst:DoTaskInTime(60, stopthighlightcontainer)
end
local function showmovefx(inst, needparent)
    if inst.disablecsfxtask2hm then return end
    if needparent then
        -- 存放到骑乘的牛里时给骑乘者加特效
        local owner = inst.parent and inst.parent:IsValid() and inst.parent or inst
        if owner.Transform then
            SpawnPrefab("sand_puff").Transform:SetPosition(owner.Transform:GetWorldPosition())
            return
        end
    end
    if inst.Transform then SpawnPrefab("sand_puff").Transform:SetPosition(inst.Transform:GetWorldPosition()) end
end
local function delayshowmovefx(inst)
    if inst:IsInLimbo() then
        showmovefx(inst, true)
        return
    end
    if inst.disablecsfxtask2hm then return end
    inst:DoTaskInTime(0.32, showmovefx)
    starthighlightcontainer(inst)
end
-- 地面容器反向过滤检测标签列表
local GROUND_CONTAINER_CANT_TAGS = { "INLIMBO", "NOCLICK", "FX", "dcs2hm" }
-- 拾取道具过滤用标签
local PICKUP_MUST_ONEOF_TAGS = { "_inventoryitem", "pickable" }
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
    -- "spider",
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
    "donotautopick",
    -- 暗影世界模式标签
    "swc2hm",
}

-- 容器无效道具拦截补丁
AddComponentPostInit("container", function(self)
    -- 2025.11.8 夜风，跳过WX-78特殊容器，避免干扰
    if self.inst:HasTag("wx78_special_container") then return end
    
    local oldGiveItem = self.GiveItem
    self.GiveItem = function(self, item, ...)
        return item ~= nil and item:IsValid() and oldGiveItem(self, item, ...) or
            false
    end
end)

-- 自定义排序
-- No.1 实体名称 prefab nameoverride 名称优先级
-- No.2 实体组件 组件优先级
-- No.3 实体标签 标签优先级
-- No.4 实体分组 分组优先级
-- No.5 特定属性
-- 仅物品栏内道具
-- 装备，堆叠，新鲜度，食物，燃料，耐久，护甲，角色配方，材料配方，治疗配方，
-- 单容器排序算法,下面代码来自[码到成功]
local ac_fns = {
    cmp = function(p1, p2)
        if not (p1 and p2) then return end
        return tostring(p1.prefab) < tostring(p2.prefab) and true or false
    end,
    isInventory = function(inst)
        return inst.components.inventoryitem and inst.components.inventoryitem
            .canonlygoinpocket
    end,
    isEquippable = function(inst) return inst.components.equippable end,
    isStackable = function(inst) return inst.components.stackable end,
    isPerishable = function(inst) return inst.components.perishable end,
    isEdible = function(inst) return inst.components.edible end,
    hasPercent = function(inst)
        if inst.components.fueled or inst.components.finiteuses or inst.components.armor then return true end
        return false
    end,
    isCHARACTER = function(inst)
        local recipes = CRAFTING_FILTERS.CHARACTER.recipes
        if recipes and type(recipes) == "table" then for _, v in ipairs(recipes) do if inst.prefab == v then return true end end end
        return false
    end,
    isREFINE = function(inst)
        if inst.prefab == "bearger_fur" then return false end
        local recipes = CRAFTING_FILTERS.REFINE.recipes
        if recipes and type(recipes) == "table" then for _, v in ipairs(recipes) do if inst.prefab == v then return true end end end
        return false
    end,
    isRESTORATION = function(inst)
        -- 遍历治疗制作栏
        local recipes = CRAFTING_FILTERS.RESTORATION.recipes
        if recipes and type(recipes) == "table" then for _, v in ipairs(recipes) do if inst.prefab == v then return true end end end
        if inst.prefab == "jellybean" then return true end
        return false
    end,
    isSilkFabric = function(inst)
        if inst:HasTag("cattoy") or inst.prefab == "silk" or inst.prefab == "bearger_fur" or inst.prefab == "furtuft" or inst.prefab == "shroom_skin" or
            inst.prefab == "dragon_scales" then
            return true
        end
        return false
    end,
    isRocks = function(inst)
        if inst:HasTag("molebait") or inst.prefab == "townportaltalisman" or inst.prefab == "moonrocknugget" then return true end
        return false
    end,
    genericResult = function(...)
        local args = { ... }
        local result = {}
        if #args > 0 then for _, tab in ipairs(args) do for _, v in ipairs(tab) do table.insert(result, v) end end end
        return result
    end
}
-- 注意每个ifelse的判定块都必须有一张表存在，不然会丢东西。
---@param slots table[] Prefab
local function preciseClassification(slots)
    local canonlygoinpocket = {}
    local equippable = { perishable = {}, non_percentage = {}, hands = {}, head = {}, body = {}, rest = {} }
    local non_stackable = { perishable = {}, rest = {} }
    local stackable = { perishable = {}, rest = {} } -- 由于扩充表的存在，perishable 算是 rest。
    -- 扩充表内容。注意此处请提前初始化完毕，不然会弄混！
    local stackable_perishable = {
        deployedfarmplant = {},
        preparedfood = { edible_veggie = {}, edible_meat = {}, rest = {} },
        edible_veggie = {},
        edible_meat = {}
    }

    -- 初始化表。注意新加表的时候必须在此处初始化！
    equippable.perishable = equippable.perishable or {}
    equippable.non_percentage = equippable.non_percentage or {}
    equippable.hands = equippable.hands or {}
    equippable.head = equippable.head or {}
    equippable.body = equippable.body or {}
    equippable.rest = equippable.rest or {}

    non_stackable.perishable = non_stackable.perishable or {}
    non_stackable.rest[1] = non_stackable.rest[1] or {}
    non_stackable.rest[2] = non_stackable.rest[2] or {}

    stackable.perishable = stackable.perishable or {}
    stackable.rest[1] = stackable.rest[1] or {}
    stackable.rest[2] = stackable.rest[2] or {}
    stackable.rest[3] = stackable.rest[3] or {}
    stackable.rest[4] = stackable.rest[4] or {}
    stackable.rest[5] = stackable.rest[5] or {}
    stackable.rest[6] = stackable.rest[6] or {}
    stackable.rest[7] = stackable.rest[7] or {}
    stackable.rest[8] = stackable.rest[8] or {}
    stackable.rest[9] = stackable.rest[9] or {}

    slots = slots or {}

    if #slots > 0 then
        for _, v in ipairs(slots) do
            if v ~= nil then
                if ac_fns.isInventory(v) then
                    table.insert(canonlygoinpocket, v)
                elseif ac_fns.isEquippable(v) then
                    local equipslot = v.components.equippable.equipslot
                    if ac_fns.isPerishable(v) then
                        table.insert(equippable.perishable, v)
                    elseif not ac_fns.hasPercent(v) or (ac_fns.hasPercent(v) and v:HasTag("hide_percentage")) then
                        table.insert(equippable.non_percentage, v)
                    elseif equipslot == EQUIPSLOTS.HANDS then
                        table.insert(equippable.hands, v)
                    elseif equipslot == EQUIPSLOTS.HEAD then
                        table.insert(equippable.head, v)
                    elseif equipslot == EQUIPSLOTS.BODY then
                        table.insert(equippable.body, v)
                    else
                        table.insert(equippable.rest, v) -- 剩余
                    end
                elseif not ac_fns.isStackable(v) then
                    if ac_fns.isPerishable(v) then
                        table.insert(non_stackable.perishable, v)
                    elseif ac_fns.hasPercent(v) then
                        table.insert(non_stackable.rest[1], v)
                    else
                        table.insert(non_stackable.rest[2], v) -- 剩余
                    end
                else
                    if ac_fns.isPerishable(v) then
                        if v:HasTag("deployedfarmplant") then
                            table.insert(stackable_perishable.deployedfarmplant, v)
                        elseif v:HasTag("preparedfood") then
                            if ac_fns.isEdible(v) then
                                if v.components.edible.foodtype == FOODTYPE.VEGGIE then
                                    table.insert(stackable_perishable.preparedfood.edible_veggie, v)
                                elseif v.components.edible.foodtype == FOODTYPE.MEAT then
                                    table.insert(stackable_perishable.preparedfood.edible_meat, v)
                                else
                                    table.insert(stackable_perishable.preparedfood.rest, v) -- 剩余
                                end
                            else
                                table.insert(stackable_perishable.preparedfood.rest, v) -- 剩余
                            end
                        else
                            if ac_fns.isEdible(v) then
                                if v.components.edible.foodtype == FOODTYPE.VEGGIE then
                                    table.insert(stackable_perishable.edible_veggie, v)
                                elseif v.components.edible.foodtype == FOODTYPE.MEAT then
                                    table.insert(stackable_perishable.edible_meat, v)
                                else
                                    table.insert(stackable.perishable, v) -- 剩余
                                end
                            else
                                table.insert(stackable.perishable, v) -- 剩余
                            end
                        end
                    elseif v:HasTag("fertilizerresearchable") then
                        table.insert(stackable.rest[4], v)
                    elseif ac_fns.isCHARACTER(v) then
                        table.insert(stackable.rest[7], v)
                    elseif ac_fns.isRESTORATION(v) then
                        table.insert(stackable.rest[6], v)
                    elseif v:HasTag("gem") then
                        table.insert(stackable.rest[1], v)
                    elseif ac_fns.isRocks(v) then
                        table.insert(stackable.rest[2], v)
                    elseif ac_fns.isREFINE(v) then
                        table.insert(stackable.rest[8], v)
                    elseif ac_fns.isSilkFabric(v) then
                        table.insert(stackable.rest[5], v)
                    elseif ac_fns.isEdible(v) then
                        table.insert(stackable.rest[9], v)
                    else
                        table.insert(stackable.rest[3], v) -- 剩余
                    end
                end
            end
        end
    end

    local cmp = ac_fns.cmp

    -- 首先把列表里面的项全按字典序排列一遍
    table.sort(canonlygoinpocket, cmp)
    table.sort(equippable.perishable, cmp)     -- perishable
    table.sort(equippable.non_percentage, cmp) -- non_percentage
    table.sort(equippable.hands, cmp)          -- hands
    table.sort(equippable.head, cmp)           -- head
    table.sort(equippable.body, cmp)           -- body
    table.sort(equippable.rest, cmp)           -- rest

    table.sort(non_stackable.perishable, cmp)  -- perishable
    table.sort(non_stackable.rest[1], cmp)     -- hasPercent
    table.sort(non_stackable.rest[2], cmp)     -- rest

    table.sort(stackable.perishable, cmp)      -- perishable
    table.sort(stackable.rest[1], cmp)         -- tag:gem
    table.sort(stackable.rest[2], cmp)         -- tag:molebait
    table.sort(stackable.rest[3], cmp)         -- rest
    table.sort(stackable.rest[4], cmp)         -- tag:fertilizerresearchable
    table.sort(stackable.rest[5], cmp)         -- custom: 丝织类
    table.sort(stackable.rest[6], cmp)         -- custom: 治疗
    table.sort(stackable.rest[7], cmp)         -- custom: 人物
    table.sort(stackable.rest[8], cmp)         -- custom: 精炼
    table.sort(stackable.rest[9], cmp)         -- custom: 食用

    table.sort(stackable_perishable.deployedfarmplant, cmp)
    table.sort(stackable_perishable.edible_veggie, cmp)
    table.sort(stackable_perishable.edible_meat, cmp)
    table.sort(stackable_perishable.preparedfood.edible_veggie, cmp)
    table.sort(stackable_perishable.preparedfood.edible_meat, cmp)
    table.sort(stackable_perishable.preparedfood.rest, cmp)

    -- 请保证健壮性。如果漏东西，那么问题是会非常严重的。

    -- 2023-03-13-20:08：搞复杂了，没必要。之后简化一下！！！而且其实没这么细！有些交集太多了。但是到底应该怎么设计呢？
    return ac_fns.genericResult(canonlygoinpocket,                                                      -- 装备：头部、身体、手部、剩余、无百分比
        equippable.head, equippable.body, equippable.hands, equippable.rest, equippable.non_percentage, -- 不可堆叠：有百分比、剩余
        non_stackable.rest[1], non_stackable.rest[2],                                                   -- 可堆叠：人物、治疗、可食用、宝石、鼹鼠爱吃的、丝织类、精炼、剩余、粪肥
        stackable.rest[7], stackable.rest[6], stackable.rest[9], stackable.rest[1], stackable.rest[2], stackable.rest[5],
        stackable.rest[8], stackable.rest[3],
        stackable.rest[4], -- 装备：有新鲜度；
        -- 不可堆叠：有新鲜度；
        -- 可堆叠有新鲜度：种子、可食用素、可食用荤、剩余；
        -- 可堆叠有新鲜度的料理：可食用素、可食用荤、剩余；
        equippable.perishable, non_stackable.perishable, stackable_perishable.deployedfarmplant,
        stackable_perishable.edible_veggie,
        stackable_perishable.edible_meat, stackable.perishable, -- rest
        stackable_perishable.preparedfood.edible_veggie, stackable_perishable.preparedfood.edible_meat,
        stackable_perishable.preparedfood.rest)
end
-- 上面代码来自[码到成功]
-- 容器整理
local sort_blacklist = {}
local function dosort(inst)
    if not (inst.components.container and inst.components.container.acceptsstacks and not inst.components.container.usespecificslotsforitems or
            inst.components.inventory) then
        return
    end
    local container = inst.components.inventory or inst.components.container
    container.ignoresound = true
    container.ignoreoverstacked = true
    local totalslots = {}
    for k, v in pairs(container.itemslots or container.slots) do
        if v then
            local item = container:GetItemInSlot(k)
            if not (item.components.inventoryitem and item.components.inventoryitem.islockedinslot == true) or table.contains(sort_blacklist, item.prefab) then
                item = container:RemoveItemBySlot(k)
            end
            if item ~= nil and item:IsValid() and not (item.components.inventoryitem and item.components.inventoryitem.islockedinslot == true) then
                item.prevslot = nil
                table.insert(totalslots, item)
            end
        end
    end
    totalslots = preciseClassification(totalslots)
    for i, item in ipairs(totalslots) do container:GiveItem(item) end
    container.ignoresound = false
    container.ignoreoverstacked = false
end
local function sortfn(player, inst)
    if inst.components.container and not inst:HasTag("dcs2hm") and not inst.dcs2hm and not inst.components.container.usespecificslotsforitems and
        inst.components.container.acceptsstacks then
        dosort(inst)
        if inst.components.equippable and inst.components.equippable:IsEquipped() then dosort(player) end
    end
end
-- 容器跨整,和容器锁定互斥，所以不需要检测itemtestfnprefabs2hm
local function domultisort(inst, player)
    if not (player.components.inventory and inst.components.container) then return end
    -- ents是除inst外其他要一起处理的容器,inst不需要放在里面
    local ents = {}
    if inst.components.equippable and inst.components.equippable:IsEquipped() then
        -- 糖果袋类和无限类的背包单独处理
        if inst.components.container.itemtestfn ~= nil or inst.components.container.itemtestfnprefabs2hm ~= nil or inst.components.container.infinitestacksize then
            dosort(inst)
            dosort(player)
            return
        end
        -- 装备的背包则一起处理自己和物品栏
        table.insert(ents, inst)
        inst = player
    elseif inst.components.inventoryitem and inst.components.inventoryitem.owner and
        (inst.components.inventoryitem.owner.components.inventory or inst.components.inventoryitem.owner.components.container) then
        -- 携带的或存在容器内的钓具箱类容器只处理自己和自己所处容器内的同类容器
        local hasothercontainers = false
        local container = (inst.components.inventoryitem.owner.components.inventory or inst.components.inventoryitem.owner.components.container)
        for k, v in pairs(container.itemslots or container.slots) do
            if v:IsValid() and v ~= inst and not v:HasTag("dcs2hm") and not v.dcs2hm and v.components.container and v.components.container.canbeopened and
                v.components.container.acceptsstacks and not v.components.container.usespecificslotsforitems and v.components.container.itemtestfn ==
                inst.components.container.itemtestfn and v.components.container.infinitestacksize == inst.components.container.infinitestacksize then
                hasothercontainers = true
                table.insert(ents, v)
            end
        end
        if not hasothercontainers then
            dosort(inst)
            return
        end
    elseif inst.components.inventoryitem and not inst:HasTag("heavy") then
        -- 地面背包或地面钓具箱则只处理自己,支持带有heavy标签的装备容器
        dosort(inst)
        return
    else
        -- 地面容器则只处理同类且同名的容器
        local x, y, z = inst.Transform:GetWorldPosition()
        local platform = inst:GetCurrentPlatform()
        local nearents = TheSim:FindEntities(x, y, z, 36, nil, GROUND_CONTAINER_CANT_TAGS)
        local hasothercontainers = false
        for i, v in ipairs(nearents) do
            if v ~= inst and v:IsValid() and v.prefab == inst.prefab and not v.dcs2hm and v.components.container and v.components.container.canbeopened and
                v.components.container.acceptsstacks and not v.components.container.usespecificslotsforitems and v.components.container.itemtestfn ==
                inst.components.container.itemtestfn and v.components.container.infinitestacksize == inst.components.container.infinitestacksize and
                v:GetCurrentPlatform() == platform then
                hasothercontainers = true
                showmovefx(v)
                table.insert(ents, v)
            end
        end
        if not hasothercontainers then
            dosort(inst)
            return
        end
    end
    local totalslots = {}
    -- 首先主容器物品收集
    local container = inst.components.inventory or inst.components.container
    container.ignoresound = true
    container.ignoreoverstacked = true
    for k, v in pairs(container.itemslots or container.slots) do
        if v then
            local item = container:RemoveItemBySlot(k)
            if item ~= nil and item:IsValid() then
                item.prevslot = nil
                table.insert(totalslots, item)
            end
        end
    end
    -- 其次额外的容器物品收集
    local tmpents = {}
    if inst.virtchest and inst.virtchest:IsValid() and inst.virtchest.components.container then
        table.insert(tmpents,
            inst.virtchest)
    end
    for i, v in ipairs(ents) do
        table.insert(tmpents, v)
        if v.virtchest and v.virtchest:IsValid() and v.virtchest.components.container then
            table.insert(tmpents,
                v.virtchest)
        end
    end
    for i, v in ipairs(tmpents) do
        local tmpcontainer = v.components.container
        tmpcontainer.ignoresound = true
        tmpcontainer.ignoreoverstacked = true
        for k, v in pairs(tmpcontainer.slots) do
            if v then
                local item = tmpcontainer:RemoveItemBySlot(k)
                if item ~= nil and item:IsValid() then
                    item.prevslot = nil
                    table.insert(totalslots, item)
                end
            end
        end
    end
    -- 用一个大容器容纳上面所有道具一起整理
    local tmp = CreateEntity()
    tmp:AddComponent("container")
    -- 火女的余烬存放进去后会读取主人的skilltree
    if inst == player then tmp:AddComponent("skilltreeupdater") end
    tmp.components.container.ShouldPrioritizeContainer = truefn
    tmp.components.container.CanTakeItemInSlot = truefn
    tmp.components.container:SetNumSlots(#totalslots)
    if container.infinitestacksize then tmp.components.container:EnableInfiniteStackSize() end
    tmp.components.container.ignoresound = true
    for _, item in ipairs(totalslots) do tmp.components.container:GiveItem(item) end
    dosort(tmp)
    tmp.components.container.ignoresound = true
    tmp.components.container.ignoreoverstacked = true
    -- 分配到各个容器
    local finalslots = tmp.components.container.slots
    -- 第一个容器准备放入
    local entindex = 1
    local entsnumslots = ents[1].components.container.numslots + (container.maxslots or container.numslots)
    for index, item in ipairs(finalslots) do
        local item = tmp.components.container:RemoveItemBySlot(index)
        if not ents[entindex] then
            ents[1].components.container:GiveItem(item)
        elseif index <= (container.maxslots or container.numslots) then
            -- 在放入第一个容器前,优先分配给inst容器
            container:GiveItem(item)
        elseif index <= entsnumslots then
            -- 准备放入的容器还未放满
            ents[entindex].components.container:GiveItem(item)
        else
            entindex = entindex + 1
            if ents[entindex] then
                -- 准备放入的容器已放满,下一个容器准备放入
                entsnumslots = entsnumslots + ents[entindex].components.container.numslots
                ents[entindex].components.container:GiveItem(item)
            else
                ents[1].components.container:GiveItem(item)
            end
        end
    end
    tmp:Remove()
    container.ignoresound = false
    container.ignoreoverstacked = false
    for i, v in ipairs(tmpents) do
        v.components.container.ignoresound = false
        v.components.container.ignoreoverstacked = false
    end
end
local function multisortfn(player, inst)
    if (hasmultisortbtn or (inst.components.equippable and inst.components.equippable:IsEquipped())) and inst.components.container and not inst:HasTag("dcs2hm") and
        not inst.dcs2hm and not inst.components.container.usespecificslotsforitems and inst.components.container.acceptsstacks then
        domultisort(inst, player)
    end
end
-- 整理按钮和跨整按钮
AddModRPCHandler("MOD_HARDMODE", "sortbtn2hm", sortfn)
local function sortbtnfn(inst, doer)
    if inst.components.container ~= nil then
        sortfn(doer, inst)
    elseif inst.replica.container ~= nil then
        SendModRPCToServer(GetModRPC("MOD_HARDMODE", "sortbtn2hm"), inst)
    end
end
AddModRPCHandler("MOD_HARDMODE", "multisortbtn2hm", multisortfn)
local function multisortbtnfn(inst, doer)
    if inst.components.container ~= nil then
        multisortfn(doer, inst)
    elseif inst.replica.container ~= nil then
        SendModRPCToServer(GetModRPC("MOD_HARDMODE", "multisortbtn2hm"), inst)
    end
end
local function doublesortbtnfn(inst, doer)
    inst.doubleclicktask2hm = nil
    if inst.doubleclicktrue2hm then
        multisortbtnfn(inst, doer)
        inst.doubleclicktrue2hm = nil
    end
end
local function realsortbtnfn(inst, doer)
    if (inst.components.equippable and inst.components.equippable:IsEquipped()) or (inst.replica.equippable and inst.replica.equippable:IsEquipped()) then
        if not inst.doubleclicktask2hm then
            inst.doubleclicktask2hm = inst:DoTaskInTime(0.25, doublesortbtnfn, doer)
            sortbtnfn(inst, doer)
        else
            inst.doubleclicktrue2hm = not inst.doubleclicktrue2hm
            inst.doubleclicktask2hm:Cancel()
            inst.doubleclicktask2hm = inst:DoTaskInTime(0.25, doublesortbtnfn, doer)
        end
    else
        sortbtnfn(inst, doer)
    end
end
local function defaultbtnvalidfn(inst)
    return (inst.components.container ~= nil or inst.replica.container ~= nil) and not inst:HasTag("dcs2hm") and
        not inst.dcs2hm and not inst:HasTag("exchangeloading2hm")
end

-- 末影箱穿越：持久化事务服务，整箱交换与双层同步存档。
local function canexchange(player, inst)
    return TheWorld.ismastersim and player and player:IsValid() and inst and inst:IsValid() and
        inst:HasTag("pocketdimension_container") and inst.components.container and
        inst.components.container.openlist[player] ~= nil
end
local function exchangefn(player, inst)
    if canexchange(player, inst) and TheWorld.components.worldexchange2hm then
        TheWorld.components.worldexchange2hm:Request(player, inst)
    end
end
AddModRPCHandler("MOD_HARDMODE", "exchangebtn2hm", exchangefn)
local function exchangevalidfn(inst)
    return defaultbtnvalidfn(inst) and inst:HasTag("pocketdimension_container") and not inst:HasTag("exchangeloading2hm")
end
local function exchangebtnfn(inst, doer)
    if TheWorld.ismastersim then exchangefn(doer, inst)
    else SendModRPCToServer(GetModRPC("MOD_HARDMODE", "exchangebtn2hm"), inst) end
end
local function exchangestatusfn(player, inst)
    if canexchange(player, inst) and TheWorld.components.worldexchange2hm then
        TheWorld.components.worldexchange2hm:Status(player)
    end
end
AddModRPCHandler("MOD_HARDMODE", "exchangestatus2hm", exchangestatusfn)
local function exchangestatusbtnfn(inst, doer)
    if TheWorld.ismastersim then exchangestatusfn(doer, inst)
    else SendModRPCToServer(GetModRPC("MOD_HARDMODE", "exchangestatus2hm"), inst) end
end
local function exchangestatusvalidfn(inst)
    return inst and inst:HasTag("pocketdimension_container")
end

-- 容器收集
local function getfinalowner(inst)
    return inst.components.inventoryitem and inst.components.inventoryitem.owner and
        getfinalowner(inst.components.inventoryitem.owner) or inst
end
local function iscontainerchild(inst, container)
    if not container.components.container then return false end
    local owner = inst.components.inventoryitem and inst.components.inventoryitem.owner
    if owner == container then
        return true
    elseif owner ~= nil then
        return iscontainerchild(owner, container)
    end
end
local function findcontainersincontainer(inst, result)
    for k, v in pairs(inst.components.container.slots) do
        if v and v:IsValid() and not v:HasTag("dcs2hm") and not v.dcs2hm and v.components.container and v.components.container.canbeopened then
            table.insert(result, v)
            findcontainersincontainer(v, result)
        end
    end
end
local function givecontaineritem(container, item, src_pos)
    if item.components.stackable and not container.infinitestacksize then
        local slotsize = item.components.stackable.originalmaxsize or item.components.stackable.maxsize
        if slotsize and item.components.stackable.stacksize > slotsize then
            local size = item.components.stackable.stacksize
            local totalsize = size + slotsize
            for i = slotsize, totalsize, slotsize do
                local giveitem = item.components.stackable:Get(slotsize)
                giveitem.currplayer2hm = item.currplayer2hm
                container:GiveItem(giveitem, nil, i > size and src_pos or nil)
                if giveitem and giveitem:IsValid() then giveitem.currplayer2hm = nil end
            end
            return
        end
    end
    container:GiveItem(item, nil, src_pos)
    if item and item:IsValid() then item.currplayer2hm = nil end
end
-- data必选参数:prefabfn,prefabs,leftnumslots,lacksize,exchangeitem,exchangeitemfn
-- data可选参数:infiniteprefabs,neednum,fastresult,currplayer2hm --返回时data参数:entfx
-- infiniteprefabs 代表contaienr组件可以无限收集某些实体
-- neednum 代表只收集固定数额后就结束收集,返回true
-- fastresult 代表只收集一次实体后就结束收集,返回true
-- prefabfn是container组件要收集的特定实体
-- prefabs是container组件要收集的实体表
-- leftnumslots是container组件的空白格子数目
-- lacksize是container组件每个要收集的堆叠实体的重叠格子的剩余空间
-- exchangeitem,在fastresult启用时和收集实体交换
-- exchangeitemfn,交换后触发一个信号
local function collectentcontaineritem(inst, container, item, ent, entcontainer, i, data)
    if (data.prefabfn and data.prefabfn(item) or (data.prefabs and table.contains(data.prefabs, item.prefab))) and item ~= inst and
        not iscontainerchild(inst, item) and container:CanTakeItemInSlot(item) then
        if data.infiniteprefabs then
            if data.infiniteprefabs[item.prefab] then
                -- 无限需求堆叠道具,所以可以无限给予
                container:GiveItem(entcontainer:RemoveItemBySlot(i), nil, data.entpos)
                if not data.entfx then data.entfx = true end
            elseif data.leftnumslots > 0 then
                -- 非堆叠道具或新加道具则只能放到有限的空格
                data.leftnumslots = data.leftnumslots - 1
                local item = entcontainer:RemoveItemBySlot(i)
                if container:GiveItem(item, nil, data.entpos) and item:IsValid() and item.components.stackable and item.components.stackable.maxsize ==
                    math.huge then
                    data.infiniteprefabs[item.prefab] = true
                end
                if not data.entfx then data.entfx = true end
            end
        elseif data.neednum then
            -- 收集配方时的收集固定数目需求,则获得固定数目道具后结束
            if item.components.stackable then
                if not data.realneednum then
                    data.realneednum = true
                    local slotsize = item.components.stackable.originalmaxsize or item.components.stackable.maxsize
                    local leftsize = (data.lacksize[item.prefab] or 0) + slotsize * data.leftnumslots
                    data.neednum = math.min(data.neednum, leftsize)
                end
                if item.components.stackable.stacksize <= data.neednum then
                    local newitem = entcontainer:RemoveItem(item, true)
                    data.neednum = data.neednum - item.components.stackable.stacksize
                    newitem.currplayer2hm = data.currplayer2hm
                    container:GiveItem(newitem, nil, data.entpos)
                    if newitem and newitem:IsValid() then newitem.currplayer2hm = nil end
                else
                    local givenum = math.min(item.components.stackable.stacksize, data.neednum)
                    data.neednum = data.neednum - givenum
                    local giveitem = item.components.stackable:Get(givenum)
                    giveitem.currplayer2hm = data.currplayer2hm
                    givecontaineritem(container, giveitem, data.entpos)
                end
            else
                if not data.realneednum then
                    data.realneednum = true
                    data.neednum = math.min(data.neednum, data.leftnumslots)
                end
                data.neednum = data.neednum - 1
                local giveitem = entcontainer:RemoveItemBySlot(i)
                giveitem.currplayer2hm = data.currplayer2hm
                container:GiveItem(giveitem, nil, data.entpos)
                if giveitem and giveitem:IsValid() then giveitem.currplayer2hm = nil end
            end
            if not data.entfx then data.entfx = true end
            if data.neednum <= 0 then return true end
        elseif data.fastresult then
            -- 收集配方时的收集更多需求,则拿到本道具后就结束
            local giveitem
            if item.components.stackable then
                local slotsize = item.components.stackable.originalmaxsize or item.components.stackable.maxsize
                giveitem = item.components.stackable:Get(slotsize)
                giveitem.currplayer2hm = data.currplayer2hm
            else
                giveitem = entcontainer:RemoveItemBySlot(i)
                giveitem.currplayer2hm = data.currplayer2hm
            end
            if data.exchangeitem and data.exchangeitem:IsValid() and data.exchangeitem.components.inventoryitem and
                data.exchangeitem.components.inventoryitem.owner then
                local owner = data.exchangeitem.components.inventoryitem.owner
                local ownercontainer = owner.components.inventory or owner.components.container
                if ownercontainer then
                    for key, value in pairs(ownercontainer.slots or ownercontainer.itemslots) do
                        if value == data.exchangeitem then
                            local exchangeitem = ownercontainer:RemoveItemBySlot(key)
                            entcontainer:GiveItem(exchangeitem, i, getfinalowner(owner):GetPosition())
                            container:GiveItem(giveitem, key, data.entpos)
                            if data.exchangeitemfn and exchangeitem:IsValid() and giveitem:IsValid() then
                                data.exchangeitemfn(exchangeitem, giveitem)
                            end
                            break
                        end
                    end
                end
            else
                container:GiveItem(giveitem, nil, data.entpos)
            end
            if giveitem:IsValid() then giveitem.currplayer2hm = nil end
            if not data.entfx then data.entfx = true end
            return true
        elseif data.lacksize[item.prefab] and item.components.stackable then -- 有限需求
            -- 有限需求,处理需求与供给数目关系
            if data.lacksize[item.prefab] >= item.components.stackable.stacksize then
                -- 重叠格子用不完,直接给
                data.lacksize[item.prefab] = data.lacksize[item.prefab] - item.components.stackable.stacksize
                if data.lacksize[item.prefab] <= 0 then data.lacksize[item.prefab] = nil end
                local giveitem = entcontainer:RemoveItemBySlot(i)
                container:GiveItem(giveitem, nil, data.entpos)
                if not data.entfx then data.entfx = true end
            elseif data.leftnumslots > 0 then
                -- 重叠格子会用完,但还有空白格子
                local slotsize = item.components.stackable.originalmaxsize or item.components.stackable.maxsize
                local leftsize = data.lacksize[item.prefab] + slotsize * data.leftnumslots
                if leftsize <= item.components.stackable.stacksize then
                    -- 重叠和空白格子都会被该道具堆满,(额要收集的容器有问题,堆叠数目似乎太高了吧)
                    data.leftnumslots = 0
                    data.lacksize[item.prefab] = nil
                    local giveitem = item.components.stackable:Get(leftsize)
                    givecontaineritem(container, giveitem, data.entpos)
                    if not data.entfx then data.entfx = true end
                    -- 全部堆满,则结束收集
                    if IsTableEmpty(data.lacksize) then return true end
                else
                    -- 还能残留空间
                    local useleftslotsize = item.components.stackable.stacksize - data.lacksize[item.prefab]
                    data.leftnumslots = data.leftnumslots - math.ceil(useleftslotsize / slotsize)
                    data.lacksize[item.prefab] = data.leftnumslots * slotsize - useleftslotsize -
                        data.leftnumslots * slotsize
                    if data.lacksize[item.prefab] <= 0 then data.lacksize[item.prefab] = nil end
                    local giveitem = entcontainer:RemoveItemBySlot(i)
                    givecontaineritem(container, giveitem, data.entpos)
                    if not data.entfx then data.entfx = true end
                end
            elseif data.lacksize[item.prefab] > 0 then
                -- 重叠格子会用完,且没有空白格子
                local giveitem = item.components.stackable:Get(data.lacksize[item.prefab])
                data.lacksize[giveitem.prefab] = nil
                container:GiveItem(giveitem, nil, data.entpos)
                if not data.entfx then data.entfx = true end
                -- 全部堆满,则结束收集
                if IsTableEmpty(data.lacksize) then return true end
            end
        elseif data.leftnumslots > 0 then
            -- 没有重叠格子但有空白格子
            if item.components.stackable then
                local slotsize = item.components.stackable.originalmaxsize or item.components.stackable.maxsize
                local leftsize = slotsize * data.leftnumslots
                if leftsize <= item.components.stackable.stacksize then
                    -- 空白格子都会被该道具堆满
                    data.leftnumslots = 0
                    local giveitem = item.components.stackable:Get(leftsize)
                    givecontaineritem(container, giveitem, data.entpos)
                    if not data.entfx then data.entfx = true end
                    -- 全部堆满,则结束收集
                    if IsTableEmpty(data.lacksize) then return true end
                else
                    -- 还能残留空间
                    data.leftnumslots = data.leftnumslots - math.ceil(item.components.stackable.stacksize / slotsize)
                    data.lacksize[item.prefab] = leftsize - item.components.stackable.stacksize -
                        data.leftnumslots * slotsize
                    if data.lacksize[item.prefab] <= 0 then data.lacksize[item.prefab] = nil end
                    local giveitem = entcontainer:RemoveItemBySlot(i)
                    givecontaineritem(container, giveitem, data.entpos)
                    if not data.entfx then data.entfx = true end
                end
            else
                data.leftnumslots = data.leftnumslots - 1
                container:GiveItem(entcontainer:RemoveItemBySlot(i), nil, data.entpos)
            end
            if not data.entfx then data.entfx = true end
            if data.leftnumslots <= 0 and IsTableEmpty(data.lacksize) then return true end
        elseif IsTableEmpty(data.lacksize) then
            return true
        end
    end
end
local function collectcontainers(inst, container, data, ents)
    local result
    local fxents = {}
    container.ignoresound = true
    for _, ent in ipairs(ents) do
        if ent ~= inst and ent.components.container then
            local entcontainer = ent.components.container
            local finalent = getfinalowner(ent.virtfrom2hm or ent)
            if data.proxyents and data.proxyents[finalent] then finalent = data.proxyents[finalent] end
            data.entpos = finalent:GetPosition()
            entcontainer.ignoreoverstacked = true
            for i = entcontainer.numslots, 1, -1 do
                local item = entcontainer.slots[i]
                if item and item:IsValid() and collectentcontaineritem(inst, container, item, ent, entcontainer, i, data) then
				if danger and data.doer and data.doer:IsValid() and data.doer.components.hunger then data.doer.components.hunger:DoDelta(-0.2) end
                    result = true
                    break
                end
            end
            entcontainer.ignoreoverstacked = false
            if data.entfx then
                data.entfx = nil
                if not table.contains(fxents, finalent) then table.insert(fxents, finalent) end
            end
            if result then break end
        elseif ent ~= inst and ent.components.inventory then
            data.entpos = ent:GetPosition()
            for i = ent.components.inventory.maxslots, 1, -1 do
                local item = ent.components.inventory.itemslots[i]
                if item and item:IsValid() and collectentcontaineritem(inst, container, item, ent, ent.components.inventory, i, data) then
				if danger and data.doer and data.doer:IsValid() and data.doer.components.hunger then data.doer.components.hunger:DoDelta(-0.2) end
                    result = true
                    break
                end
            end
            if data.entfx then
                data.entfx = nil
                if not table.contains(fxents, finalent) then table.insert(fxents, finalent) end
            end
            if result then break end
        end
    end
    container.ignoresound = false
    for index, ent in ipairs(fxents) do showmovefx(ent) end
    return result
end
local function getcontainerspace(inst, container, data, addprefab)
    local slots = container.slots or container.itemslots
    local numslots = container.numslots or container.maxslots
    -- 没有剩余空间时返回true
    if data.prefabfn == nil then data.prefabs = data.prefabs or {} end
    data.infiniteprefabs = data.infiniteprefabs or {}
    data.lacksize = data.lacksize or {}
    data.leftnumslots = (data.leftnumslots or 0) + numslots
    for i = 1, numslots do
        local item = slots[i]
        if item ~= nil and item:IsValid() then
            data.leftnumslots = data.leftnumslots - 1
            local hasprefab = (data.prefabfn and data.prefabfn(item) or (data.prefabs and table.contains(data.prefabs, item.prefab)))
            if not hasprefab and addprefab ~= false and data.prefabs and not table.contains(itemsblacklist, item.prefab) then
                table.insert(data.prefabs, item.prefab)
                hasprefab = true
            end
            if hasprefab and item.components.stackable then
                if container.infinitestacksize or item.components.stackable.maxsize == math.huge then
                    data.infiniteprefabs[item.prefab] = true
                    if data.lacksize[item.prefab] then data.lacksize[item.prefab] = nil end
                elseif not data.infiniteprefabs[item.prefab] and item.components.stackable.stacksize < item.components.stackable.maxsize then
                    data.lacksize[item.prefab] = (data.lacksize[item.prefab] or 0) + item.components.stackable.maxsize -
                        item.components.stackable.stacksize
                end
            end
        end
    end
    if (data.prefabs and #data.prefabs == 0) or (data.leftnumslots == 0 and IsTableEmpty(data.infiniteprefabs) and IsTableEmpty(data.lacksize)) then
        return true
    end
    if IsTableEmpty(data.infiniteprefabs) then data.infiniteprefabs = nil end
end
local function endcollectloading(inst) inst.collectloadingtask2hm = nil end
local function docollect(inst, player)
    if not (inst.components.container and inst.components.container.numslots > 0 and #inst.components.container.slots > 0 and player.components.inventory) then
        return
    end
    inst.collectloadingtask2hm = inst:DoTaskInTime(0.3, endcollectloading)
    local container = inst.components.container
    local data = {}
    if getcontainerspace(inst, container, data) then return end
    -- 记录要收集道具的来源容器列表
    local ents = {}
    if inst.components.inventoryitem and inst.components.inventoryitem.owner then
        -- 携带容器->自己所在根容器
        local owner = getfinalowner(inst)
        local ownercontainer = owner.components.inventory or owner.components.container
        if not owner:HasTag("dcs2hm") and not owner.dcs2hm and ownercontainer then table.insert(ents, owner) end
        if ownercontainer then
            for k, v in pairs(ownercontainer.itemslots or ownercontainer.slots) do
                if v and v:IsValid() and v.components.container and not v:HasTag("dcs2hm") and not v.dcs2hm and v.components.container.canbeopened then
                    table.insert(ents, v)
                    findcontainersincontainer(v, ents)
                end
            end
        end
        if owner.components.inventory then
            for k, v in pairs(EQUIPSLOTS) do
                local equip = owner.components.inventory:GetEquippedItem(v)
                if equip ~= nil and equip.components.container ~= nil and not equip:HasTag("dcs2hm") and not equip.dcs2hm then
                    table.insert(ents, equip)
                    findcontainersincontainer(equip, ents)
                end
            end
            local mount = owner.components.rider and owner.components.rider.mount
            if mount and mount:IsValid() and mount.components.container and not mount:HasTag("dcs2hm") and not mount.dcs2hm then
                table.insert(ents, mount)
                findcontainersincontainer(mount, ents)
            end
        end
    else
        -- 地面容器->内部容器和周围的地面容器
        data.proxyents = {}
        findcontainersincontainer(inst, ents)
        if not inst.components.inventoryitem or inst:HasTag("heavy") then
            local x, y, z = inst.Transform:GetWorldPosition()
            local platform = inst:GetCurrentPlatform()
            local nearents = TheSim:FindEntities(x, y, z, 30, nil, GROUND_CONTAINER_CANT_TAGS)
            for i, v in ipairs(nearents) do
                if v ~= inst and v:IsValid() then
                    if v.components.container_proxy and not v.dcs2hm and v.components.container_proxy:CanBeOpened() and not v.components.container and
                        not table.contains(collectblacklist, v.prefab) and v:GetCurrentPlatform() == platform then
                        local master = v.components.container_proxy.master
                        if master and master:IsValid() and not data.proxyents[master] and master.components.container and
                            master.components.container.canbeopened then
                            master.currentpocket2hm = v
                            data.proxyents[master] = v
                            table.insert(ents, master)
                            findcontainersincontainer(master, ents)
                        end
                    elseif v.components.container and not v.dcs2hm and v.components.container.canbeopened and
                        (table.contains(collectwhitelist, v.prefab) or not v.components.inventoryitem or v:HasTag("heavy")) and
                        not player.components.inventory.opencontainers[v] and not table.contains(collectblacklist, v.prefab) and v:GetCurrentPlatform() ==
                        platform then
                        table.insert(ents, v)
                        findcontainersincontainer(v, ents)
                    end
                end
            end
        end
    end
    for i = #ents, 1, -1 do
        if ents[i] == inst then
            table.remove(ents, i)
            break
        end
    end
    if #ents <= 0 then return end
    local tmpents = {}
    -- if inst.virtchest and inst.virtchest:IsValid() and inst.virtchest.components.container then table.insert(tmpents, inst.virtchest) end
    for i, v in ipairs(ents) do
        table.insert(tmpents, v)
        if v.virtchest and v.virtchest:IsValid() and v.virtchest.components.container then
            table.insert(tmpents,
                v.virtchest)
        end
    end
    -- 进行收集道具操作
    data.currplayer2hm = inst
    collectcontainers(inst, container, data, tmpents)
end
local function collectfn(player, inst)
    -- 混合拾取和收纳时,拾取后短暂时间内不会进行收纳
    if hascollectbutton and inst.components.container ~= nil and not inst.collectloadingtask2hm and not inst:HasTag("dcs2hm") and not inst.dcs2hm and
        not inst.components.container.usespecificslotsforitems and inst.components.container.acceptsstacks then
        docollect(inst, player)
    end
end
local function dopickup(inst, player)
    if not (player.components.inventory and (inst.components.inventory or (inst.components.container))) then return end
    -- 检测是否装备懒人护符
    local hasorangeamulet = false
    local data = {}
    for k, v in pairs(player.components.inventory.equipslots) do
        if v and v.prefab == "orangeamulet" and v:IsValid() and
            ((v.components.finiteuses and v.components.finiteuses.current > 1) or (v.components.fueled and v.components.fueled.currentfuel > 1)) then
            data.orangeamulet = v
            data.beforefiniteuses = v.components.finiteuses and v.components.finiteuses.current - 1 or
                (v.components.fueled and v.components.fueled.currentfuel - 1)
            data.finiteuses = data.beforefiniteuses
            hasorangeamulet = true
            break
        end
    end
    if not hasorangeamulet then
        local activeitem = player.components.inventory.activeitem
        if activeitem and activeitem.prefab == "orangeamulet" and activeitem:IsValid() and
            ((activeitem.components.finiteuses and activeitem.components.finiteuses.current > 1) or
                (activeitem.components.fueled and activeitem.components.fueled.currentfuel > 1)) then
            data.orangeamulet = activeitem
            data.beforefiniteuses = activeitem.components.finiteuses and activeitem.components.finiteuses.current - 1 or
                (activeitem.components.fueled and activeitem.components.fueled.currentfuel - 1)
            data.finiteuses = data.beforefiniteuses
            hasorangeamulet = true
        end
    end
    if not hasorangeamulet then return end
    inst.collectloadingtask2hm = inst:DoTaskInTime(0.3, endcollectloading)
    local container = inst.components.inventory or inst.components.container
    if getcontainerspace(inst, container, data) then return end
    if data.orangeamulet and data.orangeamulet.skin_equip_sound and player.SoundEmitter then
        player.SoundEmitter:PlaySound(data.orangeamulet.skin_equip_sound)
    end
    local x, y, z = player.Transform:GetWorldPosition()
    local nearents = TheSim:FindEntities(x, y, z, 36, nil, PICKUP_CANT_TAGS, PICKUP_MUST_ONEOF_TAGS)
    for i = #nearents, 1, -1 do
        local v = nearents[i]
        if v:IsValid() and table.contains(data.prefabs, v.prefab) and v ~= inst and not v:IsInLimbo() and not iscontainerchild(inst, v) and
            container:CanTakeItemInSlot(v) and not v.components.inventoryitem.owner and v.components.inventoryitem.canbepickedup and
            not ((v:HasTag("fire") and not v:HasTag("lighter")) or v:HasTag("smolder")) and not v:HasTag("heavy") and
            not (v.components.container ~= nil and v.components.equippable == nil) and
            not ((v.components.burnable ~= nil and v.components.burnable:IsBurning() and v.components.lighter == nil) or
                (v.components.projectile ~= nil and v.components.projectile:IsThrown())) and
            not (inst.components.itemtyperestrictions ~= nil and not inst.components.itemtyperestrictions:IsAllowed(v)) and
            not (v.components.container ~= nil and v.components.container:IsOpen()) and
            not (v.components.yotc_racecompetitor ~= nil and v.components.entitytracker ~= nil) and
            (not v:HasTag("spider") or (player:HasTag("spiderwhisperer"))) and
            not ((v:HasTag("spider") and player:HasTag("spiderwhisperer")) and (v.components.follower.leader ~= nil and v.components.follower.leader ~= player)) and
            not (v.components.curseditem and not v.components.curseditem:checkplayersinventoryforspace(player)) and
            not (v.components.inventory ~= nil and v:HasTag("drop_inventory_onpickup")) then
            if data.infiniteprefabs and data.infiniteprefabs[v.prefab] then
                if not v.components.stackable and data.leftnumslots > 0 then
                    -- 非堆叠道具则只能放到有限的空格
                    data.leftnumslots = data.leftnumslots - 1
                    showmovefx(v)
                    container:GiveItem(v)
                    data.finiteuses = data.finiteuses - 1
                else
                    -- 无限需求堆叠道具,所以可以无限给予
                    showmovefx(v)
                    container:GiveItem(v)
                    data.finiteuses = data.finiteuses -
                    math.max(v.components.stackable and v.components.stackable.stacksize / 4 or 1, 1)
                end
            elseif data.lacksize[v.prefab] and v.components.stackable then -- 有限需求
                -- 有限需求,处理需求与供给数目关系
                if data.lacksize[v.prefab] >= v.components.stackable.stacksize then
                    -- 重叠格子用不完,直接给
                    data.finiteuses = data.finiteuses - math.max(v.components.stackable.stacksize / 4, 1)
                    data.lacksize[v.prefab] = data.lacksize[v.prefab] - v.components.stackable.stacksize
                    if data.lacksize[v.prefab] <= 0 then data.lacksize[v.prefab] = nil end
                    showmovefx(v)
                    container:GiveItem(v)
                elseif data.leftnumslots > 0 then
                    -- 重叠格子会用完,但还有空白格子
                    local slotsize = v.components.stackable.originalmaxsize or v.components.stackable.maxsize
                    local leftsize = data.lacksize[v.prefab] + slotsize * data.leftnumslots
                    if leftsize <= v.components.stackable.stacksize then
                        -- 重叠和空白格子都会被该道具堆满
                        data.finiteuses = data.finiteuses - math.max(leftsize / 4, 1)
                        data.leftnumslots = 0
                        data.lacksize[v.prefab] = nil
                        showmovefx(v)
                        container:GiveItem(v.components.stackable:Get(leftsize), nil, data.entpos)
                        -- 全部堆满,则结束收集
                        if IsTableEmpty(data.lacksize) then break end
                    else
                        -- 还能残留空间
                        data.finiteuses = data.finiteuses - math.max(v.components.stackable.stacksize / 4, 1)
                        leftsize = leftsize - v.components.stackable.stacksize
                        data.leftnumslots = math.floor(leftsize / slotsize)
                        data.lacksize[v.prefab] = math.floor(leftsize % slotsize)
                        if data.lacksize[v.prefab] <= 0 then data.lacksize[v.prefab] = nil end
                        showmovefx(v)
                        container:GiveItem(v, nil, data.entpos)
                    end
                elseif data.lacksize[v.prefab] > 0 then
                    -- 重叠格子会用完,且没有空白格子
                    data.finiteuses = data.finiteuses - math.max(data.lacksize[v.prefab] / 4, 1)
                    showmovefx(v)
                    local giveitem = v.components.stackable:Get(data.lacksize[v.prefab])
                    data.lacksize[giveitem.prefab] = nil
                    container:GiveItem(giveitem, nil, data.entpos)
                    -- 全部堆满,则结束收集
                    if IsTableEmpty(data.lacksize) then break end
                end
            elseif data.leftnumslots > 0 then
                -- 没有重叠格子但有空白格子
                showmovefx(v)
                data.leftnumslots = data.leftnumslots - 1
                if v.components.stackable then
                    local slotsize = v.components.stackable.originalmaxsize or v.components.stackable.maxsize
                    local leftsize = slotsize * data.leftnumslots
                    if leftsize <= v.components.stackable.stacksize then
                        -- 空白格子都会被该道具堆满
                        data.finiteuses = data.finiteuses - math.max(leftsize / 4, 1)
                        data.leftnumslots = 0
                        local giveitem = v.components.stackable:Get(leftsize)
                        container:GiveItem(giveitem, nil, data.entpos)
                        -- 全部堆满,则结束收集
                        if IsTableEmpty(data.lacksize) then return true end
                    else
                        -- 还能残留空间
                        data.finiteuses = data.finiteuses - math.max(v.components.stackable.stacksize / 4, 1)
                        leftsize = leftsize - v.components.stackable.stacksize
                        data.leftnumslots = math.floor(leftsize / slotsize)
                        data.lacksize[v.prefab] = math.floor(leftsize % slotsize)
                        if data.lacksize[v.prefab] <= 0 then data.lacksize[v.prefab] = nil end
                        container:GiveItem(v, nil, data.entpos)
                    end
                else
                    data.finiteuses = data.finiteuses - 1
                    container:GiveItem(v, nil, data.entpos)
                end
                if data.leftnumslots <= 0 and IsTableEmpty(data.lacksize) then break end
            end
            if data.finiteuses <= 0 then break end
        end
    end
    data.finiteuses = math.max(data.finiteuses, 0)
    if data.orangeamulet and data.orangeamulet:IsValid() then
        if data.orangeamulet.components.finiteuses then
            data.orangeamulet.components.finiteuses:Use(data.beforefiniteuses - data.finiteuses)
        elseif data.orangeamulet.components.fueled then
            data.orangeamulet.components.fueled:DoDelta(data.finiteuses - data.beforefiniteuses, player)
        end
    end
end
local function pickupfn(player, inst)
    if hascollectbutton then
        if inst.components.container ~= nil and not inst.collectloadingtask2hm and not inst:HasTag("dcs2hm") and not inst.dcs2hm and
            not inst.components.container.usespecificslotsforitems and inst.components.container.acceptsstacks then
            dopickup(inst, player)
        end
        if inst.components.equippable and inst.components.equippable:IsEquipped() and player.components.inventory and not player.collectloadingtask2hm then
            dopickup(player, player)
        end
    end
end
local function realcollectfn(doer, inst)
    pickupfn(doer, inst)
    collectfn(doer, inst)
end
-- 收集/拾取按钮
AddModRPCHandler("MOD_HARDMODE", "collectbtn2hm", realcollectfn)
local function collectbtnfn(inst, doer)
    if not hascollectbutton then return end
    if inst.components.container ~= nil then
        realcollectfn(doer, inst)
    elseif inst.replica.container ~= nil and not inst.collectloadingtask2hm then
        inst.collectloadingtask2hm = inst:DoTaskInTime(0.5, endcollectloading)
        SendModRPCToServer(GetModRPC("MOD_HARDMODE", "collectbtn2hm"), inst)
    end
end

-- 容器锁定/解锁
if haslockbutton then
    AddComponentPostInit("container", function(self)
        -- 2025.11.8 夜风，跳过WX-78特殊容器，避免干扰
        if self.inst:HasTag("wx78_special_container") then return end
        
        local oldOnSave = self.OnSave
        self.OnSave = function(self, ...)
            local data, references, more = oldOnSave(self, ...)
            data.itemtestfnprefabs2hm = self.itemtestfnprefabs2hm
            return data, references, more
        end
        local oldOnLoad = self.OnLoad
        self.OnLoad = function(self, data, ...)
            oldOnLoad(self, data, ...)
            if not self.inst:HasTag("pocketdimension_container") then
                self.itemtestfnprefabs2hm = data.itemtestfnprefabs2hm
                if self.itemtestfnprefabs2hm then self.inst:AddTag("lockcontainer2hm") end
            end
        end
        local oldCanTakeItemInSlot = self.CanTakeItemInSlot
        self.CanTakeItemInSlot = function(self, item, slot, ...)
            return oldCanTakeItemInSlot(self, item, slot, ...) and
                (self.itemtestfnprefabs2hm == nil or table.contains(self.itemtestfnprefabs2hm, item.prefab))
        end
    end)
    local function IsBusy(inst) return inst._busy or inst._parent == nil end
    AddPrefabPostInit("inventory_classified", function(inst)
        if not TheWorld.ismastersim then
            local MoveItemFromAllOfSlot = inst.MoveItemFromAllOfSlot
            inst.MoveItemFromAllOfSlot = function(inst, slot, container, ...)
                -- TheNet:Say("测试inventory_classified MoveItemFromAllOfSlot")
                if container and container:HasTag("lockcontainer2hm") and not IsBusy(inst) then
                    return SendRPCToServer(RPC.MoveInvItemFromAllOfSlot, slot, container)
                end
                return MoveItemFromAllOfSlot(inst, slot, container, ...)
            end
            local MoveItemFromHalfOfSlot = inst.MoveItemFromHalfOfSlot
            inst.MoveItemFromHalfOfSlot = function(inst, slot, container, ...)
                -- TheNet:Say("测试inventory_classified MoveItemFromHalfOfSlot")
                if container and container:HasTag("lockcontainer2hm") and not IsBusy(inst) then
                    return SendRPCToServer(RPC.MoveInvItemFromHalfOfSlot, slot, container)
                end
                return MoveItemFromHalfOfSlot(inst, slot, container, ...)
            end
        end
    end)
    AddPrefabPostInit("container_classified", function(inst)
        if not TheWorld.ismastersim then
            local ReturnActiveItemToSlot = inst.ReturnActiveItemToSlot
            inst.ReturnActiveItemToSlot = function(inst, slot, ...)
                -- TheNet:Say("测试container_classified ReturnActiveItemToSlot")
                if inst._parent and inst._parent:HasTag("lockcontainer2hm") and not IsBusy(inst) then return end
                return ReturnActiveItemToSlot(inst, slot, ...)
            end
            local PutOneOfActiveItemInSlot = inst.PutOneOfActiveItemInSlot
            inst.PutOneOfActiveItemInSlot = function(inst, slot, ...)
                -- TheNet:Say("测试container_classified PutOneOfActiveItemInSlot")
                if inst._parent and inst._parent:HasTag("lockcontainer2hm") and not IsBusy(inst) then
                    return SendRPCToServer(RPC.PutOneOfActiveItemInSlot, slot, inst._parent)
                end
                return PutOneOfActiveItemInSlot(inst, slot, ...)
            end
            local PutAllOfActiveItemInSlot = inst.PutAllOfActiveItemInSlot
            inst.PutAllOfActiveItemInSlot = function(inst, slot, ...)
                -- TheNet:Say("测试container_classified PutAllOfActiveItemInSlot")
                if inst._parent and inst._parent:HasTag("lockcontainer2hm") and not IsBusy(inst) then
                    return SendRPCToServer(RPC.PutAllOfActiveItemInSlot, slot, inst._parent)
                end
                return PutAllOfActiveItemInSlot(inst, slot, ...)
            end
            -- local TakeActiveItemFromHalfOfSlot = inst.TakeActiveItemFromHalfOfSlot
            -- inst.TakeActiveItemFromHalfOfSlot = function(inst, slot, ...)
            --     TheNet:Say("测试container_classified TakeActiveItemFromHalfOfSlot")
            --     if inst._parent and inst._parent:HasTag("lockcontainer2hm") and not IsBusy(inst) then
            --         return SendRPCToServer(RPC.TakeActiveItemFromHalfOfSlot, slot, inst._parent)
            --     end
            --     return TakeActiveItemFromHalfOfSlot(inst, slot, ...)
            -- end
            -- local TakeActiveItemFromAllOfSlot = inst.TakeActiveItemFromAllOfSlot
            -- inst.TakeActiveItemFromAllOfSlot = function(inst, slot, ...)
            --     TheNet:Say("测试container_classified TakeActiveItemFromAllOfSlot")
            --     if inst._parent and inst._parent:HasTag("lockcontainer2hm") and not IsBusy(inst) then
            --         return SendRPCToServer(RPC.TakeActiveItemFromAllOfSlot, slot, inst._parent)
            --     end
            --     return TakeActiveItemFromAllOfSlot(inst, slot, ...)
            -- end
            -- local AddOneOfActiveItemToSlot = inst.AddOneOfActiveItemToSlot
            -- inst.AddOneOfActiveItemToSlot = function(inst, slot, ...)
            --     TheNet:Say("测试container_classified AddOneOfActiveItemToSlot")
            --     if inst._parent and inst._parent:HasTag("lockcontainer2hm") and not IsBusy(inst) then
            --         return SendRPCToServer(RPC.AddOneOfActiveItemToSlot, slot, inst._parent)
            --     end
            --     return AddOneOfActiveItemToSlot(inst, slot, ...)
            -- end
            -- local AddAllOfActiveItemToSlot = inst.AddAllOfActiveItemToSlot
            -- inst.AddAllOfActiveItemToSlot = function(inst, slot, ...)
            --     TheNet:Say("测试container_classified AddAllOfActiveItemToSlot")
            --     if inst._parent and inst._parent:HasTag("lockcontainer2hm") and not IsBusy(inst) then
            --         return SendRPCToServer(RPC.AddAllOfActiveItemToSlot, slot, inst._parent)
            --     end
            --     return AddAllOfActiveItemToSlot(inst, slot, ...)
            -- end
            local SwapActiveItemWithSlot = inst.SwapActiveItemWithSlot
            inst.SwapActiveItemWithSlot = function(inst, slot, ...)
                -- TheNet:Say("测试container_classified SwapActiveItemWithSlot")
                if inst._parent and inst._parent:HasTag("lockcontainer2hm") and not IsBusy(inst) then
                    return SendRPCToServer(RPC.SwapActiveItemWithSlot, slot, inst._parent)
                end
                return SwapActiveItemWithSlot(inst, slot, ...)
            end
            local SwapOneOfActiveItemWithSlot = inst.SwapOneOfActiveItemWithSlot
            inst.SwapOneOfActiveItemWithSlot = function(inst, slot, ...)
                -- TheNet:Say("测试container_classified SwapOneOfActiveItemWithSlot")
                if inst._parent and inst._parent:HasTag("lockcontainer2hm") and not IsBusy(inst) then
                    return SendRPCToServer(RPC.SwapOneOfActiveItemWithSlot, slot, inst._parent)
                end
                return SwapOneOfActiveItemWithSlot(inst, slot, ...)
            end
            local MoveItemFromAllOfSlot = inst.MoveItemFromAllOfSlot
            inst.MoveItemFromAllOfSlot = function(inst, slot, container, ...)
                -- TheNet:Say("测试container_classified MoveItemFromAllOfSlot")
                if container and container:HasTag("lockcontainer2hm") and not IsBusy(inst) then
                    return SendRPCToServer(RPC.MoveItemFromAllOfSlot, slot, inst._parent,
                        container.replica.container ~= nil and container or nil)
                end
                return MoveItemFromAllOfSlot(inst, slot, container, ...)
            end
            local MoveItemFromHalfOfSlot = inst.MoveItemFromHalfOfSlot
            inst.MoveItemFromHalfOfSlot = function(inst, slot, container, ...)
                -- TheNet:Say("测试container_classified MoveItemFromHalfOfSlot")
                if container and container:HasTag("lockcontainer2hm") and not IsBusy(inst) then
                    return SendRPCToServer(RPC.MoveItemFromHalfOfSlot, slot, inst._parent,
                        container.replica.container ~= nil and container or nil)
                end
                return MoveItemFromHalfOfSlot(inst, slot, container, ...)
            end
        end
    end)
end
local function dolock(inst, doer, typelock)
    if not (haslockbutton and inst.components.container and not inst.components.container.usespecificslotsforitems) then return end
    local self = inst.components.container
    -- 解锁
    -- if not typelock and self.itemtestfnargs2hm then
    if self.itemtestfnprefabs2hm then
        self.itemtestfnprefabs2hm = nil
        inst:RemoveTag("lockcontainer2hm")
        return
    end
    -- 上锁
    -- if not typelock then
    self.itemtestfnprefabs2hm = {}
    for i = 1, self.numslots do
        local item = self.slots[i]
        if item ~= nil and item:IsValid() and not table.contains(self.itemtestfnprefabs2hm, item.prefab) then
            table.insert(self.itemtestfnprefabs2hm, item.prefab)
        end
    end
    inst:AddTag("lockcontainer2hm")
end
local function lockfn(player, inst)
    if haslockbutton and inst and inst.components.container ~= nil then
        dolock(inst,
            player)
    end
end
AddModRPCHandler("MOD_HARDMODE", "lockbtn2hm", lockfn)
local lockbtninfo = {
    text1 = TUNING.isCh2hm and "锁定" or "Lock",
    text2 = TUNING.isCh2hm and "解锁" or "Unlock",
    -- 2025.7.9 melon:不显示提示的选项
    helptext1 = no_help_text and "" or TUNING.isCh2hm and [[限制该容器仅可放置此时已存道具且记忆]] or
        [[Make container limit store current items and remember limit]],
    helptext2 = no_help_text and "" or TUNING.isCh2hm and [[移除该容器的特定道具存放限制记忆]] or [[Remove container's items limit remember]],
    validfn = defaultbtnvalidfn
}
-- 锁定/解锁按钮
local function lockbtnfn(inst, doer, btn)
    if not haslockbutton then return end
    btn:SetText(inst:HasTag("lockcontainer2hm") and lockbtninfo.text1 or lockbtninfo.text2)
    btn:SetTooltip(inst:HasTag("lockcontainer2hm") and lockbtninfo.helptext1 or lockbtninfo.helptext2)
    if inst.components.container ~= nil then
        lockfn(doer, inst)
    elseif inst.replica.container ~= nil then
        SendModRPCToServer(GetModRPC("MOD_HARDMODE", "lockbtn2hm"), inst)
    end
end
lockbtninfo.fn = lockbtnfn
local function dolockinspect(inst, doer)
    if not (haslockbutton and inst.components.container and not inst.components.container.usespecificslotsforitems and doer.components.talker) then return end
    local self = inst.components.container
    local text
    if not self.itemtestfnprefabs2hm then
        inst:RemoveTag("lockcontainer2hm")
        return
    end
    local length = #self.itemtestfnprefabs2hm
    if self.itemtestfnprefabs2hm and length > 0 then
        local namelist = {}
        for index, prefab in ipairs(self.itemtestfnprefabs2hm) do
            if prefab then
                local upper = string.upper(prefab)
                if STRINGS.NAMES[upper] then
                    table.insert(namelist, STRINGS.NAMES[upper] .. "/" .. prefab)
                else
                    table.insert(namelist, prefab)
                end
            end
        end
        text = table.concat(namelist, "\n")
    end
    if text then doer.components.talker:Say(text) end
end
local function lockinspectfn(player, inst)
    if haslockbutton and inst and inst.components.container ~= nil then
        dolockinspect(inst, player)
    end
end
AddModRPCHandler("MOD_HARDMODE", "lockinspect2hm", lockinspectfn)
local function rightlockbtnfn(inst, doer)
    if not haslockbutton or not inst:HasTag("lockcontainer2hm") then return end
    if inst.components.container ~= nil then
        lockinspectfn(doer, inst)
    elseif inst.replica.container ~= nil then
        SendModRPCToServer(GetModRPC("MOD_HARDMODE", "lockinspect2hm"), inst)
    end
end

-- 衣柜换装
local function reskinfn(player, inst) if inst.components.wardrobe then inst.components.wardrobe:BeginChanging(player) end end
-- 换装按钮
AddModRPCHandler("MOD_HARDMODE", "reskinbtn2hm", reskinfn)
local function reskinbtnfn(inst, doer)
    if inst.components.wardrobe ~= nil then
        reskinfn(doer, inst)
    elseif inst.replica.container ~= nil then
        SendModRPCToServer(GetModRPC("MOD_HARDMODE", "reskinbtn2hm"), inst)
    end
end
-- local function reskinvalidfn(inst) return defaultbtnvalidfn(inst) and inst:HasTag("wardrobe") end
local reskinvalidfn = truefn

-- 晾肉架收集存放肉干
-- 快速存放相关函数
local function openvirtchest2hm(ent, inst)
    if ent.virtchest and ent.virtchest:IsValid() and ent.virtchest.components.container and ent.components.container.opencount == 0 then
        local self = ent.virtchest.components.container
        self.ignoreoverstacked = true
        ent.components.container.ignoresound = true
        for slot, _ in pairs(self.slots) do
            local item = self:RemoveItemBySlot(slot)
            if item ~= nil then ent.components.container:GiveItem(item, slot) end
        end
        ent.components.container.ignoresound = false
        self.ignoreoverstacked = false
    end
end
local function getperishablerate2hm(owner, inst, self)
    local modifier = 1
    if owner.components.preserver ~= nil then
        modifier = owner.components.preserver:GetPerishRateMultiplier(inst) or modifier
    elseif owner:HasTag("fridge") then
        if inst:HasTag("frozen") and not owner:HasTag("nocool") and not owner:HasTag("lowcool") then
            modifier = TUNING.PERISH_COLD_FROZEN_MULT
        else
            modifier = TUNING.PERISH_FRIDGE_MULT
        end
    elseif owner:HasTag("foodpreserver") then
        modifier = TUNING.PERISH_FOOD_PRESERVER_MULT
    elseif owner:HasTag("cage") and inst:HasTag("small_livestock") then
        modifier = TUNING.PERISH_CAGE_MULT
    end
    if owner:HasTag("spoiler") then modifier = modifier * TUNING.PERISH_GROUND_MULT end
    return modifier * 1
end
local function processstoreincontainers2hm(invobject, ents, proxyents, inst, src_pos, isstackable)
    -- 优先存放在当前打开的容器
    local toremove = {}
    -- for i, ent in ipairs(ents) do
    --     if inst.components.inventory.opencontainers[ent] then
    --         if ent.components.container:GiveItem(invobject, nil, src_pos, false) then
    --             delayshowmovefx(ent)
    --             return true
    --         else
    --             table.insert(toremove, i)
    --         end
    --     end
    -- end
    -- for _, i in ipairs(toremove) do table.remove(ents, i) end
    -- toremove = {}
    -- 优先存放在锁定存放此道具或已有此道具的容器(后者中,全图唯一容器更加优先)
    if haslockbutton then
        for i, ent in ipairs(ents) do
            if ent.components.container.itemtestfnprefabs2hm ~= nil then
                openvirtchest2hm(ent, inst)
                if ent.components.container:GiveItem(invobject, nil, src_pos, false) then
                    delayshowmovefx(ent)
                    return true
                else
                    table.insert(toremove, i)
                end
            end
        end
        for _, i in ipairs(toremove) do table.remove(ents, i) end
        toremove = {}
    end
    for master, v in pairs(proxyents) do
        local hasitem, oldnum = master.components.container:Has(invobject.prefab, 1)
        if hasitem then
            openvirtchest2hm(master, inst)
            if master.components.container:GiveItem(invobject, nil, src_pos, false) then
                delayshowmovefx(v)
                return true
            elseif invobject and invobject:IsValid() then
                local nowhas, newnum = master.components.container:Has(invobject.prefab, 1)
                if newnum > oldnum then delayshowmovefx(v) end
            end
        end
    end
    for i, ent in ipairs(ents) do
        local oldhas, oldnum = ent.components.container:Has(invobject.prefab, 1)
        if not oldhas and ent.virtchest and ent.virtchest:IsValid() and ent.virtchest.components.container then
            local virthas, virtnum = ent.virtchest.components.container:Has(invobject.prefab, 1)
            oldhas = virthas
            oldnum = oldnum + virtnum
        end
        if oldhas then
            openvirtchest2hm(ent, inst)
            if isstackable then
                if ent.components.container:GiveItem(invobject, nil, src_pos, false) then
                    return true
                else
                    if invobject and invobject:IsValid() then
                        local newhas, newnum = ent.components.container:Has(invobject.prefab, 1)
                        if newnum > oldnum then delayshowmovefx(ent) end
                    end
                end
            elseif ent.components.container:GiveItem(invobject, nil, src_pos, false) then
                return true
            end
            table.insert(toremove, i)
        end
    end
    for _, i in ipairs(toremove) do table.remove(ents, i) end
    -- 其次，优先存放在有存放道具限制的容器（某些道具特殊处理）
    -- 暖石特殊处理，非夏天优先存放在冰箱，夏天额根据优先级优先存放在龙鳞火炉
    if invobject:HasTag("heatrock") and not TheWorld.state.issummer then
        toremove = {}
        for i, ent in ipairs(ents) do
            if ent:HasTag("fridge") and not ent:HasTag("nocool") then
                openvirtchest2hm(ent, inst)
                if ent.components.container:GiveItem(invobject, nil, src_pos, false) then
                    delayshowmovefx(ent)
                    return true
                else
                    table.insert(toremove, i)
                end
            end
        end
        for _, i in ipairs(toremove) do table.remove(ents, i) end
    end
    -- 有新鲜度的道具特殊处理
    local tmpentsindex = {}
    local itemtestfnents = {}
    local rates
    local perishable = invobject.components.perishable
    local hasprioritystoreents
    if perishable ~= nil then
        -- 按保鲜能力排序，其次按唯一容器/限制容器/普通容器进行排序
        rates = {}
        local totalproxyents = GetTableSize(proxyents)
        local totalents = totalproxyents + #ents
        local j = 0
        for master, v in pairs(proxyents) do
            local rate = getperishablerate2hm(master, invobject, perishable)
            if rate < 1 then
                rates[master] = rate
                table.insert(itemtestfnents, master)
                j = j + 1
                tmpentsindex[master] = j
            end
        end
        for i, ent in ipairs(ents) do
            table.insert(itemtestfnents, ent)
            local rate = getperishablerate2hm(ent, invobject, perishable)
            if rate < 1 then rates[ent] = rate end
            if ent.components.container.itemtestfn ~= nil then
                tmpentsindex[ent] = i + totalproxyents
            else
                tmpentsindex[ent] = i + totalents
            end
        end
    else
        -- 无新鲜度的道具
        for i, ent in ipairs(ents) do
            if ent.components.container.itemtestfn ~= nil then
                table.insert(itemtestfnents, ent)
                tmpentsindex[ent] = i
                if not hasprioritystoreents and prioritystoreents[ent.prefab] then hasprioritystoreents = true end
            end
        end
    end
    if not IsTableEmpty(itemtestfnents) then
        if perishable ~= nil or hasprioritystoreents then
            table.sort(itemtestfnents, function(a, b)
                if not (a and b and a.prefab and b.prefab and tmpentsindex[a] and tmpentsindex[b]) then return false end
                -- 先按指定的优先级容器存放
                local aidx = prioritystoreents[a.prefab]
                local bidx = prioritystoreents[b.prefab]
                if aidx or bidx then
                    if aidx and bidx then
                        if aidx == bidx then return tmpentsindex[a] < tmpentsindex[b] end
                        return aidx < bidx
                    end
                    return aidx ~= nil
                end
                if perishable ~= nil then
                    -- 有新鲜度的道具再按保鲜程度存放
                    local arate = rates[a]
                    local brate = rates[b]
                    if arate or brate then
                        if arate and brate then
                            if arate == brate then return tmpentsindex[a] < tmpentsindex[b] end
                            return arate < brate
                        end
                        return arate ~= nil
                    end
                end
                -- 最后默认排放
                return tmpentsindex[a] < tmpentsindex[b]
            end)
        end
        for _, ent in ipairs(itemtestfnents) do
            openvirtchest2hm(ent, inst)
            if ent.components.container:GiveItem(invobject, nil, src_pos, false) then
                delayshowmovefx(ent.currentpocket2hm or ent)
                return true
            end
        end
    end
    -- 最后，存放在普通容器
    if perishable == nil then
        for _, ent in ipairs(ents) do
            if ent.components.container.itemtestfn == nil then
                openvirtchest2hm(ent, inst)
                if ent.components.container:GiveItem(invobject, nil, src_pos, false) then
                    delayshowmovefx(ent)
                    return true
                end
            end
        end
    end
end
local function store2hm(doer, item)
    local inst = doer
    if not (inst and item and item:IsValid() and item.components.inventoryitem and inst.components.inventory and
            inst.components.inventory.opencontainers) then
        return
    end
    local owner = item.components.inventoryitem.owner
    local prevcontainer = owner and (owner.components.container or owner.components.inventory)
    if not prevcontainer then return end
    -- 记录要存放道具的目的容器列表
    local isstackable = item.components.stackable ~= nil
    local isbigsize = isstackable and
        (item.components.stackable.stacksize >
            (item.components.stackable.originalmaxsize or item.components.stackable.maxsize))
    local src_pos = inst:GetPosition()
    local ents = {}
    local proxyents = {}
    if inst.components.rider and inst.components.rider.mount and inst.components.rider.mount:IsValid() and
        inst.components.rider.mount.components.container and inst.components.rider.mount ~= owner and
        inst.components.rider.mount.components.container.canbeopened then
        table.insert(ents, inst.components.rider.mount)
    end
    local x, y, z = inst.Transform:GetWorldPosition()
    local platform = inst:GetCurrentPlatform()
    local nearents = TheSim:FindEntities(x, y, z, 30, nil, GROUND_CONTAINER_CANT_TAGS)
    for i, v in ipairs(nearents) do
        if v:IsValid() and v ~= owner then
            if v.components.container_proxy and isstackable and not v.dcs2hm and v.components.container_proxy:CanBeOpened() and
                not v.components.container and not v.components.locomotor and not table.contains(storeblacklist, v.prefab) and
                (conditionstorelist[v.prefab] == nil or conditionstorelist[v.prefab](item)) and v:GetCurrentPlatform() == platform then
                local master = v.components.container_proxy.master
                if master and master:IsValid() and master ~= owner and not proxyents[master] and master.components.container and
                    master.components.container.canbeopened and not master.components.container.usespecificslotsforitems and
                    master.components.container.acceptsstacks and (not isbigsize or master.components.container.infinitestacksize) and
                    master.components.container:CanTakeItemInSlot(item) then
                    proxyents[master] = v
                    master.currentpocket2hm = v
                end
            elseif v.components.container and not v.dcs2hm and (table.contains(storewhitelist, v.prefab) or
                    ((isstackable or not v.components.container.infinitestacksize) and (not isbigsize or v.components.container.infinitestacksize) and
                        (not v.components.inventoryitem or v:HasTag("heavy")) and not v.components.health and not v.components.locomotor and
                        not v.components.stewer and v.components.container.canbeopened and not v.components.container.usespecificslotsforitems and
                        v.components.container.acceptsstacks and not table.contains(storeblacklist, v.prefab) and
                        (conditionstorelist[v.prefab] == nil and v.components.container.type == "chest" and v.components.container.numslots >= 9 or
                            (conditionstorelist[v.prefab] and conditionstorelist[v.prefab](item))))) and v:GetCurrentPlatform() == platform and
                v.components.container:CanTakeItemInSlot(item) then
                table.insert(ents, v)
            end
        end
    end
    if IsTableEmpty(ents) and IsTableEmpty(proxyents) then return end
    local prevslot = item.components.inventoryitem:GetSlotNum()
    -- 进行存放道具操作
    item.components.inventoryitem:RemoveFromOwner(true)
    item.prevplayer2hm = inst
    local result = processstoreincontainers2hm(item, ents, proxyents, inst, src_pos, isstackable)
    -- 存放完成数据修正,和失败检查
    if item:IsValid() then
        item.prevplayer2hm = nil
        if item.components.inventoryitem.owner == nil then
            prevcontainer:GiveItem(item,
                prevslot)
        end
    end
    return result
end

local function getcontainerspace2hm(inst, container, data, addprefab)
    local slots = container.slots or container.itemslots
    local numslots = container.numslots or container.maxslots
    -- 没有剩余空间时返回true
    local prefabs = data.prefabs or {}
    local infiniteprefabs = data.infiniteprefabs or {}
    local lacksize = data.lacksize or {}
    local leftnumslots = numslots
    for i = 1, numslots do
        local item = slots[i]
        if item ~= nil and item:IsValid() then
            leftnumslots = leftnumslots - 1
            local hasprefab = prefabs and table.contains(prefabs, item.prefab)
            if not hasprefab and addprefab ~= false and prefabs and not table.contains(itemsblacklist, item.prefab) then
                table.insert(prefabs, item.prefab)
                hasprefab = true
            end
            if hasprefab and item.components.stackable then
                if container.infinitestacksize or item.components.stackable.maxsize == math.huge then
                    infiniteprefabs[item.prefab] = true
                    if lacksize[item.prefab] then lacksize[item.prefab] = nil end
                elseif not infiniteprefabs[item.prefab] and item.components.stackable.stacksize < item.components.stackable.maxsize then
                    lacksize[item.prefab] = (lacksize[item.prefab] or 0) + item.components.stackable.maxsize -
                        item.components.stackable.stacksize
                end
            end
        end
    end
    return leftnumslots, lacksize, infiniteprefabs
end

local function countlength(table)
    local length = 0
    if type(table) == "table" and next(table) ~= nil then
        for i, v in pairs(table) do
            if v then length = length + 1 end
        end 
    end
    return length
end

local function domeatrack_inplayer(ents, doer, active_item)
    if ents ~= nil then
        local hasdone
        local _israin = TheWorld.state.israining
        for a, ent in pairs(ents) do
            local entpos = ent:GetPosition()
            local meatrack = ent
            local data = {}
            local slot = {}
            local _slot = {}
            local haschange
            local items = meatrack.components.container:GetAllItems()
            local length = countlength(items)
            local numslots = meatrack.components.container.numslots
            local israin = _israin and not table.contains(canuseinrain_meatracklist, ent.prefab)
            data.prefabs = {}
            if items ~= nil then
                for i, v in pairs(items) do
                    if v and (israin or not v.components.dryable or (active_item == v.prefab)) and not table.contains(data.prefabs, v.prefab) then
                        table.insert(data.prefabs, v.prefab)
                    end
                end
            end
            -- 物品栏
            local leftnumslots, lacksize, infiniteprefabs = getcontainerspace2hm(inst, doer.components.inventory, data, false)
            if items and length > 0 then 
                if leftnumslots and length > leftnumslots then
                    for i = 1, numslots do
                        local item = meatrack.components.container:GetItemInSlot(i)
                        if item and (israin or not item.components.dryable or (active_item == item.prefab)) then
                            -- 有限堆叠
                            if lacksize then
                                -- 物品栏满了但收集的物品在物品栏有空余
                                if leftnumslots <= 0 and lacksize[item.prefab] and lacksize[item.prefab] > 0 then
                                    lacksize[item.prefab] = lacksize[item.prefab] - 1
                                    slot[i] = item
                                -- 物品栏没满但收集的物品在物品栏有空余
                                elseif leftnumslots > 0 and lacksize[item.prefab] and lacksize[item.prefab] > 0 then
                                    lacksize[item.prefab] = lacksize[item.prefab] - 1
                                    slot[i] = item
                                -- 物品栏没满且收集的物品在物品栏没空余
                                elseif leftnumslots > 0 and lacksize[item.prefab] and lacksize[item.prefab] <= 0 then
                                    lacksize[item.prefab] = lacksize[item.prefab] + (item.components.stackable.maxsize or 1) - 1
                                    leftnumslots = leftnumslots - 1
                                    slot[i] = item
                                -- 物品栏没满且收集的物品在物品栏没有
                                elseif leftnumslots > 0 and not lacksize[item.prefab] then
                                    lacksize[item.prefab] = (item.components.stackable.maxsize or 1) - 1
                                    leftnumslots = leftnumslots - 1
                                    slot[i] = item
                                end
                            -- 无限堆叠
                            elseif lacksize == nil then
                                if infiniteprefabs and infiniteprefabs[item.prefab] then
                                    slot[i] = item
                                elseif leftnumslots > 0 and infiniteprefabs and not infiniteprefabs[item.prefab] then
                                    leftnumslots = leftnumslots - 1
                                    slot[i] = item
                                end
                            end
                        end
                    end
                else
                    for i = 1, numslots do
                        local item = meatrack.components.container:GetItemInSlot(i)
                        if item and (israin or not item.components.dryable or (active_item == item.prefab)) then
                            slot[i] = item
                        end
                    end
                end
            end
            if next(slot) ~= nil then
                for i, v in pairs(slot) do
                    if v ~= nil then
                        local item = meatrack.components.container:RemoveItemBySlot(i)
                        item.prevslot = nil
                        item.prevcontainer = nil
                        if item then
                            local result = doer.components.inventory:GiveItem(item, nil, entpos)
                            if not result then
                                meatrack.components.container:GiveItem(item, i)
                            else
                                if not hasdone then hasdone = true end
                                if not haschange then haschange = true end
                            end
                        end
                    end
                end
            end
            -- 背包栏
            local overflow = doer.components.inventory:GetOverflowContainer()
            if overflow then
                data.prefabs = {}
                items = meatrack.components.container:GetAllItems()
                length = countlength(items)
                if items ~= nil then
                    for i, v in pairs(items) do
                        if v and (israin or not v.components.dryable or (active_item == v.prefab)) and (overflow.itemtestfn and overflow:itemtestfn(v) or overflow.itemtestfn == nil) 
                        and not table.contains(data.prefabs, v.prefab) then
                            table.insert(data.prefabs, v.prefab)
                        end
                    end
                end
                leftnumslots, lacksize, infiniteprefabs = getcontainerspace2hm(inst, overflow, data, false)
                if items and length > 0 then
                    if leftnumslots and length > leftnumslots and lacksize then
                        for i = 1, numslots do
                            local item = meatrack.components.container:GetItemInSlot(i)
                            if item and (israin or not item.components.dryable or (active_item == item.prefab)) and (overflow.itemtestfn and overflow:itemtestfn(item) or overflow.itemtestfn == nil) then
                                -- 有限堆叠
                                if lacksize then
                                    -- 物品栏满了但收集的物品在物品栏有空余
                                    if leftnumslots <= 0 and lacksize[item.prefab] and lacksize[item.prefab] > 0 then
                                        lacksize[item.prefab] = lacksize[item.prefab] - 1
                                        _slot[i] = item
                                    -- 物品栏没满但收集的物品在物品栏有空余
                                    elseif leftnumslots > 0 and lacksize[item.prefab] and lacksize[item.prefab] > 0 then
                                        lacksize[item.prefab] = lacksize[item.prefab] - 1
                                        _slot[i] = item
                                    -- 物品栏没满且收集的物品在物品栏没空余
                                    elseif leftnumslots > 0 and lacksize[item.prefab] and lacksize[item.prefab] <= 0 then
                                        lacksize[item.prefab] = lacksize[item.prefab] + (item.components.stackable.maxsize or 1) - 1
                                        leftnumslots = leftnumslots - 1
                                        _slot[i] = item
                                    -- 物品栏没满且收集的物品在物品栏没有
                                    elseif leftnumslots > 0 and not lacksize[item.prefab] and not overflow.itemtestfnprefabs2hm then
                                        lacksize[item.prefab] = (item.components.stackable.maxsize or 1) - 1
                                        leftnumslots = leftnumslots - 1
                                        _slot[i] = item
                                    end
                                -- 无限堆叠
                                elseif lacksize == nil then
                                    if infiniteprefabs and infiniteprefabs[item.prefab] then
                                        _slot[i] = item
                                    elseif leftnumslots > 0 and infiniteprefabs and not infiniteprefabs[item.prefab] and not overflow.itemtestfnprefabs2hm then
                                        leftnumslots = leftnumslots - 1
                                        _slot[i] = item
                                    end
                                end
                            end
                        end
                    else
                        for i = 1, numslots do
                            local item = meatrack.components.container:GetItemInSlot(i)
                            if item and (overflow.itemtestfnprefabs2hm == nil or (overflow.itemtestfnprefabs2hm and table.contains(overflow.itemtestfnprefabs2hm, item.prefab)))
                            and (israin or not item.components.dryable or (active_item == item.prefab)) and 
                            (overflow.itemtestfn and overflow:itemtestfn(item) or overflow.itemtestfn == nil) then
                                _slot[i] = item
                            end
                        end
                    end
                end
                if next(_slot) ~= nil then
                    for i, v in pairs(_slot) do
                        if v ~= nil then
                            local item = meatrack.components.container:RemoveItemBySlot(i)
                            if item then
                                local result = overflow:GiveItem(item, nil, entpos)
                                if not result then
                                    meatrack.components.container:GiveItem(item, i)
                                else
                                    if not hasdone then hasdone = true end
                                    if not haschange then haschange = true end
                                end
                            end
                        end
                    end
                end
            end
            if haschange then showmovefx(ent) end
        end
        if not hasdone and doer.components.talker then
            doer.components.talker:Say((TUNING.isCh2hm and ("拿不下啦~") or ("Inventory full.")) or 
            GetActionFailString(doer, "STORE"))
        end
    end
end

local function domeatrack_incontainer(ents, doer, active_item)
    if ents ~= nil then
        local hasdone
        local _israin = TheWorld.state.israining
        for a, ent in pairs(ents) do
            local meatrack = ent
            local slot = {}
            local numslots = meatrack.components.container.numslots
            local israin = _israin and not table.contains(canuseinrain_meatracklist, ent.prefab)
            for i = 1, numslots do
                local item = meatrack.components.container:GetItemInSlot(i)
                if item and (israin or not item.components.dryable or (active_item == item.prefab)) then
                    slot[i] = item
                end
            end
            if next(slot) ~= nil then
                for i, v in pairs(slot) do
                    if v ~= nil then
                        local result = store2hm(doer, v)
                        if not hasdone then hasdone = result end
                    end
                end
            end
        end
        if not hasdone and doer.components.talker then
            doer.components.talker:Say((TUNING.isCh2hm and ("附近没有可存放的容器哦咦~") or ("There are no containers nearby to store.")))
        end
    end
end

local function findmeatracks(doer, inst, stroe)
    if inst and inst:IsValid() and inst.components.container and doer and doer:IsValid() and doer.components.inventory then
        local _israin = TheWorld.state.israining
        local active_item = doer.components.inventory:GetActiveItem()
        active_item = active_item and active_item.prefab
        local x,y,z = inst.Transform:GetWorldPosition()
        local nearmeatracks = {}
        local cancollect_nearmeatracks = {}
        local nearents = TheSim:FindEntities(x, y, z, 30, {"structure"}, GROUND_CONTAINER_CANT_TAGS)
        for i, ent in pairs(nearents) do
            if ent and ent.components.dryingrack and ent.components.container and ent.components.container.canbeopened and not ent.components.container:IsEmpty() then
                table.insert(nearmeatracks,ent)
            end
        end
        for a, ent in pairs(nearmeatracks) do
            if ent and countlength(cancollect_nearmeatracks) < 20 then
                local cancollect
                local container = ent.components.container
                local allitems = container:GetAllItems()
                local israin = _israin and not table.contains(canuseinrain_meatracklist, ent.prefab)
                if allitems then
                    for i, v in pairs(allitems) do
                        if v and (israin or not v.components.dryable or (active_item == v.prefab)) then cancollect = true end
                    end
                    if cancollect then table.insert(cancollect_nearmeatracks, ent) end
                end
            end
        end
        if next(cancollect_nearmeatracks) == nil then
            if doer.components.talker then
                doer.components.talker:Say(TUNING.isCh2hm and ("附近没有可收集的晾肉架哎") or ("There's no meatrack to collect"))
            end
            return
        end
        if stroe then
            domeatrack_incontainer(cancollect_nearmeatracks, doer, active_item)
        else
            domeatrack_inplayer(cancollect_nearmeatracks, doer, active_item)
        end
    end
end

-- 一键存放
local function storemeatbtnfn(inst, doer)
    if inst.components.container ~= nil then
        findmeatracks(doer, inst, true)
    elseif inst.replica.container ~= nil then
        SendModRPCToServer(GetModRPC("MOD_HARDMODE", "collectmeatbtn2hm"), inst, true)
    end
end

-- 一键收集
AddModRPCHandler("MOD_HARDMODE", "collectmeatbtn2hm", findmeatracks)
local function collectmeatbtnfn(inst, doer)
    if inst.components.container ~= nil then
        findmeatracks(doer, inst)
    elseif inst.replica.container ~= nil then
        SendModRPCToServer(GetModRPC("MOD_HARDMODE", "collectmeatbtn2hm"), inst)
    end
end

-- 一键晒肉
local function driedmeat(ents, doer, active_item)
    if ents ~= nil and active_item ~= nil then
        local entpos = doer:GetPosition()
        local active_itemnums = active_item.components.stackable and active_item.components.stackable:StackSize() or 1
        for i, v in pairs(ents) do
            if v then
                if active_itemnums <= 0 then break end
                local hasdone
                local selfnumslots = v.components.container.numslots
                local itemslots = v.components.container:NumItems()
                local remaining = (selfnumslots or 0) - (itemslots or 0)
                if remaining > 0 then
                    for a = 1, selfnumslots do
                        if active_itemnums <= 0 then break end
                        if not v.components.container:GetItemInSlot(a) then
                            if active_itemnums == 1 then
                                item = doer.components.inventory:GetActiveItem()
                                if item ~= nil then
                                    local result
                                    if v.components.container:CanTakeItemInSlot(item, a) then
                                        doer.components.inventory:RemoveItem(item)
                                        result = v.components.container:GiveItem(item, a, entpos)
                                    end
                                    if not result then
                                        doer.components.inventory:GiveActiveItem(item)
                                    else
                                        hasdone = true
                                        active_itemnums = active_itemnums - 1
                                    end
                                end
                            else
                                local item = active_item.components.stackable and active_item.components.stackable:Get(1)
                                if item ~= nil then
                                    local result
                                    if v.components.container:CanTakeItemInSlot(item, a) then
                                        result = v.components.container:GiveItem(item, a, entpos)
                                    end
                                    if not result then
                                        active_item.components.stackable:Put(item, entpos)
                                    else
                                        hasdone = true
                                        active_itemnums = active_itemnums - 1
                                    end
                                end
                            end
                        end
                    end
                end
                if hasdone then showmovefx(v) end
            end
        end
    end
end

local function findcandriedmeatracks(doer, inst)
    if inst and inst:IsValid() and inst.components.container and doer and doer:IsValid() and doer.components.inventory then
        local active_item = doer.components.inventory:GetActiveItem()
        if not active_item then
            if doer.components.talker then
                doer.components.talker:Say(TUNING.isCh2hm and ("手上没有物品诺") or ("There is no item on the mouse pointer"))
            end
            return
        elseif active_item and not (active_item:IsValid() and active_item.components.dryable) then
            if doer.components.talker then
                doer.components.talker:Say(TUNING.isCh2hm and ("手上的物品不能风干啦") or ("items on the mouse pointer cannot dry"))
            end
            return
        end
        local x,y,z = inst.Transform:GetWorldPosition()
        local nearmeatracks = {}
        local nearents = TheSim:FindEntities(x, y, z, 30, {"structure"}, GROUND_CONTAINER_CANT_TAGS)
        for i, ent in pairs(nearents) do
            local _israin = TheWorld.state.israining and not table.contains(canuseinrain_meatracklist, ent.prefab)
            if ent and not _israin and countlength(nearmeatracks) < 20 and ent.components.dryingrack and ent.components.container and ent.components.container.canbeopened and not ent.components.container:IsFull() then
                table.insert(nearmeatracks,ent)
            end
        end
        if next(nearmeatracks) == nil then
            if TheWorld.state.israining then
                if doer.components.talker then
                    doer.components.talker:Say(TUNING.isCh2hm and ("现在是下雨天哎") or ("It's raining now"))
                end
                return
            end
            if doer.components.talker then
                doer.components.talker:Say(TUNING.isCh2hm and ("附近没有空余的晾肉架了") or ("There are no spare meatracks nearby"))
            end
            return
        end
        driedmeat(nearmeatracks, doer, active_item)
    end
end

local function driedmeatbtnfn(inst, doer)
    if inst.components.container ~= nil then
        findcandriedmeatracks(doer, inst)
    elseif inst.replica.container ~= nil then
        SendModRPCToServer(GetModRPC("MOD_HARDMODE", "driedmeatbtn2hm"), inst)
    end
end
AddModRPCHandler("MOD_HARDMODE", "driedmeatbtn2hm", findcandriedmeatracks)
local meatrackvalidfn = truefn

-- 霜冻核心支持升级
local sharkboiupdate = GetModConfigData("sharkboi")
local function upgradevalidfn(inst)
    return not inst:HasTag("frostcore2hm")
end

local function checkpausebtnstatus2hm(_inst, inst, btn)
    _inst.checkdisabletask_2hm:Cancel()
    _inst.checkdisabletask_2hm = nil
    if btn and btn.Enable then btn:Enable() end
end

local function upgradefn(player, inst)
     if inst and inst:IsValid() and inst.components.container and player and player:IsValid() and player.components.inventory then
        if inst:HasTag("frostcore2hm") then
            if player.components.talker then
                player.components.talker:Say(TUNING.isCh2hm and ("容器已经升级过啦") or ("The container has already been upgraded."))
            end
            return 
        end
        local active_item = player.components.inventory:GetActiveItem()
        if not active_item then
            if player.components.talker then
                player.components.talker:Say(TUNING.isCh2hm and ("手上没有霜冻核心") or ("There is no Frost Core on the mouse pointer"))
            end
            return
        elseif active_item and not (active_item:IsValid() and active_item.prefab == "frostcore2hm") then
            if player.components.talker then
                player.components.talker:Say(TUNING.isCh2hm and ("手上的物品不是霜冻核心") or ("The item on the mouse is not a Frost Core"))
            end
            return
        end
        if active_item.components.action2hm and active_item.components.action2hm.actionfn then
            local result = active_item.components.action2hm.actionfn(active_item, player, inst)
            if player.components.talker then
                if result then
                    player.components.talker:Say(TUNING.isCh2hm and ("成功升级啦") or ("Successfully upgraded!"))
                else
                    player.components.talker:Say(TUNING.isCh2hm and ("升级失败了") or ("The upgrade failed"))
                end
            end
        end
    end
end

AddModRPCHandler("MOD_HARDMODE", "upgradebtn2hm", upgradefn)
local function upgradebtnfn(inst, doer, btn)
    if btn and btn.Disable and btn.inst and not btn.inst.checkdisabletask_2hm then
        btn:Disable()
        btn.inst.checkdisabletask_2hm = btn.inst:DoPeriodicTask(1, checkpausebtnstatus2hm, 5, inst, btn)
    end
    if TheWorld.ismastersim then
        upgradefn(doer, inst)
    elseif not TheWorld.ismastersim then
        SendModRPCToServer(GetModRPC("MOD_HARDMODE", "upgradebtn2hm"), inst)
    end
end

-- 按钮右键操作支持
local function SetButtonRightControl(self)
    if self.SetButtonRightControl2hm then return end
    self.SetButtonRightControl2hm = true
    local oldOnControl = self.OnControl
    self.OnControl = function(self, control, down, ...)
        local result = oldOnControl(self, control, down, ...)
        if not self:IsEnabled() or not self.focus then return result end
        if self:IsSelected() and not self.AllowOnControlWhenSelected then return result end
        if control == CONTROL_SECONDARY then
            if down then
                if not self.down2hm and not self.down then
                    if self.has_image_down and self.image then
                        self.image:SetTexture(self.atlas, self.image_down)
                        if self.size_x and self.size_y then self.image:ScaleToSize(self.size_x, self.size_y) end
                    end
                    TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
                    self.o_pos = self:GetLocalPosition()
                    if self.move_on_click then self:SetPosition(self.o_pos + self.clickoffset) end
                    self.down2hm = true
                end
            else
                if self.down2hm then
                    if self.has_image_down and self.image then
                        self.image:SetTexture(self.atlas, self.image_focus)
                        if self.size_x and self.size_y then self.image:ScaleToSize(self.size_x, self.size_y) end
                    end
                    self.down2hm = false
                    self:ResetPreClickPosition()
                    if self.onrightclick2hm then self.onrightclick2hm() end
                end
            end
        end
        return result
    end
    self.AllowOnControlWhenSelected = true
end

-- [[[[[容器按钮]]]]
if containercfg and isclient then
    local btnlist = {
        sortbtn = {
            text = TUNING.isCh2hm and "整理" or "Sort",
            -- 2025.7.9 melon:不显示提示的选项
            helptext = no_help_text and "" or TUNING.isCh2hm and [[排序该容器内道具
背包双击会混合排序物品栏和背包内道具
尝试打字“显示/隐藏/默认整理”]] or [[Sort Your Items
Backpack Double Click Will Pass Through Inventory
Try Chat: show/hide/default sort]],
            fn = realsortbtnfn,
            validfn = defaultbtnvalidfn
        },
        lockbtn = lockbtninfo,
        multisortbtn = {
            text = TUNING.isCh2hm and "跨整" or "MSort",
            helptext = TUNING.isCh2hm and [[背包会混合排序物品栏和背包内道具
携带容器混合排序所在容器内的所有同类容器内道具
地面容器会混合排序周围同名容器内道具,不会跨船]] or "Sort Your Items Pass Through Containers",
            fn = multisortbtnfn,
            validfn = defaultbtnvalidfn
        },
        collectbtn = {
            text = TUNING.isCh2hm and "收集" or "Collect",
            -- 2025.7.9 melon:不显示提示的选项
            helptext = no_help_text and "" or TUNING.isCh2hm and [[携带容器收集携带的容器内同名道具
地面容器收集周围容器内的同名道具,不会跨船
佩戴或手持懒人护符,则拾取周围地上同名道具]] or [[Collect Same Items From Containers
Use Orange Amulet will Picktop Near Same Items]],
            fn = collectbtnfn,
            validfn = defaultbtnvalidfn
        },
        exchangebtn = {
            text = TUNING.isCh2hm and "穿越" or "PassW",
            helptext = TUNING.isCh2hm and [[与另一世界整箱互换；双方确认后解锁，无需每次保存世界]] or
                [[Swap whole containers; unlock after both worlds confirm, without saving on each exchange]],
            fn = exchangebtnfn,
            validfn = exchangevalidfn
        },
        pausebtn = {
            text = TUNING.isCh2hm and "状态" or "Status",
            helptext = TUNING.isCh2hm and [[查看交换进度并重试通信；无需暂停服务器]] or
                [[Check exchange progress and retry communication]],
            fn = exchangestatusbtnfn,
            validfn = exchangestatusvalidfn
        },
        reskinbtn = { text = TUNING.isCh2hm and "换装" or "Skin", fn = reskinbtnfn, validfn = reskinvalidfn },
        collectmeatbtn = { text = TUNING.isCh2hm and "收集" or "Collect", helptext = TUNING.isCh2hm and [[一键收集附近所有晾肉架中的产物放入物品栏(雨天会收集可风干物)
        鼠标手持物品点击强制收集附近肉架内含有的相同物品]] or
                [[One click collection of all dried meat from nearby meat racks into the inventory. (Collect items that can be dried on rainy days.)
                Hold the item with the mouse and click to forcibly collect the same items contained in nearby meat racks.]],
            fn = collectmeatbtnfn, validfn = meatrackvalidfn },
        storemeatbtn = { text = TUNING.isCh2hm and "存放" or "Store", helptext = TUNING.isCh2hm and [[一键收集附近所有晾肉架中的产物放入容器中(雨天会收集可风干物)
        鼠标手持物品点击强制存放附近肉架内含有的相同物品]] or
                [[One click storage of all dried meat from nearby meat racks into containers (Collect items that can be dried on rainy days)
                Hold the item with the mouse and click to force the storage of the same item contained in the nearby meat rack]],
            fn = storemeatbtnfn, validfn = meatrackvalidfn },
        drymeatbtn = { text = TUNING.isCh2hm and "晒肉" or "Dry", helptext = TUNING.isCh2hm and [[一键晾晒鼠标手持的物品到附近的晾肉架中]] or
                [[One click drying of items on the mouse pointer to a nearby meat rack]],
            fn = driedmeatbtnfn, validfn = meatrackvalidfn },
        upgradebtn = {
        text = TUNING.isCh2hm and "升级" or "Upgrade",
        helptext = TUNING.isCh2hm and [[鼠标手持霜冻核心可升级容器]] or
            [[Mouse holds the Frost Core to upgrade the container]],
        fn = upgradebtnfn,
        validfn = upgradevalidfn
        },
        privatespacebtn = {
            text = TUNING.isCh2hm and "私人" or "Private",
            helptext = TUNING.isCh2hm and [[进入你自己的私人空间(4x5格,只有你能访问)]] or
                [[Enter your own private space (4x5 slots, only you can access)]],
            fn = function(inst, doer)
                if TUNING.util2hm.OpenMagicianPrivate2hm then TUNING.util2hm.OpenMagicianPrivate2hm(inst, doer) end
            end,
            validfn = defaultbtnvalidfn
        },
    }
    local function addbuttoninfoforcontainerparams(prefab, container)
        if container and container.inst and not container.inst:HasTag("dcs2hm") and not container.inst.dcs2hm and not container.usespecificslotsforitems and
            (container.acceptsstacks or table.contains(meatracklist, prefab)) and container.widget and not container.widget.sortbtninfo2hm and container.widget.slotpos and
            (#container.widget.slotpos > 5 or (#container.widget.slotpos >= 4 and (prefab == "puffvest" or prefab == "puffvest_big")) or 
            (#container.widget.slotpos >= 3 and table.contains(meatracklist, prefab))) then
            -- x相同说明在一条竖线上，y相同说明在一条横线上
            local allslotpos = container.widget.slotpos
            local finalslot = #allslotpos
            -- 计算顶部位置
            local linelength = 1
            local starty = allslotpos[1].y
            for i = 2, finalslot do
                if allslotpos[i].y ~= starty then break end
                linelength = linelength + 1
            end
            local firstlineendslotpos1 = allslotpos[linelength]
            local topposition1 = Vector3(firstlineendslotpos1.x, firstlineendslotpos1.y + 57, firstlineendslotpos1.z)
            local topposition2, topposition3, topposition4
            if linelength > 1 then
                local firstlineendslotpos2 = allslotpos[linelength - 1]
                topposition2 = Vector3(firstlineendslotpos2.x, firstlineendslotpos2.y + 57, firstlineendslotpos2.z)
                if linelength > 2 then
                    local firstlineendslotpos3 = allslotpos[linelength - 2]
                    topposition3 = Vector3(firstlineendslotpos3.x, firstlineendslotpos3.y + 57, firstlineendslotpos3.z)
                    if linelength > 3 then
                        local firstlineendslotpos4 = allslotpos[linelength - 3]
                        topposition4 = Vector3(firstlineendslotpos4.x, firstlineendslotpos4.y + 57, firstlineendslotpos4.z)
                    else
                        topposition4 = Vector3(firstlineendslotpos3.x, firstlineendslotpos3.y + 94, firstlineendslotpos3.z)
                    end
                else
                    topposition3 = Vector3(firstlineendslotpos2.x, firstlineendslotpos2.y + 94, firstlineendslotpos2.z)
                    topposition4 = Vector3(firstlineendslotpos2.x, firstlineendslotpos2.y + 131, firstlineendslotpos2.z)
                end
            else
                topposition2 = Vector3(firstlineendslotpos1.x, firstlineendslotpos1.y + 94, firstlineendslotpos1.z)
                topposition3 = Vector3(firstlineendslotpos1.x, firstlineendslotpos1.y + 131, firstlineendslotpos1.z)
                topposition4 = Vector3(firstlineendslotpos1.x, firstlineendslotpos1.y + 168, firstlineendslotpos1.z)
            end
            -- 计算左侧位置
            local firstcolumnlength = 1
            local startx = allslotpos[1].x
            for i = linelength + 1, finalslot, linelength do
                if allslotpos[i].x ~= startx then break end
                firstcolumnlength = firstcolumnlength + 1
            end
            local firstcolumnnendslotpos1 = allslotpos[(firstcolumnlength - 1) * linelength + 1]
            local leftposition1 = Vector3(firstcolumnnendslotpos1.x - 74, firstcolumnnendslotpos1.y - 15,
                firstcolumnnendslotpos1.z)
            local leftposition2 = Vector3(firstcolumnnendslotpos1.x - 74, firstcolumnnendslotpos1.y + 22,
                firstcolumnnendslotpos1.z)
            local leftposition3 = Vector3(firstcolumnnendslotpos1.x - 74, firstcolumnnendslotpos1.y + 59,
                firstcolumnnendslotpos1.z)
            local leftposition4 = Vector3(firstcolumnnendslotpos1.x - 74, firstcolumnnendslotpos1.y + 96,
            firstcolumnnendslotpos1.z)
            -- 计算右侧位置
            local endcolumnlength = 1
            local endx = allslotpos[linelength].x
            for i = linelength * 2, finalslot, linelength do
                if allslotpos[i].x ~= endx then break end
                endcolumnlength = endcolumnlength + 1
            end
            finalslot = linelength * endcolumnlength
            local finalslotpos1 = allslotpos[finalslot]
            local rightposition1 = Vector3(finalslotpos1.x + 74, finalslotpos1.y - 15, finalslotpos1.z)
            local rightposition2 = Vector3(finalslotpos1.x + 74, finalslotpos1.y + 22, finalslotpos1.z)
            local rightposition3 = Vector3(finalslotpos1.x + 74, finalslotpos1.y + 59, finalslotpos1.z)
            local rightposition4 = Vector3(finalslotpos1.x + 74, finalslotpos1.y + 96, finalslotpos1.z)
            -- 计算底部位置，默认位置
            local finalslotpos1 = allslotpos[finalslot]
            local position1 = Vector3(finalslotpos1.x, finalslotpos1.y - 57, finalslotpos1.z)
            local position2, position3, position4
            local finalslotpos2 = allslotpos[finalslot - 1]
            if finalslotpos2 and finalslotpos2.x ~= finalslotpos1.x and (container.widget.buttoninfo == nil or linelength >= 5) then
                position2 = Vector3(finalslotpos2.x, finalslotpos2.y - 57, finalslotpos2.z)
                local finalslotpos3 = allslotpos[finalslot - 2]
                if finalslotpos3 and finalslotpos3.x ~= finalslotpos1.x and (container.widget.buttoninfo == nil or linelength >= 7) then
                    position3 = Vector3(finalslotpos3.x, finalslotpos3.y - 57, finalslotpos3.z)
                    local finalslotpos4 = allslotpos[finalslot - 3]
                    if finalslotpos4 and finalslotpos4.x ~= finalslotpos2.x and (container.widget.buttoninfo == nil or linelength >= 9) then
                        position4 = Vector3(finalslotpos4.x, finalslotpos4.y - 57, finalslotpos4.z)
                    else
                        position4 = Vector3(finalslotpos3.x, finalslotpos3.y - 100, finalslotpos3.z)
                    end
                else
                    position3 = Vector3(finalslotpos2.x, finalslotpos2.y - 100, finalslotpos2.z)
                    position4 = Vector3(finalslotpos2.x, finalslotpos2.y - 143, finalslotpos2.z)
                end
            else
                position2 = Vector3(finalslotpos1.x, finalslotpos1.y - 100, finalslotpos1.z)
                position3 = Vector3(finalslotpos1.x, finalslotpos1.y - 143, finalslotpos1.z)
                position4 = Vector3(finalslotpos1.x, finalslotpos1.y - 186, finalslotpos1.z)
            end
            -- 存储位置信息
            local positions = { position1, position2, position3 , position4}
            local toppositions = { topposition1, topposition2, topposition3 , topposition4}
            local leftpositions = { leftposition1, leftposition2, leftposition3, leftposition4 }
            local rightpositions = { rightposition1, rightposition2, rightposition3 , rightposition4}
            local poslist = {
                positions = positions,
                toppositions = toppositions,
                leftpositions = leftpositions,
                rightpositions =
                    rightpositions
            }
            -- 衣柜多一个按钮的位置信息
            if prefab == "wardrobe" and (hasmultisortbtn or haslockbutton) then
                local finalslotpos4 = allslotpos[finalslot - 3]
                local firstlineendslotpos3 = allslotpos[linelength - 3]
                positions[4] = Vector3(finalslotpos4.x, finalslotpos4.y - 57, finalslotpos4.z)
                toppositions[4] = Vector3(firstlineendslotpos3.x, firstlineendslotpos3.y + 57, firstlineendslotpos3.z)
                leftpositions[4] = Vector3(firstcolumnnendslotpos1.x - 74, firstcolumnnendslotpos1.y + 96,
                    firstcolumnnendslotpos1.z)
                rightpositions[4] = Vector3(finalslotpos1.x + 74, finalslotpos1.y + 96, finalslotpos1.z)
            end
            -- 记录到容器上
            container.widget.poslist2hm = poslist
        end
    end
    local old_wsetup = containers.widgetsetup
    function containers.widgetsetup(container, prefab, data, ...)
        local result = old_wsetup(container, prefab, data, ...)
        addbuttoninfoforcontainerparams(prefab or container.inst.prefab, container)
        return result
    end

    if TUNING.CHESTUPGRADE then
        AddComponentPostInit("chestupgrade", function(self)
            local UpdateWidget = self.UpdateWidget
            self.UpdateWidget = function(self, ...)
                UpdateWidget(self, ...)
                if self.inst.components.container then
                    addbuttoninfoforcontainerparams(self.inst.prefab,
                        self.inst.components.container)
                end
            end
        end)
        AddClassPostConstruct("components/chestupgrade_replica", function(self)
            local UpdateWidget = self.UpdateWidget
            self.UpdateWidget = function(self, ...)
                UpdateWidget(self, ...)
                if self.inst.replica.container then
                    addbuttoninfoforcontainerparams(self.inst.prefab,
                        self.inst.replica.container)
                end
            end
        end)
    end
    -- 按钮添加
    local allbtnnewdir = { left = "top", top = "right", right = "down", down = "left" }
    local function addbutton(self, container, widget, doer, btnname, btninfo, idx, position)
        local btn = self:AddChild(ImageButton("images/ui.xml", "button_small.tex", "button_small_over.tex",
            "button_small_disabled.tex", nil, nil, { 1, 1 },
            { 0, 0 }))
        if position then
            btn:SetPosition(position)
        elseif idx and widget.poslist2hm then
            local dirpos = (TUNING.TEMP2HM.btnotherdir[container.prefab] or "") .. "positions"
            btn.idx2hm = idx
            if widget.poslist2hm[dirpos] and widget.poslist2hm[dirpos][idx] then
                btn:SetPosition(widget.poslist2hm[dirpos][idx])
                btn.poslist2hm = widget.poslist2hm
            else
                btn:Kill()
                return
            end
        end
        btn.image:SetScale(0.77, 1.07, 1.07)
        btn.text:SetPosition(2, -2)
        btn:SetFont(BUTTONFONT)
        btn:SetDisabledFont(BUTTONFONT)
        btn:SetTextSize(33)
        btn.text:SetVAlign(ANCHOR_MIDDLE)
        btn.text:SetColour(0, 0, 0, 1)
        self[btnname] = btn
        btn:SetText(btninfo.text)
        btn.btninfo2hm = btninfo
        if btninfo.helptext then btn:SetTooltip(btninfo.helptext) end
        if btninfo.fn ~= nil then btn:SetOnClick(function() btninfo.fn(container, doer, btn) end) end
        return btn
    end
    -- 按钮转向
    local btnnames = { "reskinbutton2hm", "exchangebutton2hm", "lockbutton2hm", "sortbutton2hm", "multisortbutton2hm",
        "collectbutton2hm", "button", "pause2hm", "collectmeat_inventory_button2hm", "storemeatbutton2hm", "dryingitembutton2hm",
    "upgrade2hm", "privatespacebtn2hm"}
    local changebtndirtip
    local function supportchangebtnpos(self, btn, container)
        if not changebtndirtip then
            changebtndirtip = no_help_text and "" or "\n" .. -- 2025.7.9 melon:不显示提示的选项
                TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_SECONDARY) .. ": " ..
                (TUNING.isCh2hm and "转变按钮所在方向" or "Change Buttons' Dir")
        end
        if btn.btninfo2hm and btn.btninfo2hm.helptext then btn:SetTooltip(btn.btninfo2hm.helptext .. changebtndirtip) end
        btn.onrightclick2hm = function()
            if not btn.idx2hm or not btn.poslist2hm then return end
            local old = TUNING.TEMP2HM.btnotherdir[container.prefab] or "down"
            local new = allbtnnewdir[old]
            if new == "down" then new = nil end
            TUNING.TEMP2HM.btnotherdir[container.prefab] = new
            SaveTemp2hm()
            local newdirpos = (new or "") .. "positions"
            for _, name in ipairs(btnnames) do
                if self[name] ~= nil and self[name].poslist2hm and self[name].idx2hm and self[name].poslist2hm[newdirpos] and
                    self[name].poslist2hm[newdirpos][self[name].idx2hm] then
                    self[name]:SetPosition(self[name].poslist2hm[newdirpos][self[name].idx2hm])
                end
            end
        end
        SetButtonRightControl(btn)
    end
    local chancelockbtntip
    local function processlockbtninspect(btn, inst, doer)
        if not chancelockbtntip then
            chancelockbtntip = true
            lockbtninfo.helptext2 = no_help_text and "" or lockbtninfo.helptext2 .. -- 2025.7.9
                "\n" .. TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_SECONDARY) .. ": " ..
                (TUNING.isCh2hm and "显示该容器限制存放哪些道具" or "Show its limit item names")
            if inst:HasTag("lockcontainer2hm") then btn:SetTooltip(lockbtninfo.helptext2) end
        end
        btn.onrightclick2hm = function() rightlockbtnfn(inst, doer) end
        SetButtonRightControl(btn)
    end
    AddClassPostConstruct("widgets/inventorybar", function(self)
        local oldRebuild = self.Rebuild
        self.Rebuild = function(self, ...)
            oldRebuild(self, ...)
            local inventory = self.owner.replica.inventory
            local overflow = inventory:GetOverflowContainer()
            overflow = (overflow ~= nil and overflow:IsOpenedBy(self.owner)) and overflow or nil
            local do_integrated_backpack = overflow ~= nil and self.integrated_backpack
            if do_integrated_backpack and self.bottomrow and overflow and overflow.inst then
                local widget = overflow:GetWidget()
                local num = overflow:GetNumSlots()
                if self.backpackinv and self.backpackinv[num] and (not widget.buttoninfo or overflow.inst.prefab == "silksack") and widget.poslist2hm then
                    local pos = self.backpackinv[num]:GetPosition()
                    local pos1 = Vector3(pos.x + 98, pos.y, pos.z)
                    local pos2 = Vector3(pos.x + 168, pos.y, pos.z)
                    local pos3 = Vector3(pos.x + 238, pos.y, pos.z)
                    if TUNING.DATA2HM.opensort then
                        addbutton(self.bottomrow, overflow.inst, widget, self.owner, "sortbutton2hm", btnlist.sortbtn,
                            nil, pos1)
                    end
                    if overflow.inst:HasTag("pocketdimension_container") then
                        if not TUNING.DSA_ONE_PLAYER_MODE then
                            addbutton(self.bottomrow, overflow.inst, widget, self.owner, "exchangebutton2hm",
                                btnlist.exchangebtn, nil,
                                TUNING.DATA2HM.opensort and pos2 or pos1)
                        end
                        if container.prefab == "tacklestation2hm" and sharkboiupdate then
                            addbutton(self, container, widget, doer, "upgrade2hm", btnlist.upgradebtn,
                            TUNING.DATA2HM.opensort and 4 or 3)
                        end
                    else
                        if haslockbutton then
                            btnlist.lockbtn.text = overflow.inst:HasTag("lockcontainer2hm") and btnlist.lockbtn.text2 or
                                btnlist.lockbtn.text1
                            btnlist.lockbtn.helptext = overflow.inst:HasTag("lockcontainer2hm") and
                                btnlist.lockbtn.helptext2 or btnlist.lockbtn.helptext1
                            processlockbtninspect(
                                addbutton(self.bottomrow, overflow.inst, widget, self.owner, "lockbutton2hm", btnlist
                                    .lockbtn, nil,
                                    TUNING.DATA2HM.opensort and pos2 or pos1), overflow.inst, self.owner)
                        end
                        if hasmultisortbtn then
                            addbutton(self.bottomrow, overflow.inst, widget, self.owner, "multisortbutton2hm",
                                btnlist.multisortbtn, nil,
                                TUNING.DATA2HM.opensort and pos2 or pos1)
                        end
                        if hascollectbutton then
                            addbutton(self.bottomrow, overflow.inst, widget, self.owner, "collectbutton2hm",
                                btnlist.collectbtn, nil, (haslockbutton or
                                    hasmultisortbtn) and TUNING.DATA2HM.opensort and pos3 or
                                ((haslockbutton or hasmultisortbtn or TUNING.DATA2HM.opensort) and pos2 or pos1))
                        end
                    end
                end
            end
        end
    end)
    AddClassPostConstruct("widgets/containerwidget", function(self)
        local oldOpen = self.Open
        self.Open = function(self, container, doer, ...)
            local result = oldOpen(self, container, doer, ...)
            local widget = container.replica.container and container.replica.container:GetWidget()
            if container and table.contains(meatracklist, container.prefab) and widget and not container:HasTag("dcs2hm") and not container.dcs2hm and btnlist and widget.poslist2hm then
                addbutton(self, container, widget, doer, "collectmeat_inventory_button2hm", btnlist.collectmeatbtn, 1)
                addbutton(self, container, widget, doer, "storemeatbutton2hm", btnlist.storemeatbtn, 2)
                supportchangebtnpos(self, addbutton(self, container, widget, doer, "dryingitembutton2hm", btnlist.drymeatbtn , 3), container)
                return result
            end
            if container and widget and not container:HasTag("dcs2hm") and
                (not container.dcs2hm or container:HasTag("exchangeloading2hm")) and btnlist and widget.poslist2hm then
                if TUNING.DATA2HM.opensort then
                    supportchangebtnpos(self,
                        addbutton(self, container, widget, doer, "sortbutton2hm", btnlist.sortbtn, 1), container)
                end
                if container:HasTag("pocketdimension_container") then
                    if not TUNING.DSA_ONE_PLAYER_MODE then
                        addbutton(self, container, widget, doer, "exchangebutton2hm", btnlist.exchangebtn,
                            TUNING.DATA2HM.opensort and 2 or 1)
                        addbutton(self, container, widget, doer, "pause2hm", btnlist.pausebtn,
                            TUNING.DATA2HM.opensort and 3 or 2)
                        if container.prefab == "tacklestation2hm" and sharkboiupdate then
                            addbutton(self, container, widget, doer, "upgrade2hm", btnlist.upgradebtn,
                            TUNING.DATA2HM.opensort and 4 or 3)
                        end
                    end
                else
                    if haslockbutton then
                        btnlist.lockbtn.text = container:HasTag("lockcontainer2hm") and btnlist.lockbtn.text2 or
                            btnlist.lockbtn.text1
                        btnlist.lockbtn.helptext = container:HasTag("lockcontainer2hm") and btnlist.lockbtn.helptext2 or
                            btnlist.lockbtn.helptext1
                        processlockbtninspect(
                            addbutton(self, container, widget, doer, "lockbutton2hm", btnlist.lockbtn,
                                TUNING.DATA2HM.opensort and 2 or 1),
                            container, doer)
                    end
                    if hasmultisortbtn then
                        addbutton(self, container, widget, doer, "multisortbutton2hm", btnlist.multisortbtn,
                            TUNING.DATA2HM.opensort and 2 or 1)
                    end
                    if hascollectbutton then
                        supportchangebtnpos(self,
                            addbutton(self, container, widget, doer, "collectbutton2hm", btnlist.collectbtn,
                                (haslockbutton or
                                    hasmultisortbtn) and TUNING.DATA2HM.opensort and 3 or
                                ((haslockbutton or hasmultisortbtn or TUNING.DATA2HM.opensort) and 2 or 1)), container)
                    end
                end
                local isusinghat2hm = doer ~= nil and
                                           ((doer.HasTag ~= nil and doer:HasTag("usingmagiciantool")) or
                                               (doer.sg ~= nil and doer.sg.currentstate ~= nil and
                                                   (doer.sg.currentstate.name == "using_tophat" or doer.sg.currentstate.name == "start_using_tophat")))
                if container.prefab == "shadow_container" and btnlist.privatespacebtn ~= nil and isusinghat2hm and
                    TUNING.util2hm.CanUseMagicianPrivate2hm and TUNING.util2hm.CanUseMagicianPrivate2hm(doer) then
                    local poslist = widget.poslist2hm
                    if poslist ~= nil and poslist.positions ~= nil and poslist.positions[1] ~= nil then
                        poslist.positions[4] = Vector3(poslist.positions[1].x, poslist.positions[1].y - 43, 0)
                    end
                    local prividx = TUNING.DSA_ONE_PLAYER_MODE and (TUNING.DATA2HM.opensort and 2 or 1) or
                        (TUNING.DATA2HM.opensort and 4 or 3)
                    supportchangebtnpos(self,
                        addbutton(self, container, widget, doer, "privatespacebtn2hm", btnlist.privatespacebtn, prividx),
                        container)
                end
                if container.prefab == "magician_private_container2hm" then
                    local hud = doer ~= nil and doer.HUD or nil
                    if hud ~= nil and hud.controls ~= nil and hud.controls.containers ~= nil and hud.controls.containerroot ~= nil then
                        local stales = {}
                        for c, w in pairs(hud.controls.containers) do
                            if c ~= container and w ~= nil and w:GetParent() == hud.controls.containerroot then
                                table.insert(stales, c)
                            end
                        end
                        for _, c in ipairs(stales) do
                            hud:CloseContainer(c, false)
                        end
                    end
                end
                if container.prefab == "wardrobe" then
                    local idx = 1
                    if hascollectbutton then idx = idx + 1 end
                    if haslockbutton or hasmultisortbtn then idx = idx + 1 end
                    if TUNING.DATA2HM.opensort then idx = idx + 1 end
                    addbutton(self, container, widget, doer, "reskinbutton2hm", btnlist.reskinbtn, idx)
                end
            end
            return result
        end
        local oldClose = self.Close
        self.Close = function(self, ...)
            if self.isopen then
                for _, name in ipairs(btnnames) do
                    if self[name] ~= nil then
                        self[name]:Kill()
                        self[name] = nil
                    end
                end
            end
            return oldClose(self, ...)
        end
    end)
    -- 妥协衣柜处理
    AddPrefabPostInit("wardrobe", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.wardrobe and inst.components.container then
            if inst.UnregisterComponentActions then inst:UnregisterComponentActions("wardrobe") end
            inst:RemoveTag("wardrobe")
        end
    end)
end

-- [[[[[道具/制作栏快捷存取]]]]
if itemscfg then
    -- 收集指定类型或名称的道具
    local collectrecipefn = nilfn
    if craftmenucollectsupport or hasitemscollect or foodingredientcollectsupport then
        -- 后面的doer和item都是可选的,主要用于ctrl alt右键道具收集道具
        collectrecipefn = function(inst, recipe_type, neednum, doer, item, forceitemtestfn)
            if not recipe_type or recipe_type == "" or
                not ((inst.components.inventory and inst.components.inventory.maxslots > 0) or
                    (inst.components.container and inst.components.container.numslots > 0)) then
                return
            end
            local inventory = inst.components.inventory
            if doer and doer:IsValid() and doer.components.inventory then inventory = doer.components.inventory end
            if inventory == nil then return end

            -- 开发时用,提交之前记得屏蔽
            -- do
            --     local prefab = SpawnPrefab(recipe_type)
            --     if prefab then
            --         if inst.components.inventory and inst.components.inventory:GiveItem(prefab) then
            --         else
            --             prefab:Remove()
            --         end
            --     end
            --     return
            -- end

            -- 记录要收集的实体名和目标数目,各实体堆叠时欠缺的数目(也可能是无限),剩余格子数目
            local data = {}
			data.doer = inst
            data.neednum = neednum
            if neednum == false then data.neednum = nil end
            -- 判断道具的类型或名称，决定要收集的数目
            if forceitemtestfn then
                data.fastresult = true
                data.prefabfn = forceitemtestfn
            elseif item and item:IsValid() and item.prefab then
                if item:HasTag("heatrock") and item.components.temperature and item.components.heater and not item.components.stackable and
                    (TheWorld.state.issummer or TheWorld.state.iswinter) and not item.heatrockfindtask2hm then
                    -- 收集暖石时可以与目标暖石进行交换
                    item.heatrockfindtask2hm = item:DoTaskInTime(3, function()
                        item.heatrockfindtask2hm = nil
                        item.prevplayer2hm = nil
                    end)
                    item.prevplayer2hm = inventory and inventory.inst
                    local current = item.components.temperature.current
                    data.fastresult = true
                    data.exchangeitem = item
                    data.exchangeitemfn = function(olditem, newitem)
                        if olditem.heatrockfindtask2hm then
                            olditem.heatrockfindtask2hm:Cancel()
                            olditem.heatrockfindtask2hm = nil
                            olditem.prevplayer2hm = nil
                        end
                    end
                    if TheWorld.state.issummer then
                        data.prefabfn = function(v)
                            return v:HasTag("heatrock") and v.components.temperature and v.components.heater and
                                v.components.temperature.current < current and
                                not v.components.stackable
                        end
                    elseif TheWorld.state.iswinter then
                        data.prefabfn = function(v)
                            return v:HasTag("heatrock") and v.components.temperature and v.components.heater and
                                v.components.temperature.current > current and
                                not v.components.stackable
                        end
                    end
                elseif item.dryseeds2hm then -- 干种子
                    data.fastresult = false
                    data.prefabfn = function(v) return v.dryseeds2hm ~= nil end
                elseif item.components.yotb_skinunlocker ~= nil then -- 宠物皮肤蓝图
                    data.fastresult = false
                    data.prefabfn = function(v) return v.components.yotb_skinunlocker ~= nil end
                elseif item.nameoverride == "redpouch" then -- 红包
                    data.fastresult = false
                    data.prefabfn = function(v) return v.prefab == "redpouch" or v.nameoverride == "redpouch" end
                elseif item:HasTag("halloween_ornament") then -- 万圣节装饰
                    data.fastresult = false
                    data.prefabfn = function(v) return v:HasTag("halloween_ornament") end
                elseif item:HasTag("wintersfeastfood") then -- 圣诞零食
                    data.fastresult = false
                    data.prefabfn = function(v) return v:HasTag("wintersfeastfood") end
                elseif item:HasTag("winter_ornament") then
                    if item.nameoverride == "winter_ornament" then -- 圣诞小玩意
                        data.fastresult = false
                        data.prefabfn = function(v)
                            return v.nameoverride == "winter_ornament" and
                                v:HasTag("winter_ornament")
                        end
                    elseif item:HasTag("lightbattery") then -- 圣诞灯
                        data.fastresult = false
                        data.prefabfn = function(v) return v:HasTag("winter_ornament") and v:HasTag("lightbattery") end
                    elseif item.nameoverride ~= nil then -- 圣诞装饰
                        data.fastresult = false
                        data.prefabfn = function(v)
                            return v.nameoverride ~= nil and v.nameoverride ~= "winter_ornament" and
                                v:HasTag("winter_ornament") and
                                not v:HasTag("lightbattery")
                        end
                    end
                elseif string.find(item.prefab, "trinket") then -- 玩具
                    data.fastresult = false
                    data.prefabfn = function(v) return v.prefab ~= nil and string.find(v.prefab, "trinket") end
                else
                    data.prefabs = { recipe_type }
                end
            else
                data.prefabs = { recipe_type }
            end
            -- 物品栏或容器空间进行额外检测
            if inst.components.inventory then
                local isfull = getcontainerspace(inst, inst.components.inventory, data, false)
                if isfull then
                    local overflow = inst.components.inventory:GetOverflowContainer()
                    if overflow and (overflow.itemtestfn == nil or ((item and overflow:itemtestfn(item)) or (overflow and overflow.inst:HasTag("pocketbackpack")))) then
                        isfull = getcontainerspace(inst, overflow, data, false)
                        if isfull then
                            data.leftnumslots = data.leftnumslots + 1
                            local activeitem = inventory.activeitem
                            if activeitem ~= nil and activeitem:IsValid() then
                                data.leftnumslots = data.leftnumslots - 1
                                if (data.prefabfn and data.prefabfn(activeitem) or (data.prefabs and table.contains(data.prefabs, activeitem.prefab))) and
                                    activeitem.components.stackable then
                                    if activeitem.components.stackable.maxsize == math.huge then
                                        data.infiniteprefabs[activeitem.prefab] = true
                                        if data.lacksize[activeitem.prefab] then data.lacksize[activeitem.prefab] = nil end
                                        isfull = nil
                                    elseif activeitem.components.stackable.stacksize < activeitem.components.stackable.maxsize then
                                        data.lacksize[activeitem.prefab] = (data.lacksize[activeitem.prefab] or 0) +
                                            activeitem.components.stackable.maxsize -
                                            activeitem.components.stackable.stacksize
                                        isfull = nil
                                    end
                                end
                            end
                        end
                    end
                end
                if isfull then
                    if inst.components.talker then
                        inst.components.talker:Say(GetActionFailString(inst, "STORE") or
                            (TUNING.isCh2hm and ("已经拿不下了") or ("Inventory full.")))
                    end
                    return
                end
            elseif inst.components.container then
                if getcontainerspace(inst, inst.components.container, data, false) then
                    if doer and doer:IsValid() and doer.components.talker then
                        doer.components.talker:Say(GetActionFailString(inst, "STORE") or
                            (TUNING.isCh2hm and ("已经放不下了") or ("Inventory full.")))
                    end
                    return
                end
            end
            if data.fastresult == nil then data.fastresult = true end
            if data.fastresult == false then
                data.fastresult = nil
                data.neednum = nil
            elseif data.infiniteprefabs ~= nil then
                data.lacksize[recipe_type] = data.neednum or data.lacksize[recipe_type]
                data.infiniteprefabs = nil
            elseif data.lacksize[recipe_type] == 0 then
                data.lacksize[recipe_type] = nil
            elseif not data.neednum then
                data.neednum = data.lacksize[recipe_type]
            end
            if inst.components.container and not inst.components.container.acceptsstacks then data.neednum = 1 end
            -- 记录要收集道具的来源容器列表
            local ents = {}
            data.proxyents = {}
            local x, y, z = inst.Transform:GetWorldPosition()
            local platform = inst:GetCurrentPlatform()
            local nearents = TheSim:FindEntities(x, y, z, 30, nil, GROUND_CONTAINER_CANT_TAGS)
            for i, v in ipairs(nearents) do
                if v ~= inst and v:IsValid() then
                    if v.components.container_proxy and not v.dcs2hm and v.components.container_proxy:CanBeOpened() and not v.components.container and
                        not table.contains(collectblacklist, v.prefab) and v:GetCurrentPlatform() == platform then
                        local master = v.components.container_proxy.master
                        if master and master:IsValid() and not data.proxyents[master] and master.components.container and
                            master.components.container.canbeopened then
                            master.currentpocket2hm = v
                            data.proxyents[master] = v
                            table.insert(ents, master)
                            findcontainersincontainer(master, ents)
                        end
                    elseif v.components.container and not v.dcs2hm and v.components.container.canbeopened and
                        (table.contains(collectwhitelist, v.prefab) or not v.components.inventoryitem or v:HasTag("heavy")) and not inventory.opencontainers[v] and
                        not table.contains(collectblacklist, v.prefab) and v:GetCurrentPlatform() == platform then
                        table.insert(ents, v)
                        findcontainersincontainer(v, ents)
                    end
                end
            end
            local mount = inst.components.rider and inst.components.rider.mount
            if mount == nil and doer then mount = doer.components.rider and doer.components.rider.mount end
            if mount and mount:IsValid() and mount.components.container and not mount:HasTag("dcs2hm") and not mount.dcs2hm then
                table.insert(ents, mount)
                findcontainersincontainer(mount, ents)
            end
            for i = #ents, 1, -1 do
                if ents[i] == inst then
                    table.remove(ents, i)
                    break
                end
            end
            if #ents <= 0 then return end
            local tmpents = {}
            for i, v in ipairs(ents) do
                table.insert(tmpents, v)
                if v.virtchest and v.virtchest:IsValid() and v.virtchest.components.container then
                    if not v.virtchest.virtfrom2hm then v.virtchest.virtfrom2hm = v end
                    table.insert(tmpents, v.virtchest)
                end
            end
            -- 进行收集道具操作
            data.currplayer2hm = doer or inst
            collectcontainers(inst, inst.components.inventory or inst.components.container, data, tmpents)
            -- 实际可以反馈结果
        end
    end
    -- 制作栏快速收集
    if craftmenucollectsupport then
        -- 显示隐藏配方从而可以强行收集不可用配方的素材
        AddClassPostConstruct("widgets/redux/craftingmenu_hud", function(self, ...)
            local GetRecipeState = self.GetRecipeState
            self.GetRecipeState = function(self, recipe_name, ...)
                local result = GetRecipeState(self, recipe_name, ...)
                if result and result.recipe == nil then result.recipe = AllRecipes[recipe_name] end
                return result
            end
        end)
        AddModRPCHandler("MOD_HARDMODE", "collectrecipetypebtn2hm", collectrecipefn)
        local function collectrecipeclientfn(doer, recipe_type, neednum)
            if not recipe_type or recipe_type == "" or type(recipe_type) ~= "string" then return end
            if doer.components.inventory ~= nil and not doer:HasTag("playerghost") and doer.components.inventory.isvisible then
                collectrecipefn(doer, recipe_type, neednum)
            elseif doer.replica.inventory ~= nil and not doer:HasTag("playerghost") then
                SendModRPCToServer(GetModRPC("MOD_HARDMODE", "collectrecipetypebtn2hm"), recipe_type, neednum)
            end
        end
        local function searchcollectfn(doer, name, maybe)
            if doer and doer:IsValid() and doer.components.inventory and not doer:HasTag("playerghost") and doer.components.inventory.isvisible then
                collectrecipefn(doer, name, nil, doer, nil, function(v)
                    return maybe and (v.name and string.find(v.name, name) or string.find(v.prefab, name)) or
                        (v.name == name or v.prefab == name)
                end)
            end
        end
        AddModRPCHandler("MOD_HARDMODE", "searchcollect2hm", searchcollectfn)
        -- local function collect_recipe_type(recipe_type) if ThePlayer and recipe_type and recipe_type ~= "" then collectrecipeclientfn(ThePlayer, recipe_type) end end
        -- 收集指定素材，且至多收集一组
        AddClassPostConstruct("widgets/ingredientui",
            function(self, atlas, image, num_need, num_found, has_enough, name, owner, recipe_type, quant_text_scale,
                     ingredient_recipe, ...)
                if self.recipe_type and num_need and num_found and not IsCharacterIngredient(self.recipe_type) then
                    self.onrightclick2hm = function()
                        collectrecipeclientfn(self.owner or ThePlayer, self.recipe_type, not has_enough and
                            ((num_need * (self.parent and self.parent.parent and self.parent.parent.quantity or 1) - num_found)))
                    end
                    self:SetTooltip((self.tooltip or "") ..
                        "\n" .. TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_SECONDARY) .. ": " ..
                        (has_enough and (TUNING.isCh2hm and "收集更多" or "Collect More") or (TUNING.isCh2hm and "收集" or "Collect")))
                    SetButtonRightControl(self)
                    local recipe = ingredient_recipe ~= nil and ingredient_recipe.recipe or AllRecipes[recipe_type]
                    -- if not self.onclick and recipe then
                    --     local meta = ingredient_recipe ~= nil and ingredient_recipe.meta or nil
                    --     if meta and meta.can_build then
                    --         self.onclick = function()
                    --             if recipe ~= nil and meta and meta.can_build then
                    --                 DoRecipeClick(self.owner, recipe, nil)
                    --             end
                    --         end
                    --     end
                    -- end
                    if not has_enough and recipe then
                        local selffocus, widgetfocus
                        local oldongainfocus = self.ongainfocus
                        self.ongainfocus = function()
                            selffocus = true
                            widgetfocus = true
                            if oldongainfocus then oldongainfocus() end
                            -- if oldongainfocus and self.ingredient_recipe then
                            --     local oldrecipe
                            --     if self.ingredient_recipe.recipe == nil then
                            --         oldrecipe = self.ingredient_recipe.recipe
                            --         self.ingredient_recipe.recipe = recipe
                            --     end
                            --     oldongainfocus()
                            --     if oldrecipe then self.ingredient_recipe.recipe = oldrecipe end
                            -- end
                            if self.sub_ingredients == nil then
                                self.sub_ingredients = self.parent:AddChild(Widget("sub_ingredients"))
                                self.sub_ingredients:MoveToBack()
                                self.background = self.sub_ingredients:AddChild(ThreeSlice(
                                    resolvefilepath("images/crafting_menu.xml"), "popup_end.tex",
                                    "popup_short.tex"))
                                self.ingredients = self.sub_ingredients:AddChild(CraftingMenuIngredients(self.owner, 4,
                                    recipe, 1.5))
                                self.ingredients.quantity = num_need
                                self.background:ManualFlow(math.min(5, self.ingredients.num_items), true)
                            end
                            if self.sub_ingredients ~= nil then
                                self.sub_ingredients.ongainfocus = function() widgetfocus = true end
                                self.sub_ingredients.onlosefocus = function() widgetfocus = not selffocus end
                                local pos = self:GetLocalPosition()
                                self.sub_ingredients:SetPosition(pos.x, pos.y - 64)
                            end
                        end
                        local oldonlosefocus = self.onlosefocus
                        self.onlosefocus = function()
                            selffocus = nil
                            if oldonlosefocus and not widgetfocus then
                                oldonlosefocus()
                            elseif self.sub_ingredients ~= nil and not widgetfocus then
                                self.sub_ingredients:Kill()
                                self.sub_ingredients = nil
                            end
                        end
                    end
                    if not self:IsEnabled() then self:Enable() end
                    self.AllowOnControlWhenSelected = true
                end
            end)
        local function resetpinslottooltip(self)
            if self.craft_button and self.craftingmenu then
                if self.recipe_name then
                    local recipe = AllRecipes[self.recipe_name]
                    if recipe then
                        local name = ((recipe.nameoverride or recipe.name) and STRINGS.NAMES[string.upper(recipe.nameoverride or recipe.name)]) or
                            (recipe.product and STRINGS.NAMES[string.upper(recipe.product)])
                        self.craft_button:SetTooltip((name or "") .. (name and "\n" or "") ..
                            (recipe.placer and "" or
                                (TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_SECONDARY) .. ": " ..
                                    (TUNING.isCh2hm and "收集" or "Collect"))))
                    else
                        self.craft_button:SetTooltip(nil)
                    end
                else
                    self.craft_button:SetTooltip(nil)
                end
            end
        end
        AddClassPostConstruct("widgets/redux/craftingmenu_pinslot", function(self, ...)
            if self.craft_button then
                resetpinslottooltip(self)
                SetButtonRightControl(self.craft_button)
                local oldOnControl = self.craft_button.OnControl
                self.craft_button.OnControl = function(_self, control, down, ...)
                    if not TheInput:IsControlPressed(CONTROL_FORCE_INSPECT) and not TheInput:IsControlPressed(CONTROL_FORCE_STACK) and
                        not TheInput:IsControlPressed(CONTROL_FORCE_TRADE) and control == CONTROL_SECONDARY and down and self.recipe_name then
                        local data = self.craftingmenu:GetRecipeState(self.recipe_name)
                        local prefab = data ~= nil and data.recipe ~= nil and data.recipe.product or self.recipe_name
                        collectrecipeclientfn(self.owner or ThePlayer, prefab)
                    end
                    return oldOnControl(_self, control, down, ...)
                end
            end
            local oldSetRecipe = self.SetRecipe
            self.SetRecipe = function(self, ...)
                oldSetRecipe(self, ...)
                resetpinslottooltip(self)
            end
            local oldOnPageChanged = self.OnPageChanged
            self.OnPageChanged = function(self, ...)
                oldOnPageChanged(self, ...)
                resetpinslottooltip(self)
            end
        end)
        -- AddClassPostConstruct("widgets/redux/craftingmenu_details", function(self, ...)
        --     local PopulateRecipeDetailPanel = self.PopulateRecipeDetailPanel
        --     self.PopulateRecipeDetailPanel = function(self, ...)
        --         PopulateRecipeDetailPanel(self, ...)
        --         if self.build_button_root and self.ingredients and not self.build_button_root.changepos2hm then
        --             self.build_button_root.changepos2hm = true
        --             local pos = self.ingredients:GetLocalPosition()
        --             self.build_button_root:SetPosition(pos.x, pos.y + 12.5)
        --             self.ingredients:SetPosition(pos.x, pos.y - 35)
        --         end
        --     end
        -- end)
        AddClassPostConstruct("widgets/redux/craftingmenu_widget", function(self, ...)
            local oldOnControl = self.OnControl
            self.OnControl = function(self, control, down, ...)
                if control == CONTROL_SECONDARY and down and self.crafting_hud and self.crafting_hud:IsCraftingOpen() and
                    not TheInput:IsControlPressed(CONTROL_FORCE_INSPECT) and not TheInput:IsControlPressed(CONTROL_FORCE_STACK) and
                    not TheInput:IsControlPressed(CONTROL_FORCE_TRADE) and self.focus and self.enabled then
                    if self.recipe_grid and self.recipe_grid.shown and self.recipe_grid.focus then
                        local index = self.recipe_grid.focused_widget_index + self.recipe_grid.displayed_start_index
                        local items = self.recipe_grid.items
                        if index and items and items[index] then
                            local recipe = items[index].recipe
                            if recipe and (recipe.name or recipe.product) then
                                collectrecipeclientfn(self.owner or ThePlayer, recipe.product or recipe.name)
                            end
                        end
                    end
                end
                return oldOnControl(self, control, down, ...)
            end
            if self.recipe_grid and self.recipe_grid.update_fn then
                local oldfn = self.recipe_grid.update_fn
                self.recipe_grid.update_fn = function(context, widget, data, index, ...)
                    local recipe = data and data.recipe
                    if widget and widget.cell_root and recipe then
                        local name = ((recipe.nameoverride or recipe.name) and STRINGS.NAMES[string.upper(recipe.nameoverride or recipe.name)]) or
                            (recipe.product and STRINGS.NAMES[string.upper(recipe.product)])
                        widget.cell_root:SetTooltip((name or "") .. (name and "\n" or "") ..
                            (recipe.placer and "" or
                                (TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_SECONDARY) .. ": " ..
                                    (TUNING.isCh2hm and "收集" or "Collect"))))
                        SetButtonRightControl(widget.cell_root)
                    elseif widget and widget.cell_root then
                        widget.cell_root:SetTooltip(nil)
                    end
                    oldfn(context, widget, data, index, ...)
                end
            end
            if self.search_box and self.search_box.textbox then
                local oldOnControl = self.search_box.textbox.OnControl
                local rctrl = TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_SECONDARY)
                local tooltip = STRINGS.UI.SERVERCREATIONSCREEN.SEARCH ..
                    "  " .. rctrl .. ": " .. (TUNING.isCh2hm and "收集" or "Collect") .. "  Ctrl " ..
                    rctrl .. ": " .. (TUNING.isCh2hm and "模糊收集" or "Collect Maybe")
                self.search_box:SetHoverText(tooltip)
                self.search_box.textbox.OnControl = function(_self, control, down, ...)
                    if control == CONTROL_SECONDARY and down and self.crafting_hud and self.crafting_hud:IsCraftingOpen() and
                        not TheInput:IsControlPressed(CONTROL_FORCE_INSPECT) and not TheInput:IsControlPressed(CONTROL_FORCE_TRADE) and self.focus and
                        self.enabled and ThePlayer and ThePlayer.replica and ThePlayer.replica.inventory then
                        local name = self.search_box.textbox:GetString()
                        if name and name ~= "" and type(name) == "string" then
                            local maybe = TheInput:IsControlPressed(CONTROL_FORCE_STACK)
                            if ThePlayer.components.inventory ~= nil then
                                searchcollectfn(ThePlayer, name, maybe)
                                return
                            elseif ThePlayer.replica.inventory ~= nil and not ThePlayer:HasTag("playerghost") then
                                SendModRPCToServer(GetModRPC("MOD_HARDMODE", "searchcollect2hm"), name, maybe)
                                return
                            end
                        end
                    end
                    return oldOnControl(_self, control, down, ...)
                end
            end
        end)
    end
    -- ctrl alt右键道具快速收集道具
    if hasitemscollect then
        local collectaction = Action({})
        collectaction.priority = ACTIONS.LOOKAT.priority - 0.5
        collectaction.id = "COLLECT2HM"
        collectaction.str = TUNING.isCh2hm and "收集" or "Collect"
        collectaction.rmb = true
        collectaction.instant = true
        collectaction.mount_valid = true
        collectaction.fn = function(act)
            if not (act.invobject and act.invobject:IsValid() and act.invobject.prefab and act.invobject.components.inventoryitem and
                    act.invobject.components.inventoryitem.owner) then
                return
            end
            local owner = act.invobject.components.inventoryitem.owner
            if owner and owner:IsValid() and (owner.components.container or owner.components.inventory) then
                local neednum = 1
                if act.invobject.components.stackable then
                    local slotsize = act.invobject.components.stackable.originalmaxsize or
                        act.invobject.components.stackable.maxsize
                    if slotsize and act.invobject.components.stackable.stacksize < slotsize then
                        neednum = slotsize - act.invobject.components.stackable.stacksize
                    else
                        neednum = slotsize or 1
                    end
                end
                if owner.components.container and not owner.components.container.acceptsstacks then neednum = 1 end
                collectrecipefn(owner, act.invobject.prefab, neednum, act.doer, act.invobject)
                -- 实际可以反馈收集结果
                return true
            end
        end
        AddAction(collectaction)
    end
    -- 智能锅快捷收集及相关补丁
    if foodingredientcollectsupport then
        local foodaliases = {
            cookedsmallmeat = "smallmeat_cooked",
            cookedmonstermeat = "monstermeat_cooked",
            cookedmeat =
            "meat_cooked"
        }
        local function collectfoodingredientfn(doer, food, istag, neednum, toplayer, disabledatastr)
            if doer and doer:IsValid() and doer.components.inventory and not doer:HasTag("playerghost") and doer.components.inventory.isvisible then
                if toplayer then
                    if istag then
                        collectrecipefn(doer, food, nil, doer, nil, function(v)
                            local data = cooking.ingredients[foodaliases[v.prefab] or v.prefab]
                            return data ~= nil and data.tags[food] ~= nil and
                                (food == "monster" or data.tags.monster == nil)
                        end)
                    else
                        collectrecipefn(doer, food, nil, doer)
                    end
                    return
                end
                for container_inst in pairs(doer.components.inventory.opencontainers) do
                    if container_inst:IsValid() and container_inst:HasTag("stewer") then
                        if container_inst.components.container.acceptsstacks then
                            neednum = nil
                        else
                            neednum = 1
                        end
                        if istag then
                            local limittags = {}
                            local limitnames = {}
                            if disabledatastr and string.len(disabledatastr) > 0 then
                                local success, savedata = RunInSandboxSafe(disabledatastr)
                                if success and savedata ~= nil and not IsTableEmpty(savedata) then
                                    for index, element in pairs(savedata) do
                                        if element.name then
                                            limitnames[element.name] = (limitnames[element.name] or 0) +
                                                (element.amt or 0)
                                        elseif element.tag then
                                            limittags[element.tag] = (limittags[element.tag] or 0) + (element.amt or 0)
                                        end
                                    end
                                end
                            end
                            local mintag = 0
                            if neednum then
                                local leftslots = container_inst.components.container.numslots
                                for k, v in pairs(container_inst.components.container.slots) do
                                    if v and v:IsValid() and v.prefab then
                                        leftslots = leftslots - 1
                                        if limitnames[v.prefab] then limitnames[v.prefab] = limitnames[v.prefab] - 1 end
                                        local data = cooking.ingredients[foodaliases[v.prefab] or v.prefab]
                                        if data and data.tags then
                                            for tag, value in pairs(data.tags) do
                                                if limittags[tag] and value then
                                                    limittags[tag] = limittags[tag] - value
                                                end
                                            end
                                        end
                                    end
                                end
                                -- 剩余格子需要满足多少食物度，所以单个至少满足mintag,3.5/4
                                mintag = neednum / leftslots
                                -- 剩余格子需要低于多少怪物度，所以单个至少低于剩余怪物度
                            end
                            collectrecipefn(container_inst, food, neednum, doer, nil, function(v)
                                local data = cooking.ingredients[foodaliases[v.prefab] or v.prefab]
                                if data and data.tags and (mintag == 0 or data.tags[food] and data.tags[food] >= mintag) then
                                    if limitnames[v.prefab] and limitnames[v.prefab] < 1 then return end
                                    for tag, value in pairs(limittags) do
                                        if data.tags[tag] and value and data.tags[tag] > value then return end
                                    end
                                    return true
                                end
                            end)
                        else
                            collectrecipefn(container_inst, food, neednum, doer)
                        end
                        return
                    end
                end
            end
        end
        AddModRPCHandler("MOD_HARDMODE", "collectfoodingredient2hm", collectfoodingredientfn)
        local function collectfoodingredientclientfn(doer, food, istag, neednum, toplayer, disabledatastr)
            if not food or food == "" or type(food) ~= "string" then return end
            if doer.components.inventory ~= nil then
                collectfoodingredientfn(doer, food, istag, neednum, toplayer, disabledatastr)
            elseif doer.replica.inventory ~= nil and not doer:HasTag("playerghost") and doer == ThePlayer then
                SendModRPCToServer(GetModRPC("MOD_HARDMODE", "collectfoodingredient2hm"), food, istag, neednum, toplayer,
                    disabledatastr)
            end
        end
        -- is_min代表需要的素材,is_name代表需要指定食物还是指定属性食物,alias代表食物的名字或属性名字，quantity代表数目
        if isModuleAvailable("widgets/foodingredientui") then
            local function buildSequence(mix, arr)
                for cid, conj in ipairs(mix) do
                    if conj.amt then
                        table.insert(arr, conj)
                    else
                        buildSequence(conj, arr)
                    end
                end
                return arr
            end
            local function initdisabledata(self)
                if not self.is_name and not self.disabledata and self.parent and self.parent.parent and self.parent.parent.parent and
                    self.parent.parent.parent.recipe and self.parent.parent.parent.recipe.maxmix then
                    self.disabledata = buildSequence(self.parent.parent.parent.recipe.maxmix, {})
                end
            end
            local function refreshtooltip(self)
                self.imgbtn2hm:SetTooltip((self.localized_name or "") .. (self.localized_name and "\n" or "") ..
                    TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_PRIMARY) .. ": " ..
                    (self.quantity > self.on_hand and (TUNING.isCh2hm and "收集" or "Collect") or
                        (TUNING.isCh2hm and "填充" or "Filling")) .. "\n" ..
                    TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_SECONDARY) .. ": " ..
                    (TUNING.isCh2hm and "收集更多" or "Collect More"))
            end
            AddClassPostConstruct("widgets/foodingredientui", function(self, ...)
                if self.is_min and self.owner and self.prefab and self.is_name ~= nil and self.quantity and self.atlas and self.item_tex and self.img then
                    self.on_hand = 0
                    local Update = self.Update
                    self.Update = function(self, on_hand, ...)
                        self.on_hand = on_hand
                        Update(self, on_hand, ...)
                        refreshtooltip(self)
                    end
                    self.imgbtn2hm = self:AddChild(ImageButton(self.atlas, self.item_tex))
                    self.imgbtn2hm.image:Kill()
                    self.imgbtn2hm.image = self.img
                    self.imgbtn2hm:AddChild(self.img)
                    self.img:MoveToBack()
                    refreshtooltip(self)
                    self.imgbtn2hm:SetOnClick(function()
                        initdisabledata(self)
                        collectfoodingredientclientfn(self.owner, self.prefab, not self.is_name,
                            math.max(self.quantity - self.on_hand, 0), nil,
                            not self.is_name and self.disabledata and not IsTableEmpty(self.disabledata) and
                            DataDumper(self.disabledata, nil, true))
                    end)
                    self.imgbtn2hm.onrightclick2hm = function()
                        collectfoodingredientclientfn(self.owner, self.prefab, not self.is_name, nil, true)
                    end
                    SetButtonRightControl(self.imgbtn2hm)
                    self.imgbtn2hm.AllowOnControlWhenSelected = true
                    if self.quant then self.quant:MoveToFront() end
                end
            end)
        end
    end
    -- ctrl右键道具快速存放道具
    if hasitemsstore then
        local storeaction = Action({})
        storeaction.priority = ACTIONS.LOOKAT.priority - 0.5
        storeaction.id = "STORE2HM"
        storeaction.str = STRINGS.ACTIONS.STORE
        storeaction.rmb = true
        storeaction.instant = true
        storeaction.mount_valid = true
        local function openvirtchest(ent, inst)
            if ent.virtchest and ent.virtchest:IsValid() and ent.virtchest.components.container and ent.components.container.opencount == 0 then
                local self = ent.virtchest.components.container
                self.ignoreoverstacked = true
                ent.components.container.ignoresound = true
                for slot, _ in pairs(self.slots) do
                    local item = self:RemoveItemBySlot(slot)
                    if item ~= nil then ent.components.container:GiveItem(item, slot) end
                end
                ent.components.container.ignoresound = false
                self.ignoreoverstacked = false
            end
        end
        local function getperishablerate(owner, inst, self)
            local modifier = 1
            if owner.components.preserver ~= nil then
                modifier = owner.components.preserver:GetPerishRateMultiplier(inst) or modifier
            elseif owner:HasTag("fridge") then
                if inst:HasTag("frozen") and not owner:HasTag("nocool") and not owner:HasTag("lowcool") then
                    modifier = TUNING.PERISH_COLD_FROZEN_MULT
                else
                    modifier = TUNING.PERISH_FRIDGE_MULT
                end
            elseif owner:HasTag("foodpreserver") then
                modifier = TUNING.PERISH_FOOD_PRESERVER_MULT
            elseif owner:HasTag("cage") and inst:HasTag("small_livestock") then
                modifier = TUNING.PERISH_CAGE_MULT
            end
            if owner:HasTag("spoiler") then modifier = modifier * TUNING.PERISH_GROUND_MULT end
            return modifier * 1
        end
        local function processstoreincontainers(invobject, ents, proxyents, inst, src_pos, isstackable)
            -- 优先存放在当前打开的容器
            local toremove = {}
            -- for i, ent in ipairs(ents) do
            --     if inst.components.inventory.opencontainers[ent] then
            --         if ent.components.container:GiveItem(invobject, nil, src_pos, false) then
            --             delayshowmovefx(ent)
            --             return true
            --         else
            --             table.insert(toremove, i)
            --         end
            --     end
            -- end
            -- for _, i in ipairs(toremove) do table.remove(ents, i) end
            -- toremove = {}
            -- 优先存放在锁定存放此道具或已有此道具的容器(后者中,全图唯一容器更加优先)
            if haslockbutton then
                for i, ent in ipairs(ents) do
                    if ent.components.container.itemtestfnprefabs2hm ~= nil then
                        openvirtchest(ent, inst)
                        if ent.components.container:GiveItem(invobject, nil, src_pos, false) then
                            delayshowmovefx(ent)
							if danger and inst and inst:IsValid() and inst.components.hunger then inst.components.hunger:DoDelta(-0.2) end
                            return true
                        else
                            table.insert(toremove, i)
                        end
                    end
                end
                for _, i in ipairs(toremove) do table.remove(ents, i) end
                toremove = {}
            end
            for master, v in pairs(proxyents) do
                local hasitem, oldnum = master.components.container:Has(invobject.prefab, 1)
                if hasitem then
                    openvirtchest(master, inst)
                    if master.components.container:GiveItem(invobject, nil, src_pos, false) then
                        delayshowmovefx(v)
						if danger and inst and inst:IsValid() and inst.components.hunger then inst.components.hunger:DoDelta(-0.2) end
                        return true
                    elseif invobject and invobject:IsValid() then
                        local nowhas, newnum = master.components.container:Has(invobject.prefab, 1)
                        if newnum > oldnum then delayshowmovefx(v) end
                    end
                end
            end
            for i, ent in ipairs(ents) do
                local oldhas, oldnum = ent.components.container:Has(invobject.prefab, 1)
                if not oldhas and ent.virtchest and ent.virtchest:IsValid() and ent.virtchest.components.container then
                    local virthas, virtnum = ent.virtchest.components.container:Has(invobject.prefab, 1)
                    oldhas = virthas
                    oldnum = oldnum + virtnum
                end
                if oldhas then
                    openvirtchest(ent, inst)
                    if isstackable then
                        if ent.components.container:GiveItem(invobject, nil, src_pos, false) then
							if danger and inst and inst:IsValid() and inst.components.hunger then inst.components.hunger:DoDelta(-0.2) end
                            delayshowmovefx(ent)
                            return true
                        else
                            if invobject and invobject:IsValid() then
                                local newhas, newnum = ent.components.container:Has(invobject.prefab, 1)
                                if newnum > oldnum then delayshowmovefx(ent) end
                            end
                        end
                    elseif ent.components.container:GiveItem(invobject, nil, src_pos, false) then
						if danger and inst and inst:IsValid() and inst.components.hunger then inst.components.hunger:DoDelta(-0.2) end
                        delayshowmovefx(ent)
                        return true
                    end
                    table.insert(toremove, i)
                end
            end
            for _, i in ipairs(toremove) do table.remove(ents, i) end
            -- 其次，优先存放在有存放道具限制的容器（某些道具特殊处理）
            -- 暖石特殊处理，非夏天优先存放在冰箱，夏天额根据优先级优先存放在龙鳞火炉
            if invobject:HasTag("heatrock") and not TheWorld.state.issummer then
                toremove = {}
                for i, ent in ipairs(ents) do
                    if ent:HasTag("fridge") and not ent:HasTag("nocool") then
                        openvirtchest(ent, inst)
                        if ent.components.container:GiveItem(invobject, nil, src_pos, false) then
							if danger and inst and inst:IsValid() and inst.components.hunger then inst.components.hunger:DoDelta(-0.2) end
                            delayshowmovefx(ent)
                            return true
                        else
                            table.insert(toremove, i)
                        end
                    end
                end
                for _, i in ipairs(toremove) do table.remove(ents, i) end
            end
            -- 有新鲜度的道具特殊处理
            local tmpentsindex = {}
            local itemtestfnents = {}
            local rates
            local perishable = invobject.components.perishable
            local hasprioritystoreents
            if perishable ~= nil then
                -- 按保鲜能力排序，其次按唯一容器/限制容器/普通容器进行排序
                rates = {}
                local totalproxyents = GetTableSize(proxyents)
                local totalents = totalproxyents + #ents
                local j = 0
                for master, v in pairs(proxyents) do
                    local rate = getperishablerate(master, invobject, perishable)
                    if rate < 1 then
                        rates[master] = rate
                        table.insert(itemtestfnents, master)
                        j = j + 1
                        tmpentsindex[master] = j
                    end
                end
                for i, ent in ipairs(ents) do
                    table.insert(itemtestfnents, ent)
                    local rate = getperishablerate(ent, invobject, perishable)
                    if rate < 1 then rates[ent] = rate end
                    if ent.components.container.itemtestfn ~= nil then
                        tmpentsindex[ent] = i + totalproxyents
                    else
                        tmpentsindex[ent] = i + totalents
                    end
                end
            else
                -- 无新鲜度的道具
                for i, ent in ipairs(ents) do
                    if ent.components.container.itemtestfn ~= nil then
                        table.insert(itemtestfnents, ent)
                        tmpentsindex[ent] = i
                        if not hasprioritystoreents and prioritystoreents[ent.prefab] then hasprioritystoreents = true end
                    end
                end
            end
            if not IsTableEmpty(itemtestfnents) then
                if perishable ~= nil or hasprioritystoreents then
                    table.sort(itemtestfnents, function(a, b)
                        if not (a and b and a.prefab and b.prefab and tmpentsindex[a] and tmpentsindex[b]) then return false end
                        -- 先按指定的优先级容器存放
                        local aidx = prioritystoreents[a.prefab]
                        local bidx = prioritystoreents[b.prefab]
                        if aidx or bidx then
                            if aidx and bidx then
                                if aidx == bidx then return tmpentsindex[a] < tmpentsindex[b] end
                                return aidx < bidx
                            end
                            return aidx ~= nil
                        end
                        if perishable ~= nil then
                            -- 有新鲜度的道具再按保鲜程度存放
                            local arate = rates[a]
                            local brate = rates[b]
                            if arate or brate then
                                if arate and brate then
                                    if arate == brate then return tmpentsindex[a] < tmpentsindex[b] end
                                    return arate < brate
                                end
                                return arate ~= nil
                            end
                        end
                        -- 最后默认排放
                        return tmpentsindex[a] < tmpentsindex[b]
                    end)
                end
                for _, ent in ipairs(itemtestfnents) do
                    openvirtchest(ent, inst)
                    if ent.components.container:GiveItem(invobject, nil, src_pos, false) then
						if danger and inst and inst:IsValid() and inst.components.hunger then inst.components.hunger:DoDelta(-0.2) end
                        delayshowmovefx(ent.currentpocket2hm or ent)
                        return true
                    end
                end
            end
            -- 最后，存放在普通容器
            if perishable == nil then
                for _, ent in ipairs(ents) do
                    if ent.components.container.itemtestfn == nil then
                        openvirtchest(ent, inst)
                        if ent.components.container:GiveItem(invobject, nil, src_pos, false) then
							if danger and inst and inst:IsValid() and inst.components.hunger then inst.components.hunger:DoDelta(-0.2) end
                            delayshowmovefx(ent)
                            return true
                        end
                    end
                end
            end
        end
        storeaction.fn = function(act)
            local inst = act and act.doer
            if not (inst and act.invobject and act.invobject:IsValid() and act.invobject.components.inventoryitem and inst.components.inventory and
                    inst.components.inventory.opencontainers) then
                return
            end
            local owner = act.invobject.components.inventoryitem.owner
            local prevcontainer = owner and (owner.components.container or owner.components.inventory)
            if not prevcontainer then return end
            -- 记录要存放道具的目的容器列表
            local isstackable = act.invobject.components.stackable ~= nil
            local isbigsize = isstackable and
                (act.invobject.components.stackable.stacksize >
                    (act.invobject.components.stackable.originalmaxsize or act.invobject.components.stackable.maxsize))
            local src_pos = inst:GetPosition()
            local ents = {}
            local proxyents = {}
            if inst.components.rider and inst.components.rider.mount and inst.components.rider.mount:IsValid() and
                inst.components.rider.mount.components.container and inst.components.rider.mount ~= owner and
                inst.components.rider.mount.components.container.canbeopened then
                table.insert(ents, inst.components.rider.mount)
            end
            local x, y, z = inst.Transform:GetWorldPosition()
            local platform = inst:GetCurrentPlatform()
            local nearents = TheSim:FindEntities(x, y, z, 30, nil, GROUND_CONTAINER_CANT_TAGS)
            for i, v in ipairs(nearents) do
                if v:IsValid() and v ~= owner then
                    if v.components.container_proxy and isstackable and not v.dcs2hm and v.components.container_proxy:CanBeOpened() and
                        not v.components.container and not v.components.locomotor and not table.contains(storeblacklist, v.prefab) and
                        (conditionstorelist[v.prefab] == nil or conditionstorelist[v.prefab](act.invobject)) and v:GetCurrentPlatform() == platform then
                        local master = v.components.container_proxy.master
                        if master and master:IsValid() and master ~= owner and not proxyents[master] and master.components.container and
                            master.components.container.canbeopened and not master.components.container.usespecificslotsforitems and
                            master.components.container.acceptsstacks and (not isbigsize or master.components.container.infinitestacksize) and
                            master.components.container:CanTakeItemInSlot(act.invobject) then
                            proxyents[master] = v
                            master.currentpocket2hm = v
                        end
                    elseif v.components.container and not v.dcs2hm and (table.contains(storewhitelist, v.prefab) or
                            ((isstackable or not v.components.container.infinitestacksize) and (not isbigsize or v.components.container.infinitestacksize) and
                                (not v.components.inventoryitem or v:HasTag("heavy")) and not v.components.health and not v.components.locomotor and
                                not v.components.stewer and v.components.container.canbeopened and not v.components.container.usespecificslotsforitems and
                                v.components.container.acceptsstacks and not table.contains(storeblacklist, v.prefab) and
                                (conditionstorelist[v.prefab] == nil and v.components.container.type == "chest" and v.components.container.numslots >= 9 or
                                    (conditionstorelist[v.prefab] and conditionstorelist[v.prefab](act.invobject))))) and v:GetCurrentPlatform() == platform and
                        v.components.container:CanTakeItemInSlot(act.invobject) then
                        table.insert(ents, v)
                    end
                end
            end
            if IsTableEmpty(ents) and IsTableEmpty(proxyents) then return end
            local prevslot = act.invobject.components.inventoryitem:GetSlotNum()
            -- 进行存放道具操作
            act.invobject.components.inventoryitem:RemoveFromOwner(true)
            act.invobject.prevplayer2hm = inst
            local result = processstoreincontainers(act.invobject, ents, proxyents, inst, src_pos, isstackable)
            -- 存放完成数据修正,和失败检查
            if act.invobject:IsValid() then
                act.invobject.prevplayer2hm = nil
                if act.invobject.components.inventoryitem.owner == nil then
                    prevcontainer:GiveItem(act.invobject,
                        prevslot)
                end
            end
            return result
        end
        AddAction(storeaction)
    end
    if hasitemscollect or hasitemsstore then
        local function itemcheckfn(inst, doer, actions)
            if inst.prefab and not inst:HasTag("dcs2hm") and not inst.dcs2hm and not table.contains(itemsblacklist, inst.prefab) and inst.replica.inventoryitem ~=
                nil and not inst.replica.inventoryitem:CanOnlyGoInPocket() and doer and
                not (doer.replica.inventory and doer.replica.inventory:GetActiveItem() == inst) and
                not (inst.replica.equippable and inst.replica.equippable:IsEquipped()) then
                if hasitemscollect then table.insert(actions, ACTIONS.COLLECT2HM) end
                if hasitemsstore then table.insert(actions, ACTIONS.STORE2HM) end
            end
        end
        if TUNING.INVENTORYFNS2HM ~= nil then
            table.insert(TUNING.INVENTORYFNS2HM, itemcheckfn)
        else
            AddComponentAction("INVENTORY", "inventoryitem", itemcheckfn)
        end
        AddComponentPostInit("playeractionpicker", function(self)
            local oldGetInventoryActions = self.GetInventoryActions
            self.GetInventoryActions = function(self, ...)
                if self.inst and self.inst.components.playercontroller and self.inst.components.playercontroller:IsControlPressed(CONTROL_FORCE_STACK) then
                    if self.inst.components.playercontroller:IsControlPressed(CONTROL_FORCE_INSPECT) then
                        if hasitemscollect then ACTIONS.COLLECT2HM.priority = 11 end
                    elseif hasitemsstore then
                        ACTIONS.STORE2HM.priority = 11
                    end
                end
                local res = oldGetInventoryActions(self, ...)
                if hasitemscollect and ACTIONS.COLLECT2HM.priority == 11 then
                    ACTIONS.COLLECT2HM.priority = ACTIONS
                        .LOOKAT.priority - 0.5
                end
                if hasitemsstore and ACTIONS.STORE2HM.priority == 11 then
                    ACTIONS.STORE2HM.priority = ACTIONS.LOOKAT
                        .priority - 0.5
                end
                return res
            end
        end)
    end
end

-- 智能小木牌模组补丁
AddPrefabPostInit("world", function()
    if TUNING.SMART_SIGN_DRAW_ENABLE then
        local function refreshcontainerminisign(inst)
            if inst.components.smart_minisign then
                inst.components
                    .smart_minisign:OnClose()
            end
        end
        AddComponentPostInit("container", function(self)
            -- 2025.11.8 夜风，跳过WX-78特殊容器，避免干扰
            if self.inst:HasTag("wx78_special_container") then return end
            
            self.inst:DoTaskInTime(0.5, function()
                if self.inst.components.smart_minisign then
                    self.inst:ListenForEvent("itemget", refreshcontainerminisign)
                    self.inst:ListenForEvent("itemlose", refreshcontainerminisign)
                end
            end)
        end)
    end
end)

-- 智能锅补丁,智能锅可以锁定指定食谱
if isModuleAvailable("widgets/foodcrafting") then
    AddClassPostConstruct("widgets/foodcrafting", function(self, ...)
        local SortFoods = self.SortFoods
        self.SortFoods = function(self, ...)
            local recipe
            if self.focusItem and self.focusItem.focus then recipe = self.focusItem.recipe end
            SortFoods(self, ...)
            if recipe and self.focusIdx and self.idx and self.selfoods and self.num_slots and self._overflow then
                for index, tmpfood in ipairs(self.selfoods) do
                    if tmpfood and tmpfood.recipe == recipe then
                        self.idx = index - self.focusIdx
                        if self.idx > #self.selfoods - (self.num_slots) + self._overflow then
                            self.idx = #self.selfoods - (self.num_slots) + self._overflow
                        end
                        if self.idx < -self._overflow then self.idx = -self._overflow end
                        self.focusIdx = index - self.idx
                        self:UpdateFoodSlots()
                        return
                    end
                end
            end
        end
    end)
end

-- 容器存取轨迹补丁
local clientitemtransferimage2hmdist = 36 * 36
local function clientitemtransferimage2hm(img, atlas, x, y, z, prevcontainer, prevslot, _x, _y, _z, currcontainer,
                                          currslot, userid, iscollectact)
    if img and atlas and x and y and z and -x and _y and _z and userid and ThePlayer and ThePlayer.userid and ThePlayer.HUD and TheFrontEnd and ThePlayer.HUD ==
        TheFrontEnd:GetActiveScreen() and ThePlayer.HUD.controls and ThePlayer.HUD.controls.inv and ThePlayer.HUD.controls.containers then
        local controls = ThePlayer.HUD.controls
        -- 自己取出道具,官方已有路径
        -- 自己存放道具,未存放到己已打开容器时,需要添加路径,已添加
        -- 他人取出道具,未从其已打开容器取出时,需要添加路径,已添加
        -- 他人存放道具,未存放到其已打开容器时,需要添加路径,已添加
        local isself = userid == ThePlayer.userid
        local toopen
        local destpos
        if currcontainer then
            if isself and currcontainer == userid then
                toopen = true
                if currslot and controls.inv.inv and controls.inv.inv[currslot] then
                    destpos = controls.inv.inv
                        [currslot]:GetWorldPosition()
                end
            elseif isself and controls.inv.backpack and controls.inv.backpack:IsValid() and controls.inv.backpack:HasTag(currcontainer) then
                toopen = true
                if currslot and controls.inv.backpackinv and controls.inv.backpackinv[currslot] then
                    destpos = controls.inv.backpackinv[currslot]:GetWorldPosition()
                end
            else
                for container, containerwidget in pairs(controls.containers) do
                    if container and container:IsValid() and container:HasTag(currcontainer) then
                        toopen = true
                        if containerwidget and containerwidget.inv and containerwidget.inv[currslot] then
                            destpos = containerwidget.inv[currslot]:GetWorldPosition()
                        end
                        break
                    end
                end
            end
        end
        -- toopen说明已存在官方路径
        if toopen then return end
        local fromopen
        local startpos
        if prevcontainer then
            if isself and prevcontainer == userid then
                fromopen = true
                if prevslot and controls.inv.inv and controls.inv.inv[prevslot] then
                    startpos = controls.inv.inv
                        [prevslot]:GetWorldPosition()
                end
            elseif isself and controls.inv.backpack and controls.inv.backpack:IsValid() and controls.inv.backpack:HasTag(prevcontainer) then
                fromopen = true
                if prevslot and controls.inv.backpackinv and controls.inv.backpackinv[prevslot] then
                    startpos = controls.inv.backpackinv[prevslot]:GetWorldPosition()
                end
            else
                for container, containerwidget in pairs(controls.containers) do
                    if container and container:IsValid() and container:HasTag(prevcontainer) then
                        fromopen = true
                        if containerwidget and containerwidget.inv and containerwidget.inv[prevslot] then
                            startpos = containerwidget.inv[prevslot]:GetWorldPosition()
                        end
                        break
                    end
                end
            end
        end
        startpos = startpos or Vector3(TheSim:GetScreenPos(x, y, z))
        destpos = destpos or Vector3(TheSim:GetScreenPos(_x, _y, _z))
        local im = Image(atlas, img)
        im:MoveTo(startpos, destpos, .3, function() im:Kill() end)
    end
end
AddClientModRPCHandler("MOD_HARDMODE", "itemtransferimage2hm", clientitemtransferimage2hm)
local function cancelitemtransferimagetask2hm(inst) inst.itemtransferimagetask2hm = nil end
local function canceldisablefxtask2hm(inst) inst.disablecsfxtask2hm = nil end
local function onitemget(inst, data)
    -- inst是目的容器,src是来源容器,仅在快捷存取时额外显示路径
    if not POPULATING and data and data.src_pos and data.item and data.item:IsValid() and data.item.replica and data.item.replica.inventoryitem and
        (data.item.prevplayer2hm or data.item.currplayer2hm) and not inst.itemtransferimagetask2hm then
        -- 同一容器同时进行多次存放,说明是拆分存放,只需要显示第一次存放的路径
        inst.itemtransferimagetask2hm = inst:DoTaskInTime(0, cancelitemtransferimagetask2hm)
        local actplayer = data.item.prevplayer2hm or data.item.currplayer2hm
        if not (actplayer:IsValid() and actplayer.userid) then return end
        local src = data.item.prevcontainer and data.item.prevcontainer.inst or data.item.prevplayer2hm
        if not src then return end -- 理论上不可能出现src为空的情况
        local iscollectact = data.item.currplayer2hm ~= nil
        local atlas = data.item.replica.inventoryitem:GetAtlas()
        local img = data.item.replica.inventoryitem:GetImage()
        if not (img and atlas) then return end
        local x, y, z = data.src_pos:Get()
        if x == 0 and z == 0 then
            local prevfinalowner = getfinalowner(src)
            if prevfinalowner.currentpocket2hm and prevfinalowner.currentpocket2hm:IsValid() and prevfinalowner:HasTag("pocketdimension_container") then
                prevfinalowner = prevfinalowner.currentpocket2hm
            end
            x, y, z = prevfinalowner.Transform:GetWorldPosition()
        end
        local _x, _y, _z = inst.Transform:GetWorldPosition()
        if _x == 0 and _z == 0 then
            local currfinalowner = getfinalowner(inst)
            if currfinalowner.currentpocket2hm and currfinalowner.currentpocket2hm:IsValid() and currfinalowner:HasTag("pocketdimension_container") then
                currfinalowner = currfinalowner.currentpocket2hm
            end
            _x, _y, _z = currfinalowner.Transform:GetWorldPosition()
        end
        -- 来源容器ID,目标容器ID,取放操作的玩家ID
        local prevcontainer = src.userid or src.GUID
        local currcontainer = inst.userid or inst.GUID
        local userid = actplayer.userid
        if img and atlas and x and y and z and -x and _y and _z and userid then
            local rpc = GetClientModRPC("MOD_HARDMODE", "itemtransferimage2hm")
            -- 尝试通知符合条件的所有玩家显示该路径
            for index, player in ipairs(AllPlayers) do
                if player and player:IsValid() and player.userid then
                    local isself = player.userid == userid
                    -- 进行快捷取出操作的玩家不需要显示该路径
                    -- 已打开目的容器的玩家不需要显示该路径
                    -- 一定距离外的他人不需要显示该路径
                    if not (iscollectact and isself) and not (inst.components.container and inst.components.container.openlist[player]) and
                        (isself or player:GetDistanceSqToPoint(x, y, z) < clientitemtransferimage2hmdist or player:GetDistanceSqToPoint(_x, _y, _z) <
                            clientitemtransferimage2hmdist) then
                        -- 客户端玩家不需要发rpc
                        if isclient and ThePlayer == player then
                            clientitemtransferimage2hm(img, atlas, x, y, z, prevcontainer, data.item.prevslot, _x, _y, _z,
                                currcontainer, data and data.slot,
                                userid, iscollectact)
                        else
                            SendModRPCToClient(rpc, player.userid, img, atlas, x, y, z, prevcontainer, data.item
                                .prevslot, _x, _y, _z, currcontainer,
                                data and data.slot, userid, iscollectact)
                        end
                    end
                end
            end
        end
    end
end
-- 每个容器都加了一个自己的GUID标签,以方便本模组找到服务器容器对应的客户端容器;道具存放信号
AddComponentPostInit("container", function(self)
    -- 2025.11.8 夜风，跳过WX-78特殊容器，避免干扰
    if self.inst:HasTag("wx78_special_container") then return end
    
    if not self.inst.ctfi2hm and self.inst.GUID then
        self.inst.ctfi2hm = true
        self.inst:AddTag(self.inst.GUID)
        self.inst:ListenForEvent("itemget", onitemget)
    end
end)
AddComponentPostInit("inventory",
    function(self) if self.inst:HasTag("player") then self.inst:ListenForEvent("itemget", onitemget) end end)
AddComponentPostInit("stackable", function(self)
    local Put = self.Put
    self.Put = function(self, item, src_pos, ...)
        if item ~= self and src_pos and self.inst and self.inst.components.inventoryitem and self.inst.components.inventoryitem.owner then
            onitemget(self.inst.components.inventoryitem.owner, { item = item, src_pos = src_pos })
        end
        return Put(self, item, src_pos, ...)
    end
end)

if hascollectbutton or hassortbutton then
    -- 检测是否手持懒人护符
    local function IsHoldingOrangeAmulet(player)
        if not player.components.inventory then return false end
        local activeitem = player.components.inventory.activeitem
        if activeitem and activeitem.prefab == "orangeamulet" and activeitem:IsValid() and
            ((activeitem.components.finiteuses and activeitem.components.finiteuses.current > 1) or
             (activeitem.components.fueled and activeitem.components.fueled.currentfuel > 1)) then
            return true
        end
        return false
    end

    -- 服务器端RPC处理
    AddModRPCHandler("MOD_HARDMODE", "orangeamuletsort2hm", function(player)
        if not (player and player:IsValid()) then return end
        if hassortbutton and IsHoldingOrangeAmulet(player) then
            dosort(player)
        end
    end)
    
    AddModRPCHandler("MOD_HARDMODE", "orangeamuletcollect2hm", function(player)
        if not (player and player:IsValid()) then return end
        if hascollectbutton and IsHoldingOrangeAmulet(player) then
            if not player.collectloadingtask2hm then
                -- 先收集到玩家物品栏
                dopickup(player, player)
                -- 再收集到背包（如果装备了背包）
                if player.components.inventory then
                    local overflow = player.components.inventory:GetOverflowContainer()
                    if overflow and overflow.inst and overflow.inst:IsValid() and overflow.inst.components.container then
                        dopickup(overflow.inst, player)
                    end
                end
            end
        end
    end)
    
    -- 客户端RPC发送
    if isclient then
        -- 监听输入事件来检测Ctrl+点击
        local function CheckOrangeAmuletControl(player, control)
            if not (player and player:IsValid() and player.replica.inventory) then return false end
            local activeitem = player.replica.inventory:GetActiveItem()
            if not (activeitem and activeitem.prefab == "orangeamulet") then return false end
            
            -- 检测Ctrl键 (CONTROL_FORCE_STACK)
            if TheInput:IsControlPressed(CONTROL_FORCE_STACK) then
                if control == CONTROL_PRIMARY and hascollectbutton then
                    -- Ctrl+左键 = 收集
                    SendModRPCToServer(GetModRPC("MOD_HARDMODE", "orangeamuletcollect2hm"))
                    return true
                elseif control == CONTROL_SECONDARY and hassortbutton then
                    -- Ctrl+右键 = 整理
                    SendModRPCToServer(GetModRPC("MOD_HARDMODE", "orangeamuletsort2hm"))
                    return true
                end
            end
            return false
        end
        
        -- 修改玩家控制器的输入处理
        AddClassPostConstruct("components/playercontroller", function(self)
            local oldOnControl = self.OnControl
            self.OnControl = function(self, control, down, ...)
                if down and self.inst == ThePlayer then
                    if CheckOrangeAmuletControl(self.inst, control) then
                        return true
                    end
                end
                return oldOnControl and oldOnControl(self, control, down, ...)
            end
        end)
    end
end
