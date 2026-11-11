"""Exercise real mode gates and upstream exchange RPCs with simulated shards."""
from pathlib import Path
from zipfile import ZipFile
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
source = lambda path: (ROOT / "content" / path).read_text(encoding="utf-8-sig")
with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as archive:
    lua.execute(archive.read("scripts/dumper.lua").decode("utf-8-sig"))
    util = archive.read("scripts/util.lua").decode("utf-8-sig")
    start = util.index("function RunInSandboxSafe(")
    lua.execute(util[start:util.index("\nend", start) + 4])
    rpc = archive.read("scripts/networkclientrpc.lua").decode("utf-8-sig")
    lua.globals().native_exit_rpc_source = (
        'local MOD_RPC_HANDLERS, RPC_Queue = handlers, queued\n'
        'local USERID_RPCS, RPC_Queue_Limiter, RPC_Queue_Warned, RPC_QUEUE_RATE_LIMIT = {}, {}, {}, 20\n'
        + rpc[rpc.index('function HandleModRPC('):rpc.index('function HandleClientModRPC(')]
        + rpc[rpc.index('function MarkUserIDRPC('):rpc.index('--For gamelogic to deactivate world')]
    )

collect = source("easy_other/containersort.lua")
start = collect.index('local worldexchangemode =')
lua.globals().container_mode_source = collect[start:collect.index('local itemscfg =', start)] + '\nreturn worldexchangecfg, traditionalexchange'
start = collect.index("local function defaultbtnvalidfn(")
lua.globals().exchange_source = collect[start:collect.index("-- 容器收集", start)]
lua.globals().mode_source = source("easy_other/worldexchangefast.lua").split("local function engine()", 1)[0]
exit_source = source("easy_other/worldexchangefast.lua")
if "--reproduce-workshop-exit" in sys.argv:
    released = Path("D:/SteamLibrary/steamapps/workshop/content/322330/3832182265/easy_other/worldexchangefast.lua")
    exit_source = released.read_text(encoding="utf-8-sig")
lua.globals().exit_source = exit_source[exit_source.index("local clientExit"):]
fast = source("easy_other/worldexchangefast.lua")
lua.globals().migration_source = fast[fast.index("local MIGRATION_TIMEOUT"):fast.index('AddComponentPostInit("worthyportal"')]
lua.globals().worthy_source = (
    fast[fast.index("local MIGRATION_TIMEOUT"):fast.index("-- Accept the native portal action.")]
    + fast[fast.index('AddComponentPostInit("worthyportal"'):fast.index("local transferItem")]
)
lua.globals().install_source = source("easy_other/worldexchange.lua").split("AddShardModRPCHandler", 1)[0]
lua.globals().info_source = source("modinfo.lua")
engine = source("scripts/worldexchangeengine2hm.lua")
lua.globals().idle_source = engine[engine.index("function Engine:Idle()"):engine.index("function Engine:ReadPlayer(")]
lua.execute((ROOT / "tests/exchange_modes_regression.lua").read_text(encoding="utf-8"))
