-- WX-78能力削弱，电路板只能使用1次，但拆卸没有损耗，连续拆卸掉1格电量
-- TUNING.WX78_MODULE_USES = 2
-- AddComponentPostInit(
--     "upgrademodule",
--     function(self)
--         self.inst:DoTaskInTime(
--             0,
--             function()
--                 self.onremovedfromownerfn = function()
--                 end
--             end
--         )
--     end
-- )
local UpvalueHacker = require("upvaluehacker2hm")
AddComponentPostInit("upgrademoduleowner", function(self)
    local old = self.UpdateActivatedModules
    self.UpdateActivatedModules = function(self, ...)
        old(self, ...)
        -- 统计超载插槽数(上限6)
        local level = {}
        local totallevel = 0
        for bartype, modules in pairs(self.module_bars) do
            level[bartype] = {}
            level[bartype].level = 0
            for _, module in pairs(modules) do
                if module and module.components.upgrademodule.activated and module.level2hm then
                    level[bartype].level = level[bartype].level + module.components.upgrademodule.slots * (module.nohunger2hm and 1 or module.level2hm:value())
                end
            end
            level[bartype].level = math.max(level[bartype].level - self.max_charge, 0)
        end
        for i, v in pairs(level) do
            if v and v.level then totallevel = totallevel + v.level end
        end
        -- 超载饱食度惩罚:每溢出1插槽+25%饥饿消耗
        if self.inst.components.hunger then
            if totallevel == 0 then
                self.inst.components.hunger.burnratemodifiers:RemoveModifier(self.inst, "wx78module2hm")
            else
                self.inst.components.hunger.burnratemodifiers:SetModifier(self.inst, 1 + 1.5 / TUNING.WX78_INITIAL_MAXCHARGELEVEL * totallevel, "wx78module2hm")
            end
        end
    end
end)

 -- 减伤数值封顶15%
local healths = {"maxhealth", "maxhealth2"}
local function newhealthactivate(inst, wx, isloading, ...)
    local percent
    local health
    if wx and wx.components.health then
        percent = wx.components.health:GetPercent()
        if percent then percent = percent / 2 end
        health = wx.components.health.currenthealth
    end
    inst.oldonactivatedfn2hm(inst, wx, isloading, ...)
    if percent and not wx.addhealthchange2hm and not isloading then
        wx.addhealthchange2hm = true
        wx:DoTaskInTime(.3, function() 
            wx.addhealthchange2hm = nil 
            wx.components.health.currenthealth = math.max(health or wx.components.health.currenthealth, wx.components.health.maxhealth * percent)
        end)
    end
    if wx.components.combat then
        local num = wx.components.combat.externaldamagetakenmultipliers:CalculateModifierFromKey("maxhealthmoduleskill")
        if num then
            wx.components.combat.externaldamagetakenmultipliers:SetModifier(wx, math.max(0.75, num), "maxhealthmoduleskill")
        end
    end
end

-- 芯片停用减伤仍计算bug修复
local function newhealthdeactivatedfn(inst, wx, isloading, ...)
    local percent
    local health
    if wx and wx.components.health then
        percent = wx.components.health:GetPercent()
        if percent then percent = math.min(percent * 2, 1) end
        health = wx.components.health.currenthealth
    end
    inst._skill_health_armor_mult = 0
    inst.oldondeactivatedfn2hm(inst, wx, isloading, ...)
    if percent and not wx.healthchange2hm and not isloading  then
        wx.healthchange2hm = true
        wx:DoTaskInTime(.2, function() 
            wx.healthchange2hm = nil
            wx.components.health.currenthealth = math.min(health or wx.components.health.currenthealth, wx.components.health.maxhealth * percent)
        end)
    end
end
for index, name in ipairs(healths) do
    AddPrefabPostInit("wx78module_" .. name, function(inst)
        if not TheWorld.ismastersim then return end
        inst.nohunger2hm = true
        if inst.components.upgrademodule then
            inst.oldonactivatedfn2hm = inst.components.upgrademodule.onactivatedfn
            inst.components.upgrademodule.onactivatedfn = newhealthactivate
            inst.oldondeactivatedfn2hm = inst.components.upgrademodule.ondeactivatedfn
            inst.components.upgrademodule.ondeactivatedfn = newhealthdeactivatedfn
        end
    end)
end

local hungers = {"maxhunger", "maxhunger1"}
TUNING.WX78_MAXHUNGER1_BOOST = TUNING.WX78_MAXHUNGER1_BOOST * 1.25
TUNING.WX78_MAXHUNGER_BOOST = TUNING.WX78_MAXHUNGER_BOOST * 1.5
TUNING.WX78_MAXHUNGER_SLOWPERCENT = 1
local function newhungeractivate(inst, wx, isloading, ...)
    local percent
    local hunger
    if wx and wx.components.hunger then
        percent = wx.components.hunger:GetPercent()
        hunger = wx.components.hunger.current
        if percent then percent = percent / 2 end
    end
    inst.oldonactivatedfn2hm(inst, wx, isloading, ...)
    if percent and not wx.addhungerchange2hm and not isloading  then
        wx.addhungerchange2hm = true
        wx:DoTaskInTime(.3, function() 
            wx.addhungerchange2hm = nil 
            wx.components.hunger.current = math.max(hunger or wx.components.hunger.current, percent * wx.components.hunger.max)
        end)
    end
    if wx and wx._hunger_chips then
        wx._hunger_chips2hm = wx._hunger_chips
        wx._hunger_chips = math.floor(wx._hunger_chips * 3 / 4)
    end
    if wx.components.hunger then
        wx.components.hunger.burnratemodifiers:SetModifier(inst, 1)
    end
end
local function newhungerdeactivatedfn(inst, wx, isloading, ...)
    local percent
    local hunger
    if wx and wx.components.hunger then
        percent = wx.components.hunger:GetPercent()
        hunger = wx.components.hunger.current
        if percent then percent = math.min(percent * 2, 1) end
    end
    if wx then wx._hunger_chips = wx._hunger_chips2hm or wx._hunger_chips or 0 end
    inst.oldondeactivatedfn2hm(inst, wx, isloading, ...)
    if percent and not wx.hungerchange2hm and not isloading  then
        wx.hungerchange2hm = true
        wx:DoTaskInTime(.3, function() 
            wx.hungerchange2hm = nil
            wx.components.hunger.current = math.min(hunger or wx.components.hunger.current, percent * wx.components.hunger.max)
        end)
    end
    if wx and wx._hunger_chips then
        wx._hunger_chips2hm = wx._hunger_chips
        wx._hunger_chips = math.floor(wx._hunger_chips * 3 / 4)
    end
end
for index, name in ipairs(hungers) do
    AddPrefabPostInit("wx78module_" .. name, function(inst)
        if not TheWorld.ismastersim then return end
        inst.nohunger2hm = true
        if inst.components.upgrademodule then
            inst.oldonactivatedfn2hm = inst.components.upgrademodule.onactivatedfn
            inst.components.upgrademodule.onactivatedfn = newhungeractivate
            inst.oldondeactivatedfn2hm = inst.components.upgrademodule.ondeactivatedfn
            inst.components.upgrademodule.ondeactivatedfn = newhungerdeactivatedfn
        end
    end)
end
local sanitys = {"maxsanity", "maxsanity1", "bee"}

--2025.11.4夜风修复困难模式拔插芯片刷新理智状态bug
local function newsanityactivate(inst, wx, isloading, ...)
    local percent
    local sanity
    if wx and wx.components.sanity then
        percent = wx.components.sanity:GetPercent()
        if percent then percent = percent / 2 end
        sanity = wx.components.sanity.current
    end
    inst.oldonactivatedfn2hm(inst, wx, isloading, ...)
    if percent and not wx.addsanitychange2hm and not isloading  then
        wx.addsanitychange2hm = true
        wx:DoTaskInTime(.3, function() 
            wx.addsanitychange2hm = nil
            wx.components.sanity.current = math.max(sanity or wx.components.sanity.current, percent * wx.components.sanity.max)
        end)
    end
end
local function newsanitydeactivatedfn(inst, wx, isloading, ...)
    local percent
    local sanity
    if wx and wx.components.sanity then
        percent = wx.components.sanity:GetPercent()
        if percent then percent = math.min(percent * 2, 1) end
        sanity = wx.components.sanity.current
    end
    inst.oldondeactivatedfn2hm(inst, wx, isloading, ...)
    if percent and not wx.sanitychange2hm and not isloading then
        wx.sanitychange2hm = true
        wx:DoTaskInTime(.3, function() 
            wx.sanitychange2hm = nil
            wx.components.sanity.current = math.min(sanity or wx.components.sanity.current, percent * wx.components.sanity.max)
        end)
    end
end
for index, name in ipairs(sanitys) do
    AddPrefabPostInit("wx78module_" .. name, function(inst)
        if not TheWorld.ismastersim then return end
        inst.nohunger2hm = true
        --2025.11.4夜风修复困难模式拔插芯片刷新理智状态bug
        if inst.components.upgrademodule then
            inst.oldonactivatedfn2hm = inst.components.upgrademodule.onactivatedfn
            inst.components.upgrademodule.onactivatedfn = newsanityactivate
            inst.oldondeactivatedfn2hm = inst.components.upgrademodule.ondeactivatedfn
            inst.components.upgrademodule.ondeactivatedfn = newsanitydeactivatedfn
        end
        --
    end)
end

-- 妥协加速芯片
if TUNING.DSTU and TUNING.DSTU.WXLESS then
    local return5fn = function() return 5 end
    local function newmovespeedactivate(inst, wx, ...)
        inst.oldonactivatedfn2hm(inst, wx, ...)
        if inst.accelarate ~= nil and not inst.accelarate2hm then
            inst.accelarate2hm = true
            local accelarate = inst.accelarate
            wx:RemoveEventCallback("locomote", accelarate, wx)
            inst.accelarate = function(wx, _, ...)
                local movetime = wx.components.locomotor:GetTimeMoving()
                local speed = math.clamp(TUNING.WILSON_RUN_SPEED + movetime, TUNING.WILSON_RUN_SPEED,
                                         12 - TUNING.WX78_MOVESPEED_CHIPBOOSTS[wx._movespeed_chips + 1])
                if wx.speedloosetask == nil then
                    wx.accelarate_speed = speed
                    wx.components.locomotor.runspeed = speed
                end
                local GetTimeMoving = wx.components.locomotor.GetTimeMoving
                wx.components.locomotor.GetTimeMoving = return5fn
                accelarate(wx, inst, ...)
                wx.components.locomotor.GetTimeMoving = GetTimeMoving
                if wx.speedloosetask == nil then
                    if not inst.accelarateListen2hm then
                        inst.accelarateListen2hm = true
                        inst:ListenForEvent("newstate", inst.accelarate, wx)
                    end
                    wx.accelarate_speed = speed
                    wx.components.locomotor.runspeed = speed
                else
                    if inst.accelarateListen2hm then
                        inst.accelarateListen2hm = nil
                        inst:RemoveEventCallback("newstate", inst.accelarate, wx)
                    end
                    wx.accelarate_speed = TUNING.WILSON_RUN_SPEED
                    wx.components.locomotor.runspeed = TUNING.WILSON_RUN_SPEED
                end
            end
            inst:ListenForEvent("locomote", inst.accelarate, wx)
        end
    end
    local function newmovespeeddeactivatedfn(inst, wx, ...)
        inst.accelarateListen2hm = nil
        inst:RemoveEventCallback("locomote", inst.accelarate, wx)
        inst:RemoveEventCallback("newstate", inst.accelarate, wx)
        inst.oldondeactivatedfn2hm(inst, wx, ...)
        if inst.accelarate == nil and inst.accelarate2hm then
            inst.accelarate2hm = nil
            wx.accelaratecd2hm = nil
        end
    end
    local movespeeds = {"movespeed", "movespeed2"}
    for index, name in ipairs(movespeeds) do
        AddPrefabPostInit("wx78module_" .. name, function(inst)
            if not TheWorld.ismastersim then return end
            if inst.components.upgrademodule then
                inst.oldonactivatedfn2hm = inst.components.upgrademodule.onactivatedfn
                inst.components.upgrademodule.onactivatedfn = newmovespeedactivate
                inst.oldondeactivatedfn2hm = inst.components.upgrademodule.ondeactivatedfn
                inst.components.upgrademodule.ondeactivatedfn = newmovespeeddeactivatedfn
            end
        end)
    end
    local function newtaseractivate(inst, wx, ...)
        inst.oldonactivatedfn2hm(inst, wx, ...)
        if inst._onblocked ~= nil and not inst._onblocked2hm then
            inst._onblocked2hm = true
            local _onblocked = inst._onblocked
            inst:RemoveEventCallback("blocked", inst._onblocked, wx)
            inst:RemoveEventCallback("attacked", inst._onblocked, wx)
            inst._onblocked = function(wx, data, ...)
                if inst._cdtask == nil then
                    _onblocked(wx, data, ...)
                    if inst._cdtask then inst._cdtask.period = 6 end
                end
            end
            inst:ListenForEvent("blocked", inst._onblocked, wx)
            inst:ListenForEvent("attacked", inst._onblocked, wx)
        end
    end
    local function newtaserdeactivatedfn(inst, wx, ...)
        inst.oldondeactivatedfn2hm(inst, wx, ...)
        if inst._onblocked == nil and inst._onblocked2hm then inst._onblocked2hm = nil end
    end
    AddPrefabPostInit("wx78module_taser", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.upgrademodule then
            inst.oldonactivatedfn2hm = inst.components.upgrademodule.onactivatedfn
            inst.components.upgrademodule.onactivatedfn = newtaseractivate
            inst.oldondeactivatedfn2hm = inst.components.upgrademodule.ondeactivatedfn
            inst.components.upgrademodule.ondeactivatedfn = newtaserdeactivatedfn
        end
    end)
end

--2025.11.9夜风 添加额外的扫描生物解锁电路逻辑
if GetModConfigData("WX-78 Safe Remove Module") then
    local wx78_moduledefs = require("wx78_moduledefs")
    
    -- 扫描牛解锁超级强化电路
    wx78_moduledefs.AddCreatureScanDataDefinition("beefalo", "maxhealth2", 6)
    
    -- 扫描月熠解锁照明电路
    wx78_moduledefs.AddCreatureScanDataDefinition("hutch", "light", 4)

end

-- -- 修改强化芯片电路（maxhealth）配方
-- AddRecipePostInit("wx78module_maxhealth", function(recipe)
--     -- 清空原有材料
--     recipe.ingredients = {}
--     -- 添加新材料：4个生物数据 + 2个治疗药膏
--     recipe.ingredients = {
--         Ingredient("scandata", 4),
--         Ingredient("healingsalve", 2),
--     }
-- end)
-- -- 修改超级强化芯片电路（maxhealth2）配方
-- AddRecipePostInit("wx78module_maxhealth2", function(recipe)
--     -- 清空原有材料
--     recipe.ingredients = {}
--     -- 添加新材料：4个生物数据 + 1个强化电路
--     recipe.ingredients = {
--         Ingredient("scandata", 4),
--         Ingredient("wx78module_maxhealth", 1),
--     }
-- end)
-- -- 修改处理器芯片电路（maxsanitY1）配方
-- AddRecipePostInit("wx78module_maxsanity1", function(recipe)
--     -- 清空原有材料
--     recipe.ingredients = {}
--     -- 添加新材料：2个生物数据 + 2个蝴蝶+6个绿蘑菇
--     recipe.ingredients = {
--         Ingredient("scandata", 2),
--         Ingredient("butterfly", 2),
--         Ingredient("green_cap", 6),
--     }
-- end)
-- -- 修改超级处理器芯片电路（maxsanitY）配方
-- AddRecipePostInit("wx78module_maxsanity", function(recipe)
--     -- 清空原有材料
--     recipe.ingredients = {}
--     -- 添加新材料：4个生物数据 + 1个噩梦燃料+1个处理器芯片
--     recipe.ingredients = {
--         Ingredient("scandata", 4),
--         Ingredient("nightmarefuel", 1),
--         Ingredient("wx78module_maxsanitY1", 1),
--     }
-- end)
-- -- 修改加速芯片电路（movespeed）配方
-- AddRecipePostInit("wx78module_movespeed", function(recipe)
--     -- 清空原有材料
--     recipe.ingredients = {}
--     -- 添加新材料：4个生物数据 + 1个兔子
--     recipe.ingredients = {
--         Ingredient("scandata", 4),
--         Ingredient("rabbit", 1),
--     }
-- end)
-- -- 修改超级加速芯片电路（movespeed2）配方
-- AddRecipePostInit("wx78module_movespeed2", function(recipe)
--     -- 清空原有材料
--     recipe.ingredients = {}
--     -- 添加新材料：4个生物数据 + 2个治疗药膏
--     recipe.ingredients = {
--         Ingredient("scandata", 8),
--         Ingredient("gears", 2),
--         Ingredient("wx78module_movespeed", 2),
--     }
-- end)
-- -- 修改热能芯片电路（heat）配方
-- AddRecipePostInit("wx78module_heat", function(recipe)
--     -- 清空原有材料
--     recipe.ingredients = {}
--     -- 添加新材料：8个生物数据 + 2个重生护符+1个紫宝石
--     recipe.ingredients = {
--         Ingredient("scandata", 8),
--         Ingredient("amulet", 2),
--         Ingredient("purplegem", 1),
--     }
-- end)
-- -- 修改制冷电路芯片电路（cold）配方
-- AddRecipePostInit("wx78module_cold", function(recipe)
--     -- 清空原有材料
--     recipe.ingredients = {}
--     -- 添加新材料：8个生物数据 + 2个寒冰护符+1个紫宝石
--     recipe.ingredients = {
--         Ingredient("scandata", 8),
--         Ingredient("blueamulet", 2),
--         Ingredient("purplegem", 2),
--     }
-- end)
-- -- 修改电气化芯片电路（taser）配方
-- AddRecipePostInit("wx78module_taser", function(recipe)
--     -- 清空原有材料
--     recipe.ingredients = {}
--     -- 添加新材料：10个生物数据 + 2个羊奶+1羊角
--     recipe.ingredients = {
--         Ingredient("scandata", 10),
--         Ingredient("goatmilk", 2),
--         Ingredient("lightninggoathorn", 1),
--     }
-- end)
-- -- 修改光电芯片电路（nightvision）配方
-- AddRecipePostInit("wx78module_nightvision", function(recipe)
--     -- 清空原有材料
--     recipe.ingredients = {}
--     -- 添加新材料：4个生物数据 + 1个鼹鼠 + 2个大发光浆果 + 2个照明电路
--     recipe.ingredients = {
--         Ingredient("scandata", 4),
--         Ingredient("mole", 1),
--         Ingredient("wormlight", 2),
--         Ingredient("wx78module_light", 2),
--     }
-- end)
-- -- 修改照明芯片电路（light）配方
-- AddRecipePostInit("wx78module_light", function(recipe)
--     -- 清空原有材料
--     recipe.ingredients = {}
--     -- 添加新材料：6个生物数据 + 2个荧光果 + 2个萤火虫
--     recipe.ingredients = {
--         Ingredient("scandata", 6),
--         Ingredient("lightbulb", 2),
--         Ingredient("fireflies", 2),
--     }
-- end)

--2025.11.9夜风 豆增压电路（bee模块）添加超载状态功能
-- 检查WX-78是否装备了bee模块
-- local function HasBeeModule(wx)
--     if wx and wx.components.upgrademoduleowner then
--         for _, module in ipairs(wx.components.upgrademoduleowner.module_bars) do
--             if module and module.prefab == "wx78module_bee" and module.components.upgrademodule and module.components.upgrademodule.activated then
--                 return true
--             end
--         end
--     end
--     return false
-- end

-- -- 超载状态效果更新（逐渐减弱）
-- local function UpdateOverloadEffects(wx)
--     if not wx.overload_time2hm or wx.overload_time2hm <= 0 then
--         -- 超载结束，清除所有效果
--         if wx.overload_task2hm then
--             wx.overload_task2hm:Cancel()
--             wx.overload_task2hm = nil
--         end
--         if wx.overload_light2hm then
--             wx.overload_light2hm:Enable(false)
--         end
--         if wx.components.locomotor then
--             wx.components.locomotor:RemoveExternalSpeedMultiplier(wx, "wx78_overload2hm")
--         end
--         if wx.components.temperature then
--             wx.components.temperature:RemoveModifier("wx78_overload2hm")
--         end
--         wx.overload_time2hm = nil
--         wx:RemoveTag("wx78_overloaded2hm")
--         return
--     end
    
--     -- 计算衰减系数（从1到0）
--     local decay = wx.overload_time2hm / TUNING.TOTAL_DAY_TIME
    
--     -- 更新移动速度（从35%逐渐降到0）
--     if wx.components.locomotor then
--         wx.components.locomotor:SetExternalSpeedMultiplier(wx, "wx78_overload2hm", 1 + 0.35 * decay)
--     end
    
--     -- 更新光照强度（从4格逐渐降到0）
--     if wx.overload_light2hm then
--         wx.overload_light2hm:SetRadius(4 * decay)
--         wx.overload_light2hm:SetIntensity(0.8 * decay)
--     end
    
--     wx.overload_time2hm = wx.overload_time2hm - 1
-- end

-- -- 进入超载状态
-- local function EnterOverloadState(wx)
--     if not HasBeeModule(wx) then 
--         return 
--     end
    
--     -- 添加超载标签
--     wx:AddTag("wx78_overloaded2hm")
    
--     -- 设置超载时长（约1天）
--     wx.overload_time2hm = TUNING.TOTAL_DAY_TIME
    
--     -- 恢复60点生命，损失33点理智
--     if wx.components.health and not wx.components.health:IsDead() then
--         wx.components.health:DoDelta(60)
--     end
--     if wx.components.sanity then
--         wx.components.sanity:DoDelta(-33)
--     end
    
--     -- 添加光照组件
--     if not wx.overload_light2hm then
--         if not wx.Light then
--             wx.entity:AddLight()
--         end
--         wx.overload_light2hm = wx.Light or wx.entity:AddLight()
--         wx.overload_light2hm:SetFalloff(0.5)
--         wx.overload_light2hm:SetColour(180/255, 195/255, 225/255)
--     end
--     wx.overload_light2hm:Enable(true)
--     wx.overload_light2hm:SetRadius(4)
--     wx.overload_light2hm:SetIntensity(0.8)
    
--     -- 免疫寒冷（增加温度抗性）
--     if wx.components.temperature then
--         wx.components.temperature:SetModifier("wx78_overload2hm", 30)
--     end
    
--     -- 设置移动速度加成（初始35%，随时间衰减）
--     if wx.components.locomotor then
--         wx.components.locomotor:SetExternalSpeedMultiplier(wx, "wx78_overload2hm", 1.35)
--     end
    
--     -- 启动更新任务（每秒更新一次）
--     if wx.overload_task2hm then
--         wx.overload_task2hm:Cancel()
--     end
--     wx.overload_task2hm = wx:DoPeriodicTask(1, UpdateOverloadEffects)
    
--     -- 播放特效
--     local fx = SpawnPrefab("electrichitsparks")
--     if fx then
--         fx.entity:SetParent(wx.entity)
--     end
-- end

-- -- WX-78被闪电击中时触发超载
-- AddPrefabPostInit("wx78", function(inst)
--     if not TheWorld.ismastersim then return end
    
--     -- 延迟初始化，确保所有组件都加载完成
--     inst:DoTaskInTime(0, function(inst)
--         -- Hook playerlightningtarget 组件的 DoStrike 方法
--         if inst.components.playerlightningtarget then
--             local old_DoStrike = inst.components.playerlightningtarget.DoStrike
--             inst.components.playerlightningtarget.DoStrike = function(self, ...)
--                 local result = old_DoStrike(self, ...)
--                 -- 在原版闪电处理后，检查是否装备bee模块并触发超载
--                 if HasBeeModule(inst) then
--                     EnterOverloadState(inst)
--                 end
--                 return result
--             end
--         end
        
--         -- 同时监听闪电击中事件（作为备用）
--         inst:ListenForEvent("lightningstrike", function(wx, data)
--             if HasBeeModule(wx) then
--                 EnterOverloadState(wx)
--             end
--         end)
--     end)
    
--     -- 保存时清理任务
--     local old_OnSave = inst.OnSave
--     inst.OnSave = function(inst, data)
--         if old_OnSave then old_OnSave(inst, data) end
--         if inst.overload_time2hm and inst.overload_time2hm > 0 then
--             data.overload_time2hm = inst.overload_time2hm
--         end
--     end
    
--     -- 加载时恢复状态
--     local old_OnLoad = inst.OnLoad
--     inst.OnLoad = function(inst, data)
--         if old_OnLoad then old_OnLoad(inst, data) end
--         if data and data.overload_time2hm then
--             inst.overload_time2hm = data.overload_time2hm
--             EnterOverloadState(inst)
--         end
--     end
-- end)


-- ACTIONS.REMOVEMODULES.fn = function(act)
--     if
--         (act.invobject ~= nil and act.invobject.components.upgrademoduleremover ~= nil) and
--             (act.doer ~= nil and act.doer.components.upgrademoduleowner ~= nil)
--      then
--         if act.doer.components.upgrademoduleowner:NumModules() > 0 then
--             local energy_cost = act.doer.components.upgrademoduleowner:PopOneModule()
--             if energy_cost ~= 0 then
--                 if not act.doer._modremovetask then
--                     act.doer._modremovetask =
--                         act.doer:DoTaskInTime(
--                         30,
--                         function()
--                             act.doer._modremovetask = nil
--                         end
--                     )
--                 else
--                     act.doer.components.upgrademoduleowner:AddCharge(-1)
--                     act.doer._modremovetask:Cancel()
--                     act.doer._modremovetask = nil
--                     act.doer._modremovetask =
--                         act.doer:DoTaskInTime(
--                         30,
--                         function()
--                             act.doer._modremovetask = nil
--                         end
--                     )
--                 end
--             end

--             return true
--         else
--             return false, "NO_MODULES"
--         end
--     end

--     return false
-- end

-- 2025.11.24 YeFeng: 修复WX-78永不妥协电气化电路反伤无冷却导致怪物无限僵直的问题
-- 参考重制版方案，使用electricstunimmune标签机制，CD延长至5倍
local function cancelelectricstunimmunetag(inst)
    if inst and inst:IsValid() then
        inst:RemoveTag("electricstunimmune")
    end
end
-- 重复攻击目标会施加电击抗性，减少下次伤害
local function canceleltaser_resistance2hm(inst)
    inst.taser_resistance2hm = nil
    inst.taser_resistance2hmcancel2hm = nil
end

local olddamage = TUNING.WX78_TASERDAMAGE
local UpvalueHacker = require("upvaluehacker2hm")
local module_definitions = require("wx78_moduledefs").module_definitions
if TUNING.DSTU and TUNING.DSTU.WXLESS then module_definitions = require("um_wx78_moduledefs").module_definitions end
for _, def in ipairs(module_definitions) do
    if def.name == "taser" then
        if TUNING.DSTU and TUNING.DSTU.WXLESS then
            local AltShockStun = UpvalueHacker.GetUpvalue(def.activatefn, "taser_onblockedorattacked", "AltShockStun")
            if AltShockStun then
                local newAltShockStun = function(inst, ...)
                    if inst:HasTag("electricstunimmune") then return end
                    return AltShockStun(inst, ...)
                end
                UpvalueHacker.SetUpvalue(def.activatefn, newAltShockStun, "taser_onblockedorattacked", "AltShockStun")
            end
        end

        local original_taser_onblockedorattacked = UpvalueHacker.GetUpvalue(def.activatefn, "taser_onblockedorattacked")
        if original_taser_onblockedorattacked then
            local function patched_taser_onblockedorattacked(wx, data, inst)
                local cantaser = (data ~= nil and data.attacker ~= nil and not data.redirected) and inst._cdtask == nil 
                        and data.attacker.components.combat and not (data.attacker.components.health and data.attacker.components.health:IsDead())
                        and (data.attacker.components.inventory == nil or not data.attacker.components.inventory:IsInsulated())
                        and (not data.weapon or (not data.weapon.components.projectile and (not data.weapon.components.weapon or not data.weapon.components.weapon.projectile)))
                
                TUNING.WX78_TASERDAMAGE = olddamage * (1 - (data and data.attacker and data.attacker.taser_resistance2hm or 0) * 0.1)
                local oldPushEventImmediate
                if data and data.attacker then
                    oldPushEventImmediate = data.attacker.PushEventImmediate

                    if oldPushEventImmediate then
                        data.attacker.PushEventImmediate = function(inst, event, data, ...)
                            if event == "electrocute" then
                                data.noresist = false
                            end
                            return oldPushEventImmediate(inst, event, data, ...)
                        end
                    end
                end
                original_taser_onblockedorattacked(wx, data, inst)

                TUNING.WX78_TASERDAMAGE = olddamage
                if oldPushEventImmediate then data.attacker.PushEventImmediate = oldPushEventImmediate end

                if cantaser then
                    if TUNING.DSTU and TUNING.DSTU.WXLESS and not data.attacker:HasTag("electricstunimmune") then
                        local cd_duration = TUNING.ELECTROCUTE_DEFAULT_DELAY and
                            (TUNING.ELECTROCUTE_DEFAULT_DELAY.min +
                                math.random() * (TUNING.ELECTROCUTE_DEFAULT_DELAY.max - TUNING.ELECTROCUTE_DEFAULT_DELAY.min))
                            or math.random(15, 25)
                        data.attacker:AddTag("electricstunimmune")
                        data.attacker:DoTaskInTime(cd_duration, cancelelectricstunimmunetag)
                    end
                    -- 添加电击抗性
                    if data.attacker:IsValid() and not data.attacker.taser_resistancecd2hm then
                        data.attacker.taser_resistancecd2hm = data.attacker:DoTaskInTime(.3, function() data.attacker.taser_resistancecd2hm = nil end)
                        inst:DoTaskInTime(0, function()
                            data.attacker.taser_resistance2hm = math.min((data.attacker.taser_resistance2hm or 0) + 1, 5)
                            if data.attacker.taser_resistance2hmcancel2hm then
                                data.attacker.taser_resistance2hmcancel2hm:Cancel()
                            end
                            local time = (3 * (data.attacker.components.combat and data.attacker.components.combat.min_attack_period ~= nil and data.attacker.components.combat.min_attack_period)) or 10
                            data.attacker.taser_resistance2hmcancel2hm = data.attacker:DoTaskInTime(time, canceleltaser_resistance2hm)
                        end)
                    end
                end
            end

            UpvalueHacker.SetUpvalue(def.activatefn, patched_taser_onblockedorattacked, "taser_onblockedorattacked")
        end
        break
    end
end

--2025.11.9 YeFeng: 添加额外的扫描生物解锁电路逻辑
local wx78_moduledefs = require("wx78_moduledefs")
-- 扫描牛解锁超级强化电路
wx78_moduledefs.AddCreatureScanDataDefinition("beefalo", "maxhealth2", 8)
-- 扫描哈奇解锁照明电路
wx78_moduledefs.AddCreatureScanDataDefinition("hutch", "light", 4)
-- 扫描发条骑士解锁照明电路
-- wx78_moduledefs.AddCreatureScanDataDefinition("knight", "light", 4)
-- 扫描恐惧之眼解锁照明电路
wx78_moduledefs.AddCreatureScanDataDefinition("eyeofterror", "light", 10)

--2025.11.29 YeFeng: 分别添加热能电路和制冷电路的第二配方解锁电路逻辑
-- 扫描龙蝇解锁热能电路（太阳鱼配方的）
wx78_moduledefs.AddCreatureScanDataDefinition("dragonfly", "heat_fish", 10)
-- 扫描火焰猎犬解锁热能电路（太阳鱼配方的）
wx78_moduledefs.AddCreatureScanDataDefinition("firehound", "heat_fish", 4)
-- 扫描巨鹿解锁制冷电路（冰雕鱼配方的）
wx78_moduledefs.AddCreatureScanDataDefinition("deerclops", "cold_fish", 10)
-- 扫描冰猎犬解锁制冷电路（冰雕鱼配方的）
wx78_moduledefs.AddCreatureScanDataDefinition("icehound", "cold_fish", 4)

-- 2025.11.29 YeFeng: 兼容《永不妥协》模组的额外扫描解锁
-- 支持正式版和测试版
if KnownModIndex:IsModEnabled("workshop-2039181790") or KnownModIndex:IsModEnabled("workshop-3193922031") then
    -- 扫描《永不妥协》中的火焰生物解锁热能电路（太阳鱼配方的）
    wx78_moduledefs.AddCreatureScanDataDefinition("mock_dragonfly", "heat_fish", 10)
    wx78_moduledefs.AddCreatureScanDataDefinition("snaildrake_magma", "heat_fish", 3)
    wx78_moduledefs.AddCreatureScanDataDefinition("snaildrake_slime", "heat_fish", 3)
    wx78_moduledefs.AddCreatureScanDataDefinition("magmahound", "heat_fish", 6)
    wx78_moduledefs.AddCreatureScanDataDefinition("um_pepperdragon", "heat_fish", 6)
    -- 扫描《永不妥协》中的冰冷生物解锁制冷电路（冰雕鱼配方的）
    wx78_moduledefs.AddCreatureScanDataDefinition("glacialhound", "cold_fish", 6)
end


--2025.11.9 YeFeng: 机器人芯片电路大调整，
if GetModConfigData("wx-78") ~= -1 then
    -- 修改强化芯片电路（maxhealth）配方
    AddRecipePostInit("wx78module_maxhealth", function(recipe)
        -- 清空原有材料
        recipe.ingredients = {}
        -- 添加新材料：4个生物数据 + 2个治疗药膏
        recipe.ingredients = {
            Ingredient("scandata", 4),
            Ingredient("healingsalve", 2),
        }
    end)
    -- 修改超级强化芯片电路（maxhealth2）配方
    AddRecipePostInit("wx78module_maxhealth2", function(recipe)
        -- 清空原有材料
        recipe.ingredients = {}
        -- 添加新材料：4个生物数据 + 1个强化电路
        recipe.ingredients = {
            Ingredient("scandata", 4),
            Ingredient("wx78module_maxhealth", 1),
        }
    end)
    -- 修改处理器芯片电路（maxsanitY1）配方
    -- AddRecipePostInit("wx78module_maxsanity1", function(recipe)
    --     -- 清空原有材料
    --     recipe.ingredients = {}
    --     -- 添加新材料：2个生物数据 + 2个蝴蝶+4个绿蘑菇
    --     recipe.ingredients = {
    --         Ingredient("scandata", 2),
    --         Ingredient("butterfly", 2),
    --         Ingredient("green_cap", 4),
    --     }
    -- end)
    -- 修改超级处理器芯片电路（maxsanitY）配方
    -- AddRecipePostInit("wx78module_maxsanity", function(recipe)
    --     -- 清空原有材料
    --     recipe.ingredients = {}
    --     -- 添加新材料：4个生物数据 + 1个处理器芯片
    --     recipe.ingredients = {
    --         Ingredient("scandata", 4),
    --         Ingredient("wx78module_maxsanity1", 1),
    --     }
    -- end)
    -- 修改加速芯片电路（movespeed）配方
    -- AddRecipePostInit("wx78module_movespeed", function(recipe)
    --     -- 清空原有材料
    --     recipe.ingredients = {}
    --     -- 添加新材料：4个生物数据 + 1个兔子
    --     recipe.ingredients = {
    --         Ingredient("scandata", 4),
    --         Ingredient("rabbit", 1),
    --     }
    -- end)
    -- 修改超级加速芯片电路（movespeed2）配方
    AddRecipePostInit("wx78module_movespeed2", function(recipe)
        -- 清空原有材料
        recipe.ingredients = {}
        -- 添加新材料：6个生物数据 + 2个齿轮 + 2个加速电路
        recipe.ingredients = {
            Ingredient("scandata", 6),
            Ingredient("gears", 2),
            Ingredient("wx78module_movespeed", 1),
        }
    end)
    -- 修改电气化芯片电路（taser）配方
    -- AddRecipePostInit("wx78module_taser", function(recipe)
    --     -- 清空原有材料
    --     recipe.ingredients = {}
    --     -- 添加新材料：5个生物数据 + 1个羊奶 + 1个羊角
    --     recipe.ingredients = {
    --         Ingredient("scandata", 5),
    --         Ingredient("goatmilk", 1),
    --         Ingredient("lightninggoathorn", 1),
    --     }
    -- end)
    -- 修改光电芯片电路（nightvision）配方
    AddRecipePostInit("wx78module_nightvision", function(recipe)
        -- 清空原有材料
        recipe.ingredients = {}
        -- 添加新材料：4个生物数据 + 2个鼹鼠 + 1个大发光浆果 + 1个超级照明电路
        recipe.ingredients = {
            Ingredient("scandata", 4),
            Ingredient("mole", 2),
            Ingredient("wormlight", 1),
            Ingredient("wx78module_light2", 1),
        }
    end)
    -- -- 修改照明芯片电路（light）配方
    -- AddRecipePostInit("wx78module_light", function(recipe)
    --     -- 清空原有材料
    --     recipe.ingredients = {}
    --     -- 添加新材料：6个生物数据 + 2个荧光果 + 2个萤火虫
    --     recipe.ingredients = {
    --         Ingredient("scandata", 6),
    --         Ingredient("lightbulb", 2),
    --         Ingredient("fireflies", 2),
    --     }
    -- end)
    -- 修改胃增益芯片电路（maxhunger1）配方
    AddRecipePostInit("wx78module_maxhunger1", function(recipe)
        -- 清空原有材料
        recipe.ingredients = {}
        -- 添加新材料：4个生物数据 + 2个啜食者皮
        recipe.ingredients = {
            Ingredient("scandata", 2),
            Ingredient("slurper_pelt", 2),
        }
    end)
    -- 修改超级胃增益芯片电路（maxhunger）配方
    AddRecipePostInit("wx78module_maxhunger", function(recipe)
        -- 清空原有材料
        recipe.ingredients = {}
        -- 添加新材料：4个生物数据 + 1个胃增益电路
        recipe.ingredients = {
            Ingredient("scandata", 3),
            Ingredient("wx78module_maxhunger1", 1),
        }
    end)
    -- 修改豆增压芯片电路（bee）配方
    AddRecipePostInit("wx78module_bee", function(recipe)
        -- 清空原有材料
        recipe.ingredients = {}
        -- 添加新材料：4个生物数据 +2个蜂王浆+ 1个处理器电路
        recipe.ingredients = {
            Ingredient("scandata", 4),
            Ingredient("royal_jelly", 2),
            Ingredient("wx78module_maxsanity1", 1),
        }
    end)

    -- 修改热能芯片电路（heat）配方（龙鳞片）
    AddRecipePostInit("wx78module_heat", function(recipe)
        -- 清空原有材料
        recipe.ingredients = {}
        -- 添加新材料：4个生物数据 + 2个重生护符 + 2个紫宝石 + 1个龙鳞片
        recipe.ingredients = {
            Ingredient("scandata", 4),
            -- Ingredient("amulet", 1),
            -- Ingredient("purplegem", 2),
            Ingredient("dragon_scales", 1), -- 龙鳞片
        }
    end)
    -- 修改制冷芯片电路（cold）配方（巨鹿眼球）
    AddRecipePostInit("wx78module_cold", function(recipe)
        -- 清空原有材料
        recipe.ingredients = {}
        -- 添加新材料：4个生物数据 + 2个寒冰护符 + 2个紫宝石 + 1个巨鹿眼球
        recipe.ingredients = {
            Ingredient("scandata", 4),
            Ingredient("blueamulet", 1),
            -- Ingredient("purplegem", 2),
            -- Ingredient("deerclops_eyeball", 1), -- 巨鹿眼球
        }
    end)
end

-- 2025.11.29 YeFeng: 新增热能电路的第二个配方（太阳鱼）
AddRecipe2("wx78module_heat_fish", {
    Ingredient("scandata", 4),
    Ingredient("amulet", 1),
    -- Ingredient("purplegem", 2),
    Ingredient("oceanfish_small_8_inv", 2), -- 太阳鱼×1
}, TECH.ROBOTMODULECRAFT_ONE, {
    builder_tag = "upgrademoduleowner",
    product = "wx78module_heat",
    nounlock = false,
}, {"CHARACTER"})

-- 2025.11.29 YeFeng: 新增制冷电路的第二个配方（冰雕鱼）
AddRecipe2("wx78module_cold_fish", {
    Ingredient("scandata", 4),
    -- Ingredient("blueamulet", 1),
    -- Ingredient("purplegem", 2),
    Ingredient("oceanfish_medium_8_inv", 1), -- 冰雕鱼×1
}, TECH.ROBOTMODULECRAFT_ONE, {
    builder_tag = "upgrademoduleowner",
    product = "wx78module_cold",
    nounlock = false,
}, {"CHARACTER"})

-- 2025.11.30 YeFeng: 同步解锁逻辑
-- 当玩家解锁“第二配方”电路时，自动解锁“第一配方”电路，反之亦然。
AddPrefabPostInit("wx78", function(inst)
    if not TheWorld.ismastersim then
        return
    end
    inst:ListenForEvent("unlockrecipe", function(inst, data)
        if data and data.recipe then
            local builder = inst.components.builder
            if not builder then return end
            -- 热能电路同步
            if data.recipe == "wx78module_heat_fish" then
                if not builder:KnowsRecipe("wx78module_heat") then
                    builder:UnlockRecipe("wx78module_heat")
                end
            elseif data.recipe == "wx78module_heat" then
                if not builder:KnowsRecipe("wx78module_heat_fish") then
                    builder:UnlockRecipe("wx78module_heat_fish")
                end
                -- 制冷电路同步
            elseif data.recipe == "wx78module_cold_fish" then
                if not builder:KnowsRecipe("wx78module_cold") then
                    builder:UnlockRecipe("wx78module_cold")
                end
            elseif data.recipe == "wx78module_cold" then
                if not builder:KnowsRecipe("wx78module_cold_fish") then
                    builder:UnlockRecipe("wx78module_cold_fish")
                end
            end
        end
    end)
end)

-- 电气化电路伤害削弱
TUNING.SKILLS.WX78.TASER_BUILDUP_DAMAGE = TUNING.SKILLS.WX78.TASER_BUILDUP_DAMAGE * 3 / 5
local oldelemult = TUNING.ELECTRIC_DAMAGE_MULT
local oldelewetmult = TUNING.ELECTRIC_WET_DAMAGE_MULT
AddPrefabPostInit("wx78module_taser", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.upgrademodule then
        local oldonactivatedfn = inst.components.upgrademodule.onactivatedfn
        inst.components.upgrademodule.onactivatedfn = function(inst, wx, ...)
            if oldonactivatedfn then oldonactivatedfn(inst, wx, ...) end
            if not inst.onactivated2hm then
                inst.onactivated2hm = true
                inst:RemoveEventCallback("blocked", inst._onblocked, wx)
                inst:RemoveEventCallback("attacked", inst._onblocked, wx)
                local oldfn = inst._onblocked
                inst._onblocked = function(owner, data)
                    TUNING.ELECTRIC_DAMAGE_MULT = oldelemult - 0.25
                    TUNING.ELECTRIC_WET_DAMAGE_MULT = oldelewetmult - 0.75
                    if oldfn then oldfn(owner, data) end
                    TUNING.ELECTRIC_DAMAGE_MULT = oldelemult
                    TUNING.ELECTRIC_WET_DAMAGE_MULT = oldelewetmult
                end
                inst:ListenForEvent("blocked", inst._onblocked, wx)
                inst:ListenForEvent("attacked", inst._onblocked, wx)
            end
        end

        local oldondeactivatedfn = inst.components.upgrademodule.ondeactivatedfn
        inst.components.upgrademodule.ondeactivatedfn = function(inst, ...)
            if inst.onactivated2hm == true then inst.onactivated2hm = nil end
            if oldondeactivatedfn then oldondeactivatedfn(inst, ...) end
        end
    end
end)

-- 无人机可被攻击且被攻击会消耗耐久
-- local function reducecharge(inst, data)
--     if data and data.attacker and data.attacker:IsValid() and not data.attacker:HasTag("player") and data.damage > 0 then
--         local remote = inst.owner and inst.owner:value()
--         if remote and remote:IsValid() and remote.components.finiteuses then
--             remote.components.finiteuses:Use(math.ceil(data.damage * 0.1))
--         end
--     end 
-- end
-- AddPrefabPostInit("wx78_drone_zap", function(inst)
--     if not TheWorld.ismastersim then return end
--     if not inst.components.combat then inst:AddComponent("combat") end
--     if not inst.components.health then inst:AddComponent("health") end
--     inst.components.health:SetInvincible(true)
--     local hitfn = inst.components.combat.onhitfn
--     inst.components.combat.onhitfn = function(inst, attacker, damage, spdamage, ...)
--         if damage > 0 or spdamage ~= nil then
--             -- local owner = inst.owner:value()
--             -- if owner then
--             --     local selfremote = owner.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
--             --     if selfremote and selfremote.prefab == "wx78_drone_zap_remote" and selfremote.components.finiteuses and selfremote.components.finiteuses:GetPercent() > 0 then
--             --         selfremote.components.finiteuses:Use(owner.components.skilltreeupdater and 
--             --         owner.components.skilltreeupdater:IsActivated("wx78_zapdrone_2") and
--             --         TUNING.SKILLS.WX78.ZAPDRONE_USE_PER_ATTACK_2 or
--             --         TUNING.SKILLS.WX78.ZAPDRONE_USE_PER_ATTACK_1)
--             --     end
--             -- end
--             reducecharge(inst, {attacker = attacker, damage = damage, spdamage = spdamage})
--         end
--         return hitfn(inst, attacker, damage, spdamage, ...)
--     end
-- end)

-- 被投掷物攻击飞行目标或巨兽会尝试仇恨无人机
require("stategraphs/commonstates")
AddPrefabPostInit("wx78_drone_zap_projectile_fx", function(inst)
    if not TheWorld.ismastersim then return end
    if inst._OnAttackedTarget then
        local oldfn = inst._OnAttackedTarget
        inst._OnAttackedTarget = function(inst, target, ...)
            oldfn(inst, target, ...)
            if target and target:IsValid() and (target:HasTag("flying") or target:HasTag("epic")) and inst.caster and inst.caster:IsValid() and
            target.components.combat and not target.components.combat:HasTarget() then
                target.components.combat:SuggestTarget(inst.caster)
            end
        end
    end
    if inst._CheckTarget then 
        local oldchecktargetfn = inst._CheckTarget
        inst._CheckTarget = function(inst, target, ...)
            local canattack = oldchecktargetfn(inst, target, ...)
            if canattack then
                if CommonHandlers.ElectrocuteRecoveryDelay and CommonHandlers.ElectrocuteRecoveryDelay(target) then
                    if IsEntityElectricImmune(target) then
                        inst.components.combat:SetDefaultDamage(inst.damage * inst.insulated_dmg_mult)
                        inst.components.combat:DoAttack(target, nil, nil, "electric")
                        inst.components.combat:SetDefaultDamage(inst.damage)
                    else
                        inst.components.combat:DoAttack(target, nil, nil, "electric")
                    end
                    inst.targets[target] = true
                    if inst._OnAttackedTarget then
                        inst:_OnAttackedTarget(target)
                    end
                    return false
                else
                    return true
                end
            end
            return canattack
        end
    end
end)

-- 被附加冰冻层数现在也会减少电量了
local function hardmodechangefreezefn2hm(inst)
    if inst.components.freezable and not inst.components.freezable.hardmodechangefreezefn2hm then
        inst.components.freezable.hardmodechangefreezefn2hm = true
        local oldfn = inst.components.freezable.onfreezefn
        inst.components.freezable.onfreezefn = function(inst, ...)
            if not inst.nochargereduce2hm then inst.nochargereduce2hm = true end
            if oldfn then oldfn(inst, ...) end
            inst.nochargereduce2hm = nil
        end
        local oldaddcoldfn = inst.components.freezable.AddColdness
        inst.components.freezable.AddColdness = function(self, coldness, ...)
            if inst.components.upgrademoduleowner and coldness and coldness >= 1 then
                local mult = 1
                local resistance = self:ResolveResistance()
                local reduecharge = -(TUNING.WX78_FROZEN_CHARGELOSS/2) / resistance * coldness
                if self.redirectfn ~= nil and self.redirectfn(self.inst, coldness, ...) then mult = 0.8 end
                if self.inst._cold_modcount ~= nil and self.inst._cold_modcount > 0 then mult = mult + self.inst._cold_modcount end
                inst.components.upgrademoduleowner:DoDeltaCharge(reduecharge * mult)
            end
            return oldaddcoldfn(self, coldness, ...)
        end
    end
end

AddPrefabPostInit("wx78", function(inst)
    if not TheWorld.ismastersim then
        return
    end
    inst:ListenForEvent("respawnfromghost", function(inst, data)
        inst:DoTaskInTime(0, hardmodechangefreezefn2hm)
    end)
    inst:DoTaskInTime(0, hardmodechangefreezefn2hm)
    inst:DoTaskInTime(3, function()
        if inst.components.combat then
            local num = inst.components.combat.externaldamagetakenmultipliers:CalculateModifierFromKey("maxhealthmoduleskill")
            if num then
                inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, math.max(0.75, num), "maxhealthmoduleskill")
            end
        end
    end)
end)

-- 合唱盒电路每个限制雇佣两个随从且猪王守卫不再跟随
AddPrefabPostInit("wx78module_music", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.upgrademodule then
        local oldfn = inst.components.upgrademodule.onactivatedfn
        inst.components.upgrademodule.onactivatedfn = function(inst, wx, ...)
            oldfn(inst, wx, ...)
            inst:DoTaskInTime(0, function()
                if wx.components.leaderrollcall then
                    wx.components.leaderrollcall:SetMaxFollowers((wx._music_modules or 0) * 2)
                    local CANT_TAGS = UpvalueHacker.GetUpvalue(wx.components.leaderrollcall.DoRollCall, "CANT_TAGS")
                    if CANT_TAGS and not table.contains(CANT_TAGS, "guard") then
                        table.insert(CANT_TAGS, "guard")
                    end
                end
            end)
        end
    end
end)

-- 食用燃料会根据所插入的暗影材料扣除对应理智上限
local function removtask(ent)
    if ent.components.sanity then
        ent.components.sanity:RemoveSanityPenalty("wx78_shadow_fuel_debuff2hm")
    end
    ent.removesanitypenaltytask2hm = nil
end

-- 纯度越高抵抗效果越好
local percent = {
    [SOCKETQUALITY.LOW] = 0.3,
    [SOCKETQUALITY.MEDIUM] = 0.2,
    [SOCKETQUALITY.HIGH] = 0.1,
    [SOCKETQUALITY.PERFECT] = 0,
}

AddPrefabPostInit("wx78_shadow_fuel_debuff", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.components.debuff then
        local oldonattachedfn = inst.components.debuff.onattachedfn
        inst.components.debuff.onattachedfn = function(inst, target, ...)
            local socketquality = target.components.socketholder:GetHighestQualitySocketed(SOCKETNAMES.SHADOW)
            local sanreduce_percent = percent[socketquality] or 0.4
            if target.components.sanity then
                if target.removesanitypenaltytask2hm then
                    target.removesanitypenaltytask2hm:Cancel()
                end
                local oldPenaltyPercent = target.components.sanity:GetPenaltyPercent()
                local change = math.min(0.8, oldPenaltyPercent + sanreduce_percent)
                target.components.sanity:AddSanityPenalty("wx78_shadow_fuel_debuff2hm", change)
                target.components.sanity:DoDelta(-(target.components.sanity:GetMaxWithPenalty() * sanreduce_percent))
            end
            return oldonattachedfn(inst, target, ...)
        end
        local oldonextendedfn = inst.components.debuff.onextendedfn
        inst.components.debuff.onextendedfn = function(inst, target, ...)
            local socketquality = target.components.socketholder:GetHighestQualitySocketed(SOCKETNAMES.SHADOW)
            local sanreduce_percent = percent[socketquality] or 0.4
            if target.components.sanity then
                if target.removesanitypenaltytask2hm then
                    target.removesanitypenaltytask2hm:Cancel()
                end
                local oldPenaltyPercent = target.components.sanity:GetPenaltyPercent()
                local change = math.min(0.8, oldPenaltyPercent + sanreduce_percent)
                target.components.sanity:AddSanityPenalty("wx78_shadow_fuel_debuff2hm", change)
                target.components.sanity:DoDelta(-(target.components.sanity:GetMaxWithPenalty() * sanreduce_percent))
            end
            return oldonextendedfn(inst, target, ...)
        end
        local oldondetachedfn = inst.components.debuff.ondetachedfn
        inst.components.debuff.ondetachedfn = function(inst, target, ...)
            if target.removesanitypenaltytask2hm then
                target.removesanitypenaltytask2hm:Cancel()
            end
            target.removesanitypenaltytask2hm = target:DoTaskInTime(10, removtask)
            return oldondetachedfn(inst, target, ...)
        end
    end
end)