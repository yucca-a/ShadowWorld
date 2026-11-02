function hp2hm_save()
    local player = ConsoleCommandPlayer()
    local pt = ConsoleWorldPosition()

    if player and player.components.inventory then
        local hand = player.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        if hand then
            local record = hand:GetSaveRecord()
            TheSim:SetPersistentString("./../../save_hand_record.data", DataDumper(record, nil, false), false)
            print("save", tostring(hand))
        end
    end
end

function hp2hm_load()
    local player = ConsoleCommandPlayer()
    local pt = ConsoleWorldPosition()

    TheSim:GetPersistentString("./../../save_hand_record.data",
        function(load_success, str)
            if load_success == true then
                local success, savedata = RunInSandboxSafe(str)
                if success and string.len(str) > 0 and savedata ~= nil then
                    local inst = SpawnSaveRecord(savedata)
                    inst.Transform:SetPosition(pt:Get())
                    print("load", tostring(inst))
                end
            else
                print ("Could not load save_hand_record.data")
            end
        end)
end