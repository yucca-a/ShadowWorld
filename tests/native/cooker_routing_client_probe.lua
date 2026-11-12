local G=GLOBAL
local json=require("json")
local specs={"cookpot","portablecookpot","medal_cookpot","dragonflyfurnace",
    "simmeredmoonlight","simmeredmoonlight_pro","simmeredmoonlight_inf","simmeredmoonlight_pro_inf"}
local names={"meat","smallmeat","monstermeat","carrot","corn","pumpkin","eggplant","durian","dragonfruit","pomegranate",
    "berries","berries_juicy","butterflywings","twigs","honey","ice","cutlichen","cactus_meat","green_cap","red_cap"}
local fixtures={}
AddClientModRPCHandler("CookingPreviewAudit","routing",function(raw,inst)
    G.ThePlayer._cookrouteresult=json.decode(raw)
    G.ThePlayer._cookrouteinst=inst
end)
local function Snapshot(c)
    local slots={}
    for i=1,c:GetNumSlots()do local item=c:GetItemInSlot(i);slots[tostring(i)]=item and item.prefab or false end
    return slots
end
AddModRPCHandler("CookingPreviewAudit","routing",function(p,action,index)
    print("[COOK ROUTE SERVER]",action,index)
    local inv=p.components.inventory
    if action=="prepare" then
        local old=fixtures[p];if old then old.components.container:Close(p);old:Remove()end
        inv:DestroyContents()
        local pot=G.SpawnPrefab(specs[index]);fixtures[p]=pot
        pot.Transform:SetPosition(p.Transform:GetWorldPosition())
        if pot.components.fueled then pot.components.fueled:SetPercent(1)end
        pot.components.container:Open(p)
    elseif action=="item"then
        inv:GiveItem(G.SpawnPrefab(index),1)
    end
    local pot=fixtures[p]
    p:DoTaskInTime(action=="prepare" and .5 or 0,function()
        G.SendModRPCToClient(G.GetClientModRPC("CookingPreviewAudit","routing"),p.userid,
            json.encode({slots=Snapshot(pot.components.container),rows=pot.fiveslotrows2hm,inventory=Snapshot(inv)}),pot)
    end)
end)
function CookerRoutingClientProbe(p,emit)
    local function request(action,index)
        p._cookrouteresult=nil
        G.SendModRPCToServer(G.GetModRPC("CookingPreviewAudit","routing"),action,index)
        local deadline=G.GetStaticTime()+15
        repeat G.Sleep(.1)until p._cookrouteresult or G.GetStaticTime()>deadline
        assert(p._cookrouteresult,"routing fixture response")
        return p._cookrouteresult
    end
    for index,name in ipairs(specs)do
        local state=request("prepare",index)
        G.Sleep(.4)
        local pot=p._cookrouteinst
        local order={}
        if state.rows then
            for row=1,state.rows do
                order[#order+1]=state.rows*5+row
                for col=1,4 do order[#order+1]=(row-1)*5+col end
            end
        elseif name=="dragonflyfurnace"then order={1,2,3,4,5}
        else order={1,2,3,4,5}end
        local expected,checks={},{}
        for step,slot in ipairs(order)do
            local prefab=name=="dragonflyfurnace"and step==1 and "redgem"or names[name=="dragonflyfurnace"and step-1 or step]
            request("item",prefab);G.Sleep(.3)
            local inv=p.replica.inventory
            local from
            for i=1,inv:GetNumSlots()do local item=inv:GetItemInSlot(i);if item and item.prefab==prefab then from=i;break end end
            assert(from,"routing test inventory ingredient")
            local predicted=pot.replica.container:GetSpecificSlotForItem(inv:GetItemInSlot(from))
            inv:MoveItemFromAllOfSlot(from,pot)
            expected[tostring(slot)]=prefab
            G.Sleep(.4)
            state=request("state")
            -- Standard pots use the native free-slot scan (no specific slot).
            local passed=predicted==slot or (predicted==nil and not pot.replica.container.usespecificslotsforitems)
            for k,v in pairs(state.slots)do passed=passed and v==(expected[k]or false)end
            for k,v in pairs(state.slots)do
                local item=pot.replica.container:GetItemInSlot(tonumber(k))
                passed=passed and (item and item.prefab or false)==v
            end
            checks[#checks+1]={step=step,target=slot,predicted=predicted,passed=not not passed}
        end
        request("item","garlic");G.Sleep(.3)
        p.replica.inventory:MoveItemFromAllOfSlot(1,pot);G.Sleep(.4)
        state=request("state")
        local passed=state.inventory["1"]=="garlic"
        for _,check in ipairs(checks)do passed=passed and check.passed end
        for k,v in pairs(state.slots)do passed=passed and v==(expected[k]or false)end
        emit({kind="routing",prefab=name,checks=checks,fullrejected=state.inventory["1"]=="garlic",passed=not not passed})
    end
end
