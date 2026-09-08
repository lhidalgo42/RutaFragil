# AGENTS.md — Ruta Frágil

Reglas para agentes de código que trabajen en este repo.

**Jerarquía:** maestro v0.2 > briefing v0.2 > plan de la tarea > criterio del agente. Las contradicciones se reportan, no se resuelven en silencio.

## Reglas R1–R14 (maestro §0.3)

> ⚠️ El texto original de R1–R14 no está disponible: el maestro llegó por chat y su archivo (`docs/RUTA_FRAGIL_documento_maestro_v0.2_godot.md`) está pendiente de rellenar.
> Las reglas marcadas como reconstruidas se derivan únicamente de las referencias «R#» que aparecen en `docs/planes/M0-T0.1_plan.md`.
> **Reemplazar todo por el texto textual del maestro §0.3** cuando el dueño lo deposite (el checklist de revisión exige diff vacío contra §0.3).

- **R1** — PENDIENTE: texto original del maestro §0.3.
- **R2** — PENDIENTE: texto original del maestro §0.3.
- **R3** — Tipado de declaraciones obligatorio: declaraciones sin tipo (`untyped_declaration`) y con tipo inferido (`inferred_declaration`) son error de proyecto (forzado por configuración, D34). *(reconstruida desde el plan; texto original PENDIENTE del maestro)*
- **R4** — PENDIENTE: texto original del maestro §0.3.
- **R5** — Ningún addon sin aprobación explícita del dueño. *(reconstruida desde el plan; texto original PENDIENTE del maestro)*
- **R6** — Alcance de la tarea: lo declarado «fuera» no se toca; un paso bloqueado detiene la tarea y se reporta, no se salta. *(reconstruida desde el plan; texto original PENDIENTE del maestro)*
- **R7** — Reportar explícitamente todo criterio NO verificado, con el motivo. *(reconstruida desde el plan; texto original PENDIENTE del maestro)*
- **R8** — Scripts propios de ≤400 líneas y en inglés. *(reconstruida desde el plan; texto original PENDIENTE del maestro)*
- **R9** — Identificadores en snake_case. *(reconstruida desde el plan; texto original PENDIENTE del maestro)*
- **R10** — Sin TODOs silenciosos: todo pendiente se registra en `BACKLOG.md`. *(reconstruida desde el plan; texto original PENDIENTE del maestro)*
- **R11** — Las afirmaciones sobre motor/herramientas se verifican contra fuentes primarias. *(reconstruida desde el plan; texto original PENDIENTE del maestro)*
- **R12** — PENDIENTE: texto original del maestro §0.3.
- **R13** — PENDIENTE: texto original del maestro §0.3.
- **R14** — Sin escenas/recursos binarios (`.scn`, `.res`) ni cifrado en el repo: todo texto. *(reconstruida desde el plan; texto original PENDIENTE del maestro)*

## Protocolo (maestro §0.4)

PENDIENTE: reemplazar esta sección con el texto del maestro §0.4.

## Frontera de autonomía (maestro §0.8)

PENDIENTE: reemplazar esta sección con el texto del maestro §0.8.

## Comandos verificados (plan M0-T0.1, pasos 5–7)

```powershell
# Suite de tests gdUnit4 (verifica versión, importa, corre tests/, exige ≥3 tests descubiertos)
tools/run_tests.ps1    # Windows
tools/run_tests.sh     # macOS / Linux
```

```bash
# Import del proyecto: DOS pasadas (issues abiertos GH-97952/GH-102728).
# Debe existir .godot/global_script_class_cache.cfg al terminar.
# En 4.7 el apagado con plugins puede devolver ≠0 aunque el import esté completo:
# no confiar solo en el código de salida; verificar artefactos y reportar el código tal cual.
"$GODOT_BIN" --headless --path <raíz del repo> --import
"$GODOT_BIN" --headless --path <raíz del repo> --import
```

```bash
# gdUnit4 headless (forma exacta del paso 6; NUNCA poner `--` o `++` antes de las opciones de gdUnit4)
"$GODOT_BIN" --headless --path <raíz> -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -c -a res://tests -rd res://reports
```

Códigos de salida de gdUnit4: `0` ok · `100` fallos · `101` warnings · `103` headless rechazado · `104` versión de Godot no soportada · `105` errores de script en el descubrimiento · cualquier otro (444, 134, 0xC0000005…) = fallo de infraestructura.

```bash
# Normalización de project.godot: UNA sola ejecución con ventana (headless nunca lo reescribe).
# Revisar el diff, aceptarlo y verificar que un segundo arranque no produce cambios.
"$GODOT_BIN" --editor --path <raíz> --quit
```

## Rutas clave

- Resolución de `GODOT_BIN` (D39): variable de entorno `GODOT_BIN` → `tools/godot_bin.local` (ignorado por Git) → default por SO:
  - Windows: `C:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe`
  - macOS: `/Applications/Godot.app/Contents/MacOS/Godot`
- Versión pineada del motor (ADR-000): `4.7.2.stable.official.ed1daf0bf` — solo parches 4.7.x, nunca dev/beta.
- Suites de tests en `tests/` (D33); reportes en `reports/` (ignorado).
- Decisiones: `DECISIONS.md` · Pendientes: `BACKLOG.md` · Plan vigente: `docs/planes/`.
