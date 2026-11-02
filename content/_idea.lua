--------------------------------------------------------------------------------
---------------------[[2025.8.2 melon:灵感/bug]]--------------------------------
-- 有什么想法还没实现的写这里
-- 希望以后的作者有机会实现这些想法
--------------------------------------------------------------------------------
-- [留言]
-- melon:部分内容不知道放哪里先放lunar_shadow_items.lua里了(陷阱加强，加电僵直cd等)
--------------------------------------------------------------------------------
--[[
[想法]
haitang:
新三王的本体也会暗影化，同理，影分身会伪装地实体化，，，然后玩家很难区别开来...
瓜皮头放种子种地的生效范围缩小到0.5，因此只会种到脚下的刨坑
彩虹精英怪隐身后会立即变化位置，出现到此时位置朝向主角位置方向的主角位置之后

melon:
-- 吃西瓜(melon)留言: 我在我修改了的位置都加了melon字样及时间，我的代码水平不高，如果觉得我写的有错误的或者不好的都可以修改，或者联系我讨论。希望为爽越来越有趣！
    [写给新人moder:
    游戏内输出print2hm("dt", dt, "insulation", insulation)
    
    代码尽量用hook方式(参考easy_other/lunar_shadow_items.lua 73-77行写法)，即更兼容的写法
    ListenForEvent事件、Task尽量存一下函数，方便后续取消(参考easy_other/lunar_shadow_items.lua 1304-1305行写法)

    如果没存的ListenForEvent事件、Task，取消的方法:
    ListenForEvent事件:见easy_other/easy_structures.lua
            AddPrefabPostInit("mushroom_light", function(inst)
            if not TheWorld.ismastersim then return end
            if inst.components.burnable then inst:RemoveComponent("burnable") end -- 不可燃
            -- inst.OnLoad = function() end
            if inst.Physics then inst.Physics:SetCollides(false) end -- 碰撞?
            -- 修改含范围的参数
            for i, func in ipairs(inst.event_listeners["itemget"][inst]) do -- 找light的函数
                if UpvalueHacker.GetUpvalue(func, "fulllight_light_str") then
                    -- local fn, i, prv = UpvalueHacker.GetUpvalue(func, "fulllight_light_str")
                    UpvalueHacker.SetUpvalue(func, fulllight_light_str, "fulllight_light_str")
                end
                if UpvalueHacker.GetUpvalue(func, "light_str") then
                    -- local fn, i, prv = UpvalueHacker.GetUpvalue(func, "light_str")
                    UpvalueHacker.SetUpvalue(func, light_str, "light_str")
                    break -- 改一次就行了
                end
                --[ 示例:查看所有func用到的变量、函数
                local k = 1
                while true do
                    local name, value = debug.getupvalue(func, k)
                    if not name then break end
                    print("#####", k, name, value)
                    k = k + 1
                end
                --] ]
            end
        end)
    Task:见epic/klaus.lua 929~942 以及 968~970 行的写法

    另外，一些情况下不开地洞和开地洞测试结果不同，尽量最后测一遍开地洞的情况
    ]
15.月后生物险境。月后影子变白色?或者生物死亡掉一个无影子、白色、实体抵抗的生物。体型更小，影怪也会变。
地上被虚影寄生，地下被面具寄生。影子变远程。
8.调小科技声音?0.6
11.大鹅影子改远程
20.非秋季档案馆插3彩虹关闭月亮蘑菇林的影怪

11.削石虾?
13.boss冰冻无伤。巨兽标签互相攻击会传送至远处。
12.不能把喂鸟扣血，和打鸟扣血上限  分开很麻烦
6.可装备物品掉虚空传回
7.为爽bossrush(类似熔炉?)。一片铺满卵石路的陆地。按顺序出boss。所有装备无耐久。开局每个角色带初始装备。
    每打死一个boss掉落一些装备。有能无限复活的手段。用无耐久铥棒，不消耗弹药的狗牙吹箭等打。
8.多人一起睡帐篷。
9.老麦影人优化不主动打影怪。
10.火女影火优先打boss、优先打本体
15.火女用技能ui时不关闭熊罐
10.奔雷矛冲刺不打有鞍的牛及其影子。
8.电栅栏加僵直cd  (太复杂了
9.后裔带影子，铺地板改成只铺几格，并生成一些麻刺节点的电线控制
10.限制妥协浓烟生成数量。
1.雪球砸到火堆仅扣除一部分燃料而不是全部熄灭。砸到人根据人的保暖扣除温度，不再能砸到帐篷中的人。
1.新船，划一下快速动一下，然后快速停下来。帆等无效。
1.猪boss固定1500血。每攻击2次做一次发怒动作。
1.只提示一次更新失效。
3.旺达开延迟补偿倒走有时不起效问题。
5.boss影子被打死后存档，再回档不再出影子。
妥协机器人撞梦魇疯猪出影子的问题。
撞岩石蜘蛛巢崩的问题。
10.灵魂状态改为无伤。
2.阿比盖尔不主动打怪物角色。
7.胖对玩家有仇恨时才能给玩家装备的绝望甲回耐久。
9.开启喝水mod时，睡帐篷时回满状态后也不再多扣口渴值。
16.鱼人不能带下洞。变异鱼人不能存给假人。
3.刮皮头不砍勋章的本源树。
4.生物吃火腿只吃一口。
---------------------------------------
[bug]
1.季节boss反复刷。
1.穿越的暂停只能管理员用。
19.结晶器不恒温 不知道什么问题
22.骑牛，眼球伞，偶尔过热
2.植物人反伤到跳劈，跳劈动不了了。(可能修好了)
14.永冬不刷克劳斯bug
5.无可阻挡导致的，小穹萤火乱跑。
8.座狼攻击猎犬丘的崩溃。(需要开启工坊留言里的mod，妥爽不触发)
--]]


---------------------------------------------------------------------------
-- old_code
--[[
-- 2025.10.13妥协已收编部分-------------------------
-- gulumi:妥协海泥战利品重复喷发bug修复
if TUNING.DSTU then AddPrefabPostInit("sludgestack",function(inst)
	if not TheWorld.ismastersim then return end
	local oldOnEntityWake = inst.OnEntityWake
		inst.OnEntityWake = function(inst)
			oldOnEntityWake(inst)
			inst.explode_when_loaded = false
		end
	end)
end
-- gulumi:妥协懒人护符禁止采集蜘蛛随从且可采摘各种蘑菇了 
-- if TUNING.DSTU then
-- 	local ORANGE_PICKUP_MUST_TAGS = {
--         "_inventoryitem",
--         "plant",
--         "witherable",
--         "kelp",
--         "lureplant",
--         "waterplant",
--         "oceanvine",
--         "lichen",
--         "orangeamuletcanpick2hm"
--     }
--     local ORANGE_PICKUP_CANT_TAGS = {
--         "INLIMBO",
--         "NOCLICK",
--         "knockbackdelayinteraction",
--         "catchable",
--         "fire",
--         "minesprung",
--         "mineactive",
--         "irreplaceable",
--         "moonglass_geode",
--     }
--     local function change_UM_orangeamulet(inst)
--         if inst.components.equippable ~= nil then
-- 			local oldonequipfn = inst.components.equippable.onequipfn
--             inst.components.equippable.onequipfn = function(inst, owner, ...)
--                 oldonequipfn(inst, owner, ...)
--                 if inst.task then
--                     local oldtaskfn = inst.task.fn
--                     inst.task.fn = function(inst, owner)
--                         if owner == nil or owner.components.inventory == nil then
--                             return
--                         end
--                         local spider = FindEntity(inst, 1.2 * TUNING.ORANGEAMULET_RANGE, function(guy) return guy:HasTag("spider") end)
--                         if spider then return end
--                         local x, y, z = inst.Transform:GetWorldPosition()
--                         local ents = TheSim:FindEntities(x, y, z, 1.2 * TUNING.ORANGEAMULET_RANGE, nil, ORANGE_PICKUP_CANT_TAGS, ORANGE_PICKUP_MUST_TAGS)
--                         for i, v in ipairs(ents) do
--                             if v:HasTag("orangeamuletcanpick2hm") then
--                                 if v.components.inventoryitem ~= nil and --Inventory stuff
--                                     v.components.inventoryitem.canbepickedup and
--                                     v.components.inventoryitem.cangoincontainer and
--                                     not v.components.inventoryitem:IsHeld() and
--                                     owner.components.inventory:CanAcceptCount(v, 1) > 0 then
--                                     if owner.components.minigame_participator ~= nil then
--                                         local minigame = owner.components.minigame_participator:GetMinigame()
--                                         if minigame ~= nil then
--                                             minigame:PushEvent("pickupcheat", {cheater = owner, item = v})
--                                             inst.components.fueled:DoDelta(-2)
--                                         end
--                                     end

--                                     --Amulet will only ever pick up items one at a time. Even from stacks.
--                                     SpawnPrefab("sand_puff").Transform:SetPosition(v.Transform:GetWorldPosition())

--                                     local v_pos = v:GetPosition()
--                                     if v.components.stackable ~= nil then
--                                         v = v.components.stackable:Get()
--                                     end
--                                     inst.components.fueled:DoDelta(-2)
--                                     if v.components.trap ~= nil and v.components.trap:IsSprung() then
--                                         v.components.trap:Harvest(owner)
--                                     else
--                                         owner.components.inventory:GiveItem(v, nil, v_pos)
--                                     end
--                                     return
--                                 end
--                                 if v.components.pickable ~= nil and v.components.pickable.caninteractwith == true and v.components.pickable:CanBePicked() then --Pickable stuff
--                                     v.components.pickable:Pick(owner)
--                                     inst.components.fueled:DoDelta(-2)
--                                     SpawnPrefab("sand_puff").Transform:SetPosition(v.Transform:GetWorldPosition())
--                                     owner.components.sanity:DoDelta(-0.25) --Can't take too much sanity if the purpose is to use in large farms
--                                     return
--                                 end
--                             else
--                                 oldtaskfn(inst, owner)
--                                 return
--                             end
--                         end
--                     end
--                 end
--             end
-- 		end
--     end
-- 	AddPrefabPostInit("orangeamulet", function(inst)
-- 		if not TheWorld.ismastersim then return end
--         change_UM_orangeamulet(inst)
-- 	end)
-- 	AddPrefabPostInit("green_mushroom", function(inst)
-- 		inst:AddTag("orangeamuletcanpick2hm")
-- 	end)
-- 	AddPrefabPostInit("red_mushroom", function(inst)
-- 		inst:AddTag("orangeamuletcanpick2hm")
-- 	end)
-- 	AddPrefabPostInit("blue_mushroom", function(inst)
-- 		inst:AddTag("orangeamuletcanpick2hm")
-- 	end)
-- 	AddPrefabPostInit("twiggytree", function(inst)
-- 		inst:AddTag("orangeamuletcanpick2hm")
-- 	end)
-- 	AddPrefabPostInit("sludgestack", function(inst)
-- 		inst:AddTag("orangeamuletcanpick2hm")
-- 	end)
-- end

-- gulumi:妥协荨麻甲修复bug及削弱
if TUNING.DSTU then
	local DebuffDuration = 6
	local task

	local function OnAttackOther(owner, data, inst) -- 修复植物人荨麻甲叠加计算buff伤害bug
		if checknumber(inst._hitcount) then
			inst._hitcount = inst._hitcount + 1

			if inst._hitcount >= TUNING.WORMWOOD_ARMOR_BRAMBLE_RELEASE_SPIKES_HITCOUNT then
				inst._hitcount = 0
				if data ~= nil and data.target ~= nil
					and data.target:IsValid()
					and not data.target:HasTag("INLIMBO")
					and not data.target:HasTag("noattack")
				then
					data.target:AddDebuff("umdebuff_pyre_toxin_armor_bonus_" .. math.random(100), "umdebuff_pyre_toxin", DebuffDuration)
				end
			end
		end
	end 
	AddPrefabPostInit("um_armor_pyre_nettles", function(inst)
		if not TheWorld.ismastersim then return end
		local _OnEquip = inst.components.equippable.onequipfn
		local _OnUnequip = inst.components.equippable.onunequipfn
		inst.OnEquip = function(inst, owner) -- 削弱荨麻甲 现在穿荨麻甲会持续保持火荨麻debuff状态
			_OnEquip(inst, owner)
			if not TheWorld.state.iswinter then
				if owner:IsValid()
					and not owner:HasTag("INLIMBO")
					and not owner:HasTag("noattack")
				then
					task = owner:DoPeriodicTask(3, function()
						owner:AddDebuff("umdebuff_pyre_toxin_armor_wearer", "umdebuff_pyre_toxin", 3)
					end, 3)
				end
			end
		end
		
		inst.OnUnequip = function(inst, owner)
			_OnUnequip(inst, owner)
			if task then
				task:Cancel()
			else
				return
			end
		end
		inst.components.equippable:SetOnEquip(inst.OnEquip)
		inst.components.equippable:SetOnUnequip(inst.OnUnequip)
		inst._onattackother = function(owner, data) OnAttackOther(owner, data, inst) end
	end)
end
--]]





--------------------------------------------------------------------------------
---------------------[[2026.3.8 YeFeng:灵感/bug]]--------------------------------
-- 有什么想法还没实现的写这里
-- 希望以后的作者有机会实现这些想法
--------------------------------------------------------------------------------
-- [留言]
-- YeFeng:
--------------------------------------------------------------------------------
--[[
[想法]
haitang:



YeFeng:
1.











---------------------------------------
穿越机制重构思路：
无法穿越是服务器通信延迟高放止玩家有时间操作容器内容物设置的限制；
穿越复制bug则是穿越机制在中途没有存储数据进行回退操作导致的
发送方发送的信号接收方收到了此时接收方更新了容器的数据并且发送给发送方自己的容器数据，如果这时延迟高则发送方收不到数据，此时两边的数据是一样的，接收方的容器数据就丢掉了....

重构代码
末影箱穿越使用共用数据表：创建模组本地数据表专门用于存储末影箱相关数据，每个世界生成时写入自己的id，
id表内则写入容器物品数据、容器当前所在数据、产看容器的玩家数。

制作一个ui，ui的数据使用公共表的数据，id，是否被别的世界调用，正在操作的玩家人数，附加颜色提示，
绿色为无玩家操作、无世界调用；黄色为有世界调用但无玩家操作；红色为有世界调用、有玩家操作。

容器则添加一个“是否有对应世界容器”的值，使用布尔值；将打开、关闭容器逻辑修改，根据是否有对应世界容器执行，
无则打开ui，供玩家选择穿越世界；有则直接打开该容器

穿越流程：通过ui内按钮点击穿越对应世界，穿越前再次检测公共表的操作人数和是否有世界占用，有则立刻返回提示穿越失效，
ui绿色则直接执行，提前导入自己世界ID到表中的容器所在世界中上锁，
延迟后再次检测id条件，是自己的则可通过条件，正常调用容器数据并修改共用表中相关数据上锁(延迟目的防止其它世界在同一时间调用，根据上锁世界id保证唯一性)；
黄色则通过世界通信器穿越，穿越世界发送通信给占用容器的世界，发送穿越请求，如果通信超过3秒中止操作，
未超过且接受方接受到了通信则关闭容器(将所有操作容器的玩家关闭容器ui)，延迟0.5秒后执行保存容器数据操作，清除物品数据，
清除容器的对应世界容器数据并更新公共表锁以及人数数据，最后发送通知给发送方，此通知超时也中止操作，如果发送方接收到了接受方的通信则穿越成功，
发送方更新自己的容器内容玩家提示成功穿越，就算没接收到此时对应世界通道也为绿色，仅需再次直接调用也可应用容器；红色则说明没通知到对方不可进行穿越操作。

灵感：四色蘑菇食用后会积累毒素，毒素过高会被施加对应debuff，蓝蘑菇毒素积累后移速降低走路跌跌撞撞；熟绿蘑菇毒素积累会虚弱，目标伤害倍率减半；
月亮蘑菇毒素积累会腹泻，间隔一段时间扣除饥饿值并强制进入硬值动画；熟红蘑菇毒素积累会头昏脑胀，间隔时间扣除san值并强制进入硬值动画。玩家可以制作解毒剂服用消除部分毒素值











--]]

