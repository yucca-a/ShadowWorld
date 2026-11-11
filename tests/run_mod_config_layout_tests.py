"""Exercise our config layout using the game's actual label and row update code."""
from pathlib import Path
from zipfile import ZipFile
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().package.path = str(ROOT / "content/scripts/?.lua").replace("\\", "/") + ";" + lua.globals().package.path
for key, path in {"modinfo_source": "modinfo.lua", "config_patch": "scripts/wixieconfig2hm.lua"}.items():
    lua.globals()[key] = (ROOT / "content" / path).read_text(encoding="utf-8-sig")
with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as z:
    source = z.read("scripts/widgets/redux/templates.lua").decode("utf-8-sig").replace("\r\n", "\n")
    start = source.index("function TEMPLATES.LabelSpinner(")
    lua.globals().native_label_spinner = source[start:source.index("\nend", start) + 4]
    source = z.read("scripts/screens/redux/modconfigurationscreen.lua").decode("utf-8-sig").replace("\r\n", "\n")
    start = source.index("    local function ApplyDataToWidget(")
    end = source.index("    for idx,option_item", start)
    lua.globals().native_apply = "return function(self)\n" + source[start:end] + "\nreturn ApplyDataToWidget\nend"
    start = end
    end = source.index("    self.options_scroll_list =", start)
    lua.globals().native_option_data = "return function(self)\n" + source[start:end] + "\nend"
lua.execute((ROOT / "tests/mod_config_layout_regression.lua").read_text(encoding="utf-8-sig"))
