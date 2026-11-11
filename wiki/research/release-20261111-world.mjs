// Changes checked against the published 2.8.15.0.23 source, not Workshop drafts.
export function refreshWorldArticles(articles, notes) {
  const updated = [];
  function revise(id, change, sources = []) {
    const article = articles.find(a => a.id === id);
    if (!article) throw Error('Unknown current-release article: ' + id);
    change(article);
    article.source = [...new Set([...article.source, ...sources])];
    article.auditedVersion = '2.8.15.0.23';
    updated.push(id);
  }
  const P = (title, ...paragraphs) => ({title, paragraphs});
  revise('clock-danger', a => {
    a.sections.push(P('睡眠与相位切换',
      '时钟险境反复切换黄昏和夜晚时，夜间睡具会继续睡眠，不会把黄昏误判为必须起床的时段。进入白天仍按睡具原有规则醒来。',
      '普通遮阳篷仍按白天睡眠规则使用；用瞌睡袋升级为全天可用的帐篷或遮阳篷，不因昼夜切换被强制叫醒。主动起床、饥饿和睡具被破坏仍会结束睡眠。'));
  }, ['content/easy_other/easy_mechanics.lua']);
  revise('upgraded-tents', a => {
    a.sections.push(P('时钟险境下的多人睡眠',
      '未升级的夜间帐篷允许黄昏与夜晚连续休息，来回切换不会把同睡的玩家叫醒，也不会因此额外扣一次醒来耐久。进入白天仍会正常醒来。',
      '升级后的全天睡具可以跨相位继续使用。多人共用时，每位玩家仍独立结算实际醒来的耐久；手动中断、饥饿和锤击等规则不变。'));
  }, ['content/role/clock_peril.lua']);
  revise('world-shadow', a => {
    a.source = a.source.filter(s => !s.startsWith('workshop/'));
    a.sections.find(s => s.title === '变形与读档').paragraphs = [
      '发条生物、高脚鸟、石虾、皮弗娄牛及部分永不妥协蠕虫的分身在读档、收纳放出、自我修复、成长或变种后仍保留影子身份。猪人和猪人守卫的影子会随本体变成疯猪，再随本体复原。',
      '万圣节期间，分身跟随本体已有的木乃伊鱼人、科学怪猪等节日形态，不再独立随机变形并重置分身属性。',
      '分身不能被腐化变成带正常战利品的真身；织影者分身也不能与本体同时施放地下三王的腐化仪式。石虾王、蝙蝠王与巨大蠕虫仍由原本具有资格的本体按原有规则转化。',
      '棱镜普通与辉煌颤栗树的影子死亡、回收时只结束自己的战斗，不会额外生成一棵真树或重复结算本体产物。本体正常结束战斗和还原树木的规则保留。',
    ];
  }, ['content/scripts/shadowhalloween2hm.lua']);
  revise('world-ancient-statues', a => {
    a.sections.find(s => s.title === '强化镐斧与恢复').paragraphs = [
      '带远古强化标记的多用斧镐，可避开玩家开采和完成开采时额外召唤法术、影怪的对应分支，宝石反应仍单独计算。判断的是这次真正执行采矿的工具：放在刮地皮头盔中实际使用也有效，仅把强化工具拿在手中但用另一件工具采矿不会获得该保护。',
      '雕像工作后启动 4,800 秒计时，到期恢复工作量并清除最后一击的强力开采要求。',
    ];
    a.sections.at(-1).links = ['multitool', 'turf-raiser-helm'];
  }, ['content/easy_other/easy_equipments.lua']);
  revise('turf-raiser-helm', a => {
    a.sections.find(s => s.title === '捕捉消耗').paragraphs = [
      '成功捕捉沿用陷阱本来的产物和耐久结算，头盔另消耗 1 次使用次数。青蛙交付蛙腿，鸟和蜘蛛等按原有规则变成可携带的捕获物，不会额外复制一只活体。最后一次陷阱耐久仍会交付产物。物品栏满时停止自动捕捉；玩家随从不会被捕捉。',
      '陷阱已有捕获物时先交付，不会被新的目标覆盖。目标不符合原有捕捉资格或捕捉被拒绝时，不扣头盔与陷阱耐久。',
      '每次成功装恶液消耗 1 个空瓶子和头盔 1 次使用次数；仍执行空瓶原来的使用条件和结果。装瓶失败时不生成产物，也不扣这次材料。',
    ];
    a.sections.push(P('工具本身的能力与代价',
      '头盔使用强化多用斧镐采远古雕像时，保留强化工具避免额外法术和影怪的效果。实际使用暗影斧砍树时，仍承担暗影斧原有的理智代价；用头盔中的镐采矿，不会误扣手持暗影斧的工作理智。',
      '头盔使用亮茄粉碎者耕地时按单个土堆结算，不会再叠加批量耕地造成的额外工具损耗。伍迪普通斧头转成露西的原有行为保留。'));
  }, ['content/tech/ancient_statue.lua']);
  revise('eyeturret', a => {
    a.summary = '可用龙鳞皮和蘑菇皮分别升级的连锁电击炮塔，倒下后休养五天；攻击 Boss 时伤害另乘 0.33。';
    a.sections.find(s => s.title === '攻击与护盾').table.rows.push(
      ['攻击 Boss', '目标带 Boss 标记时，伤害额外乘 0.33；200 点基础伤害对应 66 点，仍受目标防御和其他伤害修正影响。']);
    const upgrades = a.sections.find(s => s.title === '两种升级可以共存');
    if (upgrades) upgrades.title = '龙鳞皮与蘑菇皮升级';
  }, ['content/easy_other/eyeturret2hm.lua']);

  articles.push({
    id:'um-performance-compatibility', title:'永不妥协天气与运行优化', category:'mechanics', tag:'联动兼容',
    summary:'选择暴风雪与龙卷风雨溅的显示密度，了解淬炼补丁的作用和适用条件。',
    keywords:'天气粒子 暴风雪 雪堆 龙卷风 高齿蕨 海妖眼 性能 轻量 均衡',
    auditedVersion:'2.8.15.0.23', configKeys:['um_patch','um_weather_particles2hm'],
    source:['content/modmain.lua','content/modinfo.lua','content/easy_other/um_patch.lua','content/scripts/umperformance2hm.lua','content/scripts/umtornado2hm.lua','content/scripts/umcompatguard2hm.lua','content/scripts/umcompatprofiles2hm.lua'],
    sections:[
      P('启用条件', '同时加载淬炼之季与永不妥协正式版或测试版时，“永不妥协补丁”默认开启。此兼容入口独立于简单模式总开关；天气粒子密度需要该补丁开启，并匹配当前受支持的妥协实现。'),
      {title:'天气粒子密度',table:{headers:['档位','暴风雪粒子系数','龙卷风额外雨溅系数'],rows:[
        ['轻量','2','原密度的 20%'],['均衡（默认）','4','原密度的 40%'],['妥协原密度','10','原密度的 100%'],
      ]},paragraphs:['数字描述额外显示效果的系数，不是天气强度或游戏帧率。暴风雪最终粒子数还会保留固定项，普通降雨也保留基础粒子，因此不能把轻量档理解为总粒子数固定降到 20%。','该选项调整暴风雪粒子和靠近龙卷风时的雨溅，不取消天气遮挡，也不改变龙卷风的移动、吸附、闪电和环境交互。']},
      P('雪堆、植物与海妖', '补丁减少暴风雪和雪堆的重复检查，并修复冬转春时雪堆遗漏正常消失的问题。妥协测试版还优化高齿蕨及海妖眼触手的相关检查，保留采集、再生、阻挡及补生规则。'),
      P('上游更新后的行为', '兼容优化会核对永不妥协当前的对应实现。遇到尚未核对的新实现时，跳过该项优化；不会因为本页仍标为开启就强行覆盖新的上游规则。关闭可选补丁也不等于移除五格锅所必需的料理兼容或已有电气物品的存档恢复。'),
      {title:'其他联动',paragraphs:['角色、装备和容器仍应分别查看对应词条的条件。'],links:['um-compat-equipment','um-item-compatibility','configuration']},
    ],
  });
  updated.push('um-performance-compatibility');
  notes.um_weather_particles2hm = {requires:['um_patch'],conditions:'同时加载永不妥协正式版或测试版，并匹配受支持的天气实现。',paragraphs:[
    '轻量、均衡、妥协原密度分别使用 2、4、10 的暴风雪显示系数；龙卷风的额外雨溅分别取原密度的 20%、40%、100%。均衡为默认档。',
    '仅调整额外天气显示，不改变天气伤害、遮挡、龙卷风行为和普通降雨的基础效果。该入口独立于简单模式总开关。',
  ]};
  notes.um_patch = {requires:[],conditions:'需要同时加载永不妥协正式版或测试版。',paragraphs:[
    '默认开启，提供永不妥协联动调整与天气、雪堆等运行优化，并包含已核对测试版的薇诺娜死亡复活兼容。独立于简单模式总开关。',
    '需要替换上游行为的优化会核对对应实现；未知实现跳过该项。五格锅所必需的动态料理兼容、通用防崩溃及旧物品恢复仍按各自入口处理，不全部受这个可选开关控制。',
  ]};
  return updated;
}
