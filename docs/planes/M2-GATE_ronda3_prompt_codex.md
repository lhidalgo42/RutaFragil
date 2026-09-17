# Prompt para Codex — M2-GATE Ronda 3 (primer relevo: cambio de agente ejecutor)

Copiar desde `CONTEXTO:` hasta el final. **Sustituye a `M2-GATE_ronda3_prompt.md`**, que estaba escrito para el agente anterior y le hablaba de tú a su propio trabajo. Este es el mismo encargo contado desde cero, porque el ejecutor es nuevo.

---

CONTEXTO: Eres el **agente ejecutor** de un proyecto de videojuego llamado **Ruta Frágil**. El ejecutor anterior se quedó sin presupuesto a mitad de tarea y tú tomas el relevo. Nadie espera que sepas nada del proyecto: esto te lo cuenta todo. Lee este documento entero antes de tocar un archivo.

## 1. Quién es quién

- **El dueño** es el humano. Decide, juega los *gates* de sensación y es el único que mergea a `main`. No programa.
- **El revisor** es otra IA (Claude). Escribe los planes, escribe estos prompts, y **revisa tu trabajo reproduciendo tus mediciones por su cuenta** antes de aprobarlas. No escribe código de producción.
- **Tú ejecutas.** Escribes el código, los tests y la evidencia. Cuando el plan dice "para y reporta", paras de verdad.

El revisor no se cree los números que le den: monta su propia sonda y compara. En las dos rondas anteriores encontró así un umbral suyo mal escrito, una tabla irreproducible y un hecho del motor que estaba al revés en un comentario commiteado. Espera ese nivel de escrutinio y te irá bien: **un número que no se puede repetir no vale**, y **una bandera no es una consecuencia** (que un test diga `seated == true` no prueba que el mundo se comporte como si lo estuviera).

## 2. El proyecto

"Ruta Frágil": co-op online de 1 a 4 jugadores (escalable a 8) en el que la tripulación vive dentro de un bus de reparto por el que se camina mientras conduce. Godot **4.7.2 estable**, **GDScript con tipado estático en todas las declaraciones**, física **Jolt**, Windows.

- Repo: `C:\Users\Leo\Documents\RutaFragil`
- Fuente de verdad: `docs/RUTA_FRAGIL_documento_maestro_v0.2_godot.md` y `docs/CONTEXTO_RUTA_FRAGIL_v0.2.md`
- **Reglas permanentes R1–R14: están textuales en `AGENTS.md` §0.3. Léelas.** Las que más se rompen: **R3** tipado estático en todo, **R6** una tarea por sesión y no tocar nada fuera del alcance declarado, **R8** scripts ≤ 400 líneas y escenas ≤ 60 nodos, **R10** ningún pendiente silencioso (va a `BACKLOG.md`), **R13** todo sistema nuevo entrega con test gdUnit4, **R14** escenas siempre en texto (`.tscn`/`.tres`).
- Decisiones numeradas en `DECISIONS.md` (vas por D97). Pendientes en `BACKLOG.md`. Planes en `docs/planes/`, revisiones en `docs/revisiones/`, evidencia en `docs/evidencia/<tarea>/`.

### Entorno, con las trampas que ya costaron tiempo

- **Godot:** `C:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe`. Usa **siempre el ejecutable `_console`** desde la línea de órdenes: el otro no engancha la salida estándar en Windows y no verás nada.
- **Arnés de tests:** `powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1` (la forma corta falla con política Restricted) y `bash tools/run_tests.sh`. Corre unitarios + un escenario de red real con 1 anfitrión y 3 clientes. `-SkipNet` / `--skip-net` para iterar solo unitarias.
- **El arnés exige el conteo EXACTO de tests.** Hoy `expected_tests = 180`, en `tools/run_tests.ps1:68` y `tools/run_tests.sh:46`. **Si añades o quitas tests, subes la constante en el mismo commit**, o el arnés falla con código 1. Existe porque gdUnit, en clones frescos, ha omitido en silencio el último test de una suite tres veces.
- **`main` vive en OTRO worktree** (`C:\Users\Leo\Documents\RutaFragil-main`), así que `git checkout main` **falla** con "already used by worktree". Tú no lo necesitas: **no mergeas, no tocas `main`, no haces push a `main`**. Trabajas en la rama `m2/gate-two-instances`.
- **Imágenes por Git LFS.** Las capturas de evidencia van como LFS; comprueba con `git lfs ls-files` que dos capturas distintas no acabaron siendo el mismo objeto (ya pasó).
- **Las escenas `.tscn` se editan como TEXTO, nunca abriendo el editor de Godot.** Abrir y guardar en el editor reescribe la escena y una vez movió el bus a 14 m de altura sin que nadie se diera cuenta hasta mirar una captura.

### Hechos del motor ya medidos — no los vuelvas a suponer, y no los contradigas sin medir

Estos salieron de sondas reales de este proyecto. Valen para Godot 4.7.2 con Jolt:

1. **Todo cuerpo se posiciona ANTES de entrar al árbol y ANTES de reactivar su colisión.** Un tick en el sitio equivocado dispara la despenetración: midieron el bus pasando de 0,02 a 237 m/s en un solo tick.
2. **Un cinemático con colisión activa dentro del casco del bus lo patea cada tick.** Por eso una caja en mano o una tripulante sentada llevan la colisión apagada.
3. **`call_deferred` emitido durante un tick de física se ejecuta al final de ESE tick**, antes del paso del servidor. De ahí el patrón "apagar colisión y mover" como pareja diferida.
4. **Un cuerpo congelado en `FREEZE_MODE_STATIC` no transporta nada**; en `KINEMATIC` sí.
5. **Una métrica por tick no significa nada sin un punto de muestreo declarado y fijo**, y esto lo aprendió el revisor equivocándose en esta misma tarea. Llegó a afirmar que una transformada escrita sobre un `RigidBody3D` congelado en `KINEMATIC` solo entregaba velocidad de plataforma si se escribía desde `physics_frame`. Era falso: muestreando en `physics_frame` gana esa escritura (0,1586 contra 0,6009) y muestreando después de los nodos gana la contraria (0,0127 contra 0,6009). **Imagen en espejo, misma física.** Todo lo que compares tick a tick —el criterio del gate incluido— declara dónde toma la muestra, y usa el mismo punto para las dos instancias y para todas las filas. La sonda que lo demuestra es `src/tooling/run_write_order_probe.gd`; la retractación, `docs/revisiones/M2-GATE_revision_03.md`.
   **La señal `physics_frame` se emite ANTES del procesado de nodos** — eso sí quedó establecido, y se deduce de que los dos puntos de muestreo difieran.
6. **Capas de colisión (D90):** 1 mundo, 2 carga, 3 tripulantes. El rayo de suspensión del bus lee **solo** la capa mundo; sin esa máscara, una caja o una tripulante dentro del casco vuelcan el bus boca abajo.
7. **El escenario de red corre en tiempo real** (no hay `--fixed-fps` con varios procesos), todas las instancias comparten `user://` (logs separados con `--log-file`), los IDs de peer son aleatorios (el anfitrión es 1), los RPC exigen rutas de nodo idénticas en ambos extremos, y el puerto por defecto es 47810 con cuatro alternativas.
8. **El log que manda es `user://logs/godot.log`**, no la consola. En Windows: `%APPDATA%/Godot/app_userdata/RutaFragil/logs/godot.log`.

## 3. Dónde está el proyecto

`main` está en `2b16e99` con M0 (fundaciones, configuración, playground, escenario de red), M1-T1.1 (bus con suspensión por raycast, sensación aprobada por el dueño) y M2 completo hasta T2.3: interior caminable, tripulante en primera persona que entra, camina, se sienta y conduce, y carga que se agarra, se suelta, se lanza y se amarra. 180 tests.

Estás en la rama **`m2/gate-two-instances`**, HEAD **`98dccc1`**, árbol limpio, para la tarea **M2-GATE**.

### Qué es M2-GATE

Es el **gate duro del hito M2**, que el documento maestro define así (§16, ADR-003):

> Con 2 instancias locales, caminar, agarrar y amarrar dentro del bus a 80 km/h sobre baches, 60 fps, sin jitter ni atravesamientos durante 5 minutos. Si la opción A falla 3 iteraciones → opción B antes de construir nada encima.

Es **una medición con lo mínimo construido para poder medirla**, no es el hito de red completo. Léete entero `docs/planes/M2-GATE_plan.md`: sus decisiones **D91–D97** mandan sobre tu criterio.

### Lo que ya hizo el ejecutor anterior (rondas 0 a 2), y que tú heredas

- **Paso 0:** el arnés pasó a exigir el conteo exacto de tests; la suite de amarres se partió en dos; nota en BACKLOG.
- **Paso 1, la medición que decide la arquitectura:** escribió una sonda determinista y **la commiteó** en `src/tooling/run_carry_probe.gd`. Graba una vez la trayectoria real del bus con la demo y la reproduce sobre un bus congelado con tres mecanismos de cliente, midiendo cómo viaja una tripulante encima. **El revisor corrió esa sonda en su máquina y reprodujo la tabla dígito a dígito**, que es el estándar que se te va a pedir a ti también.
- **Conclusión aprobada:** el bus del cliente se congela en `KINEMATIC` y su transformada replicada **se interpola a 60 Hz** entre las dos últimas fotos de 30 Hz, con una foto de latencia. Las otras dos opciones quedan descartadas con dos sondas independientes.
- **Las firmas de la fase 0** quedaron propuestas y aprobadas, con siete correcciones ya incorporadas.

Todo eso está commiteado. **Tu trabajo empieza en la fase 0.**

## 4. TU TAREA

Lee primero, en este orden: `docs/planes/M2-GATE_plan.md` (entero), `docs/revisiones/M2-GATE_revision_02.md` (entero, es la lista de lo que hay que corregir), `src/tooling/run_carry_probe.gd`, y `src/tooling/run_net_scenario.gd` con `src/net/net_scenario_util.gd`.

### 4.1 Fase 0: un commit con las firmas y NUEVE correcciones dentro

Las firmas aprobadas están en la revisión 02 y en el plan. Encima van estas correcciones. **Cuatro son bloqueantes.**

> ⚠️ **RETIRADO el 2026-09-16.** Todo lo relativo a g2.1 en este documento queda sin efecto: la diferencia entre escribir desde `physics_frame` y desde el `_physics_process` de un nodo era un artefacto del punto de muestreo, no del punto de escritura. Véase `docs/revisiones/M2-GATE_revision_03.md`. La decisión de interpolar no depende de esto y sigue vigente.

**BLOQUEANTE g2.1 — el receptor del bus escribe desde `physics_frame`.** El docstring de `run_carry_probe.gd:12-16` afirma hoy lo contrario (que hay que escribir desde el `_physics_process` de un nodo con prioridad anterior a la tripulante). Está equivocado, y la evidencia 03 dice además lo opuesto al docstring, así que los dos textos se contradicen. Lo medido por el revisor, variando **solo** el punto de escritura:

| Camino del bus | Dónde se escribe la transformada | desliz./tick máx | velocidad de plataforma recibida / real |
|---|---|---|---|
| paso a 30 Hz | señal `physics_frame` | **0,1586** | **1,00** |
| paso a 30 Hz | nodo `_physics_process`, prioridad −100 | **0,6009** | **0,00** |
| paso a 30 Hz | nodo `_physics_process`, prioridad +100 | **0,6009** | **0,00** |
| paso a 30 Hz | nodo + fijar `linear_velocity` a mano | **2,8039** | 0,00 |
| interpolado | los tres órdenes | 0,079 | 1,00 |

Qué hacer: el receptor escribe desde `physics_frame` (o un punto equivalente anterior al procesado de nodos); **un test lo pinea** (camino a saltos de 30 Hz, tripulante de pie, y afirmar que la velocidad de plataforma no es cero en los ticks en que el bus se mueve, o como consecuencia que el deslizamiento máximo se queda bajo 0,3 m en vez de irse a 0,6); y **corriges el docstring de la sonda y la frase de la evidencia 03**. Con interpolación el orden da igual, así que **esto es invisible mientras la red va bien y aparece justo al perder paquetes**: por eso lleva test.

**BLOQUEANTE g2.7 — la mitad "caminando" de la tabla compara dos vueltas distintas.** En `run_carry_probe.gd::_run_table()` se graba la trayectoria de pie, se graba la de caminando, se imprimen los dos checksums y acto seguido se hace `_recording = recording_standing`, **descartando la grabación caminando**. Las tres filas de cliente caminando se reproducen sobre la trayectoria **de pie**, mientras la fila del anfitrión caminando corrió sobre la **de caminando**. Y difieren de verdad. Guarda las dos grabaciones, reproduce cada régimen con la suya, corrige el comentario que dice *"the checksum proves the trajectory does not depend on the crew"* (los datos dicen lo contrario) y **repite la mitad caminando de la tabla**.

**BLOQUEANTE g2.8 — `Package` no pertenece a ningún grupo.** Las firmas de los cuatro RPC resuelven el paquete "por grupo + nombre", y eso hoy no resuelve nada: los grupos que existen son `bus`, `bus_input`, `cabin_camera`, `chase_camera`, `crew`, `crew_hands`, `crew_input`, `eye_camera`, `seat` y `restraint_anchor`. Añade `add_to_group("package")` en `Package._ready()`.

**BLOQUEANTE g2.9 — las búsquedas de tripulante se resuelven una sola vez y no reintentan.** `crew_input.gd:83` y `door_transit.gd:29` hacen `get_first_node_in_group("crew")` en un `_find*()` diferido desde `_ready`, y si no hay nadie sueltan `push_error` y se quedan con `null` **para siempre**. Con las tripulantes creadas por el `MultiplayerSpawner`, que llegan después, esos nodos quedan muertos. Hay que **reintentar** o engancharse a la señal de aparición. Son once las búsquedas que asumen una sola tripulante; el reparto caso por caso está en la revisión 02 y en el plan.

**g2.2 — el criterio de paso cambió** (era un error del revisor, ya está corregido en D95). Se juzga el **p99** del deslizamiento por tick del cliente contra el del anfitrión **de la misma corrida**: no más de **1,5×**. El máximo se reporta pero **no se juzga**, porque lo sostienen una o dos muestras y premia a la réplica que alisa los golpes. Se reportan p95, p99 y p99,9 de las dos instancias.

**g2.3 — falta el error remoto del BUS en el JSON de métricas.** Hay error remoto de tripulante y de carga, pero no del bus, que es justo lo que se replica y lo que la interpolación puede alisar. Añade `bus_remote_error {p95_m, max_m, p95_deg, max_deg}`.

**g2.10 — `apply_replicated_state` necesita saber quién sostiene.** Tal como está propuesta no dice **qué tripulante** sostiene la caja cuando el estado replicado es `HELD`, y con dos tripulantes el cliente no puede colgarla de la mano correcta. Añade el peer al argumento, y **enumera en la fase 0 qué hace la función en cada transición**, incluida `STRAPPED → FREE` replicado, que hoy solo existe pasando por la mano.

**g2.13 — la columna "ticks sin suelo" no mide lo que el gate necesita** (también error de especificación del revisor). `is_on_floor()` dice **cualquier** suelo, incluido el `Ground` de 200×200 del Playground: en `03_raw/static_standing.csv` el tick 1200 tiene 59,6 m de deriva del bus y `on_floor = 1`, y 3.291 de 3.600 ticks tienen deriva mayor de 10 m con `on_floor = 1`. Tiene que significar "**no apoyada en el bus**": comprueba el cuerpo del apoyo (`get_platform_rid()` o el colisionador del último `get_slide_collision()`) contra el bus y su interior, o exige además que la posición local esté dentro del casco. Y renómbrala.

**g2.14 — el checksum de la sonda no es una distancia.** `_recording_checksum` suma **con signo** `x + y + z` sobre 3.600 muestras, así que la diferencia entre regímenes no son "0,25 m por vuelta" (eso se dijo mal) y las cancelaciones pueden esconder divergencia. Sustitúyelo por máximo y p95 de `a[i].origin.distance_to(b[i].origin)`.

**Y tres líneas sueltas, en el mismo commit:** la sonda no aparece en `README.md` ni en `AGENTS.md`, donde sí están las otras herramientas (una línea con el comando en cada sitio); la evidencia 03 no declara el aviso `Jolt Physics job system exceeded the maximum number of jobs` que sí está en su propio log `03_raw/carry_final.log` (declara dónde sale y por qué crees que sale); y al BACKLOG va el hallazgo de que **la tripulante caminando perturba el bus**, con el número bueno una vez arreglado g2.14, porque en M4 significa que dos instancias con tripulantes en sitios distintos divergen aunque la física sea determinista.

**Una trampa más, sobre la carga:** `playground.gd` tiene **dos** puertas para generar la carga, no una — la llamada en `_ready` (`if cargo_spawn and not demo_mode:`) y una re-comprobación dentro de `_spawn_cargo()` (`if not cargo_spawn or demo_mode: return`, puesta a propósito porque la llamada es diferida). El anfitrión del gate necesita carga y hoy no la tiene porque corre con `demo_mode = true`. La condición correcta es por **autoridad**, no por la demo: `cargo_spawn and network_role != "client" and not (demo_mode and network_role == "single")`, **la misma en las dos puertas y extraída a un solo método** para que no puedan divergir. Y añade `cargo_spawn = false` en `tests/net/playground_client_mode_test.gd`, que instancia el rol cliente y con la regla nueva se pondría a crear cuatro `RigidBody3D` dentro de una suite unitaria.

### 4.2 Después de la fase 0: las dos mitades del trabajo

El plan las reparte entre dos agentes en paralelo con propiedad exclusiva de archivos. **Si puedes paralelizar con propiedad exclusiva, hazlo; si no, hazlas en este orden, que es lo seguro.** Lo que no vale es mezclar los dos ámbitos en los mismos commits.

**A — Tripulantes (D93).** Una tripulante por peer, creada por `MultiplayerSpawner` bajo `Crews/Crew_<peer_id>`, con autoridad de su peer. La local se simula como hoy; las remotas **no** llaman a `move_and_slide`: reciben `global_transform` a 30 Hz con interpolación y mantienen colisión en la capa 3. **Exactamente una cámara activa por instancia, medido.** Input y manos actúan solo sobre la local. La tripulante autorada en `playground.tscn` se retira en los roles de red y se queda en el rol `single`. Archivos: `src/net/net_crew_sync.gd` (nuevo), los cambios mínimos de autoridad en `crew_member.gd`, `crew_input.gd`, `crew_hands.gd`, `camera_arbiter.gd`, la parte de `playground.gd` que retira la autorada, y `tests/net/crew_sync_test.gd`.

**B — Carga (D94).** Los paquetes sueltos tienen la autoridad del anfitrión; en mano, la del que la sostiene; amarrada, estado replicado. Los clientes **no simulan** física de carga: sus `Package` van congelados cinemáticos con transformada replicada a 20 Hz e interpolada. Agarrar manda un RPC fiable al anfitrión, que valida y **cede la autoridad** al peer; soltar o lanzar la devuelve, con el punto y la velocidad **en el marco del bus** (en coordenadas de mundo, a 18,5 m/s, una foto de latencia son 0,6 m de error). Amarrar y desamarrar los valida el anfitrión y cada peer los aplica localmente. **Ninguna instancia simula carga que no le pertenece, y eso se mide.** Archivos: `src/net/net_cargo_sync.gd` (nuevo), `package.gd`, y `tests/net/cargo_sync_test.gd`.

### 4.3 Integración y primera iteración del gate

Modo nuevo `++ mode=gate` en el guion de red: el anfitrión conduce **300 s** atacando el campo de baches **en recta** por el carril (cruza a 66,5 km/h; siguiendo el circuito cruzaría a 47,6), con dos cajas amarradas y dos sueltas, y tripulantes guionizadas en las dos instancias que caminan el pasillo y agarran, sueltan y amarran en bucle.

**Ojo con el presupuesto de tiempo:** `NetScenarioUtil.route_budget_s(waypoints) = max(30, waypoints × 15)` da 240 s con la vuelta completa, y de ahí salen las tres esperas del guion — anfitrión (`run_net_scenario.gd:203`), cliente (`:284`, +15 s) y **el plazo del lanzador** (`:364`, +45 s, o sea **285 s**). Una corrida de 300 s **muere antes de terminar** y se reporta como fallo de los hijos. El modo gate deriva su presupuesto de `seconds`, que ya existe como argumento.

**El rol cliente hoy es injugable por un humano** y el gate exige que el dueño lo juegue: `playground.gd:44` deja el input deshabilitado para el cliente, `:47` lo saca de modo jugador, `:51` pone la cámara de persecución y `:52` no captura el ratón. Hay que arreglarlo, y entregar `tools/run_gate.ps1` y `.sh` que lancen todo con una orden, con `++ human=client` para que el dueño juegue la instancia cliente con ventana mientras el anfitrión corre sin ventana.

**Criterio de paso de la primera iteración (D95, entero):** p99 del deslizamiento del cliente ≤ 1,5× el del anfitrión de la misma corrida; ninguna penetración de más de 5 cm ni de más de 3 ticks en ninguna de las dos instancias, con el hueco de la puerta excluido del casco; error remoto de bus, tripulante y carga; fps por **percentil 1** y porcentaje de fotogramas bajo 60, nunca la media; y **contadores de actividad** (`hold_requested/granted/denied`, `release`, `strap_ok/denied`, `unstrap`, `authority_transfers`) con **un mínimo de diez ciclos completos** agarrar → amarrar → desamarrar → soltar **por instancia**. Por debajo de ese mínimo la iteración es **inválida**, no fallida, y no consume una de las tres.

**La regla de las tres iteraciones se aplica literal (D96):** cada corrida del gate es una iteración numerada con su tabla completa en la evidencia. A la **tercera** fallida se para y se escribe el plan de la opción B (interior en espacio local del bus con pseudo-fuerzas). Ningún "una más".

## 5. Alcance, y lo que NO se toca

**Dentro:** `src/net/`, `src/tooling/` (el guion de red y la sonda), `playground.gd`, los cambios mínimos de autoridad en los cuatro archivos de tripulante y cámara, `package.gd`, `tools/run_gate.*`, `tests/`, `DECISIONS.md`, `BACKLOG.md`, `README.md`, `AGENTS.md` (solo la línea de la sonda) y `docs/evidencia/M2-GATE/`.

**Fuera, y el revisor lo comprueba con `git diff`:** `bus.gd` y la suspensión, la sensación aprobada, `data/tuning.json` salvo campos nuevos de red declarados, el traspaso de autoridad del bus al conductor, la reconexión, cuatro peers, voz, HUD, y la **implementación** de la opción B (solo su plan, si toca). Y `main`: no lo tocas.

## 6. Cómo se entrega

Evidencia en `docs/evidencia/M2-GATE/`, numerada como las anteriores: `01_versions` · `02_run_tests` (tres corridas del arnés completo más la sonda de accesos inseguros) · `03_client_carry_measurement` actualizada · `04_gate_iteration_N` (una por iteración, con la tabla entera y los fps) · `05_windowed` (capturas: el cliente viendo la tripulante remota y las cajas; el anfitrión en persecución) · `06_regression` (`run_demo`, red corta y larga, y las seis cifras de sensación, intactas) · `07_git` en dos partes (antes y después del commit) · `08_no_verificado` (lo que **no** probaste, honestamente) · `09_limits` (R8) · `10_windowed_clean_log` con **los logs de las dos instancias**, cero ERROR y cero WARNING · `12_orden_de_escritura` con el test de g2.1 fallando sobre la escritura mala y pasando sobre la buena.

**Criterios de aceptación:** las nueve correcciones hechas, con test las que lo llevan; fase 0 en un commit; A y B entregados sin pisarse; al menos una iteración del gate con su tabla y su veredicto contra D95; `run_demo`, el escenario de red y las seis cifras de sensación intactos; **tres corridas del arnés en código 0** con `expected_tests` actualizado; `git status` limpio **también tras importar en un clon fresco** (un `git worktree add` nuevo, `--import`, y comprobar que no aparecen `.uid` sin trackear); y nada fuera del alcance.

**Antes de dar nada por bueno, juega tú la instancia cliente con ventana mientras el anfitrión conduce.** Las cinco rondas de la tarea anterior fallaron, una tras otra, en cosas que se ven en los tres primeros segundos de jugar.

**Reporte final:** los hashes de tus commits, los tres códigos de salida del arnés, la tabla de la iteración con el criterio nuevo aplicado, los logs limpios de las dos instancias, las capturas, el veredicto A/B con la iteración en que se decidió, y **lo que quede abierto**. Si algo de este prompt no cuadra con lo que ves en el código, **dilo antes de tocarlo**: el revisor ya se ha equivocado tres veces en esta tarea y lo ha escrito cada vez.
