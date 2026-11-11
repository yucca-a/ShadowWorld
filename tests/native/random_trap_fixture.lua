local trap_fixture_scale, trap_fixture_stack
for _, name in ipairs({"rabbit", "frog", "spider"}) do
    AddPrefabPostInit(name, function(inst)
        if not TheWorld.ismastersim then return end
        if trap_fixture_scale ~= nil then
            inst.ray_suijidaxiao, inst.myscale = 1, trap_fixture_scale
        end
        if trap_fixture_stack then
            if inst.components.stackable == nil then inst:AddComponent("stackable") end
            inst.components.stackable.maxsize = 20
        end
    end)
end
AddSimPostInit(function()
    if not TheWorld.ismastersim then return end
    assert(TheNet:GetServerName() == "ShadowWorld isolated random trap test")
    TheWorld:PushEvent("ms_setautosaveenabled", false)
    TheWorld:DoTaskInTime(2, function()
        local checks = 0
        local function check(ok, why)
            checks = checks + 1
            assert(ok, "RANDOM_TRAP: " .. why)
            print("[RANDOM_TRAP] PASS", why)
        end
        local x, _, z = TheWorld.components.playerspawner:GetAnySpawnPoint()
        local doer = SpawnPrefab("wilson")
        doer.Transform:SetPosition(x, 0, z)
        doer.components.sanity:SetPercent(1)
        doer.components.health:SetInvincible(true)
        local function count(prefab)
            local total = 0
            doer.components.inventory:ForEachItem(function(item)
                if item.prefab == prefab then total = total + (item.components.stackable and item.components.stackable:StackSize() or 1) end
            end)
            return total
        end
        local cases = {{"frog",1.5},{"frog",.75},{"rabbit",1.5},{"rabbit",.75},{"spider",1.5},{"rabbit",1.5,true}}
        local index = 0
        local function nextcase()
            index = index + 1
            local case = cases[index]
            if case == nil then
                print("[RANDOM_TRAP] ALL_PASS", checks)
                c_shutdown(false)
                return
            end
            trap_fixture_scale, trap_fixture_stack = case[2], case[3]
            local target = SpawnPrefab(case[1])
            target.entity:SetCanSleep(false)
            target.Transform:SetPosition(x+2,0,z)
            trap_fixture_scale = nil
            local base = target.components.health.maxhealth
            TheWorld:DoTaskInTime(.1, function()
                local maximum = target.components.health.maxhealth
                target.components.health:SetCurrentHealth(maximum*.6)
                local current = target.components.health.currenthealth
                local trap = SpawnPrefab("trap")
                trap.Transform:SetPosition(x+2,0,z)
                trap.components.trap.target = target
                trap.components.trap:DoSpring()
                check(not target:IsValid(), case[1].." captured native target")
                local data = trap.components.trap:OnSave()
                local record = trap:GetSaveRecord()
                trap:Remove()
                trap = SpawnSaveRecord(record)
                check(trap.components.trap.lootprefabs[1] == (case[1]=="frog" and "froglegs" or case[1]), "trap save record preserves reward")
                if case[1]=="frog" then
                    local before=count("froglegs")
                    trap.components.trap:Harvest(doer)
                    check(count("froglegs")-before==(case[2]>1.35 and 2 or 1),"actual frog materials follow random size")
                    trap:Remove();nextcase();return
                end
                local live
                local listener = function(_, item) if item.prefab == case[1] then live=item end end
                TheWorld:ListenForEvent("entity_spawned",listener)
                trap.components.trap:Harvest(doer)
                TheWorld:RemoveEventCallback("entity_spawned",listener)
                check(live~=nil and live.components.inventoryitem.owner==doer,"native live harvest reaches inventory")
                if not case[3] then
                    check(live.myscale==case[2] and live.components.health.maxhealth==maximum,"live item immediately keeps scale and max HP")
                    check(math.abs(live.components.health.currenthealth-current)<.001,"live item immediately keeps wounded HP")
                else
                    check(live.components.health.maxhealth==base,"stackable live catch uses original base HP")
                    check(data.lootdata==nil or data.lootdata.randomsizecapture2hm==nil,"stackable capture has no individual metadata")
                end
                TheWorld:DoTaskInTime(.1, function()
                    if not case[3] then
                        check(live.components.health.maxhealth==maximum and math.abs(live.components.health.currenthealth-current)<.001,"queued init does not reroll or rescale HP")
                        local saved=live:GetSaveRecord()
                        live:Remove();live=SpawnSaveRecord(saved)
                        doer.components.inventory:GiveItem(live)
                    end
                    TheWorld:DoTaskInTime(.1, function()
                        if not case[3] then
                            check(live.components.health.maxhealth==maximum and math.abs(live.components.health.currenthealth-current)<.001,"live save record keeps exact HP")
                        end
                        if case[1]=="rabbit" then
                            local before=count("smallmeat")
                            check(ACTIONS.MURDER.fn({doer=doer,invobject=live}),"native inventory murder succeeds")
                            local expected=not case[3] and case[2]>1.35 and 2 or 1
                            check(count("smallmeat")-before==expected,"inventory murder follows retained size and stack fallback")
                        else
                            live:Remove()
                        end
                        trap:Remove();trap_fixture_stack=nil;nextcase()
                    end)
                end)
            end)
        end
        nextcase()
    end)
end)
