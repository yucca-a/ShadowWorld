local M = {beefaloprotection = false}

-- This is the same protection used when a bell-bound beefalo receives damage.
-- Shadow beefalo inherit the original beefalo's bell binding.
function M.IsBellBoundBeefalo(target)
    return target.prefab == "beefalo" and
        (target.components.follower:GetLeader() ~= nil or
            (target:HasTag("swc2hm") and target.swp2hm and target.swp2hm.components.follower:GetLeader() ~= nil))
end

function M.IsProtectedWeaponHit(attacker, target)
    return M.beefaloprotection and attacker:HasTag("player") and M.IsBellBoundBeefalo(target)
end

function M.CanLifeSteal(attacker, target)
    return IsLifeDrainable(target) and not M.IsProtectedWeaponHit(attacker, target)
end

return M
