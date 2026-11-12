local G=GLOBAL
local json=require("json")
local fixtures={}
AddClientModRPCHandler("CookingPreviewAudit","collection",function(raw)
    G.ThePlayer._cookcollectresult=json.decode(raw)
end)
AddModRPCHandler("CookingPreviewAudit","collection",function(p, check)
    local function count(c, name)
        local _,n=c:Has(name,10000)
        return n or 0
    end
    if not check then
        for _,name in ipairs({"carrot","meat","monstermeat"})do p.components.inventory:ConsumeByName(name,10000)end
        local chest=G.SpawnPrefab("treasurechest")
        local x,y,z=p.Transform:GetWorldPosition();chest.Transform:SetPosition(x+2,y,z)
        for _,name in ipairs({"carrot","meat","monstermeat"})do
            local item=G.SpawnPrefab(name);item.components.stackable:SetStackSize(7);chest.components.container:GiveItem(item)
        end
        local blocked=G.SpawnPrefab("treasurechest");blocked.Transform:SetPosition(x-2,y,z);blocked.dcs2hm=true
        local item=G.SpawnPrefab("carrot");item.components.stackable:SetStackSize(7);blocked.components.container:GiveItem(item)
        fixtures[p]={chest=chest,blocked=blocked}
        G.SendModRPCToClient(G.GetClientModRPC("CookingPreviewAudit","collection"),p.userid,json.encode({prepared=true}))
    else
        local f=fixtures[p]
        local inv=p.components.inventory
        G.SendModRPCToClient(G.GetClientModRPC("CookingPreviewAudit","collection"),p.userid,json.encode({
            carrot=count(inv,"carrot"),meat=count(inv,"meat"),monster=count(inv,"monstermeat"),
            remainingcarrot=count(f.chest.components.container,"carrot"),remainingmeat=count(f.chest.components.container,"meat"),
            remainingmonster=count(f.chest.components.container,"monstermeat"),blocked=count(f.blocked.components.container,"carrot")
        }))
        f.chest:Remove();f.blocked:Remove();fixtures[p]=nil
    end
end)
function CookingIngredientClientProbe(p, emit)
    local function request(check)
        p._cookcollectresult=nil
        G.SendModRPCToServer(G.GetModRPC("CookingPreviewAudit","collection"),check)
        local deadline=G.GetStaticTime()+15
        repeat G.Sleep(.1)until p._cookcollectresult or G.GetStaticTime()>deadline
        assert(p._cookcollectresult,"collection fixture response")
        return p._cookcollectresult
    end
    request(false)
    local controls=p.HUD.controls
    local root=controls:AddChild(require("widgets/widget")("CollectionAudit"))
    local icons={}
    if COOK_PREVIEW_COMPLEX then
        local req=require("ui/recipe_popup_req_section")
        local section=req.Create(root,"min",0)
        req.UpdateEntries(section,{{type="name",key="carrot",is_tag=false},{type="tag",key="meat",is_tag=true}})
        icons={section.pool[1].img,section.pool[2].img}
    elseif package.loaded["widgets/foodingredientui"] or package.loaded["widgets/craftpot/foodingredientui"] then
        local path=package.loaded["widgets/foodingredientui"]and "widgets/foodingredientui"or "widgets/craftpot/foodingredientui"
        for _,elem in ipairs({{name="carrot",amt=1},{tag="meat",amt=1}})do
            local widget=root:AddChild(require(path)(elem,true,p));widget:Update(0)
            assert(widget.imgbtn2hm,"classic ingredient collection installed")
            icons[#icons+1]=widget.imgbtn2hm
        end
    else
        local popup=root:AddChild(require("craftpot/cp_foodpopup")(p))
        local layout={icons={{elem={members={"carrot"},amt=1},x=0,y=0},{elem={tag="meat",amt=1},x=80,y=0}},symbols={},zoom=1,shift=0}
        popup:SetEntry({name="meatballs",unlocked=true,cur=require("cooking").recipes.cookpot.meatballs},
            {layout={min=layout,max={icons={},symbols={},zoom=1,shift=0}}})
        popup:Show()
        icons={popup.wraps.min.icons[1].img,popup.wraps.min.icons[2].img}
    end
    root:Show()
    for _,icon in ipairs(icons)do
        icon:SetFocus();icon:OnControl(G.CONTROL_SECONDARY,true);icon:OnControl(G.CONTROL_SECONDARY,false)
        G.Sleep(.6)
    end
    G.Sleep(1)
    local r=request(true)
    r.kind="collection"
    r.passed=r.carrot==7 and r.meat==7 and r.monster==0 and r.remainingcarrot==0 and r.remainingmeat==0 and r.remainingmonster==7 and r.blocked==7
    emit(r)
    root:Kill()
end
