(() => {
 const {search,hash}=location;
 const query=new URLSearchParams(search);
 if(query.has('category')||(hash&&hash!=='#main')){
  location.replace(new URL('tempered.html'+search+hash,location.href));
 }
})();
