-- 死亡险境: Boss附近有玩家死亡时恢复生命值
local PLAYER_DEATH_HEAL_2HM = 1000
local DETECT_RADIUS = 60
local BOSS_CANT_TAGS = {"player", "playerghost", "structure", "wall", "INLIMBO", "FX", "NOCLICK", "burnt"}

local function IsBoss(inst)
    return inst:HasTag("epic") or inst:HasTag("shadowchesspiece") or inst:HasTag("crabking")
end

local function OnEntityDeath(inst, data)
    local dead = data and data.inst
    if not dead or not dead:IsValid() or not dead.Transform then return end
    if not dead:HasTag("player") then return end 

    local amount = PLAYER_DEATH_HEAL_2HM
    local x, y, z = dead.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, DETECT_RADIUS, nil, BOSS_CANT_TAGS)
    for _, boss in ipairs(ents) do
        if IsBoss(boss) and boss.components.health and not boss.components.health:IsDead() then
            boss.components.health:DoDelta(amount)
        end
    end
end

AddSimPostInit(function()
    if not TheWorld.ismastersim then return end
    TheWorld:ListenForEvent("entity_death", OnEntityDeath)
end)
