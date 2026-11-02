local hardmode = TUNING.hardmode2hm and GetModConfigData("role_nerf")

-- 伍迪强胃
if GetModConfigData("Woodie Strong Stomach Monster Meat") then
    AddPrefabPostInit("woodie", function(inst)
        inst:AddTag("cursemaster")
        if not TheWorld.ismastersim then return end
        if inst.components.eater ~= nil then
            inst.components.eater:SetStrongStomach(true)
            inst.components.eater:SetCanEatRawMeat(true)
        end
    end)
end

-- 俗气雕像配方材料减少
if GetModConfigData("Kitschy Idol Need Less Materials") and false then
    AddRecipePostInit("wereitem_goose", function(inst) inst.ingredients = {Ingredient("monstermeat", 1), Ingredient("seeds", 1)} end)
    AddRecipePostInit("wereitem_beaver", function(inst) inst.ingredients = {Ingredient("monstermeat", 1), Ingredient("log", 1)} end)
    AddRecipePostInit("wereitem_moose", function(inst) inst.ingredients = {Ingredient("monstermeat", 1), Ingredient("cutgrass", 1)} end)
end

-- 伍迪月圆不变身获得随机俗气雕像
if GetModConfigData("Woodie Full Moon Not Become") then
    local function OnIsFullmoon(inst, isfullmoon)
        if isfullmoon and inst.components.inventory and not inst:HasTag("wereplayer") and not inst:HasTag("playerghost") then
            local wereitem = SpawnPrefab(({"wereitem_goose", "wereitem_beaver", "wereitem_moose"})[math.random(1, 3)])
            inst.components.inventory:GiveItem(wereitem)
            inst.SoundEmitter:PlaySound(({
                wereitem_goose = "dontstarve/characters/woodie/goose/death",
                wereitem_beaver = "dontstarve/characters/woodie/beaver_chop_tree",
                wereitem_moose = "dontstarve/characters/woodie/moose/death"
            })[wereitem.prefab])
        end
    end
    AddPrefabPostInit("woodie", function(inst)
        inst:AddTag("player_lunar_aligned")
        if not TheWorld.ismastersim then return end
        inst:WatchWorldState("isfullmoon", OnIsFullmoon)
    end)
    AddPrefabPostInit("woodcarvedhat", function(inst)
        inst:AddTag("waterproofer")
        if not TheWorld.ismastersim then return end
        if not inst.components.waterproofer then
            inst:AddComponent("waterproofer")
            inst.components.waterproofer:SetEffectiveness(TUNING.WATERPROOFNESS_SMALL)
        end
    end)
end

-- 伍迪变身使用饥饿值
if GetModConfigData("Woodie Hunger Wereness") then
    local function OnWereModeDirty(inst)
        if inst.weremode:value() ~= 0 and inst.components.wereness and inst.hungerpercent2hm then
            inst.components.wereness:SetPercent(math.clamp(inst.hungerpercent2hm, 0.03, 1))
            inst.hungerpercent2hm = nil
            if inst.weremode:value() == 1 and inst.components.sanity and inst.components.sanity.custom_rate_fn then
                inst.components.sanity.custom_rate_fn = function() return -TUNING.WERE_SANITY_PENALTY end
            end
        end
    end
    local function onrespawnedfromghost(inst)
        if inst.weremode:value() ~= 0 and inst.components.wereness then
            inst.components.wereness:SetPercent(2 / 3)
            inst.hungerpercent2hm = nil
        end
    end
    local function onfinishedwork(inst, data)
        if inst.weremode:value() == 1 and inst.components.sanity then inst.components.sanity:DoDelta(math.random() * 2.5) end
    end
    AddPrefabPostInit("woodie", function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("weremodedirty", OnWereModeDirty)
        inst:ListenForEvent("ms_respawnedfromghost", onrespawnedfromghost)
        inst:ListenForEvent("finishedwork", onfinishedwork)
        if inst.components.wereeater then
            local forcetransformfn = inst.components.wereeater.forcetransformfn
            inst.components.wereeater:SetForceTransformFn(function(inst, mode, ...)
                forcetransformfn(inst, mode, ...)
                if inst.components.hunger then inst.hungerpercent2hm = math.clamp(inst.components.hunger:GetPercent() - 0.007, 0.03, 1) end
            end)
        end
    end)
    AddComponentPostInit("wereness", function(self)
        self.maxhunger2hm = math.min(TUNING.WOODIE_HUNGER, 255)
        local SetDrainRate = self.SetDrainRate
        self.SetDrainRate = function(self, rate, ...)
            if self.inst.prefab ~= "woodie" then return SetDrainRate(self, rate, ...) end
            self.rate = math.clamp(-self.inst.components.hunger.hungerrate * self.inst.components.hunger.burnrate *
                                       self.inst.components.hunger.burnratemodifiers:Get() * 175 / self.maxhunger2hm, -10, 0)
        end
    end)
    local Badge = require("widgets/badge")
    AddClassPostConstruct("widgets/werebadge", function(self)
        self.maxhunger2hm = math.min(TUNING.WOODIE_HUNGER, 255)
        local SetPercent = self.SetPercent
        self.SetPercent = function(self, val, ...)
            SetPercent(self, val, ...)
            Badge.SetPercent(self, val, self.maxhunger2hm)
            if self.CombinedStatusUpdateNumbers then
                self.CombinedStatusUpdateNumbers(self, self.maxhunger2hm)
            elseif Badge.CombinedStatusUpdateNumbers then
                Badge.CombinedStatusUpdateNumbers(self, self.maxhunger2hm)
            end
        end
    end)
end

-- 伍迪结束变身
if GetModConfigData("Woodie Right Self Close Transform") then
    local function OnWereModeDirty(inst)
        if inst.weremode:value() == 0 and inst.components.hunger and inst.werepercent2hm then
            if GetModConfigData("Woodie Hunger Wereness") then
                inst.components.hunger:SetPercent(math.max(0.03, inst.werepercent2hm))
            else
                inst.components.hunger:SetPercent(0.03)
            end
            inst.werepercent2hm = nil
        end
    end
    local text = TUNING.isCh2hm and "变回人形" or "Become Human"
    AddRightSelfAction("woodie", FRAMES, "doshortaction", function(inst, act)
        if TheWorld.ismastersim and act.doer and act.doer.weremode and act.doer.weremode:value() ~= 0 and act.doer.components.wereness then
            act.doer.werepercent2hm = act.doer.components.wereness:GetPercent()
            act.doer.components.wereness:SetWereMode(nil)
            act.doer.components.wereness:SetPercent(0, true)
        end
    end, nil, text, nil, nil, function(inst) return inst.weremode and inst.weremode:value() ~= 0 end)
    local function ActionStringOverride2hm(inst, action, ...)
        if action and action.action == ACTIONS.RIGHTSELFACTION2HM then return text end
        return inst.oldActionStringOverride2hm and inst.oldActionStringOverride2hm(inst, action, ...)
    end
    AddComponentPostInit("playeractionpicker", function(self)
        if not (self.inst.prefab == "woodie" or self.inst.weremode or self.inst:HasTag("wereman")) then return end
        local GetRightClickActions = self.GetRightClickActions
        self.GetRightClickActions = function(self, position, target, spellbook, ...)
            if target == self.inst and not self.inst:HasTag("playerghost") and self.inst.weremode and self.inst.weremode:value() ~= 0 then
                if self.inst.ActionStringOverride and self.inst.ActionStringOverride ~= ActionStringOverride2hm then
                    self.inst.oldActionStringOverride2hm = self.inst.ActionStringOverride
                    self.inst.ActionStringOverride = ActionStringOverride2hm
                end
                return self:SortActionList({ACTIONS.RIGHTSELFACTION2HM}, target)
            end
            return GetRightClickActions(self, position, target, spellbook, ...)
        end
    end)
    AddPrefabPostInit("woodie", function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("weremodedirty", OnWereModeDirty)
    end)
end

-- 伍迪鹿人冲撞击破障碍拦截晕眩
if GetModConfigData("Woodie Moose Stronger Charge") then
    AddPrefabPostInit("woodie", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.tackler then
            local self = inst.components.tackler
            self:AddWorkAction(ACTIONS.CHOP, 16)
            self:AddWorkAction(ACTIONS.MINE, 8)
            self:AddWorkAction(ACTIONS.HAMMER, 4)
            local OnTackleCollide = self.oncollidefn
            self:SetOnCollideFn(function(inst, other, ...)
                if other and other:IsValid() then
                    if inst.sg and inst.sg.statemem and inst.sg.statemem.edgecount then
                        inst.sg.statemem.edgecount = inst.sg.statemem.edgecount + 1
                    end
                    inst.tacklecollideepic2hm = (inst.tacklecollideepic2hm or 0) + 1
                end
                OnTackleCollide(inst, other, ...)
            end)
            local OnTackleTrample = self.ontramplefn
            self:SetOnTrampleFn(function(inst, other, ...)
                OnTackleTrample(inst, other, ...)
                if other and other:IsValid() and other:HasTag("epic") then
                    if inst.sg and inst.sg.statemem and inst.sg.statemem.edgecount then
                        inst.sg.statemem.edgecount = inst.sg.statemem.edgecount + 2
                    end
                    inst.tacklecollideepic2hm = (inst.tacklecollideepic2hm or 0) + 1
                end
            end)
            local CheckCollision = self.CheckCollision
            self.CheckCollision = function(self, ...)
                CheckCollision(self, ...)
                local result = self.inst.tacklecollideepic2hm ~= nil and self.inst.tacklecollideepic2hm >= 2
                if self.inst.components.grogginess ~= nil then
                    local grogginess_skill = self.inst.components.skilltreeupdater and self.inst.components.skilltreeupdater:IsActivated("woodie_curse_moose_1")
                    self.inst.components.grogginess:SetPercent(math.clamp(math.clamp(self.inst.tacklecollideepic2hm or 0, 0, 4) *
                                                                              (grogginess_skill and 0.25 or 0.5), 0, 0.99))
                end
                return result
            end
        end
    end)
    AddStategraphPostInit("wilson", function(sg)
        local tackle_pre = sg.states.tackle_pre.onenter
        sg.states.tackle_pre.onenter = function(inst, ...)
            if inst.components.grogginess and inst.components.grogginess.grog_amount > 0 then
                inst.sg:GoToState("idle", true)
                return
            end
            if inst.tacklecollideepic2hm then inst.tacklecollideepic2hm = nil end
            tackle_pre(inst, ...)
            inst.sg:AddStateTag("temp_invincible")
        end
        local tackle_start = sg.states.tackle_start.onenter
        sg.states.tackle_start.onenter = function(inst, ...)
            tackle_start(inst, ...)
            inst.sg:AddStateTag("temp_invincible")
        end
        local tackle = sg.states.tackle.onenter
        sg.states.tackle.onenter = function(inst, ...)
            tackle(inst, ...)
            inst.sg:AddStateTag("temp_invincible")
        end
        -- local tackle_collide = sg.states.tackle_collide.onenter
        -- sg.states.tackle_collide.onenter = function(inst, ...)
        --     tackle_collide(inst, ...)
        --     inst.sg:AddStateTag("temp_invincible")
        -- end
        -- local tackle_stop = sg.states.tackle_stop.onenter
        -- sg.states.tackle_stop.onenter = function(inst, ...)
        --     tackle_stop(inst, ...)
        --     inst.sg:AddStateTag("temp_invincible")
        -- end
    end)
    AddPrefabPostInit("lucy", function(inst)
        if not TheWorld.ismastersim then return end
        inst.components.weapon:SetDamage(TUNING.AXE_DAMAGE)
    end)
end