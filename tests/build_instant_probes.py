"""Build isolated native probes; never installs or enables them in the game."""
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "work/instant-exchange-probes"

speed = (ROOT / "tests/native/world_exchange_speed_fixture.lua").read_text(encoding="utf-8")
needle = "        local master = TheShard:IsMaster()\n"
assert speed.count(needle) == 1
speed = 'local Instant = require("worldexchangeinstant_probe")\n' + speed
speed = speed.replace(needle, '''        assert(TheNet:GetServerName() == "ShadowWorld isolated exchange test",
            "instant probe requires the disposable isolated test cluster")
        if not service.testinstant then
            assert(not service.protocol.active, "cannot replace an active durable transaction")
            -- Performance-only fixture. This bypass MUST NEVER be used in a player world.
            local guard = {}
            function guard:Generation() return "isolated-speed-test" end
            function guard:IsReady() return true end
            function guard:IsFrozen() return false end
            function guard:CanExchange() return true end
            function guard:Dirty() end
            service.protocol = Instant.new(service.protocol.io, service.protocol:Save(), guard)
            service.testinstant = true
            print("[INSTANT_RESEARCH] SPEED_ONLY checkpoint recovery adapter is not enabled")
        end
''' + needle)

for case in ("speed", "checkpoint"):
    folder = OUT / case
    (folder / "scripts").mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / "tests/experimental/instant_exchange_protocol.lua", folder / "scripts/worldexchangeinstant_probe.lua")
    shutil.copyfile(ROOT / "tests/experimental/snapshot_store.lua", folder / "scripts/worldexchange_snapshot_probe.lua")
    if case == "speed":
        (folder / "exchange_runtime_diagnostic.lua").write_text(speed, encoding="utf-8")
    else:
        shutil.copyfile(ROOT / "tests/native/world_exchange_checkpoint_probe.lua", folder / "exchange_runtime_diagnostic.lua")
print(f"Probes generated only: {OUT}")
