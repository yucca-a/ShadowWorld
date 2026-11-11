"""Exercise client/host/dedicated FX lifecycle and syntax using Lua 5.1."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'work/test-python'))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
for rel in ('content/scripts/frostshrinefx2hm.lua', 'content/scripts/prefabs/frostshrine2hm.lua'):
    source = (ROOT/rel).read_text(encoding='utf-8-sig')
    lua.eval('function(s) return assert(loadstring(s)) end')(source)
lua.globals().fx_source = (ROOT/'content/scripts/frostshrinefx2hm.lua').read_text(encoding='utf-8-sig')
lua.execute((ROOT/'tests/frostshrine_fx_regression.lua').read_text(encoding='utf-8-sig'))
