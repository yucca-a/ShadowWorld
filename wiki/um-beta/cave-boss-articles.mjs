const beta = (file, line) => ({ file, line });
const cfg = line => beta('modinfo.lua', line);
const health = line => beta('init/init_bosshealth.lua', line);
const prefab = (name, line) => beta(`postinit/prefabs/${name}.lua`, line);
const names = line => ({ kind: 'cn', file: 'init/init_strings/init_names.lua', line });

export const caveBossArticles = [
  {
    id: 'ancient-guardian', category: 'creatures', icon: 'minotaur', title: '远古守护者',
    aliases: ['远古犀牛', '犀牛', 'Ancient Guardian', 'Minotaur', '大号华丽箱子', '守护者之角'],
    summary: '遗迹迷宫末端的首领。重做加入连跳、暗影黏液和返场，华丽箱可开出满附魔耐久的二级武器。',
    configs: ['rework_minotaur', 'minotaur_health_', 'vetcurse'],
    sections: [
      ['在哪里遇到', '在洞穴远古遗迹的迷宫末端找守护者的柱阵。默认 10,000 生命、普通攻击 100 伤害，生命设置默认 ×1。重做默认开启。守护者离出生点超过 32 距离后会尝试起跳返场，落地仍会震击。'],
      ['打法', '冲锋时用侧跑绕柱，看到它被柱子绊停再回身输出，注意撞击后周围的落石。生命低于 60% 后，蓄力跳可能接连续跳，低于 30% 后连段更长，等它真正落地停住再贴近。它还会喷出多轮黏液，落点附近会受到 50 点伤害并扣 5 理智，部分黏液会生成大暗影触手。'],
      ['掉落与二级附魔装备', '击败后会掉守护者之角、肉、支柱脚手架蓝图、雕塑草图和测试版追加的骷髅箱蓝图，随后出现大号华丽箱子。老兵诅咒房间设置为默认或始终开启时，首领额外掉犀牛帽。世界尚未记录找到远古钥匙时，箱内会放入一把。其余战利品随机抽取，包括铥矿、齿轮、普通宝石与遗迹装备。铥矿棒、懒人魔杖或唤星者魔杖若抽中，会带一项随机二级附魔，附魔耐久全满。提高首领生命档会增加箱内额外战利品的机会，远古钥匙排除在复制范围外。', null, [{ href: 'gemology.html#gemology-s10', label: '回到宝石学的高品质来源' }, { href: 'gemology.html#gemology-s6', label: '查二级附魔效果' }, { href: 'ancient-fuelweaver.html', label: '远古钥匙的下一站' }, { href: 'gore-horn-hat.html', label: '犀牛帽的冲锋与充能' }]],
    ],
    sources: [cfg(959), cfg(999), health(2), health(227), health(263), beta('init/init_postinit.lua', 422), prefab('minotaur', 15), prefab('minotaur', 118), prefab('minotaur_drops', 6), prefab('vetcurse_drops', 20), beta('postinit/stategraphs/SGminotaur.lua', 141), beta('postinit/stategraphs/SGminotaur.lua', 213), beta('scripts/prefabs/shadow_goo.lua', 73), beta('scripts/prefabs/shadow_goo.lua', 274), beta('init/init_gemology/misc.lua', 105), beta('init/init_gemology/misc.lua', 118), beta('init/init_gemology/misc.lua', 152), names(324), names(336)],
  },
  {
    id: 'ancient-fuelweaver', category: 'creatures', icon: 'stalker_atrium', title: '远古织影者',
    aliases: ['织影者', '远古骨架', '骨架', 'Ancient Fuelweaver', '暗影香炉'],
    summary: '在洞穴中庭复活。血量档同时影响首领、第二阶段血线和适用的额外掉落。',
    configs: ['stalker_atrium_health_'],
    sections: [
      ['在中庭召唤', '带远古钥匙去洞穴中庭并激活远古大门。夜间在门附近用化石碎片搭出正确形态的骸骨，再交给它暗影心房。暗影心房可从三级暗影棋子取得。', null, [{ href: 'ancient-guardian.html#ancient-guardian-s3', label: '远古钥匙来源' }, { href: 'shadow-pieces.html#shadow-pieces-s3', label: '暗影心房来源' }]],
      ['打法与血线', '默认最大生命 16,000，生命降到 10,000 时进入第二阶段。两者随同一个房间倍率缩放。被骨牢困住时优先脱离，尽快清掉朝首领爬的暗影小怪，它们会被吞食回血。看见无敌护盾时先处理维持护盾的暗影之手，再继续打本体。'],
      ['掉落', '正常战胜会掉暗影香炉、骨头盔甲、骨头头盔、远古织影者雕塑草图与噩梦燃料。高生命档会按设置额外结算适用掉落，通用复制规则排除这类骨架的化石碎片和暗影心房。'],
    ],
    sources: [cfg(985), health(3), health(60), health(67), health(98), health(115), health(155), prefab('stalker', 4)],
  },
  {
    id: 'toadstool', category: 'creatures', icon: 'toadstool', title: '毒菌蟾蜍与悲惨的毒菌蟾蜍',
    aliases: ['蟾蜍', '蛤蟆', '悲惨毒菌蟾蜍', '蓝蟾蜍', 'Toadstool', 'Misery Toadstool', '蘑菇皮'],
    summary: '新洞穴的竞技场移到红、绿、蓝蘑菇林。两种形态各有生命设置，战斗中也会掉蘑菇皮。',
    configs: ['worldgenmastertoggle', 'toadstool_health_', 'toadstool_dark_health_'],
    sections: [
      ['去蘑菇林找菌帽', '启用世界生成改动的新洞穴会把三个竞技场移到红、绿、蓝蘑菇林的对应房间。用斧头砍菌帽开战。要挑战悲惨形态，把中毒金丝雀带到菌帽附近，让它在洞穴里爆开使菌帽变质，再砍变色的菌帽。'],
      ['分阶段处理蘑菇树', '普通形态默认 52,500 生命，悲惨形态默认 99,999。两者在 70%、40% 血线进入新阶段，悲惨形态在 20% 时还有一阶段。它召出增益蘑菇树后先用斧头清树以降低减伤，看到脚边孢子炸弹或地面毒雾就移到空地。'],
      ['掉落', '普通形态死亡必掉 1 张蘑菇皮，悲惨形态必掉 2 张。两者另有雕塑草图、肉类和蘑菇。活着切入新阶段时也会抛出蘑菇皮，普通逐阶段可再拿 2 张、悲惨可再拿 3 张，单次伤害跨过血线时基础阶段掉落可能减少。测试版在较高生命档的阶段咆哮上也会追加掷骰。', null, [{ href: 'sporepack.html', label: '蘑菇皮可制作蟾蜍背包' }]],
    ],
    sources: [cfg(167), cfg(1223), cfg(1307), beta('modworldgenmain.lua', 31), beta('scripts/map/tasks/caves/mushroom_tasks.lua', 5), health(20), health(436), health(452)],
  },
  {
    id: 'nightmare-werepig', category: 'creatures', icon: 'daywalker', title: '梦魇疯猪与拾荒疯猪',
    aliases: ['梦魇疯猪', '拾荒疯猪', '疯猪', 'Nightmare Werepig', 'Scrappy Werepig', '开裂的柱子', '简陋的杠杆', '破旧的杠杆'],
    summary: '洞穴疯猪与地表拾荒变体共用生命设置。拾荒疯猪有改写的蓝图和每个世界只出一次的两种杠杆。',
    configs: ['daywalker_health_'],
    sections: [
      ['解救与再战', '在洞穴找到被柱子锁住的梦魇疯猪。用镐挖掉锁链连着的开裂柱子来释放它。两种疯猪默认都是 10,000 生命。测试版将疯猪战败后的基础再生等待设为 5 天，游戏的世界生成或重生档位也会影响等待时间。地表后续战在大型废料堆进行，对手会换成拾荒疯猪。'],
      ['打法', '洞穴战留意冲撞和连续近身攻击，冲撞开始后向侧面闪出，等连招做完再回头。拾荒疯猪会从废料堆翻武器，能挥击、冲撞或开炮，武器各有 3 次使用。测试版让大型废料堆可供应炮，看到它举炮就离开瞄准线。'],
      ['柱子与掉落', '洞穴的开裂柱子基础掉 3 块绝望石，另有 50% 机会多出第 4 块。梦魇疯猪还会掉纯粹恐惧、绝望石装备及墙的蓝图和雕塑草图。拾荒疯猪基础掉 5 个废料，50% 机会多出第 6 个，另有 50% 机会掉齿轮。固定蓝图包括 W.A.R.B.I.S. 盔甲、头戴齿轮、自动修理机、弹性空间制造器和船瓶，另有雕塑草图。简陋的杠杆、破旧的杠杆各自按世界记录，掉过的种类后续击败时不会再出。'],
    ],
    sources: [cfg(1265), health(18), health(109), health(581), health(626), beta('init/init_tuning.lua', 740), prefab('daywalker', 15), prefab('daywalker', 43), prefab('daywalker', 64), prefab('daywalker', 78), prefab('daywalker', 127), prefab('daywalker', 139), names(713), names(722)],
  },
  {
    id: 'celestial-champion', category: 'creatures', icon: 'alterguardian_phase1', title: '天体英雄',
    aliases: ['天体', '天体三阶段', 'Celestial Champion', '约束静电蓝图', '启迪之冠'],
    summary: '月岛召唤的三阶段首领。测试版给第三阶段加了约束静电蓝图，三个阶段共用一个血量档。',
    configs: ['alterguardian_health_'],
    sections: [
      ['在哪里召唤', '在月岛组装天体祭坛、天体贡品与天体圣殿，让三座装置形成神秘能量。推进瓦格斯塔夫的月亮风暴流程，并在神秘能量的位置建成月亮虹吸器。完工后仪器会自行开始召唤，留出空间应对首领坠落。'],
      ['打法与生命', '默认第一阶段 10,000 生命，第二阶段入场 13,000、上限 20,000，第三阶段入场 14,000、上限 22,500。三段的入场值和上限按同一档位缩放。第一阶段躲滚动和落地冲击，第二阶段从突刺和旋转路线侧面拉开，第三阶段离开启迪陷阱及激光的覆盖区，等连续攻击结束再靠近。'],
      ['奖励', '第一阶段掉月岩，第二阶段掉月岩与月亮碎片。第三阶段掉启迪碎片、月亮碎片、雕塑草图和测试版追加的约束静电蓝图。用镐开采被击败后的残骸可拿启迪之冠，抬高生命档也会作用于残骸掉落。'],
    ],
    sources: [cfg(1069), health(38), health(572), prefab('alterguardian', 5), beta('init/init_postinit.lua', 188)],
  },
  {
    id: 'shadow-pieces', category: 'creatures', icon: 'shadow_knight', title: '暗影棋子',
    aliases: ['暗影三基佬', '三基佬', '暗影骑士', '暗影主教', '暗影战车', 'Shadow Pieces', '暗影王冠', '暗影心房'],
    summary: '地表新月唤醒。三种棋子的各级生命提高，重做的主教会连续传送冲锋，三级增加暗影王冠。',
    configs: ['changed_shadow_pieces', 'shadowpieces_health_'],
    sections: [
      ['新月启动与等级', '在地表新月用锤敲对应的可疑大理石雕像或摆出的棋子雕塑。棋子倒下后，附近仍活着的棋子会升级。默认一级／二级／三级生命分别为暗影骑士 900／2,700／8,100，暗影主教 800／2,500／7,500，暗影战车 1,000／4,000／10,000。'],
      ['主教重做打法', '默认开启重做。暗影主教在攻击中短暂无敌，会尝试传送到目标附近，然后朝选定方向冲锋。一级到三级分别连续 3／4／5 轮，攻击伤害为 15／25／35。看见转向蓄势就往侧面横移，等整轮结束再打。想缩短高等级主教阶段，可以优先解决它。'],
      ['暗影心房与王冠', '三级棋子击败后掉暗影心房、暗夜剑和暗夜甲，开启重做时加掉暗影王冠。二级开始就有额外噩梦燃料。提高房间里的棋子生命档也会为适用战利品增加额外掉落。', null, [{ href: 'ancient-fuelweaver.html#ancient-fuelweaver-s1', label: '用暗影心房召唤远古织影者' }]],
    ],
    sources: [cfg(967), cfg(1293), health(68), health(351), health(560), beta('init/init_postinit.lua', 540), beta('init/init_tuning.lua', 686), prefab('shadowchesspieces', 15), beta('postinit/stategraphs/SGshadow_bishop.lua', 45), beta('postinit/stategraphs/SGshadow_bishop.lua', 61), beta('postinit/stategraphs/SGshadow_bishop.lua', 139), beta('postinit/stategraphs/SGshadow_bishop.lua', 242), names(212)],
  },
  {
    id: 'great-depths-worm', category: 'creatures', icon: 'worm_boss', title: '巨大洞穴蠕虫',
    aliases: ['洞穴巨虫', '巨型深渊蠕虫', '蠕虫 Boss', 'Great Depths Worm'],
    summary: '洞穴蠕虫袭击的首领变体。提高生命档也会增加普通巨虫的头部与身体战利品。',
    configs: ['worm_boss_health_'],
    sections: [
      ['在哪里遇到', '洞穴蠕虫波次有机会升级为巨虫波次。普通进度下，洞穴计日超过 25 后，未升级的波次会逐次为后续升级积累概率。世界的蠕虫设置和对应仪式进度也会影响波次。普通巨虫默认 5,000 生命。'],
      ['打法', '看到地面成串翻动就离开行进线路，离虫头太近会被吞。等虫头或身体露出地面再打，并躲开身体尖刺。它吞下点燃的爆炸物后，咀嚼时触发爆炸会打断动作，爆炸伤害乘 1.5。'],
      ['掉落', '普通巨虫头部必掉 3 块怪物肉、1 个发光浆果与雕塑草图，另有两次 66% 的怪物肉判定。身体段还会抽骨片、石料、各色普通宝石等。高生命档会增加头部适用掉落和身体弹出物，身体追加逻辑排除幸运金块。'],
    ],
    sources: [cfg(1167), health(29), health(115), health(155), health(402), health(433)],
  },
];
