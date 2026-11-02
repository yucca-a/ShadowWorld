
local assets =
{
    Asset("ANIM", "anim/pocketwatch.zip"), -- 使用原有的
    Asset("ANIM", "anim/pocketwatch_marble.zip"), -- 使用原有的
    Asset("ATLAS", "images/inventoryimages/pocketwatch_heal2hm.xml"),
	Asset("IMAGE", "images/inventoryimages/pocketwatch_heal2hm.tex"),
}

local prefabs = 
{
	-- "pocketwatch_heal_fx",
	-- "pocketwatch_heal_fx_mount",
}
-------------------------------------------------------------------------------
local function GetStatus(inst)
	return "测试"
end

local function cancelmiss(inst) -- 取消无敌
    inst.cancelmisstask2hm = nil
    if inst.allmiss2hm then inst.allmiss2hm = nil end
end

local function repair2hm(inst)
	if inst.components.finiteuses then
        -- inst.components.finiteuses:Repair(1) -- 每3.6秒修1耐久
        local percent = inst.components.finiteuses:GetPercent()
        if percent < 1 then
            inst.components.finiteuses:SetPercent(math.min(1, percent + 0.01)) -- 每次修1%
        end
        if inst.components.finiteuses:GetPercent() >= 1 and inst.repairtask2hm ~= nil then
            inst.repairtask2hm:Cancel()
            inst.repairtask2hm = nil
        end
    end
end

local function use2hm(inst, doer)-- 回复20点生命值
	if doer and doer.prefab == "wanda" and doer.components.oldager and doer.components.health and inst.components.finiteuses then
        if inst.components.finiteuses:GetUses() >= 1 then
            -- 使用时0.5秒无敌
            doer.allmiss2hm = true
            doer:DoTaskInTime(0.5, cancelmiss)
            -- 回各种状态---------------------------------------------------
            doer.components.oldager:StopDamageOverTime() -- 停了这个才能执行
            -- 回25血，抵消生存险境的回血削弱
            doer.components.health:DoDelta(inst.healthDoDelta2hm, true, "pocketwatch_heal") -- 这样才能回血 缓慢回
            if doer.components.sanity then doer.components.sanity:DoDelta(inst.sanityDoDelta2hm) end -- 回san抵消自然衰老
            if doer.components.hunger and doer.components.hunger.penalty2hm and doer.components.hunger.penalty2hm > 0 then -- 回饥饿上限
                doer.components.hunger:DeltaPenalty2hm(-TUNING.POCKETWATCH_HEAL_HEALING / doer.components.hunger.max / 4)
            end
            -- 回温
            if doer.components.temperature.current then
                doer.components.temperature:SetTemperature(math.clamp(doer.components.temperature.current +
                    (TUNING.BOOK_TEMPERATURE_AMOUNT - doer.components.temperature.current) / 3, 11, 59))
            end
            -- 灭火
            if doer.components.burnable then doer.components.burnable:Extinguish() end
            -- 给牛灭火
            if doer.components.rider ~= nil and doer.components.rider:IsRiding() and doer.components.rider:GetMount() then
                local mount = doer.components.rider:GetMount()
                if mount.components.burnable then mount.components.burnable:Extinguish() end
            end
            ------------------------------------------------------------
            inst.components.finiteuses:Use(1) -- 扣33%
            if inst.repairtask2hm == nil then -- 启动修复任务
                inst.repairtask2hm = inst:DoPeriodicTask(inst.repairspeed2hm,repair2hm) -- 每3.6秒修1耐久
            end
            ------------------------------------------------------------
            -- 特效?注意都是靠doer生成的
            doer.SoundEmitter:PlaySound("wanda2/characters/wanda/watch/heal", nil, 0.7) -- 不要声音了吧
            -- 光
            doer.sg.statemem.stafflight = SpawnPrefab("staff_castinglight_small") -- 光?
            doer.sg.statemem.stafflight.Transform:SetPosition(doer.Transform:GetWorldPosition())
            doer.sg.statemem.stafflight:SetUp(doer.sg.statemem.castfxcolour or { 1, 1, 1 }, 0.75, 0)
            -- 销毁
            doer:DoTaskInTime(1, function(doer) -- 光持续1秒
                if doer.sg.statemem.stafflight ~= nil then
                    doer.sg.statemem.stafflight:Remove()
                    doer.sg.statemem.stafflight = nil
                end
            end)
		    return true
        end
    else
        -- 非旺达角色使用提示
        if doer and doer.components.talker then
            doer.components.talker:Say("只有牢达能使用这个！")
        end
        return false
    end
end

local function healfn()
	local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    -- inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("pocketwatch")
    inst.AnimState:SetBuild("pocketwatch_marble")
    inst.AnimState:PlayAnimation("idle")

    -- 标签能让猴子青蛙偷不走
    inst:AddTag("nosteal")
    -- inst:AddTag("pocketwatch_castfrominventory")
    -- inst:AddTag("pocketwatch_mountedcast")
    inst:AddTag("pocketwatch_heal2hm") -- 不加这个用不了(动作)
    -- inst:AddTag("pocketwatch") -- 加上能拆了
	-- inst:AddTag("cattoy")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then --不加开地洞就崩
        return inst
    end

    inst:AddComponent("lootdropper")
    -- MakeInventoryFloatable(inst, "small", 0.05, {1.2, 0.75, 1.2})
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "pocketwatch_heal2hm"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/pocketwatch_heal2hm.xml"
    inst.components.inventoryitem.keepondeath = true -- 死亡不掉落
    inst.components.inventoryitem.keepondrown = true -- 溺水不掉落
    inst:AddComponent("finiteuses") --加耐久
    inst.components.finiteuses:SetMaxUses(3)
    inst.components.finiteuses:SetUses(3)
    -- 添加可用组件
	inst:AddComponent("useableitem") -- 加了不用，单纯触发动作用
    -- inst.components.useableitem:SetOnUseFn(use2hm)
    -- inst.components.useableitem:SetOnStopUseFn(stop2hm)
    inst:AddComponent("inspectable")
	inst.components.inspectable.getstatus = GetStatus
    -- 使用函数
    inst.onuse = use2hm
    -- 可调设置
    inst.repairspeed2hm = 3.6 -- 每3.6秒回1耐久
    inst.healthDoDelta2hm = 25 --使用回复血量
    inst.sanityDoDelta2hm = 2 --使用回复san值
    inst.repairtask2hm = inst:DoPeriodicTask(inst.repairspeed2hm,repair2hm) -- 每3.6秒修1耐久

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("pocketwatch_heal2hm", healfn, assets, prefabs) -- 自定义不老表
