"""Three real engine modes, native original exchange, and saved mode round trips."""
from pathlib import Path
import sys,time,json,traceback
sys.path.insert(0,str(Path(__file__).resolve().parent))
from run_vault_comparison import Cluster,ROOT
c=Cluster('hosted',2,None,ROOT/'content')
probe=c.runtime/'mods/VaultAudit/modmain.lua'
probe.write_text((ROOT/'tests/native/exchange_modes_probe.lua').read_text(encoding='utf-8'),encoding='utf-8')
with probe.open('a',encoding='utf-8')as f:f.write(r'''
local testplayer
function G.ModeSeed(family,prefab,count,slot)
 local c=assert(TheWorld:GetPocketDimensionContainer(family)).components.container
 local e=SpawnPrefab(prefab);if e.components.stackable then e.components.stackable:SetStackSize(count)end
 assert(c:GiveItem(e,slot or 1));emit({kind="seeded"})
end
function G.ModeXianyuOpen()
 local p=SpawnPrefab("wilson");p.userid="KU_XiModeProbe";testplayer=p
 p.Transform:SetPosition(0,0,0);p.components.health:SetInvincible(true);p.components.hunger:SetRate(0)
 p.components.playervision:ForceNightVision(true);AllPlayers[#AllPlayers+1]=p
 if not p.components.magician then p:AddComponent("magician")end
 local hat=SpawnPrefab("tophat");hat:ConvertToMagician()
 assert(p.components.magician:StartUsingTool(hat))
 TheWorld:DoTaskInTime(2,function()
  local b=TheWorld.components.shadowbank2hm;local view=b.viewers[p.userid]
  assert(view and view.snapshot and view.display.components.container:IsOpenedBy(p),"Xianyu remote hat opens")
  emit({kind="xi_open",items=view.snapshot.items,bank=view.bank})
 end)
end
function G.ModeXiTake()
 local b=TheWorld.components.shadowbank2hm;local view=b.viewers[testplayer.userid]
 local item=assert(view.snapshot.items[1]);b:Action(testplayer,"take",1,item.token,"half",view.session)
 TheWorld:DoTaskInTime(3,function()
  local e=assert(testplayer.components.inventory:GetActiveItem());assert(e.prefab=="goldnugget")
  emit({kind="xi_taken",count=e.components.stackable:StackSize()})
  b:Action(testplayer,"deposit",1,view.snapshot.items[1]and view.snapshot.items[1].token,nil,view.session,e)
  TheWorld:DoTaskInTime(3,function()
   assert(not testplayer.components.inventory:GetActiveItem(),"Xianyu put back")
   testplayer.components.magician:StopUsing();table.removearrayvalue(AllPlayers,testplayer);testplayer:Remove()
   emit({kind="xi_returned"})
  end)
 end)
end
function G.ModeXiSeed()
 local b=TheWorld.components.shadowbank2hm;local c=assert(b:Bank(2));local e=SpawnPrefab("goldnugget")
 e.components.stackable:SetStackSize(5);assert(c:GiveItem(e,1));emit({kind="xi_seeded"})
end
function G.ModeXiCount()
 local b=TheWorld.components.shadowbank2hm;local e=b:Bank(2):GetItemInSlot(1)
 emit({kind="xi_count",count=e and e.components.stackable:StackSize()or 0})
end
''')
def config(mode):
 for n in c.names:
  (c.cluster/n/'modoverrides.lua').write_text('return {VaultAudit={enabled=true},ShadowWorld={enabled=true,configuration_options={["World Exchange"]="'+mode+'",["Container Sort"]=-3,["Tackle Receptacle Use Fish Redeem"]=-1}}}')
def state():return {n:c.call(n,'ExchangeModeProbe()','mode_state')for n in c.names}
def save():
 before={n:len(c.events(n))for n in c.names};c.command('Master','TheWorld:PushEvent("ms_save")')
 for n in c.names:c.wait(n,'archive_saved',after=before[n],timeout=40)
 time.sleep(1)
def boot(mode):
 c.stop();config(mode);c.start();time.sleep(5)
 for _ in range(25):
  s=state()
  if all(r['ready'] for r in s.values()):return s
  time.sleep(1)
 raise RuntimeError(s)
report={'cluster':str(c.out),'checks':[]}
def check(name,condition,**data):
 report['checks'].append({'name':name,'passed':bool(condition),**data});print(name,bool(condition),flush=True);assert condition,data
try:
 s=boot('hosted');check('legacy default forces original',all(r['mode']=='classic' for r in s.values()))
 c.call('Master','ModeSeed("shadow","goldnugget",17)','seeded')
 c.call('Caves','ModeSeed("shadow","cutstone",7)','seeded')
 row=c.call('Master','ExchangeModeOpen("shadow",true)','mode_opened')
 check('original native exchange',row['items'].get('1',{}).get('prefab')=='cutstone',row=row)
 row=c.call('Master','ExchangeModeOpen("shadow",true)','mode_opened')
 check('original reverse exchange',row['items'].get('1',{}).get('count')==17,row=row)
 save();s=boot('exchange_v1_xianyu');check('manual Xianyu choice persists',all(r['mode']=='xianyu' for r in s.values()))
 c.call('Master','ModeXiSeed()','xi_seeded')
 c.call('Caves','ModeXianyuOpen()','xi_open')
 before=len(c.events('Caves'));row=c.call('Caves','ModeXiTake()','xi_taken');check('Xianyu split half',row['count']==3)
 c.wait('Caves','xi_returned',after=before)
 check('Xianyu transfer conservation',c.call('Master','ModeXiCount()','xi_count')['count']==5)
 save();s=boot('exchange_v1_nexus');check('manual Nexus choice persists',all(r['mode']=='hosted' for r in s.values()))
 for _ in range(35):
  s=state()
  if all(r.get('journal',{}).get('ready') and not r.get('protocol') for r in s.values()):break
  time.sleep(1)
 check('Nexus real journal starts',all(r.get('journal',{}).get('ready') and not r.get('error') for r in s.values()),state=s)
 c.call('Master','ModeSeed("shadow","log",11)','seeded')
 save();s=boot('exchange_v1_original');check('original mode returns without remigrating manual Nexus',all(r['mode']=='classic' and not r.get('migrated') for r in s.values()))
 row=c.call('Master','ExchangeModeOpen("shadow")','mode_opened');check('original contents survive all mode changes',row['items'].get('1',{}).get('count')==17,row=row)
 save();s=boot('exchange_v1_xianyu');check('restored Xianyu goods are not replayed into second space',c.call('Master','ModeXiCount()','xi_count')['count']==0)
 save();s=boot('exchange_v1_nexus')
 for _ in range(35):
  s=state()
  if all(r.get('journal',{}).get('ready') and not r.get('protocol') for r in s.values()):break
  time.sleep(1)
 before=len(c.events('Master'));c.call('Master','ExchangeModeProbe()','mode_state')
 bank=next(r for r in c.events('Master')[before:]if r['kind']=='mode_bank' and r['family']=='shadow')
 check('Nexus inventory survives manual round trip',bank['items'].get('1',{}).get('prefab')=='log' and bank['items']['1']['count']==11,row=bank)
 report['status']='passed'
except Exception:report.update(status='failed',error=traceback.format_exc());print(report['error'])
finally:
 c.stop();(c.out/'three-mode-native-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
 print('REPORT',c.out/'three-mode-native-report.json',flush=True)
raise SystemExit(report['status']!='passed')
