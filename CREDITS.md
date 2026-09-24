# CREDITS.md — Ruta Frágil

## Godot Engine

- Licencia: **MIT** — el aviso de licencia es **obligatorio en la distribución** del juego.
- Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md). Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.
- https://godotengine.org/license
- Versión pineada del proyecto: `4.7.2.stable.official.ed1daf0bf` (ADR-000).

## Jolt Physics

- Licencia: **MIT**. Incluido en Godot; este proyecto lo usa como motor de física 3D (`physics/3d/physics_engine="Jolt Physics"`).
- Copyright 2021 Jorrit Rouwe.
- https://github.com/jrouwe/JoltPhysics

## gdUnit4

- Licencia: **MIT** — "Copyright (c) 2023-2026 Mike Schulze".
- Se cita el `LICENSE` de la raíz del repo `godot-gdunit-labs/gdUnit4` (no la copia desactualizada dentro del addon).
- https://github.com/godot-gdunit-labs/gdUnit4
- Versión pineada: tag **v6.2.1** (D32), commit `08ffc7c65b61b1b2edd545616061a99973c13ce1`.
- Se vendoriza la carpeta `addons/gdUnit4/` **sin `test/`**, igual que la distribución oficial (que la excluye por `export-ignore`). Borrado de `test/` autorizado por el dueño el 2026-09-08 por R12. `src/dotnet/GdUnit4CSharpApi.cs` es parte de la distribución oficial y queda inerte en build estándar (D32).

## Modelos generativos

Regla del maestro §10.2: **antes de que un modelo produzca cualquier cosa que llegue al build, su licencia queda copiada aquí** (territorio, uso comercial, atribución, umbrales). Todo contenido generado por IA se declara en Steam al publicar.

Servidor ComfyUI del dueño: `https://comfy.areum.cl` tras Cloudflare Access (ComfyUI **0.37.0**, Linux, RTX 4080 SUPER 16 GB; actualizado desde 0.33.4 el 2026-09-21). Las credenciales viven en el entorno (`CF_ACCESS_ID`, `CF_ACCESS_SECRET`), nunca en el repo. Inventario revisado el 2026-09-21.

### APROBADO para assets que se publican

| Modelo | Licencia | Uso | Verificado |
|---|---|---|---|
| **FLUX.1 [schnell]** (`flux1-schnell.safetensors`) | **Apache 2.0** | Imágenes: style board, referencias, texturas | 2026-09-17 — instalado y disponible |
| **TRELLIS.2** (Microsoft; `trellis_2_int8_convrot.safetensors`, `trellis_2_shape_vae_bf16.safetensors`, `trellis_2_texture_vae_bf16.safetensors`, repo HF `Comfy-Org/TRELLIS.2`) | **MIT** (código y pesos). La implementación **nativa** de ComfyUI ≥0.34 reemplazó `nvdiffrast`/`nvdiffrec` (licencia NVIDIA, solo no comercial) por una reescritura en PyTorch/SciPy; por eso se usa la ruta nativa y **no** el custom node `ComfyUI-Trellis2`, que vuelve a traer los wheels de NVIDIA. | Mallas 3D desde imagen (`tools/comfy_mesh.py`) | 2026-09-21 — instalado; nodos `Trellis2*` verificados en `/object_info` |
| **DINOv3 ViT-L** (`dino_v3_L_naf_fp32.safetensors`, repo HF `Comfy-Org/Pixal3D`; pesos de Meta) | **DINOv3 License** (Meta, custom, https://ai.meta.com/resources/models-and-libraries/dinov3-license/). Licencia «non-exclusive, **worldwide**, non-transferable and royalty-free» para «use, reproduce, distribute, copy, create derivative works»; **sin límite de uso comercial ni de territorio** salvo Trade Controls y usos militares/armas. **Obligaciones al distribuir:** (A) incluir copia del acuerdo y (B) «prominently display “Built with DINOv3”» en web, UI, about o documentación del producto — va en los créditos del juego. Los outputs no tienen cláusula de propiedad de Meta; las derivadas son del usuario. Meta puede modificar los términos (§8). | Codificador de imagen que condiciona TRELLIS.2 (no produce contenido por sí mismo) | 2026-09-21 — instalado; licencia leída y copiada |
| **BiRefNet** (`birefnet.safetensors`, repo HF `Comfy-Org/BiRefNet`) | **MIT** | Recorte de fondo previo a TRELLIS.2 | 2026-09-21 — instalado |

### PROHIBIDO para assets que se publican

| Modelo | Motivo | Estado |
|---|---|---|
| **Hunyuan3D 2.1** (`hunyuan_3d_v2.1.safetensors` + nodos `Hy3D21*`) | Licencia de Tencent: el Territorio excluye **Unión Europea, Reino Unido y Corea del Sur**. Steam vende en todo el mundo. | **Instalado en el servidor.** Solo exploración interna; su salida NO entra al build. |
| **FLUX.1 [dev]** y `flux2_dev_fp8mixed` | Licencia no comercial. | Instalado; no usar. |

### PENDIENTE de verificar antes de usar

`triposplat_fp16` (3D), `Illustrious-XL-v2.0`, `qwen_image_*`, `z_image_turbo`, `krea2_turbo`, `anima-base`, `Stable-Cascade`, `wan2.*`, `MiniMax_*`, `stable_audio_3_medium_base`. Ninguno ha producido nada que esté en el repositorio.

### Historial

- 2026-09-24 UTC (23 en Chile): paquete crudo `docs/referencias/package_raw_v1.glb`, generado con TRELLIS.2 nativo (modelo y licencia MIT registrados arriba). Condicionamiento: `docs/referencias/paquete_referencia_v1.png`; sin prompt textual 3D; seed 56, `--no-upsample`, remallado 256, objetivo 20.000 caras y textura 1024. Prompt ID `ed642bbd-7513-4867-ad9b-eb6d0ce36253`; parámetros y fecha UTC en `docs/referencias/package_raw_v1.json`. Usa DINOv3 y BiRefNet según inventario; mantiene atribuciones indicadas arriba. Se conserva como fuente cruda; derivado limpio documentado a continuación, todavía sin gate visual aprobado.

- 2026-09-24 UTC (23 en Chile): derivado `assets/models/package_clean_v1.glb`, limpieza local con Blender 5.1.2 y `tools/blender_cleanup.py --size 0.4 --tris 800 --texture 1024 --pivot base --outer-shell`. Misma procedencia TRELLIS.2, referencia y atribuciones del crudo anterior; sin otra generación. Retiradas cuatro capas interiores invertidas, decimación a 800 tris, pivote en base confirmado, bbox 0,400 × 0,319 × 0,362 m, un material y tres texturas ≤1024²; checklist mecánico 8/8 con el validador de entonces, **7/8** tras corregir el punto 4 (tres texturas donde se pide una). Previews `docs/referencias/package_clean_v1_{front34,rear34,side}.png`; evidencia en `docs/evidencia/M-ART/limpieza/`. Integrado con autorización del dueño en `src/cargo/package.tscn` como visual, base en Y=-0,2 m y colisión D81 sin cambios. El provisional inválido `assets/models/package.glb` (7/8, normales), su `.import` y sus seis archivos de textura/import fueron eliminados con autorización. Capturas Godot, comparación con referencia y pruebas posteriores en `docs/evidencia/M-ART/integracion/`; apariencia del paquete aceptada por el dueño el 2026-09-24 UTC tras probarlo en el juego («se ve bastante bien»). No equivale al gate M8.

- 2026-09-17: el único 3D instalado era Hunyuan3D (prohibido). Trellis figuraba como «falta instalar».
- 2026-09-21: TRELLIS.2 nativo disponible tras actualizar ComfyUI a 0.37.0. La DA4 del plan M-ART queda resuelta sin custom node ni instalación aparte.

## M-ART-VAN — assets del build

Geometría final autorada localmente con Blender 5.1.2; ComfyUI/FLUX.1 schnell (Apache 2.0) produjo solo las fuentes de color. Los GLB no embeben imágenes ni colisión: cada wrapper Godot aplica un material `.tres` con un atlas externo bajo `assets/textures/`.

| Asset final | Geometría | Textura y fuentes FLUX | Licencia / registro |
|---|---|---|---|
| `assets/models/bus_exterior_clean_v1.glb` | `tools/blender_van.py`; 3.856 tris; 2,53 × 2,30 × 8,00 m; D100, sin ruedas/colisión | `bus_exterior_atlas_v1.png`; `van_tex_src_yellow_v1` seed 101, `red_v1` 102, `cream_v1` 103; prompts/fecha/modelo en JSON adyacentes | Geometría del proyecto; fuentes FLUX.1 schnell Apache 2.0. Sin marcas/logos. |
| `assets/models/bus_interior_clean_v1.glb` | `tools/blender_bus_interior.py`; 4.320 tris; piso, racks, bench, stretcher, steps y dos asientos; sin colisión | `bus_interior_atlas_v1.png`; `floor_v1` seed 104, `rack_v1` 105, `seat_v1` 106, `cream_v1` 103; piso cerrado por `texture_seamless.py` | Geometría del proyecto; fuentes FLUX.1 schnell Apache 2.0. Mosaico seamless en evidencia. |
| `assets/models/bus_wheel_clean_v1.glb` | `tools/blender_bus_wheel.py`; 996 tris; radio 0,5 m, eje +X; sin colisión | `bus_wheel_atlas_v1.png`; `tire_v2` seed 207 y `rim_v1` 108. `tire_v1` seed 107 rechazada por lettering fantasma y conservada solo como evidencia | Geometría del proyecto; fuentes FLUX.1 schnell Apache 2.0. Neumático genérico: sin Pirelli, texto, logo ni trade dress. |

Composición determinista: `tools/build_van_atlases.py`; atlas 1024², una imagen por asset. Registro visual y prompts: `docs/evidencia/M-ART-VAN/` y `docs/referencias/van_tex_src_*.json`. La aceptación visual/flicker permanece humana; esta tabla no marca el gate.
