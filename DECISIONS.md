# DECISIONS.md — Ruta Frágil

Registro de decisiones del proyecto. Jerarquía: maestro v0.2 > briefing v0.2 > plan de tarea (`docs/planes/`).

## ADR-000..009

- **ADR-000** — Solo parches **4.7.x** del motor, **nunca dev/beta**. Versión pineada: `4.7.2.stable.official.ed1daf0bf`; la hace cumplir `test_engine_is_pinned_to_4_7_2` en ambas máquinas.
- **ADR-001** — PENDIENTE: resumen desde el maestro (ver `docs/RUTA_FRAGIL_documento_maestro_v0.2_godot.md`).
- **ADR-002** — PENDIENTE: resumen desde el maestro (ver `docs/RUTA_FRAGIL_documento_maestro_v0.2_godot.md`).
- **ADR-003** — PENDIENTE: resumen desde el maestro (ver `docs/RUTA_FRAGIL_documento_maestro_v0.2_godot.md`).
- **ADR-004** — PENDIENTE: resumen desde el maestro (ver `docs/RUTA_FRAGIL_documento_maestro_v0.2_godot.md`).
- **ADR-005** — PENDIENTE: resumen desde el maestro (ver `docs/RUTA_FRAGIL_documento_maestro_v0.2_godot.md`).
- **ADR-006** — PENDIENTE: resumen desde el maestro (ver `docs/RUTA_FRAGIL_documento_maestro_v0.2_godot.md`).
- **ADR-007** — PENDIENTE: resumen desde el maestro (ver `docs/RUTA_FRAGIL_documento_maestro_v0.2_godot.md`).
- **ADR-008** — PENDIENTE: resumen desde el maestro (ver `docs/RUTA_FRAGIL_documento_maestro_v0.2_godot.md`).
- **ADR-009** — Puente MCP: **ninguno en M0**. Disparador de revisión: la primera milestone con iteración visual (M2/M8) o cuando el bug #988 de Godot AI lleve ≥4 semanas cerrado (ver D30).

## D1–D29

PENDIENTE: copiar desde el briefing (`docs/CONTEXTO_RUTA_FRAGIL_v0.2.md`).

## D30–D39 (fijadas en el plan M0-T0.1, tabla 4.1)

| # | Decisión | Valor | Por qué |
|---|---|---|---|
| D30 | Puente MCP | **Ninguno en M0.** Se documenta como ADR-009 en `DECISIONS.md` con disparador de revisión: primera milestone con iteración visual (M2/M8) o cuando el bug #988 de Godot AI lleve ≥4 semanas cerrado. | Los tres candidatos (Godot AI/hi-godot, godot-mcp/hybridindie, Swallowtail ex godot-mcp-go) exigen editor abierto para todo lo que no sea envolver la CLI; ninguno aporta a headless. Godot AI publicó 4.0.0→4.0.2 el 07/09/2026 con un bug abierto de conexión en Windows 11 + 4.7.2 (#988); Swallowtail se renombró el 07/09; hybridindie tiene 9 estrellas, 1 mantenedor, 20 bugs abiertos. Cada uno agrega `addons/` + runtime externo (Python/Go/Node): choca con R5. Todo lo que T0.1–T0.4 necesitan se hace con archivos de texto + `godot --headless`. |
| D31 | Driver de render Windows | `rendering/rendering_device/driver.windows="d3d12"` | Decisión del dueño 2026-09-08. Proponer corrección de ADR-000/D13 a "Forward+; backend por plataforma: D3D12 en Windows, Metal en macOS" (macOS usa Metal por defecto desde 4.4; "MoltenVK" del maestro ya no es exacto). |
| D32 | gdUnit4 | **v6.2.1**, tag de GitHub `godot-gdunit-labs/gdUnit4` (repo movido desde MikeSchulze), MIT. Solo la carpeta `addons/gdUnit4/`. | AssetLib sigue en 6.2.0; 6.2.1 arregla un crash del runner CLI (GD-1267). La tabla de compatibilidad llega a Godot 4.7.1; 4.7.2 salió dos días antes que 6.2.1 y no está listado. Godot declara "sin incompatibilidades conocidas" 4.7.1→4.7.2. Único issue registrado con 4.7.2: aviso cosmético con literales `1_000` en tests parametrizados (#1319). Se trata como soportado en la práctica; se re-verifica cuando salga 6.2.2. |
| D33 | Carpeta de tests | `tests/` (§20) + `[gdunit4] settings/test/test_lookup_folder="tests"` | gdUnit4 asume `test`; sin el ajuste "Crear test" del editor los pone en la carpeta equivocada. |
| D34 | Tipado forzado por configuración | `untyped_declaration=2`, `inferred_declaration=2` (error); `unsafe_method_access`, `unsafe_property_access`, `unsafe_cast`, `unsafe_call_argument` = 1 (warn). **No tocar `debug/gdscript/warnings/directory_rules`** (su default excluye `res://addons`). | R3 habla de declaraciones: esas dos claves la cumplen. Si `res://addons` deja de estar excluido con `inferred_declaration≠0`, el plugin de gdUnit4 se niega a cargar ("Loading GdUnit4 Plugin failed"). `treat_warnings_as_errors` **no existe** para GDScript en 4.7 (solo `debug/shader_language/…`). |
| D35 | Ubicación de los .md | `docs/` con `.gdignore`. §20 no lista la carpeta: desvío menor, reportado. Maestro y briefing se escriben **desde el texto del chat** con cabecera "copia reconstruida desde chat el 2026-09-08; si existe el original, reemplazar". | El maestro llegó por chat, no como archivo. |
| D36 | SVG fuera de LFS | `icon.svg` y cualquier `.svg` en Git normal. Desvío del ejemplo de la documentación de Godot, anotado como comentario en `.gitattributes`. | SVG es texto diffable. En GitHub los objetos LFS son permanentes (borrarlos no libera cuota). |
| D37 | Nombre interno | `application/config/name="RutaFragil"` | El título es provisional (Apéndice C) y el nombre define la ruta `user://`. |
| D38 | Ramas | Commit inicial en `main` con solo metadatos de repo y docs; el proyecto Godot se construye en `m0/t0.1-foundations`; el dueño hace merge tras el gate. | §0.2: el agente nunca en `main`; el primer commit tiene que existir en alguna rama. |
| D39 | Ruta al ejecutable de Godot | Variable de entorno `GODOT_BIN`; si falta, `tools/godot_bin.local` (ignorado por Git); si falta, default por SO: Windows `C:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe`, macOS `/Applications/Godot.app/Contents/MacOS/Godot`. | Mismo nombre que usa gdUnit4. Mac y Windows tendrán rutas distintas. |

**D32 — hash del commit clonado:** `08ffc7c65b61b1b2edd545616061a99973c13ce1` (tag `v6.2.1` del repo `godot-gdunit-labs/gdUnit4`).
