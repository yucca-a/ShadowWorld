"""Lua 5.1 checks for optional survival modes and private difficulty queries."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().package.path = str(ROOT / "content/scripts/?.lua").replace("\\", "/") + ";" + lua.globals().package.path
lua.globals().mod_sources = lua.table_from({str(p.relative_to(ROOT / "content")).replace("\\", "/"):
    p.read_text(encoding="utf-8-sig") for p in (ROOT / "content").rglob("*.lua")})
lua.execute((ROOT / "tests/survival_difficulty_regression.lua").read_text(encoding="utf-8-sig"))
