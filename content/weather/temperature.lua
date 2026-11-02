local temperature_change = GetModConfigData("temperature_change") -- 值为-1 或 -2
TUNING.OVERHEAT_TEMP = TUNING.OVERHEAT_TEMP + temperature_change * 5
-- 2025.8.2 melon:辣龙椒沙拉  温度维持-5/-10度，避免冬天第一天吃屏幕周围一直有特效
TUNING.HOT_FOOD_WARMING_THRESHOLD = TUNING.HOT_FOOD_WARMING_THRESHOLD + temperature_change * 5
TUNING.COLDHEAT_TEMP2hm = -temperature_change * 5
local temperature_rate = temperature_change * 240

local function newIsFreezing(self) return self.current < self.coldtemp2hm end
local function resetmax(_, insulation) return insulation end
local function shortGetInsulation(self)
    local oldGetInsulation = self.processdata2hm and self.processdata2hm.GetInsulation or self.GetInsulation
    if self.calc2hm then return oldGetInsulation(self) end
    self.calc2hm = true
    -- 应用保暖隔热
    local oldmax = math.max
    math.max = resetmax
    local winterInsulation, summerInsulation = oldGetInsulation(self)
    math.max = oldmax
    if not (self.inst.weremode and self.inst.weremode:value() ~= 0) then
        winterInsulation = winterInsulation + temperature_rate
        summerInsulation = summerInsulation + temperature_rate
    end
    -- 下列修改仅生效于：环境温度大于35且玩家正在升温，或环境温度小于35且玩家正在降温
    if TheWorld.state.season == "winter" then
        -- 冬季负保暖降温更快，降温速度最快有原版的3倍
        if winterInsulation < 0 then
            if winterInsulation >= -120 then
                -- -120时1.5倍降温速率，-10
                winterInsulation = winterInsulation / 12
            elseif winterInsulation >= -240 then
                -- -240时2倍降温速率，-15
                winterInsulation = winterInsulation / 24 - 5
            else
                -- -480时3倍降温速率，-20
                winterInsulation = math.max(-480, winterInsulation)
                winterInsulation = winterInsulation / 48 - 10
            end
        end
        summerInsulation = math.max(summerInsulation, 0)
    elseif TheWorld.state.season == "summer" then
        -- 夏季负隔热升温更快，升温速度最快有原版的3倍
        if summerInsulation < 0 then
            if summerInsulation >= -120 then
                summerInsulation = summerInsulation / 12
            elseif summerInsulation >= -240 then
                summerInsulation = summerInsulation / 24 - 5
            else
                summerInsulation = math.max(-480, summerInsulation)
                summerInsulation = summerInsulation / 48 - 10
            end
        end
        winterInsulation = math.max(winterInsulation, 0)
    else
        summerInsulation = math.max(summerInsulation, 0)
        winterInsulation = math.max(winterInsulation, 0)
    end
    self.calc2hm = nil
    return winterInsulation, summerInsulation
end
local function processSetTemperature(self)
    if self.processdata2hm then return end
    self.processdata2hm = {}
    self.processdata2hm.GetInsulation = self.GetInsulation
    self.GetInsulation = shortGetInsulation
    -- self.processdata2hm.SEG_TIME = TUNING.SEG_TIME
    -- TUNING.SEG_TIME = 100
end
local function endprocessSetTemperature(self)
    if self.processdata2hm then
        -- TUNING.SEG_TIME = self.processdata2hm.SEG_TIME
        self.GetInsulation = self.processdata2hm.GetInsulation
        self.processdata2hm = nil
    end
end


-- 2026.2.15 YeFeng: 防重入修复，解决与永不妥协热能电路叠加导致温度瞬间飙升90°的问题
-- 原因：永不妥协监听temperaturedelta将温度增量放大4倍后回调SetTemperature，
-- 而原版newSetTemperature每次都推送temperaturedelta事件，导致循环放大
-- local function newSetTemperature(self, value, ...)
--     endprocessSetTemperature(self)
--     local last = self.current
--     self.current = value
--     if (self.current < self.coldtemp2hm) ~= (last < self.coldtemp2hm) then
--         self.inst:PushEvent(self.current < self.coldtemp2hm and "startfreezing" or "stopfreezing")
--     end
--     if (self.current > self.overheattemp) ~= (last > self.overheattemp) then
--         self.inst:PushEvent(self.current > self.overheattemp and "startoverheating" or "stopoverheating")
--     end
--     self.inst:PushEvent("temperaturedelta", {last = last, new = self.current})
-- end
local function newSetTemperature(self, value, ...) 
    endprocessSetTemperature(self)
    -- 防重入：其他模组监听temperaturedelta后再调SetTemperature时只静默赋值，避免循环放大
    if self._settingtemp2hm then
        self.current = value
        return
    end
    self._settingtemp2hm = true
    local last = self.current
    self.current = value
    if (self.current < self.coldtemp2hm) ~= (last < self.coldtemp2hm) then
        self.inst:PushEvent(self.current < self.coldtemp2hm and "startfreezing" or "stopfreezing")
    end
    if (self.current > self.overheattemp) ~= (last > self.overheattemp) then
        self.inst:PushEvent(self.current > self.overheattemp and "startoverheating" or "stopoverheating")
    end
    self.inst:PushEvent("temperaturedelta", {last = last, new = self.current})
    -- 重入可能已修改self.current（如永不妥协热能电路放大温度）
    -- 补推最终温度事件，此时_settingtemp2hm仍为true所以不会再次循环
    local final = self.current
    if final ~= value then
        if (final < self.coldtemp2hm) ~= (value < self.coldtemp2hm) then
            self.inst:PushEvent(final < self.coldtemp2hm and "startfreezing" or "stopfreezing")
        end
        if (final > self.overheattemp) ~= (value > self.overheattemp) then
            self.inst:PushEvent(final > self.overheattemp and "startoverheating" or "stopoverheating")
        end
        self.inst:PushEvent("temperaturedelta", {last = value, new = final})
    end
    self._settingtemp2hm = nil
end


AddComponentPostInit("temperature", function(self)
    if self.inst:HasTag("player") then
        self.coldtemp2hm = TUNING.COLDHEAT_TEMP2hm
        self.IsFreezing = newIsFreezing
        self.SetTemperature = newSetTemperature
        local DoDelta = self.DoDelta
        self.DoDelta = function(self, delta, ...)
            processSetTemperature(self)
            DoDelta(self, delta, ...)
            endprocessSetTemperature(self)
        end
        local OnUpdate = self.OnUpdate
        self.OnUpdate = function(self, dt, applyhealthdelta, ...)
            processSetTemperature(self)
            OnUpdate(self, dt, false, ...)
            endprocessSetTemperature(self)
            if applyhealthdelta ~= false and self.inst.components.health ~= nil then
                if self.current < self.coldtemp2hm then
                    self.inst.components.health:DoDelta(-self.hurtrate * dt, true, "cold")
                elseif self.current > self.overheattemp then
                    self.inst.components.health:DoDelta(-(self.overheathurtrate or self.hurtrate) * dt, true, "hot")
                end
            end
        end
    end
end)

local function newIsFreezing_player(inst)
    if not inst.components.temperature and inst.player_classified ~= nil then return inst.player_classified.currenttemperature < TUNING.COLDHEAT_TEMP2hm end
    return inst.oldIsFreezing2hm(inst)
end
AddPlayerPostInit(function(inst)
    inst.oldIsFreezing2hm = inst.IsFreezing
    inst.IsFreezing = newIsFreezing_player
end)

local function OnTemperatureDirty(inst)
    if not inst._oldtemperature2hm then
        inst._oldtemperature2hm = inst.currenttemperature
        return
    end
    if inst._oldtemperature2hm < 0 then
        if inst.currenttemperature >= 0 and inst.currenttemperature <= TUNING.COLDHEAT_TEMP2hm then inst._parent:PushEvent("startfreezing") end
    elseif inst._oldtemperature2hm < TUNING.COLDHEAT_TEMP2hm then
        if inst.currenttemperature >= TUNING.COLDHEAT_TEMP2hm then inst._parent:PushEvent("stopfreezing") end
    elseif inst.currenttemperature < TUNING.COLDHEAT_TEMP2hm then
        inst._parent:PushEvent("startfreezing")
    end
    inst._oldtemperature2hm = inst.currenttemperature
end
local function resettemperaturedirty(inst)
    inst:ListenForEvent("temperaturedirty", OnTemperatureDirty)
    OnTemperatureDirty(inst)
end
AddPrefabPostInit("player_classified", function(inst) inst:DoStaticTaskInTime(0, resettemperaturedirty) end)

-- 冰霜特效
local showice = TUNING.COLDHEAT_TEMP2hm
local ice_thresh = {showice + 5, showice, showice - 5, showice - 10}
local freeze_sounds = {"dontstarve/winter/freeze_1st", "dontstarve/winter/freeze_2nd", "dontstarve/winter/freeze_3rd", "dontstarve/winter/freeze_4th"}
local num_steps = 4
AddClassPostConstruct("widgets/iceover", function(self)
    self.OnIceChange = function()
        local temp = self.owner.components.temperature ~= nil and self.owner.components.temperature:GetCurrent() or
                         (self.owner.player_classified ~= nil and self.owner.player_classified.currenttemperature or TUNING.STARTING_TEMP)
        local isup = false
        while ice_thresh[self.laststep + 1] ~= nil and temp < ice_thresh[self.laststep + 1] and self.laststep < num_steps and
            (temp < ice_thresh[1] or TheWorld.state.iswinter or GetLocalTemperature(self.owner) < (TUNING.COLDHEAT_TEMP2hm + ice_thresh[1])) do
            self.laststep = self.laststep + 1
            isup = true
        end
        if isup then
            TheFrontEnd:GetSound():PlaySound(freeze_sounds[self.laststep])
        else
            while ice_thresh[self.laststep] ~= nil and temp > ice_thresh[self.laststep] and self.laststep > 0 do self.laststep = self.laststep - 1 end
        end
        if self.laststep == 0 then
            self.alpha_min_target = 1
        else
            local alpha_mins = {.7, .5, .3, 0}
            self.alpha_min_target = alpha_mins[self.laststep]
            self:StartUpdating()
        end
    end
end)
-- 过热特效
local showheat = TUNING.OVERHEAT_TEMP
local heat_thresh = {showheat - 5, showheat, showheat + 5, showheat + 10}
local heat_sounds = {
    "dontstarve_DLC001/common/HUD_hot_level1",
    "dontstarve_DLC001/common/HUD_hot_level2",
    "dontstarve_DLC001/common/HUD_hot_level3",
    "dontstarve_DLC001/common/HUD_hot_level4"
}
local heat_sounds_names = {"HUD_hot_level1", "HUD_hot_level2", "HUD_hot_level3", "HUD_hot_level4"}
AddClassPostConstruct("widgets/heatover", function(self)
    -- local OnIceChange = self.OnIceChange
    self.OnHeatChange = function()
        local temp = self.owner.components.temperature ~= nil and self.owner.components.temperature:GetCurrent() or
                         (self.owner.player_classified ~= nil and self.owner.player_classified.currenttemperature or TUNING.STARTING_TEMP)
        local up_thresh = heat_thresh[self.laststep + 1]
        local down_thresh = heat_thresh[self.laststep]
        local isup = false
        while heat_thresh[self.laststep + 1] ~= nil and temp > heat_thresh[self.laststep + 1] and self.laststep < num_steps and
            (temp >= heat_thresh[1] or TheWorld.state.issummer or GetLocalTemperature(self.owner) >= heat_thresh[1]) do
            self.laststep = self.laststep + 1
            isup = true
        end
        if isup then
            if not TheFrontEnd:GetSound():PlayingSound(heat_sounds_names[self.laststep]) then
                TheFrontEnd:GetSound():PlaySound(heat_sounds[self.laststep], heat_sounds_names[self.laststep])
            end
        else
            while heat_thresh[self.laststep] ~= nil and temp < heat_thresh[self.laststep] and self.laststep > 0 do self.laststep = self.laststep - 1 end
        end
        if self.laststep == 0 then
            self.alpha_min_target = 1
        else
            local alpha_mins = {.4, .3, .1, 0}
            self.alpha_min_target = alpha_mins[self.laststep]
            local distortion_size = {0.01, 0.011, 0.012, 0.013}
            self.effectSize_target = distortion_size[self.laststep]
            local distortion_frequency = {10, 13, 17, 20}
            self.effectFrequency_target = distortion_frequency[self.laststep]
            local distortion_speed = {7, 7, 7, 7}
            self.effectSpeed = distortion_speed[self.laststep]
            self:StartUpdating()
        end
    end
end)

-- 暖石改动,保温不再那么强,同时可以放到谢天翁水壶里
local rate = 0.75 + temperature_change * 0.25
local function newheatfn(inst, observer, ...)
    return inst.oldheatfn2hm(inst, observer, ...) * rate / 2 + inst.components.temperature:GetCurrent() * (1 - rate) / 2 + TheWorld.state.temperature * 0.5
end
local function newcarriedheatfn(inst, observer, ...)
    return inst.oldcarriedheatfn2hm(inst, observer, ...) * rate + inst.components.temperature:GetCurrent() * (1 - rate)
end
local heatrockitems = {"heatrock", "dumbbell_heat", "icire_rock"}
for index, heatrock in ipairs(heatrockitems) do
    AddPrefabPostInit(heatrock, function(inst)
        if not TheWorld.ismastersim or not inst.components.heater or not inst.components.temperature then return inst end
        if inst.components.heater.heatfn then
            inst.oldheatfn2hm = inst.components.heater.heatfn
            inst.components.heater.heatfn = newheatfn
        end
        if inst.components.heater.carriedheatfn then
            inst.oldcarriedheatfn2hm = inst.components.heater.carriedheatfn
            inst.components.heater.carriedheatfn = newcarriedheatfn
        end
    end)
end
if TUNING.DSTU then
    local function premiumwateringcanupdate(inst, data)
        if inst:IsValid() and inst.components.container then
            local heatrocks = {}
            local hotfish = {}
            local coldfish = {}
            for i = 1, inst.components.container.numslots do
                local item = inst.components.container.slots[i]
                if item and item:IsValid() then
                    if table.contains(heatrockitems, item.prefab) then
                        table.insert(heatrocks, item)
                    elseif item.prefab == "oceanfish_medium_8_inv" then
                        table.insert(coldfish, item)
                    elseif item.prefab == "oceanfish_small_8_inv" then
                        table.insert(hotfish, item)
                    end
                end
            end
            if #heatrocks <= 0 then return end
            local tempModifier = (#hotfish - #coldfish) * 25
            for _, item in ipairs(heatrocks) do
                if item._light and not item._light:IsInLimbo() then item._light:RemoveFromScene() end
                if item.components.temperature then item.components.temperature:SetModifier("premiumwateringcan2hm", tempModifier / #heatrocks) end
            end
        end
    end
    local function premiumwateringcanloseitem(inst, data)
        if data and data.prev_item and data.prev_item:IsValid() and table.contains(heatrockitems, data.prev_item.prefab) and
            data.prev_item.components.temperature then
            data.prev_item.components.temperature:RemoveModifier("premiumwateringcan2hm")
            if inst.components.finiteuses and inst.components.finiteuses:GetPercent() > 0.15 and data.prev_item.components.inventoryitem then
                data.prev_item.components.inventoryitem:EnableMoisture(true)
                data.prev_item.components.inventoryitemmoisture:SetMoisture(inst.components.finiteuses:GetPercent() * 100)
            end
        end
        premiumwateringcanupdate(inst)
    end
    local function premiumwateringcangetitem(inst, data)
        if data and data.item and data.item:IsValid() and table.contains(heatrockitems, data.item.prefab) and data.item.components.temperature then
            if data.item.components.inventoryitem then data.item.components.inventoryitem:EnableMoisture(false) end
            if data.item._light and not data.item._light:IsInLimbo() then data.item._light:RemoveFromScene() end
        end
        premiumwateringcanupdate(inst)
    end
    AddPrefabPostInit("premiumwateringcan", function(inst)
        inst:AddTag("buried")
        if not TheWorld.ismastersim then return end
        if inst.components.container then
            inst:DoTaskInTime(0, premiumwateringcanupdate)
            inst:ListenForEvent("itemget", premiumwateringcangetitem)
            inst:ListenForEvent("itemlose", premiumwateringcanloseitem)
        end
    end)
    local containers = require("containers")
    local old_wsetup = containers.widgetsetup
    containers.widgetsetup = function(container, prefab, data, ...)
        old_wsetup(container, prefab, data, ...)
        if prefab == "frigginbirdpail" and container.itemtestfn then
            local old = container.itemtestfn
            container.itemtestfn = function(c, item, ...) return old(c, item, ...) or table.contains(heatrockitems, item.prefab) end
        end
    end
    -- if containers and containers.params and containers.params.fish_box and containers.params.fish_box.itemtestfn then
    --     local old = containers.params.fish_box.itemtestfn
    --     containers.params.fish_box.itemtestfn = function(c, item, ...) return old(c, item, ...) and not table.contains(heatrockitems, item.prefab) end
    -- end
    -- 妥协带格子的装备有一个背包图标
    AddPrefabPostInitAny(function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.equippable and inst.components.container and
            (inst.components.equippable.equipslot == EQUIPSLOTS.BODY or inst.components.equippable.equipslot == EQUIPSLOTS.BACKPACK) and not inst.MiniMapEntity then
            local icon = SpawnPrefab("backpackicon2hm")
            if icon then icon:TrackEntity(inst) end
        end
    end)
end

-- 树果酱
local errortext = TUNING.isCh2hm and "我还需要1个铥矿和1个蓝宝石" or "I need a thulecite and a blue gem"
local function talkerror(inst) if inst.components.talker then inst.components.talker:Say(errortext) end end
local oceantreeprefabs = {"oceantree", "oceantree_normal", "oceantree_tall", "oceantree_short"}
local ADVANCE_TREE_GROWTHfn = ACTIONS.ADVANCE_TREE_GROWTH.fn
ACTIONS.ADVANCE_TREE_GROWTH.fn = function(act)
    if act.target and table.contains(oceantreeprefabs, act.target.prefab) and
        not (act.target:HasTag("no_force_grow") or act.target:HasTag("stump") or act.target:HasTag("fire") or act.target:HasTag("burnt")) then
        if act.doer and act.doer.components.inventory and act.doer.components.inventory:Has("bluegem", 1) and act.doer.components.inventory:Has("thulecite", 1) then
            act.doer.components.inventory:ConsumeByName("bluegem", 1)
            act.doer.components.inventory:ConsumeByName("thulecite", 1)
        else
            if act.doer and act.doer.components.talker then act.doer:DoTaskInTime(0, talkerror) end
            return false
        end
    end
    return ADVANCE_TREE_GROWTHfn(act)
end

-- 蘑菇树有温度
AddPrefabPostInit("mushtree_tall", function(inst)
    if not TheWorld.ismastersim then return end
    if not inst.components.heater then
        inst:AddComponent("heater")
        inst.components.heater.heat = 25
        inst.components.heater:SetThermics(false, true)
    end
end)
AddPrefabPostInit("mushtree_medium", function(inst)
    if not TheWorld.ismastersim then return end
    if not inst.components.heater then
        inst:AddComponent("heater")
        inst.components.heater.heat = 45
    end
end)

local iceholetemp = {spring = -50, summer = 0, winter = -100, autumn = -50}
local function iceholeHeatFn(inst, observer) return iceholetemp[TheWorld.state.season] or -50 end
AddPrefabPostInit("icefishing_hole", function(inst)
    if not TheWorld.ismastersim then return end
    if not inst.components.heater then
        inst:AddComponent("heater")
        inst.components.heater.heat = -50
        inst.components.heater.heatfn = iceholeHeatFn
        inst.components.heater:SetThermics(false, true)
    end
end)
