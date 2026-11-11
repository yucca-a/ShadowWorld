(() => {
 let anchor;
 try{anchor=decodeURIComponent(location.hash.slice(1));}catch{}
 const item=anchor?.startsWith('item-')?document.getElementById(anchor):null;
 const link=item??document.querySelector('#legacy-items-home');
 if(link)location.replace(link.href);
})();
