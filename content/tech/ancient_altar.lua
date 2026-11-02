TUNING.ANCIENT_ALTAR_COMPLETE_WORK = 4
local shadowchesspieces = {"shadow_knight", "shadow_bishop", "shadow_rook"}

local function processrecipe(inst, recipe, worker)
    if inst:IsValid() and recipe then
        worker = worker or inst
        if recipe.name == "greenamulet" or recipe.name == "greenstaff" then
            SpawnPrefab("sporecloud").Transform:SetPosition(worker.Transform:GetWorldPosition())
        elseif recipe.name == "yellowamulet" or recipe.name == "yellowstaff" then
            if TheWorld.has_ocean then
                SpawnPrefab("sporecloud").Transform:SetPosition(worker.Transform:GetWorldPosition())
            else
                CreateMiasma2hm(inst, true)
            end
        elseif recipe.name == "orangeamulet" or recipe.name == "orangestaff" then
            local sinkhole = SpawnPrefab("antlion_sinkhole")
            sinkhole.Transform:SetPosition(inst.Transform:GetWorldPosition())
            sinkhole:PushEvent("startcollapse")
        elseif recipe.name == "telestaff" or recipe.name == "purpleamulet" then
            if math.random() < 0.5 then StalkerSpawnSnares2hm(inst, {worker}) end
            SpawnSpell2hm(inst, math.random() <= 0.5 and "deer_fire_circle" or "deer_ice_circle", 6, worker)
        elseif recipe.name == "icestaff" or recipe.name == "blueamulet" then
            SpawnSpell2hm(inst, "deer_ice_circle", 6, worker)
        elseif recipe.name == "firestaff" or recipe.name == "amulet" then
            SpawnSpell2hm(inst, "deer_fire_circle", 6, worker)
        elseif recipe.nounlock then
            SpawnMonster2hm(worker, "nightmarebeak")
            SpawnMonster2hm(worker, math.random() < 0.5 and "knight_nightmare" or "bishop_nightmare", 4)
        else
            SpawnMonster2hm(worker, "nightmarebeak")
        end
    end
end

AddPrefabPostInit("ancient_altar", function(inst)
    if TheWorld.ismastersim then
        inst.fx = SpawnPrefab("tophat_shadow_fx")
        inst.fx.entity:SetParent(inst.entity)
        inst.fx.Transform:SetScale(2, 3, 2)
    end
    if not TheWorld.ismastersim or not inst.components.prototyper or not inst.components.workable then return inst end
    local trees = inst.components.prototyper.trees
    local _trees = {}
    if trees and type(trees) == "table" then
        for i, v in pairs(trees) do
            _trees[i] = v
        end
        _trees.SCIENCE = 3
        _trees.MAGIC = 3
        inst.components.prototyper.trees = _trees
    end
    local oldonactivate = inst.components.prototyper.onactivate
    inst.components.prototyper.onactivate = function(inst, doer, recipe, ...)
        oldonactivate(inst, doer, recipe, ...)
        if inst.components.workable and doer.components.sanity and doer.components.sanity:GetPercent() < 0.95 and math.random() <
            (1 - doer.components.sanity:GetPercent() * 3 / 4) then
            inst.components.workable:WorkedBy(doer, 1)
            processrecipe(inst, recipe, doer)
        end
    end
    local oldonwork = inst.components.workable.onwork
    inst.components.workable:SetOnWorkCallback(function(inst, worker, ...)
        if oldonwork then oldonwork(inst, worker, ...) end
        DoRandomRuinMagic2hm(inst, worker)
    end)
    local oldonfinish = inst.components.workable.onfinish
    inst.components.workable:SetOnFinishCallback(function(inst, worker, ...)
        oldonfinish(inst, worker, ...)
        SpawnMonster2hm(worker, shadowchesspieces[math.random(3)])
        SpawnMonster2hm(worker, shadowchesspieces[math.random(3)])
        SpawnMonster2hm(worker, "oceanhorror2hm")
    end)
end)

AddPrefabPostInit("ancient_altar_broken", function(inst)
    if TheWorld.ismastersim then
        inst.fx = SpawnPrefab("tophat_shadow_fx")
        inst.fx.entity:SetParent(inst.entity)
        inst.fx.Transform:SetScale(2, 3, 2)
    end
    if not TheWorld.ismastersim or not inst.components.prototyper or not inst.components.workable then return inst end
    local trees = inst.components.prototyper.trees
    local _trees = {}
    if trees and type(trees) == "table" then
        for i, v in pairs(trees) do
            _trees[i] = v
        end
        _trees.SCIENCE = 2
        _trees.MAGIC = 2
        inst.components.prototyper.trees = _trees
    end
    local oldonactivate = inst.components.prototyper.onactivate
    inst.components.prototyper.onactivate = function(inst, doer, recipe, ...)
        oldonactivate(inst, doer, recipe, ...)
        if inst.components.workable and doer.components.sanity and math.random() < (1 - doer.components.sanity:GetPercent() * 2 / 3) then
            inst.components.workable:WorkedBy(doer, 1)
            processrecipe(inst, recipe, doer)
        end
    end
    local oldonfinish = inst.components.workable.onfinish
    inst.components.workable:SetOnFinishCallback(function(inst, worker, ...)
        oldonfinish(inst, worker, ...)
        SpawnMonster2hm(worker, shadowchesspieces[math.random(3)])
    end)
end)

if GetModConfigData("ancient_altar") ~= -1 then
    local oldshort = math.min(TUNING.NIGHTMARE_SEGS.CALM, TUNING.NIGHTMARE_SEGS.WILD)
    local oldlong = math.max(TUNING.NIGHTMARE_SEGS.CALM, TUNING.NIGHTMARE_SEGS.WILD)
    TUNING.NIGHTMARE_SEGS.CALM = oldshort
    TUNING.NIGHTMARE_SEGS.WILD = oldlong
end

local moonprototypers = {
    "moon_altar",
    "moon_altar_cosmic",
    "moon_altar_astral",
    "alterguardian_phase1",
    "alterguardian_phase2",
    "alterguardian_phase3",
    "moonrockseed"
}
AddComponentPostInit("prototyper", function(self)
    local Activate = self.Activate
    self.Activate = function(self, doer, recipe, ...)
        if table.contains(moonprototypers, self.inst.prefab) and not self.inst._upgraded and doer and doer.components.sanity and
            doer.components.sanity:GetPercent() > 0.05 then
            if math.random() < doer.components.sanity:GetPercent() * 3 / 4 then
                local cloud = SpawnPrefab("sleepcloud_lunar")
                if cloud then
                    cloud.Transform:SetPosition(self.inst.Transform:GetWorldPosition())
                    if self.lastcloud2hm and self.lastcloud2hm:IsValid() and self.lastcloud2hm:IsNear(cloud, 1) then
                        self.lastcloud2hm:Remove()
                    end
                    self.lastcloud2hm = cloud
                    self.inst:ListenForEvent("onremove", function() if self.lastcloud2hm == cloud then self.lastcloud2hm = nil end end, cloud)
                    cloud:SetOwner(self.inst)
                    if cloud._drowsytask and cloud._drowsytask.fn then
                        local fn = cloud._drowsytask.fn
                        cloud._drowsytask.fn = function(...)
                            local oldGetPVPEnabled = getmetatable(TheNet).__index["GetPVPEnabled"]
                            getmetatable(TheNet).__index["GetPVPEnabled"] = truefn
                            fn(...)
                            getmetatable(TheNet).__index["GetPVPEnabled"] = oldGetPVPEnabled
                        end
                    end
                end
                -- elseif math.random() < doer.components.sanity:GetPercent() then
                --     local monster = SpawnPrefab("gestalt")
                --     if monster then
                --         monster.Transform:SetPosition(self.inst.Transform:GetWorldPosition())
                --         monster.components.combat:SetTarget(doer)
                --         monster.components.combat:TryAttack()
                --     end
            end
        end
        return Activate(self, doer, recipe, ...)
    end
end)
