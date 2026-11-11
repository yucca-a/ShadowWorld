import fs from 'node:fs/promises';
import path from 'node:path';
import {searchDialog} from './ui.mjs';

const esc=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const moon='<svg class="hub-moon" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20.9 13A9 9 0 0 1 11 3.1 9 9 0 1 0 20.9 13Z"/></svg>';
const sun='<svg class="hub-sun" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="4"/><path d="M12 2v2m0 16v2M2 12h2m16 0h2M5 5l1.5 1.5m11 11L19 19M5 19l1.5-1.5m11-11L19 5"/></svg>';

function libraryTile(library,icon){
 return `<article class="hub-library hub-library-${library.id}">
  <a class="hub-library-entry" href="${esc(library.href)}">
   <span class="hub-library-art"><img src="${esc(library.cover)}" alt="" width="192" height="192"><span class="hub-library-open" aria-hidden="true">${icon('arrow',16)}</span></span>
   <span class="hub-library-copy"><strong>${esc(library.name)}</strong><span class="hub-library-version">${esc(library.version)}</span></span>
  </a>
  <p class="hub-library-summary">${esc(library.summary)}</p>
  <nav class="hub-library-links" aria-label="${esc(library.name)}快捷入口">${library.links.map(([href,label])=>`<a href="${esc(href)}">${esc(label)}</a>`).join('')}</nav>
 </article>`;
}

export async function buildPortal(out,libraries,icon){
 const html=`<!doctype html>
<html lang="zh-CN">
<head>
 <meta charset="utf-8">
 <meta name="viewport" content="width=device-width,initial-scale=1">
 <meta name="color-scheme" content="light dark">
 <meta name="description" content="淬炼之季与永不妥协测试版的中文 Wiki 入口。">
 <title>饥荒联机版模组 Wiki</title>
 <link rel="stylesheet" href="styles.css">
 <link rel="stylesheet" href="hub.css">
 <script src="theme.js"></script>
 <script src="search.js" defer></script>
 <script src="hub.js" defer></script>
</head>
<body data-wiki="hub">
 <a class="skip-link" href="#main">跳到模组目录</a>
 <header class="hub-header">
  <a class="hub-brand" href="index.html" aria-label="模组 Wiki 总览">
   <span class="hub-brand-mark">${icon('book',21)}</span><span><strong>模组 Wiki</strong><small>饥荒联机版</small></span>
  </a>
  <div class="search-box hub-search" role="search" aria-label="搜索两套 Wiki">
   ${icon('search',17)}<label class="sr-only" for="header-search">搜索两个 Wiki</label>
   <input id="header-search" type="search" placeholder="搜索词条、物品、配方或配置" autocomplete="off">
   <button type="button" data-search aria-label="搜索两个 Wiki" title="打开全站搜索 (Ctrl+K)"><kbd>Ctrl K</kbd><span class="hub-search-text">搜索</span></button>
  </div>
  <button type="button" class="hub-theme" data-hub-theme aria-label="切换到深色模式" title="切换主题">${moon}${sun}</button>
 </header>
 <main class="hub-main" id="main" tabindex="-1">
  <div class="hub-intro">
   <span class="hub-eyebrow">DST MOD WIKI</span>
   <h1>饥荒联机版模组 Wiki</h1>
   <p>选择一个模组，查阅玩法、物品配方与房间配置。</p>
  </div>
  <section class="hub-launchpad" aria-label="模组目录">
   ${libraries.map(library=>libraryTile(library,icon)).join('')}
  </section>
  <footer class="hub-footer">
   <span>资料来源</span>
   ${libraries.map(library=>`<a href="${esc(library.source)}">${esc(library.name)}</a>`).join('')}
  </footer>
 </main>
 ${searchDialog(icon)}
 <script src="legacy-home.js"></script>
</body>
</html>`;
 await fs.writeFile(path.join(out,'index.html'),html);
 for(const file of ['hub.css','hub.js'])await fs.copyFile(new URL('./src/'+file,import.meta.url),path.join(out,file));
 await fs.copyFile(new URL('./um-beta/legacy-home.js',import.meta.url),path.join(out,'legacy-home.js'));
}
