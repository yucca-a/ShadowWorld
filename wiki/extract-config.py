"""Evaluate actual modinfo.lua in an isolated Lua 5.1 runtime; export every option."""
from pathlib import Path
from bisect import bisect_right
import argparse
import hashlib
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'work/test-python'))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().locale = 'zh'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--mod-root', type=Path, default=ROOT / 'content', help='Directory containing the published modinfo.lua')
parser.add_argument('--check', action='store_true', help='Compare the generated snapshot with the checked-in snapshot')
args = parser.parse_args()
mod_root = args.mod_root.resolve()
modinfo = mod_root / 'modinfo.lua'
raw = modinfo.read_text(encoding='utf-8-sig')
instrumented = raw.replace('local conf = {name = key,', 'local conf = {__line = debug.getinfo(2, "l").currentline, name = key,')
lua.execute(instrumented)

def clean(value):
    if not isinstance(value, str):
        return value
    value = re.sub(r'[\U000f0000-\U000fffff]', '', value)
    return re.sub(r'\s+', ' ', value).strip().strip('-').strip()

LUA_TOKEN = re.compile(r'''(?P<comment>--(?:\[(?P<comment_level>=*)\[.*?\](?P=comment_level)\]|[^\r\n]*))
    |(?P<string>"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')
    |\[(?P<string_level>=*)\[.*?\](?P=string_level)\]
    |(?P<identifier>[a-zA-Z_]\w*)|\S''', re.VERBOSE | re.DOTALL)


def config_calls(text):
    tokens = [token for token in LUA_TOKEN.finditer(text) if not token.group('comment')]
    newlines = [line.start() for line in re.finditer('\n', text)]
    for name, opening, argument, separator in zip(tokens, tokens[1:], tokens[2:], tokens[3:]):
        if (name.group('identifier') == 'GetModConfigData' and opening[0] == '('
                and argument.group('string') and separator[0] in {')', ','}):
            yield argument[0][1:-1], bisect_right(newlines, name.start()) + 1


files = {}
for p in sorted(mod_root.rglob('*.lua')):
    if p.name == 'modinfo.lua':
        continue
    text = p.read_text(encoding='utf-8-sig')
    for key, line in config_calls(text):
        files.setdefault(key, []).append({'file': 'content/' + p.relative_to(mod_root).as_posix(), 'line': line})

mode, group, role = '通用设置', '通用设置', None
configs = []
for i in range(1, len(lua.globals().configuration_options) + 1):
    entry = lua.globals().configuration_options[i]
    label = clean(entry['label'])
    if not entry['name']:
        if label in ['简单模式', '困难模式', '暗影世界', 'Ray']:
            mode = label
            role = None
        elif label:
            group = label
            role = None
        continue
    name = entry['name']
    line = entry['__line']
    if not line:
        match = re.search(r'name\s*=\s*[\"\x27]' + re.escape(name) + r'[\"\x27]', raw)
        line = raw[:match.start()].count('\n') + 1 if match else None
    if label and '总开关' in label and name.endswith('_easy') and name != 'role_easy':
        role = name
    if name in ['other_role_easy', 'Monster Night Vision', 'wathom nightvision', 'All Right Dodge', 'Role Gym']:
        role = name if name == 'other_role_easy' else None
    opts = []
    for j in range(1, len(entry['options']) + 1):
        opt = entry['options'][j]
        opts.append({'label': clean(opt['description']), 'description': clean(opt['hover']) or '', 'value': opt['data']})
    configs.append({'key': name, 'label': label, 'description': clean(entry['hover']) or '', 'default': entry['default'], 'options': opts, 'mode': mode, 'group': group, 'roleParent': role if role != name else None, 'line': line, 'references': files.get(name, [])})

result = {'version': lua.globals().version, 'sourceHash': hashlib.sha256(modinfo.read_bytes()).hexdigest(), 'total': len(configs), 'configs': configs}
out = Path(__file__).resolve().parent / 'data/configs.json'
out.parent.mkdir(exist_ok=True)
snapshot = json.dumps(result, ensure_ascii=False, indent=2)+'\n'
if args.check:
    if out.read_text(encoding='utf-8') != snapshot:
        sys.exit('Configuration snapshot differs from the selected release source')
else:
    out.write_text(snapshot, encoding='utf-8')
print(f'Exported {len(configs)} actual settings from Lua 5.1; {sum(len(c["options"]) for c in configs)} choices.')
for mode in dict.fromkeys(c['mode'] for c in configs):
    print(mode, sum(c['mode'] == mode for c in configs))
