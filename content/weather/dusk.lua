local dusk_mode = GetModConfigData("dusk_change")
local dangerversion = GetModConfigData("dusk_change") == -1
-- 岛屿冒险兼容
local SW, HAM
for i,mod in ipairs(ModManager.mods) do
    local modinfo = KnownModIndex:GetModInfo(mod.modname)
    if modinfo.ia_shipwrecked then
        SW = true
    elseif modinfo.ia_hamlet then
        HAM = true
    end
    if SW and HAM then break end
end
if HAM then return end

-- -- 妥协晨星锤放人偶上不再照明
-- if TUNING.DSTU then
--     local function onequiptomodel(inst, owner)
--         if owner and owner:HasTag("equipmentmodel") then
--             if inst.fire ~= nil then inst.fire:Remove() end
--             if inst._fire ~= nil then inst._fire:Remove() end
--             if inst.components.burnable then inst.components.burnable:Extinguish() end
--             if inst.components.fueled then inst.components.fueled:StopConsuming() end
--         end
--     end
--     local function onequip(inst, data)
--         if data and data.owner and data.owner:HasTag("equipmentmodel") then inst:DoTaskInTime(0, onequiptomodel, data.owner) end
--     end
--     AddPrefabPostInit("nightstick", function(inst)
--         if not TheWorld.ismastersim then return end
--         inst:ListenForEvent("equipped", onequip)
--     end)
-- end

-- 非独行长路或非单世界时,玩家仅屏幕范围内有圆形范围光照,理智越低(护符骨头头盔除外)光照范围越低,屏幕范围外统统最差光照,即使白天,理智低时也能漆黑一片...
-- AddPrefabPostInit("world", function(inst)
--     if not inst.ismastersim then
--         local SetAmbientColour = getmetatable(TheSim).__index["SetAmbientColour"]
--         getmetatable(TheSim).__index["SetAmbientColour"] = function(self, cx, cy, cz, ...)
--             if TUNING.oldPVP2hm then
--                 return SetAmbientColour(self, cx, cy, cz, ...)
--             else
--                 return true
--             end
--         end
--     end
-- end)

-- 长夜模式
if dusk_mode == true then
    local mindusks = {autumn = 2, winter = 1, spring = 3, summer = nil}
    if SW then mindusks = {mild = 2, wet = 1, green = 3, dry = nil} end
    AddComponentPostInit("clock", function(self)
        if TheWorld and TheWorld.ismastersim and TheWorld.event_listeners then
            if TheWorld.event_listeners.ms_setclocksegs then
                for k, value in pairs(TheWorld.event_listeners.ms_setclocksegs) do
                    for index, fn in pairs(value) do
                        local newfn = function(_inst, data, ...)
                            if data and data.day and data.dusk and data.night and data.day > 0 and data.night > 0 then
                                local dusklength = mindusks[TheWorld and TheWorld.state and TheWorld.state.season or "autumn"]
                                if dusklength and data.dusk >= dusklength then
                                    data.night = data.night + data.dusk - dusklength
                                    data.dusk = dusklength
                                end
                            end
                            fn(_inst, data, ...)
                        end
                        value[index] = newfn
                    end
                end
            end
            if SW and TheWorld.event_listeners.ms_setclocksegs_tropical then
                for k, value in pairs(TheWorld.event_listeners.ms_setclocksegs_tropical) do
                    for index, fn in pairs(value) do
                        local newfn = function(_inst, data, ...)
                            if data and data.day and data.dusk and data.night and data.day > 0 and data.night > 0 then
                                local dusklength = mindusks[TheWorld and TheWorld.state and TheWorld.state.season or "autumn"]
                                if dusklength and data.dusk >= dusklength then
                                    data.night = data.night + data.dusk - dusklength
                                    data.dusk = dusklength
                                end
                            end
                            fn(_inst, data, ...)
                        end
                        value[index] = newfn
                    end
                end
            end
        end
    end)
    -- 绿蘑菇下雨长出来
    local function Onisraining(inst, israining)
        if israining then
            if inst.components.pickable ~= nil and inst.components.pickable:CanBePicked() then
                if inst.growtask then inst.growtask:Cancel() end
                inst.growtask = inst:DoTaskInTime(2 + math.random() * 3, inst.opentaskfn)
            end
        elseif not TheWorld.state.isdusk and not TheWorld.state.iscavedusk then
            if inst.components.pickable ~= nil and inst.components.pickable:CanBePicked() then
                if inst.growtask then inst.growtask:Cancel() end
                inst.growtask = inst:DoTaskInTime(1 + math.random() * 3, inst.closetaskfn)
            end
        end
    end
    local function OnIsOpenPhase(inst, isopen) if not isopen and TheWorld.state.israining and inst.growtask then inst.growtask:Cancel() end end
    AddPrefabPostInit("green_mushroom", function(inst)
        if not TheWorld.ismastersim then return end
        inst:WatchWorldState("israining", Onisraining)
        inst:WatchWorldState("iscavedusk", OnIsOpenPhase)
    end)
end

-- 漆黑黄昏模式
if dusk_mode ~= true then
    -- 黄昏不再有光照
    local ambientlightingsource = "scripts/components/ambientlighting.lua"
    AddComponentPostInit("ambientlighting", function(self)
        local inst = self.inst
        local _phasechanged
        local index = 1
        for i, func in ipairs(inst.event_listening["phasechanged"][inst]) do
            if GLOBAL.debug.getinfo(func, "S").source == ambientlightingsource then
                index = i
                break
            end
        end
        _phasechanged = inst.event_listening["phasechanged"][inst][index]
        if _phasechanged then
            inst:ListenForEvent("phasechanged", function(src, phase, ...) if phase == "dusk" then _phasechanged(src, "night", ...) end end)
            inst:DoTaskInTime(1.25, function() if TheWorld.state.phase == "dusk" then _phasechanged(TheWorld, "night") end end)
        end
    end)
    -- 妥协暗夜灯黄昏就开始工作
    AddPrefabPostInit("nightlight", function(inst)
        if not TheWorld.ismastersim or TheWorld:HasTag("cave") then return inst end
        if inst.components.playerprox and inst.components.playerprox.onnear then
            local oldonnear = inst.components.playerprox.onnear
            inst.components.playerprox.onnear = function(inst, ...)
                oldonnear(inst, ...)
                if inst.task and inst.task.fn then
                    local oldfn = inst.task.fn
                    inst.task.fn = function(inst, ...)
                        local oldisnight = TheWorld.state.isnight
                        TheWorld.state.isnight = TheWorld.state.isdusk or TheWorld.state.isnight
                        oldfn(inst, ...)
                        TheWorld.state.isnight = oldisnight
                    end
                end
            end
        end
    end)
    -- 是否让夜视能力变地危险
    if dangerversion then
        -- These existing role abilities keep their small physical safety light
        -- only while dangerous Long Night is actually loaded. Other nightvision
        -- sources (including the generic monster bonus) do not grant this light.
        local ROLE_LIGHTS = {webber = true, wurt = true, wonkey = true}
        local function RemoveRoleLight(inst)
            if inst._rolevisionlight2hm ~= nil then
                if inst._rolevisionlight2hm:IsValid() then inst._rolevisionlight2hm:Remove() end
                inst._rolevisionlight2hm = nil
            end
        end
        local function UpdateRoleLight(inst)
            local state = inst._rolevisionstate2hm
            if state == nil or not state.active or inst:HasTag("playerghost") or
                (inst.components.health ~= nil and inst.components.health:IsDead()) then
                RemoveRoleLight(inst)
                return
            end
            if inst._rolevisionlight2hm == nil or not inst._rolevisionlight2hm:IsValid() then
                local light = SpawnPrefab("deathcurselight2hm")
                if light == nil then return end
                inst._rolevisionlight2hm = light
                light.entity:SetCanSleep(false)
                light.entity:SetParent(inst.entity)
                light.Light:SetFalloff(0.4)
                light.Light:SetIntensity(.7)
                light.Light:SetRadius(0.5)
                light.Light:SetColour(180 / 255, 195 / 255, 150 / 255)
                light.Light:Enable(true)
            end
        end
        AddPlayerPostInit(function(inst)
            if not TheWorld.ismastersim or not ROLE_LIGHTS[inst.prefab] then return end
            inst:ListenForEvent("rolenightvision2hmchanged", UpdateRoleLight)
            inst:ListenForEvent("death", RemoveRoleLight)
            inst:ListenForEvent("onremove", RemoveRoleLight)
            -- Spawn/load callers position the player after prefab postinit.
            inst:DoTaskInTime(0, UpdateRoleLight)
        end)
        AddComponentPostInit("playervision", function(self)
            local oldHasNightVision = self.HasNightVision
            self.HasNightVision = function(self, ...)
                if TUNING.DontHasNightVision2hm then return false end
                return oldHasNightVision(self, ...)
            end
        end)
        local function OnInit(inst, self) inst:ListenForEvent("phasechanged", function() if next(self.immunity) == nil then self:Start() end end) end
        AddComponentPostInit("grue", function(self)
            local oldAddImmunity = self.AddImmunity
            self.AddImmunity = function(self, source, ...)
                if source == "nightvision" then return end
                oldAddImmunity(self, source, ...)
            end
            local oldCheckForStart = self.CheckForStart
            self.CheckForStart = function(self, ...)
                TUNING.DontHasNightVision2hm = true
                local res = oldCheckForStart(self, ...)
                TUNING.DontHasNightVision2hm = nil
                return res
            end
            self.inst:DoTaskInTime(0, OnInit, self)
        end)
        -- AddRecipePostInit("wx78module_nightvision", function(inst) table.insert(inst.ingredients, Ingredient("wx78module_light", 1)) end) ----2025.11.9 YeFeng: 机器人芯片电路大调整，这一行的夜视芯片调整不需要了。
        local function nightvision_onworldstateupdate(wx)
            wx:SetForcedNightVision((TheWorld.state.isdusk or TheWorld.state.isnight) and not TheWorld.state.isfullmoon)
        end
        local LIGHT_R, LIGHT_G, LIGHT_B = 235 / 255, 121 / 255, 12 / 255
        AddPrefabPostInit("wx78module_nightvision", function(inst)
            if not TheWorld.ismastersim then return end
            if inst.components.upgrademodule then
                local oldonactivatedfn = inst.components.upgrademodule.onactivatedfn
                inst.components.upgrademodule.onactivatedfn = function(inst, wx, ...)
                    wx._light_modules = (wx._light_modules or 0) + 1
                    wx.Light:SetRadius(TUNING.WX78_LIGHT_BASERADIUS + (wx._light_modules - 1) * TUNING.WX78_LIGHT_EXTRARADIUS)
                    -- If we had 0 before, set up the light properties.
                    if wx._light_modules == 1 then
                        wx.Light:SetIntensity(0.90)
                        wx.Light:SetFalloff(0.50)
                        wx.Light:SetColour(LIGHT_R, LIGHT_G, LIGHT_B)
                        wx.Light:Enable(true)
                    end
                    oldonactivatedfn(inst, wx, ...)
                    if wx._nightvision_modcount == 1 and TheWorld ~= nil and wx.SetForcedNightVision ~= nil and not TheWorld:HasTag("cave") then
                        wx:WatchWorldState("isdusk", nightvision_onworldstateupdate)
                        nightvision_onworldstateupdate(wx)
                    end
                end
                local oldondeactivatedfn = inst.components.upgrademodule.ondeactivatedfn
                inst.components.upgrademodule.ondeactivatedfn = function(inst, wx, ...)
                    oldondeactivatedfn(inst, wx, ...)
                    wx._light_modules = math.max(0, wx._light_modules - 1)
                    if wx._light_modules == 0 then
                        -- Reset properties to the electrocute light properties, since that's the player_common default.
                        wx.Light:SetRadius(0.5)
                        wx.Light:SetIntensity(0.8)
                        wx.Light:SetFalloff(0.65)
                        wx.Light:SetColour(255 / 255, 255 / 255, 236 / 255)
                        wx.Light:Enable(false)
                    else
                        wx.Light:SetRadius(TUNING.WX78_LIGHT_BASERADIUS + (wx._light_modules - 1) * TUNING.WX78_LIGHT_EXTRARADIUS)
                    end
                    if wx._nightvision_modcount == 0 and TheWorld ~= nil and wx.SetForcedNightVision ~= nil and not TheWorld:HasTag("cave") then
                        wx:StopWatchingWorldState("isdusk", nightvision_onworldstateupdate)
                    end
                end
            end
        end)
        AddRecipePostInit("molehat", function(inst) table.insert(inst.ingredients, Ingredient("minerhat", 1)) end)
        AddPrefabPostInit("molehat", function(inst)
            if not TheWorld.ismastersim then return end
            inst:ListenForEvent("equipped", function(inst, data)
                if inst._light == nil or not inst._light:IsValid() then inst._light = SpawnPrefab("minerhatlight") end
                if data and data.owner ~= nil then inst._light.entity:SetParent(data.owner.entity) end
                local soundemitter = data and data.owner ~= nil and data.owner.SoundEmitter or inst.SoundEmitter
                if soundemitter then soundemitter:PlaySound("dontstarve/common/minerhatAddFuel") end
            end)
            inst:ListenForEvent("unequipped", function(inst, data)
                if inst._light ~= nil then
                    if inst._light:IsValid() then inst._light:Remove() end
                    inst._light = nil
                    local soundemitter = data and data.owner ~= nil and data.owner.SoundEmitter or inst.SoundEmitter
                    if soundemitter then soundemitter:PlaySound("dontstarve/common/minerhatOut") end
                end
            end)
        end)
        local function enableplayervision(inst)
            inst:DoTaskInTime(0.25, function()
                if inst.weremode and inst.weremode:value() ~= 0 and (TheWorld:HasTag("cave") or TheWorld.state.isnight or TheWorld.state.isdusk) then
                    if not (inst._weremodelight2hm and inst._weremodelight2hm:IsValid()) then
                        inst._weremodelight2hm = SpawnPrefab("deathcurselight2hm")
                    end
                    inst._weremodelight2hm.entity:SetParent(inst.entity)
                    inst._weremodelight2hm.Light:SetFalloff(0.4)
                    inst._weremodelight2hm.Light:SetIntensity(.7)
                    inst._weremodelight2hm.Light:SetRadius(2.5)
                    inst._weremodelight2hm.Light:SetColour(180 / 255, 195 / 255, 150 / 255)
                    inst._weremodelight2hm.Light:Enable(true)
                    -- Woodie's native SetWereVision owns the transformation
                    -- source and palette on both client and server. This
                    -- dangerous-mode compensation only supplies actual light.
                else
                    if inst._weremodelight2hm and inst._weremodelight2hm:IsValid() then
                        inst._weremodelight2hm:Remove()
                        inst._weremodelight2hm = nil
                    end
                end
            end)
        end
        AddPrefabPostInit("woodie", function(inst)
            if not TheWorld.ismastersim then return end
            local oldOnLoad = inst.OnLoad
            inst.OnLoad = function(...)
                if oldOnLoad then oldOnLoad(...) end
                enableplayervision(...)
            end
            enableplayervision(inst)
            inst:ListenForEvent("transform_person", enableplayervision)
            inst:ListenForEvent("transform_wereplayer", enableplayervision)
            inst:ListenForEvent("ms_respawnedfromghost", enableplayervision)
            inst:WatchWorldState("phase", enableplayervision)
        end)
    end
end
