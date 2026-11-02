----------此文档改动地图，以及玩家地图，调用官方数据来达到目的。
local ditujiesuomoshi = GetModConfigData("World Unlock")
AddClientModRPCHandler("ray", "yiwangdituya", function() ---客户端通知
	if ThePlayer and TheWorld and TheWorld.minimap and TheWorld.minimap.MiniMap then
		if ditujiesuomoshi then
			
		else
			TheWorld.minimap.MiniMap:ContinuouslyClearRevealedAreas(true)
		end
	end
end)

AddClientModRPCHandler("ray", "yiwangdituya2", function() ---客户端通知
	if ThePlayer then
		if ThePlayer.ray_yishiditudongtai ~= nil then
			ThePlayer.ray_yishiditudongtai:Cancel()
			ThePlayer.ray_yishiditudongtai = nil
		end
		if ThePlayer and TheWorld and TheWorld.minimap and TheWorld.minimap.MiniMap then
			if ditujiesuomoshi then
			else
				TheWorld.minimap.MiniMap:ContinuouslyClearRevealedAreas(false)
			end
		end
		ThePlayer.ray_yishiditudongtai = ThePlayer:DoPeriodicTask(120, function()
			if ThePlayer and TheWorld and TheWorld.minimap and TheWorld.minimap.MiniMap then
						if ditujiesuomoshi then
						else
							TheWorld.minimap.MiniMap:ContinuouslyClearRevealedAreas(true)
						end
			end
			if ThePlayer.ray_yishiditudongtai ~= nil then
				ThePlayer.ray_yishiditudongtai:Cancel()
				ThePlayer.ray_yishiditudongtai = nil
			end
		end)
	end
end)

local function init(inst) ---添加地图周围的光
	if inst.icon == nil and not inst:HasTag("burnt") then
		inst.icon = SpawnPrefab("globalmapicon")
		inst.icon.MiniMapEntity:SetIsFogRevealer(true)
		inst.icon:AddTag("fogrevealer")
		inst.icon:TrackEntity(inst)
	end
end

local function onburnt(inst) ---移除地图光，并停止揭示地图
	if inst.components.maprevealer then
		inst.components.maprevealer:Stop()
	end
	if inst.icon ~= nil then
		inst.icon:Remove()
		inst.icon = nil
	end
end

local function topocket(inst)
    if inst.icon2 ~= nil then
        inst.icon2:Remove()
        inst.icon2 = nil
    end
end

local function toground(inst)
    if inst.icon2 == nil then
        inst.icon2 = SpawnPrefab("globalmapicon")
        inst.icon2:TrackEntity(inst)
    end
end


AddMinimapAtlas(GetInventoryItemAtlas("campfire.tex"))
AddPrefabPostInit("campfire", function(inst) ---对于篝火的修改
	inst.entity:AddMiniMapEntity()

	inst.MiniMapEntity:SetIcon("campfire.tex")
	inst.MiniMapEntity:SetCanUseCache(false)
	inst.MiniMapEntity:SetDrawOverFogOfWar(true)

	if not TheWorld.ismastersim then
		return inst
	end
	toground(inst)

	-- inst:DoTaskInTime(0, init)

	-- 设置燃料,来应对，如果其他mod改动了 营火 熄灭不消失，那么这个设置会起作用。
	if ditujiesuomoshi then

	else
		inst:AddComponent("maprevealer")
		if inst.components.fueled then
			local jiuderanliao, jiudeximieranshao
			if inst.components.fueled.sectionfn ~= nil then
				jiuderanliao = inst.components.fueled.sectionfn
			end
			if inst.components.fueled.depleted ~= nil then
				jiudeximieranshao = inst.components.fueled.depleted
			end

			inst.components.fueled.sectionfn = function(...)
				if jiuderanliao ~= nil then
					pcall(jiuderanliao, ...)
				end

				if
					inst.components.fueled
					and inst.components.fueled.currentfuel
					and inst.components.fueled.currentfuel <= 0
				then
					onburnt(inst)
				else
					init(inst)
				end
			end
			inst.components.fueled.depleted = function(...)
				if jiudeximieranshao ~= nil then
					pcall(jiudeximieranshao, ...)
				end
				onburnt(inst)
			end
		end
	end
end)

AddPrefabPostInit("mapscroll", function(inst)
	if not TheWorld.ismastersim then
		return inst
	end

	local jiuditu

	if inst.components.maprecorder.onteachfn ~= nil then
		jiuditu = inst.components.maprecorder.onteachfn
	end

	inst.components.maprecorder.onteachfn = function(inst, target, ...)
		SendModRPCToClient(CLIENT_MOD_RPC["ray"]["yiwangdituya2"], target.userid)
		
			local x,y,z = target.Transform:GetWorldPosition()
				for x =(x-150),(x+150),36 do
					for z=(z-150),(z+150),36 do
						target.player_classified.MapExplorer:RevealArea(x ,0, z)
					end
				end
	
		if jiuditu ~= nil then
			pcall(jiuditu, inst, target, ...)
		end

	end
end)


AddPlayerPostInit(function(inst)

    if not TheWorld.ismastersim then
        return inst
    end
		if inst.jiaose_yanchiyiwang == nil then
			inst.jiaose_yanchiyiwang = inst:DoTaskInTime(1, function()
					if ditujiesuomoshi then
							if  inst.jiaose_yanchiyiwang2 == nil then 
								inst.jiaose_yanchiyiwang2 = inst:DoPeriodicTask(1, function()
									if inst and inst.player_classified and inst.player_classified.MapExplorer then
										inst.player_classified.MapExplorer:EnableUpdate(false)
									end
								end)
							end
					else
						if TheWorld and TheWorld.minimap and TheWorld.minimap.MiniMap then
							TheWorld.minimap.MiniMap:ContinuouslyClearRevealedAreas(true)
						end
						SendModRPCToClient(CLIENT_MOD_RPC["ray"]["yiwangdituya"], inst.userid)
					end
					
					if inst.components.builder and not inst.components.builder:KnowsRecipe("sentryward") and inst.components.builder:CanLearn("sentryward") then
						inst.components.builder:UnlockRecipe("sentryward")
					end
					if inst.components.builder and not inst.components.builder:KnowsRecipe("moonrockcrater") and inst.components.builder:CanLearn("moonrockcrater") then
						inst.components.builder:UnlockRecipe("moonrockcrater")
					end
			end)
		end
end)