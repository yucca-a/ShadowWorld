const beta=(file,line)=>({file,line});
const names=line=>({kind:'cn',file:'init/init_strings/init_names.lua',line});
const cfg=line=>beta('modinfo.lua',line);
const hound=line=>beta('scripts/prefabs/uncompromising_hounds.lua',line);
const houndWave=line=>beta('postinit/components/hounded.lua',line);
const shock=line=>beta('scripts/prefabs/shockworm.lua',line);
const viper=line=>beta('scripts/prefabs/viperworm.lua',line);
const fruitbat=line=>beta('scripts/prefabs/fruitbat.lua',line);
const vampire=line=>beta('scripts/prefabs/um_vampirebat.lua',line);
const spider=line=>beta('scripts/prefabs/spider_trapdoor.lua',line);
const link=(id,label)=>({id,label});

export const creatureArticles=[
 {
  id:'glacial-hound',category:'creatures',icon:'glacialhound',title:'冰川青年座狼',aliases:['Glacial Hound','冰川猎犬','冰座狼','冰盾'],
  summary:'冬季升级猎犬波会带来的重型猎犬，自带冰盾，能沿直线放出冰刺。',
  configs:['glacialhounds'],
  sections:[
   ['生成地形与条件','默认开启。在地表冬季猎犬袭击中，可以占用一只升级猎犬的名额。猎犬波的升级判定从 5 只开始，规模越大越容易升级。海象营地的随从配置也有生成它的分支。'],
   ['打法','本体生命 750，基础咬击伤害 40，冰刺伤害 30。生成时会获得 400 点冰盾，破盾后约 50 秒可再生。蓄力时近战会被反冻，看到它蓄力朝向自己时横向离开冰刺路径。炽烈石榴石附魔、黑曜石工具等可以让攻击免于冰盾反弹。死亡后原地还会留 6 秒冰圈。',null,[{href:'gemology.html#gem-redgem2',label:'查看炽烈石榴石的附魔效果'}]],
   ['掉落','必掉 3 块怪物肉、1 颗犬牙、1 块冰和 1 颗普通蓝宝石。另有独立的 50% 怪物肉、33% 犬牙和 50% 冰。'],
  ],
  related:[link('magma-hound','熔岩青年座狼'),link('wx78','WX-78 生物扫描')],
  sources:[cfg(778),houndWave(194),houndWave(203),beta('postinit/prefabs/walrus_camp.lua',309),beta('init/init_tuning.lua',154),hound(98),hound(709),hound(717),hound(774),hound(830),hound(868),beta('postinit/stategraphs/SGhound.lua',223),beta('scripts/prefabs/um_ice_shield.lua',15),beta('scripts/prefabs/um_ice_shield.lua',53),beta('scripts/prefabs/glacialhound_icespike.lua',176),names(295)],
 },
 {
  id:'magma-hound',category:'creatures',title:'熔岩青年座狼',aliases:['Magma Hound','熔岩猎犬','岩浆猎犬','火座狼'],
  summary:'地表夏季的升级猎犬，免疫火焰伤害，会向正面持续喷火。',
  configs:['magmahounds'],
  sections:[
   ['生成地形与条件','默认开启。在地表夏季猎犬袭击中，可以占用一只升级猎犬的名额。升级判定从 5 只开始，规模越大越容易升级。'],
   ['打法','生命 750，基础伤害 40。它会投火球、朝正面喷火，咬击也能点燃目标。蓄力时近战会受到 5 点火焰伤害并可能着火，适合绕开喷火正面后再打。它本身免疫火焰伤害。死后原地火圈还会持续 4 秒。'],
   ['掉落','必掉 4 块怪物肉、1 颗犬牙、1 块燧石、1 块石头和 1 颗普通红宝石。另有独立的 50% 怪物肉、33% 犬牙和 50% 石头。'],
  ],
  related:[link('glacial-hound','冰川青年座狼')],
  sources:[cfg(780),houndWave(197),houndWave(203),beta('init/init_tuning.lua',150),hound(77),hound(979),hound(989),hound(1036),hound(1093),hound(1113),hound(1147),hound(1168),names(293)],
 },
 {
  id:'lightning-hound',category:'creatures',title:'闪电猎犬',aliases:['Lightning Hound','闪电狗','电狗','春季猎犬'],
  summary:'地表春季的猎犬变体，会游泳，也会在蓄电时反击近战。',
  configs:['lightninghounds'],
  sections:[
   ['生成地形与条件','默认开启。地表春季的猎犬波选到季节变体分支后，有机会生成闪电猎犬。两栖属性允许它追进海水。'],
   ['打法','生命 150，基础伤害 20，攻击带电。看到蓄电时用远程攻击，或戴有电绝缘效果的装备，避免近战反电。潮湿会提高未绝缘目标受到的反电伤害。死亡时原地也会触发闪电，基础 10 点伤害，未绝缘目标还要乘电属性和潮湿倍率。等闪电过去再捡战利品。'],
   ['掉落','必掉怪物肉、犬牙和金块各 1 个，另有 50% 概率多掉 1 块金块。'],
  ],
  related:[link('spore-hound','孢子猎犬'),link('shockworm','洞穴电鳗')],
  sources:[cfg(779),houndWave(25),houndWave(191),hound(69),hound(572),hound(578),hound(646),hound(671),beta('postinit/stategraphs/SGhound.lua',188),beta('scripts/prefabs/hound_lightning.lua',70),beta('init/init_tuning.lua',158),names(291),names(292)],
 },
 {
  id:'spore-hound',category:'creatures',title:'孢子猎犬',aliases:['Spore Hound','孢子狗','秋季猎犬','孢子云'],
  summary:'地表秋季的猎犬变体，吐出孢子云，死后也会在原地留云。',
  configs:['sporehounds','maxhphitters'],
  sections:[
   ['生成地形与条件','默认开启。地表秋季的猎犬袭击进入季节变体分支后，有机会生成孢子猎犬。'],
   ['打法','生命 150，基础咬击伤害 20。主动放云时，对 2.5 距离内的敌对目标额外结算 25 伤害。击杀后也会生成孢子云，适合离开云区再继续对付其他猎犬。启用生物生命上限惩罚时，每次咬中普通玩家还会增加 5 个百分点的上限惩罚，具有瘟疫面具标签或机器人的目标除外。'],
   ['掉落','必掉 1 个腐烂食物和 1 颗犬牙，另有 50% 概率掉 1 个蘑菇皮碎片。'],
  ],
  related:[link('lightning-hound','闪电猎犬')],
  sources:[cfg(204),cfg(781),houndWave(25),houndWave(188),hound(110),hound(572),hound(578),hound(1180),hound(1209),hound(1220),names(294)],
 },
 {
  id:'shockworm',category:'creatures',icon:'shockworm',title:'洞穴电鳗',aliases:['Depths Eel','Shockworm','电鳗','电蠕虫','可疑植物'],
  summary:'冬春洞穴蠕虫波的带电变体，月亮洞窟的特定房间全年可以遇到。',
  configs:['depthseels','flooded_caves'],
  sections:[
   ['生成地形与条件','默认开启。冬春的洞穴蠕虫波可以出现洞穴电鳗。地下月亮洞窟的特定房间带有只出电鳗的标签，其他蠕虫在这些房间生成时会被替换。埋伏时可伪装成可疑植物。'],
   ['打法','生命 900，基础咬击伤害 75，攻击间隔 4 秒。玩家近战打它时，若未绝缘就会受到反电，返伤以 15 点为基数，再受电属性和潮湿影响。它还会在充电动作中分 4 次射出电击。穿戴绝缘装备或从远处攻击，看到它充电时给队友留走位空间。'],
   ['掉落','必掉 4 块怪物肉、1 颗电光浆果和 3 片月亮碎片。'],
  ],
  related:[link('viperworm','洞穴恶蛇'),link('cave-worldgen','熔岩洞穴与潮湿陷坑')],
  sources:[cfg(830),houndWave(96),beta('postinit/prefabs/worms.lua',6),beta('scripts/map/tasks/caves/mushroom_tasks.lua',50),shock(126),shock(141),shock(207),shock(248),shock(387),shock(433),beta('postinit/stategraphs/SGworm.lua',74),names(42),names(45)],
 },
 {
  id:'viperworm',category:'creatures',icon:'viperworm',title:'洞穴恶蛇',aliases:['Depths Viper','Viperworm','恶蛇','不祥植物','洞穴蛇'],
  summary:'夏秋洞穴蠕虫波的变体，也会在熔岩洞穴出现，攻击时吐出小蛇。',
  configs:['depthsvipers','magma_caves'],
  sections:[
   ['生成地形与条件','默认开启。夏秋的洞穴蠕虫波可以出现恶蛇。熔岩洞穴部分房间带有只出恶蛇的标签，其他蠕虫在这些房间生成时会被替换。埋伏时可伪装成不祥植物。'],
   ['打法','本体生命 900，基础咬击伤害 75，攻击间隔 4 秒。咬击动作起手会向目标方向吐出投射物，落地生成敌对小蛇。小蛇生命 100、基础伤害 37.5，攻击动作结束两次后消散。躲过本体咬击后也要留意投射物落点。'],
   ['掉落','本体必掉 4 块怪物肉和 1 颗幽暗浆果。'],
  ],
  related:[link('shockworm','洞穴电鳗'),link('cave-worldgen','熔岩洞穴与潮湿陷坑')],
  sources:[cfg(831),houndWave(96),beta('postinit/prefabs/worms.lua',6),beta('scripts/map/tasks/caves/magma_cave.lua',22),viper(108),viper(123),viper(279),viper(459),viper(536),viper(581),beta('scripts/prefabs/viperprojectile.lua',1),beta('scripts/stategraphs/SGviperworm.lua',265),beta('scripts/stategraphs/SGviperworm.lua',303),names(680),names(683),names(686)],
 },
 {
  id:'fruitbat',category:'creatures',icon:'fruitbat',title:'果蝠',aliases:['Fruit Bat','猪笼草','叶翼','爆汁蓝莓'],
  summary:'连帽森林的猪笼草会放出果蝠。它猎食昆虫，被击杀后会爆开。',
  configs:['hoodedforest'],
  sections:[
   ['生成地形与条件','到地表连帽森林找猪笼草，一株猪笼草最多养一只果蝠。果蝠进入实体休眠后，夜间会尝试回到有效的猪笼草。'],
   ['行为与打法','生命 100，基础伤害 20。它会主动追蜘蛛和昆虫，并能抓住仍存活的蚜虫。主动索敌和受击时选取目标的分支都排除了玩家。击杀后约 1.5 秒会爆开，对附近合格目标造成 60 点基础伤害，打倒后先离开爆炸范围。'],
   ['掉落','死亡爆炸时掉 1 颗爆汁蓝莓和 1 个叶翼。WX-78 也可以扫描果蝠来获取加速电路的数据。'],
  ],
  related:[link('wx78','WX-78 生物扫描'),link('blueberrypancakes','爆汁蓝莓薄饼')],
  sources:[cfg(539),beta('scripts/map/rooms/forest/gianttreesrooms.lua',41),beta('scripts/prefabs/pitcherplant.lua',82),fruitbat(4),fruitbat(35),fruitbat(79),fruitbat(104),fruitbat(142),fruitbat(159),fruitbat(212),fruitbat(237),beta('scripts/stategraphs/SGfruitbat.lua',18),beta('scripts/stategraphs/SGfruitbat.lua',420),beta('init/init_character_changes/wx78.lua',41),names(248),names(254),names(255),names(726)],
 },
 {
  id:'giant-batilisk',category:'creatures',title:'巨型蝙蝠',aliases:['Adult Batilisk','Vampire Bat','成年蝙蝠','酸蚀蝙蝠'],
  summary:'洞穴蝙蝠巢的成年种，能呼叫附近的同类，酸蚀后换用一套掉落表。',
  configs:['adultbatilisks','monstersmallmeat'],
  sections:[
   ['生成地形与条件','默认开启。洞穴蝙蝠巢用巨型蝙蝠替代普通蝙蝠，打开的地表洞穴入口也把它设为稀有出场种。'],
   ['打法','生命 130，基础伤害 25，攻击间隔 1.8 秒。受击和攻击命中都可能把目标共享给其他蝙蝠，适合拉离巢口逐只处理。酸蚀个体眼睛会发光，索敌检查更频繁，速度和伤害也有独立加成。'],
   ['掉落','普通个体各自判定 75% 蝙蝠翅膀、25% 怪物肉类、5% 猪皮。酸蚀个体必掉蝙蝠翅膀，另各有 50% 怪物肉类、10% 猪皮和 20% 硝石。肉类由房间的怪物小肉设置决定。'],
  ],
  related:[link('fruitbat','果蝠')],
  sources:[cfg(759),cfg(837),beta('postinit/prefabs/batcave.lua',29),beta('postinit/prefabs/cave_entrance_open.lua',71),vampire(22),vampire(31),vampire(86),vampire(117),vampire(201),vampire(299),vampire(345),names(177)],
 },
 {
  id:'trapdoor-spider',category:'creatures',icon:'spider_trapdoor',title:'地穴蜘蛛',aliases:['Trapdoor Spider','陷阱蜘蛛','不起眼的土丘','茂密草丛'],
  summary:'藏在平原土丘下的伏击者，附近有果蝠时会留在巢内。',
  configs:['trapdoorspiders'],
  sections:[
   ['生成地形与条件','默认在新世界生成。地表的草原和平原房间会布置不起眼的土丘，部分土丘上还有茂密草丛。非冬季时玩家靠近土丘会引它出来，20 距离内有果蝠时不会触发。'],
   ['打法','生命 200，基础伤害 34，攻击间隔为 4–6 秒。它会从土丘跳出并扑击，先后退躲过第一扑再反打。具有蜘蛛亲和或伪装标签的角色也会引出蜘蛛，但土丘不会直接把这名角色作为出巢目标。'],
   ['掉落','普通击杀必掉 1 块怪物肉，再等概率抽出 1 块怪物肉或 1 个蜘蛛腺体。'],
  ],
  related:[link('fruitbat','果蝠')],
  sources:[cfg(553),beta('scripts/map/tasks/forest/the_hunters.lua',4),beta('scripts/prefabs/trapdoorspawner.lua',1),beta('scripts/prefabs/trapdoor.lua',12),spider(1),spider(430),spider(548),beta('scripts/brains/spiderbrain_trapdoor.lua',1),names(147),names(148),names(215)],
 },
 {
  id:'geothermite',category:'creatures',icon:'cave_vent_mite',title:'地热螨',aliases:['Geothermite','Cave Vent Mite','浮石晶洞','喷气孔地热螨','洞穴螨'],
  summary:'洞穴喷气孔附近的敌对生物。测试版新增带晶洞的外观，击杀后可收浮石晶洞。',
  configs:[],
  sections:[
   ['生成地形与条件','在地下喷气孔一带寻找。地热螨创建时有 50% 概率变成带晶洞的外观，带晶洞状态会写入存档。'],
   ['打法','战斗参数沿用原版，生命 400，基础伤害 25，攻击间隔 4 秒。缩进喷气硬壳时只承受通常的 5% 伤害，等它离开壳再打。洞穴暗影裂隙活跃时，它还会增加 10 点位面伤害。'],
   ['掉落','基础战利品等概率为 1 块怪物肉或 1 个火腺。缩壳时必掉 1 块石头，平时石头掉率 50%。受到暗影裂隙影响时另有 50% 概率掉纯粹恐惧。测试版的带晶洞个体必掉 1 个浮石晶洞，放在地上用镐敲开有机会得到狂怒萤石、奥术紫水晶或珍藏黄水晶。',null,[{href:'gemology.html#geode-source-vent',label:'查浮石晶洞的地形与掉落'}]],
  ],
  related:[link('gemology','宝石学与装备附魔')],
  sources:[beta('postinit/prefabs/cave_vent_mite.lua',5),beta('postinit/prefabs/cave_vent_mite.lua',20),beta('postinit/prefabs/cave_vent_mite.lua',33),beta('scripts/um_gemology_geode_defs.lua',152),names(829)],
 },
];
