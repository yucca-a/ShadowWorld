-- 新三王加强
local mutatedmonsters = {mutatedwarg = true, mutateddeerclops = true, mutatedbearger = true}
local mutatedfrom = {"bearger", "deerclops", "warg"}
local function showshieldfx(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    SpawnPrefab("statue_transition_2").Transform:SetPosition(x, y, z)
    if not inst.teleportdamagefx2hm then SpawnPrefab("shadow_teleport_in2hm").Transform:SetPosition(x, y, z) end
end
-- 新三王本体检测玩家远离距离翻倍,默认200翻倍为400
-- 当玩家远离新三王本体时,不会常规地影分身消失回归了,若之前参与过与玩家的战斗且存在影分身,会本体回血10%分身回血25%并召回所有影分身
local function mutatedonfar(inst)
    if inst.components.childspawner2hm and not inst.teleportchildcdtask2hm and not POPULATING and inst.playerattacked2hm and
        inst.components.childspawner2hm.numchildrenoutside > 0 then
        inst.playerattacked2hm = nil
        inst.teleportchildcdtask2hm = inst:DoTaskInTime(10, function() inst.teleportchildcdtask2hm = nil end)
        if inst.components.health and not inst.components.health:IsDead() then
            inst.components.health:SetPercent(inst.components.health:GetPercent() + 0.1 + (inst.gestaltrate2hm or 0))
            inst.gestaltrate2hm = nil
        end
        if inst.gestalt2hm and inst.gestalt2hm:IsValid() then
            inst.gestalt2hm:Remove()
            inst.gestalt2hm = nil
        end
        for k, child in pairs(inst.components.childspawner2hm.childrenoutside) do
            if child:IsValid() and not child.isdead2hm then
                teleportchild(child, inst)
                if child.components.health and not child.components.health:IsDead() then
                    child.components.health:SetPercent(child.components.health:GetPercent() + 0.25)
                end
            end
        end
    end
end
local function OnMutatedAttacked(inst, data)
    if not inst.playerattacked2hm and data and data.attacker and data.attacker:IsValid() and data.attacker:HasTag("player") then
        inst.playerattacked2hm = true
    end
end
local function OnMutatedMinHealth(inst)
    if inst.gestaltrate2hm and inst.gestaltrate2hm > 0 and inst.components.health then
        inst.components.health.currenthealth = inst.components.health.minhealth + inst.components.health.maxhealth * math.min(inst.gestaltrate2hm, 0.5)
        inst.gestaltrate2hm = inst.gestaltrate2hm > 0.5 and inst.gestaltrate2hm - 0.5
        if inst.gestalt2hm and inst.gestalt2hm:IsValid() then
            inst.gestalt2hm.Physics:Teleport(inst:GetPosition():Get())
            inst.gestalt2hm.sg:Stop()
            inst.gestalt2hm.sg:Start()
            inst.gestalt2hm.sg:GoToState("infest")
        else
            local gestalt = SpawnPrefab("corpse_gestalt")
            inst.gestalt2hm = gestalt
            gestalt.target2hm = inst
            gestalt.AnimState:SetMultColour(0, 0, 0, 0.6)
            gestalt.persists = false
            gestalt.Physics:Teleport(inst:GetPosition():Get())
            if gestalt.components.entitytracker then gestalt.components.entitytracker:TrackEntity("corpse", inst) end
            gestalt.sg:GoToState("infest")
        end
        showshieldfx(inst)
    end
end
-- -- 新三王本体改动
local function updatemutatedmonster(inst)
    inst.components.playerprox2hm:SetDist(60, swepicfarrange <= 3000 and swepicfarrange * 2 or swepicfarrange)
    inst.components.playerprox2hm:SetOnPlayerFar(mutatedonfar)
    inst:ListenForEvent("GetAttacked_Internal2hm", OnMutatedAttacked)
    inst:ListenForEvent("minhealth", OnMutatedMinHealth)
    if inst.components.health then
        local OnSave = inst.components.health.OnSave
        inst.components.health.OnSave = function(self, ...)
            local data = OnSave(self, ...)
            if data.health and self.inst.gestaltrate2hm and self.inst.gestaltrate2hm > 0 then
                data.health = data.health + self.maxhealth * self.inst.gestaltrate2hm
            end
            return data
        end
    end
end
-- -- 新三王分身改动
-- local function updatemutatedshadow(inst, child) end
if TUNING.hardmode2hm and GetModConfigData("monster_change") and GetModConfigData("gestalt") then
    -- 新三王本体疲惫开始时转移伤害给分身且召唤分身回来,疲惫结束时不再转移伤害,恢复分身血量
    local function addteleportdamagefx(inst, isin, proxy, notsetval)
        if not (inst.teleportdamagefx2hm and inst.teleportdamagefx2hm:IsValid()) then
            inst.teleportdamagefx2hm = SpawnPrefab(isin and "shadow_teleport_in2hm" or "shadow_teleport_out2hm")
            inst.teleportdamagefx2hm.Transform:SetPosition((proxy or inst):GetPosition():Get())
            if notsetval then inst.teleportdamagefx2hm = nil end
        end
    end
    local function mutatedredirectdamagefn(inst, attacker, ...)
        if inst.components.childspawner2hm and inst.components.childspawner2hm.numchildrenoutside > 0 then
            addteleportdamagefx(inst, nil, attacker)
            for k, v in pairs(inst.components.childspawner2hm.childrenoutside) do
                if v:IsValid() and not v.isdead2hm and v.components.combat and v.components.health and not v.components.health:IsDead() then
                    addteleportdamagefx(v, true)
                    return v
                end
            end
        end
    end
    -- 召唤暗影月灵回血
    if STRINGS.NAMES.LUNARTHRALL_PLANT_GESTALT == "亮茄虚影" then STRINGS.NAMES.LUNARTHRALL_PLANT_GESTALT = "附生虚影" end
    if not STRINGS.NAMES.LUNARTHRALL_PLANT_GESTALT then STRINGS.NAMES.CORPSE_GESTALT = STRINGS.NAMES.LUNARTHRALL_PLANT_GESTALT end
    local function StartMutation_mutated(inst)
        if inst.gestaltrate2hm and inst.components.health and not inst.components.health:IsDead() then
            inst.components.health:SetPercent(inst.components.health:GetPercent() + inst.gestaltrate2hm)
            showshieldfx(inst)
            inst.gestaltrate2hm = nil
        end
        if inst.gestalt2hm then inst.gestalt2hm = nil end
    end
    local function spawnmutatedgestalt(inst, rate)
        if inst.components.health and not inst.components.health:IsDead() and inst.components.health:IsHurt() then
            if inst.StartMutation == StartMutation_mutated and not inst:IsAsleep() then
                inst.gestaltrate2hm = (inst.gestaltrate2hm or 0) + rate
                if not (inst.gestalt2hm and inst.gestalt2hm:IsValid() and inst:IsNear(inst.gestalt2hm, 36)) then
                    local gestalt = SpawnPrefab("corpse_gestalt")
                    gestalt.AnimState:SetMultColour(0, 0, 0, 0.6)
                    local scale = math.clamp(inst.gestaltrate2hm * 4, 0.75, 1.5)
                    gestalt.Transform:SetScale(scale, scale, scale)
                    inst.gestalt2hm = gestalt
                    gestalt.target2hm = inst
                    gestalt.persists = false
                    gestalt:SetTarget(inst)
                    gestalt:Spawn()
                end
            else
                inst.components.health:SetPercent(inst.components.health:GetPercent() + rate)
                showshieldfx(inst)
            end
        end
    end
    -- 新三王本体倒地时会召回脱战的影分身且为所有分身回血25%,倒地期间转移伤害给存在的影分身,倒地起身时若存在影分身会本体回血25%
    local function updatemutatedsg(sg)
        local oldpre = sg.states.stagger_pre.onenter
        sg.states.stagger_pre.onenter = function(inst, ...)
            oldpre(inst, ...)
            if inst:HasTag("lunar_aligned") and inst:HasTag("swp2hm") and inst.components.childspawner2hm and inst.components.combat and
                not inst.components.combat.redirectdamagefn then
                inst.components.combat.redirectdamagefn = mutatedredirectdamagefn
                if inst.components.childspawner2hm.numchildrenoutside > 0 then
                    addteleportdamagefx(inst)
                    for k, child in pairs(inst.components.childspawner2hm.childrenoutside) do
                        if child:IsValid() and not child.isdead2hm then
                            if child:IsAsleep() or not (child.components.combat and child.components.combat.target) then
                                teleportchild(child, inst)
                            end
                            addteleportdamagefx(child, true)
                            spawnmutatedgestalt(child, 0.25)
                        end
                    end
                end
            end
        end
        local oldpst = sg.states.stagger_pst.onexit
        sg.states.stagger_pst.onexit = function(inst, ...)
            if oldpst then oldpst(inst, ...) end
            if inst:HasTag("lunar_aligned") and inst:HasTag("swp2hm") and inst.components.childspawner2hm and inst.components.combat and
                inst.components.combat.redirectdamagefn == mutatedredirectdamagefn then
                inst.components.combat.redirectdamagefn = nil
                inst.teleportdamagefx2hm = nil
                if inst.components.childspawner2hm.numchildrenoutside > 0 then spawnmutatedgestalt(inst, 0.25) end
                for k, child in pairs(inst.components.childspawner2hm.childrenoutside) do
                    if child:IsValid() and child.teleportdamagefx2hm then child.teleportdamagefx2hm = nil end
                end
            end
        end
    end
    for index, from in ipairs(mutatedfrom) do AddStategraphPostInit(from, updatemutatedsg) end
    -- 新三王本体有倒地机会但玩家没抓住时,若存在影分身会本体回血10%且5%概率召回脱战的影分身(巨鹿眼球长冰时才有,触发最少)
    local function mutatedteleportchildrencd(inst) inst.mutatedteleportchildrencd2hm = nil end
    local function recovermutated(inst)
        if inst:HasTag("lunar_aligned") and (inst.components.childspawner2hm and inst.components.childspawner2hm.numchildrenoutside > 0 or
            (inst:HasTag("swc2hm") and inst.components.combat and inst.components.combat.target and inst.components.combat.target:IsValid() and
                inst.components.combat.target:HasTag("player"))) then
            spawnmutatedgestalt(inst, inst:HasTag("swp2hm") and 0.1 or 0.05)
            if inst:HasTag("swp2hm") and inst.components.childspawner2hm and not inst.mutatedteleportchildrencd2hm then
                inst.mutatedteleportchildrenindex2hm = (inst.mutatedteleportchildrenindex2hm or 0) + 1
                if math.random() < inst.mutatedteleportchildrenindex2hm * 0.1 then
                    inst.mutatedteleportchildrenindex2hm = nil
                    inst.mutatedteleportchildrencd2hm = inst:DoTaskInTime(30, mutatedteleportchildrencd)
                    for k, child in pairs(inst.components.childspawner2hm.childrenoutside) do
                        if child:IsValid() and not child.isdead2hm and (child:IsAsleep() or not (child.components.combat and child.components.combat.target)) then
                            teleportchild(child, inst)
                            addteleportdamagefx(child, true, nil, true)
                        end
                    end
                end
            end
        end
    end
end
