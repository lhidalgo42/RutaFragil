"""Genera texturas con el mismo ComfyUI/FLUX que comfy_generate.py.

    python tools/comfy_texture.py <nombre> "<prompt>" [--mode plate|tileable]
        [--w 1024] [--h 1024] [--seed N] [--out docs/referencias]

Añade al prompt una redacción negativa fija (sin texto/letras/números/logos/
marcas/perspectiva/luz direccional). En modo tileable el prompt pide además
patrón continuo repetible, pero la imagen generada SIGUE siendo solo la fuente:
la costura se cierra aparte con texture_seamless.py. ComfyUI FLUX no expone
condicionado negativo (cfg=1.0), así que el negative se incrusta en el prompt
positivo; un modelo con negativo real podría moverlo sin tocar el resto.

Guarda <nombre>.png y <nombre>.json con prompt completo, modo, semilla, tamaño
y fecha (maestro §10.1 punto 5).
"""
import argparse
import io
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import comfy_api
import comfy_generate

FIXED_NEGATIVE = ("no text, no letters, no numbers, no logos, no brands, "
                  "flat top-down orthographic view, no perspective, no directional lighting, "
                  "even diffuse illumination, no shadows")
TILEABLE_SUFFIX = "seamless repeating texture pattern, continuous material surface"


def build_prompt(base, mode):
    positive = base.strip()
    if mode == "tileable":
        positive = positive + ", " + TILEABLE_SUFFIX
    return positive + ", " + FIXED_NEGATIVE


def workflow(prompt, mode, width, height, seed, steps):
    return comfy_generate.workflow(build_prompt(prompt, mode), width, height, seed, steps)


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("name")
    ap.add_argument("prompt")
    ap.add_argument("--mode", choices=("plate", "tileable"), default="plate")
    ap.add_argument("--w", type=int, default=1024)
    ap.add_argument("--h", type=int, default=1024)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--steps", type=int, default=4)
    ap.add_argument("--out", default=os.path.join("docs", "referencias"))
    a = ap.parse_args(argv)

    positive = build_prompt(a.prompt, a.mode)
    outputs = comfy_api.run(
        comfy_generate.workflow(positive, a.w, a.h, a.seed, a.steps), budget_s=300)
    for node in outputs.values():
        for img in node.get("images", []):
            blob = comfy_api.get_bytes(comfy_api.view_url(img))
            os.makedirs(a.out, exist_ok=True)
            dest = os.path.join(a.out, a.name + ".png")
            with open(dest, "wb") as f:
                f.write(blob)
            meta = {"file": a.name + ".png", "kind": "texture", "mode": a.mode,
                    "model": comfy_generate.MODEL, "licence": comfy_generate.LICENCE,
                    "prompt_base": a.prompt, "positive_prompt": positive,
                    "fixed_negative_wording": FIXED_NEGATIVE, "seed": a.seed,
                    "steps": a.steps, "width": a.w, "height": a.h,
                    "server": comfy_api.SERVER,
                    "generated_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
            with io.open(os.path.join(a.out, a.name + ".json"), "w",
                         encoding="utf-8", newline="\n") as f:
                f.write(json.dumps(meta, indent="\t", ensure_ascii=False) + "\n")
            print("guardado %s  (%.0f KB)" % (dest, len(blob) / 1024.0))
            if a.mode == "tileable":
                print("tileable: el tile aún no es repetible; ciérralo con "
                      "texture_seamless.py y compruébalo con texture_check.py --tileable")
            return 0
    print("El servidor terminó sin devolver imagen.")
    return 1


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main())
