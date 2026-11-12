local Model = require("keybindingmodel2hm")
local M = {Model=Model}
local SAVE_KEY = "mod_config_data/SeasonOfTemperingKeybindings_v1"
local namespace
local function text(zh,en) return TUNING.isCh2hm and zh or en end
M.Text=text
local function context(player)
    local inventory=player and player.replica and player.replica.inventory
    local picker=player and player.components.playeractionpicker
    local controller=player and player.components.playercontroller
    return inventory,picker,controller
end
local function actionname(player, action, target, item)
    return BufferedAction(player,target,action,item):GetActionString() or action.id
end
function M.Entries(player)
    local entries={}
    local inventory,picker=context(player)
    if not inventory or not picker then return entries end
    if player.rightselfaction2hm and ACTIONS.RIGHTSELFACTION2HM then
        entries[#entries+1]={id="self",kind="self",name=actionname(player,ACTIONS.RIGHTSELFACTION2HM,player),
            detail=text("角色技能 · 对自己使用", "Character skill · Self")}
    end
    if picker.rightactiondef2hm then
        local action=picker.rightactiondef2hm
        entries[#entries+1]={id="point:"..action.id,kind="point",action=action,
            name=actionname(player,action),detail=text("角色技能 · 指向鼠标位置", "Character skill · Cursor position")}
    end
    local item=inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    if item and (item.components.aoetargeting or item.components.aoecharging or
        item:HasTag("castonpoint") or item:HasTag("castonpointwater")) then
        local charging=item.components.aoecharging~=nil
        entries[#entries+1]={id="equipment:"..item.prefab,kind=charging and "charge" or "equipment",item=item,
            name=(item:GetDisplayName() or item.prefab)..text(charging and " · 蓄力" or " · 装备技能",charging and " · Charge" or " · Item skill"),
            detail=text(charging and "按住快捷键蓄力，松开释放" or "手持装备 · 指向鼠标位置",
                charging and "Hold to charge, release to fire" or "Equipped item · Cursor position")}
    end
    entries[#entries+1]={id="bindings",kind="bindings",global=true,name=text("打开快捷键配置","Open key bindings"),detail=text("通用功能 · 所有角色共用","General · Shared by all characters")}
    entries[#entries+1]={id="wiki",kind="wiki",global=true,name=text("打开淬炼之季 Wiki","Open Season of Tempering Wiki"),detail=text("通用功能 · 所有角色共用","General · Shared by all characters")}
    return entries
end
-- A bound function is an explicit skill selection. Ctrl is supplied only while
-- querying its normal eligibility, without changing any physical input state.
local function withselection(controller,fn)
    local old=controller.IsControlPressed
    controller.IsControlPressed=function(self,control,...)
        if control==CONTROL_FORCE_STACK then return true end
        return old(self,control,...)
    end
    local ok,result=pcall(fn)
    controller.IsControlPressed=old
    if not ok then error(result,0) end
    return result
end
function M.BuildAction(player,entry,pos)
    local inventory,picker,controller=context(player)
    if not inventory or not picker or not controller or inventory:GetActiveItem()~=nil or
        player:HasTag("playerghost") or player.ingym2hm then return end
    return withselection(controller,function()
        if entry.kind=="self" then
            for _,act in ipairs(picker:GetSceneActions(player,true)) do
                if act.action==ACTIONS.RIGHTSELFACTION2HM then return act end
            end
        elseif entry.kind=="point" then
            local actions=picker.rightaction2hm and picker.rightaction2hm(player,pos,nil,true) or {}
            for _,act in ipairs(picker:SortActionList(actions,pos,nil)) do
                if act.action==entry.action then return act end
            end
        elseif entry.kind=="equipment" then
            for _,act in ipairs(picker:GetPointActions(pos,entry.item,true)) do
                if act.action==ACTIONS.CASTSPELL or act.action==ACTIONS.CASTAOE then return act end
            end
            local aoe=entry.item.components.aoetargeting
            local rider=player.replica.rider
            if aoe and aoe:IsEnabled() and (aoe.allowriding or not (rider and rider:IsRiding())) then
                local map=TheWorld and TheWorld.Map
                if map and (map:IsGroundTargetBlocked(pos) or
                    not aoe.alwaysvalid and not map:IsPassableAtPoint(pos.x,0,pos.z,aoe.allowwater)) then return end
                return picker:SortActionList({ACTIONS.CASTAOE},pos,entry.item)[1]
            end
        end
    end)
end
local function finite(value) return type(value)=="number" and value==value and math.abs(value)<131072 end
function M.ServerAction(player,id,x,z)
    if not (player and player:IsValid()) then return false end
    local inventory,_,controller=context(player)
    if id=="charge_release" then
        if player.keybindingcharge2hm and controller then
            player.keybindingcharge2hm=nil; controller.remote_controls[CONTROL_SECONDARY]=nil
        end
        return true
    end
    if type(id)~="string" or #id>160 or not finite(x) or not finite(z) or not inventory or not controller or
        not controller:IsEnabled() or controller:IsBusy() or player:HasTag("playerghost") or inventory:GetActiveItem()~=nil then return false end
    local now=GetTime()
    if player.lastkeybinding2hm and now-player.lastkeybinding2hm<.15 then return false end
    local entry
    for _,candidate in ipairs(M.Entries(player)) do if candidate.id==id and not candidate.global then entry=candidate; break end end
    if not entry then return false end
    local pos=Vector3(x,0,z)
    if entry.kind~="self" and not CanEntitySeePoint(player,x,0,z) then return false end
    if entry.kind=="charge" then
        local angle=player:GetAngleToPoint(x,0,z)
        if controller:TryAOECharging(angle,false) then
            player.keybindingcharge2hm=true; controller.remote_controls[CONTROL_SECONDARY]=0
            player.lastkeybinding2hm=now; return true
        end
        return false
    end
    local act=M.BuildAction(player,entry,pos)
    if not act then return false end
    player.lastkeybinding2hm=now
    controller:DoAction(act)
    return true
end
function M.CanUse()
    local p=ThePlayer
    if not p or not p:IsValid() or not p.HUD or p:HasTag("playerghost") then return false end
    local screen=TheFrontEnd and TheFrontEnd:GetActiveScreen()
    local _,_,controller=context(p)
    return screen==p.HUD and not TheFrontEnd.textProcessorWidget and
        controller and controller:IsEnabled() and not controller.placer_recipe and not controller.deployplacer and
        not p.HUD:HasInputFocus()
end
local cache={}
local function hasbindings()
    if not M.store or not M.store.loaded or not ThePlayer then return false end
    local role=M.store.data.characters[ThePlayer.prefab]
    return next(M.store.data.global)~=nil or role~=nil and next(role)~=nil
end
local function activeentries()
    local p=ThePlayer
    local inventory,picker=context(p)
    if not inventory or not picker then return {} end
    local tool=inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    if cache.player~=p or cache.tool~=tool or cache.point~=picker.rightactiondef2hm or cache.self~=p.rightselfaction2hm then
        cache={player=p,tool=tool,point=picker.rightactiondef2hm,self=p.rightselfaction2hm,entries=M.Entries(p)}
    end
    return cache.entries
end
function M.Match(isdown,changedkey)
    if not hasbindings() or not M.CanUse() then return end
    for _,entry in ipairs(activeentries()) do
        local keys=M.store:Get(ThePlayer.prefab,entry)
        if keys and Model.Matches(keys,isdown) then
            local involved=changedkey==nil
            for _,key in ipairs(keys) do if key==changedkey then involved=true end end
            if involved then return entry,keys end
        end
    end
end
local function request(id)
    local p=ThePlayer
    local pos=TheInput:GetWorldPosition()
    if not p or not pos then return end
    if TheWorld.ismastersim then M.ServerAction(p,id,pos.x,pos.z)
    else SendModRPCToServer(GetModRPC(namespace,"keybinding_action"),id,pos.x,pos.z) end
end
function M.Trigger(entry)
    if entry.kind=="bindings" then M.Open()
    elseif entry.kind=="wiki" then require("seasonwiki2hm").Open()
    else
        local _,_,controller=context(ThePlayer)
        if controller:IsBusy() then return end
        if entry.kind~="self" and TheInput:GetHUDEntityUnderMouse()~=nil then return end
        if controller.reticule then
            if controller:GetActiveSpellBook()~=nil then return end
            controller:CancelAOETargeting()
        end
        request(entry.id)
    end
end
local latched, charge = {}, nil
local function isdown(key) return TheInput:IsKeyDown(key) end
function M.CheckCharge()
    if charge and (not M.CanUse() or not Model.Matches(charge.keys,isdown)) then
        request("charge_release"); charge=nil
    end
end
function M.HandleKey(key,down)
    key=Model.Key(key)
    -- Release is unconditional: chat, death or opening a screen while holding
    -- the key must never leave the server's charging control stuck down.
    if charge then
        local held=true; for _,k in ipairs(charge.keys) do if k==key and not down or not isdown(k) then held=false end end
        if not held then request("charge_release"); charge=nil end
    end
    for id,keys in pairs(latched) do
        local held=true; for _,k in ipairs(keys) do if k==key and not down or not isdown(k) then held=false end end
        if not held then latched[id]=nil end
    end
    if not down then return false end
    local entry,keys=M.Match(isdown,key)
    if not entry then return false end
    local involved=false; for _,k in ipairs(keys) do if k==key then involved=true end end
    if not involved then return false end
    if not latched[entry.id] then
        latched[entry.id]=keys
        M.Trigger(entry)
        if entry.kind=="charge" then charge={keys=keys} end
    end
    return true
end
-- The native keyboard/mouse mapping uses physical KEY_* codes (device 1).
-- Suppress only controls mapped to a bound non-modifier key while that chord
-- is active. Movement polling and key-down controls then agree with the cast.
function M.BlockedControl(control)
    if not hasbindings() or not M.CanUse() or not TheInputProxy then return false end
    local reserved={}
    for _,entry in ipairs(activeentries()) do
        local keys=M.store:Get(ThePlayer.prefab,entry)
        if keys and Model.ModifiersMatch(keys,isdown) then
            for _,key in ipairs(keys) do
                if not Model.IsModifier(key) and isdown(key) then reserved[key]=true end
            end
        end
    end
    if next(reserved)==nil then return false end
    -- Inventory/controller widgets also poll virtual controls (10000+). Those
    -- are Lua mappings, not valid IDs for the native input proxy.
    if TheInput.ResolveVirtualControls then control=TheInput:ResolveVirtualControls(control) end
    if type(control)~="number" or control<0 or control>=(VIRTUAL_CONTROL_START or 10000) then return false end
    local device,count,a,b,c,d=TheInputProxy:GetLocalizedControl(0,control,false,true)
    if device~=1 then return false end
    local inputs={a,b,c,d}
    for i=1,math.min(count or 0,4) do
        local key=Model.Key(inputs[i])
        if reserved[key] then return true end
    end
    return false
end
function M.Open()
    if not ThePlayer or not ThePlayer.HUD or not M.store then return end
    TheFrontEnd:PushScreen(require("keybindingscreen2hm")(M,ThePlayer))
end
function M.Install(api,modname)
    if M.installed then return end
    M.installed=true; namespace=modname
    api.AddModRPCHandler(modname,"keybinding_action",M.ServerAction)
    api.AddPlayerPostInit(function(inst)
        if TheWorld.ismastersim then
            inst:ListenForEvent("death",function()
                if inst.keybindingcharge2hm then
                    inst.keybindingcharge2hm=nil
                    local pc=inst.components.playercontroller
                    if pc then pc.remote_controls[CONTROL_SECONDARY]=nil end
                end
            end)
        end
    end)
    if TheNet:IsDedicated() then return end
    M.store=Model.Store({
        read=function(cb) TheSim:GetPersistentString(SAVE_KEY,cb) end,
        write=function(value,cb) TheSim:SetPersistentString(SAVE_KEY,value,false,cb) end,
    },require("json"))
    M.store:Load()
    api.AddComponentPostInit("playercontroller",function(controller)
        local update=controller.OnUpdate
        controller.OnUpdate=function(self,...)
            if self.inst==ThePlayer then M.CheckCharge() end
            if update then return update(self,...) end
        end
    end)
    api.AddSimPostInit(function()
        local raw=TheInput.OnRawKey
        TheInput.OnRawKey=function(input,key,down,...)
            if M.HandleKey(key,down) then return end
            return raw(input,key,down,...)
        end
        local controls=TheInput.OnControl
        TheInput.OnControl=function(input,control,down,...)
            if down and M.BlockedControl(control) then return end
            return controls(input,control,down,...)
        end
        local pressed=TheInput.IsControlPressed
        TheInput.IsControlPressed=function(input,control,...)
            if M.BlockedControl(control) then return false end
            return pressed(input,control,...)
        end
    end)
end
return M
