const sharedTopics=[
 {id:'characters',name:'角色改动',icon:'wilson',description:'角色能力、技能、操作与兼容'},
 {id:'mechanics',name:'机制改动',icon:'gears',description:'战斗、生存和共享玩法规则'},
 {id:'items',name:'物品改动',icon:'hammer',description:'原有道具、装备、建筑和食物的变化'},
 {id:'creatures',name:'生物改动',icon:'deerclops_eyeball',description:'普通生物、敌怪、首领与掉落'},
 {id:'new-items',name:'新增物品',icon:'blueprint',description:'模组新增的装备、道具、建筑与食材'},
];

export const temperedTopics=[
 {id:'world',name:'暗影世界',icon:'nightmarefuel',description:'暗影世界开关与各类暗影分身'},
 ...sharedTopics,
 {id:'start',name:'入门与说明',utility:true},
 {id:'updates',name:'版本记录',utility:true},
];

export const betaTopics=[
 {id:'world',name:'世界改动',icon:'lantern',description:'地形、世界生成与季节天气'},
 ...sharedTopics,
];

const newTemperedItems=new Set([
 'frost-core','frost-shrine','eternal-boots','anti-slip-boots','mourning-tomb','soul-bottle',
 'cracked-ageless-watch','vortex-sword','celestial-onion','small-candy','carrot-cake','four-season-fish-soup','dried-vegetables',
 'winona-toolbox','winona-electrical-upgrades','walter-moonglass-rounds',
]);
const temperedOverrides={
 'frostjaw':'creatures','skill-tree':'characters','right-click-actions':'characters','character-mode-switches':'characters',
 'containers':'mechanics','equipment-repair':'mechanics','login-irreplaceables':'mechanics','luck-adjustment':'mechanics',
 'quick-transfer-hunger':'mechanics','science-level-rules':'mechanics','archive-puzzle-changes':'mechanics',
 'sleep-recovery-ranges':'mechanics','food-values':'mechanics','hard-food-system':'mechanics','fuel-cooking':'mechanics',
 'crop-growth':'mechanics','resource-regrowth':'mechanics','random-seeds':'mechanics','fire-cooking':'mechanics',
 'living-container':'mechanics','prototype-costs':'mechanics',
};

export function temperedTopic(article){
 if(newTemperedItems.has(article.id))return 'new-items';
 if(article.id==='world-shadow'||article.id.startsWith('world-shadow-'))return 'world';
 if(temperedOverrides[article.id])return temperedOverrides[article.id];
 if(article.category==='world')return 'mechanics';
 if(['buildings','food'].includes(article.category))return 'items';
 return article.category;
}
