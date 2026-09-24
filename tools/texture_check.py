"""Valida una textura PNG antes de que entre al repo. Solo stdlib (zlib + struct).

    python tools/texture_check.py <png> [--tileable] [--max-seam-ratio 1.5] [--json]

Comprueba: firma y cabecera PNG, 8 bits, tipo de color gris/RGB/GA/RGBA, sin
entrelazado, lado <= 1024. Con --tileable compara la costura envolvente (última
columna contra la primera, última fila contra la primera) con la diferencia
típica entre vecinos del interior: falla si la costura es más de N veces la
del interior o si su diferencia máxima supera --max-seam-max.

NO detecta texto, letras, logos, marcas, perspectiva ni luz direccional: eso
lo revisa un humano mirando la imagen. Un verde aquí no dice nada de eso.

Salida 0 si todo pasa, 1 si algo falla.
"""
import argparse
import json
import math
import struct
import sys
import zlib

MAX_SIDE = 1024
SIGNATURE = b"\x89PNG\r\n\x1a\n"
CHANNELS = {0: 1, 2: 3, 4: 2, 6: 4}
NOT_CHECKED = "no detecta texto/letras/logos/marcas/perspectiva/luz direccional: revisión humana"


def read_png(path):
    """Devuelve (ancho, alto, canales, filas) con filas = list[bytes] sin filtro."""
    with open(path, "rb") as f:
        blob = f.read()
    if blob[:8] != SIGNATURE:
        raise ValueError("no es PNG (firma)")
    pos, header, idat = 8, None, []
    while pos + 8 <= len(blob):
        length, kind = struct.unpack(">I4s", blob[pos:pos + 8])
        data = blob[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", data)
        elif kind == b"IDAT":
            idat.append(data)
        elif kind == b"IEND":
            break
    if header is None:
        raise ValueError("PNG sin IHDR")
    width, height, depth, color, _, _, interlace = header
    if depth != 8 or color not in CHANNELS or interlace != 0:
        raise ValueError("formato no soportado: bits=%d color=%d entrelazado=%d "
                         "(se exige 8 bits, gris/RGB/GA/RGBA, sin entrelazar)"
                         % (depth, color, interlace))
    channels = CHANNELS[color]
    raw = zlib.decompress(b"".join(idat))
    stride = width * channels
    if len(raw) != height * (stride + 1):
        raise ValueError("IDAT de tamaño inesperado")
    rows, prev = [], bytearray(stride)
    for y in range(height):
        start = y * (stride + 1)
        kind, line = raw[start], bytearray(raw[start + 1:start + 1 + stride])
        for i in range(stride):
            a = line[i - channels] if i >= channels else 0
            b = prev[i]
            if kind == 1:
                line[i] = (line[i] + a) & 255
            elif kind == 2:
                line[i] = (line[i] + b) & 255
            elif kind == 3:
                line[i] = (line[i] + ((a + b) >> 1)) & 255
            elif kind == 4:
                c = prev[i - channels] if i >= channels else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
            elif kind != 0:
                raise ValueError("filtro PNG desconocido %d" % kind)
        rows.append(bytes(line))
        prev = line
    return width, height, channels, rows


def _rms_max(pairs):
    total, count, peak = 0, 0, 0
    for u, v in pairs:
        for p, q in zip(u, v):
            d = p - q
            total += d * d
            count += 1
            peak = max(peak, abs(d))
    return (math.sqrt(total / count) if count else 0.0), peak


def seam_stats(width, height, channels, rows):
    """RMS/máximo de la costura envolvente y RMS típico entre vecinos interiores."""
    cols = [[r[x * channels:(x + 1) * channels] for r in rows] for x in range(width)]
    col_bytes = [b"".join(c) for c in cols]
    seam = [(rows[-1], rows[0]), (col_bytes[-1], col_bytes[0])]
    interior = list(zip(rows, rows[1:])) + list(zip(col_bytes, col_bytes[1:]))
    seam_rms, seam_max = _rms_max(seam)
    interior_rms, _ = _rms_max(interior)
    return {"seam_rms": round(seam_rms, 3), "seam_max": seam_max,
            "interior_rms": round(interior_rms, 3)}


def check(path, tileable=False, max_seam_ratio=1.5, max_seam_max=None):
    findings = []
    try:
        width, height, channels, rows = read_png(path)
    except (OSError, ValueError, zlib.error) as error:
        return {"file": path, "pass": False, "not_checked": NOT_CHECKED,
                "findings": [{"check": "formato", "pass": False, "detail": str(error)}]}
    findings.append({"check": "formato", "pass": True,
                     "detail": "8 bits, %d canales" % channels})
    findings.append({"check": "dimensiones", "pass": 0 < width <= MAX_SIDE and 0 < height <= MAX_SIDE,
                     "detail": "%dx%d (máximo %d)" % (width, height, MAX_SIDE)})
    if tileable:
        stats = seam_stats(width, height, channels, rows)
        ok = stats["seam_rms"] <= max_seam_ratio * stats["interior_rms"]
        if max_seam_max is not None:
            ok = ok and stats["seam_max"] <= max_seam_max
        stats["max_seam_ratio"] = max_seam_ratio
        stats["max_seam_max"] = max_seam_max
        findings.append({"check": "costura", "pass": ok, "detail": stats})
    return {"file": path, "pass": all(f["pass"] for f in findings),
            "not_checked": NOT_CHECKED, "findings": findings}


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("png")
    ap.add_argument("--tileable", action="store_true")
    ap.add_argument("--max-seam-ratio", type=float, default=1.5)
    ap.add_argument("--max-seam-max", type=int, default=None)
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv)
    report = check(a.png, a.tileable, a.max_seam_ratio, a.max_seam_max)
    if a.json:
        print(json.dumps(report, indent="\t", ensure_ascii=False))
    else:
        for f in report["findings"]:
            print("%s  %s  %s" % ("OK  " if f["pass"] else "FAIL", f["check"], f["detail"]))
        print("NOTA: " + NOT_CHECKED)
    return 0 if report["pass"] else 1


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main())
