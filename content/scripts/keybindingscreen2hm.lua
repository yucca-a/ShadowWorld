local Screen=require("widgets/screen")
local Widget=require("widgets/widget")
local Text=require("widgets/text")
local Templates=require("widgets/redux/templates")
local Popup=require("screens/redux/popupdialog")

local BindingsScreen=Class(Screen,function(self,api,player)
    Screen._ctor(self,"SeasonOfTemperingKeyBindings")
    self.api=api; self.player=player; self.role=player.prefab
    local L=api.Text
    self:AddChild(Templates.BackgroundTint())
    self.root=self:AddChild(Templates.ScreenRoot())
    self.window=self.root:AddChild(Templates.CurlyWindow(940,480,L("快捷键绑定配置","Key bindings"),
        {{text=L("关闭","Close"),cb=function() self:Close() end}},nil,""))
    self.summary=self.root:AddChild(Text(CHATFONT,24,"",UICOLOURS.GOLD))
    self.summary:SetPosition(0,190)
    self.hint=self.root:AddChild(Text(CHATFONT,20,L("自动识别当前角色与手持装备 · 点击“绑定”录制按键","Detected character and equipped skills · Bind to record keys"),UICOLOURS.WHITE))
    self.hint:SetPosition(0,155)
    self.footer=self.root:AddChild(Text(CHATFONT,20,L("仅保存在本机 · 按角色记忆 · 换档或回档后保留","Saved on this computer, per character · Kept across worlds and rollbacks"),UICOLOURS.GOLD_UNIMPORTANT))
    self.footer:SetPosition(0,-193)
    self.feedback=self.root:AddChild(Text(CHATFONT,20,"",UICOLOURS.WHITE))
    self.feedback:SetPosition(0,-166)
    local function ctor(context,index)
        local row=Widget("binding-row-"..index)
        row.name=row:AddChild(Text(CHATFONT,24,"",UICOLOURS.WHITE)); row.name:SetPosition(-243,10)
        row.detail=row:AddChild(Text(CHATFONT,18,"",UICOLOURS.GOLD_UNIMPORTANT)); row.detail:SetPosition(-243,-14)
        row.keys=row:AddChild(Text(CHATFONT,22,"",UICOLOURS.GOLD)); row.keys:SetPosition(93,0)
        row.bind=row:AddChild(Templates.StandardButton(nil,L("绑定","Bind"),{92,40})); row.bind:SetPosition(268,0)
        row.clear=row:AddChild(Templates.StandardButton(nil,L("清除","Clear"),{76,40})); row.clear:SetPosition(362,0)
        row.bind:SetFocusChangeDir(MOVE_RIGHT,row.clear); row.clear:SetFocusChangeDir(MOVE_LEFT,row.bind)
        row.focus_forward=row.bind
        row:SetOnGainFocus(function() self.list:OnWidgetFocus(row) end)
        return row
    end
    local function apply(context,row,entry)
        if not entry then row:Hide(); return end
        row:Show()
        row.name:SetTruncatedString(entry.name,310,70,true)
        row.detail:SetTruncatedString(entry.detail,310,100,true)
        local keys=api.store:Get(self.role,entry)
        row.keys:SetTruncatedString(keys and api.Model.Label(keys) or L("未绑定","Unbound"),225,50,true)
        row.bind:SetOnClick(function() self:Record(entry) end)
        row.clear:SetOnClick(function()
            api.store:Set(self.role,entry,nil,self.entries,function(ok)
                if self.inst:IsValid() then
                    self.feedback:SetString(ok and L("已清除绑定","Binding cleared") or L("保存失败，请重试","Could not save. Please try again."))
                    self:Refresh()
                end
            end)
        end)
        if api.store.loaded and not api.store.saving then row.bind:Enable() else row.bind:Disable() end
        if keys and api.store.loaded and not api.store.saving then row.clear:Enable() else row.clear:Disable() end
    end
    self.list=self.root:AddChild(Templates.ScrollingGrid({}, {context={},widget_width=840,widget_height=62,
        num_visible_rows=5,num_columns=1,item_ctor_fn=ctor,apply_fn=apply,scrollbar_height_offset=-35}))
    self.list:SetPosition(0,-8)
    self.default_focus=self.list
    self:Refresh()
end)
function BindingsScreen:Refresh()
    local api=self.api
    if self.player~=ThePlayer and ThePlayer then self.player=ThePlayer; self.role=ThePlayer.prefab end
    self.entries=api.Entries(self.player)
    self.revision=api.store.revision
    self.summary:SetString((STRINGS.NAMES[string.upper(self.role)] or self.role)..api.Text(" · 当前可绑定功能"," · Available functions"))
    self.list:SetItemsData(self.entries)
    if not api.store.loaded then self.feedback:SetString(api.Text("正在读取本机绑定…","Loading local bindings…"))
    elseif api.store.loaderror then self.feedback:SetString(api.Text("旧配置无法读取；可重新绑定并保存。","Could not read previous bindings; create and save new bindings.")) end
end
function BindingsScreen:OnBecomeActive()
    BindingsScreen._base.OnBecomeActive(self)
    self:Refresh()
end
function BindingsScreen:OnUpdate(dt)
    if self.revision~=self.api.store.revision then self:Refresh() end
end
function BindingsScreen:Close() TheFrontEnd:PopScreen(self) end
function BindingsScreen:OnControl(control,down)
    if control==CONTROL_CANCEL then if not down then self:Close() end; return true end
    return BindingsScreen._base.OnControl(self,control,down)
end
function BindingsScreen:Record(entry)
    local api,L=self.api,self.api.Text
    local function newrecorder() return api.Model.Recorder(function(key) return TheInput:IsKeyDown(key) end) end
    local recorder=newrecorder()
    local popup
    local function refresh()
        local keys=recorder.result
        local conflict=keys and api.store:Conflict(self.role,entry,keys,self.entries)
        local status
        if conflict then status=L("与“","Conflicts with “")..conflict.name..L("”重叠，请换键或先清除原绑定。","”. Choose other keys or clear that binding.")
        elseif recorder.error=="modifier" then status=L("组合键需要包含字母、数字或功能键。","Include a letter, number or function key.")
        elseif recorder.error=="reserved" then status=L("Esc、Enter 和控制台按键保留给游戏，请换键。","Esc, Enter and the console key are reserved. Choose other keys.")
        elseif recorder.error=="unknown" then status=L("未能识别其中一个按键，请更换按键或重新录制。","One key could not be recognized. Choose other keys or record again.")
        elseif recorder.error then status=L("最多支持同时按下 4 个键，请重新录制。","Use at most four keys. Please record again.")
        elseif keys then status=L("录制完成，点击“保存绑定”生效。","Recorded. Save binding to apply.")
        else status=L("请按下按键或组合键，然后全部松开。","Press your key or chord, then release all keys.") end
        local shown=keys or recorder.keys
        local label=#shown>0 and api.Model.Label(shown) or L("等待按键…","Waiting for keys…")
        local kind=#shown>1 and L("组合键","Combination") or #shown==1 and L("单键","Single key") or ""
        popup.dialog.body:SetString(entry.name.."\n\n"..label.."\n"..kind.."\n\n"..status)
        local save=popup.dialog.actions.items[1]
        if keys and not conflict and not api.store.saving then save:Enable() else save:Disable() end
    end
    local function close() if TheFrontEnd:GetActiveScreen()==popup then TheFrontEnd:PopScreen(popup) end end
    popup=Popup(L("录制快捷键","Record shortcut"),"",{
        {text=L("保存绑定","Save binding"),cb=function()
            if not recorder.result then return end
            api.store:Set(self.role,entry,recorder.result,self.entries,function(ok,err,other)
                if not popup.inst:IsValid() then return end
                if ok then self.feedback:SetString(L("已保存：","Saved: ")..entry.name.."  "..api.Model.Label(recorder.result)); close()
                else
                    popup.dialog.body:SetString(err=="conflict" and L("按键冲突，请重新录制。","Conflicting keys. Record again.") or L("保存失败，请稍后重试。","Could not save. Please try again."))
                end
            end)
            refresh()
        end},
        {text=L("重新录制","Record again"),cb=function() recorder=newrecorder(); popup.recorder=recorder; refresh() end},
        {text=L("取消","Cancel"),cb=close},
    },215,"bigger","dark_wide")
    popup.recorder=recorder
    popup.OnRawKey=function(screen,key,down)
        screen.lastkeytime=GetStaticTime()
        recorder:Feed(key,down)
        if recorder.cancelled and key==KEY_ESCAPE and not down then close(); return true end
        refresh()
        return true
    end
    local control=popup.OnControl
    popup.OnControl=function(screen,c,down)
        if c==CONTROL_CANCEL then return true end
        -- Native keyboard controls can share keys with UI buttons. Keep them
        -- from activating Save/Cancel while the recorder owns those keystrokes.
        if screen.lastkeytime and GetStaticTime()-screen.lastkeytime<.2 then return true end
        return control(screen,c,down)
    end
    refresh()
    TheFrontEnd:PushScreen(popup)
end
return BindingsScreen
