-- 给射线型弹药的武器添加属性
-- weapon.projectilespeed2hm
-- weapon.projectilehoming2hm 该远程武器可以追踪
-- weapon.projectilephysics2hm
-- weapon.projectilesize2hm
-- weapon.projectilehasdamageset2hm 用远程武器发射使用自带的武器组件计算伤害的弹药
AddComponentPostInit("projectile", function(self)
    local oldThrow = self.Throw
    self.Throw = function(self, weapon, target, attacker, ...)
        -- 散射支持
        if attacker and attacker.aoethrow2hm and attacker.aoethrow2hm > 1 and target then
            local oldRotateToTarget = self.RotateToTarget
            self.RotateToTarget = function(self, dest, ...)
                if self and target and attacker and attacker.aoethrow2hm and self.start and self.range then
                    attacker.aoethrow2hmindex = attacker.aoethrow2hmindex + 1
                    attacker.aoethrow2hmangle = attacker.aoethrow2hmangle or 22.5
                    if attacker.aoethrow2hmindex >= attacker.aoethrow2hm + 1 then attacker.aoethrow2hmindex = 1 end
                    if attacker.aoethrow2hmindex == 1 then
                        oldRotateToTarget(self, dest, ...)
                        self.RotateToTarget = oldRotateToTarget
                        return
                    end
                    local pos = self.inst:GetPosition()
                    local angle = self.inst:GetAngleToPoint(target:GetPosition())
                    local remainder = attacker.aoethrow2hmindex % 2
                    local isright = remainder ~= 0 and 1 or -1
                    local anglerate = (attacker.aoethrow2hmindex - remainder) / 2
                    angle = angle + attacker.aoethrow2hmangle * isright * anglerate
                    self.dest = Vector3(pos.x + math.cos(angle * DEGREES) * 10, pos.y, pos.z - math.sin(angle * DEGREES) * 10)
                    oldRotateToTarget(self, self.dest, ...)
                    self.RotateToTarget = oldRotateToTarget
                end
            end
        end
        -- 弹药移速碰撞锁定更改,weapon为武器,self.inst为弹药
        if weapon then
            if weapon.projectilecolor2hm and self.inst.AnimState then
                self.inst.AnimState:SetMultColour(weapon.projectilecolor2hm[1], weapon.projectilecolor2hm[2], weapon.projectilecolor2hm[3],
                                                  weapon.projectilecolor2hm[4])
            end
            if weapon.projectilesize2hm and self.inst.AnimState then
                self.inst.AnimState:SetScale(weapon.projectilesize2hm, weapon.projectilesize2hm, weapon.projectilesize2hm)
            end
            if weapon.projectilespeed2hm then
                self.speed = weapon.projectilespeed2hm
                self.range = self.range or self.speed * 2.5
            end
            if weapon.projectilehitdist2hm then self.hitdist = weapon.projectilehitdist2hm end
            if weapon.projectilehoming2hm ~= nil then self.homing = weapon.projectilehoming2hm end
            if weapon.projectilemissremove2hm then
                self.inst.persists = false
                self:SetOnMissFn(self.inst.Remove)
                self.inst:ListenForEvent("entitysleep", delayremove2hm)
            end
            if weapon.projectilephysics2hm == false and self.inst.Physics then
                self.inst.entity:SetCanSleep(false)
                RemovePhysicsColliders(self.inst)
            end
            if weapon.projectileneedstartpos2hm and attacker then self.overridestartpos = attacker:GetPosition() end
        end
        return oldThrow(self, weapon, target, attacker, ...)
    end
    -- 弹药存在弹药伤害时,更改伤害由原武器伤害加该弹药伤害,self.owner为武器,inst为弹药
    local oldHit = self.Hit
    self.Hit = function(self, target, ...)
        if self.has_damage_set and self.owner and self.owner.projectilehasdamageset2hm and self.inst.components.weapon and self.owner.components.weapon then
            self.inst.components.weapon:SetDamage((self.inst.components.weapon.damage or 0) * (self.owner.projectilehasdamageset2hm or 1) +
                                                      (self.owner.components.weapon.damage or 0))
        end
        return oldHit(self, target, ...)
    end
    -- 攻击玩家的弹药会被其他玩家阻挡,从而实现散射
    local OnUpdate = self.OnUpdate
    self.OnUpdate = function(self, ...)
        if not self.homing and self.target and self.target:IsValid() and self.target:HasTag("player") and not self.inst.prefab == "wortox_soul_spawn" then
            self.target = FindClosestPlayerToInst(self.inst, 100, true) or self.target
        end
        OnUpdate(self, ...)
    end
end)

-- 给攻击者添加散射和连射
-- attacker.aoethrow2hm 1
-- attacker.aoethrow2hmangle 22.5
-- attacker.multithrow2hm 1
-- attacker.multithrow2hmdelay 0.1
local function multithrow(inst, LaunchProjectile, self, attacker, target, ...)
    if self and inst and inst.multithrow2hmtask and attacker and attacker.multithrow2hm then
        if inst.multithrow2hmnum >= attacker.multithrow2hm then
            inst.multithrow2hmnum = 0
            inst.multithrow2hmtask:Cancel()
            inst.multithrow2hmtask = nil
        else
            inst.multithrow2hmnum = inst.multithrow2hmnum + 1
            attacker.aoethrow2hmindex = 0
            if attacker:IsValid() and target:IsValid() then
                if self.projectiletmp2hm then self.projectile = self.projectiletmp2hm end
                LaunchProjectile(self, attacker, target, ...)
                if self.projectiletmp2hm then self.projectile = nil end
            end
        end
    end
end
AddComponentPostInit("weapon", function(self)
    local LaunchProjectile = self.LaunchProjectile
    self.LaunchProjectile = function(self, attacker, target, ...)
        if attacker and attacker.aoethrow2hm and attacker.aoethrow2hm > 1 and target then
            attacker.aoethrow2hmindex = 0
            if self.projectiletmp2hm then self.projectile = self.projectiletmp2hm end
            for index = 1, attacker.aoethrow2hm do LaunchProjectile(self, attacker, target, ...) end
            if self.projectiletmp2hm then self.projectile = nil end
            return
        end
        if attacker and attacker.multithrow2hm and attacker.multithrow2hm > 1 and target then
            if self.inst.multithrow2hmtask then self.inst.multithrow2hmtask:Cancel() end
            self.inst.multithrow2hmnum = 0
            self.inst.multithrow2hmtask = self.inst:DoPeriodicTask(attacker.multithrow2hmdelay or 0.1, multithrow, 0, LaunchProjectile, self, attacker, target,
                                                                   ...)
            return
        end
        if self.projectiletmp2hm then self.projectile = self.projectiletmp2hm end
        LaunchProjectile(self, attacker, target, ...)
        if self.projectiletmp2hm then self.projectile = nil end
    end
end)

-- 投掷类弹药的弹射,bouncethrow2hm为1代表不弹射,为2代表弹射一次
-- attacker.bouncethrow2hm 1
AddComponentPostInit("complexprojectile", function(self)
    local Launch = self.Launch
    self.Launch = function(self, targetPos, attacker, ...)
        if attacker and attacker.bouncethrow2hm and (self.inst.bounceindex2hm or 0) < attacker.bouncethrow2hm - 1 then
            local startpos = self.inst:GetPosition()
            if targetPos and startpos then self.inst.bouncedate2hm = {targetpos = targetPos + targetPos - startpos, args = {...}} end
        end
        return Launch(self, targetPos, attacker, ...)
    end
    local Hit = self.Hit
    self.Hit = function(self, ...)
        if self.attacker and self.inst.bouncedate2hm and (self.inst.bounceindex2hm or 0) < self.attacker.bouncethrow2hm - 1 then
            local newproj = self.attacker.bouncethrow2hmfn and self.attacker.bouncethrow2hmfn(self, self.inst) or SpawnPrefab(self.inst.prefab)
            if newproj then
                newproj.Transform:SetPosition(self.inst.Transform:GetWorldPosition())
                newproj.bounceindex2hm = (self.inst.bounceindex2hm or 0) + 1
                newproj.components.complexprojectile:Launch(self.inst.bouncedate2hm.targetpos, self.attacker, unpack(self.inst.bouncedate2hm.args))
            end
        end
        return Hit(self, ...)
    end
end)
