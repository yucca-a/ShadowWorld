local assets = {Asset("ANIM", "anim/stalker_shield.zip")}

local function MakeShield(name, num, prefabs)
    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddNetwork()

        inst:AddTag("FX")

        local n = num or math.random(4)

        inst.AnimState:SetBank("stalker_shield")
        inst.AnimState:SetBuild("stalker_shield")
        inst.AnimState:PlayAnimation("idle" .. tostring(math.min(3, n)))
        inst.AnimState:SetFinalOffset(2)
        inst.AnimState:SetScale(n == 4 and -2.36 or 2.36, 2.36, 2.36)

        if num == nil then inst:SetPrefabName(name .. tostring(n)) end

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then return inst end

        inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/shield")

        inst.persists = false
        inst:ListenForEvent("animover", inst.Remove)
        inst:DoTaskInTime(inst.AnimState:GetCurrentAnimationLength() + FRAMES, inst.Remove)

        return inst
    end

    return Prefab(name, fn, assets, prefabs)
end

local ret = {}
local prefs = {}
for i = 1, 4 do
    local name = "stalker_shield2hm" .. tostring(i)
    table.insert(prefs, name)
    table.insert(ret, MakeShield(name, i))
end
table.insert(ret, MakeShield("stalker_shield2hm", nil, prefs))
prefs = nil

-- For searching: "stalker_shield1", "stalker_shield2", "stalker_shield3"
return unpack(ret)
