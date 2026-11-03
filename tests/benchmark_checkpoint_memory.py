"""Compare published/current journals with identical synthetic player/map bytes.

The filesystem stands in for native persistence. No running game is touched.
These numbers describe this controlled workload, not a live server's total RAM.
"""
from pathlib import Path
from zipfile import ZipFile
import argparse
import json
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--size-kb", type=int, default=256)
args = parser.parse_args()
results = []
with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as archive:
    dumper = archive.read("scripts/dumper.lua").decode("utf-8-sig")
    util = archive.read("scripts/util.lua").decode("utf-8-sig")
for variant in ["published", "working"]:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(dumper)
    for name in ["deepcopy", "RunInSandboxSafe"]:
        start = util.index("function " + name + "(")
        lua.execute(util[start:util.index("\nend", start) + 4])
    source = (subprocess.check_output(["git", "show", "v2.8.14.97.3:content/scripts/worldexchangestore2hm.lua"], cwd=ROOT).decode("utf-8")
              if variant == "published" else (ROOT / "content/scripts/worldexchangestore2hm.lua").read_text(encoding="utf-8"))
    lua.globals().Store = lua.execute(source)
    lua.globals().payload_bytes = args.size_kb * 1024
    counts = {"written": 0, "read": 0, "writes": 0}
    with tempfile.TemporaryDirectory(prefix="shadowworld-perf-") as directory:
        disk = Path(directory)
        def write(key, raw):
            (disk / key).write_text(raw, encoding="utf-8")
            counts["written"] += len(raw)
            counts["writes"] += 1
        def read(key):
            path = disk / key
            if not path.exists(): return False, None
            raw = path.read_text(encoding="utf-8")
            counts["read"] += len(raw)
            return True, raw
        lua.globals().diskwrite, lua.globals().diskread = write, read
        lua.globals().diskerase = lambda key: (disk / key).unlink(missing_ok=True)
        started = time.perf_counter()
        lua.execute('''
            local peak = 0
            local function sample() peak = math.max(peak, collectgarbage("count")) end
            local io = {
                encode = function(t) sample(); local raw = DataDumper(t,nil,true); sample(); return raw end,
                decode = RunInSandboxSafe,
                write = function(k,v,cb) sample(); diskwrite(k,v); cb(true) end,
                read = function(k,cb) local ok,raw=diskread(k); sample(); cb(ok,raw) end,
                erase = diskerase,
            }
            journal = Store.new(io, "BENCH"); journal:Load(function(state) assert(state) end)
            collectgarbage("collect"); baseline_kb = collectgarbage("count")
            for serial = 1, 8 do
                local cut = {id="test/"..serial,serial=serial,players={},owners={}}
                for user = 1, 4 do
                    local text = string.rep("map"..serial..user, math.ceil(payload_bytes/5)):sub(1,payload_bytes)
                    cut.players["KU_"..user] = "return {prefab='wilson',data={worldexchange_maps2hm='"..text.."'}}"
                    cut.owners["KU_"..user] = "1"
                end
                journal:PutCut(cut, "return {world="..serial.."}", function(ok,reason) assert(ok,reason) end)
                journal:Seal(cut.id, function(ok,reason) assert(ok,reason) end)
                sample()
            end
            collectgarbage("collect"); resident_kb = collectgarbage("count") - baseline_kb
            peak_kb = peak - baseline_kb
            journal_bytes = #DataDumper(journal.state,nil,true)
            -- All old checkpoint profiles remain recoverable after offloading.
            for serial=1,8 do
                journal:ReadCut("test/"..serial,function(world,why,cut)
                    assert(world and cut,why)
                    for user=1,4 do
                        assert(cut.players["KU_"..user]:find("map"..serial..user,1,true))
                    end
                end)
            end
        ''')
        results.append({"variant": variant, "seconds": round(time.perf_counter() - started, 4),
                        "resident_kb": round(lua.globals().resident_kb, 2), "sampled_peak_kb": round(lua.globals().peak_kb, 2),
                        "journal_bytes": lua.globals().journal_bytes, **counts})
    print(json.dumps(results[-1]), flush=True)
out = ROOT / "work/performance-audit"
out.mkdir(parents=True, exist_ok=True)
(out / ("checkpoint-memory-" + str(args.size_kb) + "kb.json")).write_text(json.dumps(results, indent=2))
