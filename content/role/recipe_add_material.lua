-------------------------------------------------------------------------------------
-------------------------[[2025.5.31 melon:材料险境]]---------------------------------
-- 制作栏每个材料都有10%的概率+1
-- 可选:11-20天概率-1,21-30天概率+1,以此递推
-- 根据地图种子+天数计算随机数，因此可保证一个存档某一天的改变是固定的
-------------------------------------------------------------------------------------
local select_recipe = GetModConfigData("recipe_add_material")
select_recipe = select_recipe == true and 1 or select_recipe -- 1总是加材料 2十天减十天加
-----------------------------------------------------------------------------------------
TUNING.cave_shardid2hm = nil -- 地洞ShardId  用作随机数种子  没放下面，别的地方好用?
TUNING.recipe_add2hm = {
    player_msg2hms = {}, -- 记录用于给玩家传输id的变量 服务器使用
    addday = nil, -- 存修改的时间
    recipe_old = nil, -- 存所有旧配方
}
-----------------------------------------------------------------------------------------
local function find_id() -- 返回第一个不是1(主世界)的id
    if ShardList then
        local count = 0
        local id = nil
        for world_id, v in pairs(ShardList) do
            if true or Shard_IsWorldAvailable(world_id) then -- 不考虑是否Available ****
                if tonumber(world_id) ~= 1 and count == 0 then -- 不是1的id
                    id = tonumber(world_id)
                    count = count + 1
                end
            end
        end
        if count == 1 then return id end -- 仅有一个非1的id时(2层世界)时返回id，否则返回nil
    end
    return nil -- 没获取到或者不止2层世界
end
-- 给玩家发送id?
local function send_player_shardid()
    if not TheWorld.ismastersim then return end
    if TUNING.cave_shardid2hm ~= nil and TUNING.recipe_add2hm.player_msg2hms ~= nil and #TUNING.recipe_add2hm.player_msg2hms > 0 then
        for _,v in ipairs(TUNING.recipe_add2hm.player_msg2hms) do
            v.msg2hm:set(tostring(TUNING.cave_shardid2hm))
        end
        -- 发送完删除 注意删除方式 倒着
        TheWorld:DoTaskInTime(2, function() -- 隔段时间再执行?
            for i = #TUNING.recipe_add2hm.player_msg2hms, 1, -1 do
                TUNING.recipe_add2hm.player_msg2hms[i]:Remove()  -- 删除实体
                table.remove(TUNING.recipe_add2hm.player_msg2hms, i)  -- 从表中移除
            end
        end)
    end
end
-- [材料险境]所有制作材料概率+1------------------------------------------------------------
local avoid_prefabs = { -- 避免修改的材料 recipe_add_material
    ["mandrake"]=true, ["shadowheart"]=true, ["walrus_tusk"]=true, -- 曼德拉/黑心/象牙
    ["cane"]=true, ["lightninggoathorn"]=true, ["deerclops_eyeball"]=true, -- 手杖/羊角/眼球
    ["minotaurhorn"]=true, ["malbatross_beak"]=true, ["stash_map"]=true, -- 犀牛角/鸟嘴/海盗地图
    ["dragon_scales"]=true, ["shroom_skin"]=true, ["waxpaper"]=true, -- 龙皮/蟾蜍皮/蜡纸
    ["bearger_fur"]=true, ["beeswax"]=true, ["honeycomb"]=true, -- 熊皮/蜂蜡/蜜脾
}
-- 判断材料是否能修改
local function canchange(prefab)
    if prefab == nil then return false end
    if avoid_prefabs[prefab] then return false end -- 特殊物品
    if string.find(prefab, "gem") then return false end -- 宝石
    -- if string.find(prefab, "staff") then return false end -- 魔杖
    -- if string.find(prefab, "amulet") then return false end -- 护符
    return true
end
-- 加减材料
local function recipe_add2hm_fn()
    -- if not TheWorld.ismastersim then print("#####客户端运行recipe_add2hm_fn函数", TUNING.cave_shardid2hm) end
    -- if TheWorld.ismastersim then print("#####服务器运行recipe_add2hm_fn函数", TUNING.cave_shardid2hm) end
    -- 运行改配方函数时，检查shardid是否为空，若为空重新尝试寻找id，找到后发给客户端，并重新计算材料险境
    if TUNING.cave_shardid2hm == nil then -- 每次"cycleschanged"事件还能再判断一次
        if TheWorld.ismastersim then
            TUNING.cave_shardid2hm = tonumber(find_id()) -- 主世界再次尝试寻找地下id
            if TUNING.cave_shardid2hm ~= nil then send_player_shardid() end -- 找到则向玩家同步
        end
        if TUNING.cave_shardid2hm == nil then return end -- 仍然没找到则返回
    end -- 未获取到地下世界id
    -- -----------------------------------
    local addday = TUNING.recipe_add2hm.addday -- 存修改的时间
    local nowday = TheWorld.state.cycles -- 当前天数  比右上角显示天数少1
    if nowday < 10 then return end -- 前10天不变
    local day_seed = math.floor(nowday / 10) -- 修改种子
    local ifadd = select_recipe == 1 and true or day_seed % 2 == 0 -- 选1时总是加，选2时偶数+1  奇数-1
    if addday and addday == day_seed * 10 then return end -- 当前改变正确
    -- 没存时存一下该存的
    TUNING.recipe_add2hm.addday = day_seed * 10
    if TUNING.recipe_add2hm.recipe_old == nil then
        TUNING.recipe_add2hm.recipe_old = deepcopy(GLOBAL.AllRecipes)
    end
    local recipe_old = TUNING.recipe_add2hm.recipe_old
    -- 开加 -------------------------------------------------
    -- 根据地下世界cave_shardid2hm  + 天数/10 设置随机数 3001为了加大变化
    math.randomseed(tonumber(TUNING.cave_shardid2hm) + day_seed * 3001)
    math.random() -- 第一个不用
    local recipes = GLOBAL.AllRecipes
    for name, recipe in pairs(recipes) do
        -- print("#####cailiao name", name)
        if recipe.ingredients and recipe_old[name] and recipe_old[name].ingredients then
            for i, ingredient in ipairs(recipe.ingredients) do
                local ingredients_old = recipe_old[name].ingredients[i]
                if ingredients_old and ingredients_old.amount then -- 合法
                    if math.random() < 0.1 and canchange(ingredient.type) then -- 10%概率增减
                        if ifadd then
                            ingredient.amount = ingredients_old.amount + 1
                        elseif ingredients_old.amount > 1 then
                            ingredient.amount = ingredients_old.amount - 1
                        else
                            ingredient.amount = ingredients_old.amount -- 变回原来的数量
                        end
                    else
                        ingredient.amount = ingredients_old.amount -- 变回原来的数量
                    end
                end
            end
        end
    end
    math.randomseed(os.time()) -- 重置随机数
end
-----------------------------------------------------------------------------------------
-- 找另一个世界的id  改自containersort.lua的
local function findanotherworldid()
    if ShardList then
        for world_id, v in pairs(ShardList) do
            if TheShard and world_id ~= TheShard:GetShardId() and Shard_IsWorldAvailable(world_id) then
                return world_id
            end
        end
    end
end
local function select_id(sendid, findid) -- 地下发过来的shardid，地上自己找到的findid
    if findid == nil then return sendid end
    if sendid == nil then return findid end
    return findid <= sendid and sendid or findid -- 自己找的可能不对? 如果2个值不一样，选个更大的
end
-- 地上接收到地下发的世界id   TheShard:GetShardId()
AddShardModRPCHandler("MOD_HARDMODE", "send_cave_shardid2hm", function(shard_id, world_id, shardid)
    if TheShard and tostring(TheShard:GetShardId()) == tostring(world_id) then -- 地上收到shardid
        -- 决定该用哪个id
        TUNING.cave_shardid2hm = select_id(tonumber(shardid), tonumber(find_id()))
        send_player_shardid() -- 给用户发送
        -- 自己运行材料险境
        if TheWorld.ismastersim then TheWorld.recipe_add2hm_recipe_add2hm_fn() end
    end
end)
-- 地下给地上发送地下TheShard:GetShardId()
local function send_master_id()
    if not TheWorld.ismastersim then return end
    if TheShard then
        local world_id = findanotherworldid() -- 找另一个世界的id
        SendModRPCToShard(GetShardModRPC("MOD_HARDMODE", "send_cave_shardid2hm"), nil, world_id, TheShard:GetShardId()) -- 发送
    end
end
-----------------------------------------------------------------------------------------
local function on_msg2hm_dirty(inst) -- 客户端收到同步信息msg
    if TheWorld.ismastersim then return end
    local isnil = TUNING.cave_shardid2hm == nil
    TUNING.cave_shardid2hm = inst.msg2hm:value()
    -- 将地图种子存到客户端TUNING中
    if isnil and inst.msg2hm:value() ~= nil then -- 避免重复执行 nil变非nil才执行
        TheWorld.recipe_add2hm_recipe_add2hm_fn() -- 计算材料险境
    end
end
AddPrefabPostInit("blank2hm", function(inst)
    inst.msg2hm = net_string(inst.GUID, "blank2hm.msg2hm", "on_msg2hm_dirty") -- 用于传输信息(msg)的变量
    if not inst.ismastersim then
        inst:ListenForEvent("on_msg2hm_dirty", on_msg2hm_dirty) -- 监听set
        return
    end
end)
-- TheWorld ---------------------------------------------------------------------------
-- 玩家进入世界时，创建给玩家传输信息的变量并保存。若已经有地下id，发送给玩家。
local function playerjoined_fn(src, player)
    local blank2hm = SpawnPrefab("blank2hm")
    if TUNING.cave_shardid2hm ~= nil then -- 获取到shardid时
        blank2hm.msg2hm:set(tostring(TUNING.cave_shardid2hm)) -- 获取到shardid直接传给客户端
    else
        table.insert(TUNING.recipe_add2hm.player_msg2hms, blank2hm) -- 当前没id才记录
    end
end
-- TheWorld创建时，地上寻找地下id，地下给地上发id
local function sendandfind_fn()
    if not TheWorld.ismastersim then return end
    -- 地洞启动时向地上传输ShardId
    for i=1,5 do -- 发送5次
        TheWorld:DoTaskInTime(i*2, function() -- 2秒地上收不到，5秒能   也多发几次吧
            if TheWorld:HasTag("cave") then
                TUNING.cave_shardid2hm = TheShard and TheShard:GetShardId() -- 地洞直接使用自己的id即可
                send_master_id() -- 告诉地上启动了
                -- 自己运行
                if TUNING.cave_shardid2hm ~= nil and TheWorld.recipe_add2hm_recipe_add2hm_fn ~= nil then
                    TheWorld.recipe_add2hm_recipe_add2hm_fn()
                end
            end
        end)
    end
    -- 地上启动时，分别在0.3秒和2秒寻找地下的ShardId
    for i=1,5 do -- 获取5次
        TheWorld:DoTaskInTime(i*0.3, function() -- 不断执行直到执行成功? 用是否能获得地下世界id来判断
            if not TheWorld:HasTag("cave") then -- 非地洞
                TUNING.cave_shardid2hm = find_id() -- 找到的第一个不是1的世界id (1是主世界)
                send_player_shardid() -- 给玩家发送id
                -- 自己运行
                if TUNING.cave_shardid2hm ~= nil and TheWorld.recipe_add2hm_recipe_add2hm_fn ~= nil then
                    TheWorld.recipe_add2hm_recipe_add2hm_fn()
                end
            end
        end)
    end
end
AddPrefabPostInit("world", function(inst)
    inst.recipe_add2hm_recipe_add2hm_fn = recipe_add2hm_fn -- 存到world合适吗  存这里方便别人修改
    inst:ListenForEvent("cycleschanged", inst.recipe_add2hm_recipe_add2hm_fn) -- 地上、地下、客户端都监听此事件

    if not inst.ismastersim then return end

    -- 玩家进入世界时，创建给玩家传输信息的变量并保存。若已经有地下id，发送给玩家。
    inst.recipe_add2hm_playerjoined_fn = playerjoined_fn
    inst:ListenForEvent("ms_playerjoined", inst.recipe_add2hm_playerjoined_fn)

    -- TheWorld创建时，地上寻找地下id，地下给地上发id
    inst.recipe_add2hm_sendandfind_fn = sendandfind_fn
    inst.recipe_add2hm_sendandfind_fn() -- TheWorld创建时，地上寻找地下id，地下给地上发id
end)
