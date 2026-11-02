"""Real Frostjaw regression: floor(5*(1+x)/2), preserving legacy balances up to 500."""
import re
import sys
from pathlib import Path
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work" / "test-python"))
from lupa.lua51 import LuaRuntime

archive = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(
    "D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip"
)

def between(source, start, end):
    return source[source.index(start):source.index(end, source.index(start))]

with ZipFile(archive) as scripts:
    source = scripts.read("scripts/prefabs/sharkboi.lua").decode("utf-8-sig")
constants = "\n".join(re.findall(
    r"^local (?:MAX_TRADES|MIN_REWARDS|MAX_REWARDS|OFFSCREEN_DESPAWN_DELAY) = .*", source, re.M
))
# Preserve local MakeTrader calls: loading/sleeping must not accidentally use the wrapper.
original = constants + "\n" + between(source, "local function AcceptTest", "local function EndTradeTalkTask")
original += "\nlocal function StopAggro(inst) inst.stopped = true end\n"
original += "local function SetHue() end; local function SetBrightness() end; local function SetBrow() end; local function SetMane() end; local function SetVoice() end\n"
original += between(source, "local function OnSave", "local function TrackFishingHole")
original += "\nreturn {MakeTrader=MakeTrader, GiveReward=GiveReward, OnSave=OnSave, OnLoad=OnLoad, OnEntitySleep=OnEntitySleep, OnEntityWake=OnEntityWake}"

enhancement = (ROOT / "content/epic/sharkboi.lua").read_text(encoding="utf-8-sig")
# These are the actual enhancement wrappers that can restore stale stock_.
enhanced = between(enhancement, "local function savaandload", "local function onload")
enhanced += between(enhancement, "local function reward(inst)", 'AddPrefabPostInit("sharkboi"')
enhanced += "\nreturn function(inst)\n"
enhanced += between(enhancement, "    -- 奖励优化", "    reward(inst)")
enhanced += "\nreward(inst); savaandload(inst)\nend"

lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().original_source = original
lua.globals().enhanced_source = enhanced
lua.globals().patch_source = (ROOT / "content/extra/frostjaw_trade.lua").read_text(encoding="utf-8-sig")
for name in ["content/extra/extra.lua", "content/extra/frostjaw_trade.lua"]:
    lua.eval("function(s) return assert(loadstring(s)) end")((ROOT / name).read_text(encoding="utf-8-sig"))
lua.execute((ROOT / "tests/frostjaw_trade_regression.lua").read_text(encoding="utf-8-sig"))
