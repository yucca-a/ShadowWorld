-- 档案馆会旋转了
local function findlockbox(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local lockboxents = TheSim:FindEntities(x, y, z, 3, {"archive_lockbox"}, {"INLIMBO"})
    if #lockboxents > 0 then
        for i = #lockboxents, 1, -1 do
            if lockboxents[i].components.inventoryitem and lockboxents[i].components.inventoryitem.owner then table.remove(lockboxents, i) end
        end
    end
    return lockboxents
end
local SOCKETTEST_MUST = {"resonator_socket"}
-- 道具的顺序puzzle规定了GUID排序好的圆盘依次要第几个踩
local function resetpuzzlestart(inst)
    if inst and inst.puzzle then
        local x, y, z = inst.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities(x, y, z, 13, SOCKETTEST_MUST)
        local sockets = {}
        for i = #ents, 1, -1 do table.insert(sockets, ents[i]) end
        if #sockets ~= 8 then return end
        table.sort(sockets, function(a, b) return a.GUID < b.GUID end)
        for index, value in ipairs(inst.puzzle) do sockets[index].mustorder2hm = value end
        table.sort(sockets, function(a, b) return a.Transform:GetRotation() < b.Transform:GetRotation() end)
        -- local start = deepcopy(inst.puzzle)
        local up = math.random() < 0.5
        for index, v in ipairs(sockets) do
            if up then
                if index <= 7 then
                    v.newmustorder2hm = sockets[index + 1].mustorder2hm
                else
                    v.newmustorder2hm = sockets[1].mustorder2hm
                end
            else
                if index >= 2 then
                    v.newmustorder2hm = sockets[index - 1].mustorder2hm
                else
                    v.newmustorder2hm = sockets[8].mustorder2hm
                end
            end
        end
        table.sort(sockets, function(a, b) return a.GUID < b.GUID end)
        inst.puzzle = {}
        for index, v in ipairs(sockets) do
            table.insert(inst.puzzle, v.newmustorder2hm)
            v.newmustorder2hm = nil
            v.mustorder2hm = nil
        end
    end
end
local function resetpuzzleorder(inst)
    if inst and inst.puzzle then
        local up = math.random() < 0.5
        if up then
            for i, v in ipairs(inst.puzzle) do inst.puzzle[i] = v > 7 and 1 or (v + 1) end
        else
            for i, v in ipairs(inst.puzzle) do inst.puzzle[i] = v < 2 and 8 or (v - 1) end
        end
    end
end
AddPrefabPostInit("archive_orchestrina_main", function(inst)
    if not TheWorld.ismastersim then return end
    if inst.task and inst.task.fn and inst.task.period then
        local oldfn = inst.task.fn
        local oldperiod = inst.task.period
        inst.task:Cancel()
        inst.task = inst:DoPeriodicTask(oldperiod, function()
            if inst.failed and inst.oldlockboxes == 1 and inst.status == "on" and inst.numcount and inst.numcount > 1 and inst.numcount < 7 then
                local lockboxes = findlockbox(inst)
                if #lockboxes == 1 and lockboxes[1] and lockboxes[1]:IsValid() then
                    if lockboxes[1].product_orchestrina == "archive_resonator_item" or lockboxes[1].choosereset2hm == true then
                        resetpuzzlestart(lockboxes[1])
                        SpawnPrefab("collapse_big").Transform:SetPosition(lockboxes[1]:GetPosition():Get())
                    elseif lockboxes[1].product_orchestrina == "turfcraftingstation" or lockboxes[1].choosereset2hm == false then
                        resetpuzzleorder(lockboxes[1])
                        SpawnPrefab("collapse_big").Transform:SetPosition(lockboxes[1]:GetPosition():Get())
                    elseif lockboxes[1].product_orchestrina ~= "refined_dust" then
                        if not lockboxes[1].choosereset2hm then lockboxes[1].choosereset2hm = math.random() < 0.5 end
                        if lockboxes[1].choosereset2hm then
                            resetpuzzlestart(lockboxes[1])
                        else
                            resetpuzzleorder(lockboxes[1])
                        end
                        SpawnPrefab("collapse_big").Transform:SetPosition(lockboxes[1]:GetPosition():Get())
                    end
                end
            end
            oldfn(inst)
        end)
    end
end)

-- 屏蔽官方解密错误回退格子改动
local UpvalueHacker = require("upvaluehacker2hm")
AddPrefabPostInit("archive_orchestrina_small", function(inst)
    if not TheWorld.ismastersim then return end
    if not inst.task or type(inst.task.fn) ~= "function" then return end
    local oldfn = UpvalueHacker.GetUpvalue(inst.task.fn, "testforplayers", "testforcompletion")
    local function newfn(inst, ...)
        oldfn(inst, ...)
        if not inst.failed and inst.rollback then
            for i=1,7 do
            inst.SoundEmitter:KillSound("machine"..i)
            end
            inst.SoundEmitter:PlaySound("grotto/common/archive_orchestrina/stop")
            if inst.numcount == 1 then inst.numcount = inst.numcount + 1 end
            inst.failed = true
            inst.rollback = nil
        end
    end
    if oldfn then 
        UpvalueHacker.SetUpvalue(inst.task.fn, newfn, "testforplayers", "testforcompletion")
    end
end)

-- 档案馆生成字条提示解密改动
AddPrefabPostInit("archive_orchestrina_main", function(inst)
    if not TheWorld.ismastersim then return end
    inst:DoTaskInTime(0, function()
        if not inst.worldcreate2hm then
            inst.worldcreate2hm = true
            local x,y,z = inst.Transform:GetWorldPosition()
            local text = SpawnPrefab("wagstaff_item_2")
            text.Transform:SetPosition(x, 0, z)
            text.archive_orchestrina2hm = true
        end
    end)
    SetOnSave(inst, function(inst, data)
        if inst.worldcreate2hm then data.worldcreate2hm = true end
    end)
    SetOnLoad(inst, function(inst, data)
        if data and data.worldcreate2hm then inst.worldcreate2hm = true end
    end)
end)

AddPrefabPostInit("wagstaff_item_2", function(inst)
    if not TheWorld.ismastersim then return end
    inst.archive_orchestrina2hm = nil
    if inst.components.inspectable then
        local GetDescription = inst.components.inspectable.GetDescription
        inst.components.inspectable.GetDescription = function(self, ...)
            local desc, filter_context, author = GetDescription(self, ...)
            if inst.archive_orchestrina2hm then
                desc = (TUNING.isCh2hm and  "模组为爽而虐-困难模式解密改动" .. "\n" .. "星象探测仪: 踩错后答案整体顺时针或逆时针旋转一格" .. "\n" .. "土地夯实器: 踩错后所有格子统一变为错误前自身的下一格答案或错误前自身的上一格答案" .. "\n" .. "上述改动只在点亮至少一个格子后踩错触发,尘土块踩错不保留答案"
                or "Pacth For Happy mod - difficulty mode decryption changes." .. "\n" .. "Astral Detector: If you step incorrectly, the overall answer will rotate one position clockwise or counterclockwise." .. "\n" .. "Terra Firma Tamper: After stepping on the wrong square, all squares will uniformly change to the answer of the next square or the answer of the previous square before the mistake." .. "\n" .. "The aforementioned changes only trigger a mistake after at least one square is lit up, and errors made on dust blocks do not retain the answer.")
            end
            return  desc, filter_context, author
        end   
    end
    SetOnSave(inst, function(inst, data)
        if inst.archive_orchestrina2hm then data.archive_orchestrina2hm = true end
    end)
    SetOnLoad(inst, function(inst, data)
        if data and data.archive_orchestrina2hm then inst.archive_orchestrina2hm = true end
    end)
end)
