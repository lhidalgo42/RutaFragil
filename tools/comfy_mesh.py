"""Genera una malla 3D desde una imagen con TRELLIS.2 (MIT) y la guarda como .glb.

TRELLIS.2 es el generador 3D aprobado (CREDITS.md, maestro §10.2): código y pesos
MIT, y la implementación NATIVA de ComfyUI reemplazó nvdiffrast/nvdiffrec —licencia
NVIDIA no comercial— por una reescritura en PyTorch/SciPy. Por eso lo que sale de
aquí sí puede publicarse, a diferencia de Hunyuan3D.

    python tools/comfy_mesh.py docs/referencias/bus_exterior_canonico_v2.png salida

Requiere COMFY_URL, CF_ACCESS_ID y CF_ACCESS_SECRET en el entorno (ver comfy_api).
La malla sale densa: la retopología al presupuesto de tris y la colisión se autoran
aparte (maestro §10.1 punto 3, la física NUNCA usa el mesh generado como colisión).
"""
import argparse
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import comfy_api

MODEL = "trellis_2_int8_convrot.safetensors"
SHAPE_VAE = "trellis_2_shape_vae_bf16.safetensors"
TEXTURE_VAE = "trellis_2_texture_vae_bf16.safetensors"
CLIP_VISION = "dino_v3_L_naf_fp32.safetensors"
BG_MODEL = "birefnet.safetensors"
LICENCE = "MIT"
OUT = os.path.join("assets", "models")


def workflow(image_name, prefix, seed, faces, texture_px, resolution=1536):
    """Rama TRELLIS.2 de la plantilla oficial, sin Pixal3D ni los nodos de vista previa."""
    return {
        # --- carga y recorte al sujeto ---
        "122": {"class_type": "LoadImage",
                "inputs": {"image": image_name}},
        "193": {"class_type": "LoadBackgroundRemovalModel",
                "inputs": {"bg_removal_name": BG_MODEL}},
        "192": {"class_type": "RemoveBackground",
                "inputs": {"bg_removal_model": ["193", 0], "image": ["122", 0]}},
        "312": {"class_type": "ImageCropToMask",
                "inputs": {"images": ["122", 0], "masks": ["192", 0], "width": 1024,
                           "height": 1024, "pad_factor": 1.1, "grow_mask": 0,
                           "background": "#000000"}},

        # --- condicionamiento por visión ---
        "15": {"class_type": "CLIPVisionLoader",
               "inputs": {"clip_name": CLIP_VISION}},
        "299": {"class_type": "Trellis2Conditioning",
                "inputs": {"clip_vision_model": ["15", 0], "image": ["312", 0]}},

        # --- modelo y sus dos vistas de CFG ---
        "40": {"class_type": "UNETLoader",
               "inputs": {"unet_name": MODEL, "weight_dtype": "default"}},
        "117": {"class_type": "VAELoader", "inputs": {"vae_name": SHAPE_VAE}},
        "118": {"class_type": "VAELoader", "inputs": {"vae_name": TEXTURE_VAE}},
        "199": {"class_type": "CFGOverride",
                "inputs": {"model": ["40", 0], "cfg": 1.0,
                           "start_percent": 0.667, "end_percent": 1.0}},
        "125": {"class_type": "RescaleCFG",
                "inputs": {"model": ["199", 0], "multiplier": 0.7}},
        "108": {"class_type": "ModelSamplingSD3",
                "inputs": {"model": ["125", 0], "shift": 5.0}},
        "279": {"class_type": "CFGOverride",
                "inputs": {"model": ["40", 0], "cfg": 1.0,
                           "start_percent": 0.769, "end_percent": 1.0}},
        "126": {"class_type": "RescaleCFG",
                "inputs": {"model": ["279", 0], "multiplier": 0.5}},

        # --- 1. estructura dispersa (voxels) ---
        "87": {"class_type": "EmptyTrellis2LatentStructure",
               "inputs": {"batch_size": 1}},
        "3": {"class_type": "KSampler",
              "inputs": {"model": ["108", 0], "positive": ["299", 0],
                         "negative": ["299", 1], "latent_image": ["87", 0],
                         "seed": seed, "steps": 12, "cfg": 7.5,
                         "sampler_name": "euler", "scheduler": "normal", "denoise": 1.0}},
        "119": {"class_type": "VaeDecodeStructureTrellis2",
                "inputs": {"samples": ["3", 0], "vae": ["117", 0], "resolution": "32"}},

        # --- 2. forma, y subida a 1536 ---
        "91": {"class_type": "Trellis2ShapeStage",
               "inputs": {"positive": ["299", 0], "negative": ["299", 1],
                          "voxel": ["119", 0]}},
        "18": {"class_type": "KSampler",
               "inputs": {"model": ["126", 0], "positive": ["91", 0],
                          "negative": ["91", 1], "latent_image": ["91", 2],
                          "seed": 42, "steps": 20, "cfg": 7.5,
                          "sampler_name": "euler", "scheduler": "normal", "denoise": 1.0}},
        "94": {"class_type": "Trellis2UpsampleStage",
               "inputs": {"positive": ["91", 0], "negative": ["91", 1],
                          "shape_latent": ["18", 0], "vae": ["117", 0],
                          "target_resolution": resolution}},
        "23": {"class_type": "KSampler",
               "inputs": {"model": ["126", 0], "positive": ["94", 0],
                          "negative": ["94", 1], "latent_image": ["94", 2],
                          "seed": 42, "steps": 12, "cfg": 7.5,
                          "sampler_name": "euler", "scheduler": "simple", "denoise": 1.0}},
        "92": {"class_type": "VaeDecodeShapeTrellis",
               "inputs": {"samples": ["23", 0], "vae": ["117", 0]}},

        # --- 3. color por voxel ---
        "98": {"class_type": "Trellis2TextureStage",
               "inputs": {"positive": ["94", 0], "negative": ["94", 1],
                          "shape_latent": ["23", 0]}},
        "12": {"class_type": "KSampler",
               "inputs": {"model": ["40", 0], "positive": ["98", 0],
                          "negative": ["98", 1], "latent_image": ["98", 2],
                          "seed": seed + 1, "steps": 12, "cfg": 1.0,
                          "sampler_name": "euler", "scheduler": "normal", "denoise": 1.0}},
        "93": {"class_type": "VaeDecodeTextureTrellis",
               "inputs": {"samples": ["12", 0], "vae": ["118", 0],
                          "shape_subdivides": ["92", 1]}},

        # --- 4. limpieza de malla y UVs ---
        "202": {"class_type": "GetMeshInfo", "inputs": {"mesh": ["92", 0]}},
        "241": {"class_type": "RemeshMesh",
                "inputs": {"mesh": ["202", 0], "resolution": 768, "sign_mode": "udf",
                           "sign_mode.qef": False, "sign_mode.drop_inverted_components": False,
                           "sign_mode.drop_enclosed_components": False,
                           "band": 1.0, "project_back": 0.0, "fix_poles": False,
                           "smooth_iters": 20, "drop_small_components": 0.01,
                           "precluster_max_verts": 20000000}},
        "186": {"class_type": "DecimateMesh",
                "inputs": {"mesh": ["241", 0], "target_face_count": faces,
                           "placement_mode": "midpoint"}},
        "238": {"class_type": "MeshSmoothNormals",
                "inputs": {"mesh": ["186", 0], "crease_angle": 180.0}},
        "196": {"class_type": "UnwrapMesh",
                "inputs": {"mesh": ["238", 0], "segmenter": "pec",
                           "resolution": texture_px, "padding": 1,
                           "weld_distance": 0.0002}},

        # --- 5. horneado de texturas y ensamblado ---
        "147": {"class_type": "BakeTextureFromVoxel",
                "inputs": {"mesh": ["196", 0], "voxel_colors": ["93", 0],
                           "texture_size": texture_px, "reference_mesh": ["92", 0]}},
        "233": {"class_type": "BakeAmbientOcclusion",
                "inputs": {"low_poly": ["196", 0], "high_poly": ["241", 0],
                           "resolution": 1024, "samples": 64, "max_distance": 0.71,
                           "strength": 1.0, "bias": 0.01}},
        "224": {"class_type": "BakeNormalMapFromMesh",
                "inputs": {"low_poly": ["196", 0], "high_poly": ["241", 0],
                           "resolution": 2048, "cage_distance": 0.05,
                           "ignore_backfaces": True}},
        "210": {"class_type": "ApplyTextureToMesh",
                "inputs": {"mesh": ["196", 0], "base_color": ["147", 0],
                           "metallic": ["147", 1], "roughness": ["147", 2],
                           "occlusion": ["233", 0], "normal_map": ["224", 0]}},
        "260": {"class_type": "MeshSmoothNormals",
                "inputs": {"mesh": ["210", 0], "crease_angle": 180.0}},
        "285": {"class_type": "MeshToFile3D", "inputs": {"mesh": ["260", 0]}},
        "322": {"class_type": "SaveGLB",
                "inputs": {"mesh": ["285", 0], "filename_prefix": prefix}},
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("image", help="imagen de referencia, p.ej. docs/referencias/algo.png")
    ap.add_argument("name", help="nombre de salida, sin extension")
    ap.add_argument("--seed", type=int, default=56)
    ap.add_argument("--faces", type=int, default=20000,
                    help="caras tras decimar; la retopologia al presupuesto va aparte")
    ap.add_argument("--texture", type=int, default=2048)
    ap.add_argument("--resolution", type=int, default=1536, choices=(1024, 1536, 2048),
                    help="resolución de la etapa de forma; 1536 cabe en 16 GB para un objeto "
                         "alargado (el furgón) y se queda sin memoria en el decode para uno que "
                         "llena el recorte (el paquete): usar 1024 en ese caso")
    ap.add_argument("--budget", type=int, default=1800, help="segundos de espera")
    ap.add_argument("--out", default=OUT,
                    help="carpeta de salida; las pruebas de camino van a docs/ (Godot no lo "
                         "escanea), a assets/models/ solo lo que ya pasó por Blender (§10.1)")
    a = ap.parse_args()
    out_dir = a.out

    if not os.path.isfile(a.image):
        raise SystemExit("no existe la imagen: " + a.image)

    uploaded = comfy_api.upload_image(a.image)
    print("subida como %s" % uploaded)

    started = time.time()
    outputs = comfy_api.run(
        workflow(uploaded, "rutafragil/" + a.name, a.seed, a.faces, a.texture, a.resolution),
        budget_s=a.budget)
    elapsed = time.time() - started

    saved = None
    for node in outputs.values():
        for key in ("3d", "result", "gltf", "files", "meshes"):
            for item in node.get(key, []):
                if not isinstance(item, dict) or "filename" not in item:
                    continue
                blob = comfy_api.get_bytes(comfy_api.view_url(item))
                os.makedirs(out_dir, exist_ok=True)
                dest = os.path.join(out_dir, a.name + ".glb")
                with open(dest, "wb") as f:
                    f.write(blob)
                saved = (dest, len(blob))
                break
            if saved:
                break
        if saved:
            break

    if not saved:
        print("El servidor termino pero no devolvio un archivo reconocible.")
        print(json.dumps(outputs, indent=1)[:2000])
        return 1

    dest, size = saved
    meta = {"file": os.path.basename(dest),
            "source_image": a.image.replace("\\", "/"),
            "model": MODEL, "licence": LICENCE,
            "pipeline": "ComfyUI nativo TRELLIS.2",
            "seed": a.seed, "target_faces": a.faces, "texture_px": a.texture, "shape_resolution": a.resolution,
            "elapsed_s": round(elapsed, 1), "server": comfy_api.SERVER,
            "generated_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
    with open(os.path.join(out_dir, a.name + ".json"), "w",
              encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(meta, indent="\t", ensure_ascii=False) + "\n")
    print("guardado %s  (%.1f MB, %.0f s)" % (dest, size / 1048576.0, elapsed))
    return 0


if __name__ == "__main__":
    sys.exit(main())
