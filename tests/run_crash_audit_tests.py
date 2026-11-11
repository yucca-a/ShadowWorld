"""Targeted regressions for actual production entry points found in the audit."""
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'work/test-python'))
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
def source(path):return (ROOT/'content'/path).read_text(encoding='utf-8-sig')
def section(path,start,end):
    s=source(path);a=s.index(start);return s[a:s.index(end,a)]
g=lua.globals()
g.helper_source=source('scripts/upvaluehacker2hm.lua')
g.guard_source=source('scripts/rpcguard2hm.lua')
g.search_source=section('easy_other/containersort.lua','        local function searchcollectfn(', '        AddModRPCHandler("MOD_HARDMODE", "searchcollect2hm"')+'\nreturn searchcollectfn'
g.cook_source=section('easy_other/easy_structures.lua','    local monstermeats =','    AddModRPCHandler("MOD_HARDMODE", "cookbtn2hm"')+'\nreturn cookfn'
g.dodge_source=section('easy_role/rightaction.lua','local ctrldisable =','ACTIONS.DODGE_WALTER.distance =')
g.moon_source=section('scripts/components/moonstorms2hm.lua','    function self:AddMoonstormNodes(', '    function self:AddNewMoonstormNode(')
g.shark_source=section('epic/sharkboi.lua','    if inst.OnEntitySleep then','    if inst.components.combat then')
g.ice_source=section('epic/crabking.lua','local function oniceattacked2hm(', '\n-- 优化坐标位置冰面检测函数')+'\nreturn oniceattacked2hm'
lua.execute((ROOT/'tests/crash_audit_regression.lua').read_text(encoding='utf-8-sig'))
