"""Run with python tools/texture_seamless_test.py; stdlib only."""
import hashlib
import tempfile
from pathlib import Path

import texture_check
import texture_seamless


def main():
    width, height, channels = 16, 12, 4
    source = [bytes(value for x in range(width)
                    for value in (20 + x * 6 + y * 3,
                                  30 + x * 4 + y * 5, 90, 255))
              for y in range(height)]
    first = texture_seamless.make_seamless(width, height, channels, source)
    second = texture_seamless.make_seamless(width, height, channels, source)
    assert first == second
    assert len(first) == height and all(len(row) == width * channels for row in first)
    # Half-offset leaves ordinary source-neighbour deltas on the wrapped border.
    seam = texture_check.seam_stats(width, height, channels, first)
    assert seam["seam_rms"] <= seam["interior_rms"] * 1.5, seam

    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        source_path, output_path, proof_path = root / "source.png", root / "out.png", root / "proof.png"
        texture_seamless.write_png(source_path, width, height, channels, source)
        arguments = [str(source_path), str(output_path), "--proof", str(proof_path)]
        assert texture_seamless.main(arguments) == 0
        ow, oh, oc, decoded = texture_check.read_png(output_path)
        assert (ow, oh, oc) == (width, height, channels)
        assert decoded == first
        pw, ph, pc, proof = texture_check.read_png(proof_path)
        assert (pw, ph, pc) == (width * 3, height * 3, channels)
        assert proof[0][:width * channels] == first[0]
        before = hashlib.sha256(output_path.read_bytes()).digest()
        assert texture_seamless.main(arguments) == 0
        assert hashlib.sha256(output_path.read_bytes()).digest() == before
    print("PASS: deterministic wrap/blend, dimensions, periodic edge and 3x3 proof")


if __name__ == "__main__":
    main()
