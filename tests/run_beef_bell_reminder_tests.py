"""Check both bell types and nested ownership using the actual reminder and native owner lookup."""
from pathlib import Path
from zipfile import ZipFile
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as archive:
    source = archive.read("scripts/components/inventoryitem.lua").decode("utf-8-sig")
    start = source.index("function InventoryItem:GetGrandOwner()")
    lua.execute("InventoryItem = {}\n" + source[start:source.index("\nend", start) + 4])
source = (ROOT / "content/common/common.lua").read_text(encoding="utf-8-sig")
start = source.index("-- 骑牛忘带牛铃：")
lua.globals().ReminderSource = source[start:source.index("\nend)", start) + len("\nend)")]
lua.execute((ROOT / "tests/beef_bell_reminder_regression.lua").read_text(encoding="utf-8-sig"))
lua.execute("assert(loadstring(...))", source)
lua.execute("assert(loadstring(...))", (ROOT / "content/modinfo.lua").read_text(encoding="utf-8-sig"))
print("Reminder and mod configuration compile in Lua 5.1")
