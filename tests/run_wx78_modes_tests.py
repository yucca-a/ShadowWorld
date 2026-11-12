"""WX-78 mode compatibility matrix, draft arithmetic and Lua compilation."""
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'work/test-python'))
from lupa.lua51 import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
load = lua.eval('function(s,n) local f,e=loadstring(s,n); assert(f,e); return f end')
for file in (ROOT/'content').rglob('*.lua'):
    load(file.read_text(encoding='utf-8-sig'), '@'+str(file))
config = load((ROOT/'content/scripts/wx78config2hm.lua').read_text(encoding='utf-8'), 'config')()
draft = load((ROOT/'content/scripts/wx78draft2hm.lua').read_text(encoding='utf-8'), 'draft')()
lua.globals().config, lua.globals().draft = config, draft
lua.globals().mode_source = (ROOT/'content/common/wx78_mode.lua').read_text(encoding='utf-8')
lua.execute('''
local n = 0
for _, easy in ipairs({false,true}) do
for _, hard in ipairs({false,true}) do
for _, roleeasy in ipairs({false,true}) do
for _, rolehard in ipairs({false,true}) do
for _, oldeasy in ipairs({false,true}) do
for _, oldhard in ipairs({false,true}) do
    local values={role_easy=roleeasy,role_nerf=rolehard,wx78_easy=oldeasy,["wx-78"]=oldhard}
    local function get(k)return values[k]end
    local t={easymode2hm=easy,hardmode2hm=hard}
    local r=config.Resolve(get,t)
    assert(r.easy==(easy and roleeasy and oldeasy))
    assert(r.hard==(hard and rolehard and oldhard))
    assert(r.easyhard==(hard and rolehard))
    assert(not r.draft and r.mode=="legacy")
    local E={TUNING=t,GetModConfigData=get,AddRightSelfAction=function()end,modimport=function()end}
    E.env=E
    E.require=function(name)
        if name=="wx78config2hm"then return config end
        return {Install=function()end}
    end
    setfenv(assert(loadstring(mode_source)),E)()
    assert(not t.wx78recoverfusion2hm and not t.wx78recoverbox2hm,"default triggered migration")
    for _,mode in ipairs({"off","draft","easy","hard"})do
        values["WX-78 Mode"]=mode
        r=config.Resolve(get,t)
        assert(r.easy==(mode=="easy"or mode=="hard"))
        assert(r.hard==(mode=="hard"))
        assert(r.easyhard==(mode=="hard"))
        assert(r.draft==(mode=="draft"))
        n=n+1
    end
end end end end end end
local owner={module_bars={alpha={}}}
local skills={}
local p={components={upgrademoduleowner=owner,skilltreeupdater={IsActivated=function(_,s)return skills[s]end}}}
local function module(name,active)
    table.insert(owner.module_bars.alpha,{prefab="wx78module_"..name,components={upgrademodule={activated=active}}})
end
module("maxhealth",true);module("maxhealth2",true);module("maxsanity1",true);module("maxsanity",true)
local b,a,s,l=draft.Values(p)
assert(b==7 and math.abs(a-.675)<1e-9 and s==1 and l==1)
skills.wx78_circuitry_alphabuffs_1=true
b,a=draft.Values(p);assert(b==7 and math.abs(a-.4)<1e-9)
skills.wx78_circuitry_alphabuffs_2=true
b,a=draft.Values(p);assert(b==10.5 and math.abs(a-.3)<1e-9)
for i=1,8 do module("maxhealth2",true);module("maxsanity",true)end
b,a=draft.Values(p);assert(b==20 and a==.2)
for _,m in ipairs(owner.module_bars.alpha)do m.components.upgrademodule.activated=false end
b,a,s,l=draft.Values(p);assert(b==0 and a==1 and s==0 and l==0)
owner.charge=0;owner.max=6
function owner:GetChargeLevel()return self.charge end
function owner:GetMaxChargeLevel()return self.max end
function owner:DoDeltaCharge(n)self.charge=math.min(self.max,self.charge+n)end
draft.Feed(p,15,false);assert(p.wx78nutrition2hm==15 and owner.charge==0)
draft.Feed(p,30,false);assert(p.wx78nutrition2hm==0 and owner.charge==1)
draft.Feed(p,135,false);assert(p.wx78nutrition2hm==0 and owner.charge==4)
draft.Feed(p,15,true);assert(p.wx78nutrition2hm==0 and owner.charge==4)
draft.Feed(p,15,false);draft.Feed(p,135,false)
assert(owner.charge==6 and p.wx78nutrition2hm==0)
draft.Feed(p,30,false);assert(p.wx78nutrition2hm==0)
print("PASS WX-78: "..n.." explicit/legacy configuration cases, circuit tiers/caps/deactivation, nutrition and all Lua syntax")
''')
