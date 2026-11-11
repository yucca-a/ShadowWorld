const beta=(file,line)=>({file,line});
const prefab=(name,line)=>beta(`scripts/prefabs/${name}.lua`,line);
const state=(name,line)=>beta(`scripts/stategraphs/${name}.lua`,line);
const names=line=>({kind:'cn',file:'init/init_strings/init_names.lua',line});
const config=line=>beta('modinfo.lua',line);
const link=(href,label)=>({href,label});
const gemTrade=link('gemology.html#gemology-s5','查宝石交易与升级概率');
const gemCocoons=link('gemology.html#gemology-s10','查虫茧里的附魔宝石');

export const gemCreatureArticles=[
 {
  id:'hooded-widow',category:'creatures',icon:'hoodedwidow',title:'黑寡妇',aliases:['Hooded Widow','连帽森林首领','黑寡妇巢','大黑寡妇'],
  searchJumps:[{terms:['黑寡妇','Hooded Widow']},{section:'生成地形与开战',terms:['黑寡妇在哪','黑寡妇怎么找','黑寡妇怎么召唤','黑寡妇刷新']},{section:'打法与转阶段',terms:['黑寡妇打法','黑寡妇怎么打','黑寡妇攻略']},{section:'战利品与虫茧',terms:['黑寡妇掉落','黑寡妇战利品','黑寡妇宝石']}],
  summary:'连帽森林的首领，默认 12,000 生命。打巢旁的茧引它下树，击败后可用寡妇之爪打开有宝石的茧。',
  configs:['hoodedforest','hoodedwidow_health_','vetcurse'],
  sections:[
   ['生成地形与开战','在地表连帽森林找黑寡妇巢和散落的茧。默认的连帽森林配置会改造原本有月台和一处海象营地的森林区。用普通武器攻击巢附近的茧，就能引黑寡妇从树冠落下。茧附近 50 距离内有其他符合条件的大型首领时，这个触发会被拦下。击杀后默认等 20 个游戏日才能再引出一只。',null,[link('hooded-forest.html','连帽森林的地标')]],
   ['基础数值与战场','默认 12,000 生命，基础普通攻击 150，对玩家按 0.5 倍结算，基础攻击间隔 3 秒。普通挥击覆盖前方扇面，看到抬手可往侧后方绕，挥完再回头输出。战斗尽量留在巢周围，目标离巢约 24 距离时，它可能转向附近的茧进食，每口恢复 200 生命并持续到满血。'],
   ['打法与转阶段','扑击和抛网各有冷却，同时就绪时优先扑击。看到落点提示就侧移，抛网会散射 5 团蛛网，留出通道绕开蛛网区。生命降至 75%、50%、25% 时，它会尝试跳上附近巨树摇出蜘蛛。先处理落地的杂兵再继续输出，黑寡妇击中可吞食的小怪时能回 250 生命。低于 40% 后，原本的扑击分支改为连续冲锋，横移让开冲锋方向，等结束再靠近。',null,[link('hooded-widower.html','连帽伏击蜘蛛')]],
   ['战利品与虫茧','基础掉落为怪物肉 ×4、蜘蛛丝 ×4、寡妇之爪 ×1、寡妇之颅 ×1。老兵诅咒房间设置为默认或始终开启时，另掉蛛丝背包，击杀者无需带有诅咒。选 ×1.5 或 ×2 生命档时，每份掉落分别有 25% 或 50% 概率多给一份。×3 时全部翻倍，×4 时全部翻倍且每份原始掉落再有 50% 概率给第三份。用寡妇之爪破茧后，蛞蝓龟／蜗牛龟、雪怪、蜗龙、石虾型茧可掉对应颜色的二级或三级附魔宝石。',null,[link('widows-grasp.html','寡妇之爪与开茧'),link('widows-head.html','寡妇之颅'),link('silk-sack.html','蛛丝背包的产丝与打包'),gemCocoons]],
  ],
  sources:[config(539),config(1181),beta('scripts/map/tasks/forest/giant_trees.lua',1),prefab('widowwebspawner',10),prefab('widowweb',42),prefab('widowweb',75),prefab('webbedcreature',184),beta('init/init_tuning.lua',339),prefab('hoodedwidow',3),prefab('hoodedwidow',128),prefab('hoodedwidow',194),prefab('hoodedwidow',302),prefab('hoodedwidow',364),beta('scripts/brains/hoodedwidowbrain.lua',45),beta('scripts/brains/hoodedwidowbrain.lua',105),beta('scripts/brains/hoodedwidowbrain.lua',154),state('SGhoodedwidow',390),state('SGhoodedwidow',517),state('SGhoodedwidow',629),state('SGhoodedwidow',1297),beta('init/init_bosshealth.lua',120),beta('init/init_bosshealth.lua',648),beta('postinit/prefabs/vetcurse_drops.lua',9),beta('postinit/prefabs/vetcurse_drops.lua',31),beta('scripts/webbedcreatureloot.lua',404),names(236),names(237),names(304)],
 },
 {
  id:'hooded-widower',category:'creatures',icon:'spider_trapdoor_hooded',title:'连帽伏击蜘蛛',aliases:['小黑寡妇','Hooded Widower','连帽活板门蜘蛛','活动石板','spider_trapdoor_hooded'],
  summary:'连帽森林活动石板下的伏击蜘蛛，会喷网。社区汉化里它与首领都显示为「黑寡妇」。',
  configs:['hoodedforest'],
  sections:[
   ['生成地形','连帽森林部分房间会放置活动石板，靠近时会惊出下方的蜘蛛。遇到活动石板密集的区域可以逐个引出。'],
   ['打法','生命 200，基础伤害 34。有吐网机会时会优先喷网，等蛛网落下再从侧面靠近，避免连续踩进蛛网。也可以用普通陷阱捕捉。'],
   ['掉落','基础固定掉 1 个蜘蛛丝，另在怪物肉和蜘蛛腺体中等权抽 1 个。',null,[link('hooded-widow.html','首领黑寡妇'),link('trapdoor-spider.html','普通活板门蜘蛛')]],
  ],
  sources:[config(539),beta('scripts/map/rooms/forest/gianttreesrooms.lua',146),prefab('trapdoor',5),prefab('spider_trapdoor',6),prefab('spider_trapdoor',428),prefab('spider_trapdoor',576),beta('postinit/stategraphs/SGspider.lua',76),names(149),names(252)],
 },
 {
  id:'snowmong',category:'creatures',icon:'snowmong',title:'雪怪',aliases:['Snowmong','雪堆怪','冰冻鼹鼠尾','雪怪交易'],
  summary:'冬季雪堆里的伏击者，吃掉地上的冰和蓝宝石会成长。已吞下的蓝色附魔宝石在死亡后逐颗结算。',
  configs:['snowstorms'],
  sections:[
   ['生成地形与触发','冬季暴雪会在玩家或建筑附近的可通行地面形成雪堆。挖掘或采集仍有较多层数的雪堆时有机会惊出雪怪，还可能连带附近雪堆中的同伴。',null,[link('snowstorms.html','暴风雪与雪堆')]],
   ['打法与成长','基础生命 250、伤害 30、攻击间隔 3 秒，钻入地下时无法被攻击，等它冒头再打。雪怪免疫火焰伤害。它会吃地上的雪球、冰和蓝宝石回血并变强。吃下每颗蓝色附魔宝石会提高 10 级，等级最高 30，满级生命 1,700、攻击范围 4。单纯击杀时，先收起地上的这些物品。'],
   ['死亡掉落与蓝宝石','未融化时的基础掉落是木炭 ×2、冰 ×3、雪球 ×2。冬季另有 25% 概率给冰冻鼹鼠尾，否则给小肉。离开冬季后会周期性失血并改用较少的融化掉落。投喂蓝色附魔宝石时，最多记 10 颗，每颗独立结算，一级或二级单颗升级率均为 25%。',null,[gemTrade]],
  ],
  sources:[config(463),beta('scripts/components/snowstormwatcher.lua',97),beta('scripts/components/snowstormwatcher.lua',133),prefab('snowpile',5),prefab('snowpile',195),prefab('snowpile',316),prefab('snowmong',12),prefab('snowmong',34),prefab('snowmong',77),prefab('snowmong',103),prefab('snowmong',123),prefab('snowmong',232),state('SGsnowmong',315),beta('init/init_gemology/trades.lua',493),names(49),names(705)],
 },
 {
  id:'snaildrakes',category:'creatures',icon:'snaildrake_magma',title:'蜗龙',aliases:['Snaildrake','刺蜗龙','管蜗龙','岩浆蜗龙','黏液蜗龙','爆燃黏液'],
  summary:'沸腾地带裂缝里成对出现的两种蜗龙，会互相支援。红色附魔宝石可与它们交易。',
  configs:[],
  sections:[
   ['生成地形','在地表沸腾地带找裂缝，每个裂缝能同时有一只刺壳、一只管壳蜗龙。两只活着时会结伴，死亡后各自约两个游戏日重生。'],
   ['打法','两种均为 450 生命，普通伤害 25，基础攻击间隔 4 秒。靠近会引发仇恨，攻击其中一只也可能引来另一只。它们会朝目标位置吐出投射物，避开落点并绕开残留物，趁其中一只缩壳时调整站位。两种都免疫火焰伤害。'],
   ['掉落与红色宝石','两种都固定掉 2 个爆燃黏液。刺壳有 50% 概率掉蜗龙角盔，管壳有 50% 概率掉蜗龙盆，没出装备时改掉壳碎片。交红色附魔宝石可换同级、升级宝石或补偿，交易后会对玩家中立。蓝色附魔宝石会激怒它。',null,[gemTrade,gemCocoons,link('snaildrake-helmet.html','蜗龙头盔的用法')]],
  ],
  sources:[beta('scripts/map/rooms/forest/UM_BoilingFields.lua',47),prefab('snaildrake_hole',16),prefab('snaildrake_hole',64),prefab('snaildrake',19),prefab('snaildrake',31),prefab('snaildrake',71),prefab('snaildrake',89),prefab('snaildrake',149),prefab('snaildrake',252),prefab('snaildrake',321),beta('init/init_gemology/trades.lua',87),beta('init/init_gemology/trades.lua',183),names(666)],
 },
 {
  id:'slurtles',category:'creatures',icon:'slurtle',title:'蛞蝓龟与蜗牛龟',aliases:['Slurtle','Snurtle','蛞蝓龟','蜗牛龟','蛞蝓龟黏液','绿色宝石交易'],
  summary:'洞穴龟巢里的两种生物，测试版可用绿色附魔宝石交易，交易后会跳过偷食行为。',
  configs:[],
  sections:[
   ['生成地形与打法','在洞穴里找蛞蝓龟巢。蛞蝓龟会主动攻击，蜗牛龟较常缩壳。打到它们缩壳时可停手等出壳再继续，尤其留意地上的黏液。'],
   ['普通掉落','保留本体的掉落池，两种都掉 2 个蛞蝓龟黏液。蛞蝓龟有 10% 概率掉背壳头盔，蜗牛龟有 75% 概率掉蜗壳护甲，未出对应装备时改掉壳碎片。'],
   ['绿色宝石交易','绿色附魔宝石一级升二级和二级升三级各有 25% 概率。失败可能退回同级、给普通绿宝石或黏液。交易过的龟会跳过偷取元素食物的行为。交红色附魔宝石会令它着火并转为敌对。',null,[gemTrade,gemCocoons]],
  ],
  sources:[beta('init/init_gemology/trades.lua',87),beta('init/init_gemology/trades.lua',135),beta('init/init_gemology/trades.lua',183),beta('init/init_gemology/trades.lua',247),beta('scripts/webbedcreatureloot.lua',515)],
 },
 {
  id:'rock-lobster',category:'creatures',icon:'rocky',title:'石虾',aliases:['Rock Lobster','Rocky','石龙虾','白色宝石交易','孕育中的岩石'],
  summary:'洞穴岩石平原的矿物食客，可以雇佣。测试版会用白色附魔宝石交易，秋季还能生成孕育中的岩石。',
  configs:['gemology'],
  sections:[
   ['生成地形与打法','常见于洞穴岩石平原和石虾孵化区。用镐挖孕育中的岩石会激怒附近的石虾，准备采矿时可以先引开或雇佣它们。打石虾时等它退出缩壳姿态再输出。'],
   ['掉落与胚胎晶洞','基础掉落沿用本体，含石头 ×2、燧石 ×2 和大肉 ×1。开启宝石学时，秋天石虾附近还可能生成新的孕育中的岩石。挖这种岩石可获得胚胎晶洞。',null,[link('gemology.html#geode-source-lobster','胚胎晶洞的地形与采集')]],
   ['白色宝石交易','交白色附魔宝石时，一级升二级概率 20%，二级升三级概率 25%。失败可退回同级或走雇佣分支，已在攻击投喂者时先解除仇恨。',null,[gemTrade,gemCocoons]],
  ],
  sources:[config(184),beta('scripts/map/tasks/caves/gemology.lua',141),prefab('um_rocklobster_rock',8),beta('postinit/prefabs/rocky.lua',19),beta('postinit/prefabs/rocky.lua',49),beta('init/init_gemology/trades.lua',393),beta('init/init_gemology/trades.lua',411)],
 },
 {
  id:'widows-grasp',category:'new-items',prefab:'widowsgrasp',title:'寡妇之爪',aliases:['Widow’s Grasp','Widows Grasp','虫茧','开茧','破茧'],
  summary:'黑寡妇掉落的武器，可切开连帽森林的虫茧。大茧消耗更多耐久。',
  configs:['hoodedforest'],
  sections:[
   ['怎么获得','击败连帽森林的黑寡妇，默认掉落 1 把。装备后可用一次命中破开一个虫茧。',null,[link('hooded-widow.html#hooded-widow-s1','黑寡妇的地形和开战方式')]],
   ['武器与开茧耐久','基础伤害 59.5，满耐久 200。普通命中消耗 1 点，小、中、大茧分别消耗 20、40、60 点，再乘角色或武器的耐久修正。',null,[gemCocoons]],
  ],
  sources:[prefab('hoodedwidow',3),prefab('widowsgrasp',22),prefab('widowsgrasp',74),prefab('webbedcreature',205),beta('init/init_tuning.lua',49),names(235)],
 },
 {
  id:'widows-head',category:'new-items',prefab:'widowshead',title:'寡妇之颅',aliases:['Widow’s Head','Widows Head','黑寡妇帽','黑寡妇头'],
  summary:'黑寡妇掉落的可食用头饰，有夜视和护目标签，也会随时间腐烂。',
  configs:['hoodedforest'],
  sections:[
   ['怎么获得','击败连帽森林的黑寡妇，默认掉落 1 个。',null,[link('hooded-widow.html#hooded-widow-s4','黑寡妇完整战利品')]],
   ['佩戴与食用','占头部槽，提供夜视和护目效果，防水 20%。基础保鲜 15 天，腐坏变为腐烂食物。食用基础回复 60 生命和 75 饱食，扣 10 理智。'],
  ],
  sources:[prefab('hoodedwidow',3),prefab('widowshead',61),prefab('widowshead',80),beta('postinit/prefabs/molehat.lua',89),names(261)],
 },
];
