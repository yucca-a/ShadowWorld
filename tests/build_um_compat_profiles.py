"""Build reviewed Lua implementation fingerprints; runtime never auto-accepts updates."""
from pathlib import Path
from zipfile import ZipFile
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "work/test-python"))
from lupa.lua51 import LuaRuntime

BASE = ROOT / "work/newconstant-research/steamcmd/steamapps/workshop/content/322330"
BOOT = r'''
GLOBAL=_G
Asset=function()return {}end
Prefab=function(name,fn)return {name=name,fn=fn}end
MakePlacer=function(name)return {name=name,fn=function()end}end
SetSharedLootTable=function()end
require=function()return {GetUpvalue=function()return function()return 1 end end}end
GROUND={SCALE=999};PI=math.pi
TUNING={TOTAL_DAY_TIME=480,DSTU={STORMS_PERFORMANCE='off'}}
UM_CONFIG={UM_STORMS_PERFORMANCE='off',BUTTERFLY_TWEAKS='unique'}
UMCommonFns={GHOSTLIKE_TAGS={}}
TheWorld={ismastersim=true,components={worldsettingstimer={AddTimer=function()end}}}
TheNet={IsDedicated=function()return false end}
Ents={}
table.invert=function(a)local r={}for _,v in ipairs(a)do r[v]=true end return r end
JoinArrays=function(a,b)local r={}for _,v in ipairs(a)do r[#r+1]=v end for _,v in ipairs(b)do r[#r+1]=v end return r end
hooks={}
env={AddComponentPostInit=function(name,fn)hooks[name]=fn end}
function readfn(source,path)return assert(loadstring(source,'@'..path))()end
function fingerprint(fn)return Guard.Fingerprint(fn)end
function nested(fn,name)local slot=Guard.Find(fn,name);return slot and slot.value end
'''


def runtime():
    lua = LuaRuntime(unpack_returned_tuples=True, max_memory=128 * 1024 * 1024)
    with ZipFile("D:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts.zip") as z:
        lua.execute(z.read("scripts/class.lua").decode("utf-8-sig"))
    lua.globals().Guard = lua.execute((ROOT / "content/scripts/umcompatguard2hm.lua").read_text(encoding="utf-8"))
    lua.execute(BOOT)
    return lua


def inspect(source):
    lua = runtime()
    g = lua.globals()
    collected, source_hashes = {}, {}

    def load(path):
        p = source / path
        if not p.exists():
            return None
        source_hashes[path] = hashlib.sha256(p.read_bytes()).hexdigest()
        return g.readfn(p.read_text(encoding="utf-8-sig"), path)

    def put(key, fn, path):
        if fn is not None:
            value = g.fingerprint(fn)
            assert value, key
            collected[key] = {"file": path, "hash": value}

    for file, names in [
        ("scripts/components/snowstormwatcher.lua", {"watcher_update": "OnUpdate", "watcher_level": "UpdateSnowstormLevel", "watcher_speed": "UpdateSnowstormWalkSpeed"}),
        ("scripts/components/um_snow_stormspawner.lua", {"storm_update": "OnUpdate", "storm_toggle": "ToggleSnowstorm", "storm_load": "OnLoad", "storm_post": "OnPostInit"}),
    ]:
        cls = load(file)
        if cls:
            for key, name in names.items(): put(key, cls[name], file)
            if "watcher" in file:
                put("pile_chance", g.nested(cls.StartSnowPileTask, "SnowpileChance"), file)
                put("pile_try", cls.TrySpawning or g.TrySpawning, file)
            else:
                for key, name in [("storm_stop", "StopSnowstorm"), ("storms_stop", "StopSnowstorms"), ("storm_season", "OnSeasonChange")]:
                    put(key, g.nested(cls.OnUpdate if key != "storm_season" else cls._ctor, name), file)

    for file, prefab_index, names in [
        ("scripts/prefabs/hooded_fern.lua", 0, {"fern_register":"RegisterPathFinding", "fern_unregister":"UnregisterPathFinding"}),
        ("scripts/prefabs/um_ocupus.lua", 0, {"ocupus_born":"Born", "ocupus_remove":"RemoveAllTentacles", "ocupus_pullout":"PullOut", "ocupus_add_eye":"AddOcupusEyeTentacle", "ocupus_spawn_tentacle":"SpawnTentacle"}),
        ("scripts/prefabs/um_ocupus_eyetacle.lua", 0, {"eye_watch":"CheckForVictimsLong", "eye_respawn":"SpawnNewEyeTentacle"}),
        ("scripts/prefabs/um_ocupus_eyetacle.lua", 1, {"eye_hide":"Hide", "eye_appear":"Appear"}),
        ("scripts/prefabs/snowpile.lua", 0, {"pile_season":"OnSeasonChange"}),
        ("scripts/prefabs/air_conditioner_smoke.lua", 0, {"smoke_constructor":None}),
        ("scripts/prefabs/air_conditioner_smoke.lua", 1, {"cloud_near":"OnNear"}),
        ("scripts/prefabs/um_tornado.lua", 0, {"tornado_tick":"TornadoTask"}),
        ("scripts/prefabs/uncompromising_rat.lua", "uncompromising_ratsniffer", {"legacy_rat_check":"TimeForACheckUp"}),
        ("scripts/prefabs/mock_dragonfly.lua", 0, {"legacy_dragon_sleep":"OnEntitySleep", "legacy_dragon_season":"OnSeasonChange"}),
        ("scripts/prefabs/moonmaw_dragonfly.lua", 0, {"legacy_moonmaw_sleep":"OnEntitySleep", "legacy_moonmaw_season":"OnSeasonChange"}),
        ("scripts/prefabs/minotaur_organ.lua", 0, {"legacy_organ_shield":"ActivateShield"}),
        ("scripts/prefabs/um_armor_pyre_nettles.lua", 0, {"legacy_nettles_bump":"bumpcheck"}),
    ]:
        prefabs = load(file)
        if prefabs is None: continue
        if isinstance(prefab_index, str):
            prefab = next(p for p in (prefabs if isinstance(prefabs, tuple) else (prefabs,)) if p.name == prefab_index)
        else:
            prefab = prefabs[prefab_index] if isinstance(prefabs, tuple) else prefabs
        for key, name in names.items(): put(key, g.nested(prefab.fn, name) if name else prefab.fn, file)

    file = "scripts/components/um_snowstormmanager.lua"
    cls = load(file)
    if cls:
        obj = cls(lua.table())
        put("pile_unregister", obj.UnregisterSnowpile, file)
        put("pile_count", obj.CheckForOtherSnowpiles, file)
    file = "scripts/components/um_ocupusappearinator.lua"
    cls = load(file)
    if cls:
        obj = cls(lua.eval("{ListenForEvent=function()end}"))
        put("ocupus_tiles", g.nested(obj.SpawnOcupi, "IterateThroughTiles"), file)
        put("ocupus_location", g.nested(obj.SpawnOcupi, "FindLocation"), file)
        put("ocupus_spacing", g.nested(obj.SpawnOcupi, "CheckForOtherOcupi"), file)
    for file, component, key in [
        ("init/init_weather/init_thicket.lua", "locomotor", "thicket_update"),
        ("postinit/components/weather.lua", "weather", "weather_update"),
    ]:
        if (source / file).exists():
            load(file)
            obj = lua.eval("{OnUpdate=function()end}")
            g.hooks[component](obj)
            put(key, obj.OnUpdate, file)
            if component == "locomotor": put("thicket_check", g.nested(obj.OnUpdate, "ThicketCheck"), file)
    return collected, source_hashes


if __name__ == "__main__":
    profiles, evidence = {}, {}
    for branch, uid in [("stable", "2039181790"), ("beta", "3193922031")]:
        rows, hashes = inspect(BASE / uid)
        evidence[branch] = {"source": str(BASE / uid), "files": hashes, "profiles": rows}
        for key, entry in rows.items():
            profile = profiles.setdefault(key, {"file": entry["file"], "hashes": set()})
            assert profile["file"] == entry["file"]
            profile["hashes"].add(entry["hash"])
    lines = ["-- Reviewed against workshop stable 1.5.4.6 and beta 6.0.3.9 on 2026-11-10.",
             "-- Updating this allowlist requires source review and regression/native validation.", "return {"]
    for key, value in sorted(profiles.items()):
        entries = ", ".join('["' + h + '"] = true' for h in sorted(value["hashes"]))
        lines.append('    ' + key + ' = {file = "' + value["file"] + '", hashes = {' + entries + '}},')
    lines.append("}\n")
    (ROOT / "content/scripts/umcompatprofiles2hm.lua").write_text("\n".join(lines), encoding="utf-8")
    (ROOT / "development/validation/um-performance-reviewed-profiles-20261110.json").write_text(
        json.dumps(evidence, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"profiles": len(profiles), "per_branch": {k: len(v["profiles"]) for k, v in evidence.items()}}))
