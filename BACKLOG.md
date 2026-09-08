# BACKLOG.md — Ruta Frágil

Todo pendiente del proyecto vive aquí (R10: sin TODOs silenciosos en el código).

## Milestones (Parte 3 del maestro)

- **M0 — Fundaciones**
  - **T0.1** Fundaciones: proyecto Godot 4.7.2, Forward+, Jolt, estructura §20, Git+LFS, `AGENTS.md`, gdUnit4 corriendo headless con un test trivial, puente MCP elegido y documentado. Acepta: `run_tests` pasa en ambas máquinas; commit inicial.
  - **T0.2** GameConfig / TuningTable
  - **T0.3** Playground
  - **T0.4** Arnés de red
- **M1** — PENDIENTE: copiar desde el maestro Parte 3.
- **M2** — PENDIENTE: copiar desde el maestro Parte 3.
- **M3** — PENDIENTE: copiar desde el maestro Parte 3.
- **M4** — PENDIENTE: copiar desde el maestro Parte 3.
- **M5** — PENDIENTE: copiar desde el maestro Parte 3.
- **M6** — PENDIENTE: copiar desde el maestro Parte 3.
- **M7** — PENDIENTE: copiar desde el maestro Parte 3.
- **M8** — PENDIENTE: copiar desde el maestro Parte 3.

## Pendientes (copiados del plan M0-T0.1, sección 9)

- **M4:** `export_presets.cfg` con exclusión `addons/gdUnit4/*` (respetar mayúsculas). Según la doc de 4.7, `--export-release` **no** implica `--import`: correr `--import` explícito antes. Export templates 4.7.2 = `Godot_v4.7.2-stable_export_templates.tpz`, ~1,41 GB, verificar con `SHA512-SUMS.txt`.
- **M4:** GodotSteam movió su repo a Codeberg (GitHub archivado el 2026-09-04). GDExtension actual v4.22.1-gde, Godot 4.4+, Steamworks 1.65. Confirma la regla "solo el oficial de godotsteam.com".
- **M2 / ADR-003:** bug abierto de Godot #102763: `CharacterBody3D` se desliza sobre `AnimatableBody3D` en rotación, en ambos motores de física, fix pendiente sin milestone 4.7. Afecta la plataforma móvil del bus.
- **T0.4:** no existe `--user-data-dir` en 4.7. Instancias paralelas necesitan `--path` propio, `--log-file` propio y, para operaciones de editor, una copia del ejecutable con archivo `_sc_` al lado (modo autocontenido). Considerar `application/run/flush_stdout_on_print=true` y `debug/file_logging/enable_file_logging=true` cuando el agente necesite leer logs de instancias que crashean.
- **Headless no entrega InputEvents:** cualquier test que simule input necesita sesión con ventana. Diseñar los tests de gameplay (T0.3+) como simulación de lógica, no de input.
- Re-verificar gdUnit4 cuando salga **v6.2.2** (si añade 4.7.2 a la tabla de compatibilidad).
- 4.8-dev4 prohíbe strings como comentarios en GDScript: lint preventivo si algún día se salta a 4.8.
- **Correcciones al maestro para proponer al dueño:** §21 comando de gdUnit4; §15/D13 "Vulkan/MoltenVK" → backend por plataforma (D31); §0.2/T0.1 "`run_tests` pasa" → exigir conteo mínimo; §20 añadir `docs/`.
