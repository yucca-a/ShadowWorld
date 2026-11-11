(() => {
 const toggle=document.querySelector('[data-hub-theme]');
 const root=document.documentElement;
 function syncThemeButton(){
  const dark=root.dataset.theme==='dark';
  const label=dark?'切换到浅色模式':'切换到深色模式';
  toggle.setAttribute('aria-label',label);
  toggle.setAttribute('aria-pressed',String(dark));
  toggle.title=label;
 }
 syncThemeButton();
 toggle.addEventListener('click',()=>{
  root.dataset.theme=root.dataset.theme==='dark'?'light':'dark';
  try{localStorage.setItem('tempered-wiki-theme',root.dataset.theme);}catch{}
  syncThemeButton();
 });
})();
