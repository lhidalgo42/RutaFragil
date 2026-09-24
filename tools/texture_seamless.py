"""Convierte un PNG en repetible sin dependencias externas.

    python tools/texture_seamless.py input.png output.png [--proof proof_3x3.png]

Hace wrap-offset de medio ancho/alto (la costura exterior pasa al centro) y
reconstruye una cruz central de ancho fijo relativo con interpolación smoothstep.
El PNG debe ser 8-bit gris/RGB/GA/RGBA, no entrelazado. La salida conserva sus
canales y dimensiones. --proof escribe un mosaico 3x3 para revisión visual.
"""
import argparse
import os
import struct
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from texture_check import read_png

COLOR_TYPES = {1: 0, 2: 4, 3: 2, 4: 6}
SIGNATURE = b"\x89PNG\r\n\x1a\n"


def _chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)


def write_png(path, width, height, channels, rows):
    if channels not in COLOR_TYPES or len(rows) != height:
        raise ValueError("canales o filas inválidos")
    stride = width * channels
    if any(len(row) != stride for row in rows):
        raise ValueError("ancho de fila inválido")
    raw = b"".join(b"\0" + bytes(row) for row in rows)
    header = struct.pack(">IIBBBBB", width, height, 8, COLOR_TYPES[channels], 0, 0, 0)
    with open(path, "wb") as f:
        f.write(SIGNATURE + _chunk(b"IHDR", header) + _chunk(b"IDAT", zlib.compress(raw, 9)) + _chunk(b"IEND", b""))


def _smoothstep(value):
    return value * value * (3.0 - 2.0 * value)


def make_seamless(width, height, channels, rows):
    if width < 4 or height < 4:
        raise ValueError("se exige al menos 4x4")
    # Half-offset makes the output border an ordinary pair of source neighbours.
    # The source has no seam at its centre, so it covers the offset seam there
    # while the offset keeps the wrapped border. ponytail: a plain cross fade
    # can ghost strong features; add patch synthesis when real tiles need it.
    radius = max(1, min(width, height) // 8)
    cx, cy = width // 2, height // 2
    output = []
    for y in range(height):
        offset_row = rows[(y + cy) % height]
        wy = _smoothstep(max(0.0, 1.0 - abs(y + 0.5 - cy) / radius))
        line = bytearray(width * channels)
        for x in range(width):
            w = max(wy, _smoothstep(max(0.0, 1.0 - abs(x + 0.5 - cx) / radius)))
            sx = ((x + cx) % width) * channels
            for c in range(channels):
                a, b = offset_row[sx + c], rows[y][x * channels + c]
                line[x * channels + c] = int(a * (1.0 - w) + b * w + 0.5)
        output.append(bytes(line))
    return output


def tile_3x3(width, height, channels, rows):
    tiled_row = [b"".join([row, row, row]) for row in rows]
    return width * 3, height * 3, tiled_row * 3


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("input")
    ap.add_argument("output")
    ap.add_argument("--proof")
    a = ap.parse_args(argv)
    try:
        width, height, channels, rows = read_png(a.input)
        output = make_seamless(width, height, channels, rows)
        os.makedirs(os.path.dirname(os.path.abspath(a.output)), exist_ok=True)
        write_png(a.output, width, height, channels, output)
        if a.proof:
            pw, ph, proof = tile_3x3(width, height, channels, output)
            os.makedirs(os.path.dirname(os.path.abspath(a.proof)), exist_ok=True)
            write_png(a.proof, pw, ph, channels, proof)
    except (OSError, ValueError, zlib.error) as error:
        print("ERROR: %s" % error, file=sys.stderr)
        return 1
    print("guardado %s (%dx%d)%s" % (a.output, width, height,
          " y prueba 3x3 " + a.proof if a.proof else ""))
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main())
