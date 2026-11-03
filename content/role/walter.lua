-- Independent character switches; shared SG callbacks must test the attacker.
local walterEnabled = GetModConfigData("walter")
local wixieEnabled = TUNING.DSTU and GetModConfigData("wixie")
local function Enabled(owner)
    if owner ~= nil and owner.components ~= nil and owner.components.inventoryitem ~= nil then
        owner = owner.components.inventoryitem.owner or owner
    end
    if owner ~= nil and owner.prefab == "wixie" then return wixieEnabled end
    return walterEnabled
end

-- SpeedUpState2hm rewrites timeline entries. Use an actor-local copy so Walter
-- and Wixie (or two players with different hunger) never change each other's SG.
local function PrivateState(inst, state)
    local current = inst.sg.currentstate
    if current ~= nil and current.slingshot_source2hm == state then return current end
    local private = {}
    for key, value in pairs(state) do private[key] = value end
    -- State:HandleEvent and other engine methods live on the class metatable.
    setmetatable(private, getmetatable(state))
    private.slingshot_source2hm = state
    private.rate2hm, private.entities2hm = nil, nil
    if state.timeline ~= nil then
        private.timeline = {}
        for i, entry in ipairs(state.timeline) do
            local copy = {}
            for key, value in pairs(entry) do copy[key] = value end
            setmetatable(copy, getmetatable(entry))
            copy.time, copy.time2hm = entry.time2hm or entry.time, nil
            private.timeline[i] = copy
        end
    end
    inst.sg.currentstate = private
    return private
end

if TUNING.DSTU and TUNING.WIXIE_HEALTH then
    -- 烟花弹跳
    local radius = 0.5
    local function awayfirecrackers(inst)
        inst.index2hm = inst.index2hm + 1
        if inst.index2hm > 5 then
            inst.xdir2hm = math.random() < 0.5
            inst.zdir2hm = math.random() < 0.5
        end
        local x, y, z = inst.Transform:GetWorldPosition()
        inst.Transform:SetPosition(x + (inst.xdir2hm and radius or -radius), y, z + (inst.zdir2hm and radius or -radius))
    end
    local function startfirecrackers(inst)
        if not Enabled(inst.attacker) then return end
        inst.xdir2hm = math.random() < 0.5
        inst.zdir2hm = math.random() < 0.5
        inst.index2hm = 0
        inst:DoPeriodicTask(0.1, awayfirecrackers)
    end
    AddPrefabPostInit("firecrackers_slingshot", function(inst)
        if not TheWorld.ismastersim then return end
        inst:ListenForEvent("onignite", function(i) i:DoTaskInTime(0, startfirecrackers) end)
    end)
    -- 连发漩涡和地震弱化
    local function clearinst(inst)
        if not Enabled(inst.attacker) then return end
        local x, y, z = inst.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities(x, y, z, 5, {"shadowtalker"})
        for i, v in ipairs(ents) do
            if v and v:IsValid() and v ~= inst and v.prefab == inst.prefab and v.attacker == inst.attacker then v:DoTaskInTime(0, v.Remove) end
        end
    end
    AddPrefabPostInit("slingshot_vortex", function(inst)
        if not TheWorld.ismastersim then return end
        inst:DoTaskInTime(0, clearinst)
    end)
    AddPrefabPostInit("slingshot_tremors", function(inst)
        if not TheWorld.ismastersim then return end
        inst:DoTaskInTime(0, clearinst)
    end)
    -- 弹弓蓄力动作用时1.7倍，wixie1.6倍,且饥饿越低攻速越慢
    local function processslingshot_chargesg(sg)
        if sg.states.slingshot_charge then
            local state = sg.states.slingshot_charge
            if not state.upanim2hm then
                state.upanim2hm = true
                local onenter = state.onenter
                state.onenter = function(inst, ...)
                    if onenter then onenter(inst, ...) end
                    if not Enabled(inst) or inst.sg.currentstate == nil or inst.sg.currentstate.name ~= state.name then return end
                    local realrate = inst.prefab == "wixie" and 1.6 or 1.7
                    if inst.components.hunger then
                        realrate = realrate + 1 - inst.components.hunger:GetPercent()
                    elseif inst.replica.hunger then
                        realrate = realrate + 1 - inst.replica.hunger:GetPercent()
                    end
                    SpeedUpState2hm(inst, PrivateState(inst, state), 1 / realrate)
                end
                local onexit = state.onexit
                state.onexit = function(inst, ...)
                    if onexit then onexit(inst, ...) end
                    if Enabled(inst) then RemoveSpeedUpState2hm(inst, inst.sg.currentstate, true) end
                end
            end
        end
    end
    AddStategraphPostInit("wilson", processslingshot_chargesg)
    AddStategraphPostInit("wilson_client", processslingshot_chargesg)
end
-- 原版弹弓发射速度削弱
local function processslingshot_shoot(sg)
    if sg.states.slingshot_shoot then
        local state = sg.states.slingshot_shoot
        if not state.upanimPG then
            state.upanimPG = true
            local onenter = state.onenter
            state.onenter = function(inst, ...)
                if onenter then onenter(inst, ...) end
                if not Enabled(inst) or inst.sg.currentstate == nil or inst.sg.currentstate.name ~= state.name then return end
                local weapon
                if inst.components.inventory then
                    weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                end
                local realrate = inst.prefab == "wixie" and 1.6 or 1.7
                if weapon and weapon.components.slingshotmods then
                    if weapon.components.slingshotmods:HasPartName("slingshot_handle_sticky") then
                        realrate = realrate + 0.3
                    elseif weapon.components.slingshotmods:HasPartName("slingshot_handle_jelly") then
                        realrate = realrate + 0.9
                    elseif weapon.components.slingshotmods:HasPartName("slingshot_handle_voidcloth") then
                        realrate = realrate + 0.3
                    end
                end
                if inst.components.hunger then
                    realrate = realrate + 1 - inst.components.hunger:GetPercent()
                elseif inst.replica.hunger then
                    realrate = realrate + 1 - inst.replica.hunger:GetPercent()
                end
                SpeedUpState2hm(inst, PrivateState(inst, state), 1 / realrate)
            end
            local onexit = state.onexit
            state.onexit = function(inst, ...)
                    if onexit then onexit(inst, ...) end
                    if Enabled(inst) then RemoveSpeedUpState2hm(inst, inst.sg.currentstate, true) end
            end
        end
    end
    if sg.states.slingshot_special then
        local state = sg.states.slingshot_special
        if not state.upanimPG then
            state.upanimPG = true
            local onenter = state.onenter
            state.onenter = function(inst, ...)
            if onenter then onenter(inst, ...) end
            if not Enabled(inst) or inst.sg.currentstate == nil or inst.sg.currentstate.name ~= state.name then return end
                local realrate = 2
                if inst.components.hunger then
                    realrate = realrate + 1 - inst.components.hunger:GetPercent()
                elseif inst.replica.hunger then
                    realrate = realrate + 1 - inst.replica.hunger:GetPercent()
                end
                SpeedUpState2hm(inst, PrivateState(inst, state), 1 / realrate)
            end
            local onexit = state.onexit
            state.onexit = function(inst, ...)
                if onexit then onexit(inst, ...) end
                if Enabled(inst) then RemoveSpeedUpState2hm(inst, inst.sg.currentstate, true) end
            end
        end
    end
    if sg.states.slingshot_charge then
        local state = sg.states.slingshot_charge
        if not state.upanimPG then
            state.upanimPG = true
            local onenter = state.onenter
            state.onenter = function(inst, ...)
            if onenter then onenter(inst, ...) end
            if not Enabled(inst) or inst.sg.currentstate == nil or inst.sg.currentstate.name ~= state.name then return end
                local weapon
                if inst.components.inventory then
                    weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                end
                local realrate = 2
                if weapon and weapon.components.slingshotmods then
                    if weapon.components.slingshotmods:HasPartName("slingshot_handle_sticky") then
                        realrate = realrate - 0.1
                    elseif weapon.components.slingshotmods:HasPartName("slingshot_handle_jelly") then
                        realrate = realrate - 0.2
                    elseif weapon.components.slingshotmods:HasPartName("slingshot_handle_voidcloth") then
                        realrate = realrate - 0.1
                    end
                end
                if inst.components.hunger then
                    realrate = realrate + 1 - inst.components.hunger:GetPercent()
                elseif inst.replica.hunger then
                    realrate = realrate + 1 - inst.replica.hunger:GetPercent()
                end
                SpeedUpState2hm(inst, PrivateState(inst, state), 1 / realrate)
            end
            local onexit = state.onexit
            state.onexit = function(inst, ...)
                if onexit then onexit(inst, ...) end
                if Enabled(inst) then RemoveSpeedUpState2hm(inst, inst.sg.currentstate, true) end
            end
        end
    end
end
AddStategraphPostInit("wilson", processslingshot_shoot)
AddStategraphPostInit("wilson_client", processslingshot_shoot)

-- 削弱改装弹弓蓄力射程
local slingshotammos = {
    "slingshotammo_rock_proj",
    "slingshotammo_gold_proj",
    "slingshotammo_marble_proj",
    "slingshotammo_thulecite_proj",
    "slingshotammo_honey_proj",
    "slingshotammo_freeze_proj",
    "slingshotammo_slow_proj",
    "slingshotammo_poop_proj",
    "slingshotammo_moonglass_proj",
    "slingshotammo_dreadstone_proj",
    "slingshotammo_gunpowder_proj",
    "slingshotammo_lunarplanthusk_proj",
    "slingshotammo_purebrilliance_proj",
    "slingshotammo_horrorfuel_proj",
    "slingshotammo_gelblob_proj",
    "slingshotammo_scrapfeather_proj",
    "slingshotammo_stinger_proj",
    "trinket_1_proj",
}
for i, v in pairs(slingshotammos) do  
    AddPrefabPostInit(v, function(inst)
        if not TheWorld.ismastersim then return end
        if inst.components.projectile then
            local projectile = inst.components.projectile
            local thrown = projectile.onthrown
            projectile:SetOnThrownFn(function(i, owner, target, attacker, ...)
                if thrown ~= nil then thrown(i, owner, target, attacker, ...) end
                if Enabled(attacker or owner) then projectile.range = 20 end
            end)
        end
    end)
end

-- 帐篷材料削弱
if walterEnabled then AddRecipePostInit("portabletent_item", function(inst)
	inst.ingredients = {Ingredient("bedroll_straw", 1),
						Ingredient("twigs", 4),
						Ingredient("silk", 4)
						}
end) end
