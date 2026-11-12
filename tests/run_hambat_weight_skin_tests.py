"""Weighted hand art against the original meshes, and real component equip/weight callbacks."""
from pathlib import Path
from zipfile import ZipFile
from io import BytesIO
import hashlib,math,re,sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'development/tools'))
from build_hambat_skin_weights import readbuild,hashname,GAME
sys.path.insert(0,str(ROOT/'work/test-python'))
from lupa.lua51 import LuaRuntime
checks=0
def check(value,message):
 global checks
 checks+=1
 assert value,message
with ZipFile(GAME/'databundles/anim_dynamic.zip')as archive:
 for skin in ['hambat_nautical','hambat_potroast','hambat_spiralcut']:
  with ZipFile(BytesIO(archive.read('anim/dynamic/'+skin+'.zip')))as source:original=readbuild(source.read('build.bin'))
  with ZipFile(ROOT/('content/anim/dynamic/'+skin+'_weighted2hm.zip'))as source:weighted=readbuild(source.read('build.bin'))
  baseframes=next(f for h,f in original[2]if original[4][h]=='swap_ham_bat')
  check(weighted[1]==original[1],skin+' material pages unchanged')
  check(len(weighted[2])==18,skin+' has every original weight tier')
  for h,frames in weighted[2]:
   name=weighted[4][h]
   with ZipFile(ROOT/('content/anim/'+name+'.zip'))as z:reference=readbuild(z.read('build.bin'))
   with ZipFile(GAME/'anim/swap_ham_bat.zip')as z:vanilla=readbuild(z.read('build.bin'))
   anchor=reference[2][0][1][0][2:6]
   nativeframe=next(f for h,f in vanilla[2]if vanilla[4][h]=='swap_ham_bat')[0][2:6]
   sx,sy=anchor[2]/nativeframe[2],anchor[3]/nativeframe[3]
   check(len(frames)==len(baseframes),skin+' facing frame count')
   for a,b in zip(frames,baseframes):
    check(a[:2]==b[:2],skin+' facing frame and duration unchanged')
    check(math.isclose(a[4]/b[4],sx,rel_tol=1e-6)and math.isclose(a[5]/b[5],sy,rel_tol=1e-6),skin+' uses original weight dimensions')
    check(abs((a[2]-b[2]*sx)-(anchor[0]-nativeframe[0]*sx))<1e-4 and abs((a[3]-b[3]*sy)-(anchor[1]-nativeframe[1]*sy))<1e-4,skin+' preserves the original grip correction')
    before=original[3][b[6]:b[6]+b[7]];after=weighted[3][a[6]:a[6]+a[7]]
    check(len(before)==len(after)and all(v[2:]==w[2:]for v,w in zip(before,after)),skin+' depth and encrypted texture UV/page unchanged')
  source=GAME/('anim/dynamic/'+skin+'.dyn');generated=ROOT/('content/anim/dynamic/'+skin+'_weighted2hm.dyn')
  check(hashlib.sha256(source.read_bytes()).digest()==hashlib.sha256(generated.read_bytes()).digest(),skin+' original encrypted texture retained')
lua=LuaRuntime(unpack_returned_tuples=True)
with ZipFile(GAME/'databundles/scripts.zip')as z:lua.execute(z.read('scripts/class.lua').decode('utf-8-sig'))
lua.globals().component_source=(ROOT/'content/scripts/components/hambat2hm.lua').read_text(encoding='utf-8-sig')
lua.globals().skin_source=(ROOT/'content/scripts/hambatweightedskins2hm.lua').read_text(encoding='utf-8-sig')
count=lua.execute(r'''package.preload.hambatweightedskins2hm=function()return assert(loadstring(skin_source))()end
TUNING={HAMBAT_DAMAGE=59.5,MAXHAMBATWEIGHT2HM=10}
local Component=assert(loadstring(component_source))()
local n=0
local function check(v,m)n=n+1;assert(v,m)end
for _,skin in ipairs({false,'hambat_nautical','hambat_potroast','hambat_spiralcut'})do
 local last
 local owner={components={inventory={IsItemEquipped=function()return true end}},AnimState={}}
 function owner.AnimState:OverrideItemSkinSymbol(...)last={kind='skin',...}end
 function owner.AnimState:OverrideSymbol(...)last={kind='plain',...}end
 function owner.AnimState:Show()end;function owner.AnimState:Hide()end
 local inst={GUID=123,components={hoverer2hm={},perishable={GetPercent=function()return 1 end},weapon={}},Transform={}}
 function inst:GetSkinBuild()return skin or nil end
 function inst.Transform:SetScale(...)inst.scale={...}end
 function inst.components.weapon:SetDamage(d)inst.damage=d end
 function inst.components.weapon:SetRange(r)inst.range=r end
 inst.components.weapon.OnAttack=function()end
 inst.components.equippable={}
 inst.components.inventoryitem={GetGrandOwner=function()return owner end}
 local callbacks={}
 function inst:ListenForEvent(name,fn)callbacks[name]=fn end
 function inst:RemoveEventCallback(name)callbacks[name]=nil end
 local c=Component(inst)
 callbacks.equipped(inst,{owner=owner})
 for _,weight in ipairs({1,2,5,10})do
  c.weight=weight
  check(last.kind==(skin and 'skin'or'plain'),'equip/weight branch')
  if skin then
   check(last[2]==skin..'_weighted2hm','official skin selected')
   check(last[3]:match('^swap_ham_bat_')~=nil and last[3]~='swap_ham_bat','weight symbol selected')
   check(last[4]==inst.GUID and last[5]==last[3]and last[6]==last[3],'original item binding and weighted fallback')
  end
  if weight==10 then check(last[3]=='swap_ham_bat_2_50','ten weight uses the large tier')end
 end
 callbacks.unequipped(inst,{owner=owner});callbacks.equipped(inst,{owner=owner})
 check(last[3]=='swap_ham_bat_2_50','reequip retains weight')
 c:OnLoad({weight=2,dirty=0})
 check(last[3]=='swap_ham_bat_1_31','load uses the saved weight')
 c:OnRemoveFromEntity()
 check(next(callbacks)==nil,'component listeners removed')
end
return n''')
print('Hambat skin weight geometry:',checks,'checks; real Lua component:',count,'checks passed')
