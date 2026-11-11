const beta=(file,line)=>({file,line});
const names=line=>({kind:'cn',file:'init/init_strings/init_names.lua',line});
const recipe=line=>beta('init/init_recipes/recipes.lua',line);
const prefab=(id,line)=>beta('scripts/prefabs/'+id+'.lua',line);
const tuning=line=>beta('init/init_tuning.lua',line);
const drops=line=>beta('postinit/prefabs/vetcurse_drops.lua',line);
const common=line=>beta('scripts/tools/um_commonfns.lua',line);
const link=(href,label)=>({href,label});
const armorMapping=[
 beta('modinfo.lua',175),
 beta('init/init_postinit.lua',618),
 beta('postinit/armor_rework.lua',61),
 beta('postinit/armor_rework.lua',62),
 beta('postinit/armor_rework.lua',70),
];

export const equipmentExpansionArticles=[
 {
  id:'moon-scale-armor',category:'new-items',prefab:'armor_glassmail',title:'月鳞甲',aliases:['月亮鳞甲','玻璃鳞甲','Glass Mail','Glassmail'],
  summary:'用月光龙蝇的材料制作的发光护甲。主动进攻会积攒并驱动环绕碎片，挨打时碎片会破裂。',
  configs:['wiltfly','wiltfly_spawn','armorrework'],
  sections:[
   ['获取与制作','开启时令龙蝇后，在天体祭坛用启迪鳞片 ×1、注能月亮碎片 ×10 制作。月光龙蝇固定掉启迪鳞片 ×1 和 3 块可开采的注能玻璃晶体。用镐挖开任意一块晶体，即可得到 6–10 枚注能月亮碎片。',null,[link('summer-dragonflies.html#summer-dragonflies-s3','月光龙蝇的出现条件与掉落')]],
   ['护甲与火焰防护','占用身体栏，耐久 945，默认吸收 60% 的普通伤害。关闭护甲重做后恢复为 70%。装备后获得持续微光，火焰伤害系数降为 0。'],
   ['积攒和清空碎片','攻击有伤害能力的目标，或命中训练假人、蚁狮、远古织影者和复活的骨架时，每累计 3 次有效攻击点亮一枚碎片，最多 8 枚。有效攻击会使碎片进入持续 2 秒的快速旋转。此时每枚碎片每 0.2 秒检测自身周围 2 单位内可被攻击的目标，命中造成 5 点伤害，排除玩家和月玻璃生物。受到攻击、格挡或脱下护甲时，当前已亮的碎片会一并破裂。'],
  ],
  sources:[names(59),names(60),names(61),recipe(224),prefab('moonmaw_dragonfly',356),prefab('glass_scales',3),prefab('glass_scales',43),prefab('armor_glassmail',5),prefab('armor_glassmail',39),prefab('armor_glassmail',76),prefab('armor_glassmail',82),prefab('armor_glassmail',96),prefab('armor_glassmail',99),prefab('armor_glassmail',162),prefab('armor_glassmail_shards',1),prefab('armor_glassmail_shards',8),prefab('armor_glassmail_shards',13),prefab('armor_glassmail_shards',60),prefab('armor_glassmail_shards',129),...armorMapping,beta('postinit/components/combat.lua',43)],
 },
 {
  id:'snow-goggles',category:'new-items',prefab:'snowgoggles',title:'猫眼护目镜',aliases:['雪地护目镜','暴雪护目镜','Snow Goggles'],
  summary:'提供保暖、理智恢复和护目镜视野，可抵消暴雪造成的移动惩罚。',
  configs:['snowstorms'],
  sections:[
   ['制作','开启暴风雪后，在炼金引擎用猫帽 ×1、时髦的护目镜 ×1、牛毛 ×2 制作。'],
   ['穿戴效果','装备在头部后有 120 点冬季保暖，每分钟恢复约 3.33 理智。护目镜视野能解除冬季全域暴雪和局部暴雪的移速惩罚，并减轻暴雪遮挡视野的效果。基础耐用时间为 10 个游戏日，仅在装备时消耗，用尽时消失。',null,[link('snowstorms.html#snowstorms-s2','暴风雪中的移动与防护'),link('rimeweed.html','尖刺霜草与局部暴雪')]],
  ],
  sources:[names(36),recipe(118),recipe(119),prefab('snowgoggles',27),prefab('snowgoggles',48),prefab('snowgoggles',66),prefab('snowgoggles',90),prefab('snowgoggles',96),prefab('snowgoggles',100),beta('scripts/components/snowstormwatcher.lua',58),beta('scripts/components/snowstormwatcher.lua',75),beta('scripts/widgets/snowover.lua',70)],
 },
 {
  id:'rime-helmet',category:'new-items',prefab:'um_hat_rime',title:'霜兽头盔',aliases:['霜冻头盔','Rime Helmet','Rime Hat','冰冻鼹鼠尾'],
  summary:'随佩戴者体温改变减伤的头盔。攻击不会消耗护甲耐久，但头盔会随时间融化。',
  configs:['snowstorms','armorrework'],
  sections:[
   ['获取与制作','开启暴风雪后，在炼金引擎用冰冻鼹鼠尾 ×1、霜冻藤蔓 ×2、石头 ×6 制作。冰冻鼹鼠尾可通过在冬季击杀雪怪获取，霜冻藤蔓从尖刺霜草周围的荆棘获得。',null,[link('snowmong.html#snowmong-s3','雪怪掉落'),link('rimeweed.html','尖刺霜草的生成与采集')]],
   ['体温与防护','初始伤害吸收为 60%。装备后随体温变化刷新，基础值每升高 1℃ 减少 1 个百分点，限制在 40%–75%。默认开启护甲重做，基础值高于 70% 时实际吸收 65%，高于 60% 且至多 70% 时实际吸收 60%。例如 10℃、25℃、45℃ 时分别吸收 65%、60%、40%，关闭护甲重做后分别为 75%、60%、40%。另提供 20% 防水。'],
   ['融化与保存','制作完成后开始融化，基础时间为 7 个游戏日。可放进冰箱延缓融化。若在角色身上融化，会增加 8 点潮湿。放在地上融化时会湿润所在位置的农田。椒龙会把地上的霜兽头盔当作食物吃掉。',null,[link('pepperdragon-hat.html','椒龙与冷热逆转帽')]],
  ],
  sources:[names(696),names(702),names(703),recipe(118),recipe(140),recipe(141),prefab('um_hat_rime',10),prefab('um_hat_rime',16),prefab('um_hat_rime',28),prefab('um_hat_rime',34),prefab('um_hat_rime',53),prefab('um_hat_rime',87),prefab('um_hat_rime',107),prefab('um_hat_rime',112),prefab('um_hat_rime',115),...armorMapping,beta('postinit/armor_rework.lua',98),beta('scripts/brains/um_pepperdragonbrain.lua',43),beta('scripts/brains/um_pepperdragonbrain.lua',60),beta('scripts/stategraphs/SGum_pepperdragon.lua',419)],
 },
 {
  id:'pepperdragon-hat',category:'new-items',prefab:'um_hat_pepperdragon',title:'冷热逆转帽',aliases:['椒龙帽','体温反转','Pepperdragon Hat'],
  summary:'把升温和降温方向颠倒的护目帽。基础防水 20%，使用会消耗耐久。',
  configs:['magma_caves'],
  sections:[
   ['获取与制作','开启熔岩洞穴后，在灵子分解器用储火袋 ×1、黄铁矿 ×8、红宝石 ×2 制作。储火袋来自熔岩洞穴巢区的椒龙，黄铁矿可开采黄铁矿岩获得。',null,[link('cave-worldgen.html#cave-worldgen-s2','熔岩洞穴的生成设置')]],
   ['如何逆转体温','戴上后，直接施加的体温变化会取反，例如原本让角色升温 10℃ 的变化会使体温下降 10℃。温度组件的周期更新也会镜像这一轮升降，并将结果限制在角色体温上下限内。穿戴时还获得 20% 防水及护目镜视野，能免受暴雪的移速惩罚。',null,[link('snowstorms.html#snowstorms-s2','暴雪的护目镜判定')]],
   ['耐久消耗','直接改变体温时按原变化量的绝对值扣耐久。周期更新则按反转并限制后的体温绝对值乘 0.001 扣耐久。不能使用针线包修补，耗尽后帽子消失。'],
  ],
  sources:[names(735),names(815),names(816),names(819),recipe(320),recipe(339),recipe(340),prefab('um_pepperdragon',25),prefab('magmarocks',32),beta('scripts/map/rooms/caves/moltenregions.lua',119),prefab('um_hat_pepperdragon',50),prefab('um_hat_pepperdragon',73),prefab('um_hat_pepperdragon',74),prefab('um_hat_pepperdragon',77),beta('init/init_postinit.lua',72),beta('postinit/components/temperature.lua',11),beta('postinit/components/temperature.lua',13),beta('postinit/components/temperature.lua',33),beta('postinit/components/temperature.lua',36),beta('scripts/components/snowstormwatcher.lua',58)],
 },
 {
  id:'snaildrake-helmet',category:'new-items',prefab:'snaildrakehat',title:'蜗龙角盔',aliases:['刺蜗龙帽','Snaildrake Helmet','Snaildrake Hat'],
  summary:'刺蜗龙掉落的护甲头盔，同时提供普通减伤、火焰减伤与防水。',
  configs:['armorrework'],
  sections:[
   ['获取','在地表沸腾地带的裂缝附近击杀刺蜗龙，有 50% 概率掉落。可用拆解魔杖回收外壳碎片，配方基数为 3 块。',null,[link('snaildrakes.html#snaildrakes-s3','两种蜗龙的掉落与打法'),link('boiling-springs.html','沸腾地带的地形')]],
   ['穿戴效果','占用头部装备栏，耐久 525，防水 20%。默认吸收 60% 的普通伤害，关闭护甲重做后恢复为 70%。佩戴期间火焰伤害乘以 0.25，脱下头盔时移除这项抗性。'],
  ],
  sources:[names(670),prefab('snaildrake',41),prefab('snaildrakehat',24),prefab('snaildrakehat',45),prefab('snaildrakehat',79),prefab('snaildrakehat',87),tuning(300),recipe(469),...armorMapping,beta('postinit/components/combat.lua',43)],
 },
 {
  id:'cursed-antler',category:'new-items',prefab:'cursed_antler',title:'诅咒鹿角',aliases:['巨鹿武器','Cursed Antler','冰刺鹿角'],
  summary:'独眼巨鹿掉落的诅咒武器，充能后的下一击会提高伤害并释放范围冰刺。',
  configs:['vetcurse'],
  sections:[
   ['获取与装备','房间的老兵诅咒档位为默认或始终开启时，击杀独眼巨鹿固定额外掉落一把。玩家自身激活老兵诅咒后才能持续装备。',null,[link('deerclops.html#deerclops-s3','独眼巨鹿掉落'),link('veterans-curse.html','怎样激活老兵诅咒')]],
   ['充能打击','冷却期间基础伤害 34，充能后下一击的基础伤害升到 100，并为主目标增加 1 点冰冻值。主目标周围 2.5 单位内的其他可攻击非友方生物受到 34 点普通伤害，并增加 0.5 点冰冻值。已经冻结的生物不再叠加这次冰冻值。武器提供 1 点暗影等级。'],
   ['冷却','充能打击会进入 5 秒冷却。同一冷却规则也会在 8 单位内搜索两种鹿角，并对命中的自己持有、无人持有或由非玩家实体持有的鹿角施加冷却。',null,[link('crystal-cursed-antler.html','晶体诅咒鹿角')]],
  ],
  sources:[names(221),drops(9),drops(17),prefab('cursed_antler',8),prefab('cursed_antler',13),prefab('cursed_antler',22),prefab('cursed_antler',26),prefab('cursed_antler',29),prefab('cursed_antler',32),prefab('cursed_antler',41),prefab('cursed_antler',143),tuning(211),tuning(362),tuning(370),tuning(371),tuning(372),common(22),common(25),common(204),common(207)],
 },
 {
  id:'crystal-cursed-antler',category:'new-items',prefab:'crystal_cursed_antler',title:'晶体诅咒鹿角',aliases:['Crystal Cursed Antler','晶体巨鹿武器','晶体鹿角'],
  summary:'晶体独眼巨鹿掉落的诅咒武器，充能攻击带额外位面伤害、冰刺和减速冰圈。',
  configs:['vetcurse'],
  sections:[
   ['获取与装备','击杀晶体独眼巨鹿后固定额外掉落一把。掉落规则独立于房间的老兵诅咒档位，穿戴检查仍要求玩家自身激活老兵诅咒。',null,[link('veterans-curse.html','怎样激活老兵诅咒'),link('cursed-antler.html','独眼巨鹿掉落的诅咒鹿角')]],
   ['直接与范围伤害','普通基础伤害为 34，冷却时附加 17 位面伤害，充能时附加 116 位面伤害。充能一击给主目标增加 1 点冰冻值，并对主目标周围 2.5 单位内可攻击的其他非友方生物造成 34 普通伤害和 17 位面伤害，增加 0.5 点冰冻值。此次攻击随后进入 5 秒冷却，遵循两种鹿角共用的冷却规则。'],
   ['减速冰圈','充能命中后还会在目标处生成冰圈，约 8 秒后开始消散。冰圈内 3 单位范围里，符合条件的非友方生物移速减半，并持续累积少量冰冻值。冰圈的积累设有目标冰冻抗性的 70% 门槛，可配合命中时的冰冻值控场。'],
  ],
  sources:[names(225),drops(40),drops(47),prefab('crystal_cursed_antler',13),prefab('crystal_cursed_antler',26),prefab('crystal_cursed_antler',30),prefab('crystal_cursed_antler',33),prefab('crystal_cursed_antler',51),prefab('crystal_cursed_antler',55),prefab('crystal_cursed_antler',179),prefab('crystal_cursed_antler',185),prefab('crystal_cursed_antler',201),prefab('crystal_cursed_antler',232),prefab('crystal_cursed_antler',236),tuning(366),tuning(373),tuning(374),tuning(375),tuning(376),tuning(377),beta('postinit/components/planardamage.lua',11),common(207)],
 },
 {
  id:'nettle-mask',category:'new-items',prefab:'um_hat_nettlemask',title:'荨麻面具',aliases:['火荨麻面具','防毒面具','Nettle Mask'],
  summary:'由火荨麻叶制成的防护面具，可避开荨麻和部分孢子危害。换戴时会损失新鲜度并施加火荨麻毒。',
  configs:['magma_caves','nightterrors','snowstorms'],
  sections:[
   ['获取与制作','在炼金引擎用火荨麻叶 ×16、啜食者皮 ×1、金块 ×1 制作。到熔岩洞穴的岩浆池周围寻找荨麻丛，采收可获得火荨麻叶。',null,[link('cave-worldgen.html#cave-worldgen-s2','熔岩洞穴的生成设置')]],
   ['穿戴时的防护','提供 10% 防水和护目镜视野，每分钟损失 10 理智。佩戴者经过荨麻丛时免于触发碰撞毒性，也能避开荨麻孢子的范围伤害。启用夜惊时，面具可抵消夜惊额外理智流失的 90%。',null,[link('snowstorms.html#snowstorms-s2','暴雪的护目镜判定')]],
   ['毒气与孢子云','面具的防毒效果能挡住毒菌蟾蜍的孢子云光环、烟雾的周期伤害和鼠穴区域的空气伤害。鼠穴喷口的浓缩毒气依然有害，过滤后扣 20 生命和 15% 生命上限。',null,[link('rat-raids.html','鼠潮与鼠穴')]],
   ['佩戴代价','装备时立即损失 5% 新鲜度并施加 10 秒的火荨麻毒。中毒时，体温低于 80℃ 的玩家会额外升温 20℃，并临时受到 60 点温度修正。装备时一般还直接损失 10 生命，沃姆伍德和薇洛免去这笔直接扣血。基础保鲜时间为 8 个游戏日，腐烂后留下 1 金块。'],
  ],
  sources:[names(636),names(637),names(859),recipe(64),prefab('lava_pond_cave',67),prefab('um_pyre_nettles',30),prefab('um_pyre_nettles',315),prefab('um_hat_nettlemask',8),prefab('um_hat_nettlemask',20),prefab('um_hat_nettlemask',26),prefab('um_hat_nettlemask',35),prefab('um_hat_nettlemask',38),prefab('um_hat_nettlemask',76),prefab('um_hat_nettlemask',94),prefab('um_hat_nettlemask',100),prefab('um_hat_nettlemask',102),prefab('um_hat_nettlemask',107),prefab('umdebuff_pyre_toxin',60),prefab('umdebuff_pyre_toxin',64),prefab('um_smolder_spore',59),prefab('smog',306),prefab('ratgashole',27),prefab('ratgashole',28),beta('postinit/components/locomotor.lua',12),beta('postinit/prefabs/sporecloud.lua',12),beta('scripts/components/uncompromising_lungs.lua',6),beta('scripts/components/uncompromising_lungs.lua',39),beta('scripts/components/terrorized.lua',34),beta('scripts/components/terrorized.lua',83)],
 },
];
