"""Stdlib test for exact atlas region means, dimensions, RGB and determinism.

    python tools/build_van_atlases_test.py
"""
import json
from pathlib import Path
import sys
import tempfile

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
import build_van_atlases as builder
from texture_check import read_png

EXPECTED = {
    "bus_exterior_atlas_v1.png": {
        "yellow_body": builder.YELLOW,
        "red_stripe": builder.RED,
        "cream_roof": builder.CREAM,
        "glass": builder.GLASS,
        "dark_trim": builder.TRIM,
    },
    "bus_interior_atlas_v1.png": {
        "floor": builder.FLOOR,
        "rack": builder.RACK,
        "seat": builder.SEAT,
        "wall": builder.WALL,
    },
    "bus_wheel_atlas_v1.png": {
        "tread": builder.TREAD,
        "sidewall": builder.SIDEWALL,
        "rim": builder.RIM,
    },
}


def region_mean(rows, rect):
    x, y, width, height = rect
    sums = [0, 0, 0]
    for row in rows[y:y + height]:
        for pixel in range(x, x + width):
            for channel in range(3):
                sums[channel] += row[pixel * 3 + channel]
    count = width * height
    assert all(total % count == 0 for total in sums), (rect, sums, count)
    return tuple(total // count for total in sums)


def check_tree(root):
    for name, expected_regions in EXPECTED.items():
        atlas = Path(root) / "assets/textures" / name
        width, height, channels, rows = read_png(str(atlas))
        assert (width, height, channels) == (1024, 1024, 3), \
            (name, width, height, channels)
        for region in builder.ATLASES[name]["regions"]:
            actual = region_mean(rows, region["rect"])
            expected = expected_regions[region["name"]]
            assert actual == expected, (name, region["name"], actual, expected)

    wheel = Path(root) / "assets/textures/bus_wheel_atlas_v1.png"
    _, _, _, rows = read_png(str(wheel))
    tread = region_mean(rows, (0, 0, 328, 1024))[0]
    sidewall = region_mean(rows, (328, 0, 184, 1024))[0]
    rim = region_mean(rows, (512, 0, 512, 1024))[0]
    assert tread == 32 and sidewall == 24 and 118 <= rim <= 124
    assert rim - tread >= 80, (tread, sidewall, rim)


def main():
    with tempfile.TemporaryDirectory(prefix="rf_atlas_a_") as first, \
            tempfile.TemporaryDirectory(prefix="rf_atlas_b_") as second:
        source_root = str(TOOLS.parent)
        assert builder.main(["--root", first, "--source-root", source_root]) == 0
        assert builder.main(["--root", second, "--source-root", source_root]) == 0
        for name in EXPECTED:
            relative = Path("assets/textures") / name
            assert (Path(first) / relative).read_bytes() == (Path(second) / relative).read_bytes(), \
                "%s not deterministic" % name
            json_relative = relative.with_suffix(".json")
            assert (Path(first) / json_relative).read_bytes() == \
                (Path(second) / json_relative).read_bytes(), "%s metadata not deterministic" % name
        check_tree(first)
    print("ATLAS_TEST_OK atlases=3 size=1024x1024 rgb deterministic exact_means")


if __name__ == "__main__":
    main()
