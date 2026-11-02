local speedup = GetModConfigData("extra_change") and GetModConfigData("notboss_speed") or 1
local animal_change = GetModConfigData("animal_change")
local changeIndex = (animal_change == -1 or animal_change == true or animal_change == false) and 3 or animal_change
local else_changeIndex = math.max(1, changeIndex / 2)
TUNING.WALRUS_REGEN_PERIOD = TUNING.WALRUS_REGEN_PERIOD * else_changeIndex
TUNING.WALRUS_HEALTH = TUNING.WALRUS_HEALTH * 8 / 3
TUNING.WALRUS_TARGET_DIST = TUNING.WALRUS_TARGET_DIST * 1.5
TUNING.WALRUS_LOSETARGET_DIST = TUNING.WALRUS_LOSETARGET_DIST * 1.5
TUNING.LITTLE_WALRUS_HEALTH = TUNING.LITTLE_WALRUS_HEALTH * 2.25
-- 海象移速更快
AddPrefabPostInit("walrus", function(inst)
    if TheWorld.has_ocean then
	    inst:RemoveComponent("drownable")
        inst.Physics:ClearCollidesWith(COLLISION.WORLD)
        inst.Physics:CollidesWith(COLLISION.GROUND)
    end
    inst:AddTag("flare_summoned")
    inst:AddTag("notraptrigger")
    if not TheWorld.ismastersim then return end
    if inst.components.locomotor.runspeed and speedup < 1.7 then inst.components.locomotor.runspeed = inst.components.locomotor.runspeed * 1.7 / speedup end
end)
-- 海象巢穴翻倍
if GetModConfigData("walrus") == -2 then
    TUNING.walrus_camp2hm = true
    local function testdoubleself(inst)
        if not inst.components.persistent2hm.data.double2hm then
            inst.components.persistent2hm.data.double2hm = true
            local newinst = SpawnPrefab("walrus_camp2hm")
            newinst.Transform:SetPosition(inst.Transform:GetWorldPosition())
        end
    end
    AddPrefabPostInit("walrus_camp", function(inst)
        if not TheWorld.ismastersim then return end
        if not inst.components.persistent2hm then inst:AddComponent("persistent2hm") end
        inst:DoTaskInTime(0, testdoubleself)
    end)
end
