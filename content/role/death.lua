local mode = GetModConfigData("death_curse")
-- 帐篷内休息可以4倍速度消除诅咒
AddComponentPostInit("sleepingbaguser", function(self)
    local DoSleep = self.DoSleep
    self.DoSleep = function(self, ...)
        DoSleep(self, ...)
        if self.inst.components.inventory then
            for k, v in pairs(self.inst.components.inventory.equipslots) do
                if v and v:HasTag("curse2hm") and v.components.fueled then v.components.fueled.rate_modifiers:SetModifier(v, 8, "sleep2hm") end
            end
        end
        if self.inst._sleepinghandsitem and self.inst._sleepinghandsitem:IsValid() and self.inst._sleepinghandsitem:HasTag("curse2hm") and
            self.inst._sleepinghandsitem.components.fueled then
            self.inst._sleepinghandsitem.components.fueled.rate_modifiers:SetModifier(self.inst._sleepinghandsitem, 8, "sleep2hm")
            self.inst._sleepinghandsitem.components.fueled:StartConsuming()
        end
    end
    local DoWakeUp = self.DoWakeUp
    self.DoWakeUp = function(self, ...)
        DoWakeUp(self, ...)
        if self.inst.components.inventory then
            for k, v in pairs(self.inst.components.inventory.equipslots) do
                if v and v:HasTag("curse2hm") and v.components.fueled then v.components.fueled.rate_modifiers:RemoveModifier(v, "sleep2hm") end
            end
        end
        if self.inst._sleepinghandsitem and self.inst._sleepinghandsitem:IsValid() and self.inst._sleepinghandsitem:HasTag("curse2hm") and
            self.inst._sleepinghandsitem.components.fueled then
            self.inst._sleepinghandsitem.components.fueled.rate_modifiers:RemoveModifier(self.inst._sleepinghandsitem, "sleep2hm")
        end
    end
end)

-- 玩家复活后获得一个诅咒
local function getdeathcurse(inst)
    if inst and inst.components.inventory then
        local curse = SpawnPrefab("mod_hardmode_deathcursedequip")
        if curse then
            curse.userid = inst.userid
            curse.lockowner2hm = inst
            curse.Transform:SetPosition(inst.Transform:GetWorldPosition())
            local current = inst.components.inventory:GetEquippedItem(curse.components.equippable.equipslot)
            if current == nil then
                inst.components.inventory:Equip(curse)
            elseif current and current.prefab ~= curse.prefab then
                inst.components.inventory:DropItem(current, true)
                inst.components.inventory:Equip(curse)
                if current.components.inventoryitem and current.components.inventoryitem.cangoincontainer then
                    inst.components.inventory:GiveItem(current)
                end
            else
                inst.components.inventory:GiveItem(curse)
            end
        end
    end
end
-- 太平间
-- if Morgue then
--     local OnDeath = Morgue.OnDeath
--     Morgue.OnDeath = function(self, row, ...)
--         if row and row.days_survived then row.deathtime2hm = GetGameTime2hm() end
--         return OnDeath(self, row, ...)
--     end
-- end
-- 加载时检测到是回档,且回档前死亡过则会获得一个诅咒,不回档不会重复获得诅咒
local function checkdeathrollback(inst)
    if not TUNING.TEMP2HM then return end
    if not TheWorld.components.persistent2hm.data.worldinit then
        TheWorld.components.persistent2hm.data.worldinit = true
        if not TUNING.TEMP2HM.deathrollback or IsTableEmpty(TUNING.TEMP2HM.deathrollback) then return end
        TUNING.TEMP2HM.deathrollback = {}
        SaveTemp2hm()
        return
    end
    local data = inst.components.persistent2hm.data
    if mode ~= -1 and inst.userid and not inst:HasTag("playerghost") and TUNING.TEMP2HM.deathrollback and TUNING.TEMP2HM.deathrollback[inst.userid] and
        TUNING.TEMP2HM.deathrollback[inst.userid].cycles and (TheWorld.state.cycles < TUNING.TEMP2HM.deathrollback[inst.userid].cycles or
        (TheWorld.state.cycles == TUNING.TEMP2HM.deathrollback[inst.userid].cycles and CalcTimeOfDay2hm() <
            TUNING.TEMP2HM.deathrollback[inst.userid].time_of_day)) and
        (data.deathrollback == nil or data.deathrollback.cycles < TUNING.TEMP2HM.deathrollback[inst.userid].cycles or
            (data.deathrollback.cycles == TUNING.TEMP2HM.deathrollback[inst.userid].cycles and data.deathrollback.time_of_day <
                TUNING.TEMP2HM.deathrollback[inst.userid].time_of_day)) then
        data.deathrollback = data.deathrollback or {}
        data.deathrollback.cycles = TUNING.TEMP2HM.deathrollback[inst.userid].cycles
        data.deathrollback.time_of_day = TUNING.TEMP2HM.deathrollback[inst.userid].time_of_day
        TheNet:Announce(TUNING.isCh2hm and ("悲惨,玩家 " .. (inst.name or inst.userid) .. " 回档前的战死经历让ta身受重伤") or
                            ("Wow,Player " .. (inst.name or inst.userid) .. " rollback death make player hurt still"))
        getdeathcurse(inst)
    end
end
-- 死亡信息同步到其他世界
AddShardModRPCHandler("MOD_HARDMODE", "deathsync2hm", function(shard_id, userid, cycles, time_of_day)
    if TheShard and tostring(TheShard:GetShardId()) ~= tostring(shard_id) and userid and cycles and TUNING.TEMP2HM and
        TheWorld.components.persistent2hm.data.worldinit then
        -- if TUNING.TEMP2HM.cycles then
        --     TUNING.TEMP2HM.cycles = nil
        --     TUNING.TEMP2HM.time_of_day = nil
        -- end
        TUNING.TEMP2HM.deathrollback = TUNING.TEMP2HM.deathrollback or {}
        TUNING.TEMP2HM.deathrollback[userid] = TUNING.TEMP2HM.deathrollback[userid] or {}
        TUNING.TEMP2HM.deathrollback[userid].deathtimes = (TUNING.TEMP2HM.deathrollback[userid].deathtimes or 0) + 1
        if TUNING.TEMP2HM.deathrollback[userid].cycles then
            if TUNING.TEMP2HM.deathrollback[userid].cycles < cycles then
                TUNING.TEMP2HM.deathrollback[userid].cycles = cycles
                TUNING.TEMP2HM.deathrollback[userid].time_of_day = time_of_day
            elseif TUNING.TEMP2HM.deathrollback[userid].cycles == cycles then
                TUNING.TEMP2HM.deathrollback[userid].time_of_day = math.max(time_of_day, TUNING.TEMP2HM.deathrollback[userid].time_of_day)
            end
        else
            TUNING.TEMP2HM.deathrollback[userid].cycles = cycles
            TUNING.TEMP2HM.deathrollback[userid].time_of_day = time_of_day
        end
        SaveTemp2hm()
    end
end)
local function ondeath(inst)
    if inst.userid and TUNING.TEMP2HM and TheWorld.components.persistent2hm.data.worldinit and mode ~= -1 then
        -- if TUNING.TEMP2HM.cycles then
        --     TUNING.TEMP2HM.cycles = nil
        --     TUNING.TEMP2HM.time_of_day = nil
        -- end
        TUNING.TEMP2HM.deathrollback = TUNING.TEMP2HM.deathrollback or {}
        TUNING.TEMP2HM.deathrollback[inst.userid] = TUNING.TEMP2HM.deathrollback[inst.userid] or {}
        TUNING.TEMP2HM.deathrollback[inst.userid].deathtimes = (TUNING.TEMP2HM.deathrollback[inst.userid].deathtimes or 0) + 1
        if TUNING.TEMP2HM.deathrollback[inst.userid].cycles then
            if TUNING.TEMP2HM.deathrollback[inst.userid].cycles < TheWorld.state.cycles then
                TUNING.TEMP2HM.deathrollback[inst.userid].cycles = TheWorld.state.cycles
                TUNING.TEMP2HM.deathrollback[inst.userid].time_of_day = CalcTimeOfDay2hm()
            elseif TUNING.TEMP2HM.deathrollback[inst.userid].cycles == TheWorld.state.cycles then
                TUNING.TEMP2HM.deathrollback[inst.userid].time_of_day = math.max(CalcTimeOfDay2hm(), TUNING.TEMP2HM.deathrollback[inst.userid].time_of_day)
            end
        else
            TUNING.TEMP2HM.deathrollback[inst.userid].cycles = TheWorld.state.cycles
            TUNING.TEMP2HM.deathrollback[inst.userid].time_of_day = CalcTimeOfDay2hm()
        end
        SaveTemp2hm()
        SendModRPCToShard(GetShardModRPC("MOD_HARDMODE", "deathsync2hm"), nil, inst.userid, TUNING.TEMP2HM.deathrollback[inst.userid].cycles,
                          TUNING.TEMP2HM.deathrollback[inst.userid].time_of_day)
    end
end
-- 复活时必定获得一个诅咒
local function onrespawnedfromghost(inst) inst:DoTaskInTime(1.5, getdeathcurse) end
-- 一共四个信号:death,death动画结束时makeplayerghost,ms_becameghost;respawnfromghost,ms_respawnedfromghost
AddPlayerPostInit(function(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("ms_respawnedfromghost", onrespawnedfromghost)
    inst:ListenForEvent("death", ondeath)
    inst:DoTaskInTime(4.5, checkdeathrollback)
end)

-- local SendWorldResetRequestToServer = getmetatable(TheNet).__index["SendWorldResetRequestToServer"]
-- getmetatable(TheNet).__index["SendWorldResetRequestToServer"] = function(...)

--     return SendWorldResetRequestToServer(...)
-- end
