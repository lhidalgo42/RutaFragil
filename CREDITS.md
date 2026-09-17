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

Servidor ComfyUI del dueño: `http://192.168.50.200:8188` (ComfyUI 0.33.4, Linux). Inventario revisado el 2026-09-17.

### APROBADO para assets que se publican

| Modelo | Licencia | Uso | Verificado |
|---|---|---|---|
| **FLUX.1 [schnell]** (`flux1-schnell.safetensors`) | **Apache 2.0** | Imágenes: style board, referencias, texturas | 2026-09-17 — instalado y disponible |

### PROHIBIDO para assets que se publican

| Modelo | Motivo | Estado |
|---|---|---|
| **Hunyuan3D 2.1** (`hunyuan_3d_v2.1.safetensors` + nodos `Hy3D21*`) | Licencia de Tencent: el Territorio excluye **Unión Europea, Reino Unido y Corea del Sur**. Steam vende en todo el mundo. | **Instalado en el servidor.** Solo exploración interna; su salida NO entra al build. |
| **FLUX.1 [dev]** y `flux2_dev_fp8mixed` | Licencia no comercial. | Instalado; no usar. |

### PENDIENTE de verificar antes de usar

`triposplat_fp16` (3D), `Illustrious-XL-v2.0`, `qwen_image_*`, `z_image_turbo`, `krea2_turbo`, `anima-base`, `Stable-Cascade`, `wan2.*`, `MiniMax_*`, `stable_audio_3_medium_base`. Ninguno ha producido nada que esté en el repositorio.

### FALTA instalar

**Trellis (Microsoft, MIT)** — es la opción **por defecto para 3D** según §10.2 y **no está en el servidor**. Hoy el único generador 3D instalado es el prohibido. Sin Trellis (u otro 3D con licencia limpia) no hay malla generada que pueda publicarse.
