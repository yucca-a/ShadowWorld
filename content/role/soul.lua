local deathcurse = GetModConfigData("death_curse")
-- 给角色加一个变量即可防范灵魂受伤 inst.disablesouldeath2hm = true
-- 是否处于可以受伤的灵魂状态
local function canhurt(inst)
    return inst and inst:IsValid() and not inst.disablesouldeath2hm and inst:HasTag("playerghost") and not inst:HasTag("reviving") and inst.prefab ~= "ray" and
               inst.components.health
end

-- 禁用排队论作祟从而解决客户端兼容问题
AddComponentPostInit("actionqueuer", function(self) if self.AddAction then self.AddAction("leftclick", "HAUNT", falsefn) end end)

-- 灵魂死亡
AddClientModRPCHandler("MOD_HARDMODE", "stopplayeraction", function(inst)
    if not require("rpcguard2hm").IsEntity(inst) then return end
    if inst.components and inst.components.actionqueuer and inst.components.actionqueuer.ClearAllThreads then inst.components.actionqueuer:ClearAllThreads() end
end)
local function souldeath(inst)
    if inst and inst:IsValid() and inst.userid and inst.components.seamlessplayerswapper and not inst.disablesouldeath2hm then
        inst.disablesouldeath2hm = true
        inst:Hide()
        -- 停止玩家动作
        if inst.sg then inst.sg:Stop() end
        if inst.components.locomotor then
            inst.components.locomotor:Stop()
            inst.components.locomotor:Clear()
        end
        if inst.components.playercontroller then inst.components.playercontroller:Enable(false) end
        -- 停止玩家客户端的排队论动作
        SendModRPCToClient(GetClientModRPC("MOD_HARDMODE", "stopplayeraction"), inst.userid, inst)
        -- 复活特效
        SpawnPrefab("die_fx").Transform:SetPosition(inst.Transform:GetWorldPosition())
        SpawnPrefab("spawn_fx_medium_static").Transform:SetPosition(inst.Transform:GetWorldPosition())
        -- 清除旧地图数据
        local SaveForReroll = inst.SaveForReroll
        inst.SaveForReroll = function(inst, ...)
            local data = SaveForReroll(inst, ...) or {}
            data.builder = nil
            data.maps = nil
            if deathcurse then
                data.curses = data.curses or {}
                data.curses.mod_hardmode_deathcursedequip = (data.curses.mod_hardmode_deathcursedequip or 0) + 1
            end
            return data
        end
        -- 设置新坐标
        inst.Transform:SetPosition(TheWorld.components.playerspawner:GetAnySpawnPoint())
        inst:DoTaskInTime(0.25, function() SpawnPrefab("spawn_fx_medium_static").Transform:SetPosition(inst.Transform:GetWorldPosition()) end)
        inst:DoTaskInTime(1, function() inst.components.seamlessplayerswapper:_StartSwap(inst.prefab) end)
    end
end

-- 灭火
local FIRE_CANT_TAGS = {"INLIMBO", "lighter"}
local FIRE_ONEOF_TAGS = {"fire", "smolder"}
local function stopfires(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local fires = TheSim:FindEntities(x, y, z, TUNING.BOOK_FIRE_RADIUS / 2, nil, FIRE_CANT_TAGS, FIRE_ONEOF_TAGS)
    if #fires > 0 then
        for i, fire in ipairs(fires) do
            if fire:IsValid() and fire.components.burnable and not (fire:HasTag("campfire") and fire.prefab ~= "campfire") then
                fire.components.burnable:Extinguish(true, 0)
            end
        end
    end
end

-- 清除灵魂保护区
local function clearsoulhelpfx(inst)
    if inst.components.persistent2hm.deathsoulpos2hm then inst.components.persistent2hm.deathsoulpos2hm = nil end
    if inst.soulhelpfx2hm then
        if inst.soulhelpfx2hm:IsValid() then inst.soulhelpfx2hm:Remove() end
        inst.soulhelpfx2hm = nil
    end
end

-- 灵魂受伤（地表白天且不在死亡位置附近;地下远古区域不平静或地下非远古区域正在暴动且不在死亡位置附近）
local function soulhurt(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    if (not TheWorld:HasTag("cave") and
        (inst.soulhelpfx2hm and inst.soulhelpfx2hm:IsValid() and inst:IsNear(inst.soulhelpfx2hm, 18) or not TheWorld.state.isday)) or
        (TheWorld:HasTag("cave") and (not TheWorld.state.isnightmarecalm and TheWorld.Map:FindVisualNodeAtPoint(x, 0, z, "Nightmare") ~= nil or
            (TheWorld.state.isnightmarewild and inst.soulhelpfx2hm and inst.soulhelpfx2hm:IsValid() and inst:IsNear(inst.soulhelpfx2hm, 18)))) then return end
    -- if ShardPortals and #ShardPortals > 0 then for i, v in ipairs(ShardPortals) do if v and v:IsValid() and inst:IsNear(v, 6) then return end end end
    clearsoulhelpfx(inst)
    inst.SoundEmitter:PlaySound("dontstarve/sanity/shadowrock_down")
    inst:AddChild(SpawnPrefab("sanity_lower"))
    -- SpawnPrefab("sanity_lower").Transform:SetPosition(inst.Transform:GetWorldPosition())
    local iv = inst:HasTag("health_as_oldage") and 0.4 or 1
    if not inst.components.health.disable_penalty then inst.components.health:DeltaPenalty(0.01) end
    if not inst.lastsoulhealth2hm then inst.lastsoulhealth2hm = inst.components.health.currenthealth end
    if inst.components.health.currenthealth > 1 then
        inst.components.health.currenthealth = math.max(inst.components.health.currenthealth - iv, 1, inst.lastsoulhealth2hm - 10)
        inst.lastsoulhealth2hm = inst.components.health.currenthealth
    elseif inst.lastsoulhealth2hm and inst.lastsoulhealth2hm <= 3 then
        inst.components.health.currenthealth = 1
        inst.lastsoulhealth2hm = nil
        souldeath(inst)
    end
end
-- 作祟时同样也会受伤
AddComponentPostInit("hauntable", function(self)
    local DoHaunt = self.DoHaunt
    self.DoHaunt = function(self, doer, ...)
        DoHaunt(self, doer, ...)
        if canhurt(doer) then
            soulhurt(doer)
            stopfires(doer)
        end
    end
end)
-- 停止检测阳光且移除保护区
local function stopdeathcheck(inst)
    clearsoulhelpfx(inst)
    if inst.soulsunchecktask2hm then
        inst.soulsunchecktask2hm:Cancel()
        inst.soulsunchecktask2hm = nil
    end
    inst.lastsoulhealth2hm = nil
end
-- 任务-持续检测阳光
local function soulsuncheck(inst)
    if not canhurt(inst) then
        stopdeathcheck(inst)
    else
        if inst.components.sheltered and inst.components.sheltered.sheltered and TheWorld.state.isday and not TheWorld:HasTag("cave") then
            inst:AddChild(SpawnPrefab("shadow_puff_solid"))
        else
            soulhurt(inst)
        end
    end
end
-- 死亡时开始检测阳光
local function beginsuncheck(inst) if canhurt(inst) and not inst.soulsunchecktask2hm then inst.soulsunchecktask2hm = inst:DoPeriodicTask(12, soulsuncheck, 6) end end
-- 重载时开始检测阳光
local function onload(inst)
    if not inst.ghostenabled then return end
    if canhurt(inst) then
        if inst.components.persistent2hm.deathsoulpos2hm and not (inst.soulhelpfx2hm and inst.soulhelpfx2hm:IsValid()) then
            local pos = inst.components.persistent2hm.deathsoulpos2hm
            if pos.worldid == TheShard:GetShardId() then
                local fx = SpawnPrefab("reticuleaoeshadowtarget_6")
                fx.Transform:SetPosition(pos.x, pos.y, pos.z)
                fx.AnimState:SetScale(3, 3, 3)
                inst.soulhelpfx2hm = fx
            end
        end
        inst:DoTaskInTime(6, beginsuncheck)
        if not inst.lastsoulhealth2hm then inst.lastsoulhealth2hm = inst.components.health.currenthealth end
    else
        clearsoulhelpfx(inst)
    end
end
local function OnMakePlayerGhost(inst) inst:DoTaskInTime(0, onload) end
-- 死亡时准备检测阳光
local function ondeath(inst)
    if not inst.ghostenabled then return end
    if not (inst.soulhelpfx2hm and inst.soulhelpfx2hm:IsValid()) then
        local x, y, z = inst.Transform:GetWorldPosition()
        local fx = SpawnPrefab("reticuleaoeshadowtarget_6")
        fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
        fx.AnimState:SetScale(3, 3, 3)
        inst.soulhelpfx2hm = fx
        inst.components.persistent2hm.deathsoulpos2hm = {x = x, y = y, z = z, worldid = TheShard:GetShardId()}
    end
    inst:DoTaskInTime(1, stopfires)
    inst.lastsoulhealth2hm = nil
end

AddPlayerPostInit(function(inst)
    if not TheWorld.ismastersim then return end
    if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
    inst:DoTaskInTime(1, onload)
    inst:ListenForEvent("onremove", clearsoulhelpfx)
    inst:ListenForEvent("death", ondeath)
    inst:ListenForEvent("makeplayerghost", OnMakePlayerGhost)
    inst:ListenForEvent("ms_respawnedfromghost", stopdeathcheck)
    -- 换角色时继承相关惩罚
    local oldSaveForReroll = inst.SaveForReroll
    inst.SaveForReroll = function(inst, ...)
        local data = oldSaveForReroll(inst, ...)
        data = data or {}
        if inst.components.health then data.healthpenalty2hm = inst.components.health.penalty > 0 and inst.components.health.penalty or nil end
        if inst.components.hunger and inst.components.hunger.penalty2hm then
            data.hungerpenalty2hm = inst.components.hunger.penalty2hm > 0 and inst.components.hunger.penalty2hm or nil
        end
        return data
    end
    local oldLoadForReroll = inst.LoadForReroll
    inst.LoadForReroll = function(inst, data, ...)
        oldLoadForReroll(inst, data, ...)
        if data then
            if data.healthpenalty2hm and data.healthpenalty2hm > 0 and inst.components.health then
                inst.components.health:SetPenalty(data.healthpenalty2hm)
            end
            if data.hungerpenalty2hm and data.hungerpenalty2hm > 0 and inst.components.hunger and inst.components.hunger.SetPenalty2hm then
                inst.components.hunger:SetPenalty2hm(data.hungerpenalty2hm)
            end
        end
    end
end)

-- 灵魂状态下依旧看得到血量和血量惩罚
AddClassPostConstruct("widgets/statusdisplays", function(self)
    local SetGhostMode = self.SetGhostMode
    self.SetGhostMode = function(self, ghostmode, ...)
        SetGhostMode(self, ghostmode, ...)
        if self.isghostmode then
            self.heart:Show()
            if self.onhealthdelta2hm == nil then
                self.onhealthdelta2hm = function(owner, data) self:HealthDelta(data) end
                self.inst:ListenForEvent("healthdelta", self.onhealthdelta2hm, self.owner)
                self:SetHealthPercent(self.owner.replica.health:GetPercent())
            end
        else
            if self.onhealthdelta2hm ~= nil then
                self.inst:RemoveEventCallback("healthdelta", self.onhealthdelta2hm, self.owner)
                self.onhealthdelta2hm = nil
                self:SetHealthPercent(self.owner.replica.health:GetPercent())
            end
        end
    end
end)

-- 死因
AddStategraphPostInit("wilson", function(sg)
    local onenter = sg.states.seamlessplayerswap_death.onenter
    sg.states.seamlessplayerswap_death.onenter = function(inst, ...)
        inst.deathclientobj = inst.deathclientobj or TheNet:GetClientTableForUser(inst.userid)
        inst.deathcause = inst.deathcause or "unknown"
        onenter(inst, ...)
    end
end)
