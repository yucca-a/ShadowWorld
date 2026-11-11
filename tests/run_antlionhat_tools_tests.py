"""Test the hat's local execution guard with original DST action/work components."""
from pathlib import Path
from zipfile import ZipFile
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
scripts = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(
    "D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip"
)
with ZipFile(scripts) as archive:
    read = lambda name: archive.read("scripts/" + name).decode("utf-8-sig")
    lua.execute(read("class.lua"))
    lua.execute(read("bufferedaction.lua"))
    lua.globals().NativeWorkable = lua.execute(read("components/workable.lua"))
    entity = read("entityscript.lua")
    start = entity.index("function EntityScript:GetBufferedAction()")
    lua.execute("EntityScript = {}\n" + entity[start:entity.index("\nend", start) + 4])
    actions = read("actions.lua")
    start = actions.index("local function DoToolWork(")
    lua.globals().NativeToolWork = lua.execute(
        actions[start:actions.index("local function ValidToolWork(", start)] + "\nreturn DoToolWork"
    )

source = (ROOT / "content/easy_other/easy_equipments.lua").read_text(encoding="utf-8-sig")
start = source.index("    local function doitemaction(act)")
lua.globals().HatDo = lua.execute(
    source[start:source.index("    local actions_antlionhat =", start)] + "\nreturn doitemaction"
)
lua.globals().StatueSource = (ROOT / "content/tech/ancient_statue.lua").read_text(encoding="utf-8-sig")
lua.execute((ROOT / "tests/antlionhat_tools_regression.lua").read_text(encoding="utf-8-sig"))
for text in (source, lua.globals().StatueSource):
    lua.execute("assert(loadstring(...))", text)
print("Changed gameplay sources compile in Lua 5.1")
