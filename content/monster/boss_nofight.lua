-- 借鉴自mo酱的boss无仇恨
local UpvalueHacker = require("upvaluehacker2hm")

-- combat组件:双方都是epic时禁止互为目标/攻击/承伤
local function CombatPostInit(self)
    local old_CanTarget = self.CanTarget
    self.CanTarget = function(self, target, ...)
        if target and target:HasTag("epic") and self.inst:HasTag("epic") then
            return false
        end
        return old_CanTarget(self, target, ...)
    end

    local old_CanAttack = self.CanAttack
    self.CanAttack = function(self, target, ...)
        if target and target:HasTag("epic") and self.inst:HasTag("epic") then
            return false
        end
        return old_CanAttack(self, target, ...)
    end

    local old_DoAttack = self.DoAttack
    self.DoAttack = function(self, targ, ...)
        if targ and targ:HasTag("epic") and self.inst:HasTag("epic") then
            return false
        end
        return old_DoAttack(self, targ, ...)
    end

    local oldGetAttacked_Internal = self.GetAttacked_Internal
    self.GetAttacked_Internal = function(self, attacker, ...)
        if attacker and attacker:HasTag("epic") and self.inst:HasTag("epic") then
            return false
        end
        return oldGetAttacked_Internal(self, attacker, ...)
    end
end

AddComponentPostInit("combat", CombatPostInit)

-- 恐怖之眼选目标时排除Boss
AddSimPostInit(function(inst)
    local RETARGET_CANT_TAGS = UpvalueHacker.GetUpvalue(GLOBAL.Prefabs["eyeofterror"].fn, "common_fn", "RetargetFn", "update_targets", "RETARGET_CANT_TAGS")
    if not RETARGET_CANT_TAGS then
        print("can't find eyeofterror RETARGET_CANT_TAGS")
        return
    end
    table.insert(RETARGET_CANT_TAGS, "epic")
end)

-- 大触手不打BOSS
AddPrefabPostInit("bigshadowtentacle", function(inst)
    if not TheWorld.ismastersim then return end
    inst:AddTag("epic")
end)
