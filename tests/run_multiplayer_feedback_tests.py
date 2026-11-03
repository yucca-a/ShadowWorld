"""Focused integration checks against actual hooks and native action registration."""
from pathlib import Path
from zipfile import ZipFile
import sys
import subprocess

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'work/test-python'))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
def source(name):
    return (ROOT / 'content' / name).read_text(encoding='utf-8-sig')

with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as z:
    native = z.read('scripts/componentactions.lua').decode('utf-8-sig')
    start = native.index('function AddComponentAction(')
    register = native[start:native.index('\nend', start) + 4]
    client = z.read('scripts/stategraphs/SGwilson_client.lua').decode('utf-8-sig')
    assert 'server_states = { "combat_lunge_start", "combat_lunge" }' in client
    stategraph = z.read('scripts/stategraph.lua').decode('utf-8-sig')
    native_class = z.read('scripts/class.lua').decode('utf-8-sig')

lua.execute('''
checks=0
function check(ok, message) checks=checks+1; assert(ok,message) end
function table.contains(t,v) for _,x in ipairs(t) do if x==v then return true end end return false end
''')
# Native registration replaces same-mod callbacks: preserve repair AND upgrade.
lua.execute('local MOD_COMPONENT_ACTIONS, MOD_ACTION_COMPONENT_NAMES, MOD_ACTION_COMPONENT_IDS = {}, {}, {}\n'
    + register + '\nNativeRegister=AddComponentAction; NativeActions=MOD_COMPONENT_ACTIONS')
lua.execute('''
TUNING={TOTAL_DAY_TIME=480}; ACTIONS={}; STRINGS={ACTIONS={REPAIR={GENERIC='Repair'},UPGRADE={GENERIC='Upgrade'},ADDFUEL='Add fuel'}}
function AddComponentAction(kind,component,fn) NativeRegister(kind,component,fn,'feedback') end
function Action(t) return t end
function AddAction(a) ACTIONS[a.id]=a end
''')
common = source('common/common.lua')
start = common.index('TUNING.USEITEMFNS2HM = {}')
end = common.index('AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.REPAIR2HM', start)
lua.execute(common[start:end])
# Keep the inherited fallback: the full mod uses the shared dispatcher, while
# an isolated import without common.lua can still register its inventory action.
collect = source('easy_other/containersort.lua')
start = collect.index('        if TUNING.INVENTORYFNS2HM ~= nil then')
registration = collect[start:collect.index('\n        end', start) + len('\n        end')]
upstream = subprocess.check_output(['git', 'show',
    'upstream-v2.8.14.95:content/easy_other/containersort.lua'], cwd=ROOT).decode('utf-8-sig')
assert registration in upstream.replace('\r\n', '\n')
for main in [source('modmain.lua'), subprocess.check_output(['git', 'show',
        'upstream-v2.8.14.95:content/modmain.lua'], cwd=ROOT).decode('utf-8-sig')]:
    assert main.index('modimport("common/common.lua")') < main.index('modimport("easy_other/containersort.lua")')
lua.execute('''
inventory_dispatcher=NativeActions.feedback.INVENTORY.inventoryitem
inventory_calls, collect_calls=0,0
table.insert(TUNING.INVENTORYFNS2HM,function()inventory_calls=inventory_calls+1 end)
function itemcheckfn()collect_calls=collect_calls+1 end
''')
lua.execute(registration)
lua.execute('''
check(NativeActions.feedback.INVENTORY.inventoryitem==inventory_dispatcher,'normal collection registration preserves shared inventory dispatcher')
NativeActions.feedback.INVENTORY.inventoryitem({}, {}, {}, true)
check(inventory_calls==1 and collect_calls==1,'normal shared dispatcher invokes both existing and collection handlers once')
saved_inventory_table=TUNING.INVENTORYFNS2HM
TUNING.INVENTORYFNS2HM=nil
function AddComponentAction(kind,component,fn)NativeRegister(kind,component,fn,'isolated_collect')end
''')
lua.execute(registration)
lua.execute('''
check(NativeActions.isolated_collect.INVENTORY.inventoryitem==itemcheckfn,'isolated import retains upstream fallback registration')
NativeActions.isolated_collect.INVENTORY.inventoryitem({}, {}, {}, true)
check(collect_calls==2,'fallback collection handler remains executable')
check(NativeActions.feedback.INVENTORY.inventoryitem==inventory_dispatcher,'standalone registration is confined to its mod namespace')
TUNING.INVENTORYFNS2HM=saved_inventory_table
function AddComponentAction(kind,component,fn)NativeRegister(kind,component,fn,'feedback')end
''')
lua.execute('''
check(STRINGS.ACTIONS.REPAIR2HM.UPGRADE=='Upgrade','upgrade label survives without optional watch/weapon features')
check(STRINGS.ACTIONS.REPAIR2HM~=STRINGS.ACTIONS.REPAIR,'custom labels do not mutate native repair strings')
TheWorld={ismastersim=false}; turret_hooks={}
function AddPrefabPostInit(name,fn)turret_hooks[name]=fn end
function AddComponentPostInit()end
function AddRecipePostInit()end
function AddStategraphPostInit()end
function AddStategraphState()end
function State(t)return t end
function EventHandler(n,f)return {name=n,fn=f}end
shared_dispatcher=NativeActions.feedback.USEITEM.inventoryitem
''')
lua.execute(source('easy_other/eyeturret2hm.lua'))
lua.execute('''
local actions={}
check(shared_dispatcher==NativeActions.feedback.USEITEM.inventoryitem,'full turret module never replaces common dispatcher')
local armor={repairmaterials2hm={nightmarefuel=100},HasTag=function(_,tag)return tag=='repairable2hm'end}
NativeActions.feedback.USEITEM.inventoryitem({prefab='nightmarefuel'}, {}, armor, actions, true)
check(#actions==1 and actions[1]==ACTIONS.REPAIR2HM,'turret hook must not erase armor repair')
actions={}
local target={prefab='eyeturret_item',tags={},IsValid=function()return true end,
 HasTag=function(self,tag)return self.tags[tag]end,HasOneOfTags=function()return false end,
 AddTag=function(self,tag)self.tags[tag]=true end}
turret_hooks.eyeturret_item(target)
NativeActions.feedback.USEITEM.inventoryitem({prefab='dragon_scales'}, {}, target, actions, true)
check(#actions==1 and actions[1]==ACTIONS.REPAIR2HM,'turret inventory upgrade uses existing repair action')
actions={}
NativeActions.feedback.USEITEM.inventoryitem({prefab='dragon_scales'}, {}, target, actions, false)
check(#actions==1 and actions[1]==ACTIONS.REPAIR2HM,'world use follows common material upgrade semantics')
target:AddTag('eyeturretfire2hm');actions={}
NativeActions.feedback.USEITEM.inventoryitem({prefab='dragon_scales'}, {}, target, actions, true)
check(#actions==0,'replicated upgrade tag hides repeated upgrade on clients')
actions={}
NativeActions.feedback.USEITEM.inventoryitem({prefab='shroom_skin'}, {}, target, actions, true)
check(actions[1]==ACTIONS.REPAIR2HM,'independent second upgrade remains available')
-- A fresh client/player uses the same dispatcher after reconnect.
actions={}; armor.repairmaterials2hm={nightmarefuel=20}
NativeActions.feedback.USEITEM.inventoryitem({prefab='nightmarefuel'}, {prefab='waxwell'}, armor, actions, false)
check(actions[1]==ACTIONS.REPAIR2HM,'repair survives a fresh player and item instance')
''')

lua.execute('''
RoundBiasedUp=function(n)return math.floor(n+.5)end
''')
lua.globals().needed = lua.execute(source('scripts/ingredientcollect2hm.lua'))
lua.execute('''
local carried,discount=0,1
local owner={replica={inventory={Has=function(_,p,n,all)
 check(all==false,'open chests must not count as carried');return carried>=n,carried end},
 builder={IngredientMod=function()return discount end}}}
check(needed(owner,'log',2,nil,40)==2,'open chest full stack still collects only two logs')
carried=1;check(needed(owner,'log',2,nil,40)==1,'partial carried material collects shortage')
carried=2;check(needed(owner,'log',2,nil,0)==false,'next click collects more after inventory refresh')
carried=0;discount=.5;check(needed(owner,'log',2,nil,40)==1,'construction discount applies')
discount=1;check(needed(owner,'log',2,3,40)==6,'explicit nested recipe batches preserved')
''')

right = source('easy_role/rightaction.lua')
start = right.index('AddStategraphPostInit("wilson_client", function(sg)', right.index('ACTIONS.Lunge_WAXWELL2HM.instant'))
lua.execute(native_class)
lua.execute('function hash(s) return "hash:"..s end')
start_state = stategraph.index('State = Class(')
lua.execute(stategraph[start_state:stategraph.index('\nend)', start_state)+5])
lua.execute('sg={states={combat_lunge_start=State{name="combat_lunge_start",server_states={"combat_lunge_start","combat_lunge"}}}}; '
    'function AddStategraphPostInit(_,fn) fn(sg) end')
lua.execute(right[start:right.index('\nend)', start)+5])
lua.execute('''
local states=sg.states.combat_lunge_start.server_states
check(states[hash('lunge_pre2hm')] and states[hash('lunge_loop2hm')],'prediction accepts custom server states')
check(states[hash('combat_lunge')] and states[hash('combat_lunge_start')],'native lunge remains compatible')
''')

exchange = source('easy_other/worldexchange.lua')
start = exchange.index('local oldShardUpdate')
lua.execute('''
GLOBAL={}; REMOTESHARDSTATE={READY=1}; disconnects,wakes,nativecalls=0,0,0
GLOBAL.Shard_UpdateWorldState=function()nativecalls=nativecalls+1;return 'native'end
TheWorld={components={worldexchange2hm={
 Disconnected=function()disconnects=disconnects+1 end,Wake=function()wakes=wakes+1 end}}}
''')
lua.execute(exchange[start:exchange.index('\nend', start)+4])
lua.execute('''
check(GLOBAL.Shard_UpdateWorldState('2',1)=='native','native shard update result retained')
check(disconnects==0 and wakes==1,'READY must not freeze players or discard connection')
GLOBAL.Shard_UpdateWorldState('2',1)
check(disconnects==0 and wakes==2,'repeated READY is harmless')
GLOBAL.Shard_UpdateWorldState('2',0)
check(disconnects==1 and nativecalls==3,'real disconnect still protects checkpoint')
''')
# The valid-entity fire wrapper delegates dt unchanged, exactly once.
patch = source('common/patch.lua')
start = patch.index('AddComponentPostInit("propagator"')
lua.execute('''
local entity={IsValid=function()return true end,Transform={GetWorldPosition=function()return 1,0,1 end}}
firecalls,elapsed=0,0
prop={inst=entity,OnUpdate=function(_,dt)firecalls=firecalls+1;elapsed=elapsed+dt end,
 OnRemoveEntity=function()end,StopUpdating=function()end}
function AddComponentPostInit(_,fn) fn(prop) end
''')
lua.execute(patch[start:patch.index('\nend)',start)+5])
lua.execute('prop:OnUpdate(.25);check(firecalls==1 and elapsed==.25,"fire wrapper does not multiply heat ticks")')
print('Multiplayer feedback checks:', lua.globals().checks)

for path in (ROOT/'content').rglob('*.lua'):
    lua.eval('function(s,n) assert(loadstring(s,n)) end')(path.read_text(encoding='utf-8-sig'), str(path))
print('All content Lua files: syntax passed')
