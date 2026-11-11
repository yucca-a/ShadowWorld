const beta=(file,line)=>({file,line});
const cfg=line=>beta('modinfo.lua',line);
const names=line=>({kind:'cn',file:'init/init_strings/init_names.lua',line});
const drops=line=>beta('postinit/prefabs/vetcurse_drops.lua',line);
const hp=line=>beta('init/init_bosshealth.lua',line);
const related=(id,label)=>({id,label});

export const surfaceBossArticles=[
 {
  id:'deerclops',category:'creatures',title:'独眼巨鹿',aliases:['巨鹿','冬季 Boss','Deerclops','蓝光巨鹿','冰圈巨鹿','重击巨鹿'],icon:'deerclops',
  summary:'冬季追踪玩家的巨人，测试版随机采用蓝光激光、重击或冰圈三种强化。',
  configs:['harder_deerclops','deerclops_health_','disable_megaflare','vetcurse'],
  sections:[
   ['生成条件','冬季地表按袭击计时器出现，生成点在目标玩家附近可行走的地方。听到警告后，可先离开建筑密集区再接敌。默认生命 6000。开启强化时，首次生成会按约三分之一的概率抽取三种变体，重载会保留已选变体。'],
   ['三个变体怎么打','发蓝光的变体会先朝目标蓄力再发射激光，见到预备动作就侧移。重击变体在低于 50% 生命时能把上勾拳换成连击，且重击有击退，看到第一下后应等后续动作结束。冰圈变体会在身前放出延迟 6 秒触发的冰圈，先离开标记地面再回身。开启强化后，三种变体都会移除巨鹿的冻结组件，别依赖冰魔杖控场。'],
   ['掉落','默认档击杀掉落大肉 ×8、独眼巨鹿眼球 ×1 和独眼巨鹿雕塑草图。老兵诅咒房间设置为默认或始终开启时，掉落表另加诅咒鹿角。'],
  ],
  related:[related('veterans-curse','老兵诅咒与额外掉落'),related('cursed-antler','诅咒鹿角'),related('crystal-cursed-antler','晶体诅咒鹿角')],
  sources:[cfg(944),cfg(1111),beta('init/init_tuning.lua',672),hp(62),beta('init/init_postinit.lua',400),beta('scripts/components/deerclopsspawner.lua',170),beta('postinit/prefabs/deerclops.lua',91),beta('postinit/prefabs/deerclops.lua',141),beta('postinit/prefabs/deerclops.lua',203),beta('postinit/stategraphs/SGdeerclops.lua',231),beta('postinit/stategraphs/SGdeerclops.lua',316),beta('postinit/stategraphs/SGdeerclops.lua',351),beta('postinit/stategraphs/SGdeerclops.lua',412),drops(17),names(222)],
 },
 {
  id:'bearger',category:'creatures',title:'熊獾',aliases:['熊大','Bearger','秋季 Boss','诅咒熊爪'],icon:'bearger',
  summary:'秋季出没，强化版投出五块扇形巨石，砸地还会在朝向目标的一线上留下塌陷。',
  configs:['harder_bearger','bearger_health_','disable_megaflare','vetcurse'],
  sections:[
   ['生成条件','地表秋季由熊獾生成器计时，通常从第二年秋季起遇到。秋季已有计时且还剩超过一个游戏日时，敌对信号弹可以让它更早出现。默认生命 6000。'],
   ['扇形投石与定向塌陷','默认开启的熊獾强化给它增加投石。它面向目标撒出 5 块巨石，方向以正前方为中心每隔 15° 分布。看见投掷动作后横向离开，不要顺着扇面往后跑。砸地还会朝动作记录的目标位置生成 5 处塌陷，在地面或船上战斗都要离开这条线。'],
   ['掉落','默认档击杀掉落大肉 ×8、熊皮 ×1 和熊獾雕塑草图。平时脱落毛丛，调高生命设置会给每次脱落额外抽取机会。老兵诅咒房间设置为默认或始终开启时，另掉诅咒熊爪。'],
  ],
  related:[related('veterans-curse','老兵诅咒与额外掉落')],
  sources:[cfg(945),cfg(1041),hp(62),hp(381),beta('init/init_postinit.lua',410),beta('postinit/components/beargerspawner.lua',42),beta('postinit/prefabs/bearger.lua',75),beta('postinit/prefabs/bearger.lua',99),beta('postinit/stategraphs/SGbearger.lua',18),beta('postinit/stategraphs/SGbearger.lua',93),drops(16),names(327)],
 },
 {
  id:'moose-goose',category:'creatures',title:'麋鹿鹅',aliases:['鹿鹅','鹅鹿','春鹅','Moose','Goose','Moose/Goose','麋鹿鹅幼崽'],icon:'moose',
  summary:'春季巢区的巨人。强化后会追人跳砸，低血量缴械时还能引来雷雨。',
  configs:['harder_moose','moose_health_','vetcurse'],
  sections:[
   ['生成条件','春季去地表麋鹿鹅巢区找成体和鹅蛋。默认生命 6000。强化后若仍有有效战斗目标，实体休眠时不会执行原有的离场逻辑。'],
   ['跳砸、缴械与雷雨','强化后普通攻击带范围伤害。它追击时会越过玩家原位置向前落地，见起跳就横向拉开，等落地范围攻击结束再靠近。生命降到 33% 或更低后，缴械动作还能触发降雨和连续落雷，备好替换武器并远离站位集中的队友。'],
   ['掉落','默认档击杀掉落大肉 ×6、鸟腿 ×2、麋鹿鹅羽毛至少 3 根和麋鹿鹅雕塑草图。另有两次独立 33% 的额外羽毛判定。老兵诅咒房间设置为默认或始终开启时，另掉羽毛长袍。'],
  ],
  related:[related('veterans-curse','老兵诅咒与额外掉落')],
  sources:[cfg(947),cfg(1251),hp(62),beta('init/init_postinit.lua',405),beta('postinit/prefabs/moose.lua',52),beta('postinit/prefabs/moose.lua',75),beta('postinit/prefabs/moose.lua',120),beta('postinit/stategraphs/SGmoose.lua',17),beta('postinit/stategraphs/SGmoose.lua',76),beta('postinit/stategraphs/SGmoose.lua',175),drops(30),names(342)],
 },
 {
  id:'dragonfly',category:'creatures',title:'龙蝇',aliases:['龙蝇巢','普通龙蝇','岩浆虫','龙鳞火炉','Dragonfly','Lavae','熔岩口器'],icon:'dragonfly',
  summary:'沸腾温泉区域的常驻龙蝇。岩浆虫死后会留下引燃的黏液，原来的围墙可能被炸开。',
  configs:['harder_lavae','dragonfly_health_','worldgenmastertoggle','vetcurse'],
  sections:[
   ['生成地形','启用世界生成改动的新世界里，龙蝇竞技场位于替代原龙蝇沙漠的沸腾温泉区域。玩家靠近时，生成点每 10 秒检查一次，夏季或附近存在其他首领会停刷。季节检查暂停的是生成器，场上已有的龙蝇仍可能在场。默认生命 27500。'],
   ['岩浆虫与眩晕','默认启用的岩浆虫强化让它们死亡后留下自动引燃的黏液，约 3–6 秒后爆开，范围 4 内的可工作物体会受到 10 点工作量。把岩浆虫引到远离围墙的地方处理。默认档首次眩晕要求在 5 秒内累计造成超过 1250 点伤害，脱落鳞片的初始伤害门槛为 2500，两项均随生命倍率变化。'],
   ['掉落','默认档击杀掉落鳞片、龙鳞火炉蓝图、龙蝇雕塑草图、大肉、金块与多色普通宝石，岩浆虫卵有 33% 概率掉落。战斗中达到脱鳞门槛还可拿鳞片。老兵诅咒房间设置为默认或始终开启时，另掉熔岩口器。'],
  ],
  related:[related('summer-dragonflies','时令龙蝇与月光龙蝇'),related('veterans-curse','老兵诅咒与额外掉落')],
  sources:[cfg(957),cfg(1125),hp(62),hp(481),beta('scripts/map/tasks/forest/broiling_hills.lua',12),beta('scripts/map/tasks/forest/broiling_hills.lua',51),beta('postinit/prefabs/dragonfly_spawner.lua',5),beta('postinit/prefabs/dragonfly_spawner.lua',31),beta('init/init_postinit.lua',428),beta('postinit/prefabs/lavae.lua',14),beta('scripts/prefabs/lavaeslime.lua',22),beta('scripts/prefabs/lavaeslime.lua',83),drops(22),names(177),names(326)],
 },
 {
  id:'bee-queen',category:'creatures',title:'蜂王',aliases:['蜂后','Bee Queen','巨大蜂窝','蜂王浆','蜂王冠','手持蜂巢'],icon:'beequeen',
  summary:'锤巨大蜂窝召出的首领。重做版有追击、射击和防御蜂，进入后半场后会频繁变阵。',
  configs:['harder_beequeen','beequeen_health_','vetcurse'],
  sections:[
   ['生成条件','在地表用锤子敲成熟的巨大蜂窝，触发蜂王出现。默认生命 22500，房间默认开启重做。'],
   ['蜂群阵形与踩踏','75% 以上主要召追击蜂，75% 到 50% 间会换上防御蜂，50% 以下加入射击蜂，25% 以下还会搭配额外蜂墙。防御阵会转向，可以绕开正面找空隙。见到射击蜂时保持横向移动。75% 以下受击会积累踩踏条件，从船上攻击累积得尤其快。踩踏蓄力时先退出近身范围。短时高输出也会缩短召卫兵计时，最低压到 3 秒。'],
   ['掉落','默认档有蜂王浆至少 6 份（50% 概率再掉 1 份）、蜂王冠、捆绑包装蓝图与蜂王雕塑草图，也有蜂巢、蜂蜜和蜂刺。老兵诅咒房间设置为默认或始终开启时，另掉手持蜂巢。'],
  ],
  related:[related('veterans-curse','老兵诅咒与额外掉落')],
  sources:[cfg(961),cfg(1055),hp(62),beta('init/init_postinit.lua',526),beta('postinit/prefabs/beequeen.lua',30),beta('postinit/prefabs/beequeen.lua',61),beta('postinit/prefabs/beequeen.lua',408),beta('postinit/prefabs/beequeen.lua',478),beta('postinit/prefabs/beequeen.lua',547),beta('postinit/stategraphs/SGbeequeen.lua',7),drops(15),names(428)],
 },
 {
  id:'klaus',category:'creatures',title:'克劳斯',aliases:['Klaus','赃物袋','坎普斯背包','无锁','麋鹿茸','冬季 Boss'],icon:'klaus',
  summary:'冬季打开赃物袋召出。杀死无眼鹿会让克劳斯狂暴并回满生命，最终击杀狂暴个体可直接拿到坎普斯背包。',
  configs:['klaus_health_','vetcurse'],
  sections:[
   ['召唤与阶段','冬季到桦树林或混合地形搜赃物袋。用无眼鹿掉落的普通鹿角尝试开袋，召出带两头施法鹿的克劳斯。默认一阶段生命 10000，首次倒地后以最大生命的 50% 复起，解开锁链进入后续战斗。'],
   ['普通打法与狂暴挑战','想平稳开袋，优先打克劳斯，保留两头施法鹿，离开冰火施法圈再回到近战距离。少一头施法鹿就会触发狂暴。测试版进入狂暴时会回满生命，默认档狂暴后的最大生命为 27440。最终在解链且狂暴的状态下击杀，必掉坎普斯背包。'],
   ['掉落与开袋','最终击杀时会掉开袋用的麋鹿茸、怪物肉、木炭和克劳斯雕塑草图。回赃物袋用麋鹿茸取战利品包。调高生命倍率可能额外复制整包。狂暴解链击杀的坎普斯背包由本体直接掉落。老兵诅咒房间设置为默认或始终开启时，另掉「无锁」。'],
  ],
  related:[related('veterans-curse','老兵诅咒与额外掉落')],
  sources:[cfg(1195),hp(62),hp(303),beta('init/init_postinit.lua',182),beta('postinit/prefabs/klaus.lua',4),beta('postinit/prefabs/klaus.lua',12),beta('postinit/prefabs/klaus_sack.lua',13),drops(28),names(291)],
 },
 {
  id:'antlion',category:'creatures',title:'蚁狮',aliases:['Antlion','绿洲沙漠','沙之石','地陷','橙色宝石交易','蚁狮颚','蚁狮颚刃'],icon:'antlion',
  summary:'夏季绿洲沙漠首领，能收附魔宝石。红色或蓝色附魔宝石会触发战斗。',
  configs:['antlion_health_','gemology','vetcurse'],
  sections:[
   ['生成地形与开战','夏天到地表绿洲沙漠找蚁狮，默认生命 6000。冷透或热透的暖石都能触发战斗。红色与蓝色附魔宝石也分别触发灼烧与冻结的开战分支。想升级附魔宝石时可用橙色。'],
   ['打法与贡品','开战后看到沙刺预警就换位，在沙墙围出的区域留一条移动路线。测试版在生成和受击时将爆炸抗性设为 90%，优先用武器输出。平时给可接受的贡品能延长发怒计时，附魔宝石的正常交易也会重置或延长这段时间，并停止当前的地陷。'],
   ['掉落与交易','默认档击杀掉落懒人传送塔蓝图、刮地皮头盔蓝图、蚁狮雕塑草图、大肉 ×4、石头与至少 6 个沙之石。老兵诅咒房间设置为默认或始终开启时，另掉蚁狮颚刃（Antlion Mandible）。交易可以给沙之石、玩具或更高品质的附魔宝石。',null,[{href:'gemology.html#gemology-s5',label:'查蚁狮的宝石升级概率'}]],
  ],
  related:[related('gemology','宝石学与装备附魔'),related('veterans-curse','老兵诅咒与额外掉落')],
  sources:[cfg(1013),hp(62),beta('postinit/prefabs/antlion.lua',30),beta('init/init_gemology/trades.lua',261),beta('init/init_gemology/trades.lua',317),beta('init/init_gemology/trades.lua',333),drops(21),beta('init/init_strings/init_names.lua',324)],
 },
 {
  id:'crab-king',category:'creatures',title:'帝王蟹',aliases:['蟹王','Crab King','休眠海螺','诅咒蟹钳','刺耳三叉戟'],icon:'crabking',
  summary:'海上镶满九个插槽后开战，测试版击杀必加休眠海螺。',
  configs:['crabking_health_','vetcurse'],
  sections:[
   ['生成与激活','出海到涌浪海域寻找还没激活的帝王蟹，在九个插槽镶宝石，填满后开战。默认基础生命 12000。珍珠的珍珠会为六种常见宝石各增加 3 点计数，蓝色计数还会加冻结抗性，选石会影响这场战斗。'],
   ['船上打法','带好修船材料，留人处理船边蟹钳。它有冰墙且准备治疗时，转火清理冰墙，见到冻结施法的预备动作就把船开出危险位置。绿色计数高时会强化蟹钳，优先减少让船受损的来源。'],
   ['掉落','默认档击杀后有刺耳三叉戟蓝图、帝王蟹雕塑草图、帝王蟹保险杠套装、藤壶、漂流瓶等。用珍珠的珍珠激活时，击杀还会掉出未激活天体贡品，并返还开裂珍珠。测试版固定追加休眠海螺。老兵诅咒房间设置为默认或始终开启时，另掉诅咒蟹钳。'],
  ],
  related:[related('veterans-curse','老兵诅咒与额外掉落')],
  sources:[cfg(1083),hp(23),hp(62),beta('init/init_tuning.lua',644),drops(19),drops(34),names(297),names(377)],
 },
];
