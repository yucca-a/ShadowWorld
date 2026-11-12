"""Actual Complex Smart Pot matching/panel methods and collection UI adapters."""
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'work/test-python'))
from lupa.lua51 import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
base = Path('D:/SteamLibrary/steamapps/workshop/content/322330/3744378627/scripts')
lua.globals().package.path = ';'.join(str(p/'?.lua').replace('\\', '/') for p in [ROOT/'content/scripts', base])+';'+lua.globals().package.path
source = (base/'ui/recipe_panel.lua').read_text(encoding='utf-8-sig')
lua.execute('NativePanel={}')
for method in ['SetAcceptsStacksFromContainer', 'SetPotIngredients', 'OnSlotChanged']:
    start = source.index('function RecipePanel:'+method+'(')
    lua.execute(source[start:source.index('\nend', start)+4].replace('RecipePanel:', 'NativePanel:', 1))
lua.execute((ROOT/'tests/complex_smartpot_regression.lua').read_text(encoding='utf-8'))
