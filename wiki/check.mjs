import fs from 'node:fs/promises';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const root=fileURLToPath(new URL('./dist/',import.meta.url));
const all=await fs.readdir(root,{recursive:true});
const html=all.filter(f=>f.endsWith('.html'));
const pages=new Map(await Promise.all(html.map(async f=>[f.replaceAll('\\','/'),await fs.readFile(path.join(root,f),'utf8')])));
const paths=new Set(all.map(f=>f.replaceAll('\\','/'))),errors=[];let links=0;
function checkLink(file,value){if(/^(https?:|mailto:|data:)/.test(value))return;links++;const url=new URL(value,`https://wiki.example/${file}`),target=decodeURIComponent(url.pathname.slice(1));if(!paths.has(target))errors.push(`${file}: missing ${value}`);if(url.hash&&pages.has(target)&&!pages.get(target).includes(`id="${decodeURIComponent(url.hash.slice(1))}"`))errors.push(`${file}: missing anchor ${value}`);}
for(const [file,text] of pages){const ids=[...text.matchAll(/\bid="([^"]+)"/g)].map(m=>m[1]);if(new Set(ids).size!==ids.length)errors.push(`${file}: duplicate ID`);if((text.match(/<h1(?:\s[^>]*)?>/g)||[]).length!==1)errors.push(`${file}: expected one h1`);for(const [,value] of text.matchAll(/(?:href|src)="([^"]+)"/g))checkLink(file,value);}
for(const [file,term,asset] of [
 ['thulecite-club.html','远古铥矿盔甲','armorruins'],
 ['thulecite-club.html','铥矿','thulecite'],
 ['equipment-repair.html','铥矿甲','armorruins'],
 ['equipment-repair.html','金块','goldnugget'],
 ['frost-shrine.html','冰','ice'],
 ['role-wormwood.html','西瓜帽','watermelonhat'],
 ['role-wormwood.html','胡萝卜鼠诱饵甲','armor_carrotlure'],
 ['dried-vegetables.html','西瓜干','watermelon'],
 ['trap.html','草','cutgrass'],
 ['trap.html','树枝','twigs'],
 ['eyeturret.html','龙鳞皮','dragon_scales'],
 ['eyeturret.html','蘑菇皮','shroom_skin'],
 ['frost-core.html','寒霜之祠蓝图','blueprint'],
 ['frost-core.html','普通出逃腿靴','bootleg'],
]){
 const label=`>${term.slice(0,-1)}<span class="icon-tail">${term.slice(-1)}`;
 if(!pages.get(file)?.includes(`${label}<img class="inline-icon" src="assets/icons/${asset}.png"`)){
  errors.push(`${file}: incorrect or missing icon for ${term}`);
 }
}
for(const file of ['app.js','theme.js','search.js','search-index.js','hub.js','legacy-home.js','um-beta/filter.js','um-beta/legacy-items.js'])new vm.Script(await fs.readFile(path.join(root,file),'utf8'),{filename:file});
const portal=pages.get('index.html');
for(const href of ['tempered.html','um-beta/index.html']){
 if(!portal?.includes(`class="hub-library-entry" href="${href}"`))errors.push('Missing clickable Wiki cover for '+href);
}
if(!portal?.includes('id="header-search"')||!portal.includes('data-hub-theme'))errors.push('Missing portal search or theme control');
const beta=JSON.parse(await fs.readFile(new URL('./um-beta/snapshot.json',import.meta.url),'utf8'));
for(const [file,marker] of [['index.html','href="tempered.html"'],['index.html','href="um-beta/index.html"'],['tempered.html','data-page="index"'],['um-beta/index.html',beta.betaVersion],['um-beta/sources.html',beta.cnVersion]]){
 if(!pages.get(file)?.includes(marker))errors.push('Missing Wiki route or version marker in '+file);
}
for(const [file,pattern,count] of [['um-beta/configs.html',/data-config="/g,beta.configs.length],['um-beta/recipes.html',/data-recipe data-find="/g,beta.recipes.length]]){
 if((pages.get(file)?.match(pattern)||[]).length!==count)errors.push('Beta index coverage mismatch: '+file);
}
const betaIndex={window:{}};
vm.runInNewContext(await fs.readFile(path.join(root,'um-beta/search-index.js'),'utf8'),betaIndex);
const betaResults=betaIndex.window.WIKI_INDEX;
if(new Set(betaResults.map(a=>a.id)).size!==betaResults.length)errors.push('Duplicate Beta search index IDs');
for(const a of betaResults)checkLink('um-beta/index.html',a.href);
if(betaResults.filter(a=>a.kind==='recipe').length!==beta.recipes.length||betaResults.filter(a=>a.kind==='config').length!==beta.configs.length)errors.push('Beta search coverage mismatch');
const betaArt=JSON.parse(await fs.readFile(new URL('./um-beta/artwork.json',import.meta.url),'utf8'));
for(const art of Object.values(betaArt))if(!paths.has(art.path))errors.push('Missing Beta artwork '+art.path);
if(betaResults.filter(a=>a.kind==='item').length!==beta.artworkIds.length)errors.push('Beta item gallery search coverage mismatch');
for(const [file,asset] of [['index.html','assets/um-beta/cover.png'],['um-beta/index.html','../assets/um-beta/cover.png'],['um-beta/wixie.html','../assets/um-beta/wixie.png'],['um-beta/recipes.html','../assets/um-beta/slingshot_gnasher.png'],['um-beta/index.html','../assets/um-beta/um_gemologypurplegem2.png']]){
 if(!pages.get(file)?.includes('src="'+asset+'"'))errors.push('Missing Beta artwork reference in '+file);
}
for(const [file,id,category] of [
 ['tempered.html','world-shadow','world'],['tempered.html','world-seasons','mechanics'],['tempered.html','role-wortox','characters'],
 ['tempered.html','frost-core','new-items'],['tempered.html','frost-core-staff','items'],['tempered.html','frostjaw','creatures'],
 ['um-beta/index.html','snowstorms','world'],['um-beta/index.html','gemology','mechanics'],['um-beta/index.html','thermal-stone','items'],
 ['um-beta/index.html','slingshot-gnasher','new-items'],['um-beta/index.html','um-rice-pudding','new-items'],['um-beta/index.html','winona','characters'],
 ['um-beta/index.html','hooded-widow','creatures'],['um-beta/index.html','widows-grasp','new-items'],
]){
 if(!pages.get(file)?.includes(`data-entry="${id}" data-category="${category}"`))errors.push('Unexpected Wiki topic for '+id);
}
if(!pages.get('um-beta/index.html')?.includes('id="entry-item-slingshot_gnasher"></span><a href="slingshot-gnasher.html"'))errors.push('Missing direct Beta item card link');
if(!pages.get('um-beta/items.html')?.includes('id="item-slingshot_gnasher" href="recipes.html#recipe-slingshot_gnasher-11"'))errors.push('Missing legacy Beta item recipe link');
if(betaResults.find(a=>a.id==='item-slingshot_gnasher')?.href!=='recipes.html#recipe-slingshot_gnasher-11')errors.push('Missing direct Beta item search link');
const globalIndex={window:{}};
vm.runInNewContext(await fs.readFile(path.join(root,'global-search-index.js'),'utf8'),globalIndex);
const globalResults=globalIndex.window.WIKI_GLOBAL_INDEX;
for(const a of globalResults){
 checkLink('index.html',a.href);
 if(a.image)checkLink('index.html',a.image);
}
for(const [term,href] of [['附魔','um-beta/gemology.html#gemology-s2'],['宝石','um-beta/gemology.html'],['宝石升级','um-beta/gemology.html#gemology-s5'],['附魔效果','um-beta/gemology.html#gemology-s6'],['静电琥珀','um-beta/gemology.html#gem-yellowgem2'],['附魔宝石获取','um-beta/gemology.html#gemology-s7'],['静电琥珀获取','um-beta/gemology.html#gem-source-yellowgem2'],['粪便晶洞','um-beta/gemology.html#geode-source-guano'],['料理','um-beta/cooking-guide.html']]){
 if(!globalResults.some(a=>a.jump&&a.href===href&&a.aliases.includes(term)))errors.push('Missing direct search result for '+term);
}
for(const [term,href] of [['Boss','creature-guide.html'],['黑寡妇','hooded-widow.html'],['黑寡妇怎么打','hooded-widow.html#hooded-widow-s3'],['黑寡妇掉落','hooded-widow.html#hooded-widow-s4']]){
 if(!globalResults.some(a=>a.jump&&a.href==='um-beta/'+href&&a.aliases.includes(term)))errors.push('Missing direct search result for '+term);
}
for(const [page,links] of Object.entries({
 'gemology.html':['hooded-widow.html#hooded-widow-s1','widows-grasp.html','ancient-guardian.html#ancient-guardian-s3','geothermite.html','antlion.html','snowmong.html','snaildrakes.html','slurtles.html','rock-lobster.html'],
 'hooded-widow.html':['gemology.html#gemology-s10','widows-grasp.html','widows-head.html'],
 'creature-guide.html':['hooded-widow.html','ancient-guardian.html','crab-king.html','glacial-hound.html'],
})){
 if(links.some(href=>!pages.get('um-beta/'+page)?.includes('href="'+href+'"')))errors.push('Missing creature guide crosslink in '+page);
}
const gemology=pages.get('um-beta/gemology.html');
const hastyTopaz=gemology?.match(/<tr id="gem-yellowgem1">.*?<\/tr>/)?.[0]??'';
for(const effect of ['每分钟 +1 理智','每分钟 +2 理智','每分钟 +4 理智','移速倍率额外 +0.2','移速倍率额外 +0.3','原移速倍率已高于 ×1']){
 if(!hastyTopaz.includes(effect))errors.push('Missing Hasty Topaz effect: '+effect);
}
if(!globalResults.some(a=>a.jump&&a.href==='um-beta/gemology.html#gem-yellowgem1'&&a.aliases.includes('迅疾黄玉移速')))errors.push('Missing Hasty Topaz speed search jump');
for(const [pattern,count] of [[/<tr id="gem-\w+gem[12]"/g,14],[/<tr id="gem-source-/g,14],[/<tr id="geode-source-/g,11],[/class="table-wrap guide-table\b/g,4]]){
 if((gemology?.match(pattern)||[]).length!==count)errors.push('Incomplete Beta gem guide tables: '+pattern);
}
const context={window:{}};vm.runInNewContext(await fs.readFile(path.join(root,'search-index.js'),'utf8'),context);
for(const a of context.window.WIKI_INDEX){checkLink('index.html',a.href);if(!a.text||!a.title)errors.push('Invalid search entry '+a.id);}
for(const [id,aliases] of Object.entries({
 'role-wortox':['小恶魔','恶魔人','恶魔'],
 'role-wormwood':['植物人'],
 'role-wx78':['机器人','WX78'],
})){
 const entry=context.window.WIKI_INDEX.find(a=>a.id===id);
 if(!aliases.every(alias=>entry?.aliases?.includes(alias))||!pages.get(entry?.href)?.includes('class="role-aliases"'))errors.push('Missing character aliases for '+id);
}
const configData=JSON.parse(await fs.readFile(new URL('./data/configs.json',import.meta.url),'utf8'));
for(const page of ['multitool.html','thulecite-club.html','horn-enchant.html']){
 const text=pages.get(page);
 if(!text||/微瑕的犀牛角|破损的犀牛角|微瑕角与破损角/.test(text))errors.push(page+': retired horn variants in the current guide');
}
const coverage=JSON.parse(await fs.readFile(new URL('./coverage.json',import.meta.url),'utf8'));
const settings=pages.get('settings.html');
if((settings.match(/data-config="/g)||[]).length!==configData.configs.length)errors.push('Config coverage mismatch');
const choiceCount=configData.configs.reduce((n,c)=>n+c.options.length,0);
if(coverage.choices!==choiceCount)errors.push('Choice coverage mismatch');
if(coverage.notedSettings!==configData.configs.length)errors.push('Some configurations lack implementation notes');
if(coverage.unlinkedSettings.length)errors.push('Configurations without related articles: '+coverage.unlinkedSettings.join(', '));
if(coverage.itemAudit?.missing.length)errors.push('Items missing source audit: '+coverage.itemAudit.missing.join(', '));
if(coverage.entityAudit?.missing.length)errors.push('Characters/buildings/Bosses missing source audit: '+coverage.entityAudit.missing.join(', '));
if(coverage.lifeAudit?.missing.length)errors.push('Food/creatures missing source audit: '+coverage.lifeAudit.missing.join(', '));
for(const [file,text] of pages)if(/yucca/i.test(text))errors.push(`${file}: personal credit remains`);
if(/yucca/i.test(await fs.readFile(path.join(root,'search-index.js'),'utf8')))errors.push('Search index contains personal credit');
if(context.window.WIKI_INDEX.length!==coverage.articles+coverage.configs)errors.push('Search coverage mismatch');
for(const c of configData.configs){if(!c.options.some(o=>o.value===c.default))errors.push('Default absent '+c.key);}
const modRoot=process.env.WIKI_TEMPERED_SOURCE;
try{const source=await fs.readFile(modRoot?path.join(modRoot,'modinfo.lua'):new URL('../content/modinfo.lua',import.meta.url));if(createHash('sha256').update(source).digest('hex')!==configData.sourceHash)errors.push('Configuration source differs from the published snapshot; check WIKI_TEMPERED_SOURCE or rerun extract-config.py');}catch(e){if(e.code!=='ENOENT'||modRoot)throw e;}
const provenance=JSON.parse(await fs.readFile(new URL('./content-sources.json',import.meta.url),'utf8'));
for(const article of provenance.articles)if(!article.source?.length)errors.push('Missing source reference for '+article.id);
if(modRoot){
 const files=new Set(provenance.articles.flatMap(a=>a.source).filter(file=>file.startsWith('content/')));
 await Promise.all([...files].map(async file=>{
  try{await fs.access(path.join(modRoot,file.slice('content/'.length)));}catch(e){if(e.code!=='ENOENT')throw e;errors.push('Missing published source '+file);}
 }));
}
if(errors.length){console.error([...new Set(errors)].join('\n'));process.exitCode=1;}
else console.log(`PASS: ${html.length} pages; ${links} local links and anchors; ${coverage.configs} settings / ${choiceCount} choices; ${context.window.WIKI_INDEX.length} searchable entries; JavaScript syntax.`);
