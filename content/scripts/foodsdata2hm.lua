local foods = {
    smallcandy2hm =
    {
        test = function(cooker, names, tags)
            local berrie_count = (names.berries or 0) + (names.berries_cooked or 0) + (names.berries_juicy or 0) + (names.berries_juicy_cooked or 0)
            return berrie_count >= 1 and not tags.inedible and not tags.monster and tags.sweetener and tags.fruit >= 1
        end,
        priority = 15,
        foodtype = FOODTYPE.GOODIES,
        health = 1,
        hunger = 5,
        perishtime = nil, --TUNING.PERISH_SUPERSLOW, -- not perishable
        sanity = 1,
        cooktime = 1,
        potlevel = "high",
        tags = {"honeyed"},
        stacksize = 1,
        prefabs = { "healthregenbuff2hm" },
        displayname_ch = "小糖豆",
        displayname_en = "small candy",
        description_ch = "听说这是来自反抗军某位不愿意透露姓名的蓝盒研发的新兵食品,虽然他自己都不吃",
        description_en = "food made by LanHe from resistance army",
        oneat_desc_ch = "美味小糖豆~",
        oneat_desc_en = "delicious~",
        oneatenfn = function(inst, eater)
            eater:AddDebuff("healthregenbuff2hm", "healthregenbuff2hm", {
                healthTick = 1 / 8, healthTimer = 8 / 8, healthTime = 240, sanityTick = 1 / 8, sanityTimer = 8 / 8, sanityTime = 240,
                removeOnHit = true, removeWords = TUNING.isCh2hm and "我会想你的,小糖豆" or "i will miss you, candy"
            })
        end,
        floater = {"small", nil, 0.85},
        warlyOnly = false,
    },
    carrotcake2hm = 
    {
        test = function(cooker, names, tags)
            local carrot_count = (names.carrot or 0) + (names.carrot_cooked or 0)
            return (names.batnose or names.batnose_cooked) and carrot_count >= 2 and tags.sweetener and not tags.inedible and not tags.monster
        end,
        priority = 15,
        foodtype = FOODTYPE.GOODIES,
        health = 20,
        hunger = 62.5,
        perishtime = TUNING.PERISH_SLOW, --TUNING.PERISH_SUPERSLOW, -- not perishable
        sanity = 15,
        cooktime = 0.5,
        -- potlevel = "high",
        stacksize = 1,
        prefabs = { "gulumi_bless2hm" },
        displayname_ch = "猪鼻胡萝卜蛋糕",
        displayname_en = "Pignose carrot cake",
        description_ch = "某猪仙人最爱的猪食，据说吃了可以与猪人同呼吸",
        description_en = "Someone's favorite pig food, it is said that eating it can breathe with pigman",
        oneat_desc_ch = "吃东西的时间到了！",
        oneat_desc_en = "Food time!",
        oneatenfn = function(inst, eater)
            eater.SoundEmitter:PlaySound("dontstarve/pig/grunt")
            eater:AddDebuff("gulumi_bless2hm", "gulumi_bless2hm", {
                 blessDuration = 240 , removeWords = TUNING.isCh2hm and "该回家了！" or "Home Time!", removeSould = true
            })
        end,
        floater = {"small", nil, 0.85},
        warlyOnly = false,
    },
    -- 三色鱼汤:四季海鱼各一条,吃后16分钟 60%移速+免疫潮湿+冷热免疫+发光
    tropicalbouillabaisse2hm =
    {
        test = function(cooker, names, tags)
            -- 要四季鱼
            local n6 = (names.oceanfish_small_6 or 0) + (names.oceanfish_small_6_inv or 0)
            local n7 = (names.oceanfish_small_7 or 0) + (names.oceanfish_small_7_inv or 0)
            local n8 = (names.oceanfish_small_8 or 0) + (names.oceanfish_small_8_inv or 0)
            local nm8 = (names.oceanfish_medium_8 or 0) + (names.oceanfish_medium_8_inv or 0)
            return n6 >= 1 and n7 >= 1 and n8 >= 1 and nm8 >= 1
        end,
        priority = 500,
        foodtype = FOODTYPE.MEAT,
        health = 60,
        hunger = 150,
        sanity = 33,
        perishtime = TUNING.PERISH_SLOW,
        cooktime = 2,
        stacksize = 1,
        prefabs = { "tropicalfishbuff2hm" },
        displayname_ch = "四季鱼汤",
        displayname_en = "Tropical Bouillabaisse",
        description_ch = "用可爱的鱼做的食物",
        description_en = "Food made with adorable fish",
        oneat_desc_ch = "我感觉我变成了一条鱼",
        oneat_desc_en = "I feel like I've become a fish",
        oneatenfn = function(inst, eater)
            eater:AddDebuff("tropicalfishbuff2hm", "tropicalfishbuff2hm", {
                removeWords = TUNING.isCh2hm and "我感觉我离开了水" or "I feel like I'm out of water"
            })
        end,
        floater = {"small", nil, 0.85},
        warlyOnly = false,
    },
}

for k, v in pairs(foods) do
    v.name = k
    v.weight = v.weight or 1
    v.priority = v.priority or 0

    if TUNING.isCh2hm then
        STRINGS.NAMES[string.upper(k)] = v.displayname_ch
        STRINGS.CHARACTERS.GENERIC.DESCRIBE[string.upper(k)] = v.description_ch
        v.oneatdesc = v.oneat_desc_ch
    else
        STRINGS.NAMES[string.upper(k)] = v.displayname_en
        STRINGS.CHARACTERS.GENERIC.DESCRIBE[string.upper(k)] = v.description_en
        v.oneatdesc = v.oneat_desc_en
    end

    v.atlasname = "images/inventoryimages/" .. k .. ".xml"
    v.build = k
    v.bank = k
    v.overridebuild = k
    v.overridesymbolname = k
	-- v.cookbook_category = "cookpot"
end

-- 四季鱼汤模型用自包含zip tropicalbouillabaisse,循环后强制覆盖自身名，贴图文件是直接用的海难模组的，正常情况下贴图文件名要和这个东西名字一样，但是和海难（岛屿冒险三合一什么的）一起开的话，名字一样冲突了
if foods.tropicalbouillabaisse2hm then
    foods.tropicalbouillabaisse2hm.build = "tropicalbouillabaisse"
    foods.tropicalbouillabaisse2hm.bank = "tropicalbouillabaisse"
    foods.tropicalbouillabaisse2hm.overridebuild = "tropicalbouillabaisse"
    foods.tropicalbouillabaisse2hm.overridesymbolname = "tropicalbouillabaisse"
end

return foods