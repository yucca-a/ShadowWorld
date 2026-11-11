-- TXG_PROTECTED_1: generated release, keep maintenance sources outside the mod.
local g=GLOBAL
local e=g.getfenv(1)
local c,t,n=g.string.char,g.table.concat,g.tonumber
local k={220,203,48,215,233,22,77,104,113,251,65,153,100,19,100,83,140,87,30,192,145,246,97,214,40,248,162,30,107,160,82,201}
local h="80987f577dd219308fb678de027c82e0892321f5d8638a54ae2aa240e9fa81b0d0be32a653f7afd4d98ce0f66a272da1b44b72c9c015ab4d7e50779bdc4f0cdf2286a225a0904340d998ee62d36d3db51fba096980cc39fce0b44b9fbf1b808f00c1753a383cd2144815b894b9d8d22b0d2caef0d369d79a05dee5f1a4dde345f182247ec9a3672fed95b248ef49d2dab9c9c48114679c6c054bbb59a1afa9a64165df48093f43329d9906716757397ae45032ebab8ac16e7553b44dea5e56b7dc65dd6c13271780c09d6b44ffde1470c9ecc75f9953529dfba8ca96aaca8abe7bf50ed467a0624a0106b4e53b400c1b54c81abb11443737701227402ba7775f38b3144823b2537c2bbaa7c922ede4a405704d258aee0418b2b450d9ae7a5861645b30f031264448ccec8204b82e8044345acb34f8ac19bc4f481b767ab6947d5dc9acfac15f8d626224ef6ab217b4510bc5f4764f894604a5d994c9b538e5837f45bdf8ca1d4da78baa873a67a188bbedab3d7b753af1a8bc50cc700955061ee201827aaee150fdd3e2ff2bc761af6f03238fdedab0a7ed731cc16162d4809341997a1f76f5b8bf1eb5657de45751086c5fadd312f43f2940d2fb88f806bac46b837a0f6f10deb5710618e1291666e890f2b6fa038e5a4b649dc3c8f4ee3bc25027b166036b3dfdae07acede1e9e3c3320117fd08a1059df42734a3311bd6fe7a8975af29aa7c8984fa2f942c8c256bcd4e6b3a77033de6f3f80eae0bdaa0f34eaf951aa746710f0fe0b5d8677a60035870a22b07aa1da13893e8ecad9361cef5c2b1ed623e7b623ebef5b391d58fad159052a4941769c63b20ba89b27b2a98baccfae3ae04fe19a597dfbaea8470d6591bc0215cd76519ccd44a5f17e67e9a3734ab19f506eb417cbafca43761afc9205529d93ded"
local s={}
for i=0,255 do s[i]=i end
local j=0
for i=0,255 do j=(j+s[i]+k[i%#k+1])%256;s[i],s[j]=s[j],s[i] end
local function x(a,b)
 local v,p=0,1
 while a>0 or b>0 do
  local q,r=a%2,b%2
  if q~=r then v=v+p end
  a,b,p=(a-q)/2,(b-r)/2,p*2
 end
 return v
end
local out,i,a,b={},0,1,0
j=0
for p=1,#h,2 do
 i=(i+1)%256;j=(j+s[i])%256;s[i],s[j]=s[j],s[i]
 local v=x(n(g.string.sub(h,p,p+1),16),s[(s[i]+s[j])%256])
 out[#out+1]=c(v);a=(a+v)%65521;b=(b+a)%65521
end
if #out~=662 or b*65536+a~=1121508509 then g.error("TXG protected payload corrupted",0) end
local f,err=g.loadstring(t(out),"@tianxing_guard/protected")
if not f then g.error(err,0) end
g.setfenv(f,e)
return f(...)
