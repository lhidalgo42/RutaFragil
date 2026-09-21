"""Genera imágenes en el ComfyUI del dueño con FLUX.1 [schnell] (Apache 2.0).

Único modelo de imagen aprobado hoy para lo que entra al repositorio (CREDITS.md,
maestro §10.2). Habla con la API HTTP del servidor a través de comfy_api, que lee
las credenciales de Cloudflare Access del entorno (nunca del repo).

    python tools/comfy_generate.py <nombre> "<prompt>" [--w 1024] [--h 576] [--seed N]

Guarda la imagen en docs/referencias/<nombre>.png y, al lado, <nombre>.json con
el prompt, el modelo, la semilla y la fecha — el registro que exige §10.1 punto 5.
"""
import argparse
import io
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import comfy_api

MODEL = "flux1-schnell.safetensors"
LICENCE = "Apache-2.0"
OUT = os.path.join("docs", "referencias")

def workflow(prompt, width, height, seed, steps):
    return {
        "1": {"class_type": "UNETLoader",
              "inputs": {"unet_name": MODEL, "weight_dtype": "default"}},
        "2": {"class_type": "DualCLIPLoader",
              "inputs": {"clip_name1": "t5xxl_fp16.safetensors",
                         "clip_name2": "clip_l.safetensors", "type": "flux"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": "ae.safetensors"}},
        "4": {"class_type": "CLIPTextEncode",
              "inputs": {"clip": ["2", 0], "text": prompt}},
        "5": {"class_type": "CLIPTextEncode",
              "inputs": {"clip": ["2", 0], "text": ""}},
        "6": {"class_type": "EmptySD3LatentImage",
              "inputs": {"width": width, "height": height, "batch_size": 1}},
        "7": {"class_type": "KSampler",
              "inputs": {"model": ["1", 0], "positive": ["4", 0], "negative": ["5", 0],
                         "latent_image": ["6", 0], "seed": seed, "steps": steps,
                         "cfg": 1.0, "sampler_name": "euler", "scheduler": "simple",
                         "denoise": 1.0}},
        "8": {"class_type": "VAEDecode", "inputs": {"samples": ["7", 0], "vae": ["3", 0]}},
        "9": {"class_type": "SaveImage",
              "inputs": {"images": ["8", 0], "filename_prefix": "rutafragil"}},
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("name")
    ap.add_argument("prompt")
    ap.add_argument("--w", type=int, default=1024)
    ap.add_argument("--h", type=int, default=576)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--steps", type=int, default=4)
    a = ap.parse_args()

    outputs = comfy_api.run(workflow(a.prompt, a.w, a.h, a.seed, a.steps), budget_s=300)
    for node in outputs.values():
        for img in node.get("images", []):
            blob = comfy_api.get_bytes(comfy_api.view_url(img))
            os.makedirs(OUT, exist_ok=True)
            dest = os.path.join(OUT, a.name + ".png")
            with open(dest, "wb") as f:
                f.write(blob)
            meta = {"file": a.name + ".png", "model": MODEL, "licence": LICENCE,
                    "prompt": a.prompt, "seed": a.seed, "steps": a.steps,
                    "width": a.w, "height": a.h, "server": comfy_api.SERVER,
                    "generated_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
            with io.open(os.path.join(OUT, a.name + ".json"), "w",
                         encoding="utf-8", newline="\n") as f:
                f.write(json.dumps(meta, indent="\t", ensure_ascii=False) + "\n")
            print("guardado %s  (%.0f KB)" % (dest, len(blob) / 1024.0))
            return 0
    print("El servidor terminó sin devolver imagen.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
