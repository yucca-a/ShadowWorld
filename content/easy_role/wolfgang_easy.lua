local hardmode = TUNING.hardmode2hm and GetModConfigData("role_nerf")

-- 沃尔夫冈强壮时打架加速
if GetModConfigData("Wolfgang Strong Battle Speedup") then
    local function leavebattle(inst)
        if inst.mightybattlespeeduptask2hm then inst.mightybattlespeeduptask2hm = nil end
        inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "mightybattlespeeduptask2hm")
        if inst.hungermults2hm and (inst.components.hunger.burnrate or 1) > 1.25 then inst.components.hunger.burnrate = 1.25 end
    end
    local function onbattle(inst)
        if not inst:HasTag("playerghost") and inst.GetCurrentMightinessState and inst:GetCurrentMightinessState() == "mighty" then
            if inst.mightybattlespeeduptask2hm then
                inst.mightybattlespeeduptask2hm:Cancel()
            else
                inst.components.talker:Say((TUNING.isCh2hm and "打起精神" or "Wolfgang's battle"))
                local fx = SpawnPrefab("wanda_attack_pocketwatch_old_fx")
                local x, y, z = inst.Transform:GetWorldPosition()
                local radius = inst:GetPhysicsRadius(.5)
                local angle = (inst.Transform:GetRotation() - 90) * DEGREES
                fx.Transform:SetPosition(x + math.sin(angle) * radius, 0, z + math.cos(angle) * radius)
            end
            inst.mightybattlespeeduptask2hm = inst:DoTaskInTime(8, leavebattle)
            inst.components.locomotor:SetExternalSpeedMultiplier(inst, "mightybattlespeeduptask2hm", 1.25)
            if inst.hungermults2hm and (inst.components.hunger.burnrate or 1) < 1.75 then inst.components.hunger.burnrate = 1.75 end
        end
    end
    AddPrefabPostInit("wolfgang", function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("attacked", onbattle)
        inst:ListenForEvent("onhitother", onbattle)
    end)
end

-- 沃尔夫冈可以打断战斗变身
if GetModConfigData("Wolfgang break Powerup/down") then
    local specialstates = {
        -- "powerup_wurt",
        -- "powerdown_wurt",
        "powerup",
        "powerdown"
    }
    AddStategraphPostInit("wilson", function(sg)
        for i, specialstate in ipairs(specialstates) do
            local oldOnEnter = sg.states[specialstate].onenter
            sg.states[specialstate].onenter = function(inst)
                inst.ismighty2hm = inst.prefab == "wolfgang" and not (inst:HasTag("ingym") or inst.sg.mem.lifting_dumbbell)
                oldOnEnter(inst)
                if inst.ismighty2hm then inst.sg:SetTimeout(10 * FRAMES) end
            end
            sg.states[specialstate].ontimeout = function(inst)
                if inst.sg.currentstate.name == specialstate and sg.states[specialstate].timeline and sg.states[specialstate].timeline[1] then
                    sg.states[specialstate].timeline[1].fn(inst)
                    if inst.ismighty2hm then inst.ismighty2hm = nil end
                    inst.sg:GoToState("idle", true)
                end
            end
        end
    end)
end

-- 沃尔夫冈吃食物增加力量值
local Wolfgangfood = GetModConfigData("Wolfgang Eat Food For Mightiness")
if Wolfgangfood then
    local rate = Wolfgangfood == true and 0.35 or Wolfgangfood
    local function OnEat(inst, data)
        local food = data.food
        if food == nil or inst.components.mightiness == nil then return end
        local hunger = food.components.edible:GetHunger(inst)
        inst.components.mightiness:DoDelta(hunger * rate)
    end
    AddPrefabPostInit("wolfgang", function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("oneat", OnEat)
    end)
end

-- 沃尔夫冈吃饱时不掉力量值
local Wolfgangthreshold = GetModConfigData("Wolfgang Pause Drain When Satiated")
if Wolfgangthreshold and not (TUNING.DSTU and TUNING.DSTU.WOLFGANG_HUNGERMIGHTY) then
    local threshold = Wolfgangthreshold == true and 100 or Wolfgangthreshold
    AddComponentPostInit("mightiness", function(self)
        if not self.inst:HasTag("strongman") then return end
        local oldDoDec = self.DoDec
        self.DoDec = function(self, ...)
            if self.draining and not self.invincible and self.inst.components.hunger and self.inst.components.hunger.current >= threshold then
                self:DelayDrain(2)
                return
            end
            oldDoDec(self, ...)
        end
    end)
end