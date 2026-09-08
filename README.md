# Ruta Frágil

Proyecto Godot **4.7.2.stable.official.ed1daf0bf** (build estándar, no .NET), GDScript tipado.

El título es provisional (Apéndice C del maestro); el nombre interno del proyecto es `RutaFragil` (D37).

## Regla de versión del motor (ADR-000)

**Solo parches 4.7.x, nunca dev/beta.** El test `test_engine_is_pinned_to_4_7_2` (`tests/smoke_test.gd`) lo hace cumplir en ambas máquinas.

## Instalación del motor

### Windows

1. Descargar el build **estándar (no .NET)** de Godot 4.7.2 desde godotengine.org.
2. Instalar en `C:\Godot\4.7.2\`.
3. Desde terminal usar siempre `Godot_v4.7.2-stable_win64_console.exe`: propaga el código de salida; el `.exe` sin sufijo `_console` no.

### macOS

1. macOS ≥ 11 (mínimo de Godot 4.7).
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
# Windows — suite de tests gdUnit4 headless
tools/run_tests.ps1
```

```bash
# macOS / Linux — suite de tests gdUnit4 headless
tools/run_tests.sh
```

Ambos verifican la versión del motor, importan el proyecto y corren `tests/`; dejan el reporte JUnit en `reports/` (ignorado por Git).

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
- Git LFS trackea los binarios listados en `.gitattributes`. Los `.svg` van en Git normal (D36).
- Documentos de referencia: `AGENTS.md` (reglas para agentes), `DECISIONS.md`, `BACKLOG.md`, `CREDITS.md`, `docs/planes/M0-T0.1_plan.md`.
