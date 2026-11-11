local function Play(p,step)
    local inv=p.replica.inventory
    local controls=p.HUD.controls
    local function command(action)SendModRPCToServer(GetModRPC("NexusPlayAudit","step"),action,step)end
    local function widget()return p._nexus_container and controls.containers[p._nexus_container]end
    local function container()return p._nexus_container and p._nexus_container.replica.container end
    local function qty(item)return item and (item.replica.stackable and item.replica.stackable:StackSize() or 1)end
    local function cursor(prefab,count)local item=inv:GetActiveItem();return item and item.prefab==prefab and qty(item)==count end
    local function item(slot)return container() and container():GetItemInSlot(slot)end
    local function entry(slot,prefab,count)local e=item(slot);return e and e.prefab==prefab and qty(e)==count end
    local function ready()return widget() and widget().isopen and container() and not container():IsBusy() and not container():IsReadOnlyContainer()end
    local function page(id)return p._nexus_state and p._nexus_state.page==id and ready()end
    local function wait(name,check)
        local deadline=GetStaticTime()+35
        repeat
            assert(not controls.shadowvaultpanel2hm,"custom UI must never be created")
            assert(not (p._nexus_state and p._nexus_state.error),"server native state healthy")
            if check() then Sleep(.3);if check() then return end end
            Sleep(.1)
        until GetStaticTime()>deadline
        error("[NEXUS PLAY] timed out "..name.." round="..step.." page="..tostring(p._nexus_state and p._nexus_state.page))
    end
    local function close()
        command("close")
        wait("native close",function()return not widget()end)
    end
    local shard=step%2==1 and "1" or "2"
    local other=shard=="1" and "2" or "1"
    local function travel(target)
        wait("native travel button",function()return ready() and widget().exchangebutton2hm and widget().exchangebutton2hm:IsEnabled()end)
        widget().exchangebutton2hm.onclick()
        wait("page "..target,function()return page(target)end)
    end
    command("start");Sleep(.5)
    wait("native armor tint replicated",function()
        local boss=p._armor_test_boss
        local colour=boss and boss.components.colouradder and boss.components.colouradder.colour
        return colour and colour[1]>.08 and colour[1]<.2 and colour[2]<colour[1]*.2
    end)
    print("[NEXUS PLAY] ARMOR TINT PASS",unpack(p._armor_test_boss.components.colouradder.colour))
    Sleep(15)
    for i=1,3 do
        command("shadow");wait("shadow",function()return page(shard)end)
        assert(container():GetNumSlots()==12 and math.abs(widget().inst.UITransform:GetScale()-.6)<.001)
        if i==1 then
            command("chester")
            wait("native Chester exclusion",function()
                if widget() then return false end
                for e in pairs(inv:GetOpenContainers())do if e.prefab=="chester" then return true end end
            end)
        else close() end
    end
    command("tackle");wait("tackle",function()return page("tackle_"..shard)end)
    assert(container():GetNumSlots()==20)
    travel("tackle_"..other);travel("tackle_"..shard)
    command("seeds");wait("seeds",function()return cursor("seeds",6) and ready()end)
    widget().inv[20]:Click(false)
    wait("native tackle deposit",function()return entry(20,"seeds",6) and not inv:GetActiveItem() and ready()end)
    widget().inv[20]:Click(false)
    wait("native tackle take",function()return cursor("seeds",6) and not item(20) and ready()end)
    command("clear_seeds")
    command("shadow");wait("shadow after tackle",function()return page(shard)end)
    travel(other);travel(shard);travel(other)
    command("gift");wait("gift",function()return cursor("gift",1) and ready()end)
    local clicktime=GetStaticTime()
    widget().inv[12]:Click(false)
    repeat Sleep(.01) until p._nexus_state.item12=="gift" and not p._nexus_state.held or GetStaticTime()-clicktime>3
    local latency=GetStaticTime()-clicktime
    assert(p._nexus_state.item12=="gift" and not p._nexus_state.held,"server acknowledges native item action")
    print("[NEXUS PLAY] NATIVE ITEM ACK "..step.." "..latency)
    wait("native gift deposit",function()return entry(12,"gift",1) and not inv:GetActiveItem() and ready()end)
    local tile=assert(widget().inv[12].tile)
    print("[NEXUS PLAY] TILE ID",tile.item and tile.item.GUID,item(12)and item(12).GUID,tile.item==item(12))
    wait("native ItemTile entity",function()return widget().inv[12].tile and widget().inv[12].tile.item.GUID==item(12).GUID end)
    tile=widget().inv[12].tile
    assert(tile.item.GUID==item(12).GUID and tile:is_a(require("widgets/itemtile")),"unmodified native ItemTile holds the replicated entity")
    local replica=item(12).replica.inventoryitem
    assert(TheSim:AtlasContains(replica:GetAtlas(),replica:GetImage()),"native dynamic gift icon")
    close();command("shadow");wait("reopen",function()return page(shard)end)
    travel(other)
    wait("gift after reopen",function()return entry(12,"gift",1)end)
    widget().inv[12]:Click(false)
    wait("native gift withdrawal",function()return cursor("gift",1) and not item(12) and ready()end)
    command("verify");command("gold")
    local bag_slot
    wait("inventory gold",function()
        if not ready() then return false end
        for i in pairs(controls.inv.inv)do
            local e=inv:GetItemInSlot(i)
            if e and e.prefab=="goldnugget" and qty(e)==18 then bag_slot=i;return true end
        end
    end)
    controls.inv.inv[bag_slot]:TradeItem(false)
    local stack_slot
    wait("native shortcut deposit",function()
        if inv:GetItemInSlot(bag_slot) or not ready()then return false end
        for i=1,container():GetNumSlots()do if entry(i,"goldnugget",18)then stack_slot=i;return true end end
    end)
    widget().inv[stack_slot]:Click(true)
    wait("native split",function()return entry(stack_slot,"goldnugget",9) and cursor("goldnugget",9) and ready()end)
    widget().inv[stack_slot]:Click(false)
    wait("native merge",function()return entry(stack_slot,"goldnugget",18) and not inv:GetActiveItem() and ready()end)
    command("swap");wait("axe",function()return cursor("axe",1)and ready()end)
    widget().inv[stack_slot]:Click(false)
    wait("native swap",function()return entry(stack_slot,"axe",1)and cursor("goldnugget",18)and ready()end)
    local axe_tile=widget().inv[stack_slot].tile
    wait("native axe durability",function()return axe_tile.percent and axe_tile.percent:GetString()=="31%"end)
    widget().inv[stack_slot]:Click(false)
    wait("swap back",function()return entry(stack_slot,"goldnugget",18)and cursor("axe",1)and ready()end)
    widget().inv[11]:Click(false)
    wait("axe stored",function()return entry(11,"axe",1)and not inv:GetActiveItem()and ready()end)
    widget().inv[stack_slot]:TradeItem(false)
    wait("gold shortcut",function()return not item(stack_slot)and not inv:GetActiveItem()and ready()end)
    widget().inv[11]:TradeItem(false)
    wait("axe shortcut",function()return not item(11)and not inv:GetActiveItem()and ready()end)
    close()
    command("hat");wait("native possessed hat",function()return page(shard)and widget().privatespacebtn2hm end)
    widget().privatespacebtn2hm.onclick()
    wait("native private",function()
        for e in pairs(inv:GetOpenContainers())do if e.prefab=="magician_private_container2hm"then return true end end
    end)
    command("leave_private");Sleep(.5)
    command("shadow");wait("shadow after private",function()return page(shard)end)
    close()
    command("armorfade")
    wait("native armor tint cleared",function()
        local boss=p._armor_test_boss
        return boss and boss.components.colouradder and boss.components.colouradder.colour[1]<.001
    end)
    print("[NEXUS PLAY] ARMOR CLEAN PASS")
    print("[NEXUS PLAY] CLIENT PASS "..step)
    command("finish")
end
AddSimPostInit(function()
    if TheWorld.ismastersim then return end
    TheWorld:DoStaticPeriodicTask(.15,function()
        local p=ThePlayer
        if not p or not p.HUD or not p._nexus_play_step then return end
        SendModRPCToServer(GetModRPC("NexusPlayAudit","query"))
        if p._nexus_play_started then return end
        p._nexus_play_started=true
        p:StartThread(function()Play(p,p._nexus_play_step)end)
    end)
end)
