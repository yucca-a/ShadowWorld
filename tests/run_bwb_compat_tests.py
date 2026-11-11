"""Execute production hooks with native Hunger and the downloaded BWB hooks."""
from pathlib import Path
from zipfile import ZipFile
import argparse, sys

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"work/test-python"))
from lupa.lua51 import LuaRuntime
sys.stdout.reconfigure(encoding="utf-8")
p=argparse.ArgumentParser(description=__doc__)
p.add_argument("--before",action="store_true")
a=p.parse_args()
bwb=ROOT/"work/newconstant-research/steamcmd/steamapps/workshop/content/322330/3360553731"
lua=LuaRuntime(unpack_returned_tuples=True)
g=lua.globals()
with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as z:
    for key,name in {"class_source":"class","modifier_source":"util/sourcemodifierlist","native_hunger":"components/hunger"}.items():
        g[key]=z.read("scripts/"+name+".lua").decode("utf-8-sig")
source=ROOT/("work/vault-hardened-hosted-g53f5ieg/input" if a.before else "content")
g.sw_hunger=(source/"role/hunger.lua").read_text(encoding="utf-8-sig")
g.sw_autumn=(source/"weather/autumn.lua").read_text(encoding="utf-8-sig")
g.bwb_hunger=(bwb/"scripts/mains/postinit/components/hunger.lua").read_text(encoding="utf-8-sig")
g.bwb_badge=(bwb/"scripts/mains/init/widgets/hungerbadge.lua").read_text(encoding="utf-8-sig")
status=(bwb/"scripts/mains/init/widgets/statusdisplays.lua").read_text(encoding="utf-8-sig")
start=status.index("-- hungerpenalty")
g.bwb_status="return function(self)\n"+status[start:status.index("\nend\n",start)]+"\nend"
g.expect_bug=a.before
lua.execute((ROOT/"tests/bwb_compat_regression.lua").read_text(encoding="utf-8"))
