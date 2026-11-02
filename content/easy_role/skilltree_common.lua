local hardmode = TUNING.hardmode2hm and GetModConfigData("role_nerf")
local skilltreedefs = require "prefabs/skilltree_defs"


-- 威尔逊更多技能点且快速加点且防止onload失败
local skillpointsopt = GetModConfigData("More Skill Points")
if not hardmode then skillpointsopt = -16 end -- 2025.7.17 melon:关闭困难模式时开局15点
local no_more_point = skillpointsopt == -1 -- 2025.9.19 melon:选择0时永不获得技能点
if skillpointsopt then
    TUNING.SKILL_THRESHOLDS = {4, 4, 4, 5, 5, 5, 5, 6, 6, 6, 6, 6, 7, 7, 7, 7, 7, 7, 8, 8, 8, 8, 8, 8, 3, 1, 1, 1, 1, 1}
    local maxpoints = {wilson = 26, willow = 24, wolfgang = 25, woodie = 27, wathgrithr = 23, wormwood = 26, wurt = 28, winona = 26, walter = 26, wortox = 27, wendy = 25}
    AddClassPostConstruct("skilltreedata", function(self)
        local GetAvailableSkillPoints = self.GetAvailableSkillPoints
        self.GetAvailableSkillPoints = function(self, characterprefab, ...)
            if not self.prefab2hm or self.prefab2hm ~= characterprefab then self.prefab2hm = characterprefab end
            local result = GetAvailableSkillPoints(self, characterprefab, ...)
            return result
        end
        local GetPointsForSkillXP = self.GetPointsForSkillXP
        self.GetPointsForSkillXP = function(self, ...)
            if self.prefab2hm and maxpoints[self.prefab2hm] then return math.min(GetPointsForSkillXP(self, ...), maxpoints[self.prefab2hm]) end
            return GetPointsForSkillXP(self, ...)
        end
        if skillpointsopt ~= true then
            local startskills = math.clamp(-skillpointsopt - 1, 0, 15)
            local startxp = 0
            for i = 1, startskills do startxp = startxp + TUNING.SKILL_THRESHOLDS[i] end
            local GetSkillXP = self.GetSkillXP
            self.GetSkillXP = function(self, ...)
                local skillxp = GetSkillXP(self, ...)
                -- 2025.9.19 melon:选择0时(no_more_point)永不获得技能点
                local newxp = no_more_point and 0 or not self.disablehardxp2hm and (TheWorld and math.min(TheWorld.state.cycles + startxp, skillxp) or 0) or skillxp
                -- local newxp = no_more_point and 0 or not self.disablehardxp2hm and TheWorld and (TheWorld.state.cycles + startxp) or skillxp -- 2025.10.13 melon:改为原本没点也能开局获得5点 存在问题:无技能树左上也有提示
                return newxp
            end
            local OPAH_DoBackup = self.OPAH_DoBackup
            self.OPAH_DoBackup = function(self, ...)
                self.disablehardxp2hm = true
                local result = OPAH_DoBackup(self, ...)
                self.disablehardxp2hm = nil
                return result
            end
            local AddSkillXP = self.AddSkillXP
            self.AddSkillXP = function(self, ...)
                self.disablehardxp2hm = true
                local result, xp = AddSkillXP(self, ...)
                if TheWorld and TheWorld.state.cycles <= 160 then result = true end
                self.disablehardxp2hm = nil
                return result, xp
            end
        end
    end)
    local function learnparentskill(self, currentskill, skilltreeupdater)
        for skill, skilldata in pairs(self.skilltreedef) do
            if skilldata and not skilldata.lock_open and skilldata.connects then
                for i, connected_skill in ipairs(self.skilltreedef[skill].connects) do
                    if connected_skill == currentskill and self.skillgraphics[skill] then
                        if self.skillgraphics[skill].status and self.skillgraphics[skill].status.activatable then
                            skilltreeupdater:ActivateSkill(skill, self.target)
                            return true
                        else
                            return learnparentskill(self, skill, skilltreeupdater)
                        end
                    end
                end
            end
        end
    end
    AddClassPostConstruct("widgets/redux/skilltreebuilder", function(self)
        local oldbuildbuttons = self.buildbuttons
        self.buildbuttons = function(self, ...)
            oldbuildbuttons(self, ...)
            for i, data in ipairs(self.buttongrid) do
                if data and data.button then
                    local old = data.button.onclick
                    data.button:SetOnClick(function(...)
                        if not TheInput:ControllerAttached() and self.skillgraphics then
                            for skill, graphics in pairs(self.skillgraphics) do
                                if graphics and graphics.button == data.button and self.selectedskill == skill and graphics.status.activatable and
                                    self.infopanel.activatebutton:IsVisible() then
                                    self:LearnSkill(self.fromfrontend and TheSkillTree or (ThePlayer and ThePlayer.components.skilltreeupdater), self.target)
                                    break
                                elseif graphics and graphics.button == data.button and self.selectedskill == skill then
                                    local skilltreeupdater = self.fromfrontend and TheSkillTree or (ThePlayer and ThePlayer.components.skilltreeupdater)
                                    if skilltreeupdater then
                                        local availableskillpoints = skilltreeupdater:GetAvailableSkillPoints(self.target) or 0
                                        if availableskillpoints > 0 and self.skilltreedef and self.skilltreedef[skill] and not self.skilltreedef[skill].root then
                                            learnparentskill(self, skill, skilltreeupdater)
                                        end
                                    end
                                end
                            end
                        end
                        old(...)
                        if self.skillgraphics then
                            for skill, graphics in pairs(self.skillgraphics) do
                                if self.selectedskill and self.selectedskill == skill and not TheInput:ControllerAttached() then
                                    graphics.frame:Hide()
                                    break
                                end
                            end
                        end
                    end)
                end
            end
        end
    end)
    AddClassPostConstruct("widgets/skilltreetoast", function(self)
        self.tab_gift:Hide()
        self.shownotification = Profile:GetScrapbookHudDisplay()
        local UpdateElements = self.UpdateElements
        self.UpdateElements = function(self, ...)
            local craft_hide = self.craft_hide
            self.craft_hide = craft_hide or not self.shownotification
            if self.shownotification then
                self.tab_gift:Show()
            else
                self.tab_gift:Hide()
            end
            UpdateElements(self, ...)
            self.craft_hide = craft_hide
        end
        local Onupdate = self.Onupdate
        self.Onupdate = function(self, ...)
            if self.shownotification ~= Profile:GetScrapbookHudDisplay() then
                self.shownotification = Profile:GetScrapbookHudDisplay()
                self:UpdateElements()
            end
            if self.opened then Onupdate(self, ...) end
        end
        local UpdateControllerHelp = self.UpdateControllerHelp
        self.UpdateControllerHelp = function(self, ...) if self.opened then UpdateControllerHelp(self, ...) end end
    end)
end

-- 威尔逊技能组解禁
if GetModConfigData("Wilson Skill Unlock") then
    local finalTags = {"lunar_favor", "shadow_favor"}
    local woodieTags = {"beaver", "moose", "goose"}
    local woodieEpicTags = {"beaver_epic", "moose_epic", "goose_epic"}
    local skilltreedefs = require "prefabs/skilltree_defs"
    -- 角色可以同时点出暗影与位面的终极技能
    for prefab, skills in pairs(skilltreedefs.SKILLTREE_DEFS) do
        if skills and type(skills) == "table" then
            for skill_name, skill in pairs(skills) do
                if skill and skill.tags then
                    for i = #skill.tags, 1, -1 do if table.contains(finalTags, skill.tags[i]) then table.remove(skill.tags, i) end end
                end
            end
        end
    end
    -- 威尔逊可以拆解宝石
    AddRecipe2("transmute_orangegem2hm", {Ingredient("orangegem", 1)}, TECH.NONE,
               {product = "purplegem", numtogive = 2, image = "purplegem.tex", builder_skill="wilson_alchemy_5", description = "transmute_orangegem"},
               {"CHARACTER"})
    AddRecipe2("transmute_yellowgem2hm", {Ingredient("yellowgem", 1)}, TECH.NONE,
               {product = "orangegem", numtogive = 2, image = "orangegem.tex", builder_skill="wilson_alchemy_5", description = "transmute_yellowgem"},
               {"CHARACTER"})
    AddRecipe2("transmute_greengem2hm", {Ingredient("greengem", 1)}, TECH.NONE,
               {product = "yellowgem", numtogive = 2, image = "yellowgem.tex", builder_skill="wilson_alchemy_6", description = "transmute_greengem"},
               {"CHARACTER"})
    -- 薇诺娜可以点出双终极技能
    if skilltreedefs.SKILLTREE_DEFS and skilltreedefs.SKILLTREE_DEFS.winona then
        local skills = skilltreedefs.SKILLTREE_DEFS.winona
        if skills and type(skills) == "table" and skills.winona_wagstaff_2_lock and skills.winona_charlie_2_lock then
            skills.winona_wagstaff_2_lock.lock_open = function(prefabname, activatedskills, readonly)
                return activatedskills and activatedskills["winona_wagstaff_1"]
            end
            skills.winona_charlie_2_lock.lock_open = function(prefabname, activatedskills, readonly)
                return activatedskills and activatedskills["winona_charlie_1"]
            end
        end
    end
    -- 伍迪可以点出三个形态的最后技能
    local FN = skilltreedefs.FN
    if skilltreedefs.FN and skilltreedefs.FN.CountTags then
        local old = skilltreedefs.FN.CountTags
        skilltreedefs.FN.CountTags = function(prefab, targettag, ...)
            if targettag then
                if table.contains(woodieTags, targettag) then
                    TUNING.woodieEpicTags2hm = 2
                elseif TUNING.woodieEpicTags2hm and TUNING.woodieEpicTags2hm > 0 and table.contains(woodieEpicTags, targettag) then
                    TUNING.woodieEpicTags2hm = TUNING.woodieEpicTags2hm - 1
                    return 0
                elseif TUNING.woodieEpicTags2hm then
                    TUNING.woodieEpicTags2hm = nil
                end
            end
            return old(prefab, targettag, ...)
        end
    end
    if TUNING.DSTU and TUNING.DSTU.WATHGRITHR_REWORK then
        -- 妥协女武神重做部分回调,且依旧可以做曲子
        local skills = skilltreedefs.SKILLTREE_DEFS and skilltreedefs.SKILLTREE_DEFS.wathgrithr
        if skills and skills.wathgrithr_allegiance_lock_1 and skills.wathgrithr_allegiance_lock_1.lock_open then
            skills.wathgrithr_allegiance_lock_1.lock_open = function(prefabname, activatedskills, readonly)
                -- return skilltreedefs.FN.CountSkills(prefabname, activatedskills) = 1
                return true
            end
        end
        if skills and skills.wathgrithr_allegiance_shadow and skills.wathgrithr_allegiance_shadow then
            local onactivate = skills.wathgrithr_allegiance_shadow.onactivate
            skills.wathgrithr_allegiance_shadow.onactivate = function(inst, ...)
                if onactivate then onactivate(inst, ...) end
                inst:AddTag("battlesongshadowalignedmaker")
            end
            local onactivate = skills.wathgrithr_allegiance_lunar.onactivate
            skills.wathgrithr_allegiance_lunar.onactivate = function(inst, ...)
                if onactivate then onactivate(inst, ...) end
                inst:AddTag("battlesonglunaralignedmaker")
            end
            local ondeactivate = skills.wathgrithr_allegiance_shadow.ondeactivate
            skills.wathgrithr_allegiance_shadow.ondeactivate = function(inst, ...)
                if ondeactivate then ondeactivate(inst, ...) end
                inst:RemoveTag("battlesongshadowalignedmaker")
            end
            local ondeactivate = skills.wathgrithr_allegiance_lunar.ondeactivate
            skills.wathgrithr_allegiance_lunar.ondeactivate = function(inst, ...)
                if ondeactivate then ondeactivate(inst, ...) end
                inst:RemoveTag("battlesonglunaralignedmaker")
            end
        end
    end
    -- 沃尔夫冈终极技能的第三级强化禁用
    -- if hardmode then
        -- TUNING.SKILLS.WOLFGANG_ALLEGIANCE_SHADOW_RESIST_1 = 1
        -- TUNING.SKILLS.WOLFGANG_ALLEGIANCE_LUNAR_RESIST_1 = 1
        -- TUNING.SKILLS.WOLFGANG_ALLEGIANCE_VS_LUNAR_BONUS_3 = 1
        -- TUNING.SKILLS.WOLFGANG_ALLEGIANCE_VS_SHADOW_BONUS_3 = 1
    -- end
end