"""Export the selected shrine v4 and core v3 using Klei's official compiler.

Only format conversion/cropping/scaling is performed; the selected artwork is
not repainted. Build into work/ by default; --install backs up and copies assets.
"""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from io import BytesIO
from datetime import datetime
import argparse, hashlib, json, shutil, struct, subprocess
import xml.etree.ElementTree as ET
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
WORK = ROOT / 'work/frost-assets-build'
GAME = Path("D:/SteamLibrary/steamapps/common/Don't Starve Together")
MODTOOLS = Path("D:/SteamLibrary/steamapps/common/Don't Starve Mod Tools/mod_tools")
PY2 = MODTOOLS / 'buildtools/windows/Python27/python.exe'
COMPILER = MODTOOLS / 'tools/scripts/buildanimation.py'
CONVERTER = MODTOOLS / 'tools/bin/TextureConverter.exe'
SPECS = [
    dict(name='frostshrine2hm', source='2026-11-04-frost-v4/frost-shrine-v4.png',
         master='frost-shrine-v4.png', height=512, ground=24, icon='images/frostshrine2hm'),
    dict(name='frostcore2hm', source='2026-11-04-frost-v3/frost-core-v3.png',
         master='frost-core-v3.png', height=144, ground=24, icon='images/inventoryimages/frostcore2hm', icon_size=64),
]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

class Reader:
    def __init__(self, data): self.data, self.pos = data, 0
    def read(self, fmt):
        values = struct.unpack_from('<'+fmt, self.data, self.pos)
        self.pos += struct.calcsize('<'+fmt)
        return values[0] if len(values) == 1 else values
    def string(self):
        n = self.read('I'); value = self.data[self.pos:self.pos+n]; self.pos += n
        return value.decode('utf-8')

def original_shrine_motion():
    """Retain the engine's existing chesspiece idle/hammer feedback transforms."""
    with ZipFile(GAME/'data/anim/chesspiece.zip') as archive:
        r = Reader(archive.read('anim.bin'))
    magic, version, _, _, _, count = r.read('4sIIIII')
    assert (magic, version) == (b'ANIM', 4)
    motion = {}
    for _ in range(count):
        name = r.string()
        facing, bank, fps, frames = r.read('BIfI')
        values = []
        for _ in range(frames):
            r.read('ffff')
            events = r.read('I'); r.pos += 4*events
            elements = [r.read('IIIfffffff') for _ in range(r.read('I'))]
            if name in ('idle', 'jiggle'):
                assert len(elements) == 1 and facing == 255
                values.append(elements[0][3:9])
        if values: motion[name] = (int(fps), values)
    assert set(motion) == {'idle', 'jiggle'}
    return motion

def make_xml(spec, image, motion):
    w, h = image.size
    cx, cy = 0, -h/2 + spec['ground']
    build = ET.Element('Build', name=spec['name'])
    symbol = ET.SubElement(build, 'Symbol', name='body')
    ET.SubElement(symbol, 'Frame', framenum='0', duration='1', image='body',
                  x=str(cx), y=str(cy), w=str(w), h=str(h))
    animations = ET.Element('Anims')
    for name, (fps, transforms) in motion.items():
        anim = ET.SubElement(animations, 'anim', name=name, root=spec['name'], framerate=str(fps))
        for a, b, c, d, tx, ty in transforms:
            corners = [(a*x+c*y+tx, b*x+d*y+ty)
                       for x in (-w/2, w/2) for y in (cy-h/2, cy+h/2)]
            left, right = min(p[0] for p in corners), max(p[0] for p in corners)
            top, bottom = min(p[1] for p in corners), max(p[1] for p in corners)
            frame = ET.SubElement(anim, 'frame', x=str((left+right)/2), y=str((top+bottom)/2),
                                  w=str(right-left), h=str(bottom-top))
            ET.SubElement(frame, 'element', name='body', frame='0', layername='body', z_index='0',
                          **dict(zip(('m_a','m_b','m_c','m_d','m_tx','m_ty'), map(str,(a,b,c,d,tx,ty)))))
    return ET.tostring(build), ET.tostring(animations)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--install', action='store_true')
    args = parser.parse_args()
    source_dir = WORK/'intermediate'; stage = WORK/'compiled'
    source_dir.mkdir(parents=True, exist_ok=True)
    stage.mkdir(parents=True, exist_ok=True)
    motion = original_shrine_motion()
    manifest = {'selected': [], 'outputs': [], 'compiler': str(COMPILER),
                'scope': 'Local artwork resource replacement; no gameplay changes or Workshop upload.'}
    for spec in SPECS:
        source = ROOT/'development/art-previews'/spec['source']
        master = HERE/spec['master']
        if master.exists(): assert sha(master) == sha(source), 'Selected master differs; refuse overwrite'
        else: shutil.copy2(source, master)
        image = Image.open(master).convert('RGBA')
        # Ignore near-invisible generator noise for the crop rectangle only.
        # Original alpha inside the rectangle is kept, including antialiased edges.
        bbox = image.getchannel('A').point(lambda a: 255 if a >= 16 else 0).getbbox()
        assert bbox
        image = image.crop(bbox)
        world = image.resize((round(image.width*spec['height']/image.height), spec['height']), Image.Resampling.LANCZOS)
        world.save(source_dir/(spec['name']+'-world.png'))
        anims = motion if spec['name'] == 'frostshrine2hm' else {'idle': (30, [(1,0,0,1,0,0)])}
        buildxml, animxml = make_xml(spec, world, anims)
        png = BytesIO(); world.save(png, format='PNG')
        input_zip = source_dir/(spec['name']+'.zip')
        with ZipFile(input_zip, 'w', ZIP_DEFLATED) as archive:
            archive.writestr('build.xml', buildxml)
            archive.writestr('animation.xml', animxml)
            archive.writestr('body.png', png.getvalue())
        subprocess.run([str(PY2), str(COMPILER), str(input_zip), '--outputdir', str(stage), '--force'], check=True)
        output_zip = stage/'anim'/(spec['name']+'.zip')
        assert output_zip.exists()
        with ZipFile(output_zip) as archive:
            assert {'anim.bin','build.bin','atlas-0.tex'} <= set(archive.namelist())
            assert archive.read('build.bin')[:8] == b'BILD\x06\x00\x00\x00'
        # Transparent 128px source icon, with a 6px inset before any export resize.
        icon = Image.new('RGBA',(128,128))
        icon_art = image.copy(); icon_art.thumbnail((116,116), Image.Resampling.LANCZOS)
        icon.alpha_composite(icon_art,((128-icon_art.width)//2,(128-icon_art.height)//2))
        pngpath = source_dir/(spec['name']+'-icon.png'); icon.save(pngpath)
        tex = stage/(spec['icon']+'.tex'); tex.parent.mkdir(parents=True,exist_ok=True)
        icon_size = spec.get('icon_size')
        resize = ['-w', str(icon_size), '-h', str(icon_size), '--filter', 'lanczos3'] if icon_size else []
        subprocess.run([str(CONVERTER),'--swizzle','--format','bc3','--platform','opengl',
                        '--premultiply','--mipmap',*resize,'-i',str(pngpath),'-o',str(tex)],check=True)
        atlas = ET.Element('Atlas'); ET.SubElement(atlas,'Texture',filename=tex.name)
        elements=ET.SubElement(atlas,'Elements')
        ET.SubElement(elements,'Element',name=tex.name,u1='0.0078125',u2='0.9921875',v1='0.0078125',v2='0.9921875')
        xml=tex.with_suffix('.xml'); xml.write_bytes(ET.tostring(atlas)+b'\n')
        manifest['selected'].append(dict(name=spec['name'],source=spec['source'],sha256=sha(master),
                                          crop=bbox,world_size=world.size,ground_anchor=spec['ground'],
                                          animations={n:len(m[1]) for n,m in anims.items()}))
        for path in (output_zip,tex,xml):
            manifest['outputs'].append(dict(path=path.relative_to(stage).as_posix(),sha256=sha(path),bytes=path.stat().st_size))
    if args.install:
        backup=ROOT/'backups'/('frost-art-before-'+datetime.now().strftime('%Y%m%d-%H%M%S'))
        files=[o['path'] for o in manifest['outputs']]+['scripts/prefabs/frostshrine2hm.lua','scripts/prefabs/frostcore2hm.lua']
        backup_record=[]
        for rel in files:
            src=ROOT/'content'/rel
            backup_record.append(dict(path=rel,existed=src.exists(),sha256=sha(src) if src.exists() else None))
            if src.exists():
                dest=backup/rel; dest.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(src,dest)
        backup.mkdir(parents=True,exist_ok=True)
        (backup/'manifest.json').write_text(json.dumps(backup_record,indent=2),encoding='utf-8')
        for entry in manifest['outputs']:
            dest=ROOT/'content'/entry['path']; dest.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(stage/entry['path'],dest)
        manifest['backup']=str(backup)
        manifest['installed']=True
    (HERE/'build-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(manifest,indent=2))

if __name__=='__main__': main()
