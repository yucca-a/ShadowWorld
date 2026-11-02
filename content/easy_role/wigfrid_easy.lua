local hardmode = TUNING.hardmode2hm and GetModConfigData("role_nerf") and GetModConfigData("wigfrid")

--女武神薇格弗德激励值脱战不掉落 -- 2025.4.10
if GetModConfigData("Wigfrid Inspiration Not Drop") then
    TUNING.WATHGRITHR_HUNGER = TUNING.WILSON_HUNGER
    TUNING.WATHGRITHR_SANITY = TUNING.WILSON_SANITY
    TUNING.INSPIRATION_DRAIN_RATE = 0
end -- 2025.4.10 melon:回退

-- 薇格弗德骑乘冲刺
if GetModConfigData("Wigfrid Ride Right Dodge") then
    local cd = GetModConfigData("Wilson Right Dodge")
    cd = (cd == true or cd == false) and 1 or cd
    AddPrefabPostInit("wathgrithr", function(inst)
        AddDodgeAbility(inst)
        inst.rightaction2hm_cooldown = cd
        inst.rightaction2hm_beefalo = true
    end)
end

if GetModConfigData("Wigfrid can eat any") then
    -- local function OnCustomStatsModFn(inst, health, hunger, sanity, food, feeder)
    --     if food.components.edible.foodtype ~= FOODTYPE.MEAT and
    --         food.components.edible.foodtype ~= FOODTYPE.GOODIES then
    --         return health > 0 and health * 0.3 or health,
    --                 hunger > 0 and hunger * 0.3 or hunger,
    --                 sanity > 0 and sanity * 0.7 or sanity -- 2025.8.22 melon:正的70%收益,负的全收益
    --     end
    --     if food ~= nil and food.components.edible ~= nil and
    --         food.components.edible.foodtype == FOODTYPE.MEAT then
    --         -- 肉食溢出转换
    --         local need = inst.components.hunger.max - inst.components.hunger.current
    --         -- 20%转化率
    --         if hunger > need then
    --             local mult = 0.2
    --             local canusehunger = (hunger - need) * mult
    --             local needspiration = inst.components.singinginspiration.max - inst.components.singinginspiration.current
    --             if needspiration > 0 and canusehunger <= needspiration then
    --                 hunger = need
    --                 inst.components.singinginspiration:DoDelta(canusehunger)
    --                 inst.components.singinginspiration.last_attack_time = GetTime()
    --             elseif needspiration > 0 then
    --                 hunger = (canusehunger - needspiration) * 5
    --                 inst.components.singinginspiration:SetPercent(1)
    --             end
    --         end
    --     end
    --     return health, hunger, sanity
    -- end
    AddPrefabPostInit("wathgrithr", function(inst)
        if not TheWorld.ismastersim then return inst end
        inst:DoTaskInTime(0, function()
            if inst.components.eater ~= nil then
                inst.components.eater:SetDiet({FOODGROUP.OMNI}) -- 解锁全食谱

                local oldeat = inst.components.eater.Eat
                inst.components.eater.Eat = function(self, food, ...)
                    if inst.components.hunger then self.oldcurrent2hm = inst.components.hunger.current end
                    local result = oldeat(self, food, ...)
                    if inst.components.hunger then self.oldcurrent2hm = nil end
                    return result
                end

                local oldfn = inst.components.eater.custom_stats_mod_fn
                inst.components.eater.custom_stats_mod_fn = function(inst, health, hunger, sanity, food, feeder)
                    if oldfn then
                        health, hunger, sanity = oldfn(inst, health, hunger, sanity, food, feeder)
                    end
                    if food.components.edible.foodtype ~= FOODTYPE.MEAT and
                        food.components.edible.foodtype ~= FOODTYPE.GOODIES then
                        return health > 0 and health * 0.3 or health,
                                hunger > 0 and hunger * 0.3 or hunger,
                                sanity > 0 and sanity * 0.7 or sanity -- 2025.8.22 melon:正的70%收益,负的全收益
                    end
                    if food ~= nil and food.components.edible ~= nil and not inst.cantusesinginginspiration and
                        food.components.edible.foodtype == FOODTYPE.MEAT and inst.components.eater.oldcurrent2hm then
                        -- 肉食溢出转换
                        local mult = 0.25
                        local effective_max = inst.components.hunger.max * (1 - (inst.components.hunger.penalty2hm or 0))
                        -- oldcurrent 可能因为饥饿上限惩罚、其他模组改 max 而高于有效上限；
                        -- 不夹到 0 会把 need 算成负数，随后 hunger=need 会让这顿饭一点饥饿都不加。
                        local need = math.max(0, effective_max - inst.components.eater.oldcurrent2hm)
                        local needspiration = inst.components.singinginspiration.max - inst.components.singinginspiration.current
                        -- 20%转化率
                        if hunger > 0 then
                            local canusehunger = (hunger - need) * mult
                            if canusehunger > 0 then
                                if needspiration > 0 and canusehunger <= needspiration then
                                    hunger = need
                                    needspiration = needspiration - canusehunger
                                    inst.components.singinginspiration:DoDelta(canusehunger)
                                    inst.components.singinginspiration.last_attack_time = GetTime()
                                elseif needspiration > 0 then
                                    hunger = (canusehunger - needspiration) * 5
                                    inst.components.singinginspiration:DoDelta(needspiration)
                                    inst.components.singinginspiration.last_attack_time = GetTime()
                                    return health, hunger, sanity
                                end
                            end
                        end
                        -- 吃撑时再转化生命理智
                        if need <= 10 then
                            if health > 0 then
                                local canusehealth = health * mult * 2
                                if canusehealth > 0 then
                                    if needspiration > 0 and canusehealth <= needspiration then
                                        health = 0
                                        needspiration = needspiration - canusehealth
                                        inst.components.singinginspiration:DoDelta(canusehealth)
                                        inst.components.singinginspiration.last_attack_time = GetTime()
                                    elseif needspiration > 0 then
                                        health = (canusehealth - needspiration) * 5
                                        inst.components.singinginspiration:DoDelta(needspiration)
                                        inst.components.singinginspiration.last_attack_time = GetTime()
                                        return health, hunger, sanity
                                    end
                                end
                            end
                            if sanity > 0 then
                                local canusesanity = sanity * mult * 2
                                if canusesanity > 0 then
                                    if needspiration > 0 and canusesanity <= needspiration then
                                        sanity = 0
                                        needspiration = needspiration - canusesanity
                                        inst.components.singinginspiration:DoDelta(canusesanity)
                                        inst.components.singinginspiration.last_attack_time = GetTime()
                                    elseif needspiration > 0 then
                                        sanity = (canusesanity - needspiration) * 5
                                        inst.components.singinginspiration:DoDelta(needspiration)
                                        inst.components.singinginspiration.last_attack_time = GetTime()
                                        return health, hunger, sanity
                                    end
                                end
                            end
                        end
                    end
                    return health, hunger, sanity
                end
            end
        end)
    end)
end

-- 女武神右键自己战士重奏，重奏粗鲁插曲加头盔,重奏惊心独白加长矛
local wigfrid_rightself = GetModConfigData("Wigfrid Right Self Reprise")
local wigfrid_hat = GetModConfigData("Rude Interlude Provide Battle Helm")
local wigfrid_spear = GetModConfigData("Startling Soliloquy Provide Battle Spear")
local reprisesongfns = {}
local reprisesongtypes = {}
if wigfrid_rightself or wigfrid_hat or wigfrid_spear then
    local song_defs = require("prefabs/battlesongdefs").song_defs
    -- 没有生效的直接战歌不再有任何消耗了;支持覆盖效果
    local needconsume
    local function canceloverridesongfntask(inst)
        inst.canceloverridesongfntask2hm = nil
        if inst.overridesongfn2hm then inst.overridesongfn2hm = nil end
        if inst.rightselftype2hm then inst.rightselftype2hm:set(0) end
    end
    AddComponentPostInit("singinginspiration", function(self)
        if wigfrid_rightself then
            local CanAddSong = self.CanAddSong
            self.CanAddSong = function(self, songdata, inst, ...)
                if inst and inst.overridesongfn2hm and self.current >= 100 / 3 then return true end
                return CanAddSong(self, songdata, inst, ...)
            end
        end
        local OnAddInstantSong = self.OnAddInstantSong
        self.OnAddInstantSong = function(self, songdata, inst, ...)
            if wigfrid_rightself and inst then
                if inst.overridesongfn2hm then
                    -- 重复操作确认修理武器或护甲
                    inst.overridesongfn2hm(self, self.inst)
                    self.inst.overridesongfn2hm = inst.overridesongfn2hm
                    if self.inst.canceloverridesongfntask2hm then self.inst.canceloverridesongfntask2hm:Cancel() end
                    self.inst.canceloverridesongfntask2hm = self.inst:DoTaskInTime(12, canceloverridesongfntask)
                    return
                elseif reprisesongfns[inst.prefab] and reprisesongfns[inst.prefab].fn then
                    -- 角色进入可以修理武器或护甲的状态
                    self.inst.overridesongfn2hm = reprisesongfns[inst.prefab].fn
                    local type = reprisesongfns[inst.prefab].type
                    if self.inst.rightselftype2hm and type and reprisesongtypes[type] then self.inst.rightselftype2hm:set(type) end
                    if self.inst.canceloverridesongfntask2hm then self.inst.canceloverridesongfntask2hm:Cancel() end
                    self.inst.canceloverridesongfntask2hm = self.inst:DoTaskInTime(12, canceloverridesongfntask)
                end
            end
            needconsume = nil
            if songdata and songdata.ONINSTANT and not songdata.help2hm then
                songdata.help2hm = true
                local old = songdata.ONINSTANT
                songdata.ONINSTANT = function(...)
                    old(...)
                    needconsume = true
                end
            end
            self:InstantInspire(songdata)
            if needconsume then
                local old = self.InstantInspire
                self.InstantInspire = nilfn
                OnAddInstantSong(self, songdata, inst, ...)
                self.InstantInspire = old
                return true
            end
        end
    end)
    -- 重复吟唱BUFF(失败)会取消此BUFF
    ACTIONS.SING_FAIL.fn = function(act)
        local self = act.doer and act.doer.components.singinginspiration
        if act.invobject and self ~= nil then
            local songdata = act.invobject.songdata
            if songdata and songdata.NAME and not songdata.INSTANT then
                if #self.active_songs == 1 and self.active_songs[1].NAME == songdata.NAME then
                    self:PopSong()
                elseif self:IsSongActive(songdata) then
                    local active_songs = {}
                    for i = #self.active_songs, 1, -1 do
                        if self.active_songs[i].NAME ~= songdata.NAME then table.insert(active_songs, self.active_songs[i].ITEM_NAME) end
                        self:PopSong()
                    end
                    for i = #active_songs, 1, -1 do
                        local songdata = song_defs[active_songs[i]]
                        if songdata ~= nil then self:AddSong(songdata, true) end
                    end
                end
            end
        end
        return true
    end
    -- 吟唱新BUFF(成功)无BUFF栏会取消最旧的BUFF
    AddStategraphPostInit("wilson", function(sg)
        local sing_pre = sg.states.sing_pre.onenter
        sg.states.sing_pre.onenter = function(inst, ...)
            sing_pre(inst, ...)
            inst.sing_pre_temp_invincible2hm = not inst.sing_pre_temp_invincible2hm
            -- 2025.9.21 melon:一次无敌一次不无敌
            if inst.sing_pre_temp_invincible2hm then inst.sg:AddStateTag("temp_invincible") end
            local buffaction = inst:GetBufferedAction()
            local songdata = buffaction and buffaction.invobject and buffaction.invobject.songdata or nil
            local self = inst.components.singinginspiration
            if self and songdata and not songdata.INSTANT and not self:IsSongActive(songdata) then
                self.available_slots = self.CalcAvailableSlotsForInspirationFn(self.inst, self:GetPercent())
                if self.available_slots > 0 and #self.active_songs >= self.available_slots then
                    local active_songs = {}
                    for i = #self.active_songs, 1, -1 do
                        table.insert(active_songs, self.active_songs[i].ITEM_NAME)
                        self:PopSong()
                    end
                    for i = #active_songs - 1, 1, -1 do
                        local songdata = song_defs[active_songs[i]]
                        if songdata ~= nil then self:AddSong(songdata, true) end
                    end
                end
            end
        end
        -- local sing_fail = sg.states.sing_fail.onenter
        -- sg.states.sing_fail.onenter = function(inst, ...)
        --     sing_fail(inst, ...)
        --     inst.sg:AddStateTag("temp_invincible")
        -- end
        local sing = sg.states.sing.onenter
        sg.states.sing.onenter = function(inst, ...)
            sing(inst, ...)
            -- 2025.9.21 melon:一次无敌一次不无敌
            if inst.sing_pre_temp_invincible2hm then inst.sg:AddStateTag("temp_invincible") end
        end
        -- local cantsing = sg.states.cantsing.onenter
        -- sg.states.cantsing.onenter = function(inst, ...)
        --     cantsing(inst, ...)
        --     inst.sg:AddStateTag("temp_invincible")
        -- end
    end)
    -- 2025.8.17 melon:科雷垃圾代码没判空，加一个
    local function IsHoldingPocketRummageActionItem2hm(holder, item)
        local owner = item.components.inventoryitem and item.components.inventoryitem.owner or nil
        return owner and -- 加判空
        (owner == holder or (owner.components.inventoryitem == nil and owner.entity:GetParent() == holder))
    end
    AddStategraphPostInit("wilson", function(sg)
        -- 2025.8.17 melon:加判空，修复使用粗鲁插曲导致的崩溃
        local UpvalueHacker = require("upvaluehacker2hm")
        local _onexit = sg.states.start_pocket_rummage.onexit
        if type(_onexit) == "function" then
            if UpvalueHacker.GetUpvalue(_onexit, "CheckPocketRummageMem") then
                local fn, i, prv = UpvalueHacker.GetUpvalue(_onexit, "CheckPocketRummageMem")
                if UpvalueHacker.GetUpvalue(fn, "IsHoldingPocketRummageActionItem") then
                    UpvalueHacker.SetUpvalue(fn, IsHoldingPocketRummageActionItem2hm, "IsHoldingPocketRummageActionItem")
                end
            end
        end
    end)
    -- 谱子服务器不处理图标，客户端处理图标
    local function itemtilefn(inst, self)
        local text
        if inst.songdata and inst.replica.inventoryitem and ThePlayer and ThePlayer:IsValid() and ThePlayer:HasTag("battlesinger") and ThePlayer.GetInspiration and
            ThePlayer.GetInspirationSong and ThePlayer.CalcAvailableSlotsForInspiration then
            local cansongbuffs = ThePlayer:CalcAvailableSlotsForInspiration()
            local canuse = (inst.songdata.RESTRICTED_TAG == nil or ThePlayer:HasTag(inst.songdata.RESTRICTED_TAG)) and
                               (inst.songdata.INSTANT and (ThePlayer:GetInspiration() >= inst.songdata.DELTA) or (cansongbuffs > 0))
            local newimage = canuse and inst.prefab or (inst.prefab .. "_unavaliable")
            if inst.replica.inventoryitem.overrideimage ~= (newimage .. ".tex") then inst.replica.inventoryitem:OverrideImage(newimage) end
            if not inst.songdata.INSTANT then
                local songs = {}
                for i = 1, cansongbuffs, 1 do
                    local songdata = ThePlayer:GetInspirationSong(i)
                    if songdata and songdata.ITEM_NAME then table.insert(songs, songdata.ITEM_NAME) end
                end
                if not canuse then
                    text = ""
                elseif table.contains(songs, inst.prefab) then
                    local idx = 0
                    for i, v in ipairs(songs) do if v == inst.prefab then idx = i end end
                    text = tostring(idx)
                elseif cansongbuffs > #songs then
                    text = "+"
                elseif cansongbuffs > 0 then
                    text = "0"
                else
                    text = ""
                end
            end
            if not self.imglisten2hm then
                self.imglisten2hm = true
                self.inst:ListenForEvent("inspirationdelta", function() if self.refreshitemtile2hm then self.refreshitemtile2hm(self) end end, ThePlayer)
                self.inst:ListenForEvent("inspirationsongchanged", function() if self.refreshitemtile2hm then self.refreshitemtile2hm(self) end end, ThePlayer)
            end
        end
        return nil, text
    end
    local function processsong(inst)
        inst.itemtilefn2hm = itemtilefn
        if not TheWorld.ismastersim then return end
        if inst.components.inventoryitem then
            local ChangeImageName = inst.components.inventoryitem.ChangeImageName
            inst.components.inventoryitem.ChangeImageName = function(self, prefab, ...)
                if prefab == (self.inst.prefab .. "_unavaliable") then return ChangeImageName(self, self.inst.prefab, ...) end
                return ChangeImageName(self, prefab, ...)
            end
        end
        inst:RemoveEventCallback("ondropped", inst.UpdateInvImage)
        inst.updateinvimage = nilfn
    end
    for k, v in pairs(song_defs) do AddPrefabPostInit(k, processsong) end
end
if wigfrid_rightself then
    -- 女武神右键自己战士重奏，最近嘲讽或恐惧过则重奏嘲讽或恐惧
    AddRightSelfAction("wathgrithr", 3, "sing_pre", function(inst, act)
        if TheWorld.ismastersim and act.doer and act.doer:IsValid() then
            local song = SpawnPrefab("battlesong_instant_revive")
            if song ~= nil then
                song.persists = false
                song:RemoveFromScene()
                song:DoTaskInTime(6, song.Remove)
                -- 支持覆盖效果
                if act.doer.overridesongfn2hm then
                    song.overridesongfn2hm = act.doer.overridesongfn2hm
                elseif song.components.rechargeable and act.doer.components.timer and act.doer.components.timer:TimerExists("instantrevive2hm") then
                    song.components.rechargeable:Discharge(act.doer.components.timer:GetTimeLeft("instantrevive2hm"))
                end
                act.invobject = song
                inst.rightselfaction2hm_handler = "sing_pre"
            else
                inst.rightselfaction2hm_handler = "sing_fail"
            end
        else
            inst.rightselfaction2hm_handler = "sing_fail"
        end
    end, function(act)
        if act.invobject and act.invobject.prefab == "battlesong_instant_revive" then
            local result, reason = ACTIONS.SING.fn(act)
            if result and act.invobject and not act.invobject.overridesongfn2hm and act.invobject.components.rechargeable and
                not act.invobject.components.rechargeable:IsCharged() and act.doer and act.doer.components.timer then
                act.doer.components.timer:StopTimer("instantrevive2hm")
                act.doer.components.timer:StartTimer("instantrevive2hm", TUNING.SKILLS.WATHGRITHR.BATTLESONG_INSTANT_COOLDOWN_HIGH)
            end
            return result, reason
        end
    end, STRINGS.NAMES.BATTLESONG_INSTANT_REVIVE)
    local function rightselfstrfn2hm(act)
        if act.doer and act.doer.rightselftype2hm then
            local type = act.doer.rightselftype2hm:value()
            if reprisesongtypes[type] then return reprisesongtypes[type] end
        end
    end
    AddPrefabPostInit("wathgrithr", function(inst)
        inst.rightselfstrfn2hm = rightselfstrfn2hm
        inst.rightselftype2hm = net_byte(inst.GUID, "rightself.type2hm")
        if not TheWorld.ismastersim then return end
        inst.rightselftype2hm:set(0)
    end)
end
if wigfrid_rightself and (wigfrid_hat or wigfrid_spear) then
    -- 特效
    local function addfx(target, fxname)
        if target and target:IsValid() then
            local x, y, z = target.Transform:GetWorldPosition()
            local fx = SpawnPrefab(fxname)
            if fx then fx.Transform:SetPosition(x, y, z) end
        end
    end
    local function AddEnemyDebuffFx(fx, target) target:DoTaskInTime(math.random() * 0.25, addfx, fx) end
    -- 某些友军可以给予武器
    local weaponprefabs = {}
    if hardmode and GetModConfigData("monster_change") and GetModConfigData("pigman") then
        table.insert(weaponprefabs, "pigman")
        table.insert(weaponprefabs, "bunnyman")
    end
    if GetModConfigData("Trade Fish with Merm") then table.insert(weaponprefabs, "merm") end
    -- 修理的装备都是临时耐久
    local function testnewowner(inst)
        if inst.equipbindowner2hm and inst.oldpercent2hm and inst.components.inventoryitem and (inst.components.armor or inst.components.finiteuses) then
            local self = inst.components.armor or inst.components.finiteuses
            local newpercent = self:GetPercent()
            if inst.equipbindowner2hm ~= inst.components.inventoryitem:GetGrandOwner() or (newpercent < inst.oldpercent2hm) then
                inst.equipbindowner2hm = nil
                inst:RemoveEventCallback("ondropped", testnewowner)
                inst:RemoveEventCallback("onputininventory", testnewowner)
                -- if newpercent > inst.oldpercent2hm then self:SetPercent(inst.oldpercent2hm) end -- 2025.9.10 melon:注释此处，不再是临时耐久
                inst.oldpercent2hm = nil
            end
        else
            inst.equipbindowner2hm = nil
            inst.oldpercent2hm = nil
            inst:RemoveEventCallback("ondropped", testnewowner)
            inst:RemoveEventCallback("onputininventory", testnewowner)
        end
    end
    local function makebackpercent(inst, target, oldpercent)
        inst.oldpercent2hm = inst.oldpercent2hm and math.min(oldpercent, inst.oldpercent2hm) or oldpercent
        if inst.equipbindowner2hm == nil then
            inst.equipbindowner2hm = target
            inst:ListenForEvent("onputininventory", testnewowner)
            inst:ListenForEvent("ondropped", testnewowner)
        end
    end
    local function repairarmorequip(self, equip, target)
        if equip.components.armor and not equip.components.armor:IsIndestructible() then
            local oldpercent = equip.components.armor:GetPercent()
            if oldpercent < 1 then
                equip.components.armor:SetPercent(math.max(oldpercent, math.min(1, oldpercent + (target == self.inst and 0.5 or 0.25))))
                local newpercent = equip.components.armor:GetPercent()
                if newpercent > oldpercent then
                    local recipe = AllRecipes[equip.prefab]
                    local rate = recipe and (self.inst.components.builder:KnowsRecipe(recipe) and 1 or 2) or 3
                    self:DoDelta((newpercent - oldpercent) * -10 * rate)
                    AddEnemyDebuffFx("battlesong_instant_panic_fx", target)
                    makebackpercent(equip, target, oldpercent)
                    return true
                end
            end
        end
    end
    -- 每次修理至少消耗33点激励值
    local function endhelp(self, oldcurrent)
        if self.current > 0 and oldcurrent - self.current < 100 / 3 then self.current = math.max(0, oldcurrent - 100 / 3) end
    end
    -- 重奏嘲讽可以修理护甲
    local function dohelparmor(self, inst)
        local dohelp
        local persistentdata = self.inst.components.persistent2hm.data
        if persistentdata.instantrepairgoodtime then persistentdata.instantrepairgoodtime = nil end
        local headequip = self.inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
        -- 记录皮肤
        local hatdata = persistentdata.hat
        if headequip and headequip.prefab == "wathgrithrhat" then
            hatdata = {skinname = headequip.skinname, skin_id = headequip.skin_id, alt_skin_ids = headequip.alt_skin_ids}
            persistentdata.hat = hatdata
        end
        local oldPVP2hm = TUNING.oldPVP2hm
        TUNING.oldPVP2hm = true
        local targets = self:FindFriendlyTargetsToInspire()
        TUNING.oldPVP2hm = oldPVP2hm
        local oldcurrent = self.current
        for _, target in ipairs(targets) do
            if target.components.inventory and not target:IsInLimbo() then
                local equip = target.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
                if equip ~= nil then
                    if repairarmorequip(self, equip, target) then
                        if self.current <= 0 then break end
                        dohelp = true
                    end
                else
                    local hat
                    if hatdata then
                        hat = SpawnPrefab("wathgrithrhat", hatdata.skinname, hatdata.skin_id, self.inst.userid)
                        if hatdata.alt_skin_ids then hat.alt_skin_ids = hatdata.alt_skin_ids end
                    else
                        hat = SpawnPrefab("wathgrithrhat")
                    end
                    hat.Transform:SetPosition(target.Transform:GetWorldPosition())
                    hat.components.armor:SetPercent(target == self.inst and 0.5 or 0.25)
                    if not target.components.inventory:Equip(hat) then
                        hat:Remove()
                    else
                        self:DoDelta(target == self.inst and -5 or -2.5)
                        AddEnemyDebuffFx("battlesong_instant_panic_fx", target)
                        if self.current <= 0 then break end
                    end
                    dohelp = true
                end
                local equip = target.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                if equip ~= nil and repairarmorequip(self, equip, target) then
                    if self.current <= 0 then break end
                    dohelp = true
                end
            end
        end
        if dohelp then endhelp(self, oldcurrent) end
    end
    -- -- 护甲持续可修理特效
    -- local function armorcanhelpfx(self, inst) 
    --     if inst.wigfridhelpfx2hm ~= nil then inst.wigfridhelpfx2hm:Remove() end
    --     inst.wigfridhelpfx2hm = SpawnPrefab("tophat_shadow_fx")
    --     inst.wigfridhelpfx2hm.entity:SetParent(inst.entity)
    --     inst.wigfridhelpfx2hm.Follower:FollowSymbol(inst.GUID, "swap_object", 50, -25, 0)
    -- end
    -- 重奏恐惧可以修理武器
    local function dohelpweapon(self, inst)
        local dohelp
        local persistentdata = self.inst.components.persistent2hm.data
        if persistentdata.instantrepairgoodtime then persistentdata.instantrepairgoodtime = nil end
        local handequip = self.inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        local weapondata = persistentdata.spear
        if handequip and handequip.prefab == "spear_wathgrithr" then
            weapondata = {skinname = handequip.skinname, skin_id = handequip.skin_id, alt_skin_ids = handequip.alt_skin_ids}
            persistentdata.spear = weapondata
        end
        local oldPVP2hm = TUNING.oldPVP2hm
        TUNING.oldPVP2hm = true
        local targets = self:FindFriendlyTargetsToInspire()
        TUNING.oldPVP2hm = oldPVP2hm
        local oldcurrent = self.current
        for _, target in ipairs(targets) do
            if target.components.inventory and
                ((target:HasTag("player") and target.components.inventory.isvisible) or table.contains(weaponprefabs, target.prefab)) and not target:IsInLimbo() then
                local equip = target.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                if equip ~= nil then
                    if equip.components.finiteuses and (not hardmode or
                        (not equip.components.finiteuses:IgnoresCombatDurabilityLoss() and equip.components.weapon and
                            (equip.components.weapon.attackrange or 0) <= 2 and (equip.components.weapon.attackwear or 1) > 0 and
                            not equip:HasTag("rangedweapon") and equip.components.projectile == nil and equip.components.weapon.projectile == nil)) then
                        local oldpercent = equip.components.finiteuses:GetPercent()
                        if oldpercent < 1 then
                            equip.components.finiteuses:SetPercent(math.max(oldpercent, math.min(1, oldpercent + (target == self.inst and 0.5 or 0.25))))
                            local newpercent = equip.components.finiteuses:GetPercent()
                            if newpercent > oldpercent then
                                local recipe = AllRecipes[equip.prefab]
                                local rate = recipe and (self.inst.components.builder:KnowsRecipe(recipe) and 1 or 2) or 3
                                self:DoDelta((newpercent - oldpercent) * -10 * rate)
                                AddEnemyDebuffFx("battlesong_instant_taunt_fx", target)
                                makebackpercent(equip, target, oldpercent)
                                if self.current <= 0 then break end
                                dohelp = true
                            end
                        end
                    end
                else
                    local spear
                    if weapondata then
                        spear = SpawnPrefab("spear_wathgrithr", weapondata.skinname, weapondata.skin_id, self.inst.userid)
                        if weapondata.alt_skin_ids then spear.alt_skin_ids = weapondata.alt_skin_ids end
                    else
                        spear = SpawnPrefab("spear_wathgrithr")
                    end
                    spear.Transform:SetPosition(target.Transform:GetWorldPosition())
                    spear.components.finiteuses:SetPercent(target == self.inst and 0.5 or 0.25)
                    if not target.components.inventory:Equip(spear) then
                        spear:Remove()
                    else
                        self:DoDelta(target == self.inst and -5 or -2.5)
                        AddEnemyDebuffFx("battlesong_instant_taunt_fx", target)
                        if self.current <= 0 then break end
                    end
                    dohelp = true
                end
            end
        end
        if dohelp then endhelp(self, oldcurrent) end
    end
    -- -- 武器持续可修理特效
    -- local function weaponcanhelpfx(self, inst)
    --     if inst.wigfridhelpfx2hm ~= nil then inst.wigfridhelpfx2hm:Remove() end
    --     inst.wigfridhelpfx2hm = SpawnPrefab("tophat_shadow_fx")
    --     inst.wigfridhelpfx2hm.entity:SetParent(inst.entity)
    --     inst.wigfridhelpfx2hm.Follower:FollowSymbol(inst.GUID, "swap_hat", 0, -100, 0)
    -- end
    if wigfrid_hat then
        reprisesongfns.battlesong_instant_taunt = {fn = dohelparmor, type = 1}
        reprisesongtypes[1] = "BATTLESONG_INSTANT_TAUNT"
        STRINGS.ACTIONS.RIGHTSELFACTION2HM.BATTLESONG_INSTANT_TAUNT = STRINGS.NAMES.BATTLESONG_INSTANT_REVIVE .. " " .. STRINGS.NAMES.BATTLESONG_INSTANT_TAUNT
    end
    if wigfrid_spear then
        reprisesongfns.battlesong_instant_panic = {fn = dohelpweapon, type = 2}
        reprisesongtypes[2] = "BATTLESONG_INSTANT_PANIC"
        STRINGS.ACTIONS.RIGHTSELFACTION2HM.BATTLESONG_INSTANT_PANIC = STRINGS.NAMES.BATTLESONG_INSTANT_REVIVE .. " " .. STRINGS.NAMES.BATTLESONG_INSTANT_PANIC
    end
end

-- 2025.9.10 melon:武器化的颤音、英勇美声颂加强  只是把覆盖写法(battlesongdefs.lua)改为兼容写法
if GetModConfigData("battlesong_durability_sanitygain") then
    AddPrefabPostInit("battlesong_durability", function(inst)
        if not TheWorld.ismastersim then return end
        inst.bufftask2hm = inst:DoTaskInTime(0,function(inst) -- 不加task覆盖不了妥协?
            local _ONAPPLY = inst.songdata.ONAPPLY
            inst.songdata.ONAPPLY = function(inst, target, ...)
                if target.components.debuffable ~= nil and target.components.debuffable:IsEnabled() then
                    inst:ListenForEvent("onattackother", function(attacker, data)
                        target.components.debuffable:AddDebuff("buff_attackbuff", "buff_attackbuff") -- 加伤
                    end, target)
                end
                if _ONAPPLY ~= nil then _ONAPPLY(inst, target, ...) end
            end
        end)
    end)
    AddPrefabPostInit("battlesong_sanityaura", function(inst)
        if not TheWorld.ismastersim then return end
        inst.bufftask2hm = inst:DoTaskInTime(0,function(inst) -- 不加task覆盖不了妥协?
            local _ONAPPLY = inst.songdata.ONAPPLY
            inst.songdata.ONAPPLY = function(inst, target, ...)
                if target.components.debuffable ~= nil and target.components.debuffable:IsEnabled() then
                    inst:ListenForEvent("onattackother", function(attacker, data) -- 骑乘不触发
                        if target.components.rider ~= nil and target.components.rider:IsRiding() then return end
                        target.components.debuffable:AddDebuff("buff_kitespeed", "buff_kitespeed") -- 加移速
                    end, target)
                end
                if _ONAPPLY ~= nil then _ONAPPLY(inst, target, ...) end
            end
        end)
    end)
end

-- 女武神直接右键矛盾
if GetModConfigData("aoespell change") then
    local function disableStatus(inst)
        inst.components.spellcaster.canuseontargets = false
        inst.components.spellcaster.canuseondead = false
        inst.components.spellcaster.canuseonpoint = false
        inst.components.spellcaster.canuseonpoint_water = false
        inst.components.spellcaster.spell = nil
        inst.components.spellcaster.spellfn = nil
        inst.reticule2hm:set(false)
    end
    local function enableStatus(inst)
        inst.components.spellcaster.spell = nilfn
        inst.components.spellcaster.spellfn = nilfn
        inst.components.spellcaster.canuseontargets = true
        inst.components.spellcaster.canuseondead = true
        inst.components.spellcaster.canuseonpoint = true
        inst.components.spellcaster.canuseonpoint_water = inst.components.aoetargeting and inst.components.aoetargeting.allowwater or false
        inst.reticule2hm:set(true)
    end
    local function UpdateStatus(inst)
        if not inst:IsValid() then return end
        local owner = inst.components.inventoryitem.owner
        -- 非常奇怪，莫名其妙会aoetargeting被禁用
        -- inst.components.rechargeable and inst.components.rechargeable:IsCharged()
        if inst.components.aoetargeting and inst.components.aoetargeting:IsEnabled() and inst.components.equippable and inst.components.equippable:IsEquipped() and
            owner and owner:IsValid() and owner:HasTag("player") and not owner:HasTag("playerghost") and
            (inst.components.aoetargeting.allowriding or not (owner.components.rider and owner.components.rider:IsRiding())) then
            enableStatus(inst)
        else
            disableStatus(inst)
        end
    end
    local function onequip(inst, data)
        if data.owner and data.owner:HasTag("player") then
            if not (inst.components.aoetargeting and inst.components.aoetargeting.allowriding) then
                inst:ListenForEvent("mounted", inst._updatestatus, data.owner)
                inst:ListenForEvent("dismounted", inst._updatestatus, data.owner)
            end
            inst:ListenForEvent("death", inst._updatestatus, data.owner)
        end
        UpdateStatus(inst)
    end
    local function onunequip(inst, data)
        if data.owner and data.owner:HasTag("player") then
            inst:RemoveEventCallback("mounted", inst._updatestatus, data.owner)
            inst:RemoveEventCallback("dismounted", inst._updatestatus, data.owner)
            inst:RemoveEventCallback("death", inst._updatestatus, data.owner)
        end
        UpdateStatus(inst)
    end
    -- 2025.6.28 melon:加个判空，不然换人会报x空
    local function Lightning_ReticuleMouseTargetFn(inst, mousepos)
        if mousepos ~= nil then
            local x, y, z = inst.Transform:GetWorldPosition()
            if x==nil or y==nil or z==nil then return nil end -- melon:换人会报空
            local dx = mousepos.x - x
            local dz = mousepos.z - z
            local l = dx * dx + dz * dz
            if l <= 0 then
                return inst.components.reticule.targetpos
            end
            l = 6.5 / math.sqrt(l)
            return Vector3(x + dx * l, 0, z + dz * l)
        end
    end
    local function Lightning_ReticuleUpdatePositionFn(inst, pos, reticule, ease, smoothing, dt)
        local x, y, z = inst.Transform:GetWorldPosition()
        if x==nil or y==nil or z==nil then return end -- melon:换人会报空
        reticule.Transform:SetPosition(x, 0, z)
        local rot = -math.atan2(pos.z - z, pos.x - x) / DEGREES
        if ease and dt ~= nil then
            local rot0 = reticule.Transform:GetRotation()
            local drot = rot - rot0
            rot = Lerp((drot > 180 and rot0 + 360) or (drot < -180 and rot0 - 360) or rot0, rot, dt * smoothing)
        end
        reticule.Transform:SetRotation(rot)
    end
    -- 2025.6.28 end
    local function EnableReticule(inst, enable)
        if inst.components.aoetargeting then
            -- 2025.6.28 melon:改2个函数
            inst.components.aoetargeting.reticule.mousetargetfn = Lightning_ReticuleMouseTargetFn
            inst.components.aoetargeting.reticule.updatepositionfn = Lightning_ReticuleUpdatePositionFn
            if enable then
                if inst.components.reticule == nil then
                    inst:AddComponent("reticule")
                    for k, v in pairs(inst.components.aoetargeting.reticule) do inst.components.reticule[k] = v end
                    inst.components.reticule.ispassableatallpoints = inst.components.aoetargeting.alwaysvalid
                    if ThePlayer and ThePlayer.components.playercontroller ~= nil and ThePlayer.replica and ThePlayer.replica.inventory and
                        ThePlayer.replica.inventory:IsHolding(inst) then ThePlayer.components.playercontroller:RefreshReticule() end
                end
            else
                if inst.components.reticule ~= nil then
                    inst:RemoveComponent("reticule")
                    if ThePlayer and ThePlayer.components.playercontroller ~= nil and ThePlayer.replica and ThePlayer.replica.inventory and
                        ThePlayer.replica.inventory:IsHolding(inst) then ThePlayer.components.playercontroller:RefreshReticule() end
                end
            end
        end
    end
    local function actfn(act, inst)
        if act.action == ACTIONS.CASTSPELL then
            act.distance = math.huge
            if not act.pos and act.target then
                act.pos = DynamicPosition(not TheNet:IsDedicated() and TheInput:GetWorldPosition() or act.target:GetPosition())
            end
        end
    end
    local function OnreticuleDirty(inst) EnableReticule(inst, inst.reticule2hm:value()) end
    local function processaoetargeting(inst)
        if inst.components.aoetargeting == nil then return end
        inst.components.aoetargeting.StopTargeting = nilfn
        inst.components.aoetargeting.StartTargeting = nilfn
        inst.actfn2hm = actfn
        inst.spellaoe2hm = true
        inst.spelltype = string.upper(inst.prefab)
        if STRINGS.ACTIONS.CASTSPELL[inst.spelltype] == nil then STRINGS.ACTIONS.CASTSPELL[inst.spelltype] = STRINGS.ACTIONS.CASTAOE[inst.spelltype] end
        inst.reticule2hm = net_bool(inst.GUID, "spell.reticule2hm", "spellreticule2hmdirty")
        if not TheNet:IsDedicated() then inst:ListenForEvent("spellreticule2hmdirty", OnreticuleDirty) end
        if not TheWorld.ismastersim then return end
        if not inst.components.spellcaster and inst.components.aoespell then
            inst:AddComponent("spellcaster")
            inst.components.spellcaster.spell = nilfn
            inst.components.spellcaster.spellfn = nilfn
            inst.components.spellcaster.canuseontargets = true
            inst.components.spellcaster.canuseondead = true
            inst.components.spellcaster.canuseonpoint = true
            inst.components.spellcaster.canuseonpoint_water = inst.components.aoetargeting.allowwater
            inst.components.spellcaster.canusefrominventory = false
            inst.components.spellcaster.can_cast_fn = truefn
            local range = inst.components.aoetargeting.range
            inst.components.spellcaster.CanCast = function(self, doer, target, pos)
                if pos and doer and doer:IsValid() and not inst:HasTag("shield") then
                    local x, y, z = pos:Get()
                    local x1, y1, z1 = doer.Transform:GetWorldPosition()
                    local rangesq = distsq(x, z, x1, z1)
                    if rangesq == 0 then
                        local rot = doer.Transform:GetRotation() * DEGREES
                        pos.x = x1 + math.cos(rot) * range
                        pos.z = z1 - math.sin(rot) * range
                    else
                        local rate = range / math.sqrt(rangesq)
                        pos.x = x1 + (x - x1) * rate
                        pos.z = z1 + (z - z1) * rate
                    end
                end
                local alwayspassable, allowwater, deployradius, allowriding
                local aoetargeting = self.inst.components.aoetargeting
                if aoetargeting then
                    if not aoetargeting:IsEnabled() then return false end
                    alwayspassable = aoetargeting.alwaysvalid
                    allowwater = aoetargeting.allowwater
                    deployradius = aoetargeting.deployradius
                    allowriding = aoetargeting.allowriding
                end
                if not allowriding and doer.components.rider ~= nil and doer.components.rider:IsRiding() then return false end
                return TheWorld.Map:CanCastAtPoint(pos, alwayspassable, allowwater, deployradius)
            end
            local aoespellfn = inst.components.aoespell.spellfn
            inst.components.spellcaster.CastSpell = function(self, target, pos, doer)
                local success, reason = true, nil
                if aoespellfn then
                    success, reason = aoespellfn(self.inst, doer, pos)
                    if success == nil and reason == nil then success = true end
                end
                return success, reason
            end
            inst:RemoveComponent("aoespell")
            inst:ListenForEvent("enableddirty", UpdateStatus)
            inst:ListenForEvent("equipped", onequip)
            inst:ListenForEvent("unequipped", onunequip)
            inst._updatestatus = function() UpdateStatus(inst) end
        end
    end
    AddPrefabPostInit("spear_wathgrithr_lightning", processaoetargeting)
    AddPrefabPostInit("spear_wathgrithr_lightning_charged", processaoetargeting)
    AddPrefabPostInit("wathgrithr_shield", processaoetargeting)
    -- local fn = ACTIONS.CASTSPELL.fn
    -- ACTIONS.CASTSPELL.fn = function(act)
    --     if act and act.invobject and act.invobject.spellaoe2hm then return ACTIONS.CASTAOE.fn(act) end
    --     return fn(act)
    -- end
    AddStategraphPostInit("wilson", function(sg)
        local _OldCASTSPELL = sg.actionhandlers[ACTIONS.CASTSPELL].deststate
        local _OldCASTAOE = sg.actionhandlers[ACTIONS.CASTAOE].deststate
        sg.actionhandlers[ACTIONS.CASTSPELL].deststate = function(inst, action, ...)
            if action.invobject and action.invobject.spellaoe2hm then
                return _OldCASTAOE(inst, action, ...)
            else
                return _OldCASTSPELL(inst, action, ...)
            end
        end
        local onenter = sg.states.combat_lunge.onenter
        sg.states.combat_lunge.onenter = function(inst, data, ...) onenter(inst, data, ...) end
    end)
    AddStategraphPostInit("wilson_client", function(sg)
        local _OldCASTSPELL = sg.actionhandlers[ACTIONS.CASTSPELL].deststate
        local _OldCASTAOE = sg.actionhandlers[ACTIONS.CASTAOE].deststate
        sg.actionhandlers[ACTIONS.CASTSPELL].deststate = function(inst, action, ...)
            if action.invobject and action.invobject.spellaoe2hm then
                return _OldCASTAOE(inst, action, ...)
            else
                return _OldCASTSPELL(inst, action, ...)
            end
        end
    end)
    local NEWCONSTANT2HM = ModManager:GetMod("workshop-3191348907") or ModManager:GetMod("workshop-3645179905")-- 判断新界是否开启
    AddComponentPostInit("playercontroller", function(self)
        local _IsAOETargeting = self.IsAOETargeting
        -- 2025.7.9 melon:修复和新界一起开用不了左键+右键的问题.目前没找到好的写法，兼容性写法会导致矛盾用不了
        self.IsAOETargeting = function(self, ...)
            if NEWCONSTANT2HM then -- 2025.10.24
                return self.reticule ~= nil and self.reticule.inst.components.aoetargeting ~= nil and self.reticule.inst.spellaoe2hm == nil or self.remote_AOETARGET -- 新界的remote_AOETARGET
            else
                return _IsAOETargeting and _IsAOETargeting(self, ...) and self.reticule ~= nil and self.reticule.inst.spellaoe2hm == nil
            end
        end
    end)
end

--冲刺无前摇
if GetModConfigData("Valkyrie thunder sprints without shaking") then
    TUNING.WATHGRITHR_SHIELD_COOLDOWN_ONEQUIP = 1 -- 2025.7.19 melon:装备盾的cd减1秒
    AddPrefabPostInit("wathgrithr", function(inst)
        -- 检查 inst.sg 是否存在
        if inst.sg and inst.sg.sg and inst.sg.sg.states then
            -- 闪电奔袭无前摇
            ----------------------------------------combat_lunge_start
            local combat_lunge_start = inst.sg.sg.states["combat_lunge_start"]
            if combat_lunge_start then
                combat_lunge_start.onenter = function(inst) 
                    inst.components.locomotor:Stop() -- 停止角色移动
                    -- 这个BufferedAction中，有pushEvent(combat_lunge)的过程
                    if inst.bufferedaction then
                        local failfn = function()
                            if inst and inst:IsValid() then
                                inst:DoTaskInTime(0, function() inst.sg:GoToState("idle") end)
                            end
                        end
                        inst.bufferedaction:AddFailAction(failfn)
                    end
                    inst:PerformBufferedAction()
                end
            end
            ----------------------------------------combat_lunge
            local combat_lunge = inst.sg.sg.states["combat_lunge"]
            -- 检查 combat_lunge 是否存在
            if combat_lunge then
                local original_onenter = combat_lunge.onenter
                
                combat_lunge.onenter = function(inst, data) 
                    if data ~= nil and
                        data.targetpos ~= nil and
                        data.weapon ~= nil and
                        data.weapon.components.aoeweapon_lunge ~= nil 
                        --and inst.AnimState:IsCurrentAnimation("lunge_lag") 
                    then
                        -- 施法过程不可打断
                        inst.sg:AddStateTag("nointerrupt")
                        
                        inst.AnimState:PlayAnimation("lunge_pst")
                        inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_weapon")
                        local pos = inst:GetPosition()
                        local dir
                        if pos.x ~= data.targetpos.x or pos.z ~= data.targetpos.z then
                            dir = inst:GetAngleToPoint(data.targetpos)
                            inst.Transform:SetRotation(dir)
                        end
                        if data.weapon.components.aoeweapon_lunge:DoLunge(inst, pos, data.targetpos) then
                            inst.SoundEmitter:PlaySound(data.weapon.components.aoeweapon_lunge.sound or "dontstarve/common/lava_arena/fireball")

                            --Make sure we don't land directly on world boundary, where
                            --physics may end up popping in the wrong direction to void
                            local x, z = data.targetpos.x, data.targetpos.z
                            if dir then
                                local theta = dir * DEGREES
                                local cos_theta = math.cos(theta)
                                local sin_theta = math.sin(theta)
                                local x1, z1
                                local map = TheWorld.Map
                                if not map:IsPassableAtPoint(x, 0, z) then
                                    --scan for nearby land in case we were slightly off
                                    --adjust position slightly toward valid ground
                                    if map:IsPassableAtPoint(x + 0.1 * cos_theta, 0, z - 0.1 * sin_theta) then
                                        x1 = x + 0.5 * cos_theta
                                        z1 = z - 0.5 * sin_theta
                                    elseif map:IsPassableAtPoint(x - 0.1 * cos_theta, 0, z + 0.1 * sin_theta) then
                                        x1 = x - 0.5 * cos_theta
                                        z1 = z + 0.5 * sin_theta
                                    end
                                else
                                    --scan to make sure we're not just on the edge of land, could result in popping to the wrong side
                                    --adjust position slightly away from invalid ground
                                    if not map:IsPassableAtPoint(x + 0.1 * cos_theta, 0, z - 0.1 * sin_theta) then
                                        x1 = x - 0.4 * cos_theta
                                        z1 = z + 0.4 * sin_theta
                                    elseif not map:IsPassableAtPoint(x - 0.1 * cos_theta, 0, z + 0.1 * sin_theta) then
                                        x1 = x + 0.4 * cos_theta
                                        z1 = z - 0.4 * sin_theta
                                    end
                                end

                                if x1 and map:IsPassableAtPoint(x1, 0, z1) then
                                    x, z = x1, z1
                                end
                            end

                            local mass = inst.Physics:GetMass()
                            if mass > 0 then
                                inst.sg.statemem.restoremass = mass
                                inst.Physics:SetMass(mass + 1)
                            end
                            inst.Physics:Teleport(x, 0, z)

                            if not data.skipflash and inst.sg.currentstate == "combat_lunge" then
                                inst.components.bloomer:PushBloom("lunge", "shaders/anim.ksh", -2)
                                inst.components.colouradder:PushColour("lunge", 1, 1, 0, 0)
                                inst.sg.statemem.flash = 1
                            end
                            
                            -- 成功
                            return
                        end
                    end
                    -- Failed
                    inst.sg:GoToState("idle", true)
                end
            end
        end
    end)
end


-- 无开关-------------------------------------------------------------------------------



---------------------------------------------------------------------------------------
-- 2025.10.24 melon:留存完全无前后摇的代码
-- if GetModConfigData("Valkyrie thunder sprints without shaking") then
--     TUNING.WATHGRITHR_SHIELD_COOLDOWN_ONEQUIP = 1 -- 2025.7.19 melon:装备盾的cd减1秒
--     AddPrefabPostInit("wathgrithr", function(inst)
--         -- 检查 inst.sg 是否存在
--         if inst.sg and inst.sg.sg and inst.sg.sg.states then
--             -- 闪电奔袭无前摇
--             ----------------------------------------combat_lunge_start
--             local combat_lunge_start = inst.sg.sg.states["combat_lunge_start"]
--             if combat_lunge_start then
--                 combat_lunge_start.onenter = function(inst) 
--                     inst.components.locomotor:Stop() -- 停止角色移动
--                     -- 这个BufferedAction中，有pushEvent(combat_lunge)的过程
--                     if inst.bufferedaction then
--                         local failfn = function()
--                             if inst and inst:IsValid() then
--                                 inst:DoTaskInTime(0, function() inst.sg:GoToState("idle") end)
--                             end
--                         end
--                         inst.bufferedaction:AddFailAction(failfn)
--                     end
--                     inst:PerformBufferedAction()
--                 end
--             end

--             ----------------------------------------combat_lunge
--             local combat_lunge = inst.sg.sg.states["combat_lunge"]
--             -- 检查 combat_lunge 是否存在
--             if combat_lunge then
--                 local original_onenter = combat_lunge.onenter
                
--                 combat_lunge.onenter = function(inst, data) 
--                     if data ~= nil and
--                         data.targetpos ~= nil and
--                         data.weapon ~= nil and
--                         data.weapon.components.aoeweapon_lunge ~= nil 
--                         --and inst.AnimState:IsCurrentAnimation("lunge_lag") 
--                     then
--                         -- 施法过程不可打断
--                         inst.sg:AddStateTag("nointerrupt")
--                         -- inst.AnimState:PlayAnimation("lunge_pst") -- 2025.7.19 melon:去掉后摇
--                         inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_weapon")
--                         local pos = inst:GetPosition()
--                         local dir
--                         if pos.x ~= data.targetpos.x or pos.z ~= data.targetpos.z then
--                             dir = inst:GetAngleToPoint(data.targetpos)
--                             inst.Transform:SetRotation(dir)
--                         end
--                         if data.weapon.components.aoeweapon_lunge:DoLunge(inst, pos, data.targetpos) then
--                             inst.SoundEmitter:PlaySound(data.weapon.components.aoeweapon_lunge.sound or "dontstarve/common/lava_arena/fireball")

--                             --Make sure we don't land directly on world boundary, where
--                             --physics may end up popping in the wrong direction to void
--                             local x, z = data.targetpos.x, data.targetpos.z
--                             if dir then
--                                 local theta = dir * DEGREES
--                                 local cos_theta = math.cos(theta)
--                                 local sin_theta = math.sin(theta)
--                                 local x1, z1
--                                 local map = TheWorld.Map
--                                 if not map:IsPassableAtPoint(x, 0, z) then
--                                     --scan for nearby land in case we were slightly off
--                                     --adjust position slightly toward valid ground
--                                     if map:IsPassableAtPoint(x + 0.1 * cos_theta, 0, z - 0.1 * sin_theta) then
--                                         x1 = x + 0.5 * cos_theta
--                                         z1 = z - 0.5 * sin_theta
--                                     elseif map:IsPassableAtPoint(x - 0.1 * cos_theta, 0, z + 0.1 * sin_theta) then
--                                         x1 = x - 0.5 * cos_theta
--                                         z1 = z + 0.5 * sin_theta
--                                     end
--                                 else
--                                     --scan to make sure we're not just on the edge of land, could result in popping to the wrong side
--                                     --adjust position slightly away from invalid ground
--                                     if not map:IsPassableAtPoint(x + 0.1 * cos_theta, 0, z - 0.1 * sin_theta) then
--                                         x1 = x - 0.4 * cos_theta
--                                         z1 = z + 0.4 * sin_theta
--                                     elseif not map:IsPassableAtPoint(x - 0.1 * cos_theta, 0, z + 0.1 * sin_theta) then
--                                         x1 = x + 0.4 * cos_theta
--                                         z1 = z - 0.4 * sin_theta
--                                     end
--                                 end

--                                 if x1 and map:IsPassableAtPoint(x1, 0, z1) then
--                                     x, z = x1, z1
--                                 end
--                             end

--                             local mass = inst.Physics:GetMass()
--                             if mass > 0 then
--                                 inst.sg.statemem.restoremass = mass
--                                 inst.Physics:SetMass(mass + 1)
--                             end
--                             inst.Physics:Teleport(x, 0, z)

--                             if not data.skipflash and inst.sg.currentstate == "combat_lunge" then
--                                 inst.components.bloomer:PushBloom("lunge", "shaders/anim.ksh", -2)
--                                 inst.components.colouradder:PushColour("lunge", 1, 1, 0, 0)
--                                 inst.sg.statemem.flash = 1
--                             end
--                             -- 2025.7.19 melon:去掉后摇需要idle
--                             inst.sg:GoToState("idle", true)
--                             -- 成功
--                             return
--                         end
--                     end
--                     -- Failed
--                     inst.sg:GoToState("idle", true)
--                 end
--             end
--         end
--     end)
-- end
--------------------------------------------------------------------------------------------
-- 2025.9.19 melon:没有这个ONINSTANTALLIES感觉代码没用到，所以注释一下看看------------------
-- local function HasFriendlyLeader(target, singer, PVP_enabled)
--     local target_leader = (target.components.follower ~= nil) and target.components.follower.leader or nil
--     if target_leader and target_leader.components.inventoryitem then
--         target_leader = target_leader.components.inventoryitem:GetGrandOwner()
--         -- 如果领导者没有所有者
--         if target_leader == nil then return not PVP_enabled end
--     end
--     -- 判断目标是否有领导者，且领导者是歌手，或者在非 PVP 模式下领导者是玩家
--     -- 或者在非 PVP 模式下，目标是被驯化的生物
--     -- 或者在非 PVP 模式下，目标是被盐化的生物
--     return (target_leader ~= nil and (target_leader == singer or (not PVP_enabled and target_leader:HasTag("player"))))
--         or (not PVP_enabled and target.components.domesticatable and target.components.domesticatable:IsDomesticated())
--         or (not PVP_enabled and target.components.saltlicker and target.components.saltlicker.salted)
-- end

-- local INSTANT_TARGET_MUST_HAVE_TAGS = {"_combat", "_health"}
-- local INSTANT_ALLY_CANTHAVE_TAGS = { "INLIMBO", "epic", "structure", "butterfly", "wall", "balloon", "groundspike", "smashable"}
-- AddComponentPostInit("singinginspiration", function(self)
--     local _InstantInspire = self.InstantInspire
--     self.InstantInspire = function(self, songdata)
--         _InstantInspire(self, songdata)
--         -- 检查是否有针对盟友的即时激励函数
--         local PVP_enabled = TheNet:GetPVPEnabled() -- 获取 PVP 模式的开启状态
--         local fn = songdata.ONINSTANTALLIES -- 获取歌曲数据中针对盟友的即时激励函数   melon:没有这个ONINSTANTALLIES
--         if fn ~= nil then
--             -- 获取当前实体的世界坐标
--             local x, y, z = self.inst.Transform:GetWorldPosition()
--             -- 查找的实体必须拥有 INSTANT_TARGET_MUST_HAVE_TAGS 中的标签，且不能拥有 INSTANT_ALLY_CANTHAVE_TAGS 中的标签
--             local entities_near_me = TheSim:FindEntities(x, y, z, self.attach_radius, INSTANT_TARGET_MUST_HAVE_TAGS, INSTANT_ALLY_CANTHAVE_TAGS)
--             -- 遍历找到的所有实体
--             for _, ent in ipairs(entities_near_me) do
--                 -- 判断实体是否为当前实体本身，或者在非 PVP 模式下是玩家，或者有友好的领导者
--                 if ent == self.inst or ent:HasTag("player") and not PVP_enabled or HasFriendlyLeader(ent, self.inst, PVP_enabled) then
--                     fn(self.inst, ent)
--                 end
--             end
--         end
--     end
-- end)

-- 2025.4.10 melon:有bug先去掉----------------------
-- --武神快速上牛
-- if GetModConfigData("Quick loading") then
--     -- 跳跃前处理函数
--     local function Lighting_OnLeapPre(inst, doer, startpos, endpos)
--         -- 在落点周围2单位半径内寻找可骑乘的实体
--         for _, v in pairs(TheSim:FindEntities(endpos.x, endpos.y, endpos.z, 2)) do
--             -- 检查实体是否可骑乘且有鞍无骑手
--             if v.components and v.components.rideable and v.components.rideable.saddle and not v.components.rideable.rider then
--                 doer.components.rider:Mount(v, true)  -- 自动骑乘该实体
--                 return
--             end
--         end
--     end

--     -- 跳跃完成时处理函数
--     local function Lightning_OnLeap(inst, doer, startingpos, targetpos)
--         -- 生成超级跳跃特效
--         local fx = SpawnPrefab("superjump_fx")
--         if fx then
--             fx:SetTarget(inst)
--         end
--         -- 触发冷却
--         if inst.components.rechargeable then
--             inst.components.rechargeable:Discharge(inst._cooldown)
--         end

--         -- 在落点生成闪电特效
--         local lightning = SpawnPrefab("lightning")
--         if lightning then
--             lightning.Transform:SetPosition(targetpos:Get())
--         end
--     end

--     -- 定义一个通用的修改武器函数
--     local function ModifyWeapon(weapon_prefab)
--         AddPrefabPostInit(weapon_prefab, function(inst)
--             -- 添加超级跳跃标签
--             inst:AddTag("superjump")

--             -- 仅服务端执行后续修改
--             if not TheWorld.ismastersim then return inst end

--             -- 添加AOE跳跃组件
--             inst:AddTag("aoeweapon_leap")  -- 添加组件标识标签
--             inst:AddComponent("aoeweapon_leap")  -- 添加自定义组件（需确保组件已定义）
--             inst.components.aoeweapon_leap:SetAOERadius(2.5)  -- 设置跳跃影响半径
--             inst.components.aoeweapon_leap:SetOnLeaptFn(Lightning_OnLeap)  -- 绑定跳跃完成回调
--             inst.components.aoeweapon_leap:SetOnPreLeapFn(Lighting_OnLeapPre)  -- 绑定跳跃前回调

--             -- 修改装备行为
--             local oldonequipfn = inst.components.equippable.onequipfn
--             local oldonunequipfn = inst.components.equippable.onunequipfn

--             inst.components.equippable:SetOnEquip(function(inst, owner)
--                 ACTIONS.MOUNT.distance = 50  -- 修改骑乘动作的检测距离为50（原版可能不同）
--                 if oldonequipfn then
--                     oldonequipfn(inst, owner)  -- 保留原版装备逻辑
--                 end
--             end)

--             inst.components.equippable:SetOnUnequip(function(inst, owner)
--                 ACTIONS.MOUNT.distance = nil  -- 重置骑乘检测距离
--                 if oldonunequipfn then
--                     oldonunequipfn(inst, owner)  -- 保留原版卸除逻辑
--                 end
--             end)
--         end)
--     end

--     -- 修改普通闪电矛
--     ModifyWeapon("spear_wathgrithr_lightning")

--     -- 修改充能奔雷矛
--     ModifyWeapon("spear_wathgrithr_lightning_charged")

--     -- 保存原始的 ACTIONS.MOUNT 动作执行函数
--     local old_mount_fn = ACTIONS.MOUNT.fn

--     -- 重写 ACTIONS.MOUNT 的执行函数
--     ACTIONS.MOUNT.fn = function(act)
--         -- act.doer 表示执行该动作的实体，通常是玩家角色
--         -- 获取该实体手部装备的物品
--         local weapon = act.doer.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
--         -- 检查手部是否有装备，并且装备的预制体名称是否为奔雷矛或充能奔雷矛
--         if weapon and (weapon.prefab == "spear_wathgrithr_lightning" or weapon.prefab == "spear_wathgrithr_lightning_charged") then
--             -- 如果满足条件，触发一个名为 "combat_superjump" 的事件
--             -- 事件携带两个参数：targetpos 为目标位置（即要骑乘的目标的位置），weapon 为当前装备的武器
--             act.doer:PushEvent("combat_superjump", { targetpos = act.target:GetPosition(), weapon = weapon })
--             -- 返回 true 表示该动作已被处理
--             return true
--         else
--             -- 如果不满足条件，调用原始的骑乘执行函数
--             return old_mount_fn(act)
--         end
--     end

--     -- 定义一个处理骑乘动作的函数，用于状态图动作处理
--     local function mountHandler(inst, action)
--         -- 获取实体手部装备的物品
--         local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
--         -- 检查手部是否有装备，并且装备的预制体名称是否为奔雷矛或充能奔雷矛
--         if weapon and (weapon.prefab == "spear_wathgrithr_lightning" or weapon.prefab == "spear_wathgrithr_lightning_charged") then
--             -- 如果满足条件，返回 "combat_superjump_start"，表示应该进入战斗超级跳跃开始的状态
--             return "combat_superjump_start"
--         else
--             -- 如果不满足条件，返回 "doshortaction"，表示执行普通的短动作状态
--             return "doshortaction"
--         end
--     end

--     -- 为 'wilson' 角色的状态图添加动作处理程序
--     -- 当 'wilson' 执行 ACTIONS.MOUNT 动作时，调用 mountHandler 函数来处理
--     AddStategraphActionHandler('wilson', ActionHandler(ACTIONS.MOUNT, mountHandler))
--     -- 为 'wilson_client' 角色的状态图添加动作处理程序
--     -- 同样，当 'wilson_client' 执行 ACTIONS.MOUNT 动作时，调用 mountHandler 函数来处理
--     AddStategraphActionHandler('wilson_client', ActionHandler(ACTIONS.MOUNT, mountHandler))

--     -- 确保事件处理逻辑存在
--     local function OnCombatSuperjump(inst, data)
--         if inst.components.aoeweapon_leap then
--             inst.components.aoeweapon_leap:DoLeap(data.targetpos, data.weapon)
--         end
--     end

--     -- 为玩家添加事件处理函数
--     AddPlayerPostInit(function(player)
--         player:ListenForEvent("combat_superjump", OnCombatSuperjump)
--     end)
-- end

-- --更好的战歌
-- -- if GetModConfigData("Sprint without moving forward") then

-- -- end

-- --攻击返还cd
-- if GetModConfigData("Sprint without moving forward") then
-- GLOBAL.setmetatable(env,{__index=function(t,k) return GLOBAL.rawget(GLOBAL,k) end})


-- -- 强化版攻击充能函数
-- local function AttackCanCharge(prefabSelf)
--     -- 延迟确保组件初始化
--     prefabSelf:DoTaskInTime(0, function()
--         -- 防御性检查层级
--         if not prefabSelf:IsValid() then
--             print("[WARNING] 无效的武器实例:", prefabSelf.prefab)
--             return
--         end
        
--         -- 确保武器组件存在
--         if not prefabSelf.components.weapon then
--             print("[ERROR] 武器缺少weapon组件:", prefabSelf.prefab)
--             return
--         end

--         -- 保留原始攻击回调
--         local original_onattack = prefabSelf.components.weapon.onattack
        
--         -- 设置新的攻击回调
--         prefabSelf.components.weapon:SetOnAttack(function(inst, attacker, target)
--             -- 执行原始回调（如果存在）
--             if type(original_onattack) == "function" then
--                 original_onattack(inst, attacker, target)
--             end

--             -- 电击特效（带有效性检查）
--             if attacker and attacker:IsValid() 
--                 and target and target:IsValid() 
--                 and inst.CanElectrocuteTarget then  -- 确保方法存在
                
--                 if inst:CanElectrocuteTarget(target) then
--                     SpawnPrefab("electrichitsparks"):AlignToTarget(target, attacker, true)
--                 end
--             end

--             -- 充能逻辑（带组件检查）
--             if inst.components.rechargeable then
--                 local current_percent = inst.components.rechargeable:GetPercent()
--                 local new_percent = math.min(current_percent + 0.3, 1.0)
--                 inst.components.rechargeable:SetPercent(new_percent)
--             else
--                 print("[WARNING] 武器缺少充能组件:", inst.prefab)
--             end
--         end)
--     end)
-- end

-- -- 安全注册武器修改
-- AddPrefabPostInit("spear_wathgrithr_lightning", function(inst)
--     if inst.components.weapon then  -- 预检查武器组件
--         AttackCanCharge(inst)
--     else
--         print("[ERROR] 奔雷矛预制体缺少weapon组件")
--     end
-- end)

-- AddPrefabPostInit("spear_wathgrithr_lightning_charged", function(inst)
--     if inst.components.weapon then
--         AttackCanCharge(inst)
--     else
--         print("[ERROR] 充能奔雷矛预制体缺少weapon组件")
--     end
-- end)
-- end