"""Decode the actual DST builds/animation transforms for a local canvas preview."""
from pathlib import Path
from zipfile import ZipFile
import json, re, struct
from PIL import Image
from build_assets import Reader, ROOT, GAME

HERE = Path(__file__).resolve().parent
OUT = HERE/'effects-preview-assets'


def decode(data):
    assert data[:4] == b'KTEX'
    header = struct.unpack_from('<I', data, 4)[0]
    fmt, levels = (header >> 4) & 31, (header >> 13) & 31
    w, h, _, size = struct.unpack_from('<HHHI', data, 8)
    raw = data[8 + levels*10:8 + levels*10 + size]
    im = Image.frombytes('RGBA', (w, h), raw, 'bcn',
                        ((1, 2, 3)[fmt], ('DXT1', 'DXT3', 'DXT5')[fmt]))
    im = im.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    im.putdata([(min(255, round(r*255/a)), min(255, round(g*255/a)),
                 min(255, round(b*255/a)), a) if a else (0, 0, 0, 0)
                for r, g, b, a in im.getdata()])
    return im


def export(path, wanted):
    with ZipFile(path) as z:
        r = Reader(z.read('build.bin'))
        magic, version, nsymbols, _ = r.read('4sIII')
        assert (magic, version) == (b'BILD', 6)
        name = r.string()
        atlases = [r.string() for _ in range(r.read('I'))]
        symbols = {}
        for _ in range(nsymbols):
            key, nframes = r.read('II')
            symbols[key] = [r.read('IIffffII') for _ in range(nframes)]
        vertices = [r.read('ffffff') for _ in range(r.read('I'))]
        names = {}
        for _ in range(r.read('I')):
            key = r.read('I'); names[key] = r.string()
        frame_data = {}
        for key, frames in symbols.items():
            frame_data[str(key)] = []
            for frame, duration, _, _, _, _, start, count in frames:
                assert count % 6 == 0
                quads = []
                for i in range(start, start+count, 6):
                    vs = vertices[i:i+6]
                    x1, x2 = min(v[0] for v in vs), max(v[0] for v in vs)
                    y1, y2 = min(v[1] for v in vs), max(v[1] for v in vs)
                    u1, u2 = min(v[3] for v in vs), max(v[3] for v in vs)
                    v1, v2 = min(v[4] for v in vs), max(v[4] for v in vs)
                    quads.append([int(vs[0][5]), x1, y1, x2-x1, y2-y1, u1, 1-v2, u2-u1, v2-v1])
                frame_data[str(key)].append(dict(frame=frame, duration=duration, quads=quads))
        urls = []
        for atlas in atlases:
            output = OUT/(name+'-'+Path(atlas).stem+'.png')
            decode(z.read(atlas)).save(output)
            urls.append('effects-preview-assets/'+output.name)
        r = Reader(z.read('anim.bin'))
        magic, version, _, _, _, count = r.read('4sIIIII')
        assert (magic, version) == (b'ANIM', 4)
        animations = {}
        for _ in range(count):
            anim = r.string(); facing, _, fps, nframes = r.read('BIfI')
            frames = []
            for _ in range(nframes):
                r.read('ffff'); events = r.read('I'); r.pos += 4*events
                frames.append([r.read('IIIfffffff') for _ in range(r.read('I'))])
            if anim in wanted:
                assert facing == 255
                animations[anim] = dict(fps=fps, frames=frames)
        assert set(animations) == set(wanted)
        return dict(atlases=urls, symbols=frame_data, animations=animations, names=names)


def render_checks(data):
    """Offline atlas geometry checks, not screenshots or repainted source art."""
    images = {p: Image.open(HERE/p).convert('RGBA')
              for key in ('shrine', 'fire') for p in data[key]['atlases']}

    def mul(a, b):
        return [a[0]*b[0]+a[2]*b[1], a[1]*b[0]+a[3]*b[1],
                a[0]*b[2]+a[2]*b[3], a[1]*b[2]+a[3]*b[3],
                a[0]*b[4]+a[2]*b[5]+a[4], a[1]*b[4]+a[3]*b[5]+a[5]]

    def frame(key, name, time):
        anim = data[key]['animations'][name]
        return anim['frames'][int(time*anim['fps']) % len(anim['frames'])]

    def draw(out, key, elements, parent):
        build = data[key]
        for el in sorted(elements, key=lambda e: -e[9]):
            f = next(f for f in build['symbols'][str(el[0])]
                     if f['frame'] <= el[1] < f['frame']+f['duration'])
            for q in f['quads']:
                im = images[build['atlases'][q[0]]]
                size = (max(1, round(q[3])), max(1, round(q[4])))
                uv = (q[5]*im.width, q[6]*im.height,
                      (q[5]+q[7])*im.width, (q[6]+q[8])*im.height)
                tile = im.transform(size, Image.Transform.EXTENT, uv, Image.Resampling.BICUBIC)
                m = mul(parent, mul(el[3:9], [q[3]/size[0], 0, 0, q[4]/size[1], q[1], q[2]]))
                a, b, c, d, tx, ty = m; det = a*d-b*c
                inverse = (d/det, -c/det, (c*ty-d*tx)/det, -b/det, a/det, (b*tx-a*ty)/det)
                out.alpha_composite(tile.transform(out.size, Image.Transform.AFFINE, inverse,
                                                   Image.Resampling.BICUBIC))

    for state, time in [('idle', 0), ('awake', .2), ('use', .37)]:
        out = Image.new('RGBA', (600, 620), (68, 76, 66, 255))
        parent = [1.02, 0, 0, 1.02, 300, 566]
        body = frame('shrine', 'jiggle' if state == 'use' else 'idle', time)
        draw(out, 'shrine', body, parent)
        if state != 'idle':
            for eye in data['eyes']:
                size = 1.25 if state == 'use' else 1
                m = mul(parent, mul(body[0][3:9], [data['sx']*eye['flip']*size, 0, 0,
                                                data['sy']*size, eye['x'], eye['y']]))
                draw(out, 'fire', frame('fire', 'level1_redux', time+eye['phase']), m)
        out.convert('RGB').save(HERE/('effects-'+state+'.png'))


if __name__ == '__main__':
    OUT.mkdir(exist_ok=True)
    source = (ROOT/'content/scripts/frostshrinefx2hm.lua').read_text()
    eyes = [dict(x=int(x), y=int(y), flip=int(flip), phase=eval(phase, {'__builtins__': {}}))
            for x, y, flip, phase in re.findall(r'\{ x = (-?\d+), y = (-?\d+), flip = (-?\d+), phase = ([0-9 /]+) \}', source)]
    sx, sy = map(float, re.search(r'SCALE_X, SCALE_Y = ([.\d]+), ([.\d]+)', source).groups())
    fade, pulse = map(float, re.search(r'FADE_TIME, PULSE_TIME = ([.\d]+), ([.\d]+)', source).groups())
    data = dict(shrine=export(ROOT/'content/anim/frostshrine2hm.zip', ['idle', 'jiggle']),
                fire=export(GAME/'data/anim/coldfire_fire.zip', ['level1_redux']),
                eyes=eyes, sx=sx, sy=sy, fade=fade, pulse=pulse)
    (OUT/'data.js').write_text('window.FROST_PREVIEW='+json.dumps(data, separators=(',', ':'))+';\n')
    render_checks(data)
    print('Exported native atlas geometry, animation frames, and Lua eye layout to', OUT)
