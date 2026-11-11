const groups={
 'Client-Side':'客户端','Mod Compatibility':'模组兼容','In Development':'开发中','Core Gameplay':'核心玩法',
 'Shadow Creatures':'暗影生物','Characters':'角色','Weather & Seasons':'天气与季节','World Gen':'世界生成',
 'Rat Raids':'鼠潮','Items and Structures':'道具与建筑','Food':'食物','New Hounds':'新猎犬',
 'New Depths Worms':'新洞穴蠕虫','Bats':'蝙蝠','Spiders':'蜘蛛','New Ruins Monsters':'新遗迹生物',
 'Misc Monsters':'其他怪物','Standard Creatures':'普通生物','Additional Seasonal Giants':'额外季节巨兽',
 'Giants & Bosses':'巨兽与首领','Raid Bosses':'首领生命倍率',
 "Giants' Adjustments":'巨兽调整',"Small Giants' Adjustments":'小型首领调整',
 '> Experimental <':'实验性','> Dev Tools <':'开发工具','ROLLBACK CITY':'高风险趣味设置',
};
const labels={
 um_music:'模组原声音乐',ui_showmultiproducts:'显示制作产量',ui_showmultiproducts_font:'制作产量字体',
 ui_showvetcurse:'显示老兵诅咒图标',um_tips_only:'仅显示模组载入提示',um_storms_over:'降低龙卷风特效',
 wathom_nightvision:'沃托姆夜视滤镜',ui_healthpenalty_grey:'低生命上限惩罚显示为灰色',
 worldgenmastertoggle:'世界生成总开关',nightterrors:'夜惊',food_stats:'动态食物属性',armorrework:'护甲重做',
 gemology:'宝石学',no_winter_growing_:'冬季作物生长限制',beefalo_nerf:'皮弗娄牛调整',
 maxhpdeath:'死亡扣生命上限',maxhphitters:'怪物伤害扣生命上限',maxhungerdamage:'饥饿扣生命上限',
 maxtempdamage:'过冷过热扣生命上限',foodregen:'食物持续恢复',rat_raids:'鼠潮',vetcurse:'老兵诅咒',
 limbo_leap:'鬼魂返回出生传送门',harder_shadows:'强化梦魇生物',dreadeyes_allowed:'恐惧之眼',
 creepingfear_allowed:'潜伏恐惧',wixie_walter:'薇希与沃尔特重做',woby_hunger_classic:'经典沃比饥饿表',
 'funny rat':'温奇',"holy fucking shit it's wathom":'沃托姆',wathom_ampvulnerability:'沃托姆强化承伤倍率',
 wathom_armordamage:'沃托姆强化承伤计入护甲',wathom_max_dmg:'沃托姆伤害上限',wathom_undeath:'沃托姆拒死',
 wathgrithr_rework_:'女武神重做',wx78:'WX-78 机器人',wx78_backupbody:'WX-78 备用机体',
 weatherhazard_autumn:'秋季灾害起始周期',weatherhazard_winter:'冬季灾害起始周期',
 weatherhazard_spring:'春季灾害起始周期',weatherhazard_summer:'夏季灾害起始周期',
 winter_burning:'冬季燃烧调整',snowstorms:'暴风雪',um_storms:'龙卷风',um_storms_performance:'龙卷风性能档位',
 heatwaves:'热浪',hotcaves:'洞穴升温',smog:'烟雾',hoodedforest:'连帽森林',ghostwalrus:'生锈的陷阱',
 rice:'稻米',trapdoorspiders:'活板门蜘蛛',magma_caves:'熔岩洞穴',flooded_caves:'潮湿陷坑',
 rattimer:'鼠潮初始计时',ratgrace:'鼠潮周期嗅探宽限',ratsnifftimer:'鼠潮嗅探间隔',
 wiltfly:'时令龙蝇',wiltfly_spawn:'时令龙蝇生成周期',moonmaw_dragonfly_health_:'月光龙蝇生命倍率',
 mock_dragonfly_health_:'时令龙蝇生命倍率',newrecipes:'新增料理',horriblefood:'更多难吃的食物',
 generalcrockblocker:'限制料理填充物',crockpotmonstmeat:'料理怪物肉调整',
};
export const groupName=name=>groups[name]??name;
export const configName=c=>labels[c.key]??c.title;
const techNames={
 NONE:'无需科技',SCIENCE_ONE:'科学机器',SCIENCE_TWO:'炼金引擎',MAGIC_TWO:'灵子分解器',MAGIC_THREE:'暗影操纵器',
 ANCIENT_TWO:'损坏的远古伪科学站',ANCIENT_THREE:'远古伪科学站',SHADOWFORGING_TWO:'暗影术基座',
 LUNARFORGING_TWO:'辉煌铁匠铺',TURFCRAFTING_TWO:'土地夯实器',LOST:'特殊解锁',
 CELESTIAL_ONE:'天体宝球',CELESTIAL_THREE:'天体祭坛',
 ANCIENT_FOUR:'远古科技 IV',SEAFARING_ONE:'航海科技 I',OBSIDIAN_TWO:'黑曜石科技 II',
 SPIDERCRAFT_ONE:'蜘蛛制作',ORPHANAGE_ONE:'宠物巢穴',HALLOWED_NIGHTS:'万圣节活动',
 HERMITCRABSHOP_ONE:'隐士商店 I',HERMITCRABSHOP_THREE:'隐士商店 III',
 HERMITCRABSHOP_FIVE:'隐士商店 V',HERMITCRABSHOP_SEVEN:'隐士商店 VII',
};
export const techName=key=>techNames[key]??key;
export const extraNames={obsidian:'黑曜石',iron:'铁',um_gem_repair_kit:'修复套件',um_gemology_geode_magma:'熔火晶洞'};
