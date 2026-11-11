import fs from 'node:fs/promises';
import path from 'node:path';
import {createUI} from '../ui.mjs';
import {buildPortal} from '../portal.mjs';
import {betaTopics} from '../topics.mjs';
import {articles,auditedVersion,auditedCnVersion} from './articles.mjs';
import {configName,groupName,techName,extraNames} from './labels.mjs';
import {itemGroups} from './items.mjs';

const snapshot=JSON.parse(await fs.readFile(new URL('./snapshot.json',import.meta.url),'utf8'));
const icons=JSON.parse(await fs.readFile(new URL('../data/icon-manifest.json',import.meta.url),'utf8'));
const artwork=JSON.parse(await fs.readFile(new URL('./artwork.json',import.meta.url),'utf8'));
const {betaVersion,cnVersion,configs,preset,recipes,names}=snapshot;
const workshop='https://steamcommunity.com/sharedfiles/filedetails/?id=3193922031';
const translation='https://steamcommunity.com/sharedfiles/filedetails/?id=3597225156';
const esc=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const code=s=>`<code>${esc(s)}</code>`;
const val=v=>code(JSON.stringify(v));
const link=(href,title)=>`<a href="${esc(href)}">${esc(title)}</a>`;
const configByKey=new Map(configs.map(c=>[c.key,c]));
const configId=key=>'config-'+key.replace(/[^a-z0-9_-]/giu,c=>'_'+c.codePointAt(0).toString(16)+'_');
const configLink=c=>link('configs.html#'+configId(c.key),configName(c));
const standard=c=>c.options.find(o=>o.value===c.default);
const modeLabel=o=>({Enabled:'开启',Disabled:'关闭',Default:'默认',Off:'关闭','Always On':'始终开启'}[o.title]??o.title);
const itemName=id=>names[id]?.zh??extraNames[id]??names[id]?.en??id;
const defaultText=c=>esc(modeLabel(standard(c)))+' · '+val(c.default);
const stale=betaVersion!==auditedVersion||cnVersion!==auditedCnVersion;
const reviewedNotice=stale?`<p class="callout">正文核对于测试版 v${esc(auditedVersion)}、汉化 ${esc(auditedCnVersion)}，与索引快照的版本有差异。</p>`:'';

const categories=betaTopics;
const articleIcons={
 'rat-raids':'ratpoisonbottle','food-recovery':'cookpot','snowstorms':'snowgoggles','cave-worldgen':'cave_entrance_magmabiome',
 gemology:'um_gemologyforge',winky:'winky',wixie:'wixie',wathom:'wathom',
 'summer-dragonflies':'moonmaw_dragonfly','dreadstone-shield':'wathgrithr_shield_dreadstone','beak-basher':'beakbasher',
 'veterans-curse':'veteranshrine','thermal-stone':'heatrock','sewing-kit':'sewing_kit',
};
const entryArticles=articles.map(a=>({...a,tag:'公开测试版',
 configKeys:a.configs,sections:a.sections.map(([title,text,guide,links])=>({title,text,links,
  guide:guide?.makeRows?{...guide,rows:guide.makeRows(snapshot.geodePools)}:guide}))}));
const articleById=new Map(entryArticles.map(a=>[a.id,a]));
const articleByPrefab=new Map(entryArticles.filter(a=>a.category==='new-items'&&a.prefab).map(a=>[a.prefab,a]));
const articleByVariantPrefab=new Map(entryArticles.flatMap(a=>(a.variantPrefabs??[]).map(id=>[id,a])));
const artFor=id=>artwork[id]??(icons[id]?.source.startsWith('DST images.zip/')?icons[id]:null);
function artImage(id,size,css=''){
 const art=artFor(id);
 return art?`<img class="${css}" src="../${esc(art.path)}" alt="" width="${size}" height="${size}" loading="lazy">`:'';
}
function itemLabel(id){
 const name=itemName(id),image=artImage(id,18,'inline-icon');
 return image?`${esc(name.slice(0,-1))}<span class="icon-tail">${esc(name.slice(-1))}${image}</span>`:esc(name);
}
const configModes=[
 ['客户端',['Client-Side']],
 ['生存与机制',['Core Gameplay','Shadow Creatures','Rat Raids']],
 ['角色',['Characters']],
 ['世界与季节',['Weather & Seasons','World Gen']],
 ['道具与食物',['Items and Structures','Food']],
 ['生物与首领',['New Hounds','New Depths Worms','Bats','Spiders','New Ruins Monsters','Misc Monsters','Standard Creatures','Additional Seasonal Giants','Giants & Bosses','Raid Bosses',"Giants' Adjustments","Small Giants' Adjustments"]],
 ['兼容与实验',['Mod Compatibility','In Development','> Experimental <','> Dev Tools <','ROLLBACK CITY']],
];
const modeByGroup=new Map(configModes.flatMap(([mode,groups])=>groups.map(group=>[group,mode])));
const configGroups=[...Map.groupBy(configs,c=>c.category)].map(([category,configs],i)=>({
 id:'group-'+(i+1),name:groupName(category),mode:modeByGroup.get(category)??'其他设置',configs,
}));
const groupByKey=new Map(configGroups.flatMap(g=>g.configs.map(c=>[c.key,g])));
const filterModes=[...new Set([...configModes.map(([mode])=>mode),...configGroups.map(g=>g.mode)])].filter(mode=>configGroups.some(g=>g.mode===mode));

const recipeTypes=[
 ['science','科学与建造','#357485',/^(SCIENCE|TURFCRAFTING|SEAFARING)_/],
 ['magic','魔法与遗迹','#785aa8',/^(MAGIC|ANCIENT|OBSIDIAN)_/],
 ['allegiance','天体与阵营','#765382',/^(CELESTIAL|SHADOWFORGING|LUNARFORGING)_/],
 ['trade','兑换与商店','#a05f36',/^HERMITCRABSHOP_/],
 ['special','角色与活动','#a94f69',/^(SPIDERCRAFT|ORPHANAGE|HALLOWED_NIGHTS)/],
 ['basic','基础与其他','#65737b'],
];
const recipeScope=[
 ['character','角色或技能'],['config','受配置控制'],['compat','岛屿冒险兼容'],['general','无额外条件标记'],
];
const recipeEntries=recipes.map(r=>{
 const [type]=recipeTypes.find(([, , ,test])=>!test||test.test(r.tech));
 const scopes=[];
 if(r.requirements.builder_tag||r.requirements.builder_skill||r.requirements.no_builder_skill)scopes.push('character');
 if(r.gates.some(g=>/UM_CONFIG|GetModConfigData|WATHGRITHR_REWORK/.test(g)))scopes.push('config');
 if(r.file.endsWith('recipes_ia.lua'))scopes.push('compat');
 if(!scopes.length&&!r.gates.length&&!r.requirements.testfn&&!r.requirements.nounlock&&!r.requirements.station_tag)scopes.push('general');
 return {...r,type,scopes,anchor:'recipe-'+r.id.replace(/[^a-z0-9_-]/gi,'-')+'-'+r.line,
  title:itemName(r.product),materialText:r.ingredients.map(i=>itemName(i.id)+' '+i.id+' × '+i.amount).join('、')};
});
const recipeGroups=recipeTypes.map(([type,name,color])=>({id:'recipes-'+type,type,name,color,rows:recipeEntries.filter(r=>r.type===type)}))
 .filter(g=>g.rows.length);
const newItems=itemGroups.flatMap(group=>group.ids.map(id=>{
 const article=group.links?.[id]??group.article;
 const recipe=recipeEntries.find(r=>r.product===id);
 const primaryArticle=id==='wathgrithr_shield_dreadstone'||id==='beakbasher';
 const variant=articleByVariantPrefab.get(id);
 const href=variant?variant.id+'.html':primaryArticle?article:recipe?'recipes.html#'+recipe.anchor:article;
 return {id:'item-'+id,prefab:id,category:'new-items',title:itemName(id),href,primaryArticle,recipe,
  summary:recipe&&!primaryArticle&&!variant?'查看配方 · '+techName(recipe.tech):'查看相关玩法',group:group.title};
}));
const newItemByPrefab=new Map(newItems.map(item=>[item.prefab,item]));
const primaryItemCards=[
 ...newItems.filter(item=>item.primaryArticle).map(item=>({...item,id:item.href.replace('.html','')})),
 ...[...articleByPrefab].map(([prefab,a])=>({id:a.id,prefab,category:a.category,title:a.title,href:a.id+'.html',summary:a.summary,legacyId:newItemByPrefab.get(prefab)?.id})),
];
const primaryItemIds=new Set(primaryItemCards.map(item=>item.id));
const changedRecipeIds=new Set(['ice','shroom_skin','transmute_monstermeat','hermitshop_bootleg']);
const changedItems=recipeEntries.filter(r=>changedRecipeIds.has(r.id)).map(r=>({
 id:r.anchor,prefab:r.product,category:'items',title:r.title,href:'recipes.html#'+r.anchor,
 summary:'原有物品 · 新配方或兑换',
}));
const extraEntries=[...changedItems,...newItems.filter(item=>!item.primaryArticle&&!articleByPrefab.has(item.prefab))];
const newItemsHref='index.html?category=new-items#encyclopedia';
const articleItems={
 gemology:['um_gemologyforge','um_magnifier_purplegem','um_gemologypurplegem2','um_gemology_geode_blue','um_gemology_pouch'],
 wixie:['slingshot_gnasher','slingshot_matilda','slingshot_jessie','slingshot_claire'],
 winona:['winona_toolbox','winona_upgradekit_electrical','powercell'],
 winky:['uncompromising_winkyhomeburrow'], 'rat-raids':['ratpoisonbottle','rat_tail'],
 snowstorms:['snowgoggles','um_hat_rime'],'summer-dragonflies':['glass_scales','armor_glassmail'],
 'dreadstone-shield':['wathgrithr_shield_dreadstone'],'beak-basher':['beakbasher'],
};
const recipeSearch=r=>[r.title,r.id,r.product,names[r.product]?.en,r.materialText,techName(r.tech),r.tech,...r.gates].filter(Boolean).join(' ');
const requirements={builder_tag:'制作者标签',builder_skill:'必需技能',no_builder_skill:'排斥技能',station_tag:'制作站标签',nounlock:'在对应科技站使用',testfn:'有额外位置或制作者检查'};
const table=(headers,rows,label,css='')=>`<div class="table-wrap${css?' '+css:''}" tabindex="0" role="region" aria-label="${esc(label)}"><table><thead><tr>${headers.map(h=>`<th scope="col">${esc(h)}</th>`).join('')}</tr></thead><tbody>${rows.join('')}</tbody></table></div>`;
const sourceList=a=>a.sources.map(s=>`<li>${s.kind==='cn'?'汉化补丁':'测试版'} · ${code(s.file+':'+s.line)}</li>`).join('');
const sectionId=(a,i)=>a.id+'-s'+(i+1);
const guideRowId=prefab=>'gem-'+prefab.replace(/^um_gemology/,'');
const guideAnchors=guide=>guide?.rowAnchors??guide?.prefabs?.map(guideRowId)??[];
const guideCellText=cell=>Array.isArray(cell)?cell.map(({label,detail})=>[label,detail].filter(Boolean).join(' ')).join(' '):cell;
const guideCell=cell=>Array.isArray(cell)?`<ul class="guide-cell-links">${cell.map(({href,label,detail})=>`<li>${link(href,label)}${detail?` <small>${esc(detail)}</small>`:''}</li>`).join('')}</ul>`:esc(cell);
function guideTable(s){
 const {headers,rows,prefabs=[],rowLinks=[],style}=s.guide,anchors=guideAnchors(s.guide);
 const hint=headers.length>2?'<p class="guide-table-hint">在窄屏可横滑查看其余列。</p>':'';
 return hint+table(headers,rows.map(([name,...cells],i)=>{
  const prefab=prefabs[i],anchor=anchors[i],related=rowLinks[i];
  return `<tr${anchor?` id="${esc(anchor)}"`:''}><th scope="row">${prefab?artImage(prefab,28):''}${esc(name)}${related?`<small class="guide-row-link">${link(related.href,related.label)}</small>`:''}</th>${cells.map(cell=>`<td>${guideCell(cell)}</td>`).join('')}</tr>`;
 }),s.title,['guide-table',style].filter(Boolean).join(' '));
}
function sectionHTML(s,i,a,continuous){
 const id=sectionId(a,i),heading=continuous?3:2;
 const guide=s.guide?(continuous?`<p>${link(articleHref(a)+'#'+id,'查看完整表格 →')}</p>`:guideTable(s)):'';
 const links=s.links?.map(({href,label})=>`<li>${link(continuous&&href.startsWith('#')?articleHref(a)+href:href,label)}</li>`).join('');
 return `<section class="article-section" id="${id}"><h${heading}><a href="#${id}">${esc(s.title)}<span class="anchor-hash">#</span></a></h${heading}><p>${esc(s.text)}</p>${links?`<ul class="section-related-links">${links}</ul>`:''}${guide}</section>`;
}
function configStrip(a){
 const rows=a.configs.map(key=>configByKey.get(key));
 const items=(articleItems[a.id]??[]).map(id=>({prefab:id,label:itemName(id),href:articleByPrefab.has(id)?articleHref(articleByPrefab.get(id)):newItemByPrefab.get(id).href}));
 const related=(a.related??[]).map(({id,label})=>{
  const article=articleById.get(id);
  return {prefab:article.icon??article.prefab,label,href:articleHref(article)};
 });
 const recipes=recipeEntries.filter(r=>r.product===a.prefab);
 const relatedLinks=(label,links)=>links.length?`<div class="beta-related-art"><strong>${label}</strong><div>${links.map(({href,prefab,label})=>`<a href="${esc(href)}">${artImage(prefab,28)}<span>${esc(label)}</span></a>`).join('')}</div></div>`:'';
 return (rows.length?`<details class="article-config"><summary>相关配置 <span>${rows.length}</span></summary>${table(['配置','默认档位'],rows.map(c=>`<tr><td>${configLink(c)}</td><td>${defaultText(c)}</td></tr>`),'相关配置')}</details>`:'')+
 relatedLinks('相关物品',items)+relatedLinks(a.id==='cooking-guide'?'锅料理食谱':'相关词条',related)+
 relatedLinks('制作材料',recipes.map(r=>({href:'recipes.html#'+r.anchor,label:r.file.endsWith('recipes_ia.lua')?'岛屿冒险配方':techName(r.tech)})))+
 `<details class="source-note"><summary>版本与核对来源</summary><p>测试版 v${esc(auditedVersion)} · 汉化 ${esc(auditedCnVersion)}</p><ul>${sourceList(a)}</ul></details>`;
}
const site={
 id:'um-beta',name:'永不妥协测试版',subtitle:'Uncompromising Mode · Public Beta',home:'index.html',settings:'configs.html',
 sources:'sources.html',hub:'../index.html',assets:'../',mark:artwork['cover-icon'].path,extraStyles:'beta.css',
featured:[],configFilterLabel:'筛选配置类别',configAllLabel:'全部类别',
 routes:[['../index.html','模组 Wiki 总览',''],['index.html','测试版百科','index'],['configs.html','配置大全','settings'],['recipes.html','制作与兑换','recipes'],[newItemsHref,'新增物品',''],['sources.html','版本与来源','sources']],
 recipeNav:recipeGroups.map(g=>({...g,count:g.rows.length})),
};
const badge=(label,color='#7b526d')=>`<span class="tag" style="--tag-color:${color}"><i></i>${esc(label)}</span>`;
const count={articles:entryArticles.length,configs:configs.length,choices:configs.reduce((n,c)=>n+c.options.length,0)};
const articleHref=a=>a.id+'.html';

export async function buildHub(out,tempered,icon,temperedIndex){
 const dir=path.join(out,'um-beta');
 await fs.mkdir(dir,{recursive:true});
 const seen=new Set();
 if(newItems.length!==newItemByPrefab.size||newItems.some(item=>!artwork[item.prefab]?.workshop||!item.href))throw Error('Missing or duplicate Public Beta item link or artwork');
 for(const a of entryArticles){
  if(seen.has(a.id)||!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(a.id)||!categories.some(c=>c.id===a.category)||!a.sources.length||a.configs.some(key=>!configByKey.has(key))||a.related?.some(({id})=>!articleById.has(id)))throw Error('Invalid Beta article '+a.id);
  for(const s of a.sources){
   const src=snapshot.sourceFiles[(s.kind??'beta')+'/'+s.file];
   if(!src?.citations?.includes(s.line))throw Error(`Unverified source citation in ${a.id}: ${s.file}:${s.line}. Run extract.mjs against the reviewed Beta source.`);
  }
  seen.add(a.id);
 }
 for(const file of await fs.readdir(dir,{withFileTypes:true})){
  if(file.isFile()&&file.name.endsWith('.html'))await fs.unlink(path.join(dir,file.name));
 }
 await buildPortal(out,[
  {id:'tempered',name:'淬炼之季',href:'tempered.html',cover:'assets/workshop-cover.png',version:'v'+tempered.version,
   summary:'暗影世界、战斗险境与角色改动。',source:'about.html',
   links:[['directory.html','分类索引'],['settings.html','配置大全']]},
  {id:'beta',name:'永不妥协测试版',href:'um-beta/index.html',cover:artwork.cover.path,version:'Public Beta · v'+betaVersion,
   summary:'测试版角色、宝石学、季节与配方。',source:'um-beta/sources.html',
   links:[['um-beta/configs.html','配置大全'],['um-beta/'+newItemsHref,'新增物品'],['um-beta/recipes.html','制作与兑换']]},
 ],icon);

 const meta={version:betaVersion,workshop};
 const ui=createUI({articles:entryArticles,configs:configs.map(c=>({...c,mode:groupByKey.get(c.key).mode})),groups:configGroups,
  categories,meta,esc,icon,sectionHTML,configStrip,counts:count,site,extraEntries,
  articleIcon:a=>{const art=artFor(a.icon??a.prefab??articleIcons[a.id]);return art?'../'+art.path:null;}});
 const render=(file,current,title,desc,body,toc)=>fs.writeFile(path.join(dir,file),ui.shell(current,title,desc,body,toc));
 const titleBlock=(eyebrow,title,text)=>`<div class="wiki-heading"><div><span class="eyebrow">${eyebrow}</span><h1>${esc(title)}</h1><p>${text}</p></div></div>`;
 const startLink=(href,img,title,desc)=>`<a class="start-link" href="${href}">${artImage(img,38)}<span><strong>${title}</strong><small>${desc}</small></span>${icon('arrow',16)}</a>`;
 const itemCards=[...primaryItemCards,...extraEntries].map(item=>`<article class="beta-topic-item" id="entry-${item.id}" data-entry="${item.id}" data-category="${item.category}">${item.legacyId?`<span class="beta-legacy-anchor" id="entry-${item.legacyId}"></span>`:''}<a href="${item.href}">${artImage(item.prefab,44)}<span><strong>${esc(item.title)}</strong><small>${esc(item.summary)}</small></span>${icon('arrow',16)}</a></article>`).join('');
 const welcome=`<section class="wiki-welcome beta-welcome" id="welcome" aria-labelledby="welcome-title"><div class="welcome-topline"><span>UNCOMPROMISING MODE</span><a href="sources.html">Public Beta · v${esc(betaVersion)} ${icon('arrow',12)}</a></div><div class="beta-welcome-copy"><div><p class="eyebrow">中文源码百科</p><h1 id="welcome-title">永不妥协测试版</h1><p class="welcome-copy">查阅首领打法、季节威胁、角色改动和宝石学，也可以按房间配置找默认值，或按材料查制作与兑换。</p></div><img class="beta-cover" src="../${artwork.cover.path}" width="${artwork.cover.width}" height="${artwork.cover.height}" alt="永不妥协测试版工坊封面" fetchpriority="high"></div>${reviewedNotice}<div class="start-paths">${startLink(newItemsHref,'um_gemologyforge','新增物品','从物品直达配方或玩法')}${startLink('configs.html','gears','配置大全','分类核对房间与客户端选项')}${startLink('recipes.html','blueprint','制作与兑换','按科技、材料和使用条件查找')}</div><div class="welcome-foot"><span>常查 ${link('creature-guide.html','生物与首领')} · ${link('index.html?category=characters#encyclopedia','角色')} · ${link('gemology.html','宝石学')} · ${link('cooking-guide.html','料理速查')} · ${link('snowstorms.html','暴风雪')}</span><span>${count.articles} 篇词条 · ${count.configs} 项配置 · ${recipeEntries.length} 条配方</span></div></section>`;
 await render('index.html','index','百科全览','永不妥协公开测试版的中文词条、配置与配方索引。',welcome+ui.categoryNav()+'<div class="empty-state" id="entry-empty" hidden>没有匹配的词条，请调整搜索或分类。</div>'+ui.ordered.filter(a=>!primaryItemIds.has(a.id)).map(a=>ui.articleHTML(a,true)).join('')+`<div class="beta-topic-items">${itemCards}</div>`);
 for(const a of entryArticles){
  const category=categories.find(c=>c.id===a.category);
  const peers=ui.ordered.filter(p=>p.category===a.category);
  const i=peers.indexOf(a);
  const adjacent=`<nav class="adjacent-entries" aria-label="继续阅读">${[peers[i-1],peers[i+1]].map((p,i)=>p?`<a href="${articleHref(p)}"><small>${i?'下一篇':'上一篇'}</small><strong>${esc(p.title)}</strong></a>`:'<span></span>').join('')}</nav>`;
  const crumbs=`<nav class="breadcrumbs" aria-label="当前位置">${link('index.html','测试版百科')}<span>/</span>${link('index.html?category='+category.id+'#encyclopedia',category.name)}<span>/</span><span>${esc(a.title)}</span></nav>`;
  const toc=`<aside class="toc" aria-label="本页目录"><h2>本页目录</h2><nav>${a.sections.map((s,i)=>link('#'+sectionId(a,i),s.title)).join('')}</nav>${a.configs.length?`<h2>相关配置</h2><div class="toc-config">${a.configs.map(key=>configLink(configByKey.get(key))).join('')}</div>`:''}</aside>`;
  const bottom=`<div class="article-bottom"><span>按 v${esc(auditedVersion)} 核对</span>${link('index.html#entry-'+a.id,'回到连续阅读 →')}</div>`;
  await render(articleHref(a),a.id,a.title,a.summary,crumbs+reviewedNotice+ui.articleHTML(a)+adjacent+bottom,toc);
 }
 const configModeTabs=`<div class="config-mode-tabs"><button data-config-mode="all" aria-pressed="true">全部配置</button>${filterModes.map(mode=>`<button data-config-mode="${esc(mode)}" aria-pressed="false">${esc(mode)}</button>`).join('')}</div>`;
 const configTools=`<section class="config-filter-panel" aria-label="配置筛选">${configModeTabs}<div class="settings-tools"><span id="config-status" role="status"></span><div><select id="config-state" aria-label="筛选默认状态"><option value="all">全部默认状态</option><option value="on">默认开启</option><option value="off">默认关闭</option><option value="value">其他默认档位</option><option value="notes">有相关词条</option></select><button id="expand-configs">全部展开</button><button id="collapse-configs">全部收起</button></div></div></section>`;
 const configIntro=titleBlock('BETA CONFIGURATION','配置大全',`核对 v${esc(betaVersion)} 的 ${count.configs} 项配置。可按玩法类别和默认状态筛选，也能用中文、英文或配置键定位。`)+configTools;
 const configSections=configGroups.map(g=>`<section class="config-group" data-config-group="${g.id}"><h2 id="${g.id}">${g.mode!==g.name?`<span class="config-mode-label">${esc(g.mode)}</span>`:''}${esc(g.name)}<small>${g.configs.length} 项</small></h2>${g.configs.map(c=>{
  const related=entryArticles.filter(a=>a.configs.includes(c.key));
  const options=table(['界面选项','存档值'],c.options.map(o=>`<tr${o.value===c.default?' class="default-row"':''}><td>${esc(modeLabel(o))}${o.value===c.default?' <span class="default-badge">默认</span>':''}</td><td>${val(o.value)}</td></tr>`),'可选档位');
  const id=configId(c.key);
  return `<details class="config-card" id="${id}" data-config="${id}" data-mode="${esc(g.mode)}" data-default="${c.default===true?'on':c.default===false?'off':'value'}"><summary><span class="config-summary-copy"><span class="config-title">${esc(configName(c))}</span><span class="config-summary-note">${esc(c.title)} · ${c.client?'客户端':'服务器'}</span></span><span class="config-default"><span>默认</span><strong>${esc(modeLabel(standard(c)))}</strong></span></summary><div class="config-content"><p class="config-path">${esc(g.name)} · ${c.client?'客户端':'服务器'} <a href="#${id}" class="config-anchor" aria-label="定位${esc(configName(c))}">#</a></p><h3>可选档位 <span>${c.options.length}</span></h3>${options}${related.length?`<div class="related-links"><span>玩法解析</span>${related.map(a=>link(articleHref(a),a.title)).join('')}</div>`:''}<details class="source-note"><summary>配置键与核对来源</summary><p>${code(c.key)} · ${code('modinfo.lua:'+c.line)}</p></details></div></details>`;
 }).join('')}</section>`).join('');
 const presets=preset.map(p=>`<details class="config-card"><summary><span class="config-title">${esc(p.title)}</span><span class="config-default">${p.changes.length} 条覆盖</span></summary><div class="config-content"><p>预设包含独立的覆盖值。「菜单无对应项」标识仅见于预设表的键。</p>${table(['配置','预设值'],p.changes.map(({key,value})=>`<tr><td>${configByKey.has(key)?configLink(configByKey.get(key)):code(key)+' <small>菜单无对应项</small>'}</td><td>${val(value)}</td></tr>`),'预设覆盖值')}<p>${code('modinfo.lua:'+p.line)}</p></div></details>`).join('');
 await render('configs.html','settings','配置大全','公开测试版的客户端与服务器配置、默认值及档位。',configIntro+'<div class="empty-state" id="config-empty" hidden>没有匹配的设置，请调整搜索或筛选条件。</div>'+configSections+`<section class="config-group beta-presets"><h2>难度预设</h2>${presets}</section>`);
 const recipeTools=`<section class="config-filter-panel" aria-label="配方筛选"><div class="config-mode-tabs"><button data-recipe-type="all" aria-pressed="true">全部配方</button>${recipeGroups.map(g=>`<button data-recipe-type="${g.type}" aria-pressed="false">${g.name}</button>`).join('')}</div><div class="settings-tools"><span id="recipe-status" role="status"></span><div><select id="recipe-scope" aria-label="筛选配方条件"><option value="all">全部制作条件</option>${recipeScope.map(([value,title])=>`<option value="${value}">${title}</option>`).join('')}</select><button id="expand-recipes">全部展开</button><button id="collapse-recipes">全部收起</button></div></div></section>`;
 const recipeRows=recipeGroups.map(g=>`<section class="config-group" id="${g.id}" data-recipe-group="${g.type}"><h2>${g.name}<small data-recipe-count>${g.rows.length} 条</small></h2>${g.rows.map(r=>{
  const material=r.ingredients.length?table(['材料','数量'],r.ingredients.map(i=>`<tr><td>${itemLabel(i.id)} <small>${code(i.id)}</small></td><td>${esc(i.amount)}</td></tr>`),'制作材料'):'<p>无常规物品材料。</p>';
  const gates=r.gates.map(g=>`<li>${code(g)}</li>`).join('');
  const props=Object.entries(r.requirements).filter(([,value])=>value!==false).map(([key,value])=>`<li>${requirements[key]}${value===true?'':' · '+code(value)}</li>`).join('');
  const article=articleByPrefab.get(r.product)??articleByVariantPrefab.get(r.product);
  return `<details class="config-card recipe-card" id="${r.anchor}" data-recipe data-find="${esc(recipeSearch(r))}" data-scopes="${r.scopes.join(' ')}"><summary><span class="beta-recipe-product">${artImage(r.product,34,'recipe-product-icon')}<span class="config-summary-copy"><span class="config-title">${esc(r.title)}</span><span class="config-summary-note">${esc(r.id)}</span></span></span><span class="config-default"><span>科技</span><strong>${esc(techName(r.tech))}</strong></span></summary><div class="config-content"><div class="beta-recipe-tags">${r.scopes.filter(s=>s!=='general').map(s=>badge(recipeScope.find(([value])=>value===s)[1],g.color)).join('')}</div><h3>制作材料</h3>${material}<p>产量 ${typeof r.count==='number'?esc(r.count):'取决于 '+code(r.count)} · 科技 ${code(r.tech)}</p>${gates||props?`<h3>注册与制作条件</h3><ul>${gates}${props}</ul>`:''}${article?`<p>${link(articleHref(article),'查看物品用法 →')}</p>`:''}<details class="source-note"><summary>配方 ID 与核对来源</summary><p>${code(r.id)}${r.product!==r.id?' · 产物 '+code(r.product):''} · ${code(r.file+':'+r.line)}${r.overrides?' · 属性覆盖行 '+esc(r.overrides.join('、')):''}</p></details></div></details>`;
 }).join('')}</section>`).join('');
 const recipeIntro=titleBlock('BETA CRAFTING','制作与兑换',`收录 v${esc(betaVersion)} 的 ${recipeEntries.length} 条制作与兑换注册。按科技分组，也可按角色、配置或兼容条件筛选。`);
 await render('recipes.html','recipes','制作与兑换','公开测试版源码中的制作、兑换与兼容注册。',recipeIntro+recipeTools+'<div class="empty-state" id="recipe-empty" hidden>没有匹配的配方，请调整材料搜索或制作条件。</div>'+recipeRows+`<section class="wiki-entry"><h2>单独核对的动态配方</h2><p>温奇的定居鼠穴消耗饥饿，见 ${link('winky.html','温奇')}。其余动态注册和后续覆盖需结合实现核对。</p><ul>${snapshot.skipped.map(r=>`<li>${code(r.id??'动态 ID')} · ${code(r.file+':'+r.line)}</li>`).join('')}</ul></section>`);
 await render('sources.html','sources','版本与来源','永不妥协测试版和社区汉化补丁的版本及维护范围。',titleBlock('SOURCE NOTES','版本与来源',`源码快照 v${esc(betaVersion)} · 社区汉化 ${esc(cnVersion)} · 正文核对 v${esc(auditedVersion)}`)+reviewedNotice+
 `<section class="wiki-entry"><h2>资料来源</h2><ul><li>${link(workshop,'Steam 工坊 · Uncompromising Mode: Public Beta')} · The Uncomp Dev Team</li><li>${link(translation,'Steam 工坊 · 永不妥协全汉化 - 测试版专供')} · 郎溪小杰哥、不堪白昼、不笑猫、去码头整点薯条</li><li>${link('https://github.com/LeeMo123/Hanization_um_beta','社区汉化项目源码')}</li><li>${link('https://uncompromisingmode.wiki.gg/','Uncompromising Mode 英文 Wiki')}</li><li>${link('https://qineko.wiki/umpb/','QiNeko Wiki · 永不妥协 BETA')} · 参考导航与关联词条的组织方式</li></ul><h2>覆盖范围</h2><p>本分区包含 ${count.articles} 篇源码核对词条、${count.configs} 项实际菜单配置、${recipeEntries.length} 条可解析的制作与兑换注册。配方记录注册时的材料、科技和可解析条件。食谱、运行中变动及其余内容在后续复核中补充。</p><p>机制、数值和开关从测试版本体核对。汉化补丁用于术语对照，配置中的中文辅助标题用于与英文菜单互查。封面、角色头像和专属物品缩略图来自工坊测试版资源，原版物品图标来自《饥荒联机版》。</p></section>`);
 const legacyLinks=newItems.map(item=>`<li><a id="${item.id}" href="${item.href}">${esc(item.title)}</a></li>`).join('');
 await render('items.html','legacy-items','新增物品','旧图鉴链接会前往对应的配方或玩法。',
  `<section class="wiki-entry"><h1>新增物品</h1><p><a id="legacy-items-home" href="${newItemsHref}">浏览全部新增物品</a></p><ul>${legacyLinks}</ul></section><script src="legacy-items.js" defer></script>`);
 const index=[
  ...entryArticles.map(a=>{
   const art=artFor(a.icon??a.prefab??articleIcons[a.id]);
   return {id:a.id,kind:'article',href:articleHref(a),title:a.title,summary:a.summary,category:categories.find(c=>c.id===a.category).name,topic:a.category,aliases:a.aliases,
    text:a.sections.flatMap(s=>[s.title,s.text,...(s.guide?.rows.flat().map(guideCellText)??[])]).join(' '),image:art?'../'+art.path:undefined,featured:true};
  }),
  ...configs.map(c=>{const group=groupByKey.get(c.key),related=entryArticles.filter(a=>a.configs.includes(c.key));return {
   id:configId(c.key),kind:'config',href:'configs.html#'+configId(c.key),title:configName(c),category:group.mode+' / '+group.name,summary:c.title+' · 默认 '+modeLabel(standard(c)),keywords:c.key,
   text:[...c.options.map(modeLabel),...related.flatMap(a=>[a.title,...a.aliases])].join(' '),status:related.length?'linked':'',
  };}),
  ...recipeEntries.map(r=>({id:r.anchor,kind:'recipe',href:'recipes.html#'+r.anchor,title:r.title,category:techName(r.tech),summary:r.materialText||'无常规物品材料',topic:changedRecipeIds.has(r.id)?'items':undefined,keywords:r.id,text:recipeSearch(r),image:artFor(r.product)?'../'+artFor(r.product).path:undefined})),
  ...newItems.map(item=>({id:item.id,kind:'item',href:item.href,title:item.title,topic:item.category,category:item.group,
   summary:item.summary,keywords:item.prefab,text:names[item.prefab]?.en??'',image:'../'+artwork[item.prefab].path})),
 ];
 const jumps=entryArticles.flatMap(a=>(a.searchJumps??[]).map(jump=>{
  const i=jump.section?a.sections.findIndex(s=>s.title===jump.section):-1;
  const row=jump.anchor??(jump.prefab&&guideRowId(jump.prefab));
  if(jump.section&&i<0||row&&!guideAnchors(a.sections[i]?.guide).includes(row))throw Error('Unknown Beta search target '+jump.section);
  const art=artFor(jump.prefab);
  return {id:a.id+'-jump-'+(row||i+1),kind:'article',href:articleHref(a)+(i<0?'':'#'+(row||sectionId(a,i))),
   title:jump.title??(jump.section?a.title+' · '+jump.section:a.title),category:categories.find(c=>c.id===a.category).name,
   aliases:jump.terms,summary:jump.summary??(i<0?a.summary:a.sections[i].text),image:art?'../'+art.path:undefined,text:'',jump:true};
 }));
 const globalIndex=[
  ...temperedIndex.map(a=>({...a,wiki:'tempered'})),
  ...[...jumps,...index].map(a=>({...a,wiki:'um-beta',href:'um-beta/'+a.href,image:a.image?.slice(3)})),
 ];
 await fs.writeFile(path.join(out,'global-search-index.js'),`window.WIKI_GLOBAL_INDEX=${JSON.stringify(globalIndex).replaceAll('<','\\u003c')};\n`);
 await fs.writeFile(path.join(dir,'search-index.js'),`window.WIKI_INDEX=${JSON.stringify(index).replaceAll('<','\\u003c')};\n`);
 await fs.copyFile(new URL('./legacy-items.js',import.meta.url),path.join(dir,'legacy-items.js'));
 await fs.copyFile(new URL('./filter.js',import.meta.url),path.join(dir,'filter.js'));
 await fs.copyFile(new URL('./beta.css',import.meta.url),path.join(dir,'beta.css'));
 console.log(`Built Wiki hub and ${count.articles} Beta articles, ${count.configs} Beta configs, ${recipeEntries.length} recipe rows.`);
}
