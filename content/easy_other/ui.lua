local TextListPopup = require "screens/redux/textlistpopup"
local ModConfigurationScreen = require "screens/redux/modconfigurationscreen"
local ImageButton = require "widgets/imagebutton"

local enableshow = ((TUNING.TEMP2HM.openmods == nil and GetModConfigData("Show Mod Icon In Game")) or TUNING.TEMP2HM.openmods)

local function viewModConfiguration(self, mod, mod_config_data)
    local oldLoadModConfigurationOptions = KnownModIndex.LoadModConfigurationOptions
    KnownModIndex.LoadModConfigurationOptions = function(...)
        local config = deepcopy(oldLoadModConfigurationOptions(...))
        -- Use a special data to make server mod config change more visible
        if config and type(config) == "table" then
            for i, v in ipairs(config) do
                if v.name ~= nil and v.options and mod_config_data[v.name] ~= nil then
                    v.saved = v.default
                    v.default = mod_config_data[v.name]
                end
            end
        end
        return config
    end
    local oldCONFIGSCREENTITLESUFFIX = STRINGS.UI.MODSSCREEN.CONFIGSCREENTITLESUFFIX
    STRINGS.UI.MODSSCREEN.CONFIGSCREENTITLESUFFIX = mod.mod_name
    local screen = ModConfigurationScreen(mod.mod_name, true)
    STRINGS.UI.MODSSCREEN.CONFIGSCREENTITLESUFFIX = oldCONFIGSCREENTITLESUFFIX
    KnownModIndex.LoadModConfigurationOptions = oldLoadModConfigurationOptions
    -- Disable Confirm Revert Dialog Tip
    screen.ResetToDefaultValues = function(self)
        for i, v in pairs(self.optionwidgets) do
            self.options[i].value = self.options[i].default
            v.selected_value = self.options[i].default
        end
        self.options_scroll_list:RefreshView()
    end
    screen.Cancel = function() TheFrontEnd:PopScreen() end
    -- Use a special data to make server mod config change more visible
    screen:ResetToDefaultValues()
    -- Disable Apply Mod Config Change
    screen.dialog.actions.items[1]:Hide()
    screen.OnControl = function(self, control, down)
        if ModConfigurationScreen._base.OnControl(self, control, down) then return true end
        if not down then
            if control == CONTROL_CANCEL then
                self:Cancel()
                return true
            elseif control == CONTROL_MAP and TheInput:ControllerAttached() then
                self:ResetToDefaultValues()
                return true
            end
        end
    end
    screen.GetHelpText = function()
        local t = {}
        local controller_id = TheInput:GetControllerID()
        table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_CANCEL) .. " " .. STRINGS.UI.HELP.BACK)
        table.insert(t, TheInput:GetLocalizedControl(controller_id, CONTROL_MAP) .. " " .. STRINGS.UI.MODSSCREEN.RESETDEFAULT)
        return table.concat(t, "  ")
    end
    TheFrontEnd:PushScreen(screen)
end

local function viewWorldModsConfigData(self)
    if not self.server_listing then return end
    local mods_list = {}
    for _, mod in pairs(self.server_listing.mods_description) do
        local onclick = nil
        local needprocess
        if self.server_listing._processed_mods_config_data[mod.mod_name] and not IsTableEmpty(self.server_listing._processed_mods_config_data[mod.mod_name]) then
            onclick = function() viewModConfiguration(self, mod, self.server_listing._processed_mods_config_data[mod.mod_name]) end
        elseif KnownModIndex:HasModConfigurationOptions(mod.mod_name) then
            needprocess = true
            onclick = function() viewModConfiguration(self, mod, {}) end
        end
        local modinfo = KnownModIndex:GetModInfo(mod.mod_name) or {}
        local text_tag = ""
        if modinfo.client_only_mod then
            text_tag = "[Client Only] "
        elseif modinfo.all_clients_require_mod then
            text_tag = "[All Clients] "
        elseif modinfo.all_clients_require_mod == false then
            text_tag = "[Server Only] "
        else
            text_tag = "[Unknown Type] "
        end
        table.insert(mods_list, {text = text_tag .. mod.modinfo_name, onclick = onclick, needprocess = needprocess})
    end
    local screen = TextListPopup(mods_list, STRINGS.UI.MODSSCREEN.SERVERMODS)
    -- if screen.scroll_list then
    --     local oldupdate_fn = screen.scroll_list.update_fn
    --     screen.scroll_list.update_fn = function(context, item, data, index, ...)
    --         if oldupdate_fn then oldupdate_fn(context, item, data, index, ...) end
    --         -- if data and data.needprocess and item and item.btn2hm then
    --         --     item.btn2hm:UseFocusOverlay("menu_focus.tex")
    --         --     item.btn2hm:SetImageNormalColour(1, 1, 1, 0) -- we don't want anything shown for normal.
    --         --     item.btn2hm:SetImageFocusColour(1, 1, 1, 0.1) -- use focus overlay instead.
    --         --     item.btn2hm:SetImageSelectedColour(1, 1, 1, 0.1)
    --         --     item.btn2hm:SetTextColour(UICOLOURS.GOLD_CLICKABLE)
    --         --     item.btn2hm:SetTextFocusColour(UICOLOURS.WHITE)
    --         --     item.btn2hm:SetTextSelectedColour(UICOLOURS.GOLD_FOCUS)
    --         -- end
    --     end
    --     screen.scroll_list:RefreshView()
    -- end
    TheFrontEnd:PushScreen(screen)
end

local function SetImageButtonRightControl(self)
    if self.SetImageButtonRightControl2hm then return end
    self.SetImageButtonRightControl2hm = true
    local oldOnControl = self.OnControl
    self.OnControl = function(self, control, down, ...)
        local result = oldOnControl(self, control, down, ...)
        if not self:IsEnabled() or not self.focus then return result end
        if self:IsSelected() and not self.AllowOnControlWhenSelected then return result end
        if control == CONTROL_SECONDARY then
            if down then
                if not self.down2hm and not self.down then
                    if self.has_image_down then
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
                    if self.has_image_down then
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
end

-- [[该函数来自蘑菇慕斯，但经过一定魔改]]
-- 该函数可以获得鼠标相对于UI父级坐标的局部坐标(需要考虑的因素有该UI的原点坐标和父UI的全局缩放值)
-- 默认的原点坐标为父级的坐标，如果widget上有v_anchor和h_anchor这两个变量，就说明改变了默认的原点坐标
-- 我们会在GetMouseLocalPos函数里检查这两个变量，以对这种情况做专门的处理
-- 这个函数可以将鼠标坐标从屏幕坐标系下转换到和wiget同一个坐标系下
local function GetMouseLocalPos(ui, mouse_pos) -- ui: 要拖拽的widget, mouse_pos: 鼠标的屏幕坐标(Vector3对象)
    local g_s = ui:GetScale() -- ui的全局缩放值
    local l_s = Vector3(0, 0, 0)
    l_s.x, l_s.y, l_s.z = ui:GetLooseScale() -- ui本身的缩放值
    local scale = Vector3(g_s.x / l_s.x, g_s.y / l_s.y, g_s.z / l_s.z) -- 父级的全局缩放值

    local ui_local_pos = ui:GetPosition() -- ui的相对位置（也就是SetPosition的时候传递的坐标）
    ui_local_pos = Vector3(ui_local_pos.x * scale.x, ui_local_pos.y * scale.y, ui_local_pos.z * scale.z)
    local ui_world_pos = ui:GetWorldPosition()
    -- 如果修改过ui的屏幕原点，就重新计算ui的屏幕坐标（基于左下角为原点的）
    if not (not ui.v_anchor or ui.v_anchor == ANCHOR_BOTTOM) or not (not ui.h_anchor or ui.h_anchor == ANCHOR_LEFT) then
        local screen_w, screen_h = TheSim:GetScreenSize() -- 获取屏幕尺寸（宽度，高度）
        if ui.v_anchor and ui.v_anchor ~= ANCHOR_BOTTOM then -- 如果修改了原点的垂直坐标
            ui_world_pos.y = ui.v_anchor == ANCHOR_MIDDLE and screen_h / 2 + ui_world_pos.y or screen_h - ui_world_pos.y
        end
        if ui.h_anchor and ui.h_anchor ~= ANCHOR_LEFT then -- 如果修改了原点的水平坐标
            ui_world_pos.x = ui.h_anchor == ANCHOR_MIDDLE and screen_w / 2 + ui_world_pos.x or screen_w - ui_world_pos.x
        end
    end

    local origin_point = ui_world_pos - ui_local_pos -- 原点坐标
    mouse_pos = mouse_pos - origin_point

    return Vector3(mouse_pos.x / scale.x, mouse_pos.y / scale.y, mouse_pos.z / scale.z) -- 鼠标相对于UI父级坐标的局部坐标
end

-- tex前缀可以从prefabskins.lua文件获取
local defaulttex = "reskin_tool_bouquet.tex"
local defaultatlas
local numChoices
local function addModsInfobtn2hm(self, name)
    self.server_listing = TheNet:GetServerListing()
    if not self.server_listing or not TUNING.TEMP2HM then return end
    -- 󰀂
    if self.server_listing._processed_mods_config_data == nil and self.server_listing.mods_config_data ~= nil then
        local success, temp_config_data = RunInSandboxSafe(self.server_listing.mods_config_data)
        if success and temp_config_data ~= nil then self.server_listing._processed_mods_config_data = temp_config_data end
    end
    if not defaultatlas then defaultatlas = GetInventoryItemAtlas(defaulttex, true) end
    -- 加载记忆图标
    local currtex = TUNING.TEMP2HM.btn2hmicon and TUNING.TEMP2HM.btn2hmicon[name] and TUNING.TEMP2HM.btn2hmicon[name].tex or defaulttex
    local curratlas = TUNING.TEMP2HM.btn2hmicon and TUNING.TEMP2HM.btn2hmicon[name] and TUNING.TEMP2HM.btn2hmicon[name].atlas or
                          GetInventoryItemAtlas(currtex, true) or defaultatlas
    self.btn2hm = self:AddChild(ImageButton(defaultatlas, defaulttex, nil, nil, nil, nil, {1, 1}, {0, 0}))
    if not pcall(function() self.btn2hm:SetTextures(curratlas, currtex, nil, nil, nil, nil, {1, 1}, {0, 0}) end) then
        TheNet:Say(TUNING.isCh2hm and "为爽而虐客户端警告：您的[显示模组]按钮的自定义图标不存在，推荐更换一个图标" or
                       "Your Show Mods Btn Icon is not exist,please change another icon")
        curratlas = defaultatlas
        currtex = defaulttex
        self.btn2hm:SetTextures(defaultatlas, defaulttex, nil, nil, nil, nil, {1, 1}, {0, 0})
    end
    -- 右键更换图标
    self.btn2hm:SetTooltip(TUNING.isCh2hm and ("显示模组\n" .. TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_PRIMARY) .. "拖拽\n" ..
                               TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_SECONDARY) .. "换肤") or
                               ("Show Mods\n" .. TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_PRIMARY) .. "Drag\n" ..
                                   TheInput:GetLocalizedControl(TheInput:GetControllerID(), CONTROL_SECONDARY) .. "Icon"))
    self.btn2hm.onrightclick2hm = function()
        if PREFAB_SKINS then
            if not numChoices then numChoices = GetTableSize(PREFAB_SKINS) end
            if numChoices < 1 then return end
            local lastChoice
            for i = 1, math.min(30, numChoices), 1 do
                local choice = math.random(numChoices - 1) + 1
                if choice == lastChoice then
                    choice = lastChoice + 1
                    if choice > numChoices then numChoices = 1 end
                end
                lastChoice = choice
                local filters = nil
                for k, v in pairs(PREFAB_SKINS) do
                    filters = v
                    if choice <= 1 then break end
                    choice = choice - 1
                end
                if filters and type(filters) == "table" then
                    local newtex = GetRandomItem(filters)
                    if newtex and type(newtex) == "string" then
                        newtex = newtex .. ".tex"
                        local newatlas = GetInventoryItemAtlas(newtex, true)
                        if newatlas then
                            if pcall(function() self.btn2hm:SetTextures(newatlas, newtex, nil, nil, nil, nil, {1, 1}, {0, 0}) end) then
                                TUNING.TEMP2HM.btn2hmicon = TUNING.TEMP2HM.btn2hmicon or {}
                                TUNING.TEMP2HM.btn2hmicon[name] = {tex = newtex, atlas = newatlas}
                                SaveTemp2hm()
                                currtex = newtex
                                curratlas = newatlas
                                return
                            end
                        end
                    end
                end
            end
            -- 没有随机成功，复原图标
            self.btn2hm:SetTextures(curratlas, currtex, nil, nil, nil, nil, {1, 1}, {0, 0})
        end
    end
    SetImageButtonRightControl(self.btn2hm)
    -- 左键更换位置
    if TUNING.TEMP2HM and TUNING.TEMP2HM.btn2hmposition and TUNING.TEMP2HM.btn2hmposition[name] then
        self.btn2hm:SetPosition(TUNING.TEMP2HM.btn2hmposition[name].x, TUNING.TEMP2HM.btn2hmposition[name].y, TUNING.TEMP2HM.btn2hmposition[name].z)
    else
        local screen_w, screen_h = TheSim:GetScreenSize()
        self.btn2hm:SetPosition(screen_w - 25, 120, 0)
    end
    self.btn2hm:SetOnDown(function()
        if not self.btn2hm.followhandler then
            self.btn2hm.followhandler = TheInput:AddMoveHandler(function(x, y, z)
                local loc_pos = GetMouseLocalPos(self.btn2hm, Vector3(x, y, z or 0))
                if not self.btn2hm.oldPosition2hm then
                    self.btn2hm.oldPosition2hm = self.btn2hm:GetPosition()
                    self.btn2hm.offset2hm_x = self.btn2hm.oldPosition2hm.x - loc_pos.x
                    self.btn2hm.offset2hm_y = self.btn2hm.oldPosition2hm.y - loc_pos.y
                    self.btn2hm.offset2hm_z = self.btn2hm.oldPosition2hm.z - loc_pos.z
                end
                self.btn2hm.finalPosition2hm = Vector3(loc_pos.x + self.btn2hm.offset2hm_x, loc_pos.y + self.btn2hm.offset2hm_y,
                                                       loc_pos.z + self.btn2hm.offset2hm_z)
                self.btn2hm:SetPosition(self.btn2hm.finalPosition2hm.x, self.btn2hm.finalPosition2hm.y, self.btn2hm.finalPosition2hm.z)
            end)
        end
    end)
    self.btn2hm:SetOnClick(function()
        if self.btn2hm.offset2hm_x then
            self.btn2hm.offset2hm_x = nil
            self.btn2hm.offset2hm_y = nil
            self.btn2hm.offset2hm_z = nil
        end
        if self.btn2hm.followhandler ~= nil then
            self.btn2hm.followhandler:Remove()
            self.btn2hm.followhandler = nil
        end
        if self.btn2hm.oldPosition2hm == nil or
            distsq(self.btn2hm.oldPosition2hm.x, self.btn2hm.oldPosition2hm.y, self.btn2hm.finalPosition2hm.x, self.btn2hm.finalPosition2hm.y) < 16 then
            viewWorldModsConfigData(self)
        elseif TUNING.TEMP2HM then
            self.btn2hm:SetPosition(self.btn2hm.finalPosition2hm.x, self.btn2hm.finalPosition2hm.y, self.btn2hm.finalPosition2hm.z)
            TUNING.TEMP2HM.btn2hmposition = TUNING.TEMP2HM.btn2hmposition or {}
            TUNING.TEMP2HM.btn2hmposition[name] = {x = self.btn2hm.finalPosition2hm.x, y = self.btn2hm.finalPosition2hm.y, z = self.btn2hm.finalPosition2hm.z}
            SaveTemp2hm()
        end
        self.btn2hm.oldPosition2hm = nil
        self.btn2hm.finalPosition2hm = nil
    end)
    -- if TheWorld then
    --     TheWorld.uiupdatebtn2hm = function()
    --         enableshow = ((TUNING.TEMP2HM.openmods == nil and GetModConfigData("Show Mod Icon In Game")) or TUNING.TEMP2HM.openmods)
    --         if enableshow then
    --             self.btn2hm:Hide()
    --         else
    --             self.btn2hm:Show()
    --         end
    --     end
    -- end
end

local function addModsInfobtn2hm1(self) if enableshow then addModsInfobtn2hm(self, "controls") end end
local function addModsInfobtn2hm2(self) if enableshow then addModsInfobtn2hm(self, "lobbyscreen") end end
-- playerhud不能显示tooltip
-- AddClassPostConstruct("screens/playerhud", addModsInfobtn2hm)
AddClassPostConstruct("widgets/controls", addModsInfobtn2hm1)
AddClassPostConstruct("screens/redux/lobbyscreen", addModsInfobtn2hm2)


if not ModConfigurationScreen._happypatch2hm then
    ModConfigurationScreen._happypatch2hm = true
    local ModConfigurationScreenconstructor = ModConfigurationScreen._ctor
    ModConfigurationScreen._ctor = function(self, _modname, client_config, ...)
        local result = ModConfigurationScreenconstructor(self, _modname, client_config, ...)
        local total = self.optionwidgets and #self.optionwidgets
        if self.options_scroll_list and total and total >= 30 then
            local headeritems = {}
            for i, data in ipairs(self.optionwidgets) do
                if data and data.is_header and data.option then
                    table.insert(headeritems, {i = i, option = data.option.label or data.option.name or ""})
                end
            end
            local lastoption
            local laststep
            local lastdata
            local stepoptions = {}
            for _, data in ipairs(headeritems) do
                local key = data.i
                if lastoption == nil then
                    lastoption = key
                    laststep = key
                    lastdata = data
                    table.insert(stepoptions, data)
                else
                    if key ~= lastoption + 1 then
                        if key - laststep >= 2 then
                            -- 首个header选项
                            laststep = key
                            lastdata = data
                            table.insert(stepoptions, data)
                        end
                    elseif lastdata and lastdata.option == "" then
                        -- 连续header选项，排除其中的空白
                        if data.option ~= "" then
                            lastdata.i = key
                            lastdata.option = data.option
                        end
                    end
                    lastoption = key
                end
            end
            local start = self.options_scroll_list:GetSlideStart()
            local range = self.options_scroll_list:GetSlideRange()
            for _, data in ipairs(stepoptions) do
                local key = data.i
                local btn = self.options_scroll_list.scroll_bar_container:AddChild(ImageButton("images/global_redux.xml", "scrollbar_handle.tex"))
                btn.show_stuff = true
                self["stepbtn2hm" .. key] = btn
                btn:SetScale(0.15, 0.15, 1)
                local height = start - range * key / total
                btn:SetPosition(0, height)
                local txt = data.option
                if txt == "" then txt = STRINGS.UI.MODSSCREEN.UNKNOWN_MOD_CONFIG_SETTING end
                btn:SetHoverText(txt)
                -- 强行跳转到对应位置
                btn:SetOnDown(function()
                    self.options_scroll_list:ScrollToDataIndex(data.i)
                    local currentindex = data.i - self.options_scroll_list.displayed_start_index
                    if currentindex > 3 then for i = 1, currentindex - 3 do self.options_scroll_list:GetNextWidget(2) end end
                end)
            end
            self.options_scroll_list.position_marker:MoveToFront()
        end
        return result
    end
end
