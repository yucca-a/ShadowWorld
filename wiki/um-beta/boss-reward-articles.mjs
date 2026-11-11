const beta = (file, line) => ({ file, line });
const prefab = (id, line) => beta(`scripts/prefabs/${id}.lua`, line);
const name = line => ({ kind: 'cn', file: 'init/init_strings/init_names.lua', line });
const drops = line => beta('postinit/prefabs/vetcurse_drops.lua', line);

export const bossRewardArticles = [
  {
    id: 'charlies-slider', category: 'new-items', prefab: 'the_real_charles_t_horse', title: '滑行手杖',
    aliases: ['破旧玩具', 'Charlie’s Slider', "Charles T. Horse", '暗影薇希', '影薇', '衣橱谜题', '钢琴谜题'],
    summary: '暗影薇希掉落并解锁制作。主动冲刺会推开敌人，薇希推得更远。',
    configs: ['wixie_walter'],
    sections: [
      ['获取与制作', '开启薇希与沃尔特重做后，在新地表找华丽的衣橱、三角钢琴、落地摆钟和破旧玩具。完成谜题可从衣橱召出暗影薇希。击败她会直接掉一把滑行手杖，死亡动画后距她 40 单位内的玩家还会学到配方。材料为噩梦燃料 ×2、步行手杖 ×1、齿轮 ×1。', null, [{ href: 'wixie.html', label: '薇希与专属弹弓' }]],
      ['衣橱谜题解法', '在钢琴依次弹 G、B、D、E、D、E、D、B。拿着破旧玩具从衣橱附近起步，按地图正北、东、南、南、北、西、南、东、北、西的顺序移动。玩具每 0.8 秒检查一次面向，南需要连续判定两次。出现「The path is set...」后，把摆钟的时、分、秒权重分别调到 12、2、7 并启动摆钟，等钟响结束后回到衣橱。'],
      ['冲刺与充能', '装备后朝目标方向使用充能动作，至少需要 20% 能量。每次消耗 20 点，普通物品栏中备用的滑行手杖也各扣 20 点。能量上限 100，释放 2 秒后开始每 0.5 秒恢复 5 点。骑乘时先下坐骑。冲刺本身会扫开附近可推动的敌人，命中按 0 点伤害处理。薇希的击退系数是其他角色的 1.5 倍，被薇希诅咒的目标会被推得更远。普通挥击沿用步行手杖伤害。'],
    ],
    sources: [
      beta('scripts/map/tasks/forest/make_a_pick.lua', 13), beta('scripts/map/tasks/forest/make_a_pick.lua', 20),
      beta('scripts/screens/WixiePiano.lua', 78), beta('scripts/screens/WixiePiano.lua', 104), beta('scripts/screens/WixiePiano.lua', 117),
      prefab('wixie_piano', 35), prefab('wixie_clock', 55), prefab('wixie_wardrobe', 35),
      prefab('charles_t_horse', 165), prefab('charles_t_horse', 207), prefab('shadow_wixie', 212),
      beta('scripts/stategraphs/SGshadow_wixie.lua', 650), beta('scripts/stategraphs/SGshadow_wixie.lua', 659),
      beta('init/init_recipes/recipes_wixie.lua', 7), prefab('charles_t_horse', 257), prefab('charles_t_horse', 347),
      prefab('charles_t_horse', 434), prefab('charles_t_horse', 449), beta('postinit/stategraphs/SGwilson.lua', 166),
      beta('postinit/stategraphs/SGwilson.lua', 190), beta('postinit/stategraphs/SGwilson.lua', 245),
      beta('postinit/stategraphs/SGwilson.lua', 1801), name(565), name(566),
    ],
  },
  {
    id: 'silk-sack', category: 'new-items', prefab: 'silksack', title: '蛛丝背包',
    aliases: ['Silk Sack', '蛛丝捆绑物资', '黑寡妇背包', '蜘蛛丝背包', 'silken_bundle'],
    summary: '黑寡妇的诅咒装备。穿戴时产丝，可以消耗蜘蛛丝把物资压成一包。',
    configs: ['vetcurse'],
    sections: [
      ['获取与装备', '老兵诅咒设为默认或始终开启时，击败黑寡妇固定掉落蛛丝背包，击杀者无需受诅咒。要穿戴使用，角色需处于老兵诅咒状态。背包有 9 格，空包可放入其他容器。', null, [{ href: 'hooded-widow.html#hooded-widow-s4', label: '黑寡妇的战利品' }, { href: 'veterans-curse.html', label: '如何开启老兵诅咒' }]],
      ['产丝与打包', '穿着时每累计 480 秒产 1 个蜘蛛丝，尝试放进第 9 格。卸下会暂停计时。把至少 6 个蜘蛛丝放入最后一格，待打包物品放在前 6 格，再按打包按钮。打包会消耗 6 丝，跳过不可替换物品，成品放到第 7 或 8 格。'],
      ['拆包与保鲜', '蛛丝捆绑物资拆开时会补扣从打包到拆包期间经过的腐烂时间，易腐物的剩余保质时间最低扣到 0。适合整理物资。'],
    ],
    sources: [
      drops(9), drops(31), beta('scripts/tools/um_commonfns.lua', 204), prefab('silksack', 1),
      prefab('silksack', 8), prefab('silksack', 36), prefab('silksack', 55), prefab('silksack', 93),
      beta('init/init_containers.lua', 250), beta('init/init_containers.lua', 294),
      beta('postinit/components/unwrappable.lua', 5), name(237), name(238),
    ],
  },
  {
    id: 'gore-horn-hat', category: 'new-items', prefab: 'gore_horn_hat', title: '犀牛帽',
    aliases: ['Gore Horn Hat', '犀牛冲锋帽', '远古守护者帽'],
    summary: '远古守护者的诅咒装备。持续直跑会加速，蓄满速度时可以撞击敌人。',
    configs: ['vetcurse'],
    sections: [
      ['获取与装备', '老兵诅咒设为默认或始终开启时，击杀远古守护者固定掉落犀牛帽。玩家处于老兵诅咒状态时才能戴稳。它占头部栏，有 2 级暗影位面等级。', null, [{ href: 'ancient-guardian.html#ancient-guardian-s3', label: '远古守护者掉落与打法' }, { href: 'veterans-curse.html', label: '如何开启老兵诅咒' }]],
      ['加速和撞击', '戴上后保持直跑来逐步提速，约到 1.5 倍移速时开启撞击。急转、停下或骑乘会打断这套加速。移动组件也会以当前蓄出的倍率作为速度乘数下限。冲锋会对附近可攻击的敌人造成 200 点基础伤害，撞中后加速归零。'],
      ['能量', '能量上限 200，进入撞击阶段后持续扣能量，撞中额外扣 50 点。退出撞击阶段约 2 秒后开始自充，每 0.5 秒恢复 20 点。'],
    ],
    sources: [
      drops(9), drops(20), beta('scripts/tools/um_commonfns.lua', 204), prefab('gore_horn_hat', 19),
      prefab('gore_horn_hat', 38), prefab('gore_horn_hat', 83), prefab('gore_horn_hat', 97),
      prefab('gore_horn_hat', 124), prefab('gore_horn_hat', 270), prefab('gore_horn_hat', 290),
      prefab('gore_horn_hat', 301), beta('init/init_tuning.lua', 218),
      beta('postinit/components/locomotor.lua', 42), name(325),
    ],
  },
];
