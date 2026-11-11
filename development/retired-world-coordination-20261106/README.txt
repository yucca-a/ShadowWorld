Retired world coordination sources (2026-11-06)

These files were removed from the shipped content directory after Shadow Nexus
became the sole enabled exchange implementation. The archived files are kept for
historical comparison and regression tests, and are not loaded by the mod.
manifest.json records the original bytes of each archived production source.

The current content/scripts/components/worldexchange2hm.lua is a separate,
passive compatibility reader. It preserves an unfinished old transaction record
and protects its container; it has no exchange protocol, timer, RPC, player gate,
world rollback or save coordination. Completed old records are not retained.

Shared live tools worldexchangeprotocol2hm, worldexchangestore2hm and
worldexchangerpc2hm remain in content because the independent vault uses them.
Item serialization and native persistence IO now live in shadowvaultitems2hm and
shadowvaultio2hm, without loading the retired coordinator.

The two scripts under tests/ are historical snapshots of the previous mode
tests. Current tests/run_exchange_modes_tests.py verifies the new runtime.
Current tests/run_fast_exchange_tests.py reads the archive for legacy regression
and continues to check the shared persistence store; it is not a live gameplay
test of the removed feature.
