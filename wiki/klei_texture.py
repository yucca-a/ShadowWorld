"""Read Klei KTEX artwork for Wiki thumbnails."""
import struct
from PIL import Image


def decode(data):
    assert data[:4] == b'KTEX'
    spec = struct.unpack_from('<I', data, 4)[0]
    fmt, count = (spec >> 4) & 31, (spec >> 13) & 31
    width, height, pitch, size = struct.unpack_from('<HHHI', data, 8)
    pixels = data[8+count*10:8+count*10+size]
    if fmt in (0, 1, 2):
        image = Image.frombytes('RGBA', (width,height), pixels, 'bcn', ((1,2,3)[fmt], ('DXT1','DXT3','DXT5')[fmt]))
    elif fmt in (4, 5):
        image = Image.frombytes('RGBA' if fmt == 4 else 'RGB', (width,height), pixels).convert('RGBA')
    else:
        raise ValueError(f'Unsupported KTEX format: {fmt}')
    return image.transpose(Image.Transpose.FLIP_TOP_BOTTOM)


def web_crop(image):
    image = image.convert('RGBA')
    # KTEX generally stores premultiplied alpha; restore edge colours for web compositing.
    image.putdata([(min(255,round(r*255/a)),min(255,round(g*255/a)),min(255,round(b*255/a)),a) if a else (0,0,0,0) for r,g,b,a in image.getdata()])
    bbox = image.getbbox()
    if bbox: image = image.crop(bbox)
    return image
