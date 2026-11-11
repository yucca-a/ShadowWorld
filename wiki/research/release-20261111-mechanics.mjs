// Player-facing amendments checked against the published 2.8.15.0.23 source.
// Keep the earlier audits as historical inputs; replace affected sections here.
import { articles as initial } from '../content.mjs';
import { patches as itemPatches } from './item-audit-general.mjs';
import { patches as foodPatches } from './life-audit-food.mjs';
import { patches as buildingPatches } from './entity-audit-buildings.mjs';

const version = '2.8.15.0.23';
const P = (title, ...paragraphs) => ({ title, paragraphs });
const T = (title, headers, rows) => ({ title, table: { headers, rows } });
const R = (...links) => ({ title: '相关词条', links });
const source = (...files) => files.map(file => 'content/' + file);
const clone = (list, id) => structuredClone(list.find(article => article.id === id));
const amend = (article, values) => Object.assign(article, values, { auditedVersion: version });
const hard = ['enable hard mode', 'food_change'];

const gettingStarted = clone(initial, 'getting-started');
gettingStarted.sections[1].list = [
  '订阅淬炼之季的创意工坊条目，在房间模组设置中启用；地面、洞穴和额外分片应同时更新。',
  '简单模式与困难模式可以同时开启。先查看各分类总开关，再选择子项。贝爷求生、德爷生存另有独立总开关，默认均关闭。',
  '穿越机制默认使用“为爽原版”。升级前的旧配置统一迁移到原版，之后可以手动选择咸鱼版或暗影枢纽；各分片档位应保持一致。',
  '旧默认战斗险境和巨兽装甲会升级为锋芒渐敛、遇强则坚。要沿用传统1档，请在新菜单中明确选择；巨兽摧毁旧100%配置按80%生效。',
];
gettingStarted.sections[gettingStarted.sections.length - 1] = P('资料覆盖范围',
  '本轮资料基线为淬炼之季 2.8.15.0.23。优先查看当前配置、暗影空间、烹饪及角色词条，旧版本更新日志保留当时的规则。',
  '贝爷求生、德爷生存已经加入，但默认关闭。远古宝珠仍只有设计草案，不属于当前已发布玩法。');
gettingStarted.sections.push(R('survival-modes', 'difficulty-rating', 'world-exchange'));

const configuration = clone(initial, 'configuration');
configuration.source = source('modinfo.lua', 'scripts/combatconfig2hm.lua', 'scripts/exchangemode2hm.lua', 'scripts/difficultyrating2hm.lua', 'modservercreationmain.lua');
configuration.configKeys = ['enable easy mode', 'enable hard mode', 'World Exchange', 'Container Sort', 'combat', 'epic_armor_5', 'epic_ruin', 'difficulty_rating', '贝爷求生', '德爷生存'];
configuration.sections = [
  P('先检查上级开关', '多数子选项需要其所属模式、分类总开关一起开启。贝爷求生与德爷生存独立于简单／困难模式，它们的子项只在各自总开关开启后生效。'),
  T('当前常用设置', ['选项', '默认', '生效条件与说明'], [
    ['战斗险境', '锋芒渐敛', '困难模式＋角色改动；高倍率逐渐递减'],
    ['巨兽装甲', '遇强则坚', '困难模式＋怪物改动；按近期实际掉血积累动态减伤'],
    ['穿越机制', '为爽原版', '容器按钮／快捷入口启用后使用；另可选咸鱼版、暗影枢纽或关闭空间切换'],
    ['巨兽摧毁', '80%', '旧100%值自动按80%生效；新菜单可明确选回100%'],
    ['贝爷求生／德爷生存', '均关闭', '独立的可选生存挑战，开启后再检查子项'],
    ['难度评级', '开启', '在聊天或控制台输入 /nd，只向自己显示当前配置评级'],
    ['怪物角色夜视', '开启', '独立开关，不依赖简单／困难模式；不额外授予查理免疫'],
    ['永不妥协补丁', '开启', '需加载永不妥协；五格锅与动态料理同时开启时保留必需适配'],
  ]),
  P('旧档设置迁移', '旧穿越值统一转为“为爽原版”，旧暗影枢纽物品先恢复再送回所属分片原生空间。之后明确选择的新档位会保留。各机制各存一套物品，切换档位不会把三套库存合并。', '战斗险境与巨兽装甲的旧默认1／true值分别迁移为锋芒渐敛、遇强则坚；新的“传统1档”选项会保留。传统2、3档等明确选择不被统一改写。'),
  P('本机开房的通信频率', '在游戏开房界面启动且启用了淬炼之季的世界时，本次启动使用60 tick通信频率。它不等于游戏帧率，也不会替独立部署的专用服务器改写启动参数。'),
  R('combat', 'armor', 'world-exchange', 'survival-modes', 'difficulty-rating', 'fuel-cooking'),
];

const faq = clone(initial, 'faq');
faq.source = source('modinfo.lua', 'scripts/exchangemode2hm.lua', 'easy_other/shadowvault.lua', 'scripts/difficultyrating2hm.lua');
faq.sections[1] = { ...P('暗影空间提示等待，是需要其他玩家同意吗？',
  '不需要其他玩家投票。先确认所有分片已更新且穿越档位一致；首次升级旧枢纽时会恢复旧空间并保存迁移结果，完成前相关入口暂时不能打开。',
  '暗影枢纽中其他分片离线、主世界不可用或物品暂时不能安全转移，也可能需要等待。不要把等待提示理解为可以删除旧记录或清空容器。'), links: ['world-exchange', 'shadow-nexus'] };
faq.sections.push({ ...P('我开了贝爷／德爷子项，为什么没变化？', '这两套模式各有默认关闭的总开关。只打开子项不会启用整套模式，简单模式或困难模式总开关也不能代替它们。'), links: ['survival-modes'] });
faq.sections.push({ ...P('怎样查询当前房间难度？', '启用“难度评级”后，在聊天或控制台输入 /nd。结果只给自己，比较的是本模组实际生效设置与默认设置，不代表玩家水平。'), links: ['difficulty-rating'] });

const combat = amend(clone(initial, 'combat'), {
  source: source('modmain.lua', 'modinfo.lua', 'role/combat.lua', 'scripts/progressivecombat2hm.lua', 'scripts/combatconfig2hm.lua'),
  configKeys: ['enable hard mode', 'role_nerf', 'combat'],
  summary: '高额增伤逐渐递减；普通伤害和位面伤害分别计算，普通角色的普通增伤逐渐趋近4倍。',
  sections: [
    P('生效条件与旧档', '需要困难模式、角色改动与战斗险境。默认“锋芒渐敛”；旧默认1档自动迁移，新菜单中的“传统1档”可明确保留原乘算规则。关闭及传统2、3档仍可选择。'),
    T('正向增伤的递减区间', ['伤害来源', '从此倍率开始递减', '逐渐趋近'], [
      ['普通角色的普通伤害', '2.5倍', '4倍'], ['沃尔夫冈的普通伤害', '3.5倍', '5倍'],
      ['沃托姆的普通伤害', '4倍', '5.5倍'], ['骑乘时的普通伤害', '2.5倍', '4倍'], ['位面等特殊伤害', '2倍', '3.5倍'],
    ]),
    P('如何理解倍率', '这不是武器面板伤害上限。正向增伤先合并，超过阈值的部分逐渐压缩；减伤方向的倍率仍照常参与。以普通角色为例，原本10倍的适用普通增伤会变为3.75倍。', '如果正向倍率为m、开始递减的阈值为C，超过阈值后按 C＋1.5×(m−C)÷(1.5＋m−C) 计算。未超过阈值的正向倍率不受压缩。'),
    P('普通与位面分开', '普通伤害的增益不会串入位面伤害。武器专属倍率不会套到角色自带的位面伤害，目标克制归入对应伤害项。固定加伤保留原有处理，不应把全部数字乘一个统一倍率。'),
    P('传统档位与显示', '传统1档使用原有乘算；传统2档对大倍率采用加算；传统3档保留2.5倍上限与溢出补偿。锋芒渐敛不提供额外减伤或移速补偿。检查拳击袋可以切换伤害信息显示，显示开关不改变算法。'),
    { ...P('与巨兽装甲共同结算', '锋芒渐敛只处理攻击端。命中目标后，还会经过目标防御、单次掉血限制与动态巨兽装甲。'), links: ['armor'] },
  ],
});

const armor = amend(clone(initial, 'armor'), {
  source: source('modmain.lua', 'modinfo.lua', 'epic/dynamic_armor.lua', 'scripts/components/dynamicarmor2hm.lua', 'scripts/prefabs/dynamicarmor_indicator2hm.lua', 'scripts/combatconfig2hm.lua'),
  configKeys: ['enable hard mode', 'monster_change', 'epic_armor_5', 'extra_change', 'boss_health'],
  summary: '近期实际掉血超过最大生命20%后逐渐减伤；停手1秒后，压力每秒至少消退400点生命对应的额度。',
  sections: [
    P('生效条件', '需要困难模式、怪物改动与巨兽装甲“遇强则坚”。旧默认1档迁移到此机制；禁用和传统1～5档仍可在新菜单中明确选择。'),
    T('单次伤害与动态压力', ['项目', '规则'], [
      ['单次伤害', '现有防御结算后，最多造成目标最大生命10%的掉血；更低的既有上限仍有效'],
      ['压力累积', '按最终实际掉血累积；所有攻击者和伤害来源共用同一份压力'],
      ['开始动态减伤', '压力达到最大生命20%后逐渐增加减伤'],
      ['高压力区间', '20%～30%之间连续增加减伤，接近30%时接近100%'],
    ]),
    P('连续输出与停手恢复', '连续受伤时，压力仍以“最大生命×2%÷√额外血量倍率”每秒消退。每次受伤后1秒内，只使用这个比例衰减；停手满1秒后，每秒衰减改为该值与400点生命额度中的较大者。不是停手后才开始衰减，也不是每秒给Boss回复400点生命。', '额外血量倍率按本模组生效的Boss血量配置及明确提供的外部倍率计算，不会简单把Boss最终生命当成倍率。多人不另增伤害额度。'),
    T('不计400点保底时的衰减示例', ['额外血量倍率', '每秒消退占最大生命'], [['1倍', '2%'], ['4倍', '1%'], ['9倍', '约0.667%']]),
    P('可见提示与存档', '动态减伤生效时会出现随减伤强弱变化的淡红微光。压力支持保存读档及适配Boss的阶段继承；离线经过的现实时间不作为游戏内衰减时间。'),
    P('适用范围与火药', '作用于符合条件的巨兽，排除蚁狮、果蝇王和暗影分身。蚁狮沙尘暴减伤由它自己的技能控制。火药保留原版爆炸抗性，再受单次上限与动态装甲约束；没有额外爆炸记忆、定时无敌、回血或陨石。', '直接设定生命、强制击杀和脚本阶段变化不等于普通攻击掉血。'),
    R('combat', 'configuration'),
  ],
});

const worldExchange = amend(clone(initial, 'world-exchange'), {
  title: '穿越机制与暗影空间',
  summary: '为爽原版、咸鱼版和暗影枢纽三种机制各自保存库存；旧设置默认迁移到为爽原版。',
  keywords: '穿越 末影箱 暗影空间 钓具 原版 咸鱼 暗影枢纽 地面 洞穴 多分片 旧档 迁移',
  configKeys: ['Container Sort', 'Items collect', 'World Exchange'],
  source: source('modinfo.lua', 'modmain.lua', 'easy_other/exchangemodes2hm.lua', 'easy_other/exchangeclassic2hm.lua', 'easy_other/shadowbank2hm.lua', 'easy_other/shadowvault.lua', 'scripts/exchangemode2hm.lua', 'scripts/components/exchangevariants2hm.lua', 'scripts/exchangeoriginalmigration2hm.lua'),
  sections: [
    T('三种机制与关闭选项', ['档位', '玩法与范围'], [
      ['为爽原版（默认）', '沿用整箱交换：使用容器穿越按钮，和其他在线分片对应空间交换整箱物品；保留辅助暂停按钮'],
      ['咸鱼版', '暗影／钓具各有两套空间，通过相应入口与按钮访问；副世界使用远端存取，不把远端界面当成本地实物箱'],
      ['暗影枢纽', '主世界托管各层空间，暗影及钓具支持跨层同时存取；用穿越按钮切换不同层的空间'],
      ['关闭空间切换', '关闭跨空间切换，整理和收集由各自设置管理'],
    ]),
    P('使用前检查', '容器按钮或快捷收集入口需启用；要使用容器上的穿越按钮，请开启“容器整理收集按钮”。地面、洞穴与额外分片应同时更新，并选择一致的穿越档位。', '为爽原版只会寻找已连接、可用的其他分片与对应空间。多个目标分片存在时轮流选择。它沿用原版交换方式，不能套用暗影枢纽的离线访问与恢复规则。'),
    P('旧世界升级', '升级前的旧配置值，不论此前为关闭、传统或世界协同，均按“为爽原版”生效。旧暗影枢纽先恢复物品记录，再将物品送回其所属分片的原生空间；世界保存完成前相关入口暂时等待。', '之后在新菜单明确选择咸鱼版或暗影枢纽，会保留选择，不会每次启动都重新改回原版。恢复需要的分片、原模组或物品归属不完整时，不会靠删物品或清记录强行解锁。'),
    P('切换档位后的物品在哪里', '三种机制分别保留空间库存。由原版切到枢纽或咸鱼版，看到不同库存不代表原箱物品被清空；切回原档位可继续使用该档库存。旧枢纽自动回送只属于首次旧档迁移，不会把手动切换后的三套库存反复合并。'),
    P('版本说明', '早期日志中的“世界协同默认”“共同存档恢复”描述的是旧版本。当前默认和具体操作以本页为准，使用暗影枢纽时再查看其空间与恢复限制。'),
    R('shadow-nexus', 'containers', 'faq'),
  ],
});

const shadowNexus = {
  id: 'shadow-nexus', new: true, title: '暗影枢纽与共享空间', category: 'mechanics', tag: '容器',
  summary: '选择暗影枢纽后，主世界托管各层空间；暗影和钓具能跨层同时存取。',
  keywords: '暗影枢纽 暗影箱 钓具 共享空间 跨层 同时 离线 私人容器 牛铃',
  configKeys: ['Container Sort', 'Items collect', 'World Exchange'],
  source: source('easy_other/shadowvault.lua', 'easy_other/shadowvaultshared.lua', 'easy_other/shadowvaultplayer.lua', 'scripts/shadowvaultconfig2hm.lua', 'scripts/shadowvaultnative2hm.lua', 'scripts/shadowvaultshared2hm.lua', 'scripts/components/shadowvault2hm.lua', 'scripts/shadowvaultitems2hm.lua'),
  sections: [
    P('打开和切换', '在“穿越机制”明确选择“暗影枢纽”。正常打开暗影入口或钓具入口，使用容器穿越按钮切换所属分片的空间。暗影与钓具是不同容器家族，不会混成同一个物品栏。'),
    P('跨层同时使用', '暗影空间、钓具空间允许不同层玩家同时打开并存取同一空间。各人的界面随物品变化刷新；同一件物品只能由一次操作取得，冲突时应等待刷新后重试。', '动态扩容的第三方共享容器保留其原生容量与升级管理，按整页交接，不能由此推断也支持与暗影／钓具完全相同的同时存取。'),
    P('主世界与离线分片', '空间由主世界托管，因此主世界必须可用。已经托管到主世界的暗影或钓具空间，可在其所属层暂时离线时访问；尚未完成接入、正在交接或等待旧档恢复的空间需先完成相应步骤。第三方动态容器按整页交接，若页面仍由其他层持有、尚未归还，而该层离线，可能需要等待该层恢复。'),
    P('无法转移的物品与私人容器', '私人离线掉落容器不作为公共空间接管。有宠物关联的牛铃、受保护或暂时不能安全转移的模组物品，可能让相应原箱保留在本地使用；关闭容器并移开阻塞物后会自动重试接入。不要为了接入枢纽而销毁物品。'),
    P('保存、重启与回档', '使用游戏正常保存、关服和回档流程。回档或重启后，入口会重新对应有效容器；空间暂时锁定时等待恢复，不要把空白或失效入口当成可以重建库存的依据。枢纽保存机制不代表任意第三方物品和任意模组组合都已完成验收。'),
    R('world-exchange', 'containers', 'tackle-station', 'possessed-magician-hat'),
  ], auditedVersion: version,
};

const containers = clone(itemPatches, 'containers');
containers.source.push(...source('easy_other/exchangemodes2hm.lua', 'scripts/exchangemode2hm.lua'));
containers.sections[containers.sections.length - 1] = { ...P('穿越与空间切换', '“穿越机制”默认是为爽原版，可手选咸鱼版或暗影枢纽，也可关闭空间切换。整理、收集、锁定由各自按钮档位决定，不能把关闭空间切换等同于关闭全部整理功能。', '各机制独立保留库存，旧配置统一迁移为爽原版；地面和洞穴须同时更新且档位一致。'), links: ['world-exchange', 'shadow-nexus'] };

const fuelCooking = clone(foodPatches, 'fuel-cooking');
fuelCooking.source.push(...source('common/food_util.lua', 'scripts/fiveslotcookers2hm.lua', 'scripts/cookpreviewlayout2hm.lua', 'easy_other/um_food_stats.lua', 'easy_other/um_patch.lua'));
fuelCooking.sections[0].table.rows[2][1] = '包含−2，并加入五格锅、鲜度与配方规则；支持永不妥协正式／测试版';
fuelCooking.sections.find(s => s.title === '相关配置').paragraphs = ['需要困难模式、食物改动总开关与“烹饪改动”。−2、−3均削减食材度；只有−3扩为五格并启用额外鲜度／配方规则。五格不再因加载永不妥协测试版而整体关闭。'];
fuelCooking.sections.splice(-1, 0,
  P('永不妥协与动态料理', '五格锅兼容永不妥协正式版和测试版。测试版另开启其动态料理属性时，五份食材均参与配方与动态三维计算，保存、收取及料理自身的产量规则保留。五格锅与动态料理同时开启时，即使关闭可选“永不妥协补丁”，防止第五份食材出错的必要适配仍会启用。'),
  P('红晶锅与月炆宝炊', '能力勋章红晶锅使用五个食材格，保留自身配方和入锅限制，并接入燃料与附近龙鳞火炉供火。棱镜月炆宝炊的每行变为五份食材加一个产物格；四行版同样按行计算，其他行与已做好的料理不混入本行配方。', '调味仍使用料理与香料的原有组合，不要求凑满五份。升级、收起／展开和扩容保留原输入、产物与燃料；燃料不足时补充后继续。'),
  P('智能锅与火炉例外', '独立智能锅和群鸟绘卷内置版按当前锅具与完整五份食材显示预告；重新打开、移动食材与切换月炆行会刷新。预告仍是料理候选，应以实际配方条件为准。', '龙鳞火炉始终是四份食材加红宝石专用槽。五格档位下，火炉读取未扣减0.25的食材度，不套用五格锅的填充物限制与冷汤／炖兔子额外冰度规则；做出的食物仍受50%～70%鲜度饥饿折扣影响。'),
);

const foodValues = clone(foodPatches, 'food-values');
foodValues.sections.find(s => s.title === '鲜度与五格锅').paragraphs = ['上表的鲜度宽免只在食物改动与简单模式同时开启时加入。若“烹饪改动”选择−3，后加载的五格规则会将一般角色陈旧／变质饥饿倍率恢复为0.667／0.5，薇克巴顿恢复为0.333／0.167，并加入50%～70%鲜度的正饥饿折扣。该规则同样可与永不妥协测试版一起生效。'];

const furnace = clone(buildingPatches, 'dragonfly-furnace');
furnace.source.push(...source('common/food_util.lua', 'easy_other/um_food_stats.lua'));
furnace.sections = furnace.sections.filter(s => s.title !== '兼容四格火炉');
furnace.sections.find(s => s.title === '批量烹饪').paragraphs[0] = '火炉有一个红宝石专用槽和四个食材槽，搭配永不妥协正式版／测试版也使用此规则。四个食材槽都放入可入锅食材后才能开始，红宝石不算第五份食材。';
furnace.sections.find(s => s.title === '批量调味').paragraphs[0] = '同时开启“便携烹饪锅批量调味”后，便携调味站接受整组料理和调料，按两者较少的数量批量消耗、产出。调味时间不按份数延长。';
furnace.sections.splice(-1, 0, P('五格档位与妥协兼容', '即使“烹饪改动”选−3，火炉仍只读取四份食材。它免于食材度减0.25及五格锅具额外配方限制，但成品不免于50%～70%鲜度饥饿折扣。搭配妥协动态料理时，四份食材全部参与动态三维，批次堆叠数量不会放大一锅的食材度。', '智能锅预告也按四份火炉食材与火炉实际配方刷新，红宝石专用格不参与预告。'));

const survival = {
  id: 'survival-modes', new: true, title: '贝爷求生与德爷生存', category: 'mechanics', tag: '可选挑战',
  summary: '两套独立的生存挑战，默认关闭；子项只有在各自总开关开启后才生效。',
  keywords: '贝爷 德爷 求生 生存 困难 读书 制作 堆叠 冻结 下雨 禁火',
  configKeys: ['贝爷求生', '种地种树需要书', '做饭需要书', '材料制造翻倍', '低san采集失败', '捡东西变慢', '德爷生存', '料理禁止堆叠', '护甲失效', '难以冻结', '下雨禁火', '火把传热', '空挥武器'],
  source: source('modinfo.lua', 'modmain.lua', 'ray/beye.lua', 'ray/beye_actions.lua', 'ray/beye_crafting.lua', 'ray/deyeshengcun.lua'),
  sections: [
    P('两个默认关闭的总开关', '“贝爷求生”和“德爷生存”独立于简单／困难模式，可以分别启用。子项显示开启而总开关关闭时，该项不会生效。开启总开关会带来下列整组规则，不只是给原困难模式加一个等级。'),
    P('贝爷求生的基础规则', '制作变慢并显示制作进度，新制物品可能有随机初始耐久，制作熟练度会影响后续结果；部分资源掉落减半，制作不再永久解锁科技配方，猪王不再正常兑换金块但保留图纸兑换。另有磨刀、全员读书与黑暗免疫等配套规则。', '蓝图学习仍可正常解锁。随机初始耐久不超过100%；制作不永久解锁只作用于制作成功流程，不会把等待期间其他正常解锁全部封掉。'),
    T('贝爷的可选子项（均默认关闭）', ['子项', '启用后的规则'], [
      ['种地种树需要书', '播种／种树需要合适园艺或造林书，每次消耗1点书耐久'],
      ['做饭需要书', '烹饪需要可用烹饪指南，每次开锅消耗1点耐久'],
      ['材料制造翻倍', '制作配方所需材料数量翻倍'],
      ['低san采集失败', '理智越低越容易失败，理智见底最高50%'],
      ['捡东西变慢', '拾取、采摘、收获使用慢动作'],
    ]),
    T('德爷的子项', ['子项', '子项默认', '启用后的规则'], [
      ['料理禁止堆叠', '关闭', '料理每格一份；旧档原有堆叠数量保留，拆分后不可重新合并'],
      ['护甲失效', '关闭', '护甲不抵挡伤害且受击不耗耐久，伴随对应影怪保护'],
      ['难以冻结', '开启', '冻结有23秒冷却，单次冻结最长4秒'],
      ['下雨禁火', '开启', '雨中无有效遮雨保护时不能正常点火，火把会熄灭'],
      ['火把传热', '开启', '点燃的火把、打火机火焰作为附近玩家的热源'],
      ['空挥武器', '关闭', '发起攻击时原地挥武器，不先走到最远攻击距离'],
    ]),
    P('旧料理与雨天保护', '禁堆叠不会删掉旧档一叠料理中的多余数量；已保存的整组仍在，拆开后按单份规则使用。特殊饮料、装饰品及明确多份配方有原有豁免。', '下雨禁火会检查有效遮雨，已经受到遮雨保护的火炉不按完全露天处理；原生龙鳞火炉也包含在检查范围内。'),
    R('difficulty-rating', 'configuration', 'fuel-cooking'),
  ], auditedVersion: version,
};

const difficulty = {
  id: 'difficulty-rating', new: true, title: '用 /nd 查询房间难度', category: 'start', tag: '配置',
  summary: '按本模组实际生效配置与默认设置比较，私下显示简单、默认、困难或地狱。',
  keywords: 'nd /nd 难度 评级 默认 简单 困难 地狱 私有 查询',
  configKeys: ['difficulty_rating', 'enable hard mode', '贝爷求生', '德爷生存'],
  source: source('common/difficulty.lua', 'scripts/difficultyrating2hm.lua', 'scripts/combatconfig2hm.lua', 'modinfo.lua', 'modmain.lua'),
  sections: [
    P('怎样查询', '保持“难度评级”开启，在聊天或控制台输入 /nd。普通玩家也能使用，结果只向自己显示，不会在入服时、定时或向全服自动公告。'),
    P('与什么比较', '基准是当前淬炼之季的默认设置，并先应用战斗／装甲的旧值迁移。每个实际生效子项比默认更强计上调1项，变弱或关闭计下调1项；同一项跨多档也只算一次，上调与下调相抵得到净变化。查询按玩家所在分片的实际设置计算，地面和洞穴配置不同时，结果可能不同。'),
    T('四档阈值', ['净变化', '评级'], [['≤−5', '简单'], ['−4～3', '默认'], ['4～6', '困难'], ['≥7', '地狱']]),
    P('怎样理解结果', '回复同时列出上调、下调、其中关闭项数与净变化。“默认”表示处于−4～3区间，不要求每个设置都与默认完全相同。', '只修改一个已关闭模式下的子项不会计入；关闭困难模式或分类总开关时，原本默认生效的子项分别算下调，父开关不重复加分。传统战斗／装甲等替代机制不强行排列高低，但关闭它们算下调。'),
    P('评定的边界', '统计本模组可比较的困难模式、启示录及实际启用的贝爷／德爷挑战。语言、整理、简单模式便利项等不计；未启用妥协时不计其专属子项。它不测量玩家技术、世界进度、原版世界生成设置或其他模组带来的全部难度。'),
    R('survival-modes', 'configuration', 'combat', 'armor'),
  ], auditedVersion: version,
};

export const patches = [gettingStarted, configuration, faq, combat, armor, worldExchange, shadowNexus, containers, fuelCooking, foodValues, furnace, survival, difficulty]
  .map(article => ({ ...article, auditedVersion: version }));

export const configNotes = {
  'World Exchange': { requires: [], paragraphs: ['默认为爽原版。操作界面由容器整理收集按钮或道具快捷收集存放提供；要显示容器穿越按钮，需开启容器整理收集按钮。关闭按钮不会删除旧空间的托管与恢复记录。三种机制为原版整箱交换、咸鱼双空间远端存取与主世界托管的暗影枢纽，另可关闭空间切换。', '旧配置值统一迁移原版，旧枢纽物品恢复后送回所属层；新菜单明确选档会保留。各机制独立保留库存，不能把切档视为合并全部物品。地面、洞穴及其他分片须同时更新且设置一致。暗影／钓具跨层同时存取属于暗影枢纽。'] },
  combat: { requires: ['enable hard mode', 'role_nerf'], paragraphs: ['默认锋芒渐敛；普通角色2.5倍起递减趋近4倍，沃尔夫冈3.5→5倍，沃托姆4→5.5倍，骑乘2.5→4倍，位面2→3.5倍。没有溢出减伤或移速补偿。旧默认1档自动迁移，新菜单传统1档可明确保留。'] },
  epic_armor_5: { requires: ['enable hard mode', 'monster_change'], paragraphs: ['默认遇强则坚。单次掉血不高于最大生命10%；实际掉血累积的压力在20%～30%之间递增减伤。每秒比例衰减为最大生命2%÷√额外血量倍率，停手1秒后另保证至少400点生命额度／秒的衰减。', '淡红微光表示动态减伤强弱。排除蚁狮、果蝇王及暗影分身。保留禁用与传统1～5档，不附带传统无敌期、回血或陨石。'] },
  cooking_change: { requires: hard, paragraphs: ['−1燃料锅为默认；−2再使多数食材度减0.25；−3再启用五格锅与鲜度、填充物／配方规则。五格兼容永不妥协正式／测试版，以及测试版开启后的动态料理属性，也适配能力勋章红晶锅、棱镜月炆宝炊。', '龙鳞火炉仍用四份食材＋红宝石专用槽。五格档下，火炉按原食材度和原配方条件计算；成品仍受50%～70%鲜度饥饿折扣。必要动态料理适配不随可选妥协补丁关闭而撤回。'] },
  difficulty_rating: { requires: [], paragraphs: ['默认开启。在聊天或控制台输入 /nd，普通玩家可私下查询本模组实际生效配置相对默认的净变化。≤−5简单，−4～3默认，4～6困难，≥7地狱；每个设置最多计一次。没有全服定时或入服广播。'] },
  '贝爷求生': { requires: [], paragraphs: ['独立总开关，默认关闭。开启后加入制作变慢、随机初始耐久与熟练度、资源减半、制作不永久解锁、猪王不换金及磨刀、全员读书、黑暗免疫等配套规则。子项需此开关，不依赖简单／困难模式。'] },
  '种地种树需要书': { requires: ['贝爷求生'], paragraphs: ['默认关闭。启用贝爷后，再开启本项，播种或种树需要对应园艺／造林书，每次消耗1点耐久。'] },
  '做饭需要书': { requires: ['贝爷求生'], paragraphs: ['默认关闭。启用贝爷后，再开启本项，开锅需要可用烹饪指南，每次烹饪消耗1点耐久。'] },
  '材料制造翻倍': { requires: ['贝爷求生'], paragraphs: ['默认关闭。启用贝爷且开启本项时，制作配方所需材料翻倍。'] },
  '低san采集失败': { requires: ['贝爷求生'], paragraphs: ['默认关闭。启用贝爷且开启本项时，理智越低，采集失败率越高；理智见底最高50%。'] },
  '捡东西变慢': { requires: ['贝爷求生'], paragraphs: ['默认关闭。启用贝爷且开启本项时，拾取、采摘、收获使用慢动作。'] },
  '德爷生存': { requires: [], paragraphs: ['独立总开关，默认关闭。子项即使显示开启，也只有在本项启用后生效，不依赖简单／困难模式。请逐项确认禁堆叠、护甲、冻结、雨天火源与挥刀规则。'] },
  '料理禁止堆叠': { requires: ['德爷生存'], paragraphs: ['默认关闭。启用德爷且开启本项后，料理每格一份；已有存档堆叠保留全部数量，拆分后不能重新合并。特殊饮料／装饰品和明确多份配方有原有豁免。'] },
  '护甲失效': { requires: ['德爷生存'], paragraphs: ['默认关闭。启用德爷且开启本项后，护甲不再抵挡伤害，也不因受击损失耐久，同时加入对应暗影生物保护规则。'] },
  '难以冻结': { requires: ['德爷生存'], paragraphs: ['子项默认开启，但德爷总开关默认关闭。实际生效后冻结有23秒冷却，单次冻结最长4秒。'] },
  '下雨禁火': { requires: ['德爷生存'], paragraphs: ['子项默认开启，但德爷总开关默认关闭。生效后雨中无有效遮雨时禁止正常点火，火把会熄灭；火源是否受遮雨保护会影响处理。'] },
  '火把传热': { requires: ['德爷生存'], paragraphs: ['子项默认开启，但德爷总开关默认关闭。生效后点燃的火把／打火机火焰成为附近玩家的热源；此便利项不计入 /nd 的难度变化。'] },
  '空挥武器': { requires: ['德爷生存'], paragraphs: ['默认关闭。启用德爷且开启本项后，攻击时原地挥武器，不先走到最远攻击距离。这是操作方式选择，不计入 /nd 难度变化。'] },
};
