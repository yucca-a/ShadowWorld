const beta=(file,line)=>({file,line});
const prefab=(name,line)=>beta('scripts/prefabs/'+name+'.lua',line);
const recipe=line=>beta('init/init_recipes/recipes.lua',line);
const names=line=>({kind:'cn',file:'init/init_strings/init_names.lua',line});
const link=(href,label)=>({href,label});

const healingSources=[
  beta('postinit/components/healer.lua',15),
  beta('postinit/components/healer.lua',26),
  beta('init/init_character_changes/wormwood.lua',209),
  beta('init/init_character_changes/wormwood.lua',220),
];

export const toolExpansionArticles=[
 {
  id:'gem-magnifiers',category:'new-items',prefab:'um_magnifier_purplegem',title:'宝石放大镜与远古宝石放大镜',
  variantPrefabs:['um_magnifier'],
  aliases:['宝石放大镜','远古宝石放大镜','宝石鉴定镜','Gem Magnifier','Ancient Gem Magnifier'],
  summary:'揭示附魔宝石的品质和效果，并把鉴定结果写入操作者的宝石图鉴。两种放大镜分别有 100 和 400 点耐久。',
  configs:['gemology'],
  sections:[
   ['制作','启用宝石学后，在暗影操纵器旁用 1 颗紫宝石、2 个骨片、1 根活木头制作宝石放大镜。远古版在完整的远古伪科学站用 1 颗奥术紫水晶、1 个化石碎片、1 块铥矿制作。点出「远古亲缘 I」的沃托姆走同材料的角色配方，成品相同。',null,[
    link('recipes.html#recipe-um_magnifier_purplegem-95','宝石放大镜配方'),
    link('recipes.html#recipe-um_magnifier-92','远古宝石放大镜配方'),
    link('recipes.html#recipe-wathom_um_magnifier-103','沃托姆配方'),
    link('wathom.html','沃托姆技能'),
   ]],
   ['鉴定','拿起放大镜，对附魔宝石使用「检查」。鉴定会揭示这颗石头的品质，同时在操作者的图鉴中登记该种宝石和品质。别的玩家鉴定过的宝石，如果自己的图鉴尚未登记或只登记了更低品质，仍可检查。',null,[link('gemology.html#gemology-s6','查各级附魔效果'),link('gemology.html#gemology-s7','查附魔宝石来源')]],
   ['批量与耐久','普通版有 100 点耐久，远古版有 400 点。每颗扣 1 点，对一叠宝石使用时可以整叠分析。剩余耐久不足时，只拆出并鉴定能负担的数量，工具耗尽后消失。'],
  ],
  sources:[recipe(92),recipe(95),recipe(103),prefab('um_magnifier',45),prefab('um_magnifier',55),prefab('um_magnifier',57),
    beta('init/init_actions.lua',688),beta('scripts/components/gemologyscanner.lua',18),beta('scripts/components/gemologyscanner.lua',44),
    prefab('um_gemologygems',174),beta('postinit/components/inventory.lua',24),names(853),names(854),
    {kind:'cn',file:'init/init_strings/init_descriptions/skilltreestrings.lua',line:63},
    {kind:'cn',file:'init/init_strings_other.lua',line:125}],
 },
 {
  id:'sporepack',category:'new-items',prefab:'sporepack',title:'蟾蜍背包',
  aliases:['孢子背包','蘑菇背包','Spore Pack','Sporepack'],
  summary:'12 格背包，会恢复蘑菇和孢子的新鲜度。其他会腐坏的东西放进去会变质得更快。',
  configs:[],
  sections:[
   ['获取','在炼金引擎旁用 1 张蘑菇皮、2 根绳子和 2 份腐烂物制作。蘑菇皮可打毒菌蟾蜍获得。若启用孢子猎犬，也可用 4 份蘑菇皮碎片和 2 条蛙腿合成蘑菇皮。',null,[link('toadstool.html','毒菌蟾蜍打法'),link('spore-hound.html','孢子猎犬与蘑菇皮碎片')]],
   ['存放','装备后打开 12 格容器。放进去的蘑菇或孢子会停止自然变质，每 3 秒恢复 0.5 个百分点的新鲜度。识别依据是物品的蘑菇、孢子或特殊孢子标签。其余会腐坏的物品以通常速度的 2 倍变质。背包可以放下继续保管，恢复任务在未装备时也会运行。'],
  ],
  sources:[recipe(78),recipe(266),prefab('sporepack',56),prefab('sporepack',60),prefab('sporepack',66),prefab('sporepack',108),prefab('sporepack',116),prefab('sporepack',123),names(154)],
 },
 {
  id:'rimeweed-icepack',category:'new-items',prefab:'um_rimeweed_icepack',title:'冰袋',
  aliases:['霜草冰袋','冰敷袋','Ice Pack','Rimeweed Icepack'],
  summary:'一次性治疗品，基础回复 30 生命并降温。实际温度变化受目标装备影响。',
  configs:['snowstorms'],
  sections:[
   ['获取','启用暴风雪后，在炼金引擎旁用 1 张莎草纸、2 块冰、2 根霜冻藤蔓制作。藤蔓来自冬季的尖刺霜草，第二或第三阶段的主株可掉 2 根。',null,[link('rimeweed.html','尖刺霜草位置与掉落'),link('snowstorms.html','暴风雪发生条件')]],
   ['治疗与降温','对可治疗的目标用掉 1 个冰袋，基础回复 30 生命。常见体温下冰袋会立即降温，没有保暖时通常降到 −1 ℃。冬季保暖越高，降温越少。沃姆伍德的专属老兵诅咒生效时，治疗转为缓慢回复，冰袋的温度效果仍会立即结算。戴着冷热逆转帽时，冰袋的降温会变成升温，并消耗帽子耐久。',null,[link('wormwood.html','沃姆伍德的治疗机制'),link('pepperdragon-hat.html','冷热逆转帽')]],
   ['储藏与融化','可以堆叠和放进冰箱，基础保质期为 20 个游戏日。融化后留下莎草纸。若当时由角色携带，每个冰袋增加 2 点潮湿度。容器如果具备物品湿度接口，每个给容器增加 4 点湿度。放在地上融化时会润湿耕地。'],
  ],
  sources:[recipe(118),recipe(131),prefab('um_rimeweed',854),prefab('um_rimeweed',866),prefab('um_rimeweed',1038),
    prefab('um_rimeweed',1056),prefab('um_rimeweed',1077),prefab('um_rimeweed',1083),prefab('um_rimeweed',1085),
    beta('postinit/components/temperature.lua',11),beta('postinit/components/temperature.lua',13),...healingSources,names(696),names(699),names(819)],
 },
 {
  id:'saltpack',category:'new-items',prefab:'saltpack',title:'盐瓶3000',
  aliases:['盐瓶 3000','撒盐背包','撒盐机','Salt Pack','Saltpack'],
  summary:'穿在身体栏的除雪工具，撒盐可清除雪堆和冰矿，并打击附近的雪怪和龟类。',
  configs:['snowstorms'],
  sections:[
   ['获取与补充','启用暴风雪后，在炼金引擎旁用 1 个齿轮、2 块木板、4 份盐晶制作。新盐瓶是满的。用额外盐晶补充燃料，通常每份干燥盐晶补 60 个百分点，至多补满。'],
   ['开关与耗料','使用物品可启动或关闭撒盐。开启时每 0.25 秒检查一次，4 个地面距离单位内已有盐堆时跳过。实际撒一次扣 1.25 个百分点的燃料，并在脚边留下盐堆。燃料用尽时停止。'],
   ['除雪与战斗','每次撒盐直接清除半径 6 内可盐化的雪堆和冰矿，并尝试对附近符合条件的雪怪、蛞蝓龟和蜗牛龟各造成一次 30 点基础伤害。盐堆周边会压制新雪堆生成。耕地附近的盐堆会吸走土壤水分、让作物承受照料压力，然后自行消失。其他位置的盐堆遇到非冬季降雨会消失。',null,[link('snowstorms.html','暴风雪与雪堆'),link('snowmong.html','雪怪的打法与交易')]],
  ],
  sources:[recipe(118),recipe(123),prefab('saltpack',44),prefab('saltpack',49),prefab('saltpack',59),prefab('saltpack',64),prefab('saltpack',68),
    prefab('saltpack',101),prefab('saltpack',102),prefab('saltpack',121),prefab('saltpack',192),prefab('saltpack',195),prefab('saltpack',212),
    prefab('saltpile',27),prefab('saltpile',43),prefab('saltpile',48),prefab('saltpile',75),beta('scripts/components/snowstormwatcher.lua',107),
    beta('postinit/prefabs/rock_ice.lua',6),prefab('snowpile',494),beta('init/init_batterypower.lua',66),names(153)],
 },
 {
  id:'driftwood-fishing-rod',category:'new-items',prefab:'driftwoodfishingrod',title:'浮木钓杆',
  aliases:['浮木钓竿','浮木鱼竿','Driftwood Fishing Rod'],
  summary:'装备后在池塘垂钓。咬钩等待随鱼量变化，耐久为普通钓竿的 1.5 倍。',
  configs:[],
  sections:[
   ['获取','在炼金引擎旁用 3 块浮木、3 份蜘蛛丝和 2 根绳子制作。'],
   ['池塘垂钓','手持钓杆对池塘垂钓，咬钩后提竿收鱼。等待参数为 2 到 20 秒，池中鱼越少越接近上限，空池不会咬钩。拉扯阶段的最大时间按当前耐久比例在 0 到 5 秒之间变化，超时会同时失去鱼和钓杆。'],
   ['耐久与近战','新钓杆有 13.5 点耐久，每次成功收鱼扣 1 点。也可以近战敲打，基础伤害 4.25，每次命中耗 4 点耐久。想直接从海面收取鱼和漂浮物时，可用渔网。',null,[link('fishing-net.html','渔网的使用与耐久')]],
  ],
  sources:[recipe(238),prefab('driftwoodfishingrod',25),prefab('driftwoodfishingrod',60),prefab('driftwoodfishingrod',61),prefab('driftwoodfishingrod',65),
    prefab('driftwoodfishingrod',66),prefab('driftwoodfishingrod',69),prefab('driftwoodfishingrod',72),names(346)],
 },
 {
  id:'fishing-net',category:'new-items',prefab:'uncompromising_fishingnet',title:'渔网',
  aliases:['撒网','投网','海钓渔网','Fishing Net','Trawl Net'],
  summary:'向可投网的海面撒网，可以打捞浮物和捕捉海鱼。捕鱼重量档越高，收网时扣的耐久越多。',
  configs:[],
  sections:[
   ['获取与投网','在科学机器旁用 1 根绳子、2 块石头和 3 份蜘蛛丝制作。手持渔网右键向合适的海面投网，骑乘时无法投网。收网后渔获和拾到的物品会落在角色附近。',null,[link('driftwood-fishing-rod.html','查池塘用的浮木钓杆')]],
   ['渔获','落网点约 2 个地面距离单位内的漂浮物可一并打捞。测试版另外尝试捕捉范围内的海鱼，最多收 2 条，鱼重按该鱼种的最低重量生成。'],
   ['耐久','新网有 22 点耐久，每次成功收网至少扣 1 点。按捕到的每条鱼的最低重量再追加消耗。低于 100 加 2 点，100 至不足 200 加 3 点，200 及以上加 4 点。两条最重档海鱼合计会消耗 9 点耐久。'],
  ],
  sources:[recipe(242),prefab('uncompromising_fishingnet',60),prefab('uncompromising_fishingnet',67),beta('init/init_actions.lua',636),
    beta('postinit/components/fishingnet.lua',28),beta('postinit/components/fishingnet.lua',36),beta('postinit/components/fishingnet.lua',48),
    beta('postinit/components/fishingnet.lua',53),beta('postinit/components/fishingnet.lua',64),beta('postinit/components/fishingnet.lua',162),
    beta('scripts/stategraphs/SGuncompromising_fishingnetvisualizer.lua',92),names(425)],
 },
 {
  id:'rat-poison',category:'new-items',prefab:'ratpoisonbottle',title:'毒果酱与毒果酱陷阱',
  aliases:['毒果酱','毒果酱陷阱','老鼠药','灭鼠药','Rat Poison','Poisonous Jam'],
  summary:'放在地上引诱袭击鼠吃下，造成即时伤害和持续中毒。',
  configs:['rat_raids'],
  sections:[
   ['制作与布置','启用鼠潮后，在科学机器旁用 2 个红蘑菇、1 份果酱和 1 块石头制作 4 瓶。用瓶子在老鼠能走到的地面布置陷阱。远离陷阱等老鼠靠近，附近有会吓跑猎物的实体时，老鼠会避开这处诱饵。',null,[link('rat-raids.html','鼠潮的时机与应对')]],
   ['伤害','吃下后一般受到 24 点基础生命损失，随后持续 20 秒，每秒 2 点基础中毒伤害。袭击鼠对应为 60 点和每秒 5 点。中毒会让袭击鼠跳过继续吃毒果酱的寻食行为。毒果酱属于可吃的素食诱饵，玩家也要留意误食。'],
   ['一次布置可吃几口','一瓶布置后可被吃 9 口。第一次吃完会在同一位置补出 8 次，补出的诱饵逐次减少剩余次数。'],
  ],
  sources:[recipe(260),recipe(261),prefab('ratpoison',20),prefab('ratpoison',23),prefab('ratpoison',27),prefab('ratpoison',86),prefab('ratpoison',119),
    beta('init/init_tuning.lua',392),beta('init/init_tuning.lua',395),prefab('ratpoison_debuff',4),prefab('ratpoison_debuff',23),
    beta('scripts/brains/uncompromising_ratbrain.lua',273),beta('scripts/brains/uncompromising_ratbrain.lua',283),names(38),names(39)],
 },
 {
  id:'moon-eye-balm',category:'new-items',prefab:'um_eyebalm',title:'眼霜',
  aliases:['月岛眼霜','风暴眼霜','眼膏','Eye Balm'],
  summary:'治疗品，基础回复 8 生命并提供 8 分钟的护目镜式风暴视野。',
  configs:['moon_bees'],
  sections:[
   ['获取','启用腐臭蜂后，在炼金引擎旁用 1 个腐臭蜂巢、3 份腐臭蜂蜜和 3 个蚊子血囊制作 3 份眼霜。打掉月岛的一座腐臭蜂巢，固定给齐配方所需的巢和蜂蜜。',null,[link('lunar-island.html','去月岛哪里找腐臭蜂巢')]],
   ['治疗与风暴视野','对可治疗的角色使用，消耗 1 份并基础回复 8 生命，8 分钟内视野按护目镜方式处理。重复涂抹会把计时重置为 8 分钟，死亡会结束效果。遇到暴风雪时仍需单独准备保暖。',null,[link('snowstorms.html','暴风雪防护')]],
   ['角色差异','沃姆伍德的专属老兵诅咒生效时，治疗部分改成缓慢回复，视野增益仍正常施加。',null,[link('wormwood.html','沃姆伍德的治疗机制')]],
  ],
  sources:[recipe(177),recipe(178),prefab('um_beehive_moon',233),prefab('um_eyebalm',38),prefab('um_eyebalm',55),prefab('um_eyebalm',60),
    prefab('um_eyebalm',76),beta('postinit/player.lua',276),beta('postinit/sim.lua',168),...healingSources,names(731),names(732),names(740)],
 },
 {
  id:'sludge-sack',category:'new-items',prefab:'sludge_sack',title:'海泥包',
  aliases:['海泥背包','海泥防盗包','Sludge Sack','Sludge Backpack'],
  summary:'12 格身体栏背包，可保护包里的物品免遭袭击鼠等盗取。背包本身会持续保持潮湿。',
  configs:[],
  sections:[
   ['获取','在炼金引擎旁用 6 份海泥、2 张鲨鱼皮和 3 根绳子制作。海泥可从海面上的海泥喷孔采集或开采。击杀岩颚鲨固定掉 1 张鲨鱼皮。'],
   ['容量与防盗','装备在身体栏，打开 12 格容器。物品装入后会获得防盗标记，拿出时撤掉，袭击鼠等会略过包内有标记的物品。背包自身每 10 秒重新设为潮湿状态，可正常浮在水上。',null,[link('rat-raids.html','查袭击鼠如何偷东西'),link('rat-poison.html','制作毒果酱')]],
  ],
  sources:[recipe(252),prefab('sludgestack',10),prefab('sludgestack',275),beta('postinit/prefabs/shark.lua',9),
    prefab('sludge_sack',21),prefab('sludge_sack',32),prefab('sludge_sack',69),prefab('sludge_sack',83),prefab('sludge_sack',98),prefab('sludge_sack',103),
    beta('init/init_containers.lua',688),prefab('uncompromising_rat',148),names(446),names(449),names(450),names(455)],
 },
];
