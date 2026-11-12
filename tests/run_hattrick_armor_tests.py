"""Hat trick immunity with native armor and installed UM beta armor rework.

Entity events, scheduling and effect methods are simulated. No game is launched.
"""
from pathlib import Path
from zipfile import ZipFile
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as archive:
    lua.execute(archive.read("scripts/class.lua").decode("utf-8-sig"))
    for key, name in (("armor_source", "components/armor"), ("modifiers_source", "util/sourcemodifierlist")):
        lua.globals()[key] = archive.read(f"scripts/{name}.lua").decode("utf-8-sig")

lua.globals().rework_source = Path(
    "D:/SteamLibrary/steamapps/workshop/content/322330/3193922031/postinit/armor_rework.lua"
).read_text(encoding="utf-8-sig")
source_path = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "content/scripts/components/removeleaveinventory2hm.lua"
lua.globals().component_source = source_path.read_text(encoding="utf-8-sig")
lua.execute((ROOT / "tests/hattrick_armor_regression.lua").read_text(encoding="utf-8-sig"))
