-- -- 复制描述文本
-- function CopyPrefabNameAndDesc(dst, src, prefix, suffix)
--     local dst2 = string.upper(dst)
--     local src2 = string.upper(src)
--     if STRINGS.NAMES[src2] then
--         STRINGS.NAMES[dst2] = STRINGS.NAMES[src2]
--         if prefix or suffix then STRINGS.NAMES[dst2] = (prefix or "") .. STRINGS.NAMES[dst2] .. (suffix or "") end
--     end
--     if STRINGS.RECIPE_DESC[src2] then STRINGS.RECIPE_DESC[dst2] = STRINGS.RECIPE_DESC[src2] end
--     if STRINGS.CHARACTERS then
--         for _, data in pairs(STRINGS.CHARACTERS) do if data and data.DESCRIBE and data.DESCRIBE[src2] then data.DESCRIBE[dst2] = data.DESCRIBE[src2] end end
--     end
-- end
-- local modprefabs = {
--     mod_hardmode_stafflight = "stafflight",
--     mod_hardmode_staffcoldlight = "staffcoldlight",
--     staffhotlight2hm = "stafflight",
--     staffcoldlight2hm = "staffcoldlight",
--     mod_hardmode_lavae = "lavae",
--     mod_hardmode_shadow_pillar_spell = "shadow_pillar",
--     mod_hardmode_shadow_trap = "shadow_trap",
--     oceanhorror2hm = "oceanhorror",
--     shadowhutch2hm = "hutch",
--     malbatross_feather2hm = "malbatross_feather",
--     pirate_stash2hm = "pirate_stash",
--     townportaltalisman2hm = "townportaltalisman",
--     bookstation2hm = "bookstation"
-- }
-- CopyPrefabNameAndDesc("mod_hardmode_tumbleweed", "tumbleweed", STRINGS.SCRAPBOOK.FOODTYPE.BURNT)
-- for dst, src in pairs(modprefabs) do CopyPrefabNameAndDesc(dst, src) end
return {
    "playertagentity2hm",
    "moonstorm_ground_lightning_fx2hm",
    "beargerrangeattackfx2hm",
    "shadow_teleport2hm",
    "stalker_shield2hm",
    "shadowskittish2hm",
    "boatwaterfx2hm",
    "linefx2hm",
    "bookstation2hm",
    "dryseeds2hm",
    "dryberries2hm",
    "fx2hm",
    "mod_hardmode_stafflight",
    "mod_hardmode_lavae",
    "mod_hardmode_shadow_trap",
    "mod_hardmode_shadow_pillar",
    "mod_hardmode_tumbleweed",
    "mod_hardmode_deathcursedequip",
    "oceanshadowcreature2hm",
    "torchfireprojectile2hm",
    "moonstormmarker2hm",
    "malbatross_feather2hm",
    "shadowhutch2hm",
    -- "foodbuffs2hm",
    "devilfruits2hm",
    "devilplants2hm",
    "groundpoundringfx2hm",
    "reticulearc",
    "reticuleaoe",
    "pirate_stash2hm",
    "shadowchessicon2hm",
    "backpackicon2hm",
    "townportaltalisman2hm",
    -- "houndterritory2hm",
    "walrus_camp2hm",
    -- "heavyoceanfish2hm"

    "player_soul2hm",
    "player_soul_bottle2hm",
    "player_tomb2hm",
    "tomb_plant2hm",
    "tomb_weed2hm",
    "dirt2hm",
    "classified2hm",
    "healthregenbuff2hm",
    "food2hm",
    "shadowmeteor2hm",
	"primemateP",
	"powdermonkeyP",
    "pocketwatch_heal2hm", -- melon:裂开的不老表
    "watch_weapon_horn2hm", -- 警钟触发的两面夹击
    "ruinsnightmare_horn_attack2hm", -- 修改潜伏暗影的夹击
    "blank2hm", -- 材料险境用到的空白prefab
    "dryplants2hm", -- 晾肉架晾干的作物
    "sword_vortex2hm", -- 涡流(刀)
    "battlesongbuffs", -- 乐谱改动用到的 加伤和加移速buff
    "gulumi_bless2hm",
    "crabking_feeze2hm",
    "crabking_kit2hm",
    "klaus2hm",
    "deer2hm",
    "ruinsnightmare_horn_circular_attack_2hm",
    "wx78_toolbox",  -- WX-78虚拟芯片容器（2025.11.2夜风）
    "sharkboi_icefx2hm",
    "sharkboi_attackfx2hm",
    "bootleg2hm",
    "bootleg_2hm",
    "frostshrine2hm",
    "frostcore2hm",
    -- "crabking_ring_fx2hm",
    "crabking2hm",
    "crabking2hm_claw",
    "passive_shadow_fx2hm",
    "onion_celestial2hm",
    "magician_private_container2hm",
    "book_temperature_buff2hm",
    "tropicalfishbuff2hm",
    "spiderbag2hm",
    "devil_heart2hm",
    "eyeturret_safefire2hm",
    "slingshotammo_moonglass_walter2hm",
}
