-- Disposable test cluster ONLY: creates test structures/player/items and rolls back.
local key, peerReady = "swx_prototyper_private_fixture_v2", {}
AddShardModRPCHandler("SWX_PRIVATE_TEST", "ready", function(peer, generation)
    peerReady[tostring(peer)] = generation
end)
AddShardModRPCHandler("SWX_PRIVATE_TEST", "stop", function()c_shutdown(false)end)
require("worldexchangerpc2hm").Install(GLOBAL, GetShardModRPC("SWX_PRIVATE_TEST", "ready"),
    GetShardModRPCHandler("SWX_PRIVATE_TEST", "ready"))
require("worldexchangerpc2hm").Install(GLOBAL, GetShardModRPC("SWX_PRIVATE_TEST", "stop"),
    GetShardModRPCHandler("SWX_PRIVATE_TEST", "stop"))
local uid = "KU_swx_private_check"
AddPrefabPostInit("world", function(inst)
    if not inst.ismastersim then return end
    assert(TheNet:GetServerName()=="ShadowWorld isolated private space test", "disposable private space cluster required")
    inst:PushEvent("ms_setautosaveenabled", false)
    local phase, state, player, hat, baseline = "boot", nil, nil, nil, nil
    TheSim:GetPersistentString(key,function(ok,raw)
        if ok then local parsed,data=RunInSandboxSafe(raw);assert(parsed);state=data end
        phase="wait"
    end)
    local function check(ok,why)assert(ok,"PRIVATE_SPACE_TEST: "..why)end
    local function count(box)
        local item=box.components.container.slots[1]
        return item and item.prefab=="goldnugget" and item.components.stackable:StackSize() or 0
    end
    local function finish()
        print("[PRIVATE_SPACE_TEST] PRIVATE_ROLLBACK_PASS", baseline)
        local peer=next(inst.components.worldexchange2hm.peers)
        if peer then SendModRPCToShard(GetShardModRPC("SWX_PRIVATE_TEST","stop"),peer)end
        c_shutdown(false)
    end
    inst:DoStaticPeriodicTask(.1,function()
        local s=inst.components.worldexchange2hm;local e=s and s.engine
        if not e or not e.core:IsReady() or phase=="boot" then return end
        local peer=next(s.peers)
        if peer then SendModRPCToShard(GetShardModRPC("SWX_PRIVATE_TEST","ready"),peer,e.core.generation)end
        if not TheShard:IsMaster() then return end
        if phase=="wait" then
            phase="running"
            if state then
                baseline=state.baseline
                check(e.core.generation==baseline,"shared cut after rollback")
                local file=TheNet:GetUserSessionFile(s.session,uid)
                check(file,"restored player file")
                TheNet:DeserializeUserSession(file,function(ok,raw)
                    local parsed,record=RunInSandboxSafe(raw or "")
                    check(ok and parsed and record.prefab,"native player record")
                    local restored=SpawnSaveRecord(record)
                    check(restored,"spawn restored player")
                    restored.userid=uid
                    -- Private-container initialization is itself a zero-delay
                    -- task; don't depend on scheduler table iteration order.
                    restored:DoTaskInTime(.2,function()
                        local box=restored.magicianprivatecontainer2hm
                        check(box and box.master2hm==restored and count(box)==20,"bound private items restored")
                        check(restored:HasTag("magician") and restored:HasTag("shadowmagic"),"temporary permission restored")
                        finish()
                    end)
                end)
                return
            end
            for _,prefab in ipairs({"researchlab","researchlab2","researchlab3","researchlab4"})do
                local station=SpawnPrefab(prefab)
                check(station,"spawn station "..prefab)
                local saved=TheWorld.components.persistent2hm
                TheWorld.components.persistent2hm=nil
                station:Remove()
                TheWorld.components.persistent2hm=saved
            end
            print("[PRIVATE_SPACE_TEST] STATION_REMOVE_PASS")
            player=SpawnPrefab("wilson");player.userid=uid
            e:Joined(player,false)
            local station=SpawnPrefab("researchlab3")
            local fuel=SpawnPrefab("nightmarefuel");fuel.components.stackable:SetStackSize(4)
            check(station.components.trader:AcceptGift(player,fuel),"nightmare fuel accepted")
            check(player:HasTag("magician") and player:HasTag("shadowmagic"),"shadow permission granted")
            check(player.components.persistent2hm.data.shadowmagiccycle==inst.state.cycles,"permission expiry baseline")
            check(AllRecipes.tophat_magician~=nil,"native magician hat recipe")
            hat=SpawnPrefab("tophat");hat:onPreBuilt(player,nil,AllRecipes.tophat_magician)
            check(hat:HasTag("magiciantool"),"crafted magician hat")
            local heart=SpawnPrefab("shadowheart_infused")
            check(hat.components.repairable2hm.customrepair(hat,1,player,heart),"possessed atrium upgrade")
            check(hat:HasTag("magicianupgraded2hm") and not heart:IsValid(),"upgrade consumes one atrium")
            player.magicianhatupgraded2hm:set(true);player:AddTag("usingmagiciantool")
            TUNING.util2hm.OpenMagicianPrivate2hm(hat,player)
            local box=player.magicianprivatecontainer2hm
            check(box and box.master2hm==player,"player-bound container")
            box.components.container:DestroyContents()
            local gold=SpawnPrefab("goldnugget");gold.components.stackable:SetStackSize(20)
            check(box.components.container:GiveItem(gold,1),"fill private container")
            box.components.container:Close(player)
            print("[PRIVATE_SPACE_TEST] UNLOCK_UPGRADE_PRIVATE_PASS")
            phase="registration"
        elseif phase=="registration" and not e.core.registrations[uid] then
            phase="saving"
            SaveGame(false,function()
                baseline=e.core.generation
                local box=player.magicianprivatecontainer2hm
                box.components.container:DestroyContents()
                SerializeUserSession(player)
                phase="second_save"
            end)
        elseif phase=="second_save" and peerReady[peer]==e.core.generation then
            phase="saving"
            SaveGame(false,function()
                TheSim:SetPersistentString(key,DataDumper({baseline=baseline},nil,true),false,function(ok)
                    check(ok~=false,"fixture stage persisted")
                    print("[PRIVATE_SPACE_TEST] CALL_ROLLBACK",baseline)
                    c_rollback(1)
                end)
            end)
        end
    end)
end)
