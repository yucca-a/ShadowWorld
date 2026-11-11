-- Register helpers added since .18 before require() consults the workshop
-- filename index, including when the previous version's index is still in use.
local manifest = GLOBAL.ManifestManager
if manifest ~= nil and GLOBAL.IsWorkshopMod(modname) then
    for _, path in ipairs({
        "scripts/shadowhalloween2hm.lua",
        "scripts/bootlegnonslip2hm.lua",
        "common/um_compat_fixes.lua",
        "common/beef_bell_pack.lua",
        "scripts/umcompatguard2hm.lua",
        "scripts/umwinonaworker2hm.lua",
        "scripts/winonabuilder2hm.lua",
        "scripts/umcompatprofiles2hm.lua",
        "scripts/umperformance2hm.lua",
        "scripts/umtornado2hm.lua",
        "scripts/winonaelectrical2hm.lua",
        "easy_role/winona_electrical.lua",
        "scripts/prefabs/winona_electrical2hm.lua",
        "scripts/prefabs/electrical_shock2hm.lua",
        "scripts/prefabs/slingshotammo_moonglass_walter2hm.lua",
    }) do
        manifest:AddFileToModManifest(modname, path)
    end
end

-- 本模组需要的一些设定的通用补充
modimport("common/common.lua")
GetModConfigData = require("combatconfig2hm").Wrap(GetModConfigData)
require("wixieconfig2hm").Install(GLOBAL, modname)
modimport("common/language2hm.lua")
modimport("common/replica.lua")
modimport("init/assets")
modimport("common/projectile.lua") -- 弹药改动
modimport("common/curse.lua") -- 诅咒改动
modimport("common/temp.lua") -- 持久化数据
modimport("common/patch.lua") -- 官方冲突修正,涵盖可选的replica错误修复补丁
modimport("common/recipe_util.lua")
modimport("common/food_util.lua")
modimport("common/newstate.lua")
modimport("common/bugfix.lua")
require("gemstaffcompat2hm").Install(GLOBAL.ModManager)
modimport("common/equip_slot_fix.lua")
modimport("init/hover")
modimport("common/monster_nightvision.lua")
modimport("common/walter_wixie_slingshot.lua")
require("debugcommands2hm")
TUNING.HAPPYPATCHMOD = true -- 供其他模组访问
TUNING.HappyPatchTest = modname == "HappyPatch"
TUNING.Plants = {}
PrefabFiles = require("prefabs2hm") -- 本模组额外实体
modimport("epic/icestaff_frostcore2hm.lua") -- 冰核升级冰杖
if GetModConfigData("Celestial Jewel Upgrade Sword Lunarplant") then modimport("epic/sword_lunarplant_moonfire2hm.lua") end
modimport("epic/beargerfur_sack_lunar_seed2hm.lua") -- 天体珠宝升级极地熊獾桶
if GetModConfigData("gelblob_storage_kit upgrade") then modimport("epic/gelblob_storage_kit2hm.lua") end -- 恶液存储套件右键升级容器(容器获永鲜)
modimport("easy_other/magician_private2hm.lua")

-- 简单模式----------------------------------------------------------------------------------
if TUNING.easymode2hm then
    -- 简单模式非角色改动-----------------------------------------------
    modimport("easy_other/easy_living_things.lua") -- 生物(动物、植物)
    modimport("easy_other/easy_equipments.lua") -- 装备
    modimport("easy_other/easy_items.lua") -- 物品
    modimport("easy_other/easy_mechanics.lua") -- 机制
    modimport("easy_other/easy_structures.lua") -- 建筑
    if GetModConfigData("lunar shadow items") then modimport("easy_other/lunar_shadow_items.lua") end -- 2025.5.3 melon
    -- 简单模式角色改动-------------------------------------------------
    if GetModConfigData("role_easy") then
        -- if GetModConfigData("Walter Throw Slingshot First Attack") == -1 then modimport("easy_role/attackaction.lua") end
        modimport("easy_role/rightaction.lua")
        modimport("easy_role/rightselfaction.lua")
        if GetModConfigData("Role Gym") then modimport("easy_role/gym.lua") end
        -- 简单模式角色改动
        modimport("easy_role/role_common.lua")
        modimport("easy_role/skilltree_common.lua") -- 技能树
        -- roles
        if GetModConfigData("wilson_easy") then modimport("easy_role/wilson_easy.lua") end
        if GetModConfigData("willow_easy") then modimport("easy_role/willow_easy.lua") end
        if GetModConfigData("wolfgang_easy") then modimport("easy_role/wolfgang_easy.lua") end
        if GetModConfigData("wendy_easy") then modimport("easy_role/wendy_easy.lua") end
        if GetModConfigData("wx78_easy") then modimport("easy_role/wx78_easy.lua") end
        if GetModConfigData("wickerbottom_easy") then modimport("easy_role/wickerbottom_easy.lua") end
        if GetModConfigData("woodie_easy") then modimport("easy_role/woodie_easy.lua") end
        if GetModConfigData("wes_easy") then modimport("easy_role/wes_easy.lua") end 
        if GetModConfigData("waxwell_easy") then modimport("easy_role/waxwell_easy.lua") end 
        if GetModConfigData("wigfrid_easy") then modimport("easy_role/wigfrid_easy.lua") end        
        if GetModConfigData("webber_easy") then modimport("easy_role/webber_easy.lua") end
        if GetModConfigData("winona_easy") then modimport("easy_role/winona_easy.lua") end
        if GetModConfigData("warly_easy") then modimport("easy_role/warly_easy.lua") end 
        if GetModConfigData("wortox_easy") then modimport("easy_role/wortox_easy.lua") end
        if GetModConfigData("wormwood_easy") then modimport("easy_role/wormwood_easy.lua") end
        if GetModConfigData("wurt_easy") then modimport("easy_role/wurt_easy.lua") end
        if GetModConfigData("walter_easy") then modimport("easy_role/walter_easy.lua") end
        if TUNING.DSTU and GetModConfigData("Wixie No Claustrophobia") then modimport("easy_role/wixie_easy.lua") end
        if GetModConfigData("wanda_easy") then modimport("easy_role/wanda_easy.lua") end
        if GetModConfigData("Wanda Dread Watch") then modimport("easy_role/wanda_dreadwatch2hm.lua") end -- 恐惧-警告表:附身暗影心房升级警钟,独立开关默认开启
        if GetModConfigData("wonkey_easy") then modimport("easy_role/wonkey_easy.lua") end -- wonkey
        if GetModConfigData("other_role_easy") then
            modimport("easy_role/wathom_easy.lua") -- wathom
        end

        if GetModConfigData("avoidselfdmg") then TUNING.avoidselfdmg2hm = true end
    end
end

-- 即使关闭增强，也要能读取旧存档中的工具箱。
modimport("easy_role/winona_toolbox.lua")
modimport("easy_role/winona_electrical.lua")

if TUNING.DSTU then modimport("easy_other/um_patch.lua") end
if TUNING.DSTU then modimport("common/um_compat_fixes.lua") end

-- 模组相关-----------------------------------------------------------------------------
if ((TUNING.TEMP2HM.openmods == nil and GetModConfigData("Show Mod Icon In Game")) or TUNING.TEMP2HM.openmods) and
    not TheNet:IsDedicated() then modimport("easy_other/ui.lua") end
if not TheNet:IsDedicated() then
    AddClassPostConstruct("screens/consolescreen", require("seasonwiki2hm").InstallConsole)
end
if GetModConfigData("Disable Outdate Tip") then modimport("easy_other/mod.lua") end
-- 快捷存取和额外容器按钮
-- Keep Shadow Nexus custody readable when container buttons are disabled.
modimport("easy_other/exchangemodes2hm.lua")
modimport("easy_other/shadowvault.lua")
if GetModConfigData("Container Sort") or GetModConfigData("Items collect") then
    modimport("easy_other/containersort.lua")
end
-- if GetModConfigData("simple chatbot") then modimport("easy_other/simplechatbot.lua") end
-- 暗影世界
-- 关闭影子生成后，仍需拦截先前被道具保存的临时分身记录。
local oldSpawnSaveRecord = GLOBAL.SpawnSaveRecord
GLOBAL.SpawnSaveRecord = function(record, ...)
    if record and record.data and record.data.shadowworld_clone2hm then return end
    return oldSpawnSaveRecord(record, ...)
end
if GetModConfigData("Shadow World") then
    modimport("shadowworld.lua")
    if GetModConfigData("shadow_nerf") then modimport("shadow_nerf.lua") end-- 2025.7.17 melon
end

-- 随机生物大小
if GetModConfigData("Random Sized") then modimport("ray/suijishengwuapi.lua") end
-- 群系灭绝
if GetModConfigData("World ecosystem") then modimport("ray/shengwudamiejve.lua") end

-- 遗忘地图
if GetModConfigData("World lose") then modimport("ray/yincangditu.lua") end
-- 禁止控制台
if not GetModConfigData("ban op") then
    GLOBAL.ExecuteConsoleCommand = function() end
    AddSimPostInit(function()
        local UserCommands = require("usercommands")
        local rollback_command = UserCommands.GetCommandFromName("rollback")
        rollback_command.serverfn = function(params, caller) end
        local regenerate_command = UserCommands.GetCommandFromName("regenerate")
        regenerate_command.serverfn = function(params, caller) end
    end)
end

-- if GetModConfigData("Server Paused") then modimport("easy_other/serverpaused.lua") end

-- 困难模式-----------------------------------------------------------------------------
if TUNING.hardmode2hm then
    modimport("common/hardmode.lua")
    -- 科技改动
    if GetModConfigData("other_change") then
        modimport("tech/common.lua")
        if GetModConfigData("Harder Distilled Knowledge") then modimport("tech/distilledknowledge.lua") end
        if GetModConfigData("Harder Prototyper Recipe") then modimport("tech/prototyper.lua") end
        if GetModConfigData("Harder Prototyper Level") then modimport("tech/prototyperlevel.lua") end
        if GetModConfigData("oceanlife") then modimport("tech/oceanlife.lua") end
        if GetModConfigData("sleepingbag") then modimport("tech/sleep.lua") end
        if GetModConfigData("clockwork_guard") then modimport("tech/clockwork_guard.lua") end -- 2025.7.17 meloh
        if GetModConfigData("moonrockidol") then modimport("tech/moonrockidol.lua") end
        if GetModConfigData("rocks_change") then modimport("tech/rocks.lua") end
        if GetModConfigData("cheap_wrap") then modimport("tech/cheap_wrap.lua") end
        if GetModConfigData("cave_entrance") and not TUNING.HappyPatchTest then modimport("tech/cave_entrance.lua") end
        if GetModConfigData("ancient_statue") then modimport("tech/ancient_statue.lua") end
        if GetModConfigData("ancient_altar") then modimport("tech/ancient_altar.lua") end
    end
    -- 角色改动
    if GetModConfigData("role_nerf") then
        if GetModConfigData("combat") then modimport("role/combat.lua") end
        if GetModConfigData("regen_danger") then modimport("role/regen.lua") end
        if GetModConfigData("stand_fight_danger") then modimport("role/stand_fight.lua") end
        if GetModConfigData("death_danger") then modimport("role/death_danger.lua") end
        if GetModConfigData("role_battle") and not TUNING.HappyPatchTest then modimport("role/health.lua") end
        if GetModConfigData("role_sanity") and not TUNING.HappyPatchTest then modimport("role/sanity.lua") end
        if GetModConfigData("role_hunger") and not TUNING.HappyPatchTest then modimport("role/hunger.lua") end
        if GetModConfigData("pvp_force") then modimport("role/pvp.lua") end
        if GetModConfigData("leader") then modimport("role/leader.lua") end
        -- if GetModConfigData("haitang_curse") then modimport("role/haitang_curse.lua") end
        if GetModConfigData("haitang_curse_2") then modimport("role/haitang_curse_2.lua") end
        if GetModConfigData("delay_leave") and not TUNING.HappyPatchTest then modimport("role/delayleave.lua") end
        if GetModConfigData("norunattack") then modimport("role/norunattack.lua") end
        if GetModConfigData("death_curse") and not TUNING.HappyPatchTest then modimport("role/death.lua") end
        if GetModConfigData("soul_wild") then modimport("role/soul.lua") end
        if GetModConfigData("legion_shield") then modimport("role/legion_shield.lua") end
        if GetModConfigData("riding_hunger") then modimport("role/riding_hunger.lua") end-- 2025.7.25 melon
        if GetModConfigData("recipe_add_material") then modimport("role/recipe_add_material.lua") end-- 2025.5.31 melon
        -- if GetModConfigData("clock_rotate") then modimport("role/clock_rotate.lua") end-- 2025.6.23 melon
        if GetModConfigData("clock_peril") then modimport("role/clock_peril.lua") end-- 2025.2.24 YeFeng:《时钟险境》真正实现
        if GetModConfigData("taste") then modimport("role/taste.lua") end
        if GetModConfigData("willow") then modimport("role/willow.lua") end
        if GetModConfigData("webber") then modimport("role/webber.lua") end
        if GetModConfigData("wx-78") then modimport("role/wx78.lua") end
        if GetModConfigData("wendy") then modimport("role/wendy.lua") end
        if GetModConfigData("wolfgang") then modimport("role/wolfgang.lua") end
        if GetModConfigData("wickerbottom") then modimport("role/wickerbottom.lua") end
        if GetModConfigData("wigfrid") then modimport("role/wigfrid.lua") end
        if GetModConfigData("wormwood") then modimport("role/wormwood.lua") end
        if GetModConfigData("wortox") then modimport("role/wortox.lua") end
        if GetModConfigData("wurt") then modimport("role/wurt.lua") end
        if GetModConfigData("wanda") then modimport("role/wanda.lua") end
        if GetModConfigData("walter") or (TUNING.DSTU and GetModConfigData("wixie")) then modimport("role/walter.lua") end
        if GetModConfigData("maxwell") then modimport("role/waxwell.lua") end
    end
    -- 天气改动
    if GetModConfigData("weather_change") then
        modimport("weather/weather.lua")
        if GetModConfigData("temperature_change") then modimport("weather/temperature.lua") end
        if GetModConfigData("rain_change") then modimport("weather/rain.lua") end
        if GetModConfigData("moonisland") then modimport("weather/moonisland.lua") end
        if GetModConfigData("sandstorm") then modimport("weather/sandstorm.lua") end
        if GetModConfigData("summer_change") then modimport("weather/summer.lua") end
        if GetModConfigData("winter_change") then modimport("weather/winter.lua") end
        if GetModConfigData("autumn_change") then modimport("weather/autumn.lua") end
        modimport("weather/seasons.lua")
        -- if GetModConfigData("random_seasons") then modimport("weather/seasons.lua") end
        if GetModConfigData("dusk_change") then modimport("weather/dusk.lua") end
        if GetModConfigData("moonlight") then modimport("weather/moonlight.lua") end
    end
    -- 食物改动
    if GetModConfigData("food_change") then
        if GetModConfigData("fooddata_change") then modimport("food/fooddata.lua") end
        if GetModConfigData("cooking_change") then modimport("food/cooking.lua") end
        if GetModConfigData("birds_change") then modimport("food/birds.lua") end
        if GetModConfigData("oceanfish_change") then modimport("food/oceanfish.lua") end
        if GetModConfigData("container_live") then modimport("food/container_live.lua") end
        if GetModConfigData("animal_change") then modimport("food/animal.lua") end
        if GetModConfigData("beefalo") then modimport("food/beefalo.lua") end
        if GetModConfigData("koalefant") then modimport("food/koalefant.lua") end
        if GetModConfigData("plant_change") then modimport("food/plant.lua") end
        if GetModConfigData("action_change") then modimport("food/action.lua") end
        if GetModConfigData("Seeds Weed Chance") then modimport("food/seeds.lua") end
        if GetModConfigData("farm") then modimport("food/farm.lua") end
        if GetModConfigData("nutrient") then modimport("food/nutrient.lua") end
        if GetModConfigData("farm_plant_change") then modimport("food/farm_plant.lua") end
    end
    -- 怪物加强
    if GetModConfigData("monster_change") then
        modimport("monster/common.lua")
        -- 新三王暗影分身改动
        if GetModConfigData("gestalt") and GetModConfigData("Shadow World") and
            (GetModConfigData("warg") or GetModConfigData("bearger") or GetModConfigData("deerclops")) then modimport("epic/lunarepic.lua") end
        -- 小怪改动
        if GetModConfigData("rangesupermonster") or GetModConfigData("specialsupermonster") then modimport("monster/supermonster.lua") end
        if GetModConfigData("calmfire") then modimport("monster/calmfire.lua") end
        if GetModConfigData("nosrctarget") then TUNING.nosrctarget2hm = true end
        if GetModConfigData("wall_destroy") then modimport("monster/wall.lua") end
        if GetModConfigData("boss_no_fight") then modimport("monster/boss_nofight.lua") end
        if GetModConfigData("moveattack") then modimport("monster/moveattack.lua") end
        if GetModConfigData("flyingattack") then modimport("monster/flying.lua") end
        if GetModConfigData("bee") then modimport("monster/bee.lua") end
        if GetModConfigData("fruitfly") then modimport("monster/fruitfly.lua") end
        if GetModConfigData("shark") then modimport("monster/shark.lua") end
        if GetModConfigData("shadowthrall") then modimport("monster/shadowthrall.lua") end
        if GetModConfigData("lunarthrall_plant") then modimport("monster/lunarthrall_plant.lua") end
        if GetModConfigData("warg") then modimport("monster/hound.lua") end
        if GetModConfigData("walrus") then modimport("monster/walrus.lua") end
        if GetModConfigData("spider") then modimport("monster/spider.lua") end
        if GetModConfigData("pigman") then modimport("monster/pigman.lua") end
        if GetModConfigData("otter") then modimport("monster/otter.lua") end
        if GetModConfigData("monkey") then modimport("monster/monkey.lua") end
        if GetModConfigData("crawlingshadow") then modimport("monster/crawlingshadow.lua") end
        if GetModConfigData("shadowbeak") then modimport("monster/shadowbeak.lua") end
        if GetModConfigData("shadowleech") then modimport("monster/shadowleech.lua") end
        if GetModConfigData("oceanshadow") then modimport("monster/oceanshadow.lua") end
        if GetModConfigData("ruinsnightmare") then modimport("monster/ruinsnightmare.lua") end-- 2025.7.17 melon
        if GetModConfigData("chess") then modimport("monster/chess.lua") end
        if GetModConfigData("krampus") then modimport("monster/krampus.lua") end
        if GetModConfigData("tentacle") then modimport("monster/tentacle.lua") end
        if GetModConfigData("mimicreep") then modimport("monster/mimicreep.lua") end
        if GetModConfigData("shadowthrall_centipede") then modimport("monster/shadowthrall_centipede.lua") end
        -- BOSS加强
        if GetModConfigData("toadstool") then modimport("epic/toadstool.lua") end
        if GetModConfigData("bearger") then modimport("epic/bearger.lua") end
        if GetModConfigData("sharkboi") then modimport("epic/sharkboi.lua") end
        if GetModConfigData("leif") then modimport("epic/leif.lua") end
        -- 犀牛加强三档: 0关闭(原版) / 1旧版 / 2难度加强(高级技能+犀牛角强化)
        local minotaur_mode = GetModConfigData("minotaur")
        if minotaur_mode == true then minotaur_mode = 2 end -- 旧档true兼容(之前默认开启=全量加强)
        if minotaur_mode == 1 then modimport("epic/minotaur_old.lua")
        elseif minotaur_mode == 2 then modimport("epic/minotaur.lua") end
        if GetModConfigData("malbatross") then modimport("epic/malbatross.lua") end
        if GetModConfigData("klaus") then modimport("epic/klaus.lua") end
        if GetModConfigData("shadowchesspieces") then modimport("epic/shadowchesspieces.lua") end
        if GetModConfigData("antlion") then modimport("epic/antlion.lua") end
        if GetModConfigData("deerclops") then modimport("epic/deerclops.lua") end
        if GetModConfigData("dragonfly") then modimport("epic/dragonfly.lua") end
        if GetModConfigData("beequeen") then modimport("epic/beequeen.lua") end
        if GetModConfigData("crabking") == true then 
            modimport("epic/crabking.lua")
        elseif GetModConfigData("crabking") == -1 then
            modimport("epic/crabking_deprecated.lua")
        end
        if GetModConfigData("eyeofterror") then modimport("epic/eyeofterror.lua") end
        if GetModConfigData("atriumstalker") then modimport("epic/atriumstalker.lua") end
        local epic_armor_mode = GetModConfigData("epic_armor_5")
        if epic_armor_mode == "dynamic" then
            modimport("epic/dynamic_armor.lua")
        elseif epic_armor_mode then
            modimport("epic/epic_armor.lua")
        end
if GetModConfigData("epic_ruin") then modimport("epic/epic_ruin.lua") end
        if GetModConfigData("poor_armor") then modimport("epic/poor_armor.lua") end -- 2025.9.20 melon
        if GetModConfigData("pig_boss") then modimport("epic/pig_boss.lua") end -- 2025.5.3 melon
        if GetModConfigData("alterguardian") then modimport("epic/alterguardian.lua") end -- 单文件版:档位逻辑在文件内部(alterguardianmode)
        if GetModConfigData("alterguardian_phase4") then modimport("epic/alterguardian_phase4_lunarrift.lua") end
		if GetModConfigData("daywalker2") then modimport("epic/daywalker2.lua") end
        if GetModConfigData("UM Widow") then modimport("epic/um_hoodedwidow.lua") end -- 妥协黑寡妇
        -- 第二周目攻击动画加快
        if GetModConfigData("Monster Harder Level") then modimport("monster/secondlevel.lua") end
    end
    -- 额外改动
    if GetModConfigData("extra_change") then
        modimport("extra/extra.lua")
        modimport("extra/fruitfly2hm.lua")
        if (GetModConfigData("boss_attackanim") or GetModConfigData("notboss_attackanim")) and not TUNING.upatkanim2hm then
            modimport("monster/secondlevel")
        end
    end
    -- 怪物启示录
    if GetModConfigData("shengwuqishilu") or GetModConfigData("shengwuqishilu2") or GetModConfigData("shengwuqishilu3") then
        modimport("ray/shengwuqishilu.lua")
    end
end

-----------------------------------------------------------------------------------------

-- Optional upstream survival modes; independent of Easy/Hard Mode.
if GetModConfigData("贝爷求生") then modimport("ray/beye.lua") end
if GetModConfigData("德爷生存") then modimport("ray/deyeshengcun.lua") end
if GetModConfigData("difficulty_rating") then modimport("common/difficulty.lua") end -- Private, on-demand /nd only.
