-- 蜜蜂增强,蜜蜂全部远程攻击
local function cancelnearattacktask2hm() inst.nearattacktask2hm = nil end
local function cancelrangeattacktask2hm(inst)
    inst.rangeattacktask2hm = nil
    inst.nearattacktask2hm = inst:DoTaskInTime(math.random(8, 16), cancelrangeattacktask2hm)
end
local function beeweaponfn(self, ...)
    local inst = self.inst
    if inst.nearattacktask2hm then return end
    if not inst.rangeattacktask2hm then inst.rangeattacktask2hm = inst:DoTaskInTime(math.random(8, 16), cancelrangeattacktask2hm) end
    if inst.rangeattacktask2hm then
        if not (inst.beeweapon2hm and inst.beeweapon2hm:IsValid()) then
            local thrower = CreateEntity()
            thrower.persists = false
            thrower.entity:AddTransform()
            thrower:RemoveFromScene()
            thrower:AddComponent("inventoryitem")
            thrower.components.inventoryitem.owner = inst
            thrower:AddComponent("weapon")
            thrower.projectilespeed2hm = 10
            thrower.projectilecolor2hm = {0.4, 0, 0, 1}
            thrower.projectilesize2hm = 0.75
            thrower.projectilehitdist2hm = math.sqrt(5)
            thrower.projectilehoming2hm = false
            thrower.projectilephysics2hm = false
            thrower.projectilehasdamageset2hm = 0.1
            thrower.projectilemissremove2hm = true
            thrower.projectileneedstartpos2hm = true
            thrower.components.weapon:SetDamage(inst.components.combat.defaultdamage * 2 / 3)
            thrower.components.weapon:SetRange(TUNING.WALRUS_ATTACK_DIST, TUNING.WALRUS_ATTACK_DIST + 4)
            thrower.components.weapon:SetProjectile("blowdart_pipe")
            inst.beeweapon2hm = thrower
        end
        return inst.beeweapon2hm
    end
end
local function updatebeeweapon(inst) if inst.components.combat then inst.components.combat.GetWeapon = beeweaponfn end end
-- 富贵的杀人蜂兼容优化
local function onbeehitother(inst, data)
    local target = data and data.target
    if target ~= nil and target:IsValid() and target:HasTag("player") and not table.contains(TUNING.NDNR_NOT_BEEPOISONPLAYERS, target.prefab) and
        not target:HasTag("beehatprotect") and not target:HasTag("playerghost") and not (target.components.rider ~= nil and target.components.rider:IsRiding()) and
        target.components.debuffable and not target.components.debuffable:HasDebuff("ndnr_beepoisondebuff") then
        target.components.debuffable:AddDebuff("ndnr_beepoisondebuff", "ndnr_beepoisondebuff")
    end
end
local function delayupdatebeeweapon(inst)
    if not TheWorld.ismastersim then return end
    inst:DoTaskInTime(0, updatebeeweapon)
    if TUNING.NDNR_NOT_BEEPOISONPLAYERS then
        local PushEvent = inst.PushEvent
        inst.PushEvent = function(self, event, ...)
            if event == "onattackother" then return end
            PushEvent(self, event, ...)
        end
        inst:ListenForEvent("onhitother", onbeehitother)
        if inst.components.health then
            local Kill = inst.components.health.Kill
            inst.components.health.Kill = function(self, ...)
                if self.inst and self.inst:IsValid() and not self.inst:IsInLimbo() then return end
                Kill(self, ...)
            end
        end
    end
end
-- AddPrefabPostInit("bee", delayupdatebeeweapon)
AddPrefabPostInit("killerbee", delayupdatebeeweapon)
-- local function onspawnchild(inst, child) if child.prefab == "beeguard" and child.AddToArmy then child:AddToArmy(inst) end end
-- local function updatebeehive(inst)
--     if not inst.components.commander then inst:AddComponent("commander") end
--     if inst.components.childspawner then
--         inst.components.childspawner.emergencychildname = "beeguard"
--         inst.components.childspawner:SetSpawnedFn(onspawnchild)
--     end
-- end
-- AddPrefabPostInit("beehive", updatebeehive)
-- AddPrefabPostInit("wasphive", updatebeehive)

AddBrainPostInit("killerbeebrain", function(self)
    if self.bt.root.children then
        if self.bt.root.children[5] and self.bt.root.children[5].name == "go home" then
            if self.bt.root.children[5].getactionfn then
                local oldfn = self.bt.root.children[5].getactionfn
                self.bt.root.children[5].getactionfn = function(inst, ...)
                    return inst.components.combat and not inst.components.combat:HasTarget() and oldfn(inst, ...) 
                end
            end
        end
    end
end)