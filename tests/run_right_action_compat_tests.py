"""Exercise all shared character point abilities with native picking and medal blink."""
from pathlib import Path
import sys
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as z:
    lua.execute(z.read("scripts/class.lua").decode("utf-8-sig"))
    lua.globals().picker_source = z.read("scripts/components/playeractionpicker.lua").decode("utf-8-sig")
    controller = z.read("scripts/components/playercontroller.lua").decode("utf-8-sig")
    start = controller.index("function PlayerController:OnRightClick(down)")
    lua.globals().click_source = controller[start:controller.index("\nfunction ", start + 1)]
    start = controller.index("function PlayerController:GetActiveSpellBook()")
    lua.globals().spellbook_source = controller[start:controller.index("\nfunction ", start + 1)]
    lua.globals().targeting_source = z.read("scripts/components/aoetargeting.lua").decode("utf-8-sig")
    lua.globals().charging_source = z.read("scripts/components/aoecharging.lua").decode("utf-8-sig")
medal = Path("D:/SteamLibrary/steamapps/workshop/content/322330/1909182187/scripts/medal_hook.lua").read_text(encoding="utf-8-sig")
start = medal.index("local function CanBlinkTo(inst,pt)")
end = medal.index("local function setBlinkFn(player)", start)
lua.globals().medal_source = medal[start:end] + "\nreturn MedalBlinkPointSpecialActions"
lua.globals().right_source = (ROOT / "content/easy_role/rightaction.lua").read_text(encoding="utf-8-sig")
lua.execute((ROOT / "tests/right_action_compat_regression.lua").read_text(encoding="utf-8"))
