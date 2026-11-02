-- 2025.9.21 melon:蜈蚣死亡分裂
local function OnDeath2hm(inst)
    if inst.components.centipedebody then
        local num = inst.components.centipedebody.num_torso
        if num and num > 3 then
            local cnum = math.floor(num / 2)
            local cent1 = SpawnPrefab("shadowthrall_centipede_controller")
            cent1.components.centipedebody.num_torso = cnum
            cent1.Transform:SetPosition(inst.Transform:GetWorldPosition())
            local cent2 = SpawnPrefab("shadowthrall_centipede_controller")
            cent2.components.centipedebody.num_torso = cnum
            cent2.Transform:SetPosition(inst.Transform:GetWorldPosition())
        end
    end
end
AddPrefabPostInit("shadowthrall_centipede_controller", function(inst)
    if not TheWorld.ismastersim then return end
    inst:ListenForEvent("death", OnDeath2hm)
    inst.OnDeath2hm = OnDeath2hm
end)
-- 不生成影子
AddPrefabPostInit("shadowthrall_centipede_head", function(inst) inst.disablesw2hm = true end)
AddPrefabPostInit("shadowthrall_centipede_body", function(inst) inst.disablesw2hm = true end)