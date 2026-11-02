local SpawnFader = Class(function(self, inst)
    self.inst = inst
    self.fadeval = 0
    self.updating = false
    -- self.speed = 2
    -- self.rgb = 0
    -- self.alpha = 0.5
end)

function SpawnFader:FadeIn()
    self.fadeval = 1
    if not self.updating then
        self.updating = true
        self.inst:StartUpdatingComponent(self)
        self.inst:AddTag("NOCLICK")
        self:OnUpdate(FRAMES)
    end
end

function SpawnFader:Cancel()
    if self.updating then
        self.fadeval = 0
        self:OnUpdate(FRAMES)
    end
end

function SpawnFader:OnUpdate(dt)
    self.fadeval = math.max(0, self.fadeval - dt * (self.speed or 2))
    local k = 1 - self.fadeval * self.fadeval
    local rgb = self.rgb or 0
    self.inst.AnimState:SetMultColour(rgb, rgb, rgb, k * (self.alpha or 0.5))
    if self.hasscale then self.inst.AnimState:SetScale(k, k * (self.scaley or 1), k) end
    if self.fadeval <= 0 then
        self.updating = false
        self.inst:StopUpdatingComponent(self)
        self.inst:RemoveTag("NOCLICK")
        if self.fn then self.fn(self.inst) end
    end
end

return SpawnFader
