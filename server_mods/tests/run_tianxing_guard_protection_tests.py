"""Protected payload integrity and native-style mod environment regression."""
from pathlib import Path
import re
import sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/"work/test-python"))
from lupa.lua51 import LuaRuntime

checks=0
for name in ['modmain.lua','scripts/tianxing_guard.lua','scripts/tianxing_guard_watch.lua']:
    text=(ROOT/'server_mods/tianxing_guard'/name).read_text(encoding='utf-8')
    assert text.startswith('-- TXG_PROTECTED_1')
    assert all(token not in text for token in ['MAPDELIVER_MAP','inspect_corrections','QUIET_TIME','AddComponentPostInit'])
    payload=re.search(r'local h="([0-9a-f]+)"',text)
    assert payload is not None
    corrupted=('1' if payload[1][0]=='0' else '0')+payload[1][1:]
    damaged=text[:payload.start(1)]+corrupted+text[payload.end(1):]
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.execute('GLOBAL=_G')
    lua.globals().source=damaged
    result=lua.execute('local ok,err=pcall(assert(loadstring(source)));return ok,tostring(err)')
    assert result[0] is False and 'TXG protected payload corrupted' in result[1]
    checks+=2

# Real mod environments are distinct from GLOBAL. The decoded entry point must
# retain that environment to resolve AddComponentPostInit/GetModConfigData.
lua=LuaRuntime(unpack_returned_tuples=True)
lua.globals().source=(ROOT/'server_mods/tianxing_guard/modmain.lua').read_text(encoding='utf-8')
lua.execute(r'''
local env={GLOBAL=_G}
local hooks=0
local guard={SetReporter=function()end,AttachController=function()end,AttachLocomotor=function()end}
env.require=function(name)
 if name=="tianxing_guard" then return guard end
 return {New=function(opts)assert(opts.auto_kick==false);return {Report=function()end}end}
end
env.GetModConfigData=function()return false end
env.AddComponentPostInit=function()hooks=hooks+1 end
local f=assert(loadstring(source));setfenv(f,env);f()
assert(hooks==2)
assert(env.TheNet==nil and env.loadstring==nil)
''')
checks+=1
print(f"TIANXING_PROTECTION checks={checks} failures=0")
