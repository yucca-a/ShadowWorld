import fs from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { articles as initial, meta } from './content.mjs';
export { meta };
export const categories = [
  {id:'start',name:'入门与说明'}, {id:'mechanics',name:'战斗与生存'}, {id:'world',name:'暗影世界与季节'},
  {id:'characters',name:'角色解析'}, {id:'items',name:'道具与装备'}, {id:'buildings',name:'建筑与科技'},
  {id:'food',name:'食物与农业'}, {id:'creatures',name:'生物与首领'}, {id:'updates',name:'版本记录'},
];
export const configData=JSON.parse(await fs.readFile(new URL('./data/configs.json',import.meta.url),'utf8'));
if(configData.version!==meta.version)throw Error('Wiki and configuration snapshot versions differ');
export const iconManifest=JSON.parse(await fs.readFile(new URL('./data/icon-manifest.json',import.meta.url),'utf8'));
export const iconLabels=JSON.parse(await fs.readFile(new URL('./data/icon-labels.json',import.meta.url),'utf8'));
export const protectedIconNames=JSON.parse(await fs.readFile(new URL('./data/icon-protected-names.json',import.meta.url),'utf8'));
export const notes={};
export const articles=structuredClone(initial);
const sourceAuditVersion='2.8.14.97.4';
for(const part of ['general','items','characters','world','um-compat-equipment']){
  try {
    const content=await import(`./research/${part}.mjs`);
    articles.push(...(content.articles??[]));
    Object.assign(notes,content.configNotes??{});
  }catch(error){if(error.code!=='ERR_MODULE_NOT_FOUND')throw error;}
}
const originalKeys={ 'configuration':['enable easy mode','enable hard mode','World Exchange','epic_ruin'],combat:['combat'],armor:['epic_armor_5'], 'world-exchange':['World Exchange','Container Sort'], 'skill-tree':['More Skill Points'], 'night-vision':['Monster Night Vision','wathom nightvision'], wixie:['Wixie No Claustrophobia','wixie'], walter:['Walter Use Wixie Slingshot','walter'], wanda:['wanda strengthen',"Wanda Don't Auto Drop Age",'regen_danger'], eyeturret:['eyeturret'],trap:['Trap Guaranteed Catch'], containers:['Container Sort','Items collect'], frostjaw:['boss_health','sharkboi','extra_change'] };
for(const a of articles){a.configKeys??=originalKeys[a.id]??[];a.keywords??='';a.source??=[];}
export const itemAuditIds=new Set();
for(const part of ['custom','equipment','utility','general']){
  const audit=await import(`./research/item-audit-${part}.mjs`);
  for(const patch of audit.patches){
    const article=articles.find(a=>a.id===patch.id);
    if(!article||itemAuditIds.has(patch.id))throw Error(`Invalid or duplicate item audit: ${patch.id}`);
    Object.assign(article,patch,{auditedVersion:sourceAuditVersion});
    itemAuditIds.add(patch.id);
  }
  for(const [key,note] of Object.entries(audit.configNotes??{}))notes[key]={...notes[key],...note};
}
export const entityAuditIds=new Set(['frost-shrine','mourning-tomb']);
for(const part of ['characters','buildings','bosses','general']){
  const audit=await import(`./research/entity-audit-${part}.mjs`);
  for(const patch of audit.patches){
    const article=articles.find(a=>a.id===patch.id);
    if(!article||entityAuditIds.has(patch.id))throw Error(`Invalid or duplicate entity audit: ${patch.id}`);
    Object.assign(article,patch,{auditedVersion:sourceAuditVersion});
    if(article.category==='characters'||article.category==='buildings'||article.id.startsWith('boss-'))entityAuditIds.add(patch.id);
  }
  for(const [key,note] of Object.entries(audit.configNotes??{}))notes[key]={...notes[key],...note};
}
export const lifeAuditIds=new Set();
for(const part of ['food','creatures','shadows','general']){
  const audit=await import(`./research/life-audit-${part}.mjs`);
  for(const patch of audit.patches){
    const article=articles.find(a=>a.id===patch.id);
    if(!article||lifeAuditIds.has(patch.id))throw Error(`Invalid or duplicate life audit: ${patch.id}`);
    Object.assign(article,patch,{auditedVersion:sourceAuditVersion});
    lifeAuditIds.add(patch.id);
  }
  for(const [key,note] of Object.entries(audit.configNotes??{}))notes[key]={...notes[key],...note};
}
for(const article of articles.filter(a=>entityAuditIds.has(a.id))){
 if(article.id.startsWith('role-'))article.title=article.title.replace(/\s*·\s*角色改动$/,'');
 const title={'boss-crabking':'帝王蟹','boss-frostjaw-combat':'大霜鲨','boss-celestial-champion':'天体英雄','boss-lunar-possession':'月亮附身与变异巨兽'}[article.id];
 if(title)article.title=title;
 if(article.id.startsWith('boss-')&&!article.sections.some(s=>s.links?.includes('mechanic-extra-stats'))){
  article.sections.push({title:'通用属性与掉落倍率',paragraphs:['本页专属数值未计额外 Boss 倍率。开启额外改动后，生命、伤害、攻频和部分奖励还会按房间配置调整；各项算法见下方条目。'],links:['mechanic-extra-stats','mechanic-extra-defense','armor']});
 }
}
articles.find(a=>a.id==='armor').sections.at(-1).paragraphs.push('遇强则坚作用于符合条件的巨兽，并排除蚁狮与果蝇王。蚁狮的沙尘暴减伤由自身技能控制，不能套用这套动态装甲。');
const characterAliases={
 wilson:['威尔森','科学家'], willow:['火女','纵火女'], wolfgang:['大力士'], wendy:['鬼女','幽灵女孩'],
 wx78:['机器人','WX78','WX 78'], wickerbottom:['老奶奶','图书管理员','薇克伯顿'],
 woodie:['伐木工'], wes:['小丑','默剧演员','维斯'], waxwell:['老麦','麦克斯韦','Maxwell'],
 wigfrid:['女武神','维格弗里德'], webber:['蜘蛛人','蜘蛛男孩','小蜘蛛'], winona:['女工','女工人'],
 warly:['厨师','大厨'], walter:['童子军','小童子军'], wortox:['小恶魔','恶魔人','恶魔','沃托克斯'],
 wormwood:['植物人','树人'], wurt:['鱼妹','鱼人妹'], wanda:['表姐','钟表匠','旺妲'],
 wonkey:['猴子','猴人'], wathom:['Wathom'], wixie:['Wixie'],
};
for(const article of articles){
 if(article.id.startsWith('role-'))article.aliases=characterAliases[article.id.slice(5)]??[];
}
const itemReadingLinks={
 'frost-core':['frostjaw','frost-shrine','frost-core-staff'],
 'frost-core-staff':['frost-core','frost-shrine'],
 'frost-shrine':['frostjaw','anti-slip-boots'],
 'anti-slip-boots':['frost-shrine','eternal-boots'],
 'infused-lunar-sword':['rift-equipment-changes'],
 'eternal-bearger-bin':['rift-bearger-bin','carrot-cake','four-season-fish-soup'],
 'possessed-magician-hat':['containers'],
 'mourning-tomb':['soul-bottle'], 'soul-bottle':['mourning-tomb'],
 'vortex-sword':['equipment-repair','infused-nightsword'],
 'upgraded-beefalo-bell':['shadow-beef-bell'],
 'shadow-boat':['crabking-bumper','fast-malbatross-sail'],
 'rift-equipment-changes':['wagpunk-rift-upgrade','rift-bearger-bin','shadow-battleaxe-rift','shadow-beef-bell','infused-lunar-sword'],
 'rift-bearger-bin':['eternal-bearger-bin'], 'shadow-beef-bell':['upgraded-beefalo-bell'],
 'horn-enchant':['multitool','thulecite-club','um-compat-equipment'],
 'multitool':['equipment-repair','horn-enchant'], 'thulecite-club':['equipment-repair','horn-enchant'],
 'infused-glass-cutter':['equipment-repair','infused-nightsword'],
 'bone-helm':['shadow-thurible'], 'shadow-thurible':['bone-helm']
};
articles.find(a=>a.id==='boss-celestial-champion').sections.find(s=>s.title==='掉落与采矿').links=['celestial-onion'];
for(const [id,links] of Object.entries(itemReadingLinks)){
 const section=articles.find(a=>a.id===id).sections.at(-1);
 section.links=[...new Set([...(section.links??[]),...links])];
}
const about=articles.find(a=>a.id==='about');
about.sections[0].paragraphs=['本资料库面向《为爽而虐 / 暗影世界 淬炼之季》玩家，包含当前全部配置的默认值、可选档位与关联玩法，以及按源码整理的角色、道具、建筑、食物、生物和世界机制。','机制说明按当前版本源码核对。页面标注的版本是资料基线，工坊版本变化后需要再次核对更新。配置说明与当前实现存在差异时会单独标注。'];
about.sections[2].paragraphs=['阅读布局参考 QiNeko Wiki；正文依据淬炼之季本地源码和更新日志独立整理。两个分支的机制、数值与默认配置不同，参考站的新内容不代表本分支已经实装。','图标从已安装的饥荒联机版与本模组资源中提取，仅用于识别相关游戏内容，权利归 Klei Entertainment 及相应作者。'];
about.sections[2].externalLinks[0].url='https://qineko.wiki/ws/';
about.sections[2].paragraphs.push('角色词条保留游戏角色名，并列出玩家攻略和讨论中常用的称呼，方便查找。');
about.sections[2].externalLinks.push(
 {label:'灰机 Wiki · 饥荒联机版角色',url:'https://dontstarve.huijiwiki.com/wiki/角色'},
 {label:'3DM · 角色昵称与介绍',url:'https://www.3dmgame.com/gl/3787258.html'},
 {label:'小黑盒 · 角色技能加点攻略',url:'https://playblackbox.com/guides/2070708/'},
 {label:'Steam 社区 · 联机版角色攻略',url:'https://steamcommunity.com/sharedfiles/filedetails/?id=2066554357'},
);
const gettingStarted=articles.find(a=>a.id==='getting-started');
gettingStarted.sections.at(-1).paragraphs=[`配置大全覆盖当前 ${configData.total} 项实际配置。百科按玩法分类阅读，每篇可跳转到对应开关查看全部档位；遇到名称不同的配置，检索也支持配置键。`,'远古宝珠目前只有设计草案，未包含在当前发布版中。贝爷求生、德爷生存等参考站其他分支规则也不能直接套用。'];
const configByKey=new Map(configData.configs.map(c=>[c.key,c]));
export const configId=key=>'cfg-'+createHash('sha1').update(key).digest('hex').slice(0,12);
export const groupId=(mode,group)=>'group-'+createHash('sha1').update(mode+'/'+group).digest('hex').slice(0,10);
export function defaultChoice(config){return config.options.find(o=>o.value===config.default);}
export function choiceText(option){return option?.label||String(option?.value);}
export function requirements(c){
  if(notes[c.key]?.requires!==undefined)return notes[c.key].requires;
  if(['Monster Night Vision','wathom nightvision','Walter Use Wixie Slingshot','Celestial Jewel Upgrade Sword Lunarplant','gelblob_storage_kit upgrade'].includes(c.key))return [];
  if(c.mode==='暗影世界'&&c.key!=='Shadow World')return ['Shadow World'];
  if(c.mode==='Ray')return c.key==='Random sized beefalo'?['Random Sized']:[];
  if(c.mode==='简单模式'){
    const r=['enable easy mode'];
    if(c.group==='角色改动'&&c.key!=='role_easy')r.push('role_easy');
    if(c.roleParent&&!['ctrl disable right','right self need ctrl'].includes(c.key))r.push(c.roleParent);
    return r;
  }
  if(c.mode==='困难模式'){
    const gate={'角色改动':'role_nerf','天气改动':'weather_change','科技改动':'other_change','食物改动':'food_change','怪物改动':'monster_change','额外改动':'extra_change'}[c.group];
    return ['enable hard mode',...(gate&&gate!==c.key?[gate]:[])];
  }
  return [];
}
export const configs=configData.configs.map(c=>({...c,id:configId(c.key),groupId:groupId(c.mode,c.group),note:notes[c.key]??{},requires:requirements(c),related:articles.filter(a=>a.configKeys.includes(c.key)).map(a=>a.id)}));
for(const config of configs){
  for(const key of config.requires)if(!configByKey.has(key))throw new Error(`Unknown parent config ${key} for ${config.key}`);
}
export const groups=Object.values(Object.groupBy(configs,c=>c.groupId)).map(cs=>({id:cs[0].groupId,mode:cs[0].mode,name:cs[0].group,configs:cs}));
for(const a of articles){for(const key of a.configKeys)if(!configByKey.has(key))throw new Error(`Unknown config key in ${a.id}: ${key}`);}
