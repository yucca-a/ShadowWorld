(() => {
 const dialog=document.querySelector('#search-dialog');
 if(!dialog)return;
 const input=dialog.querySelector('#search-input');
 const results=dialog.querySelector('#search-results');
 const status=dialog.querySelector('#search-meta');
 const branch=dialog.querySelector('#search-wiki');
 const kinds=[...dialog.querySelectorAll('[data-kind]')];
 const indexUrl=new URL(dialog.dataset.index,location.href);
 const wikiNames={tempered:'淬炼之季','um-beta':'永不妥协测试版'};
 const kindNames={article:'词条',config:'配置',recipe:'配方',item:'新增物品'};
 const normalize=text=>String(text??'').normalize('NFKC').toLowerCase().replace(/\s+/g,' ').trim();
 const escape=text=>String(text??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 function mark(text,needle){
  text=String(text??'');
  const at=needle?text.toLowerCase().indexOf(needle.toLowerCase()):-1;
  if(at<0)return escape(text);
  return escape(text.slice(0,at))+'<mark>'+escape(text.slice(at,at+needle.length))+'</mark>'+escape(text.slice(at+needle.length));
 }
 function prepare(entries,base,wiki){
  return entries.map(entry=>({...entry,wiki:entry.wiki??wiki,url:new URL(entry.href,base).href,imageUrl:entry.image?new URL(entry.image,base).href:null,
   titleKey:normalize(entry.title),summaryKey:normalize(entry.summary),keywordsKey:normalize(entry.keywords),aliasesKey:(entry.aliases??[]).map(normalize),
   hay:normalize([entry.title,entry.summary,entry.keywords,entry.text,entry.category,...(entry.aliases??[])].join(' ')),
  }));
 }
 let entries=[],localPrepared=false,globalPrepared=false;
 let kind='all',selected=-1,loading=false,failed=false,loadStarted=false,pendingEnter=null;
 let renderTimer=0,composing=false,renderedQuery=null;
 function cancelRender(){if(renderTimer)clearTimeout(renderTimer);renderTimer=0;}
 function scheduleRender(){
  cancelRender();
  if(!dialog.open)return;
  renderTimer=setTimeout(()=>{renderTimer=0;if(dialog.open&&!composing)render();},100);
 }
 function useLocalIndex(){
  if(localPrepared||globalPrepared)return;
  entries=prepare(window.WIKI_INDEX??[],location.href,document.body.dataset.wiki);
  localPrepared=true;
 }
 function useGlobalIndex(){
  if(!globalPrepared){entries=prepare(window.WIKI_GLOBAL_INDEX,indexUrl);globalPrepared=true;}
  failed=false;
 }
 function finishLoading(){
  const pending=pendingEnter;
  pendingEnter=null;
  if(!dialog.open||composing)return;
  render();
  if(pending?.query!==input.value)return;
  const links=[...results.querySelectorAll('a')];
  (links.find(a=>a.href===pending.url)??links[0])?.click();
 }
 function loadIndex(){
  if(window.WIKI_GLOBAL_INDEX){useGlobalIndex();return;}
  if(loadStarted)return;
  loadStarted=true;
  if(failed)useLocalIndex();
  loading=true;failed=false;
  const script=document.createElement('script');
  script.src=indexUrl.href;
  script.onload=()=>{
   loading=false;
   if(window.WIKI_GLOBAL_INDEX){if(dialog.open)useGlobalIndex();}
   else {failed=true;loadStarted=false;script.remove();if(dialog.open)useLocalIndex();}
   finishLoading();
  };
  script.onerror=()=>{loading=false;failed=true;loadStarted=false;script.remove();if(dialog.open)useLocalIndex();finishLoading();};
  document.head.append(script);
 }
 function rank(entry,q,terms){
  const alias=entry.aliasesKey.includes(q);
  if(entry.jump)return alias?1000:0;
  if(!terms.every(term=>entry.hay.includes(term)))return 0;
  return 1+(entry.titleKey===q?90:entry.titleKey.startsWith(q)?48:entry.titleKey.includes(q)?32:0)
   +(alias?82:entry.aliasesKey.some(a=>a.startsWith(q))?24:0)
   +(entry.keywordsKey===q?72:entry.keywordsKey.includes(q)?14:0)
   +(entry.summaryKey.includes(q)?7:0);
 }
 function render(){
  cancelRender();
  if(!dialog.open)return;
  renderedQuery=input.value;
  const raw=input.value.trim();
  const q=normalize(raw);
  const terms=q.split(' ').filter(Boolean);
  const seen=new Set();
  const candidates=entries.filter(e=>(kind==='all'||kind===e.kind||kind==='item'&&e.topic==='new-items')&&(branch.value==='all'||branch.value===e.wiki));
  const ranked=q?candidates.map(e=>({e,score:rank(e,q,terms)})).filter(r=>r.score).sort((a,b)=>b.score-a.score).map(r=>r.e):
   candidates.filter(e=>!e.jump&&(kind!=='all'||e.featured||['getting-started','settings-guide','combat','armor','world-exchange','eyeturret','upgrade-frost-staff'].includes(e.id)));
  const unique=ranked.filter(e=>!seen.has(e.url)&&seen.add(e.url));
  const shown=unique.slice(0,q?70:16);
  status.textContent=loading?'正在载入两套 Wiki 的索引…':failed?(entries.length?'全站索引暂时无法载入，显示当前百科的结果。':'全站索引暂时无法载入，请关闭后重新打开搜索。'):
   q?`找到 ${unique.length} 个结果${unique.length>70?' · 先显示前 70 条':''}`:'可搜索词条、章节、配置键、产物或材料';
  results.innerHTML=shown.length?shown.map(e=>{
   let snippet=e.summary;
   if(e.jump)snippet='直达 · '+snippet;
   else if(e.aliasesKey.includes(q))snippet='相关名称 · '+e.aliases.join('、');
   else if(q&&!e.summaryKey.includes(q)){
    const text=String(e.text??'');
    const hit=text.toLowerCase().indexOf(raw.toLowerCase());
    if(hit>=0)snippet=(hit>24?'…':'')+text.slice(Math.max(0,hit-24),hit+105)+'…';
   }
   return `<a class="search-result" href="${escape(e.url)}"><span class="result-category">${escape([wikiNames[e.wiki],kindNames[e.kind],e.category].filter(Boolean).join(' · '))}</span><strong>${e.imageUrl?`<img class="search-item-icon" src="${escape(e.imageUrl)}" alt="" width="20" height="20" loading="lazy">`:''}${mark(e.title,raw)}</strong><p>${mark(String(snippet??'').slice(0,156),raw)}</p><span class="result-enter" aria-hidden="true">↵</span></a>`;
  }).join(''):(loading?'':'<div class="empty-state">没有找到匹配的内容，试试简称、配置键或材料名。</div>');
  selected=-1;
 }
 function open(){
  document.dispatchEvent(new Event('wiki-search-open'));
  if(!dialog.open)dialog.showModal();
  loadIndex();
  render();
  input.focus();
 }
 document.querySelectorAll('[data-search]').forEach(button=>button.addEventListener('click',open));
 const headerSearch=document.querySelector('#header-search');
 function openFromHeader(){input.value=headerSearch.value;open();}
 headerSearch?.addEventListener('input',event=>{if(!event.isComposing)openFromHeader();});
 headerSearch?.addEventListener('compositionend',()=>{if(headerSearch.value.trim())openFromHeader();});
 headerSearch?.addEventListener('keydown',event=>{
  if(event.key==='Enter'&&!event.isComposing){event.preventDefault();openFromHeader();}
 });
 dialog.querySelector('#search-close').addEventListener('click',()=>dialog.close());
 input.addEventListener('compositionstart',()=>{composing=true;pendingEnter=null;cancelRender();});
 input.addEventListener('compositionend',()=>{composing=false;pendingEnter=null;scheduleRender();});
 input.addEventListener('input',event=>{
  pendingEnter=null;
  if(composing||event.isComposing){cancelRender();return;}
  scheduleRender();
 });
 branch.addEventListener('change',()=>{pendingEnter=null;render();});
 kinds.forEach(button=>button.addEventListener('click',()=>{
  pendingEnter=null;
  kind=button.dataset.kind;
  kinds.forEach(item=>{item.classList.toggle('active',item===button);item.setAttribute('aria-pressed',String(item===button));});
  render();input.focus();
 }));
 dialog.addEventListener('close',()=>{pendingEnter=null;composing=false;cancelRender();});
 dialog.addEventListener('click',event=>{
  if(event.target!==dialog)return;
  const r=dialog.getBoundingClientRect();
  if(event.clientX<r.left||event.clientX>r.right||event.clientY<r.top||event.clientY>r.bottom)dialog.close();
 });
 results.addEventListener('click',event=>{if(event.target.closest('a'))dialog.close();});
 dialog.addEventListener('keydown',event=>{
  if(event.isComposing||composing||event.target===branch)return;
  if((event.key==='ArrowDown'||event.key==='ArrowUp'||event.key==='Enter')&&
    (renderTimer||renderedQuery!==input.value))render();
  const links=[...results.querySelectorAll('a')];
  if(event.key==='ArrowDown'||event.key==='ArrowUp'){
   event.preventDefault();
   if(!links.length)return;
   selected=selected<0?(event.key==='ArrowDown'?0:links.length-1):
    (selected+(event.key==='ArrowDown'?1:-1)+links.length)%links.length;
   links.forEach((a,i)=>a.classList.toggle('selected',i===selected));
   links[selected].scrollIntoView({block:'nearest'});
  }else if(event.key==='Enter'&&event.target===input){
   event.preventDefault();
   if(loading)pendingEnter={query:input.value,url:links[selected]?.href};
   else links[Math.max(0,selected)]?.click();
  }
 });
 document.addEventListener('keydown',event=>{
  const active=document.activeElement;
  const typing=/INPUT|TEXTAREA|SELECT/.test(active?.tagName)||active?.isContentEditable;
  if(((event.ctrlKey||event.metaKey)&&event.key.toLowerCase()==='k')||(event.key==='/'&&!typing)){
   event.preventDefault();open();
  }
 });
})();
