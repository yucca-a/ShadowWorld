// Targeted refresh against the published 2.8.15.0.23 content snapshot.
// Earlier unchanged sections remain sourced from the original article audits.
import { patches as characters } from './entity-audit-characters.mjs';
import { patches as general } from './entity-audit-general.mjs';
import { patches as equipment } from './item-audit-equipment.mjs';
import { patches as custom } from './item-audit-custom.mjs';
import { patches as utility } from './item-audit-utility.mjs';
import { patches as life } from './life-audit-general.mjs';

const P = (title, ...paragraphs) => ({ title, paragraphs });
const T = (title, headers, rows) => ({ title, table: { headers, rows } });
const easy = ['enable easy mode', 'role_easy', 'winona_easy'];
const originals = new Map([...characters, ...general, ...equipment, ...custom, ...utility, ...life].map(a => [a.id, a]));
export const patches = [];
export const configNotes = {};

function copy(id, extraSources = []) {
  const original = originals.get(id);
  if (!original) throw Error('Unknown release article: ' + id);
  const article = structuredClone(original);
  article.source = [...new Set([...article.source, ...extraSources])];
  article.auditedVersion = '2.8.15.0.23';
  patches.push(article);
  return article;
}
function replace(article, title, section) {
  const index = article.sections.findIndex(s => s.title === title);
  if (index < 0) throw Error(`Missing section ${article.id}: ${title}`);
  article.sections[index] = section;
}
function add(article) {
  patches.push({ ...article, new: true, auditedVersion: '2.8.15.0.23' });
}
function note(key, paragraphs, requires = []) {
  configNotes[key] = { paragraphs: Array.isArray(paragraphs) ? paragraphs : [paragraphs], requires };
}

const winona = copy('role-winona', [
  'content/scripts/winonabuilder2hm.lua', 'content/scripts/umwinonaworker2hm.lua',
  'content/easy_other/um_patch.lua', 'content/easy_role/winona_toolbox.lua',
  'content/easy_role/winona_electrical.lua', 'content/scripts/winonaelectrical2hm.lua',
]);
winona.summary = '薇诺娜可制作工具箱、改造电气照明并解锁 200% 过充；制作增强保留永不妥协的工作能力。';
winona.configKeys = [...new Set([...winona.configKeys, 'Winona Toolbox Tools', 'Winona Generator Ground Charging', 'Winona Electrical Upgrades', 'um_patch'])];
replace(winona, '建造与拆除', P('制作与拆除',
  '“薇诺娜制作不再受饥饿值影响”只调整普通制作动作，不会关闭永不妥协的工作能力；其砍树、挖矿、采集、工具损耗与动作扣饥饿仍按对应模组设置处理。带专用动作的配方保留自身规则。',
  '锤拆有制作配方、可掉落材料且不是生物生成器的物体时，普通建筑返还全部配方材料。若目标有耐久、燃料、护甲或新鲜度，则返还比例为 50%＋剩余比例÷2；烧毁建筑再减半。最终材料数量仍按配方掉落规则计算。'));
winona.sections.splice(2, 0,
  T('与永不妥协测试版同开时的工作能力', ['饥饿状态', '工作量', '工具消耗'], [
    ['饥饿比例至少66.6%', '1.5 倍', '0.5 倍'], ['饥饿比例33.3%至不足66.6%', '1 倍', '1 倍'], ['饥饿比例不足33.3%', '0.666 倍', '1.333 倍'],
  ]),
  P('工作能力的开关',
    '上表要求永不妥协测试版本身启用薇诺娜工作能力。淬炼角色增强会补齐已核对版本初次生成角色时的倍率刷新；死亡后不再继续扣工作饥饿、复活后恢复一次监听的修复，则另受“永不妥协补丁”控制。关闭制作增强不会自动关闭上游工作能力。'),
  { title: '工具箱与电气装备', links: ['winona-toolbox', 'winona-electrical-upgrades'] },
);
note('Winona No Hungry Builder', '只让薇诺娜普通制作不再采用饥饿制作动作；保留原有工作、采集、工具消耗和永不妥协工作能力，不再通过移除角色标签关闭它们。专用配方动作仍保留。', easy);
note('Winona Toolbox Tools', '允许工具箱额外存放斧头、镐、铲子等带工具属性的物品，保留原有可存物品。单开淬炼时提供工具箱配方：木板×2、金块×4、可靠的胶布×2，薇诺娜专属。', easy);
note('Winona Generator Ground Charging', '地面电器在运转发电机范围内自动补电；受管装备每约0.5秒增加1个百分点。未解锁过充的物品最高100%，已由薇诺娜解锁的最高200%；拿起后停止地面充电。', easy);
note('Winona Electrical Upgrades', '电能转换套件改造提灯、矿工帽和鼹鼠帽，耗能降低25%。薇诺娜必须穿戴装备并主动向低级或高级发电机充电，实际超过100%后，才为该件物品解锁200%过充；过充不加倍消耗。', easy);

add({
  id: 'winona-toolbox', title: '薇诺娜的工具箱', category: 'items', tag: '角色专属', icon: 'tacklecontainer',
  summary: '薇诺娜制作的随身工具箱可收纳原有工程材料，并额外收纳斧头、镐和铲子等工具。',
  keywords: 'winona_toolbox 女工 工具箱 斧头 镐 铲子',
  configKeys: [...easy, 'Winona Toolbox Tools'],
  source: ['content/modmain.lua', 'content/easy_role/winona_toolbox.lua', 'content/scripts/prefabs/winona_toolbox2hm.lua'],
  sections: [
    T('制作配方', ['材料', '数量'], [['木板', '2'], ['金块', '4'], ['可靠的胶布', '2']]),
    P('解锁与获取', '单开淬炼之季时，由薇诺娜直接制作，不需要额外科技站。与永不妥协同开时，优先沿用其同名工具箱和已有配方；只有同名配方不存在时才补上上表配方。'),
    P('可存物品', '开启“薇诺娜工具箱可存放工具”后，斧头、镐、铲子等带工具属性的物品可存入。原有工程材料、宝石等存放规则仍保留。', '单开时提供 12 格工具箱，可放可靠的胶布、扫描仪、传送伞、远程控制器、废料与修补工具、电子元件、硝石、天体英雄碎片、纯粹辉煌和储物机器人等指定物品，以及宝石、便携物品和噩梦燃料类物品。'),
    P('关闭增强之后', '原有工具箱和已存入的工具仍可随存档恢复；关闭后不再允许新存入额外开放的工具。'),
    { title: '相关词条', links: ['role-winona', 'winona-electrical-upgrades'] },
  ],
});

add({
  id: 'winona-electrical-upgrades', title: '电能转换套件与过充', category: 'items', tag: '角色专属', icon: 'transistor',
  summary: '用套件改造三种照明装备，再由薇诺娜穿戴并触摸发电机，为每件装备解锁最高 200% 电量。',
  keywords: '薇诺娜 女工 电能转换套件 电提灯 电矿工帽 电鼹鼠帽 晨星锤 电蚊拍 奔雷矛 过充 发电机',
  configKeys: [...easy, 'Winona Electrical Upgrades', 'Winona Generator Ground Charging'],
  source: ['content/modmain.lua', 'content/easy_role/winona_electrical.lua', 'content/scripts/winonaelectrical2hm.lua', 'content/scripts/prefabs/winona_electrical2hm.lua', 'content/scripts/prefabs/electrical_shock2hm.lua'],
  sections: [
    T('淬炼提供的套件配方', ['材料', '数量'], [['金块', '6'], ['可靠的胶布', '2'], ['废料', '4']]),
    P('解锁与改造', '薇诺娜在炼金引擎旁解锁。拿起套件，对提灯、矿工帽或鼹鼠帽使用升级，每次消耗 1 个套件；已改造的装备不能重复转换。', '同开永不妥协正式版或测试版时共用一个套件，沿用它的外观和已有配方。若其相关设置关闭导致没有配方，淬炼补上同名配方。单开时套件使用电子元件外观。'),
    P('改造后的变化', '装备改用电池燃料，容量基准沿用原装备，消耗速度为原来的 0.75 倍。晨星锤、电蚊拍和两种奔雷矛也纳入电气装备增强：燃料或计次消耗降为 0.75 倍。过充不会另行加倍消耗。'),
    { title: '首次解锁 200% 过充', list: [
      '由真正的薇诺娜穿戴待解锁的电气装备，放入该物品对应的装备栏。',
      '对运转的低级或高级发电机主动执行充电；每次最多补充 33 个百分点。',
      '这件装备实际充过 100% 后，便记住过充资格，最高电量为 200%。每件装备分别解锁。',
    ] },
    P('充电限制', '背包中拿起物品、其他角色借用制作能力或使用其他电池，都不能首次解锁。其他角色手动充电与普通燃料补充最高到 100%。解锁后的装备即使电量降到 100% 以下，也不会遗失资格。'),
    P('地面自动补电', '另开启“发电机为地面电器充电”，将物品放在运转发电机的供电范围内，可每约 0.5 秒补充 1 个百分点。多台发电机不会叠加这个频率。未解锁最高 100%，已解锁最高 200%；拿起物品后停止地面充电。'),
    T('超过 100% 时的效果', ['装备', '效果'], [
      ['矿工帽', '照明半径从 2.5 提升到 5'],
      ['晨星锤', '符合条件的目标可受电击眩晕；部分机械目标额外失去17生命'],
      ['电蚊拍', '对昆虫、蜘蛛等目标的连锁伤害由5提升到25'],
      ['其他受管电气装备', '获得额外储电；未额外添加专属攻击效果'],
    ]),
    P('保存与耗尽', '实际电量和过充资格随物品保存，奔雷矛永久升级时继承资格。关闭本增强后，已改造装备仍可读取，但恢复 100% 充电上限。', '原有耗尽规则仍保留，例如鼹鼠帽电量耗尽仍会损毁；过充不是无限耐久。'),
    { title: '相关词条', links: ['role-winona', 'winona-toolbox'] },
  ],
});

const walter = copy('role-walter', ['content/scripts/prefabs/slingshotammo_moonglass_walter2hm.lua', 'content/tech/prototyperlevel.lua']);
walter.summary = '沃尔特保留原版和改装弹弓，与永不妥协同开时另有独立的圆形玻璃弹配方。';
replace(walter, '移动射击', P('弹弓攻击优化', '“沃尔特弹弓攻击优化”控制射击和相关动作兼容；选择 −1 档还会加载替代攻击动作。与永不妥协维希模块同开时，补回开局原版弹弓与 10 发石弹。'));
walter.sections.push({ title: '圆形玻璃弹', links: ['walter-moonglass-rounds'] });

const slingshot = copy('walter', ['content/scripts/prefabs/slingshotammo_moonglass_walter2hm.lua', 'content/tech/prototyperlevel.lua']);
slingshot.sections.push(P('恢复圆形玻璃弹', '与永不妥协维希模块同开时，沃尔特另有“玻璃弹（沃尔特）”配方，恢复原版圆形弹药。1 个月亮碎片制作 20 发，拥有弹药效率技能时为 30 发，仍需对应玻璃弹技能和三级天体科技。它不依赖维希弹弓权限开关，不会解除维希尖刺弹的专属限制。'));
slingshot.sections.push({ title: '圆形玻璃弹配方', links: ['walter-moonglass-rounds'] });

add({
  id: 'walter-moonglass-rounds', title: '玻璃弹（沃尔特）', category: 'items', tag: '角色专属', icon: 'moonglass',
  summary: '与永不妥协同开时，用独立配方恢复沃尔特的圆形玻璃弹；不与维希的尖刺玻璃弹混用。',
  keywords: '沃尔特 弹弓 圆形 玻璃弹 月亮碎片 维希 尖刺 slingshotammo_moonglass_walter2hm',
  configKeys: ['Walter Use Wixie Slingshot'],
  source: ['content/modmain.lua', 'content/common/walter_wixie_slingshot.lua', 'content/scripts/prefabs/slingshotammo_moonglass_walter2hm.lua', 'content/tech/prototyperlevel.lua'],
  sections: [
    T('制作配方', ['材料', '基础产量', '弹药效率技能产量'], [['月亮碎片 ×1', '20 发', '30 发']]),
    P('解锁条件', '仅沃尔特可制作，需解锁对应玻璃弹技能，并在提供三级天体科技的天体祭坛工作站制作。它是与永不妥协维希模块同开时补回的独立配方，不依赖简单／困难模式，也不依赖“沃尔特可使用维希弹弓”开关。'),
    P('圆形与尖刺弹的区别', '圆形弹沿用当前原版的玻璃弹命中和技能效果，供沃尔特使用；永不妥协同名的尖刺弹仍由维希制作和使用。既有尖刺弹不会自动转换成圆形弹。', '关闭维希弹弓权限时，圆形弹仍可用于沃尔特原版及已适配的改装弹弓；开启权限后，也可装进获准使用的维希弹弓。关闭永不妥协后，存档里已有的圆形弹仍可读取。'),
    { title: '相关词条', links: ['walter', 'role-walter', 'role-wixie'] },
  ],
});

const wendy = copy('role-wendy');
wendy.sections.splice(wendy.sections.findIndex(s => s.title === '夜影万金油与护盾'), 0,
  P('连续使用药剂', '同一种药剂再次成功使用时，把本次药剂的完整有效时长加到已有剩余时长上。例如某药剂每次有效时长为 60 秒，剩余 20 秒时再用一份，结果为 80 秒。技能只修正本次新增时长，不会反复放大此前的剩余时长。',
    '阿比盖尔与共享到温蒂身上的药剂分别保留自己的剩余时间。对支持延时技能的药剂，阿比盖尔及非困难模式共享沿用原版技能，本机游戏版本为基础时长的 2 倍。困难角色改动生效时，仅共享给温蒂的新增时长按基础时长的 3/4 计算；支持延时且点出该技能时，改为基础时长 ×1.5×3/4。上述修正都只作用于本次新增时长。',
    '不同药剂可分别生效，但高级防御药剂存在时，低级防御药剂不能用来覆盖它。'));
note('Wendy Share Debuff From Abigail', '不同灵体药剂可分别生效，并共享对应状态给温蒂。同种药剂成功再用时，按“已有剩余＋本次有效时长”相加，不反复放大旧时长。支持延时技能的药剂，阿比盖尔和非困难共享沿用原版技能（本机为2倍）；困难角色改动生效时，温蒂共享的新增时长为基础的3/4，支持延时且点出技能时为基础×1.5×3/4。', ['enable easy mode', 'role_easy', 'wendy_easy']);

for (const id of ['anti-slip-boots', 'eternal-boots']) {
  const a = copy(id, ['content/scripts/bootlegnonslip2hm.lua', 'content/common/patch.lua']);
  replace(a, '防滑', P('防滑', '放在玩家物品栏或随身背包中即可防止滑倒，不需要装备。同时携带多件防滑来源时，移走其中一件不会取消其他物品仍提供的防滑；最后一件离身后恢复普通滑倒规则。', '防滑在携带、离身和角色迁移时保持同一套规则，不会为了切换效果反复移除角色的滑倒能力。'));
}

const lunar = copy('infused-lunar-sword');
lunar.sections.splice(lunar.sections.findIndex(s => s.title === '耐久与修理'), 0,
  P('月火斩冷却', '基础冷却为 10 秒，使用原生物品冷却圈显示。冷却期间不会再次进入技能起手动作，冷却结束恢复瞄准与施放；普通攻击仍可使用。保存和读档保留冷却进度。有效目标检查通过后才消耗技能冷却。'));

for (const id of ['infused-nightsword', 'infused-glass-cutter']) {
  const a = copy(id, ['content/scripts/weaponinfusionview2hm.lua']);
  a.sections.push(P('注能显示与储存', '注能或注魔进度变化只更新物品格显示，不会为了刷新图标临时取下、移动或删除武器。武器耐久与注能时间分别保留，存入暗影／钓具空间等容器后仍可正常读取。'));
}

const magician = copy('possessed-magician-hat');
magician.sections.push(P('打开时保存与回档', '正在使用帽子时保存或回档，载入后会关闭临时使用界面并把帽子归还物品栏；其他已获得魔术师能力的角色也遵循此规则。私人空间内容仍随玩家保存，帽子的附身升级状态也会保留。'));

for (const id of ['upgraded-beefalo-bell', 'shadow-beef-bell']) {
  const a = copy(id, ['content/common/um_compat_fixes.lua', 'content/common/beef_bell_pack.lua']);
  a.sections.push(P('寡妇背包打包', '与永不妥协同开时，普通绑定牛铃、橙宝石牛铃和阴郁皮弗娄牛铃可正常放入寡妇背包打包。打包会先让骑手下牛，再把绑定坐骑随牛铃一并收进包裹；拆包恢复一头牛，不在原处留下另一头。', '只查看包裹内容不会放出坐骑，也不会启动额外复活。召回状态、死亡状态和剩余复活等待时间随原有牛铃规则保存。其他打包工具自身的禁装规则仍然适用。'));
}

const beefalo = copy('creature-beefalo-bonding');
beefalo.sections.splice(beefalo.sections.findIndex(s => s.title === '牛铃升级'), 0,
  P('牛犊成长与盐碱舔块', '开启本页皮弗娄牛改动时，每 10 秒检查附近仍可使用的盐碱舔块。普通舔块额外推进 10 秒成长，强化舔块额外推进 20 秒；多块不累加，优先采用强化效果。成长暂停时也会扣减剩余成长等待时间。'),
  P('成年体型与生命', '牛犊长大时，参考周围 20 距离内存活成年牛的平均最大生命，没有成年牛时以 1000 为基准；再随机乘以 0.8～1.1，最高 3000，并据此确定体型。与随机体型功能同开时，交由对应随机体型流程应用。'));
note('beefalo', '普通牛铃要求至少10%驯化度，并限制绑定影子、属性精英、警惕猎物者和正在带跟随者的牛；已有主人的牛获得部分防误伤。牛犊可受附近盐碱舔块加速成长，成年体型参考周围成年牛。', ['enable hard mode', 'food_change']);

add({
  id: 'equipment-slot-swapping', title: '手部装备换装', category: 'mechanics', tag: '操作便利',
  summary: '从自己物品栏选中另一件手部装备时，旧手持物进入这次选中物品腾出的格子。',
  keywords: '换装 武器 格子 快捷键 数字键 手柄 装备栏 胡须槽', configKeys: [],
  source: ['content/modmain.lua', 'content/common/equip_slot_fix.lua'],
  sections: [
    P('换装方法', '空手时，1 号格是矛、2 号格是斧头。先按 1 拿矛，1 号格空出；再按 2 拿斧头，矛进入 2 号格，1 号格保持空。再次按 2，两件手部装备在当前格与手上交换。', '这项便利默认加载，不受简单／困难模式开关控制。重复的同件装备请求不会把手中的同一件物品卸下。'),
    P('适用范围', '适用于从本角色物品栏选取手部装备。主动卸下、鼠标活动物品、从地面或其他容器装备以及物品自身的装备限制，继续按原有规则处理。旧版本记录的历史来源格不再强制锁定归位。'),
    P('额外装备栏', '旧额外装备栏模组遗漏威尔逊胡须槽时，会补回对应槽位，使两端使用一致的槽位表。'),
  ],
});
