"""Build the three external M-ART-VAN atlases without dependencies.

    python tools/build_van_atlases.py [--root <output repo>] [--source-root <source repo>]

Canonical colors define the palette. ComfyUI/FLUX sources contribute only
high-frequency microdetail: a wide local mean is removed, the residual is
clamped to a few RGB levels, then balanced to zero mean. Baked lighting and
source hue therefore cannot shift the authored palette.
"""
import argparse
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from texture_check import read_png
from texture_seamless import write_png

SIDE = 1024

YELLOW = (232, 177, 20)
RED = (200, 32, 28)
CREAM = (225, 215, 190)
GLASS = (35, 78, 92)
TRIM = (28, 30, 32)
FLOOR = (38, 38, 40)
RACK = (92, 86, 76)
SEAT = (50, 49, 52)
WALL = (166, 157, 144)
TREAD = (32, 32, 32)
SIDEWALL = (24, 24, 24)
RIM = (121, 121, 121)

ATLASES = {
    "bus_exterior_atlas_v1.png": {
        "regions": [
            {"name": "yellow_body", "rect": (0, 0, 1024, 512), "rgb": YELLOW,
             "source": "docs/referencias/van_tex_src_yellow_v1.png", "detail": 4},
            {"name": "red_stripe", "rect": (0, 512, 256, 512), "rgb": RED,
             "source": "docs/referencias/van_tex_src_red_v1.png", "detail": 2},
            {"name": "cream_roof", "rect": (256, 512, 256, 512), "rgb": CREAM,
             "source": "docs/referencias/van_tex_src_cream_v1.png", "detail": 2},
            {"name": "glass", "rect": (512, 512, 256, 512), "rgb": GLASS},
            {"name": "dark_trim", "rect": (768, 512, 256, 512), "rgb": TRIM},
        ],
    },
    "bus_interior_atlas_v1.png": {
        "regions": [
            {"name": "floor", "rect": (0, 0, 512, 512), "rgb": FLOOR,
             "source": "docs/referencias/van_tex_src_floor_v1.png", "detail": 4},
            {"name": "rack", "rect": (512, 0, 512, 512), "rgb": RACK,
             "source": "docs/referencias/van_tex_src_rack_v1.png", "detail": 3},
            {"name": "seat", "rect": (0, 512, 512, 512), "rgb": SEAT,
             "source": "docs/referencias/van_tex_src_seat_v1.png", "detail": 3},
            {"name": "wall", "rect": (512, 512, 512, 512), "rgb": WALL,
             "source": "docs/referencias/van_tex_src_cream_v1.png", "detail": 2},
        ],
    },
    "bus_wheel_atlas_v1.png": {
        "regions": [
            {"name": "tread", "rect": (0, 0, 328, 1024), "rgb": TREAD,
             "source": "docs/referencias/van_tex_src_tire_v2.png", "detail": 4,
             "uv_blender": (0.02, 0.02, 0.31, 0.98)},
            {"name": "sidewall", "rect": (328, 0, 184, 1024), "rgb": SIDEWALL,
             "source": "docs/referencias/van_tex_src_tire_v2.png", "detail": 1,
             "uv_blender": (0.34, 0.02, 0.48, 0.98)},
            {"name": "rim", "rect": (512, 0, 512, 1024), "rgb": RIM,
             "source": "docs/referencias/van_tex_src_rim_v1.png", "detail": 3,
             "uv_blender": (0.52, 0.02, 0.98, 0.98)},
        ],
    },
}


def _luma(row, pixel, channels):
    start = pixel * channels
    return (row[start] * 2 + row[start + 1] * 3 + row[start + 2]) // 6


def flux_detail(path, width, height, amplitude):
    src_width, src_height, channels, rows = read_png(str(path))
    if channels not in (3, 4):
        raise ValueError("%s: RGB/RGBA required" % path)
    deltas = []
    radius = max(8, min(src_width, src_height) // 24)
    for y in range(height):
        sy = min(src_height - 1, int((y + 0.5) * src_height / height))
        ym = max(0, sy - radius)
        yp = min(src_height - 1, sy + radius)
        for x in range(width):
            sx = min(src_width - 1, int((x + 0.5) * src_width / width))
            xm = max(0, sx - radius)
            xp = min(src_width - 1, sx + radius)
            center = _luma(rows[sy], sx, channels)
            local = (_luma(rows[sy], xm, channels) + _luma(rows[sy], xp, channels) +
                     _luma(rows[ym], sx, channels) + _luma(rows[yp], sx, channels)) // 4
            deltas.append(max(-amplitude, min(amplitude, round((center - local) / 12))))
    # Preserve the canonical region mean exactly. Deterministic rebalancing only
    # changes pixels that still have room inside the declared amplitude.
    balance = sum(deltas)
    direction = -1 if balance > 0 else 1
    remaining = abs(balance)
    while remaining:
        changed = 0
        for index, value in enumerate(deltas):
            if remaining == 0:
                break
            candidate = value + direction
            if -amplitude <= candidate <= amplitude:
                deltas[index] = candidate
                remaining -= 1
                changed += 1
        if changed == 0:
            raise ValueError("cannot balance FLUX detail from %s" % path)
    return deltas


def textured(width, height, rgb, source, amplitude):
    deltas = flux_detail(source, width, height, amplitude)
    output = []
    for y in range(height):
        row = bytearray(width * 3)
        for x in range(width):
            delta = deltas[y * width + x]
            row[x * 3:x * 3 + 3] = bytes(channel + delta for channel in rgb)
        output.append(bytes(row))
    return output


def solid(width, height, rgb):
    return [bytes(rgb) * width] * height


def paste(canvas, source, x0, y0):
    for y, row in enumerate(source):
        start = x0 * 3
        canvas[y0 + y][start:start + len(row)] = row


def build(path, regions, source_root):
    canvas = [bytearray(SIDE * 3) for _ in range(SIDE)]
    for region in regions:
        x, y, width, height = region["rect"]
        data = textured(width, height, region["rgb"], source_root / region["source"], region["detail"]) \
            if "source" in region else solid(width, height, region["rgb"])
        paste(canvas, data, x, y)
    write_png(str(path), SIDE, SIDE, 3, [bytes(row) for row in canvas])


def metadata(name, specification):
    regions = []
    for region in specification["regions"]:
        item = {"name": region["name"], "rect_px": list(region["rect"]),
                "rgb_mean": list(region["rgb"])}
        if "source" in region:
            item.update({"source": region["source"], "source_usage": "FLUX high-pass microdetail",
                         "detail_amplitude": region["detail"]})
        if "uv_blender" in region:
            item["uv_blender"] = list(region["uv_blender"])
        regions.append(item)
    return {
        "file": name,
        "kind": "atlas",
        "generator": "tools/build_van_atlases.py",
        "size": [SIDE, SIDE],
        "composition": "canonical palette plus zero-mean high-pass FLUX microdetail",
        "sources": sorted({r["source"] for r in specification["regions"] if "source" in r}),
        "regions": regions,
        "licence": "Apache-2.0 (FLUX.1 schnell sources); deterministic local composition",
        "not_checked": "logos/text/brand and visual coherence require human review",
    }


def main(argv=None):
    parser = argparse.ArgumentParser()
    default_root = str(Path(__file__).resolve().parent.parent)
    parser.add_argument("--root", default=default_root)
    parser.add_argument("--source-root", default=default_root)
    arguments = parser.parse_args(argv)
    output = Path(arguments.root) / "assets/textures"
    source_root = Path(arguments.source_root)
    output.mkdir(parents=True, exist_ok=True)
    for name, specification in ATLASES.items():
        target = output / name
        build(target, specification["regions"], source_root)
        (output / name.replace(".png", ".json")).write_text(
            json.dumps(metadata(name, specification), indent="\t", ensure_ascii=False) + "\n",
            encoding="utf-8", newline="\n")
        print("saved", target)
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    raise SystemExit(main())
