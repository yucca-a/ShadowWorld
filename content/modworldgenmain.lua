local Layouts = GLOBAL.require("map/layouts").Layouts
GLOBAL.require("map/lockandkey")
local ocean_gen_config = GLOBAL.require("map/ocean_gen_config")
local storygen = GLOBAL.require("map/storygen")
------------------------------------------------------------------------------------------------------------------------------------------
-- 移除洞口周围的空白地皮设定
local hardcaveentrance = GetModConfigData("enable hard mode") and GetModConfigData("other_change") and GetModConfigData("cave_entrance") == true
if hardcaveentrance and Layouts and Layouts.CaveEntrance and Layouts.CaveEntrance.ground then Layouts.CaveEntrance.ground = {} end

-- 大幅度更改地表地洞的地形
local hardworldgen = GetModConfigData("enable hard mode") and GetModConfigData("other_change") and GetModConfigData("worldgen")
if hardworldgen then
    -- 地图形状随机
    local branchingmodes = {"most", "most", "default", "random", "least", "least", "never", "never"}
    local loopmodes = {"never", "never", "default", "always", "always"}
    AddLevelPreInitAny(function(level)
        -- 移除道路
        if level.overrides.roads ~= "never" and math.random() < 0.8 then level.overrides.roads = "never" end
        -- 允许岛屿存在
        if level.location == "forest" then level.overrides.islands = "always" end
        -- 随机分支
        if level.overrides.branching == "default" or level.overrides.branching == nil then
            level.overrides.branching = branchingmodes[math.random(#branchingmodes)]
        end
        -- 随机循环
        if level.overrides.loop == "default" or level.overrides.loop == nil then level.overrides.loop = loopmodes[math.random(#loopmodes)] end
    end)
    ------------------------------------------------------------------------------------------------------------------------------------------
    -- 浅海和中海地皮变少
    local shallow = math.random(35, 70)
    if ocean_gen_config and ocean_gen_config.final_level_shallow then
        ocean_gen_config.final_level_shallow = shallow / 100
        ocean_gen_config.final_level_medium = math.random(5, shallow - 20) / 100
    end
    ------------------------------------------------------------------------------------------------------------------------------------------
    -- 月岛不再环形
    local moonislandtasks = {"MoonIsland_IslandShards", "MoonIsland_Beach"}
    local function settasknotloop(task) task.make_loop = nil end
    for _, task in ipairs(moonislandtasks) do AddTaskSetPreInit(task, settasknotloop) end
    ------------------------------------------------------------------------------------------------------------------------------------------
    -- -- 移除不想要的地形,比如第二个桦树林
    -- AddTaskSetPreInit("default", function(taskset)
    --     for i = #taskset.optionaltasks, 1, -1 do
    --         if taskset.optionaltasks[i] == "Mole Colony Deciduous" then
    --             table.remove(taskset.optionaltasks, i)
    --             break
    --         end
    --     end
    -- end)
    ------------------------------------------------------------------------------------------------------------------------------------------
    -- 地表生成的地形概率变为岛屿地形
    -- 该房间可以是岛屿
    -- print("hardworldgen", hardworldgen)
    local islandlevel = hardworldgen == true and math.random(0, 4) or (-hardworldgen - 1)
    if islandlevel > 4 then
        islandlevel = 4
    end
    local islandtasks = {}
    if islandlevel > 0 then
        local mainlandtasks_maybeisland = -- {"Dig that rock", "Squeltch", "Beeeees!", "Speak to the king", "Forest hunters"}
        {"Dig that rock", "Great Plains", "Squeltch", "Beeeees!", "Speak to the king", "Forest hunters", "Badlands", "For a nice walk", "Lightning Bluff"}
        local optionaltasks_maybeisland = {
            "Befriend the pigs",
            "Kill the spiders",
            "Killer bees!",
            "Make a Beehat",
            "The hunters",
            "Magic meadow",
            "Frogs and bugs",
            "Mole Colony Deciduous",
            "Mole Colony Rocks",
            "MooseBreedingTask"
        }
        local moonislandtasks_maybeisland = {"MoonIsland_Beach", "MoonIsland_Forest", "MoonIsland_Baths", "MoonIsland_Mine"}
        local islandrooms = {"Forest", "Clearing", "FlowerPatch"}

        if hardworldgen == -6 then
            local cave_maybeisland = {
                -- "MudWorld",
                -- "MudCave",
                -- "MudLights",
                -- "MudPit",

                -- "BigBatCave",
                -- "RockyLand",
                -- "RedForest",
                -- "GreenForest",
                -- "BlueForest",
                -- "SpillagmiteCaverns",

                -- "MoonCaveForest",
                -- "ArchiveMaze",

                -- "LichenLand",
                -- "Residential",
                -- "Military",
                -- "Sacred",
                -- "TheLabyrinth",
                -- "SacredAltar",
                -- "AtriumMaze",

                -- "SwampySinkhole",
                -- "CaveSwamp",
                -- "UndergroundForest",
                -- "PleasantSinkhole",
                -- "FungalNoiseForest",
                -- "FungalNoiseMeadow",
                -- "BatCloister",
                -- "RabbitTown",
                -- "RabbitCity",
                -- "SpiderLand",
                -- "RabbitSpiderWar",
            }
            -- function GLOBAL.print_lockandkey_ex(...)
            --     -- print(...)
            -- end
            -- function GLOBAL.print_lockandkey(...)
            --     -- print(...)
            -- end

            local ignoreTask = {"MoonIsland_IslandShards"}
            local newTasks = {}
            local function initislandroom(room)
                -- print("remove room entrance")
                room.entrance = false
                room.random_node_entrance_weight = nil
                room.random_node_exit_weight = nil
            end
            local splitTask = function(task)
                if not table.contains(mainlandtasks_maybeisland, task.id) and not table.contains(optionaltasks_maybeisland, task.id) and not table.contains(cave_maybeisland, task.id) then
                    return
                end
                if task.room_choices and not table.contains(ignoreTask, task.id) then
                    -- print("尝试拆分", task.id)
                    local list = {}
                    for k, v in pairs(task.room_choices) do
                        local maxV = 0
                        for _ = 1, 10 do
                            maxV = math.max(maxV, GLOBAL.FunctionOrValue(v))
                        end
                        local tb = {k = k, v = maxV}
                        if tb.v > 0 then
                            table.insert(list, tb)
                        end
                    end
                    if #list > 0 then
                        for room, _ in pairs(task.room_choices) do
                            if not table.contains(islandrooms, room) then
                                table.insert(islandrooms, room)
                                AddRoomPreInit(room, initislandroom)
                            end
                        end
                        local remItem = table.remove(list, #list)
                        task.room_choices = {
                            [remItem.k] = 1,
                        }
                        remItem.v = remItem.v - 1
                        if remItem.v > 0 then
                            table.insert(list, remItem)
                        end
                        -- print("保留", task.id, remItem.k, remItem.v)
                        local index = 0
                        while #list > 0 do
                            index = index + 1
                            local remItem = table.remove(list, #list)
                            -- task.room_choices[remItem.k] = nil
                            local newTask = GLOBAL.deepcopy(task)
                            local newName = task.id .. "____" .. index
                            newTask.id = newName
                            newTask.baseid = task.id
                            newTask.make_loop = nil
                            newTask.room_choices = {
                                [remItem.k] = 1,
                            }
                            newTask.entrance_room = nil
                            newTask.entrance_room_chance = 0
                            newTask.room_bg = WORLD_TILES.IMPASSABLE
                            -- newTask.background_room = "Empty_Cove"
                            newTask.cove_room_name = "Blank"
                            newTask.crosslink_factor = 2
                            newTask.cove_room_chance = 1
                            newTask.cove_room_max_edges = 2
                            AddTask(newName, newTask)
                            newTasks[task.id] = newTasks[task.id] or {}
                            table.insert(newTasks[task.id], newTask.id)
                            -- print("拆分出", newName, remItem.k, remItem.v)

                            remItem.v = remItem.v - 1
                            if remItem.v > 0 then
                                table.insert(list, remItem)
                            end
                        end
                    end
                end
            end

            local Tasks = require"map/tasks"
            for _, taskName in pairs(Tasks.GetAllTaskNames()) do
                -- body
                -- print("拆分", taskName)
                splitTask(Tasks.GetTaskByName(taskName))
            end

            AddTaskSetPreInit("default", function(taskset)
                local new_tasks = {}
                for _, task in pairs(taskset.tasks) do
                    table.insert(new_tasks, task)
                    local news = newTasks[task]
                    if news then
                        for _, _task in pairs(news) do
                            table.insert(new_tasks, _task)
                            -- print("添加", _task, "到", task)
                        end
                    end
                end
                taskset.tasks = new_tasks
                local option_rate = taskset.numoptionaltasks / #taskset.optionaltasks
                local new_optionaltasks = {}
                for _, task in pairs(taskset.optionaltasks) do
                    table.insert(new_optionaltasks, task)
                    local news = newTasks[task]
                    if news then
                        for _, _task in pairs(news) do
                            table.insert(new_optionaltasks, _task)
                            -- print("添加", _task, "到", task)
                        end
                    end
                end
                taskset.optionaltasks = new_optionaltasks
                taskset.numoptionaltasks = math.ceil(#taskset.optionaltasks * option_rate * (0.5 + math.random() / 4))
            end)

            -- AddTaskSetPreInit("cave_default", function(taskset)
            --     local new_tasks = {}
            --     for _, task in pairs(taskset.tasks) do
            --         table.insert(new_tasks, task)
            --         local news = newTasks[task]
            --         if news then
            --             for _, _task in pairs(news) do
            --                 table.insert(new_tasks, _task)
            --                 -- print("添加", _task, "到", task)
            --             end
            --         end
            --     end
            --     taskset.tasks = new_tasks
            --     local option_rate = taskset.numoptionaltasks / #taskset.optionaltasks
            --     local new_optionaltasks = {}
            --     for _, task in pairs(taskset.optionaltasks) do
            --         table.insert(new_optionaltasks, task)
            --         local news = newTasks[task]
            --         if news then
            --             for _, _task in pairs(news) do
            --                 table.insert(new_optionaltasks, _task)
            --                 -- print("添加", _task, "到", task)
            --             end
            --         end
            --     end
            --     taskset.optionaltasks = new_optionaltasks
            --     taskset.numoptionaltasks = math.ceil(#taskset.optionaltasks * option_rate)
            -- end)
        end

        local function initislandroom(room) room.entrance = false end
        local function initislandtask(task)
            -- 该task不再与其他task接壤
            task.background_room = "Empty_Cove"
            task.cove_room_name = "Blank"
            task.room_bg = WORLD_TILES.IMPASSABLE
            task.crosslink_factor = 2
            task.cove_room_chance = 1
            task.cove_room_max_edges = 2
            task.entrance_room = nil
            task.entrance_room_chance = 0
            if hardworldgen == -6 then
                task.make_loop = nil
            end
            for room, _ in pairs(task.room_choices) do
                if not table.contains(islandrooms, room) then
                    table.insert(islandrooms, room)
                    AddRoomPreInit(room, initislandroom)
                end
            end
        end
        for _, room in ipairs(islandrooms) do if math.random() < islandlevel * 0.25 then AddRoomPreInit(room, initislandroom) end end
        -- 随机1~9个必定地形变成岛屿
        local islandtaskindex, islandtask
        for i = 1, math.clamp(math.floor(math.random(islandlevel * 5, islandlevel * 10 + 15) / 5), islandlevel, islandlevel * 2 + 1) do
            if #mainlandtasks_maybeisland == 0 then break end
            islandtaskindex = math.random(#mainlandtasks_maybeisland)
            islandtask = mainlandtasks_maybeisland[islandtaskindex]
            table.insert(islandtasks, islandtask)
            AddTaskPreInit(islandtask, initislandtask)
            table.remove(mainlandtasks_maybeisland, islandtaskindex)
        end
        -- 随机1~10个可选地形变成岛屿
        for i = 1, math.clamp(math.floor(math.random(islandlevel * 5, islandlevel * 5 + 30) / 5), islandlevel, 6 + islandlevel) do
            if #optionaltasks_maybeisland == 0 then break end
            islandtaskindex = math.random(#optionaltasks_maybeisland)
            islandtask = optionaltasks_maybeisland[islandtaskindex]
            table.insert(islandtasks, islandtask)
            AddTaskPreInit(islandtask, initislandtask)
            table.remove(optionaltasks_maybeisland, islandtaskindex)
        end
        -- 随机1~4个月岛地形变成岛屿
        for i = 1, math.clamp(math.floor(math.random(4 + islandlevel * 5) / 5), 1, islandlevel) do
            if #moonislandtasks_maybeisland == 0 then break end
            islandtaskindex = math.random(#moonislandtasks_maybeisland)
            islandtask = moonislandtasks_maybeisland[islandtaskindex]
            table.insert(islandtasks, islandtask)
            AddTaskPreInit(islandtask, initislandtask)
            table.remove(moonislandtasks_maybeisland, islandtaskindex)
        end
    end
    ------------------------------------------------------------------------------------------------------------------------------------------
    -- 月岛和大陆符合一定条件则不再有浅海地皮连接
    if storygen then
        local _LinkRegions = storygen.LinkRegions
        if storygen.LinkRegions then
            storygen.LinkRegions = function(self, ...)
                local oldAddNode = GLOBAL.Graph and GLOBAL.Graph.AddNode
                local oldAddEdge = GLOBAL.Graph and GLOBAL.Graph.AddEdge
                GLOBAL.Graph.AddNode = function(self, ...)
                    if self.data and self.data.background == "MoonIsland_Meadows" then self.data.background = "BGImpassable" end
                    return oldAddNode(self, ...)
                end
                GLOBAL.Graph.AddEdge = function(self, ...)
                    if self.data and self.data.background == "MoonIsland_Meadows" then self.data.background = "BGImpassable" end
                    return oldAddEdge(self, ...)
                end
                _LinkRegions(self, ...)
                GLOBAL.Graph.AddNode = oldAddNode
                GLOBAL.Graph.AddEdge = oldAddEdge
            end
        end
    end
    if storygen then
        local _LinkRegions = storygen.LinkRegions
        if storygen.LinkRegions then
            if shallow > 50 then
                storygen.LinkRegions = function(self, ...)
                    local old = GLOBAL.WORLD_TILES.OCEAN_COASTAL
                    GLOBAL.WORLD_TILES.OCEAN_COASTAL = GLOBAL.WORLD_TILES.OCEAN_SWELL
                    _LinkRegions(self, ...)
                    GLOBAL.WORLD_TILES.OCEAN_COASTAL = old
                end
            end
        end
        local SeperateStoryByBlanks = storygen.SeperateStoryByBlanks
        if _LinkRegions and SeperateStoryByBlanks then
            storygen.SeperateStoryByBlanks = function(self, startnode, endnode, ...)
                if (table.contains(islandtasks, startnode.data.task) or table.contains(islandtasks, endnode.data.task)) then
                    if islandlevel < 2 or table.contains(moonislandtasks_maybeisland, startnode.data.task) or
                        table.contains(moonislandtasks_maybeisland, endnode.data.task) then
                        _LinkRegions(self, {node = startnode}, endnode)
                    else
                        storygen.LinkRegions(self, {node = startnode}, endnode)
                    end
                    return
                end
                SeperateStoryByBlanks(self, startnode, endnode, ...)
            end
        end
    end
    ------------------------------------------------------------------------------------------------------------------------------------------
    -- 地下沼泽地形现在变为必刷地形
    if math.random() < 0.75 then
        AddTaskSetPreInit("cave_default", function(taskset)
            for i = #taskset.optionaltasks, 1, -1 do
                if taskset.optionaltasks[i] == "SwampySinkhole" then
                    table.remove(taskset.optionaltasks, i)
                    break
                end
            end
            table.insert(taskset.tasks, "SwampySinkhole")
        end)
        -- 地下沼泽地形替换为中央地形
        local lasttasktoexchange
        local function exchangetaskkeylocks(task)
            if lasttasktoexchange == nil then
                lasttasktoexchange = task
            else
                local keys_given = lasttasktoexchange.keys_given
                local locks = lasttasktoexchange.locks
                lasttasktoexchange.keys_given = task.keys_given
                lasttasktoexchange.locks = task.locks
                task.keys_given = keys_given
                task.locks = locks
            end
        end
        AddTaskPreInit("SwampySinkhole", exchangetaskkeylocks)
        AddTaskPreInit("MudWorld", exchangetaskkeylocks)
    end
    ------------------------------------------------------------------------------------------------------------------------------------------
    -- 月亮蘑菇档案馆连接到随机地形,可能是远古入口地形
    AddTaskPreInit("MoonCaveForest", function(task) task.locks = {GLOBAL.LOCKS.TIER3} end)
    ------------------------------------------------------------------------------------------------------------------------------------------
    -- 地下3级地形有3个升级地形
    local function updatetile3(task)
        local chance = math.random() < 0.5
        for i = #task.locks, 1, -1 do
            if task.locks[i] == GLOBAL.LOCKS.TIER3 then
                table.remove(task.locks, i)
                table.insert(task.locks, chance and GLOBAL.LOCKS.TIER2 or GLOBAL.LOCKS.TIER1)
                break
            end
        end
        for i = #task.keys_given, 1, -1 do
            if task.keys_given[i] == GLOBAL.KEYS.TIER4 then
                table.remove(task.keys_given, i)
                table.insert(task.keys_given, chance and GLOBAL.KEYS.TIER3 or GLOBAL.KEYS.TIER2)
                break
            end
        end
    end
    local tile3cavetasks = {
        -- "SwampySinkhole",
        "CaveSwamp",
        "UndergroundForest",
        "PleasantSinkhole",
        -- "SoggySinkhole",
        "FungalNoiseForest",
        "FungalNoiseMeadow",
        "BatCloister",
        "RabbitTown",
        "RabbitCity",
        "SpiderLand",
        "RabbitSpiderWar",
        "CentipedeCaveTask",
    }
    -- 升级地形1
    local updatetile3taskindex = math.random(#tile3cavetasks)
    local updatetile3task = tile3cavetasks[updatetile3taskindex]
    AddTaskPreInit(updatetile3task, updatetile3)
    -- 升级地形2
    table.remove(tile3cavetasks, updatetile3taskindex)
    updatetile3taskindex = math.random(#tile3cavetasks)
    updatetile3task = tile3cavetasks[updatetile3taskindex]
    AddTaskPreInit(updatetile3task, updatetile3)
    -- 升级地形3
    table.remove(tile3cavetasks, updatetile3taskindex)
    updatetile3taskindex = math.random(#tile3cavetasks)
    updatetile3task = tile3cavetasks[updatetile3taskindex]
    AddTaskPreInit(updatetile3task, updatetile3)
    ------------------------------------------------------------------------------------------------------------------------------------------
    -- 地下2级地形有一个升级地形有一个颠倒地形
    local tile2cavetasks = {"BigBatCave", "RockyLand", "RedForest", "GreenForest", "BlueForest", "SpillagmiteCaverns"}
    -- 升级地形
    local updatetile2taskindex = math.random(#tile2cavetasks)
    local updatetile2task = tile2cavetasks[updatetile2taskindex]
    AddTaskPreInit(updatetile2task, function(task)
        for i = #task.locks, 1, -1 do
            if task.locks[i] == GLOBAL.LOCKS.TIER2 then
                table.remove(task.locks, i)
                table.insert(task.locks, GLOBAL.LOCKS.TIER1)
                break
            end
        end
        for i = #task.keys_given, 1, -1 do
            if task.keys_given[i] == GLOBAL.KEYS.TIER3 then
                table.remove(task.keys_given, i)
                table.insert(task.keys_given, GLOBAL.KEYS.TIER2)
                break
            end
        end
    end)
    -- 颠倒地形
    table.remove(tile2cavetasks, updatetile2taskindex)
    local tile2task = tile2cavetasks[math.random(#tile2cavetasks)]
    AddTaskPreInit(tile2task, function(task)
        for i = #task.locks, 1, -1 do
            if task.locks[i] == GLOBAL.LOCKS.TIER2 then
                table.remove(task.locks, i)
                table.insert(task.locks, GLOBAL.LOCKS.TIER3)
                break
            end
        end
        for i = #task.keys_given, 1, -1 do
            if task.keys_given[i] == GLOBAL.KEYS.TIER3 then
                table.remove(task.keys_given, i)
                table.insert(task.keys_given, GLOBAL.KEYS.TIER2)
                break
            end
        end
    end)
    ------------------------------------------------------------------------------------------------------------------------------------------
    -- 地下某些地形有一个远古预备入口,有一个是远古入口
    -- 远古入口标签管理
    local keycount = 0
    for k, v in pairs(GLOBAL.KEYS) do keycount = keycount + 1 end
    GLOBAL.KEYS.RUINSSTART2HM = keycount + 1
    GLOBAL.KEYS.RUINSSTARTPRE2HM = keycount + 1
    local lockcount = 0
    for k, v in pairs(GLOBAL.LOCKS) do lockcount = lockcount + 1 end
    GLOBAL.LOCKS.RUINSSTART2HM = lockcount + 1
    GLOBAL.LOCKS.RUINSSTARTPRE2HM = lockcount + 1
    GLOBAL.LOCKS_KEYS[GLOBAL.LOCKS.RUINSSTART2HM] = {GLOBAL.KEYS.RUINSSTART2HM}
    GLOBAL.LOCKS_KEYS[GLOBAL.LOCKS.RUINSSTARTPRE2HM] = {GLOBAL.KEYS.RUINSSTARTPRE2HM}
    -- 选一个地形作为预备入口
    local ruintasks = {
        "MudCave",
        "MudLights",
        "MudPit",
        "BigBatCave",
        "RockyLand",
        "RedForest",
        "GreenForest",
        "BlueForest",
        "SpillagmiteCaverns",
        -- optionaltasks
        "SwampySinkhole",
        "CaveSwamp",
        "UndergroundForest",
        "PleasantSinkhole",
        "FungalNoiseForest",
        "FungalNoiseMeadow",
        "BatCloister",
        "RabbitTown",
        "RabbitCity",
        "SpiderLand",
        "RabbitSpiderWar"
    }
    local function processruinentrancetask(task, lock, given)
        if lock then task.locks = {GLOBAL.LOCKS.CAVE, lock} end
        for i = #task.keys_given, 1, -1 do
            if task.keys_given[i] == GLOBAL.KEYS.ENTRANCE_INNER or task.keys_given[i] == GLOBAL.KEYS.ENTRANCE_OUTER or task.keys_given[i] == GLOBAL.KEYS.TIER2 or
                task.keys_given[i] == GLOBAL.KEYS.TIER3 or task.keys_given[i] == GLOBAL.KEYS.TIER4 then table.remove(task.keys_given, i) end
        end
        if given then table.insert(task.keys_given, given) end
        -- 预备入口和实际入口连接调整
        local ruintotalrooms = 0
        for _, count in pairs(task.room_choices) do ruintotalrooms = ruintotalrooms + 1 end
        if ruintotalrooms <= 2 then return end
        local ruinindexrooms = 0
        for room, _ in pairs(task.room_choices) do
            ruinindexrooms = ruinindexrooms + 1
            local ruinindexroom = ruinindexrooms
            AddRoomPreInit(room, function(room)
                room.random_node_entrance_weight = math.max(ruinindexrooms / ruintotalrooms, 0.1)
                room.random_node_exit_weight = math.max((ruintotalrooms - ruinindexrooms) / ruintotalrooms, 0.1)
            end)
        end
    end
    local ruinpreindex = math.random(#ruintasks)
    local ruinpretask = ruintasks[ruinpreindex]
    AddTaskPreInit(ruinpretask, function(task) processruinentrancetask(task, nil, GLOBAL.KEYS.RUINSSTARTPRE2HM) end)
    -- 再选一个地形作为实际入口
    table.remove(ruintasks, ruinpreindex)
    local ruinstartindex = math.random(#ruintasks)
    local ruinstarttask = ruintasks[ruinstartindex]
    AddTaskPreInit(ruinstarttask, function(task) processruinentrancetask(task, GLOBAL.LOCKS.RUINSSTARTPRE2HM, GLOBAL.KEYS.RUINSSTART2HM) end)
    -- 所选的入口地形从可选变必选
    AddTaskSetPreInit("cave_default", function(tasksetdata)
        if tasksetdata.location ~= "forest" then return end
        if not table.contains(tasksetdata.tasks, ruinpretask) then
            table.insert(tasksetdata.tasks, ruinpretask)
            if table.contains(tasksetdata.optionaltasks, ruinpretask) then
                tasksetdata.numoptionaltasks = math.max(tasksetdata.numoptionaltasks - 1, 0)
                for i = #tasksetdata.optionaltasks, 1, -1 do
                    if tasksetdata.optionaltasks[i] == ruinpretask then
                        table.remove(tasksetdata.optionaltasks, i)
                        break
                    end
                end
            end
        end
        if not table.contains(tasksetdata.tasks, ruinstarttask) then
            table.insert(tasksetdata.tasks, ruinstarttask)
            if table.contains(tasksetdata.optionaltasks, ruinstarttask) then
                tasksetdata.numoptionaltasks = math.max(tasksetdata.numoptionaltasks - 1, 0)
                for i = #tasksetdata.optionaltasks, 1, -1 do
                    if tasksetdata.optionaltasks[i] == ruinstarttask then
                        table.remove(tasksetdata.optionaltasks, i)
                        break
                    end
                end
            end
        end
    end)
    -- 所选的入口地形避免了楼梯生成,但还要安排楼梯到其他地形进行生成
    local caveinnertasks = {"RedForest", "GreenForest", "BlueForest"}
    local caveoutertasks = {"UndergroundForest", "PleasantSinkhole", "FungalNoiseForest", "FungalNoiseMeadow", "RabbitTown", "RabbitCity"}
    local innercaveexittasks = {"CaveExitTask1", "CaveExitTask2", "CaveExitTask3", "CaveExitTask4"}
    local outercaveexittasks = {"CaveExitTask5", "CaveExitTask6", "CaveExitTask7", "CaveExitTask8", "CaveExitTask9", "CaveExitTask10"}
    local function addinnertask(task) table.insert(task.keys_given, GLOBAL.KEYS.ENTRANCE_INNER) end
    local function addounertask(task) table.insert(task.keys_given, GLOBAL.KEYS.ENTRANCE_OUTER) end
    if table.contains(caveinnertasks, ruinpretask) then
        local randomexitindex = math.random(#outercaveexittasks)
        local randomexittask = outercaveexittasks[randomexitindex]
        AddTaskPreInit(randomexittask, addinnertask)
        table.remove(outercaveexittasks, randomexitindex)
    end
    if table.contains(caveinnertasks, ruinstarttask) then
        local randomexitindex = math.random(#outercaveexittasks)
        local randomexittask = outercaveexittasks[randomexitindex]
        AddTaskPreInit(randomexittask, addinnertask)
        -- table.remove(outercaveexittasks, randomexitindex)
    end
    if table.contains(caveoutertasks, ruinpretask) then
        local randomexitindex = math.random(#innercaveexittasks)
        local randomexittask = innercaveexittasks[randomexitindex]
        AddTaskPreInit(randomexittask, addounertask)
        table.remove(innercaveexittasks, randomexitindex)
    end
    if table.contains(caveoutertasks, ruinstarttask) then
        local randomexitindex = math.random(#innercaveexittasks)
        local randomexittask = innercaveexittasks[randomexitindex]
        AddTaskPreInit(randomexittask, addounertask)
        -- table.remove(innercaveexittasks, randomexitindex)
    end
    -- 远古连接实际入口
    AddTaskPreInit("LichenLand", function(task) task.locks = {GLOBAL.LOCKS.RUINSSTART2HM} end)
    -- -- 远古出口地形缩小
    -- local CaveExitTaskstartrooms = {
    --     "RabbitArea",
    --     "RabbitTown",
    --     "RabbitSinkhole",
    --     "SpiderIncursion",
    --     "SinkholeForest",
    --     "SinkholeCopses",
    --     "SinkholeOasis",
    --     "GrasslandSinkhole",
    --     "GreenMushSinkhole",
    --     "GreenMushRabbits"
    -- }
    -- local function processcaveexittask(task)
    --     if task and task.room_choices then
    --         for key, value in pairs(task.room_choices) do
    --             if key and table.contains(CaveExitTaskstartrooms, key) then task.room_choices[key] = nil end
    --         end
    --     end
    -- end
    -- for i = 1, 10 do AddTaskPreInit("CaveExitTask" .. i, processcaveexittask) end
end