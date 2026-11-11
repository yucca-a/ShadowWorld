const beta=(file,line)=>({file,line});
const cn=(file,line)=>({kind:'cn',file,line});
const cfg=line=>beta('modinfo.lua',line);
const names=line=>cn('init/init_strings/init_names.lua',line);
const role=(name,line)=>beta(`init/init_character_changes/${name}.lua`,line);
const link=(id,label)=>({id,label});

export const characterArticles=[
 {
  id:'warly',category:'characters',icon:'warly',title:'沃利',aliases:['Warly','厨师','大厨','厨师袋','食物记忆'],
  summary:'进食收益、重复料理记忆和物品栏内宰杀战利品都有调整，厨师袋可单独保留原版行为。',
  configs:['warly_changes','foodregen','vetcurse'],
  sections:[
   ['食物记忆','角色改动默认完整开启。食物记忆持续 3 个游戏日，重复进食衰减表的五档倍率为 60%、50%、35%、20%、10%。'],
   ['进食收益','有正饱食度收益的食物额外恢复该食物饱食值的 20%。关闭食物持续恢复时，无老兵诅咒的沃利也额外获得正生命值与正理智值的 20%。开启食物持续恢复后，无诅咒沃利在该机制下的生命与理智结算量按 1.2 倍计算，再判定走即时还是持续恢复。'],
   ['宰杀与厨师袋','在物品栏执行宰杀时，沃利可按被宰杀堆叠数量，从该猎物的战利品池额外抽取。默认厨师袋改为只能放入物品栏口袋的便携容器，打开会落地，并且不能装备或点燃。关闭厨师袋改动的档位仍保留沃利的其他改动。'],
  ],
  related:[link('food-recovery','食物持续恢复'),link('veterans-curse','老兵诅咒')],
  sources:[cfg(380),beta('init/init_tuning.lua',198),role('warly',5),role('warly',26),role('warly',92),role('warly',124),beta('init/init_food/init_foodregen.lua',4),beta('init/init_actions.lua',499),names(85)],
 },
 {
  id:'winona',category:'characters',icon:'winona',title:'薇诺娜',aliases:['Winona','女工','工程师','投石机钓鱼','脆弱玫瑰','器械箱','电能转换套件','蓄电池'],
  summary:'按高、中、低三档饱食度调整工作量、工具消耗与额外耗饥，制作和采集动画另有自己的判定。',
  configs:['winonaworker','winonarose','winonafishing','winona_items'],
  sections:[
   ['三档工作效率','工作能力默认开启。饱食度至少 66.6% 时，砍伐、采矿、敲击和划船按 1.5 倍工作量结算；饱食度低于 33.3% 时改为 0.666 倍；中间区间为基础倍率。岛屿冒险提供劈砍动作时，也将其纳入工作量调整。'],
   ['工具耐久','高、中、低饱食区间的适用工具消耗依次为 0.5、1、1.333 倍。范围包括砍伐、采矿、敲击、挖掘、攻击、划船和耕地；有劈砍动作时也包含劈砍。采摘会额外耗饥，但没有这项工具消耗倍率。'],
   ['高饱食额外耗饥','适用动作共用 0.3 秒的耗饥间隔。高饱食时，划船、耕地、采摘每次基础耗饥 0.1；砍伐 0.2；采矿、敲击和适用的劈砍 0.333；挖掘 0.5；攻击 0.15。各值再乘角色当前饥饿速率修正。'],
   ['中低饱食与骑乘','中间区间对应基础耗饥依次为 0.05、0.1、0.166、0.25 和 0.1。低于 33.3% 或骑乘时，这段工作能力不再追加耗饥。工作量、工具耐久与额外耗饥是三项分别判定的效果，不能把制作速度直接当作工作倍率。'],
   ['复活与采集','变鬼与复活有单独的工作状态回调，复活时重新按当前饱食度刷新工作倍率。采摘进入普通长动作时，具有饥饿制作标签的薇诺娜改用对应的饥饿制作动作；其他采集动作仍保留自身路由。'],
   ['投石机与脆弱玫瑰','默认开启投石机捕鱼调整，命中的适用海鱼会被抛出。默认开启玫瑰调整，薇诺娜受到致命伤时，若没有优先触发的复活道具，可消耗物品栏中的一朵脆弱玫瑰阻止死亡，将生命和理智设为 50%、饱食设为三分之二，并增加 25 个百分点的生命上限惩罚。'],
   ['专属制作','专属物品开关默认开启，添加器械箱、电能转换套件和蓄电池配方。电能转换套件在炼金引擎档解锁，一次制作蓄电池得到 3 个。'],
  ],
  sources:[cfg(371),cfg(374),cfg(375),cfg(376),role('winona',13),role('winona',29),role('winona',113),role('winona',12),role('winona',151),role('winona',157),role('winona',162),role('winona',175),role('winona',450),beta('postinit/components/health.lua',149),beta('postinit/components/health.lua',180),beta('init/init_recipes/recipes.lua',289),cn('init/init_strings/init_strings.lua',875),names(435),names(463),names(476)],
 },
 {
  id:'wanda',category:'characters',icon:'wanda',title:'旺达',aliases:['Wanda','钟表匠','警钟','第二次机会表','溯源表','裂缝表'],
  summary:'警钟与第二次机会表的平衡选项默认关闭，溯源表和裂缝表的地点命名仍单独生效。',
  configs:['wanda_nerf','vetcurse'],
  sections:[
   ['警钟','开启旺达平衡调整后，装有燃料的警钟按年龄应用伤害倍率。年轻为 1 倍，中年为 68/51，老年为 102/51。该段调整要求旺达未骑乘。'],
   ['第二次机会表','同一开关启用后，复活目标当前生命上限惩罚低于 75% 时，额外增加 25 个百分点。旺达以鬼魂作祟成功自救时，表会损毁并掉出拆解物。'],
   ['给锚点命名','溯源表可以给锚点命名，制成裂缝表时沿用名称。已标记的裂缝表需要目标分片可用，打开裂缝后回到溯源表，保留锚点与名称，并进入溯源表冷却。命名逻辑独立于旺达平衡开关。'],
   ['老兵诅咒','旺达实际获得诅咒后，特定暗影生物和梦魇生物造成的伤害会先被替换为按最大生命值换算的老化伤害，再按原有老化流程结算。'],
  ],
  related:[link('veterans-curse','老兵诅咒')],
  sources:[cfg(426),role('wanda',18),role('wanda',22),role('wanda',45),role('wanda',111),role('wanda',174),beta('postinit/components/oldager.lua',5),names(91)],
 },
 {
  id:'wes',category:'characters',icon:'wes',title:'韦斯',aliases:['Wes','小丑','哑剧演员','韦斯仇恨','蝙蝠仇恨'],
  summary:'老兵诅咒下，韦斯会主动吸引合条件的敌人。蝙蝠的目标保留另有一条独立规则。',
  configs:['vetcurse'],
  sections:[
   ['诅咒仇恨范围','韦斯获得老兵诅咒后才会周期检查并吸引敌人。通常检查距离为 16，浣猫为 12，触手、洞穴触手臂、眼球草与大型暗影触手为 4。敌人仍须能以韦斯为目标，现有交战对象和跟随关系也会影响结果。'],
   ['蝙蝠目标','普通蝙蝠与吸血蝙蝠会保留已经选中的韦斯作为目标。已有其他目标时，这段调整会跳过原本的周期搜索。蝙蝠规则独立于韦斯是否获得诅咒。'],
  ],
  related:[link('veterans-curse','老兵诅咒')],
  sources:[cfg(231),role('wes',1),role('wes',24),role('wes',94),role('wes',124),names(93)],
 },
 {
  id:'wendy',category:'characters',icon:'wendy',title:'温蒂',aliases:['Wendy','鬼女','姐姐','阿比盖尔','姐妹骨灰罐','哀悼荣耀'],
  summary:'让放在姐妹骨灰罐里的花瓣腐烂，可以获得哀悼荣耀。',
  configs:['wendy'],
  sections:[
   ['花瓣转化','默认开启。普通花瓣腐烂时，若直接由姐妹骨灰罐持有，腐烂产物会改为哀悼荣耀。把花瓣放在其他容器里腐烂仍走普通流程。转化使用花瓣自身的腐烂计时。'],
  ],
  sources:[cfg(303),beta('init/init_postinit.lua',190),beta('postinit/prefabs/petals.lua',4),names(94),cn('init/init_strings/init_tooltips.lua',36)],
 },
 {
  id:'willow',category:'characters',icon:'willow',title:'薇洛',aliases:['Willow','火女','纵火者','伯尼','薇洛的打火机','潜伏恐惧','烟雾'],
  summary:'手持未激活的伯尼可抑制潜伏恐惧的生成，打火机引导能清理近处烟雾。',
  configs:['bernie_buffs'],
  sections:[
   ['伯尼的暗影支配','默认开启。将未激活的伯尼装备在手上时，生成器判定角色具有暗影支配，跳过本次针对该角色的潜伏恐惧生成。'],
   ['用打火机清烟','打火机获得可引导施法能力后，引导期间每 0.3 秒移除 12 单位内带烟雾标签的实体。停止引导时停止清理。此功能走打火机的技能刷新逻辑，独立于伯尼开关。'],
  ],
  sources:[cfg(301),role('willow_bernie',4),role('willow',13),beta('scripts/components/uncompromising_shadowcreaturespawner.lua',105),beta('scripts/components/uncompromising_shadowcreaturespawner.lua',159),names(15),names(84),cn('init/init_strings/init_strings.lua',883)],
 },
 {
  id:'walter',category:'characters',icon:'walter',title:'沃尔特',aliases:['Walter','童子军','沃比','Woby','沃比饥饿表','zaspberry_lesser','viperfruit_lesser','moon_cap'],
  summary:'重做调整了沃比的变身门槛与饥饿表，沃尔特的诅咒另有受伤和恢复规则。',
  configs:['wixie_walter','woby_hunger_classic','vetcurse'],
  sections:[
   ['沃比变身','沃尔特与薇克茜重做默认开启。小沃比的饱食度达到 95% 时变大，大沃比降至 30% 时变小。大沃比降到 40% 或以下时可触发一次饥饿提醒，重新高于 40% 才会重置提醒。'],
   ['可采摘食物识别','小电光浆果、小幽暗浆果与月亮蘑菇被加入可采摘食物清单，供沃尔特相关的原生食物采摘判断使用。该清单本身不额外赠送产量，也不解除目标自身的采摘限制。'],
   ['饥饿表','默认启用经典沃比饥饿表。该选项由沃尔特与薇克茜重做载入，对有沃尔特标记的角色隐藏原表并以沃比事件更新自定义表。'],
   ['沃比受击与安抚','沃比受击会让主人损失本次伤害量二十分之一的理智，同一只沃比的这项转移有 0.3 秒触发间隔。带老兵诅咒的玩家抚摸小沃比，每只小沃比每游戏日最多可帮玩家扣除 5 个百分点的理智上限惩罚。'],
   ['老兵诅咒','沃尔特实际获得诅咒后，符合条件的受伤会增加理智上限惩罚，最多 75%。普通伤害取绝对值的 50%，持续伤害取 25%，再按基础最大理智和防护修正换算。后续受伤通常重置一天计时，恢复程序每次扣除 10 个百分点。'],
  ],
  related:[link('veterans-curse','老兵诅咒'),link('wixie','薇克茜')],
  sources:[cfg(258),cfg(261),beta('init/init_postinit.lua',342),beta('wixie_postinit/prefabs/wobysmall.lua',30),beta('wixie_postinit/prefabs/wobysmall.lua',60),beta('wixie_postinit/prefabs/wobysmall.lua',134),beta('wixie_postinit/prefabs/wobybig.lua',43),beta('wixie_postinit/widgets/controls.lua',26),role('walter',10),role('walter',16),role('walter',33),names(81),cn('init/init_strings/init_strings.lua',879)],
 },
 {
  id:'wurt',category:'characters',icon:'wurt',title:'沃特',aliases:['Wurt','鱼妹','鱼人妹','烤稻米','月亮鱼人'],
  summary:'沃特的寻路表纳入潮湿陷坑的积水地形，烤稻米列入食物偏好。',
  configs:['flooded_caves','mermtweaks'],
  sections:[
   ['涉水寻路','模组把潮湿陷坑的普通积水、石窟积水和沸腾积水纳入沃特可通过的寻路地形。是否能遇到这些地形仍取决于洞穴生成配置。'],
   ['烤稻米和月亮鱼人','烤稻米被登记为沃特的偏好食物，偏好倍率 1.33。开启鱼人调整时，月亮鱼人和月亮鱼人守卫更换领袖会跳过原本的领袖变更回调。'],
  ],
  related:[link('cave-worldgen','熔岩洞穴与潮湿陷坑')],
  sources:[cfg(558),cfg(893),role('wurt',6),role('wurt',19),role('wurt',26),names(189),cn('init/init_strings/init_strings.lua',885)],
 },
 {
  id:'woodie',category:'characters',icon:'woodie',title:'伍迪',aliases:['Woodie','伐木工','海狸人','鹅人','鹅人 II','变鹅','鹅人防水'],
  summary:'点出对应鹅人技能后，伍迪变身为鹅人时会获得额外的防水能力。',
  configs:[],
  sections:[
   ['鹅人防水','检测到伍迪处于鹅人形态且已激活「鹅人 II」技能时，把形态自带防水值设为 2.0。变身和激活技能后延迟 1 秒检查，读档后延迟 2 秒检查。'],
  ],
  sources:[beta('init/init_gamemodes/init_uncompromising_mode.lua',227),role('woodie',76),role('woodie',96),names(89)],
 },
];
