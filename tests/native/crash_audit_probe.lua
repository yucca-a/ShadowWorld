function A.crash_audit()
    local player=A.player(1)
    player.sg:GoToState("idle")
    if not player.components.playercontroller then player:AddComponent("playercontroller") end
    player.components.playercontroller:Enable(true)
    local rows={}
    local function check(name,fn)
        local ok,result=pcall(fn)
        rows[#rows+1]={name=name,passed=ok and result~=false}
        if not ok then print("[CrashAudit]",name,result) end
    end
    check("bad_container_rpcs",function()
        for _,name in ipairs({"cookbtn2hm","destroybtn2hm","sortbtn2hm","collectrecipetypebtn2hm","searchcollect2hm","collectfoodingredient2hm"}) do
            local exists,fn=pcall(GetModRPCHandler,"MOD_HARDMODE",name)
            if exists and type(fn)=="function" then
                fn(player,nil)
                fn(player,"cutstone",{})
                fn(player,{prefab="dragonflyfurnace"})
            end
        end
    end)
    check("bad_shard_data",function()
        local fn=GetShardModRPCHandler("MOD_HARDMODE","ms_prototyper_update")
        fn("2",false,nil);fn("2",false,{});fn("2",false,"return true");fn("2",false,"return 7")
    end)
    check("furnace_cook_preserves_ruby",function()
        local furnace=SpawnPrefab("dragonflyfurnace")
        furnace.Transform:SetPosition(player.Transform:GetWorldPosition())
        local container=furnace.components.container
        local ruby=SpawnPrefab("redgem")
        local carrot=SpawnPrefab("carrot")
        container:GiveItem(ruby,1);container:GiveItem(carrot,2);container:Open(player)
        GetModRPCHandler("MOD_HARDMODE","cookbtn2hm")(player,furnace)
        local output=container:GetItemInSlot(2)
        emit({kind="furnace_audit_detail",opened=container:IsOpenedBy(player),
            allowed=require("rpcguard2hm").CanUseFurnace(player,furnace),
            output=output and output.prefab,ruby=container:GetItemInSlot(1)==ruby})
        local good=output and output.prefab=="carrot_cooked" and container:GetItemInSlot(1)==ruby
        if output then container:RemoveItemBySlot(2):Remove() end
        local invalid=SpawnPrefab("carrot")
        invalid.components.cookable.Cook=function()return nil end
        container:GiveItem(invalid,2)
        GetModRPCHandler("MOD_HARDMODE","cookbtn2hm")(player,furnace)
        good=good and invalid:IsValid() and container:GetItemInSlot(2)==invalid and container:GetItemInSlot(1)==ruby
        container:DestroyContents();furnace:Remove()
        return good
    end)
    local prefabs={"nightsword","glasscutter","eyebrellahat","wx78","wormwood","walter",
        "archive_orchestrina_small","archive_orchestrina_main","honey_trail","knight","bishop","rook",
        "crabking","klaus","klaus2hm","sharkboi","wagdrone_rolling","prime_mate","powder_monkey",
        "tacklestation","chester","tophat","researchlab2","winona_toolbox"}
    local index=0
    local function nextprefab()
        index=index+1
        local name=prefabs[index]
        if not name then
            local passed=true
            for _,row in ipairs(rows)do passed=passed and row.passed end
            emit({kind="crash_audit",passed=passed,rows=rows})
            return
        end
        local item
        check("spawn_"..name,function()
            item=SpawnPrefab(name)
            return item~=nil and item:IsValid()
        end)
        TheWorld:DoTaskInTime(.2,function()
            if item and item:IsValid() then
                check("save_"..name,function()
                    local record=item:GetSaveRecord()
                    return type(record)=="table" and record.prefab==name
                end)
                item:Remove()
            end
            nextprefab()
        end)
    end
    nextprefab()
end
