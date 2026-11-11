local G = GLOBAL
G.setmetatable(env, {__index=function(_,key) return G.rawget(G,key) end})
local json = require("json")
local sessions = {}
local function emit(data) print("[COOK PREVIEW] "..json.encode(data)) end
local cases = {{"cookpot",4},{"cookpot",5},{"cookpot",4},{"portablecookpot",5},{"dragonflyfurnace",4},{"cookpot",5}}
if COOK_PREVIEW_MOD_COOKERS then
    cases={{"medal_cookpot",4},{"medal_cookpot",5},{"medal_cookpot",4},{"simmeredmoonlight",5},
        {"simmeredmoonlight_pro",5},{"simmeredmoonlight_inf",5},{"simmeredmoonlight_pro_inf",5},{"medal_cookpot",5},
        {"simmeredmoonlight_inf",5,stacked=true},
        {"simmeredmoonlight_inf",5,row=4,reuse=true,stacked=true,names={"twigs","twigs","twigs","meat","berries"}},
        {"simmeredmoonlight_inf",4,row=4,reuse=true,names={"twigs","twigs","twigs","meat"}},
        {"simmeredmoonlight_inf",5,row=4,reuse=true,names={"berries","berries","berries","berries","berries"}},
        {"simmeredmoonlight_inf",5,reuse=true,focusrow=1}}
end
AddClientModRPCHandler("CookingPreviewAudit","state",function(raw, pot)
    ThePlayer._cookpreviewstate = json.decode(raw)
    ThePlayer._cookpreviewpot = pot
end)
local function Step(p,index)
    print("[COOK PREVIEW SERVER] step",index)
    local old = sessions[p.userid]
    local spec=cases[index]
    if not spec then return end
    local reuse=(index==2 or index==3 or spec.reuse) and old and old.prefab==spec[1]
    if old and not reuse then old.components.container:Close(p);old:Remove() end
    local pot=reuse and old or SpawnPrefab(spec[1]);sessions[p.userid]=pot
    pot.Transform:SetPosition(p.Transform:GetWorldPosition())
    if pot.components.fueled then pot.components.fueled:SetPercent(1) end
    local c=pot.components.container
    local rows,row=pot.fiveslotrows2hm,spec.row or 1
    if reuse and not spec.focusrow then
        if rows then
            for column=1,5 do
                local slot=column==5 and rows*5+row or (row-1)*5+column
                local item=c:GetItemInSlot(slot);if item then item:Remove()end
            end
        else c:DestroyContents()end
    end
    local items=spec.names or {"meat","meat","meat","berries","carrot"}
    local start=1
    if spec[1]=="dragonflyfurnace" then c:GiveItem(SpawnPrefab("redgem"),1);start=2 end
    if not spec.focusrow then for i=1,spec[2] do
        local slot=rows and (i==5 and rows*5+row or (row-1)*5+i) or start+i-1
        local item=SpawnPrefab(items[i]);if spec.stacked and item.components.stackable then item.components.stackable:SetStackSize(7)end
        c:GiveItem(item,slot)
    end end
    if rows and not reuse then
        c:GiveItem(SpawnPrefab("bonestew"),5) -- Permanent output slot must never enter prediction.
    end
    local names={};for i=1,spec[2] do names[i]=items[i] end
    local product=require("cooking").CalculateRecipe(pot.components.moonsimmered and "portablecookpot" or spec[1],names)
    print("[COOK PREVIEW SERVER] prepared",index,product)
    if not reuse then c:Open(p) end
    p:DoTaskInTime(.5,function()
        SendModRPCToClient(GetClientModRPC("CookingPreviewAudit","state"),p.userid,
            json.encode({index=index,prefab=spec[1],count=spec[2],full=spec[1]=="dragonflyfurnace" or spec[2]==5,
                product=product,rows=rows,row=row,focusrow=spec.focusrow,
                preview=pot.components.moonsimmered and pot.components.moonsimmered.show.name}),pot)
        print("[COOK PREVIEW SERVER] sent",index)
    end)
end
G.CookingPreviewAuditStep=function(index)
    local ok,err=pcall(Step,assert(AllPlayers[1],"connected test player"),index)
    if not ok then print("[COOK PREVIEW SERVER] ERROR",tostring(err)) end
end
AddSimPostInit(function()
    if TheNet:IsDedicated() then
        TheWorld:DoTaskInTime(1,function() print('[VAUDIT] {"kind":"ready"}') end)
        return
    end
    TheWorld:DoStaticPeriodicTask(.25,function()
        local p=ThePlayer
        if not p or not p.HUD or p._cookpreviewstarted then return end
        p._cookpreviewstarted=true
        p:StartThread(function()
            Sleep(3)
            emit({kind="client_ready"})
            do
                for index,spec in ipairs(cases) do
                    local deadline=GetStaticTime()+35
                    repeat Sleep(.1) until p._cookpreviewstate and p._cookpreviewstate.index==index or GetStaticTime()>deadline
                    assert(p._cookpreviewstate and p._cookpreviewstate.index==index,"server case response")
                    if p._cookpreviewstate.focusrow then
                        local w=p.HUD.controls.containers[p._cookpreviewpot]
                        w.inv[(p._cookpreviewstate.focusrow-1)*5+1]:OnGainFocus()
                    end
                    Sleep(1)
                    local controls=p.HUD.controls
                    local view=controls.foodcrafting or controls.craftpot
                    local widget=controls.containers[p._cookpreviewpot]
                    local actual={};local visible,icons=0,0
                    if view then
                        for _,food in ipairs(view.selfoods or view.visible or {}) do
                            -- 刷新版状态在条目上，经典版状态在条目的 recipe 上。
                            local recipe=food.ready ~= nil and food or (food.recipe or food)
                            if recipe.readytocook or recipe.ready then actual[#actual+1]=recipe.name end
                        end
                        visible=#(view.selfoods or view.visible or {})
                        for _,slot in ipairs(view.foodslots or view.slots or {}) do
                            local item=slot.fooditem or slot.entry
                            if item and (slot.fooditem and slot.fooditem.shown or slot.entry and slot.icon and slot.icon.shown) then
                                icons=icons+1
                            end
                        end
                    end
                    local expected=p._cookpreviewstate
                    local matches=not expected.full and #actual==0 or expected.full and table.contains(actual,expected.product)
                    local opened=view and (view.IsOpen and view:IsOpen() or view.isopen) or false
                    local passed=not not (view and widget and opened and matches and (not expected.full or icons>0))
                    local nativeicons=0
                    local layoutchecks={}
                    if COOK_PREVIEW_MOD_COOKERS and index==8 then
                        local pos=view:GetPosition()
                        local restored=not view.cookpreviewlayout2hm and math.abs(pos.x-280)<.01 and math.abs(view:GetLooseScale()-.5)<.01
                        layoutchecks[#layoutchecks+1]={label='ordinary_restores_layout',passed=restored}
                        passed=passed and restored
                    end
                    if expected.rows and widget then
                        for _,slot in ipairs(widget.inv or {})do if slot.tile then nativeicons=nativeicons+1 end end
                        local c=p._cookpreviewpot.replica.container
                        passed=passed and widget.isopen and #widget.inv==expected.rows*6 and nativeicons>=5
                        if expected.full then passed=passed and c:GetItemInSlot(expected.rows*5+(expected.focusrow or expected.row))~=nil end
                        if view.FoodFocus then view:FoodFocus(1-view.idx) else view:FocusSlot(1-view.idx) end
                        Sleep(.3)
                        local function Apart(a,b)
                            return a and b and (a.r<=b.l+.1 or b.r<=a.l+.1 or a.t<=b.b+.1 or b.t<=a.b+.1)
                        end
                        local function Inside(a,last)
                            return a and a.l>=-.1 and a.b>=-.1 and a.r<=last.screenw+.1 and a.t<=last.screenh+.1
                        end
                        local function Inspect(label)
                            local l=view.cookpreviewlayout2hm
                            local last=l and l.last
                            local ok=last and Apart(last.container,last.bar) and Inside(last.bar,last)
                                and last.popup and Apart(last.popup,last.container) and Apart(last.popup,last.bar) and Inside(last.popup,last)
                            layoutchecks[#layoutchecks+1]={label=label,passed=not not ok,bounds=last}
                            passed=passed and ok
                        end
                        Inspect('initial')
                        if index==4 or index==6 then
                            local pos,scale=widget:GetPosition(),{widget:GetLooseScale()}
                            widget:SetPosition(pos.x+180,pos.y-100,pos.z)
                            widget:SetScale(scale[1]*1.3,scale[2]*1.3,scale[3]*1.3)
                            Sleep(.4)
                            Inspect('drag_and_scale')
                            widget:SetPosition(pos);widget:SetScale(unpack(scale));Sleep(.3)
                            Inspect('restored')
                        end
                    end
                    emit({kind="case",index=index,prefab=spec[1],count=spec[2],expected=expected.product,full=expected.full,
                        actual=actual,visible=visible,icons=icons,widget=widget and widget.isopen or false,open=opened,
                        hooked=view and view.cookingrules2hm or false,nativeicons=nativeicons,rows=expected.rows,
                        row=expected.focusrow or expected.row,nativepreview=expected.preview,layout=layoutchecks,passed=not not passed})
                    Sleep(.3)
                end
            end
            emit({kind="finished"})
        end)
    end)
end)
