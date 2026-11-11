import { characterArticles } from './character-articles.mjs';
import { exclusiveArticles } from './exclusive-articles.mjs';
import { foodArticles } from './food-articles.mjs';
import { additionalArticles } from './additional-articles.mjs';
import { gemCreatureArticles } from './gem-creature-articles.mjs';
import { caveBossArticles } from './cave-boss-articles.mjs';
import { creatureArticles } from './creature-articles.mjs';
import { surfaceBossArticles } from './surface-boss-articles.mjs';
import { worldExpansionArticles } from './world-expansion-articles.mjs';
import { bossRewardArticles } from './boss-reward-articles.mjs';
import { equipmentExpansionArticles } from './equipment-expansion-articles.mjs';
import { toolExpansionArticles } from './tool-expansion-articles.mjs';
import { effectTable, gemEffects, tradeTable } from './gemology-tables.mjs';
import { gemSources, gemSourceTitle, geodeSources, geodeSourceTitle, sourceJumps } from './gemology-sources.mjs';

export const auditedVersion='6.0.3.8';
export const auditedCnVersion='20260926.1';

const beta=(file,line)=>({file,line});
const cn=(file,line)=>({kind:'cn',file,line});
const cfg=line=>beta('modinfo.lua',line);
const names=line=>cn('init/init_strings/init_names.lua',line);
const recipe=line=>beta('init/init_recipes/recipes.lua',line);
const character=line=>cn('init/init_character_um.lua',line);
const articleLinks=entries=>entries.map(({id,title})=>({href:id+'.html',label:title}));

export const articles=[
 {
  id:'creature-guide',category:'creatures',icon:'hoodedwidow',title:'生物与首领速查',aliases:['生物图鉴','怪物图鉴','Boss','首领攻略'],
  searchJumps:[{terms:['生物改动','生物图鉴','首领','Boss','Boss攻略','首领攻略']}],
  summary:'从地表、海上到洞穴和终局，按名字查生成条件、打法和战利品。',
  configs:[],
  sections:[
   ['连帽森林与宝石相关生物','从黑寡妇的开战方式查到虫茧和寡妇装备，也可以直接查参与宝石交易或掉落的生物。',null,articleLinks(gemCreatureArticles)],
   ['地表与海上首领','按首领查看出现时机、妥协测试版的战斗改动和奖励。',null,articleLinks([...surfaceBossArticles,{id:'summer-dragonflies',title:'时令龙蝇与月光龙蝇'}])],
   ['洞穴与终局首领','从遗迹守护者查到终局战斗，也可以查季节性的洞穴威胁。',null,articleLinks(caveBossArticles)],
   ['其他生物与变种','查座狼、深渊蠕虫、蝙蝠、蜘蛛和地热螨等生物的应对方式。',null,articleLinks([...creatureArticles,{id:'rat-raids',title:'鼠潮与鼠穴'},{id:'dread-eye',title:'恐惧之眼'}])],
  ],
  sources:[gemCreatureArticles[0].sources[0],surfaceBossArticles[0].sources[0],caveBossArticles[0].sources[0],creatureArticles[0].sources[0]],
 },
 {
  id:'thermal-stone',category:'items',title:'暖石保温调整',aliases:['暖石','Thermal Stone','heatrock'],
  summary:'暖石有基础保温，并按持有者的冬夏保温能力分别加成。',
  configs:['insul_thermalstone'],
  sections:[
   ['保温如何结算','重做默认开启。暖石的基础冬季保温和夏季隔热均为 30，取自游戏的 INSULATION_TINY。温度变化时会分别加上持有者对应保温值的一半。没有能提供温度属性的持有者时，两项恢复到基础值。'],
  ],
  sources:[cfg(685),beta('postinit/prefabs/heatrock.lua',12),beta('init/init_postinit.lua',135)],
 },
 {
  id:'sewing-kit',category:'items',title:'针线包调整',aliases:['针线包','Sewing Kit','sewing_kit'],
  summary:'启用重做后，针线包可用 10 次，每次的修补值为 1,200。',
  configs:['sewingkit'],
  sections:[
   ['使用次数与修补量','重做默认开启。模组把针线包的使用上限设为 10 次，单次修补值设为 1,200。修补目标还取决于物品自身的可修补组件。'],
  ],
  sources:[cfg(661),beta('init/init_durability.lua',1),beta('init/init_gamemodes/init_uncompromising_mode.lua',169)],
 },
 {
  id:'rat-raids',category:'creatures',title:'鼠潮与鼠穴',aliases:['Rat Raids','背包鼠','穴居鼠','花衣吹笛者'],
  summary:'食物储存和开关容器都可能影响地表鼠潮。周期嗅探与容器触发走两条路径。',
  configs:['rat_raids','rattimer','ratgrace','ratsnifftimer'],
  sections:[
   ['计时与嗅探','默认开启。周期计时默认 9,600 秒，嗅探间隔默认 120 秒。周期嗅探要等世界周期计数严格大于宽限值，默认宽限值为 30。默认森林地表挂载鼠潮组件，普通洞穴没有这一路径。'],
   ['食物和容器','鼠群会检查附近鼠穴与食物。地面上不新鲜或腐坏的食物比存进容器的同类食物贡献更多嗅探分，料理按双倍计算，食物堆叠数量也计入。关闭木箱、冰箱、盐盒等容器以及收获锅中料理，可发出独立的鼠潮事件。'],
   ['宽限的适用范围','容器事件分支独立于周期宽限。在满足玩家附近的实体数量、可用位置与袭击状态条件时，可提前进入预警。',null,[{href:'rat-poison.html',label:'用毒果酱陷阱处理鼠群'}]],
  ],
  sources:[cfg(229),cfg(578),beta('init/init_ratraid.lua',4),beta('init/init_ratraid.lua',35),beta('scripts/components/ratcheck.lua',213),beta('scripts/components/ratcheck.lua',301),beta('scripts/prefabs/uncompromising_rat.lua',1742),names(18)],
 },
 {
  id:'food-recovery',category:'mechanics',title:'食物持续恢复',aliases:['Food Regen','回血','回理智'],
  summary:'食物恢复较多的生命或理智时，默认会改为持续结算。',
  configs:['foodregen'],
  sections:[
   ['即时与持续','默认开启。生命和理智分别判定，单项结算量大于 3 时进入持续恢复，其基础时长参数为该项结算量乘 0.1。数值不超过 3 或角色持有对应免疫标签时即时结算。饱食度按进食逻辑结算。'],
   ['重复进食','持续效果按食物 prefab 区分。再次吃同一种食物会延长对应效果，累计剩余时长受基础时长四倍的上限约束。老兵诅咒相关结算有独立分支。'],
  ],
  sources:[cfg(226),beta('init/init_food/init_foodregen.lua',4),beta('init/init_food/init_foodregen.lua',41),beta('scripts/prefabs/healthregenbuff_vetcurse.lua',24),beta('scripts/prefabs/healthregenbuff_vetcurse.lua',101)],
 },
 {
  id:'snowstorms',category:'world',title:'暴风雪与雪堆',aliases:['Snowstorms','猫眼护目镜','尖刺霜草'],
  summary:'冬季暴风雪分全域和局部天气，防护装备与近距离掩体能抵消移动惩罚。',
  configs:['snowstorms','weatherhazard_winter'],
  sections:[
   ['触发','暴风雪默认开启。进入冬季或载入世界时，世界周期达到默认门槛 5 后可以启动或恢复计时。新计时为 3 个游戏日再加 0–120 秒。计时到期后，通常先预警约 60 秒，再进入持续 320–360 秒的暴雪。冬季结束会停止暴雪与计时。'],
   ['移动和防护','全域暴雪或局部暴雪中，无防护玩家移速乘 0.75。护目镜视野、骑乘、熊皮背心、雨罩，或角色 6 单位内有适用的墙、火或掩体，均可免去该移动惩罚。',null,[{href:'snow-goggles.html',label:'猫眼护目镜的用法'},{href:'rime-helmet.html',label:'查霜兽头盔'}]],
   ['雪堆','玩家监测器可以在暴雪中生成雪堆。建筑脚本中隐藏容器的积雪逻辑当前处于注释状态，岩浆池和龙鳞火炉等仍有防雪堆标签。',null,[{href:'rimeweed.html',label:'尖刺霜草与局部暴雪'},{href:'snowmong.html',label:'雪怪与雪堆'},{href:'saltpack.html',label:'用盐瓶3000除雪'}]],
  ],
  sources:[cfg(451),cfg(463),beta('init/init_weather/init_harder_weather.lua',130),...[11,100,123,141,176].map(line=>beta('scripts/components/um_snow_stormspawner.lua',line)),beta('scripts/components/snowstormwatcher.lua',45),beta('init/init_weather/init_snowstorm_structures.lua',126),names(35),names(692)],
 },
 {
  id:'cave-worldgen',category:'world',title:'熔岩洞穴与潮湿陷坑',aliases:['Magma Caves','Flooded Caves','月岛','蓝蘑菇林'],
  summary:'洞穴配置会改变新世界的地形、入口和宝石学锻造台的位置。',
  configs:['worldgenmastertoggle','magma_caves','flooded_caves','gemology'],
  sections:[
   ['潮湿陷坑的三种档位','默认 lunar_cave 在月岛提供潮湿陷坑入口，对应离大陆洞穴区域。cave 将相关区域放在蓝蘑菇林方向。off 保留原版月亮石窟。',null,[{href:'lunar-island.html',label:'月岛地形与入口'}]],
   ['熔岩洞穴与锻造台','熔岩洞穴和宝石学默认开启。两者同时启用时，新洞穴在熔岩区域要求生成宝石学锻造台。关闭熔岩洞穴并保留宝石学时，锻造台转入远古遗迹。',null,[{href:'gemology.html#gemology-s8',label:'查洞穴各地形的晶洞'}]],
  ],
  sources:[cfg(556),beta('scripts/map/tasks/forest/moonisland.lua',19),beta('scripts/map/tasks/caves/mushroom_tasks.lua',46),beta('scripts/map/tasks/caves/magma_cave.lua',103),names(784)],
 },
 {
  id:'gemology',category:'mechanics',title:'宝石学与装备附魔',aliases:['Gemology','晶洞','宝石学锻造台','鉴定'],
  searchJumps:[{terms:['宝石','宝石学','宝石附魔学']},{section:'锻造台操作',terms:['附魔','装备附魔','锻造台','宝石学锻造台','宝石附魔','附魔石']},{section:'鉴定工具',terms:['鉴定','宝石鉴定']},
   {section:'宝石升级与交易速查',terms:['附魔升级','宝石升级','交易升级','宝石交易','宝石升级路径','附魔宝石升级路径']},
   {section:'三级附魔效果',terms:['附魔效果','宝石品质','三级附魔','附魔宝石效果']},
   ...gemEffects.map(gem=>({section:'三级附魔效果',prefab:gem.prefab,title:gem.name,terms:[gem.name,gem.english,gem.prefab,...(gem.prefab==='um_gemologyyellowgem1'?['迅疾黄玉移速','迅疾黄玉加速']:[])],summary:gem.levels[2]})),...sourceJumps],
  summary:'逐种查 14 种附魔宝石的晶洞来源、地形、交易升级和三档附魔效果。',
  configs:['gemology','magma_caves','worldgenmastertoggle'],
  sections:[
   ['晶洞掉落','把晶洞放在地上，用镐敲开。每个晶洞抽三次普通材料、一次宝石池，并有 5% 概率额外抽一次宝石池。抽到附魔宝石后再判定品质，一级 95%、二级 4%、三级 1%。',null,[{href:'#gemology-s7',label:'按宝石查来源'},{href:'#gemology-s8',label:'按地形查晶洞'}]],
   ['锻造台操作','第一槽放装备，第二槽放宝石。装备与宝石相容时才能附魔。成功会消耗宝石，新附魔耐久设满。重复同种附魔会替换同种，槽满时新增不同种会移除旧附魔。普通附魔组件默认一个槽，具体装备可以有特例。',null,[{href:'mending-kit.html',label:'修补装备与附魔耐久'}]],
   ['配置的作用','宝石学和世界生成总开关默认开启，共同控制新洞穴的宝石学地形与资源。既有地图不会因打开这两个开关而补生成相应房间。已有装备与附魔还涉及单独载入的运行代码。'],
   ['鉴定工具','宝石放大镜有 100 点鉴定耐久，远古宝石放大镜和宝石熔岩镜各有 400 点。可以鉴定整叠宝石，每枚消耗 1 点耐久。耐久不足时，只会鉴定能够负担的数量。',null,[{href:'gem-magnifiers.html',label:'放大镜的制作、鉴定与耐久'}]],
   ['宝石升级与交易速查','以下概率按单颗宝石结算，适用于各颜色的两种附魔宝石。三级已经封顶，交出去有风险。红色交蜗龙只有 25% 留在三级，绿色交龟类只有 40% 留在三级。蚁狮和石虾都不会返还三级，雪怪吃下三级蓝色只掉普通蓝宝石。',tradeTable],
   ['三级附魔效果','汉化中的「碎裂的」「微瑕的」「无暇的」分别对应一级、二级、三级。表中同时列出装备附魔和角色组件触发的效果，涉及移速、工作、战斗、理智和拾取。装备自身还须支持附魔。',effectTable],
   [gemSourceTitle,'同色的两种宝石，能掉落它们的晶洞也可能不同。表中百分比是每次从该晶洞的宝石池抽取时，命中指定宝石的概率，已计入普通宝石等候选掉落。点击晶洞名可查看对应的地形和采集方法。',gemSources],
   [geodeSourceTitle,'先从下表的地形取得晶洞，再放到地上用镐敲开。石化蘑菇树与几类矿物都有外观相近的无晶洞版本。',geodeSources,[{href:'cave-worldgen.html',label:'查洞穴地形与房间设置'}]],
   ['巨石枝与旧档','斧砍长成的巨石枝时，藤上掉落按种植位置所属地形的池子抽取。三色蘑菇林、混合菌类区、月亮洞窟、苔藓区、岩石平原、蝙蝠洞、遗迹、喷气孔区和落水洞的池子均能提供对应晶洞。旧树沿用已经保存的掉落，在现有对应地形重新种植可以抽当前池。开启宝石学和蘑菇树调整时，绿树入夏、红树入秋、蓝树入春也有机会自然石化。秋天已有的石虾附近还可能生成孕育中的岩石。'],
   ['虫茧的高品质宝石','到地表连帽森林的黑寡妇巢旁，用寡妇之爪破开茧。蛞蝓龟或蜗牛龟型、雪怪型、蜗龙型、石虾型的茧各随机给一颗绿、蓝、红、白色附魔宝石，同色两种都可能出现。每颗有 90% 概率为二级、10% 为三级。遗迹迷宫和远古守护者的箱子还可能提供已经附魔的装备。',null,[{href:'hooded-widow.html#hooded-widow-s1',label:'黑寡妇在哪、怎么开战'},{href:'widows-grasp.html',label:'寡妇之爪与开茧'},{href:'ancient-guardian.html#ancient-guardian-s3',label:'远古守护者的附魔战利品'}]],
   ['岛屿冒险的额外来源','海难的熔岩地与火山中，开采普通或含金熔岩矿时，14 种附魔宝石都以相同的低权重加入额外掉落池。黑曜石岩石和龙骑士蛋各有 10% 概率给熔岩晶洞，木炭岩有 10% 概率给浮石晶洞。启用岛屿冒险的老虎机战利品时，部分老虎机奖池还会给晶洞。'],
  ],
  sources:[cfg(184),beta('scripts/prefabs/um_gemology_geodes.lua',17),beta('scripts/prefabs/um_gemologyforge.lua',25),beta('scripts/components/gem_enchantable.lua',25),beta('init/init_gamemodes/init_uncompromising_mode.lua',92),beta('scripts/prefabs/um_magnifier.lua',55),beta('scripts/components/gemologyscanner.lua',13),
   ...[87,247,261,411,493].map(line=>beta('init/init_gemology/trades.lua',line)),beta('scripts/prefabs/snowmong.lua',123),beta('scripts/stategraphs/SGsnowmong.lua',329),
   ...[90,228,301,353,421,450,472,581,648,689,742,789,842].map(line=>beta('scripts/gemology_defs.lua',line)),beta('init/init_tuning.lua',400),beta('init/init_gemology/special.lua',5),beta('postinit/components/freezable.lua',21),beta('scripts/prefabs/um_ice_shield.lua',37),names(752),names(764),names(770),names(821),names(853),
   ...[44,83,111,129,149].map(line=>beta('init/init_gemology/special.lua',line)),beta('init/init_gamemodes/init_uncompromising_mode.lua',93),...[79,92,121].map(line=>beta('postinit/components/combat.lua',line)),
   beta('scripts/prefabs/uncompromising_buffs.lua',6),beta('scripts/prefabs/uncompromising_buffs.lua',451),beta('scripts/prefabs/um_ice_shield.lua',69),beta('scripts/prefabs/um_ice_shield.lua',108),beta('init/init_containers.lua',1000),
   cfg(167),beta('modworldgenmain.lua',31),beta('scripts/um_gemology_geode_defs.lua',1),beta('scripts/prefabs/um_gemology_geodes.lua',97),
   ...[3,47,128,141,167].map(line=>beta('scripts/map/tasks/caves/gemology.lua',line)),...[2,55,117,166,198,231,249].map(line=>beta('scripts/map/rooms/caves/gemology.lua',line)),beta('scripts/map/rooms/caves/moonregions.lua',243),beta('scripts/map/rooms/caves/moltenregions.lua',311),
   beta('scripts/prefabs/um_mushtrees_petri.lua',179),beta('scripts/prefabs/um_guano_rock.lua',17),beta('scripts/prefabs/um_rocklobster_rock.lua',19),beta('scripts/prefabs/um_moonglass_ceiling.lua',50),beta('scripts/prefabs/um_moonglass_ceiling.lua',144),beta('scripts/prefabs/um_slimestone_rock.lua',18),beta('scripts/prefabs/um_sinkmound_rock.lua',34),beta('scripts/prefabs/um_magmastone.lua',19),beta('scripts/prefabs/um_magmastone.lua',59),beta('postinit/prefabs/chessjunk.lua',78),beta('postinit/prefabs/cave_vent_mite.lua',20),beta('init/init_strings/init_names.lua',830),names(842),
   beta('init/um_tree_rock_data.lua',34),beta('init/um_tree_rock_data.lua',83),beta('init/init_gamemodes/init_uncompromising_mode.lua',256),beta('postinit/prefabs/mushtrees.lua',34),beta('postinit/prefabs/mushtrees.lua',84),beta('postinit/prefabs/rocky.lua',19),beta('scripts/map/tasks/forest/giant_trees.lua',11),...[404,515,615,713].map(line=>beta('scripts/webbedcreatureloot.lua',line)),beta('scripts/prefabs/webbedcreature.lua',108),beta('scripts/prefabs/widowsgrasp.lua',22),beta('init/init_gemology/misc.lua',10),beta('init/init_compat.lua',244),beta('init/init_compat.lua',282),beta('init/init_compat.lua',320),names(233),names(303)],
 },
 {
  id:'winky',category:'characters',title:'温奇',aliases:['Winky','鼠人','定居鼠穴'],
  summary:'温奇擅长地下通道和鼠穴储物，夜间走得更快。',
  configs:['funny rat'],
  sections:[
   ['基础属性','生命 175、饥饿 175、理智 125。移动倍率白天和黄昏为 1.15，夜间为 1.25。可以吃生肉和怪物肉。丢下非重物或触发符合条件的堆叠合并通常会扣 5 理智。'],
   ['鼠穴','空手右键合适的地面可打临时鼠穴。服务端要求饥饿严格大于 15 且未站在船等平台上，打洞消耗 15 饥饿，临时鼠穴约 180 秒消失。定居鼠穴消耗 20 饥饿，每个分片受一处定居鼠穴的限制。两类鼠穴在同一分片连接温奇的口袋空间。'],
   ['老兵诅咒','诅咒激活时，普通物品栏从 15 格降到 10 格，后 5 格的内容会被丢出。'],
  ],
  sources:[cfg(265),beta('modmain.lua',113),beta('scripts/prefabs/winky.lua',61),beta('scripts/prefabs/winky.lua',145),beta('scripts/prefabs/winky.lua',170),beta('init/init_actions.lua',140),recipe(737),beta('scripts/prefabs/uncompromising_rat.lua',1463),character(6)],
 },
 {
  id:'wixie',category:'characters',title:'薇希',aliases:['Wixie','薇茜','维希','弹弓妹','沃尔特重做'],
  summary:'测试版默认启用薇希和沃尔特重做，加入幽闭恐惧与专属弹弓配方。',
  configs:['wixie_walter'],
  sections:[
   ['角色与译名','相关配置默认开启。薇希的生命为 130、饥饿 150、理智 200。汉化的角色初始化写作「薇希」，角色专用文本又使用「薇茜」。两种写法都可搜索。'],
   ['幽闭恐惧','附近战斗生物、躲藏、骑乘、邻近墙壁或树木以及部分护具都会影响幽闭恐惧。部分头部和身体护甲各增加 0.2 的基础影响。累积到 100% 触发恐慌，降到 0 后解除并进入 10 秒冷却。'],
   ['弹弓','专属弹弓包括浮木弹弓-玛蒂尔达、活木弹弓-切齿、绝望弹弓-杰西和光芒弹弓-克莱尔。杰西和克莱尔分别在暗影与月亮制作站制作，最终生效的配方仅检查薇希制作标签和制作站。'],
   ['衣橱谜题','解开地表的钢琴、破旧玩具与摆钟谜题可召出暗影薇希，击败后获得滑行手杖。薇希使用手杖冲刺时会把敌人推得更远。',null,[{href:'charlies-slider.html#charlies-slider-s2',label:'滑行手杖与衣橱谜题解法'}]],
  ],
  sources:[beta('modmain.lua',355),beta('modmain.lua',382),beta('scripts/prefabs/wixie.lua',77),beta('scripts/prefabs/wixie.lua',176),beta('init/init_recipes/init_recipes.lua',84),beta('init/init_recipes/recipes_wixie.lua',11),beta('init/init_recipes/recipes_wixie.lua',141),character(18),cn('wixie_postinit/wixie_strings.lua',9),names(571)],
 },
 {
  id:'wathom',category:'characters',title:'沃托姆',aliases:['Wathom','跳劈哥','肾上腺素'],
  summary:'沃托姆靠近战积攒肾上腺素，强化状态与技能和房间配置有关。',
  configs:["holy fucking shit it's wathom",'wathom_ampvulnerability','wathom_armordamage'],
  sections:[
   ['基础属性','角色默认可用，生命 225、饥饿 120、理智 120。'],
   ['肾上腺素','肾上腺素至少 25% 时，符合条件的非投射物攻击会推迟自然衰减 10 秒。未进入强化或拒死状态时，25% 至不足 50%、50% 至不足 75%、75% 以上分别获得 5、4、3 点。肾上腺素至少 25%、且未强化时，部分受伤也可按伤害的 25% 向下取整增加。'],
   ['强化与代价','满肾上腺素进入强化要求对应的第二档强化技能。强化时默认承伤倍率为 5，房间可选 2 到 5，配置默认也计入护甲损耗。'],
  ],
  sources:[cfg(266),cfg(269),beta('scripts/prefabs/wathom.lua',12),beta('scripts/prefabs/wathom.lua',359),beta('scripts/prefabs/wathom.lua',535),beta('init/init_wathom.lua',1576),character(25)],
 },
 {
  id:'summer-dragonflies',category:'creatures',title:'时令龙蝇与月光龙蝇',aliases:['Wiltfly','Moonmaw Dragonfly','注能的玻璃碎片','启迪鳞片'],
  summary:'两种龙蝇共享地表季节生成器，月光龙蝇需要额外的世界进度和月亮条件。',
  configs:['wiltfly','wiltfly_spawn'],
  sections:[
   ['何时出现','额外夏季龙蝇默认开启。常规生成要求地表有活跃玩家、当前为夏季，世界周期高于房间档位，默认档位为 26。世界周期高于 50 后，在满月或天体祭坛激活的条件下，生成器可改用月光龙蝇。'],
   ['时令龙蝇','默认 4,000 生命。基础单次攻击为 125，面对玩家另有 0.5 倍伤害系数。基础掉落是 8 大肉和 1 鳞片。'],
   ['月光龙蝇','默认 8,000 生命，基础单次攻击为 100，面对玩家有 0.5 倍伤害系数。免疫火焰，半血会刷新玻璃熔岩虫。基础掉落为 8 大肉、1 启迪鳞片和 3 个可开采的注能玻璃晶体（汉化名称为「注能的玻璃碎片」）。每个晶体放在地上开采一次，产出 6–10 个注能月亮碎片。',null,[{href:'moon-scale-armor.html#moon-scale-armor-s1',label:'月鳞甲的制作材料'}]],
  ],
  sources:[cfg(927),cfg(1237),cfg(1349),beta('scripts/components/mock_dragonflyspawner.lua',56),beta('scripts/components/mock_dragonflyspawner.lua',186),beta('scripts/prefabs/mock_dragonfly.lua',467),beta('scripts/prefabs/moonmaw_dragonfly.lua',356),beta('scripts/prefabs/moonmaw_dragonfly.lua',633),beta('scripts/prefabs/glass_scales.lua',2),beta('scripts/prefabs/glass_scales.lua',43),names(53),names(60)],
 },
 {
  id:'dreadstone-shield',category:'new-items',title:'绝望石圆盾',aliases:['Dreadstone Shield','女武神','维格弗德'],
  summary:'女武神技能装备，可以格挡并使符合条件的攻击者恐慌。',
  configs:['wathgrithr_rework_'],
  sections:[
   ['制作','女武神重做选择 1 或 3 档，并点出对应的圆盾技能。配方为绝望石 6、纯粹恐惧 4、暗影碎布 1。'],
   ['属性与格挡','基础 41 普通伤害、20 位面伤害和 5 位面防御，耐久为基础女武神圆盾的两倍。成功格挡会让符合条件的攻击者恐慌 5 秒。主动挥击消耗 3 点基础耐久。'],
  ],
  sources:[cfg(360),recipe(669),beta('init/init_tuning.lua',39),beta('scripts/prefabs/wathgrithr_shield_dreadstone.lua',154),beta('scripts/prefabs/wathgrithr_shield_dreadstone.lua',290),names(811)],
 },
 {
  id:'beak-basher',category:'new-items',title:'喙击者',aliases:['Beak Basher','多目章鱼喙','锤子'],
  summary:'可用来战斗和拆建筑的锤子。',
  configs:[],
  sections:[
   ['制作','需要炼金引擎。配方为漂流木 2、海带 8、多目章鱼喙 1。'],
   ['用途','武器基础伤害为 51，锤击工作效率为普通值的 2 倍。满耐久为 425 次使用，每次锤击消耗 1 次。'],
  ],
  sources:[recipe(655),beta('scripts/prefabs/beakbasher.lua',51),names(550)],
 },
 {
  id:'veterans-curse',category:'mechanics',title:'老兵诅咒',aliases:["Veteran's Curse",'头骨洞窟','诅咒神龛'],
  summary:'可选难度，激活方式由服务器设置决定，效果因角色而异。',
  configs:['vetcurse','ui_showvetcurse'],
  sections:[
   ['房间档位','默认档允许通过头骨洞窟开启，已激活的状态可随存档恢复。始终开启档会在玩家初始化时施加诅咒。房间另有关闭档。'],
   ['角色差异','诅咒有角色专属效果。例如温奇会失去 5 个普通物品栏槽位。客户端可单独切换诅咒图标显示。'],
   ['首领装备','默认与始终开启档会让部分首领追加装备掉落，击杀者无需受诅咒。穿戴带有诅咒要求的装备时，通常要先让角色进入老兵诅咒状态。',null,[{href:'gore-horn-hat.html',label:'犀牛帽'},{href:'silk-sack.html',label:'蛛丝背包'},{href:'cursed-antler.html',label:'诅咒鹿角'}]],
  ],
  sources:[cfg(146),cfg(231),beta('init/init_vetcurse.lua',173),beta('scripts/prefabs/veteranshrine.lua',72),beta('scripts/map/tasks/forest/make_a_pick.lua',6),beta('scripts/prefabs/winky.lua',170),beta('postinit/prefabs/vetcurse_drops.lua',9),beta('scripts/tools/um_commonfns.lua',204),names(78),cn('init/init_strings/init_strings.lua',267)],
 },
 {
  id:'dread-eye',category:'creatures',title:'恐惧之眼',aliases:['Dread Eye','暗影生物','影怪'],
  summary:'强化梦魇生物中的伏击者，能用诱饵外观伪装。',
  configs:['harder_shadows','dreadeyes_allowed'],
  sections:[
   ['出现条件','强化梦魇生物和恐惧之眼两个开关默认启用。强化生成器为低于 50% 理智的目标挑选普通暗影时，陆地和海上的候选分支都可能选到恐惧之眼。'],
   ['战斗','基础生命 250、伤害 35、攻击间隔 6 秒。它会在玩家附近伪装后伏击，基础掉落为 1 个噩梦燃料。'],
  ],
  sources:[cfg(244),beta('init/init_creatures/init_harder_shadows.lua',71),beta('scripts/components/uncompromising_shadowcreaturespawner.lua',84),beta('scripts/prefabs/dreadeye.lua',280),beta('scripts/prefabs/dreadeye.lua',509),names(16)],
 },
 {
  id:'mending-kit',category:'new-items',prefab:'um_gem_repair_kit',title:'修补工具包',aliases:['Mending Kit','宝石修补工具包','修理附魔','附魔耐久'],
  summary:'同时修补符合条件的装备本体和附魔耐久，同一件装备修得越多，每次恢复越少。',
  configs:['gemology'],
  sections:[
   ['制作与使用','开启宝石学后，用坚钢钻石 ×1、钢丝绒 ×2、海象牙 ×1 在暗影操纵器制作。拿起工具包对装备右键修理。一个工具包最多成功使用 5 次。'],
   ['恢复量','同一件装备第 1、2、3、4 次及以后，分别恢复本体耐久上限的 60%、40%、20%、10%。有独立附魔耐久的附魔在前 3 次分别恢复 50%、20%、0%，之后仍为 0%。次数记在装备上并随存档保存。'],
   ['适用范围','本体修理适用于有使用次数的装备和可破坏护甲。附魔修理要求该附魔启用独立耐久。即使后期附魔的恢复量已经是 0，只要它还未满且进入该修理分支，操作仍会计为成功并消耗工具包次数。',null,[{href:'gemology.html#gemology-s6',label:'查附魔效果'}]],
  ],
  sources:[recipe(88),beta('scripts/prefabs/um_gem_repair_kit.lua',35),beta('scripts/prefabs/um_gem_repair_kit.lua',55),beta('init/init_actions.lua',699),beta('scripts/components/gemrepairer.lua',17),beta('init/init_tuning.lua',514),beta('init/init_gemology/misc.lua',247),beta('init/init_strings/init_names.lua',872)],
 },
 {
  id:'cooking-guide',category:'mechanics',icon:'cookpot',title:'测试版料理速查',aliases:['烹饪','锅料理','新料理','Crock Pot'],
  searchJumps:[{terms:['料理','食谱','测试版料理','妥协料理']}],
  summary:'按菜名查配料、基础三维、保鲜时间与特殊效果，涵盖 12 道测试版锅料理。',
  configs:['newrecipes','foodregen','food_stats'],
  sections:[
   ['从哪里下锅','新增食谱默认开启。普通锅、便携烹饪锅和远古锅均可煮常规新增食谱。标为沃利专用的配方只注册在便携烹饪锅。'],
   ['看懂配方','写明材料数量的要求要放指定食材；写成蛋值、肉值等的是食材标签的合计。部分食谱还限制填充料，点进菜品查看可用搭配。'],
   ['看懂数值','料理词条列的是基础数值。房间的食物持续恢复设置会影响回复如何结算，食物属性调整也可能改变部分食物的实际数值。'],
  ],
  related:foodArticles.map(food=>({id:food.id,label:food.title})),
  sources:[cfg(700),beta('init/init_food/init_crockpot.lua',605),beta('scripts/um_preparedfoods.lua',4),beta('init/init_gamemodes/init_uncompromising_mode.lua',217),beta('init/init_gamemodes/init_uncompromising_mode.lua',247)],
 },
 ...characterArticles,
 ...exclusiveArticles,
 ...foodArticles,
 ...additionalArticles,
 ...gemCreatureArticles,
 ...caveBossArticles,
 ...creatureArticles,
 ...surfaceBossArticles,
 ...worldExpansionArticles,
 ...bossRewardArticles,
 ...equipmentExpansionArticles,
 ...toolExpansionArticles,
];
