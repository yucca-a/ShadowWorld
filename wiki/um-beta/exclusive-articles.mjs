const beta=(file,line)=>({file,line});
const names=line=>({kind:'cn',file:'init/init_strings/init_names.lua',line});
const recipe=line=>beta('init/init_recipes/recipes.lua',line);
const wixieRecipe=line=>beta('init/init_recipes/recipes_wixie.lua',line);
const wixieState=line=>beta('wixie_postinit/stategraphs/SGwixie.lua',line);
const containers=line=>beta('init/init_containers.lua',line);
const cfg=line=>beta('modinfo.lua',line);

export const exclusiveArticles=[
 {
  id:'honey-rounds',category:'new-items',icon:'slingshot_gnasher',title:'蜂蜜弹药',aliases:['Honey Rounds','um_slingshotammo_honey','slingshotammo_honey','蜂蜜减速'],
  summary:'命中后让目标沿途留下蜂蜜，地面蜂蜜可把合条件生物的移动速度降至 66%。',
  configs:['wixie_walter'],
  sections:[
   ['制作与装填','启用薇希与沃尔特重做后，具有弹药制作资格的薇希在炼金引擎用蜂蜜 ×3 制作，基础产量为 10 发。将弹药装进适用弹弓后射击。'],
   ['命中与持续','命中会刷新目标的留蜜状态。每 0.2 秒检查一次，基础累计 75 次检查后结束，因此基础留蜜期为 15 秒，再乘弹药获得的威力系数。再次命中会刷新这段时间，不是每发永久叠加。'],
   ['地面蜂蜜','蜜迹在 2 单位范围内检查可移动生物，移动速度倍率为 0.66。玩家、鬼魂和暂离场景的实体被排除。通常不影响未被本弹药命中的飞行生物；蜜迹在陆地生成，水面改为溅水效果。已有黏液减速的目标不会被这项速度倍率覆盖。目标移动越快，落蜜间隔越短，蜜迹本身也有独立的短暂存在时间。'],
  ],
  related:[{id:'wixie',label:'薇希'},{id:'slingshot-gnasher',label:'活木弹弓-切齿'}],
  sources:[wixieRecipe(78),beta('scripts/prefabs/slingshotammo_extras.lua',471),beta('scripts/prefabs/slingshotammo_extras.lua',483),beta('scripts/prefabs/slingshotammo_extras.lua',519),beta('scripts/prefabs/slingshotammo_extras.lua',529),beta('scripts/prefabs/wixiehoney_trail.lua',7),beta('scripts/prefabs/wixiehoney_trail.lua',61),beta('scripts/prefabs/wixiehoney_trail.lua',67),names(581)],
 },
 {
  id:'slingshot-gnasher',category:'new-items',title:'活木弹弓-切齿',aliases:['活木弹弓','切齿','Gnasher'],
  prefab:'slingshot_gnasher',icon:'slingshot_gnasher',
  summary:'薇希的单槽弹弓。满蓄力出手后，只要还有弹药就会立即开始下一次蓄力。',
  configs:['wixie_walter'],
  sections:[
   ['制作','启用薇希替换后，由薇希在暗影操纵器用活木头 ×1、噩梦燃料 ×2、蚊子血囊 ×2 制作。岛屿冒险的海难区域改用黄色蚊子血囊 ×2。'],
   ['抓住满蓄力时机','以蓄力动画的时间点计，第 19 帧进入 1.25 倍威力档，第 24 帧达到 2 倍，第 29 帧回落到 1.25 倍。以满档射出且仍有弹药时，会直接进入下一轮蓄力。'],
  ],
  sources:[names(574),wixieRecipe(11),beta('init/init_recipes/recipes_ia.lua',100),wixieState(367),wixieState(440),wixieState(603),beta('scripts/prefabs/slingshot_gnasher.lua',308)],
 },
 {
  id:'slingshot-matilda',category:'new-items',title:'浮木弹弓-玛蒂尔达',aliases:['浮木弹弓','玛蒂尔达','Matilda'],
  prefab:'slingshot_matilda',icon:'slingshot_matilda',
  summary:'薇希的三槽弹弓。蓄力增加参与射击的弹药槽数。',
  configs:['wixie_walter'],
  sections:[
   ['制作','启用薇希替换后，由薇希在炼金引擎用浮木 ×1、猫尾 ×1、蚊子血囊 ×3 制作。岛屿冒险的海难区域改用牛角 ×1、藤蔓 ×2、黄色蚊子血囊 ×3。'],
   ['三槽射击','短蓄力使用第一个弹药槽。以蓄力动画的时间点计，第 21 帧起最多发射两槽，第 28 帧起最多发射三槽。对应的槽位有弹药才会射出，连射间隔为 0.1 秒。普通弹道在瞄准方向两侧各有最多 15° 的随机偏移。'],
  ],
  sources:[names(573),wixieRecipe(15),beta('init/init_recipes/recipes_ia.lua',101),wixieState(361),wixieState(384),wixieState(424),beta('scripts/prefabs/slingshot_matilda.lua',247),containers(665)],
 },
 {
  id:'slingshot-jessie',category:'new-items',title:'绝望弹弓-杰西',aliases:['绝望弹弓','杰西','Jessie'],
  prefab:'slingshot_jessie',icon:'slingshot_jessie',
  summary:'薇希的六槽暗影弹弓，可在单发、两连发和三向散射之间切换。',
  configs:['wixie_walter'],
  sections:[
   ['制作','启用薇希替换后，由薇希在暗影术基座用纯粹恐惧 ×2、暗影碎布 ×2 制作。该配方无须点出对应的阵营技能。'],
   ['装填和切换射击模式','六槽填满后才能开火，打空再装填。装备后可以切换单发、间隔 0.1 秒的两连发，以及沿 −30°、0°、30° 同时射出的三发散射。三种模式传给弹药的威力系数依次为 1.75、1.5 和 1.25。'],
  ],
  sources:[names(575),wixieRecipe(19),wixieRecipe(141),beta('scripts/prefabs/slingshot_jessie.lua',15),beta('scripts/prefabs/slingshot_jessie.lua',98),beta('scripts/prefabs/slingshot_jessie.lua',236),beta('scripts/prefabs/slingshot_jessie.lua',358),beta('scripts/prefabs/slingshot_jessie.lua',390),containers(668)],
 },
 {
  id:'slingshot-claire',category:'new-items',title:'光芒弹弓-克莱尔',aliases:['光芒弹弓','克莱尔','Claire'],
  prefab:'slingshot_claire',icon:'slingshot_claire',
  summary:'薇希的月亮阵营弹弓，靠持续引导提高威力，再次操作时发射。',
  configs:['wixie_walter'],
  sections:[
   ['制作','启用薇希替换后，由薇希在辉煌铁匠铺用纯粹辉煌 ×2、亮茄外壳 ×2 制作。该配方无须点出对应的阵营技能。'],
   ['引导和释放','引导从 1 倍威力开始，每 0.3 秒增加 0.25 倍，最高为 2 倍。再次操作便以当时的档位释放。使用梦魇弹药时，满档的一次射击会消耗一颗弹药并发出五枚投射物。'],
  ],
  sources:[names(576),names(579),wixieRecipe(24),wixieRecipe(142),beta('scripts/prefabs/slingshot_claire.lua',151),beta('scripts/prefabs/slingshot_claire.lua',186),beta('scripts/prefabs/slingshot_claire.lua',356)],
 },
 {
  id:'winona-toolbox',category:'new-items',title:'器械箱',aliases:['薇诺娜器械箱','工具箱','Winona’s Toolbox'],
  prefab:'winona_toolbox',icon:'winona_toolbox',
  summary:'薇诺娜制作的便携容器，打开时放到地上，可分类收纳套件、电池、宝石等。',
  configs:['winona_items','toolbox_tools'],
  sections:[
   ['制作','薇诺娜可用木板 ×2、金块 ×4、可靠的胶布 ×2 制作，无需科技。'],
   ['可收纳物品','可放入带器械箱物品标签的升级套件和蓄电池、宝石、便携器械及噩梦燃料。另有一个默认关闭的配置，开启后也能收纳带工具标签的物品。打开器械箱会把它放到地上，拾取时关闭。'],
  ],
  sources:[names(435),cfg(376),recipe(290),containers(101),containers(833),beta('scripts/prefabs/winona_toolbox.lua',61)],
 },
 {
  id:'electrical-upgrade-kit',category:'new-items',title:'电能转换套件',aliases:['电能升级','电灯','电矿工帽','Electrical Upgrade Kit'],
  prefab:'winona_upgradekit_electrical',icon:'winona_upgradekit_electrical',
  summary:'将提灯或矿工帽改成电池供电的版本，耗能速率降至原来的 75%。',
  configs:['winona_items'],
  sections:[
   ['制作','薇诺娜在炼金引擎用金块 ×6、可靠的胶布 ×2、废料 ×4 制作。'],
   ['转换操作','拿起套件，对尚未电气改造的提灯或矿工帽执行升级。提灯升级为电灯，矿工帽升级为电矿工帽；套件作为升级材料消耗。转换后不能继续重复使用同类升级套件。'],
   ['燃料与充电','改造后改用电池燃料，耗能速率为原来的 75%。可用蓄电池等电池燃料补充电量；支持部分充电，充电最多补到 100%，满电会拒绝继续充电。这里记录测试版本体规则，淬炼之季的再次改造与 200% 过充属于另一分区的扩展。'],
   ['保存与提灯作祟','升级状态随存档保存，读档后恢复电气名称、燃料类型和节能倍率。鬼魂作祟亮着的电灯可将其关闭；灯原本关闭时仍走提灯原有的作祟行为。'],
  ],
  sources:[names(459),names(476),cfg(376),recipe(293),beta('scripts/prefabs/winona_upgradekit.lua',46),beta('postinit/prefabs/lantern.lua',25),beta('postinit/prefabs/minerhat.lua',21),beta('postinit/prefabs/lantern.lua',7),beta('postinit/prefabs/lantern.lua',12),beta('postinit/prefabs/lantern.lua',50),beta('postinit/prefabs/lantern.lua',64)],
 },
 {
  id:'powercell',category:'new-items',title:'蓄电池',aliases:['薇诺娜蓄电池','一次性电池','Power Cell'],
  prefab:'powercell',icon:'powercell',
  summary:'一次性电池燃料。烧毁时按堆叠数量造成范围电击。',
  configs:['winona_items'],
  sections:[
   ['制作和供能','薇诺娜可用可靠的胶布 ×1、金块 ×1、硝石 ×2 制作，每次产出三节，无需科技。可为电灯、电矿工帽等接受电池燃料的装备补充电量。'],
   ['烧毁伤害','蓄电池烧毁时会搜索 5 单位内有生命组件的目标，排除暗影、发条生物和暂离场景的实体。对符合条件的存活目标，每节造成 30 点生命损失，具备电绝缘的目标每节损失 15 点。'],
  ],
  sources:[names(463),cfg(376),recipe(295),beta('scripts/prefabs/powercell.lua',11),beta('scripts/prefabs/powercell.lua',104)],
 },
 {
  id:'gemology-pouch',category:'new-items',title:'宝石袋',aliases:['珠宝袋','Gemology Pouch','Gem Pouch'],
  prefab:'um_gemology_pouch',icon:'um_gemology_pouch',
  summary:'宝石学的专用收纳袋，共 25 格，接受宝石及带宝石学标签的晶洞。',
  configs:['gemology'],
  sections:[
   ['制作','启用宝石学后，可在灵子分解器用珍藏黄水晶 ×1、猪皮 ×4、噩梦燃料 ×2 制作。'],
   ['收纳规则','宝石袋有 5 行 5 列。可装入宝石学定义中的宝石，以及带有宝石学宝石或晶洞标签的物品。打开时会放到地上，拾取时自动关闭。'],
  ],
  sources:[names(786),names(858),cfg(184),recipe(99),containers(141),containers(628),beta('scripts/prefabs/um_gemology_pouch.lua',85)],
 },
 {
  id:'amulet-backpack',category:'new-items',title:'护符镶嵌背包',aliases:['护符背包','镶嵌背包','Amulet Backpack','宝石学背包'],
  prefab:'um_backpack_amuletuse',icon:'um_backpack_amuletuse',
  summary:'穿戴时可以触发第九格内兼容护符的装备效果。',
  configs:['gemology'],
  sections:[
   ['制作','启用宝石学后，可在天体宝球处用巨型触手皮 ×3、奥术紫水晶 ×1、金块 ×6 制作。'],
   ['护符位','有八个普通位置和一个额外位置。穿上背包后，第九格里兼容的护符才会触发装备效果。源码列出红、蓝、紫、黄、橙、绿六种原版护符和唤灵护符。第九格仍能放普通物品。'],
   ['黄护符','第九格内的黄护符在有燃料时将移动速度乘以 1.2，燃料耗尽时取消该加成。脱下背包也会结束该背包施加的效果。'],
  ],
  sources:[names(286),names(780),names(870),names(874),cfg(184),recipe(83),containers(326),beta('scripts/prefabs/um_backpack_amuletuse.lua',121),beta('scripts/prefabs/um_backpack_amuletuse.lua',153),beta('scripts/prefabs/um_backpack_amuletuse.lua',181)],
 },
];
