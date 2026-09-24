"""Compone los tres atlases externos de M-ART-VAN, sin dependencias.

    python tools/build_van_atlases.py [--root <repo>]

Layout UV fijo (origen de imagen arriba; Blender usa V invertida al asignar):
- exterior: body 0..1 x 0..0.5, red/cream/glass/black en cuartos inferiores.
- interior: floor 0..0.5 x 0..0.5, rack/seat/wall en otros cuadrantes.
- wheel: tread 0..0.5, rim 0.5..1.

Las fuentes FLUX y sus JSON quedan en docs/referencias/. Los atlases y un JSON
de procedencia reproducible van a assets/textures/. Un atlas es una imagen por
asset, la regla del maestro §10.1.4.
"""
import argparse
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from texture_check import read_png
from texture_seamless import write_png

SIDE = 1024


def crop_scale(path, box, out_w, out_h):
    width, height, channels, rows = read_png(str(path))
    if channels not in (3, 4):
        raise ValueError("%s: se exige RGB/RGBA" % path)
    x0, y0, x1, y1 = box
    x0, x1 = int(x0 * width), int(x1 * width)
    y0, y1 = int(y0 * height), int(y1 * height)
    result = []
    for y in range(out_h):
        sy = min(y1 - 1, y0 + int((y + 0.5) * (y1 - y0) / out_h))
        line = bytearray(out_w * 3)
        for x in range(out_w):
            sx = min(x1 - 1, x0 + int((x + 0.5) * (x1 - x0) / out_w))
            src = sx * channels
            line[x * 3:x * 3 + 3] = rows[sy][src:src + 3]
        result.append(bytes(line))
    return result


def paste(canvas, src, x0, y0):
    for y, row in enumerate(src):
        start = x0 * 3
        canvas[y0 + y][start:start + len(row)] = row


def solid(width, height, rgb):
    row = bytes(rgb) * width
    return [row for _ in range(height)]


def build(path, regions):
    canvas = [bytearray(SIDE * 3) for _ in range(SIDE)]
    for region in regions:
        x, y, w, h = region["rect"]
        if "rgb" in region:
            data = solid(w, h, region["rgb"])
        else:
            data = crop_scale(region["source"], region.get("crop", (0, 0, 1, 1)), w, h)
        paste(canvas, data, x, y)
    write_png(str(path), SIDE, SIDE, 3, [bytes(r) for r in canvas])


def metadata(name, regions):
    return {
        "file": name,
        "kind": "atlas",
        "generator": "tools/build_van_atlases.py",
        "size": [SIDE, SIDE],
        "sources": [str(r["source"]).replace("\\", "/") for r in regions if "source" in r],
        "regions": [{"name": r["name"], "rect_px": list(r["rect"]),
                     "crop": list(r.get("crop", (0, 0, 1, 1)))} for r in regions],
        "licence": "Apache-2.0 (FLUX.1 schnell sources); deterministic local composition",
        "not_checked": "logos/text/brand and visual coherence require human review",
    }


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=str(Path(__file__).resolve().parent.parent))
    a = ap.parse_args(argv)
    root = Path(a.root)
    refs, out = root / "docs/referencias", root / "assets/textures"
    out.mkdir(parents=True, exist_ok=True)
    floor = Path("C:/Users/Leo/AppData/Local/Temp/rf_mart_van/floor_seamless.png")
    if not floor.exists():
        floor = refs / "van_tex_src_floor_v1.png"

    atlases = {
        "bus_exterior_atlas_v1.png": [
            {"name": "yellow_body", "rect": (0, 0, 1024, 512), "source": refs / "van_tex_src_yellow_v1.png", "crop": (.12, .12, .88, .88)},
            {"name": "red_stripe", "rect": (0, 512, 256, 512), "source": refs / "van_tex_src_red_v1.png", "crop": (0, 0, 1, .4)},
            {"name": "cream_roof", "rect": (256, 512, 256, 512), "source": refs / "van_tex_src_cream_v1.png", "crop": (0, .12, 1, .88)},
            {"name": "glass", "rect": (512, 512, 256, 512), "rgb": (35, 78, 92)},
            {"name": "dark_trim", "rect": (768, 512, 256, 512), "rgb": (28, 30, 32)},
        ],
        "bus_interior_atlas_v1.png": [
            {"name": "floor", "rect": (0, 0, 512, 512), "source": floor, "crop": (.08, .08, .92, .92)},
            {"name": "rack", "rect": (512, 0, 512, 512), "source": refs / "van_tex_src_rack_v1.png", "crop": (.08, .08, .92, .92)},
            {"name": "seat", "rect": (0, 512, 512, 512), "source": refs / "van_tex_src_seat_v1.png", "crop": (.05, .05, .95, .95)},
            {"name": "wall", "rect": (512, 512, 512, 512), "source": refs / "van_tex_src_cream_v1.png", "crop": (.08, .08, .92, .92)},
        ],
        "bus_wheel_atlas_v1.png": [
            {"name": "tread", "rect": (0, 0, 512, 1024), "source": refs / "van_tex_src_tire_v2.png", "crop": (.15, 0, .85, 1)},
            {"name": "rim", "rect": (512, 0, 512, 1024), "source": refs / "van_tex_src_rim_v1.png", "crop": (.08, .08, .92, .92)},
        ],
    }
    for name, regions in atlases.items():
        target = out / name
        build(target, regions)
        (out / name.replace(".png", ".json")).write_text(
            json.dumps(metadata(name, regions), indent="\t", ensure_ascii=False) + "\n",
            encoding="utf-8", newline="\n")
        print("guardado", target)
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    raise SystemExit(main())
