const beta=(file,line)=>({file,line});
const cn=(file,line)=>({kind:'cn',file,line});
const cfg=line=>beta('modinfo.lua',line);
const names=line=>cn('init/init_strings/init_names.lua',line);
const role=(name,line)=>beta(`init/init_character_changes/${name}.lua`,line);
const link=(id,label)=>({id,label});

export const additionalArticles=[
 {
  id:'wortox',category:'characters',icon:'wortox',title:'沃拓克斯',aliases:['Wortox','小恶魔','恶魔人','恶魔','双尾心','灵魂治疗'],
  summary:'普通灵魂改为持续治疗，技能树可改变治疗方式，也能把双尾心做成抵消致命伤的道具。',
  configs:['wortox'],
  sections:[
   ['灵魂治疗','默认范围为 8，目标必须存活、可见且处于范围内。优先选择已受伤的玩家，旺达默认不在普通治疗名单内。未受技能影响时，只有一名合格伤员的结算量为 10 点生命，目标越多，每名目标分到的治疗越少。淘气包目标的治疗量再减半。'],
   ['治疗技能','灵魂触及让掉落的灵魂靠近伤员并增大治疗范围。后续治疗技能可增加即时治疗，或加快后续治疗、减轻多人治疗衰减并给目标附加灵魂振奋。'],
   ['双尾心','点出对应技能后，可用 20 个灵魂制作双尾心。将它放在物品栏中，可在遭受致命伤时消耗它以抵消这次死亡，并增加 25 个百分点的生命上限惩罚。若双尾心绑定的沃拓克斯点出进阶技能，还会释放灵魂。'],
  ],
  sources:[cfg(396),role('wortox',11),role('wortox',42),role('wortox',128),role('wortox',163),role('wortox',180),beta('postinit/components/health.lua',78),beta('postinit/components/health.lua',123),beta('scripts/prefabs/healthregenbuff_vetcurse.lua',8),cn('init/init_strings/init_descriptions/skilltreestrings.lua',219),names(82)],
 },
 {
  id:'wormwood',category:'characters',icon:'wormwood',title:'沃姆伍德',aliases:['Wormwood','植物人','伍姆伍德','荆棘陷阱','光合作用','改进光合作用'],
  summary:'挖植物额外掉理智，火焰弱点加重，荆棘陷阱一次能制作两个。',
  configs:['wormwood_extrafiredmg','wormwood_plants','wormwood_trapbuffs','wormwood_photosynthesis'],
  sections:[
   ['火焰与挖掘','默认火焰伤害倍率从 1.25 提高到 1.75，燃烧时间从约 4.3 秒提高到 6.66 秒。自己挖掉植物并触发植物死亡事件时，额外失去 5 点理智，并清除尚未结算的种植理智奖励。'],
   ['荆棘陷阱与护甲','默认一次制作 2 个荆棘陷阱，普通陷阱和荆棘护甲的刺击特效不会击中玩家。霜冻外壳有独立的冰刺特效。'],
   ['改进光合作用','点出技能后，季节切换到春季或夏季时会获得一次促进绽放的施肥效果。这两个季节也会加快有肥料时的绽放进度，阻止绽放结束阶段的自然衰减。'],
  ],
  related:[link('rimeweed-bramble-armor','霜冻外壳'),link('rimeweed-icepack','冰袋'),link('moon-eye-balm','眼霜')],
  sources:[cfg(418),cfg(420),cfg(422),cfg(425),beta('init/init_tuning.lua',195),beta('init/init_tuning.lua',596),role('wormwood',24),role('wormwood',127),role('wormwood',172),role('wormwood',196),role('wormwood',237),role('skilltree_wormwood',22),beta('init/init_recipes/recipe_changes.lua',354),cn('init/init_strings/init_descriptions/skilltreestrings.lua',158)],
 },
 {
  id:'wx78',category:'characters',icon:'wx78',title:'WX-78',aliases:['WX78','机器人','电路','生物扫描','备份底盘'],
  summary:'默认雷击会扣理智并充电，备份底盘只保存护盾，测试版生物可以补齐部分电路的扫描来源。',
  configs:['wx78','wx78_backupbody'],
  sections:[
   ['雷击与充电','开启 WX-78 雷击调整后，未绝缘且存活、非无敌的 WX-78 被雷击时失去 33 理智，并增加 1 格电量。绝缘时只触发避雷事件。食用小电光浆果补 1 格，电光浆果补 3 格，电光浆果芭菲和蓄电池各补 6 格。'],
   ['备份底盘','该调整默认开启。玩家写入和读取底盘的备份属性时，只保留 WX-78 的护盾量。'],
   ['新增扫描对象','黑寡妇对应超级强化电路，可累积的生物数据上限为 6。蚜虫对应胃增益电路，上限 2；果蝠对应加速电路，上限 2；冰川青年座狼对应制冷电路，上限 6。',null,[{href:'hooded-widow.html',label:'黑寡妇'},{href:'fruitbat.html',label:'果蝠'},{href:'glacial-hound.html',label:'冰川青年座狼'}]],
  ],
  related:[link('powercell','蓄电池')],
  sources:[cfg(304),cfg(305),role('wx78',29),role('wx78',41),role('wx78',49),role('wx78',75),role('wx78',110),beta('scripts/prefabs/zaspberry.lua',144),beta('scripts/prefabs/zaspberry.lua',162),beta('scripts/prefabs/zaspberryparfait.lua',53),beta('scripts/prefabs/powercell.lua',101),names(45),names(180),names(235),names(254),names(258),names(295),names(461)],
 },
 {
  id:'wickerbottom',category:'characters',icon:'wickerbottom',title:'薇克巴顿',aliases:['Wickerbottom','老奶奶','图书管理员','月之魔典','实用求雨仪式'],
  summary:'队友可向她学习一本科技；默认月之魔典改为只影响附近目标。',
  configs:['wickerbottom_changes'],
  sections:[
   ['向她学习','默认和保留魔典的档位都能让其他玩家在薇克巴顿身边学习科学机器档位的配方。她提供的是原型制作科技。'],
   ['月之魔典','默认完整调整将阅读效果改为影响半径 8 内的合格可变异生物、兽化生物和伍迪。伍迪未兽化时可被直接触发变身，已兽化时补满兽化值。魔典可用 3 次，阅读消耗 50 理智。选择保留魔典的档位可沿用原版魔典。'],
   ['实用求雨仪式','在风暴威胁标记下阅读时，会进入龙卷风分支。有指定转向点时，现有龙卷风会采用该目标的路线编号，120 秒后归零。普通情况下仍调用原版求雨逻辑。'],
  ],
  related:[link('woodie','伍迪')],
  sources:[cfg(333),role('wickerbottom',267),role('wickerbottom',275),role('wickerbottom',300),role('wickerbottom',330),role('wickerbottom',414),role('wickerbottom',451),names(87)],
 },
 {
  id:'wolfgang',category:'characters',icon:'wolfgang',title:'沃尔夫冈',aliases:['Wolfgang','大力士','强壮值','力量壮举','强力跳跃','暗影连击'],
  summary:'强壮值可以花在重击、跳跃和快速工作上，暗影分支可连续命中叠加伤害。',
  configs:['wolfgang'],
  sections:[
   ['重击与跳跃','重击基础花费 50 强壮值，技能可逐档降到 25，成功重击的冷却为 5 秒。空手右键可以选择跳跃，普通冷却为 5 秒，跳跃专精缩短到 2.5 秒。月亮路线的相应技能可在强壮形态下用饥饿补足强壮值差额，每缺 1 点强壮值消耗 0.33 饥饿。'],
   ['快速工作','快速工作的强壮值成本随目标剩余工作量、动作类型和工具效率变化。满足条件可一次完成工作，工具仍会消耗耐久，较硬的目标也可能增加成本。'],
   ['暗影连击','对应技能下，命中或成功触发快速工作可积攒连击。每层为暗影连击倍率增加 0.134，最多 5 层；受击或 6 秒内没有续上连击就会清空。'],
  ],
  sources:[cfg(370),role('wolfgang',12),role('wolfgang',17),role('wolfgang',25),role('wolfgang',364),role('wolfgang',401),role('wolfgang',423),role('wolfgang',482),beta('scripts/components/featsofstrength.lua',15),beta('scripts/components/featsofstrength.lua',41),beta('scripts/components/featsofstrength.lua',89),beta('scripts/components/featsofstrength.lua',136),names(90)],
 },
 {
  id:'wathgrithr',category:'characters',icon:'spear_wathgrithr_lightning',title:'薇格弗德',aliases:['Wigfrid','女武神','女武神重做','奔雷矛','战斗吸血','战斗号子'],
  summary:'默认完整重做包含战斗恢复削弱、格挡调整和装备改动，另可选择仅保留恢复削弱。',
  configs:['wathgrithr_rework_'],
  sections:[
   ['档位与战斗恢复','完整启用和奔雷矛恢复档都应用重做，传统档只应用战斗恢复削弱。削弱将恢复组件的下限、上限和额外恢复系数分别设为 0.1089、0.66、0.165。'],
   ['格挡与战歌袋','完整重做下，盾牌格挡持续 2.5 秒，基础冷却 5 秒；还会移除战歌袋的可燃和传火组件。绝望石圆盾的制作与特殊防护见单独词条。'],
   ['奔雷矛','默认奔雷矛和充能奔雷矛的最大使用次数均为 200。启用奔雷矛恢复档后，充能奔雷矛冲刺命中合格目标可以恢复耐久，并受单次冲刺的修复次数上限限制。'],
  ],
  related:[link('dreadstone-shield','绝望石圆盾')],
  sources:[cfg(359),beta('init/init_tuning.lua',748),role('wathgrithr',4),role('wathgrithr',18),role('wathgrithr',37),role('wathgrithr',91),beta('postinit/prefabs/spear_wathgrithr.lua',107),beta('postinit/prefabs/spear_wathgrithr.lua',163),names(92)],
 },
 {
  id:'rimeweed-bramble-armor',category:'new-items',prefab:'um_armor_bramble_rimeweed',title:'霜冻外壳',aliases:['霜草荆棘甲','霜冻荆棘甲','Rime Bramble'],
  summary:'沃姆伍德用荆棘壳和霜草材料制成的护甲，受击时用带冰冻值的刺击反击。',
  configs:['snowstorms','wormwood_photosynthesis'],
  sections:[
   ['制作','默认开启暴风雪玩法时，沃姆伍德可用荆棘壳 ×1、霜冻藤蔓 ×8、霜花 ×1 制作，无需原型制作站。'],
   ['冰刺反击','受到攻击或成功挡下伤害时，间隔至少 0.3 秒可触发一次冰刺。扩散的冰刺对合格敌人造成 20 伤害，并为可冻结目标增加 1 点冰冻值。护甲沿用荆棘壳的基础耐久与吸收率。'],
   ['沃姆伍德技能','点出荆棘护甲后，沃姆伍德可连续命中 3 次主动释放冰刺。点出荆棘爆发后，受击触发时还会在 0.6 秒后再放一次。'],
  ],
  related:[link('wormwood','沃姆伍德'),link('snowstorms','暴风雪与雪堆')],
  sources:[cfg(463),beta('init/init_recipes/recipes.lua',127),beta('scripts/prefabs/um_armor_bramble_rimeweed.lua',14),beta('scripts/prefabs/um_armor_bramble_rimeweed.lua',31),beta('scripts/prefabs/um_armor_bramble_rimeweed.lua',39),beta('scripts/prefabs/um_armor_bramble_rimeweed.lua',123),beta('scripts/prefabs/um_rimeweed.lua',48),beta('scripts/prefabs/um_rimeweed.lua',70),beta('scripts/prefabs/um_rimeweed.lua',148),cn('init/init_strings/init_descriptions/skilltreestrings.lua',200),names(695),names(701)],
 },
];
