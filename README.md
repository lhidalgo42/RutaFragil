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

- `data/*.tres` — artefacto **autoritativo para el editor/Inspector** (`game_config.tres`, `tuning.tres`).
- `data/*.json` — **espejo** editable del `.tres`; formato de modding y edición en caliente. Un test de deriva exige que ambos coincidan.
- `user://mods/*.json` — mods del juego: archivos planos aplicados sobre la base en **orden de bytes ASCII** (`B.json` < `a.json`: las mayúsculas van primero; usa minúsculas en los nombres de archivo de mod). En Windows, `user://` = `%APPDATA%\Godot\app_userdata\RutaFragil`. Ojo: `res://` es de **solo lectura en los exports** — editar el JSON base es función de desarrollo; los mods en `user://` son la vía publicada.

Autoridad entre capas: el `.tres` es autoritativo **para el editor/Inspector**; en caliente gana la última capa (el JSON base va encima del `.tres`, y los mods encima de ambos); el test de deriva mantiene ambos iguales. Los `.tres` se regeneran **solo con la herramienta** (`import_data_mirror.gd`); no guardar desde el Inspector.

Recarga en caliente (D46): `GameConfig.reload(base_dir: String = "res://data", mods_dir: String = "user://mods") -> DataLoadReport` — los argumentos existen para pruebas; el juego usa los defaults.

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

# Imprime lo cargado (base + mods) y el resumen del reporte — prueba los criterios de T0.2; sale con código 1 si !is_ok()
timeout 120 "$GODOT_BIN" --headless --path . -s res://src/tooling/print_game_data.gd
```

**R1:** nunca hardcodear el número de jugadores. Toda UI de lobby/HUD se genera para N jugadores leyendo `GameConfig.max_players` (el autoload lo expone como propiedad delegada del dato, D43).

## Playground y demo

El **Playground** (`scenes/playground.tscn`, M0-T0.3) es la escena principal del proyecto: un greybox con plano, rampa, campo de baches y una zona de agua, recorrido por un **bus placeholder conducido por script** (`DemoDriver` sobre la interfaz `set_drive(throttle, steer, brake)`). Con **F5** en el editor la corre directamente (`run/main_scene` apunta a ella, D52).

Por CLI corre la herramienta `src/tooling/run_demo.gd` (siempre con `timeout`; hace `quit()` en todas las rutas):

```bash
timeout 120 "$GODOT_BIN" --headless --fixed-fps 60 --path . -s res://src/tooling/run_demo.gd
timeout 300 "$GODOT_BIN" --headless --path . -s res://src/tooling/run_demo.gd            # tiempo real
timeout 120 "$GODOT_BIN" --path . -s res://src/tooling/run_demo.gd ++ seconds=20 screenshot=user://playground.png
```

La primera forma (`--fixed-fps 60`) es determinista y corre la vuelta en segundos de reloj; la segunda demuestra que también funciona a 60 Hz en tiempo real; la tercera (con ventana) guarda una captura PNG.

Cada línea `DEMO` del reporte significa:

- `DEMO waypoint i t=..s` — el bus alcanzó el waypoint `i` en el segundo de juego `t`.
- `DEMO water_entered t=..s` — el bus entró en la zona de agua.
- `DEMO result=<lap_completed|rolled_over|stuck|timeout> t=..s waypoints=N max_speed_kmh=.. min_upright=..` — cierre de la corrida: cómo terminó, tiempo de juego, waypoints alcanzados, velocidad máxima y el mínimo producto punto "arriba" del bus (1.0 = nunca cerca de volcar).

El **código de salida es 0 solo con `result=lap_completed`**; `rolled_over`, `stuck` y `timeout` salen con código 1.

## Pruebas de red (M0-T0.4)

Sonda de acarreo M2-GATE: `timeout 120 "$GODOT_BIN" --headless --fixed-fps 60 --path . -s res://src/tooling/run_carry_probe.gd ++ window_s=60 save_raw=1 write=physics_frame` guarda CSV/JSON en `user://carryprobe/`; `write=physics_process` compara el orden de escritura.

Banco de adopción de plataforma (ronda 5): `python docs/evidencia/M2-GATE/run_r5_probe.py recording mode=rec` graba una recta real a 60 Hz; después `python docs/evidencia/M2-GATE/run_r5_probe.py slow_encounter candidate=engine ratio=0.665 walking=0 box_z=1.5 box_x=0.3` reproduce sin red. El helper tiene plazo externo y guarda todos los argumentos; variantes y límites en evidencia 16.

El tercer intento D96 exige `-Precondition <summary.json del experimento de 300 s>` en PowerShell, o `precondition=<ruta>` en Bash: mismo commit limpio y configuración, ambos peers con ≥95 % de apoyo, último tick apoyado y pérdida máxima de 30 ticks.


Arnés multi-instancia sobre ENet: 1 host + 3 clientes headless en la misma máquina que conectan, reciben marcadores replicados y afirman convergencia del bus (≤ 0,5 m / ≤ 5° tras frenar y asentar). Vive en `src/net/` (`NetworkBackend`, `NetMarker`, utilidades) y `src/tooling/run_net_scenario.gd` (roles `launcher | host | client`). Detalles y decisiones: D53–D58 en `DECISIONS.md`.

El arnés completo (`tools/run_tests.ps1` / `run_tests.sh`) corre la red como paso final; para iterar solo las unitarias usa `-SkipNet` / `--skip-net`. Solo la parte de red:

```bash
powershell -ExecutionPolicy Bypass -File tools/run_net_tests.ps1   # Windows
bash tools/run_net_tests.sh                                        # macOS / Linux
```

Opciones del guion (tras `++`): `port=` (defecto 47810, con 4 alternativas), `clients=` (3), `seconds=` (30), `waypoints=` (índice en el que parar, 0-based: 2 por defecto, **16 = vuelta completa**; el presupuesto de tiempo se deriva de la ruta pedida). Los procesos hijos reportan por archivo (`user://netscenario/*.json`) y por su propio `--log-file` (`user://netlogs/`), nunca por stdout. Tras una corrida no debe quedar ningún proceso Godot vivo; el lanzador mata supervivientes y todo corre bajo `timeout` externo.

## Conducir el bus (M1-T1.1)

El bus con suspensión por raycast (ADR-007) es la escena principal: abre el proyecto y pulsa F5 — quedas al volante (desde M1-T1.1 el modo por defecto de la escena es conducir; la demo automática sigue con `run_demo`, que fuerza `demo_mode`).

Teclas (D62, sección `[input]` de `project.godot`): **W** acelerar · **S** frenar/marcha atrás · **A/D** girar · **Espacio** freno de mano (derrapa: §4.5) · **C** alternar cámara cabina/persecución · **F1** entrega el bus a la demo automática (y lo devuelve) sin consola (D71) · **E** interactuar (sentarse al volante / levantarse, D76).

Desde M2-T2.2, **F5 te deja a pie**: camina con WASD (Shift corre, Espacio salta) hasta la puerta lateral del bus, entra por ella, siéntate al volante con **E** y conduce; otra **E** te levanta. La tripulante es un `CharacterBody3D` (`src/crew/`) transportado por la plataforma móvil con la herencia del motor (D74, medido).

**Cámara y ratón** (D79): a pie ves en primera persona por la `EyeCamera`; al sentarte pasas a la cabina (primera persona del conductor) y **C** alterna con la persecución (tercera persona); al levantarte recuperas tu vista. El **ratón mueve la mirada** (guiñada + cabeceo ±89° a pie; cono ±120°/±45° en cabina para los retrovisores), con la sensibilidad en `data/tuning.json` (`player_mouse_sensitivity`). El ratón queda **capturado** al jugar: **Escape lo libera** y un **clic** lo recaptura; con la demo automática (F1) queda libre.

El interior greybox (M2-T2.1, `src/vehicle/bus_interior.tscn`) sigue §4.3 y D67: caja útil 2,30 × 7,60 × 2,05 m libres, pasillo central de 1,20 m, seis posiciones útiles marcadas (`driver`, `copilot`, `bench`, `shelf_left`, `shelf_right`, `stretcher`), doce anclajes de carga en ambos muros, puerta lateral de 0,90 m con dos escalones y puertas traseras dobles. Sin personaje todavía: caminar y el abordaje son T2.2.

**Medir la sensación** (r1.3 de M2-T2.2): `godot --headless --path . -s res://src/tooling/probe_handling.gd` (bajo `timeout`) imprime líneas `MEASURE` con altura de reposo, 0–60 km/h, velocidad máxima, radio de giro y frenada desde 50 km/h — la regla de regresión de la sensación aprobada en el gate de T1.1. Referencia actual: 0,977 m · 6,93 s · 90,0 km/h · 12,4 m · 6,7 m en 0,98 s.

**Ajustar la sensación sin recompilar** (D61, para lo que se construyó T0.2): edita `data/tuning.json` (grupo `bus_*`, valores en `docs/datos/esquema_v1.md`) y recarga — con el juego en marcha basta llamar a `GameConfig.reload()` desde el depurador o editar antes de arrancar. El `.tres` se regenera con `import_data_mirror.gd` (ver "Datos y mods"), nunca a mano ni desde el Inspector.

## Carga: agarrar, soltar, lanzar y amarrar (M2-T2.3, D81–D89)

Cuatro cajas greybox (0,4 m, 8 kg) viven en el bus: dos sobre los estantes, dos en el pasillo. Los tres estados físicos de ADR-003: suelto (rigid real, con el amortiguador vertical relativo al bus), en mano (cinemático, sigue tu mirada), amarrado (congelado en un anclaje).

- **E (toque)** sobre lo más alineado con tu mirada: agarrar una caja libre, desamarrar una amarrada, o el asiento si apuntas al volante. Con una caja en la mano, E toque apunta a anclajes o a nada — el asiento se rechaza (nadie conduce cargando).
- **E (mantener)** con una caja en la mano y un anclaje libre al alcance: **amarrar** (1,5 s; suelta E antes para cancelar).
- **Clic izquierdo**: lanzar (6 m/s + la velocidad del bus). **Clic derecho**: soltar con cuidado (cae a tus pies si no cabe en la mano).
- La carga suelta **rueda y golpea**: al frenar a fondo una caja suelta se viene al frente a velocidad de daño (§5.3). Amarra.
- Los doce anclajes (`Restraints`, seis por muro sobre las tapas de los estantes) aceptan una caja cada uno; la deriva de una amarrada es cero por construcción.

Los números de la carga viven en `data/tuning.json` (grupo `cargo`, D87) y se ajustan igual que el resto de la sensación (ver "Datos y mods").

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

## Gate de dos instancias (M2-GATE)

Cliente con ventana e input humano; anfitrión sin ventana conduciendo:

```powershell
powershell -ExecutionPolicy Bypass -File tools/run_gate.ps1
```

```bash
bash tools/run_gate.sh
```

Equivale a `run_net_scenario.gd ++ mode=gate seconds=300 human=client`.
En Windows, `-Human none -Windowed both` ejecuta ambas tripulantes guionizadas
con render; en Bash, `human=none windowed=both`. Los resultados, trazas, logs
y capturas quedan en `user://gate/run_<fecha>/`; `-Output` o `output=` fija la ruta.
El presupuesto sigue `seconds + 90`, independientemente de los waypoints.
El gate desactiva VSync por defecto y usa `max_fps=0`. Para dejarlo explícito:
`-VSync off` en PowerShell, `vsync=off` en Bash. Con VSync o límite de FPS,
el rendimiento queda sin verificar.
Cada JSON declara VSync, límite de FPS y tamaño del viewport; se informan
percentil 1 y porcentaje de frames bajo 60, también si el resultado falla.

El observador de deslizamiento es un nodo separado, al final de la física
(`process_physics_priority=1000`, también `process_priority=1000`) en ambas
instancias. Primero se exige apoyo local en el bus en al menos el 95 % de los
ticks; por debajo falla por no poder viajar y no se cita el deslizamiento como
jitter. Con apoyo suficiente se comparan los p99 de la misma corrida; el máximo
solo se informa. Penetración se juzga solo en cuerpos simulados localmente.
Menos de diez ciclos agarrar → amarrar → desamarrar → soltar por instancia
invalida la medición. Las corridas de menos de 300 s son comprobaciones previas.
El registro `docs/evidencia/M2-GATE/04_iteration_ledger.json` impide una cuarta
corrida tras tres iteraciones válidas fallidas. El resultado automático no
sustituye la aprobación humana del gate.

## Notas de configuración

- `physics_ticks_per_second` queda en **60**: es el default del motor, por eso no aparece en `project.godot` (el editor borra las claves con valor default en su primer guardado con ventana).
- Física 3D: Jolt (`physics/3d/physics_engine="Jolt Physics"`, declarado a mano: el DEFAULT del motor sigue siendo GodotPhysics3D).
- Render: Forward+; driver en Windows `d3d12` (D31).
- `*.uid` e `*.import` **se versionan**; `.godot/` y `reports/` no. `export_presets.cfg` se versiona (M4).
- Git LFS trackea los binarios listados en `.gitattributes`. Los `.svg` van en Git normal (D36). El remoto debe tener **LFS habilitado ANTES del primer push**: el índice ya contiene punteros LFS (ver `git lfs ls-files`; hoy todos son PNG del addon gdUnit4).
- Documentos de referencia: `AGENTS.md` (reglas para agentes), `DECISIONS.md`, `BACKLOG.md`, `CREDITS.md`, `docs/planes/M0-T0.1_plan.md`, `docs/planes/M0-T0.2_plan.md`, `docs/datos/esquema_v1.md` (esquema de datos v1).
