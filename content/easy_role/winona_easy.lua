local hardmode = TUNING.hardmode2hm and GetModConfigData("role_nerf")

-- 制作增强只改变制作动作；保留妥协独立配置的工作能力，并初始化其已有倍率。
require("winonabuilder2hm").Install(env, GetModConfigData("Winona No Hungry Builder"))

-- 薇诺娜锤建筑掉落全部材料
if GetModConfigData("Winona Hammer Drop All Loot") then
    local function delay(inst) inst.winonahammertask = nil end
    local function onworking(inst, data)
        if data and data.target and data.target:IsValid() and data.target.prefab and data.target.components.workable and data.target.components.workable.action ==
            ACTIONS.HAMMER and data.target.components.lootdropper and not data.target.components.spawner and AllRecipes[data.target.prefab] ~= nil and
            not data.target.winonahammertask then data.target.winonahammertask = data.target:DoTaskInTime(FRAMES, delay) end
    end
    AddPrefabPostInit("winona", function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("working", onworking)
    end)
    local old_HAMMER_LOOT_PERCENT, old_BURNT_HAMMER_LOOT_PERCENT
    AddComponentPostInit("lootdropper", function(self)
        local oldGetRecipeLoot = self.GetRecipeLoot
        self.GetRecipeLoot = function(self, ...)
            if self.inst.winonahammertask ~= nil then
                old_HAMMER_LOOT_PERCENT = TUNING.HAMMER_LOOT_PERCENT
                old_BURNT_HAMMER_LOOT_PERCENT = TUNING.BURNT_HAMMER_LOOT_PERCENT
                local component = self.inst.components.finiteuses or self.inst.components.fueled or self.inst.components.armor or
                                      self.inst.components.perishable
                if component and component.GetPercent then
                    TUNING.HAMMER_LOOT_PERCENT = 0.5 + math.min(component:GetPercent(), 1) / 2
                    TUNING.BURNT_HAMMER_LOOT_PERCENT = TUNING.HAMMER_LOOT_PERCENT / 2
                else
                    TUNING.HAMMER_LOOT_PERCENT = 1
                    TUNING.BURNT_HAMMER_LOOT_PERCENT = 0.5
                end
            end
            local loots = oldGetRecipeLoot(self, ...)
            if old_HAMMER_LOOT_PERCENT then
                TUNING.HAMMER_LOOT_PERCENT = old_HAMMER_LOOT_PERCENT
                TUNING.BURNT_HAMMER_LOOT_PERCENT = old_BURNT_HAMMER_LOOT_PERCENT
                old_HAMMER_LOOT_PERCENT = nil
                old_BURNT_HAMMER_LOOT_PERCENT = nil
            end
            return loots
        end
    end)
    AddPrefabPostInit("potatosack", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.lootdropper then
            local oldSLP = inst.components.lootdropper.SpawnLootPrefab
            inst.components.lootdropper.SpawnLootPrefab = function(self,lootprefab, pt, linked_skinname, skin_id, userid, ...)
                if lootprefab == "cutgrass" or lootprefab == "rocks" then return end
                oldSLP(self,lootprefab, pt, linked_skinname, skin_id, userid, ...)
            end
        end
    end)
end

-- 薇诺娜控制发条随从停下
if GetModConfigData("Winona Control Chess") then
    STRINGS.ACTIONS.ACTION2HM.STOP = TUNING.isCh2hm and "看守此处" or "Stay Here"
    local function canstop(inst, doer, actions, right)
        return
            doer and doer.prefab == "winona" and not inst:HasTag("swc2hm") and inst.replica and inst.replica.follower and inst.replica.follower:GetLeader() ==
                doer
    end
    local function actionfn(inst, doer, target, pos, act)
        target = target or inst
        if doer and doer.prefab == "winona" and target and target:HasTag("chess") and target.components.follower and target.components.follower:GetLeader() ==
            doer and target.components.knownlocations and target.components.health and not target.components.health:IsDead() then
            target.components.knownlocations:RememberLocation("home", doer:GetPosition(), false)
            if target.components.sleeper then target.components.sleeper:GoToSleep(480) end
            if target.components.combat and not target.components.combat.target and target:HasTag("swp2hm") and target.components.childspawner2hm and
                target.components.childspawner2hm.numchildrenoutside > 0 and target.components.playerprox2hm and target.components.playerprox2hm.isclose then
                target.components.playerprox2hm.isclose = false
                target:PushEvent("onfar2hm")
                if target.components.playerprox2hm.onfar ~= nil then target.components.playerprox2hm.onfar(target) end
            end
            target.components.follower:StopFollowing()
            doer.SoundEmitter:PlaySound("dontstarve/common/staff_dissassemble")
            return true
        end
    end
    local chessmonsters = {"knight", "knight_nightmare", "bishop", "bishop_nightmare", "rook", "rook_nightmare"}
    for _, monster in ipairs(chessmonsters) do
        AddPrefabPostInit(monster, function(inst)
            inst.actionstate2hm = "doshortaction"
            inst.action2hmdistance = 20
            inst.straightactioncondition2hm = canstop
            inst.actiontext2hm = "STOP"
            if not TheWorld.ismastersim then return end
            inst:AddComponent("action2hm")
            inst.components.action2hm.actionfn = actionfn
        end)
    end
end

-- 薇诺娜连击时旋转武器附魔
if GetModConfigData("Winona Rotating Weapon Perpetual Attack") then AddPrefabPostInit("winona", AddRotateAbility) end

-- 薇诺娜右键自身折叠建设
if GetModConfigData("Winona Right Self Hide Structures") then
    local function delaytask(inst) inst:RemoveTag("NOBLOCK") end
    AddRightSelfAction("winona", GetModConfigData("Winona Right Self Hide Structures"), "dolongaction", nil, function(act)
        if act.doer and act.doer.prefab == "winona" and act.doer.components.sanity then
            act.doer.SoundEmitter:PlaySound("dontstarve/common/staffteleport")
            local x, y, z = act.doer.Transform:GetWorldPosition()
            local ents = TheSim:FindEntities(x, y, z, 8, nil, {"NOBLOCK", "player", "FX", "INLIMBO", "DECOR", "walkableplatform", "walkableperipheral"})
            local sanityvalue = 1
            for index, ent in ipairs(ents) do
                if ent and ent:IsValid() then
                    ent:AddTag("NOBLOCK")
                    ent:DoTaskInTime(13.5, delaytask)
                    sanityvalue = sanityvalue + 0.1
                    if not ent.components.locomotor and
                        (not ent.components.health or (ent.components.workable and ent.components.workable:GetWorkAction() ~= nil)) and ent.AnimState then
                        sanityvalue = sanityvalue + 0.15
                        local r, g, b, alpha = ent.AnimState:GetMultColour()
                        local i = 1
                        ent:AddTag("NOBLOCK")
                        local noclick = ent:HasTag("NOCLICK")
                        if not noclick then ent:AddTag("NOCLICK") end
                        ent.winonahidetask2hm = ent:DoPeriodicTask(0.1, function(inst)
                            if i == 135 then
                                inst.AnimState:SetMultColour(r, g, b, alpha)
                                inst.winonahidetask2hm:Cancel()
                                inst.winonahidetask2hm = nil
                                if not noclick then ent:RemoveTag("NOCLICK") end
                            elseif i <= 8 then
                                inst.AnimState:SetMultColour(r, g, b, math.max(0.2, alpha - 0.1 * i))
                            elseif i >= 127 then
                                inst.AnimState:SetMultColour(r, g, b, math.min(alpha, (i - 125) * 0.1))
                            end
                            i = i + 1
                        end)
                    end
                end
            end
            act.doer.components.sanity:DoDelta(-sanityvalue)
        end
        return true
    end, TUNING.isCh2hm and "折叠空间" or "Hide Them")
end
