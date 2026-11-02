-- 易伤险境: 玩家被Boss攻击后短时间内获得易伤(承伤增加), 持续衰减
-- 每次受击+20%承伤(最多+100%), 每秒消除10%, 回落到0%时自动清除
-- 仅Boss(epic标签)真实攻击触发, 小怪/饥饿/火烧/debuff不叠加
-- 开启时玩家常驻20%减伤, 与易伤叠层乘算
local VULN_STACK_PER_HIT = 0.2
local VULN_DECAY_PER_SEC = 0.1
local VULN_MAX = 2.0
local VULN_KEY = "standfight_vuln2hm"
local FLAT_REDUCTION = 0.8 -- 常驻20%减伤
local FLAT_KEY = "standfight_flat2hm"

local function SetFlatReduction(inst)
    if inst.components.combat then
        inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, FLAT_REDUCTION, FLAT_KEY)
    end
end

local function ClearVulnerable(inst)
    if inst.components.combat then
        inst.components.combat.externaldamagetakenmultipliers:RemoveModifier(inst, VULN_KEY)
    end
    inst._standfight_vuln_mult = nil
    if inst._standfight_vuln_task then
        inst._standfight_vuln_task:Cancel()
        inst._standfight_vuln_task = nil
    end
end

local function StartDecay(inst)
    if inst._standfight_vuln_task then return end
    inst._standfight_vuln_task = inst:DoPeriodicTask(1, function()
        if not inst:IsValid() then return end
        inst._standfight_vuln_mult = inst._standfight_vuln_mult - VULN_DECAY_PER_SEC
        if inst._standfight_vuln_mult <= 1.0 then
            ClearVulnerable(inst)
        elseif inst.components.combat then
            inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, inst._standfight_vuln_mult, VULN_KEY)
        end
    end)
end

local function OnAttacked(inst, data)
    -- 仅Boss攻击(epic标签)才触发叠易伤, 小怪不叠
    if not data or not data.attacker then return end
    if not data.attacker.components or not data.attacker.components.combat then return end
    if not data.attacker:HasTag("epic") then return end

    inst._standfight_vuln_mult = math.min((inst._standfight_vuln_mult or 1.0) + VULN_STACK_PER_HIT, VULN_MAX)
    if inst.components.combat then
        inst.components.combat.externaldamagetakenmultipliers:SetModifier(inst, inst._standfight_vuln_mult, VULN_KEY)
    end
    StartDecay(inst)
end

local function OnRespawn(inst)
    ClearVulnerable(inst)
    SetFlatReduction(inst) -- 复活后重新挂上减伤
end

AddPlayerPostInit(function(inst)
    if not TheWorld.ismastersim then return end
    SetFlatReduction(inst)
    inst:ListenForEvent("attacked", OnAttacked)
    inst:ListenForEvent("respawn", OnRespawn)
end)
