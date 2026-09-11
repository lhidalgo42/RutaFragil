# AGENTS.md — Ruta Frágil

Reglas para agentes de código que trabajen en este repo.

**Jerarquía:** maestro v0.2 > briefing v0.2 > plan de la tarea > criterio del agente. Las contradicciones se reportan, no se resuelven en silencio.

**Fuente:** las secciones §0.3, §0.4 y §0.8 de abajo son copia **textual** de `docs/RUTA_FRAGIL_documento_maestro_v0.2_godot.md`. Si difieren, manda el maestro. Escritas por Claude el 2026-09-08 con autorización del dueño (revisión 01 de M0-T0.1, hallazgo B1).

## Reglas R1–R14 (maestro §0.3, textual)

```
REGLAS DEL PROYECTO RUTA FRÁGIL — OBLIGATORIAS EN TODA SESIÓN (v0.2 Godot)
R1  Nunca hardcodear el número de jugadores. Leer siempre GameConfig.max_players.
    Toda UI de lobby/HUD se genera dinámicamente para N jugadores.
R2  Todo contenido (paquetes, biomas, contratos, herramientas, sistemas del bus)
    se define en Resources (.tres) con espejo JSON en res://data/ y carga desde
    user://mods/. Prohibido definir contenido en código.
R3  GDScript con tipado estático en TODAS las declaraciones (variables, parámetros,
    retornos). Prohibido C#, GDExtension o addons nuevos sin ADR aprobado.
R4  Autoridad de red: el peer con autoridad sobre el bus (ADR-006) simula el bus y
    los paquetes sueltos en su interior; el host es dueño de economía, contratos,
    spawns y estado de sistemas. Nadie simula física de lo que no le pertenece.
R5  Prohibido agregar addons/dependencias sin aprobación humana explícita.
R6  Una tarea por sesión. No tocar archivos fuera del alcance declarado en el plan.
R7  Antes de declarar una tarea terminada: (a) el proyecto abre sin errores en
    consola, (b) los tests gdUnit4 pasan en headless, (c) los criterios de
    aceptación se probaron con evidencia adjunta (salida de tests, log, screenshot).
    Si un criterio no se puede probar desde CLI/editor, decirlo; nunca marcarlo.
R8  Scripts de máximo 400 líneas; escenas de máximo 60 nodos. Si crece, dividir.
R9  Código, nodos y archivos en inglés, snake_case. Comentarios solo para el porqué.
R10 No dejar TODOs silenciosos: todo pendiente se registra en BACKLOG.md.
R11 No inventar APIs. Verificar en la documentación de Godot 4.7 / GodotSteam antes
    de escribir; si hay duda, pedirla.
R12 Ediciones destructivas (borrar archivos, reescribir escenas existentes)
    requieren confirmación humana previa.
R13 Todo sistema de gameplay nuevo entrega con al menos un test gdUnit4 que lo
    ejercite sin editor abierto.
R14 Escenas y recursos siempre en formato texto (.tscn/.tres). Prohibido .scn/.res
    binarios. Prohibido cifrar scripts (moddabilidad, D11).
```

## Protocolo por tarea (maestro §0.4, textual)

1. Humano pega: reglas §0.3 + tarea completa (Parte 3) + rutas relevantes.
2. Agente responde con **plan** (archivos, enfoque, riesgos). Humano aprueba o corrige.
3. Agente implementa → `godot --headless` corre tests → adjunta evidencia.
4. Humano ejecuta el **GATE** (§0.7). Solo entonces merge.
5. Tres intentos fallidos = detenerse y replantear, no forzar.

## Frontera de autonomía (maestro §0.8, textual)

La razón del cambio a Godot es que la IA pueda **desarrollar y probar sin un humano en cada iteración**. Eso es cierto para una clase de pruebas y falso para otra; esta es la frontera exacta.

**El agente ejecuta sin supervisión, tantas veces como quiera:**

- Correr el proyecto en headless (`godot --headless`) y los tests gdUnit4: unitarios y de simulación (decaimiento de paquetes, ventanas de sincronía de `CoopInteractable`, física del bus en el circuito automático del Playground — Jolt corre sin render).
- **Pruebas de red multi-instancia automáticas (T0.4):** lanzar 1 host + N clientes headless en procesos separados sobre ENet en la misma máquina, ejecutar un guion scriptado y afirmar convergencia de estado (posiciones de paquetes, dinero, ocupación de puestos, cambio de autoridad del bus). Esto no era posible sin editor en Unity; es la ventaja concreta de D17.
- Exportar builds por CLI a una carpeta de staging (nunca subirlas).
- Capturar screenshots por script en una ejecución con ventana (en la máquina de desarrollo) y compararlas contra referencias.
- Iterar código → test → código hasta que todo esté verde, sin pedir permiso entre iteraciones.

**El agente NO hace sin humano, nunca:** merge a `main` · crear o cambiar ADRs · agregar dependencias (R5) · borrar o reescribir escenas (R12) · tocar Steamworks, subir builds o gastar dinero · marcar un gate como pasado · declarar que algo "se siente bien".

**Lo que ninguna prueba automática mide (por eso existen los gates §0.7):** jitter *perceptible*, game feel, diversión, legibilidad visual, calidad de voz, comportamiento bajo latencia real de internet y con cuentas Steam reales. Un test verde en headless dice "la lógica converge"; no dice "es jugable". La supervisión no desaparece: **se mueve de cada iteración a cada gate.** Un agente que reporta verde sin que un humano lo reproduzca es exactamente cómo un co-op llega a Steam con 40% de reseñas positivas.

## Comandos verificados (plan M0-T0.1, pasos 5–7)

```powershell
# Suite de tests gdUnit4 (verifica versión, limpia reports/ y crea reports/.gdignore,
# importa, corre tests/, exige ≥3 tests descubiertos y falla ante "No test cases found").
# Forma verificada en Windows (m-2.4): la forma corta `tools/run_tests.ps1` falla
# con política Restricted — ver README.md.
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1
```

```bash
# macOS / Linux — forma verificada
bash tools/run_tests.sh
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
# gdUnit4 headless (forma exacta del paso 6 v1.1 + D40: SIN `-d` ni `--remote-debug`;
# con esos flags cada corrida imprimía dos líneas ERROR por el puerto 0, y se verificó
# que sin ellos los errores de script siguen saliendo con backtrace y código 105.
# NUNCA poner `--` o `++` antes de las opciones de gdUnit4)
"$GODOT_BIN" --headless --path <raíz> -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -c -a res://tests -rd res://reports
```

Códigos de salida de gdUnit4: `0` ok · `100` fallos · `101` orphans (nodos huérfanos) · `103` headless rechazado · `104` versión de Godot no soportada · `105` errores de script en el descubrimiento · cualquier otro (444, 134, 0xC0000005…) = fallo de infraestructura.

```bash
# Normalización de project.godot: UNA sola ejecución con ventana (headless nunca lo reescribe).
# Revisar el diff, aceptarlo y verificar que un segundo arranque no produce cambios.
"$GODOT_BIN" --editor --path <raíz> --quit
```

```bash
# Herramienta de demo del Playground (M0-T0.3): corre el circuito automático y
# reporta líneas DEMO; quit() en todas las rutas; SIEMPRE con `timeout`.
# Código de salida 0 solo con result=lap_completed (ver README.md "Playground y demo").
timeout 120 "$GODOT_BIN" --headless --fixed-fps 60 --path . -s res://src/tooling/run_demo.gd
timeout 300 "$GODOT_BIN" --headless --path . -s res://src/tooling/run_demo.gd            # tiempo real
timeout 120 "$GODOT_BIN" --path . -s res://src/tooling/run_demo.gd ++ seconds=20 screenshot=user://playground.png
```

## Rutas clave

- Resolución de `GODOT_BIN` (D39): variable de entorno `GODOT_BIN` → `tools/godot_bin.local` (ignorado por Git) → default por SO:
  - Windows: `C:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe`
  - macOS: `/Applications/Godot.app/Contents/MacOS/Godot`
- Versión pineada del motor (ADR-000): `4.7.2.stable.official.ed1daf0bf` — solo parches 4.7.x, nunca dev/beta.
- Al subir de parche 4.7.x hay que actualizar la versión pineada en cuatro archivos: `tests/smoke_test.gd`, `tools/run_tests.ps1`, `tools/run_tests.sh`, `README.md` (revisión 01, m8).
- Suites de tests en `tests/` (D33); reportes en `reports/` (ignorado).
- Los `CLAUDE.md`/`AGENTS.md` bajo `addons/` son documentos de terceros y NO aplican al proyecto (ej. `addons/gdUnit4/src/asserts/CLAUDE.md`).
- Decisiones: `DECISIONS.md` · Pendientes: `BACKLOG.md` · Plan vigente: `docs/planes/` · Revisiones: `docs/revisiones/`.
