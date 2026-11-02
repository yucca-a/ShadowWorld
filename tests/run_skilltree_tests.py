"""Run with Python + lupa; uses the installed game's Lua 5.1 scripts, without launching it.

python tests/run_skilltree_tests.py [path/to/data/databundles/scripts.zip]
The local work/test-python dependency directory is also supported.
"""
import sys
from pathlib import Path
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work" / "test-python"))
from lupa.lua51 import LuaRuntime

archive = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(
    "D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip"
)
lua = LuaRuntime(unpack_returned_tuples=True)
loader = lua.eval("function(source, name) return assert(loadstring(source, '@' .. name)) end")
with ZipFile(archive) as scripts:
    lua.execute(scripts.read("scripts/class.lua").decode("utf-8-sig"))
    for name in scripts.namelist():
        if name.startswith("scripts/prefabs/skilltree_") or name in {
            "scripts/skilltreedata.lua", "scripts/components/skilltreeupdater.lua",
            "scripts/widgets/skilltreetoast.lua",
        }:
            module = name.removeprefix("scripts/").removesuffix(".lua")
            lua.globals().package.preload[module] = loader(scripts.read(name).decode("utf-8-sig"), name)
    # Test the real game's checkbox implementation with a small rendering stub.
    templates = scripts.read("scripts/widgets/redux/templates.lua").decode("utf-8-sig")
    checkbox = templates.split("function TEMPLATES.LabelCheckbox", 1)[1].split("\n-- Spinner", 1)[0]
    lua.globals().checkbox_source = "function TEMPLATES.LabelCheckbox" + checkbox

lua.globals().patch_source = (ROOT / "content/easy_role/skilltree_common.lua").read_text(encoding="utf-8-sig")
loader(lua.globals().patch_source, "skilltree_common.lua")  # Lua 5.1 syntax check.
lua.execute((ROOT / "tests/skilltree_regression.lua").read_text(encoding="utf-8-sig"))
