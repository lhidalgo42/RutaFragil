# Ruta Frágil

Proyecto Godot **4.7.2.stable.official.ed1daf0bf** (build estándar, no .NET), GDScript tipado.

El título es provisional (Apéndice C del maestro); el nombre interno del proyecto es `RutaFragil` (D37).

## Regla de versión del motor (ADR-000)

**Solo parches 4.7.x, nunca dev/beta.** El test `test_engine_is_pinned_to_4_7_2` (`tests/smoke_test.gd`) lo hace cumplir en ambas máquinas.

Al subir de parche 4.7.x hay que actualizar la versión pineada en cuatro archivos: `tests/smoke_test.gd`, `tools/run_tests.ps1`, `tools/run_tests.sh`, `README.md` (m8 de la revisión 01).

## Instalación del motor

### Windows

1. Descargar el build **estándar (no .NET)** de Godot 4.7.2 desde godotengine.org.
2. Instalar en `C:\Godot\4.7.2\`.
3. Desde terminal usar siempre `Godot_v4.7.2-stable_win64_console.exe`: propaga el código de salida; el `.exe` sin sufijo `_console` no.
4. `git lfs install` (Git LFS viene incluido en Git para Windows) y `git config --global core.autocrlf input`.

### macOS

1. macOS ≥ 11 solo en Mac Intel; en Apple Silicon el mínimo es **macOS ≥ 13** (requisitos oficiales de Godot 4.7).
2. Descargar `Godot_v4.7.2-stable_macos.universal.zip` (build estándar, no .NET) desde godotengine.org; está firmado y notarizado, se extrae y se ejecuta.
3. Mover `Godot.app` a `/Applications`. El ejecutable CLI es `/Applications/Godot.app/Contents/MacOS/Godot`.
4. `brew install git-lfs && git lfs install` y `git config --global core.autocrlf input`.
5. La primera apertura del editor con ventana reescribirá `project.godot` una vez: revisar el diff, no descartarlo a ciegas.

**Verificación (ambas máquinas):** `"$GODOT_BIN" --version` debe imprimir `4.7.2.stable.official.ed1daf0bf`. Si el hash difiere, no es la misma build: no seguir.

## GODOT_BIN (D39)

Los scripts del repo resuelven el ejecutable de Godot en este orden:

1. Variable de entorno `GODOT_BIN`.
2. Archivo `tools/godot_bin.local` (ignorado por Git).
3. Default por SO:
   - Windows: `C:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe`
   - macOS: `/Applications/Godot.app/Contents/MacOS/Godot`

## Comandos

```powershell
# Windows — suite de tests gdUnit4 headless (forma verificada; con política
# Restricted la forma corta `tools/run_tests.ps1` falla)
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1
```

```bash
# macOS / Linux — suite de tests gdUnit4 headless (forma verificada)
bash tools/run_tests.sh
```

Ambos verifican la versión del motor, importan el proyecto y corren `tests/`; dejan el reporte JUnit en `reports/` (ignorado por Git).

> **D42 (decisión del dueño, 2026-09-09):** la corrida de `run_tests.sh` en la Mac está **diferida hasta antes del gate M4** (red real Mac + Windows, D13) y **ya no bloquea el cierre de M0-T0.1**: T0.1 se acepta con `run_tests` verde solo en Windows. La receta macOS de esta página se conserva para cuando toque esa corrida. Residuo declarado: el arreglo de BOM POSIX de `run_tests.sh` (m-2.3) solo está probado bajo Git Bash; su prueba real en BSD sed queda para esa corrida.

## Datos y mods

Dónde viven los datos del juego (R2, D44/D45; esquema completo en `docs/datos/esquema_v1.md`; plan de la tarea en `docs/planes/M0-T0.2_plan.md`):

- `data/*.tres` — artefacto **autoritativo para el editor** (`game_config.tres`, `tuning.tres`).
- `data/*.json` — **espejo** editable del `.tres`; formato de modding y edición en caliente. Un test de deriva exige que ambos coincidan.
- `user://mods/*.json` — mods del juego: archivos planos aplicados sobre la base en **orden de bytes ASCII** (`B.json` < `a.json`: las mayúsculas van primero; usa minúsculas en los nombres de archivo de mod). En Windows, `user://` = `%APPDATA%\Godot\app_userdata\RutaFragil`. Ojo: `res://` es de **solo lectura en los exports** — editar el JSON base es función de desarrollo; los mods en `user://` son la vía publicada.

Autoridad entre capas: el `.tres` es autoritativo **para el editor**; en caliente gana la última capa aplicada (el JSON base va encima del `.tres`, y los mods encima de ambos). El test de deriva mantiene `.tres` y espejo iguales. Los `.tres` se regeneran **solo con la herramienta** (`import_data_mirror.gd`); no guardar desde el Inspector.

Un mod mínimo (`user://mods/zz_mi_mod.json`):

```json
{ "tuning": { "starting_money": 999 } }
```

Tres herramientas headless (ejecutar siempre con `timeout 120`; forma verificada en M0-T0.2):

```bash
# JSON → .tres (regenera los Resources desde los espejos)
timeout 120 "$GODOT_BIN" --headless --path . -s res://src/tooling/import_data_mirror.gd

# .tres → JSON (reescribe los espejos; tras regenerar, `git status` debe quedar limpio)
timeout 120 "$GODOT_BIN" --headless --path . -s res://src/tooling/write_data_mirror.gd

# Imprime lo cargado (base + mods) y el resumen del reporte — prueba los criterios de T0.2
timeout 120 "$GODOT_BIN" --headless --path . -s res://src/tooling/print_game_data.gd
```

**R1:** nunca hardcodear el número de jugadores. Toda UI de lobby/HUD se genera para N jugadores leyendo `GameConfig.max_players` (el autoload lo expone como propiedad delegada del dato, D43).

## Mapa de carpetas (§20)

```
addons/     addons de terceros (hoy solo gdUnit4; cualquier addon nuevo requiere aprobación del dueño, R5)
src/
  autoloads/
  core/
  vehicle/
  packages/
  crew/
  net/
  ui/
  biomes/
  tooling/  herramientas CLI del juego (import/write/print de datos; se ejecutan con `godot -s`)
data/       datos del juego
assets/     arte, audio, fuentes (binarios vía Git LFS)
scenes/     escenas .tscn
tests/      suites gdUnit4 ([gdunit4] test_lookup_folder="tests", D33)
tools/      scripts del repo (con .gdignore: el editor no los ve)
docs/       documentación del proyecto (con .gdignore)
```

## Notas de configuración

- `physics_ticks_per_second` queda en **60**: es el default del motor, por eso no aparece en `project.godot` (el editor borra las claves con valor default en su primer guardado con ventana).
- Física 3D: Jolt (`physics/3d/physics_engine="Jolt Physics"`, declarado a mano: el DEFAULT del motor sigue siendo GodotPhysics3D).
- Render: Forward+; driver en Windows `d3d12` (D31).
- `*.uid` e `*.import` **se versionan**; `.godot/` y `reports/` no. `export_presets.cfg` se versiona (M4).
- Git LFS trackea los binarios listados en `.gitattributes`. Los `.svg` van en Git normal (D36). El remoto debe tener **LFS habilitado ANTES del primer push**: el índice ya contiene punteros LFS (ver `git lfs ls-files`; hoy todos son PNG del addon gdUnit4).
- Documentos de referencia: `AGENTS.md` (reglas para agentes), `DECISIONS.md`, `BACKLOG.md`, `CREDITS.md`, `docs/planes/M0-T0.1_plan.md`, `docs/planes/M0-T0.2_plan.md`, `docs/datos/esquema_v1.md` (esquema de datos v1).
