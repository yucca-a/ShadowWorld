TUNING.WOLFGANG_COACH_BUFF = (TUNING.WOLFGANG_COACH_BUFF - 1) / 2 + 1
if not (TUNING.DSTU and TUNING.DSTU.WOLFGANG_HUNGERMIGHTY) then
    local easymode = TUNING.easymode2hm and GetModConfigData("role_easy") and GetModConfigData("Wolfgang Strong Battle Speedup")
    -- 沃尔夫冈饥饿速率修正
    local hunger_mult = {mighty = easymode and 1.25 or 1.75, normal = 1, wimpy = easymode and 0.75 or 1}
    local function statechange(inst, data) inst.components.hunger.burnrate = hunger_mult[data and data.state or "normal"] or 1 end
    local function init(inst)
        inst.components.hunger.burnrate = hunger_mult[inst.GetCurrentMightinessState and inst:GetCurrentMightinessState() or "normal"] or 1
    end
    AddPrefabPostInit("wolfgang", function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("mightiness_statechange", statechange)
        inst:DoTaskInTime(0, init)
        inst.hungermults2hm = hunger_mult
    end)
    AddComponentPostInit("mightiness", function(self)
        if not self.inst:HasTag("strongman") then return end
        local DoDelta = self.DoDelta
        self.DoDelta = function(self, dt, force, ...)
            if self.state == "mighty" and not force and TUNING.MIGHTY_THRESHOLD == 75 then
                TUNING.MIGHTY_THRESHOLD = 50
            elseif self.state == "wimpy" and not force and TUNING.WIMPY_THRESHOLD == 25 then
                TUNING.WIMPY_THRESHOLD = 50
            end
            DoDelta(self, dt, force, ...)
            if TUNING.MIGHTY_THRESHOLD == 50 then
                TUNING.MIGHTY_THRESHOLD = 75
            elseif TUNING.WIMPY_THRESHOLD == 50 then
                TUNING.WIMPY_THRESHOLD = 25
            end
        end
    end)
    TUNING.WOLFGANG_MIGHTY_WORK_CHANCE_1 = 0.97
    TUNING.WOLFGANG_MIGHTY_WORK_CHANCE_2 = 0.95
    TUNING.WOLFGANG_MIGHTY_WORK_CHANCE_3 = 0.93
    for k, v in pairs(TUNING.WOLFGANG_MIGHTINESS_WORK_GAIN) do TUNING.WOLFGANG_MIGHTINESS_WORK_GAIN[k] = 0 end
    TUNING.WOLFGANG_MIGHTINESS_ATTACK_GAIN_GIANT = 1
    TUNING.WOLFGANG_MIGHTINESS_ATTACK_GAIN_SMALLCREATURE = 0.25
    TUNING.WOLFGANG_MIGHTINESS_ATTACK_GAIN_DEFAULT = 0.5
end
-- local function combatrefresh(inst)
    -- local index = #AllPlayers
    -- if index < 3 then
        -- inst.components.combat.externaldamagemultipliers:SetModifier(inst, 1 - (3 - index) * 0.1, "AllPlayers2hm")
    -- else
        -- inst.components.combat.externaldamagemultipliers:RemoveModifier(inst, "AllPlayers2hm")
    -- end
-- end
-- local function combatinit(inst)
    -- if not inst.combatrefresh2hm then inst.combatrefresh2hm = function() combatrefresh(inst) end end
    -- combatrefresh(inst)
    -- inst:ListenForEvent("ms_playerjoined", inst.combatrefresh2hm, TheWorld)
    -- inst:ListenForEvent("ms_playerleft", inst.combatrefresh2hm, TheWorld)
-- end
-- AddPrefabPostInit("wolfgang", function(inst)
    -- if not TheWorld.ismastersim then return end
    -- inst:DoTaskInTime(0, combatinit)
-- end)