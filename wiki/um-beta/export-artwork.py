"""Export the Wiki's selected Public Beta textures from the locally installed Workshop mod."""
import argparse
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from zipfile import ZipFile

from PIL import Image

WIKI = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(WIKI))
from klei_texture import decode, web_crop

HERE = Path(__file__).resolve().parent
OUTPUT = WIKI / 'assets/um-beta'
ARTWORK = HERE / 'artwork.json'
EXPLICIT = {
    'cover': 'modicon.xml',
    **{role: f'images/avatars/avatar_{role}.xml' for role in ('winky', 'wixie', 'wathom')},
    **{item: f'images/scrapbook/{item}.xml' for item in (
        'cave_entrance_magmabiome', 'um_gemologyforge', 'moonmaw_dragonfly', 'veteranshrine',
    )},
}
VANILLA_IMAGE_OVERRIDES = {
    'hermit_bundle_lures': 'hermit_bundle',
    'boat_ancient_item_blueprint': 'blueprint_rare',
}


def extract_region(image, entry):
    width, height = image.size
    u1, u2, v1, v2 = (float(entry.attrib[k]) for k in ('u1', 'u2', 'v1', 'v2'))
    crop = image.crop((round(u1 * width), round((1 - v2) * height), round(u2 * width), round((1 - v1) * height)))
    return web_crop(crop)


def atlas_image(root, xml):
    atlas = ET.parse(root / xml).getroot()
    tex = xml.parent / atlas.find('Texture').attrib['filename']
    entry = next(e for e in atlas.findall('./Elements/Element') if e.attrib['name'] == f'{xml.stem}.tex')
    return extract_region(decode((root / tex).read_bytes()), entry), tex


def save(key, image, source, atlas, *, workshop=True):
    size = 512 if key == 'cover' else 96
    image.thumbnail((size, size), Image.Resampling.LANCZOS)
    filename = key + '.png'
    image.save(OUTPUT / filename, optimize=True)
    return {'path': f'assets/um-beta/{filename}', 'source': source, 'atlas': atlas,
            'width': image.width, 'height': image.height, 'workshop': workshop}


def vanilla_images(images_zip, missing, article_keys):
    names = {VANILLA_IMAGE_OVERRIDES.get(key, key): key for key in sorted(missing)}
    inventory_atlases = [f'images/inventoryimages{n}.xml' for n in range(1, 5)]
    scrapbook_atlases = [f'images/scrapbook_icons{n}.xml' for n in range(1, 4)]
    found = set()
    with ZipFile(images_zip) as archive:
        for xml in inventory_atlases + scrapbook_atlases:
            scrapbook = xml in scrapbook_atlases
            atlas = ET.fromstring(archive.read(xml))
            tex = 'images/' + atlas.find('Texture').attrib['filename']
            image = None
            for entry in atlas.findall('./Elements/Element'):
                key = names.get(entry.attrib['name'].removesuffix('.tex'))
                if not key or scrapbook and (key in found or key not in article_keys):
                    continue
                if image is None:
                    image = decode(archive.read(tex))
                found.add(key)
                yield key, save(key, extract_region(image, entry), tex, xml, workshop=False)


def export(root, game_images):
    snapshot = json.loads((HERE / 'snapshot.json').read_text(encoding='utf-8'))
    keys = {i for recipe in snapshot['recipes'] for i in
            (recipe['product'], *(ingredient['id'] for ingredient in recipe['ingredients']))}
    keys.update(snapshot['articleArtIds'])
    candidates = {}
    for key in sorted(keys | set(snapshot['artworkIds'])):
        for folder in ('images/inventoryimages', 'images', 'images/scrapbook'):
            xml = Path(folder, key + '.xml')
            if (root / xml).is_file():
                candidates[key] = xml
                break
    candidates.update({key: Path(xml) for key, xml in EXPLICIT.items()})
    OUTPUT.mkdir(parents=True, exist_ok=True)
    manifest = {}
    for key, xml in sorted(candidates.items()):
        image, tex = atlas_image(root, xml)
        manifest[key] = save(key, image, tex.as_posix(), xml.as_posix())
    icon = Image.open(OUTPUT / 'cover.png').convert('RGBA')
    icon.thumbnail((96, 96), Image.Resampling.LANCZOS)
    icon.save(OUTPUT / 'cover-icon.png', optimize=True)
    manifest['cover-icon'] = {**manifest['cover'], 'path': 'assets/um-beta/cover-icon.png',
                              'width': icon.width, 'height': icon.height}
    base = json.loads((WIKI / 'data/icon-manifest.json').read_text(encoding='utf-8'))
    base_keys = {key for key, art in base.items() if art['source'].startswith('DST images.zip/')}
    mod_count = len(manifest) - 2
    manifest.update(vanilla_images(game_images, keys - manifest.keys() - base_keys, set(snapshot['articleArtIds'])))
    ARTWORK.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Exported {mod_count} Public Beta icon thumbnails, the cover and {len(manifest) - 2 - mod_count} additional game icons.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('workshop', type=Path, help='Local Steam Workshop folder for mod 3193922031')
    parser.add_argument('game_images', type=Path, help='Local DST data/databundles/images.zip')
    args = parser.parse_args()
    export(args.workshop, args.game_images)
