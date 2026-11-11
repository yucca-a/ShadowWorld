local statueruins = {"ruins_statue_head", "ruins_statue_head_nogem", "ruins_statue_mage", "ruins_statue_mage_nogem"}

-- 强化镐斧(远古多用镐斧)挖雕像不出怪
local function isancientenhancedaxe(inst, worker)
    if not worker or not worker.components.inventory then return false end
    local act = worker:GetBufferedAction()
    local item
    if act then
        if act.target ~= inst or act.action ~= ACTIONS.MINE then return false end
        item = act.invobject
    else
        item = worker.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    end
    return item and item:IsValid() and item.prefab == "multitool_axe_pickaxe" and item:HasTag("ancient_enhanced2hm")
end

local function magicGemPlayer(inst, worker)
    if not inst.gemmed then return end
    if worker and worker:IsValid() and not worker:HasTag("player") then
        if worker.components.combat then
            worker.components.combat:GetAttacked_Internal(inst, math.random(3, 8))
        elseif worker.components.health then
            worker.components.health:DoDelta(-math.random(3, 8), false, inst.prefab)
        end
        return
    end
    worker = worker or inst
    if inst.gemmed == "redgem" then
        SpawnSpell2hm(inst, "deer_fire_circle", 6, worker)
    elseif inst.gemmed == "bluegem" then
        SpawnSpell2hm(inst, "deer_ice_circle", 6, worker)
    elseif inst.gemmed == "orangegem" then
        local sinkhole = SpawnPrefab("antlion_sinkhole")
        sinkhole.Transform:SetPosition(worker.Transform:GetWorldPosition())
        sinkhole:PushEvent("startcollapse")
    elseif inst.gemmed == "purplegem" then
        if math.random() < 0.5 then StalkerSpawnSnares2hm(inst, {worker}) end
        SpawnSpell2hm(inst, math.random() <= 0.5 and "deer_fire_circle" or "deer_ice_circle", 6, worker)
    elseif inst.gemmed == "yellowgem" then
        if TheWorld.has_ocean then
            SpawnPrefab("sporecloud").Transform:SetPosition(worker.Transform:GetWorldPosition())
        else
            CreateMiasma2hm(inst, true)
        end
    elseif inst.gemmed == "greengem" then
        SpawnPrefab("sporecloud").Transform:SetPosition(worker.Transform:GetWorldPosition())
    end
end

for _, statue in ipairs(statueruins) do
    AddPrefabPostInit(statue, function(inst)
        if not TheWorld.ismastersim or not inst.components.workable then return end
        if not inst.components.timer then inst:AddComponent("timer") end
        local oldonwork = inst.components.workable.onwork
        inst.components.workable:SetOnWorkCallback(function(inst, worker, ...)
            local enhanced = isancientenhancedaxe(inst, worker)
            oldonwork(inst, worker, ...)
            if worker and worker:HasTag("player") and not enhanced and math.random() < 0.11 then DoRandomRuinMagic2hm(inst, worker) end
            if worker and worker:HasTag("player") and not enhanced and math.random() < 0.11 then
                SpawnMonster2hm(worker, math.random() < 0.75 and "crawlingnightmare" or "oceanhorror2hm")
            end
            if math.random() < 0.11 then magicGemPlayer(inst, worker) end
            if not inst.components.timer:TimerExists("mod_hardmode_timechange") then
                inst.components.timer:StartTimer("mod_hardmode_timechange", 4800)
            end
            if inst.components.workable.workleft <= 0 and not inst.components.workable.tough or worker.prefab == "winona_catapult_projectile" and worker:HasTag("toughworker") then
                inst.components.workable:SetWorkLeft(1)
                inst.components.workable:SetRequiresToughWork(true)
            end
        end)
        local oldonfinish = inst.components.workable.onfinish
        inst.components.workable:SetOnFinishCallback(function(inst, worker, ...)
            local enhanced = isancientenhancedaxe(inst, worker)
            oldonfinish(inst, worker, ...)
            if worker and worker:HasTag("player") and not enhanced and math.random() < 0.51 then DoRandomRuinMagic2hm(inst, worker) end
            if worker and worker:HasTag("player") and not enhanced then SpawnMonster2hm(worker, math.random() < 0.6 and "nightmarebeak" or "ruinsnightmare") end
            magicGemPlayer(inst, worker)
        end)
        inst:ListenForEvent("timerdone", function(inst, data)
            if data and data.name == "mod_hardmode_timechange" then
                inst.components.workable:SetWorkLeft(TUNING.MARBLEPILLAR_MINE)
                oldonwork(inst, inst, inst.components.workable.workleft)
                inst.components.workable:SetRequiresToughWork(false)
            end
        end)
    end)
end

AddPrefabPostInit("archive_moon_statue", function(inst)
    if not TheWorld.ismastersim or not inst.components.workable then return inst end
    inst.components.workable:SetRequiresToughWork(true)
end)
