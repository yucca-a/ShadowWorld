--------------------------------------
---生物大灭绝代码-----
----原理：生物每次被击杀，则值+1，如果值超过100则删除该生物，每天值回退5，如果超过100不回退生物灭绝.

local miejveshuliang = 100 ---要杀死多少生物，该生命才会灭绝。
local hanheshengwu = 5  ----每天缓和多少生物防止灭绝。
local shayimiejve = 1  ----杀死生物增加多少进度。
-----

AddPrefabPostInitAny(function(inst) -- 全世界生效

				
	if not TheWorld.ismastersim then   ----服务器
		return inst
	end
	-- if TheWorld and TheWorld.ray_qvanshijieyuzhiwu and not inst:HasTag("fx") then
		-- table.insert(TheWorld.ray_qvanshijieyuzhiwu, inst)  -- 添加新的数据组
	-- end
			local jiubaocun = inst.OnSave
			inst.OnSave = function(inst, data,...)  ----修改保存
				local refs
				if jiubaocun then
					local ok, result = pcall(jiubaocun,inst, data,...)
					if ok then refs = result end
				end
				if data and inst.ray_shengwudamiejve_jianceguo then
					data.ray_shengwudamiejve_jianceguo = inst.ray_shengwudamiejve_jianceguo
				end
				return refs
			end
			
			
			local jizairu = inst.OnLoad
			inst.OnLoad = function(inst, data,...)
				if jizairu then
					pcall(jizairu,inst, data,...)
				end
				if data and data.ray_shengwudamiejve_jianceguo then
					inst.ray_shengwudamiejve_jianceguo = data.ray_shengwudamiejve_jianceguo
				end
			end

			
		inst:DoTaskInTime(0, function()
				if inst.ray_shengwudamiejve_jianceguo == nil then
					inst.ray_shengwudamiejve_jianceguo = true
					local targetName = inst.prefab
					if TheWorld and TheWorld.ray_shengwudamiejvemingdan then
						for i, data in ipairs(TheWorld.ray_shengwudamiejvemingdan) do
							if data[1] == targetName then
								if data[2] >= miejveshuliang then
										if inst and inst ~= nil and inst:IsValid() and inst.Transform then
											if not inst:HasTag("ray_yimiejve") then inst:AddTag("ray_yimiejve")end
											local x, s, c = inst.Transform:GetWorldPosition()
											local boss = TheSim:FindEntities(x, s, c, 3,{"_health"},{ "wall","FX","player","ray_yimiejve","companion"},{"epic","hive","structure"})
											if #boss < 1 then
												if inst ~= nil and inst:IsValid() then
													inst:Remove() 
												end
											end
										end
								end
								break
							end
						end
					end
				end
		end)	
end)
local function shengwumiejveguize(inst) ---恢复世界还未被灭绝的生物
	if inst and inst.ray_shengwudamiejvemingdan then
		for i, data in ipairs(inst.ray_shengwudamiejvemingdan) do
			if data[2] < miejveshuliang and data[2] > 0 then
				data[2] = data[2] - hanheshengwu
				if data[2] < 0 then data[2] = 0 end
			end
		end
	end
end
local function shijiemiejveshengwtongbudiaoyongchanshu(shengwuming,shuliang) ---恢复世界还未被灭绝的生物
	if shengwuming and shuliang and TheWorld and TheWorld.ray_shengwudamiejvemingdan then
		local targetExists = false
		for i, data in ipairs(TheWorld.ray_shengwudamiejvemingdan) do
			if data[1] == shengwuming then
				data[2] = shuliang
				targetExists = true
				break
			end
		end
		if not targetExists then
			table.insert(TheWorld.ray_shengwudamiejvemingdan, {shengwuming, shuliang})  -- 添加新的数据组
		end
	end
end


AddShardModRPCHandler( "ray", "ray_shijiewupinmiejve", function(moshi,shengwuming,shuliang) ---同步整个服务器，地上灭绝地下也见不到它。
	shijiemiejveshengwtongbudiaoyongchanshu(shengwuming,shuliang)
end)


local function shijiemiejveshengwtongbuqiyong(shengwuming,shuliang) ---同步整个服务器，地上灭绝地下也见不到它。
	if shengwuming and shuliang and TheWorld and TheWorld.ray_shengwudamiejvemingdan then
		SendModRPCToShard(SHARD_MOD_RPC["ray"]["ray_shijiewupinmiejve"],nil,shengwuming,shuliang)
	end
end


local function shanchuqvanshijiewupin(shengwuming) ---删除全世界，包含洞穴，地上的所有物品调用。

				for i, data in pairs(Ents) do
					if data and data:IsValid() and data.prefab == shengwuming then
								if data and data.components and data.components.health then
									if data.components.health then data.components.health:SetVal(0, "SHENPAN") end
								else
									data:Remove()
								end
					end
				end

end

AddShardModRPCHandler( "ray", "ray_shanchuzhenggeshijiewupun", function(moshi,shengwuming) ---同步整个服务器，地上灭绝地下也见不到它。
	shanchuqvanshijiewupin(shengwuming)
end)

function ray_qiangzhimiejve(shengwu,moshi) ---强制灭绝函数调用此函数来不通过判定的灭绝生物。
	if shengwu and shengwu:IsValid() and TheWorld and TheWorld.ray_shengwudamiejvemingdan then

		shijiemiejveshengwtongbudiaoyongchanshu(shengwu.prefab,100)
		SendModRPCToShard(SHARD_MOD_RPC["ray"]["ray_shijiewupinmiejve"],nil,shengwu.prefab,100)
		if moshi then
				shanchuqvanshijiewupin(shengwu.prefab)
				SendModRPCToShard(SHARD_MOD_RPC["ray"]["ray_shanchuzhenggeshijiewupun"],nil,shengwu.prefab)
		else
			
									if TheNet  and shengwu and shengwu:GetBasicDisplayName() then
										TheNet:Announce(" 生物： " ..
											shengwu:GetBasicDisplayName() .. " 已被强制灭绝。 ")
									end	
		end
	end
end
GLOBAL.ray_qiangzhimiejve = ray_qiangzhimiejve

local function miejvemingdanjia(world, data)    ----------主死亡函数
if data and data.inst and TheWorld and TheWorld.ray_shengwudamiejvemingdan and (not TheWorld.state or not TheWorld.state.israining) then
            local mubiao = data.inst
			if mubiao and mubiao:IsValid() and mubiao.yisiwangyici == nil and mubiao.persists and mubiao.sg 
			and not mubiao:HasTag("player") and ---非玩家
			not mubiao:HasTag("structure") and ---非建筑
			not mubiao:HasTag("wall") and ---非墙
			not mubiao:HasTag("shadow") and ---非暗影
			not mubiao:HasTag("groundtile") and ---非地砖
			not mubiao:HasTag("molebait") and ---非分子
			not mubiao:HasTag("FX") and ---非特效
			not mubiao:HasTag("notarget") and ---非特效
			not mubiao:HasTag("NOCLICK") and ---非特效
			not mubiao:HasTag("shadowminion") and ---非暗影生物
			not mubiao:HasTag("shadowcreature") and ---非暗影生物
			not mubiao:HasTag("companion") and ----非同伴。
			not mubiao:HasTag("boat") and ---非船
			not mubiao:HasTag("ghost") and ----非幽灵。
			not mubiao:HasTag("abigail") then  ----不能多次同目标多次执行,不能是玩家
				mubiao.yisiwangyici = true
				if  data.afflicter ~= nil and data.afflicter ~= mubiao then
						local targetName = mubiao.prefab
						local targetExists = false
						for i, data in ipairs(TheWorld.ray_shengwudamiejvemingdan) do
							if data[1] == targetName then
								if data[2] <= 100 then
									data[2] = data[2] + shayimiejve
									if data[2] == 100 then
										if TheNet  and mubiao and mubiao:GetBasicDisplayName() then
											TheNet:Announce(" 生物： " ..
												mubiao:GetBasicDisplayName() .. "  已被灭绝，剩余现已存活生物成唯一生物。 ")
										end
									elseif data[2] == 80 then
										if TheNet  and mubiao and mubiao:GetBasicDisplayName() then
											TheNet:Announce(" 生物： " ..
												mubiao:GetBasicDisplayName() .. "  以列入高度濒危物种，请保护剩余生物，不要过度捕杀。 ")
										end
									elseif data[2] == 50 then
										if TheNet  and mubiao and mubiao:GetBasicDisplayName() then
											TheNet:Announce(" 生物： " ..
												mubiao:GetBasicDisplayName() .. "  以列入濒危物种，在短时间内请不要过度杀戮。 ")
										end
									end
									shijiemiejveshengwtongbuqiyong(data[1],data[2])
								end
								targetExists = true
								break
							end
						end

					if not targetExists then
						table.insert(TheWorld.ray_shengwudamiejvemingdan, {targetName, 1})  -- 添加新的数据组
					end
				end
			
			end
end
end



AddPrefabPostInit("world", function(inst)-----单独修改世界

	if TheWorld.ismastersim then

		inst.ray_shengwudamiejvemingdan = {{"灭绝名单", 1}}       ----灭绝名单
		-- inst.ray_qvanshijieyuzhiwu = {}       ----全世界预制物！不保存。
			if GetModConfigData("World ecosystem")  then
				inst:WatchWorldState("cycles", shengwumiejveguize)
				inst:ListenForEvent("entity_death", miejvemingdanjia, TheWorld)
			end
		
			local jiubaocun = inst.OnSave
			inst.OnSave = function(inst, data,...)  ----修改保存
				local refs
				if jiubaocun then
					local ok, result = pcall(jiubaocun,inst, data,...)
					if ok then refs = result end
				end
				if data and inst.ray_shengwudamiejvemingdan then
					data.ray_shengwudamiejvemingdan = inst.ray_shengwudamiejvemingdan
				end
				return refs
			end
			
			
			local jizairu = inst.OnLoad
			inst.OnLoad = function(inst, data,...)
				if jizairu then
					pcall(jizairu,inst, data,...)
				end
				if data and data.ray_shengwudamiejvemingdan then
					inst.ray_shengwudamiejvemingdan = data.ray_shengwudamiejvemingdan
				end
			end
			
	end	

end)

-------------全部能力end