-- TUNING.INSPIRATION_DRAIN_BUFFER_TIME = TUNING.INSPIRATION_DRAIN_BUFFER_TIME * 2
TUNING.INSPIRATION_RIDING_GAIN_RATE = TUNING.INSPIRATION_RIDING_GAIN_RATE / 3
TUNING.INSPIRATION_RIDING_GAIN_MAX = TUNING.BATTLESONG_THRESHOLDS[1]
AddComponentPostInit("singinginspiration", function(self)
    local oldUpdate = self.OnUpdate
    self.OnUpdate = function(self, ...)
        oldUpdate(self, ...)
        if self.is_draining then
            if self.active2hm then
                self.active2hm = nil
                if self.inspire_refresh_task ~= nil then
                    self.inspire_refresh_task:Cancel()
                    self.inspire_refresh_task = nil
                end
                if self.display_fx_task ~= nil then
                    self.display_fx_task:Cancel()
                    self.display_fx_task = nil
                    self.display_fx_count = nil
                end
            end
        elseif not self.active2hm then
            self.active2hm = true
            if #self.active_songs > 0 then
                self:Inspire()
                self:DisplayFx()
                if self.inspire_refresh_task == nil then
                    self.inspire_refresh_task = self.inst:DoPeriodicTask(TUNING.SONG_REAPPLY_PERIOD, function() self:Inspire() end)
                end
            end
        end
    end
    local AddSong = self.AddSong
    self.AddSong = function(self, ...)
        AddSong(self, ...)
        if not self.active2hm then
            if self.inspire_refresh_task ~= nil then
                self.inspire_refresh_task:Cancel()
                self.inspire_refresh_task = nil
            end
            if self.display_fx_task ~= nil then
                self.display_fx_task:Cancel()
                self.display_fx_task = nil
                self.display_fx_count = nil
            end
        end
    end
    -- local Inspire = self.Inspire
    -- self.Inspire = function(self, ...)
    --     return Inspire(self, ...)
    -- end
    local DisplayFx = self.DisplayFx
    self.DisplayFx = function(self, ...)
        if #self.active_songs == 0 and not self.display_fx_task then
            self.display_fx_count = 1
            return
        end
        return DisplayFx(self, ...)
    end
end)

AddRecipePostInit("battlesong_instant_revive", function(inst) table.insert(inst.ingredients, Ingredient("greengem", 1)) end)
TUNING.SKILLS.WATHGRITHR.BATTLESONG_INSTANT_COOLDOWN_HIGH = TUNING.SKILLS.WATHGRITHR.BATTLESONG_INSTANT_COOLDOWN_HIGH * 16
TUNING.POCKETWATCH_REVIVE_COOLDOWN = TUNING.SKILLS.WATHGRITHR.BATTLESONG_INSTANT_COOLDOWN_HIGH

-- 限制谱子只能攻击敌人回复
local function IsValidVictim(victim)
    return victim ~= nil and
               not ((victim:HasTag("prey") and not victim:HasTag("hostile")) or victim:HasTag("veggie") or victim:HasTag("structure") or victim:HasTag("wall") or
                   victim:HasTag("balloon") or victim:HasTag("groundspike") or victim:HasTag("smashable") or victim:HasTag("companion")) and
               victim.components.health ~= nil and victim.components.combat ~= nil
end
local function processsongapply(inst)
    if not TheWorld.ismastersim then return end
    if inst.songdata and not inst.songdata.gainpro2hm and inst.songdata.ONAPPLY then
        inst.songdata.gainpro2hm = true
        local old = inst.songdata.ONAPPLY
        inst.songdata.ONAPPLY = function(inst, target, ...)
            local num = 0
            if target.components.health and target.event_listeners and target.event_listeners.onattackother and target.event_listeners.onattackother[inst] then
                num = #target.event_listeners.onattackother[inst]
            end
            old(inst, target, ...)
            if target.components.health and target.event_listeners and target.event_listeners.onattackother and target.event_listeners.onattackother[inst] then
                local fns = target.event_listeners.onattackother[inst]
                if #fns > num then
                    local fn = fns[#fns]
                    fns[#fns] = function(attacker, data, ...)
                        if data and data.target and data.target:IsValid() and IsValidVictim(data.target) then fn(attacker, data, ...) end
                    end
                end
            end
        end
    end
end
AddPrefabPostInit("battlesong_healthgain", processsongapply)
AddPrefabPostInit("battlesong_sanitygain", processsongapply)

-- 2025.8.26 melon:充能奔雷矛削弱   cd+0.5  冲刺消耗部分激励，激励不足扣3血。点暗影总是扣0.5血。
if GetModConfigData("Charged Elding Spear negative buff") and GetModConfigData("Valkyrie thunder sprints without shaking") then -- 奔雷无前摇开启才加材料
    TUNING.SPEAR_WATHGRITHR_LIGHTNING_CHARGED_LUNGE_COOLDOWN = TUNING.SPEAR_WATHGRITHR_LIGHTNING_CHARGED_LUNGE_COOLDOWN + 0.5 -- 原本1.5
    AddPrefabPostInit("spear_wathgrithr_lightning_charged", function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.aoeweapon_lunge then
            local _onlungedfn = inst.components.aoeweapon_lunge.onlungedfn
            inst.components.aoeweapon_lunge.onlungedfn = function(inst, doer, ...)
                if _onlungedfn ~= nil then _onlungedfn(inst, doer, ...) end
                if doer and doer.components.singinginspiration then
                    -- 开启妥协武神重做,且点了暗影2025.8.28    2025.9.12 melon:不是用WATHGRITHR_REWORK
                    if TUNING.DSTU and TUNING.DSTU.WATHGRITHR_ARSENAL and doer:HasTag("player_shadow_aligned") then
                        if doer.components.health then doer.components.health:DoDelta(-0.5) end -- 点暗影扣0.5血
                        -- if doer.components.hunger then doer.components.hunger:DoDelta(-1) end -- 扣1饥饿(声音吵)
                    else
                        if doer.components.singinginspiration:GetPercent() >= 0.3 then
                            -- 激励越高扣得越少，最少1.5点.前面的8调整低激励时扣的量,后面的1.5调整高激励时扣的量.
                            local delta = -8 * (1 - doer.components.singinginspiration:GetPercent()) - 1.5
                            doer.components.singinginspiration:DoDelta(delta, true)
                        elseif doer.components.health then
                            doer.components.health:DoDelta(-3)
                        end
                    end
                end
            end
        end
    end)
end

-- 2025.6.28 melon:奔雷矛变难做
AddRecipePostInit("spear_wathgrithr_lightning", function(inst)
    table.remove(inst.ingredients)
    table.insert(inst.ingredients, Ingredient("purplegem", 1))
end)
-- 2025.9.10 melon:乐谱制作变难
AddRecipePostInit("battlesong_instant_taunt",function(inst)
    table.remove(inst.ingredients) -- 移除最后一个 2025.10.13
    table.insert(inst.ingredients, Ingredient("greengem", 1)) -- 绿宝石  (建造会被用来刷)
end)
-- if GetModConfigData("Valkyrie thunder sprints without shaking") then -- 奔雷无前摇开启才加材料
--     AddRecipePostInit("battlesong_instant_panic",function(inst)
--         table.remove(inst.ingredients)
--         table.insert(inst.ingredients, Ingredient("greengem", 1)) -- 绿宝石
--     end)
-- end
-- AddRecipePostInit("battlesong_sanitygain",function(inst) -- 没加强就不加材料了吧 2025.10.3
--     table.remove(inst.ingredients)
--     table.insert(inst.ingredients, Ingredient("glasscutter", 1)) -- 玻璃刀
-- end)
-- AddRecipePostInit("battlesong_healthgain",function(inst) -- 没加强就不加材料了吧
--     table.remove(inst.ingredients)
--     table.insert(inst.ingredients, Ingredient("batbat", 1)) -- 蝙蝠棒
-- end)
AddRecipePostInit("battlesong_fireresistance",function(inst)
    table.remove(inst.ingredients)
    table.insert(inst.ingredients, Ingredient("dragon_scales", 1)) -- 龙皮
end)

if GetModConfigData("battlesong_durability_sanitygain") then -- 开启这个才变难做
    if GetModConfigData("moonisland") then -- 开了月岛流星 2025.10.13
        AddRecipePostInit("battlesong_durability",function(inst)
            table.remove(inst.ingredients)
            table.insert(inst.ingredients, Ingredient("moonglass_charged", 3)) -- 注能碎片 2025.10.4
        end)
    end
    AddRecipePostInit("battlesong_sanityaura",function(inst)
        table.remove(inst.ingredients)
        table.insert(inst.ingredients, Ingredient("cane", 1)) -- 手杖 2025.10.3
    end)
end
-- 大削版↓ 改为上面兼容写法
-- Recipe("battlesong_durability",	{_G.Ingredient("papyrus", 3), _G.Ingredient("featherpencil", 3), _G.Ingredient("minotaurhorn", 1)},		_G.CUSTOM_RECIPETABS.BATTLESONGS, _G.TECH.NONE, nil, nil, nil, nil, "battlesinger")
-- Recipe("battlesong_sanitygain",	{_G.Ingredient("papyrus", 3), _G.Ingredient("featherpencil", 3), _G.Ingredient("glasscutter", 1)},		_G.CUSTOM_RECIPETABS.BATTLESONGS, _G.TECH.NONE, nil, nil, nil, nil, "battlesinger")
-- Recipe("battlesong_sanityaura",	{_G.Ingredient("papyrus", 3), _G.Ingredient("featherpencil", 3), _G.Ingredient("orangestaff", 1)},		_G.CUSTOM_RECIPETABS.BATTLESONGS, _G.TECH.NONE, nil, nil, nil, nil, "battlesinger")
-- Recipe("battlesong_healthgain",	{_G.Ingredient("papyrus", 3), _G.Ingredient("featherpencil", 3), _G.Ingredient("batbat", 1)},	_G.CUSTOM_RECIPETABS.BATTLESONGS, _G.TECH.NONE, nil, nil, nil, nil, "battlesinger")
-- Recipe("battlesong_fireresistance",	{_G.Ingredient("papyrus", 3), _G.Ingredient("featherpencil", 3), _G.Ingredient("dragon_scales", 1)},		_G.CUSTOM_RECIPETABS.BATTLESONGS, _G.TECH.NONE, nil, nil, nil, nil, "battlesinger")
-- Recipe("battlesong_instant_taunt",	{_G.Ingredient("papyrus", 3), _G.Ingredient("featherpencil", 3), _G.Ingredient("greenamulet", 1)},		_G.CUSTOM_RECIPETABS.BATTLESONGS, _G.TECH.NONE, nil, nil, nil, nil, "battlesinger")
-- Recipe("battlesong_instant_panic",	{_G.Ingredient("papyrus", 3), _G.Ingredient("featherpencil", 3), _G.Ingredient("greenamulet", 1)},		_G.CUSTOM_RECIPETABS.BATTLESONGS, _G.TECH.NONE, nil, nil, nil, nil, "battlesinger")


