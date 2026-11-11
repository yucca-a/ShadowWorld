"""Focused vault journal custody tests with the actual Lua adapter and journal."""
from pathlib import Path
import runpy
ROOT=Path(__file__).resolve().parents[1]
b=runpy.run_path(str(ROOT/'tests/run_shadow_vault_tests.py'));lua=b['lua']
s=(ROOT/'tests/shadow_vault_regression.lua').read_text(encoding='utf-8')
lua.execute(s+'\nVA_TEST={entity=entity,box=box,service=service}\n')
lua.execute((ROOT/'tests/shadow_vault_journal_regression.lua').read_text(encoding='utf-8'))
lua.execute((ROOT/'tests/shadow_vault_capture_recovery.lua').read_text(encoding='utf-8'))
lua.execute((ROOT/'tests/shadow_vault_native_adoption.lua').read_text(encoding='utf-8'))
lua.execute((ROOT/'tests/shadow_vault_proxy_regression.lua').read_text(encoding='utf-8'))
