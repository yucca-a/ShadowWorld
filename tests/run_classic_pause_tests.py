"""Exercise actual classic pause callbacks and pocket-container button branches."""
from pathlib import Path
import sys
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
source = (ROOT / "content/easy_other/containersort.lua").read_text(encoding="utf-8-sig")
lua.eval("function(s) return assert(loadstring(s)) end")(source)
start = source.index("-- 世界唯一容器穿越")
lua.globals().callback_source = source[start:source.index("-- 容器收集", start)] + "\npausevalidfn_export=pausevalidfn; pausebtnfn_export=pausebtnfn"
start = source.index('                    if overflow.inst:HasTag("pocketdimension_container") then')
lua.globals().backpack_source = source[start:source.index('                    else\n                        if haslockbutton', start)] + "\nend"
start = source.index('                if container:HasTag("pocketdimension_container") then', source.index('local hastravel = worldexchangecfg and isshadowspace(overflow.inst)'))
lua.globals().panel_source = source[start:source.index('                else\n                    if haslockbutton', start)] + "\nend"
start = source.index("                    local hastravel = not TUNING.DSA_ONE_PLAYER_MODE")
end = source.index('\n                end', start)
lua.globals().private_source = source[start:end]
start = source.index("        pausebtn = {")
lua.globals().button_source = "local pausevalidfn,pausebtnfn=pausevalidfn_export,pausebtnfn_export\nreturn {" + source[start:source.index("        reskinbtn =", start)] + "}"
lua.globals().classic_source = (ROOT / "content/easy_other/exchangeclassic2hm.lua").read_text(encoding="utf-8")
lua.execute((ROOT / "tests/classic_pause_regression.lua").read_text(encoding="utf-8"))
