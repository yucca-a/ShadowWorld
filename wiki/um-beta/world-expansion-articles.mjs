const beta=(file,line)=>({file,line});
const cfg=line=>beta('modinfo.lua',line);
const cn=line=>({kind:'cn',file:'init/init_strings/init_names.lua',line});
const task=(file,line)=>beta(`scripts/map/tasks/forest/${file}.lua`,line);
const room=(file,line)=>beta(`scripts/map/rooms/forest/${file}.lua`,line);
const prefab=(file,line)=>beta(`scripts/prefabs/${file}.lua`,line);
const related=(id,label)=>({id,label});
const link=(href,label)=>({href,label});
const worldgen=beta('modworldgenmain.lua',7);

export const worldExpansionArticles=[
 {
  id:'hooded-forest',category:'world',icon:'hooded_fern',title:'连帽森林',aliases:['Hooded Forest','巨型红杉','巨树森林','月台森林','高齿蕨'],
  summary:'默认替代原来的地表月台森林。用巨型红杉、活动石板和蛛网认路，可在此找到黑寡妇和虫茧。',
  configs:['worldgenmastertoggle','hoodedforest'],
  sections:[
   ['地形位置','新地表同时开启世界生成总开关与连帽森林时，改造原来的 Forest hunters 区域。该区域保留月台和海象房间，另有连帽入口、蜘蛛林和红杉林等房间。岛屿冒险的海难任务表另加专用连帽森林，房间组合与地表不同。'],
   ['黑寡妇与活动石板','蛛网巢和虫茧指向黑寡妇战区。蜘蛛林和海象区域的一些活动石板下藏有连帽伏击蜘蛛。想找宝石可先查看黑寡妇的触发方式与能掉宝石的茧型。',null,[link('hooded-widow.html#hooded-widow-s1','黑寡妇的开战方式'),link('hooded-widower.html','连帽伏击蜘蛛'),link('gemology.html#gemology-s10','虫茧附魔宝石')]],
   ['巨型红杉的资源','完好的巨型红杉需要 25 点砍伐工作量。砍伐会从树冠抖落树枝、木头，也可能有青蛙或蜘蛛。砍到终点会再抖落一批资源，可能含鸟蛋、羽毛或鸟巢。树干留下并开始 3 天再生计时。'],
  ],
  sources:[worldgen,cfg(539),task('giant_trees',4),task('giant_trees',11),task('giant_trees',55),task('giant_trees',84),room('gianttreesrooms',146),room('gianttreesrooms',173),room('gianttreesrooms',258),prefab('widowwebspawner',10),prefab('giant_tree',98),prefab('giant_tree',361),prefab('giant_tree',430),prefab('giant_tree',441),prefab('giant_tree',452),cn(232),cn(251),cn(303)],
 },
 {
  id:'boiling-springs',category:'world',icon:'um_hotspring',title:'沸腾温泉与龙蝇荒地',aliases:['Boiling Springs','Broiling Hills','沸腾地带','温泉','浴球','泡澡','温暖洞穴'],
  summary:'改造原版龙蝇荒地，沿温泉找蜗龙裂缝、龙蝇竞技场和熔岩洞穴入口。浴球还能恢复生命上限。',
  configs:['worldgenmastertoggle','bath_heal','magma_caves'],
  sections:[
   ['地形位置','世界生成总开关开启时，新地表的 Badlands 会换成温泉、岩地、猎犬区和龙蝇竞技场。岩地的裂缝会出蜗龙，温泉可散见于不同房间。地表任务表另要求生成温暖洞穴入口。岛屿冒险的海难也有温泉分区，使用另一套房间。',null,[link('snaildrakes.html','蜗龙与裂缝'),link('dragonfly.html','龙蝇竞技场'),link('cave-worldgen.html','熔岩洞穴与潮湿陷坑')]],
   ['浴球与生命上限','默认开启的浴球调整把配方改为 3 个月树花和 3 个硝石，科技为 CELESTIAL_THREE。投进沸腾温泉后，浴球效果持续 60 秒。待在池内每秒去除 0.9 个百分点的生命上限惩罚，并增加最多 4 点潮湿，防水可抵消这部分潮湿。池内每秒还会使体温上升 0.3℃。'],
   ['新月的黑水','新月状态变化时，未投浴球的温泉会变暗，并关闭投浴球功能。进入黑水会施加强制疯狂状态，离池时解除温泉施加的状态。之后白天状态变化时，未投浴球的暗色温泉会恢复原色。'],
  ],
  sources:[worldgen,cfg(556),cfg(614),task('broiling_hills',12),task('broiling_hills',23),task('broiling_hills',52),task('broiling_hills',103),room('UM_BoilingFields',52),room('UM_BoilingFields',144),prefab('um_hotspring',95),prefab('um_hotspring',106),prefab('um_hotspring',145),prefab('um_hotspring',152),prefab('um_hotspring',197),prefab('um_hotspring',343),beta('init/init_recipes/recipe_changes.lua',154),cn(168),cn(176)],
 },
 {
  id:'oasis-desert',category:'world',icon:'antlion',title:'绿洲沙漠地形',aliases:['Oasis Desert','Lightning Bluff','蚁狮沙漠','荒地合并','猎犬丘'],
  summary:'部分原龙蝇荒地房间并入绿洲，绿洲周边可以找到草地、猎犬丘、仙人掌和风滚草。',
  configs:['worldgenmastertoggle'],
  sections:[
   ['绿洲周边有什么','启用世界生成总开关的新地表，绿洲所在的 Lightning Bluff 区域加入开阔草地与猎犬丘房间。开阔草地有草和兔洞，猎犬丘区有矿石、猎犬骨和猎犬丘。新背景房间还可分布仙人掌、风滚草生成点和草蜥蜴。'],
   ['沙尘与地标','新房间带沙尘暴标签，原绿洲的雷区和蚁狮房也仍有这个标签。复活石、虫洞和普通洞穴入口都能被分配到改造后的绿洲，具体落点看地图生成。夏季可以在绿洲沙漠找蚁狮交易或开战。'],
  ],
  related:[related('antlion','蚁狮的交易与打法'),related('boiling-springs','龙蝇荒地的温泉地形')],
  sources:[worldgen,task('merged_desert',4),task('merged_desert',16),task('merged_desert',29),room('UM_LightningBluff',41),room('UM_LightningBluff',63),room('UM_LightningBluff',78)],
 },
 {
  id:'marsh-rice',category:'world',icon:'riceplant',title:'沼泽水稻与稻米',aliases:['Rice','Lice','水稻','烤稻米','水稻池','沼泽灌木'],
  summary:'到沼泽小水面找水稻。生稻米没有腐烂计时，下锅的稻米值比烤稻米高。',
  configs:['worldgenmastertoggle','rice'],
  sections:[
   ['在沼泽找稻田','开启世界生成总开关和水稻设置后，新地表的沼泽任务会加入普通、密集两种稻田房间。找被陆地包围的小片水面，稻田生成器会在水面附近寻找种植点。沼泽的灌木和雾另由地形脚本加入。'],
   ['采收与再生','靠近水稻可采收稻米，碰撞事件也可触发掉落并转为采过的状态。采后沿用芦苇的 3 天再生间隔，冬天停长。水稻再生时，若 1.5 单位内有船，会移除该株。'],
   ['生米、烤米与下锅','生稻米基础饱食为 12.5，食物类型为难吃蔬菜，能直接吃的角色取决于饮食规则。烤稻米属普通蔬菜，基础饱食 12.5、生命 −1，并有腐烂计时。下锅时两者均提供 1 蔬菜值，生米提供 1 稻米值，烤米只提供 0.5。',null,[link('um-rice-pudding.html','米布丁食谱'),link('seafoodpaella.html','海鲜饭食谱'),link('wurt.html','沃特的食物调整')]],
  ],
  sources:[worldgen,cfg(552),task('squeltch',7),task('squeltch',36),task('squeltch',70),task('squeltch',85),prefab('riceplantspawner',116),prefab('riceplant',24),prefab('riceplant',47),prefab('riceplant',100),prefab('riceplant',122),prefab('rice',55),prefab('rice',120),prefab('rice',125),beta('init/init_food/init_crockpot.lua',553),beta('init/init_food/init_crockpot.lua',555),cn(186),cn(188),cn(190)],
 },
 {
  id:'lunar-island',category:'world',icon:'um_beehive_moon',title:'月岛与腐臭蜂巢',aliases:['Lunar Island','Moon Island','Carrion Bees','腐臭蜂','腐臭蜂巢','月岛洞穴入口'],
  summary:'海滩、矿区和森林都可能遇到腐臭蜂巢。腐臭蜂会在死亡时爆出月光孢子，蜂帽可免这次爆炸伤害。',
  configs:['worldgenmastertoggle','moon_bees','flooded_caves'],
  sections:[
   ['岛上怎么找','启用世界生成总开关和腐臭蜂后，新月岛海滩加入腐臭蜂巢，矿区和森林也各新增一类有蜂巢的房间。潮湿洞穴设置为默认 lunar_cave 时，月岛海滩任务还会增加通往地下潮湿区域的入口。',null,[link('cave-worldgen.html','潮湿陷坑配置和入口')]],
   ['清理蜂巢','腐臭蜂巢有 900 生命，受击时会放出蜂群。野外腐臭蜂有 250 生命、34 点基础攻击。清醒时死亡通常会爆出孢子，对符合条件的玩家造成 25 点伤害，装备蜂帽可免这次爆炸伤害。电击命中后会令仍存活的腐臭蜂立即死亡，近身时也要留意孢子。击破蜂巢固定掉 3 份腐臭蜂蜜和 1 个同名的腐臭蜂巢材料。'],
   ['月亮风暴与配置','当前风暴节点脚本检查 LUNAR_BEES，菜单的腐臭蜂开关实际生成 MOON_BEES。月岛世界生成读取的是正确的菜单键，可以作为稳定的寻找路线。'],
  ],
  sources:[worldgen,cfg(558),cfg(871),task('moonisland',1),task('moonisland',19),room('UM_moonisland',1),room('UM_moonisland',31),prefab('um_beehive_moon',125),prefab('um_beehive_moon',208),prefab('um_beehive_moon',233),prefab('um_bee_moon',116),prefab('um_bee_moon',133),prefab('um_bee_moon',153),prefab('um_bee_moon',257),prefab('um_bee_moon',264),beta('postinit/components/moonstorms.lua',40),beta('init/init_configs.lua',21),cn(729),cn(731),cn(732),cn(739)],
 },
 {
  id:'rimeweed',category:'world',icon:'rimeweed_main',title:'尖刺霜草与局部暴雪',aliases:['Spiny Rimeweed','Rimeweed','霜草荆棘','霜花','霜冻藤蔓','霜鞭','局部暴雪'],
  summary:'全域暴雪期间可能长在可采植物旁，成熟后自带局部暴雪。尽早清理可减少荆棘蔓延，等成熟则有更多材料。',
  configs:['snowstorms','weatherhazard_winter'],
  sections:[
   ['去哪里找','启用暴风雪后，冬季全域暴雪会尝试在可采植物旁生成尖刺霜草。生成检查要求世界周期严格超过冬季天气门槛，默认是 5。候选有时限定为茂密草丛、芦苇或仙人掌。已成熟的植株有自己维持的局部暴雪，全域天气结束后仍可能继续。',null,[link('snowstorms.html','全域暴风雪与防护')]],
   ['何时清理','主株有 600 生命，荆棘有 200 生命。生成半天后进入第二阶段，再过一天进入第三阶段。扩散可在周边可采植物附近连成荆棘，成熟主株受攻击还会反击并施加寒冷。打掉主株可一起清掉相连的荆棘。离开冬季后霜草会清理。'],
   ['掉落与用途','第一阶段固定掉 1 根霜冻藤蔓。第二阶段掉 2 根，并有 25% 概率掉霜鞭。第三阶段也掉 2 根，另以各一半概率掉霜花或霜鞭。藤蔓可做霜冻外壳或下锅，霜花可用于冰镇龙舌兰。',null,[link('rimeweed-bramble-armor.html','霜冻外壳'),link('rimeweed-icepack.html','冰袋'),link('rime-helmet.html','霜兽头盔'),link('um-rimeweed-spagett.html','霜冻意面'),link('um-rimeweed-tequila.html','冰镇龙舌兰')]],
  ],
  sources:[cfg(451),cfg(463),beta('init/init_weather/init_harder_weather.lua',130),beta('scripts/components/um_snow_stormspawner.lua',21),beta('scripts/components/um_snow_stormspawner.lua',30),beta('scripts/components/um_snow_stormspawner.lua',121),beta('scripts/components/snowstormwatcher.lua',49),prefab('um_rimeweed',43),prefab('um_rimeweed',273),prefab('um_rimeweed',383),prefab('um_rimeweed',450),prefab('um_rimeweed',463),prefab('um_rimeweed',496),prefab('um_rimeweed',519),prefab('um_rimeweed',603),prefab('um_rimeweed',634),prefab('um_rimeweed',726),beta('init/init_recipes/recipes.lua',127),beta('scripts/um_preparedfoods.lua',660),beta('scripts/um_preparedfoods.lua',696),cn(692),cn(695),cn(696),cn(697)],
 },
];
