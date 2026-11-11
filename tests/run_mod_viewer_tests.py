"""Exercise the actual viewer hooks with native configuration lookup and UI stubs."""
from pathlib import Path
from zipfile import ZipFile
import argparse
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("scripts", nargs="?", default="D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip")
parser.add_argument("--source-ref", help="Test an archived Git version instead of working source")
args = parser.parse_args()
lua = LuaRuntime(unpack_returned_tuples=True)


def function_source(text, start):
    begin = text.index(start)
    return text[begin:text.index("\nend", begin) + len("\nend")]


def source(path):
    if args.source_ref:
        return subprocess.check_output(["git", "show", f"{args.source_ref}:{path}"], cwd=ROOT).decode("utf-8-sig")
    return (ROOT / path).read_text(encoding="utf-8-sig")


with ZipFile(args.scripts) as archive:
    def native(path):
        return archive.read("scripts/" + path + ".lua").decode("utf-8-sig")

    lua.execute(native("class"))
    lua.execute("ModIndex = {}; ModWrangler = {}")
    for name in ["GetModInfo", "HasModConfigurationOptions", "GetModConfigurationOptions_Internal"]:
        lua.execute(function_source(native("modindex"), "function ModIndex:" + name + "("))
    lua.execute(function_source(native("mods"), "function ModWrangler:GetMod("))
    lua.execute(function_source(native("modutil"), "function GetModConfigData("))
    screen = native("screens/redux/modconfigurationscreen")
    options = screen[screen.index("\tself.modname = modname"):screen.index("\tself.started_default =")]
    lua.execute("native_screen_options = function(self, modname, client_config)\n" + options + "\nend")

lua.globals().ui_source = source("content/easy_other/ui.lua")
lua.globals().temp_source = source("content/common/temp.lua")
main = source("content/modmain.lua")
if 'require("seasonwiki2hm")' in main:
    lua.globals().wiki_source = source("content/scripts/seasonwiki2hm.lua")
start = main.index('if ((TUNING.TEMP2HM.openmods == nil and GetModConfigData("Show Mod Icon In Game"))')
lua.globals().ui_import_source = main[start:main.index('\nif GetModConfigData("Disable Outdate Tip")', start)]
for path in ["content/modmain.lua", "content/common/temp.lua", "content/easy_other/ui.lua"]:
    lua.eval("function(s) return assert(loadstring(s)) end")(source(path))
lua.execute((ROOT / "tests/mod_viewer_regression.lua").read_text(encoding="utf-8-sig"))
