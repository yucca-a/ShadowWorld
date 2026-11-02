local hardmode = TUNING.hardmode2hm and GetModConfigData("role_nerf")

-- 2025.7.9 melon:沃托姆能量优化,脱战时间翻倍,回档满能量不脱战.伤害削弱.
if TUNING.DSTU and GetModConfigData("wathom upgrade") then
    -- 设置 Wathom 角色的饥饿值与 Wilson 角色相同
    AddPrefabPostInit("world", function() TUNING.WATHOM_HUNGER = TUNING.WILSON_HUNGER end)
    -- 禁用 Wathom 角色的护甲伤害相关机制
    TUNING.DSTU.WATHOM_ARMOR_DAMAGE = false
    -- 对名为 "wilson" 的状态图进行后初始化操作 -- melon:这段代码好像没用
    AddStategraphPostInit("wilson", function(sg)
        if sg.states.wathomleap then
            -- 触发时执行的函数是将实体的物理碰撞检测设置为与巨人进行碰撞检测
            AddStateTimeEvent2hm(sg.states.wathomleap, 24 * FRAMES, function(inst) inst.Physics:CollidesWith(COLLISION.GIANTS) end)
        end
    end)
    --------------------------------------------
    local select_wathom = GetModConfigData("wathom upgrade")
    if select_wathom ~= 1 then select_wathom = 2 end -- 默认选2  2025.10.24
    local onattack_bounds = select_wathom == 1 and 1.6 or 2.5
    local damage_bounds = select_wathom == 1 and 2 or 4
    if not hardmode then -- 关闭困难模式改为4倍伤害1.6倍承伤
        onattack_bounds = 1.6
        damage_bounds = 4
    end
    --
    local UpvalueHacker = require("upvaluehacker2hm")
    local function CustomCombatDamage(inst, target, weapon, multiplier, mount)
        if mount == nil then
            return (target.components.hauntable and target.components.hauntable.panic and inst:HasTag("amped")) and (1.5 * damage_bounds) or   -- 4改3
                (target.components.hauntable and target.components.hauntable.panic) and (1.5 * 2) or
                inst:HasTag("amped") and damage_bounds or 2  -- 4改3
                or 1
        end
    end
    --
    local ifchangeUnAmp = true
    -- 修改脱战时间---------------------
    local function OnAttackOther(inst, data)
        if data and data.target and not data.projectile and inst.components.adrenaline:GetPercent() >= 0.25 and
        ((data.target.components.combat and data.target.components.combat.defaultdamage > 0) or
            (data.target.prefab == "dummytarget" or data.target.prefab == "antlion" or data.target.prefab == "stalker_atrium" or
                data.target.prefab == "stalker")) then
            inst.adrenalpause = true
            if inst.adrenalresume then
                inst.adrenalresume:Cancel()
                inst.adrenalresume = nil
            end
            -- 10改为20
            inst.adrenalresume = inst:DoTaskInTime(20, function(inst) inst.adrenalpause = false end)
        end
    end
    local function OnAttacked(inst, data)
        inst.adrenalpause = true
        if inst.adrenalresume then
            inst.adrenalresume:Cancel()
            inst.adrenalresume = nil
        end
        inst.adrenalresume = inst:DoTaskInTime(20, function(inst) inst.adrenalpause = false end)
    end
    AddPrefabPostInit("wathom", function(inst)
        if not TheWorld.ismastersim then return end
        -- 激活伤害变为3倍
        if inst.components.combat then 
            inst.components.combat.customdamagemultfn = CustomCombatDamage
        end
        -- 修改激活相关---------------------
        local _UpdateAdrenaline = nil -- 记录原来的函数
        local count_fn = 0 -- 记录个数  保证只有一个目标函数时才修改
        for i, func in ipairs(inst.event_listeners["adrenalinedelta"][inst]) do -- 找函数
            if UpvalueHacker.GetUpvalue(func, "UnAmp") then
                _UpdateAdrenaline = func -- 函数
                count_fn = count_fn + 1
                local _UnAmp, _, _ = UpvalueHacker.GetUpvalue(func, "UnAmp")
                local function UnAmp(inst)
                    if _UnAmp ~= nil then _UnAmp(inst) end -- 原来的
                    if inst.components.adrenaline then
                        inst.components.adrenaline:SetPercent(0.2) -- 2025.10.24 meln:到20能量，虚弱7.5秒
                    end
                end
                if _UnAmp and ifchangeUnAmp then
                    UpvalueHacker.SetUpvalue(func, UnAmp, "UnAmp") -- 替换函数UnAmp
                    ifchangeUnAmp = false
                end
            end
        end
        -- 受伤倍率修改
        if _UpdateAdrenaline ~= nil and count_fn == 1 then
            local function UpdateAdrenaline(inst, data)
                _UpdateAdrenaline(inst, data)
                if inst:HasTag("amped") or inst:HasTag("deathamp") then
                    inst.AmpDamageTakenModifier = onattack_bounds -- 激活1.7倍
                else
                    inst.AmpDamageTakenModifier = 1 -- 未激活1倍
                end
            end
            inst:RemoveEventCallback("adrenalinedelta", _UpdateAdrenaline)
            inst:ListenForEvent("adrenalinedelta", UpdateAdrenaline)
            inst.UpdateAdrenaline2hm = UpdateAdrenaline -- 保存 方便后续修改
        end
        -- 攻击重置脱战时间
        inst:ListenForEvent("onattackother", OnAttackOther) -- 直接增加一个修改的监听，不改原来的
        inst.OnAttackOther2hm = OnAttackOther -- 保存 方便后续修改
        -- 挨打重置脱战时间
        inst:ListenForEvent("attacked", OnAttacked) -- 直接增加一个修改的监听，不改原来的
        inst.OnAttacked2hm = OnAttacked -- 保存 方便后续修改
    end)
    -- 重置脱战时间---------------------
    local function adrenaline_recover(inst)
        if inst:HasTag("amped") or inst:HasTag("deathamp") then
            inst.components.adrenaline:SetPercent(1) -- 能量变为1
            inst.adrenalpause = true
            if inst.adrenalresume then
                inst.adrenalresume:Cancel()
                inst.adrenalresume = nil
            end
            -- 20秒后脱战
            inst.adrenalresume = inst:DoTaskInTime(20, function(inst) inst.adrenalpause = false end)
        end
    end
    -- 回档恢复能量   (写这里才有用,重进也执行这里)
    AddPlayerPostInit(function(inst)
        if not TheWorld.ismastersim then return end
        if inst.prefab ~= "wathom" then return end
        if inst.components.adrenaline then
            inst.adrenaline_recovertask2hm = inst:DoTaskInTime(1, adrenaline_recover) -- 保存
        end
    end)

    -- 2025.8.28 melon:wathom 使用冰/火魔杖时，攻击到目标前切换装备会滑倒---------------------------------
    if hardmode then
        local function onequip2hm(inst, data)
            if inst.range2hm and inst.sg then
                -- 掉落手部装备(不然手上有假装备bug)
                local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
                if weapon then inst.components.inventory:DropItem(weapon) end
                -- 滑倒
                inst.sg:GoToState("knockback2hm", {propsmashed = true, knocker = inst, radius = 3, strengthmult = 1})
            end
        end
        AddPrefabPostInit("wathom", function(inst)
            if not TheWorld.ismastersim then return end
            inst:ListenForEvent("equip", onequip2hm)
            inst:ListenForEvent("onattackother", function(inst) inst.range2hm = nil end) -- 打中后恢复
        end)
        AddStategraphPostInit("wilson", function(sg)
            if sg.states.wathomleap and sg.states.wathomleap.onenter then
                local _wathomleap = sg.states.wathomleap.onenter
                sg.states.wathomleap.onenter = function(inst, ...)
                    _wathomleap(inst, ...)
                    local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
                    if inst.prefab == "wathom" and weapon and weapon.prefab and (weapon.prefab == "icestaff" or weapon.prefab == "firestaff") then
                        inst.range2hm = true -- 使用远程武器的标记
                        inst.rangetask2hm = inst:DoTaskInTime(0.6, function(inst) inst.range2hm = nil end) -- 0.6秒恢复
                    end
                end
            end
        end)
    end
end  -- 2025.7.9 end

-- 2025.4.22 melon:沃托姆锁定夜视和滤镜
-- 2026.8.7:重构为"微光+永久夜视"游戏机制方案,不再覆盖不妥协内部变量。
-- 二轮修复:GetLightAtPoint 对玩家附近动态点光源不敏感(火把/提灯实测也无法>0.9),
--   故黑雾/心跳改用"服务器端拦截 WathomInDark 标签"从根源屏蔽(AddTag 是 DST 通用 API,
--   不依赖不妥协内部变量);微光保留为视觉微光。客户端永久夜视+春天滤镜由
--   common/wathom_nightvision_client.lua 强制(房主由本文件直接包装,立即生效)。
if TUNING.DSTU and GetModConfigData("wathom nightvision") then
    AddPrefabPostInit("wathom", function(inst)
        if not TheWorld.ismastersim then return end
        inst:AddTag("wathom_nv_2hm") -- 客户端据此开启永久夜视(标签随实体复制)
        -- 拦截不妥协的 WathomInDark 标签:服务器端根本不添加 → 客户端黑雾/心跳特效永远不会出现。
        -- (不妥协 CheckLight 黑暗分支用 inst:AddTag("WathomInDark") 添加,被拦截后其 RemoveTag 逻辑照常执行,无副作用)
        local _AddTag_orig = inst.AddTag
        function inst:AddTag(tag)
            if tag == "WathomInDark" then return end
            return _AddTag_orig(self, tag)
        end
        -- 微光:沃托姆自带光源(视觉微光;若光照判定生效则锦上添花,但黑雾不依赖它)
        if not (inst._wathomlight2hm and inst._wathomlight2hm:IsValid()) then
            inst._wathomlight2hm = SpawnPrefab("deathcurselight2hm")
        end
        inst._wathomlight2hm.entity:SetParent(inst.entity)
        inst._wathomlight2hm.Light:SetFalloff(0.4)
        inst._wathomlight2hm.Light:SetIntensity(2)
        inst._wathomlight2hm.Light:SetRadius(6)
        inst._wathomlight2hm.Light:SetColour(180 / 255, 195 / 255, 150 / 255)
        inst._wathomlight2hm.Light:Enable(true)
        -- 房主(客户端托管)场景:服务器实体即客户端渲染实体,直接包装 playervision 立即生效
        -- (纯远程客户端由 common/wathom_nightvision_client.lua 依据标签处理)
        local function applyvision()
            if inst.components.playervision and TUNING.wathom_nv_patch2hm then
                TUNING.wathom_nv_patch2hm(inst.components.playervision)
            end
        end
        applyvision()
        inst:DoTaskInTime(0.5, function()
            if inst:IsValid() then applyvision() end
        end)
    end)
end  -- 2025.4.22 end