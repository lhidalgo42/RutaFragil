"""Genera imágenes en el ComfyUI del dueño con FLUX.1 [schnell] (Apache 2.0).

Único modelo aprobado hoy para lo que entra al repositorio (CREDITS.md, maestro
§10.2). No usa credenciales: habla con la API HTTP del servidor.

    python tools/comfy_generate.py <nombre> "<prompt>" [--w 1024] [--h 576] [--seed N]

Guarda la imagen en docs/referencias/<nombre>.png y, al lado, <nombre>.json con
el prompt, el modelo, la semilla y la fecha — el registro que exige §10.1 punto 5.
"""
import argparse, io, json, os, sys, time, urllib.request, urllib.error

SERVER = os.environ.get("COMFY_URL", "http://192.168.50.200:8188")
MODEL = "flux1-schnell.safetensors"
LICENCE = "Apache-2.0"
OUT = os.path.join("docs", "referencias")


def post(path, payload):
    data = json.dumps(payload).encode()
    req = urllib.request.Request(SERVER + path, data=data,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def get(path):
    with urllib.request.urlopen(SERVER + path, timeout=30) as r:
        return json.load(r)


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

    wf = workflow(a.prompt, a.w, a.h, a.seed, a.steps)
    queued = post("/prompt", {"prompt": wf})
    pid = queued["prompt_id"]
    print("encolado %s" % pid)

    deadline = time.time() + 300
    while time.time() < deadline:
        hist = get("/history/" + pid)
        if pid in hist:
            entry = hist[pid]
            status = entry.get("status", {})
            if status.get("status_str") == "error" or not status.get("completed", True):
                print("ERROR del servidor:", json.dumps(status)[:800])
                return 1
            for node in entry.get("outputs", {}).values():
                for img in node.get("images", []):
                    q = "/view?filename=%s&subfolder=%s&type=%s" % (
                        urllib.parse.quote(img["filename"]),
                        urllib.parse.quote(img.get("subfolder", "")), img["type"])
                    with urllib.request.urlopen(SERVER + q, timeout=60) as r:
                        blob = r.read()
                    os.makedirs(OUT, exist_ok=True)
                    dest = os.path.join(OUT, a.name + ".png")
                    with open(dest, "wb") as f:
                        f.write(blob)
                    meta = {"file": a.name + ".png", "model": MODEL, "licence": LICENCE,
                            "prompt": a.prompt, "seed": a.seed, "steps": a.steps,
                            "width": a.w, "height": a.h, "server": SERVER,
                            "generated_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
                    with io.open(os.path.join(OUT, a.name + ".json"), "w",
                                 encoding="utf-8", newline="\n") as f:
                        f.write(json.dumps(meta, indent="\t", ensure_ascii=False) + "\n")
                    print("guardado %s  (%.0f KB)" % (dest, len(blob) / 1024.0))
                    return 0
        time.sleep(2)
    print("ERROR: sin resultado en 300 s")
    return 1


if __name__ == "__main__":
    import urllib.parse
    sys.exit(main())
