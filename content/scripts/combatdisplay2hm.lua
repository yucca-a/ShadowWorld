-- Reporting is observational: never re-run an attack/weapon/modifier callback.
return function(inst, damage, special, report)
    if not inst.components.combat.inspectstatus2hm or inst.inspectstatustaskcd2hm or not inst.components.talker then return end
    inst.inspectstatustaskcd2hm = inst:DoTaskInTime(3, function() inst.inspectstatustaskcd2hm = nil end)
    local lines = {TUNING.isCh2hm and "[战斗险境]攻击端伤害（目标防御前）" or "[Combat] outgoing damage (before target defenses)"}
    lines[#lines + 1] = string.format(TUNING.isCh2hm and "普通：%.2f" or "Regular: %.2f", damage or 0)
    for kind, amount in pairs(special or {}) do
        lines[#lines + 1] = string.format("%s: %.2f", kind == "planar" and TUNING.isCh2hm and "位面" or kind, amount)
    end
    if report ~= nil then
        lines[#lines + 1] = string.format(TUNING.isCh2hm and "渐进阈值：普通 %.1f / 特殊 %.1f；增长空间 0.5"
            or "Soft thresholds: regular %.1f / special %.1f; width 0.5", report.threshold, report.specialthreshold)
        if report.opaque then
            lines[#lines + 1] = TUNING.isCh2hm and "含兼容来源：内部倍率未拆分" or "Includes compatibility sources with opaque internal multipliers"
        end
    end
    local message = table.concat(lines, "\n")
    inst:DoTaskInTime(0.1, function()
        if inst:IsValid() and inst.components.talker then inst.components.talker:Say(message, 8, true, true) end
    end)
end
