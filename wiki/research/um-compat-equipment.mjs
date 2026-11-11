const betaLink = (id, label) => ({url:`um-beta/${id}.html`,label:`妥协测试版 · ${label}`});

export const articles = [{
  id:'um-compat-equipment',
  title:'永不妥协联动装备与道具',
  category:'mechanics',
  tag:'联动兼容',
  summary:'双模组同开时，修补工具包、滑行手杖、月鳞甲、厨师袋及灵魂万灵药的实际变化。',
  keywords:'妥测兼容 修补工具包 宝石修理 查尔斯滑行手杖 马头杖 月鳞甲 玻璃碎片 厨师袋 熊皮背心 灵魂万灵药 编织暗影',
  auditedVersion:'2.8.14.98.6',
  configKeys:['um_patch','Minotaurhorn Enchant','lunar shadow items','wendy'],
  source:[
    'content/modmain.lua',
    'content/modinfo.lua',
    'content/easy_other/um_patch.lua',
    'content/easy_other/easy_items.lua',
    'content/easy_other/lunar_shadow_items.lua',
    'content/role/wendy.lua',
    'content/role/pvp.lua',
    'content/common/patch.lua',
  ],
  sections:[
    {
      title:'联动如何开启',
      paragraphs:[
        '本页按淬炼之季工坊版 2.8.14.98.6 核对。和永不妥协同时加载后，“永不妥协补丁”默认开启，可单独开关。部分条目还会读取永不妥协自己的玩法设置，或淬炼之季的其他开关。',
      ],
      links:['um-item-compatibility'],
    },
    {
      title:'修补工具包',
      paragraphs:[
        '开启妥协测试版宝石学后，拿起修补工具包对装备右键修理。淬炼补丁会取消工具包本身的可修补状态，也会在服务端拒绝用工具包修理另一个工具包。',
        '同一件装备的修理次数越多，恢复量越少。按测试版当前数值，从第 3 次起附魔耐久恢复量降为 0。此时只有装备还有可恢复的使用次数，或可损耗的护甲耐久尚未补满，操作才可能成功。',
      ],
      table:{
        headers:['使用场景','联动后的处理'],
        rows:[
          ['用工具包修另一个工具包','直接拒绝，保留次数'],
          ['附魔恢复量已为 0，装备本体满耐久或没有可恢复耐久','直接拒绝，保留次数与目标的修理计数'],
          ['附魔恢复量已为 0，装备本体仍有损耗','按测试版规则修复本体，消耗工具包一次并增加目标修理计数'],
        ],
      },
      links:['equipment-repair'],
      wikiLinks:[betaLink('mending-kit','修补工具包配方与修复量'),betaLink('gemology','宝石附魔学')],
    },
    {
      title:'滑行手杖与月鳞甲',
      table:{
        headers:['道具','淬炼之季联动效果'],
        rows:[
          ['滑行手杖','装备时移速倍率设为 1.25，相当于基础移速加成 25%。'],
          ['月鳞甲','初始化时，当前耐久和最大耐久各增加 555。'],
          ['玻璃碎片','月鳞甲产生的环绕碎片，发光半径设为 2.3。'],
        ],
      },
      paragraphs:[
        '若同时开启简单模式和“守卫者角附魔”，拿 1 个守护者之角对滑行手杖使用附魔。装备后持续移动约 3 秒可获得最高额外 10% 移速修正，达到最高加速时饥饿消耗倍率为 1.33。附魔冲锋的触发与撞击切换见守护者之角词条。',
      ],
      links:['horn-enchant'],
      wikiLinks:[betaLink('charlies-slider','滑行手杖获取与用法'),betaLink('moon-scale-armor','月鳞甲获取与碎片机制')],
    },
    {
      title:'厨师袋与熊皮背心',
      paragraphs:[
        '妥协测试版开启沃利改动时，厨师袋改为手持容器。联动取消打开时落地的设置，可以在移动中打开和使用。',
        '淬炼另开简单模式和“月后影后装备增强”时，普通孢子云和毒菌蟾蜍孢子云造成的区域腐烂会跳过厨师袋中的食物。这项保护取决于装备增强开关。',
        '永不妥协同时开启衣物口袋改动时，熊皮背心获得 6 格（2 × 3）储物栏。穿上打开，脱下关闭。装有物品时不能塞进其他容器，清空后可以再收纳。',
      ],
      links:['role-warly','containers','rift-equipment-changes','boss-toadstool'],
      wikiLinks:[betaLink('warly','沃利和厨师袋的原有规则')],
    },
    {
      title:'灵魂万灵药',
      paragraphs:[
        '联动给温蒂注册无需科技的配方，制作每批消耗 3 个哀悼荣耀和 50 点生命。若同时开启困难模式、困难模式角色改动总开关和温蒂改动，材料改为 6 个哀悼荣耀、2 份亡者补药和 50 点生命。',
        '点出灵体药剂增产技能后，每批有 20% 和 5% 两次独立判定，每次命中额外获得 1 份。合计为 76% 得 1 份、23% 得 2 份、1% 得 3 份。',
      ],
      links:['role-wendy'],
    },
    {
      title:'沃拓克斯的编织暗影',
      paragraphs:[
        '妥协测试版启用灵魂编织功能时，补丁会给沃拓克斯编织出的暗影保存召唤标记。覆盖三种远古织影者小暗影，以及爬行梦魇、尖喙梦魇、潜伏梦魇和墨荒。',
        '世界存读档和装入船瓶会记录这个标记。只要识别为编织召唤物，常规战利品与通过同一掉落组件添加的额外战利品都会被拦截，包括墨荒的暗影碎布。',
      ],
      links:['role-wortox'],
      wikiLinks:[betaLink('wortox','沃拓克斯的灵魂编织')],
    },
    {
      title:'随双模组加载的道具修复',
      paragraphs:[
        '淬炼的通用兼容代码会为荨麻斗篷的近身毒素扫描保留房间原本的 PVP 判定。若房间关闭 PVP，淬炼的“友伤险境”不会让斗篷误入妥协的 PVP 扫描分支。',
        '若气垫船缺少立即沉没处理，淬炼会为其补上。被帝王蟹炮塔等触发立即沉没时，船会通知船上实体和玩家，结算沉船掉落后移除。',
      ],
      links:['boss-crabking'],
    },
  ],
}];
