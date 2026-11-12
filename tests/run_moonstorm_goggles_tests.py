"""Native vision/speed methods plus the actual moonstorm overlay event handlers."""
from pathlib import Path
from zipfile import ZipFile
import argparse,sys
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source',type=Path,default=ROOT/'content/weather/moonisland.lua')
args=parser.parse_args()
sys.path.insert(0,str(ROOT/'work/test-python'))
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as z:
    lua.execute(z.read('scripts/class.lua').decode('utf-8-sig'))
    lua.globals().vision_source=z.read('scripts/components/playervision.lua').decode('utf-8-sig')
    lua.globals().watcher_source=z.read('scripts/components/moonstormwatcher.lua').decode('utf-8-sig')
    s=z.read('scripts/widgets/moonstormover.lua').decode('utf-8-sig')
    a=s.index('self.inst:ListenForEvent("gogglevision"')
    b=s.index('if owner.components.playervision',a)
    lua.globals().overlay_source='return function(self,owner)\n'+s[a:b]+'\nend'
source=args.source.read_text(encoding='utf-8-sig')
lua.globals().patch_source=source[source.index('-- 月亮风暴专属护目镜'):source.index('local function moonstormsparkonsave')]
lua.execute((ROOT/'tests/moonstorm_goggles_regression.lua').read_text(encoding='utf-8'))
lua.execute('assert(loadstring(...))',source)
