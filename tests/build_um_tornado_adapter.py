"""Emit reviewed storm bodies with only weather-marker refresh substituted."""
from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))
from build_um_compat_profiles import BASE, runtime

header = '''-- Reviewed UM movement bodies; keep movement, lightning and pulling timings.
-- Only the cancelled/recreated weather-expiry timer is replaced by a deadline.
local M = {}
local function RefreshWeather(target)
    target:AddTag("under_the_weather")
    target.um_tornado_weatheruntil2hm = GetTime() + 1
    if target.um_tornado_weathertask == nil then
        target.um_tornado_weathertask = target:DoTaskInTime(1, M.ExpireWeather)
    end
end
function M.ExpireWeather(target)
    local remaining = (target.um_tornado_weatheruntil2hm or 0) - GetTime()
    if remaining > 0 then
        target.um_tornado_weathertask = target:DoTaskInTime(remaining, M.ExpireWeather)
    else
        target.um_tornado_weathertask = nil
        target.um_tornado_weatheruntil2hm = nil
        target:RemoveTag("under_the_weather")
    end
end
'''
pieces = [header]
for branch, uid in [("stable", "2039181790"), ("beta", "3193922031")]:
    path = "scripts/prefabs/um_tornado.lua"
    source = (BASE / uid / path).read_text(encoding="utf-8-sig")
    begin = source.index("local function TornadoTask(")
    end = source.index("\nend", begin) + 4
    body = source[begin:end]
    start_refresh = body.index('                v:AddTag("under_the_weather")')
    end_refresh = body.index('\n            end\n            if not IsUnderRainDomeAtXZ', start_refresh)
    original = body[start_refresh:end_refresh]
    assert 'v.um_tornado_weathertask = v:DoTaskInTime(1,' in original
    body = body[:start_refresh] + '                RefreshWeather(v)' + body[end_refresh:]
    lua = runtime()
    prefab = lua.globals().readfn(source, path)[0]
    target = lua.globals().nested(prefab.fn, "TornadoTask")
    signature = lua.globals().fingerprint(target)
    lua.globals().target = target
    names = lua.eval("function()local t={}for i=1,128 do local n=debug.getupvalue(target,i)if not n then break end t[#t+1]=n end return table.concat(t,',')end")().split(',')
    pieces.append('M["' + signature + '"] = function(values, globals)')
    for name in names: pieces.append('    local ' + name + ' = values.' + name)
    pieces.append(body)
    pieces.append('    setfenv(TornadoTask, globals)\n    return TornadoTask\nend\n')
pieces.append('return M\n')
(ROOT / 'content/scripts/umtornado2hm.lua').write_text('\n'.join(pieces), encoding='utf-8')
print(json.dumps({'reviewed_variants': 2}))
