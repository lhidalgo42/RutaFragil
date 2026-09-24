"""Run with python tools/texture_check_test.py; stdlib only."""
import contextlib
import io
import json
import tempfile
from pathlib import Path

import texture_check
import texture_seamless


def rows(width, height, channels, pixel):
    return [bytes(value for x in range(width) for value in pixel(x, y)) for y in range(height)]


def main():
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        good = root / "good.png"
        source = rows(16, 12, 3, lambda x, y: ((x * 13) % 256, (y * 17) % 256, 80))
        texture_seamless.write_png(good, 16, 12, 3, source)
        report = texture_check.check(str(good))
        assert report["pass"]
        assert report["findings"][1]["detail"].startswith("16x12")
        assert "no detecta texto" in report["not_checked"]

        too_large = root / "large.png"
        texture_seamless.write_png(too_large, 1025, 1, 1, [bytes(1025)])
        assert not texture_check.check(str(too_large))["pass"]

        periodic = root / "periodic.png"
        periodic_rows = rows(8, 8, 3, lambda x, y: (min(x, 7 - x) * 20,
                                                               min(y, 7 - y) * 20, 10))
        texture_seamless.write_png(periodic, 8, 8, 3, periodic_rows)
        periodic_report = texture_check.check(str(periodic), tileable=True)
        assert periodic_report["pass"], periodic_report

        bad = root / "bad.png"
        bad_rows = rows(8, 8, 3, lambda x, _y: (255, 255, 255) if x == 7 else (0, 0, 0))
        texture_seamless.write_png(bad, 8, 8, 3, bad_rows)
        bad_report = texture_check.check(str(bad), tileable=True, max_seam_ratio=1.5)
        assert not bad_report["pass"], bad_report
        seam = next(f for f in bad_report["findings"] if f["check"] == "costura")
        assert seam["detail"]["seam_max"] == 255

        invalid = root / "fake.png"
        invalid.write_bytes(b"not png")
        assert not texture_check.check(str(invalid))["pass"]

        stream = io.StringIO()
        with contextlib.redirect_stdout(stream):
            assert texture_check.main([str(bad), "--tileable", "--json"]) == 1
        assert json.loads(stream.getvalue())["pass"] is False
    print("PASS: format, dimensions, periodic edge, bad seam and JSON exit")


if __name__ == "__main__":
    main()
