"""Check the native MNFS filename index; use --write before packaging new files."""
from pathlib import Path
import argparse
import struct

ROOT = Path(__file__).resolve().parents[1]


def path_hash(path):
    value = 0
    for byte in path.replace("\\", "/").lower().encode("utf-8"):
        value = (value * 65599 + byte) & 0xFFFFFFFF
    return value


def paths_in(root):
    return sorted({"mod.manifest"} | {p.relative_to(root).as_posix() for p in root.rglob("*") if p.is_file()})


def decode(data):
    if len(data) < 12:
        raise ValueError("Truncated MNFS header")
    magic, version, count = struct.unpack("<4sII", data[:12])
    if magic != b"MNFS" or version != 1 or len(data) != 12 + count * 4:
        raise ValueError("Invalid MNFS header or file count")
    return list(struct.unpack("<" + "I" * count, data[12:]))


def encode(paths):
    values = [path_hash(path) for path in paths]
    if len(set(values)) != len(values):
        raise ValueError("Filename hash collision")
    return struct.pack("<4sII", b"MNFS", 1, len(values)) + struct.pack("<" + "I" * len(values), *values)


def audit(root):
    paths = paths_in(root)
    values = decode((root / "mod.manifest").read_bytes())
    expected = {path_hash(path) for path in paths}
    actual = set(values)
    missing = [path for path in paths if path_hash(path) not in actual]
    extra = actual - expected
    if missing or extra or len(actual) != len(values):
        raise ValueError(f"Stale mod.manifest: missing={missing}; obsolete={len(extra)}; duplicate={len(values) - len(actual)}")
    return len(paths)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT / "content")
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    if args.write:
        (args.root / "mod.manifest").write_bytes(encode(paths_in(args.root)))
    print(f"Native mod.manifest: {audit(args.root)} files indexed")
