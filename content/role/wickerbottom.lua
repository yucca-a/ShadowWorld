-- 薇克巴顿能力削弱，书柜回复耐久速度变慢，书籍耐久削弱
local TechTree = require("techtree")

TUNING.BOOK_USES_SMALL = 1.01
TUNING.BOOK_USES_LARGE = 1.67
TUNING.BOOKSTATION_RESTORE_TIME = TUNING.BOOKSTATION_RESTORE_TIME * 8

AddRecipePostInit("bookstation", function(inst)
    inst.builder_tag = nil
    inst.level = TechTree.Create(TECH.SCIENCE_ONE)
end)

-- 雷书(末日将至/book_brimstone)加强:闪电优先电boss和怪物(类似伏特山羊按_combat索敌),伤害大幅提升(原版每道LIGHTNING_DAMAGE=10)
local LIGHTNING_BOOK_DAMAGE_2HM = 100 -- 每道闪电对目标额外伤害
local LIGHTNING_BOOK_STUN_CD_2HM = 1.5 -- 电击硬直内置CD(秒):同一目标CD内再被电不掉硬直但照常掉血,防止连续雷书把Boss电到动不了
-- 雷书配方增加1个福特羊角(伏特山羊角),原配方:纸2+红宝石1
AddRecipePostInit("book_brimstone", function(recipe)
    table.insert(recipe.ingredients, Ingredient("lightninggoathorn", 1))
end)
local LIGHTNING_BOOK_CANT_TAGS = {"player", "playerghost", "structure", "wall", "INLIMBO", "FX", "NOCLICK", "abigail", "chester", "bernie_active", "pet_hound"}

local function IsStunReady(target)
    local last = target._book_brimstone_stun_time_2hm
    return last == nil or GetTime() - last >= LIGHTNING_BOOK_STUN_CD_2HM
end
AddPrefabPostInit("book_brimstone", function(inst)
    if not TheWorld.ismastersim then return end
    -- 雷书耐久:总耐久0.5833(=0.35/0.6),配合"读书更少耐久"机制(理智满时最低消耗0.35点)正好一次掉60%
    if inst.components.finiteuses then
        inst.components.finiteuses:SetMaxUses(0.5833)
        inst.components.finiteuses:SetUses(0.5833)
    end
    local book = inst.components.book
    if not book or not book.onread then return end
    local oldonread = book.onread
    book.onread = function(inst, reader)
        if not reader then return true end
        local pt = reader:GetPosition()
        local num_lightnings = 16
        reader:StartThread(function()
            for k = 0, num_lightnings do
                if reader and reader:IsValid() then
                    -- 索敌优先级:epic(boss)>monster(怪物)>其他战斗生物,排除玩家/结构/宠物
                    local ents = TheSim:FindEntities(pt.x, pt.y, pt.z, 20, {"_combat", "epic"}, LIGHTNING_BOOK_CANT_TAGS)
                    if #ents == 0 then
                        ents = TheSim:FindEntities(pt.x, pt.y, pt.z, 20, {"_combat", "monster"}, LIGHTNING_BOOK_CANT_TAGS)
                    end
                    if #ents == 0 then
                        ents = TheSim:FindEntities(pt.x, pt.y, pt.z, 20, {"_combat"}, LIGHTNING_BOOK_CANT_TAGS)
                    end
                    local target = #ents > 0 and ents[math.random(#ents)] or nil
                    if target and target:IsValid() and target.components.health and not target.components.health:IsDead() then
                        if IsStunReady(target) then
                            -- 硬直窗口:落雷直接劈目标(原版电击硬直)+GetAttacked_Internal(受击硬直+仇恨),并记录CD
                            target._book_brimstone_stun_time_2hm = GetTime()
                            TheWorld:PushEvent("ms_sendlightningstrike", target:GetPosition())
                            if target.components.combat then
                                target.components.combat:GetAttacked_Internal(reader, LIGHTNING_BOOK_DAMAGE_2HM)
                            else
                                target.components.health:DoDelta(-LIGHTNING_BOOK_DAMAGE_2HM, nil, "book_brimstone", nil, reader)
                            end
                        else
                            -- CD内:落雷偏移到目标旁边4格>落雷3格，削弱下
                            local ang = math.random() * TWOPI
                            local off = Vector3(4 * math.cos(ang), 0, 4 * math.sin(ang))
                            TheWorld:PushEvent("ms_sendlightningstrike", target:GetPosition() + off)
                            target.components.health:DoDelta(-LIGHTNING_BOOK_DAMAGE_2HM, nil, "book_brimstone", nil, reader)
                        end
                    else
                        -- 无目标:原版螺旋落雷
                        local rad = math.random(3, 15)
                        local angle = k * 4 * PI / num_lightnings
                        local pos = pt + Vector3(rad * math.cos(angle), 0, rad * math.sin(angle))
                        TheWorld:PushEvent("ms_sendlightningstrike", pos)
                    end
                end
                Sleep(.3 + math.random() * .2)
            end
        end)
        return true
    end
end)

if GetModConfigData("wickerbottom") ~= -1 then
    local plant_change = GetModConfigData("plant_change")
    local plantchangeIndex = (plant_change == -1 or plant_change == true) and 3 or plant_change
    if plant_change == false then plantchangeIndex = 3 end
    local animal_change = GetModConfigData("animal_change")
    local animalchangeIndex = (animal_change == -1 or animal_change == true) and 3 or animal_change
    if animal_change == false then animalchangeIndex = 2 end
    -- 地域魔力
    local locationbooks = {
        -- default_data
        -- global = false
        -- range = 256 fxscale = 4
        book_birds = {date = 2 * animalchangeIndex},
        book_gardening = {date = 3 * plantchangeIndex, range = 900, fxscale = 7.5},
        book_horticulture = {date = 2 * plantchangeIndex, same = "book_horticulture_upgraded", range = 900, fxscale = 7.5},
        book_horticulture_upgraded = {date = 3 * plantchangeIndex, same = "book_horticulture", range = 900, fxscale = 7.5},
        book_silviculture = {date = 3 * plantchangeIndex, range = 900, fxscale = 7.5},
        book_sleep = {date = 2, range = 36, fxscale = 1.5},
        book_brimstone = {date = 1},
        book_tentacles = {date = 2 * animalchangeIndex},
        book_fish = {date = 2 * animalchangeIndex},
        book_web = {date = 2},
        book_temperature = {date = 1, range = 36, fxscale = 1.5},
        book_light = {date = 1, same = "book_light_upgraded"},
        book_light_upgraded = {date = 2, same = "book_light"},
        book_moon = {date = 7, global = true},
        book_rain = {date = 1, global = true},
        book_bees = {date = 2 * animalchangeIndex},
        book_research_station = {date = 1, range = 36, fxscale = 1.5},
        -- 2025.9.25 melon:勋章植物图鉴禁魔  2025.10.4 去掉
        -- medal_plant_book = {date = 3 * plantchangeIndex, range = 50, fxscale = 2},
    }
    local errortext = TUNING.isCh2hm and "此处魔力不太充足了,还需要" or "The place has not enough magiciness and need "
    local errortext2 = TUNING.isCh2hm and "天恢复" or " days to cooldown."
    local function talkerror(inst, cd) if inst.components.talker then inst.components.talker:Say(errortext .. (cd or "1") .. errortext2) end end
    local fxlist = {}
    for book, value in pairs(locationbooks) do fxlist[book] = {} end
    AddComponentPostInit("book", function(self)
        local Interact = self.Interact
        self.Interact = function(self, fn, reader, ...)
            local bookdata
            local currentpos
            local maxcd = 1
            if locationbooks[self.inst.prefab] and reader and reader:IsValid() and TheWorld.components.persistent2hm then
                if not TheWorld.components.persistent2hm.data.booklocations then TheWorld.components.persistent2hm.data.booklocations = {} end
                if not TheWorld.components.persistent2hm.data.booklocations[self.inst.prefab] then
                    TheWorld.components.persistent2hm.data.booklocations[self.inst.prefab] = {}
                end
                for book, list in pairs(fxlist) do
                    if book ~= self.inst.prefab and book ~= locationbooks[self.inst.prefab].same and list and list[reader.userid] then
                        for i = #list[reader.userid], 1, -1 do
                            local fx = list[reader.userid][i]
                            if fx and fx:IsValid() then fx:Remove() end
                        end
                        list[reader.userid] = {}
                    end
                end
                bookdata = TheWorld.components.persistent2hm.data.booklocations[self.inst.prefab]
                if bookdata then
                    local x, _, z = reader.Transform:GetWorldPosition()
                    currentpos = {x = x, z = z, cycles = TheWorld.state.cycles}
                    local result = true
                    for i = #bookdata, 1, -1 do
                        local pos = bookdata[i]
                        if TheWorld.state.cycles - pos.cycles >= (locationbooks[self.inst.prefab].date or 3) then
                            table.remove(bookdata, i)
                        elseif reader.prefab == "wickerbottom" and TheWorld.state.cycles - pos.cycles >= (locationbooks[self.inst.prefab].date or 3) - 1 then
                            table.remove(bookdata, i)
                        elseif locationbooks[self.inst.prefab].global then
                            maxcd = math.max((locationbooks[self.inst.prefab].date or 3) - TheWorld.state.cycles + pos.cycles, maxcd)
                            reader:DoTaskInTime(0, talkerror, maxcd)
                            return false, "LOCATIONLOCK2HM"
                        elseif distsq(x, z, pos.x, pos.z) < (locationbooks[self.inst.prefab].range or 256) then
                            local fx = SpawnPrefab("reticuleaoeshadowtarget_6")
                            fx.Transform:SetPosition(pos.x, 0, pos.z)
                            local scale = locationbooks[self.inst.prefab].fxscale or 4
                            fx.AnimState:SetScale(scale, scale, scale)
                            fx:DoTaskInTime(60, fx.Remove)
                            fxlist[self.inst.prefab][reader.userid] = fxlist[self.inst.prefab][reader.userid] or {}
                            table.insert(fxlist[self.inst.prefab][reader.userid], fx)
                            result = false
                            maxcd = math.max((locationbooks[self.inst.prefab].date or 3) - TheWorld.state.cycles + pos.cycles, maxcd)
                        end
                    end
                    if locationbooks[self.inst.prefab].same then
                        local prefab = locationbooks[self.inst.prefab].same
                        if not TheWorld.components.persistent2hm.data.booklocations[prefab] then
                            TheWorld.components.persistent2hm.data.booklocations[prefab] = {}
                        end
                        local elsebookdata = TheWorld.components.persistent2hm.data.booklocations[prefab]
                        if elsebookdata then
                            for i = #elsebookdata, 1, -1 do
                                local pos = elsebookdata[i]
                                if TheWorld.state.cycles - pos.cycles >= (locationbooks[prefab].date or 3) then
                                    table.remove(elsebookdata, i)
                                elseif reader.prefab == "wickerbottom" and TheWorld.state.cycles - pos.cycles >= (locationbooks[self.inst.prefab].date or 3) - 1 then
                                    table.remove(elsebookdata, i)
                                elseif locationbooks[self.inst.prefab].global then
                                    maxcd = math.max((locationbooks[self.inst.prefab].date or 3) - TheWorld.state.cycles + pos.cycles, maxcd)
                                    reader:DoTaskInTime(0, talkerror, maxcd)
                                    return false, "LOCATIONLOCK2HM"
                                elseif distsq(x, z, pos.x, pos.z) < (locationbooks[prefab].range or 256) then
                                    local fx = SpawnPrefab("reticuleaoeshadowtarget_6")
                                    fx.Transform:SetPosition(pos.x, 0, pos.z)
                                    local scale = locationbooks[prefab].fxscale or 4
                                    fx.AnimState:SetScale(scale, scale, scale)
                                    fx:DoTaskInTime(60, fx.Remove)
                                    fxlist[self.inst.prefab][reader.userid] = fxlist[self.inst.prefab][reader.userid] or {}
                                    table.insert(fxlist[self.inst.prefab][reader.userid], fx)
                                    result = false
                                    maxcd = math.max((locationbooks[self.inst.prefab].date or 3) - TheWorld.state.cycles + pos.cycles, maxcd)
                                end
                            end
                        end
                    end
                    if result == false then
                        reader:DoTaskInTime(0, talkerror, maxcd)
                        return false, "LOCATIONLOCK2HM"
                    end
                end
            end
            local success, reason = Interact(self, fn, reader, ...)
            if success and bookdata and currentpos then
                table.insert(bookdata, currentpos)
                if not locationbooks[self.inst.prefab].global then
                    local fx = SpawnPrefab("reticuleaoeshadowtarget_6")
                    fx.Transform:SetPosition(currentpos.x, 0, currentpos.z)
                    local scale = locationbooks[self.inst.prefab].fxscale or 4
                    fx.AnimState:SetScale(scale, scale, scale)
                    fx.AnimState:SetMultColour(.5, .5, .5, .5)
                    fx:DoTaskInTime(60, fx.Remove)
                    fxlist[self.inst.prefab][reader.userid] = fxlist[self.inst.prefab][reader.userid] or {}
                    table.insert(fxlist[self.inst.prefab][reader.userid], fx)
                end
            end
            return success, reason
        end
    end)
end

-- -- 鸟书
-- AddRecipePostInit(
--     "book_birds",
--     function(inst)
--         inst.ingredients = {Ingredient("papyrus", 2), Ingredient("yellowgem", 1), Ingredient("featherhat", 1)}
--     end
-- )
-- -- 园艺
-- AddRecipePostInit(
--     "book_horticulture",
--     function(inst)
--         inst.ingredients = {Ingredient("papyrus", 2), Ingredient("greengem", 1), Ingredient("nutrientsgoggleshat", 1)}
--     end
-- )
-- -- 造林
-- AddRecipePostInit(
--     "book_silviculture",
--     function(inst)
--         inst.ingredients = {Ingredient("papyrus", 2), Ingredient("greengem", 1), Ingredient("livinglog", 6)}
--     end
-- )
-- -- 睡书
-- AddRecipePostInit(
--     "book_sleep",
--     function(inst)
--         inst.ingredients = {Ingredient("papyrus", 2), Ingredient("shadowheart", 1), Ingredient("nightmarefuel", 6)}
--     end
-- )
-- -- 电书
-- AddRecipePostInit(
--     "book_brimstone",
--     function(inst)
--         inst.ingredients = {Ingredient("papyrus", 2), Ingredient("yellowgem", 1), Ingredient("lightninggoathorn", 2)}
--     end
-- )
-- -- 触手书
-- AddRecipePostInit(
--     "book_tentacles",
--     function(inst)
--         inst.ingredients = {Ingredient("papyrus", 2), Ingredient("shadowheart", 1), Ingredient("tentaclespots", 1)}
--     end
-- )
-- -- 鱼书
-- AddRecipePostInit(
--     "book_fish",
--     function(inst)
--         inst.ingredients = {Ingredient("papyrus", 2), Ingredient("bluegem", 3), Ingredient("durian_seeds", 6)}
--     end
-- )
-- -- 火书
-- AddRecipePostInit(
--     "book_fire",
--     function(inst)
--         inst.ingredients = {Ingredient("papyrus", 2), Ingredient("redgem", 3), Ingredient("dragon_scales", 1)}
--     end
-- )
-- -- 网书
-- AddRecipePostInit(
--     "book_web",
--     function(inst)
--         inst.ingredients = {Ingredient("papyrus", 2), Ingredient("bluegem", 3), Ingredient("silk", 8)}
--     end
-- )
-- -- 温度书
-- AddRecipePostInit(
--     "book_temperature",
--     function(inst)
--         table.insert(inst.ingredients, Ingredient("redgem", 1))
--         table.insert(inst.ingredients, Ingredient("bluegem", 1))
--     end
-- )
-- -- 照明书
-- AddRecipePostInit(
--     "book_light",
--     function(inst)
--         table.insert(inst.ingredients, Ingredient("yellowgem", 1))
--     end
-- )
-- -- 雨书
-- AddRecipePostInit(
--     "book_rain",
--     function(inst)
--         table.insert(inst.ingredients, Ingredient("bluegem", 3))
--     end
-- )
-- -- 蜜蜂书
-- AddRecipePostInit(
--     "book_bees",
--     function(inst)
--         table.insert(inst.ingredients, Ingredient("redgem", 3))
--     end
-- )
-- -- 科技书
-- AddRecipePostInit(
--     "book_research_station",
--     function(inst)
--         table.insert(inst.ingredients, Ingredient("gears", 4))
--     end
-- )
